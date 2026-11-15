extends Node
## Fishing: typing to a pony shouldn't put your rod back. The game's FishingHands (physics
## priority -65) returns the rod to the rack whenever its hands aren't "available", and a focused
## chat box counts. (Before 0.6.0 pony companions only fished while you held a rod, so pressing Enter to talk
## to one sent every companion back to the rack too.) While a text box has focus, this hides the
## rod from FishingHands for its tick (-66 takes it, -64 gives it back), so neither the rod nor
## the cast is lost. Only typing is covered: E/Q, menus and the briefcase still return the rod.
var host: Node        # main.gd
var _stash: Node3D
var _hands: Node
var _give_back: Node
var _was_typing := false

func _ready() -> void:
	process_physics_priority = -66
	_give_back = Node.new(); _give_back.name = "GiveBack"
	var s := GDScript.new()
	s.source_code = "extends Node\nvar guard: Node\nfunc _ready() -> void:\n\tprocess_physics_priority = -64\nfunc _physics_process(_d: float) -> void:\n\tif is_instance_valid(guard): guard.give_back()\n"
	s.reload(); _give_back.set_script(s); _give_back.set("guard", self); add_child(_give_back)

func _physics_process(_delta: float) -> void:
	_hands = _find_hands()
	if not is_instance_valid(_hands): return
	var rod: Node3D = _hands.get("rod")
	if not is_instance_valid(rod) or str(rod.get("holder")) != "player" or str(_hands.get("side")) != "desktop": return
	var focus: Control = get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit
	if typing:
		_stash = rod; _hands.set("rod", null)
	if typing != _was_typing:
		print("[fishing] typing: %s (rod %s kept in hand)" % ["started" if typing else "finished", rod.name])
		_was_typing = typing

func give_back() -> void:
	if is_instance_valid(_stash) and is_instance_valid(_hands) and _hands.get("rod") == null:
		_hands.set("rod", _stash)
	_stash = null

func _find_hands() -> Node:
	if not is_instance_valid(host): return null
	for rod: Node in host.get("_rods"):
		if is_instance_valid(rod) and rod.get_parent() != null and rod.get_parent().get_parent() != null:
			var h: Variant = rod.get_parent().get_parent().get("hands")
			if h is Node and is_instance_valid(h): return h
	return null

func _exit_tree() -> void:
	give_back()
