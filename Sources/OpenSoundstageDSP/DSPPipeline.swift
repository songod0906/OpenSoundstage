// SPDX-License-Identifier: MIT

import Darwin

public final class DSPPipeline: @unchecked Sendable {
  public let sampleRate: Float
  public let settings: DSPSettings

  private var leftFilters: [BiquadFilter]
  private var rightFilters: [BiquadFilter]
  private var envelope: Float = 0
  private var compressorGain: Float = 1
  private var limiterGain: Float = 1

  private let inputGain: Float
  private let compressionThreshold: Float
  private let compressorAttack: Float
  private let compressorRelease: Float
  private let limiterRelease: Float
  private let outputCeiling: Float

  public init(sampleRate: Float, settings: DSPSettings) {
    self.sampleRate = sampleRate
    self.settings = settings
    inputGain = Self.dbToLinear(settings.inputGainDB)
    compressionThreshold = Self.dbToLinear(settings.compressionThresholdDB)
    compressorAttack = expf(-1 / (0.015 * sampleRate))
    compressorRelease = expf(-1 / (0.180 * sampleRate))
    limiterRelease = expf(-1 / (0.080 * sampleRate))
    outputCeiling = Self.dbToLinear(settings.outputCeilingDB)

    let coefficients = [
      BiquadCoefficients.highPass(sampleRate: sampleRate, frequency: 28, q: 0.707),
      BiquadCoefficients.lowShelf(
        sampleRate: sampleRate,
        frequency: 95,
        gainDB: settings.lowShelfDB
      ),
      BiquadCoefficients.peak(
        sampleRate: sampleRate,
        frequency: 320,
        q: 0.72,
        gainDB: settings.bodyDB
      ),
      BiquadCoefficients.peak(
        sampleRate: sampleRate,
        frequency: 3_000,
        q: 0.8,
        gainDB: settings.presenceDB
      ),
      BiquadCoefficients.highShelf(
        sampleRate: sampleRate,
        frequency: 9_500,
        gainDB: settings.airDB
      ),
    ]
    leftFilters = coefficients.map(BiquadFilter.init)
    rightFilters = coefficients.map(BiquadFilter.init)
  }

  public func processInterleaved(
    _ samples: UnsafeMutablePointer<Float>,
    frameCount: Int
  ) {
    guard frameCount > 0 else { return }
    for frame in 0..<frameCount {
      let index = frame * 2
      var left = samples[index]
      var right = samples[index + 1]
      processFrame(left: &left, right: &right)
      samples[index] = left
      samples[index + 1] = right
    }
  }

  public func processPlanar(
    left: UnsafeMutablePointer<Float>,
    right: UnsafeMutablePointer<Float>,
    frameCount: Int
  ) {
    guard frameCount > 0 else { return }
    for frame in 0..<frameCount {
      var leftSample = left[frame]
      var rightSample = right[frame]
      processFrame(left: &leftSample, right: &rightSample)
      left[frame] = leftSample
      right[frame] = rightSample
    }
  }

  private func processFrame(left: inout Float, right: inout Float) {
    for index in leftFilters.indices {
      left = leftFilters[index].process(left)
      right = rightFilters[index].process(right)
    }

    let mid = 0.5 * (left + right)
    let side = 0.5 * (left - right) * settings.width
    left = mid + side
    right = mid - side

    left *= inputGain
    right *= inputGain

    let detector = max(abs(left), abs(right))
    let envelopeCoefficient = detector > envelope ? compressorAttack : compressorRelease
    envelope = envelopeCoefficient * envelope + (1 - envelopeCoefficient) * detector

    var targetGain: Float = 1
    if settings.compressionRatio > 1, envelope > compressionThreshold {
      let overDB = 20 * log10f(max(envelope / compressionThreshold, 0.000_001))
      let reductionDB = overDB * (1 - 1 / settings.compressionRatio)
      targetGain = Self.dbToLinear(-reductionDB)
    }

    let gainCoefficient = targetGain < compressorGain ? compressorAttack : compressorRelease
    compressorGain = gainCoefficient * compressorGain + (1 - gainCoefficient) * targetGain
    left *= compressorGain
    right *= compressorGain

    if settings.saturation > 0 {
      let drive = 1 + settings.saturation * 3
      let normalization = 1 / tanhf(drive)
      left = tanhf(left * drive) * normalization
      right = tanhf(right * drive) * normalization
    }

    let peak = max(abs(left), abs(right))
    let requiredGain = peak > outputCeiling ? outputCeiling / peak : 1
    if requiredGain < limiterGain {
      limiterGain = requiredGain
    } else {
      limiterGain = limiterRelease * limiterGain + (1 - limiterRelease) * requiredGain
    }
    left *= limiterGain
    right *= limiterGain
  }

  public static func dbToLinear(_ decibels: Float) -> Float {
    powf(10, decibels / 20)
  }
}
