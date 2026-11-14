extends Node
## Stable (half) front door, 1.3.0: keeps the top half open at least as far as the bottom half,
## as when the halves are bolted together, so a pony opening the house door (the bottom half)
## never walks into a shut top. The top still opens on its own. When the bottom shuts again, a
## top it carried open goes back to where the player left it.
var bottom
var top
var _carried := false
var _own := 0.0

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(bottom) or not is_instance_valid(top): return
	if is_instance_valid(top.holder): _carried = false; _own = top.target; return
	if not _carried: _own = top.target
	var want: float = maxf(bottom.target, bottom.opening_angle())
	if want > top.target + 0.001:
		top.target = minf(want, top.open_limit()); _carried = true
	elif _carried:
		var rest := maxf(want, _own)
		if rest < top.target - 0.001: top.target = rest
		if want <= _own + 0.001: _carried = false
