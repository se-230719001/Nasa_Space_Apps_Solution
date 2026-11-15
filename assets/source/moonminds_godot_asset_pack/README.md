# MoonMinds — Godot UI Asset Pack

This pack was generated from the supplied MoonMinds UI style reference.

## Contents
- `atlas/`: full reference sprite atlas.
- `backgrounds/`: lunar-base header/background crop.
- `panels/`: panel frames and popup crop.
- `buttons/`: primary, secondary, danger, disabled and focus-state button crops.
- `mascots/`: three mascot poses.
- `icons/`: resource and navigation icons.
- `buildings/`: greenhouse, solar panel, habitat, water system, lab and base.
- `hud/`: resource-bar group.
- `layout/`: spacing and shape footer reference.

## Import into Godot 4
1. Extract this folder into your Godot project's `assets/moonminds/` directory.
2. Select PNG files in the FileSystem dock and set **Import > Compress > Mode** as appropriate for your target.
3. Use PNG crops as `Texture2D` resources in `TextureRect`, `NinePatchRect`, `TextureButton` or `Sprite2D`.
4. For scalable panel/button backgrounds, configure `NinePatchRect` patch margins manually in the Inspector.

## Important
These are raster PNG crops from a generated sprite atlas, not editable vector artwork or a production-ready `.tres` theme. The full atlas is included as the source reference. Some crops retain the atlas's dark navy backdrop; inspect them in your target scene and use the full atlas when exact visual context is needed.
