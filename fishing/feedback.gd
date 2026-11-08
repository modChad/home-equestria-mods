extends Node3D
## Fishing: what you see, hear and feel for one pier rod. A bigger two-tone float, splashes and
## ripple rings, nibbles, a plunging bite with the rod tip jerking, and a hooked fish thrashing at
## the surface. Desktop: the HUD's "Bite!" and tension bar. VR (untested): controller pulses
## and a floating "!" over the float.
const SFX = preload("res://world/audio/interaction_sounds.gd")
const MODEL = preload("res://mods/fishing/fish_model.gd")
const SOUNDS = preload("res://mods/fishing/sounds.gd")
var rod: Node3D
var line: RefCounted
var hud: CanvasLayer        # shared, owned by main.gd
var hands: Node             # the game's FishingHands (null in labs)
var inventory: Node
var _float_parts: Array[Node3D] = []
var _old_mesh: Mesh
var _old_material: Material
var _rings: Array = []      # [MeshInstance3D, age, life, max radius]
var _ring_material: StandardMaterial3D
var _drops: CPUParticles3D
var _bang: Label3D
var _bend = 0.0
var _bend_kick = 0.0
var _visual_rest: Transform3D
var _fish_view: Node3D
var _fish_id = ""
var _idle_ring = 0.0
var _pulse = 0.0
var _state = "ready"
var _t = 0.0
var _cord: MeshInstance3D
var _card3d: Label3D
var _fly: Dictionary = {}      # an animation of the caught fish: {from, to, t, length, arc, done}
var _left_held = false
var _last_remaining = 0.0
var _reeled = 0.0
var _flap_in = 0.0
var _cord_material: StandardMaterial3D
var _old_line_colour = Color("e7ddbb")

func setup(r: Node3D, l: RefCounted, shared_hud: CanvasLayer, h: Node) -> void:
	rod = r; line = l; hud = shared_hud; hands = h
	inventory = hands.get("inventory") if is_instance_valid(hands) else null
	top_level = true; global_transform = Transform3D.IDENTITY
	_dress_float()
	_ring_material = StandardMaterial3D.new(); _ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _ring_material.albedo_color = Color(1, 1, 1, .9)
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_drops = CPUParticles3D.new(); _drops.emitting = false; _drops.one_shot = true; _drops.amount = 28; _drops.lifetime = .8
	_drops.explosiveness = .95; _drops.direction = Vector3.UP; _drops.spread = 35; _drops.initial_velocity_min = 1.4; _drops.initial_velocity_max = 2.8
	_drops.gravity = Vector3(0, -9.8, 0); _drops.scale_amount_min = .5; _drops.scale_amount_max = 1.2
	var drop = SphereMesh.new(); drop.radius = .02; drop.height = .04; drop.radial_segments = 6; drop.rings = 3
	var dm = StandardMaterial3D.new(); dm.albedo_color = Color(.9, .96, 1.0, .85); dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; dm.roughness = .1
	drop.material = dm; _drops.mesh = drop; add_child(_drops)
	_bang = Label3D.new(); _bang.text = "!"; _bang.font_size = 160; _bang.pixel_size = .0016; _bang.modulate = Color("ffd34d")
	_bang.outline_modulate = Color("3a2616"); _bang.outline_size = 24; _bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bang.no_depth_test = true; _bang.visible = false; add_child(_bang)
	_card3d = Label3D.new(); _card3d.font = preload("res://world/ui/fonts/PonyvilleMedium.ttf"); _card3d.font_size = 64; _card3d.pixel_size = .0011
	_card3d.modulate = Color("fff3d6"); _card3d.outline_modulate = Color("3a2616"); _card3d.outline_size = 14
	_card3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _card3d.visible = false; add_child(_card3d)
	var visual: Node3D = rod.get("visual")
	if is_instance_valid(visual): _visual_rest = visual.transform
	# The game's line is a 1-pixel strip; ours is a ribbon that stays ~2-3 px wide at any distance.
	var game_line: StandardMaterial3D = rod.get("_material")
	if game_line != null:
		_old_line_colour = game_line.albedo_color
		game_line.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; game_line.albedo_color.a = 0.0
	_cord = MeshInstance3D.new(); _cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(_cord)
	_cord_material = StandardMaterial3D.new(); _cord_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cord_material.albedo_color = Color("f3ecd2"); _cord_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	line.changed.connect(_on_changed)

## The game's float is a 9 cm red ball. This one is 18 cm: white below, a red top, a short
## bright antenna, so it reads at 10 m and its dips are easy to see.
func _dress_float() -> void:
	var b: MeshInstance3D = rod.get("bobber")
	if not is_instance_valid(b): return
	_old_mesh = b.mesh; _old_material = b.material_override
	var lower = SphereMesh.new(); lower.radius = .09; lower.height = .18; lower.radial_segments = 16; lower.rings = 8
	var white = StandardMaterial3D.new(); white.albedo_color = Color("f4f1e8"); white.roughness = .35
	b.mesh = lower; b.material_override = white
	var cap = MeshInstance3D.new(); var cm = SphereMesh.new(); cm.radius = .092; cm.height = .092; cm.is_hemisphere = true; cm.radial_segments = 16; cm.rings = 6
	var red = StandardMaterial3D.new(); red.albedo_color = Color("e23b2e"); red.roughness = .35; red.emission_enabled = true; red.emission = Color("e23b2e"); red.emission_energy_multiplier = .25
	cap.mesh = cm; cap.material_override = red; cap.position.y = .005; b.add_child(cap); _float_parts.append(cap)
	var stick = MeshInstance3D.new(); var sm = CylinderMesh.new(); sm.top_radius = .012; sm.bottom_radius = .016; sm.height = .18; sm.radial_segments = 8
	var glow = StandardMaterial3D.new(); glow.albedo_color = Color("ffcf3a"); glow.emission_enabled = true; glow.emission = Color("ffcf3a"); glow.emission_energy_multiplier = .8
	stick.mesh = sm; stick.material_override = glow; stick.position.y = .16; b.add_child(stick); _float_parts.append(stick)

func _on_changed(state: String) -> void:
	var player = _player_holds()
	match state:
		"casting":
			SOUNDS.play_at(self, "whoosh", rod.call("tip"), -16.0, randf_range(.92, 1.08))
			SOUNDS.play_at(self, "zip", rod.call("tip"), -10.0)
		"waiting":
			if _state == "casting":
				_splash(line.bobber, 1.0); _ring(line.bobber, 1.4, 1.3); _ring(line.bobber, .8, 1.0)
				SFX.play_event(rod, "splash", {"intensity": .7}, line.bobber)
			if player: hud.clear_call()
		"nibble":
			_ring(line.bobber, .35, .7); _bend_kick = .05
			SFX.play_event(rod, "splash", {"intensity": .2}, line.bobber)
			if player: _haptic(.25, .05)
		"bite":
			_splash(line.bobber, .7)
			for i in 3: _ring(line.bobber, .9 + i * .5, .8 + i * .25)
			_bend_kick = .22
			SFX.play_event(rod, "splash", {"intensity": 1.0}, line.bobber)
			SOUNDS.play_at(self, "plop", line.bobber, 2.0 if player else -4.0)
			SOUNDS.play_at(self, "bell", rod.call("tip"), -6.0 if player else -14.0)
			if player:
				if _desktop(): hud.bite("Click to hook")
				else: _bang.visible = true
				_pulse = 0.0
		"hooked":
			_bang.visible = false
			if player:
				hud.clear_call()
				if _desktop(): hud.tension(0.0)
			_bend_kick = .15
			_show_fish(true)
		"landed":
			_bang.visible = false
			if player: hud.tension(-1.0)
			_show_fish(true)
			SFX.play_at(rod, "prop_fish_land", line.bobber)
			_splash(line.bobber + Vector3.DOWN * .3, .2)
			_flap_in = .1
		"ready", "lost":
			_bang.visible = false; _card3d.visible = false
			if is_instance_valid(hud) and _state == "landed": hud.clear_card()
			_release_left()
			if player: hud.clear_call(); hud.tension(-1.0)
			if state == "lost": _ring(line.bobber, .6, 1.0); _splash(line.bobber, .5)
			_show_fish(false)
	_state = state if state in ["ready", "casting", "waiting", "bite", "hooked", "landed"] else _state

func _physics_process(delta: float) -> void:
	if not is_instance_valid(rod) or line == null: return
	_t += delta
	var state: String = line.state
	if state == "casting": _state = "casting"
	# Rod tip: kicks decay into a springy bend; a hooked fish holds it bent and jerking.
	var target = 0.0
	if state == "bite": target = .10 + .06 * sin(_t * 18.0)
	elif state == "hooked": target = .07 + .12 * line.thrash + .03 * sin(_t * 23.0) * line.thrash
	_bend_kick = move_toward(_bend_kick, 0.0, delta * .6)
	_bend = lerpf(_bend, target + _bend_kick * sin(_t * 30.0), minf(1.0, delta * 14.0))
	var visual: Node3D = rod.get("visual")
	if is_instance_valid(visual): visual.transform = _visual_rest * Transform3D(Basis(Vector3.RIGHT, _bend), Vector3.ZERO)
	# A slow ring now and then while the float sits, so it is easy to find again.
	if state == "waiting":
		_idle_ring -= delta
		if _idle_ring <= 0.0: _idle_ring = 2.0; _ring(line.bobber, .55, 1.6)
	if state == "hooked":
		_idle_ring -= delta * (1.0 + 3.0 * line.thrash)
		if _idle_ring <= 0.0:
			_idle_ring = .3; _ring(line.bobber, .4 + .6 * line.thrash, .7)
			if line.thrash > .7 and randf() < .3: _splash(line.bobber, .35)
		_pose_fish(delta)
		if _player_holds():
			var t: float = clampf(line.tension / 2.5, 0.0, 1.0) * .6 + line.thrash * .4
			if _desktop(): hud.tension(t)
			else:
				_pulse -= delta
				if _pulse <= 0.0: _pulse = .18; _haptic(.15 + .6 * t, .06)
	if not _fly.is_empty(): _step_fly(delta)
	elif state == "landed": _pose_landed(delta)
	if state == "bite" and _player_holds():
		_bang.global_position = line.bobber + Vector3.UP * (.45 + .05 * sin(_t * 8.0))
		if not _desktop():
			_pulse -= delta
			if _pulse <= 0.0: _pulse = .22; _haptic(minf(1.0, .5 + line.clock * .2), .09)
	_age_rings(delta)
	_draw_cord(state)
	_reel_clicks(state)
	if state == "landed" and _fly.is_empty() and is_instance_valid(_fish_view):
		_flap_in -= delta
		if _flap_in <= 0.0:
			# Wet slaps, quick at first, slower as it tires.
			_flap_in = randf_range(.18, .32) + line.clock * .08
			SOUNDS.play_at(self, "flap", _fish_view.global_position, -6.0 - minf(line.clock * 1.5, 10.0), randf_range(.85, 1.2))

## Ratchet clicks as line comes in: one per 8 cm, deeper and slower against a pulling fish.
func _reel_clicks(state: String) -> void:
	var remaining: float = line.remaining
	if state in ["waiting", "bite", "hooked"] and remaining < _last_remaining:
		_reeled += _last_remaining - remaining
		if _reeled >= .08:
			_reeled = 0.0
			var strain: bool = state == "hooked" and line.thrash > .5
			SOUNDS.play_at(self, "click_strain" if strain else "click", rod.call("tip") + rod.global_basis.y * -1.2, -8.0, randf_range(.9, 1.1))
	_last_remaining = remaining

func _draw_cord(state: String) -> void:
	if state == "ready" or not is_instance_valid(_cord):
		if is_instance_valid(_cord): _cord.visible = false
		return
	var cam = get_viewport().get_camera_3d()
	if cam == null: return
	_cord.visible = true
	var start: Vector3 = rod.call("tip"); var end: Vector3 = line.bobber
	var sag = .015 if state == "hooked" else .14
	var mesh = ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _cord_material)
	for i in 17:
		var t = i / 16.0
		var p: Vector3 = start.lerp(end, t) + Vector3.DOWN * sin(t * PI) * sag
		var to_cam: Vector3 = (cam.global_position - p)
		var along: Vector3 = (end - start).normalized()
		var side: Vector3 = along.cross(to_cam).normalized() * maxf(.0025, to_cam.length() * .0016)
		mesh.surface_add_vertex(p - side); mesh.surface_add_vertex(p + side)
	mesh.surface_end(); _cord.mesh = mesh

## Rings: flat tori that grow and fade on the water.
func _ring(at: Vector3, radius: float, life: float) -> void:
	if not at.is_finite(): return
	var mi = MeshInstance3D.new(); var torus = TorusMesh.new(); torus.inner_radius = .86; torus.outer_radius = 1.0; torus.rings = 32; torus.ring_segments = 4
	mi.mesh = torus; mi.material_override = _ring_material.duplicate(); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); mi.global_position = Vector3(at.x, line.water_y + .012, at.z); mi.scale = Vector3(.05, .02, .05)
	_rings.append([mi, 0.0, life, radius])

func _age_rings(delta: float) -> void:
	for i in range(_rings.size() - 1, -1, -1):
		var r: Array = _rings[i]; r[1] += delta
		var f: float = r[1] / r[2]
		var mi: MeshInstance3D = r[0]
		if f >= 1.0: mi.queue_free(); _rings.remove_at(i); continue
		var s: float = lerpf(.05, r[3], 1.0 - pow(1.0 - f, 2.0))
		mi.scale = Vector3(s, .02, s)
		(mi.material_override as StandardMaterial3D).albedo_color.a = .9 * (1.0 - f)

func _splash(at: Vector3, power: float) -> void:
	if not at.is_finite(): return
	_drops.global_position = Vector3(at.x, line.water_y, at.z)
	_drops.initial_velocity_max = 1.6 + 1.6 * power; _drops.amount = int(10 + 20 * power)
	_drops.restart(); _drops.emitting = true

## A hooked fish shows at the surface: the species picked at the bite, sized to its roll.
func _show_fish(on: bool) -> void:
	if not on:
		if is_instance_valid(_fish_view): _fish_view.visible = false
		return
	var id: String = line.fish.get("id", "trout")
	if id != _fish_id or not is_instance_valid(_fish_view):
		if is_instance_valid(_fish_view): _fish_view.queue_free()
		var spec: Dictionary = (MODEL as Script).get_script_constant_map().get(id.to_upper(), MODEL.TROUT)
		_fish_view = MODEL.build(spec); add_child(_fish_view); _fish_id = id
		_fish_view.set_meta("base_length", float(spec.length))
	var k: float = float(line.fish.get("length", .4)) / float(_fish_view.get_meta("base_length"))
	_fish_view.scale = Vector3.ONE * k
	_fish_view.visible = true

func _pose_fish(_delta: float) -> void:
	if not is_instance_valid(_fish_view) or not _fish_view.visible: return
	var to_rod: Vector3 = rod.call("tip") - line.bobber; to_rod.y = 0
	var yaw = atan2(-to_rod.x, -to_rod.z) if to_rod.length() > .01 else 0.0
	# Head toward the float's line, body swinging; on a big pull it rolls and breaks the surface.
	var swing = sin(_t * (9.0 + 6.0 * line.thrash)) * (.25 + .35 * line.thrash)
	var roll = sin(_t * 4.3) * .5 * line.thrash
	var leap = maxf(0.0, sin(_t * 1.7) - .75) * 4.0 * line.thrash
	var lift: float = -.015 + .08 * line.thrash + .3 * leap
	_fish_view.global_transform = Transform3D(Basis.from_euler(Vector3(0, yaw + swing, roll)).scaled(_fish_view.scale), Vector3(line.bobber.x, line.water_y + lift, line.bobber.z) + Basis(Vector3.UP, yaw) * Vector3(0, 0, .18 * _fish_view.scale.x))

## Desktop: the free hand holds the catch up in view, side-on, flapping. VR: it hangs from the
## rod tip by its mouth for the free hand to take. Either way the line runs to its mouth.
func _pose_landed(_delta: float) -> void:
	if not is_instance_valid(_fish_view): return
	var k: float = _fish_view.scale.x
	var length: float = float(_fish_view.get_meta("base_length")) * k
	var flap = sin(_t * 11.0) * .3 * maxf(.15, 1.0 - line.clock * .15)
	var ease = minf(1.0, line.clock / .35)
	var tip: Vector3 = rod.call("tip")
	var hang_b = Basis(Vector3.UP, flap + _t * .4) * Basis(Vector3.FORWARD, sin(_t * 2.2) * .18) * Basis(Vector3.RIGHT, PI * .5)
	var hang = Transform3D(hang_b.scaled(Vector3.ONE * k), tip + Vector3.DOWN * (.25 + length * .5))
	var target = hang
	var cam = get_viewport().get_camera_3d()
	if _player_holds() and _desktop() and cam != null:
		# Held up in view, hanging head-up from the line, side-on to the camera.
		var dist = maxf(.6, length * 1.5)
		# Model axes: nose -Z, flank +X. Nose up, flank toward the camera.
		var side: Vector3 = cam.global_basis.z; side.y = 0; side = side.normalized()
		var zz = Vector3.DOWN; var yy = zz.cross(side)
		var face = Basis(side, yy, zz)
		var b = Basis(Vector3.UP, flap) * Basis(-cam.global_basis.z, sin(_t * 2.2) * .12) * face
		target = Transform3D(b.scaled(Vector3.ONE * k), cam.global_transform * Vector3(-.2 * dist, 0.0, -dist))
	var xf = hang.interpolate_with(target, ease * ease * (3.0 - 2.0 * ease))
	_fish_view.global_transform = xf
	# The hook sits at the fish's mouth (nose is -Z in the model).
	line.bobber = xf * Vector3(0, 0, -float(_fish_view.get_meta("base_length")) * .5)
	var b_mesh: Node3D = rod.get("bobber")
	if is_instance_valid(b_mesh): b_mesh.visible = false
	if _player_holds() and _desktop() and is_instance_valid(inventory):
		var visual: Node = inventory.get("desktop_presentation") as Node
		if is_instance_valid(visual) and visual.has_method("set_hold_target"):
			visual.set_hold_target("left", Transform3D(cam.global_basis if cam else Basis(), xf.origin), "hold"); _left_held = true
	if _card3d.visible:
		_card3d.global_position = xf.origin + Vector3.UP * (length * .6 + .12)

func _release_left() -> void:
	if not _left_held or not is_instance_valid(inventory): return
	var visual: Node = inventory.get("desktop_presentation") as Node
	if is_instance_valid(visual) and visual.has_method("clear_hold_target"): visual.clear_hold_target("left")
	_left_held = false

## VR's card floats over the fish (desktop uses the HUD card).
func show_card3d(text: String) -> void:
	_card3d.text = text; _card3d.visible = true

## Keep: the fish arcs into the bucket. Release: it flips back into the water with a splash.
func fly_fish(to: Vector3, seconds: float, into_water: bool, done: Callable) -> void:
	_release_left(); _card3d.visible = false
	if not is_instance_valid(_fish_view) or not _fish_view.visible: done.call(); return
	_fly = {"from": _fish_view.global_position, "to": to, "t": 0.0, "length": seconds, "water": into_water, "done": done, "basis": _fish_view.global_transform.basis}

func _step_fly(delta: float) -> void:
	_fly.t += delta
	# The hook is off the fish now: the float stays hidden and the line hangs short at the tip.
	line.bobber = rod.call("tip") + Vector3.DOWN * .25
	var b_mesh: Node3D = rod.get("bobber")
	if is_instance_valid(b_mesh): b_mesh.visible = false
	var f: float = clampf(_fly.t / _fly.length, 0.0, 1.0)
	var p: Vector3 = (_fly.from as Vector3).lerp(_fly.to, f) + Vector3.UP * sin(f * PI) * (.9 if _fly.water else .5)
	if is_instance_valid(_fish_view):
		_fish_view.global_transform = Transform3D((_fly.basis as Basis) * Basis(Vector3.RIGHT, f * TAU * (1.0 if _fly.water else .5)), p)
	if f >= 1.0:
		var done: Callable = _fly.done; var water: bool = _fly.water; var at: Vector3 = _fly.to
		_fly = {}
		if water:
			_splash(at, .8); _ring(at, 1.0, 1.0); _ring(at, .5, .8)
			SFX.play_event(rod, "splash", {"intensity": .8}, at)
		_show_fish(false)
		done.call()

func _player_holds() -> bool: return is_instance_valid(rod) and str(rod.get("holder")) == "player"
func _desktop() -> bool:
	if not is_instance_valid(hands): return true
	return str(hands.get("side")) == "desktop"

func _haptic(amplitude: float, seconds: float) -> void:
	if not is_instance_valid(inventory) or not is_instance_valid(hands): return
	var c: Variant = inventory.get("controllers").get(str(hands.get("side"))) if inventory.get("controllers") is Dictionary else null
	if c is XRController3D and (c as XRController3D).get_is_active():
		(c as XRController3D).trigger_haptic_pulse("haptic", 0.0, clampf(amplitude, 0, 1), seconds, 0.0)

## Switched off: the rod gets its own float, pose and nothing else.
func restore() -> void:
	var b: MeshInstance3D = rod.get("bobber") if is_instance_valid(rod) else null
	if is_instance_valid(b):
		b.mesh = _old_mesh; b.material_override = _old_material
	for p in _float_parts: if is_instance_valid(p): p.queue_free()
	var visual: Node3D = rod.get("visual") if is_instance_valid(rod) else null
	if is_instance_valid(visual): visual.transform = _visual_rest
	var game_line: StandardMaterial3D = rod.get("_material") if is_instance_valid(rod) else null
	if game_line != null: game_line.albedo_color = _old_line_colour; game_line.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_release_left()
	if is_instance_valid(hud) and _player_holds(): hud.clear_call(); hud.tension(-1.0); hud.clear_card()
