# Version 0.4 product research

## Question

Which additions make a system-wide equalizer more useful without weakening
route reliability or turning OpenSoundstage into a general audio laboratory?

## Public evidence

- EasyEffects 8.0 puts frequently used presets in its tray, supports preset
  autoload and backup, includes a spectrum, and adds shortcut support. This is
  evidence that access and feedback matter alongside the DSP itself.
  <https://github.com/wwmm/easyeffects/blob/master/src/contents/docs/community/CHANGELOG.md>
- eqMac users requested hotkey preset switching for common music and voice
  modes. <https://github.com/bitgapp/eqMac/issues/338>
- eqMac's expert EQ request combines a spectrum, response curve, and presets in
  one workflow. <https://github.com/bitgapp/eqMac/issues/252>
- Users want per-device profiles because speakers and headphones need different
  settings. <https://github.com/bitgapp/eqMac/issues/231>
- Public reports also show broken device auto-switching and short, dangerous
  level spikes. <https://github.com/bitgapp/eqMac/issues/924>
- An eqMac report specifically warns that large preset boosts can clip and
  overload playback. <https://github.com/bitgapp/eqMac/issues/873>
- Users expect presets to be portable through import and export.
  <https://github.com/bitgapp/eqMac/issues/889>

## Version 0.4 decision

| Need | Decision | Reason |
| --- | --- | --- |
| Common listening profiles | Ship | High value, small route risk |
| Live spectrum | Ship | Makes the processed signal inspectable |
| Fast background access | Ship through the menu bar | No new system permission |
| Preset usage evidence | Ship as local-only counters | Measures value without analytics |
| Device-specific recall | Defer | Needs a multi-device safety test matrix |
| Custom import/export | Defer | Needs a durable public preset schema |
| Global shortcuts | Defer | Avoid Accessibility permission for one release |

## Profile design rules

Profiles describe listening jobs rather than music genres. Every EQ boost is at
most 3 dB, every profile ends in the stereo-linked limiter, and Night uses a
-2 dBFS ceiling. Bass avoids the extreme +11 dB style of boost called out in
public clipping reports.

## Success signals

- Profile selection counts show whether the four new jobs receive repeat use.
- Start success does not regress from the prior release.
- FFT tests identify both a tone's bin and its dBFS level.
- Manual playback shows the spectrum moving only from real post-DSP samples.
- Compact and wide layouts remain scroll-free.
