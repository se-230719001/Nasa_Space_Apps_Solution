# MoonMinds assets

| Folder | Contents |
|---|---|
| `sprites/` | **Final in-game UI art.** Transparent PNGs cut from the sprite atlas: `brand`, `buttons`, `chips`, `icons`, `mascots`, `panels`, `buildings`, `backgrounds`. |
| `fonts/` | Fredoka (display) and Poppins (body), SIL Open Font License. |
| `source/` | Raw source material. Godot ignores it (`.gdignore`); nothing in the game loads from here. |

`sprites/` is generated from `source/moonminds_godot_asset_pack/atlas/moonminds_full_sprite_atlas.png`.
To add or re-cut a sprite, edit the rectangle list in `tools/extract_ui_sprites.gd` and run:

```sh
godot --headless --path . --script res://tools/extract_ui_sprites.gd
```

Don't hand-edit files in `sprites/`; they are overwritten on the next run.
