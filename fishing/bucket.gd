extends Node3D
## Fishing: the pier's catch bucket as a live well. Kept fish are a list saved with the world
## (Mods.state("fishing").bucket: [{id, length}]), shown swimming in water inside the bucket,
## shrunk to fit. Looking at it lists the catch; E (desktop) or a grip inside it (VR, untested)
## takes the newest fish out into your free hand as an item.
const MODEL = preload("res://mods/fishing/fish_model.gd")
const SOUNDS = preload("res://mods/fishing/sounds.gd")
const SFX = preload("res://world/audio/interaction_sounds.gd")
const CAPACITY = 12
const SHOWN = 6
const FONT = preload("res://world/ui/fonts/PonyvilleMedium.ttf")
var dock: Node3D
var inventory: Node
var state_source: Callable          # returns the mod's per-world Dictionary
var radius = .17                   # inner radius at the water line (measured in setup)
var water_h = .27                  # water height above the bucket's origin
var _water: MeshInstance3D
var _swimmers: Array = []           # [{node, phase, ring, speed, depth}]
var _list: Label3D
var _t = 0.0
var _looked = false
var _look_until = -1.0
var _scan_in = 0.0

func setup(d: Node3D, inv: Node, source: Callable) -> void:
	dock = d; inventory = inv; state_source = source
	add_to_group("interaction_hint_sources"); add_to_group("grab_providers")
	var bucket: Node3D = dock.get("bucket")
	if is_instance_valid(bucket):
		_measure(bucket)
		global_transform = Transform3D(Basis(), bucket.global_position)
	_water = MeshInstance3D.new(); var disc = CylinderMesh.new(); disc.top_radius = radius; disc.bottom_radius = radius * .96; disc.height = .01
	disc.radial_segments = 24; _water.mesh = disc
	var wm = StandardMaterial3D.new(); wm.albedo_color = Color(.35, .6, .7, .28); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = .25; wm.metallic_specular = .3; _water.material_override = wm; _water.position.y = water_h; add_child(_water)
	_list = Label3D.new(); _list.font = FONT; _list.font_size = 44; _list.pixel_size = .0008; _list.modulate = Color("fff3d6")
	_list.outline_modulate = Color("3a2616"); _list.outline_size = 12; _list.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_list.position.y = water_h + .3; _list.visible = false; add_child(_list)
	refresh()

## The bucket model's inside, from its mesh bounds (falls back to the dock's collision ring).
func _measure(bucket: Node3D) -> void:
	var box = AABB(); var first = true
	for mi: MeshInstance3D in bucket.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null: continue
		var b: AABB = bucket.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b); first = false
	if first: return
	radius = minf(box.size.x, box.size.z) * .5 * .82
	water_h = box.position.y + box.size.y * .72

func fish() -> Array:
	var st: Dictionary = state_source.call()
	if not st.get("bucket") is Array: st["bucket"] = []
	return st.bucket

func full() -> bool: return fish().size() >= CAPACITY

func add(id: String, length: float) -> void:
	fish().append({"id": id, "length": snappedf(length, .001)})
	_saved()
	refresh()
	SOUNDS.play_at(self, "plop", global_position + Vector3.UP * water_h, -10.0, 1.6)
	SFX.play_event(self, "splash", {"intensity": .25}, global_position + Vector3.UP * water_h)

func _saved() -> void:
	if Mods.has_method("save_changed"): Mods.save_changed()

## Rebuild the swimmers to match the list (newest shown).
func refresh() -> void:
	for s in _swimmers: if is_instance_valid(s.node): s.node.queue_free()
	_swimmers.clear()
	var all = fish()
	var shown = all.slice(maxi(0, all.size() - SHOWN))
	for i in shown.size():
		var f: Dictionary = shown[i]
		var spec: Dictionary = (MODEL as Script).get_script_constant_map().get(str(f.id).to_upper(), MODEL.TROUT)
		var view: Node3D = MODEL.build(spec)
		# Shrunk to fit the bucket, keeping big ones bigger than small ones.
		var fit: float = clampf(float(f.length), .1, .95)
		var k: float = (radius * (1.15 + .55 * inverse_lerp(.1, .95, fit))) / float(spec.length)
		view.scale = Vector3.ONE * k
		add_child(view)
		_swimmers.append({"node": view, "phase": TAU * i / maxf(1, shown.size()), "ring": radius * randf_range(.35, .6),
			"speed": randf_range(.35, .6) * (1 if i % 2 == 0 else -1), "depth": randf_range(.012, .035)})
	_water.visible = true

func _process(delta: float) -> void:
	_t += delta
	for s in _swimmers:
		var n: Node3D = s.node
		if not is_instance_valid(n): continue
		s.phase += s.speed * delta
		var p = Vector3(cos(s.phase), 0, sin(s.phase)) * s.ring
		var tangent = Vector3(-sin(s.phase), 0, cos(s.phase)) * signf(s.speed)
		var yaw = atan2(-tangent.x, -tangent.z)
		n.position = p + Vector3.UP * (water_h - s.depth)
		n.rotation = Vector3(0, yaw + sin(_t * 6.0 + s.phase) * .25, 0)
	if _looked: _look_until = _t + .35
	_looked = false
	_list.visible = _t < _look_until
	_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = .4; _absorb_loose()

func _list_text() -> String:
	var all = fish()
	if all.is_empty(): return "Bucket (empty)"
	var lines: PackedStringArray = ["Bucket  %d/%d" % [all.size(), CAPACITY]]
	var newest = all.slice(maxi(0, all.size() - 6)); newest.reverse()
	for f: Dictionary in newest:
		lines.append("%s  %d cm" % [_name(f.id), roundi(float(f.length) * 100.0)])
	if all.size() > 6: lines.append("+ %d more" % (all.size() - 6))
	return "\n".join(lines)

static func _name(id: String) -> String:
	var table: Dictionary = preload("res://mods/fishing/catch_table.gd").species()
	return str(table.get(id, {}).get("name", id.capitalize()))

## Desktop: the game's hint line asks this while you look about. Looking at the bucket shows the list.
func interaction_hint() -> Dictionary:
	if not is_instance_valid(inventory) or not bool(inventory.get("_desktop")): return {}
	var hit = _look_hit()
	if hit.is_empty(): return {}
	_looked = true; _list.text = _list_text()
	var text = ""
	if _held_fish("desktop") != null: text = "[E] Put in bucket" if not full() else "Bucket's full"
	elif fish().is_empty(): return {}
	else: text = "[E] Take a fish out" if not inventory.hand_busy("desktop") else "Hands full"
	return {"target": hit.collider, "text": text, "point": hit.position, "collider": hit.collider}

func _look_hit() -> Dictionary:
	var cam: Camera3D = inventory.get("camera")
	if not is_instance_valid(cam): return {}
	var q = PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 2.6, 1)
	var body: Variant = inventory.get("player_body")
	if body is CollisionObject3D: q.exclude = [(body as CollisionObject3D).get_rid()]
	var hit = cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return {}
	var at: Vector3 = hit.position
	var flat = Vector2(at.x - global_position.x, at.z - global_position.z).length()
	return hit if flat < radius + .12 and at.y < global_position.y + water_h + .25 else {}

## Desktop E while looking at it (main.gd routes the key here first): put a held fish in, or
## take the newest one out. Logs why it didn't, to help track down problems.
func desktop_use() -> bool:
	if not is_instance_valid(inventory): return false
	if _look_hit().is_empty(): return false
	if _held_fish("desktop") != null:
		if full(): print("[fishing] bucket: full"); return false
		return deposit("desktop")
	if fish().is_empty(): print("[fishing] bucket: empty"); return false
	if inventory.hand_busy("desktop"):
		print("[fishing] bucket: hand busy (held=%s activity=%s)" % [inventory.held.has("desktop"), inventory.has_meta("desktop_activity_owner")]); return false
	return _take("desktop", inventory.camera.global_transform)

## The fish item in this hand, or null.
func _held_fish(side: String) -> Node3D:
	if not is_instance_valid(inventory) or not inventory.held.has(side): return null
	var item: Node3D = inventory.held[side]
	if not is_instance_valid(item): return null
	return item if str(item.get_meta("item_id", "")).begins_with("food:fish-") else null

## A fish in hand goes into the well (its size if it came out of the bucket, else a typical one).
func deposit(side: String) -> bool:
	var item: Node3D = _held_fish(side)
	if item == null: return false
	var token = str(item.get_meta("token", ""))
	var id = str(item.get_meta("item_id", "")).trim_prefix("food:fish-")
	if not inventory.inventory.consume(token): print("[fishing] bucket: couldn't take ", token, " from the inventory"); return false
	inventory.held.erase(side); inventory.loose.erase(token); inventory._track.erase(side); inventory._claim(side, false)
	item.queue_free()
	if inventory.has_method("_refresh_holding"): inventory._refresh_holding()
	add(id, _length_of(item, id))
	return true

func _length_of(item: Node, id: String) -> float:
	if item.has_meta("fish_length"): return float(item.get_meta("fish_length"))
	var s: Dictionary = preload("res://mods/fishing/catch_table.gd").species().get(id, {})
	var size: Array = s.get("size", [.2, .4])
	return lerpf(float(size[0]), float(size[1]), .35)

## Any loose fish item dropped or thrown into the bucket swims instead (VR's way in, too).
func _absorb_loose() -> void:
	if not is_instance_valid(inventory) or full(): return
	var loose: Dictionary = inventory.get("loose")
	for token in loose.keys():
		var item: Node3D = loose[token]
		if not is_instance_valid(item) or item in inventory.held.values(): continue
		var id = str(item.get_meta("item_id", ""))
		if not id.begins_with("food:fish-"): continue
		var local: Vector3 = item.global_position - global_position
		if Vector2(local.x, local.z).length() > radius + .03 or local.y < -.05 or local.y > water_h + .1: continue
		if not inventory.inventory.consume(str(token)): continue
		loose.erase(token); item.queue_free()
		add(id.trim_prefix("food:fish-"), _length_of(item, id.trim_prefix("food:fish-")))
		if full(): return

func _take(side: String, pose: Transform3D) -> bool:
	var all = fish()
	if all.is_empty(): return false
	var f: Dictionary = all.back()
	var id = "food:fish-" + str(f.id)
	var body: RigidBody3D = inventory.spawn_owned_drop(id, Transform3D(Basis(), global_position + Vector3.UP * (water_h + .35)))
	if body == null:
		print("[fishing] bucket: couldn't make %s (loose items %d, briefcase full?)" % [id, inventory.inventory.loans.size()]); return false
	body.set_meta("fish_length", float(f.length))
	all.pop_back(); _saved(); refresh()
	SFX.play_event(self, "splash", {"intensity": .35}, global_position + Vector3.UP * water_h)
	if inventory.has_method("_take_pick"):
		var ok = inventory.call("_take_pick", side, {"target": body, "kind": "", "pointed": true, "point": body.global_position}, pose)
		if not ok: print("[fishing] bucket: %s made but not taken into the hand; it's sitting on the bucket" % id)
	return true

## VR (untested): a free hand gripping inside the bucket takes the newest fish.
func grab_offer(hand_side: String, sample: Dictionary) -> Dictionary:
	if fish().is_empty() or not is_instance_valid(inventory) or inventory.hand_busy(hand_side): return {}
	var pose: Transform3D = sample.get("pose", Transform3D.IDENTITY)
	var point: Vector3 = sample.get("grip_position", pose.origin)
	var local = point - global_position
	if Vector2(local.x, local.z).length() > radius + .05 or local.y < -.05 or local.y > water_h + .25: return {}
	return {"target": self, "point": global_position + Vector3.UP * water_h, "text": hand_side.capitalize() + " grip · Take a fish"}

func grab_take(hand_side: String, _offer: Dictionary, sample: Dictionary) -> bool:
	return _take(hand_side, sample.get("pose", Transform3D.IDENTITY))
