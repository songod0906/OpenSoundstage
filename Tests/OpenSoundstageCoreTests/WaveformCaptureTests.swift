// SPDX-License-Identifier: MIT

import OpenSoundstageCore
import XCTest

@testable import OpenSoundstageCore

final class WaveformCaptureTests: XCTestCase {
  func testInterleavedSamplesRoundTripWithoutNormalization() throws {
    let capture = try XCTUnwrap(WaveformCapture(capacity: 8))
    let interleaved: [Float] = [0.25, -0.5, 1, -1, -0.125, 0.75]

    interleaved.withUnsafeBufferPointer { buffer in
      capture.writeInterleaved(buffer.baseAddress!, frameCount: 3)
    }
    let snapshot = capture.snapshot(maximumFrameCount: 8)

    XCTAssertEqual(snapshot.left, [0.25, 1, -0.125])
    XCTAssertEqual(snapshot.right, [-0.5, -1, 0.75])
    XCTAssertEqual(snapshot.leftPeakDBFS, 0, accuracy: 0.000_01)
    XCTAssertEqual(snapshot.rightPeakDBFS, 0, accuracy: 0.000_01)
  }

  func testRMSMeterUsesFullScaleDecibels() {
    let snapshot = WaveformSnapshot(
      left: [0.5, -0.5, 0.5, -0.5],
      right: [0.25, -0.25, 0.25, -0.25]
    )

    XCTAssertEqual(snapshot.leftRMSDBFS, -6.0206, accuracy: 0.001)
    XCTAssertEqual(snapshot.rightRMSDBFS, -12.0412, accuracy: 0.001)
  }

  func testRingReturnsOnlyMostRecentFrames() throws {
    let capture = try XCTUnwrap(WaveformCapture(capacity: 3))
    let interleaved: [Float] = [1, 10, 2, 20, 3, 30, 4, 40]

    interleaved.withUnsafeBufferPointer { buffer in
      capture.writeInterleaved(buffer.baseAddress!, frameCount: 4)
    }
    let snapshot = capture.snapshot(maximumFrameCount: 8)

    XCTAssertEqual(snapshot.left, [2, 3, 4])
    XCTAssertEqual(snapshot.right, [20, 30, 40])
  }
}
