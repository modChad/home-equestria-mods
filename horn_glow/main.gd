extends Node
## Horn Glow (modChad) entry. Gives each unicorn's horn magic (unicorn_magic.gd) a HornGlow child
## (glow.gd), and makes the magic auras of the horn itself silent as they enter the tree, before
## their _ready plays the cast sound: the horn's own aura, its excited flares (MagicBurst under the
## horn magic) and Idle Life's sparks leaving the horn (IdleLifeSpark). Their round discs are hidden
## once made; the sparkles stay. Lifted things and door bursts keep the game's aura.
const MAGIC := "res://world/characters/magic/unicorn_magic.gd"
const AURA := "res://world/characters/magic/magic_aura.gd"
const GLOW := preload("res://mods/horn_glow/glow.gd")


func _ready() -> void:
	get_tree().node_added.connect(_on_added)
	Mods.on_node(MAGIC, _on_magic)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_added): get_tree().node_added.disconnect(_on_added)
	for node in get_tree().get_nodes_in_group("horn_glow"): node.queue_free()


func _on_magic(magic: Node) -> void:
	if magic.get_node_or_null("HornGlow") != null: return
	var glow: Node = GLOW.new()
	glow.name = "HornGlow"
	glow.set("magic", magic)
	glow.add_to_group("horn_glow")
	magic.add_child(glow)


func _on_added(node: Node) -> void:
	var script: Script = node.get_script()
	if script == null or script.resource_path != AURA: return
	var target: Variant = node.get("target")
	if not target is Node or not is_instance_valid(target): return
	var holder := target as Node
	var horn := holder.name == "HornMagicAnchor" or holder.name.begins_with("IdleLifeSpark")
	if not horn and holder.name.begins_with("MagicBurst") and holder.get_parent() != null:
		var parent_script: Script = holder.get_parent().get_script()
		horn = parent_script != null and parent_script.resource_path == MAGIC
	if not horn: return
	node.set("silent", true)
	node.ready.connect(func() -> void:
		var disc: Variant = node.get("_disc")
		if disc is Node3D: (disc as Node3D).visible = false, CONNECT_ONE_SHOT)
