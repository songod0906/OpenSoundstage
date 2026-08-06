// SPDX-License-Identifier: MIT

import AppKit
import Foundation
import OpenSoundstageCore
import OpenSoundstageDSP

final class AppModel: ObservableObject {
    @Published var preset: SoundPreset = .whole {
        didSet {
            guard !isRunning else { return }
            settings = preset.settings
        }
    }
    @Published var settings = SoundPreset.whole.settings
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Ready"
    @Published private(set) var outputName = "Default output"
    @Published var errorMessage: String?

    private let engine = SystemAudioEngine()
    private var shouldRestartAfterWake = false

    init() {
        engine.outputDeviceDidChange = { [weak self] in
            self?.restartForOutputChange()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(willSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        do {
            errorMessage = nil
            status = "Starting"
            try engine.start(settings: settings)
            isRunning = true
            outputName = engine.outputDeviceName
            status = "Sound is enhanced"
        } catch {
            engine.stop()
            isRunning = false
            status = "Stopped"
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        engine.stop()
        isRunning = false
        status = "Ready"
    }

    func resetPreset() {
        guard !isRunning else { return }
        settings = preset.settings
    }

    private func restartForOutputChange() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
        status = "Output changed. Restarting"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.start()
        }
    }

    @objc private func willSleep() {
        shouldRestartAfterWake = isRunning
        if isRunning { stop() }
    }

    @objc private func didWake() {
        guard shouldRestartAfterWake else { return }
        shouldRestartAfterWake = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.start()
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        engine.stop()
    }
}
