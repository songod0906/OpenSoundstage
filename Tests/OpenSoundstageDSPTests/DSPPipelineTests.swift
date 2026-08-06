// SPDX-License-Identifier: MIT

import XCTest

@testable import OpenSoundstageDSP

final class DSPPipelineTests: XCTestCase {
  func testSilenceStaysFiniteAndSilent() {
    let pipeline = DSPPipeline(sampleRate: 48_000, settings: .init())
    var samples = [Float](repeating: 0, count: 4_096)
    let frameCount = samples.count / 2
    samples.withUnsafeMutableBufferPointer {
      pipeline.processInterleaved($0.baseAddress!, frameCount: frameCount)
    }
    XCTAssertTrue(samples.allSatisfy { $0.isFinite && $0 == 0 })
  }

  func testNonSilentInputProducesNonSilentOutput() {
    let pipeline = DSPPipeline(sampleRate: 48_000, settings: .neutral)
    var samples = makeStereoSignal(frames: 2_048) { index in
      let value = sin(Float(index) * 0.09) * 0.25
      return (value, value)
    }
    let frameCount = samples.count / 2

    samples.withUnsafeMutableBufferPointer {
      pipeline.processInterleaved($0.baseAddress!, frameCount: frameCount)
    }

    XCTAssertGreaterThan(samples.lazy.map(abs).max() ?? 0, 0.2)
  }

  func testMonoSignalStaysCentered() {
    let pipeline = DSPPipeline(sampleRate: 48_000, settings: .init(width: 1.6))
    var samples = makeStereoSignal(frames: 8_192) { index in
      let value = sin(Float(index) * 0.031) * 0.2
      return (value, value)
    }
    let frameCount = samples.count / 2
    samples.withUnsafeMutableBufferPointer {
      pipeline.processInterleaved($0.baseAddress!, frameCount: frameCount)
    }
    for frame in 0..<(samples.count / 2) {
      XCTAssertEqual(samples[frame * 2], samples[frame * 2 + 1], accuracy: 0.000_001)
    }
  }

  func testWideningIncreasesSideToMidRatio() {
    var neutral = DSPSettings.neutral
    neutral.width = 1.0
    var wide = neutral
    wide.width = 1.5

    var neutralSamples = makeStereoSignal(frames: 8_192) { index in
      let mid = sin(Float(index) * 0.021) * 0.15
      let side = sin(Float(index) * 0.047) * 0.05
      return (mid + side, mid - side)
    }
    var wideSamples = neutralSamples
    let neutralFrameCount = neutralSamples.count / 2
    let wideFrameCount = wideSamples.count / 2

    neutralSamples.withUnsafeMutableBufferPointer {
      DSPPipeline(sampleRate: 48_000, settings: neutral)
        .processInterleaved($0.baseAddress!, frameCount: neutralFrameCount)
    }
    wideSamples.withUnsafeMutableBufferPointer {
      DSPPipeline(sampleRate: 48_000, settings: wide)
        .processInterleaved($0.baseAddress!, frameCount: wideFrameCount)
    }

    XCTAssertGreaterThan(sideToMidRatio(wideSamples), sideToMidRatio(neutralSamples) * 1.35)
  }

  func testLimiterKeepsSamplesBelowCeiling() {
    var settings = DSPSettings()
    settings.inputGainDB = 12
    settings.outputCeilingDB = -1
    let ceiling = DSPPipeline.dbToLinear(-1)
    let pipeline = DSPPipeline(sampleRate: 48_000, settings: settings)
    var samples = [Float](repeating: 1, count: 8_192)
    let frameCount = samples.count / 2
    samples.withUnsafeMutableBufferPointer {
      pipeline.processInterleaved($0.baseAddress!, frameCount: frameCount)
    }
    let peak = samples.map(abs).max() ?? 0
    XCTAssertLessThanOrEqual(peak, ceiling + 0.000_01)
  }

  func testClubPresetAddsControlledLowEndWithoutBreakingCeiling() {
    let settings = SoundPreset.club.settings
    let lowBass = DSPPipeline.equalizerResponseDB(
      at: 64,
      sampleRate: 48_000,
      settings: settings
    )
    let midrange = DSPPipeline.equalizerResponseDB(
      at: 500,
      sampleRate: 48_000,
      settings: settings
    )

    XCTAssertGreaterThan(lowBass, midrange + 2)

    var samples = makeStereoSignal(frames: 8_192) { index in
      let value = sin(Float(index) * 0.12) * 0.9
      return (value, value * 0.92)
    }
    let frameCount = samples.count / 2
    samples.withUnsafeMutableBufferPointer {
      DSPPipeline(sampleRate: 48_000, settings: settings)
        .processInterleaved($0.baseAddress!, frameCount: frameCount)
    }
    XCTAssertLessThanOrEqual(
      samples.lazy.map(abs).max() ?? 0,
      DSPPipeline.dbToLinear(settings.outputCeilingDB) + 0.000_01
    )
  }

  func testFlatEqualizerResponseIsZeroDecibels() {
    let settings = DSPSettings.neutral
    for frequency: Float in [20, 32, 100, 1_000, 8_000, 20_000] {
      XCTAssertEqual(
        DSPPipeline.equalizerResponseDB(
          at: frequency,
          sampleRate: 48_000,
          settings: settings
        ),
        0,
        accuracy: 0.000_01
      )
    }
  }

  func testEqualizerCenterGainMatchesSelectedBand() {
    var settings = DSPSettings.neutral
    settings[.hz1000] = 6

    let center = DSPPipeline.equalizerResponseDB(
      at: 1_000,
      sampleRate: 48_000,
      settings: settings
    )
    let distant = DSPPipeline.equalizerResponseDB(
      at: 32,
      sampleRate: 48_000,
      settings: settings
    )

    XCTAssertEqual(center, 6, accuracy: 0.001)
    XCTAssertLessThan(abs(distant), 0.02)
  }

  private func makeStereoSignal(
    frames: Int,
    generator: (Int) -> (Float, Float)
  ) -> [Float] {
    var result = [Float]()
    result.reserveCapacity(frames * 2)
    for index in 0..<frames {
      let frame = generator(index)
      result.append(frame.0)
      result.append(frame.1)
    }
    return result
  }

  private func sideToMidRatio(_ samples: [Float]) -> Float {
    var midEnergy: Float = 0
    var sideEnergy: Float = 0
    for frame in 0..<(samples.count / 2) {
      let left = samples[frame * 2]
      let right = samples[frame * 2 + 1]
      let mid = 0.5 * (left + right)
      let side = 0.5 * (left - right)
      midEnergy += mid * mid
      sideEnergy += side * side
    }
    return sqrt(sideEnergy / max(midEnergy, 0.000_001))
  }
}
