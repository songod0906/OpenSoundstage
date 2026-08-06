# Changelog

All important product changes appear in this file.

The project uses [Semantic Versioning](https://semver.org/).

## 0.4.0 - 2026-08-06

### Added

- Bass, Voice, Night, and Detail task-focused sound profiles
- Calibrated 2,048-point live post-DSP spectrum behind the EQ response
- Sound profile selection from the menu bar
- Private on-device profile-selection counters in Product health
- FFT frequency and level calibration tests plus preset safety-bound tests

### Changed

- Expanded waveform monitoring from 512 to 2,048 frames for useful spectral resolution
- Made the limiter status reflect each profile's actual output ceiling
- Added a short intended-use description beside every selected profile

### Safety

- Kept every built-in EQ boost at or below 3 dB and input gain at or below 2.2 dB
- Gives Night an additional decibel of limiter headroom

## 0.3.0 - 2026-08-06

### Added

- Responsive single-window DJ mixer interface with no scrolling
- Club preset with focused low-end punch and bounded soft drive
- Direct Width, Boost, and Drive master controls
- Stereo peak and RMS meter bars beside the post-DSP waveform

### Changed

- Reflowed analysis, equalizer, and master controls for compact, medium, and wide windows
- Replaced fixed-height workstation cards with a unified adaptive mixer console
- Reduced the usable minimum window from 900×720 to 760×560

## 0.2.0 - 2026-08-06

### Added

- Ten-band equalizer from 32 Hz to 16 kHz with ±12 dB control
- Frequency response curve calculated from the audio engine coefficients
- Live post-DSP stereo waveform with a fixed full-scale axis
- Stereo peak and RMS dBFS meters
- Lock-free real-time monitoring ring
- Tests for EQ response, sample integrity, dBFS math, and preference migration

### Changed

- Replaced broad tone controls with direct frequency-band controls
- Expanded the main window into a complete audio workstation interface
- Preserved version 0.1 preferences through automatic EQ migration
- Vectorized the equalizer and bounded monitor refresh work for audio callback headroom

## 0.1.0 - 2026-08-06

### Added

- Native private Core Audio route
- Whole, Wide, and Gentle presets
- Body, presence, air, width, and controlled boost settings
- Stereo-linked compressor and limiter
- Automatic output-change and wake recovery
- Persistent product settings
- Private local product health report
- Native menu bar control
- Original application icon
