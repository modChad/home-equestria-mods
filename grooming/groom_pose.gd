extends SkeletonModifier3D
## The pony's side of grooming: small additive turns on her body skeleton, layered after
## locomotion and her other modifiers. One animation per action:
##   mane  - she tips her head toward the brush and nods softly with each stroke.
##   tail  - she looks back over her shoulder; her tail lifts aside and swishes (tail_motion.aside_goal).
##   coat  - she leans her body into the brush, drops her head low and sways with the strokes.
##   preen - wings held half open, she turns her neck back toward the wing and nuzzles; when done,
##           a quick wing shake.
## Every turn is a rotation about her own up / right / forward axes, a few degrees per bone, well
## inside the rig's joint limits. Bones are only rotated, never moved or scaled.

var mare: Node3D
var tool := ""
var amount := 0.0      # 0..1, eased by main.gd
var side := 1.0        # +1: the groomer is on her right, -1: on her left
var phase := 0.0       # stroke phase (radians), advanced while strokes land
var shake := 0.0       # 0..1 wing shake after preening

var _bones: Dictionary = {}
var _bound_skeleton: Skeleton3D


func _bind(sk: Skeleton3D) -> void:
	_bound_skeleton = sk
	_bones.clear()
	for bone_name: String in ["pony_spine1", "pony_spine2", "pony_spine3", "pony_neck1", "pony_neck2", "pony_head"]:
		_bones[bone_name] = sk.find_bone(bone_name)


func _process_modification_with_delta(_delta: float) -> void:
	if amount <= 0.001 or not is_instance_valid(mare): return
	var sk := get_skeleton()
	if sk == null: return
	if sk != _bound_skeleton: _bind(sk)
	var basis := mare.global_basis.orthonormalized()
	var up := basis.y
	var right := basis.x
	var forward := -basis.z
	var a := amount
	var s := side
	var wave := sin(phase)
	match tool:
		"mane":
			# Head tipped toward the brush, chin a little down, a soft nod with each stroke.
			_turn(sk, "pony_neck1", forward, s * deg_to_rad(3.0) * a)
			_turn(sk, "pony_neck2", right, deg_to_rad(-3.0 + 2.0 * wave) * a)
			_turn(sk, "pony_head", forward, s * deg_to_rad(9.0 + 2.0 * wave) * a)
			_turn(sk, "pony_head", right, deg_to_rad(-5.0 + 1.5 * wave) * a)
		"tail":
			# Looking back over the shoulder on the brushing side.
			_turn(sk, "pony_spine3", up, -s * deg_to_rad(4.0) * a)
			_turn(sk, "pony_neck1", up, -s * deg_to_rad(10.0) * a)
			_turn(sk, "pony_neck2", up, -s * deg_to_rad(9.0) * a)
			_turn(sk, "pony_head", up, -s * deg_to_rad(7.0) * a)
			_turn(sk, "pony_head", forward, s * deg_to_rad(4.0) * a)
		"coat":
			# Leaning into the brush, head low and relaxed, swaying with the strokes.
			for bone_name: String in ["pony_spine1", "pony_spine2", "pony_spine3"]:
				_turn(sk, bone_name, forward, s * deg_to_rad(2.2 + 0.8 * wave) * a)
			_turn(sk, "pony_neck1", right, deg_to_rad(-6.0) * a)
			_turn(sk, "pony_neck2", right, deg_to_rad(-4.0) * a)
			_turn(sk, "pony_head", right, deg_to_rad(3.0) * a)
			_turn(sk, "pony_head", forward, s * deg_to_rad(4.0 + 1.5 * wave) * a)
		"preen":
			# Neck curled back toward the wing, nose down to it, a little nuzzling motion.
			var nuzzle := sin(phase * 1.7)
			_turn(sk, "pony_neck1", up, -s * deg_to_rad(13.0) * a)
			_turn(sk, "pony_neck2", up, -s * deg_to_rad(12.0) * a)
			_turn(sk, "pony_head", up, -s * deg_to_rad(9.0 + 2.0 * nuzzle) * a)
			_turn(sk, "pony_head", right, deg_to_rad(-9.0 + 2.5 * nuzzle) * a)
			_turn(sk, "pony_head", forward, s * deg_to_rad(5.0) * a)
	if shake > 0.001:
		# A shiver through her withers that runs with the wing shake.
		_turn(sk, "pony_spine3", forward, deg_to_rad(2.5) * sin(shake * 40.0) * shake)


## Rotates `bone_name` by `angle` about `axis` (world), keeping its parent and children attached.
func _turn(sk: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	var bone: int = _bones.get(bone_name, -1)
	if bone < 0 or absf(angle) < 0.00001: return
	var local_axis := (sk.global_basis.orthonormalized().inverse() * axis).normalized()
	if not local_axis.is_finite() or local_axis.is_zero_approx(): return
	var parent := sk.get_bone_parent(bone)
	var parent_rotation := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var global := parent_rotation * sk.get_bone_pose_rotation(bone)
	sk.set_bone_pose_rotation(bone, (parent_rotation.inverse() * Quaternion(local_axis, angle) * global).normalized())
