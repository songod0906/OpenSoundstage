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
