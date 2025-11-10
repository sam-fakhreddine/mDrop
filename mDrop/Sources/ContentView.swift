import SwiftUI

struct ContentView: View {
    @StateObject private var visualizationEngine = VisualizationEngine()
    @StateObject private var presetManager = PresetManager()
    @State private var showControls = true
    @State private var controlsOpacity = 1.0

    var body: some View {
        ZStack {
            // Main visualization view
            VisualizationView(engine: visualizationEngine)
                .edgesIgnoringSafeArea(.all)

            // Controls overlay
            if showControls {
                VStack {
                    Spacer()

                    controlPanel
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.7))
                        )
                        .padding()
                        .opacity(controlsOpacity)
                }
            }
        }
        .onAppear {
            visualizationEngine.start()
        }
        .onDisappear {
            visualizationEngine.stop()
        }
        .onChange(of: presetManager.currentPreset) { newPreset in
            visualizationEngine.setPreset(newPreset)
        }
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width > 0 {
                        presetManager.previousPreset()
                    } else {
                        presetManager.nextPreset()
                    }
                }
        )
    }

    var controlPanel: some View {
        VStack(spacing: 15) {
            // Current preset info
            VStack(spacing: 5) {
                Text(presetManager.currentPreset.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(presetManager.currentPreset.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Preset selection
            HStack(spacing: 10) {
                ForEach(VisualizationPreset.allCases) { preset in
                    Button(action: {
                        presetManager.selectPreset(preset)
                    }) {
                        Text(preset.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                presetManager.currentPreset == preset ?
                                    Color.blue : Color.white.opacity(0.2)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Controls
            HStack(spacing: 20) {
                // Previous button
                Button(action: {
                    presetManager.previousPreset()
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                // Play/Pause button
                Button(action: {
                    if visualizationEngine.isRunning {
                        visualizationEngine.stop()
                    } else {
                        visualizationEngine.start()
                    }
                }) {
                    Image(systemName: visualizationEngine.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                // Next button
                Button(action: {
                    presetManager.nextPreset()
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                // Auto-rotate toggle
                Toggle(isOn: $presetManager.autoRotate) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Auto")
                    }
                    .foregroundColor(.white)
                    .font(.caption)
                }
                .toggleStyle(.button)
            }

            // Audio source selector
            HStack(spacing: 10) {
                Text("Audio Source:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Picker("", selection: $visualizationEngine.audioSource) {
                    Text("🎤 Microphone").tag(AudioSource.microphone)
                    Text("🔊 System Audio").tag(AudioSource.systemAudio)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                .onChange(of: visualizationEngine.audioSource) { newSource in
                    visualizationEngine.setAudioSource(newSource)
                }
            }

            // Audio status indicator
            HStack {
                Circle()
                    .fill(visualizationEngine.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(visualizationEngine.isRunning ?
                     (visualizationEngine.audioSource == .microphone ? "Microphone Active" : "System Audio Active") :
                     "Audio Stopped")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text("Tap to hide controls • Swipe to change presets")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
