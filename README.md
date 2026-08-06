# OpenSoundstage

OpenSoundstage makes macOS audio wider and more coherent. It uses a native
Core Audio tap and a small real-time DSP pipeline. It does not install a
permanent audio driver.

The first release has three presets:

- **Whole** adds body, presence, air, stereo width, and controlled gain.
- **Wide** increases width and air for spacious mixes.
- **Gentle** uses lighter processing for long listening sessions.

OpenSoundstage is a clean-room project. It is not affiliated with Boom 3D or
Global Delight. It does not contain Boom code, presets, calibration data, or
other proprietary assets.

## Requirements

- macOS 14.4 or later
- Apple silicon or Intel Mac
- Xcode 15.3 or later

## Build the app

Run these commands from the repository root:

```sh
swift test
Scripts/build-app.sh
open dist/OpenSoundstage.app
```

The build script creates an ad hoc signed app. For distribution, use an Apple
Developer ID certificate and notarize the app.

## Use the app

1. Quit Boom and other system audio enhancers.
2. Open `dist/OpenSoundstage.app`.
3. Select a preset.
4. Adjust the controls if necessary.
5. Select **Start sound**.
6. Allow system audio access if macOS asks for it.
7. Select **Stop sound** before you use another audio enhancer.

OpenSoundstage follows the current default output. It stops before sleep. It
starts again after wake if it was active before sleep.

## How it works

The app creates a private Core Audio process tap. The tap excludes the app
itself and mutes the original stream while it is active. A private aggregate
route connects the tap to the current output device. Drift compensation is
enabled for the tap. The app destroys the route and the tap when you stop
sound or quit the app.

The DSP pipeline applies these stages:

1. High-pass protection
2. Body, presence, and air filters
3. Mid-side stereo width
4. Stereo-linked compression
5. Soft saturation
6. Stereo-linked output limiting at -1 dBFS

See [ARCHITECTURE.md](ARCHITECTURE.md) for more information.

## Safety notes

- Start with a low hardware volume.
- Do not use two system audio enhancers at the same time.
- Wider processing cannot add width to a mono signal.
- The limiter reduces digital clipping risk. It cannot protect your hearing.
- Bluetooth headset mode can reduce quality when the headset microphone is in
  use. Select the Mac microphone for calls when possible.

## Test status

The first release has unit tests for silence, mono compatibility, stereo width,
and the limiter ceiling. It also passed a local playback test on macOS 26.5.1
with a Bluetooth output and four CPU load workers.

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you send a change. Report a
security problem as described in [SECURITY.md](SECURITY.md).

## License

OpenSoundstage uses the MIT License. See [LICENSE](LICENSE) and
[ThirdParty/NOTICE.md](ThirdParty/NOTICE.md).
