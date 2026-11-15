# MoonMinds — UI Style Guideline

**Design system:** MoonMinds  
**Tagline:** *Build. Balance. Explore.*  
**Document type:** Visual identity, UI components, UX interaction, and implementation handoff guideline  
**Version:** 1.0  
**Language:** English  
**Audience:** Game designers, UI/UX designers, illustrators, animators, content designers, and QA reviewers  
**Primary players:** Children ages 7–12  
**Core experience:** A single-player, child-friendly 3D lunar/Martian outpost management and STEM simulation game

> **Source of truth:** This document translates the provided **MoonMinds UI Style Guide** image into a usable design specification. **Sections marked “From the visual reference”** reproduce the image's explicitly shown direction and values. **Sections marked “Recommended extension”** add production-level rules that are not depicted in the image and should be reviewed by the team before being treated as final requirements.

![MoonMinds UI Style Guide visual reference](moonminds_ui_style_guide.png)

---

## 1. Design System at a Glance

### 1.1 Product purpose

MoonMinds helps children learn the engineering trade-offs of maintaining an outpost on the Moon or Mars. Players build modules, observe resource changes, balance power/water/food/radiation protection, conduct research, and explore. The interface makes cause and effect visible without requiring prior engineering knowledge.

### 1.2 The intended feel — from the visual reference

- **Playful and polished:** A commercial-quality cartoon strategy game, not a classroom dashboard.
- **Cosmic but approachable:** Dark navy and violet spaces with high-energy blue, orange, cyan, and green accents.
- **Dimensional:** Thick, rounded silhouettes; glossy highlights; soft raised edges; subtle depth and shadows.
- **Easy to scan:** Big icons, direct labels, visible resource bars, and short messages.
- **Character-led:** A smiling robot astronaut explains systems and celebrates progress.
- **Decision-focused:** Building choices clearly show what will be used, what will improve, and the resource trade-off.

### 1.3 Design principles

1. **Show the outcome before the choice.** Players should understand a building's impact before confirming it.
2. **Make resources glanceable.** Icons, bar fill, labels, and state indicators must work together.
3. **Explain trade-offs, not punish mistakes.** Resource deficits trigger explanations and recovery paths rather than a dead end.
4. **Prioritize one next action.** The current mission, highlighted placement area, or primary button should be recognizable immediately.
5. **Keep the game world visible.** HUD and cards support the 3D outpost rather than obscuring it.
6. **Be consistent.** Color semantics, shapes, icon meanings, mascot proportions, and placement patterns must remain stable.

### 1.4 Design hierarchy

**First:** the 3D base and current build/exploration activity.  
**Second:** critical resource conditions, current mission, and available primary actions.  
**Third:** contextual building details, research information, and optional guidance.  
**Fourth:** settings, secondary utility controls, and decorative elements.

---

## 2. Visual Identity

### 2.1 Brand elements — from the visual reference

- **Wordmark:** `MOONMINDS`, uppercase, chunky, rounded, white-to-icy-blue lettering with a dark blue dimensional outline.
- **Tagline:** `Build. Balance. Explore.` displayed as a compact orange/yellow pill beneath the wordmark.
- **Mascot:** A friendly white robot astronaut with orange/yellow accents, dark face screen, bright cyan smiling eyes, and an orange `M` insignia.
- **Scene:** Stylized rocky lunar terrain, modular space habitats, solar panels, starry sky, distant planets, and a blue-violet cosmic atmosphere.
- **Illustration style:** Bright, rounded, toy-like 3D/cartoon forms; readable object silhouettes; high contrast between interactive UI and background scenery.

### 2.2 Logo usage — recommended extension

- Keep the wordmark legible at the smallest intended display size; switch to a simpler `M` emblem where necessary.
- Use the tagline on titles, landing screens, brand material, and onboarding; do **not** repeat it in every in-game panel.
- Preserve the visual relationship between the white/blue wordmark and orange tagline.
- Provide full-color, small-size, monochrome, light-background, and dark-background logo variants.
- Do not stretch, distort, recolor randomly, or place the logo over bright, noisy game objects without contrast support.

### 2.3 Art direction — from the visual reference

Rounded greenhouse domes, blue solar panels, compact water modules, orange doors, cyan windows, purple terrain shadows, and simplified laboratory equipment form the core visual vocabulary. UI elements should feel like part of the same toy-like universe as the 3D game assets.

---

## 3. Color System

### 3.1 Core palette — from the visual reference

| Token | Hex | Meaning | Primary usage |
|---|---|---|---|
| Primary Blue | `#4F6BFF` | Primary / navigation | Navigation buttons, selected controls, brand accents |
| Action Orange | `#FFB020` | Action / progress | Build actions, progression, highlighted calls to action |
| Danger Pink | `#FF4961` | Danger / critical | Critical alerts, destructive or irreversible actions |
| Success Green | `#3CDB56` | Success / healthy | Healthy systems, positive confirmation, improvements |
| Warning Yellow | `#F7C948` | Warning / attention | Resource strain, caution, next-step emphasis |
| Info Cyan | `#00C6FF` | Info / explanation | Helpful information, technology, water-coded cues |
| Dark Background | `#080F2B` | Cosmic background | Backdrops, low-level surfaces, negative space |
| Panel Background | `#1A1F48` | Modal / UI | HUD frames, overlays, modal bodies |
| Surface | `#282F6B` | Cards / areas | Cards, panel interiors, nested controls |
| Border | `#3F4BAB` | Structural borders | Card outlines, dividers, selected panel frames |

**Important semantic rule:** The visual defines **green = healthy**, **yellow = warning**, **pink = danger**, **blue = navigation**, **orange = action**, and **cyan = information**. Never change a color's meaning from screen to screen.

### 3.2 Suggested semantic token names — recommended extension

| Role | Suggested token | Value |
|---|---|---|
| Main interactive action | `color.action.primary` | `#FFB020` |
| Primary navigation | `color.navigation.primary` | `#4F6BFF` |
| Positive system state | `color.state.healthy` | `#3CDB56` |
| Caution state | `color.state.warning` | `#F7C948` |
| Critical state | `color.state.critical` | `#FF4961` |
| Informational state | `color.state.info` | `#00C6FF` |
| World backdrop | `color.background.space` | `#080F2B` |
| Primary panel fill | `color.surface.panel` | `#1A1F48` |
| Nested content surface | `color.surface.card` | `#282F6B` |
| Panel edge | `color.border.default` | `#3F4BAB` |
| Primary readable text | `color.text.primary` | `#FFFFFF` (proposed, visible in the reference but not separately specified) |

### 3.3 Color application

**Backgrounds:** Start with Dark Background; use Panel Background and Surface to establish depth and hierarchy.  
**Actions:** Use orange for the single primary task action, not every clickable control.  
**Navigation:** Use blue for moving between gameplay modes or destinations.  
**Feedback:** Use green, yellow, pink, or cyan based on meaning; accompany them with an icon and readable message.  
**Progress:** A green bar can indicate a healthy resource. Warnings may require a yellow state indicator even when the bar is predominantly cyan or blue.  
**Water:** A cyan droplet may be used as the resource identity independently of warning or success states.

### 3.4 Gradients, elevation, and outlines — recommended extension

The reference uses soft gradients, dimensional shading, bright top-edge highlights, and dark shadows rather than flat rectangles. Replicate this style without excessively bright glow.

- Keep gradients within the relevant semantic color family; avoid unrelated rainbow gradients.
- Use a darker lower edge and subtle highlight on raised buttons.
- Give major panels a soft outer shadow and clearly defined blue/violet rim.
- Reserve strong glow for focused controls, placement validity, rewards, or important guidance.
- Ensure the readable label remains high contrast regardless of highlight or overlay.

**Accessibility note:** These are palette inputs, not a guarantee of readable combinations. Test actual text/background pairings. See Section 13.

---

## 4. Typography

### 4.1 Typefaces — from the visual reference

**Fredoka** is the expressive display font for titles, large headings, primary buttons, and prominent game labels.  
**Poppins** is the readable support font for body copy, descriptions, UI labels, tooltips, and resource details.

### 4.2 Type scale — from the visual reference

| Text style | Size | Font | Use |
|---|---:|---|---|
| H1 | **36 px** | Fredoka | Screen title, brand/hero-level heading |
| H2 | **24 px** | Fredoka | Major panel or section heading |
| H3 | **18 px** | Fredoka | Card title, module name |
| Body | **16 px** | Poppins | Educational descriptions and general content |
| Caption | **14 px** | Poppins | Resource explanation, support labels, secondary notes |

The image uses the examples **“MoonMinds,” “Build Your Base,” “Greenhouse,” “Grow food for your crew,”** and **“Requires water and power.”**

### 4.3 Type rules — recommended extension

- Prefer regular-to-semibold Poppins for body text and semibold-to-bold Fredoka for titles and primary actions.
- Use sentence case for descriptions and mixed-case headings; reserve uppercase for short, visually expressive labels where readability is preserved.
- Keep line length short in dialogue bubbles and cards; use a simple sentence whenever possible.
- Make UI text scalable. Avoid shrinking body text below the visual reference's 16 px simply to fit a panel.
- Maintain generous line height for learning content: approximately 1.35–1.5 for body text and 1.15–1.3 for headings.
- Support longer text in localization without clipping labels or losing button meaning.
- Never communicate a crucial outcome using decorative text alone.

---

## 5. Layout, Spacing, Shape, and Depth

### 5.1 Dimensional rules — from the visual reference

| Property | Visual reference value |
|---|---|
| Grid / spacing increment | **8 px** |
| Card, panel, and popup corner radius | **20 px** |
| Button corner radius | **16 px** |
| Minimum interactive touch target | **48 px or larger** |
| Content inset | **Safe margin** around the screen, with no fixed numeric inset specified |

### 5.2 Recommended spacing scale

Derived from the image's 8 px grid; additional usage guidance is proposed below.

| Spacing | Suggested use |
|---:|---|
| 8 px | Icon-to-label micro-gap, compact control spacing |
| 16 px | Standard card padding, small panel gap |
| 24 px | Section padding, major component separation |
| 32 px | Large modal margins, HUD-to-world breathing room |
| 40–48 px | Distinct section separation on spacious screens |

### 5.3 Layout logic — from the visual reference

The illustrated primary game screen contains:

1. A **top resource HUD** with compact bars, mission-day indicator, and settings.
2. A **left mission/objective panel** that communicates the current goals.
3. A large **central 3D outpost scene** with interactable structures and a highlighted build-placement grid.
4. A **bottom action row** with `BUILD`, `RESEARCH`, and `EXPLORE`.
5. A contextual **right-side build confirmation panel**.
6. A **mascot callout** near the lower-left scene, presenting short next-step guidance.

This is the preferred composition for the outpost-management view; other screens may adapt it without changing component semantics.

### 5.4 Safe-area and responsiveness — recommended extension

- Start from a **landscape-first** composition matching the wide visual reference.
- Keep primary controls inside the device/platform safe area and clear of rounded screen corners, notches, and OS overlays.
- Treat **24–32 px screen insets** as a provisional desktop/tablet starting point, subject to screen size and usability testing; the reference does **not** assign this number.
- Ensure mission and building-detail panels can collapse, stack, or replace each other if the viewport is narrow.
- Do not scale the entire HUD down uniformly until text becomes unreadable; reflow or simplify secondary content first.
- The game world should remain visually identifiable behind open UI, especially when choosing building placement.
- Avoid covering the selected building with a popup if the panel can dock alongside it.

---

## 6. Buttons and Interactive States

### 6.1 Button families — from the visual reference

| Variant | Label example | Core treatment | Meaning |
|---|---|---|---|
| Primary action | `BUILD` | Orange, raised, rounded | Execute key current action |
| Secondary / navigation | `EXPLORE` | Blue, rounded | Change mode or navigate |
| Danger / cancel-themed action | `CANCEL` | Pink/red in the component showcase | Exit/cancel or caution-based action in the illustrated palette |
| Icon-only | Settings gear | Purple/blue square-rounded button | Compact utility action |

**Usage clarification:** The visual uses a pink `CANCEL` example to demonstrate a danger-colored button family. For real interactions, *non-destructive* Cancel/Back should normally use a lower-emphasis neutral or blue treatment; reserve danger pink for destructive or genuinely critical actions. This is a **recommended UX refinement**, not a change to the reference artwork.

### 6.2 Button states — from the visual reference

Every visible button variant is shown in four states:

- **Default:** Clearly interactive raised form.
- **Pressed:** Darker/depressed form with immediate tactile feedback.
- **Disabled:** Muted fill and reduced visual emphasis.
- **Focus:** Bright glow/ring to indicate current selection.

### 6.3 Production behavior — recommended extension

- Provide `hover` on cursor-enabled platforms in addition to the four shown states.
- Never use color alone to explain disabled or critical actions; pair state with contrast, label, and/or icon.
- Make the clickable area at least **48 × 48 px** at the intended UI scale.
- Prefer a short verb label: `Build`, `Research`, `Explore`, `Try Again`, `View Resources`.
- Give only one action per decision panel the primary orange treatment.
- Keep button labels unchanged between focus and pressed states.
- Provide a way to go back or dismiss a modal without losing important progress.
- For disabled actions, say *why* and *what to do next*: “Need more power. Add a solar panel first.”

---

## 7. Cards, Panels, Popups, and Feedback

### 7.1 Building card anatomy — from the visual reference

The illustrated **Greenhouse** card contains:

1. A large, recognizable greenhouse image.
2. A bold module name: `Greenhouse`.
3. Resource effects expressed with icons and labels.
4. Positive benefit: more food.
5. Trade-offs: water and power consumption.
6. A clearly visible orange `BUILD` button.

**Rule:** Building cards must show the *benefit* and the *cost* together; do not describe only the positive outcome.

### 7.2 Positive and warning feedback — from the visual reference

**Positive feedback:**

> **Great balance!**  
> Your resources are well balanced!

Style: green-tinted speech panel, checkmark, happy robot mascot.

**Warning feedback:**

> **Need more power!**  
> This building will increase your food, but it also uses more power.

Style: yellow-tinted speech panel, warning triangle, concerned/explanatory robot mascot.

### 7.3 Message hierarchy — recommended extension

| Type | Color / icon | Example | Player response |
|---|---|---|---|
| Success | Green + check | “Your water system is working!” | Continue |
| Info | Cyan + info | “Solar panels make power in sunlight.” | Understand |
| Warning | Yellow + warning | “Your greenhouse needs more water.” | Review choices |
| Critical | Pink + alert | “Power is too low for this module.” | Adjust system safely |

A warning should communicate (a) **what changed**, (b) **why it matters**, and (c) **what the player can try**.

### 7.4 Modal anatomy — from the visual reference

The illustrated `Build Greenhouse?` popup has:

- Clear title with a close button.
- A central module illustration.
- **Will Use:** water and power.
- **Will Improve:** more food.
- **Trade-off:** higher water usage.
- Distinct `CANCEL` and orange `BUILD` actions.

### 7.5 Popup and card behavior — recommended extension

- Do not open multiple blocking dialogs at once.
- Preserve readable context: selected module, expected effects, and available action.
- Use a simple visual before/after comparison if resources are significantly affected.
- Keep warning text supportive rather than punitive.
- Use a fixed structure for build/research/upgrade previews to reduce the learning curve.
- Give reward notifications short durations and permit skipping animations.

---

## 8. Icons and Illustrations

### 8.1 Iconography — from the visual reference

The visual shows dimensional cartoon icons for:

- Solar Panel
- Habitat Module
- Greenhouse
- Water System
- Lab / Research

The HUD uses clear small symbols for power (lightning), water (droplet), food (sprout), radiation protection (shield), and day count (calendar). Mission goals use a target; settings use a gear.

### 8.2 Icon principles — recommended extension

- Use **rounded, slightly three-dimensional, high-recognition silhouettes** with controlled blue/cyan highlights and orange accents.
- Make each icon understandable without needing to read its label, but always provide a label where space permits.
- Keep a consistent perspective, outline weight, shadow depth, and material appearance.
- Ensure an icon retains its meaning at HUD size as well as card size.
- Use resource colors consistently: cyan droplet for water, yellow lightning for power, green sprout for food, and yellow/purple shield for radiation protection.
- For placement, use a simplified recognizable module silhouette rather than a dense detailed thumbnail.
- Avoid photorealistic imagery, emoji-only production assets, mixed illustration techniques, and overloaded icons.

### 8.3 Icon states — recommended extension

Define default, selected, unavailable, warning, and rewarded/unlocked versions. Selection should be apparent through outline/shape/contrast, not only a hue change.

---

## 9. Mascot System

### 9.1 Appearance — from the visual reference

The MoonMinds guide is a small robot astronaut with:

- A white rounded helmet/body.
- A dark navy face display.
- Bright cyan eyes with expressive curved shapes.
- Orange/yellow detailing and an `M` on its chest.
- Friendly waving, thumbs-up, and explanatory gestures.

### 9.2 Role — from the visual reference

The mascot:

1. Gives hints.
2. Explains engineering trade-offs.
3. Celebrates progress.

### 9.3 Mascot behavior — recommended extension

| Moment | Facial/gestural state | Example copy |
|---|---|---|
| First-time tutorial | Excited, waving | “Let's build your first home on the Moon!” |
| Neutral suggestion | Curious, pointing | “Want more food? Try a greenhouse.” |
| Resource warning | Concerned but calm | “This building uses power. Let's check our supply.” |
| Balanced system | Cheerful, thumbs-up | “Nice work! Your systems are in balance.” |
| Experiment/recovery | Encouraging | “That didn't work yet. Let's try another solution!” |
| Milestone | Celebrating | “You unlocked a new research module!” |

**Guardrail:** The mascot must never shame the player. It must make trade-offs understandable and offer a next step. Avoid excessive interruptions during active building or exploration.

---

## 10. Resource HUD and System Status

### 10.1 HUD elements — from the visual reference

The persistent management HUD includes:

| Resource | Icon | Example treatment |
|---|---|---|
| Power | Yellow lightning bolt | Labeled bar with green healthy fill |
| Water | Cyan droplet | Labeled bar with cyan fill |
| Food | Green sprout | Labeled bar with green fill |
| Radiation Protection | Yellow/purple shield | Labeled bar, protective status visible |
| Mission Day | Calendar | Separate high-contrast numeral, shown as **12** in the image |

The reference also shows state chips: **Healthy**, **Warning**, and **Critical**.

### 10.2 Semantic interpretation — recommended extension

- **Power, water, food:** Higher available supply is usually better relative to demand and upcoming consumption.
- **Radiation Protection:** A higher protection level is usually safer. Never style it in a way that confuses *radiation exposure* with *radiation protection*.
- A single numeric percentage should **not** automatically determine health. Compare resources against current consumption and operating requirements.
- Pair every bar with a resource name, icon, and optional exact value on expanded view.
- Make a critically low system visible through an icon/message in addition to color.
- Keep resource order consistent across management, build preview, and educational explanations.

### 10.3 HUD density — recommended extension

Use a compact persistent summary; provide detail in a contextual panel when selected. Do not show engineering formulas, multiple decimals, or unrelated resources in the default view. The child should answer “Are we okay?” within a glance.

### 10.4 Change previews — recommended extension

On a greenhouse build preview, visibly show:

- **Uses:** water + power.
- **Improves:** food production.
- **Trade-off:** increased water/power demand.
- **Result:** forecasted change to relevant bars.

Do not silently deduct resources after confirmation; animate the changes and explain them.

---

## 11. Screens and Information Architecture

### 11.1 Screen families — from the reference and project brief

The image explicitly depicts the **Outpost Management** view with resource HUD, mission objectives, build placement, mascot prompt, bottom mode actions, and a building confirmation popup. The following screen inventory extends this composition to the rest of MoonMinds.

| Screen | Main user goal | Required UI |
|---|---|---|
| Start / Main Menu | Begin or continue the adventure | MoonMinds identity, mascot, large Play/Continue action |
| Mission Introduction | Understand current objective | Mission title, short story prompt, one clear next action |
| Outpost Management | Observe and operate the base | 3D world, HUD, mission panel, Build/Research/Explore navigation |
| Build Mode | Select and place a module | Module cards, valid placement highlight, resource cost/benefit preview |
| Build Confirmation | Decide with full context | Module illustration, Will Use, Will Improve, Trade-off, Cancel/Build |
| Research | Understand and unlock technology | Research cards, simple prerequisites, benefit explanation, progress |
| Explore / Mission Map | Choose a destination or mission | Large destination visuals, mission suitability and expected learning |
| Mission Event | Respond to a new condition | Friendly event story, consequence, 2–3 meaningful options if needed |
| Result / Learning Feedback | Understand cause and effect | System change, short explanation, suggested next step |
| Achievement / Progression | Recognize improvement | Reward, unlocked item, celebration, Continue |
| Settings / Accessibility | Adjust the experience | Sound, text, motion, readability, controls and accessibility options |

### 11.2 Outpost screen zoning

```text
┌───────────────────────────────────────────────────────────┐
│ RESOURCE HUD: POWER | WATER | FOOD | SHIELD | DAY | SETTINGS │
├──────────────┬────────────────────────────────────────────┤
│ CURRENT      │                                            │
│ MISSION      │              3D OUTPOST WORLD              │
│              │       MODULES + PLACEMENT HIGHLIGHT        │
│ Short goals  │                                            │
│              │                            [BUILD PREVIEW] │
│ MASCOT HINT  │                                            │
├──────────────┴────────────────────────────────────────────┤
│                   BUILD | RESEARCH | EXPLORE                │
└───────────────────────────────────────────────────────────┘
```

*Diagram is schematic, not a pixel-accurate reconstruction.*

### 11.3 Navigation rules — recommended extension

- Preserve Build / Research / Explore as the three principal management actions.
- Use a persistent visual indication for the selected mode.
- Do not bury the current mission behind secondary menus.
- Keep primary navigation in stable positions during gameplay.
- Return the player to the previous context after confirming or cancelling a building decision.
- Favor progressive disclosure: the default screen teaches enough to play; detailed science appears on demand.

---

## 12. In-World 3D UI and Placement Feedback

### 12.1 Scene direction — from the visual reference

- Lunar ground with stylized rocks, dusty blue-violet shadows, and clear module separation.
- Rounded habitat modules, transparent greenhouse domes, solar panel arrays, water machinery, and labs.
- A visible square-based **green build-placement area** in the central world.
- A 3D/cutaway presentation that reveals the activity inside selected buildings.
- UI stays legible against the outpost environment through dark panels and framed cards.

### 12.2 Placement behavior — recommended extension

- **Valid location:** Green-highlighted ground tiles and a clear module preview.
- **Needs adjustment:** Yellow or pattern-based cue with a reason such as “Requires an open tile.”
- **Unavailable location:** Pink/neutral blocked cue and a short explanation; never rely on red alone.
- **Selected building:** Strong silhouette outline or highlight with contextual information.
- **Completed placement:** Brief construction animation, followed by visible changes to HUD resources.
- **Recoverability:** Allow simple move, edit, or undo where game rules permit, particularly in tutorial stages.

### 12.3 Game-world readability — recommended extension

3D detail must never obscure the action. Keep silhouettes clear at the default camera distance; reduce visual noise around selected modules; limit simultaneous callouts; and avoid moving decorative objects behind critical text.

---

## 13. Accessibility and Inclusive Design

**This entire section is a recommended production extension**; the reference image specifies large touch targets and readable layout but does not certify any accessibility conformance.

### 13.1 Text and contrast

- Target **WCAG 2.2 AA** contrast where applicable: at least **4.5:1** for normal text and **3:1** for large text and important graphical UI indicators.
- Verify button labels against **actual gradient states**, not just the base palette values.
- Avoid yellow-on-white and low-contrast cyan-on-bright-blue labels.
- Add backing surfaces, outlines, or shadows when text overlaps 3D scenery.
- Let players increase text size while keeping important controls visible.

### 13.2 Color and perception

- Encode Healthy / Warning / Critical using **color + icon + short text**.
- Resource bars must be distinguishable by icon/label even in grayscale.
- Use shapes, patterns, and/or icons to indicate valid/invalid placement.
- Ensure both warm and cool accent colors remain distinguishable on dark panels.

### 13.3 Motor and navigation access

- Keep touch/click targets **48 px or larger**, as stated in the visual reference.
- Provide noticeable focus states for keyboard or controller navigation.
- Avoid requiring precise drag operations as the only way to perform a core action; offer discrete selection/placement alternatives where feasible.
- Provide forgiving hit areas for small structures, particularly when they are near one another.
- Do not require rapid response or complex simultaneous inputs to recover from resource warnings.

### 13.4 Cognitive accessibility and age appropriateness

- Present one important decision at a time.
- Use short verbs, familiar vocabulary, and pictorial examples.
- Explain new science terms in context rather than placing definitions in dense dialogs.
- Offer repeatable tutorial instructions and optional hint replay.
- Prefer explicit feedback like “Water went down because the greenhouse uses water” over abstract “-10 efficiency” penalties.
- A failed experiment is a learning moment, not a game-over screen.

### 13.5 Motion and audio preferences

- Support reduced motion or an equivalent low-animation setting.
- Never make an action understandable only through animation or sound.
- Offer sound/music controls and subtitle or text equivalents for spoken guidance.
- Avoid intense flashing, aggressive warning animation, or repeated startling audio cues.

---

## 14. Motion and Interaction Feedback

**Recommended extension based on the visual's dimensional, rewarding aesthetic.**

| Event | Suggested animation | Purpose |
|---|---|---|
| Button press | Short downward compression and highlight shift | Confirms input |
| Mode change | Soft transition and selected-state glow | Maintains orientation |
| Resource change | Brief bar movement with concise delta indicator | Shows causality |
| Building placement | Preview snap and short construction flourish | Rewards decisions |
| Success | Small star sparkle and happy mascot gesture | Celebrates progress |
| Warning | Gentle pulse / icon appearance, then static state | Attracts attention without alarm |
| New research | Simple reveal animation | Communicates unlock |
| Mission transition | Planet/starfield wipe or soft zoom | Connects space-adventure narrative |

**Suggested timing bands (to be validated):** 100–180 ms for press feedback, 180–300 ms for panel transitions, 300–600 ms for small positive effects. Make nonessential motion skippable.

---

## 15. UX Writing and Educational Feedback

### 15.1 Voice

Curious, encouraging, simple, and empowering. Speak as a supportive mission guide, not a strict instructor. Give direct reasons and opportunities to experiment.

### 15.2 Content pattern

**Observation → Cause → Next action**

- **Observation:** “Your power is running low.”
- **Cause:** “The greenhouse and water system both need electricity.”
- **Next action:** “Try adding a solar panel.”

### 15.3 Language rules

- Prefer everyday words first; introduce one technical term at a time.
- Name the relevant resource or system explicitly.
- Avoid blame: do not use “You failed,” “Wrong answer,” or “Bad choice.”
- Use action verbs on buttons: `Build`, `Move`, `Repair`, `Explore`, `Continue`.
- Put the educational reason into a one- or two-sentence supporting explanation.
- Let curious players access an optional “Why?” explanation for deeper STEM learning.

### 15.4 Example copy set — recommended extension

| Situation | Suggested copy |
|---|---|
| Build preview | “A greenhouse grows food, but it needs water and power.” |
| Low water | “We need more water for our plants. Can we save or recycle some?” |
| Insufficient power | “This module needs more electricity. Let's improve our power supply.” |
| Safe experiment | “Try a different setup and see what changes!” |
| Research unlocked | “Great discovery! You can now improve your water system.” |
| Balanced outpost | “Amazing work! Your base has enough power, water, and food.” |

---

## 16. Screen-Level UI Examples

### 16.1 Building a greenhouse

**Entry:** The player taps `BUILD` and selects a Greenhouse card.  
**Preview:** The card shows a greenhouse image and uses/improves/trade-off icons.  
**Placement:** A green grid indicates a valid available footprint.  
**Confirmation:** `Build Greenhouse?` presents `Will Use`, `Will Improve`, and `Trade-off`.  
**Action:** An orange `BUILD` button confirms; `CANCEL` returns to the prior context.  
**Outcome:** The module appears, affected resource bars update, and the mascot offers a friendly explanation.

### 16.2 A resource warning

**Trigger:** Current production cannot meet anticipated demand.  
**HUD:** The corresponding resource receives Warning or Critical state treatment.  
**Message:** The mascot says what is missing and which module is involved.  
**Resolution:** The player can build, adjust, research, or return to a safer prior setup.  
**Learning:** The game connects the corrective action to its effect on the system.

### 16.3 Successful balance

**Trigger:** The outpost maintains its target operating conditions.  
**Feedback:** A green check and short “Great balance!” message, with a thumbs-up mascot.  
**Progression:** Invite the player to proceed to the next mission, explore, or try an optional improvement.

---

## 17. Component Inventory and Required Specifications

**Recommended extension.** A production design library should contain the following components, each with named sizes, variants, states, spacing, anatomy, and usage notes.

| Component | Required variants/states | Content/accessibility requirements |
|---|---|---|
| Button | Primary, secondary, danger, neutral, icon-only; default/pressed/focus/disabled (+ hover where relevant) | Action label, large hitbox, disabled reason |
| Resource bar | Normal, healthy, warning, critical; compact/expanded | Resource icon, label, value/status, expected-change preview |
| Status chip | Healthy, Warning, Critical, Info | Icon + text, not color alone |
| Building card | Available, selected, unavailable, unlocked | Module art, name, uses/improves/trade-off, action |
| Mission card | Active, complete, pending | Short goal, recognizable task icon, completion state |
| Popup | Confirmation, educational, alert, reward | Title, summary, explanation, primary/secondary action |
| Mascot bubble | Hint, warning, success, exploration | Expression, concise copy, dismiss/replay behavior |
| Navigation tab | Selected, available, unavailable | Icon + label, clear current state |
| Icon button | Settings, close, back, information | Name or accessible label, 48 px target |
| Placement indicator | Valid, unavailable, selected | Visual outline, optional pattern, clear consequence |
| Progress/achievement | In progress, unlocked, completed | Goal, progress, reward explanation |
| Tooltip | First-use, contextual help, advanced info | Short explanation, controllable dismissal |
| Empty/loading state | Loading, no item, no task | Friendly explanation, useful next action |

### 17.1 Component documentation template

For every new UI component, capture:

- Component name and purpose.
- Screenshot or illustration.
- Anatomy and content structure.
- Design tokens used.
- Dimensions, padding, and minimum target size.
- Default/selected/pressed/disabled/focus/error states.
- Behavior in different screen sizes.
- Keyboard/controller/touch interactions where relevant.
- Accessibility label, reading order, and icon alternatives.
- Approved examples, anti-patterns, and ownership/version.

---

## 18. Asset Production and Design Handoff

**Recommended extension.** Keep the source artwork, UI components, in-world objects, and motion assets consistent across production.

### 18.1 Asset groups

1. **Brand:** wordmark, tagline lockup, `M` emblem.
2. **Mascot:** standard pose, wave, explain, concern, celebrate, idle.
3. **Resources:** power, water, food, shield, mission-day icons.
4. **Modules:** habitat, solar panel, greenhouse, water system, research lab, radiation protection.
5. **UI components:** buttons, tabs, progress bars, cards, popups, mission lists, speech bubbles.
6. **World effects:** placement tiles, selection outline, construction flourish, resource impact effects.
7. **Progression:** research unlocks, badges, milestone effects, mission completion art.

### 18.2 Handoff checklist

For each screen or component, deliver:

- Intended player goal and interaction sequence.
- Component states and layout constraints.
- Token references instead of arbitrary replacement colors.
- Readable text and localization constraints.
- Expected resource effects or mission-state dependencies.
- Transition/motion descriptions where relevant.
- Accessibility and content QA notes.
- Reference to the mascot expression and necessary art variants.

### 18.3 Consistency requirements

Do not mix realistic control-room elements with the friendly 3D cartoon system. Keep outlines, soft shading, blue-violet panels, glow behavior, and icon perspective consistent. All new screens should look like they belong to the provided MoonMinds reference image.

---

## 19. Do and Don't

| Do | Don't |
|---|---|
| Keep the central outpost visible during play | Cover most of the game world with permanent panels |
| Explain both gains and consumption before building | Reveal resource costs only after confirmation |
| Use Fredoka for prominent headings and buttons | Use many unrelated display fonts |
| Use Poppins for readable learning content | Compress explanatory text into tiny labels |
| Use 8 px spacing increments and rounded containers | Introduce arbitrary spacing and sharp SaaS-style cards |
| Show icons, state labels, and bars together | Use only color to indicate resource danger |
| Make feedback constructive and actionable | Punish experimentation with abrupt game-over loops |
| Keep the mascot appearance and voice consistent | Change robot design between screens |
| Reserve orange for the primary action | Make every button the same visual priority |
| Pair 3D cartoon environments with cohesive UI art | Use photorealistic NASA-like control-room panels |

---

## 20. Design QA Acceptance Checklist

Use this checklist before approving a screen or component.

### Visual fidelity

- [ ] Uses the ten colors in Section 3 with correct semantic meaning.
- [ ] Uses Fredoka and Poppins with the reference type scale.
- [ ] Uses the 8 px grid, 20 px panel radius, and 16 px button radius as appropriate.
- [ ] Uses cartoon dimensional iconography and cohesive shadows/edges.
- [ ] Retains the recognizable MoonMinds mascot design.
- [ ] Feels like a polished, child-friendly game—not a productivity dashboard.

### Usability

- [ ] The primary action is identifiable at a glance.
- [ ] Touch/click targets are at least 48 px in the intended scale.
- [ ] States are clear: default, pressed, focus, and disabled.
- [ ] The current mission and resource summary are discoverable.
- [ ] The 3D base remains visible and understandable.
- [ ] The screen has a clear way to continue, cancel, or go back.

### Educational behavior

- [ ] A decision shows its costs, benefits, and trade-offs.
- [ ] Resource changes receive understandable feedback.
- [ ] Warning messages explain causes and recovery options.
- [ ] Progress is celebrated without shaming unsuccessful experiments.
- [ ] Content is age-appropriate for children ages 7–12.

### Accessibility

- [ ] Information does not depend on color alone.
- [ ] Body text and UI graphics have sufficient verified contrast.
- [ ] Controls have visible focus and adequate interactive size.
- [ ] Text remains readable when resized or localized.
- [ ] Important information is available without motion or sound.

---

## 21. Non-Negotiable Reference Values

The following values are **directly specified by the MoonMinds UI Style Guide image** and should not be silently changed by future screens:

| System | Reference rule |
|---|---|
| Primary | `#4F6BFF` |
| Action | `#FFB020` |
| Danger | `#FF4961` |
| Success | `#3CDB56` |
| Warning | `#F7C948` |
| Info | `#00C6FF` |
| Dark background | `#080F2B` |
| Panel background | `#1A1F48` |
| Surface | `#282F6B` |
| Border | `#3F4BAB` |
| Display typeface | Fredoka |
| Body typeface | Poppins |
| Type sizes | H1 36 px, H2 24 px, H3 18 px, Body 16 px, Caption 14 px |
| Grid | 8 px |
| Card/panel/popup radius | 20 px |
| Button radius | 16 px |
| Touch target | 48 px minimum |
| Core modes | Build, Research, Explore |
| Permanent HUD | Power, Water, Food, Radiation Protection, Mission Day |
| Feedback | Healthy, Warning, Critical; with encouraging mascot guidance |
| Primary gameplay | Child-friendly 3D lunar outpost with module placement and contextual build decisions |

> **Final design criterion:** Each MoonMinds interface should help a child understand **what will happen, what the action uses, what improves, and what trade-off follows**—while remaining visually delightful and easy to operate.

---

**MoonMinds — Build. Balance. Explore.**
