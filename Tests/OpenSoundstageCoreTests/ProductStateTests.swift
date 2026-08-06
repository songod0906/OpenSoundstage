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
      metrics.recordPresetSelection("Voice")
      metrics.recordPresetSelection("Voice")
    }

    let metrics = ProductMetricsStore(defaults: defaults).current
    XCTAssertEqual(metrics.launchCount, 1)
    XCTAssertEqual(metrics.startSuccessRate, 1)
    XCTAssertEqual(metrics.completedSessions, 1)
    XCTAssertEqual(metrics.enhancedSeconds, 125)
    XCTAssertEqual(metrics.outputChanges, 1)
    XCTAssertEqual(metrics.presetSelections["Voice"], 2)
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

  func testVersionOneMetricsMigrateWithoutLosingCounters() throws {
    let json = """
      {
        "schemaVersion": 1,
        "firstLaunchAt": 0,
        "launchCount": 7,
        "startAttempts": 3,
        "successfulStarts": 2,
        "failedStarts": 1,
        "completedSessions": 2,
        "enhancedSeconds": 500,
        "outputChanges": 1
      }
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let metrics = try decoder.decode(ProductMetrics.self, from: Data(json.utf8))

    XCTAssertEqual(metrics.schemaVersion, 2)
    XCTAssertEqual(metrics.launchCount, 7)
    XCTAssertEqual(metrics.successfulStarts, 2)
    XCTAssertEqual(metrics.presetSelections, [:])
  }

  private func makeDefaults() throws -> UserDefaults {
    let suiteName = "org.opensoundstage.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}
