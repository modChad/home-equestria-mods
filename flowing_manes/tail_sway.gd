extends SkeletonModifier3D
## The big slow S-curve of a flowing tail: a wave travels down the body's five tail bones
## (pony_tail_01..05), side to side with a gentle lift. Small additive turns on top of whatever the
## game does with the tail, inside its own spring limits. The shader adds the fine ripples.

const BONES := ["pony_tail_01", "pony_tail_02", "pony_tail_03", "pony_tail_04", "pony_tail_05"]
## Per bone, radians: side swing and lift. Under the game's tail angle limits (0.14..0.24 rad).
const SIDE := [0.05, 0.08, 0.10, 0.12, 0.12]
const LIFT := [0.02, 0.03, 0.04, 0.05, 0.05]

var pony: Node3D
var amount := 0.0
var speed := 0.32        # cycles per second
var lag := 0.9           # radians of phase from one bone to the next
var seed := 0.0
var _bones := PackedInt32Array()
var _bound: Skeleton3D
var _phase := 0.0
## Set by main.gd from her mood: pace and swing multipliers, and her movement's trail
## (skeleton-independent: radians of extra swing to her right / lift).
var speed_scale := 1.0
var swing_scale := 1.0
var trail_side := 0.0
var trail_lift := 0.0


func _bind(sk: Skeleton3D) -> void:
	_bound = sk
	_bones = PackedInt32Array()
	for name: String in BONES: _bones.append(sk.find_bone(name))


func _process_modification_with_delta(delta: float) -> void:
	_phase += delta * speed * speed_scale
	if amount <= 0.001 or not is_instance_valid(pony): return
	var sk := get_skeleton()
	if sk == null: return
	if sk != _bound: _bind(sk)
	var to_skeleton := sk.global_basis.orthonormalized().inverse()
	var up := (to_skeleton * pony.global_basis.y).normalized()
	var right := (to_skeleton * pony.global_basis.x).normalized()
	for i in _bones.size():
		var bone := _bones[i]
		if bone < 0: continue
		var ph := TAU * _phase - lag * i + seed
		var reach := float(i + 1) / BONES.size()
		var side: float = (sin(ph) * SIDE[i] * swing_scale + trail_side * reach * 0.12) * amount
		var lift: float = (sin(ph * 0.7 + 1.1) * LIFT[i] * swing_scale + trail_lift * reach * 0.06) * amount
		var turn := Quaternion(up, side) * Quaternion(right, lift)
		var parent := sk.get_bone_parent(bone)
		var parent_rot := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		var global := parent_rot * sk.get_bone_pose_rotation(bone)
		sk.set_bone_pose_rotation(bone, (parent_rot.inverse() * turn * global).normalized())
