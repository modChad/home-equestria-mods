extends "res://world/ai/director_group.gd"
## Better Balloon: talking in the balloon is a group conversation. The game's choice of who joins
## in (director_group.gd _group_candidates) skips any pony with an action_interruption_reason(),
## and every balloon passenger has one ("Riding a hot-air balloon"), so only the pony Anon looked at
## ever answered. Here, a passenger isn't skipped for riding, and ponies in the basket with him
## count as part of his conversation (as companions out with him do). Everything else is the
## game's own rule, unchanged. main.gd swaps this in for the conversation director's own helper
## (copying its state), and back when the mod is switched off.

const RIDING := "Riding a hot-air balloon"


func _group_candidates(first: String) -> Array[String]:
	var ids: Array[String] = []
	if not bool(host.config.get_value("group_conversations/enabled", true)) or first == "": return ids
	var riders := _riders_with_anon()
	var candidates: Array = []
	for id in host.characters:
		var node: Variant = host.characters[id].node
		if not is_instance_valid(node) or not node.is_inside_tree() or not node.is_visible_in_tree(): continue
		if node.has_method("is_held") and node.is_held(): continue
		if node.has_method("action_interruption_reason"):
			var why := str(node.action_interruption_reason())
			if why != "" and not (why == RIDING and id in riders): continue
		var distance: float = host.awareness.point(node).distance_to(host.awareness.point(host.player_head))
		if distance <= GROUP.RANGE: candidates.append({"id": id, "distance": distance})
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	var offered: Array = candidates.slice(0, 12)
	if not offered.any(func(item): return item.id == first): return ids
	var companions: Array = host.social.companions(first) if is_instance_valid(host.social) else []
	if not bool(host._address.get("everyone", false)):
		var addressed: Array = host._address.get("addressed", [])
		offered = offered.filter(func(item: Dictionary) -> bool: return item.id == first or item.id in addressed or item.id in companions or item.id in riders or _in_chat(item.id) or _mentioned(item.id))
	offered.sort_custom(func(a, b):
		var rank_a := 0 if a.id == first else (1 if _mentioned(a.id) else (2 if a.id in companions or a.id in riders else 3))
		var rank_b := 0 if b.id == first else (1 if _mentioned(b.id) else (2 if b.id in companions or b.id in riders else 3))
		return rank_a < rank_b if rank_a != rank_b else a.distance < b.distance)
	for candidate in offered:
		var node: Node3D = host.characters[candidate.id].node
		if not host.awareness.can_hear(node, host.player_head, GROUP.RANGE): continue
		var compatible := true
		for id in ids:
			if not host.awareness.can_hear(node, host.characters[id].node, GROUP.RANGE): compatible = false; break
		if compatible: ids.append(candidate.id)
		if ids.size() == GROUP.MAX_MEMBERS: break
	return ids if not ids.is_empty() and ids[0] == first else []


## Ids of the ponies riding in the balloon Anon is aboard (empty when he isn't in one).
func _riders_with_anon() -> Array:
	var out: Array = []
	var tree := (host as Node).get_tree() if is_instance_valid(host) else null
	if tree == null: return out
	for balloon: Node in tree.get_nodes_in_group("hot_air_balloons"):
		if not balloon.has_method("holds_player") or not "passengers" in balloon: continue
		var player: Variant = balloon.get("_player")
		if not is_instance_valid(player) or not bool(balloon.call("holds_player", player)): continue
		for row: Variant in balloon.get("passengers"):
			if row is Dictionary and (row as Dictionary).has("id"): out.append(str(row.id))
	return out
