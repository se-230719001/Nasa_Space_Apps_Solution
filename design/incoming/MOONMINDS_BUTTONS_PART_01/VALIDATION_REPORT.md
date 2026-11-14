# VALIDATION REPORT — MoonMinds Buttons Part 01

**Date:** 2026-11-14  
**Asset folder:** `design/incoming/MOONMINDS_BUTTONS_PART_01/`  
**Manifest status:** `PRELIMINARY_IMAGE_GENERATED_REVIEW_REQUIRED`  
**Reviewer:** automated pixel analysis + Godot architecture review

---

## 1. Asset Validation Results

| File | Canvas | RGBA | Transparent corners | Edge bleed | Status |
|---|---|---|---|---|---|
| build_default.png | 376×176 px | ✓ | ✓ | None | **PASS** |
| build_pressed.png | 376×176 px | ✓ | ✓ | None | **PASS** |
| build_focus.png | 376×176 px | ✓ | ✓ | None | **PASS** |
| build_disabled.png | 376×176 px | ✓ | ✓ | None | **PASS** |
| research_default.png | 376×176 px | ✓ | ✓ | None | **PASS** |
| research_pressed.png | 376×176 px | ✓ | ✓ | None | **PASS** |
| research_focus.png | 376×176 px | ✓ | ✓ | None | **PASS** |
| research_disabled.png | 376×176 px | ✓ | ✓ | None | **PASS** |

**All 8 files delivered. All pass automated format checks.**  
No black/white background artifacts detected. No edge-pixel bleed from neighboring atlas cells. No unexpected solid corner pixels.

---

## 2. Identified Visual Defects

### DEFECT-01 — Focus state body offset (both buttons) ⚠️

The visible button body in the focus states (`build_focus.png`, `research_focus.png`) is shifted relative to the transparent canvas center compared to the other three states.

| State | Body bbox (px) | Body center | Canvas center | Offset |
|---|---|---|---|---|
| build_default | (44,30)–(333,146) | (188.5, 88.0) | (188, 88) | +0.5, 0 |
| build_pressed | (42,34)–(333,142) | (187.5, 88.0) | (188, 88) | −0.5, 0 |
| build_disabled | (40,33)–(333,143) | (186.5, 88.0) | (188, 88) | −1.5, 0 |
| **build_focus** | **(30,3)–(340,165)** | **(185.0, 84.0)** | (188, 88) | **−3.0, −4.0** |
| research_default | (43,30)–(333,146) | (188.0, 88.0) | (188, 88) | 0, 0 |
| research_pressed | (41,34)–(335,142) | (188.0, 88.0) | (188, 88) | 0, 0 |
| research_disabled | (40,33)–(337,142) | (188.5, 87.5) | (188, 88) | +0.5, −0.5 |
| **research_focus** | **(39,3)–(344,165)** | **(191.5, 84.0)** | (188, 88) | **+3.5, −4.0** |

**Impact:** The glow ring in focus sprites extends 4 px further toward the top compared to other states. Vertically this is cosmetically acceptable and expected for a glow effect. The horizontal offset (−3 px for BUILD, +3.5 px for RESEARCH) means the two focus glows drift in **opposite directions** — a symmetry inconsistency that may be visible side-by-side.

**Recommendation:** Request a regeneration where all four states use the same canvas-center anchor. If the glow naturally extends the bounding box, that is fine — but the button body center should remain at canvas center (188, 88). The 4 px vertical glow extension is acceptable; the ±3–3.5 px horizontal drift is the correction target.

**Workaround available:** Using `expand_mode = 3` (KEEP_ASPECT_CENTERED) in the `TextureRect` or `TextureButton.STRETCH_KEEP_ASPECT_CENTERED` ensures the full 376×176 canvas is scaled uniformly, so Godot will not clip glow. The offset will still be visible but at sub-pixel magnitude after 2× downscaling.

### DEFECT-02 — Pressed state brightness low ⚠️ (minor)

The pressed states have noticeably fewer bright opaque pixels than default:

| State | Bright opaque pixels in center band |
|---|---|
| build_default | 8 261 |
| build_pressed | 3 566 (−57%) |
| research_default | 8 447 |
| research_pressed | 4 765 (−44%) |
| build_disabled | 13 435 |
| research_disabled | 10 739 |

The pressed states appear significantly darker/more subdued than disabled states. On a dark (#080F2B) background this may make the pressed state harder to perceive as a tap response rather than a disabled/unavailable state. This is a visual design concern to confirm with the designer — not a technical error.

### DEFECT-03 — No black/white background, grid artifacts, or clipped shadows ✓

No issues found. All states have clean transparent fields with smooth anti-aliased edges.

---

## 3. State Alignment Findings

- **Default, Pressed, Disabled:** Body centers are within ±1.5 px of canvas center. Consistent and production-ready from an alignment standpoint.
- **Focus states:** Body center is offset 3–3.5 px horizontally, 4 px vertically (glow expansion). The glow extends to within 3 px of the canvas edge at the top (`y=3`) — there is adequate but tight clearance.
- **Canvas dimensions are consistent** across all 8 files: all 376×176 px.

---

## 4. Scaling Recommendations

### In the test scene (`tests/ui/buttons_part01_preview.tscn`)

Use `TextureRect` with:
```
expand_mode = 3   ; KEEP_ASPECT_CENTERED
stretch_mode = 5  ; KEEP_ASPECT_CENTERED
```
Container size: **188×88 logical px** — matches the manifest's `display_canvas_px`.

### In the production HUD (`ui/screens/outpost_hud.tscn`)

Use `TextureButton` with:
```
ignore_texture_size = true          ; already set in SpriteButton._init()
stretch_mode = STRETCH_KEEP_ASPECT_CENTERED  ; already set in SpriteButton._init()
custom_minimum_size = Vector2(188, 88)       ; update from current 158×58
```

**Do NOT** set the custom minimum size to 168×60 (the visible body rect). The full 188×88 canvas must be preserved so Godot renders the glow and shadow padding. Squeezing to 168×60 would distort the artwork.

### Godot filter setting

Set texture import filter to **Linear** (default) for these buttons. The artwork uses soft anti-aliased edges and glows — Nearest-neighbour filtering would create jagged edges at display size.

---

## 5. Godot Compatibility

| Concern | Status |
|---|---|
| RGBA PNG with transparency | ✓ Compatible |
| 376×176 px canvas (power-of-4 aligned) | ✓ GPU-friendly |
| `TextureButton` state texture slots | ✓ Godot 4 supports `texture_normal`, `texture_pressed`, `texture_disabled`, `texture_focused` |
| `SpriteButton.gd` visual effects conflict | ⚠️ See below |

### SpriteButton conflict analysis

`ui/components/sprite_button.gd` currently applies code-driven visual state effects:

| Effect | Code mechanism | Conflict with new assets? |
|---|---|---|
| Hover brighten (`HOVER_TINT = 1.12×`) | `self_modulate` set on `mouse_entered` | **No conflict** — applies only on desktop/mouse; already guarded by `_touch_only` flag |
| Press squash (scale 0.94) | `create_tween` on `button_down/up` | **Minor visual overlap** — the new pressed artwork already shows visual suppression. The squash tween is still useful as a tactile response but if the pressed art is already dark enough it may feel redundant. Recommendation: keep the tween — its scale is subtle (0.94) and adds physical feel. |
| Disabled tint (`Color(0.55, 0.55, 0.65, 0.8)`) | `self_modulate` when `disabled and texture_disabled == null` | **Conflict resolved by assignment:** if you assign `texture_disabled` on the button, `SpriteButton._update_tint()` will NOT apply the code tint (see line 67: `if disabled and texture_disabled == null`). Assign the new `build_disabled.png` to `texture_disabled` and the code path is bypassed automatically. |
| Focus ring (yellow glow `StyleBoxFlat`) | `draw_style_box` in `_draw()` | **Overlaps with focus artwork.** The code draws a yellow border ring, and the new `build_focus.png` / `research_focus.png` already contain a baked glow. On touch devices the focus ring never draws (`_touch_only` guard). On desktop/keyboard, both would show simultaneously. Recommendation: **suppress the code ring when `texture_focused` is assigned** — see integration plan below. |

---

## 6. Screenshot Location

> **Visual validation via Godot screenshot could not be completed.**  
> The preview scene (`tests/ui/buttons_part01_preview.tscn`) was created for in-editor validation. Open it in Godot 4.7.2, set it as the active scene, and press **F5** (Run Current Scene) at 1280×720 to verify visual appearance.  
>
> Asset pixel analysis was performed via Python/Pillow on the raw PNGs. All automated checks passed.

---

## 7. Production Integration Plan

> ⚠️ **Do not execute until you approve the preview scene visually.**

### Step 1 — Copy new PNGs to the assets folder

```
design/incoming/MOONMINDS_BUTTONS_PART_01/buttons/build_default.png
  → assets/sprites/buttons/build.png            (replaces current 164×56 sprite)

design/incoming/MOONMINDS_BUTTONS_PART_01/buttons/build_pressed.png
  → assets/sprites/buttons/build_pressed.png    (file already exists — overwrite)

design/incoming/MOONMINDS_BUTTONS_PART_01/buttons/build_focus.png
  → assets/sprites/buttons/build_focus.png      (file already exists — overwrite)

design/incoming/MOONMINDS_BUTTONS_PART_01/buttons/build_disabled.png
  → assets/sprites/buttons/build_disabled.png   (file already exists — overwrite)

design/incoming/MOONMINDS_BUTTONS_PART_01/buttons/research_default.png
  → assets/sprites/buttons/research.png         (replaces current 163×58 sprite)

design/incoming/MOONMINDS_BUTTONS_PART_01/buttons/research_pressed.png
  → assets/sprites/buttons/research_pressed.png (new file)

design/incoming/MOONMINDS_BUTTONS_PART_01/buttons/research_focus.png
  → assets/sprites/buttons/research_focus.png   (new file)

design/incoming/MOONMINDS_BUTTONS_PART_01/buttons/research_disabled.png
  → assets/sprites/buttons/research_disabled.png (new file)
```

Godot will re-import automatically on next editor launch/focus.

### Step 2 — Update `ui/screens/outpost_hud.tscn`

Add new ext_resource entries for the state-specific textures, then assign them on both buttons:

**New ext_resource declarations:**
```gdscript
[ext_resource type="Texture2D" path="res://assets/sprites/buttons/build_pressed.png"    id="btn_build_pressed"]
[ext_resource type="Texture2D" path="res://assets/sprites/buttons/build_focus.png"      id="btn_build_focus"]
[ext_resource type="Texture2D" path="res://assets/sprites/buttons/build_disabled.png"   id="btn_build_disabled"]
[ext_resource type="Texture2D" path="res://assets/sprites/buttons/research_pressed.png" id="btn_research_pressed"]
[ext_resource type="Texture2D" path="res://assets/sprites/buttons/research_focus.png"   id="btn_research_focus"]
[ext_resource type="Texture2D" path="res://assets/sprites/buttons/research_disabled.png" id="btn_research_disabled"]
```

**BuildButton node — updated properties:**
```
[node name="BuildButton" type="TextureButton" parent="BottomBar"]
custom_minimum_size = Vector2(188, 88)      ; was 158×58
texture_normal   = ExtResource("btn_build")
texture_pressed  = ExtResource("btn_build_pressed")
texture_focused  = ExtResource("btn_build_focus")
texture_disabled = ExtResource("btn_build_disabled")
script = ExtResource("sprite_button")
```

**ResearchButton node — updated properties:**
```
[node name="ResearchButton" type="TextureButton" parent="BottomBar"]
custom_minimum_size = Vector2(188, 88)      ; was 158×58
texture_normal   = ExtResource("btn_research")
texture_pressed  = ExtResource("btn_research_pressed")
texture_focused  = ExtResource("btn_research_focus")
texture_disabled = ExtResource("btn_research_disabled")
script = ExtResource("sprite_button")
```

### Step 3 — Suppress code focus ring when artwork focus texture is assigned

In `ui/components/sprite_button.gd`, update `_draw()` to skip the code ring when a focus texture is already provided:

```gdscript
func _draw() -> void:
    # Skip code-drawn ring when the button has a baked focus texture.
    if texture_focused != null:
        return
    if has_focus() and not _touch_only and not Engine.is_editor_hint():
        var r := _art_rect()
        _focus_ring.set_corner_radius_all(int(r.size.y / 2))
        draw_style_box(_focus_ring, r)
```

This is a **minimal surgical change** (3 lines added, nothing removed) that preserves the existing behaviour for all non-focus-textured buttons (e.g. ExploreButton and EndDayButton, which have no focus artwork yet).

### Step 4 — HUD layout review

The BUILD and RESEARCH buttons grow from 158×58 to 188×88 logical px.  
- The `BottomBar` is an `HBoxContainer` centred at `anchor (0.5, 1.0)`. It will expand naturally.
- The total bottom bar width increases by 2 × 30 = 60 px. At 1280 px wide viewport this leaves comfortable margins.
- Verify visually that BottomBar does not overlap the MascotArea (bottom-left, 304 px from left) or the ExploreButton / EndDayButton layout.
- No other HUD nodes reference the BUILD or RESEARCH button sizes directly.

### Step 5 — Touch target verification

Logical button body at display: ~144–148 × 54–58 px. At **2× device scale (iPad):** 288–296 × 108–116 physical px.  
Godot's touch hitbox uses the `custom_minimum_size`/actual size of the Control, not the baked artwork. At 188×88 logical = **176–176 physical px height at 2× — well above the 44–48 pt minimum**.

### Files requiring changes (summary)

| File | Change type |
|---|---|
| `assets/sprites/buttons/build.png` | Replace |
| `assets/sprites/buttons/build_pressed.png` | Replace |
| `assets/sprites/buttons/build_focus.png` | Replace |
| `assets/sprites/buttons/build_disabled.png` | Replace |
| `assets/sprites/buttons/research.png` | Replace |
| `assets/sprites/buttons/research_pressed.png` | New file |
| `assets/sprites/buttons/research_focus.png` | New file |
| `assets/sprites/buttons/research_disabled.png` | New file |
| `ui/screens/outpost_hud.tscn` | Add ext_resource refs + assign state textures + resize to 188×88 |
| `ui/components/sprite_button.gd` | 3-line guard in `_draw()` to skip code ring when `texture_focused != null` |

**Files NOT touched:** `scenes/sim/colony_sim.gd`, gameplay signals, other UI components, `moonminds_theme.tres`, `moonminds_sprite_theme.tres`, ExploreButton, EndDayButton, CancelButton.

---

## 8. Deployment Readiness

| Check | Result |
|---|---|
| All 8 PNG files present | ✓ |
| Correct RGBA transparency | ✓ |
| No edge bleed or grid artifacts | ✓ |
| Consistent canvas dimensions (376×176) | ✓ |
| Touch targets ≥ 48 px logical | ✓ (54–58 px body, 88 px container) |
| Focus state horizontal drift | ⚠️ ±3–3.5 px — cosmetic, workaround available |
| Pressed state brightness | ⚠️ Darker than disabled — confirm intent with designer |
| Manifest marks as preliminary | ⚠️ |
| In-editor visual validation completed | ✗ — **not yet** |

### Verdict

> **NOT YET READY for production deployment.**
>
> The assets pass all automated technical checks. However:
> 1. **In-editor visual validation has not been performed.** You must open `tests/ui/buttons_part01_preview.tscn` in Godot and visually confirm all 8 states look correct on the dark background at 1280×720.
> 2. **The focus state horizontal drift** (±3.5 px) is worth reporting back to the asset designer for correction before shipping.
> 3. **The manifest itself** marks this as a preliminary iteration: `PRELIMINARY_IMAGE_GENERATED_REVIEW_REQUIRED`.
>
> Once you have approved the preview visually, the integration plan in Section 7 can be executed as-is.

---

*Report generated: 2026-11-14. No production files were modified.*
