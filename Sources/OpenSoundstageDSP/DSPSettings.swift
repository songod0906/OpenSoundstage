// SPDX-License-Identifier: MIT

import Foundation

public struct DSPSettings: Equatable, Sendable {
    public var width: Float
    public var inputGainDB: Float
    public var lowShelfDB: Float
    public var bodyDB: Float
    public var presenceDB: Float
    public var airDB: Float
    public var compressionThresholdDB: Float
    public var compressionRatio: Float
    public var saturation: Float
    public var outputCeilingDB: Float

    public init(
        width: Float = 1.32,
        inputGainDB: Float = 2.2,
        lowShelfDB: Float = 2.0,
        bodyDB: Float = -0.7,
        presenceDB: Float = 1.0,
        airDB: Float = 1.3,
        compressionThresholdDB: Float = -18.0,
        compressionRatio: Float = 2.0,
        saturation: Float = 0.12,
        outputCeilingDB: Float = -1.0
    ) {
        self.width = width
        self.inputGainDB = inputGainDB
        self.lowShelfDB = lowShelfDB
        self.bodyDB = bodyDB
        self.presenceDB = presenceDB
        self.airDB = airDB
        self.compressionThresholdDB = compressionThresholdDB
        self.compressionRatio = compressionRatio
        self.saturation = saturation
        self.outputCeilingDB = outputCeilingDB
    }

    public static let neutral = DSPSettings(
        width: 1.0,
        inputGainDB: 0,
        lowShelfDB: 0,
        bodyDB: 0,
        presenceDB: 0,
        airDB: 0,
        compressionThresholdDB: 0,
        compressionRatio: 1,
        saturation: 0,
        outputCeilingDB: -0.2
    )
}

public enum SoundPreset: String, CaseIterable, Identifiable, Sendable {
    case whole = "Whole"
    case wide = "Wide"
    case gentle = "Gentle"

    public var id: String { rawValue }

    public var settings: DSPSettings {
        switch self {
        case .whole:
            DSPSettings()
        case .wide:
            DSPSettings(
                width: 1.48,
                inputGainDB: 1.6,
                lowShelfDB: 1.5,
                bodyDB: -0.5,
                presenceDB: 1.2,
                airDB: 1.6,
                compressionThresholdDB: -20,
                compressionRatio: 1.7,
                saturation: 0.08
            )
        case .gentle:
            DSPSettings(
                width: 1.16,
                inputGainDB: 1.0,
                lowShelfDB: 1.0,
                bodyDB: -0.3,
                presenceDB: 0.5,
                airDB: 0.6,
                compressionThresholdDB: -16,
                compressionRatio: 1.5,
                saturation: 0.05
            )
        }
    }
}
