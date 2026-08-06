// SPDX-License-Identifier: MIT

import Darwin
import OpenSoundstageRealtime

public struct WaveformSnapshot: Equatable, Sendable {
  public let left: [Float]
  public let right: [Float]
  public let leftPeakDBFS: Float
  public let rightPeakDBFS: Float
  public let leftRMSDBFS: Float
  public let rightRMSDBFS: Float

  public static let silence = WaveformSnapshot(left: [], right: [])

  public init(left: [Float], right: [Float]) {
    self.left = left
    self.right = right
    leftPeakDBFS = Self.peakDBFS(left)
    rightPeakDBFS = Self.peakDBFS(right)
    leftRMSDBFS = Self.rmsDBFS(left)
    rightRMSDBFS = Self.rmsDBFS(right)
  }

  private static func peakDBFS(_ samples: [Float]) -> Float {
    guard let peak = samples.lazy.map(abs).max() else { return -96 }
    return decibels(fullScale: peak)
  }

  private static func rmsDBFS(_ samples: [Float]) -> Float {
    guard !samples.isEmpty else { return -96 }
    let energy = samples.reduce(Float.zero) { $0 + $1 * $1 }
    return decibels(fullScale: sqrtf(energy / Float(samples.count)))
  }

  private static func decibels(fullScale value: Float) -> Float {
    max(-96, 20 * log10f(max(value, 0.000_015_848_9)))
  }
}

public final class WaveformCapture: @unchecked Sendable {
  private let ring: OpaquePointer

  public init?(capacity: Int = 8_192) {
    guard capacity > 0, let ring = oss_waveform_ring_create(capacity) else { return nil }
    self.ring = ring
  }

  public func clear() {
    oss_waveform_ring_clear(ring)
  }

  func writeInterleaved(_ samples: UnsafePointer<Float>, frameCount: Int) {
    oss_waveform_ring_write_interleaved(ring, samples, frameCount)
  }

  func writePlanar(
    left: UnsafePointer<Float>,
    right: UnsafePointer<Float>,
    frameCount: Int
  ) {
    oss_waveform_ring_write_planar(ring, left, right, frameCount)
  }

  public func snapshot(maximumFrameCount: Int = 1_024) -> WaveformSnapshot {
    guard maximumFrameCount > 0 else { return .silence }
    var left = [Float](repeating: 0, count: maximumFrameCount)
    var right = [Float](repeating: 0, count: maximumFrameCount)
    let count = left.withUnsafeMutableBufferPointer { leftBuffer in
      right.withUnsafeMutableBufferPointer { rightBuffer in
        oss_waveform_ring_copy_latest(
          ring,
          leftBuffer.baseAddress,
          rightBuffer.baseAddress,
          maximumFrameCount
        )
      }
    }
    left.removeLast(maximumFrameCount - count)
    right.removeLast(maximumFrameCount - count)
    return WaveformSnapshot(left: left, right: right)
  }

  deinit {
    oss_waveform_ring_destroy(ring)
  }
}
