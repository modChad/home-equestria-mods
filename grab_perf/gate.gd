extends Node
## One side of Grab Perf's window around the pony grabber's physics tick (main.gd).
var on_tick: Callable

func _physics_process(_delta: float) -> void:
	if on_tick.is_valid(): on_tick.call()
