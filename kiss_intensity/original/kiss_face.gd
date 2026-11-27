extends RefCounted
## These three absolute poses share one budget. The residual belongs to the resting muzzle.
const PUCKER := 0.94
const WRAP := 0.98
const OPEN := 0.98
const EYES: Dictionary = preload("res://world/characters/hybrid_mare/face_poses.gd").EYE_POSES.affectionate

static func mouth(mouth_rig: PonyMouth, act: RefCounted, amount: float, cycle: bool, jaw: float, breath: float) -> void:
	var wrap := clampf(float(act.grip), 0.0, 1.0) if cycle else 0.0
	var pucker := maxf(float(act.open) if cycle else 0.0, breath * 0.6)
	# The base affection writer has already applied its deep-kiss speech poses this frame.
	mouth_rig.set_posed_expression({
		"open_soft": 0.0, "pout": 0.0, "smile": 0.0,
		"kiss_open": OPEN * jaw * amount,
		"kiss_wrap": WRAP * wrap * (1.0 - jaw) * amount,
		"kiss_pucker": PUCKER * pucker * (1.0 - wrap) * (1.0 - jaw) * amount,
	})


static func clear_mouth(mouth_rig: PonyMouth) -> void:
	for shape in ["kiss_wrap", "kiss_open", "kiss_pucker"]:
		mouth_rig.set_expression(shape, 0.0)

static func eyes(expressions: RefCounted, level: float, look: float) -> bool:
	var head: Variant = expressions.show_head
	if not head is Object or not head.has_method("set_face_sculpt") or not str(expressions.dialogue_face).is_empty(): return false
	var weight := smoothstep(0.10, 0.4, level) * lerpf(0.85, 1.0, look) * (1.0 - smoothstep(0.9, 1.0, float(expressions.stare_lids)))
	var sculpt := {}
	for key: String in EYES.sculpt: sculpt[key] = float(EYES.sculpt[key]) * weight
	var shape: Array = EYES.iris_shape
	head.set_face_sculpt(sculpt, Vector2.ONE.lerp(Vector2(float(shape[0]), float(shape[1])), weight))
	if head.has_method("set_eye_details"):
		head.set_eye_details(lerpf(1.0, float(EYES.pupil), weight), weight, float(EYES.shine_drop) * weight)
	return true
