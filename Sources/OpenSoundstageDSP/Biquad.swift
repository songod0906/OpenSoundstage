// SPDX-License-Identifier: MIT

import Darwin

struct BiquadCoefficients: Sendable {
  let b0: Float
  let b1: Float
  let b2: Float
  let a1: Float
  let a2: Float

  static func highPass(sampleRate: Float, frequency: Float, q: Float) -> Self {
    let omega = 2 * Float.pi * frequency / sampleRate
    let cosine = cosf(omega)
    let alpha = sinf(omega) / (2 * q)
    let a0 = 1 + alpha
    return Self(
      b0: ((1 + cosine) / 2) / a0,
      b1: (-(1 + cosine)) / a0,
      b2: ((1 + cosine) / 2) / a0,
      a1: (-2 * cosine) / a0,
      a2: (1 - alpha) / a0
    )
  }

  static func peak(sampleRate: Float, frequency: Float, q: Float, gainDB: Float) -> Self {
    let amplitude = powf(10, gainDB / 40)
    let omega = 2 * Float.pi * frequency / sampleRate
    let cosine = cosf(omega)
    let alpha = sinf(omega) / (2 * q)
    let a0 = 1 + alpha / amplitude
    return Self(
      b0: (1 + alpha * amplitude) / a0,
      b1: (-2 * cosine) / a0,
      b2: (1 - alpha * amplitude) / a0,
      a1: (-2 * cosine) / a0,
      a2: (1 - alpha / amplitude) / a0
    )
  }

  func magnitudeDB(at frequency: Float, sampleRate: Float) -> Float {
    let omega = 2 * Double.pi * Double(frequency) / Double(sampleRate)
    let cosine = cos(omega)
    let sine = sin(omega)
    let cosine2 = cos(2 * omega)
    let sine2 = sin(2 * omega)
    let numeratorReal = Double(b0) + Double(b1) * cosine + Double(b2) * cosine2
    let numeratorImaginary = -(Double(b1) * sine + Double(b2) * sine2)
    let denominatorReal = 1 + Double(a1) * cosine + Double(a2) * cosine2
    let denominatorImaginary = -(Double(a1) * sine + Double(a2) * sine2)
    let numerator = numeratorReal * numeratorReal + numeratorImaginary * numeratorImaginary
    let denominator =
      denominatorReal * denominatorReal + denominatorImaginary * denominatorImaginary
    return Float(10 * log10(max(numerator / max(denominator, 1e-18), 1e-18)))
  }

  static func lowShelf(sampleRate: Float, frequency: Float, gainDB: Float) -> Self {
    shelf(sampleRate: sampleRate, frequency: frequency, gainDB: gainDB, high: false)
  }

  static func highShelf(sampleRate: Float, frequency: Float, gainDB: Float) -> Self {
    shelf(sampleRate: sampleRate, frequency: frequency, gainDB: gainDB, high: true)
  }

  private static func shelf(
    sampleRate: Float,
    frequency: Float,
    gainDB: Float,
    high: Bool
  ) -> Self {
    let amplitude = powf(10, gainDB / 40)
    let omega = 2 * Float.pi * frequency / sampleRate
    let cosine = cosf(omega)
    let sine = sinf(omega)
    let alpha = sine / sqrtf(2)
    let twoRootAAlpha = 2 * sqrtf(amplitude) * alpha

    let b0: Float
    let b1: Float
    let b2: Float
    let a0: Float
    let a1: Float
    let a2: Float

    if high {
      b0 = amplitude * ((amplitude + 1) + (amplitude - 1) * cosine + twoRootAAlpha)
      b1 = -2 * amplitude * ((amplitude - 1) + (amplitude + 1) * cosine)
      b2 = amplitude * ((amplitude + 1) + (amplitude - 1) * cosine - twoRootAAlpha)
      a0 = (amplitude + 1) - (amplitude - 1) * cosine + twoRootAAlpha
      a1 = 2 * ((amplitude - 1) - (amplitude + 1) * cosine)
      a2 = (amplitude + 1) - (amplitude - 1) * cosine - twoRootAAlpha
    } else {
      b0 = amplitude * ((amplitude + 1) - (amplitude - 1) * cosine + twoRootAAlpha)
      b1 = 2 * amplitude * ((amplitude - 1) - (amplitude + 1) * cosine)
      b2 = amplitude * ((amplitude + 1) - (amplitude - 1) * cosine - twoRootAAlpha)
      a0 = (amplitude + 1) + (amplitude - 1) * cosine + twoRootAAlpha
      a1 = -2 * ((amplitude - 1) + (amplitude + 1) * cosine)
      a2 = (amplitude + 1) + (amplitude - 1) * cosine - twoRootAAlpha
    }

    return Self(
      b0: b0 / a0,
      b1: b1 / a0,
      b2: b2 / a0,
      a1: a1 / a0,
      a2: a2 / a0
    )
  }
}

struct BiquadFilter: Sendable {
  private let coefficients: BiquadCoefficients
  private var x1: Float = 0
  private var x2: Float = 0
  private var y1: Float = 0
  private var y2: Float = 0

  init(_ coefficients: BiquadCoefficients) {
    self.coefficients = coefficients
  }

  mutating func process(_ input: Float) -> Float {
    let output =
      coefficients.b0 * input
      + coefficients.b1 * x1
      + coefficients.b2 * x2
      - coefficients.a1 * y1
      - coefficients.a2 * y2
    x2 = x1
    x1 = input
    y2 = y1
    y1 = output
    return output
  }
}
