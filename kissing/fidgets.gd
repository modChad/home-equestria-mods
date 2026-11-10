extends SkeletonModifier3D
## Kissing: an earth pony grows fidgety as her feelings build (feelings.gd `level`).
##
## Earth ponies have no horn to glow or wings to shiver, so they show it in their body, all of it
## growing with her feelings:
## - weight shifting: she rocks gently side to side and a little front to back, the whole body
##   turning about her hooves (the skeleton's root bone, a few degrees), quicker as it builds;
## - tail swishing: her tail swings side to side (hybrid_tail_motion.gd aside_goal), wider and
##   faster as it builds;
## - ear flicks: now and then an ear twitches up (her face rig's ear shapes), more often as it
##   builds;
## - hoof taps: past TAP_FROM she lifts a forehoof for a moment and sets it down again
##   (pony_hoof_hold.gd raise), more often as it builds, whenever her forehooves are free.
## The game's own excited kick and raised forehoof (excitement.gd) still happen as before.

const SWAY_DEGREES := Vector2(1.0, 3.0) # Side to side, at no feelings .. full.
const ROCK_DEGREES := 1.2 # Front to back at full.
const SWAY_RATE := Vector2(0.35, 0.7) # Rocks per second.
const TAIL_RADIANS := Vector2(0.12, 0.45)
const TAIL_RATE := Vector2(0.5, 1.3)
const EAR_EVERY := Vector2(5.0, 1.2) # Seconds between flicks.
const EAR_SECONDS := 0.28
const EAR_SHAPES := ["ears_alert", "ears_side"]
const TAP_FROM := 0.3
const TAP_EVERY := Vector2(4.0, 1.6)
const TAP_SECONDS := Vector2(0.3, 0.55)

var mare: Node3D
var feelings: Node
var amount := 0.0 # How fidgety, 0..1 (eased from her feelings).
var _root := -1
var _clock := 0.0
var _sway_phase := 0.0
var _tail_phase := 0.0
var _tail_owned := false
var _ear_next := 2.0
var _ear_left := 0.0
var _ear_shape := ""
var _tap_next := 2.0


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null: return
	for bone in sk.get_bone_count():
		if sk.get_bone_parent(bone) < 0:
			_root = bone
			break


func _process(delta: float) -> void:
	if not is_instance_valid(mare): return
	var level: float = float(feelings.get("level")) if is_instance_valid(feelings) else 0.0
	amount = move_toward(amount, level, delta * 0.8)
	_clock += delta
	_tail(delta)
	_ears(delta)
	_taps(delta)


## Weight shifting: the whole body about her hooves.
func _process_modification_with_delta(delta: float) -> void:
	if amount <= 0.001 or _root < 0: return
	_sway_phase += delta * TAU * lerpf(SWAY_RATE.x, SWAY_RATE.y, amount)
	var side := deg_to_rad(lerpf(SWAY_DEGREES.x, SWAY_DEGREES.y, amount)) * amount * sin(_sway_phase)
	var rock := deg_to_rad(ROCK_DEGREES) * amount * sin(_sway_phase * 0.5 + 1.3)
	var sk := get_skeleton()
	# In skeleton space: z runs along her body, x across it.
	var turn := Quaternion(Vector3(0.0, 0.0, 1.0), side) * Quaternion(Vector3(1.0, 0.0, 0.0), rock)
	# About the ground under her (the skeleton's floor), not the root bone's own origin, so her
	# hooves stay where they stand.
	var at := sk.get_bone_pose_position(_root)
	var floor := Vector3(at.x, 0.0, at.z)
	sk.set_bone_pose_position(_root, floor + turn * (at - floor))
	sk.set_bone_pose_rotation(_root, turn * sk.get_bone_pose_rotation(_root))


func _tail(delta: float) -> void:
	var tail: Variant = mare.get("tail_motion")
	if not tail is Object or not is_instance_valid(tail) or not "aside_goal" in tail: return
	# The spa table moves her tail aside for his hands; it has the tail while she's a client.
	if mare.has_meta("spa_client"):
		_tail_owned = false
		return
	if amount <= 0.01:
		if _tail_owned:
			tail.set("aside_goal", 0.0)
			_tail_owned = false
		return
	_tail_phase += delta * TAU * lerpf(TAIL_RATE.x, TAIL_RATE.y, amount)
	tail.set("aside_goal", lerpf(TAIL_RADIANS.x, TAIL_RADIANS.y, amount) * amount * sin(_tail_phase))
	_tail_owned = true


func _ears(delta: float) -> void:
	var ears: Variant = _ear_dict()
	if ears == null: return
	if _ear_left > 0.0:
		_ear_left -= delta
		var t := 1.0 - _ear_left / EAR_SECONDS
		ears[_ear_shape] = sin(clampf(t, 0.0, 1.0) * PI)
		if _ear_left <= 0.0: ears.erase(_ear_shape)
		return
	if amount < 0.05: return
	_ear_next -= delta
	if _ear_next > 0.0: return
	_ear_shape = EAR_SHAPES[randi() % EAR_SHAPES.size()]
	if ears.has(_ear_shape): return # Her face is already using it (a line, a mood).
	_ear_left = EAR_SECONDS
	_ear_next = lerpf(EAR_EVERY.x, EAR_EVERY.y, amount) * randf_range(0.6, 1.4)


func _ear_dict() -> Variant:
	var expressions: Variant = mare.get("expressions")
	var eyes: Variant = expressions.get("eyes") if expressions is Object else null
	var ears: Variant = eyes.get("expression_ears") if eyes is Object and is_instance_valid(eyes) else null
	return ears if ears is Dictionary else null


func _taps(delta: float) -> void:
	if amount < TAP_FROM: return
	_tap_next -= delta
	if _tap_next > 0.0: return
	_tap_next = lerpf(TAP_EVERY.x, TAP_EVERY.y, amount) * randf_range(0.7, 1.3)
	var hold: Variant = mare.get("hoof_hold")
	if hold == null or not hold.has_method("raise") or int(hold.get("leg_index")) >= 0: return
	hold.raise(randi() % 2, randf_range(TAP_SECONDS.x, TAP_SECONDS.y))


func _exit_tree() -> void:
	if _tail_owned and is_instance_valid(mare):
		var tail: Variant = mare.get("tail_motion")
		if tail is Object and is_instance_valid(tail): tail.set("aside_goal", 0.0)
	var ears: Variant = _ear_dict() if is_instance_valid(mare) else null
	if ears != null and _ear_left > 0.0: ears.erase(_ear_shape)
