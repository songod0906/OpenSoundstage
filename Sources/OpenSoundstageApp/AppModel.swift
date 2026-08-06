// SPDX-License-Identifier: MIT

import AppKit
import Foundation
import OpenSoundstageCore
import OpenSoundstageDSP
import SwiftUI

final class WaveformMonitor: ObservableObject {
  @Published fileprivate(set) var snapshot = WaveformSnapshot.silence
}

final class AppModel: ObservableObject {
  @Published var preset: SoundPreset = .whole {
    didSet {
      guard !isRunning else { return }
      settings = preset.settings
      savePreferences()
    }
  }
  @Published var settings = SoundPreset.whole.settings {
    didSet {
      guard !isRunning else { return }
      savePreferences()
    }
  }
  @Published private(set) var isRunning = false
  @Published private(set) var status = "Ready"
  @Published private(set) var outputName = "Default output"
  @Published private(set) var sampleRate: Float = 48_000
  @Published var errorMessage: String?
  @Published var showsProductHealth = false
  @Published private(set) var metrics = ProductMetrics()
  let waveformMonitor = WaveformMonitor()

  private let engine = SystemAudioEngine()
  private let preferencesStore = PreferencesStore()
  private let metricsStore = ProductMetricsStore()
  private var shouldRestartAfterWake = false
  private var sessionStartedAt: Date?
  private var waveformTimer: Timer?

  init() {
    let preferences = preferencesStore.load()
    preset = preferences.preset
    settings = preferences.settings
    metrics = metricsStore.update { $0.recordLaunch() }

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
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(willTerminate),
      name: NSApplication.willTerminateNotification,
      object: nil
    )
    waveformTimer = Timer.scheduledTimer(withTimeInterval: 1 / 15, repeats: true) {
      [weak self] _ in
      guard let self else { return }
      waveformMonitor.snapshot =
        isRunning ? engine.waveformSnapshot(maximumFrameCount: 512) : .silence
    }
  }

  func toggle() {
    isRunning ? stop() : start()
  }

  func start() {
    metrics = metricsStore.update { $0.recordStartAttempt() }
    do {
      errorMessage = nil
      status = "Starting"
      try engine.start(settings: settings)
      isRunning = true
      sessionStartedAt = Date()
      outputName = engine.outputDeviceName
      sampleRate = engine.sampleRate
      status = "Sound is enhanced"
      metrics = metricsStore.update { $0.recordSuccessfulStart() }
    } catch {
      engine.stop()
      isRunning = false
      status = "Stopped"
      errorMessage = error.localizedDescription
      metrics = metricsStore.update {
        $0.recordFailedStart(category: "route_start")
      }
    }
  }

  func stop() {
    engine.stop()
    finishSession()
    isRunning = false
    status = "Ready"
  }

  func resetPreset() {
    guard !isRunning else { return }
    settings = preset.settings
  }

  func flattenEqualizer() {
    guard !isRunning else { return }
    settings.flattenEqualizer()
  }

  func gainBinding(for band: EqualizerBand) -> Binding<Float> {
    Binding(
      get: { self.settings[band] },
      set: { self.settings[band] = $0 }
    )
  }

  func copyMetricsReport() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(metricsStore.report(), forType: .string)
  }

  func resetMetrics() {
    metrics = metricsStore.reset()
  }

  private func restartForOutputChange() {
    guard isRunning else { return }
    engine.stop()
    finishSession()
    isRunning = false
    status = "Output changed. Restarting"
    metrics = metricsStore.update { $0.recordOutputChange() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
      self?.start()
    }
  }

  private func savePreferences() {
    preferencesStore.save(
      AppPreferences(preset: preset, settings: settings)
    )
  }

  private func finishSession() {
    guard let sessionStartedAt else { return }
    metrics = metricsStore.update {
      $0.recordCompletedSession(
        seconds: Date().timeIntervalSince(sessionStartedAt)
      )
    }
    self.sessionStartedAt = nil
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

  @objc private func willTerminate() {
    if isRunning { stop() }
  }

  deinit {
    waveformTimer?.invalidate()
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    NotificationCenter.default.removeObserver(self)
    engine.stop()
  }
}
