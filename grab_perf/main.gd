extends Node
## Grab Perf: VR frame drops while the hands are clenched.
##
## With a full fist (grip + trigger) and nothing held, player/pony_hoof_grabber.gd checks every
## pony the grabber knows (every spawned pony, ~47 in town) for a leg within 9 cm of each hand,
## every physics tick. Each check (pony_hoof_hold.gd candidate()) first runs forward kinematics
## over her whole skeleton in GDScript, however far away she is: about 5,600 full skeleton passes
## a second with both fists, which takes a Quest from ~25 to 17-19 FPS.
##
## For the grabber's own tick only, its `ponies` list holds just the ponies near a hand (plus any
## it holds or targets). A gate just before it swaps the short list in; a gate just after puts the
## full list back, keeping any pony the game added or removed in between. Nothing else ever sees
## the short list, and the grabber's behaviour is unchanged: a leg or chest grip is only ever
## taken within centimetres of a hand. Desktop has no physics hands, so nothing changes there.

const GRABBER_SCRIPT := "res://player/pony_grabber.gd"
const GATE := preload("res://mods/grab_perf/gate.gd")
## A pony's legs and chest grips sit well within this of her root, per unit of body scale.
const REACH_PER_SCALE := 2.5

var _grabber: Node
var _pre: Node
var _post: Node
var _full: Array = []
var _near: Array = []
var _swapped := false


func _ready() -> void:
	var mods := get_node_or_null("/root/Mods")
	if mods != null: mods.on_node(GRABBER_SCRIPT, _attach)


func _attach(node: Node) -> void:
	if node == _grabber or node.get("ponies") == null: return
	_detach()
	_grabber = node
	var priority: int = node.process_physics_priority
	_pre = _gate("GrabPerfBefore", priority - 1, _before)
	_post = _gate("GrabPerfAfter", priority + 1, _after)
	if not node.tree_exiting.is_connected(_detach): node.tree_exiting.connect(_detach)


func _gate(gate_name: String, priority: int, tick: Callable) -> Node:
	var gate: Node = GATE.new()
	gate.name = gate_name
	gate.process_physics_priority = priority
	gate.on_tick = tick
	add_child(gate)
	return gate


## Just before the grabber's tick: only the ponies near a hand.
func _before() -> void:
	if _swapped: _after()
	if not is_instance_valid(_grabber): return
	var hands: Array[Vector3] = []
	var hand_nodes: Variant = _grabber.get("_hands")
	if hand_nodes is Dictionary:
		for hand: Variant in (hand_nodes as Dictionary).values():
			if is_instance_valid(hand) and hand is Node3D: hands.append((hand as Node3D).global_position)
	if hands.is_empty(): return  # desktop: the grabber skips the scan anyway
	var all: Array = _grabber.get("ponies")
	if all.size() <= 2: return
	var keep_always: Array = _kept_ponies()
	var near: Array = []
	var nearest: Node = null
	var nearest_distance := INF
	for pony: Variant in all:
		if not is_instance_valid(pony) or not pony is Node3D: continue
		if pony in keep_always:
			near.append(pony); continue
		var scale: float = maxf(1.0, float(pony.get("body_scale")) if pony.get("body_scale") != null else 1.0)
		var reach := REACH_PER_SCALE * scale
		var closest := INF
		for hand in hands: closest = minf(closest, hand.distance_squared_to((pony as Node3D).global_position))
		if closest < reach * reach: near.append(pony)
		elif closest < nearest_distance:
			nearest_distance = closest; nearest = pony
	# Never hand the grabber an empty list: it reads that as "no ponies" and lets go.
	if near.is_empty() and nearest != null: near.append(nearest)
	if near.is_empty(): return
	_full = all
	_near = near.duplicate()  # the grabber edits `near` in place; compare against a copy
	_grabber.set("ponies", near)
	_swapped = true


## Just after: the full list back, with anything the game added or removed meanwhile.
func _after() -> void:
	if not _swapped: return
	_swapped = false
	if not is_instance_valid(_grabber):
		_full = []; _near = []; return
	var now: Variant = _grabber.get("ponies")
	if now is Array:
		for pony: Variant in now:
			if pony not in _full: _full.append(pony)
		for pony: Variant in _near:
			if is_instance_valid(pony) and pony not in now: _full.erase(pony)
	_grabber.set("ponies", _full.filter(func(p: Variant) -> bool: return is_instance_valid(p)))
	_full = []; _near = []


## Ponies the grabber is holding or targeting stay in its list whatever their distance.
func _kept_ponies() -> Array:
	var kept: Array = []
	var target: Variant = _grabber.get("pony")
	if is_instance_valid(target): kept.append(target)
	var held: Variant = _grabber.get("_held_ponies")
	if held is Dictionary:
		for pony: Variant in (held as Dictionary).values():
			if is_instance_valid(pony): kept.append(pony)
	var hoof: Variant = _grabber.get("hoof_grabber")
	if hoof is Object and (hoof as Object).get("held") is Dictionary:
		for pony: Variant in ((hoof as Object).get("held") as Dictionary).values():
			if is_instance_valid(pony): kept.append(pony)
	return kept


func _detach() -> void:
	_after()
	for gate: Node in [_pre, _post]:
		if is_instance_valid(gate): gate.queue_free()
	_pre = null; _post = null
	if is_instance_valid(_grabber) and _grabber.tree_exiting.is_connected(_detach):
		_grabber.tree_exiting.disconnect(_detach)
	_grabber = null


## Switched off mid-game: the grabber keeps its full list.
func _exit_tree() -> void:
	_detach()
