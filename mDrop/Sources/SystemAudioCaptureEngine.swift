import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 12.3, *)
class SystemAudioCaptureEngine: NSObject, ObservableObject {
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 512)
    @Published var isCapturing = false

    private var stream: SCStream?
    private var audioBuffer: [Float] = []
    private let bufferSize = 1024
    private var bufferCount = 0

    override init() {
        super.init()
    }

    func start() async {
        do {
            // Request screen recording permission (required for system audio)
            try await requestScreenRecordingPermission()

            // Get shareable content (windows, displays, apps)
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            // Create a filter to capture system audio
            // Capture from the main display
            guard let display = content.displays.first else {
                print("No display found")
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])

            // Configure stream to capture audio only
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.sampleRate = 44100
            config.channelCount = 2

            // Don't capture video (we only want audio)
            config.width = 1
            config.height = 1
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

            // Create and start the stream
            stream = SCStream(filter: filter, configuration: config, delegate: self)

            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
            try await stream?.startCapture()

            DispatchQueue.main.async { [weak self] in
                self?.isCapturing = true
            }

            print("✓ System audio capture started")
        } catch {
            print("Failed to start system audio capture: \(error)")
        }
    }

    func stop() async {
        do {
            try await stream?.stopCapture()
            stream = nil

            DispatchQueue.main.async { [weak self] in
                self?.isCapturing = false
            }

            print("✓ System audio capture stopped")
        } catch {
            print("Failed to stop system audio capture: \(error)")
        }
    }

    private func requestScreenRecordingPermission() async throws {
        // Try to get shareable content - this will trigger permission prompt if needed
        _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }
}

@available(macOS 12.3, *)
extension SystemAudioCaptureEngine: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = false
        }
    }
}

@available(macOS 12.3, *)
extension SystemAudioCaptureEngine: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Extract audio data from the sample buffer
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            print("Failed to get audio buffer list: \(status)")
            return
        }

        defer {
            if let blockBuffer = blockBuffer {
                // Release the block buffer when done
                CFRelease(blockBuffer)
            }
        }

        let buffers = UnsafeBufferPointer<AudioBuffer>(
            start: &audioBufferList.mBuffers,
            count: Int(audioBufferList.mNumberBuffers)
        )

        for buffer in buffers {
            guard let data = buffer.mData else { continue }

            let frameCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            let samples = UnsafeBufferPointer<Float>(
                start: data.assumingMemoryBound(to: Float.self),
                count: frameCount
            )

            // Convert to mono if stereo by averaging channels
            var monoSamples: [Float] = []
            if audioBufferList.mNumberBuffers == 2 {
                // Stereo to mono
                for i in stride(from: 0, to: frameCount, by: 2) {
                    if i + 1 < frameCount {
                        monoSamples.append((samples[i] + samples[i + 1]) / 2.0)
                    }
                }
            } else {
                monoSamples = Array(samples)
            }

            bufferCount += 1
            if bufferCount == 1 || bufferCount % 60 == 0 {
                let rms = sqrt(monoSamples.map { $0 * $0 }.reduce(0, +) / Float(monoSamples.count))
                print("🔊 System audio buffer #\(bufferCount): frames=\(frameCount), RMS=\(rms)")
            }

            // Ensure we have enough data
            var audioData = monoSamples
            if audioData.count < 512 {
                audioData.append(contentsOf: Array(repeating: 0, count: 512 - audioData.count))
            }

            DispatchQueue.main.async { [weak self] in
                self?.audioLevels = Array(audioData.prefix(512))
            }
        }
    }
}
