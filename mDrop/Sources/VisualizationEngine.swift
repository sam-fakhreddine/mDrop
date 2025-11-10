import Foundation
import Combine

enum AudioSource {
    case microphone
    case systemAudio
}

@MainActor
class VisualizationEngine: ObservableObject {
    @Published var isRunning = false
    @Published var currentPreset: VisualizationPreset = .plasma
    @Published var audioSource: AudioSource = .microphone

    let audioCaptureEngine: AudioCaptureEngine
    let systemAudioCaptureEngine: SystemAudioCaptureEngine
    let fftAnalyzer: FFTAnalyzer

    private var cancellables = Set<AnyCancellable>()
    private var audioUpdateTimer: Timer?

    var onFrequencyUpdate: (([Float]) -> Void)?
    var onAudioLevelUpdate: ((Float, Float, Float) -> Void)?

    init() {
        audioCaptureEngine = AudioCaptureEngine()
        systemAudioCaptureEngine = SystemAudioCaptureEngine()
        fftAnalyzer = FFTAnalyzer()

        setupBindings()
    }

    private func setupBindings() {
        // Listen to microphone audio level updates
        audioCaptureEngine.$audioLevels
            .sink { [weak self] levels in
                guard let self = self, self.audioSource == .microphone else { return }
                self.fftAnalyzer.analyze(samples: levels)
            }
            .store(in: &cancellables)

        // Listen to system audio level updates
        systemAudioCaptureEngine.$audioLevels
            .sink { [weak self] levels in
                guard let self = self, self.audioSource == .systemAudio else { return }
                self.fftAnalyzer.analyze(samples: levels)
            }
            .store(in: &cancellables)

        // Listen to FFT magnitude updates
        fftAnalyzer.$magnitudes
            .sink { [weak self] magnitudes in
                self?.onFrequencyUpdate?(magnitudes)
            }
            .store(in: &cancellables)

        // Listen to frequency band updates
        Publishers.CombineLatest3(
            fftAnalyzer.$bassLevel,
            fftAnalyzer.$midLevel,
            fftAnalyzer.$trebleLevel
        )
        .sink { [weak self] bass, mid, treble in
            self?.onAudioLevelUpdate?(bass, mid, treble)
        }
        .store(in: &cancellables)
    }

    func start() {
        Task {
            switch audioSource {
            case .microphone:
                audioCaptureEngine.start()
            case .systemAudio:
                await systemAudioCaptureEngine.start()
            }
            isRunning = true
        }
    }

    func stop() {
        Task {
            audioCaptureEngine.stop()
            await systemAudioCaptureEngine.stop()
            isRunning = false
        }
    }

    func setAudioSource(_ source: AudioSource) {
        if isRunning {
            stop()
            audioSource = source
            start()
        } else {
            audioSource = source
        }
    }

    func setPreset(_ preset: VisualizationPreset) {
        currentPreset = preset
    }
}

enum VisualizationPreset: String, CaseIterable, Identifiable {
    case plasma = "Plasma"
    case particle = "Particles"
    case waveform = "Waveform"
    case spectrum = "Spectrum"
    case tunnel = "Tunnel"

    var id: String { rawValue }

    var shaderName: String {
        switch self {
        case .plasma: return "plasma"
        case .particle: return "particle"
        case .waveform: return "waveform"
        case .spectrum: return "spectrum"
        case .tunnel: return "tunnel"
        }
    }

    var description: String {
        switch self {
        case .plasma:
            return "Classic plasma waves with audio-reactive colors"
        case .particle:
            return "Dynamic particle system responding to frequencies"
        case .waveform:
            return "Circular waveform visualization"
        case .spectrum:
            return "Frequency spectrum bars"
        case .tunnel:
            return "Psychedelic tunnel effect"
        }
    }
}
