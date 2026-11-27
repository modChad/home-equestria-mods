extends RefCounted
## Owns the player's camera mask, first-person face and desktop pitch offset during a kiss.
const KI := preload("res://mods/kiss_intensity/kiss_terms.gd")
const FACE := preload("res://mods/kiss_intensity/own_face.gd")
var tip := 0.0
var piece: MeshInstance3D
var _camera: Camera3D
var _hide: SkeletonModifier3D
var _owner: Node
var _added_layer := false

func restore_pitch(kisser: Node) -> void:
	if tip > 0.0: _set_pitch(kisser, 0.0)

func update(kisser: Node, affection: Node, delta: float) -> void:
	var level := -1.0
	if is_instance_valid(affection) and affection.has_method("ki_level"): level = affection.ki_level()
	if level < 0.0 and piece == null and tip == 0.0: return
	var camera: Camera3D = kisser.get("camera") if is_instance_valid(kisser) else null
	if level >= 0.0 and is_instance_valid(camera) and KI.on("own_face") and _human(kisser):
		if _camera != camera or _owner != affection: drop()
		if piece == null: _attach(kisser, camera, affection)
		if is_instance_valid(piece):
			if _head_hidden(_hide):
				var size := XRServer.world_scale if camera is XRCamera3D else float(preload("res://player/player_mouth.gd").human_scale(camera))
				if camera is XRCamera3D: piece.transform = FACE.seat(1.0)
				else: piece.global_transform = Transform3D(camera.global_basis.orthonormalized(), camera.global_position) * FACE.seat(size)
				affection.ki_his_lips = FACE.HIS_LIPS * size
				affection.ki_lower_lip = FACE.part(piece, affection.ki_jaw)
			else: drop()
	else: drop()
	var want := KI.view_tip(level)
	# In a breather the tip eases most of the way back, so her eyes and her mouth are both in
	# view (critique 2026-11-25: at the full tip the breather showed her chin and forelegs).
	if want > 0.0 and is_instance_valid(affection) and affection.get("pose") != null:
		want *= 1.0 - KI.VIEW_TIP_BREATHER * clampf(float(affection.pose.pause), 0.0, 1.0)
	if tip == 0.0 and want == 0.0: return
	tip = KI.ease_tip(tip, want, delta)
	if not _set_pitch(kisser, tip): tip = 0.0

func _set_pitch(kisser: Node, angle: float) -> bool:
	if not is_instance_valid(kisser) or kisser.get("controller") != null: return false
	var body: Variant = kisser.get("body")
	var camera := kisser.get("camera") as Camera3D
	if not is_instance_valid(body) or not is_instance_valid(camera) or camera.get_parent() != body: return false
	if body.get("_pitch") == null or body.get("headset_view") == true or is_instance_valid(body.get("form_driver")) or camera.top_level: return false
	var pitch := float(body.get("_pitch"))
	camera.rotation.x = maxf(pitch - angle, minf(pitch, -1.45))
	return true

func _human(kisser: Node) -> bool:
	var body: Variant = kisser.get("body")
	if is_instance_valid(body) and is_instance_valid(body.get("form_driver")): return false
	var form: Node = preload("res://player/pony_form.gd").find(kisser.get_tree())
	return form == null or not is_instance_valid(form.get("avatar"))

func _head_hidden(hide: SkeletonModifier3D) -> bool:
	return is_instance_valid(hide) and hide.active and hide.influence > 0.0 and hide.is_visible_in_tree()

func _attach(kisser: Node, camera: Camera3D, affection: Node) -> void:
	var at := kisser.get("body") as Node
	if at == null: at = camera
	for step in 4:
		if at == null or at == camera.get_tree().root: return
		_hide = at.find_child("HeadHide", true, false) as SkeletonModifier3D
		if _hide != null: break
		at = at.get_parent()
	if not _head_hidden(_hide) or _hide.get("head_bone") == null: return
	var headset := camera is XRCamera3D
	piece = FACE.piece(_hide.get_skeleton(), _hide.get("head_bone"), headset)
	if piece == null: return
	var parent := camera if headset else camera.get_parent()
	parent.add_child(piece)
	_added_layer = camera.cull_mask & FACE.LAYER == 0
	camera.cull_mask |= FACE.LAYER
	_camera = camera
	_owner = affection

func drop() -> void:
	if is_instance_valid(piece): piece.queue_free()
	if is_instance_valid(_camera) and _added_layer: _camera.cull_mask &= ~FACE.LAYER
	if is_instance_valid(_owner):
		_owner.ki_his_lips = Vector3.ZERO
		_owner.ki_lower_lip = Vector3.INF
	piece = null
	_camera = null
	_owner = null
	_hide = null
	_added_layer = false
