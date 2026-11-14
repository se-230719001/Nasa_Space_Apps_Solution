extends SceneTree
## Cuts clean, transparent UI sprites out of the MoonMinds sprite atlas.
##
## The PNG crops shipped in assets/source/moonminds_godot_asset_pack/ keep the atlas's navy
## backdrop and slivers of neighbouring elements, so they can't sit on top of the
## 3D scene. This tool re-crops from the atlas, flood-fills the backdrop from the
## crop edges into transparency (un-blending anti-aliased edges), drops neighbour
## fragments that touch the crop edge, and trims to content.
##
## Run:  godot --headless --path . --script res://tools/extract_ui_sprites.gd

const ATLAS := "res://assets/source/moonminds_godot_asset_pack/atlas/moonminds_full_sprite_atlas.png"
const OUT := "res://assets/sprites/"
## Colour distance (0..1 RGB) below which a pixel counts as backdrop.
const T_HARD := 0.07
const T_SOFT := 0.17

## name: [x0, y0, x1, y1, option]
## option: `true` keeps the backdrop; a Vector2i samples the backdrop colour at
## that atlas pixel (for sprites sitting on a coloured chip, not the navy page).
const SPRITES := {
	"brand/logo": [1018, 20, 1440, 172],
	"buttons/build": [1155, 272, 1326, 337],
	"buttons/explore": [1322, 272, 1494, 337],
	"buttons/cancel": [1490, 272, 1664, 337],
	"buttons/research": [1155, 335, 1326, 400],
	"buttons/mission": [1322, 335, 1494, 400],
	"buttons/ok": [1490, 335, 1664, 400],
	"buttons/build_disabled": [1150, 408, 1278, 474],
	"buttons/build_focus": [1278, 392, 1408, 476],
	"buttons/explore_focus": [1408, 404, 1540, 476],
	"buttons/cancel_focus": [1540, 404, 1666, 476],
	"chips/healthy": [1164, 490, 1332, 550],
	"chips/warning": [1328, 490, 1494, 550],
	"chips/critical": [1490, 490, 1660, 550],
	"panels/panel_layers": [6, 370, 368, 528],
	"panels/panel_star": [364, 370, 738, 528],
	"panels/panel_plain": [750, 530, 1150, 683],
	"panels/popup_close": [510, 528, 746, 680],
	"panels/checklist": [322, 530, 510, 680],
	"panels/bubble_white": [12, 536, 162, 624],
	"panels/bubble_yellow": [160, 536, 320, 624],
	"panels/toast_success": [12, 622, 320, 680],
	"mascots/wave": [8, 684, 164, 848],
	"mascots/think": [160, 684, 274, 848],
	"mascots/celebrate": [270, 684, 410, 848],
	"icons/check": [338, 550, 376, 586],
	"icons/box": [338, 588, 376, 624],
	"icons/close": [700, 524, 746, 566],
	"icons/warning": [1346, 500, 1394, 541, Vector2i(1342, 520)],
	"icons/critical": [1512, 500, 1558, 541],
	"icons/power": [426, 684, 484, 752],
	"icons/water": [484, 684, 536, 752],
	"icons/food": [536, 684, 598, 752],
	"icons/shield": [598, 684, 662, 752],
	"icons/calendar": [666, 694, 732, 756],
	"icons/settings": [412, 758, 474, 820],
	"icons/info": [472, 758, 532, 820],
	"icons/home": [528, 758, 590, 820],
	"icons/arrow_left": [588, 764, 620, 812],
	"icons/arrow_right": [620, 764, 652, 812],
	"icons/add": [650, 760, 698, 816],
	"icons/remove": [696, 760, 746, 816],
	"buildings/greenhouse": [962, 692, 1074, 778],
	"buildings/solar_panel": [1074, 692, 1166, 780],
	"buildings/habitat": [1164, 692, 1248, 774],
	"buildings/water_system": [1246, 692, 1318, 774],
	"buildings/research_lab": [1316, 690, 1398, 774],
	"buildings/main_base": [1350, 690, 1670, 842],
	"backgrounds/lunar_header": [0, 0, 996, 178, true],
}


func _init() -> void:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS))
	atlas.convert(Image.FORMAT_RGBA8)
	for sprite_name: String in SPRITES:
		var r: Array = SPRITES[sprite_name]
		var img := atlas.get_region(Rect2i(r[0], r[1], r[2] - r[0], r[3] - r[1]))
		if r.size() < 5 or r[4] is Vector2i:
			_remove_backdrop(img, atlas.get_pixelv(r[4]) if r.size() >= 5 else Color(0, 0, 0, 0))
			_drop_edge_fragments(img)
			img = _trim(img)
		var path := OUT + sprite_name + ".png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		img.save_png(ProjectSettings.globalize_path(path))
		print("%-28s %s" % [sprite_name, img.get_size()])
	quit()


static func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Flood fill from the crop border through backdrop-coloured pixels.
func _remove_backdrop(img: Image, bg_override: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	# Backdrop colour estimated from the darkest-quarter of border pixels.
	var border: Array[Color] = []
	for p in stack:
		border.append(img.get_pixelv(p))
	border.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	var bg := Color(0, 0, 0)
	var n := maxi(1, border.size() / 2)
	for i in n:
		bg += border[i] / n
	bg.a = 1.0
	if bg_override.a > 0.0:
		bg = bg_override

	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		var i := p.y * w + p.x
		if visited[i]:
			continue
		visited[i] = 1
		var c := img.get_pixelv(p)
		var d := _dist(c, bg)
		if d >= T_SOFT:
			continue
		var a := clampf((d - T_HARD) / (T_SOFT - T_HARD), 0.0, 1.0)
		if a <= 0.0:
			img.set_pixelv(p, Color(0, 0, 0, 0))
		else:
			# Un-blend the backdrop out of the anti-aliased edge.
			var fg := Color((c.r - bg.r * (1 - a)) / a, (c.g - bg.g * (1 - a)) / a, (c.b - bg.b * (1 - a)) / a, a)
			img.set_pixelv(p, fg.clamp())
		for o in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + o
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and not visited[q.y * w + q.x]:
				stack.append(q)


## Removes opaque islands that touch the crop edge (slivers of neighbours),
## keeping the largest island (the sprite itself) and anything fully inside.
func _drop_edge_fragments(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var islands: Array[Dictionary] = []
	for start in w * h:
		if label[start] != -1 or img.get_pixel(start % w, start / w).a < 0.1:
			continue
		var id := islands.size()
		var info := {"size": 0, "edge": false, "pixels": PackedInt32Array()}
		var stack := PackedInt32Array([start])
		label[start] = id
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var x := i % w
			var y := i / w
			info.size += 1
			info.pixels.append(i)
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				info.edge = true
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
				if j >= 0 and label[j] == -1 and img.get_pixel(j % w, j / w).a >= 0.1:
					label[j] = id
					stack.append(j)
		islands.append(info)
	if islands.is_empty():
		return
	var largest := 0
	for k in islands.size():
		if islands[k].size > islands[largest].size:
			largest = k
	for k in islands.size():
		if k != largest and (islands[k].edge or islands[k].size < 12):
			for i: int in islands[k].pixels:
				img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))


func _trim(img: Image) -> Image:
	var used := img.get_used_rect()
	return img.get_region(used.grow(1).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
