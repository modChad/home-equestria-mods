extends RefCounted
## Kiss intensity: the one hook to the relationship rules, the levels and the switches.
##
## Everything this pack shows is driven by one value, the Kissing mod's `level` (feelings.gd,
## 0..1), cut off at the ceiling kiss_terms() gives. Nothing else decides what her body shows.

const OWNER := "kiss_intensity"

## The level at which her body starts to show each thing. For what her body shows only.
const BLUSH_FROM := 0.10
const WINGS_LIFT_FROM := 0.40
const BREATHER_FROM := 0.45
const TONGUE_FROM := 0.55
const WINGS_OPEN_FROM := 0.70
const REAR_FROM := 0.70
const STRAND_FROM := 0.85
## The desktop view tips down between these two levels, to VIEW_TIP_DEGREES (ext/main.gd).
const VIEW_TIP_FROM := 0.28
const VIEW_TIP_FULL := 0.58
const VIEW_TIP_DEGREES := 48.0
## Degrees a second the view tips down at most, and eases back up at most.
const VIEW_TIP_RATE := Vector2(13.0, 34.0)
## The share of the tip given back at the widest point of a breather (48 -> about 19 degrees).
const VIEW_TIP_BREATHER := 0.6

## One switch per feature, all on by default: user://mods/data/kiss_intensity/options.cfg,
## section [effects]. Read again at the start of every kiss, so a change needs no restart.
const SWITCHES := ["blush", "eyes", "lip_cycle", "small_motions", "breather", "breath_clouds", "sounds", "wings", "rearing", "tongue", "saliva_bridge", "held_moment", "view_tip", "own_face", "turn_away", "mane_fade"]
static var _switches: Dictionary = {}
## The review fixture sets this to see one answer on demand ("back", "between", "away"). Empty in
## play. While set, the rules are not asked and nothing is recorded.
static var review_answer := ""


## What she does when he leans in, and how far her feelings may build in this kiss.
## answer: "back", "between" or "away". ceiling: 0..1, the most `level` may reach.
##
## Today's body is the rules that already exist: relationship_runtime.affection_allowed() for the
## answer (it never says "between") and the Kissing mod's bond peak for the ceiling.
## Asking is itself an event for those rules (it records the touch and counts a press), so the
## pack asks once per lean-in, for an awake adult and an adult player only, and keeps the answer
## for that kiss (ext/affection.gd ki_ask() and begin()).
## A later body that has to wait for its answer may return {"answer": "wait"}: she stays in the
## held moment while he keeps leaning in, and the pack asks again on the next physics tick.
static func kiss_terms(mare: Node3D) -> Dictionary:
	if not review_answer.is_empty(): return {"answer": review_answer, "ceiling": ceiling_for(mare) if review_answer == "back" else 0.0}
	var runtime: Variant = mare.get_meta("relationship_runtime") if mare.has_meta("relationship_runtime") else null
	var back: bool = runtime is Object and (runtime as Object).has_method("affection_allowed") and bool(runtime.affection_allowed(mare, "kiss"))
	return {"answer": "back" if back else "away", "ceiling": ceiling_for(mare) if back else 0.0}


## The Kissing mod's own peak for her bond (feelings.gd PEAK). Asks the rules nothing.
static func ceiling_for(mare: Node3D) -> float:
	var feelings: Node = mare.get_node_or_null("KissingFeelings")
	if feelings == null or not feelings.has_method("_peak"): return 0.0
	return clampf(float(feelings.call("_peak")), 0.0, 1.0)


## How far the desktop view tips down at this level, in radians. Below 0 (no kiss of this pack)
## and with the switch off: none.
static func view_tip(level: float) -> float:
	if level < 0.0 or not on("view_tip"): return 0.0
	return deg_to_rad(VIEW_TIP_DEGREES) * smoothstep(VIEW_TIP_FROM, VIEW_TIP_FULL, level)


## One step of the tip toward `want` (radians): slow down, quicker back, soft at both ends.
static func ease_tip(now: float, want: float, delta: float) -> float:
	var rate := deg_to_rad(VIEW_TIP_RATE.x if want > now else VIEW_TIP_RATE.y)
	var step := minf(rate, absf(want - now) * 3.0 + deg_to_rad(0.6)) * delta
	return move_toward(now, want, step)


static func on(switch: String) -> bool:
	if _switches.is_empty(): reload()
	return bool(_switches.get(switch, true))


static func options_path() -> String:
	var mods: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Mods")
	var folder: String = str(mods.call("data_folder", OWNER)) if mods != null and mods.has_method("data_folder") else "user://mods/data/" + OWNER
	return folder.path_join("options.cfg")


## Reads the switches; writes the file with every switch in it when one is missing.
static func reload() -> void:
	var path := options_path()
	var file := ConfigFile.new()
	var found := FileAccess.file_exists(path) and file.load(path) == OK
	var complete := found
	for switch: String in SWITCHES:
		if not file.has_section_key("effects", switch):
			file.set_value("effects", switch, true)
			complete = false
		_switches[switch] = bool(file.get_value("effects", switch, true))
	if complete: return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	file.save(path)
