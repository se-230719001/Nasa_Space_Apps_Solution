class_name NasaDb
extends RefCounted
## Reads nasa_db/manifest.csv, the one place that says where each NASA
## picture/dataset came from (credit, NASA ID, what kind of picture, why it
## fits). The HUD shows these fields as they are; it never retypes them.
## A missing or broken manifest just means no picture/caption (never a crash).

const ROOT := "res://nasa_db/"

static var _rows: Dictionary = {}


## Manifest rows keyed by their `file` path (relative to nasa_db/).
static func rows() -> Dictionary:
	if _rows.is_empty():
		var f := FileAccess.open(ROOT + "manifest.csv", FileAccess.READ)
		if f == null:
			return {}
		var header := f.get_csv_line()
		while not f.eof_reached():
			var line := f.get_csv_line()
			if line.size() != header.size():
				continue
			var row := {}
			for i in header.size():
				row[header[i]] = line[i]
			_rows[row.file] = row
	return _rows


## The mission's picture: {texture, row} or {} when there is none.
static func mission_image(mission_id: StringName) -> Dictionary:
	var key := "processed/images/%s.jpg" % mission_id
	var row: Dictionary = rows().get(key, {})
	if row.is_empty() or not ResourceLoader.exists(ROOT + key):
		return {}
	return {"texture": load(ROOT + key), "row": row}


## Share of the south-pole map area per sunlight band (percent), plus
## "best_spot_sunlit_percent". From processed/datasets (see its manifest row).
static func sunlight_bands() -> Dictionary:
	var out := {}
	var f := FileAccess.open(ROOT + "processed/datasets/south_pole_sunlight_bands.csv", FileAccess.READ)
	if f == null:
		return out
	f.get_csv_line()  # header
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() == 2:
			out[line[0]] = float(line[1])
	return out
