# Release process

## Entry gate

- The change has a user problem and a success measure.
- The scope fits the current product brief.
- The issue has clear acceptance criteria.

## Engineering gate

- `Scripts/verify.sh` passes.
- The audio callback has no new allocations, locks, or logs.
- DSP changes have deterministic tests.
- EQ response uses the same coefficients as the audio pipeline.
- Known waveform samples and dBFS values pass deterministic tests.
- A stopped route shows no simulated waveform.
- Start failure destroys each partial route object.

## Product gate

- The first-run acceptance path passes.
- Settings persist after restart.
- Product health counters remain local.
- User-facing language states one clear result.
- The EQ can be flattened and restored to its preset without help.

## Audio gate

- Test 44.1 kHz and 48 kHz stereo output.
- Test built-in and Bluetooth output.
- Test start, stop, output change, sleep, wake, and quit.
- Run playback with four CPU load workers.
- Scan Core Audio logs for drops, overloads, and underruns.

## Distribution gate

- Update `CHANGELOG.md` and the bundle version.
- Use a Developer ID signature for public binaries.
- Notarize and staple the public app.
- Verify the archive checksum.
- Publish source only when the binary gate is not complete.

## Exit gate

- CI passes on the published commit.
- The repository has support and security paths.
- The release notes state known limits.
- The maintainer can reproduce the build from a clean checkout.
