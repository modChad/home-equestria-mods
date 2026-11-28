extends Node
## Horn Touch: what the princesses do on the fifth unwanted touch of their own horn (main.gd).
## Luna banishes Anon to the moon: about a minute alone there, then a full day has passed and he
## wakes at home. Celestia and Twilight teleport him to a random spot in the Everfree Forest.
## Everything is the game's own: the moon, sky and pausing of Luna's dream (world/life/luna_dream.gd
## _build_moon / _space / _place), the sleep cover (world/ui/sleep_cover.gd), the home bed of the
## sleep system (player_sleep.gd _home_bed / _place_beside) and the debug console's _place.
const COVER := preload("res://world/ui/sleep_cover.gd")
const HABITAT := preload("res://world/life/everfree_habitat.gd")
const MOON_SECONDS := 60.0
const CHARGE := 2.0 # Her horn glows this long before the spell.
const EVERFREE_TRIES := 80
const AFTER_SPEECH := 3.0 # Seconds after she finishes her announcement before the spell.
const SPEECH_START_WAIT := 12.0 # Longest wait for her to start speaking.
const SPEECH_MAX := 25.0 # Longest she may speak before the spell goes ahead anyway.
var busy := false
var host: Node # main.gd


func _game() -> Node:
	var game: Variant = Mods.game
	return game if is_instance_valid(game) else null


func _body() -> Node3D:
	var game := _game()
	if game == null: return null
	var body: Variant = game.player.get_node("Body") if bool(game.get("xr_active")) else game.player
	return body if body is Node3D and is_instance_valid(body) else null


func _camera() -> Camera3D:
	var game := _game()
	return game.call("_find_camera", game.player) if game != null and game.has_method("_find_camera") else null


func _lock(on: bool) -> void:
	var body := _body()
	if body != null and "controls_locked" in body: body.controls_locked = on


func _cover(text: String) -> Node:
	var game := _game()
	var cover: Node = COVER.new()
	cover.name = "HornTouchCover"
	game.add_child(cover)
	cover.setup(game)
	if not text.is_empty() and cover.has_method("show_text"): cover.show_text(text)
	return cover


## She has her say first: wait for her to start speaking, to finish, then AFTER_SPEECH more.
## Her horn glows the whole time. If she never speaks, the spell goes ahead after the start wait.
func _await_announcement(pony: Node3D) -> bool:
	var waited := 0.0
	var spoke := false
	while waited < SPEECH_START_WAIT + SPEECH_MAX:
		if not is_instance_valid(pony) or _game() == null: return false
		var speaking: bool = pony.has_method("is_speaking") and bool(pony.call("is_speaking"))
		if speaking: spoke = true
		elif spoke or waited >= SPEECH_START_WAIT: break
		if pony.has_method("cast_magic") and int(waited * 4.0) % 4 == 0: pony.call("cast_magic", 1.5)
		await get_tree().create_timer(.25).timeout
		waited += .25
	await get_tree().create_timer(AFTER_SPEECH if spoke else 0.0).timeout
	return is_instance_valid(pony) and _game() != null


## Her horn lights and a flash takes him. True when it went ahead.
func _charge(pony: Node3D, color: Color) -> bool:
	if not await _await_announcement(pony): return false
	if pony.has_method("cast_magic"): pony.call("cast_magic", CHARGE + 1.5)
	var magic: Variant = pony.get("magic")
	var body := _body()
	if body != null and magic is Node3D and is_instance_valid(magic):
		UnicornMagic.burst(body, Vector3.UP * 1.0, color, CHARGE + .4, .6)
	await get_tree().create_timer(CHARGE).timeout
	return is_instance_valid(pony) and _body() != null and _game() != null


# ------------------------------------------------------------------ the moon

func banish_to_moon(pony: Node3D, color: Color) -> bool:
	var dream: Node = get_tree().get_first_node_in_group("luna_dream")
	var game := _game()
	if busy or dream == null or bool(dream.get("active")) or game == null or bool(game.get("player_sleeping")): return false
	if not dream.has_method("_build_moon") or not dream.has_method("_space") or not dream.has_method("_place"): return false
	busy = true
	if not await _charge(pony, color): busy = false; return false
	var body := _body()
	var camera := _camera()
	if body.has_method("stand_up") and body.get("seat") != null: body.stand_up()
	_lock(true)
	var saves: Variant = game.get("saves")
	var could_save: bool = saves is Object and bool(saves.get("ready_to_save"))
	if could_save: saves.set("ready_to_save", false) # Never a checkpoint on the moon.
	var cover := _cover("Banished to the moon!")
	await cover.close_eyes()
	dream.call("_build_moon")
	dream.call("_space", true)
	dream.call("_place", body, camera, Vector3(dream.call("_surface", Vector2.ZERO)) + Vector3.UP * 0.1, 0.0)
	_lock(false)
	await cover.open_eyes()
	if is_instance_valid(cover): cover.finish()
	if host != null: host.call("note", "Banished to the moon until tomorrow…")
	print("[horn_touch] banished to the moon")
	await get_tree().create_timer(MOON_SECONDS).timeout
	game = _game()
	body = _body()
	if game == null or body == null: busy = false; return true
	_lock(true)
	cover = _cover("A day passes…")
	await cover.close_eyes()
	var root: Variant = dream.get("_root")
	if root is Node and is_instance_valid(root): (root as Node).queue_free()
	dream.set("_root", null); dream.set("_surface_mesh", null)
	dream.call("_space", false)
	# A full day later, at home.
	var clock := get_node_or_null("/root/TimeOfDay")
	if clock != null: clock.day = int(clock.day) + 1
	var sleep: Variant = game.get("sleep")
	var bed: Variant = sleep.call("_home_bed") if sleep is Object and sleep.has_method("_home_bed") else null
	if bed is Node3D and sleep.has_method("_place_beside"): sleep.call("_place_beside", bed)
	else:
		var spawn: Variant = game.get("spawn")
		if spawn is Node3D: dream.call("_place", body, _camera(), (spawn as Node3D).global_position, 0.0)
	await get_tree().physics_frame
	var zones := get_node_or_null("/root/ZoneManager")
	if zones != null and zones.has_method("wait_until_idle"): await zones.wait_until_idle()
	if could_save and is_instance_valid(saves): saves.set("ready_to_save", true)
	_lock(false)
	await cover.open_eyes()
	if is_instance_valid(cover): cover.finish()
	busy = false
	print("[horn_touch] back from the moon, day %s" % (str(clock.day) if clock != null else "?"))
	return true


# ------------------------------------------------------------------ the Everfree

## A random spot well inside the Everfree, on the ground; INF when none was found.
func everfree_spot() -> Vector3:
	var region := WorldLayout.region("everfree")
	if region.is_empty() or not is_instance_valid(WorldTerrain.instance): return Vector3.INF
	var area := WorldLayout.footprint(region)
	for i in EVERFREE_TRIES:
		var x := randf_range(area.position.x, area.end.x)
		var z := randf_range(area.position.y, area.end.y)
		var ground: float = WorldTerrain.instance.height_at(Vector3(x, 0.0, z))
		if not is_finite(ground): continue
		var at := Vector3(x, ground, z)
		if HABITAT.strength(at + Vector3.UP * 0.5) >= 0.6: return at
	return Vector3.INF


func send_to_everfree(pony: Node3D, color: Color) -> bool:
	var game := _game()
	if busy or game == null or bool(game.get("player_sleeping")): return false
	var goal := everfree_spot()
	if not goal.is_finite(): return false
	busy = true
	if not await _charge(pony, color): busy = false; return false
	var body := _body()
	if body.has_method("stand_up") and body.get("seat") != null: body.stand_up()
	_lock(true)
	var cover := _cover("Teleported to the Everfree Forest!")
	await cover.close_eyes()
	var console: Variant = game.get_node_or_null("CommandConsole")
	if console is Object and (console as Object).has_method("_place"): console.call("_place", goal + Vector3.UP * 0.3, "")
	elif body.has_method("teleport"): body.call("teleport", goal + Vector3.UP * 0.3)
	else: body.global_position = goal + Vector3.UP * 0.3
	if is_instance_valid(WorldTerrain.instance) and WorldTerrain.instance.has_method("focus"): WorldTerrain.instance.focus(goal)
	await get_tree().physics_frame
	var zones := get_node_or_null("/root/ZoneManager")
	if zones != null and zones.has_method("wait_until_idle"): await zones.wait_until_idle()
	# Ground under him now that it has loaded.
	var ground: float = WorldTerrain.instance.height_at(goal) if is_instance_valid(WorldTerrain.instance) else NAN
	if is_finite(ground) and absf(body.global_position.y - ground) > 2.0:
		body.global_position.y = ground + 0.3
		if "velocity" in body: body.velocity = Vector3.ZERO
	_lock(false)
	UnicornMagic.burst(body, Vector3.UP * 1.0, color, 1.0, .5)
	await cover.open_eyes()
	if is_instance_valid(cover): cover.finish()
	busy = false
	print("[horn_touch] sent to the Everfree at %s" % str(goal.round()))
	return true
