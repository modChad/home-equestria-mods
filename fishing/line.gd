extends RefCounted
## Fishing: the mod's line, swapped in for each pier rod's own (world/minigames/fishing/fishing_line.gd).
## Same public shape (state, bobber, velocity, reset/cast/tick/hook/reel, caught/changed), so the
## game's rod, hands and companions drive it unchanged. Differences:
##  - the cast follows the camera's pitch: look up to throw far, down to drop it close;
##  - a fish nibbles once or twice before it bites, and the bite waits 3.5 s (was 2.6);
##  - the bite's species is picked from where the float landed (catch_table.gd);
##  - it does its own ray sweep so it knows which water it hit.
signal caught(at: Vector3)
signal changed(state: String)
## A held catch was dropped by a reset (the rod went back to the rack): main.gd keeps it.
signal dropped(fish: Dictionary)
const TABLE := preload("res://mods/fishing/catch_table.gd")
const MAX_LINE: float = 16.0
const BITE_WINDOW: float = 3.5
const WATER := 1 << 15
var state: String = "ready"
var bobber: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var water_y: float = 0.0
var remaining: float = 0.0
var tension: float = 0.0        # metres of stretch; the line parts at 2.5
var clock: float = 0.0
var wait_time: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Mod additions, read by feedback.gd and main.gd.
var rod: Node3D
var water_kind: String = ""
var water_depth: float = 0.0
var fish: Dictionary = {}       # the fish on the line from the bite on: {id, name, length, size_t}
var nibble: float = -1.0        # >= 0 while a nibble dip plays (seconds into it)
var thrash: float = 0.0         # 0..1, how hard a hooked fish is pulling right now
var landed_at: Vector3 = Vector3.INF
var _nibbles: Array = []        # wait clock times of the nibbles to come
var _rod_last: Vector3
var _ready: bool = false
var _lifting: bool = false

func reset(tip: Vector3) -> void:
	if state == "landed" and not fish.is_empty():
		var held: Dictionary = fish; fish = {}
		dropped.emit(held)
	bobber = tip; velocity = Vector3.ZERO; tension = 0; remaining = 0; thrash = 0; nibble = -1
	_rod_last = tip; _ready = true; _lifting = false; fish = {}; _nibbles = []
	_set_state("ready")

func cast(tip: Vector3, direction: Vector3, strength: float = 1.0) -> bool:
	if state != "ready" or not tip.is_finite() or not direction.is_finite() or direction.length_squared() < .01: return false
	reset(tip)
	var horizontal := Vector3(direction.x, 0, direction.z)
	if horizontal.length_squared() < .01: return false
	horizontal = horizontal.normalized()
	# Pitch sets the throw: looking down 40 deg drops it ~3 m out, level ~9 m, up 20 deg ~13 m.
	var pitch := asin(clampf(direction.normalized().y, -1.0, 1.0))
	var angle := clampf(pitch + deg_to_rad(28.0), deg_to_rad(-10.0), deg_to_rad(55.0))
	var speed := clampf(lerpf(4.0, 10.5, inverse_lerp(deg_to_rad(-40.0), deg_to_rad(20.0), pitch)), 3.5, 10.5) * clampf(strength, .7, 1.3)
	velocity = horizontal * speed * cos(angle) + Vector3.UP * speed * sin(angle)
	clock = 0; landed_at = Vector3.INF; _set_state("casting"); return true

## The sweep argument is the rod's own (kept for the shape); this line sweeps itself.
func tick(delta: float, tip: Vector3, _sweep: Callable) -> void:
	if not tip.is_finite() or delta <= 0: return
	if not _ready: reset(tip)
	clock += delta
	if state == "ready": bobber = tip
	elif state == "casting":
		velocity.y -= 9.8 * delta
		var next: Vector3 = bobber + velocity * delta
		var hit: Dictionary = _ray(bobber, next)
		if not hit.is_empty():
			bobber = hit.position
			if (hit.collider as CollisionObject3D).collision_layer & WATER:
				water_y = bobber.y; remaining = tip.distance_to(bobber); landed_at = bobber
				water_kind = TABLE.water_kind(hit.collider)
				water_depth = _depth_below(bobber)
				wait_time = rng.randf_range(5.0, 13.0); clock = 0
				_nibbles = []
				for i in rng.randi_range(0, 2): _nibbles.append(rng.randf_range(1.5, wait_time - 1.0))
				_set_state("waiting")
			else: reset(tip)
		else: bobber = next
		if tip.distance_to(bobber) > MAX_LINE or clock > 5: reset(tip)
	elif state == "waiting":
		if nibble >= 0.0:
			nibble += delta
			if nibble > .45: nibble = -1.0
		for t in _nibbles:
			if clock >= t:
				_nibbles.erase(t); nibble = 0.0; changed.emit("nibble"); break
		if not _lifting:
			var dip := sin(clamp(nibble, 0.0, .45) / .45 * PI) * .03 if nibble >= 0.0 else 0.0
			bobber.y = water_y + .025 + sin(clock * 2.8) * .013 - dip
			if clock >= wait_time:
				fish = TABLE.pick(water_kind, water_depth, _hour(), rng, _moon())
				if fish.is_empty():  # nothing lives here (the sea): try again later
					clock = 0; wait_time = rng.randf_range(8.0, 15.0)
				else:
					clock = 0; _set_state("bite")
	elif state == "bite":
		# A hard plunge then jerks: the float pulled under.
		var plunge := minf(clock / .15, 1.0)
		bobber.y = water_y - .12 * plunge + sin(clock * 18.0) * .03
		if tip.y - _rod_last.y > maxf(.045, delta * .65): hook()
		elif clock > BITE_WINDOW:
			clock = 0; wait_time = rng.randf_range(6, 14); fish = {}; _set_state("waiting")
	elif state == "landed":
		pass  # feedback.gd puts the hook (bobber) at the held fish's mouth
	elif state == "hooked":
		# The fish pulls in bursts; bigger fish pull harder. Cosy: it never breaks the line alone.
		var size_t: float = fish.get("size_t", .3)
		if fish.get("junk", false): thrash = .04; size_t = 0.0  # junk just drags
		else: thrash = clampf(.35 + .65 * maxf(0.0, sin(clock * (2.2 + size_t)) * sin(clock * 5.3)), 0.0, 1.0) * (.5 + .5 * size_t)
		if not _lifting:
			bobber.y = water_y + .01 + sin(clock * 14) * .02 * (1.0 + thrash)
		var distance: float = tip.distance_to(bobber)
		# Walking away cannot reel: an overstretched line loses its fish.
		tension = maxf(0.0, distance - remaining)
		if tension > 2.5:
			changed.emit("lost"); reset(tip)
	_rod_last = tip

## The mod's own state after a player's catch: the fish hangs on a short line at the rod tip until
## it is kept or released (main.gd). The game's hands do nothing in a state they don't know, so
## the rod can't be cast meanwhile.
func land(caught_fish: Dictionary) -> void:
	fish = caught_fish; clock = 0; _set_state("landed")

func hook() -> bool:
	if state != "bite": return false
	clock = 0; tension = 0; _set_state("hooked"); return true

## Metres collected by turning the reel (mouse wheel / the other hand).
func reel(metres: float, tip: Vector3) -> bool:
	if state not in ["waiting", "bite", "hooked"] or metres <= 0 or not is_finite(metres): return false
	var has_fish: bool = state == "hooked"
	metres = minf(metres, .35)
	if has_fish: metres *= lerpf(1.0, .55, thrash)  # a pulling fish gives line back slowly
	remaining = maxf(0, remaining - metres)
	var toward: Vector3 = tip - bobber
	var distance: float = toward.length()
	if not _lifting and Vector2(toward.x, toward.z).length() > 1.5:
		toward.y = 0
	else:
		_lifting = true
		if state == "bite": fish = {}; _set_state("waiting")
	if distance > .001:
		bobber += toward.normalized() * minf(metres, toward.length())
	if tip.distance_to(bobber) <= .65:
		var at: Vector3 = bobber
		var landed: Dictionary = fish
		reset(tip)
		if has_fish:
			fish = landed  # still readable by caught's listeners
			caught.emit(at)
			if state != "landed": fish = {}
	return true

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if not is_instance_valid(rod) or not rod.is_inside_tree(): return {}
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | WATER)
	var excludes: Array[RID] = rod.get("player_excludes").duplicate()
	excludes.append(rod.grip.get_rid()); q.exclude = excludes; q.hit_back_faces = true
	return rod.get_world_3d().direct_space_state.intersect_ray(q)

func _depth_below(at: Vector3) -> float:
	if not is_instance_valid(rod): return 1.0
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.DOWN * .05, at + Vector3.DOWN * 30.0, 1)
	var hit := rod.get_world_3d().direct_space_state.intersect_ray(q)
	return at.y - float(hit.position.y) if not hit.is_empty() else 2.0

func _hour() -> float:
	if is_instance_valid(rod) and rod.is_inside_tree():
		var tod: Node = rod.get_tree().root.get_node_or_null("TimeOfDay")
		if tod != null and "hours" in tod: return float(tod.hours)
	return 12.0

func _moon() -> float:
	if is_instance_valid(rod) and rod.is_inside_tree():
		var tod: Node = rod.get_tree().root.get_node_or_null("TimeOfDay")
		if tod != null and tod.has_method("moon_lit_fraction"): return float(tod.moon_lit_fraction())
	return 0.0

func _set_state(next: String) -> void:
	if next == state: return
	state = next; changed.emit(state)
