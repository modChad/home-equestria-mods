extends RefCounted
## Kiss intensity: a pegasus's or alicorn's wings follow the level through a kiss.
##
## Without this pack the game spreads her wings fully the moment she is kissed (excitement.gd).
## With it they stay folded at first, lift out of the fold from WINGS_LIFT_FROM, widen slowly, and
## snap fully open at WINGS_OPEN_FROM. Once fully open the Kissing mod's own shiver takes over
## (its wings.gd reads the same tuck and half values). After the kiss they follow the level back
## down as it fades.
##
## Built on the game's wing hold (hybrid_open_wings.gd hold_at / release_hold) and its two posed
## blends: `tuck` (folded .. open) and `half` (the half-open pose .. fully open). Both are poses
## made in Blender for this rig; this only moves between them, so no joint limit is involved.
## While held, flight's and excitement's own open/close requests are remembered by the wings and
## applied again on release.

const KI := preload("res://mods/kiss_intensity/kiss_terms.gd")
## How far above WINGS_LIFT_FROM the wings are out of the fold.
const LIFT_SPAN := 0.12
## The half-open blend just before they snap open (1 = the half-open pose, 0 = fully open).
const WIDE_BEFORE_SNAP := 0.55
## Seconds for a full unfold, a full widening and the snap.
const LIFT_SECONDS := 0.6
const WIDEN_SECONDS := 0.8
const SNAP_SECONDS := 0.15
## The level must fall this far under WINGS_OPEN_FROM before they close in again.
const OPEN_SLACK := 0.08

var wings: Node # hybrid_open_wings.gd
var open := false


## Takes her wings for this kiss, still folded. Null when she has none, is flying, already has
## them open (flight, a spread her AI asked for) or someone else holds them (the spa).
static func take(mare: Node3D) -> RefCounted:
	var identity: Variant = mare.get("identity")
	if not identity is Object or not (identity as Object).has_method("has_wings") or not identity.has_wings(): return null
	var excitement: Variant = mare.get("excitement")
	if not excitement is Node or not (excitement as Node).has_method("_wings"): return null
	if (excitement as Node).has_method("_flying") and bool(excitement.call("_flying")): return null
	var node: Variant = excitement.call("_wings")
	if not node is Node or not (node as Node).has_method("hold_at"): return null
	if bool(node.get("opened")) or not str(node.get("hold_owner")).is_empty(): return null
	if not bool(node.call("hold_at", KI.OWNER, 1.0)): return null
	var lift: RefCounted = new()
	lift.wings = node
	node.set("tuck", 1.0)
	node.set("half", 1.0)
	lift._drive()
	return lift


func held() -> bool:
	return is_instance_valid(wings) and str(wings.get("hold_owner")) == KI.OWNER


func tick(level: float, delta: float) -> void:
	if not held(): return
	if level >= KI.WINGS_OPEN_FROM: open = true
	elif level < KI.WINGS_OPEN_FROM - OPEN_SLACK: open = false
	var lift := smoothstep(KI.WINGS_LIFT_FROM, KI.WINGS_LIFT_FROM + LIFT_SPAN, level)
	var half_goal := 0.0 if open else lerpf(1.0, WIDE_BEFORE_SNAP, smoothstep(KI.WINGS_LIFT_FROM + LIFT_SPAN, KI.WINGS_OPEN_FROM, level))
	var half_now := float(wings.get("half"))
	wings.set("tuck", move_toward(float(wings.get("tuck")), 1.0 - lift, delta / LIFT_SECONDS))
	wings.set("half", move_toward(half_now, half_goal, delta / (SNAP_SECONDS if open and half_now > half_goal else WIDEN_SECONDS)))
	wings.set("hold_goal", half_goal)
	_drive()


## Folded again, with nothing left to show.
func folded() -> bool:
	return not held() or float(wings.get("tuck")) >= 1.0


## The last open or close request the wings remember (flight, excitement).
func asked_open() -> bool:
	return is_instance_valid(wings) and bool(wings.get("_asked_open"))


## Gives the wings back: they ease to whatever flight or excitement last asked for.
func release() -> void:
	if held(): wings.call("release_hold", KI.OWNER)
	wings = null


## The wings' own easing is off while this moves them; the folded mesh shows while fully tucked.
func _drive() -> void:
	wings.set_process(false)
	var out := float(wings.get("tuck")) < 1.0
	for mesh: MeshInstance3D in wings.get("meshes"): mesh.visible = out
	for mesh: MeshInstance3D in wings.get("folded"): mesh.visible = not out
