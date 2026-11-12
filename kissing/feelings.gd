extends Node
## Kissing: a pony's excitement as a build-up instead of bursts (Kissing 1.1.0).
##
## The game's excitement (world/characters/hybrid_mare/excitement.gd) flares a unicorn's horn with
## a full magic cast, cast sound and all, about every 0.9 s while she's kissed, petted on the head
## for a while or tagged [excited] by her AI. Here those flares are held back and her feelings
## build instead: `level` (0..1) rises while she's excited, fastest in a deep kiss, up to a peak set
## by her bond with Anon (a partner peaks higher than a friend), holds a moment once it's over,
## then fades slowly. Unicorns and alicorns show it in their horn: a quiet glow and hum that
## gather, brighten and quicken with `level` (no cast sounds). Pegasi and alicorns: once the game
## has spread their wings, they shiver as it runs high (wings.gd). Earth ponies grow fidgety:
## weight shifting, tail swishes, ear flicks and hoof taps (fidgets.gd).

const MAGIC_AURA := preload("res://world/characters/magic/magic_aura.gd")
const MAGIC := preload("res://world/characters/magic/unicorn_magic.gd")
const SUSTAIN := preload("res://world/characters/magic/aura/magic_sustain.res")

## Build-up per second while excited, by what excites her.
const RISE_KISS := 0.05
const RISE_DEEP := 0.09
const RISE_OTHER := 0.06 # Head scratches, her AI's [excited] / [wings:spread].
## Once it's over: held this long, then faded over FADE_SECONDS.
const HOLD_SECONDS := 1.5
const FADE_SECONDS := 4.0
## The most her feelings reach, by her bond with Anon (player_bonds.gd STAGES).
const PEAK := {"acquaintance": 0.35, "friend": 0.5, "close_friend": 0.7, "dating": 0.85, "engaged": 0.95, "married": 1.0}

## Horn: glow strength, light and hum at level 1. The hum peaks a little under the game's own
## cast sustain (magic_aura.gd BASE_VOLUME * SOUND_SCALE * 0.6).
const GLOW_MIN := 0.08
const LIGHT_ENERGY := 0.45
const HUM_PEAK := 0.10
const HUM_PITCH := Vector2(0.85, 1.12)
## The glow breathes: a slow swell that quickens with her feelings (beats per second).
const PULSE_RATE := Vector2(0.5, 1.6)
const PULSE_DEPTH := 0.12

var mare: Node3D
var level := 0.0
var cause := "" # What's exciting her now: "deep", "kiss", "other" or "".
var _hold := 0.0
var _clock := 0.0
var _anchor: Node3D
var _aura: Node3D
var _light: OmniLight3D
var _hum: AudioStreamPlayer3D


func _process(delta: float) -> void:
	if not is_instance_valid(mare): return
	_clock += delta
	_feel(delta)
	if as_earth:
		var excitement: Variant = mare.get("excitement")
		if excitement is Node: excitement.set("_spark", 1.0e9)
	else:
		_horn(delta)
		_wings()
	_fidgets()


# ---------------------------------------------------------------- earth ponies

const FIDGETS := preload("res://mods/kissing/fidgets.gd")
var _fidget: Node
## The lab sets this to show only the fidgets (no horn, no wing shiver) on a pony who isn't an
## earth pony.
var as_earth := false


## An earth pony's fidgets (fidgets.gd), on her skeleton after the game's own pose writers.
func _fidgets() -> void:
	if is_instance_valid(_fidget) or level <= 0.001: return
	var identity: Variant = mare.get("identity")
	var earth: bool = identity is Object and identity.has_method("has_wings") and not identity.has_wings() and not (identity.has_method("has_horn") and identity.has_horn())
	if not earth and not as_earth: return
	var sk: Variant = mare.get("skeleton")
	if not sk is Skeleton3D or not is_instance_valid(sk): return
	_fidget = FIDGETS.new()
	_fidget.name = "KissingFidgets"
	_fidget.set("mare", mare)
	_fidget.set("feelings", self)
	(sk as Node).add_child(_fidget)


# ---------------------------------------------------------------- wings

const WINGS := preload("res://mods/kissing/wings.gd")
var _shiver: Node


## Her wing shiver (wings.gd), once the game has given her open wings; kept the skeleton's last
## modifier, after the wing tuck, which the game adds when it first binds her open wings.
func _wings() -> void:
	if level <= 0.001 and not is_instance_valid(_shiver): return
	var flight: Variant = mare.get("flight")
	if flight == null or not flight.get("wings") is Node: return
	var sk: Variant = mare.get("skeleton")
	if not sk is Skeleton3D or not is_instance_valid(sk): return
	if not is_instance_valid(_shiver):
		_shiver = WINGS.new()
		_shiver.name = "KissingWingShiver"
		_shiver.set("mare", mare)
		_shiver.set("feelings", self)
		(sk as Node).add_child(_shiver)
	elif _shiver.get_index() != (sk as Node).get_child_count() - 1:
		(sk as Node).move_child(_shiver, -1)


## How far her feelings have built.
func _feel(delta: float) -> void:
	cause = _cause()
	if not cause.is_empty():
		var rise: float = {"deep": RISE_DEEP, "kiss": RISE_KISS}.get(cause, RISE_OTHER)
		var peak := _peak()
		if level < peak: level = move_toward(level, peak, rise * delta)
		_hold = HOLD_SECONDS
	elif _hold > 0.0:
		_hold -= delta
	else:
		level = move_toward(level, 0.0, delta / FADE_SECONDS)


func _cause() -> String:
	if bool(mare.get("sleeping")): return ""
	var affection: Node = mare.get_node_or_null("Affection")
	if affection != null and str(affection.get("kind")) == "kiss":
		return "deep" if affection.get("deep") == true else "kiss"
	var excitement: Variant = mare.get("excitement")
	if excitement is Node and float(excitement.get("_until")) > 0.0: return "other"
	return ""


func _peak() -> float:
	var runtime: Variant = mare.get_meta("relationship_runtime") if mare.has_meta("relationship_runtime") else null
	var bonds: Variant = runtime.get("bonds") if runtime is Object else null
	if bonds == null or not bonds.has_method("record_for"): return PEAK.friend
	var record: Variant = bonds.record_for(str(mare.get_meta("relationship_id", "")))
	return float(PEAK.get(str((record as Dictionary).get("stage", "friend")), PEAK.friend)) if record is Dictionary else PEAK.friend


# ---------------------------------------------------------------- horn

func _horn(delta: float) -> void:
	var magic: Variant = mare.get("magic")
	if not magic is Node or not is_instance_valid(magic): return
	# The game's excitement flares (excitement.gd _show, magic.sparkle) are held off for good.
	var excitement: Variant = mare.get("excitement")
	if excitement is Node: excitement.set("_spark", 1.0e9)
	if level <= 0.001:
		_horn_off()
		return
	# With the Horn Glow mod the build-up lights its glow around the horn (and its hum) instead.
	var horn_glow: Node = (magic as Node).get_node_or_null("HornGlow")
	if horn_glow != null and horn_glow.has_method("glow_from_outside"):
		_horn_off()
		var e := level * level * (3.0 - 2.0 * level)
		var p := 1.0 + PULSE_DEPTH * sin(_clock * TAU * lerpf(PULSE_RATE.x, PULSE_RATE.y, level))
		horn_glow.call("glow_from_outside", clampf(lerpf(GLOW_MIN, 1.0, e) * p, 0.0, 1.0))
		return
	if not _horn_on(magic): return
	var skeleton: Skeleton3D = magic.get("_skeleton")
	var bone: int = magic.get("_bone")
	var frame := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	var base: Vector3 = frame * (magic.get("_base_local") as Vector3)
	var tip: Vector3 = frame * (magic.get("_tip_local") as Vector3)
	_anchor.global_position = (base + tip) * 0.5
	var eased := level * level * (3.0 - 2.0 * level)
	var pulse := 1.0 + PULSE_DEPTH * sin(_clock * TAU * lerpf(PULSE_RATE.x, PULSE_RATE.y, level))
	if not is_instance_valid(_aura):
		var radius := maxf(base.distance_to(tip) * 0.5 * MAGIC_AURA.MARGIN, 0.05)
		_aura = MAGIC_AURA.create(_anchor, magic.get("color"), GLOW_MIN, radius, true)
		if is_instance_valid(_aura) and magic.get("_visual_layer") != null: _aura.set_visual_layer(int(magic.get("_visual_layer")))
	if is_instance_valid(_aura):
		_aura.set("strength", clampf(lerpf(GLOW_MIN, 1.0, eased) * pulse, 0.05, 1.0))
		var sparkles: Variant = _aura.get("_sparkles")
		if sparkles is GPUParticles3D: (sparkles as GPUParticles3D).amount_ratio = clampf(eased * eased, 0.0, 1.0)
	_light.visible = true
	_light.global_position = tip
	_light.light_energy = LIGHT_ENERGY * eased * pulse
	if not _hum.playing: _hum.play()
	_hum.volume_db = linear_to_db(maxf(HUM_PEAK * eased, 0.0001))
	_hum.pitch_scale = lerpf(HUM_PITCH.x, HUM_PITCH.y, level)


func _horn_on(magic: Node) -> bool:
	if is_instance_valid(_anchor): return true
	if magic.has_method("_build") and not bool(magic.call("_build")): return false
	if magic.get("_skeleton") == null: return false
	_anchor = Node3D.new()
	_anchor.name = "FeelingsHorn"
	_anchor.top_level = true
	add_child(_anchor)
	_light = OmniLight3D.new()
	_light.light_color = MAGIC.vivid(magic.get("color"))
	_light.omni_range = 0.8 * maxf(float(mare.get("body_scale")) if mare.get("body_scale") != null else 1.0, 1.0)
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	_light.top_level = true
	_anchor.add_child(_light)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = SUSTAIN
	_hum.unit_size = 4.0
	_hum.volume_db = -80.0
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("route"): settings.route(_hum, "SFX")
	_hum.finished.connect(func() -> void: if level > 0.001: _hum.play())
	_anchor.add_child(_hum)
	return true


func _horn_off() -> void:
	if is_instance_valid(_aura): _aura.call("release")
	_aura = null
	if is_instance_valid(_light): _light.visible = false
	if is_instance_valid(_hum) and _hum.playing: _hum.stop()


func _exit_tree() -> void:
	_horn_off()
	if is_instance_valid(_shiver): _shiver.queue_free()
	if is_instance_valid(_fidget): _fidget.queue_free()
	var excitement: Variant = mare.get("excitement") if is_instance_valid(mare) else null
	if excitement is Node: excitement.set("_spark", 0.0)
