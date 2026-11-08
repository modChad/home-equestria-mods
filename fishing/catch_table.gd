extends RefCounted
## Fishing: which fish bites, from where the float landed. Data in species.json.
## Water type comes from the water body's name (world/water/world_water.gd): PonyvilleCanals,
## River_<id>_<n>, Lake_<id>, Sea. Depth is the water surface minus the ground below the float.

const DATA := "res://mods/fishing/species.json"
static var _species: Dictionary = {}

static func species() -> Dictionary:
	if _species.is_empty():
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if doc is Dictionary: _species = doc.get("species", {})
	return _species

## "canal", "river", "lake", "sea" or "" for a water collider.
static func water_kind(collider: Object) -> String:
	var node := collider as Node
	for _i in 3:
		if node == null: break
		var n := String(node.name)
		if n.begins_with("PonyvilleCanals"): return "canal"
		if n.begins_with("River_"): return "river"
		if n.begins_with("Lake_"): return "lake"
		if n.begins_with("Sea"): return "sea"
		node = node.get_parent()
	return "river"  # baked native water (older scenes): flowing water is the safest guess

static func time_band(hour: float) -> String:
	if hour >= 5.0 and hour < 8.0: return "dawn"
	if hour >= 8.0 and hour < 17.0: return "day"
	if hour >= 17.0 and hour < 20.0: return "dusk"
	return "night"

## Weighted pick: {id, name, length} or {} when nothing lives there (the sea).
static func pick(kind: String, depth: float, hour: float, rng: RandomNumberGenerator) -> Dictionary:
	var band := time_band(hour)
	var total := 0.0
	var weights: Array = []
	for id: String in species():
		var s: Dictionary = species()[id]
		var w: float = float(s.habitat.get(kind, 0.0)) * float(s.time.get(band, 1.0))
		var d: Array = s.depth
		# Outside its depth range a fish is rarer, not impossible (depth is a rough read).
		if depth < float(d[0]): w *= .35
		elif depth > float(d[1]): w *= .6
		weights.append([id, w]); total += w
	if total <= 0.0: return {}
	var roll := rng.randf() * total
	for pair: Array in weights:
		roll -= pair[1]
		if roll <= 0.0:
			var s: Dictionary = species()[pair[0]]
			# Sizes lean small: big ones are the stories.
			var t := pow(rng.randf(), 1.8)
			return {"id": pair[0], "name": s.name, "length": lerpf(float(s.size[0]), float(s.size[1]), t), "size_t": t}
	return {}
