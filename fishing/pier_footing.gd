extends Node
## Fishing: keeps pony companions from being sent home on the pier. fishing_companions.gd
## (physics priority -5) gives up on any frame a leased pony isn't grounded(), and up close
## (HERO tier) that is is_on_floor() or _heightmap_supported. On the deck is_on_floor() can drop
## out for a frame (0.5.1 log: Apple Bloom at the deck's bank end, "Waiting for safe ground
## support"), which ended every visit. Just before that check (priority -6), a leased pony who is
## on the pier, on deck height, and momentarily off her floor gets _heightmap_supported set:
## the game's own "held up by the ground below" flag, which its locomotion clears again as soon
## as she is on her floor. Ponies off the pier, flying, thrown or held are left alone.
var host: Node    # main.gd
const DEBUG := true
var _told: Dictionary = {}

func _ready() -> void:
	process_physics_priority = -6

func _physics_process(_delta: float) -> void:
	var companions: Node = _companions()
	if not is_instance_valid(companions): return
	var dock: Node3D = companions.get("dock")
	if not is_instance_valid(dock): return
	for lease: Dictionary in companions.get("leases"):
		var actor: Variant = lease.get("actor")
		if not actor is CharacterBody3D or not is_instance_valid(actor): continue
		var pony := actor as CharacterBody3D
		if pony.is_on_floor() or bool(pony.get("_heightmap_supported")): continue
		if pony.get("_held") == true: continue
		var thrown: Variant = pony.get("thrown")
		if thrown != null and thrown.has_method("active") and thrown.active(): continue
		var flight: Variant = pony.get("flight")
		if flight != null and flight.has_method("active") and flight.active(): continue
		var local := dock.to_local(pony.global_position)
		# On the deck or the top of the bank ramp, within a few cm of their surface.
		if absf(local.x) > 1.95 or local.z < -4.3 or local.z > 4.9 or local.y < -.45 or local.y > .2: continue
		pony.set("_heightmap_supported", true)
		var who := str(lease.get("id", "?"))
		if DEBUG and not _told.has(who):
			_told[who] = true
			print("[fishing] footing: kept %s on the pier at local %s (her floor check dropped out)" % [who, local])

func _companions() -> Node:
	if not is_instance_valid(host): return null
	for rod: Node in host.get("_rods"):
		if is_instance_valid(rod) and rod.get_parent() != null and rod.get_parent().get_parent() != null:
			var c: Variant = rod.get_parent().get_parent().get("companions")
			if c is Node and is_instance_valid(c): return c
	return null
