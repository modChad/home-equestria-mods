extends RefCounted
## Idle cost, from devanon's "Kissing: idle and typing fixes" 1.0.3 (bundled with the game as
## kissing_patch, written for 1.2.9 to 1.2.11), merged into Kissing in 1.2.13 with his work credited.
## main.gd calls tick() once a physics tick. The code and its reasoning are devanon's; only the
## names changed (no _patch_ prefix) and it reads main.gd's list of ponies (_hooked) through `main`.
##
## Each pony has a KissingFeelings node (feelings.gd) whose _process ran on every rendered frame,
## also while nopony was excited (47 ponies in a town street: 47 calls a frame). While she is calm
## it only (a) holds the game's horn flares off (excitement.gd _spark = 1.0e9, feelings.gd _horn())
## and (b) keeps an existing wing shiver the skeleton's last child (_wings()).
## Now a feelings node's _process runs only while she is excited or her feelings have not faded yet
## (awake()); this does (a) for the sleeping ones. Only awake nodes are looked at each tick, to put
## them back to sleep. A sleeping node is woken from her own excitement beat (after_beat(), 10 Hz),
## so her build-up starts at most 0.1 s later; the 0.5 s refresh wakes a pony whose beat is not
## hooked yet and keeps the flare hold for those.
## Flare hold: excitement.gd sets _spark to 0 in _calm() on every 10 Hz beat while she is calm and
## flares the horn whenever _show(true) finds _spark <= 0 (from that beat, or at once from her AI's
## [excited] / [wings:spread] tags). after_beat() runs right after the game's _on_beat() (connected
## later, so called later) and writes 1.0e9 back for a sleeping node, so outside the beat _spark is
## never 0 and no flare fires that the per-frame version would have held.
## Fidget nodes (fidgets.gd) and wing shivers (wings.gd) were never removed: after her first
## excitement they ran every frame for the rest of the session and kept a far pony's rig from
## parking. The refresh frees them once they have settled; feelings.gd makes them again next time.
## feelings.gd _clock only feeds the horn's pulse, so pausing it changes only where the pulse starts.

## Seconds between passes over main.gd's list of ponies (_hooked).
const LIST_EVERY := 0.5

var main: Node
## Feelings nodes whose _process runs now; the only ones looked at every tick.
var _running: Array = []
var _list_in := 0.0
## Instance ids of the Beat timers hook_beat() has connected to.
var _beats: Dictionary = {}


func _init(owner: Node) -> void:
	main = owner


func tick(delta: float) -> void:
	_list_in -= delta
	if _list_in <= 0.0:
		_list_in = LIST_EVERY
		_refresh()
	for index: int in range(_running.size() - 1, -1, -1):
		var item: Variant = _running[index]
		if not is_instance_valid(item):
			_running.remove_at(index); continue
		var feelings: Node = item
		var mare: Variant = feelings.get("mare")
		# Without her its _process returns at once: nothing to run, nothing to do.
		if is_instance_valid(mare) and awake(feelings): continue
		feelings.set_process(false)
		_running.remove_at(index)
		if is_instance_valid(mare): hold_flares(mare as Node)


func wake(feelings: Node) -> void:
	feelings.set_process(true)
	if not _running.has(feelings): _running.append(feelings)


## Runs while she is excited (_cause()), while her feelings are built or held (level, _hold), and
## always in the lab (as_earth). level > 0.0 rather than feelings.gd's own 0.001: below it her
## _process still fades level to 0 (the fidgets read it), so the node sleeps only once it is 0.
func awake(feelings: Node) -> bool:
	if bool(feelings.get("as_earth")): return true
	if float(feelings.get("level")) > 0.0 or float(feelings.get("_hold")) > 0.0: return true
	return not str(feelings.call("_cause")).is_empty()


## feelings.gd _horn(): with her horn magic there, the game's excitement flares are held off.
func hold_flares(mare: Node) -> void:
	var magic: Variant = mare.get("magic")
	if not is_instance_valid(magic) or not magic is Node: return
	var excitement: Variant = mare.get("excitement")
	if is_instance_valid(excitement) and excitement is Node: (excitement as Node).set("_spark", 1.0e9)


func _refresh() -> void:
	var beats: Dictionary = {}
	var hooked: Dictionary = main.get("_hooked")
	for pony: Variant in hooked.keys():
		if not is_instance_valid(pony):
			hooked.erase(pony); continue
		var node: Node = pony
		var feelings: Node = node.get_node_or_null("KissingFeelings")
		if feelings == null or feelings.is_queued_for_deletion(): continue
		hook_beat(node, beats)
		if feelings.is_processing():
			# Made since the last refresh, or woken: the tick puts her to sleep when calm.
			if not _running.has(feelings): _running.append(feelings)
			continue
		if is_instance_valid(feelings.get("mare")) and awake(feelings):
			wake(feelings); continue
		hold_flares(node)
		settle(feelings)
	# Forgets timers that are gone; a timer still there stays connected for good.
	_beats = beats


## A sleeping pony's fidget node and wing shiver are freed once they have come to rest; wings.gd
## puts the wing bones back in its _exit_tree.
func settle(feelings: Node) -> void:
	var fidget: Variant = feelings.get("_fidget")
	if is_instance_valid(fidget) and fidget is Node and not (fidget as Node).is_queued_for_deletion():
		if float(fidget.get("amount")) <= 0.0 and float(fidget.get("_ear_left")) <= 0.0 and not bool(fidget.get("_tail_owned")):
			(fidget as Node).queue_free()
	var shiver: Variant = feelings.get("_shiver")
	if is_instance_valid(shiver) and shiver is Node and not (shiver as Node).is_queued_for_deletion():
		if float(shiver.get("amount")) <= 0.001: (shiver as Node).queue_free()


## Connects after_beat() to her excitement's Beat timer, once. Bound to the pony, not to her
## feelings node, so it finds whichever feelings node she has when it runs.
func hook_beat(pony: Node, beats: Dictionary) -> void:
	var excitement: Variant = pony.get("excitement")
	if not is_instance_valid(excitement) or not excitement is Node: return
	var beat: Timer = (excitement as Node).get_node_or_null("Beat") as Timer
	if beat == null: return
	var id: int = beat.get_instance_id()
	beats[id] = true
	if not _beats.has(id): beat.timeout.connect(after_beat.bind(pony))


## Right after her excitement beat: a sleeping node is woken if she is excited now, else the flare
## hold goes back in place at once. An awake node holds them itself on its next frame.
func after_beat(pony: Variant) -> void:
	if not is_instance_valid(pony): return
	var feelings: Node = (pony as Node).get_node_or_null("KissingFeelings")
	if feelings == null or feelings.is_processing(): return
	if is_instance_valid(feelings.get("mare")) and awake(feelings): wake(feelings)
	else: hold_flares(pony as Node)
