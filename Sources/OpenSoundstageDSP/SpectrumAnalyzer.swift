// SPDX-License-Identifier: MIT

import Accelerate
import Foundation

public struct SpectrumPoint: Equatable, Sendable {
  public let frequency: Float
  public let decibels: Float

  public init(frequency: Float, decibels: Float) {
    self.frequency = frequency
    self.decibels = decibels
  }
}

public struct SpectrumSnapshot: Equatable, Sendable {
  public let points: [SpectrumPoint]

  public static let silence = SpectrumSnapshot(points: [])

  public init(points: [SpectrumPoint]) {
    self.points = points
  }
}

/// Calculates a one-sided, Hann-windowed FFT outside the real-time audio callback.
public final class SpectrumAnalyzer {
  public let frameCount: Int

  private let log2FrameCount: vDSP_Length
  private let setup: FFTSetup
  private var window: [Float]

  public init?(frameCount: Int = 2_048) {
    guard frameCount >= 256, frameCount.nonzeroBitCount == 1 else { return nil }
    let log2FrameCount = vDSP_Length(log2(Double(frameCount)))
    guard let setup = vDSP_create_fftsetup(log2FrameCount, FFTRadix(kFFTRadix2)) else {
      return nil
    }
    self.frameCount = frameCount
    self.log2FrameCount = log2FrameCount
    self.setup = setup
    window = [Float](repeating: 0, count: frameCount)
    vDSP_hann_window(&window, vDSP_Length(frameCount), Int32(vDSP_HANN_DENORM))
  }

  public func analyze(
    left: [Float],
    right: [Float],
    sampleRate: Float,
    maximumFrequency: Float = 20_000
  ) -> SpectrumSnapshot {
    guard left.count >= frameCount, right.count >= frameCount, sampleRate > 0 else {
      return .silence
    }

    let leftStart = left.count - frameCount
    let rightStart = right.count - frameCount
    var mono = [Float](repeating: 0, count: frameCount)
    for index in 0..<frameCount {
      mono[index] = 0.5 * (left[leftStart + index] + right[rightStart + index])
    }
    vDSP_vmul(mono, 1, window, 1, &mono, 1, vDSP_Length(frameCount))

    let binCount = frameCount / 2
    var real = [Float](repeating: 0, count: binCount)
    var imaginary = [Float](repeating: 0, count: binCount)
    var magnitudes = [Float](repeating: 0, count: binCount)

    real.withUnsafeMutableBufferPointer { realBuffer in
      imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
        var split = DSPSplitComplex(
          realp: realBuffer.baseAddress!,
          imagp: imaginaryBuffer.baseAddress!
        )
        mono.withUnsafeBufferPointer { monoBuffer in
          monoBuffer.baseAddress!.withMemoryRebound(
            to: DSPComplex.self,
            capacity: binCount
          ) { complex in
            vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(binCount))
          }
        }
        vDSP_fft_zrip(setup, &split, 1, log2FrameCount, FFTDirection(FFT_FORWARD))
        vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(binCount))
      }
    }

    let frequencyStep = sampleRate / Float(frameCount)
    // vDSP's packed real FFT yields N / 2 magnitude for a bin-centered full-scale sine.
    // The denormalized Hann window halves it, so 2 / N restores the original amplitude.
    let amplitudeScale = 2 / Float(frameCount)
    let lastBin = min(binCount - 1, Int(maximumFrequency / frequencyStep))
    guard lastBin >= 1 else { return .silence }

    let points = (1...lastBin).map { bin in
      let amplitude = sqrtf(max(magnitudes[bin], 0)) * amplitudeScale
      let decibels = max(-96, 20 * log10f(max(amplitude, 0.000_015_848_9)))
      return SpectrumPoint(
        frequency: Float(bin) * frequencyStep,
        decibels: decibels
      )
    }
    return SpectrumSnapshot(points: points)
  }

  deinit {
    vDSP_destroy_fftsetup(setup)
  }
}
