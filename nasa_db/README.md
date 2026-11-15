# nasa_db — NASA sources used by MoonMinds

- `raw/` — files exactly as NASA serves them. Never edit. Godot ignores this
  folder (`.gdignore`). Large datasets (`*.IMG`) are not in git: run
  `python3 -I tools/nasa/build_nasa_db.py` to download them again; their
  sha256 is in the manifest.
- `processed/` — small game-ready files, each made from one raw file by
  `tools/nasa/build_nasa_db.py` (the exact steps are in its manifest row).
- 3D models: the raw `.glb` is Draco-compressed; set `GLTF_TOOLS` (see the top of
  `tools/nasa/build_nasa_db.py`) to decode it into `processed/models/`.
- `manifest.csv` — one row per file: source URL and page, NASA ID, dates,
  location, original format/unit, conversion, credit, licence note, retrieved
  date, game use, what kind of picture/data it is, and why it fits.

Rules: only official NASA / NASA-archive sources; no file without a manifest
row; no API keys anywhere (none are needed today; DONKI would need one and is
skipped). Facts in the game must say what is real and what MoonMinds made up.
