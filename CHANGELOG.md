# Changelog

All important product changes appear in this file.

The project uses [Semantic Versioning](https://semver.org/).

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
