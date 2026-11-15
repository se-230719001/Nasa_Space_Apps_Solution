# Audio handoff (from the gameplay track)

Gameplay changed a lot since the audio side last looked. These are the facts
the audio code can listen to on `Events` (append-only, nothing renamed).

## New signals (silent until audio maps them)

| Signal | When it fires |
|---|---|
| `campaign_started(campaign)` | the player picks a training: `&"apollo"`, `&"base"`, `&"full"` |
| `mission_day_started(day)` | a new mission day begins (after the night) |
| `prediction_made(correct)` | the player answers a Mission Briefing "what would you do?" question |
| `star_earned(mission_id)` | a science star (finish / guess / "why" answer) |
| `badge_earned(badge_id)` | a concept badge, e.g. `&"plant_keeper"`, `&"never_give_up"` |
| `decor_unlocked(decor_id)` | a milestone decoration: `&"lamp"`, `&"antenna"`, `&"moon_garden"` |
| `hint_shown(level)` | only in the old resource game (off by default now) |
| `crew_rescued` | only in the old resource game (off by default now) |

## Signals that no longer fire in a normal game

- `session_started` — the session-length picker was removed (campaigns replaced it).
- `resource_changed` — the resource bars are hidden (Stage 6), so no per-night deltas.

## `button_pressed(id)` ids added

`TutorialNext`, `Choice0..n` (all cards), `Option0..2` (briefing quiz),
`WhyOption0..1` (debrief), `TurnButton`, `CancelPlace`, `PlaceButton` (base grid),
`StoryButton`, `LogButton`, `BadgesButton`, `PastSummary`, `Past1..n`,
`UseOwnName`, `NasaLink`, `InfoButton`, plus the build-menu option names
(`greenhouse`, `lander`, `lamp`, ...).

Ideas: a soft "ding" for `star_earned`, a short fanfare for `badge_earned`,
a "building" thunk for `PlaceButton`, a page-turn for `LogButton`.
