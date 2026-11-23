extends RefCounted
## Swaps the geometry of Fluttershy's cottage for Discopears' complete room ("A True True
## Friend" assets, CC BY-SA 4.0), at 0.345 of the .blend's world size: the same scale the game's
## cropped copy of the set already uses (game glb x 0.85), so ponies, Anon and the set's
## furniture keep their sizes. The game's cottage (cottage.gd) still owns the home record,
## Fluttershy's bed, the stove and the bookshelf; this only hides its shell, foyer and set,
## and puts the room, a door and a stone skirt in their place on the same doorway.
##
## The room glb (models/cottage_room.glb) is in the set's own frame: origin at the door's
## centre on the floor, +Z out of the door, metres. Its materials carry no images: the game
## already ships the set's textures (world/buildings/fluttershy/interior/), so they are
## reused by material name instead of copying ~28 MB into the pack.
const ROOM := preload("res://mods/fluttershy_cottage/models/cottage_room.glb")
const DOOR := preload("res://world/buildings/hinged_door.gd")
const TEX_DIR := "res://world/buildings/fluttershy/interior/cottage_interior_"
const TEXTURES := {"Walls_1": "walls_1", "Walls_2": "walls_2", "Ceiling_Detail": "ceiling_detail",
	"Ceiling_Floor": "ceiling_floor", "Detail": "detail", "Masonry": "masonry"}
## The outside (1.3.0): models/cottage_exterior.glb, modelled for this room after the show's
## cottage: one lumpy leafy mound over both storeys (kept above every ceiling inside), a scalloped
## fringe of leaf clumps, ivy down the tall back and sides, a tall chimney behind the fireplace with
## birdhouses, open wooden window frames over the room's own windows, an arched door surround, and
## a storeroom under the loft's overhang (its own door at the back, jars, barrels, crates, feed
## sacks, a lantern). The room's own walls show the game cottage's plaster from outside.
const EXTERIOR := preload("res://mods/fluttershy_cottage/models/cottage_exterior.glb")
const RNL_SOURCE := preload("res://world/props/rnl/rnl_snazzys_fluttershy_cottage/mesh_0.res")
const STONE_TEXTURE := preload("res://world/buildings/stone/flagstone_albedo.png")
const BOARDS_TEXTURE := "res://world/buildings/fluttershy/interior/cottage_interior_floorboards_albedo.png"
const PLASTER_SCALE := 0.25
## Exterior parts that are solid, as their own triangles.
const EXTERIOR_SOLIDS := ["X2_Mound", "X2_Chimney", "X2_Storeroom", "X2_StoreStep"]
## Storeroom (room frame, plan x/y, h). Its door: hinge on the right seen from outside, swinging in.
const STORE_DOOR_HINGE := Vector3(-2.31, 0.01, -11.47)
const STORE_DOOR_LEAF := Vector3(0.78, 1.86, 0.05) # matches X2_StoreDoor
## [scene, plan x, plan y, h, yaw degrees]; the game's props at 0.8 (they are made human-sized).
const STORE_PROPS := [
	["res://world/props/ponyville_kit/barrel_stack.glb", -0.16, 8.62, 0.0, 0.0],
	["res://world/props/ponyville_kit/barrel.glb", -0.05, 10.0, 0.0, 0.0],
	["res://world/props/ponyville_kit/barrel.glb", 0.05, 10.75, 0.0, 25.0],
	["res://world/props/ponyville_kit/barrel.glb", -0.75, 11.02, 0.0, -30.0],
	["res://world/props/ponyville_kit/produce_crate.glb", -1.5, 8.38, 0.0, 0.0],
	["res://world/props/ponyville_kit/produce_crate.glb", -3.3, 8.38, 0.0, 8.0],
	["res://world/props/ponyville_kit/produce_crate.glb", -1.5, 8.38, 0.78, 15.0],
	["res://world/props/household/pantry.glb", -4.96, 9.6, 0.0, 90.0],
	["res://world/props/household/fishing-bucket.glb", -4.55, 10.4, 0.0, 0.0],
]
const STORE_PROP_SCALE := 0.8
const STORE_LANTERN := ["res://world/props/ponyville_kit/wall_lantern.glb", -1.0, 8.06, 1.7]
static var _materials := {}
## Door hinge and leaf, measured from the set's rig (room frame, metres).
const HINGE := Vector3(-0.408, 0.0, -0.007)
const LEAF := Vector3(0.826, 1.852, 0.04)
## Stable (half) door, 1.3.0: the leaf splits at the ledge (CottageDoor below, CottageDoorTop
## above). Both halves swing out, like the show's door (the game's door swings in by default),
## and stop at 80 degrees, short of the arch frame. The bottom half is the house's FrontDoor; the
## top half (FrontDoorTop) opens on its own and always opens with the bottom (half_door_link.gd).
const DOOR_SPLIT := 0.936
const DOOR_TOP_HANDLE := 1.2
const DOOR_OUT := -1.0
const DOOR_MAX_OPEN := 80.0
const DOOR_LINK := preload("res://mods/fluttershy_cottage/half_door_link.gd")
## Ground-floor outline (room frame x, z), from the set's floor boards. The skirt follows it.
const FLOOR_OUTLINE := [Vector2(3.65, 0.03), Vector2(3.65, -7.93), Vector2(-1.99, -7.93), Vector2(-1.99, -7.73), Vector2(-6.1, -7.73),
	Vector2(-6.1, -6.99), Vector2(-5.98, -5.37), Vector2(-5.48, -0.27), Vector2(-1.99, -0.27), Vector2(-1.99, 0.03)]
## Skirt depth below the floor, metres.
const SKIRT_DEPTH := 1.6
## The room sits this far below the old cottage floor: the ground under it is 0.36-0.72 m
## below that floor (tools/_cottage_lab/sample_ground.gd), so the door step is about 0.1 m.
const FLOOR_DROP := 0.30
## Invisible ramp over the stairs (like the game's cottage): one plane just above the 13
## nosings, so bodies see a steady 34-degree slope instead of steps. Room frame, metres:
## x between the stair cheeks; [z, height] along the run, from the toe to the loft.
const STAIR_X := Vector2(-1.94, -0.76)
const STAIR_RUN := [Vector2(-3.39, -0.07), Vector2(-3.49, 0.0), Vector2(-7.617, 2.821), Vector2(-7.96, 2.80), Vector2(-8.26, 2.79)]
## Room plan positions below are the set's plan in metres: x right, y into the room from the
## door (room frame z = -y), h above the ground floor.
const LOFT_Y := 2.794
## The stair flight's footprint.
const STAIR_PLAN := Rect2(-1.97, 3.1, 1.24, 4.85)
## The home's outline (room frame x, z): the ground floor plus the loft's overhang at the back, so
## the loft counts as inside. The space under the overhang is closed (the exterior's base).
const HOME_OUTLINE := [Vector2(3.65, 0.03), Vector2(3.65, -7.93), Vector2(0.30, -7.93), Vector2(0.30, -11.15), Vector2(-4.95, -11.15),
	Vector2(-4.95, -7.73), Vector2(-6.1, -7.73), Vector2(-6.1, -6.99), Vector2(-5.98, -5.37), Vector2(-5.48, -0.27),
	Vector2(-1.99, -0.27), Vector2(-1.99, 0.03)]
## The game's home counts a body as inside up to 0.25 home units above its floor (2.5 m at its
## usual 10x scale), so the loft at 2.79 m would be outside. Stretching only the home's vertical
## scale makes that band taller, with no game script changed (1.1.0's script extension did not
## survive the game's mod loader: no way in). 12x (3.0 m) took in the loft floor but not the bed:
## its mattress is 3.36 m up, so a pony or Anon lying on it was "outside" and she could not get on
## the bed (1.3.0 test). 16x makes the band 4.0 m.
const HOME_SCALE := Vector3(10.0, 16.0, 10.0)
## The game's working furniture, moved into the new room: [node, plan x, plan y, h, yaw].
## Fluttershy's bed where the set has hers (loft, back wall; getting in from its +x side), the
## working stove against the kitchen's front wall facing in, the readable bookshelf on the loft's
## left wall (the set's fireplace stands on the sitting room's right wall).
const BED := ["CottageBed", -2.25, 10.4, LOFT_Y, 0.0]
const KITCHEN := ["Kitchen", -3.0, 0.62, 0.0, PI]
const SHELF_PREFIX := "Furnishing_bookshelf"
const SHELF := [-4.75, 7.0, LOFT_Y, PI * 0.5]
## Discopears' own prop layout (the .blend's "Prop Layout", room frame, set bed left out: the game's
## bed takes its place): models/cottage_props.glb, no images; props_textures.json maps each
## material to the game's copy of its texture.
const PROPS := preload("res://mods/fluttershy_cottage/models/cottage_props.glb")
const PROP_TEXTURES := "res://mods/fluttershy_cottage/models/props_textures.json"
const HOUSE := preload("res://world/buildings/house_interior.gd")
const FURNISHER := preload("res://world/interiors/interior_furnisher.gd")
## Props that stand solid (a box around the model). Seats are below; the rest (rugs, books, pans,
## garlic, pillows) is decoration.
const SOLID_PROPS := ["fc_furnace", "fc_desk", "fc_bird_cage", "fc_table_round", "fc_small_table", "fc_k_table",
	"fc_b_chest", "fc_b_desk", "fc_pet_bed", "fc_standing_lamp"]
## Real seats (the game's seating, as the old cottage gave the set's sofa, armchair and bench):
## metres from the seat marker (the model's bottom centre), the sitter facing +Z.
const SEATING := {
	"fc_sofa_1": {"couch": true, "seating": {
		"seats": [[-0.62, 0.29, 0.12], [0.0, 0.29, 0.12], [0.62, 0.29, 0.12]], "depth": 0.5,
		"solid": [[[0.0, 0.145, 0.0], [1.9, 0.29, 0.8]]],
		"upper": [[[0.0, 0.62, -0.32], [2.0, 0.66, 0.22]]]}},
	"fc_sofa_2": {"couch": false, "seating": {
		"seats": [[0.0, 0.29, 0.1]], "depth": 0.5,
		"solid": [[[0.0, 0.145, 0.05], [0.8, 0.29, 0.75]]],
		"upper": [[[0.0, 0.75, -0.36], [0.95, 0.9, 0.16]], [[-0.42, 0.42, 0.0], [0.14, 0.26, 0.7]], [[0.42, 0.42, 0.0], [0.14, 0.26, 0.7]]]}},
	"fc_k_bench": {"couch": false, "seating": {
		"seats": [[-0.36, 0.26, 0.0], [0.36, 0.26, 0.0]], "depth": 0.35,
		"solid": [[[0.0, 0.13, 0.0], [1.42, 0.26, 0.35]]], "upper": []}},
	"fc_k_bench_2": {"couch": false, "seating": {
		"seats": [[-0.36, 0.26, 0.0], [0.36, 0.26, 0.0]], "depth": 0.35,
		"solid": [[[0.0, 0.13, 0.0], [1.42, 0.26, 0.35]]], "upper": []}},
}
## The set's standing lamp lights the sitting room; two more of the same lamp (the game's copy,
## set scale x 0.85) light the kitchen and the loft. All run on the kit lamp (lit at night).
const SET_LAMP := "fc_standing_lamp"
const LAMP_MODEL := "res://world/buildings/fluttershy/interior/standing_lamp.glb"
const LAMP := preload("res://world/props/lamps/kit_lamp.gd")
const LAMPS := [[-4.4, 0.65, 0.0, 5.0], [0.0, 10.85, LOFT_Y, 6.0]]
const SET_LAMP_RANGE := 7.0
## Indoor route anchors [plan x, plan y, h] (the last five: down the kitchen's back strip, through
## the storeroom doorway at the right end of the kitchen's back wall, into the storeroom): sitting room, the kitchen doorway (y 2.1-3.2,
## lintel 1.715 m: ponies fit, Anon does not) and both sides of it, kitchen, the stair
## toe and head (6 cm over the ramp: the route capsule touches a 34-degree slope otherwise),
## the loft.
const WAYPOINTS := [[0.0, 0.8, 0.0], [1.5, 1.5, 0.0], [1.5, 3.5, 0.0], [1.5, 5.6, 0.0], [-0.2, 2.2, 0.0],
	[-1.35, 2.65, 0.0], [-2.0, 2.65, 0.0], [-2.65, 2.65, 0.0], [-3.0, 2.1, 0.0], [-4.2, 2.3, 0.0],
	[-1.35, 3.1, 0.0], [-1.35, 7.62, 2.88], [-1.35, 8.6, LOFT_Y], [-3.6, 8.2, LOFT_Y],
	[-3.6, 6.0, LOFT_Y], [-0.6, 9.2, LOFT_Y], [-0.6, 10.2, LOFT_Y],
	[-2.45, 2.6, 0.0], [-2.45, 5.6, 0.0], [-2.49, 7.2, 0.0], [-2.49, 8.6, 0.0], [-2.0, 9.6, 0.0]]
const ROOM_CENTRE := Vector2(1.2, 3.5)
const CEILING := 6.1
const DOOR_STEP := 0.1
## Upright set triangles smaller than this (m²) are trim and do not collide.
const TRIM_AREA := 0.03
## Old cottage parts this replaces (children of UsableCottage).
const OLD_PARTS := ["ShowInterior", "SourceWalls", "InteriorSolid", "FittedFloor", "FittedFoundation"]
const META := "fluttershy_cottage_mod"

## Builds the new cottage under `usable` (the game's UsableCottage). Returns the new root.
static func apply(usable: Node3D) -> Node3D:
	if not is_instance_valid(usable) or usable.has_meta(META): return null
	var frame := usable.get_node_or_null("RoomFrame") as Node3D
	var data: Variant = usable.get("data")
	if frame == null or not data is Dictionary: return null
	var floor_y := float((data as Dictionary).get("floor_y", 0.0))
	var hidden: Array = []
	var existing := usable.get_parent()
	# The cottage's exterior model (everything outside UsableCottage).
	if existing != null:
		for g: GeometryInstance3D in existing.find_children("*", "GeometryInstance3D", true, false):
			if not usable.is_ancestor_of(g) and g.visible: hidden.append(g)
	for part: String in OLD_PARTS:
		var node := usable.get_node_or_null(part) as Node3D
		if node != null: hidden.append(node)
	var old_door := frame.get_node_or_null("FrontDoor") as Node3D
	for node: Node3D in hidden: _switch(node, false)
	var root := Node3D.new(); root.name = "ModCottage"
	floor_y -= FLOOR_DROP
	root.position = Vector3(0, floor_y, 0)
	frame.add_child(root)
	var room := ROOM.instantiate() as Node3D
	room.name = "Room"; root.add_child(room)
	var leaf: MeshInstance3D
	var leaf_top: MeshInstance3D
	for mesh: MeshInstance3D in room.find_children("*", "MeshInstance3D", true, false):
		_dress(mesh)
		if mesh.name.begins_with("CottageDoorTop"): leaf_top = mesh
		elif mesh.name.begins_with("CottageDoor"): leaf = mesh
	_room_collision(root, room, [leaf, leaf_top])
	root.add_child(_stair_ramp())
	root.add_child(_skirt())
	_exterior(root)
	if old_door != null:
		old_door.name = "FrontDoor_Original"; _switch(old_door, false)
		hidden.append(old_door)
	if leaf != null:
		var bottom := _door(leaf, floor_y, "FrontDoor", 0.0, DOOR_SPLIT if leaf_top != null else LEAF.y, 0.85)
		frame.add_child(bottom)
		if leaf_top != null:
			var top := _door(leaf_top, floor_y, "FrontDoorTop", DOOR_SPLIT, LEAF.y, DOOR_TOP_HANDLE)
			top.set("navigation_box", AABB()) # the bottom half carries the doorway for navigation
			frame.add_child(top)
			var link := DOOR_LINK.new(); link.name = "HalfDoorLink"; link.set_meta(META, true)
			link.bottom = bottom; link.top = top
			frame.add_child(link)
	var record := {"root": root, "hidden": hidden, "moved": {}, "home": {}}
	usable.set_meta(META, record)
	_furnish(usable, frame, root, record)
	_configure_home(usable, frame, root, record)
	return root

## A room-frame point (relative to the cottage frame) from the set's plan.
static func _at(root: Node3D, x: float, y: float, h: float) -> Vector3:
	return root.position + Vector3(x, h, -y)

## Moves one of the game's furniture nodes (a child of UsableCottage) to a plan spot.
static func _move(usable: Node3D, frame: Node3D, root: Node3D, node: Node3D, spot: Array, record: Dictionary) -> void:
	if node == null: return
	record.moved[node] = node.transform
	node.transform = frame.transform * Transform3D(Basis(Vector3.UP, float(spot[3])), _at(root, spot[0], spot[1], spot[2]))

static func _furnish(usable: Node3D, frame: Node3D, root: Node3D, record: Dictionary) -> void:
	var home: Node = usable.get("home")
	_move(usable, frame, root, usable.get_node_or_null(str(BED[0])) as Node3D, BED.slice(1), record)
	_move(usable, frame, root, usable.get_node_or_null(str(KITCHEN[0])) as Node3D, KITCHEN.slice(1), record)
	for node: Node in usable.get_children():
		if str(node.name).begins_with(SHELF_PREFIX) and node is Node3D:
			_move(usable, frame, root, node as Node3D, SHELF, record)
	_props(root, home)
	if not ResourceLoader.exists(LAMP_MODEL): return
	for i in LAMPS.size():
		var spec: Array = LAMPS[i]
		var model := (load(LAMP_MODEL) as PackedScene).instantiate() as Node3D
		model.name = "Lamp_%d" % i
		model.scale = Vector3.ONE * 0.85
		model.position = _at(root, spec[0], spec[1], spec[2]) - root.position
		root.add_child(model)
		_lamp(model, home, float(spec[3]))

## The set's props, dressed with the game's textures, with solids, seats and the lamp.
static func _props(root: Node3D, home: Node) -> void:
	var props := PROPS.instantiate() as Node3D
	props.name = "SetProps"; root.add_child(props)
	var textures: Dictionary = {}
	if FileAccess.file_exists(PROP_TEXTURES):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROP_TEXTURES))
		if parsed is Dictionary: textures = parsed
	for mesh: MeshInstance3D in props.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(s)
			var key := str(source.resource_name) if source != null else ""
			var material := StandardMaterial3D.new(); material.roughness = 0.9
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			var path := str(textures.get(key, ""))
			if path != "" and ResourceLoader.exists(path): material.albedo_texture = load(path)
			elif source is BaseMaterial3D: material.albedo_color = (source as BaseMaterial3D).albedo_color
			mesh.set_surface_override_material(s, material)
	for node: Node in props.get_children():
		var id := str(node.name).trim_prefix("Prop_").trim_prefix("Seat_")
		if node is MeshInstance3D and id in SOLID_PROPS: _solid(root, node as MeshInstance3D)
		if str(node.name).begins_with("Seat_") and SEATING.has(id):
			var spec: Dictionary = SEATING[id]
			FURNISHER._add_seating(node as Node3D, spec.seating, AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE), 1.0, bool(spec.couch))
		if node is Node3D:
			node.add_to_group("house_furniture"); node.set_meta("house", home); node.set_meta("furniture", id)
	var set_lamp := props.get_node_or_null("Prop_" + SET_LAMP) as MeshInstance3D
	if set_lamp != null:
		var holder := Node3D.new(); holder.name = "SetLamp"
		holder.transform = set_lamp.transform
		props.add_child(holder)
		set_lamp.reparent(holder, false); set_lamp.transform = Transform3D.IDENTITY
		_lamp(holder, home, SET_LAMP_RANGE)
	HOUSE.limit_range(props, HOUSE.PROP_RANGE, true)

## A box solid around one prop, as a separate unscaled body (the props carry the set's scale).
static func _solid(root: Node3D, mesh: MeshInstance3D) -> void:
	var box := mesh.get_aabb()
	var t := mesh.transform
	var scale := t.basis.get_scale()
	var shape := BoxShape3D.new(); shape.size = box.size * scale
	var body := StaticBody3D.new(); body.name = "Solid_" + str(mesh.name).trim_prefix("Prop_"); body.collision_mask = 0
	body.transform = Transform3D(t.basis.orthonormalized(), t * box.get_center())
	var holder := CollisionShape3D.new(); holder.shape = shape
	body.add_child(holder); root.add_child(body)

static func _lamp(model: Node3D, home: Node, reach: float) -> void:
	model.add_to_group("house_furniture"); model.set_meta("house", home); model.set_meta("furniture", "standing_lamp")
	var lamp: Node = LAMP.attach(model, "cone_lamp")
	var bulb := lamp.get_node_or_null("LampLight") if lamp != null else null
	if bulb is OmniLight3D:
		var top := 0.0
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			top = maxf(top, (mesh.transform * mesh.get_aabb()).end.y)
		(bulb as OmniLight3D).position = Vector3(0, top - 0.3, 0)
		(bulb as OmniLight3D).omni_range = reach

## Points the game's home (Fluttershy's address, beds, routing) at the new room, loft included
## (HOME_SCALE, HOME_OUTLINE).
static func _configure_home(usable: Node3D, frame: Node3D, root: Node3D, record: Dictionary) -> void:
	var home := usable.get("home") as Node3D
	if home == null: return
	var keep := {}
	for key: String in ["scale", "floor_y", "_ceiling_y", "doorway", "door_width", "approach", "boundary", "floors",
			"room_center", "inside_at", "waypoints", "_reach_sq"]:
		if not key in home: continue
		var value: Variant = home.get(key)
		keep[key] = (value as Array).duplicate() if value is Array else value
	record.home = keep
	home.scale = HOME_SCALE
	var to_home := func(p: Vector3) -> Vector3: return home.to_local(frame.to_global(p))
	var floor_y := root.position.y
	var origin: Vector3 = to_home.call(Vector3(0, floor_y, 0))
	home.floor_y = origin.y
	home._ceiling_y = (to_home.call(Vector3(0, floor_y + CEILING, 0)) as Vector3).y
	home.doorway = origin
	home.door_width = LEAF.x / HOME_SCALE.x
	home.approach = to_home.call(Vector3(0, floor_y - DOOR_STEP, 1.2))
	var boundary := PackedVector2Array()
	for p: Vector2 in HOME_OUTLINE:
		var local: Vector3 = to_home.call(Vector3(p.x, floor_y, p.y))
		boundary.append(Vector2(local.x, local.z))
	home.boundary = boundary
	var bounds := Rect2(boundary[0], Vector2.ZERO)
	for p in boundary: bounds = bounds.expand(p)
	home.floors.clear(); home.floors.append(bounds)
	home.room_center = to_home.call(_at(root, ROOM_CENTRE.x, ROOM_CENTRE.y, 0.0))
	home.inside_at = to_home.call(Vector3(0, floor_y, -0.6))
	home.waypoints.clear()
	for w: Array in WAYPOINTS: home.waypoints.append(to_home.call(_at(root, w[0], w[1], w[2])))
	var bed := home.get("bed") as Node3D
	if bed != null and home.has_method("bed_side"): home.waypoints.append(home.to_local(home.bed_side("fluttershy")))
	var kitchen := usable.get_node_or_null(str(KITCHEN[0]))
	var spot := kitchen.get_node_or_null("CounterAccess") as Node3D if kitchen != null else null
	if spot != null: home.waypoints.append(home.to_local(spot.global_position))
	if "_reach_sq" in home: home._reach_sq = -1.0
	var links: Variant = home.get("_links")
	if links is Dictionary: (links as Dictionary).clear()

## Puts the game's cottage back (mod switched off).
static func undo(usable: Node3D) -> void:
	if not is_instance_valid(usable) or not usable.has_meta(META): return
	var record: Dictionary = usable.get_meta(META)
	var frame := usable.get_node_or_null("RoomFrame")
	var ours := frame.get_node_or_null("FrontDoor") if frame != null else null
	if ours != null and ours.has_meta(META): ours.name = "FrontDoor_Mod"; ours.queue_free()
	for extra: String in ["FrontDoorTop", "HalfDoorLink"]:
		var node := frame.get_node_or_null(extra) if frame != null else null
		if node != null and node.has_meta(META): node.queue_free()
	for node: Variant in record.get("hidden", []):
		if not is_instance_valid(node): continue
		_switch(node as Node3D, true)
		if (node as Node).name == "FrontDoor_Original": (node as Node).name = "FrontDoor"
	var moved: Dictionary = record.get("moved", {})
	for node: Variant in moved:
		if is_instance_valid(node): (node as Node3D).transform = moved[node]
	var home := usable.get("home") as Node
	if home != null:
		var keep: Dictionary = record.get("home", {})
		for key: String in keep: home.set(key, keep[key])
		var links: Variant = home.get("_links")
		if links is Dictionary: (links as Dictionary).clear()
	var root: Variant = record.get("root")
	if is_instance_valid(root): (root as Node).queue_free()
	usable.remove_meta(META)

static func _switch(node: Node3D, on: bool) -> void:
	node.visible = on
	node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

## Game textures by material name, and the plain outside pass.
static func _dress(mesh: MeshInstance3D) -> void:
	# Single-sided room: cast shadows from both sides so the sun does not shine through walls.
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	for s in mesh.mesh.get_surface_count():
		var source := mesh.mesh.surface_get_material(s)
		var key := str(source.resource_name) if source != null else ""
		var material := StandardMaterial3D.new()
		material.resource_name = key
		material.roughness = 0.95
		if TEXTURES.has(key):
			var path: String = TEX_DIR + str(TEXTURES[key]) + ".png"
			if ResourceLoader.exists(path): material.albedo_texture = load(path)
		elif source is BaseMaterial3D:
			material.albedo_color = (source as BaseMaterial3D).albedo_color
		material.next_pass = _outside()
		mesh.set_surface_override_material(s, material)

## One static collider from the room's own triangles (not the door leaf); small upright trim
## (the critters' little ramps, hooks, frames) is left out so it does not snag ponies.
static func _room_collision(root: Node3D, room: Node3D, leaves: Array) -> void:
	var faces := PackedVector3Array()
	for mesh: MeshInstance3D in room.find_children("*", "MeshInstance3D", true, false):
		if mesh in leaves: continue
		var to_root := room.transform * _relative(room, mesh)
		var source := mesh.mesh.get_faces()
		for i in range(0, source.size(), 3):
			var a := to_root * source[i]; var b := to_root * source[i + 1]; var c := to_root * source[i + 2]
			var cross := (b - a).cross(c - a)
			var area := cross.length() * 0.5
			if area <= 0.0: continue
			# Small level faces count only at a floor's height (the boards' own tiles), not the
			# critters' little ramps' and steps' plank tops.
			var level := absf(cross.normalized().y) > 0.9 and (absf(a.y) < 0.06 or absf(a.y - LOFT_Y) < 0.06)
			if area < TRIM_AREA and not level: continue
			faces.append(a); faces.append(b); faces.append(c)
	var shape := ConcavePolygonShape3D.new(); shape.set_faces(faces); shape.backface_collision = true
	var body := StaticBody3D.new(); body.name = "RoomSolid"; body.collision_mask = 0
	body.set_meta("building_design", "fluttershy_cottage")
	var holder := CollisionShape3D.new(); holder.shape = shape
	body.add_child(holder); root.add_child(body)

## One half of the stable door on the game's hinged door, swinging out. The bottom half is named
## FrontDoor so the home finds it. `low`/`high`: the half's span above the floor (metres).
static func _door(leaf: MeshInstance3D, floor_y: float, door_name: String, low: float, high: float, handle_y: float) -> Node3D:
	var door := DOOR.new(); door.name = door_name; door.set_meta(META, true)
	door.position = HINGE + Vector3(0, floor_y, 0)
	door.handle = Vector3(LEAF.x - 0.12, handle_y, 0.02)
	door.swing_direction = DOOR_OUT
	door.max_open = deg_to_rad(DOOR_MAX_OPEN)
	door.navigation_box = AABB(Vector3(0, 0, -0.09), Vector3(LEAF.x, LEAF.y, 0.18))
	var art := leaf.duplicate() as MeshInstance3D
	art.name = "Leaf"; art.transform = Transform3D.IDENTITY
	# The leaf is one-sided: both of its sides show the door, not the outside plaster.
	for s in art.mesh.get_surface_count():
		var own := art.get_surface_override_material(s) as StandardMaterial3D
		if own == null: continue
		own = own.duplicate(); own.next_pass = null; own.cull_mode = BaseMaterial3D.CULL_DISABLED
		art.set_surface_override_material(s, own)
	leaf.visible = false
	door.add_child(art)
	var height := high - low - 0.02
	var shape := BoxShape3D.new(); shape.size = Vector3(LEAF.x, height, LEAF.z)
	var holder := CollisionShape3D.new(); holder.name = "LeafCollision"; holder.shape = shape
	holder.position = Vector3(LEAF.x * 0.5, low + 0.01 + height * 0.5, -LEAF.z * 0.5 + 0.015)
	door.add_child(holder)
	return door

## Stone skirt around the ground floor, from the floor down SKIRT_DEPTH.
static func _skirt() -> MeshInstance3D:
	var material := _stone()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(material)
	var run := 0.0
	var n := FLOOR_OUTLINE.size()
	var centre := Vector2.ZERO
	for p: Vector2 in FLOOR_OUTLINE: centre += p / n
	for i in n:
		var a: Vector2 = FLOOR_OUTLINE[i]; var b: Vector2 = FLOOR_OUTLINE[(i + 1) % n]
		var length := a.distance_to(b)
		var out := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		var mid := (a + b) * 0.5
		if out.dot(Vector3(mid.x - centre.x, 0, mid.y - centre.y)) < 0.0: out = -out
		var top := -0.01; var bottom := -SKIRT_DEPTH
		var quad := [[Vector3(a.x, top, a.y), Vector2(run, 0)], [Vector3(b.x, top, b.y), Vector2(run + length, 0)],
			[Vector3(b.x, bottom, b.y), Vector2(run + length, SKIRT_DEPTH)], [Vector3(a.x, bottom, a.y), Vector2(run, SKIRT_DEPTH)]]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(out); st.set_uv((quad[k][1] as Vector2) * 0.6); st.add_vertex(quad[k][0])
		run += length
	var view := MeshInstance3D.new(); view.name = "Skirt"; view.mesh = st.commit()
	return view

## The game cottage's materials by name, its plaster, and the town's flagstone (cached).
static func _rnl(name: String) -> Material:
	if _materials.is_empty():
		for s in RNL_SOURCE.get_surface_count():
			var m := RNL_SOURCE.surface_get_material(s)
			if m != null: _materials[str(m.resource_name)] = m
	return _materials.get(name)

static func _triplanar(texture: Texture2D, scale: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture; m.albedo_color = tint; m.roughness = 1.0
	m.uv1_triplanar = true; m.uv1_world_triplanar = true; m.uv1_scale = Vector3.ONE * scale
	return m

static func _plaster(tint := Color.WHITE) -> StandardMaterial3D:
	var flat := _rnl("flutter_cabin_flat_snazzy") as BaseMaterial3D
	var m := _triplanar(flat.albedo_texture if flat != null else null, PLASTER_SCALE, tint)
	if flat == null: m.albedo_color = Color("e6dcc0") * tint
	return m

## The room's outside (its faces' backs): the game cottage's plaster, one shared material.
static func _outside() -> StandardMaterial3D:
	if not _materials.has("_outside"):
		var m := _plaster(); m.cull_mode = BaseMaterial3D.CULL_FRONT
		_rnl(""); _materials["_outside"] = m
	return _materials["_outside"]

static func _stone() -> StandardMaterial3D:
	if not _materials.has("_stone"):
		_rnl(""); _materials["_stone"] = _triplanar(STONE_TEXTURE, 0.6)
	return _materials["_stone"]

static func _exterior(root: Node3D) -> void:
	var outside := EXTERIOR.instantiate() as Node3D
	outside.name = "Exterior"; root.add_child(outside)
	var foliage := StandardMaterial3D.new()
	foliage.vertex_color_use_as_albedo = true; foliage.roughness = 1.0
	var wall := _plaster()
	var store_wall := _plaster(Color(1.0, 0.97, 0.92))
	var boards: Material = null
	if ResourceLoader.exists(BOARDS_TEXTURE): boards = _triplanar(load(BOARDS_TEXTURE), 0.5)
	for mesh: MeshInstance3D in outside.find_children("*", "MeshInstance3D", true, false):
		# Both sides cast shadows so the sun does not shine through single-sided walls and seams.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		for s in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(s)
			var key := str(source.resource_name) if source != null else ""
			var material: Material = null
			match key:
				"ext_foliage": material = foliage
				"ext_wall": material = wall
				"ext_stone": material = _stone()
				"store_wall": material = store_wall
				"store_floor": material = boards
			if material != null: mesh.set_surface_override_material(s, material)
		var id := str(mesh.name)
		for part: String in EXTERIOR_SOLIDS:
			if not id.begins_with(part): continue
			var faces := ConcavePolygonShape3D.new(); faces.set_faces(mesh.mesh.get_faces()); faces.backface_collision = true
			var body := StaticBody3D.new(); body.name = "Solid"; body.collision_mask = 0
			# Roofs must not become outdoor resident spawn support (as the game's cottage walls).
			body.set_meta("building_design", "fluttershy_cottage")
			var holder := CollisionShape3D.new(); holder.shape = faces
			body.add_child(holder); mesh.add_child(body)
	_storeroom(root, outside)

## The storeroom's door, props and lantern.
static func _storeroom(root: Node3D, outside: Node3D = null) -> void:
	var store := Node3D.new(); store.name = "Storeroom"; root.add_child(store)
	# The game's door writes rotation.y as its opening angle, so the turn that hangs it on the back
	# wall (PI) lives on a holder; on the door itself it was undone (1.3.0 test: the leaf sat in the
	# wall beside the doorway, its handle floating on the plaster).
	var hinge := Node3D.new(); hinge.name = "StoreDoorHinge"
	hinge.transform = Transform3D(Basis(Vector3.UP, PI), STORE_DOOR_HINGE)
	store.add_child(hinge)
	var door := DOOR.new(); door.name = "StoreDoor"
	door.handle = Vector3(STORE_DOOR_LEAF.x - 0.12, 0.9, 0.02)
	door.swing_direction = DOOR_OUT
	door.max_open = deg_to_rad(90.0)
	door.navigation_box = AABB(Vector3(0, 0, -0.09), Vector3(STORE_DOOR_LEAF.x, STORE_DOOR_LEAF.y, 0.18))
	# The leaf is modelled (X2_StoreDoor in cottage_exterior.glb, hinge-relative like the front door).
	var leaf_model := outside.find_child("X2_StoreDoor*", true, false) as MeshInstance3D if outside != null else null
	if leaf_model != null:
		var art := leaf_model.duplicate() as MeshInstance3D
		art.name = "Leaf"; art.transform = Transform3D.IDENTITY
		for s in art.mesh.get_surface_count():
			var source := art.mesh.surface_get_material(s) as BaseMaterial3D
			if source == null: continue
			var both := source.duplicate() as BaseMaterial3D
			both.cull_mode = BaseMaterial3D.CULL_DISABLED
			art.set_surface_override_material(s, both)
		leaf_model.visible = false
		door.add_child(art)
	else:
		var leaf := MeshInstance3D.new(); leaf.name = "Leaf"
		var box := BoxMesh.new(); box.size = STORE_DOOR_LEAF; leaf.mesh = box
		var wood := StandardMaterial3D.new(); wood.albedo_color = Color("6b4423"); leaf.material_override = wood
		leaf.position = Vector3(STORE_DOOR_LEAF.x * 0.5, STORE_DOOR_LEAF.y * 0.5, 0)
		door.add_child(leaf)
	var shape := BoxShape3D.new(); shape.size = STORE_DOOR_LEAF - Vector3(0, 0.02, 0)
	var holder := CollisionShape3D.new(); holder.name = "LeafCollision"; holder.shape = shape
	holder.position = Vector3(STORE_DOOR_LEAF.x * 0.5, STORE_DOOR_LEAF.y * 0.5, 0)
	door.add_child(holder)
	hinge.add_child(door)
	for spec: Array in STORE_PROPS:
		if not ResourceLoader.exists(str(spec[0])): continue
		var model := (load(str(spec[0])) as PackedScene).instantiate() as Node3D
		model.position = Vector3(spec[1], spec[3], -float(spec[2]))
		model.rotation.y = deg_to_rad(float(spec[4]))
		model.scale = Vector3.ONE * STORE_PROP_SCALE
		store.add_child(model)
		var bounds := _model_box(model)
		var solid := BoxShape3D.new(); solid.size = bounds.size * STORE_PROP_SCALE
		var body := StaticBody3D.new(); body.name = "PropSolid_%d" % store.get_child_count(); body.collision_mask = 0
		body.transform = Transform3D(Basis(Vector3.UP, model.rotation.y), model.position + Basis(Vector3.UP, model.rotation.y) * (bounds.get_center() * STORE_PROP_SCALE))
		var h := CollisionShape3D.new(); h.shape = solid; body.add_child(h); store.add_child(body)
	if ResourceLoader.exists(str(STORE_LANTERN[0])):
		var lantern := (load(str(STORE_LANTERN[0])) as PackedScene).instantiate() as Node3D
		lantern.name = "Lantern"
		lantern.position = Vector3(STORE_LANTERN[1], STORE_LANTERN[3], -float(STORE_LANTERN[2]))
		lantern.rotation.y = PI
		store.add_child(lantern)
		LAMP.attach(lantern, "wall_lantern")
	HOUSE.limit_range(store, HOUSE.PROP_RANGE, true)

## A model's mesh bounds in its own frame.
static func _model_box(model: Node3D) -> AABB:
	var box := AABB(); var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b := _relative(model, mesh) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

static func _stair_ramp() -> StaticBody3D:
	var faces := PackedVector3Array()
	for i in STAIR_RUN.size() - 1:
		var p: Vector2 = STAIR_RUN[i]; var q: Vector2 = STAIR_RUN[i + 1]
		var a := Vector3(STAIR_X.x, p.y, p.x); var b := Vector3(STAIR_X.y, p.y, p.x)
		var c := Vector3(STAIR_X.y, q.y, q.x); var d := Vector3(STAIR_X.x, q.y, q.x)
		faces.append_array([a, b, c, a, c, d])
	var shape := ConcavePolygonShape3D.new(); shape.set_faces(faces); shape.backface_collision = true
	var body := StaticBody3D.new(); body.name = "StairRamp"; body.collision_mask = 0
	var holder := CollisionShape3D.new(); holder.shape = shape
	body.add_child(holder)
	return body

static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != root and at is Node3D:
		t = (at as Node3D).transform * t
		at = at.get_parent()
	return t
