# Architecture

OpenSoundstage has three Swift targets.

## OpenSoundstageDSP

This target has no user interface or Core Audio dependency. `DSPPipeline`
processes stereo 32-bit float audio. It supports interleaved and planar buffer
layouts.

The pipeline uses one state for the left channel and one state for the right
channel. The compressor and limiter use a shared stereo detector. This design
keeps the stereo image stable when one channel has a high peak.

The audio callback does not allocate memory. It does not use a lock. It does
not write a log message.

## OpenSoundstageCore

`SystemAudioEngine` owns the complete route lifecycle.

1. Read the default output device.
2. Create a private process tap for that device.
3. Exclude the OpenSoundstage process from the tap.
4. Create a private aggregate route.
5. Enable drift compensation for the tap.
6. Start one Audio Device IO callback.
7. Copy and process each stereo buffer.
8. Stop and destroy all temporary Core Audio objects.

The app never changes the macOS default output. It does not install an Audio
Server plug-in. It does not keep a helper process active after the app quits.

`PreferencesStore` saves the selected preset and controls. `ProductMetricsStore`
saves local product health counters. Both stores use the application defaults
domain. Neither store runs in the real-time audio callback.

## OpenSoundstageApp

This target provides the SwiftUI window and menu bar control. `AppModel` owns
one audio engine. It stops the route before sleep. It restarts the route after
wake when necessary. It also restarts the route when the default output
changes.

## Failure behavior

Each partial start failure calls `stop()`. This action destroys an existing IO
callback, aggregate route, and process tap in reverse order. The user interface
shows the Core Audio error code.

The app does not call `killall coreaudiod`. A failed route must not require a
Core Audio daemon restart.
