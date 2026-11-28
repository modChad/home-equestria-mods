extends Node3D
## Horn Touch: dazed by her magic. The game's buck daze (player/buck_daze.gd: thump, ringing and
## a dark flash) plays first through receive_buck; this one lasts longer: blurred, doubled,
## swaying sight with a dark pulsing rim and a tint of her magic, easing out over the last third.
## Movement is locked by main.gd for as long as this runs.
const FADE_IN := 0.3
static var _shader: Shader
var seconds := 15.0
var tint := Color.WHITE
var _started_ms := 0
var _material: ShaderMaterial


static func play(camera: Camera3D, length: float, color: Color) -> Node3D:
	if not is_instance_valid(camera): return null
	var old := camera.get_node_or_null("HornDaze")
	if old != null: old.queue_free()
	var daze := preload("res://mods/horn_touch/daze.gd").new()
	daze.name = "HornDaze"
	daze.seconds = length
	daze.tint = color
	camera.add_child(daze)
	return daze


func left() -> float:
	return maxf(0.0, seconds - (Time.get_ticks_msec() - _started_ms) / 1000.0)


func _ready() -> void:
	# Real time and always processed, as the buck daze: a pause must never leave it on his eyes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_ms = Time.get_ticks_msec()
	if _shader == null: _shader = load("res://mods/horn_touch/daze.gdshader")
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.render_priority = 126 # Under the buck vignette (127).
	_material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	var quad := MeshInstance3D.new()
	var plane := QuadMesh.new(); plane.size = Vector2(0.9, 0.7)
	quad.mesh = plane
	quad.material_override = _material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = Vector3(0, 0, -0.12)
	add_child(quad)
	_process(0.0)


func _process(_delta: float) -> void:
	var time := (Time.get_ticks_msec() - _started_ms) / 1000.0
	var amount := smoothstep(0.0, FADE_IN, time) * (1.0 - smoothstep(seconds * 0.66, seconds, time))
	_material.set_shader_parameter("amount", amount)
	if time >= seconds: queue_free()
