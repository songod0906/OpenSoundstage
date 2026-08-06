# Product metrics

## North-star metric

Use **reliable enhanced listening hours** as the north-star metric. One hour
counts when sound starts, stays active, and ends without a route failure.

The current app records the time proxy on the Mac. It does not send the value.
Beta users can copy the local report when they choose to share it.

## Activation metrics

- Start success rate: successful starts divided by start attempts
- First-session completion: one successful start and one clean stop
- Setup recovery rate: a successful start after a failed start

## Engagement metrics

- Enhanced listening time
- Completed sessions
- Starts per launch
- Preset and control research notes from user interviews

The app does not record track names, applications, or listening content.

## Reliability metrics

- Route start failure rate
- Output-change recovery rate
- Clean quit rate
- Crash-free session rate
- Reported pop or dropout incidents per listening hour
- Audio callback CPU budget at 44.1 kHz and 48 kHz

## Experience measures

Ask beta users these questions after at least three sessions:

1. Did music feel wider without losing the center image?
2. Did the mix feel more complete at a matched volume?
3. Did you trust the app to clean up its route?
4. Which control was unclear or unnecessary?
5. Would you keep the app active for daily listening?

## Decision rules

- Do not add a feature to improve a vanity metric.
- Fix route reliability before adding sound effects.
- Treat a repeated daemon restart as a release blocker.
- Keep remote analytics out until users request it and the privacy design is
  reviewed.
