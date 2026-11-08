extends RefCounted
## Fishing: every new sound is synthesised here at load (no audio files): a cast whoosh, the reel
## paying out, ratchet clicks, a plop and a little rod bell for a bite, wet flaps for a hanging
## fish, and a short jingle for a first catch or a new best. 22.05 kHz mono, built once.
const RATE := 22050
static var _cache: Dictionary = {}

static func get_sound(id: String) -> AudioStreamWAV:
	if not _cache.has(id):
		match id:
			"whoosh": _cache[id] = _whoosh()
			"zip": _cache[id] = _zip()
			"click": _cache[id] = _click(3200.0)
			"click_strain": _cache[id] = _click(1900.0)
			"plop": _cache[id] = _plop()
			"bell": _cache[id] = _bell(1760.0, .7, 2)
			"flap": _cache[id] = _flap()
			"jingle": _cache[id] = _jingle([523.25, 659.25, 783.99], .13, .55)
			"jingle_best": _cache[id] = _jingle([523.25, 659.25, 783.99, 1046.5], .11, .8)
	return _cache.get(id)

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray(); bytes.resize(samples.size() * 2)
	for i in samples.size(): bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = bytes
	return w

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = seed_value; return r

## Air past the line: noise through a sweeping low-pass, swelling then fading.
static func _whoosh() -> AudioStreamWAV:
	var n := int(RATE * .42); var out := PackedFloat32Array(); out.resize(n)
	var r := _rng(11); var lp := 0.0
	for i in n:
		var t := float(i) / n
		var cutoff := lerpf(.04, .22, sin(t * PI))
		lp += (r.randf_range(-1, 1) - lp) * cutoff
		out[i] = lp * sin(t * PI) * pow(1.0 - t, .4) * 1.4
	return _wav(out)

## The reel paying out: clicks that start fast and slow down as the line runs out.
static func _zip() -> AudioStreamWAV:
	var n := int(RATE * .9); var out := PackedFloat32Array(); out.resize(n)
	var r := _rng(12); var next := 0.0; var t_click := 1.0
	for i in n:
		var t := float(i) / RATE
		if t >= next:
			t_click = 0.0; next = t + lerpf(.012, .05, t / .9) * r.randf_range(.85, 1.15)
		t_click += 1.0 / RATE
		var env := exp(-t_click * 900.0)
		out[i] = (sin(t_click * TAU * 2600.0) * .6 + r.randf_range(-1, 1) * .4) * env * .5 * (1.0 - t / .95)
	return _wav(out)

## One ratchet tooth: a tiny metal tick.
static func _click(freq: float) -> AudioStreamWAV:
	var n := int(RATE * .03); var out := PackedFloat32Array(); out.resize(n)
	var r := _rng(13)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(t * TAU * freq) * .7 + r.randf_range(-1, 1) * .3) * exp(-t * 260.0) * .55
	return _wav(out)

## The float pulled under: a falling "bloop" with a wet edge.
static func _plop() -> AudioStreamWAV:
	var n := int(RATE * .3); var out := PackedFloat32Array(); out.resize(n)
	var r := _rng(14); var phase := 0.0; var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(420.0, 95.0, minf(t / .12, 1.0)) / RATE
		lp += (r.randf_range(-1, 1) - lp) * .25
		out[i] = sin(phase) * exp(-t * 16.0) * .8 + lp * exp(-t * 45.0) * .5
	return _wav(out)

## A little bell on the rod tip: inharmonic partials, rung `rings` times.
static func _bell(freq: float, seconds: float, rings: int) -> AudioStreamWAV:
	var n := int(RATE * seconds); var out := PackedFloat32Array(); out.resize(n)
	var partials := [[1.0, 1.0], [2.76, .45], [5.4, .25], [8.93, .12]]
	for k in rings:
		var start := int(k * RATE * .13)
		for i in range(start, n):
			var t := float(i - start) / RATE
			var v := 0.0
			for p in partials: v += sin(t * TAU * freq * p[0]) * p[1] * exp(-t * (6.0 + p[0] * 2.0))
			out[i] += v * .32 * (1.0 if k == 0 else .7)
	return _wav(out)

## A wet tail-slap: a short low thud with spray.
static func _flap() -> AudioStreamWAV:
	var n := int(RATE * .12); var out := PackedFloat32Array(); out.resize(n)
	var r := _rng(15); var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (r.randf_range(-1, 1) - lp) * .35
		out[i] = (lp * 1.2 + sin(t * TAU * 140.0) * .6) * exp(-t * 55.0) * .7
	return _wav(out)

## A short rising arpeggio of soft chimes.
static func _jingle(notes: Array, step: float, tail: float) -> AudioStreamWAV:
	var n := int(RATE * (step * notes.size() + tail)); var out := PackedFloat32Array(); out.resize(n)
	for k in notes.size():
		var start := int(k * step * RATE); var f: float = notes[k]
		for i in range(start, n):
			var t := float(i - start) / RATE
			out[i] += (sin(t * TAU * f) + .35 * sin(t * TAU * f * 2.0) + .12 * sin(t * TAU * f * 3.0)) * exp(-t * 5.5) * .22
	return _wav(out)

## Plays a sound at a point (3D) on the world effects bus.
static func play_at(parent: Node, id: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or not at.is_finite(): return
	var p := AudioStreamPlayer3D.new(); p.stream = get_sound(id); p.volume_db = volume_db; p.pitch_scale = pitch
	p.unit_size = 4.0; p.max_distance = 30.0; p.bus = "WorldSFX" if AudioServer.get_bus_index("WorldSFX") >= 0 else "Master"
	parent.add_child(p); p.global_position = at; p.finished.connect(p.queue_free); p.play()

## Plays a sound with no position (the catch jingle), on the effects bus.
static func play_ui(parent: Node, id: String, volume_db := 0.0) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree(): return
	var p := AudioStreamPlayer.new(); p.stream = get_sound(id); p.volume_db = volume_db
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	parent.add_child(p); p.finished.connect(p.queue_free); p.play()
