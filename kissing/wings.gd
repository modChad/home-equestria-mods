extends SkeletonModifier3D
## Kissing: her spread wings shiver as her feelings run high (feelings.gd `level`).
##
## The game spreads a pegasus's or alicorn's wings while she's excited (excitement.gd, through
## hybrid_open_wings.gd). Once they're fully spread and her feelings pass SHIVER_FROM, a fine
## tremble runs through them: every wing bone turns a little about its own axes, each with its own
## mix of quick waves, stronger toward the feather tips, and now and then a ripple runs out along
## the wing. It grows with her feelings, and stops as the wings fold. Runs after every other
## modifier (the wing tuck included), so flight and the half-open hold are untouched beneath it.

const SHIVER_FROM := 0.45
const SHIVER_FULL := 0.95
## Most a bone turns at full shiver (degrees): roots, then feathers, then feather tips.
const ROOT_DEGREES := 0.5
const FEATHER_DEGREES := 1.4
const TIP_DEGREES := 2.0
## The tremble's quick waves (per second), mixed per bone.
const RATES := [11.0, 17.0, 23.0]
## A ripple out along the wing every few seconds, lasting RIPPLE_SECONDS.
const RIPPLE_EVERY := Vector2(1.8, 4.0)
const RIPPLE_SECONDS := 0.45
const RIPPLE_GAIN := 0.8

var mare: Node3D
var feelings: Node
var amount := 0.0 # The shiver now, 0..1 (for the lab).
var _bones: Array[int] = []
var _reach: Array[float] = [] # Degrees at full shiver, per bone.
var _order: Array[float] = [] # 0 at the wing root .. 1 at the tip, for the ripple.
var _phases: Array[Vector3] = []
var _base: Array[Quaternion] = [] # Each bone's pose beneath the tremble.
var _written: Array[Quaternion] = [] # What the tremble last wrote.
var _clock := 0.0
var _ripple := -1.0
var _next_ripple := 2.0


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null: return
	for side: String in ["L", "R"]:
		for name: String in ["WingBase", "WingBaseF", "WingBaseR"]:
			_add(sk, "pony_%s_%s" % [name, side], ROOT_DEGREES, 0.0)
		for name: String in ["FeatherBaseF", "FeatherBaseF_001", "FeatherBaseM", "FeatherBaseM_001", "FeatherBaseR", "FeatherSmall"]:
			_add(sk, "pony_%s_%s" % [name, side], FEATHER_DEGREES, 0.5)
		for name: String in ["FeatherTipF", "FeatherTipM", "FeatherTipR"]:
			_add(sk, "pony_%s_%s" % [name, side], TIP_DEGREES, 1.0)


func _add(sk: Skeleton3D, name: String, degrees: float, order: float) -> void:
	var bone := sk.find_bone(name)
	if bone < 0: return
	_bones.append(bone)
	_reach.append(deg_to_rad(degrees))
	_order.append(order)
	_phases.append(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	_base.append(sk.get_bone_pose_rotation(bone))
	_written.append(Quaternion(0.0, 0.0, 0.0, 0.0))


func _process_modification_with_delta(delta: float) -> void:
	_clock += delta
	var want := 0.0
	var level: float = float(feelings.get("level")) if is_instance_valid(feelings) else 0.0
	var spread := _spread()
	if spread > 0.0: want = smoothstep(SHIVER_FROM, SHIVER_FULL, level) * spread
	amount = move_toward(amount, want, delta * 1.5)
	if _bones.is_empty(): return
	if amount <= 0.001:
		_settle()
		return
	# A ripple out along the wing now and then, more often as she feels more.
	_next_ripple -= delta
	if _next_ripple <= 0.0:
		_ripple = 0.0
		_next_ripple = randf_range(RIPPLE_EVERY.x, RIPPLE_EVERY.y) / maxf(amount, 0.3)
	if _ripple >= 0.0:
		_ripple += delta / RIPPLE_SECONDS
		if _ripple > 1.6: _ripple = -1.0
	var sk := get_skeleton()
	for i in _bones.size():
		var p: Vector3 = _phases[i]
		var t := _clock * TAU
		var wave := Vector3(
			sin(t * RATES[0] + p.x) * 0.6 + sin(t * RATES[2] + p.y) * 0.4,
			sin(t * RATES[1] + p.y) * 0.7 + sin(t * RATES[0] + p.z) * 0.3,
			sin(t * RATES[2] + p.z) * 0.5 + sin(t * RATES[1] + p.x) * 0.5)
		var gain := 1.0
		if _ripple >= 0.0:
			# A bump that travels from root (order 0) to tip (order 1).
			gain += RIPPLE_GAIN * exp(-pow((_ripple - _order[i]) * 4.0, 2.0))
		var angles := wave * _reach[i] * amount * gain
		var bone: int = _bones[i]
		# Nothing rewrites the open wing's bones every frame (the tuck lets go of them once they're
		# open), so the tremble goes on top of the pose from before it, not on top of itself.
		var now := sk.get_bone_pose_rotation(bone)
		var base: Quaternion = _base[i] if _written.size() > i and now.is_equal_approx(_written[i]) else now
		var shaken := base * Quaternion.from_euler(angles)
		sk.set_bone_pose_rotation(bone, shaken)
		_base[i] = base
		_written[i] = shaken


## The tremble over: each bone it last wrote goes back to the pose beneath, once.
func _settle() -> void:
	var sk := get_skeleton()
	if sk == null: return
	for i in _bones.size():
		if _written[i].is_equal_approx(Quaternion(0.0, 0.0, 0.0, 0.0)): continue
		if sk.get_bone_pose_rotation(_bones[i]).is_equal_approx(_written[i]): sk.set_bone_pose_rotation(_bones[i], _base[i])
		_written[i] = Quaternion(0.0, 0.0, 0.0, 0.0)


func _exit_tree() -> void:
	_settle()


## How fully spread her wings are: 1 open, 0 folded (or flying: her flight has them).
func _spread() -> float:
	var flight: Variant = mare.get("flight") if is_instance_valid(mare) else null
	if flight == null: return 0.0
	if flight.has_method("active") and bool(flight.call("active")): return 0.0
	var wings: Variant = flight.get("wings")
	if not wings is Node or not is_instance_valid(wings) or not bool(wings.get("opened")): return 0.0
	return clampf(1.0 - float(wings.get("tuck")), 0.0, 1.0) * clampf(1.0 - float(wings.get("half")), 0.0, 1.0)
