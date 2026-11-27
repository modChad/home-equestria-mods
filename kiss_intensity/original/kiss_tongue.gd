extends Node3D
## Four skinned joints. Extension moves the root behind the lips while curl, twist and
## sweep accumulate along the chain, leaving the root seated inside the muzzle.
const MODEL := preload("res://mods/kiss_intensity/kiss_model.gd")
const LENGTH := 0.072
const REST_TIP := Vector3(0.0, 0.002, -LENGTH)
var tip_local: Vector3
var skeleton: Skeleton3D
var joints := PackedInt32Array()
var local_axes: Array[Basis] = []

func setup(mare: Node3D) -> bool:
	var model := MODEL.instantiate("res://mods/kiss_intensity/tongue.glb")
	if model == null: return false
	add_child(model)
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty(): return false
	skeleton = rigs[0] as Skeleton3D
	var material := _ki_tongue_material(mare)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		var joint := skeleton.find_bone("Tongue%d" % i)
		if joint < 0: return false
		joints.append(joint)
		local_axes.append(skeleton.get_bone_global_rest(joint).basis.orthonormalized().inverse())
	tip_local = skeleton.get_bone_global_rest(joints[-1]).affine_inverse() * REST_TIP
	return true


func follow(head: Transform3D, lips: Vector3, socket: Vector3, out: float, act: RefCounted) -> void:
	var size := head.basis.y.length()
	var into := socket - lips
	var forward := head.basis.z.normalized()
	var aim := forward
	if into.length_squared() > 0.000001:
		aim = forward.slerp(into.normalized(), smoothstep(0.15, 0.75, out)).normalized()
	var reach := minf(lerpf(-0.014, 0.035, out), into.length() / size)
	if reach <= 0.0:
		hide()
		return
	var side := head.basis.y.cross(-aim).normalized()
	if side.length_squared() < 0.5: return
	var frame := Basis(side, -aim.cross(side), -aim).scaled(Vector3.ONE * size)
	pose_at(Transform3D(frame, lips), out, act.curl, act.roll, act.circle)
	# Locate the section that crosses her lips after skinning. Fit that section to
	# the lip opening and the exposed segment to his mouth, even with a curled tip.
	var station := (1.0 - reach / LENGTH) * joints.size()
	var joint := clampi(floori(station), 0, joints.size() - 1)
	var start := skeleton.get_bone_global_pose(joints[joint]).origin
	var tip := tip_world()
	var end := skeleton.to_local(tip)
	if joint + 1 < joints.size(): end = skeleton.get_bone_global_pose(joints[joint + 1]).origin
	var through := skeleton.to_global(start.lerp(end, station - joint))
	var chord := tip - through
	if chord.length_squared() < 0.00000001: return
	var align := Basis(Quaternion(chord.normalized(), aim))
	var origin := lips + align * (global_position - through)
	global_transform = Transform3D(align * frame, origin)


func tip_world() -> Vector3:
	return skeleton.global_transform * (skeleton.get_bone_global_pose(joints[-1]) * tip_local)


func pose_at(frame: Transform3D, out: float, curl: float, roll: float, sweep: Vector2) -> void:
	global_transform = frame
	for i in joints.size():
		var share := float(i) / 6.0
		var axes := local_axes[i]
		var bend := Quaternion(axes.x, deg_to_rad(42.0 * curl + 9.0 * sweep.y) * out * share)
		var turn := Quaternion(axes.y, deg_to_rad(16.0 * sweep.x) * out * share)
		var twist := Quaternion(-axes.z, deg_to_rad(18.0 * roll) * share)
		var rest := skeleton.get_bone_rest(joints[i]).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(joints[i], rest * turn * bend * twist)
	visible = true


## Her own tongue's material, so the mesh is lit and coloured as the inside of her mouth is.
static func _ki_tongue_material(mare: Node3D) -> Material:
	for mesh: MeshInstance3D in mare.find_children("Tongue", "MeshInstance3D", true, false):
		var look := mesh.get_active_material(0)
		if look != null: return look
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color("d9668a")
	plain.roughness = 1.0
	return plain
