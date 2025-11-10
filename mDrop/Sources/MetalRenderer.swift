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
            return nil
        }

        self.device = device
        metalView.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        super.init()

        metalView.delegate = self
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.colorPixelFormat = .bgra8Unorm

        setupMetal()
        createPipelines()
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
            print("Failed to create Metal library")
            return
        }

        let vertexFunction = library.makeFunction(name: "vertexShader")
        let shaderNames = ["plasma", "particle", "waveform", "spectrum", "tunnel"]

        for shaderName in shaderNames {
            let fragmentFunction = library.makeFunction(name: "\(shaderName)Shader")

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                pipelineStates[shaderName] = pipelineState
            } catch {
                print("Failed to create pipeline state for \(shaderName): \(error)")
            }
        }
    }

    func updateFrequencyData(_ frequencies: [Float]) {
        frequencyData = frequencies
    }

    func updateAudioLevels(bass: Float, mid: Float, treble: Float) {
        uniforms.bassLevel = bass
        uniforms.midLevel = mid
        uniforms.trebleLevel = treble
    }

    // MTKViewDelegate methods
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineStates[currentShader] else {
            return
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
