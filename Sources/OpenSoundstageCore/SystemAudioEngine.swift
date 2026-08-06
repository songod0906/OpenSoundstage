// SPDX-License-Identifier: MIT
// The private tap lifecycle is based in part on AudioCap.
// See ThirdParty/NOTICE.md.

import AudioToolbox
import CoreAudio
import Foundation
import OpenSoundstageDSP

public final class SystemAudioEngine: @unchecked Sendable {
  public private(set) var isRunning = false
  public private(set) var outputDeviceName = "No output"
  public var outputDeviceDidChange: (() -> Void)?

  private let audioQueue = DispatchQueue(
    label: "org.opensoundstage.audio",
    qos: .userInteractive
  )
  private var tapID = AudioObjectID.unknown
  private var aggregateDeviceID = AudioObjectID.unknown
  private var ioProcID: AudioDeviceIOProcID?
  private var outputListener: AudioObjectPropertyListenerBlock?

  public init() {}

  public func start(settings: DSPSettings) throws {
    guard !isRunning else { return }

    do {
      let outputDevice = try CoreAudioDevices.defaultOutput()
      let outputUID = try outputDevice.readString(kAudioDevicePropertyDeviceUID)
      outputDeviceName = try outputDevice.readString(kAudioObjectPropertyName)
      let ownProcess = try CoreAudioDevices.processObject(for: getpid())

      let tapDescription = CATapDescription(
        excludingProcesses: [ownProcess],
        deviceUID: outputUID,
        stream: 0
      )
      tapDescription.name = "OpenSoundstage private tap"
      tapDescription.uuid = UUID()
      tapDescription.isPrivate = true
      tapDescription.isExclusive = true
      tapDescription.muteBehavior = .mutedWhenTapped

      var newTap = AudioObjectID.unknown
      var status = AudioHardwareCreateProcessTap(tapDescription, &newTap)
      guard status == noErr else {
        throw SoundstageError("Core Audio could not create the system tap. Error: \(status).")
      }
      tapID = newTap

      let format: AudioStreamBasicDescription = try tapID.read(
        kAudioTapPropertyFormat,
        defaultValue: AudioStreamBasicDescription()
      )
      guard format.mFormatID == kAudioFormatLinearPCM,
        format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
        format.mBitsPerChannel == 32,
        format.mChannelsPerFrame == 2
      else {
        throw SoundstageError("The selected output does not provide stereo 32-bit float audio.")
      }

      let aggregateDescription: [String: Any] = [
        kAudioAggregateDeviceNameKey: "OpenSoundstage Private Route",
        kAudioAggregateDeviceUIDKey: "org.opensoundstage.route.\(UUID().uuidString)",
        kAudioAggregateDeviceMainSubDeviceKey: outputUID,
        kAudioAggregateDeviceIsPrivateKey: true,
        kAudioAggregateDeviceIsStackedKey: false,
        kAudioAggregateDeviceTapAutoStartKey: true,
        kAudioAggregateDeviceSubDeviceListKey: [
          [kAudioSubDeviceUIDKey: outputUID]
        ],
        kAudioAggregateDeviceTapListKey: [
          [
            kAudioSubTapUIDKey: tapDescription.uuid.uuidString,
            kAudioSubTapDriftCompensationKey: true,
          ]
        ],
      ]

      var newAggregate = AudioObjectID.unknown
      status = AudioHardwareCreateAggregateDevice(
        aggregateDescription as CFDictionary,
        &newAggregate
      )
      guard status == noErr else {
        throw SoundstageError("Core Audio could not create the private route. Error: \(status).")
      }
      aggregateDeviceID = newAggregate

      let pipeline = DSPPipeline(sampleRate: Float(format.mSampleRate), settings: settings)
      var newIOProc: AudioDeviceIOProcID?
      status = AudioDeviceCreateIOProcIDWithBlock(
        &newIOProc,
        aggregateDeviceID,
        audioQueue
      ) { _, inputData, _, outputData, _ in
        Self.render(input: inputData, output: outputData, pipeline: pipeline)
      }
      guard status == noErr, let newIOProc else {
        throw SoundstageError("Core Audio could not create the render callback. Error: \(status).")
      }
      ioProcID = newIOProc

      status = AudioDeviceStart(aggregateDeviceID, newIOProc)
      guard status == noErr else {
        throw SoundstageError("Core Audio could not start the private route. Error: \(status).")
      }

      isRunning = true
      installOutputListener()
    } catch {
      stop()
      throw error
    }
  }

  public func stop() {
    removeOutputListener()

    if aggregateDeviceID.isValid {
      if let ioProcID {
        AudioDeviceStop(aggregateDeviceID, ioProcID)
        AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
      }
      AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
    }
    if tapID.isValid {
      AudioHardwareDestroyProcessTap(tapID)
    }

    ioProcID = nil
    aggregateDeviceID = .unknown
    tapID = .unknown
    isRunning = false
  }

  private func installOutputListener() {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      DispatchQueue.main.async {
        self?.outputDeviceDidChange?()
      }
    }
    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID.system,
      &address,
      DispatchQueue.main,
      listener
    )
    if status == noErr {
      outputListener = listener
    }
  }

  private func removeOutputListener() {
    guard let outputListener else { return }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectRemovePropertyListenerBlock(
      AudioObjectID.system,
      &address,
      DispatchQueue.main,
      outputListener
    )
    self.outputListener = nil
  }

  private static func render(
    input: UnsafePointer<AudioBufferList>,
    output: UnsafeMutablePointer<AudioBufferList>,
    pipeline: DSPPipeline
  ) {
    let inputBuffers = UnsafeMutableAudioBufferListPointer(
      UnsafeMutablePointer(mutating: input)
    )
    let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
    let bufferCount = min(inputBuffers.count, outputBuffers.count)

    for index in 0..<bufferCount {
      guard let inputData = inputBuffers[index].mData,
        let outputData = outputBuffers[index].mData
      else { continue }
      let byteCount = min(
        Int(inputBuffers[index].mDataByteSize),
        Int(outputBuffers[index].mDataByteSize)
      )
      memcpy(outputData, inputData, byteCount)
    }

    if outputBuffers.count == 1,
      outputBuffers[0].mNumberChannels == 2,
      let data = outputBuffers[0].mData
    {
      let frameCount = Int(outputBuffers[0].mDataByteSize) / (2 * MemoryLayout<Float>.size)
      pipeline.processInterleaved(
        data.assumingMemoryBound(to: Float.self),
        frameCount: frameCount
      )
    } else if outputBuffers.count >= 2,
      outputBuffers[0].mNumberChannels == 1,
      outputBuffers[1].mNumberChannels == 1,
      let left = outputBuffers[0].mData,
      let right = outputBuffers[1].mData
    {
      let leftFrames = Int(outputBuffers[0].mDataByteSize) / MemoryLayout<Float>.size
      let rightFrames = Int(outputBuffers[1].mDataByteSize) / MemoryLayout<Float>.size
      pipeline.processPlanar(
        left: left.assumingMemoryBound(to: Float.self),
        right: right.assumingMemoryBound(to: Float.self),
        frameCount: min(leftFrames, rightFrames)
      )
    }
  }

  deinit {
    stop()
  }
}
