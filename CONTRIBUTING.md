# Contributing

Thank you for helping OpenSoundstage.

## Prepare a change

1. Create a focused branch.
2. Keep the DSP callback free of allocations and locks.
3. Add a test for each DSP behavior change.
4. Run `swift test`.
5. Run `Scripts/build-app.sh`.
6. Test start, playback, output change, sleep, wake, stop, and quit.
7. Describe the user-visible result in the pull request.

Use short sentences. Use active voice. Use one term for one item. Do not claim
ASD-STE100 certification. The project only applies selected plain-language
principles from that specification.

## Original work

Submit original work or code that has a compatible open-source license. Add a
notice for third-party code. Do not submit private code, private data, or
proprietary assets.

## Commit rule

Keep each commit easy to review. Do not include build output. Do not include
personal signing identities or Apple credentials.
