// SPDX-License-Identifier: MIT

import Foundation

public enum EqualizerBand: Int, CaseIterable, Codable, Identifiable, Sendable {
  case hz32
  case hz64
  case hz125
  case hz250
  case hz500
  case hz1000
  case hz2000
  case hz4000
  case hz8000
  case hz16000

  public var id: Int { rawValue }

  public var frequency: Float {
    [32, 64, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000][rawValue]
  }

  public var label: String {
    switch self {
    case .hz32: "32"
    case .hz64: "64"
    case .hz125: "125"
    case .hz250: "250"
    case .hz500: "500"
    case .hz1000: "1k"
    case .hz2000: "2k"
    case .hz4000: "4k"
    case .hz8000: "8k"
    case .hz16000: "16k"
    }
  }
}

public struct DSPSettings: Codable, Equatable, Sendable {
  public static let equalizerRange: ClosedRange<Float> = -12...12

  public var width: Float
  public var inputGainDB: Float
  public var equalizerGainsDB: [Float]
  public var compressionThresholdDB: Float
  public var compressionRatio: Float
  public var saturation: Float
  public var outputCeilingDB: Float

  public init(
    width: Float = 1.32,
    inputGainDB: Float = 2.2,
    equalizerGainsDB: [Float] = [1.2, 1.8, 1.5, 0.3, -0.7, -0.2, 0.7, 1.0, 1.3, 1.0],
    compressionThresholdDB: Float = -18.0,
    compressionRatio: Float = 2.0,
    saturation: Float = 0.12,
    outputCeilingDB: Float = -1.0
  ) {
    self.width = width
    self.inputGainDB = inputGainDB
    self.equalizerGainsDB = Self.normalized(equalizerGainsDB)
    self.compressionThresholdDB = compressionThresholdDB
    self.compressionRatio = compressionRatio
    self.saturation = saturation
    self.outputCeilingDB = outputCeilingDB
  }

  public subscript(band: EqualizerBand) -> Float {
    get { equalizerGainsDB[band.rawValue] }
    set {
      equalizerGainsDB[band.rawValue] = min(
        max(newValue, Self.equalizerRange.lowerBound), Self.equalizerRange.upperBound)
    }
  }

  public mutating func flattenEqualizer() {
    equalizerGainsDB = Array(repeating: 0, count: EqualizerBand.allCases.count)
  }

  public static let neutral = DSPSettings(
    width: 1.0,
    inputGainDB: 0,
    equalizerGainsDB: Array(repeating: 0, count: EqualizerBand.allCases.count),
    compressionThresholdDB: 0,
    compressionRatio: 1,
    saturation: 0,
    outputCeilingDB: -0.2
  )

  private enum CodingKeys: String, CodingKey {
    case width
    case inputGainDB
    case equalizerGainsDB
    case compressionThresholdDB
    case compressionRatio
    case saturation
    case outputCeilingDB
    case lowShelfDB
    case bodyDB
    case presenceDB
    case airDB
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    width = try values.decodeIfPresent(Float.self, forKey: .width) ?? 1.32
    inputGainDB = try values.decodeIfPresent(Float.self, forKey: .inputGainDB) ?? 2.2
    compressionThresholdDB =
      try values.decodeIfPresent(Float.self, forKey: .compressionThresholdDB) ?? -18
    compressionRatio = try values.decodeIfPresent(Float.self, forKey: .compressionRatio) ?? 2
    saturation = try values.decodeIfPresent(Float.self, forKey: .saturation) ?? 0.12
    outputCeilingDB = try values.decodeIfPresent(Float.self, forKey: .outputCeilingDB) ?? -1

    if let gains = try values.decodeIfPresent([Float].self, forKey: .equalizerGainsDB) {
      equalizerGainsDB = Self.normalized(gains)
    } else {
      let low = try values.decodeIfPresent(Float.self, forKey: .lowShelfDB) ?? 0
      let body = try values.decodeIfPresent(Float.self, forKey: .bodyDB) ?? 0
      let presence = try values.decodeIfPresent(Float.self, forKey: .presenceDB) ?? 0
      let air = try values.decodeIfPresent(Float.self, forKey: .airDB) ?? 0
      equalizerGainsDB = [
        low, low, low * 0.7, body, body * 0.6, 0, presence * 0.7, presence, air, air,
      ]
    }
  }

  public func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(width, forKey: .width)
    try values.encode(inputGainDB, forKey: .inputGainDB)
    try values.encode(equalizerGainsDB, forKey: .equalizerGainsDB)
    try values.encode(compressionThresholdDB, forKey: .compressionThresholdDB)
    try values.encode(compressionRatio, forKey: .compressionRatio)
    try values.encode(saturation, forKey: .saturation)
    try values.encode(outputCeilingDB, forKey: .outputCeilingDB)
  }

  private static func normalized(_ gains: [Float]) -> [Float] {
    EqualizerBand.allCases.map { band in
      let gain = gains.indices.contains(band.rawValue) ? gains[band.rawValue] : 0
      return min(max(gain, equalizerRange.lowerBound), equalizerRange.upperBound)
    }
  }
}

public enum SoundPreset: String, CaseIterable, Codable, Identifiable, Sendable {
  case whole = "Whole"
  case club = "Club"
  case bass = "Bass"
  case voice = "Voice"
  case night = "Night"
  case detail = "Detail"
  case wide = "Wide"
  case gentle = "Gentle"

  public var id: String { rawValue }

  public var summary: String {
    switch self {
    case .whole: "Fuller, coherent everyday sound"
    case .club: "Punch and presence for energetic music"
    case .bass: "Deeper lows without the giant boost"
    case .voice: "Clearer dialogue, podcasts, and vocals"
    case .night: "Tighter dynamics for quiet listening"
    case .detail: "Extra definition with restrained low end"
    case .wide: "A more open stereo image"
    case .gentle: "Light processing for long sessions"
    }
  }

  public var systemImage: String {
    switch self {
    case .whole: "circle.hexagongrid"
    case .club: "music.note.list"
    case .bass: "speaker.wave.3"
    case .voice: "quote.bubble"
    case .night: "moon.stars"
    case .detail: "sparkles"
    case .wide: "arrow.left.and.right"
    case .gentle: "leaf"
    }
  }

  public var settings: DSPSettings {
    switch self {
    case .whole:
      DSPSettings()
    case .club:
      DSPSettings(
        width: 1.26,
        inputGainDB: 1.4,
        equalizerGainsDB: [1.4, 2.2, 1.5, 0.1, -0.8, -0.4, 0.7, 1.2, 1.0, 0.3],
        compressionThresholdDB: -19,
        compressionRatio: 2.2,
        saturation: 0.15
      )
    case .bass:
      DSPSettings(
        width: 1.22,
        inputGainDB: 1.0,
        equalizerGainsDB: [1.8, 2.8, 2.2, 0.8, -0.6, -0.4, 0.2, 0.4, 0.2, 0],
        compressionThresholdDB: -20,
        compressionRatio: 2.2,
        saturation: 0.12
      )
    case .voice:
      DSPSettings(
        width: 1.08,
        inputGainDB: 1.2,
        equalizerGainsDB: [-1.5, -1.3, -0.9, -0.3, 0.8, 1.8, 2.3, 1.4, 0.2, -0.5],
        compressionThresholdDB: -21,
        compressionRatio: 2.5,
        saturation: 0.04
      )
    case .night:
      DSPSettings(
        width: 1.05,
        inputGainDB: 0.4,
        equalizerGainsDB: [0.5, 1.0, 0.8, 0.2, -0.3, 0.4, 1.1, 0.7, -0.4, -0.8],
        compressionThresholdDB: -24,
        compressionRatio: 3.0,
        saturation: 0.03,
        outputCeilingDB: -2.0
      )
    case .detail:
      DSPSettings(
        width: 1.28,
        inputGainDB: 0.7,
        equalizerGainsDB: [-0.4, -0.3, -0.2, -0.3, -0.1, 0.5, 1.2, 1.7, 1.8, 1.0],
        compressionThresholdDB: -18,
        compressionRatio: 1.6,
        saturation: 0.05
      )
    case .wide:
      DSPSettings(
        width: 1.48,
        inputGainDB: 1.6,
        equalizerGainsDB: [0.7, 1.1, 1.0, 0.2, -0.5, -0.2, 0.8, 1.2, 1.6, 1.3],
        compressionThresholdDB: -20,
        compressionRatio: 1.7,
        saturation: 0.08
      )
    case .gentle:
      DSPSettings(
        width: 1.16,
        inputGainDB: 1.0,
        equalizerGainsDB: [0.4, 0.7, 0.6, 0.1, -0.3, 0, 0.3, 0.5, 0.6, 0.4],
        compressionThresholdDB: -16,
        compressionRatio: 1.5,
        saturation: 0.05
      )
    }
  }
}
