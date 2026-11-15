# MoonMinds — Görsel Üretim Promptları (ChatGPT)

## Neden pikselli görünüyor?
Mevcut PNG'ler bir atlas görselinden kesilmiş ve çok küçük: ikonlar ~50×50 px, maskot ~150 px,
logo 403×141 px. Oyun ekranda 2–3 kat büyütülerek çizildiği için (özellikle Retina ekranda) bulanık ve pikselli duruyorlar.
Yeni görseller **en az 1024 px** olacak; Godot onları küçültürse netlik korunur.

## Nasıl kullanılır
1. ChatGPT'de **yeni bir sohbet** aç ve önce aşağıdaki **ANA STİL PROMPTU**'nu gönder.
   ("Understood" desin, henüz görsel üretmesin.)
2. Sonra listeden **her seferinde tek bir** asset promptunu gönder. Aynı sohbette devam et ki stil tutarlı kalsın.
3. Her görseli **PNG** olarak indir, dosya adını listedeki gibi koy, bana gönder.
4. Bir görsel stile uymadıysa: "Regenerate. Follow the MoonMinds style rules strictly: thicker outline, flatter shading, transparent background." yaz.

> Butonlar, paneller ve konuşma balonları **görsel olarak üretilmeyecek**; onları kodda (Godot tema) çiziyorum,
> böylece her boyutta keskin kalıyorlar. Sadece aşağıdaki ikon, bina, maskot ve logo lazım.

---

## ANA STİL PROMPTU (önce bunu gönder)

```
You are producing game UI assets for "MoonMinds", a kids' (ages 7–12) lunar-outpost strategy game.
The UI design language is inspired by polished mobile tower-defense games: chunky, bold, toy-like, instantly readable at small sizes.
For every image I request in this chat, follow ALL of these rules strictly. Do not generate anything yet, reply only "Understood".

STYLE RULES
1. Rendering: clean 2D vector-style cartoon illustration with soft 3D volume (cel-shaded). NOT pixel art, NOT photoreal, NOT painterly, NO noise/grain/texture.
2. Outline: every object has one thick, uniform dark-navy outer outline (#0B1236), about 6% of the image width. Inner detail lines are thinner (about half).
3. Shading: exactly 2 tones per color (base + darker shade on the bottom-right) plus ONE glossy white highlight on the top-left. No soft airbrush gradients.
4. Light source: always top-left.
5. Palette (use only these plus white and the navy outline):
   Royal blue #4F6BFF, Violet #6B5CFF, Orange #FFB020, Yellow #FFD84A, Green #3CDB56,
   Cyan #3EC8FF, Red/Coral #FF4961, Lunar grey #B8BCD6, Dark navy #0B1236.
6. Shapes: rounded, chunky, slightly exaggerated proportions; no thin spikes or tiny details that disappear when the image is shrunk to 48×48 px.
7. Composition: ONE single object, centered, filling ~84% of the canvas, with equal empty padding on all sides. Front view or slight 3/4 view as specified.
8. Background: fully TRANSPARENT (PNG with alpha). No background color, no floor, no cast shadow, no glow, no frame, no circle behind the object unless I ask for it.
9. NO text, letters or numbers inside the image unless I explicitly ask for them.
10. Canvas: square 1024×1024 unless I specify otherwise.
11. Consistency: every asset must look like it belongs to the same icon set — same outline thickness, same shading, same highlight style.
```

---

## 1) HUD ve arayüz ikonları — her biri 1024×1024, şeffaf arka plan

Her satırı ayrı ayrı gönder. Format: `Create asset: <açıklama>`

| Dosya adı | Prompt |
|---|---|
| `icon_health.png` | `Create asset: a plump glossy red/coral (#FF4961) heart with a small white heartbeat (ECG) line across its center. Front view.` |
| `icon_food.png` | `Create asset: a fresh green (#3CDB56) sprout with two big rounded leaves growing from a tiny brown soil mound. Front view.` |
| `icon_water.png` | `Create asset: a single big glossy cyan (#3EC8FF) water droplet, rounded bottom, pointed top. Front view.` |
| `icon_energy.png` | `Create asset: a chunky yellow-orange (#FFD84A to #FFB020) lightning bolt, thick zig-zag shape, slightly tilted. Front view.` |
| `icon_oxygen.png` | `Create asset: a round cyan (#3EC8FF) bubble badge with the bold white text "O2" (the 2 as small subscript) in its center. Text IS allowed for this one.` |
| `icon_clock.png` | `Create asset: a round royal blue (#4F6BFF) stopwatch with a white face, two navy hands and a small button on top. Front view.` |
| `icon_settings.png` | `Create asset: a chunky white gear/cog with 8 rounded teeth and a royal blue (#4F6BFF) center hole. Front view.` |
| `icon_checklist.png` | `Create asset: a clipboard with a yellow (#FFD84A) clip, white paper and three rows; first two rows have green check marks, third is an empty box. Front view.` |
| `icon_search.png` | `Create asset: a magnifying glass with a thick orange (#FFB020) handle and a light-cyan glass lens with a white shine. Tilted 45°, handle bottom-right.` |
| `icon_explore.png` | `Create asset: a cartoon white rocket with a coral (#FF4961) nose cone and fins, round blue window, small orange flame at the bottom. Tilted 45° pointing top-right.` |
| `icon_build.png` | `Create asset: a chunky construction hammer, grey steel head, orange (#FFB020) wooden handle. Tilted 45°, head top-left.` |
| `icon_add.png` | `Create asset: a round green (#3CDB56) circle badge with a bold white plus sign. Front view.` |
| `icon_remove.png` | `Create asset: a round red (#FF4961) circle badge with a bold white minus sign. Front view.` |
| `icon_info.png` | `Create asset: a round royal blue (#4F6BFF) circle badge with a bold white lowercase "i". Text IS allowed for this one.` |
| `icon_warning.png` | `Create asset: a rounded-corner yellow (#FFD84A) warning triangle with a bold navy exclamation mark. Front view.` |
| `icon_critical.png` | `Create asset: a round red (#FF4961) circle badge with a bold white exclamation mark. Front view.` |
| `icon_check.png` | `Create asset: a rounded white square checkbox with a big bold green (#3CDB56) check mark overflowing the top-right corner. Front view.` |
| `icon_box.png` | `Create asset: an empty rounded white square checkbox, thick navy outline, nothing inside. Front view.` |
| `icon_close.png` | `Create asset: a round red (#FF4961) circle badge with a bold white X. Front view.` |

---

## 2) Bina görselleri — her biri 1024×1024, şeffaf arka plan, 3/4 izometrik görünüm

Ön ek (her birinin başına koy):
`Create asset: isometric 3/4 view (camera from front-left, 30° above), a lunar base building, standing on a small round grey metal pad.`

| Dosya adı | Prompt devamı |
|---|---|
| `building_greenhouse.png` | `A half-cylinder glass greenhouse with a light-cyan transparent dome and white ribs, rows of bright green plants visible inside, orange (#FFB020) base frame.` |
| `building_habitat.png` | `A white cylindrical habitat module with round blue windows, orange (#FFB020) ring bands and a small round door.` |
| `building_main_base.png` | `The main outpost: a large white dome with a small satellite dish on top, connected to a short white tube corridor, orange accent bands, glowing light-blue windows.` |
| `building_research_lab.png` | `A white rounded lab building with a big royal blue (#4F6BFF) observation dome and a small antenna; one round window.` |
| `building_solar_panel.png` | `A tilted solar array: two dark royal blue grid panels on a white metal stand.` |
| `building_water_system.png` | `A white cylindrical water tank with a cyan (#3EC8FF) water level window band and a short pipe on the side.` |

---

## 3) Maskot pozları — her biri 1024×1024, şeffaf arka plan

Ön ek (her birinin başına koy, karakter her pozda **birebir aynı** kalmalı):
`Create asset: the MoonMinds mascot — a small friendly robot astronaut, chibi proportions (head is 45% of body height), white rounded spacesuit with orange (#FFB020) and yellow accents, a dark navy glass face screen with two big glowing cyan (#3EC8FF) smiling eyes, a small orange "M" badge on the chest, tiny antenna ears. Full body, 3/4 front view.`

| Dosya adı | Prompt devamı |
|---|---|
| `mascot_wave.png` | `Pose: standing, happily waving with the right hand raised, eyes curved in a smile.` |
| `mascot_think.png` | `Pose: thinking, one hand on its chin, head slightly tilted, eyes looking up-left, a small yellow "?" floating next to the head.` |
| `mascot_celebrate.png` | `Pose: jumping with both arms raised in celebration, eyes closed happily, three small yellow sparkles around it.` |

---

## 4) Logo — 2048×768, şeffaf arka plan

`logo_moonminds.png`
```
Create asset: canvas 2048×768, transparent background. The game logo wordmark "MOONMINDS" in one line, ALL CAPS, very chunky rounded bubbly display letters, white-to-icy-blue vertical fill, thick dark-navy (#0B1236) outline plus a deeper royal-blue (#4F6BFF) 3D extrusion below each letter. The first "O" is replaced by a small cartoon grey moon with craters. Below the wordmark, centered, a compact orange-to-yellow (#FFB020 → #FFD84A) rounded pill with navy outline containing the white bold text "BUILD. BALANCE. EXPLORE.". Text IS allowed and must be spelled exactly like this. No other elements.
```

---

## Kontrol listesi (görseli göndermeden önce)
- [ ] Arka plan gerçekten şeffaf mı? (Damalı desen *çizilmiş* değil, gerçekten saydam olmalı)
- [ ] Kenar boşlukları eşit mi, obje ortalanmış mı?
- [ ] Dış çizgi kalın ve koyu lacivert mi?
- [ ] Görselin içinde istenmeyen yazı var mı?
- [ ] Diğer ikonlarla yan yana koyunca aynı setten gibi duruyor mu?
