// SPDX-License-Identifier: MIT

import Accelerate
import Darwin

public final class DSPPipeline: @unchecked Sendable {
  public let sampleRate: Float
  public let settings: DSPSettings

  private let filterSetup: vDSP_biquad_Setup
  private var leftDelay: [Float]
  private var rightDelay: [Float]
  private var leftScratch: [Float]
  private var rightScratch: [Float]
  private var envelope: Float = 0
  private var compressorGain: Float = 1
  private var compressorTargetGain: Float = 1
  private var framesUntilCompressorUpdate = 0
  private var limiterGain: Float = 1

  private let inputGain: Float
  private let compressionThreshold: Float
  private let compressorAttack: Float
  private let compressorRelease: Float
  private let limiterRelease: Float
  private let outputCeiling: Float
  private let saturationDrive: Float
  private let saturationNormalization: Float

  public init(sampleRate: Float, settings: DSPSettings) {
    self.sampleRate = sampleRate
    self.settings = settings
    inputGain = Self.dbToLinear(settings.inputGainDB)
    compressionThreshold = Self.dbToLinear(settings.compressionThresholdDB)
    compressorAttack = expf(-1 / (0.015 * sampleRate))
    compressorRelease = expf(-1 / (0.180 * sampleRate))
    limiterRelease = expf(-1 / (0.080 * sampleRate))
    outputCeiling = Self.dbToLinear(settings.outputCeilingDB)
    saturationDrive = 1 + settings.saturation * 3
    saturationNormalization = 1 / Self.fastTanh(saturationDrive)

    let coefficients = Self.filterCoefficients(sampleRate: sampleRate, settings: settings)
    let flattened = coefficients.flatMap { coefficients in
      [
        Double(coefficients.b0),
        Double(coefficients.b1),
        Double(coefficients.b2),
        Double(coefficients.a1),
        Double(coefficients.a2),
      ]
    }
    guard let setup = vDSP_biquad_CreateSetup(flattened, vDSP_Length(coefficients.count)) else {
      preconditionFailure("Accelerate could not create the equalizer.")
    }
    filterSetup = setup
    leftDelay = Array(repeating: 0, count: 2 * (coefficients.count + 1))
    rightDelay = Array(repeating: 0, count: 2 * (coefficients.count + 1))
    leftScratch = Array(repeating: 0, count: Self.maximumBlockFrames)
    rightScratch = Array(repeating: 0, count: Self.maximumBlockFrames)
  }

  public func processInterleaved(
    _ samples: UnsafeMutablePointer<Float>,
    frameCount: Int
  ) {
    guard frameCount > 0 else { return }
    var offset = 0
    while offset < frameCount {
      let count = min(Self.maximumBlockFrames, frameCount - offset)
      leftDelay.withUnsafeMutableBufferPointer { delay in
        leftScratch.withUnsafeMutableBufferPointer { scratch in
          vDSP_biquad(
            filterSetup,
            delay.baseAddress!,
            samples + offset * 2,
            2,
            scratch.baseAddress!,
            1,
            vDSP_Length(count)
          )
        }
      }
      rightDelay.withUnsafeMutableBufferPointer { delay in
        rightScratch.withUnsafeMutableBufferPointer { scratch in
          vDSP_biquad(
            filterSetup,
            delay.baseAddress!,
            samples + offset * 2 + 1,
            2,
            scratch.baseAddress!,
            1,
            vDSP_Length(count)
          )
        }
      }
      for frame in 0..<count {
        var left = leftScratch[frame]
        var right = rightScratch[frame]
        processFrame(left: &left, right: &right)
        let index = (offset + frame) * 2
        samples[index] = left
        samples[index + 1] = right
      }
      offset += count
    }
  }

  public func processPlanar(
    left: UnsafeMutablePointer<Float>,
    right: UnsafeMutablePointer<Float>,
    frameCount: Int
  ) {
    guard frameCount > 0 else { return }
    var offset = 0
    while offset < frameCount {
      let count = min(Self.maximumBlockFrames, frameCount - offset)
      leftDelay.withUnsafeMutableBufferPointer { delay in
        leftScratch.withUnsafeMutableBufferPointer { scratch in
          vDSP_biquad(
            filterSetup,
            delay.baseAddress!,
            left + offset,
            1,
            scratch.baseAddress!,
            1,
            vDSP_Length(count)
          )
        }
      }
      rightDelay.withUnsafeMutableBufferPointer { delay in
        rightScratch.withUnsafeMutableBufferPointer { scratch in
          vDSP_biquad(
            filterSetup,
            delay.baseAddress!,
            right + offset,
            1,
            scratch.baseAddress!,
            1,
            vDSP_Length(count)
          )
        }
      }
      for frame in 0..<count {
        var leftSample = leftScratch[frame]
        var rightSample = rightScratch[frame]
        processFrame(left: &leftSample, right: &rightSample)
        left[offset + frame] = leftSample
        right[offset + frame] = rightSample
      }
      offset += count
    }
  }

  private func processFrame(left: inout Float, right: inout Float) {
    let mid = 0.5 * (left + right)
    let side = 0.5 * (left - right) * settings.width
    left = mid + side
    right = mid - side

    left *= inputGain
    right *= inputGain

    let detector = max(abs(left), abs(right))
    let envelopeCoefficient = detector > envelope ? compressorAttack : compressorRelease
    envelope = envelopeCoefficient * envelope + (1 - envelopeCoefficient) * detector

    if framesUntilCompressorUpdate == 0 {
      compressorTargetGain = 1
      if settings.compressionRatio > 1, envelope > compressionThreshold {
        let overDB = 20 * log10f(max(envelope / compressionThreshold, 0.000_001))
        let reductionDB = overDB * (1 - 1 / settings.compressionRatio)
        compressorTargetGain = Self.dbToLinear(-reductionDB)
      }
      framesUntilCompressorUpdate = Self.compressorUpdateInterval - 1
    } else {
      framesUntilCompressorUpdate -= 1
    }

    let gainCoefficient =
      compressorTargetGain < compressorGain ? compressorAttack : compressorRelease
    compressorGain =
      gainCoefficient * compressorGain + (1 - gainCoefficient) * compressorTargetGain
    left *= compressorGain
    right *= compressorGain

    if settings.saturation > 0 {
      left = Self.fastTanh(left * saturationDrive) * saturationNormalization
      right = Self.fastTanh(right * saturationDrive) * saturationNormalization
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

  public static func equalizerResponseDB(
    at frequency: Float,
    sampleRate: Float,
    settings: DSPSettings
  ) -> Float {
    EqualizerBand.allCases.reduce(0) { response, band in
      response
        + BiquadCoefficients.peak(
          sampleRate: sampleRate,
          frequency: band.frequency,
          q: equalizerQ,
          gainDB: settings[band]
        ).magnitudeDB(at: frequency, sampleRate: sampleRate)
    }
  }

  private static let equalizerQ: Float = 1.1
  private static let maximumBlockFrames = 8_192
  private static let compressorUpdateInterval = 16

  private static func fastTanh(_ value: Float) -> Float {
    let limited = min(max(value, -3), 3)
    let squared = limited * limited
    return limited * (27 + squared) / (27 + 9 * squared)
  }

  private static func filterCoefficients(
    sampleRate: Float,
    settings: DSPSettings
  ) -> [BiquadCoefficients] {
    [BiquadCoefficients.highPass(sampleRate: sampleRate, frequency: 28, q: 0.707)]
      + EqualizerBand.allCases.map { band in
        BiquadCoefficients.peak(
          sampleRate: sampleRate,
          frequency: band.frequency,
          q: equalizerQ,
          gainDB: settings[band]
        )
      }
  }

  deinit {
    vDSP_biquad_DestroySetup(filterSetup)
  }
}
