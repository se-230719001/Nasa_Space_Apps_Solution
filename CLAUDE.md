# MoonMinds — working agreement for Claude

Godot 4.7 (GDScript, Mobile renderer). Kids' (7–12) lunar-outpost strategy game.
Main scene: `scenes/main.tscn`. Design reference: `design_guidline.md`.

Two people work on the **same branch (`last_ver`)**, each with their own Claude:

| Track | Owns | Never edits |
|---|---|---|
| **Audio** (SFX + music) | `scenes/audio/**`, `assets/audio/**`, `default_bus_layout.tres`, `sounds.md` | anything else |
| **Gameplay** (mechanics + gamification, UI, 3D) | everything else: `scenes/**` (except `scenes/audio/`), `ui/**`, `assets/` (except `assets/audio/`), `tools/**` | `scenes/audio/**`, `assets/audio/**`, `default_bus_layout.tres` |

**Shared files** (both may touch, carefully): `scenes/core/events.gd`, `project.godot`, this `CLAUDE.md`.
Before editing a shared file, pull first and keep the change small.

If you don't know which track the person you're working with is on, ask once at the start of the session.

## The contract: `Events` (scenes/core/events.gd)

Gameplay and audio never call each other. They talk only through the `Events` autoload:

- **Gameplay emits** what happened: `Events.build_confirmed.emit(&"greenhouse")`.
  Gameplay code must never play sounds, reference `AudioStream*`, `Music` or `Sfx`.
- **Audio listens** and decides what to play: `scenes/audio/sfx_director.gd` (autoload `Sfx`,
  event → sound in its `SOUNDS` map) and `scenes/audio/music_director.gd` (autoload `Music`).

Rules for `events.gd`:
- **Append-only.** Add a new signal at the bottom with a one-line comment. Never rename,
  remove, or change the arguments of an existing signal (the other track may depend on it).
- Signals describe facts in past tense (`task_completed`), not sound requests (`play_ding`).
- Gameplay needs a new sound hook → add the signal, emit it, and say so in the commit
  message (`events: + rover_launched`). Audio wires the sound later; until then it's silent.
- Audio needs a hook that doesn't exist → ask the gameplay side (or add the signal and leave
  a `# TODO(gameplay): emit this when …` next to it). Don't edit gameplay files to emit it.

## Git on a shared branch

- `git pull --rebase` before starting and before every push.
- **Stage only your own paths** (`git add scenes/audio assets/audio`), never `git add -A`/`.`.
  Check `git status` first: the other person's work-in-progress may be in your tree after a pull.
- Small, focused commits; push often so the other side rebases on small diffs.
- `.tscn`/`.tres` files merge badly. If a pull conflicts in a scene/theme file you don't own,
  take theirs (`git checkout --theirs <file>`) and redo your part; never hand-merge someone
  else's scene.
- Commit generated `*.import` and `*.uid` files that belong to your files.
- Never force-push.

## Running and verifying

- Godot binary differs per machine (one setup: `~/Downloads/Godot.app/Contents/MacOS/Godot`).
- Fresh clone / after a pull with new art: import once with `<godot> --headless --path . --import`
  (or open the editor). Without it textures and fonts fail to load (e.g. no title wallpaper).
- Run the game: `<godot> --path .` (leave it open for the person to try after a change).
- Headless self-check: write a throwaway `extends SceneTree` script outside the repo that loads
  `res://scenes/main.tscn`, drives it, prints pass/fail, then
  `<godot> --headless --path . --script <file>`.
- Screenshot: same kind of script without `--headless`, `--resolution 1280x720 --windowed`,
  then `root.get_texture().get_image().save_png(path)` after ~150 frames (splash fades first).
- Tests (exit 0 = pass): `<godot> --headless --path . --script res://tools/tests/test_simulation.gd`
  (sim rules), `test_hud_flow.gd` (start → 8 days → win), `test_learning_flow.gd`, `test_hud_ui.gd`, `test_stories.gd`, `test_nasa_db.gd`, `test_mission_cards.gd`, `test_base_grid.gd`, `test_rewards.gd`, `test_full_runs.gd` (all 3 campaigns end to end), `test_realtime_input.gd` (real clicks/Esc; run windowed: `--resolution 1024x576 --windowed`). Keep them green.
- New Events signals since the audio side last synced are listed in `audio_handoff.md`.
- NASA sources live in `nasa_db/` (raw untouched, processed + `manifest.csv`); rebuild with
  `python3 -I tools/nasa/build_nasa_db.py`. No file without a manifest row; never write an API key.
- Ignore the `git_plugin` dylib errors at startup; they're from a missing editor plugin binary.

## Gameplay-side conventions

- UI is **mobile-first** (BTD6-style): base resolution 1024×576, big touch targets, actions
  bottom-right, info top, mascot bottom-left. Desktop only adds hover/keyboard, never layout.
- One visual language: navy `#0B1236` 4px outline + thicker bottom lip + rounded corners on
  every button/panel/card. Styles live in `ui/theme/moonminds_theme.tres`; reuse its variations
  (`PrimaryButton`, `IconButton`, `DangerButton`, `HudPill`, `DialogCard`, `PopupCard`, …)
  instead of per-node style overrides.
- Art: `assets/generated/moonminds/` (1254px sources, mipmaps on). HUD art gets
  `ui/theme/sticker.tres` for the white sticker rim.
- Game rules live in `scenes/core/outpost_simulation.gd` (see `GAME_ARCHITECTURE.md`); the live
  state is the `Colony` autoload (`scenes/core/colony.gd`). HUD and 3D world only call `Colony`
  actions/previews and react to its signals; never hard-code resource numbers in UI.
- New buildable module: add it to `OutpostSimulation.MODULES`, a procedural `OutpostModule`
  script in `scenes/buildings/`, its lot + script in `scenes/main.gd`, and its `INFO`/`MENUS`
  entry in `ui/screens/outpost_hud.gd`.
- Mascot speaks through `%Helper.say(kind, title, text)` (`ui/components/mascot_helper.gd`).
- 3D buildings are procedural (`scenes/buildings/`, materials via `BuildingKit.mat()`).

## Audio-side conventions

- Buses: `Music`, `SFX` (`default_bus_layout.tres`).
- New sound: drop the file in `assets/audio/sfx/`, add credit/source to `assets/audio/CREDITS.md`,
  map it in `SOUNDS` in `sfx_director.gd` under the event's key.
- Music tracks: `TRACKS` in `music_director.gd`, switched by `Events.screen_changed`.
