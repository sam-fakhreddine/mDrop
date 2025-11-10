import Metal
import MetalKit
import simd

class MetalRenderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineStates: [String: MTLRenderPipelineState] = [:]
    var currentShader: String = "plasma"

    private var vertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    private var frequencyBuffer: MTLBuffer!

    struct Uniforms {
        var time: Float = 0
        var bassLevel: Float = 0
        var midLevel: Float = 0
        var trebleLevel: Float = 0
        var resolution: SIMD2<Float> = SIMD2<Float>(800, 600)
    }

    var uniforms = Uniforms()
    var frequencyData: [Float] = Array(repeating: 0, count: 256)

    init?(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("ERROR: No Metal device available")
            return nil
        }

        print("✓ Metal device: \(device.name)")
        self.device = device
        metalView.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            print("ERROR: Failed to create command queue")
            return nil
        }
        self.commandQueue = commandQueue

        super.init()

        metalView.delegate = self
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.colorPixelFormat = .bgra8Unorm

        print("Setting up Metal renderer...")
        setupMetal()
        createPipelines()
        print("✓ Metal renderer initialized with \(pipelineStates.count) pipelines")
    }

    private func setupMetal() {
        // Create vertex buffer for fullscreen quad
        let vertices: [Float] = [
            // Position    // TexCoord
            -1.0,  1.0,    0.0, 0.0,
            -1.0, -1.0,    0.0, 1.0,
             1.0, -1.0,    1.0, 1.0,

            -1.0,  1.0,    0.0, 0.0,
             1.0, -1.0,    1.0, 1.0,
             1.0,  1.0,    1.0, 0.0
        ]

        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.size,
            options: .storageModeShared
        )

        // Create uniform buffer
        uniformBuffer = device.makeBuffer(
            length: MemoryLayout<Uniforms>.size,
            options: .storageModeShared
        )

        // Create frequency buffer
        frequencyBuffer = device.makeBuffer(
            length: 256 * MemoryLayout<Float>.size,
            options: .storageModeShared
        )
    }

    private func createPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            print("ERROR: Failed to create Metal library - shaders may not be compiled")
            return
        }

        guard let vertexFunction = library.makeFunction(name: "vertexShader") else {
            print("ERROR: Failed to find vertexShader function")
            return
        }

        let shaderNames = ["plasma", "particle", "waveform", "spectrum", "tunnel"]

        for shaderName in shaderNames {
            guard let fragmentFunction = library.makeFunction(name: "\(shaderName)Shader") else {
                print("ERROR: Failed to find \(shaderName)Shader function")
                continue
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            // Set up vertex descriptor (not strictly needed for our fullscreen quad, but good practice)
            let vertexDescriptor = MTLVertexDescriptor()
            // Position attribute
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            // TexCoord attribute
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
            vertexDescriptor.attributes[1].bufferIndex = 0
            // Layout
            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex

            pipelineDescriptor.vertexDescriptor = vertexDescriptor

            do {
                let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                pipelineStates[shaderName] = pipelineState
                print("Successfully created pipeline for: \(shaderName)")
            } catch {
                print("ERROR: Failed to create pipeline state for \(shaderName): \(error)")
            }
        }

        print("Total pipelines created: \(pipelineStates.count)")
    }

    private var updateCount = 0

    func updateFrequencyData(_ frequencies: [Float]) {
        frequencyData = frequencies
        updateCount += 1
        if updateCount == 1 || updateCount % 60 == 0 {
            let maxFreq = frequencies.max() ?? 0
            print("📊 Frequency update #\(updateCount): max=\(maxFreq)")
        }
    }

    func updateAudioLevels(bass: Float, mid: Float, treble: Float) {
        uniforms.bassLevel = bass
        uniforms.midLevel = mid
        uniforms.trebleLevel = treble
        if updateCount == 1 || updateCount % 60 == 0 {
            print("🎵 Audio levels: bass=\(bass), mid=\(mid), treble=\(treble)")
        }
    }

    // MTKViewDelegate methods
    private var drawCount = 0

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
        print("📐 View size changed: \(size.width) x \(size.height)")
    }

    func draw(in view: MTKView) {
        drawCount += 1

        guard let drawable = view.currentDrawable else {
            if drawCount % 60 == 0 {
                print("⚠️  No drawable available")
            }
            return
        }

        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            if drawCount % 60 == 0 {
                print("⚠️  No render pass descriptor")
            }
            return
        }

        guard let pipelineState = pipelineStates[currentShader] else {
            if drawCount % 60 == 0 {
                print("⚠️  No pipeline state for shader: \(currentShader)")
            }
            return
        }

        if drawCount == 1 {
            print("🎨 First draw call - shader: \(currentShader)")
        }
        if drawCount % 60 == 0 {
            print("🎨 Draw #\(drawCount) - time: \(uniforms.time)")
        }

        // Update uniforms
        uniforms.time += 0.016 // Approximately 60 FPS
        let uniformPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniformPointer.pointee = uniforms

        // Update frequency data
        let frequencyPointer = frequencyBuffer.contents().bindMemory(to: Float.self, capacity: 256)
        for i in 0..<min(256, frequencyData.count) {
            frequencyPointer[i] = frequencyData[i]
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(frequencyBuffer, offset: 0, index: 1)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func setShader(_ shaderName: String) {
        if pipelineStates[shaderName] != nil {
            currentShader = shaderName
        }
    }
}
