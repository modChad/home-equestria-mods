extends Node
## Shader warm-up, from devanon's Flowing Manes warm-up patch 1.0.0 (folded in at 1.0.1; main.gd
## adds this node as its child).
## Flowing Manes makes its hair shaders (wave_shader.gd: flowing copies of the game's cel and outline
## shaders, and Luna's glow) when Celestia or Luna first appears. They are seldom in the world while
## it loads, so the loading screen's pipeline warm-up (world/game_loading.gd _warm_up_pipelines,
## every material on a MeshInstance3D in the scene) never saw them and the first sight of a princess
## compiled them mid-game: a stutter. Here, as each world starts loading, the same shaders are made
## through the mod's own cache (the very Shader objects the princesses' hair will use) and set on a
## few hidden quads under the world, so the warm-up draws them behind the cover. The quads go once
## the cover does; the shaders stay in the mod's cache.

const SHUTDOWN := preload("res://world/shutdown_waits.gd")
const WAVES := "res://mods/flowing_manes/wave_shader.gd"
## The hair's own shaders (world/characters/locomotion/pony_dressing.gd: the cel pass, cutout when
## alpha-scissored, and the outline hull, lit or tinted by shading version).
const BASES := ["res://addons/cel-shader/cel-shader-base.gdshader", "res://addons/cel-shader/cel-shader-cutout.gdshader"]
const OUTLINES := ["res://addons/cel-shader/cel-outline-lit.gdshader", "res://addons/cel-shader/outline-tinted.gdshader"]

## Shader names warmed for the current world, and the shaders themselves (tests read both).
var warmed: Array[String] = []
var shaders: Array = []
var _holder: Node3D


func _ready() -> void:
	Mods.world_ready.connect(_on_world)
	if is_instance_valid(Mods.game) and Mods.game.get_node_or_null("LoadingCover") != null: _on_world(Mods.game)


func _on_world(game: Node) -> void:
	if not Mods.is_active("flowing_manes") or is_instance_valid(_holder) or game.get_node_or_null("LoadingCover") == null: return
	var waves: Script = load(WAVES) if ResourceLoader.exists(WAVES) else null
	if waves == null or not _has(waves, "flowing"): return
	var bases: Array = []
	var passes: Array = []
	warmed.clear()
	for path: String in BASES:
		var made: Variant = waves.call("flowing", load(path), "base") if ResourceLoader.exists(path) else null
		if made is Shader: bases.append(made); warmed.append(path.get_file() + " base")
	for path: String in OUTLINES:
		var made: Variant = waves.call("flowing", load(path), "outline") if ResourceLoader.exists(path) else null
		if made is Shader: passes.append(made); warmed.append(path.get_file() + " outline")
	var glow: Variant = waves.call("glow") if _has(waves, "glow") else null
	if glow is Shader: passes.append(glow); warmed.append("glow")
	if bases.is_empty(): return
	shaders = bases + passes
	_holder = Node3D.new()
	_holder.name = "FlowingManesWarmup"
	_holder.visible = false
	for i in maxi(bases.size(), passes.size()):
		var material := ShaderMaterial.new()
		material.shader = bases[i % bases.size()]
		if not passes.is_empty():
			var next := ShaderMaterial.new()
			next.shader = passes[i % passes.size()]
			material.next_pass = next
		var quad := QuadMesh.new()
		quad.size = Vector2(0.01, 0.01)
		var mesh := MeshInstance3D.new()
		mesh.mesh = quad
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_holder.add_child(mesh)
	game.add_child(_holder)
	_release(game)


## A static function of the mod's script (has_method does not see a script's static functions).
static func _has(script: Script, name: String) -> bool:
	return script.get_script_method_list().any(func(method: Dictionary) -> bool: return str(method.get("name", "")) == name)


## The quads go once the loading cover has.
func _release(game: Node) -> void:
	while is_instance_valid(game) and game.get_node_or_null("LoadingCover") != null:
		if not await SHUTDOWN.seconds(self, 0.5): return
	if is_instance_valid(_holder): _holder.queue_free()
	_holder = null


func _exit_tree() -> void:
	if is_instance_valid(_holder): _holder.queue_free()
	_holder = null
