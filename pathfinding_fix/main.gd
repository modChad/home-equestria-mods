extends Node
## Pathfinding Fix (modChad), entry script.
## - Swaps every new zone WalkGridService onto walk_grid_service_fix.gd before it is ready
##   (route choice: roads, detours). Zones already loaded keep the game's script until reloaded.
## - Keeps each pony's avoidance agent (NavigationAgent3D) at her current size: the game sets
##   its radius/height once at spawn, so size presets, fillies and stallions kept canon values.
## - Princess clearance: princess_hybrid.gd sets an unscaled 1.95 m (Celestia) / 1.45 m in _ready,
##   overwriting any size scaling done before it, and every standard house assumes a 2.0 m doorway
##   with 0.1 m to spare, so Celestia never fitted. Clearance is kept at CELESTIA_CLEARANCE /
##   LUNA_CLEARANCE times her body scale.
## - House ceilings (house_ceilings.gd): each town house's roof, attic and porch roofs stop counting
##   as walkable floor, so the walk grid sees the room and the stoop under them.

const BASE_SERVICE := "res://world/navigation/walk_grid_service.gd"
const FIX_SERVICE := preload("res://mods/pathfinding_fix/walk_grid_service_fix.gd")
const PRINCESS := "res://world/characters/princesses/princess_hybrid.gd"
const CEILINGS := preload("res://mods/pathfinding_fix/house_ceilings.gd")
const CELESTIA_CLEARANCE := 1.85
const LUNA_CLEARANCE := 1.45
## Seconds between agent/clearance checks.
const CHECK_SECONDS := 0.5
## Vars bake() sets before the service enters the tree; set_script would reset them.
const SERVICE_KEEP := ["_content", "preset_geometry", "zone_id"]
var _wait := 0.0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# Houses already standing when the mod starts.
	for interior: Node in get_tree().get_nodes_in_group("house_interiors"):
		if CEILINGS.is_town_house(interior) and interior.is_node_ready(): _on_house_ready(interior)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for box: AABB in CEILINGS.undo_all(get_tree()): _notify_geometry(box)


func _on_node_added(node: Node) -> void:
	if node.get_script() != null and CEILINGS.is_town_house(node) and not node.is_node_ready():
		# After its _ready: the house edits its own shell collision there.
		node.ready.connect(_on_house_ready.bind(node), CONNECT_ONE_SHOT)
		return
	var script := node.get_script() as Script
	if script == null or script == FIX_SERVICE or script.resource_path != BASE_SERVICE: return
	if node.is_node_ready(): return
	var keep := {}
	for property: String in SERVICE_KEEP: keep[property] = node.get(property)
	node.set_script(FIX_SERVICE)
	for property: String in keep: node.set(property, keep[property])
	print("[pathfinding_fix] route fixes on %s" % str(keep.get("zone_id", node.name)))


func _on_house_ready(interior: Node) -> void:
	if not is_instance_valid(interior) or not interior.is_inside_tree(): return
	var box: AABB = CEILINGS.apply(interior as Node3D)
	if box.size != Vector3.ZERO: _notify_geometry(box)


## Resample walk-grid chunks over `box` that a zone already sampled. Chunks not sampled yet need
## nothing (they will see the split shell), and notify_geometry_changed() would keep them out of
## the disk cache for the session.
func _notify_geometry(box: AABB) -> void:
	box = box.grow(1.0)
	for service: Node in get_tree().get_nodes_in_group("pony_navigation"):
		if not (service is WalkGridService) or not service.is_node_ready(): continue
		var grid: WalkGrid = service.grid
		var a := WalkGrid.chunk_of(WalkGrid.column(box.position))
		var b := WalkGrid.chunk_of(WalkGrid.column(box.end))
		var sampled := false
		for z in range(a.y, b.y + 1):
			for x in range(a.x, b.x + 1):
				if grid.chunks.has(Vector2i(x, z)): sampled = true
		if sampled: service.notify_geometry_changed(box)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0: return
	_wait = CHECK_SECONDS
	for nav: Node in get_tree().get_nodes_in_group("pony_navigators"):
		var agent := nav.get("agent") as NavigationAgent3D
		var pony := nav.get("pony") as Node
		if agent == null or not is_instance_valid(pony): continue
		var profile: Resource = pony.get("profile")
		if profile == null: continue
		_fix_princess(pony, profile)
		var radius: float = float(profile.radius)
		var height: float = float(profile.clearance)
		if not is_equal_approx(agent.radius, radius): agent.radius = radius
		if not is_equal_approx(agent.height, height): agent.height = height


func _fix_princess(pony: Node, profile: Resource) -> void:
	if not Mods.matches(pony, PRINCESS): return
	var identity: Object = pony.get("identity")
	if identity == null or not identity.has_method("character"): return
	var scale_value: Variant = pony.get("body_scale")
	var body: float = float(scale_value) if scale_value != null else 1.0
	var base: float = CELESTIA_CLEARANCE if str(identity.character()) == "celestia" else LUNA_CLEARANCE
	var wanted: float = base * body
	if absf(float(profile.clearance) - wanted) > 0.005: profile.clearance = wanted
