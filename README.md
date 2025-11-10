# mDrop - MilkDrop-style Music Visualizer for macOS

A beautiful, hardware-accelerated music visualizer built natively for macOS and optimized for Apple Silicon.

![Platform](https://img.shields.io/badge/platform-macOS%2013.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![Metal](https://img.shields.io/badge/Metal-GPU%20Accelerated-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Features

- **Real-time Audio Visualization**: Captures system audio or microphone input and visualizes it in stunning, dynamic effects
- **GPU Accelerated**: Built with Metal for maximum performance on Apple Silicon and Intel Macs
- **Multiple Presets**: Five unique visualization modes inspired by the classic MilkDrop visualizer
- **Optimized for Apple Silicon**: Uses native frameworks (Accelerate, Metal) for peak performance
- **SwiftUI Interface**: Modern, native macOS interface with intuitive controls

## Visualization Presets

1. **Plasma**: Classic plasma waves with audio-reactive colors
2. **Particles**: Dynamic particle system responding to frequency data
3. **Waveform**: Circular waveform visualization
4. **Spectrum**: Traditional frequency spectrum bars
5. **Tunnel**: Psychedelic tunnel effect with audio influence

## Technical Stack

- **Language**: Swift 5.0
- **Graphics**: Metal (GPU-accelerated rendering)
- **Audio**: AVFoundation (system audio capture)
- **FFT**: Accelerate framework (optimized for Apple Silicon)
- **UI**: SwiftUI (native macOS interface)

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Apple Silicon (M1/M2/M3) or Intel Mac with Metal support

## Build Instructions

### Using Xcode

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/mDrop.git
   cd mDrop
   ```

2. **Open the project**:
   ```bash
   open mDrop.xcodeproj
   ```

3. **Select your development team**:
   - In Xcode, select the mDrop project in the navigator
   - Go to "Signing & Capabilities"
   - Select your development team

4. **Build and run**:
   - Press `Cmd + R` or click the Run button
   - Grant microphone permissions when prompted

### Using Command Line

```bash
# Build the project
xcodebuild -project mDrop.xcodeproj -scheme mDrop -configuration Release build

# Run the built application
open build/Release/mDrop.app
```

## Usage

### Controls

- **Tap anywhere**: Show/hide controls
- **Swipe left/right**: Change visualization presets
- **Play/Pause button**: Start/stop audio capture
- **Arrow buttons**: Navigate between presets
- **Auto button**: Enable automatic preset rotation
- **Preset buttons**: Directly select a specific preset

### Permissions

On first launch, mDrop will request microphone access. This is required to capture and visualize audio. You can grant this permission in:

**System Settings** > **Privacy & Security** > **Microphone** > Enable for mDrop

## Architecture

### Core Components

#### AudioCaptureEngine (`AudioCaptureEngine.swift`)
- Captures audio using AVFoundation's AVAudioEngine
- Processes audio buffers in real-time
- Provides raw audio samples to the FFT analyzer

#### FFTAnalyzer (`FFTAnalyzer.swift`)
- Performs Fast Fourier Transform using Accelerate framework
- Optimized for Apple Silicon using vDSP
- Analyzes frequency bands (bass, mid, treble)
- Applies Hann window for smoother frequency analysis

#### MetalRenderer (`MetalRenderer.swift`)
- Manages Metal rendering pipeline
- Handles GPU buffer management
- Switches between different shader programs
- Updates uniforms and frequency data each frame

#### Shaders (`Shaders.metal`)
- Five distinct fragment shaders for different visual effects
- Vertex shader for fullscreen quad rendering
- Optimized for Metal on Apple Silicon
- Audio-reactive parameters and color palettes

#### VisualizationEngine (`VisualizationEngine.swift`)
- Coordinates audio capture and FFT analysis
- Manages the visualization lifecycle
- Publishes frequency and audio level updates
- Handles preset switching

#### VisualizationView (`VisualizationView.swift`)
- SwiftUI wrapper for MTKView (Metal view)
- Bridges between SwiftUI and Metal renderer
- Handles view lifecycle and updates

#### PresetManager (`PresetManager.swift`)
- Manages visualization presets
- Handles auto-rotation of presets
- Provides preset metadata and descriptions

### Data Flow

```
Audio Input → AudioCaptureEngine → FFTAnalyzer → VisualizationEngine
                                                          ↓
                                                   MetalRenderer
                                                          ↓
                                                   Metal Shaders
                                                          ↓
                                                      Display
```

## Customization

### Adding New Presets

1. Add a new shader function in `Shaders.metal`
2. Add the preset to the `VisualizationPreset` enum in `VisualizationEngine.swift`
3. Update the `shaderName` computed property to return the new shader name
4. The preset will automatically appear in the UI

### Modifying Shaders

All visual effects are defined in `mDrop/Shaders/Shaders.metal`. Each shader receives:
- `Uniforms`: time, bass/mid/treble levels, resolution
- `frequencies`: array of 256 frequency magnitudes

You can create your own effects by modifying these shaders or adding new ones.

## Performance

- **60 FPS** rendering on Apple Silicon
- **Low CPU usage** due to GPU acceleration
- **Optimized FFT** using Accelerate framework's vDSP
- **Efficient memory management** with Metal buffers

## Troubleshooting

### No visualization appearing
- Check that microphone permissions are granted
- Ensure audio is playing on your system
- Try selecting a different preset

### Poor performance
- Close other GPU-intensive applications
- Reduce window size
- Ensure you're running on a Metal-compatible GPU

### Build errors
- Ensure you're using Xcode 15.0 or later
- Clean build folder: `Cmd + Shift + K`
- Update to the latest macOS SDK

## Known Limitations

- Currently captures microphone input only (system audio loopback coming in future update)
- Requires macOS 13.0 or later
- Must grant microphone permissions to function

## Future Enhancements

- [ ] System audio capture (loopback) without microphone
- [ ] Custom color palettes
- [ ] Preset editor
- [ ] Save/load custom presets
- [ ] Fullscreen mode
- [ ] Window transparency options
- [ ] Beat detection
- [ ] MIDI support

## License

MIT License - See LICENSE file for details

## Credits

Inspired by the legendary Winamp MilkDrop visualizer by Ryan Geiss.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues, questions, or suggestions, please open an issue on GitHub.