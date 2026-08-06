// SPDX-License-Identifier: MIT

import Foundation
import OpenSoundstageDSP

public struct AppPreferences: Codable, Equatable, Sendable {
  public var preset: SoundPreset
  public var settings: DSPSettings

  public init(
    preset: SoundPreset = .whole,
    settings: DSPSettings = SoundPreset.whole.settings
  ) {
    self.preset = preset
    self.settings = settings
  }
}

public final class PreferencesStore {
  private let defaults: UserDefaults
  private let key: String

  public init(
    defaults: UserDefaults = .standard,
    key: String = "product.preferences.v1"
  ) {
    self.defaults = defaults
    self.key = key
  }

  public func load() -> AppPreferences {
    guard let data = defaults.data(forKey: key),
      let value = try? JSONDecoder().decode(AppPreferences.self, from: data)
    else {
      return AppPreferences()
    }
    return value
  }

  public func save(_ preferences: AppPreferences) {
    guard let data = try? JSONEncoder().encode(preferences) else { return }
    defaults.set(data, forKey: key)
  }
}

public struct ProductMetrics: Codable, Equatable, Sendable {
  public var schemaVersion = 1
  public var firstLaunchAt: Date
  public var launchCount = 0
  public var startAttempts = 0
  public var successfulStarts = 0
  public var failedStarts = 0
  public var completedSessions = 0
  public var enhancedSeconds: Double = 0
  public var outputChanges = 0
  public var lastFailureCategory: String?

  public init(firstLaunchAt: Date = Date()) {
    self.firstLaunchAt = firstLaunchAt
  }

  public var startSuccessRate: Double {
    guard startAttempts > 0 else { return 0 }
    return Double(successfulStarts) / Double(startAttempts)
  }

  public mutating func recordLaunch() {
    launchCount += 1
  }

  public mutating func recordStartAttempt() {
    startAttempts += 1
  }

  public mutating func recordSuccessfulStart() {
    successfulStarts += 1
    lastFailureCategory = nil
  }

  public mutating func recordFailedStart(category: String) {
    failedStarts += 1
    lastFailureCategory = category
  }

  public mutating func recordCompletedSession(seconds: TimeInterval) {
    completedSessions += 1
    enhancedSeconds += max(0, seconds)
  }

  public mutating func recordOutputChange() {
    outputChanges += 1
  }
}

public final class ProductMetricsStore {
  private let defaults: UserDefaults
  private let key: String
  private var metrics: ProductMetrics

  public init(
    defaults: UserDefaults = .standard,
    key: String = "product.metrics.v1"
  ) {
    self.defaults = defaults
    self.key = key
    if let data = defaults.data(forKey: key),
      let stored = try? JSONDecoder().decode(ProductMetrics.self, from: data)
    {
      metrics = stored
    } else {
      metrics = ProductMetrics()
    }
  }

  public var current: ProductMetrics { metrics }

  @discardableResult
  public func update(
    _ change: (inout ProductMetrics) -> Void
  ) -> ProductMetrics {
    change(&metrics)
    save()
    return metrics
  }

  @discardableResult
  public func reset(at date: Date = Date()) -> ProductMetrics {
    metrics = ProductMetrics(firstLaunchAt: date)
    metrics.recordLaunch()
    save()
    return metrics
  }

  public func report() -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(metrics),
      let report = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }
    return report
  }

  private func save() {
    guard let data = try? JSONEncoder().encode(metrics) else { return }
    defaults.set(data, forKey: key)
  }
}
