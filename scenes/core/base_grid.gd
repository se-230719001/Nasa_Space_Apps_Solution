class_name BaseGrid
extends RefCounted
## The base's building grid (game rules, not NASA data): 2 m square parcels
## inside the dome. Pure logic, so it is unit-tested; the 3D world and HUD
## only ask it where things go and whether a spot is allowed (and why not).
##
## A placement is {"cell": Vector2i, "rot": 0-3}: `cell` is the footprint's
## corner with the smallest x/z, `rot` turns the building by 90° steps.

const CELL := 2.0
## Cells -HALF .. HALF-1 on both axes (28 m square around the dome centre).
const HALF := 7
## A parcel's centre must be this close to the dome centre (dome radius 15.5).
const DOME_LIMIT := 12.3
## Footprint in cells (x, z) at rot 0.
const SIZE := {
	&"greenhouse": Vector2i(2, 2), &"ice_drill": Vector2i(2, 2), &"shield": Vector2i(2, 2),
	&"rover": Vector2i(2, 2), &"solar": Vector2i(4, 2), &"water_tank": Vector2i(3, 1),
	&"lander": Vector2i(3, 3),
	&"lamp": Vector2i(1, 1), &"antenna": Vector2i(1, 1), &"moon_garden": Vector2i(1, 1),
}
## Centre of each model's ground box, in its own space (measured from the
## procedural meshes), so the model sits centred on its parcels.
const MODEL_CENTER := {
	&"greenhouse": Vector2(0.0, 0.16), &"ice_drill": Vector2(0.33, 0.0), &"shield": Vector2.ZERO,
	&"rover": Vector2.ZERO, &"solar": Vector2(-0.27, 0.0), &"water_tank": Vector2(-1.26, 0.0),
	&"lander": Vector2.ZERO,
	&"lamp": Vector2.ZERO, &"antenna": Vector2.ZERO, &"moon_garden": Vector2.ZERO,
}
## The habitat is the crew's home: fixed, never moved.
const HABITAT := Rect2i(-5, -4, 6, 4)
## Kept clear: the walk from the habitat's door.
const PATH := [Vector2i(1, -2), Vector2i(2, -2)]
## Where each building is first offered (world x, z); the nearest free spot wins.
const NEAR := {
	&"greenhouse": Vector2(1.0, 4.0), &"shield": Vector2(-6.0, 6.0), &"rover": Vector2(8.0, -7.0),
	&"ice_drill": Vector2(-10.0, 2.0), &"solar": Vector2(7.0, -4.0), &"water_tank": Vector2(7.0, 2.0),
	&"lander": Vector2(-3.0, 8.0),
	&"lamp": Vector2(3.0, 1.0), &"antenna": Vector2(-7.0, -9.0), &"moon_garden": Vector2(4.0, 6.0),
}


static func size_of(id: StringName, rot: int) -> Vector2i:
	var s: Vector2i = SIZE.get(id, Vector2i(2, 2))
	return Vector2i(s.y, s.x) if rot % 2 == 1 else s


## Cells covered by `id` placed at `cell` with `rot`.
static func cells(id: StringName, cell: Vector2i, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s := size_of(id, rot)
	for x in s.x:
		for z in s.y:
			out.append(cell + Vector2i(x, z))
	return out


static func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


static func in_dome(c: Vector2i) -> bool:
	return c.x >= -HALF and c.x < HALF and c.y >= -HALF and c.y < HALF and cell_center(c).length() <= DOME_LIMIT


## What sits on parcel `c`: &"habitat", &"path", a building id, or &"" if free.
static func occupant(placements: Dictionary, c: Vector2i, ignore: StringName = &"") -> StringName:
	if HABITAT.has_point(c):
		return &"habitat"
	if c in PATH:
		return &"path"
	for id in placements:
		if id != ignore and c in cells(id, placements[id].cell, placements[id].rot):
			return id
	return &""


## Can `id` go here? {ok, reason}. `reason` is one short kid-friendly line.
static func check(placements: Dictionary, id: StringName, cell: Vector2i, rot: int) -> Dictionary:
	for c in cells(id, cell, rot):
		if not in_dome(c):
			return {"ok": false, "reason": "Too close to the dome wall"}
		var who := occupant(placements, c, id)
		if who == &"path":
			return {"ok": false, "reason": "Keep the path to the habitat door open"}
		if who != &"":
			return {"ok": false, "reason": "Something is already here"}
	return {"ok": true, "reason": ""}


## The free spot closest to the building's usual area (rot 0 first, then 1).
static func suggest(placements: Dictionary, id: StringName) -> Dictionary:
	var best := {}
	var best_d := INF
	var near: Vector2 = NEAR.get(id, Vector2.ZERO)
	for rot in [0, 1]:
		for x in range(-HALF, HALF):
			for z in range(-HALF, HALF):
				var cell := Vector2i(x, z)
				if not check(placements, id, cell, rot).ok:
					continue
				var d: float = footprint_center(id, cell, rot).distance_to(near) + rot * 0.5
				if d < best_d:
					best_d = d
					best = {"cell": cell, "rot": rot}
	return best


## Middle of the footprint on the ground (world x, z).
static func footprint_center(id: StringName, cell: Vector2i, rot: int) -> Vector2:
	return (Vector2(cell) + Vector2(size_of(id, rot)) / 2.0) * CELL


## Where to put the model node so its mesh is centred on the footprint.
static func world_transform(id: StringName, cell: Vector2i, rot: int) -> Transform3D:
	var angle := -rot * PI / 2.0
	var offset: Vector2 = MODEL_CENTER.get(id, Vector2.ZERO).rotated(-angle)
	var c := footprint_center(id, cell, rot) - offset
	return Transform3D(Basis(Vector3.UP, angle), Vector3(c.x, 0.0, c.y))


## World point on the ground -> the parcel under it.
static func cell_at(world: Vector3) -> Vector2i:
	return Vector2i(floori(world.x / CELL), floori(world.z / CELL))
