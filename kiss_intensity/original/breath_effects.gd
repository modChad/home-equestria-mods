extends Node3D
## World-space breath and saliva for one kiss.

const WISP := preload("res://world/vfx/textures/smoke_soft_a.png")
## The breath puff (dev 2026-11-22: "tiny tiny really really faint small clouds that get thicker in
## winter"): a few tiny, barely-there wisps in warm air; in winter or snow (as world/vfx/cold_breath.gd
## decides cold) more of them, a little bigger and clearly seen. [warm, cold].
## The 0.6.5 values Anon's words were built on (the cleanup round had shrunk them unasked).
const WISPS := [5, 10]
const PUFF_LIFE := [1.3, 2.0]
const PUFF_SIZE := [0.026, 0.05]
const PUFF_OPACITY := [0.09, 0.38]
## The strand: tube radius in metres when new, how long it lasts, and the widest gap it spans.
const STRAND_RADIUS := 0.0013
const STRAND_SECONDS := 1.7
const STRAND_SPAN := 0.12
const SECTORS := 5
const RINGS := 9

var puff := GPUParticles3D.new()
var strand := MeshInstance3D.new()
var ribbon := ImmediateMesh.new()
var wet := StandardMaterial3D.new()
## Counted for the review fixture.
var puffs := 0
var strand_frames := 0


func _ready() -> void:
	top_level = true
	# Placed every drawn frame, not on physics ticks (as cold_breath.gd).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	global_transform = Transform3D.IDENTITY
	var smoke := StandardMaterial3D.new()
	smoke.albedo_texture = WISP
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke.billboard_keep_scale = true
	smoke.vertex_color_use_as_albedo = true
	smoke.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(PUFF_SIZE[0])
	quad.material = smoke
	var flow := ParticleProcessMaterial.new()
	flow.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	flow.emission_sphere_radius = 0.005
	flow.spread = 20.0
	flow.gravity = Vector3.UP * 0.03
	flow.initial_velocity_min = 0.05
	flow.initial_velocity_max = 0.09
	flow.damping_min = 0.10
	flow.damping_max = 0.16
	flow.angle_min = 0.0
	flow.angle_max = 360.0
	flow.scale_min = 0.8
	flow.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(0.35, 0.75))
	grow.add_point(Vector2(1.0, 1.4))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	flow.scale_curve = grow_texture
	var fade := Gradient.new()
	# A warm breath: faintly rosy where it leaves her, white as it thins.
	fade.set_color(0, Color(1.0, 0.95, 0.92, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	# Shape of the fade only; how much shows is flow.color's alpha, set per breath (warm or cold).
	fade.add_point(0.12, Color(1.0, 0.95, 0.92, 1.0))
	fade.add_point(0.55, Color(1.0, 0.98, 0.97, 0.55))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	flow.color_ramp = fade_texture
	puff.amount = int(WISPS[0])
	puff.lifetime = float(PUFF_LIFE[0])
	puff.one_shot = true
	puff.explosiveness = 0.35
	puff.local_coords = false
	puff.draw_pass_1 = quad
	puff.process_material = flow
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.visibility_aabb = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	# Drawn over her coat and the strand, never sorted behind them at this range.
	smoke.render_priority = 1
	puff.emitting = false
	add_child(puff)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.cull_mode = BaseMaterial3D.CULL_DISABLED
	wet.albedo_color = Color(0.88, 0.95, 1.0, 0.72)
	wet.roughness = 0.12
	wet.metallic_specular = 0.8
	strand.mesh = ribbon
	strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strand)


## One panting puff out of her mouth at `lip`, along `direction`.
func exhale(lip: Vector3, direction: Vector3) -> void:
	var cold := 1 if _cold() else 0
	if puff.amount != int(WISPS[cold]): puff.amount = int(WISPS[cold])
	puff.lifetime = float(PUFF_LIFE[cold])
	(puff.draw_pass_1 as QuadMesh).size = Vector2.ONE * float(PUFF_SIZE[cold])
	(puff.process_material as ParticleProcessMaterial).color = Color(1.0, 1.0, 1.0, float(PUFF_OPACITY[cold]))
	puff.global_position = lip
	# The process material's direction is in the emitter's own frame, not the world's: given as a
	# world vector it turned with her body and sent the puff back into her face.
	(puff.process_material as ParticleProcessMaterial).direction = (puff.global_basis.orthonormalized().inverse() * direction).normalized()
	puff.restart()
	puff.emitting = true
	puffs += 1


## The strand from her lower lip to his mouth point, `age` seconds after their lips parted: it
## sags as the gap opens, thins as it stretches and is gone by STRAND_SECONDS. False once gone.
func bridge(lip: Vector3, other: Vector3, age: float) -> bool:
	ribbon.clear_surfaces()
	var span := other - lip
	var length := span.length()
	if age < 0.0 or age >= STRAND_SECONDS or length > STRAND_SPAN: return false
	if length < 0.007: return true # Lips still together: nothing to see yet.
	var width := STRAND_RADIUS * clampf(0.03 / length, 0.5, 1.3) * (1.0 - smoothstep(STRAND_SECONDS * 0.55, STRAND_SECONDS, age))
	var sag := minf(0.006, length * 0.22) * smoothstep(0.2, 1.2, age)
	var axis := span / length
	var across := axis.cross(Vector3.UP)
	if across.length_squared() < 0.001: across = axis.cross(Vector3.RIGHT)
	across = across.normalized()
	var normal := across.cross(axis).normalized()
	# A closed tube, so each eye gets its own highlight even when looking along the strand.
	for sector: int in SECTORS:
		ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, wet)
		for i: int in RINGS:
			var t := float(i) / float(RINGS - 1)
			var center := lip.lerp(other, t) - Vector3.UP * (4.0 * t * (1.0 - t) * sag)
			# Thinnest in the middle, where it will snap.
			var radius := width * (1.0 + 1.1 * pow(absf(2.0 * t - 1.0), 5.0))
			for edge: int in 2:
				var angle := TAU * float(sector + edge) / float(SECTORS)
				var radial := across * cos(angle) + normal * sin(angle)
				ribbon.surface_set_normal(radial)
				ribbon.surface_add_vertex(center + radial * radius)
		ribbon.surface_end()
	strand_frames += 1
	return true


func clear_bridge() -> void:
	ribbon.clear_surfaces()


## Cold air, as world/vfx/cold_breath.gd decides it: winter, or snow falling. The season-effects
## setting at Off makes every breath the warm one.
func _cold() -> bool:
	if not is_inside_tree(): return false
	var seasons: Node = get_tree().get_first_node_in_group("season_state")
	var weather: Node = get_tree().get_first_node_in_group("weather")
	var params: Variant = weather.get("params") if weather != null else null
	var snow := float((params as Dictionary).get("snow", 0.0)) if params is Dictionary else 0.0
	var cold := snow > 0.05 or (seasons != null and seasons.has_method("season") and str(seasons.call("season")) == "winter")
	if cold and seasons != null and seasons.has_method("effects_level") and int(seasons.call("effects_level")) <= 0: cold = false
	return cold
