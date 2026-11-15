#!/usr/bin/env python3
"""Builds nasa_db/ from official NASA sources, reproducibly.

  python3 -I tools/nasa/build_nasa_db.py            (run from the repo root)

- raw/       files exactly as NASA serves them (never edited).
- processed/ small game-ready files, each made from one raw file by the
             steps written in its manifest row.
- manifest.csv one row per file: source, credit, licence note, dates, use.

No API key is used or needed: the NASA Image and Video Library API, the
LOLA/PGDA archive and NASA 3D Resources are open. (DONKI needs a key; it is
skipped on purpose.) Standard library only (+ macOS `sips` for images).

3D models: the raw .glb is Draco-compressed, which Godot can't import. With
GLTF_TOOLS set to a folder where these are npm-installed:
  npm install --prefix "$GLTF_TOOLS" @gltf-transform/core@4 @gltf-transform/extensions@4 draco3dgltf@1
the script decodes it with tools/nasa/undraco.mjs into processed/models/.
"""
import csv, datetime, hashlib, json, os, struct, subprocess, sys, urllib.parse, urllib.request, zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "nasa_db")
RAW_IMG, RAW_DATA = os.path.join(ROOT, "raw", "images"), os.path.join(ROOT, "raw", "datasets")
PRO_IMG, PRO_DATA = os.path.join(ROOT, "processed", "images"), os.path.join(ROOT, "processed", "datasets")
RAW_MODEL, PRO_MODEL = os.path.join(ROOT, "raw", "models"), os.path.join(ROOT, "processed", "models")
TOOLS = os.path.dirname(os.path.abspath(__file__))
TODAY = datetime.date.today().isoformat()
USAGE = ("NASA content is generally not subject to copyright in the US for non-commercial, educational use; "
         "credit NASA, do not imply NASA endorsement, no NASA logos "
         "(https://www.nasa.gov/nasa-brand-center/images-and-media/, read " + TODAY + ").")

# One photo per mission day. `kind` says what the picture really is; `why`
# says how it relates to the day's real story (and where it differs).
IMAGES = [
    ("iss046e017204", "greenhouse", "photo",
     "A zinnia grown in the Veggie plant system on the Space Station, photographed by Scott Kelly. Same event as the day 1 story (Space Station, not the Moon)."),
    ("ARC-2009-ACD09-0220-126", "ice_drill", "photo",
     "The LCROSS team at NASA Ames celebrating right after the impact was confirmed. Shows the people, not the crater."),
    ("as14-64-9140", "rover_blueprint", "photo",
     "Edgar Mitchell next to the two-wheeled cart (MET) on the Moon. Same mission as the day 3 story."),
    ("iss065e125924", "solar_upgrade", "photo",
     "A new roll-out solar array (iROSA) unrolled over an old Space Station solar wing. Same event as the day 4 story (Space Station, not the Moon)."),
    ("as15-86-11603", "rover", "photo",
     "James Irwin at the first Moon car (Lunar Roving Vehicle) on its first day of use. Same mission as the day 5 story."),
    ("as17-137-20979", "explore", "photo",
     "The Apollo 17 rover with its makeshift fender repair. Same event as the day 6 story."),
    ("GSFC_20171208_Archive_e001210", "radiation_map", "photo (space telescope)",
     "A solar flare seen by NASA's SDO in February 2014. NOT the August 1972 storm (no photo of that one is used): an example of the same kind of event."),
    ("KSC-20220808-PH-FMX01_0011", "shield", "photo",
     "Two test manikins with radiation detectors being put into the Orion capsule for Artemis I (2022). Shows radiation testing in Orion, not the storm shelter itself."),
]
IMAGE_MAX_PX = 768

# Average sunlight at the lunar south pole (LOLA / PGDA product 69).
SUN_LBL = "http://imbrium.mit.edu/EXTRAS/ILLUMINATION/IMG/AVGVISIB_85S_060M_201608.LBL"
SUN_IMG = "http://imbrium.mit.edu/EXTRAS/ILLUMINATION/IMG/AVGVISIB_85S_060M_201608.IMG"
SUN_PAGE = "https://pgda.gsfc.nasa.gov/products/69"
SUN_SIZE, SUN_SCALE, SUN_DOWN = 5058, 0.00004, 21  # from the .LBL; 5058/21 -> 240 px preview

FIELDS = ["file", "layer", "title", "source_url", "source_page", "asset_id", "date_range", "location",
          "original_format_unit", "conversion", "derived_from", "credit", "license_note", "retrieved",
          "game_use", "content_type", "relevance", "sha256"]


def fetch(url):
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def rel(path):
    return os.path.relpath(path, ROOT)


def images(rows):
    for nasa_id, task, kind, why in IMAGES:
        meta = json.loads(fetch("https://images-api.nasa.gov/search?" + urllib.parse.urlencode({"nasa_id": nasa_id})))
        data = meta["collection"]["items"][0]["data"][0]
        assets = json.loads(fetch("https://images-api.nasa.gov/asset/" + urllib.parse.quote(nasa_id)))
        hrefs = [a["href"] for a in assets["collection"]["items"]]
        url = next((h for h in hrefs if "~medium." in h), None) or next(h for h in hrefs if "~orig." in h)
        url = url.replace("http://", "https://")
        ext = os.path.splitext(urllib.parse.urlparse(url).path)[1].lower()
        raw = os.path.join(RAW_IMG, nasa_id + ext)
        open(raw, "wb").write(fetch(url))
        open(os.path.join(RAW_IMG, nasa_id + ".metadata.json"), "w").write(json.dumps(data, indent=1))
        pro = os.path.join(PRO_IMG, task + ".jpg")
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "85", "-Z", str(IMAGE_MAX_PX), raw, "--out", pro],
                       check=True, capture_output=True)
        page = "https://images.nasa.gov/details/" + urllib.parse.quote(nasa_id)
        credit = "NASA" + (" / " + data["photographer"] if data.get("photographer") else "") + \
            (" (" + data["center"] + ")" if data.get("center") else "")
        common = dict(title=data.get("title", nasa_id), source_page=page, asset_id=nasa_id,
                      date_range=data.get("date_created", "")[:10], credit=credit, license_note=USAGE,
                      retrieved=TODAY, content_type=kind, relevance=why)
        rows.append(dict(common, file=rel(raw), layer="raw", source_url=url, location="see NASA description",
                         original_format_unit=ext[1:].upper() + " image (NASA '~medium' rendition)",
                         conversion="none (as served)", derived_from="", game_use="source of " + rel(pro),
                         sha256=sha256(raw)))
        rows.append(dict(common, file=rel(pro), layer="processed", source_url=url, location="see NASA description",
                         original_format_unit="JPEG",
                         conversion="macOS sips: resized to fit %dpx, JPEG quality 85; no other change" % IMAGE_MAX_PX,
                         derived_from=rel(raw), game_use="picture on the day '%s' mission card" % task,
                         sha256=sha256(pro)))
        print("image", nasa_id, "->", rel(pro))


def png_gray(path, width, height, rows_bytes):
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    raw = b"".join(b"\x00" + r for r in rows_bytes)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)) + \
        chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def sunlight(rows):
    lbl, img = os.path.join(RAW_DATA, os.path.basename(SUN_LBL)), os.path.join(RAW_DATA, os.path.basename(SUN_IMG))
    for url, path in ((SUN_LBL, lbl), (SUN_IMG, img)):
        if not os.path.exists(path):
            open(path, "wb").write(fetch(url))
    label = open(lbl, errors="ignore").read()
    assert "LINE_SAMPLES          = %d" % SUN_SIZE in label and "SCALING_FACTOR        = 0.00004" in label, \
        "label changed: re-check the format before converting"
    buf = open(img, "rb").read()
    assert len(buf) == SUN_SIZE * SUN_SIZE * 2
    import array
    dn = array.array("h")
    dn.frombytes(buf)
    if sys.byteorder != "little":
        dn.byteswap()
    # Share of the 85S-90S map area in each sunlight band (time the Sun is visible).
    bands = [(0.0, 0.0, "never (permanent shadow)"), (0.0, 0.2, "under 20% of the time"), (0.2, 0.4, "20-40%"),
             (0.4, 0.6, "40-60%"), (0.6, 0.8, "60-80%"), (0.8, 1.01, "80% or more")]
    counts = [0] * len(bands)
    best = 0
    for v in dn:
        if v > best:
            best = v
        f = v * SUN_SCALE
        if v == 0:
            counts[0] += 1
            continue
        for i in range(1, len(bands)):
            if bands[i][0] <= f < bands[i][1]:
                counts[i] += 1
                break
    total = SUN_SIZE * SUN_SIZE
    csv_path = os.path.join(PRO_DATA, "south_pole_sunlight_bands.csv")
    with open(csv_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["sunlight_band", "share_of_area_percent"])
        for (lo, hi, name), c in zip(bands, counts):
            w.writerow([name, "%.2f" % (100.0 * c / total)])
        w.writerow(["best_spot_sunlit_percent", "%.1f" % (100.0 * best * SUN_SCALE)])
    # 240 x 240 preview: block mean, 0 = black (shadow), 1 = white (always lit).
    n = SUN_SIZE // SUN_DOWN
    out = []
    for by in range(n):
        line = bytearray(n)
        for bx in range(n):
            s = 0
            for y in range(by * SUN_DOWN, by * SUN_DOWN + SUN_DOWN):
                base = y * SUN_SIZE + bx * SUN_DOWN
                s += sum(dn[base:base + SUN_DOWN])
            line[bx] = min(255, int(s / (SUN_DOWN * SUN_DOWN) * SUN_SCALE * 255))
        out.append(bytes(line))
    png_path = os.path.join(PRO_IMG, "south_pole_sunlight_map.png")
    png_gray(png_path, n, n, out)
    common = dict(source_page=SUN_PAGE, asset_id="AVGVISIB_85S_060M_201608 (PDS3, LRO-L-LOLA-4-GDR-V1.0)",
                  date_range="model averaged over 18.6 years of hourly timesteps; LOLA data 2009-07-13 to 2013-07-18; product 2016-09-15",
                  location="Moon, 85S-90S, polar stereographic, 60 m/pixel", credit="NASA GSFC / LRO LOLA team; Mazarico et al. (2011), Icarus 211",
                  license_note="Public NASA/PDS archive data; credit NASA/LOLA and cite Mazarico et al. (2011). " + USAGE,
                  retrieved=TODAY, content_type="dataset (computer model from measured terrain)")
    rows.append(dict(common, file=rel(lbl), layer="raw", title="PDS3 label for the average solar illumination map",
                     source_url=SUN_LBL, original_format_unit="PDS3 text label", conversion="none (as served)", derived_from="",
                     game_use="describes the .IMG format", relevance="needed to read the map correctly", sha256=sha256(lbl)))
    rows.append(dict(common, file=rel(img), layer="raw", title="Average solar illumination, lunar south pole (85S-90S, 60 m)",
                     source_url=SUN_IMG, original_format_unit="int16 LSB, 5058x5058; DN x 0.00004 = fraction of timesteps sunlit (0-1)",
                     conversion="none (as served); 51 MB, kept out of git (re-download with this script, check sha256)",
                     derived_from="", game_use="source of the two processed files below",
                     relevance="real sunlight at the pole: the base site and solar-panel days", sha256=sha256(img)))
    rows.append(dict(common, file=rel(csv_path), layer="processed", title="How much of the south pole area gets how much sun",
                     source_url=SUN_IMG, original_format_unit="CSV, percent",
                     conversion="each pixel's DN x 0.00004 counted into sunlight bands; DN 0 = permanent shadow; plus the highest value found",
                     derived_from=rel(img), game_use="facts for the sunlight / base-site mission card (not a daily forecast)",
                     relevance="these are long-term averages, not sunlight on any chosen date", sha256=sha256(csv_path)))
    rows.append(dict(common, file=rel(png_path), layer="processed", title="Average sunlight map preview, lunar south pole",
                     source_url=SUN_IMG, original_format_unit="PNG 8-bit grey, 240x240",
                     conversion="21x21 pixel block mean of DN x 0.00004, scaled to 0-255 (black = shadow, white = always lit); orientation as in the file",
                     derived_from=rel(img), game_use="picture on the sunlight / base-site mission card",
                     relevance="visualization of the real average, made by this script", content_type="visualization (made by MoonMinds from NASA data)",
                     sha256=sha256(png_path)))
    print("sunlight bands:", [round(100.0 * c / total, 2) for c in counts], "best:", best * SUN_SCALE)


# NASA 3D Resources model used as a placeable replica in the base.
LM_URL = "https://assets.science.nasa.gov/content/dam/science/cds/3d/resources/model/apollo-lunar-module/Apollo%20Lunar%20Module.glb"
LM_PAGE = "https://science.nasa.gov/3d-resources/apollo-lunar-module/"


def models(rows):
    raw = os.path.join(RAW_MODEL, "Apollo Lunar Module.glb")
    if not os.path.exists(raw):
        open(raw, "wb").write(fetch(LM_URL))
    pro = os.path.join(PRO_MODEL, "apollo_lunar_module.glb")
    tools = os.environ.get("GLTF_TOOLS", "")
    if tools:
        import shutil
        shutil.copy(os.path.join(TOOLS, "undraco.mjs"), os.path.join(tools, "undraco.mjs"))
        subprocess.run(["node", os.path.join(tools, "undraco.mjs"), raw, pro], check=True, capture_output=True)
    elif not os.path.exists(pro):
        print("models: set GLTF_TOOLS to decode the Draco model (see the top of this file)")
    common = dict(title="Apollo Lunar Module (3D model)", source_url=LM_URL, source_page=LM_PAGE,
                  asset_id="NASA 3D Resources: Apollo Lunar Module",
                  date_range="real Apollo landings 1969-1972 (the model itself is undated)",
                  location="Moon (Apollo 11, 12, 14-17 landing sites)", credit="NASA/Michael D. Carbajal",
                  license_note=USAGE, retrieved=TODAY, content_type="3D model (NASA-made replica of a real spacecraft)",
                  relevance="The real Apollo Lunar Module landed 12 astronauts on the Moon in six landings, 1969-1972.")
    rows.append(dict(common, file=rel(raw), layer="raw", original_format_unit="glTF 2.0 binary, Draco-compressed meshes, WebP textures",
                     conversion="none (as served)", derived_from="", game_use="source of " + rel(pro), sha256=sha256(raw)))
    if os.path.exists(pro):
        rows.append(dict(common, file=rel(pro), layer="processed", original_format_unit="glTF 2.0 binary, plain meshes, WebP textures",
                         conversion="tools/nasa/undraco.mjs (glTF-Transform 4): Draco meshes decoded; nothing else changed",
                         derived_from=rel(raw), game_use="the 'Apollo Lander (replica)' landmark the player can place in the base",
                         sha256=sha256(pro)))
    print("model", rel(raw), "->", rel(pro) if os.path.exists(pro) else "(not decoded)")


def main():
    for d in (RAW_IMG, RAW_DATA, PRO_IMG, PRO_DATA, RAW_MODEL, PRO_MODEL):
        os.makedirs(d, exist_ok=True)
    rows = []
    images(rows)
    sunlight(rows)
    models(rows)
    with open(os.path.join(ROOT, "manifest.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in FIELDS})
    print("manifest rows:", len(rows))


if __name__ == "__main__":
    main()
