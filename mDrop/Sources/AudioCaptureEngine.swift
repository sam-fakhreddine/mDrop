import AVFoundation
import Accelerate

class AudioCaptureEngine: NSObject, ObservableObject {
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 512)
    @Published var isCapturing = false

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let bufferSize: AVAudioFrameCount = 1024

    override init() {
        super.init()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        inputNode = engine.inputNode

        let format = inputNode?.outputFormat(forBus: 0)

        inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
    }

    func start() {
        requestMicrophonePermission { [weak self] granted in
            guard granted else {
                print("Microphone permission denied")
                return
            }

            do {
                try self?.audioEngine?.start()
                DispatchQueue.main.async {
                    self?.isCapturing = true
                }
            } catch {
                print("Failed to start audio engine: \(error)")
            }
        }
    }

    func stop() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        DispatchQueue.main.async {
            self.isCapturing = false
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataPointer = channelData[0]
        let frameLength = Int(buffer.frameLength)

        // Convert to array for processing
        var audioData = Array(UnsafeBufferPointer(start: channelDataPointer, count: frameLength))

        // Ensure we have enough data
        if audioData.count < 512 {
            audioData.append(contentsOf: Array(repeating: 0, count: 512 - audioData.count))
        }

        DispatchQueue.main.async {
            self.audioLevels = Array(audioData.prefix(512))
        }
    }

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        #if os(macOS)
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted)
        }
        #else
        completion(true)
        #endif
    }

    deinit {
        stop()
    }
}
