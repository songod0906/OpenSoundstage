# Customer journey

The primary journey starts with a listener who dislikes the default system mix
or an unstable audio setup.

| Stage | User question | Product response | Success signal | Main risk |
| --- | --- | --- | --- | --- |
| Discover | Will this make music feel more complete? | State one clear sound promise. | User opens the project or app. | Vague audio claims. |
| Evaluate | Will this damage or complicate my setup? | Explain the private route and local processing. | User starts the app. | Fear of permanent drivers. |
| Permit | Why does the app need system audio access? | Show a precise local-processing reason. | Permission is granted. | Permission denial. |
| Activate | Can I hear a useful result now? | Start with the Whole preset and one button. | First successful start. | Silence or route failure. |
| Tune | Can I make this sound like mine? | Offer ten labeled EQ bands, a true response curve, width, gain, and three presets. | A setting changes, the curve responds, and the setting persists. | Technical controls feel unclear. |
| Verify | Is the app processing the signal I hear? | Show actual post-DSP samples on a fixed full-scale axis with peak and RMS dBFS values. | The monitor is flat when stopped and follows playback when active. | A decorative animation destroys trust. |
| Rely | Can I use it every day? | Recover from output, sleep, and wake changes. | Repeated successful sessions. | Pops, stale routes, or high CPU. |
| Recover | What do I do if sound stops? | Stop cleanly and show a useful error. | Next start succeeds. | Daemon restart becomes routine. |
| Advocate | Can I trust and recommend it? | Publish code, tests, privacy policy, and releases. | Useful issue, star, or referral. | Claims exceed evidence. |

## First-run acceptance path

1. Open the app.
2. Read the sound promise and route status.
3. Select **Start sound**.
4. Grant system audio access.
5. Hear the Whole preset.
6. Confirm that the waveform and dBFS meters follow the processed output.
7. Play music for ten minutes.
8. Stop sound.
9. Confirm that the monitor becomes flat and normal output continues.

The first run fails if the user must restart Core Audio, repair an aggregate
device, or search for a hidden helper.
