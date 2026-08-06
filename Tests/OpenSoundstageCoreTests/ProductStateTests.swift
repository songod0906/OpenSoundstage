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

  func testLegacyPreferencesMigrateToEqualizerBands() throws {
    let json = """
      {
        "width": 1.3,
        "inputGainDB": 2,
        "lowShelfDB": 2,
        "bodyDB": -1,
        "presenceDB": 1.5,
        "airDB": 1,
        "compressionThresholdDB": -18,
        "compressionRatio": 2,
        "saturation": 0.1,
        "outputCeilingDB": -1
      }
      """

    let settings = try JSONDecoder().decode(DSPSettings.self, from: Data(json.utf8))

    XCTAssertEqual(settings[.hz32], 2)
    XCTAssertEqual(settings[.hz250], -1)
    XCTAssertEqual(settings[.hz4000], 1.5)
    XCTAssertEqual(settings[.hz16000], 1)
  }

  private func makeDefaults() throws -> UserDefaults {
    let suiteName = "org.opensoundstage.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}
