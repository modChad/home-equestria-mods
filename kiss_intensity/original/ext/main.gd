extends "res://mods/kissing/main.gd"
## Extends the Kissing mod's start, rearing decision and player tick.
## The held moment asks for one answer. A young player, young pony, sleeper or
## carried pony takes the base path. Desktop pitch and camera-only presence live in kiss_view.gd.

const KI := preload("res://mods/kiss_intensity/kiss_terms.gd")
## Seconds she holds still before she answers [least, most].
const KI_MOMENT := Vector2(1.0, 2.0)

var _ki_pony: Node3D
var _ki_vr := false
var _ki_left := 0.0
## True while the held moment hands its kiss on to the mod's own _start().
var _ki_pass := false
var _ki_view := preload("res://mods/kiss_intensity/kiss_view.gd").new()


func _rearing(pony: Node3D) -> bool:
	if not super(pony): return false
	if not KI.on("rearing"): return true
	var affection: Node = pony.get_node_or_null("Affection")
	if affection == null or not affection.has_method("ki_level"): return true
	var level := float(affection.call("ki_level"))
	# Below 0: this pack shows nothing in this kiss, so the mod's own timing stands.
	return level < 0.0 or level >= KI.REAR_FROM


func _start(pony: Node3D, camera: Camera3D, vr := false) -> void:
	if _ki_pass or not KI.on("held_moment") or not _ki_holds(pony):
		super(pony, camera, vr)
		return
	if is_instance_valid(_ki_pony): return # She is already holding still for him.
	_ki_pony = pony
	_ki_vr = vr
	_ki_left = randf_range(KI_MOMENT.x, KI_MOMENT.y)
	_kisser.set("_used_hold", true)
	pony.get_node("Affection").call("ki_hold", true, camera.global_position)
	if LAB_DEBUG: print("[kiss_intensity] held moment ", pony.name)


## An awake adult on her own hooves, free to answer, with an adult player in front of her.
func _ki_holds(pony: Node3D) -> bool:
	if not is_instance_valid(pony) or pony.get("sleeping") == true or pony.has_meta("spa_client") or _forehead(pony): return false
	if pony.has_method("is_held") and bool(pony.call("is_held")): return false
	var affection: Node = pony.get_node_or_null("Affection")
	return affection != null and affection.has_method("ki_hold") and str(affection.get("kind")).is_empty() and float(affection.get("_buck_time")) < 0.0


func _physics_process(delta: float) -> void:
	# First of the tick: everything that reads the camera below sees his own look.
	_ki_view.restore_pitch(_kisser)
	super(delta)
	# After the mod's own tick, where its starts happen too: a kiss it is handed here is still
	# hidden from the kisser when after_kisser (-19) takes it over, as the mod expects.
	if _ki_pony != null: _ki_moment(delta)


func _vr_lean(camera: Camera3D, delta: float) -> void:
	super(camera, delta)
	# The mod frees the hold after a start that began no kiss; the held moment keeps it taken.
	if _ki_pony != null and is_instance_valid(_kisser): _kisser.set("_used_hold", true)


func _ki_moment(delta: float) -> void:
	var pony := _ki_pony
	var affection: Node = pony.get_node_or_null("Affection") if is_instance_valid(pony) else null
	var camera: Camera3D = _kisser.get("camera") as Camera3D if is_instance_valid(_kisser) else null
	if affection == null or not is_instance_valid(camera) or not _ki_holds(pony):
		_ki_moment_over(affection)
		return
	# He let go or drew back before she answered: nothing was asked, nothing is recorded.
	var leaning: bool = _kisser.get("_down") == true or (_ki_vr and _lean_close(camera, LEAN_BREAK))
	if not leaning:
		_ki_moment_over(affection)
		if _ki_vr: _lean_rearm = true
		return
	_kisser.set("_used_hold", true)
	affection.call("ki_hold", true, camera.global_position)
	_ki_left -= delta
	if _ki_left > 0.0: return
	var answer := str(affection.call("ki_ask"))
	if answer == "wait": return # A later kiss_terms() still deciding: she keeps holding.
	_ki_moment_over(affection)
	if LAB_DEBUG: print("[kiss_intensity] answer ", answer)
	if answer == "between":
		affection.call("ki_between", camera.global_position)
		if _ki_vr: _lean_rearm = true
		return
	_ki_pass = true
	super._start(pony, camera, _ki_vr)
	_ki_pass = false
	if not _ki_vr: return
	# As the mod's own lean does after a start.
	if _mine == null: _kisser.set("_used_hold", false)
	else: _lean_rearm = true


## After the player's own tick (his look and eye height are set): the tip for the next frames.
func after_player(delta: float) -> void:
	super(delta)
	if not is_instance_valid(_mine) and _ki_view.piece == null and _ki_view.tip == 0.0: return
	_ki_view.update(_kisser, _mine if is_instance_valid(_mine) else null, delta)


func _ki_moment_over(affection: Node) -> void:
	_ki_pony = null
	if is_instance_valid(affection) and affection.has_method("ki_hold"): affection.call("ki_hold", false)


func _exit_tree() -> void:
	_ki_view.drop()
	_ki_view.restore_pitch(_kisser)
	var held: Node = _ki_pony.get_node_or_null("Affection") if is_instance_valid(_ki_pony) else null
	_ki_moment_over(held)
	super()
