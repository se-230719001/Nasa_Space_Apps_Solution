# MOONMINDS PROJECT REPORT
**Comprehensive UI Integration & Asset Pipeline Audit**
*Generated: 2026-11-14 | For: External Visual Designer (ChatGPT)*

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Project Technology Stack](#2-project-technology-stack)
3. [Verified Project Architecture](#3-verified-project-architecture)
4. [Existing UI System](#4-existing-ui-system)
5. [Gameplay and UI Dependencies](#5-gameplay-and-ui-dependencies)
6. [Asset Pipeline Compatibility](#6-asset-pipeline-compatibility)
7. [Design System Compatibility](#7-design-system-compatibility)
8. [Screen Inventory](#8-screen-inventory)
9. [Complete UI Asset Requirements](#9-complete-ui-asset-requirements)
10. [Recommended Project Folder Structure](#10-recommended-project-folder-structure)
11. [ChatGPT ↔ Claude Code Collaboration Workflow](#11-chatgpt--claude-code-collaboration-workflow)
12. [Reusable Claude Code Integration Prompt](#12-reusable-claude-code-integration-prompt)
13. [Risks and Limitations](#13-risks-and-limitations)
14. [Prioritized Implementation Roadmap](#14-prioritized-implementation-roadmap)
15. [Open Questions and Unverified Assumptions](#15-open-questions-and-unverified-assumptions)
16. [Instructions for ChatGPT — MoonMinds Visual Designer](#16-instructions-for-chatgpt--moonminds-visual-designer)

---

## 1. Executive Summary

MoonMinds is a **turn-based, child-friendly (ages 7–12) 3D lunar colony management game** built in **Godot 4.7.2** targeting **iOS iPad** as primary platform. The player manages five life-critical resources (Health, Food, Water, Energy, Oxygen) within a 3D procedurally built outpost, constructing and upgrading seven building types across four levels each, conducting research, and launching space missions.

**Key findings:**

- The game has **1 active scene** (`main.tscn`) with a **single HUD scene** (`outpost_hud.tscn`) that encompasses all UI — splash, tutorial, resource bar, build menus, research, hangar, day-end reports, and mascot guidance.
- The UI is a **hybrid system**: image-based sprites for buttons, panels, mascots, building thumbnails, and icons; code-drawn UI (GDScript) for the resource bar rings, overlays, and dynamic cards.
- A **complete artwork asset pack** already exists at `assets/source/moonminds_godot_asset_pack/` (source) and `assets/sprites/` (imported into Godot), covering buttons, panels, icons, mascots, building thumbnails, and backgrounds. These are PNG crops from a sprite atlas.
- The **design system is almost fully aligned** with the target MoonMinds style guide: Fredoka + Poppins fonts, correct color palette (`#4F6BFF` primary, `#FFB020` action, `#FF4961` danger, `#3CDB56` success), 8px grid, 20px card radius, 16px button radius — all implemented in `moonminds_theme.tres`.
- **3 scene files** (1 main, 1 HUD, 1 reusable widget), **15 distinct UI states** all managed within the single HUD.
- **Approximately 30 additional visual assets** are recommended to complete the visual system, prioritised around missing building art (Hangar), missing resource icons (health, oxygen, rocket), and destination/craft illustrations for the Explore screen.
- **Most critical integration constraint**: Godot uses `StyleBoxTexture` with nine-patch (texture margin) configuration for scalable image panels. New panel sprites must have clean transparent regions at their patch borders, with explicit margin values, to scale correctly without visual artifacts.

---

## 2. Project Technology Stack

| Component | Value | Evidence |
|---|---|---|
| Game Engine | **Godot 4.7.2 stable** | `project.godot` `config_version=5`; MCP API |
| Engine Feature Set | Mobile | `config/features=PackedStringArray("4.7", "Mobile")` |
| Primary Language | **GDScript** | All `.gd` files; no C# or C++ |
| Rendering Method | **Mobile renderer** | `renderer/rendering_method="mobile"` |
| Physics Engine | **Jolt Physics** | `3d/physics_engine="Jolt Physics"` |
| Scene Count | **3 scenes** | `main.tscn`, `outpost_hud.tscn`, `resource_bar.tscn` |
| Script Count | **21 scripts** | MCP project info |
| Asset Count | **109 assets** | MCP project info |
| Target Platform | **iOS (iPad)** | `export_presets.cfg` — only iOS preset defined |
| Bundle ID | `com.moonminds.game` | `export_presets.cfg` |
| Version | `0.1.0` | `export_presets.cfg` |
| Display Mode | Fullscreen (mode=3) | `window/size/mode=3` |
| Base Resolution | **1280×720** | `window/size/viewport_width=1280, viewport_height=720` |
| Stretch Mode | `canvas_items` / `expand` | `window/stretch/mode="canvas_items"` |
| Orientation | Landscape (4 = horizontal) | `window/handheld/orientation=4` |
| UI Theme | `res://ui/theme/moonminds_theme.tres` | `project.godot [gui]` |
| Autoload (Global) | `Music` → `scenes/audio/music_director.gd` | `project.godot [autoload]` |
| VCS Plugin | godot-git-plugin | `addons/godot-git-plugin/` |
| Texture Compression | ETC2/ASTC enabled | `textures/vram_compression/import_etc2_astc=true` |
| MSAA | 2× desktop, 1× iOS | rendering settings |
| Build Target (iOS) | arm64 only | export preset |
| Fonts | Fredoka Variable TTF, Poppins Regular/Medium/SemiBold/Bold | `assets/fonts/` |
| Audio | OGG Vorbis + MP3 + WAV | `assets/audio/` |

**How the game works technically:**
The game has one scene (`main.tscn`) that creates a 3D world. A `ColonySim` (pure GDScript class, no Node) runs entirely in memory as the game model. `main.gd` owns the sim and the 3D world; it passes the sim reference to the HUD (`outpost_hud.gd`). The HUD emits signals back to `main.gd` which acts on them — a clean signal-based MVC pattern. The UI runs on a `CanvasLayer` node above the 3D world; Godot's `canvas_items` stretch mode scales everything uniformly to fit the physical screen. There are no separate game modes or scene transitions — all UI states are shown/hidden inside the single HUD scene.

---

## 3. Verified Project Architecture

```
moon-minds/
│
├── project.godot               # Entry point; main_scene=scenes/main.tscn
├── icon.svg                    # App icon
├── export_presets.cfg          # iOS export only
├── default_bus_layout.tres     # Audio bus config (Music + SFX buses)
├── design_guidline.md          # Full MoonMinds UI style guide (21 sections, 780 lines)
├── docs/
│   └── game_systems_design.md  # Turkish-language game mechanics reference
│
├── scenes/                     # GAMEPLAY — 3D world + simulation
│   ├── main.tscn               # Root scene: 3D world + UI CanvasLayer
│   ├── main.gd                 # Scene root; owns ColonySim; wires all signals
│   ├── sim/
│   │   └── colony_sim.gd       # ~900-line pure GDScript game model (no Node)
│   ├── buildings/              # Procedural 3D building scripts (@tool)
│   │   ├── building_kit.gd     # Primitive mesh factory (box, sphere, cylinder, dome…)
│   │   ├── module_base.gd      # Abstract base for all building scripts
│   │   ├── greenhouse.gd       # Lv1–4 glass dome geometry
│   │   ├── habitat_base.gd     # Life Support module
│   │   ├── solar_array.gd      # Energy Center panels
│   │   ├── water_tank.gd       # Water Recycling module
│   │   ├── research_lab.gd     # Radiation Lab
│   │   ├── shelter.gd          # Health Center
│   │   └── hangar.gd           # Launch Hangar
│   ├── environment/            # 3D world environment
│   │   ├── colony_dome.gd      # Expanding glass dome (O2 color + CO2 haze)
│   │   ├── rock_field.gd       # Procedural rock scatter
│   │   └── *.gdshader          # Custom shaders: sky, ground, earth, dome, rocks, grid
│   ├── camera/
│   │   └── touch_camera.gd     # Drag / pan / pinch-zoom camera
│   ├── world/
│   │   └── build_grid.gd       # Grid placement system
│   └── audio/
│       └── music_director.gd   # Autoload: crossfade + stingers
│
├── ui/                         # UI LAYER
│   ├── screens/
│   │   ├── outpost_hud.tscn    # The single HUD scene (all UI states inside)
│   │   └── outpost_hud.gd      # ~780-line HUD controller
│   ├── components/
│   │   ├── resource_bar.tscn   # Reusable HBoxContainer: icon + label + ProgressBar
│   │   ├── resource_bar.gd     # ResourceBar class with Status enum
│   │   └── sprite_button.gd    # SpriteButton class (TextureButton + hover/press/focus)
│   └── theme/
│       ├── moonminds_theme.tres         # Code-drawn theme (fonts, colors, StyleBoxFlat)
│       └── moonminds_sprite_theme.tres  # Sprite panel theme (StyleBoxTexture nine-patch)
│
├── assets/                     # VISUAL ASSETS
│   ├── fonts/                  # Fredoka-Variable.ttf, Poppins-*.ttf + OFL licenses
│   ├── sprites/                # ← ALL IN-GAME PNGS (auto-imported by Godot)
│   │   ├── backgrounds/        # lunar_header.png (996×178)
│   │   ├── brand/              # logo.png (403×141)
│   │   ├── buildings/          # greenhouse, habitat, main_base, research_lab, solar_panel, water_system
│   │   ├── buttons/            # build, cancel, explore, mission, ok, research + disabled/focus
│   │   ├── chips/              # critical, healthy, warning
│   │   ├── icons/              # 19 icons (PNG + 3 SVG)
│   │   ├── mascots/            # celebrate, think, wave
│   │   ├── panels/             # bubble_white, bubble_yellow, checklist, panel_layers,
│   │   │                       #   panel_plain, panel_star, popup_close, toast_success
│   │   └── textures/           # earth_blue_marble_2048.jpg (3D texture)
│   ├── audio/
│   │   ├── music/              # intro_music_box.ogg, outpost_theme.ogg, explore_theme.mp3
│   │   └── sfx/                # mission_complete.wav
│   └── source/                 # ← SOURCE REFERENCE (.gdignore — excluded from build)
│       └── moonminds_godot_asset_pack/
│           ├── asset_manifest.json    # Exact pixel coords of all atlas crops
│           ├── atlas/                 # moonminds_full_sprite_atlas.png (master sheet)
│           ├── backgrounds/, panels/, buttons/, mascots/, icons/, buildings/, hud/, layout/
│
├── tools/                      # Editor-only scripts (excluded in export_presets)
│   ├── extract_ui_sprites.gd
│   └── test_colony_sim.gd
│
└── intro_assets/               # Reference images + intro MP4 videos (not built into game)
    └── moonminds_ui_style_guide.png
```

**Directory responsibilities:**

| Directory | Responsibility |
|---|---|
| `scenes/sim/` | Gameplay logic — pure GDScript, no Node |
| `scenes/buildings/` | Procedural 3D building mesh generation |
| `scenes/environment/` | Shader-based 3D world (sky, ground, dome, rocks) |
| `ui/screens/` | All UI scene definitions and controllers |
| `ui/components/` | Reusable UI widgets |
| `ui/theme/` | Godot Theme resources (design tokens) |
| `assets/sprites/` | Production PNG/SVG assets consumed by the game |
| `assets/source/` | Source artwork and atlas (excluded from build) |
| `assets/fonts/` | Fredoka + Poppins TTF files |

---

## 4. Existing UI System

### 4.1 Architecture Overview

The game uses a **hybrid UI approach**:

- **Image-based**: Buttons (`TextureButton` + `SpriteButton.gd`), panel borders (`StyleBoxTexture` with nine-patch), mascot displays (`TextureRect`), building thumbnails (`TextureRect`), icons (`TextureRect`)
- **Code-drawn**: The custom ring/donut progress indicators in the resource bar (procedural `ImageTexture` drawn pixel-by-pixel in GDScript), the overlay layout (dynamic `VBoxContainer`/`HBoxContainer` instances built at runtime), progress bars (Godot `ProgressBar` with styled `StyleBoxFlat`)

The HUD scene has **no nested sub-scenes other than `resource_bar.tscn`** — all popups, overlays, and panels are either pre-placed nodes or dynamically constructed nodes via `add_child()` in GDScript.

### 4.2 Theme System (Verified)

**File: `ui/theme/moonminds_theme.tres`** — The primary code-drawn theme applied project-wide via `project.godot`.

Defined custom type variations (all verified by reading the file):

| Variation Name | Base Type | Key Styling |
|---|---|---|
| `H1` | Label | Fredoka Bold 36px, white, outline 8 |
| `H2` | Label | Fredoka Bold 24px, white, outline 6 |
| `H3` | Label | Fredoka SemiBold 18px, white |
| `HudLabel` | Label | Poppins SemiBold 14px, white |
| `Caption` | Label | Poppins Regular 14px, muted blue-white |
| `DarkTitle` | Label | Fredoka Bold 20px, dark navy |
| `DarkBody` | Label | Poppins Medium 15px, dark navy |
| `DarkCaption` | Label | Poppins SemiBold 13px, dark navy |
| `ChipLabel` | Label | Poppins SemiBold 14px, white |
| `DayNumber` | Label | Fredoka Bold 36px, white, outline 6 |
| `PrimaryButton` | Button | Orange (#FFB020 normal), 16px radius |
| `Button` (base) | Button | Blue (#4F6BFF), Fredoka Bold 22px, 16px radius, bottom-edge border |
| `DangerButton` | Button | Red (#FF4961), Fredoka Bold, 16px radius |
| `IconButton` | Button | Purple-blue, compact 10px padding |
| `CloseButton` | Button | Red circle, 24px radius |
| `PanelContainer` (base) | PanelContainer | Dark navy `#1A1F42`, border `#3F4BAB`, radius 20px, shadow |
| `HudPanel` | PanelContainer | Semi-transparent navy 0.92 alpha, radius 20px |
| `CardPanel` | PanelContainer | Mid-navy `#282F6B`, radius 20px |
| `TagPanel` | PanelContainer | Near-white `rgba(255,255,255,0.95)`, radius 12px |
| `ChipHealthy` | PanelContainer | Green `#3CDB56` filled, radius 16px |
| `ChipWarning` | PanelContainer | Yellow `#F7C948`, radius 16px |
| `ChipCritical` | PanelContainer | Red `#FF4961`, radius 16px |
| `InfoBubble` | PanelContainer | Near-white with cyan border `#00C6FF` |
| `WarningBubble` | PanelContainer | Warm white `#FFF4D1` with yellow border |
| `SuccessBubble` | PanelContainer | Light green with green border |
| `BarHealthy` | ProgressBar | Green fill `#3CDB56`, dark bg, radius 8px, white highlight border |
| `BarWarning` | ProgressBar | Yellow fill `#F7C948` |
| `BarCritical` | ProgressBar | Red fill `#FF4961` |
| `BarWater` | ProgressBar | Cyan fill `#00C6FF` |

**File: `ui/theme/moonminds_sprite_theme.tres`** — Sprite-based nine-patch panel theme.

| Variation Name | Texture | Nine-patch content margins |
|---|---|---|
| `BubbleWhite` | `panels/bubble_white.png` (145×79) | L:44 T:20 R:22 B:28 |
| `BubbleYellow` | `panels/bubble_yellow.png` (154×80) | L:22 T:22 R:22 B:22 |
| `PopupCard` | `panels/popup_close.png` (229×149) | L:26 T:50 R:52 B:24 |
| `SpritePanel` | `panels/panel_plain.png` (392×146) | L:28 T:28 R:28 B:28 |
| `StarPanel` | `panels/panel_star.png` (368×156) | L:60 T:50 R:26 B:22 |

### 4.3 Major UI Components (Detailed)

#### OutpostHUD (Top-Level Controller)
- **Files**: `ui/screens/outpost_hud.tscn` + `ui/screens/outpost_hud.gd`
- **Purpose**: Single HUD controller; manages all UI states
- **Dependencies**: `ColonySim`, `moonminds_sprite_theme.tres`, all sprite assets, `Music` autoload
- **Visual technique**: Hybrid — sprite buttons + code-drawn overlays + Godot themed controls
- **Interaction**: Signals emitted upstream to `main.gd`; `mouse` + `touch` input handled
- **Styling**: `moonminds_sprite_theme.tres` applied as scene theme; individual nodes set `theme_type_variation`
- **Replaceability**: Buttons, panels, mascot textures fully replaceable; overlay structure is runtime-generated in code
- **Integration note**: Overlay panels are dynamically instantiated — their style comes from theme type variations only

#### Resource Bar (Ring Indicators — expanded/collapsed)
- **Location**: `outpost_hud.gd` → `_make_resource_row()`, `_make_ring_texture()`
- **Purpose**: Top-center HUD showing Health / Food / Water / Energy / Oxygen as coloured rings
- **Visual technique**: **100% code-drawn** — `TextureProgressBar` using a procedurally generated 58×58px donut `ImageTexture` as both `texture_under` and `texture_progress`; `tint_progress` changes to green/yellow/red at runtime
- **Interaction**: Tap to expand/collapse all 5 rows; per-resource `?` button opens detail overlay
- **Replaceability**: The ring texture IS replaceable with an external PNG (pure white donut shape, ~116×116px for retina). Runtime colour tinting still applies, so the texture must be white/grey.
- **Integration challenge**: Ring must remain white/greyscale artwork to accept runtime colour

#### ResourceBar Widget (reusable component)
- **Files**: `ui/components/resource_bar.tscn` + `ui/components/resource_bar.gd`
- **Purpose**: Self-contained `HBoxContainer`: icon (`TextureRect`) + name (`Label`) + `ProgressBar`; exported properties allow configuration in the Inspector
- **Class**: `ResourceBar` with `Status { HEALTHY, WARNING, CRITICAL }` enum
- **Animation**: `animate_to(value, status)` tweens the bar with TRANS_CUBIC
- **Note**: Component exists and is complete but is **not yet wired into `outpost_hud.tscn`** — the HUD builds its own ring-based indicator instead

#### SpriteButton
- **File**: `ui/components/sprite_button.gd`
- **Purpose**: `TextureButton` subclass adding: hover brightening, press squash (scale), disabled grey, focus ring (gold `StyleBoxFlat`)
- **States**: Normal (`texture_normal`), disabled (manual `self_modulate = Color(0.55, 0.55, 0.65, 0.8)`), hover (`1.12` brightness), press (scale tween to `0.94`), focus (gold ring drawn in `_draw()`)
- **Touch devices**: Hover and focus ring are disabled on mobile (`_touch_only`)
- **Replaceability**: Drop in a new PNG for `texture_normal`; all state behaviour is code-applied

#### GoalPanel
- **Node**: `OutpostHUD/GoalPanel` — `PanelContainer` (`StarPanel` variation)
- **Purpose**: Top-left mission objective panel; shows current goal title, description, good/bad outcome hints
- **Visual**: Nine-patch `panel_star.png` (has a star motif in one corner); labels: H2 header, H3 title, Caption text
- **Replaceability**: Replace `panel_star.png`

#### MascotArea / Speech Bubble
- **Node**: `OutpostHUD/MascotArea` — `VBoxContainer` anchored bottom-left
- **Sub-nodes**: Bubble (`BubbleWhite` / `BubbleYellow` nine-patch), Mascot (84×84 `TextureRect`), HintButton (standard `Button`)
- **Mascot swaps**: `wave.png` (info), `think.png` (warning), `celebrate.png` (success)
- **Replaceability**: Replace bubble PNGs and mascot PNGs independently

#### Bottom Navigation (Primary Buttons)
- **Nodes**: `BuildButton`, `ResearchButton`, `ExploreButton` — `TextureButton` + `SpriteButton.gd`
- **Sizes**: `custom_minimum_size = Vector2(158, 58)`; artwork: 164×56, 163×58, 168×58
- **EndDayButton**: Standard `Button` with `PrimaryButton` theme variation; text is dynamic ("END DAY")
- **Replaceability**: Drop new PNG per button

#### PopupDock / BuildPopup
- **Node**: `OutpostHUD/PopupDock/BuildPopup/Card` — `PanelContainer` (`PopupCard` variation)
- **Purpose**: Side-docked confirmation card for build/upgrade: illustration, effects rows, Cancel/Confirm buttons
- **Visual**: `popup_close.png` nine-patch; illustration via `TextureRect`; buttons via `SpriteButton`
- **Replaceability**: Replace `popup_close.png`

#### Overlay System (Modal)
- **Node**: `OutpostHUD/Overlay` — `ColorRect` (dark navy, 0.6 alpha) over full screen
- **Sub-node**: `OverlayCard` — `PanelContainer` (default PanelContainer theme)
- **Content nodes**: `OverlayTitle` (H2 label), `OverlayBody` (VBoxContainer, runtime-populated), `OverlayButtons` (HBoxContainer, runtime-populated)
- **Purpose**: Shared modal for 10 different content types: tutorial, build menu, resource info, research, hangar, day report, problem detail, building detail, mission report, hint
- **Replaceability**: Overlay card panel can get a new nine-patch texture; all content is code-built

#### Splash / Logo
- **Node**: `OutpostHUD/Splash` — `ColorRect` (0.85 alpha, dark); fades in 1.4s on `_ready()`
- **Sub-node**: Logo 600×210 `TextureRect` showing `brand/logo.png`
- **Replaceability**: Replace `logo.png`

#### StormChip
- **Node**: `OutpostHUD/TopCenter/StormChip` — `PanelContainer` switching between `WarningBubble` / `InfoBubble`
- **Purpose**: Always-visible upcoming-problem warning at top-centre
- **Label**: Dynamic text set by `refresh()` — not baked into image

### 4.4 Reusable UI Primitives

| Primitive | Location | Use |
|---|---|---|
| `SpriteButton` | `ui/components/sprite_button.gd` | All image-based buttons; drop-in replaceable |
| `ResourceBar` | `ui/components/resource_bar.tscn` | Complete icon+bar+label widget |
| `_label()` | `outpost_hud.gd:738` | Factory for themed labels in overlays |
| `_add_row()` | `outpost_hud.gd:705` | Factory for icon+text rows |
| `_add_button()` | `outpost_hud.gd:727` | Factory for overlay action buttons |
| `_open_overlay()` | `outpost_hud.gd:679` | Opens the shared overlay card |
| `_add_list()` | `outpost_hud.gd:721` | Adds headed icon+text list in overlay |

---

## 5. Gameplay and UI Dependencies

### 5.1 Verified Game Mechanics (all in `scenes/sim/colony_sim.gd`)

#### Five Core Resources
| Resource | State variable | Display formula | Status colours |
|---|---|---|---|
| Health | `health` (float) | `health` directly (0–100) | Green ≥ 35%, Yellow ≥ 15%, Red otherwise |
| Food | `stock.food` | `stock.food / 150.0 * 100` | Same thresholds |
| Water | `stock.water` | `stock.water / 200.0 * 100` | Same |
| Energy | `stock.energy` | `stock.energy / battery_capacity() * 100` | Same |
| Oxygen | `stock.oxygen` | `stock.oxygen / 100.0 * 100` | Same |

Status colours in code: `STATUS_COLORS := [Color("#3CDB56"), Color("#F7C948"), Color("#FF4961")]`

#### Seven Buildings (4 levels each)
| ID | Name | Art key | 3D script | UI thumbnail |
|---|---|---|---|---|
| `life_support` | Life Support Center | `main_base` | `habitat_base.gd` | `buildings/main_base.png` 512×263 |
| `greenhouse` | Greenhouse | `greenhouse` | `greenhouse.gd` | `buildings/greenhouse.png` 397×278 |
| `energy_center` | Energy Center | `solar_panel` | `solar_array.gd` | `buildings/solar_panel.png` 199×169 |
| `water_recycling` | Water Recycling Center | `water_system` | `water_tank.gd` | `buildings/water_system.png` 186×208 |
| `health_center` | Health Center | `habitat` | `shelter.gd` | `buildings/habitat.png` 220×185 |
| `radiation_lab` | Radiation Lab | `research_lab` | `research_lab.gd` | `buildings/research_lab.png` 222×236 |
| `hangar` | Hangar | `hangar` | `hangar.gd` | **`icons/rocket.svg` (fallback — no thumbnail)** |

#### Energy Priority System
`ENERGY_PRIORITY`: Life Support > Water Recycling > Greenhouse > Health Center > Radiation Lab > Hangar. Same-priority buildings share proportionally.

#### Seven Cycling Problems (every 5 days)
Dust storm, Greenhouse pests, Solar storm, New crew member, Water pipe leak, CO₂ filter breakdown, Long lunar night — each announced in advance via `StormChip`.

#### Eight Research Cards
Found on missions; studied using science points. `CARDS` dict in `colony_sim.gd`. UI: Research overlay.

#### Fourteen Sequential Goals
Shown in `GoalPanel`. Checked in `_check_goal()`. Each rewards materials.

#### Spacecraft & Destinations
3 craft types (rover, shuttle, deep-space), 5 destinations (Shackleton, Tycho, Jezero, Europa, Psyche).

### 5.2 State Flow: Player → HUD → Sim → 3D World

```
Player taps BUILD
→ outpost_hud.gd: show_build_menu()   [opens overlay with building grid]
→ Player taps a building card
→ outpost_hud.gd: _on_building_card(id) → emits place_requested
→ main.gd: _grid.show_free_cells()   [green cells appear in 3D world]
→ Player taps a grid cell
→ main.gd: _on_cell_tapped(cell) → _hud.confirm_placement(cell)
→ outpost_hud.gd: _open_build_popup(id, cell)  [side popup appears]
→ Player taps CONFIRM
→ outpost_hud.gd: emits build_confirmed
→ main.gd: _on_build_confirmed(id, cell)
→ sim.start_build(id)   [deducts materials, increments level]
→ _on_built(id, level, cell)   [spawns 3D node with tween]
→ _hud.refresh()   [updates all ring values and labels]
```

### 5.3 HUD Signal Contract (must not be broken by UI changes)

| Signal | From | To | When |
|---|---|---|---|
| `place_requested(id)` | HUD | main.gd | Player selects a new building to place |
| `place_cancelled` | HUD | main.gd | Player cancels placement |
| `build_confirmed(id, cell)` | HUD | main.gd | Player confirms build/upgrade |
| `research_requested(card_id)` | HUD | main.gd | Player clicks RESEARCH on a card |
| `craft_requested(type)` | HUD | main.gd | Player orders a spacecraft |
| `launch_requested(dest_id)` | HUD | main.gd | Player launches a mission |
| `toggle_requested(setting)` | HUD | main.gd | Player toggles exercise/sleep/CO₂ filter |
| `end_day_requested` | HUD | main.gd | Player presses END DAY |

---

## 6. Asset Pipeline Compatibility

### 6.1 Format Support

| Format | Support | Evidence | Notes |
|---|---|---|---|
| **PNG with alpha** | ✅ Native | All sprites in `assets/sprites/` are RGBA PNG | Imported as ETC2/ASTC `.ctex`; transparency preserved |
| **SVG** | ✅ Supported | `health.svg`, `oxygen.svg`, `rocket.svg` imported | Rasterised at import; not truly vector-scalable at runtime |
| **WebP** | ⚠️ Supported | Godot 4 accepts WebP | No existing examples; PNG preferred |
| **JPG** | ✅ (no alpha) | `earth_blue_marble_2048.jpg` imported | For 3D textures/backgrounds only |
| **Nine-patch** | ✅ Full | `moonminds_sprite_theme.tres` uses `StyleBoxTexture` with texture margins | Margins set in theme; not in the texture itself |
| **Sprite atlas / region** | ✅ Supported | Atlas in `assets/source/`; project uses individual crops at runtime | |
| **Animated sprites** | ✅ via AnimatedSprite2D | Not currently used for UI | Could add sprite animation for mascot |
| **Fonts (TTF)** | ✅ Full | Fredoka Variable + all Poppins weights |  |
| **Resolution scaling** | ✅ canvas_items | Game scales all UI uniformly | Base 1280×720, expand mode |
| **iOS Retina** | ✅ | ETC2/ASTC compression; `scaling_3d/scale.ios=0.8` | UI canvas not separately Retina-scaled; deliver at 2× |
| **Runtime colour tinting** | ✅ | `self_modulate`, `tint_progress` | Sprites must be white/grey to receive colour |

### 6.2 Nine-Patch Technical Requirements

`StyleBoxTexture` in Godot defines margins (texture regions) that stay fixed while the centre stretches. Current registered margins:

```
bubble_white.png  (145×79)   → content L:44 T:20 R:22 B:28  |  texture L:44 T:20 R:22 B:28
bubble_yellow.png (154×80)   → all margins 22
popup_close.png   (229×149)  → content L:26 T:50 R:52 B:24  |  texture L:26 T:50 R:52 B:24
panel_plain.png   (392×146)  → all margins 28
panel_star.png    (368×156)  → content L:60 T:50 R:26 B:22
```

**Rule for new nine-patch sprites**: The corner regions must be at least as large as the margin values. The centre strip must be a 1-pixel-wide tileable region (or at least a gradient that stretches acceptably).

### 6.3 Asset Import Settings for New PNG Files

When placing a new PNG in `assets/sprites/`:
1. Godot auto-detects and generates a `.import` file on next editor scan
2. For UI sprites: **Compress → Mode = Lossless** (pixel-perfect) or VRAM Compressed for large images
3. **Detect 3D** should be OFF
4. Nine-patch margins are set on the `StyleBoxTexture` resource, not on the texture itself

### 6.4 Current Sprite Dimensions (Verified)

| Asset | Dimensions |
|---|---|
| `backgrounds/lunar_header.png` | 996×178 |
| `brand/logo.png` | 403×141 |
| `buildings/greenhouse.png` | 397×278 |
| `buildings/habitat.png` | 220×185 |
| `buildings/main_base.png` | 512×263 |
| `buildings/research_lab.png` | 222×236 |
| `buildings/solar_panel.png` | 199×169 |
| `buildings/water_system.png` | 186×208 |
| `buttons/build.png` | 164×56 |
| `buttons/build_disabled.png` | 121×53 |
| `buttons/build_focus.png` | 130×84 |
| `buttons/cancel.png` | 161×57 |
| `buttons/cancel_focus.png` | 126×69 |
| `buttons/explore.png` | 168×58 |
| `buttons/explore_focus.png` | 132×69 |
| `buttons/mission.png` | 164×58 |
| `buttons/ok.png` | 161×58 |
| `buttons/research.png` | 163×58 |
| `chips/critical.png` | 158×51 |
| `chips/healthy.png` | 161×52 |
| `chips/warning.png` | 158×52 |
| `icons/food.png` | 128×128 |
| `icons/power.png` | 95×128 |
| `icons/water.png` | 87×128 |
| `icons/shield.png` | 116×128 |
| `icons/calendar.png` | 49×50 |
| `icons/info.png` | 53×53 |
| `icons/home.png` | 53×52 |
| `icons/settings.png` | 52×55 |
| `icons/warning.png` | 40×40 |
| `icons/check.png` | 30×32 |
| `icons/close.png` | 43×40 |
| `icons/critical.png` | 43×40 |
| `icons/add.png` | 40×42 |
| `icons/remove.png` | 41×41 |
| `icons/arrow_left.png` | 23×32 |
| `icons/arrow_right.png` | 22×32 |
| `icons/box.png` | 27×28 |
| `mascots/wave.png` | 152×151 |
| `mascots/think.png` | 111×153 |
| `mascots/celebrate.png` | 133×149 |
| `panels/bubble_white.png` | 145×79 |
| `panels/bubble_yellow.png` | 154×80 |
| `panels/panel_plain.png` | 392×146 |
| `panels/panel_star.png` | 368×156 |
| `panels/popup_close.png` | 229×149 |
| `panels/checklist.png` | 181×144 |
| `panels/panel_layers.png` | 355×153 |
| `panels/toast_success.png` | 298×51 |

---

## 7. Design System Compatibility

### 7.1 Palette Comparison (Verified against `moonminds_theme.tres`)

| Token | Target Hex | Current Godot Color | Status |
|---|---|---|---|
| Primary Blue | `#4F6BFF` | `Color(0.310, 0.420, 1.0)` ≈ `#4F6BFF` | ✅ Match |
| Action Orange | `#FFB020` | `Color(1.0, 0.690, 0.125)` ≈ `#FFB020` | ✅ Match |
| Danger Pink | `#FF4961` | `Color(1.0, 0.286, 0.380)` = `#FF4961` | ✅ Match |
| Success Green | `#3CDB56` | `Color(0.235, 0.859, 0.337)` ≈ `#3CDB56` | ✅ Match |
| Warning Yellow | `#F7C948` | `Color(0.969, 0.788, 0.282)` ≈ `#F7C948` | ✅ Match |
| Info Cyan | `#00C6FF` | `Color(0, 0.776, 1.0)` ≈ `#00C6FF` | ✅ Match |
| Dark Background | `#080F2B` | `Color(0.031, 0.059, 0.169)` ≈ `#080F2B` | ✅ Match |
| Panel Background | `#1A1F48` | `Color(0.102, 0.122, 0.282)` ≈ `#1A1F4B` | ✅ Match |
| Surface / Card | `#282F6B` | `Color(0.157, 0.184, 0.420)` ≈ `#282F6B` | ✅ Match |
| Border | `#3F4BAB` | `Color(0.247, 0.294, 0.671)` ≈ `#3F4BAB` | ✅ Match |

### 7.2 Typography Comparison (Verified)

| Element | Target | Current | Status |
|---|---|---|---|
| Display font | Fredoka | Fredoka-Variable.ttf | ✅ |
| Body font | Poppins | Poppins Regular/Medium/SemiBold/Bold | ✅ |
| H1 | Fredoka Bold 36px | Fredoka Bold 36px | ✅ |
| H2 | Fredoka Bold 24px | Fredoka Bold 24px | ✅ |
| H3 | Fredoka SemiBold 18px | Fredoka SemiBold 18px | ✅ |
| Body | Poppins Regular 16px | Poppins Regular 16px (default_font_size) | ✅ |
| Caption | Poppins Regular 14px | Poppins Regular 14px | ✅ |

### 7.3 Spacing & Shape (Verified)

| Token | Target | Current | Status |
|---|---|---|---|
| Grid | 8px | Used as `theme_override_constants/separation` increments | ✅ |
| Card radius | 20px | `corner_radius_*=20` in CardPanel | ✅ |
| Button radius | 16px | `corner_radius_*=16` in all button StyleBoxFlat | ✅ |
| Touch target min | 48px | Buttons: `custom_minimum_size = Vector2(150+, 52+)` | ✅ |

### 7.4 What Already Matches ✅
Complete colour palette, both fonts + all sizes, border radii, grid increments, mascot presence (3 poses), all button sprites (Build/Research/Explore/Cancel/OK/Mission), all panel frame sprites (plain, star, bubble white/yellow, popup), all resource icons for HUD (power, water, food, shield), status chips (healthy/warning/critical), all six building thumbnails, logo splash.

### 7.5 What Partially Matches 🟡
- **Resource rings**: Code-drawn rings work; illustrated sprite rings would elevate the aesthetic
- **Mascot poses**: Wave/Think/Celebrate exist; Idle, Excited, Pointing would enrich the experience
- **Building thumbnails**: Images exist but are relatively small — may appear pixelated in the 100px illustration slot on retina

### 7.6 What Is Missing or Conflicting 🔴
- **Hangar building art**: Currently uses `icons/rocket.svg` as fallback; no building thumbnail
- **Health icon**: `health.svg` — simple vector heart; not styled to match the cartoon icon set
- **Oxygen icon**: `oxygen.svg` — simple molecule; not styled to match the icon set
- **Rocket icon**: `rocket.svg` — used in multiple places; needs a cartoon-polished version
- **Research button states**: No `research_focus.png` or `research_disabled.png`
- **Settings, main menu screens**: Not implemented

### 7.7 What Must Not Change (Gameplay Critical)
- The 5-resource HUD structure (Health, Food, Water, Energy, Oxygen)
- Ring colour semantics (green/yellow/red = healthy/warning/critical)
- The 3-button bottom nav (Build / Research / Explore)
- The overlay system (reused across 10 content types)
- The signal contract between HUD and `main.gd` (see Section 5.3)
- `ColonySim` GDScript logic

---

## 8. Screen Inventory

### All Verified UI States (within `outpost_hud.tscn`)

| # | Screen State | Node | Trigger | Purpose |
|---|---|---|---|---|
| 1 | **Splash / Logo** | `Splash` ColorRect | `_ready()` | Dark overlay + logo; fades out in ~2s |
| 2 | **Outpost HUD — Normal** | Persistent top + bottom bars | Always | Collapsed rings, goal panel, mascot bubble, nav |
| 3 | **Resource Bar — Expanded** | `ResourceBar` PanelContainer | Tap ring bar | 5 resources shown vertically w/ detail labels |
| 4 | **Resource Info Overlay** | `Overlay` | Tap `?` per resource | Goes-up / Goes-down / Strategy for one resource |
| 5 | **Tutorial Overlay** | `Overlay` | 2s after splash | 8-page tutorial; Back / Skip / Next / Let's Go |
| 6 | **Build Menu Overlay** | `Overlay` | Tap BUILD | 2-column building card grid |
| 7 | **Placement Mode** | `PlaceBanner` | After build card selected | Instruction banner; cancel button |
| 8 | **Build / Upgrade Popup** | `BuildPopup` / `PopupCard` | After grid cell tapped | Illustration + effects + Cancel / Confirm |
| 9 | **Building Detail Overlay** | `Overlay` | Tap existing building on 3D map | Level info, toggles (exercise/sleep/CO₂), Upgrade |
| 10 | **Research Overlay** | `Overlay` | Tap RESEARCH | 8 research card list |
| 11 | **Hangar / Explore Overlay** | `Overlay` | Tap EXPLORE | Spacecraft status + build options + mission list |
| 12 | **Day End Report Overlay** | `Overlay` | After END DAY | Per-resource delta + events table |
| 13 | **Storm / Problem Detail Overlay** | `Overlay` | Tap StormChip | Full problem card (what/prepare/good/bad) |
| 14 | **Mission Return Report** | `Overlay` | Mission complete event | Loot + discoveries + lesson |
| 15 | **Mascot Hint Bubble** | `MascotArea/Bubble` | Tap TAKE HINT | Bubble scale-bounce animation |

**Total: 15 distinct UI states, 3 scene files, 1 active scene.**

### HUD Layout Diagram

```
1280×720  (landscape, canvas_items stretch)
┌─────────────────────────────────────────────────────────────────────────┐
│ [GoalPanel ★]                              [○ ○ ○ ○ ○  Day N  Crew  ]  │
│  Goal title                                [Materials  Science      ]   │  ← TopCenter + TopRight
│  Goal text                                                              │
│            [StormChip: "Day N problem · in X days"]                    │  ← Centred
├──────────────────────────────────────────────────────────────────────── │
│                                                                          │
│                   3 D   O U T P O S T   W O R L D                       │
│                   (renders behind CanvasLayer)                           │
│                                         [BuildPopup dock  right edge]   │  ← PopupDock
│         [PlaceBanner: "Tap a green square…"] ← top-centre during place  │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────│
│  [Mascot 84×84]  [TAKE HINT button]                                     │  ← MascotArea, bottom-left
│  [Speech bubble above mascot]                                           │
├──────────────────────────────────────────────────────────────────────────│
│      [BUILD ████]  [RESEARCH ████]  [EXPLORE ████]  [END DAY ██████]   │  ← BottomBar, centred
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Complete UI Asset Requirements

### 9.1 Assets Present and In-Use (No Action Needed)

39 assets are already imported and actively referenced in `.tscn` / `.gd` files. See Section 6.4 for full dimensions list. Key in-use assets: all 6 building thumbnails, all navigation buttons (3 primary + 3 focus + 1 disabled + cancel, ok, mission), all 3 mascot poses, bubble/panel nine-patches, all resource icons (power, water, food, shield), all status chips, logo.

### 9.2 Recommended New / Replacement Assets

| Asset ID | Suggested File | Visual Description | Target | Dimensions | Transparency | Text Baked? | Priority |
|---|---|---|---|---|---|---|---|
| `building-hangar` | `buildings/hangar.png` | Cartoon toy hangar: large orange bay doors, blue-grey metallic roof, radar dish, launch support frame. Same isometric-cartoon perspective as existing building thumbnails. | `ART["hangar"]` in `outpost_hud.gd` | 220×200px | Yes | No | 🔴 High |
| `icon-health` | `icons/health_cartoon.png` | Dimensional cartoon heart or medical cross; soft green/cyan glow; same style as power.png/water.png | `ICONS["health"]` in `outpost_hud.gd` | 128×128px | Yes | No | 🔴 High |
| `icon-oxygen` | `icons/oxygen_cartoon.png` | Cartoon O₂ — two spheres bonded, cyan colour, sparkle effect; or air-swirl / bubble icon | `ICONS["oxygen"]` in `outpost_hud.gd` | 128×128px | Yes | No | 🔴 High |
| `icon-rocket` | `icons/rocket_cartoon.png` | Cartoon rocket: white body, orange nose, cyan portal window, colourful exhaust | `ART["hangar"]` fallback + Hangar overlay rows | 128×128px | Yes | No | 🔴 High |
| `ring-resource` | `ui/resource_ring.png` | **Pure white** circular donut / ring shape; outer dia ~108px, ring width ~8px; soft AA edges; NO colour — must stay white for runtime tinting | `TextureProgressBar` texture_under / texture_progress | 116×116px | Yes | No | 🔴 High |
| `mascot-excited` | `mascots/excited.png` | Robot arms raised, star sparkles; same white/orange/cyan design | `MASCOTS` dict, goal completion | 152×152px | Yes | No | 🟡 Medium |
| `mascot-idle` | `mascots/idle.png` | Robot relaxed neutral standing; slight head tilt | `MASCOTS` dict, future idle state | 152×152px | Yes | No | 🟢 Low |
| `icon-materials` | `icons/materials.png` | Orange or gold cargo crate / crystal; dimensional cartoon | TopRight stats label prefix | 40×40px | Yes | No | 🟡 Medium |
| `icon-science` | `icons/science.png` | Cyan flask / beaker with sparkle; dimensional cartoon | TopRight stats label prefix | 40×40px | Yes | No | 🟡 Medium |
| `icon-crew` | `icons/crew.png` | Mini astronaut helmet; white + cyan visor | TopRight stats label prefix | 40×40px | Yes | No | 🟡 Medium |
| `btn-research-focus` | `buttons/research_focus.png` | RESEARCH button with same golden focus ring as `build_focus.png` | `ResearchButton` texture_focused | 130×84px | Yes | Yes ("RESEARCH") | 🟡 Medium |
| `btn-research-disabled` | `buttons/research_disabled.png` | RESEARCH button muted/greyed | `ResearchButton` texture_disabled | 121×53px | Yes | Yes | 🟢 Low |
| `btn-ok-focus` | `buttons/ok_focus.png` | OK button with golden focus ring | `ConfirmButton` texture_focused | 130×84px | Yes | Yes | 🟢 Low |
| `destination-moon` | `ui/destinations/moon.png` | Cartoon Moon surface: grey craters, black sky, Earth in background | Hangar overlay mission row | 280×180px | Yes | No | 🟡 Medium |
| `destination-mars` | `ui/destinations/mars.png` | Cartoon Mars: rust-red rocky ground, pink sky, dust haze | Hangar overlay mission row | 280×180px | Yes | No | 🟡 Medium |
| `destination-europa` | `ui/destinations/europa.png` | Cartoon Europa: icy white-blue, cracked shell, Jupiter visible | Hangar overlay mission row | 280×180px | Yes | No | 🟡 Medium |
| `destination-asteroid` | `ui/destinations/asteroid.png` | Cartoon Psyche: metallic silver-grey rocky body in space | Hangar overlay mission row | 280×180px | Yes | No | 🟡 Medium |
| `craft-rover` | `ui/crafts/rover.png` | Cartoon 4-wheel moon rover: white, orange accents, antenna | Hangar craft build buttons | 100×80px | Yes | No | 🟡 Medium |
| `craft-shuttle` | `ui/crafts/shuttle.png` | Cartoon shuttle: white, blue windows, orange engine | Hangar craft build buttons | 100×80px | Yes | No | 🟡 Medium |
| `craft-deep-space` | `ui/crafts/deep_space.png` | Cartoon deep-space ship: elongated, gold solar wings, multiple engines | Hangar craft build buttons | 100×80px | Yes | No | 🟡 Medium |
| `panel-overlay-card` | `panels/overlay_card.png` | Large dark navy rounded panel with blue glow edge; nine-patch; replaces flat `PanelContainer_sb` on OverlayCard | OverlayCard PanelContainer | 600×400px nine-patch | Yes | No | 🟡 Medium |
| `panel-day-report-header` | `panels/day_report_header.png` | "End of Day" banner strip: stars, space ribbon; no text (day number is dynamic) | Day Report overlay header | 560×80px | Yes | No | 🟡 Medium |
| `sticker-goal-done` | `ui/sticker_goal_done.png` | Celebration sticker: stars, confetti, thumbs-up; 200×200 | Goal completion overlay flash | 200×200px | Yes | No | 🟢 Low |
| `building-greenhouse-lv2` | `buildings/greenhouse_lv2.png` | Two-dome greenhouse illustration | Build card (optional per-level art) | 400×400px | Yes | No | 🟢 Low |
| `building-greenhouse-lv3` | `buildings/greenhouse_lv3.png` | Three-dome + LED ring illustration | Build card | 400×400px | Yes | No | 🟢 Low |
| `building-greenhouse-lv4` | `buildings/greenhouse_lv4.png` | Three-dome + hydroponic tanks + sensor mast | Build card | 400×400px | Yes | No | 🟢 Low |

**Total recommended new assets: ~26**  
**Combined with ~39 existing in-use assets: ~65 visual assets total**

---

## 10. Recommended Project Folder Structure

```
assets/
├── fonts/               # TTF files — complete, do not change
├── sprites/             # ← All in-game sprites (Godot auto-imports)
│   ├── backgrounds/     # Full-width background images
│   ├── brand/           # Logo, wordmark, emblem
│   ├── buildings/       # Building thumbnails; one per building per level
│   ├── buttons/         # name.png + name_focus.png + name_disabled.png
│   ├── chips/           # Status chip images (healthy, warning, critical)
│   ├── crafts/          # NEW: spacecraft images (rover, shuttle, deep_space)
│   ├── destinations/    # NEW: mission destination images (moon, mars, europa, asteroid)
│   ├── icons/           # Resource + navigation icons; 128×128 for resource icons
│   ├── mascots/         # All mascot poses (~152×152)
│   ├── panels/          # Nine-patch panel frames + speech bubbles
│   └── ui/              # Misc: resource ring, stickers, report headers
├── audio/               # Keep as-is
├── textures/            # 3D world textures — keep as-is
└── source/              # .gdignore — source reference, not built
    └── moonminds_godot_asset_pack/

design/                  # NEW: Design handoff artifacts (tracked in git)
├── design-tokens.json   # Machine-readable colour/typography/spacing tokens
├── asset_tracker.md     # Delivery status of each asset
└── moonminds-style-guide.png
```

---

## 11. ChatGPT ↔ Claude Code Collaboration Workflow

### 11.1 Step-by-Step Workflow

```
1. Developer identifies needed asset (Section 9.2)
2. Developer posts asset spec to ChatGPT (Asset ID + description)
3. ChatGPT generates & exports PNG per the spec in Section 16
4. Developer drops PNG into assets/sprites/[category]/ on disk
5. Godot auto-imports on next editor focus
6. Developer sends Claude Code: "Integrate [asset-id] into [component]" using the template in Section 12
7. Claude Code edits the relevant .gd or .tscn; reports file:line changed
8. Developer runs Godot (F5) → visually inspects
9. Screenshots compared with ChatGPT reference
10. Differences flagged → ChatGPT refines → repeat from step 4
```

### 11.2 Asset Handoff Rules

| Convention | Rule |
|---|---|
| Format | PNG-24 with alpha (RGBA) |
| Colour profile | sRGB; no embedded ICC profiles |
| Background | Transparent for all sprites except backgrounds |
| Naming | `snake_case.png` matching the suggested filename exactly |
| Delivery resolution | **2× the displayed pixel size** (iPad is 2× Retina). E.g., a "58px ring" → deliver at 116×116px |
| Nine-patch sprites | Include margin values (L/T/R/B in px) in the delivery note |
| Bleed | 2–4px transparent bleed around edges to prevent aliasing at non-integer scales |

### 11.3 Image vs. Dynamic Code

| Element | Strategy | Reason |
|---|---|---|
| Button labels (BUILD, RESEARCH…) | **Image** (baked) | Already baked; consistent rendering |
| Resource values, day count, percentages | **Code** (dynamic) | Changes every turn |
| Resource ring fill colour | **Code** (runtime tint) | Green / yellow / red state-driven |
| Panel frames / borders | **Image** (nine-patch) | Visual style consistent regardless of content |
| Mascot expressions | **Image** per pose state | Static PNG swaps |
| Building thumbnails | **Image** per level (optional) | Currently one per building type |
| Overlay card content | **Code** (dynamic) | Reused across 10+ content types |
| Destination / craft illustrations | **Image** | Static per destination / craft |

### 11.4 Asset Version Tracking

Maintain `design/asset_tracker.md`:

```markdown
| Asset ID | File | Status | Version | Notes |
|---|---|---|---|---|
| building-hangar | buildings/hangar.png | ✅ Delivered | v1 | |
| icon-health | icons/health_cartoon.png | 🔄 In review | v0.9 | Needs brighter glow |
```

### 11.5 Visual Validation

After Claude Code integrates an asset:
1. Launch in Godot editor (F5)
2. Navigate to the UI state showing the new asset
3. Check: correct placement, correct scale, transparent background correct, no white fringing, nine-patch corners intact
4. Use Godot's built-in screenshot or macOS screenshot for reference

---

## 12. Reusable Claude Code Integration Prompt

Copy, fill `[BRACKETED]` fields, and paste into your Claude Code session:

```
Integrate a new visual asset into MoonMinds.

**Asset ID**: [e.g., building-hangar]
**Delivered file**: assets/sprites/[category]/[filename.png]
**Target component**: [e.g., ui/screens/outpost_hud.gd — ART dictionary]
**Expected visual behaviour**: [e.g., shown in BuildPopup when player selects the Hangar building; also in Build menu card grid]
**Integration method**: [e.g., In outpost_hud.gd at line 35, the ART dict has "hangar" mapped to rocket.svg — change the preload to the new PNG]

Rules:
- Do NOT modify gameplay logic in colony_sim.gd
- Do NOT rename any existing files
- Match the existing pattern — look at how other building thumbnails are referenced
- Verify the file path is syntactically correct in GDScript
- After integrating, report the exact file:line changed
```

**Filled example:**

```
Integrate a new visual asset into MoonMinds.

**Asset ID**: building-hangar
**Delivered file**: assets/sprites/buildings/hangar.png
**Target component**: ui/screens/outpost_hud.gd — ART dict; possibly outpost_hud.tscn ext_resources
**Expected visual behaviour**: hangar.png shown in BuildPopup illustration and Build menu card art when player selects the Hangar building.
**Integration method**: In outpost_hud.gd, the ART dict at the top of the file currently maps "hangar" → preload("res://assets/sprites/icons/rocket.svg"). Change that preload to preload("res://assets/sprites/buildings/hangar.png"). If outpost_hud.tscn references the texture directly, add it as an ext_resource there too.

Rules: Do NOT modify gameplay logic. Match existing patterns. Report file:line.
```

---

## 13. Risks and Limitations

| Risk | Severity | Description | Mitigation |
|---|---|---|---|
| Nine-patch margins misconfigured | 🔴 High | New panel sprites without correct inner padding deform when stretched (corners squash) | Supply explicit L/T/R/B margin values with every panel delivery; test in Godot before approving |
| White fringing on transparent PNGs | 🔴 High | AA edges against a white canvas leave a white halo on dark backgrounds | Export from a dark/transparent canvas; inspect edges at 100% zoom before delivery |
| Retina pixel density inconsistency | 🟡 Medium | iPad 2× Retina; if some assets at 1× and others at 2×, inconsistent sharpness | Deliver all new assets at 2× the display size; document scale in asset manifest |
| Ring texture receives runtime tinting | 🟡 Medium | If the ring replacement contains colour, tint_progress will multiply onto it, giving wrong hues | Deliver ring as pure white donut shape only |
| Dynamic overlay is entirely code-built | 🟡 Medium | Research list, build cards, day report content cannot be replaced with static images | Only the OverlayCard PanelContainer frame is replaceable via nine-patch |
| iOS-only export | 🟡 Medium | No macOS/Android/Windows export preset; desktop testing has slightly different input paths | Always test at `1280×720` to simulate iPad resolution; touch area sizing is critical |
| canvas_items expand stretch | 🟢 Low | On non-16:9 iPad aspect ratios (iPad Pro 11″) UI content at edges may shift | Safe-area insets are already implemented in `_apply_safe_area()`; apply the same to any new fixed-position element |
| Fonts are OFL licensed | 🟢 Low | Fredoka (OFL-Fredoka.txt) and Poppins (OFL-Poppins.txt) are confirmed open in `assets/fonts/` | No licensing action required |
| Building thumbnails may appear soft | 🟢 Low | Current buildings are ~200×200px max; shown in 100px illustration slot; Godot applies bilinear upscale | Deliver replacement building art at 400×400px minimum |
| Missing settings / main menu | 🟢 Low | No settings screen or main menu is implemented; game starts straight in outpost | Not blocking current development; flag for a future stage |

---

## 14. Prioritized Implementation Roadmap

### Stage 1 — Foundation (Complete ✅)

The design system foundation is fully implemented.

- **Status**: Colour palette, typography, border radii, button sprites, panel sprites, icon set, mascot poses, building thumbnails all integrated
- **Acceptance criteria**: ✅ All palette values match spec; fonts match spec; layout matches spec

---

### Stage 2 — Core HUD Completeness

Fill the remaining gaps in the always-visible HUD.

**Assets needed:**
- `icons/health_cartoon.png` (128×128) — replace `health.svg`
- `icons/oxygen_cartoon.png` (128×128) — replace `oxygen.svg`
- `icons/rocket_cartoon.png` (128×128) — replace `rocket.svg`
- `buildings/hangar.png` (220×200) — replace `ART["hangar"] = rocket.svg`
- `ui/resource_ring.png` (116×116, pure white) — replace procedural ring

**Code affected:**
- `ui/screens/outpost_hud.gd` lines 28–45 (`ART` dict and `ICONS` dict)
- `_make_ring_texture()` function — replace procedural generation with preloaded PNG

**Dependencies:** None

**Blockers:** Must validate that runtime `tint_progress` still applies correctly after ring replacement

**Acceptance criteria:**
- All 5 resource rings show cartoon icons instead of SVG placeholders
- Hangar has a building thumbnail instead of rocket fallback
- Rings are visually polished and correctly tinted green/yellow/red

---

### Stage 3 — Gameplay Components (Explore / Hangar / Research)

Add visual richness to interactive popups and overlays.

**Assets needed:**
- `ui/destinations/moon.png`, `mars.png`, `europa.png`, `asteroid.png`
- `ui/crafts/rover.png`, `shuttle.png`, `deep_space.png`
- `icons/materials.png`, `icons/science.png`, `icons/crew.png` (40×40)
- `buttons/research_focus.png`, `buttons/research_disabled.png`

**Code affected:**
- `outpost_hud.gd` `show_hangar()` function — add destination/craft `TextureRect` to rows
- `outpost_hud.tscn` — add `texture_focused` to ResearchButton

**Dependencies:** Stage 2

**Blockers:** Hangar overlay is code-built; destination images require adding a TextureRect before the label text in `_add_row()`

**Acceptance criteria:**
- Build/Research/Explore buttons all have focus states
- Hangar overlay shows destination images and craft art
- Stats panel shows icon prefixes for materials, science, and crew

---

### Stage 4 — Major Visual Upgrade

Polish the overlay system and building illustrations.

**Assets needed:**
- `panels/overlay_card.png` (nine-patch, 600px wide)
- `panels/day_report_header.png` (560×80)
- Replacement building thumbnails at 2× (400×400) for all 6 types
- `mascots/excited.png`

**Code affected:**
- `outpost_hud.tscn` OverlayCard PanelContainer style
- `outpost_hud.gd` MASCOTS dict

**Dependencies:** Stages 2–3

**Blockers:** OverlayCard height is dynamic (content-driven); nine-patch must handle full range of overlay heights (≈200–600px)

**Acceptance criteria:**
- Overlay modal has an art-framed card instead of flat StyleBoxFlat
- Building illustrations are sharp on iPad Retina
- Excited mascot used during goal completions

---

### Stage 5 — Polish and New Screens

Celebration effects, optional main menu, mascot animation.

**Assets needed:**
- `ui/sticker_goal_done.png` (200×200)
- `panels/toast_success.png` redesign
- Main menu scene assets (if main menu is added)
- Per-level building variants (lv2–lv4) for Greenhouse

**Code affected:**
- `main.gd` would need a main menu scene added; `project.godot` `main_scene` updated
- `outpost_hud.gd` for sticker display logic

**Dependencies:** Stages 2–4

**Acceptance criteria:**
- Goal completion has a visible celebration element
- (If added) Main menu with MoonMinds logo and Play button exists

---

## 15. Open Questions and Unverified Assumptions

| # | Question / Assumption | Status | Impact |
|---|---|---|---|
| 1 | Does the project need a main menu / title screen? (design guide says yes; `project.godot` starts directly in the game scene) | ❓ Unverified | High — new scene required |
| 2 | Is a Settings screen (audio, text size, accessibility controls) planned? | ❓ Unverified | Medium |
| 3 | What is the intended asset delivery resolution — 1× or 2×? The base canvas is 1280×720 but iPad renders at 2× physical density | ❓ Unverified | Medium — affects all future deliveries |
| 4 | `resource_bar.tscn` exists as a complete reusable widget but is not wired into `outpost_hud.tscn`. Is there a plan to refactor the HUD to use it? | 🟡 Assumed "future plan" | Low |
| 5 | Are per-level building thumbnails expected? The ART dict uses the same key regardless of level; the 3D model gains new geometry per level. | 🟡 Assumed "optional" | Low |
| 6 | `panel_layers.png` and `checklist.png` are imported but not referenced in any `.tscn` or `.gd` file. What screen are they intended for? | ❓ Unknown | Low |
| 7 | `toast_success.png` (298×51) is imported but not wired. Is an automatic toast notification system planned? | ❓ Unknown | Low |
| 8 | The `intro_assets/` directory contains two Gemini-generated MP4 videos. Are they for an in-game intro cutscene? | ❓ Unknown | Medium if re-added |
| 9 | Are the source atlas crops in `assets/source/` considered final quality, or do they need to be replaced with higher-quality artwork? | 🟡 Assumed "to be replaced" given README says "not editable vector artwork" | High — determines replacement scope |
| 10 | Is there a plan for Android or macOS export? Only iOS is configured. | ❓ Unverified | Low for current milestone |

---

## 16. Instructions for ChatGPT — MoonMinds Visual Designer

*This section is written directly to you, the AI visual designer creating artwork for this game. Read it in full before generating any asset.*

---

### What MoonMinds Is

MoonMinds is a **turn-based, child-friendly 3D game** where children (ages 7–12) manage a lunar colony. Players build and upgrade 7 types of modular buildings, balance 5 life-critical resources (Health, Food, Water, Energy, Oxygen), conduct research, and launch spacecraft on missions to the Moon, Mars, Europa, and the asteroid belt. The game teaches STEM concepts through cause-and-effect mechanics, not punishment.

**Visual aesthetic:** Polished, playful, space-themed cartoon. Think high-quality mobile children's game — dimensional toy-like objects, rounded forms, bright colours, soft shadows, glossy highlights. **Not** realistic or NASA-style. **Not** flat or minimalist.

---

### Technology Constraints

- Engine: **Godot 4.7.2** on **iPad (landscape, 1280×720 base canvas, 2× Retina)**
- UI runs as a 2D `CanvasLayer` on top of a 3D scene
- Buttons use **full-image PNG artwork** — the visual IS the button
- Panel borders use **nine-patch scaling** (`StyleBoxTexture`) — panels stretch in the centre while corners stay fixed
- Some sprites receive **runtime colour tinting** (`modulate` / `tint_progress`) — these must be delivered as **pure white or greyscale**
- Labels, numbers, and gameplay values are always rendered in code — **do not bake them into images** (except for button text like "BUILD" which is already baked in the existing artwork)

---

### Non-Negotiable Visual Rules

**1. Colour palette — use only these:**

| Semantic role | Hex | Use for |
|---|---|---|
| Primary Blue | `#4F6BFF` | Navigation buttons, selected highlights, borders |
| Action Orange | `#FFB020` | Primary action (build, confirm), progress accents |
| Danger Pink | `#FF4961` | Errors, critical states, destructive actions |
| Success Green | `#3CDB56` | Healthy systems, positive feedback |
| Warning Yellow | `#F7C948` | Caution, approaching danger |
| Info Cyan | `#00C6FF` | Information, water resource, technology highlights |
| Dark Navy | `#080F2B` | Backgrounds, deep space |
| Panel Dark | `#1A1F48` | Panel fills |
| Card Surface | `#282F6B` | Card interiors |
| Border Blue | `#3F4BAB` | Panel outlines, dividers |

**2. Typography reference:** Fredoka (display/buttons) and Poppins (body). Use only for reference when designing baked-text buttons — do not assume these fonts are embedded in image exports.

**3. Shapes:** Always use rounded corners. 20px radius for panels and cards, 16px for buttons.

**4. Mascot:** The robot has a **white rounded body**, **dark navy face screen**, **bright cyan eyes**, **orange/yellow accents**, and an **orange M on its chest**. Never change this design. Three poses exist: wave (info), think (warning), celebrate (success). Additional poses must match exactly.

**5. Icons:** Dimensional cartoon icons with soft highlights on top, shadows on bottom, not flat. Resource icons are 128×128px. Navigation/action icons are 40–55px.

**6. Transparency:** All buttons, icons, mascots, building thumbnails, and panel frames must have transparent backgrounds (PNG with alpha). Never deliver a white or solid background unless explicitly specified.

**7. Building style:** Rounded toy-like modules in an isometric-ish cartoon perspective. White structures, orange doors, cyan window panels, blue metallic panels. Match the dimensions and perspective of the existing `greenhouse.png`, `habitat.png`, and `solar_panel.png`.

---

### What to Generate First — Priority 1

Generate these 5 assets immediately:

**1. `buildings/hangar.png`** (220×200px, transparent)
- A cartoon toy-style hangar building
- Large orange bay doors (open or closed), blue-grey metallic exterior, small radar dish on roof, launch support scaffolding visible at sides
- Same isometric-ish cartoon angle as other building thumbnails
- White structural walls, orange accent doors, cyan windows/lights

**2. `icons/health_cartoon.png`** (128×128px, transparent)
- A dimensional cartoon heart icon
- Soft inner glow; green/cyan colour; white highlight at top-left
- Alternatively: a rounded red cross (+) with a blue aura — dimensional, not flat
- Style must match the weight and feel of `power.png` (yellow lightning) and `water.png` (cyan droplet)

**3. `icons/oxygen_cartoon.png`** (128×128px, transparent)
- A dimensional cartoon O₂ representation
- Two linked spheres (oxygen atoms) in cyan/white, or a stylised air-swirl / bubble icon
- Cyan-to-white colour gradient; sparkle accent

**4. `icons/rocket_cartoon.png`** (128×128px, transparent)
- A cartoon rocket ship
- White cylindrical body, orange nose cone, cyan circular porthole, colourful exhaust trail (orange → yellow → transparent)
- Slight dynamic angle (not perfectly vertical)

**5. `ui/resource_ring.png`** (116×116px, transparent)
- A **pure white circular donut / ring** shape
- Outer diameter approximately 108px, ring width approximately 8px
- Soft anti-aliased edges
- **Absolutely no colour** — must stay white to accept runtime tinting (the game applies green/yellow/red at runtime)
- Think of it as a clock face ring with no numbers

---

### What to Generate Next — Priority 2

After Priority 1 is approved:

6. `mascots/excited.png` (152×152px) — Robot with arms raised, star sparkles; celebration pose
7. `icons/materials.png` (40×40px) — Orange/gold cargo crate or crystal cluster; dimensional
8. `icons/science.png` (40×40px) — Cyan science flask/beaker with sparkle; dimensional
9. `icons/crew.png` (40×40px) — Mini astronaut helmet; white with cyan visor accent
10. `ui/destinations/moon.png` (280×180px) — Cartoon Moon surface scene; grey craters, black star sky, blue Earth glow on horizon
11. `ui/destinations/mars.png` (280×180px) — Cartoon Mars; red-orange rocky ground, dusty pink sky, two small moons optional
12. `ui/destinations/europa.png` (280×180px) — Cartoon Europa; white-blue icy shell with orange-brown cracks, Jupiter visible in background
13. `ui/destinations/asteroid.png` (280×180px) — Cartoon Psyche asteroid; metallic silver-grey, rough rocky form, stars in background
14. `ui/crafts/rover.png` (100×80px) — Cartoon 4-wheel moon rover; white chassis, orange accents, dish antenna
15. `ui/crafts/shuttle.png` (100×80px) — Cartoon shuttle; white fuselage, blue windows, orange engine nozzle
16. `ui/crafts/deep_space.png` (100×80px) — Cartoon deep-space ship; elongated body, gold extended solar wings, multiple engine nozzles

---

### What NOT to Generate

- ❌ Do not generate full screen mockups or composited scenes — deliver individual elements only
- ❌ Do not use photorealistic rendering or NASA/ISS photograph aesthetics
- ❌ Do not add solid or white backgrounds to icons, buttons, or mascots
- ❌ Do not change the mascot robot's design (colour, shape, eye colour, chest logo)
- ❌ Do not generate flat / low-shadow minimalist icons — the style requires dimensional highlights
- ❌ Do not bake in labels, numbers, or game text unless the asset is explicitly a button sprite
- ❌ Do not use colours outside the defined palette for semantic UI elements
- ❌ Do not add colour tints to the resource ring (`ui/resource_ring.png`) — it must be pure white
- ❌ Do not generate a focus-state button by simply drawing a glowing border around the normal version — match the golden ring style visible in the existing `build_focus.png`

---

### Export Checklist Before Delivering

For every asset:
- [ ] PNG-24 with alpha (RGBA), not PNG-8
- [ ] sRGB colour space, no embedded ICC profile
- [ ] Exported from a dark or transparent canvas (not white)
- [ ] Transparent regions are clean — no white halo, no fringe pixels
- [ ] Dimensions match the specification
- [ ] Delivered at 2× the display size (e.g., a "58px ring" → 116×116px)
- [ ] Filename matches the suggested filename exactly (snake_case.png)
- [ ] If a nine-patch panel: margin values (L/T/R/B) stated in the delivery note

---

### How Claude Code Integrates Your Work

1. Claude Code receives the integration prompt (Section 12) with the asset filename and target
2. It edits the relevant GDScript file (usually `ui/screens/outpost_hud.gd`) to change a `preload()` path
3. It may also update `ui/screens/outpost_hud.tscn` to add an `[ext_resource]` declaration
4. It verifies the GDScript reference is syntactically correct
5. The developer runs the game in Godot editor (F5) and visually inspects

**Your responsibility**: deliver a clean, correctly sized, correctly named PNG to spec.  
**Claude Code's responsibility**: wire it into the GDScript/TSCN files.  
**Developer's responsibility**: visually approve and flag differences back to you.

---

*This report was generated from a complete analysis of the MoonMinds repository source code, scene files, theme resources, GDScript files, asset files, and project configuration.*  
*No code changes were made during this audit.*  
*All file paths, type names, colour values, signal names, and asset dimensions stated here are verified facts read directly from repository files.*

---

**MoonMinds — Build. Balance. Explore.**
