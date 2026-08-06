// SPDX-License-Identifier: MIT
// The Core Audio property helpers are based in part on AudioCap.
// See ThirdParty/NOTICE.md.

import AudioToolbox
import CoreAudio
import Foundation

public struct SoundstageError: LocalizedError, Sendable {
  public let message: String
  public var errorDescription: String? { message }

  public init(_ message: String) {
    self.message = message
  }
}

extension AudioObjectID {
  static var system: AudioObjectID { AudioObjectID(kAudioObjectSystemObject) }
  static var unknown: AudioObjectID { kAudioObjectUnknown }
  var isValid: Bool { self != .unknown }

  func read<T>(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
    defaultValue: T
  ) throws -> T {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: scope,
      mElement: element
    )
    var dataSize = UInt32(MemoryLayout<T>.size)
    var value = defaultValue
    let status = withUnsafeMutableBytes(of: &value) { bytes in
      AudioObjectGetPropertyData(
        self,
        &address,
        0,
        nil,
        &dataSize,
        bytes.baseAddress!
      )
    }
    guard status == noErr else {
      throw SoundstageError("Core Audio could not read property \(selector). Error: \(status).")
    }
    return value
  }

  func readString(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
  ) throws -> String {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMain
    )
    var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    var value: Unmanaged<CFString>?
    let status = withUnsafeMutablePointer(to: &value) { pointer in
      AudioObjectGetPropertyData(self, &address, 0, nil, &dataSize, pointer)
    }
    guard status == noErr, let value else {
      throw SoundstageError(
        "Core Audio could not read text property \(selector). Error: \(status).")
    }
    return value.takeUnretainedValue() as String
  }
}

enum CoreAudioDevices {
  static func defaultOutput() throws -> AudioDeviceID {
    let device: AudioDeviceID = try AudioObjectID.system.read(
      kAudioHardwarePropertyDefaultOutputDevice,
      defaultValue: .unknown
    )
    guard device.isValid else {
      throw SoundstageError("No default audio output is available.")
    }
    return device
  }

  static func processObject(for processID: pid_t) throws -> AudioObjectID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var qualifier = processID
    var objectID = AudioObjectID.unknown
    var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = withUnsafePointer(to: &qualifier) { pointer in
      AudioObjectGetPropertyData(
        AudioObjectID.system,
        &address,
        UInt32(MemoryLayout<pid_t>.size),
        pointer,
        &dataSize,
        &objectID
      )
    }
    guard status == noErr, objectID.isValid else {
      throw SoundstageError("Core Audio could not identify this app. Error: \(status).")
    }
    return objectID
  }
}
