extends Node
## Desktop only. Placed last under the root by main.gd, so its _input runs before the briefcase's:
## with a grooming brush in hand and a pony's mane, tail or coat under the crosshair, a click starts
## brushing and holding the button keeps it going. Every other click reaches the game unchanged.

var groomer: Node


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not is_instance_valid(groomer): return
	var button := event as InputEventMouseButton
	if button.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: return
	# A release always reaches the groomer, so a stroke never sticks on.
	if not button.pressed:
		if bool(groomer.call("desktop_click", false)): get_viewport().set_input_as_handled()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not _free_hand(): return
	if bool(groomer.call("desktop_click", true)): get_viewport().set_input_as_handled()


## The briefcase is closed, no menu, activity or text field owns the click.
func _free_hand() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	var game: Node = Mods.game
	if not is_instance_valid(game): return false
	var inventory: Node = game.get("inventory")
	if inventory == null or not bool(inventory.get("_desktop")): return false
	var case: Variant = inventory.get("case")
	if case is CanvasItem and (case as CanvasItem).visible: return false
	if case is Node3D and (case as Node3D).visible: return false
	var customizer: Variant = inventory.get("customizer")
	if customizer != null and bool(customizer.get("opened")): return false
	if inventory.has_meta("desktop_activity_owner") and is_instance_valid(inventory.get_meta("desktop_activity_owner")): return false
	var body: Variant = inventory.get("player_body")
	if is_instance_valid(body) and body.get("controls_locked") == true: return false
	return true
