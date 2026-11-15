extends Node
## Fishing: a fish thrown into the water swims away, and junk sinks, for good. The game parks every
## dropped item at its last saved spot and, if it then falls more than 2 m below it, deletes it
## and puts it back there (briefcase_drops.gd _sync_dropped_items), so a fish thrown off the pier
## came back on the deck. Every quarter second this looks for loose fish and junk items under a
## water surface, takes them out of the inventory and lets them go with a splash. Not counted as
## a release: the catch was already counted.
const WATER := 1 << 15
const SOUNDS := preload("res://mods/fishing/sounds.gd")
var host: Node   # main.gd
var _scan := 0.0

func _physics_process(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0: return
	_scan = .25
	var inv: Node = host.call("_any_inventory") if is_instance_valid(host) else null
	if not is_instance_valid(inv) or not inv.is_inside_tree(): return
	var loose: Variant = inv.get("loose")
	if not loose is Dictionary or (loose as Dictionary).is_empty(): return
	var held: Array = (inv.get("held") as Dictionary).values() if inv.get("held") is Dictionary else []
	var space: PhysicsDirectSpaceState3D = (inv as Node3D).get_world_3d().direct_space_state
	for token: Variant in (loose as Dictionary).keys():
		var item: Node3D = loose[token] as Node3D
		if not is_instance_valid(item) or item in held: continue
		var id := str(item.get_meta("item_id", ""))
		var fish := id.begins_with("food:fish-") or id.ends_with("river-fish")
		if not fish and not id.begins_with("food:junk-"): continue
		var surface := _water_above(space, item.global_position)
		if not surface.is_finite(): continue
		if not inv.inventory.consume(str(token)): continue
		(loose as Dictionary).erase(token)
		SOUNDS.play_at(host, "plop", surface, -4.0, 1.15 if fish else .8)
		print("[fishing] water: ", id, " went into the water", " and swam off" if fish else " and sank")
		item.queue_free()

## The water surface over this point, or INF if it isn't under water.
func _water_above(space: PhysicsDirectSpaceState3D, at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.UP * .02, WATER)
	query.collide_with_areas = true; query.hit_back_faces = true
	var hit := space.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector3.INF
