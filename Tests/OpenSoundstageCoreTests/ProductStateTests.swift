// SPDX-License-Identifier: MIT

import Foundation
import OpenSoundstageCore
import OpenSoundstageDSP
import XCTest

final class ProductStateTests: XCTestCase {
  func testPreferencesRoundTrip() throws {
    let defaults = try makeDefaults()
    let store = PreferencesStore(defaults: defaults)
    var settings = SoundPreset.wide.settings
    settings.width = 1.41
    let expected = AppPreferences(preset: .wide, settings: settings)

    store.save(expected)

    XCTAssertEqual(store.load(), expected)
  }

  func testMetricsTrackActivationAndListeningTime() throws {
    let defaults = try makeDefaults()
    let store = ProductMetricsStore(defaults: defaults)

    store.update { metrics in
      metrics.recordLaunch()
      metrics.recordStartAttempt()
      metrics.recordSuccessfulStart()
      metrics.recordCompletedSession(seconds: 125)
      metrics.recordOutputChange()
    }

    let metrics = ProductMetricsStore(defaults: defaults).current
    XCTAssertEqual(metrics.launchCount, 1)
    XCTAssertEqual(metrics.startSuccessRate, 1)
    XCTAssertEqual(metrics.completedSessions, 1)
    XCTAssertEqual(metrics.enhancedSeconds, 125)
    XCTAssertEqual(metrics.outputChanges, 1)
  }

  func testMetricsReportContainsNoAudioOrDeviceFields() throws {
    let defaults = try makeDefaults()
    let report = ProductMetricsStore(defaults: defaults).report().lowercased()

    XCTAssertFalse(report.contains("audio"))
    XCTAssertFalse(report.contains("device"))
    XCTAssertFalse(report.contains("outputname"))
  }

  private func makeDefaults() throws -> UserDefaults {
    let suiteName = "org.opensoundstage.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}
