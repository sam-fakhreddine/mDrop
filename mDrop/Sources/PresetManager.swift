import Foundation
import Combine

class PresetManager: ObservableObject {
    @Published var currentPresetIndex: Int = 0
    @Published var autoRotate: Bool = false
    @Published var rotationInterval: TimeInterval = 10.0

    private var rotationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    let presets = VisualizationPreset.allCases

    var currentPreset: VisualizationPreset {
        presets[currentPresetIndex]
    }

    init() {
        setupAutoRotation()
    }

    private func setupAutoRotation() {
        $autoRotate
            .sink { [weak self] autoRotate in
                if autoRotate {
                    self?.startAutoRotation()
                } else {
                    self?.stopAutoRotation()
                }
            }
            .store(in: &cancellables)
    }

    func nextPreset() {
        currentPresetIndex = (currentPresetIndex + 1) % presets.count
    }

    func previousPreset() {
        currentPresetIndex = (currentPresetIndex - 1 + presets.count) % presets.count
    }

    func selectPreset(_ preset: VisualizationPreset) {
        if let index = presets.firstIndex(of: preset) {
            currentPresetIndex = index
        }
    }

    private func startAutoRotation() {
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
            self?.nextPreset()
        }
    }

    private func stopAutoRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    deinit {
        rotationTimer?.invalidate()
    }
}
