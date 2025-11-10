import Accelerate
import Foundation

class FFTAnalyzer: ObservableObject {
    @Published var magnitudes: [Float] = Array(repeating: 0, count: 256)
    @Published var bassLevel: Float = 0
    @Published var midLevel: Float = 0
    @Published var trebleLevel: Float = 0

    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize: Int = 512
    private var window: [Float] = []
    private var realParts: [Float]
    private var imagParts: [Float]

    init() {
        realParts = Array(repeating: 0, count: fftSize)
        imagParts = Array(repeating: 0, count: fftSize)

        // Create FFT setup for Apple Silicon optimization
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )

        // Create Hann window for smoother frequency analysis
        window = Array(repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    func analyze(samples: [Float]) {
        guard samples.count >= fftSize else { return }

        var windowedSamples = Array(samples.prefix(fftSize))

        // Apply window function
        vDSP_vmul(windowedSamples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // Prepare real and imaginary parts
        realParts = windowedSamples
        imagParts = Array(repeating: 0, count: fftSize)

        // Perform FFT
        guard let setup = fftSetup else { return }

        vDSP_DFT_Execute(
            setup,
            &realParts,
            &imagParts,
            &realParts,
            &imagParts
        )

        // Calculate magnitudes
        var mags = [Float](repeating: 0, count: fftSize / 2)

        // Use withUnsafeMutableBufferPointer for safe pointer access
        realParts.withUnsafeMutableBufferPointer { realBuffer in
            imagParts.withUnsafeMutableBufferPointer { imagBuffer in
                var splitComplex = DSPSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imagBuffer.baseAddress!
                )

                vDSP_zvabs(&splitComplex, 1, &mags, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Normalize
        var normalizedMags = mags
        var maxValue: Float = 0
        vDSP_maxv(mags, 1, &maxValue, vDSP_Length(mags.count))

        if maxValue > 0 {
            vDSP_vsdiv(mags, 1, &maxValue, &normalizedMags, 1, vDSP_Length(mags.count))
        }

        // Update published values
        DispatchQueue.main.async {
            self.magnitudes = Array(normalizedMags.prefix(256))
            self.updateFrequencyBands(normalizedMags)
        }
    }

    private var bandLevels: [Float] = Array(repeating: 0, count: 10)

    private func updateFrequencyBands(_ mags: [Float]) {
        let bands: [(range: Range<Int>, weight: Float)] = [
            (0..<1, 3.0),      // 31 Hz
            (1..<2, 2.5),      // 62 Hz
            (2..<3, 2.0),      // 125 Hz
            (3..<5, 5),      // 250 Hz
            (5..<9, 6),      // 500 Hz
            (9..<17, 7),     // 1 kHz
            (17..<33, 8),    // 2 kHz
            (33..<65, 7),    // 4 kHz
            (65..<129, 7),   // 8 kHz
            (129..<256, 6)   // 16 kHz
        ]
        
        for (index, band) in bands.enumerated() {
            let range = Array(mags[band.range.clamped(to: 0..<mags.count)])
            guard !range.isEmpty else { continue }
            
            let average = range.reduce(0, +) / Float(range.count)
            let weighted = average * band.weight
            
            // Smooth the value
            bandLevels[index] = bandLevels[index] * 0.75 + weighted * 0.25
        }
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
}
