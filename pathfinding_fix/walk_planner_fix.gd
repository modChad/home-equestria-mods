extends "res://world/navigation/walk_planner.gd"
## Pathfinding Fix (modChad): the GDScript route search (used only when the native search is off
## or refuses a job). The game's chunk corridor scores every 16 m tile the same and ignores roads,
## trails and slopes, then keeps the exact search inside that band, so a road just outside it is
## never used. With fix_use_corridor off, the exact search sees every resident tile.

var fix_use_corridor := true


func _chunk_corridor(start: Vector3i, goal: Vector3i) -> Dictionary:
	if not fix_use_corridor: return {}
	return super(start, goal)
