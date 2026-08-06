# Architecture

OpenSoundstage has three Swift targets and one small C target.

## OpenSoundstageDSP

This target has no user interface or Core Audio dependency. `DSPPipeline`
processes stereo 32-bit float audio. It supports interleaved and planar buffer
layouts.

The pipeline uses one state for the left channel and one state for the right
channel. The compressor and limiter use a shared stereo detector. This design
keeps the stereo image stable when one channel has a high peak.

The audio callback does not allocate memory. It does not use a lock. It does
not write a log message.

The equalizer uses ten peaking biquads with a Q of 1.1. The response graph
evaluates the transfer function from the same coefficients. Response
evaluation uses 64-bit math to avoid cancellation near DC. The audio callback
applies the cascaded filters with Apple's Accelerate framework. Stereo state
is separate, and the setup is allocated before the callback starts.

The compressor updates its nonlinear gain calculation every 16 frames and
smooths gain on every frame. Soft saturation uses a bounded rational curve.
These choices remove transcendental math from the per-frame hot path.

`SpectrumAnalyzer` runs only on copied monitor samples. It applies a
denormalized Hann window and a 2,048-point Accelerate real FFT. Its amplitude
scale is calibrated in tests with a bin-centered sine. No FFT work runs in the
audio callback.

## OpenSoundstageRealtime

This target provides a bounded stereo ring for the waveform monitor. The audio
callback writes IEEE 754 sample bits into C11 atomic slots and publishes one
write cursor. The user interface copies the latest frames at 15 Hz. The writer
does not allocate, wait, or take a lock.

## OpenSoundstageCore

`SystemAudioEngine` owns the complete route lifecycle.

1. Read the default output device.
2. Create a private process tap for that device.
3. Exclude the OpenSoundstage process from the tap.
4. Create a private aggregate route.
5. Enable drift compensation for the tap.
6. Start one Audio Device IO callback.
7. Copy and process each stereo buffer.
8. Copy post-DSP samples into the monitoring ring.
9. Stop and destroy all temporary Core Audio objects.

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

`AppModel` reads the latest 2,048 frames from the monitoring ring at 15 Hz. It
calculates stereo peak and RMS values in dBFS and the live spectrum outside the
audio callback. The waveform has a fixed ±1.0 full-scale axis. A stopped route
produces empty waveform and spectrum snapshots, not simulated motion.

## Failure behavior

Each partial start failure calls `stop()`. This action destroys an existing IO
callback, aggregate route, and process tap in reverse order. The user interface
shows the Core Audio error code.

The app does not call `killall coreaudiod`. A failed route must not require a
Core Audio daemon restart.
