extends RefCounted
## Horn Touch effects, all in her magic colour and built from the game's own horn magic
## (unicorn_magic.gd cast / burst) plus a beam and a sparkle shower of this mod's own.
const BEAM_SECONDS := 0.28


static func _material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color, 0.9)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## The bolt that pushes him away: her horn flares, a beam jumps from its tip to his chest.
static func bolt(pony: Node3D, tip: Vector3, target: Vector3, color: Color) -> void:
	var magic: Node3D = pony.get("magic")
	if not is_instance_valid(magic): return
	magic.cast(1.2)
	UnicornMagic.burst(magic, magic.to_local(tip), color, .4, .12)
	var length := tip.distance_to(target)
	if length < .05: return
	var holder := Node3D.new(); holder.name = "HornTouchBolt"; holder.top_level = true
	magic.add_child(holder)
	holder.global_position = (tip + target) * .5
	var up := (target - tip).normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < .95 else Vector3.RIGHT).normalized()
	holder.global_basis = Basis(side, up, side.cross(up)).orthonormalized()
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = .012; mesh.bottom_radius = .02; mesh.height = length
	mesh.radial_segments = 8; mesh.rings = 1
	beam.mesh = mesh
	beam.material_override = _material(color, 4.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(beam)
	var light := OmniLight3D.new()
	light.light_color = color; light.light_energy = 2.0; light.omni_range = 2.5
	holder.add_child(light)
	UnicornMagic.burst(holder, holder.to_local(target), color, .5, .25)
	var tween := holder.create_tween()
	tween.tween_property(beam, "transparency", 1.0, BEAM_SECONDS).set_delay(.06)
	tween.parallel().tween_property(light, "light_energy", 0.0, BEAM_SECONDS)
	tween.tween_interval(1.0)
	tween.tween_callback(holder.queue_free)


## Her horn overloads: it lights fully, bursts at the tip and along its length, and showers
## soft sparkles that drift out and down and fade. Harmless and quick.
static func overload(pony: Node3D, base: Vector3, tip: Vector3, color: Color) -> void:
	var magic: Node3D = pony.get("magic")
	if not is_instance_valid(magic): return
	magic.cast(3.0)
	UnicornMagic.burst(magic, magic.to_local(tip), color, 1.4, .4)
	for i in 3:
		var at := base.lerp(tip, .3 + .3 * i)
		var t := magic.get_tree().create_timer(.15 + .2 * i)
		t.timeout.connect(func() -> void:
			if is_instance_valid(magic): UnicornMagic.burst(magic, magic.to_local(at), color, .6, .18))
	var holder := Node3D.new(); holder.name = "HornTouchSparkles"; holder.top_level = true
	magic.add_child(holder)
	holder.global_position = tip
	var sparkles := CPUParticles3D.new()
	sparkles.amount = 90
	sparkles.lifetime = 1.8
	sparkles.one_shot = true
	sparkles.explosiveness = .85
	sparkles.direction = Vector3.UP
	sparkles.spread = 75.0
	sparkles.initial_velocity_min = .6; sparkles.initial_velocity_max = 1.6
	sparkles.gravity = Vector3(0, -1.2, 0)
	sparkles.damping_min = .8; sparkles.damping_max = 1.6
	sparkles.scale_amount_min = .5; sparkles.scale_amount_max = 1.2
	var curve := Curve.new(); curve.add_point(Vector2(0, 1)); curve.add_point(Vector2(1, 0))
	sparkles.scale_amount_curve = curve
	var dot := SphereMesh.new(); dot.radius = .012; dot.height = .024; dot.radial_segments = 6; dot.rings = 3
	dot.material = _material(color, 3.0)
	sparkles.mesh = dot
	holder.add_child(sparkles)
	sparkles.emitting = true
	var light := OmniLight3D.new()
	light.light_color = color; light.light_energy = 1.6; light.omni_range = 2.0
	holder.add_child(light)
	var tween := holder.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 1.6)
	tween.tween_interval(.6)
	tween.tween_callback(holder.queue_free)
