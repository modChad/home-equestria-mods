extends RefCounted
## Fishing: what bites, from where the float landed. Data in species.json.
## Water type comes from the water body's name (world/water/world_water.gd): PonyvilleCanals,
## River_<id>_<n>, Lake_<id>, Sea. Depth is the water surface minus the ground below the float.
## About 1 bite in 12 is junk; a rare fish now and then replaces its common kind when its
## conditions hold (time of day, water, how full the moon is).

const DATA := "res://mods/fishing/species.json"
static var _doc: Dictionary = {}

static func doc() -> Dictionary:
	if _doc.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary: _doc = parsed
	return _doc

static func species() -> Dictionary: return doc().get("species", {})
static func rare() -> Dictionary: return doc().get("rare", {})
static func junk() -> Dictionary: return doc().get("junk", {}).get("items", {})

## Name for any id: species, rare or junk.
static func name_of(id: String) -> String:
	for table: Dictionary in [species(), rare(), junk()]:
		if table.has(id): return str(table[id].get("name", id.capitalize()))
	return id.capitalize()

## Every fish id, commons then rares (the log's page order).
static func fish_ids() -> Array:
	return species().keys() + rare().keys()

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

## {id, name, length, size_t[, rare][, junk, keep, line]} or {} when nothing lives there (the sea).
static func pick(kind: String, depth: float, hour: float, rng: RandomNumberGenerator, moon := 0.0) -> Dictionary:
	if kind == "sea": return {}
	var j: Dictionary = doc().get("junk", {})
	if rng.randf() < float(j.get("chance", 0.0)):
		var got := _weighted(junk(), rng, func(row: Dictionary) -> float: return float(row.get("weight", 1.0)))
		if got != "":
			var row: Dictionary = junk()[got]
			return {"id": got, "name": row.name, "length": float(row.get("base", .2)), "size_t": 0.0, "junk": true,
				"keep": bool(row.get("keep", false)), "line": str(row.get("line", ""))}
	var band := time_band(hour)
	var id := _weighted(species(), rng, func(s: Dictionary) -> float:
		var w: float = float(s.habitat.get(kind, 0.0)) * float(s.time.get(band, 1.0))
		var d: Array = s.depth
		# Outside its depth range a fish is rarer, not impossible (depth is a rough read).
		if depth < float(d[0]): w *= .35
		elif depth > float(d[1]): w *= .6
		return w)
	if id == "": return {}
	var size: Array = species()[id].size
	var fish_name: String = species()[id].name
	var is_rare := false
	for rid: String in rare():
		var r: Dictionary = rare()[rid]
		if str(r.get("of", "")) != id: continue
		if r.has("time") and not band in r.time: continue
		if r.has("habitat") and not kind in r.habitat: continue
		if r.has("moon") and moon < float(r.moon): continue
		if rng.randf() < float(r.get("chance", 0.0)):
			id = rid; size = r.size; fish_name = r.name; is_rare = true; break
	# Sizes lean small: big ones are the stories.
	var t := pow(rng.randf(), 1.8)
	var out := {"id": id, "name": fish_name, "length": lerpf(float(size[0]), float(size[1]), t), "size_t": t}
	if is_rare: out["rare"] = true
	return out

static func _weighted(table: Dictionary, rng: RandomNumberGenerator, weight: Callable) -> String:
	var total := 0.0; var rows: Array = []
	for key: String in table:
		var w: float = weight.call(table[key]); rows.append([key, w]); total += w
	if total <= 0.0: return ""
	var roll := rng.randf() * total
	for r: Array in rows:
		roll -= r[1]
		if roll <= 0.0: return r[0]
	return rows.back()[0]
