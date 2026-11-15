extends SceneTree
## nasa_db rules: every file has a manifest row with all fields, sources are
## official NASA / NASA-archive hosts, raw files are unchanged (sha256), each
## processed file names its raw source, and no API key is written anywhere.
## Run: <godot> --headless --path . --script res://tools/tests/test_nasa_db.gd

const DB := "res://nasa_db/"
const REQUIRED := ["file", "layer", "title", "source_url", "source_page", "asset_id", "date_range", "location",
	"original_format_unit", "conversion", "credit", "license_note", "retrieved", "game_use", "content_type", "relevance", "sha256"]
## Official hosts: NASA sites and the LOLA PDS node that NASA's PGDA page links to.
const HOSTS := ["nasa.gov", "imbrium.mit.edu"]

var _fails := 0
var _count := 0


func check(name: String, ok: bool) -> void:
	_count += 1
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + name)


func files_in(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".import") and not f.ends_with(".gdignore"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(files_in(dir.path_join(d)))
	return out


func host_ok(url: String) -> bool:
	var host := url.get_slice("://", 1).get_slice("/", 0)
	for h in HOSTS:
		if host == h or host.ends_with("." + h):
			return true
	return false


func _initialize() -> void:
	var f := FileAccess.open(DB + "manifest.csv", FileAccess.READ)
	check("manifest.csv exists", f != null)
	if f == null:
		quit(1)
		return
	var header := f.get_csv_line()
	var rows := {}
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < header.size():
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i]
		rows[row.file] = row
	check("manifest has every required column", REQUIRED.all(func(c): return header.has(c)))

	var complete := true
	var hosts := true
	for row in rows.values():
		for c in REQUIRED:
			complete = complete and not String(row[c]).strip_edges().is_empty()
		hosts = hosts and host_ok(row.source_url) and host_ok(row.source_page)
	check("every row fills every required field", complete)
	check("every source is an official NASA / NASA-archive host", hosts)

	var listed := true
	for path in files_in(DB + "raw") + files_in(DB + "processed"):
		var key: String = path.trim_prefix(DB)
		if key.ends_with(".metadata.json"):
			continue  # NASA's own metadata, stored next to its image
		if not rows.has(key):
			listed = false
			print("  not in manifest: ", key)
	check("every raw/processed file has a manifest row", listed)

	var unchanged := true
	var checked := 0
	for row in rows.values():
		if row.layer != "raw":
			continue
		var p: String = DB + row.file
		if not FileAccess.file_exists(p):
			print("  not downloaded (ok, re-fetch with the script): ", row.file)
			continue
		checked += 1
		unchanged = unchanged and FileAccess.get_sha256(p) == row.sha256
	check("raw files are byte-for-byte what NASA served (%d checked)" % checked, unchanged and checked > 0)

	var linked := true
	for row in rows.values():
		if row.layer == "processed":
			linked = linked and rows.has(row.derived_from) and rows[row.derived_from].layer == "raw" \
				and FileAccess.get_sha256(DB + row.file) == row.sha256
	check("every processed file comes from a listed raw file and matches its sha256", linked)

	var images := 0
	for task in OutpostSimulation.TASK_ACTIONS:
		if rows.has("processed/images/%s.jpg" % task):
			images += 1
	check("all 8 mission days have a NASA picture", images == 8)

	# No API key in the repo's text files we own (api.nasa.gov keys are 40 chars).
	var key_re := RegEx.create_from_string("api_key=[A-Za-z0-9]{40}|NASA_API_KEY\\s*=\\s*[A-Za-z0-9]{40}")
	var leaked := []
	for dir in ["res://tools", "res://scenes", "res://ui", DB]:
		for p in files_in(dir):
			if p.get_extension() in ["gd", "py", "csv", "md", "json", "tscn", "cfg"]:
				if key_re.search(FileAccess.get_file_as_string(p)) != null:
					leaked.append(p)
	check("no API key written in code, data or docs", leaked.is_empty())

	print("\n%d/%d passed" % [_count - _fails, _count])
	quit(1 if _fails > 0 else 0)
