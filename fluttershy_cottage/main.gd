extends Node
## Fluttershy's Cottage: replaces the cottage's shell and cropped set with Discopears' complete
## room (cottage_swap.gd) and moves Fluttershy's bed, stove and bookshelf into it. The loft
## routing is ext/cottage_home.gd. Switching the mod off puts the game's cottage back (the
## extension then does nothing until the next start).
const SWAP := preload("res://mods/fluttershy_cottage/cottage_swap.gd")
const COTTAGE := "res://world/buildings/fluttershy/cottage.gd"
var _done: Array[Node3D] = []

func _ready() -> void:
	Mods.on_node(COTTAGE, _on_cottage)

func _on_cottage(node: Node) -> void:
	# The game's attach() finishes its own work after the cottage is ready; build after it.
	_apply.call_deferred(node)

func _apply(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	if SWAP.apply(node as Node3D) != null: _done.append(node as Node3D)

func _exit_tree() -> void:
	for usable in _done:
		if is_instance_valid(usable): SWAP.undo(usable)
	_done.clear()
