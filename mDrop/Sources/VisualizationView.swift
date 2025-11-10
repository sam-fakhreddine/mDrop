import SwiftUI
import MetalKit

struct VisualizationView: NSViewRepresentable {
    @ObservedObject var engine: VisualizationEngine
    var renderer: MetalRenderer?

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60

        if let renderer = MetalRenderer(metalView: mtkView) {
            context.coordinator.renderer = renderer

            // Set up callbacks
            engine.onFrequencyUpdate = { frequencies in
                renderer.updateFrequencyData(frequencies)
            }

            engine.onAudioLevelUpdate = { bass, mid, treble in
                renderer.updateAudioLevels(bass: bass, mid: mid, treble: treble)
            }

            // Set initial shader
            renderer.setShader(engine.currentPreset.shaderName)
        }

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update shader when preset changes
        if let renderer = context.coordinator.renderer {
            renderer.setShader(engine.currentPreset.shaderName)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var renderer: MetalRenderer?
    }
}
