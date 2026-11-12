extends Node
## Typing Lock: while an editable text box has keyboard focus, every game hotkey is off and Anon
## stays put.
##
## Why: the game's chat box and console already set player_body.controls_locked, but
##   - the seat/bed "Get up" key (Q, action stand_up) is polled in desktop_player.gd
##     _physics_process without checking that lock, so typing "quick" stands you up;
##   - other mods (Sit Anywhere replaces desktop_player.gd) may poll WASD without the lock;
##   - another lock owner restoring its saved value can unlock mid-sentence.
##
## How:
##   - Every key event is taken out of every InputMap action except the engine's ui_* actions
##     (those are what LineEdit/TextEdit type and move the caret with), and the actions are
##     released. Anything that asks Input/InputEvent about an action sees nothing pressed.
##     The keys go back the moment the text box loses focus, the world pauses, or the mod stops.
##     An action rebound in the meantime keeps its new key.
##   - controls_locked is held on while typing (only released afterwards if this mod set it).
##   - Nothing happens on the main menu or while the world is paused (menus, Settings key
##     rebinding), so a saved binding is never touched.
## Not covered: code that reads raw keys (Input.is_key_pressed, event.physical_keycode) without
## checking for a focused text box; that can't be blocked without also blocking the typing.

const LOG := "[typing_lock] "

## action -> Array of the InputEventKey removed from it.
var _stripped: Dictionary = {}
## The player body this mod locked, released again when typing ends.
var _locked_body: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Before the player's own _process/_physics_process, so it never sees a key mid-typing.
	process_priority = -1000
	process_physics_priority = -1000
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _exit_tree() -> void:
	_set_typing(false)


func _on_focus_changed(_node: Control) -> void:
	_update()


func _process(_delta: float) -> void:
	_update()


func _physics_process(_delta: float) -> void:
	_update()


func _input(event: InputEvent) -> void:
	# Focus taken inside this same event (Enter opening the chat): catch it before the next key.
	if event is InputEventKey: _update()


func _update() -> void:
	_set_typing(is_typing())


## An editable, visible text box has focus in the running world.
func is_typing() -> bool:
	if not is_inside_tree() or get_tree().paused: return false
	if not is_instance_valid(Mods.game): return false
	var focus := get_viewport().gui_get_focus_owner()
	if not (focus is LineEdit or focus is TextEdit): return false
	if not focus.is_visible_in_tree(): return false
	return focus.get("editable") != false


func _set_typing(on: bool) -> void:
	if on:
		if _stripped.is_empty(): _strip()
		_hold_lock()
	else:
		if not _stripped.is_empty(): _restore()
		_release_lock()


func _strip() -> void:
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_"): continue
		var keys: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey: keys.append(event)
		if keys.is_empty(): continue
		for event: InputEvent in keys: InputMap.action_erase_event(action, event)
		_stripped[action] = keys
		Input.action_release(action)
	print(LOG, "typing: %d actions off" % _stripped.size())


func _restore() -> void:
	for action: StringName in _stripped:
		if not InputMap.has_action(action): continue
		var rebound := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey: rebound = true; break
		if rebound: continue
		for event: InputEvent in _stripped[action]: InputMap.action_add_event(action, event)
	_stripped.clear()
	print(LOG, "typing done: keys back")


func _body() -> Node:
	var game: Node = Mods.game
	if not is_instance_valid(game): return null
	var inventory: Variant = game.get("inventory")
	if inventory is Node and is_instance_valid(inventory):
		var body: Variant = (inventory as Node).get("player_body")
		if body is Node and is_instance_valid(body): return body
	var player: Variant = game.get("player")
	if player is Node and is_instance_valid(player) and "controls_locked" in player: return player
	return null


func _hold_lock() -> void:
	var body := _body()
	if body == null or not "controls_locked" in body: return
	if body.controls_locked != true:
		body.controls_locked = true
		_locked_body = body


func _release_lock() -> void:
	if is_instance_valid(_locked_body) and _locked_body.controls_locked == true:
		_locked_body.controls_locked = false
	_locked_body = null
