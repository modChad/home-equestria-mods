extends "res://world/minigames/fishing/fishing_companions.gd"
## Fishing: ponies fish on their own. The game's FishingCompanions only lets ponies borrow a rod
## while the player holds one, and sends them all back the moment the player's rod goes back
## (Q, a dropped rod, a menu). This copy changes only that one test: while the pier is loaded,
## up to two idle ponies near it may fish whether or not the player is. Everything else (who is
## eligible, the walk to the rack, the cast and reel, giving up a rod the player takes) is the game's.

## Ponies may fish whenever the pier and its hands exist.
func _player_fishing() -> bool:
	return is_instance_valid(game) and is_instance_valid(dock) and is_instance_valid(hands)

## The game's original test: the player is holding a pier rod near the pier. Used for the shared
## "fished together" memory, which should only happen when the player really is fishing too.
func player_with_rod() -> bool:
	if not _player_fishing(): return false
	var rod: Node3D = hands.get("rod") as Node3D
	return is_instance_valid(rod) and rod in dock.rods and rod.holder == "player" \
		and rod.global_position.distance_to(dock.global_position) <= 16.0

## Talking doesn't end fishing. The game counts a pony in conversation (her conversation_target,
## or the director's engaged()) as interrupted, so every AI reply sent her rod back to the rack.
## For a pony already fishing with a rod, those two checks are skipped; everything else stands.
## New invites still wait for a pony who isn't talking (eligible() passes no lease).
func _interrupted(actor: Node3D, allow_follow := false) -> bool:
	if not is_instance_valid(actor) or not actor.has_meta("fishing_companion"):
		return super(actor, allow_follow)
	var nav: Node = actor.get_node_or_null("Navigator")
	if not is_instance_valid(nav): return true
	if actor.get("sleeping") == true or actor.get("_held") == true or actor.get("motion_paused") == true: return true
	if actor.has_method("action_interruption_reason") and not str(actor.action_interruption_reason()).is_empty(): return true
	if actor.has_meta("seating"): return true
	if actor.get_meta("active_follow", false) and not allow_follow: return true
	if is_instance_valid(nav.get("_follow_target")) and not allow_follow: return true
	var flight: Variant = actor.get("flight")
	if is_instance_valid(flight) and flight.active(): return true
	var group: Variant = actor.get_meta("social_group", {})
	if group is Dictionary and group.get("members", []).size() > 1: return true
	return actor.has_meta("balloon_passenger")

## While she talks the Navigator turns her to face whoever she's talking to, and she only casts
## facing the water. Once the chat is over, turn her back to the water.
func _step(lease: Dictionary, delta: float) -> void:
	super(lease, delta)
	if str(lease.get("phase")) != "fishing" or not is_instance_valid(lease.get("actor")): return
	var actor: Node3D = lease.actor
	if is_instance_valid(actor.get("conversation_target")): return
	if (-actor.global_basis.z.normalized()).dot(dock.water_direction()) < 0.9 and is_instance_valid(lease.get("nav")):
		lease.nav.face_point = actor.global_position + dock.water_direction() * 6.0
