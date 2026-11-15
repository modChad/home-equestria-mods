extends Node
## Fishing: unicorns and alicorns (princesses included) fishing with you hold the rod in their
## magic instead of their mouth. The game's companions (fishing_companions.gd, physics priority
## -5) place a borrowed rod at the pony's mouth every frame; this runs just after (priority -4)
## and before the rods tick (0), moving the rod to float in front of her and a little to the
## side at horn height, wrapped in her aura with her horn lit. Casting, hooking and reeling stay
## the game's. Ponies without magic are left as they are.
var host: Node                      # main.gd (for its rods)
var _glows: Dictionary = {}         # rod -> {actor, magic, meshes}
## Debugging (0.5.1): logs "[fishing] magic:" lines and turns on the game's own companion trace
## ("[fishing-route]" lines: why a pony gave up). Set false to quieten.
const DEBUG := true
var _traced: Node
var _logged_float: Dictionary = {}

func _ready() -> void:
	process_physics_priority = -4

func _physics_process(_delta: float) -> void:
	var companions: Node = _companions()
	if DEBUG and is_instance_valid(companions) and companions != _traced:
		_traced = companions; companions.set("trace", true)
		print("[fishing] magic: companion trace on (look for [fishing-route] lines)")
	if DEBUG and is_instance_valid(companions):
		for lease: Dictionary in companions.get("leases"):
			var key := "%s:%s" % [lease.get("id", "?"), lease.get("phase", "?")]
			if not _logged_float.has(key):
				_logged_float[key] = true
				var a: Variant = lease.get("actor"); var r: Variant = lease.get("rod")
				print("[fishing] magic: %s phase=%s magic=%s rod=%s holder=%s owner=%s" % [lease.get("id", "?"), lease.get("phase", "?"),
					is_instance_valid(a) and (a as Node).get("magic") is Node, (r as Node).name if is_instance_valid(r) else "-",
					(r as Node).get("holder") if is_instance_valid(r) else "-", lease.get("owner", "?")])
	var held: Dictionary = {}
	if is_instance_valid(companions):
		for lease: Dictionary in companions.get("leases"):
			var rod: Node3D = lease.get("rod"); var actor: Node3D = lease.get("actor")
			if not is_instance_valid(rod) or not is_instance_valid(actor): continue
			if str(rod.get("holder")) != str(lease.get("owner")): continue
			var magic: Variant = actor.get("magic")
			if not magic is Node or not is_instance_valid(magic): continue
			held[rod] = true
			_float(lease, rod, actor, magic)
	for rod: Node3D in _glows.keys():
		if not held.has(rod): _unglow(rod)

func _companions() -> Node:
	if not is_instance_valid(host): return null
	for rod: Node in host.get("_rods"):
		if is_instance_valid(rod) and rod.get_parent() != null and rod.get_parent().get_parent() != null:
			var c: Variant = rod.get_parent().get_parent().get("companions")
			if c is Node and is_instance_valid(c): return c
	return null

func _float(lease: Dictionary, rod: Node3D, actor: Node3D, magic: Node) -> void:
	var k := _size(actor)
	var forward: Vector3 = -actor.global_basis.z; forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > .01 else Vector3.FORWARD
	var right := forward.cross(Vector3.UP).normalized()
	var t := float(lease.get("hold_time", 0.0))
	# In front of her and to her right, a little below the horn, bobbing gently in the aura.
	var grip := _horn_tip(actor, magic) + forward * .42 * k + right * .2 * k + Vector3.UP * (-.12 * k + .015 * sin(t * 2.3))
	var along := (forward * .91 + Vector3.UP * (.42 + float(lease.get("lift", 0.0)))).normalized()
	var frame := Transform3D(Basis(right, along, right.cross(along).normalized()), grip)
	var start: Transform3D = lease.get("prop_start", rod.global_transform)
	rod.global_transform = start.interpolate_with(frame, smoothstep(0.0, .6, t))
	if not _glows.has(rod):
		var visual: Variant = rod.get("visual")
		var meshes: Array = magic.glow_object(visual if visual is Node3D else rod) if magic.has_method("glow_object") else []
		if magic.has_method("hold"): magic.hold(true)
		_glows[rod] = {"actor": actor, "magic": magic, "meshes": meshes}
		if DEBUG: print("[fishing] magic: %s lifts %s; horn %s, rod to %s (size %.2f, hold_time %.2f)" % [lease.get("id", "?"), rod.name,
			_horn_tip(actor, magic), grip, k, t])

func _unglow(rod: Node3D) -> void:
	var g: Dictionary = _glows.get(rod, {})
	_glows.erase(rod)
	if g.is_empty(): return
	if DEBUG: print("[fishing] magic: lets go of %s (now at %s, holder %s)" % [rod.name, rod.global_position, rod.get("holder")])
	preload("res://world/characters/magic/unicorn_magic.gd").unglow_object(g.get("meshes", []))
	var magic: Variant = g.get("magic")
	if magic is Node and is_instance_valid(magic) and magic.has_method("hold"): magic.hold(false)

## Her horn's tip from her magic (unicorn_magic.gd measures it), else above her head.
func _horn_tip(actor: Node3D, magic: Node) -> Vector3:
	var sk: Variant = magic.get("_skeleton"); var bone: Variant = magic.get("_bone"); var local: Variant = magic.get("_tip_local")
	if sk is Skeleton3D and is_instance_valid(sk) and bone is int and int(bone) >= 0 and local is Vector3:
		return (sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(int(bone)) * Vector3(local)
	var head: Vector3 = actor.call("listen_point") if actor.has_method("listen_point") else actor.global_position + Vector3.UP
	return head + Vector3.UP * .25 * _size(actor)

## Her size against a Canon mare, from her hips' height.
func _size(actor: Node3D) -> float:
	var sk: Variant = actor.get("skeleton")
	if not sk is Skeleton3D or not is_instance_valid(sk): return 1.0
	var hips := (sk as Skeleton3D).find_bone("pony_hips")
	if hips < 0: return 1.0
	var height := ((sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(hips).origin).y - actor.global_position.y
	return clampf(height / .59, .5, 2.5)  # as Idle Life measures it

func _exit_tree() -> void:
	for rod: Node3D in _glows.keys(): _unglow(rod)
	if is_instance_valid(_traced): _traced.set("trace", false)
