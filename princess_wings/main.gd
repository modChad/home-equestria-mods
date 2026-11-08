extends Node
## Princess Wings: moves Celestia's and Luna's open wings onto their shoulder blades.
##
## The princesses wear fitted bodies (world/characters/princesses/princess_hybrid.gd) with their
## own open-wing meshes (<id>_wings.glb), bound to the body's skeleton by
## world/characters/hybrid_mare/hybrid_open_wings.gd. The open wings' roots sit well behind the
## shoulder and perch on top of the back: Celestia's 12 cm behind the top of her foreleg and
## 2.7 cm above her back line. On the ordinary mare (Rainbow Dash) the root sits above the top of
## the foreleg, 3.5 cm into the back.
##
## Rule used for both princesses (measured in tools/_wing_lab/measure.gd, renders in
## renders/wing_fit/): the root goes just behind the top of the foreleg, sunk into the back by
## 8.4% of the barrel's height (Rainbow Dash's ratio), 67% of the way from the spine to the side.
##
## Only the open-wing meshes move: each one gets its own copy of its skin with the bind poses
## offset, so the vertices shift in the skeleton's rest space and every bone pose (flight, tuck,
## half open, preen) still drives them the same way. The body, the folded wings and the skeleton
## are untouched, and the offset scales with the pony's size setting.

## Offset of each open wing in skeleton space, metres. x is outward from the spine (mirrored for
## the left wing), y up, z toward the tail (-z is forward).
const SHIFT := {
	"celestia": Vector3(0.0, -0.05, -0.10),
	"luna": Vector3(0.011, -0.018, -0.048),
}
const PRINCESS_DIR := "res://world/characters/princesses/"
const META := &"princess_wings_original_skin"

var _fitted: Array[MeshInstance3D] = []


func _ready() -> void:
	Mods.on_node(_is_princess_wing, _fit)


## Cheap tests first: this runs for every node that enters the tree.
func _is_princess_wing(node: Node) -> bool:
	if not node is MeshInstance3D or not String(node.name).begins_with("wing open"): return false
	return SHIFT.has(_princess_of(node))


## "celestia" or "luna" for an open-wing mesh worn on a princess's own skeleton, else "".
## While binding, the game briefly adds the source <id>_wings.glb under the pony too; its meshes
## share the name but sit on their own skeleton, and the game copies their skin into the worn
## meshes, so they must be left alone.
func _princess_of(node: Node) -> String:
	var at := node.get_parent()
	for _i in 8:
		if at == null: return ""
		if at.has_meta("open_wing_scene"):
			if not str(at.get_meta("open_wing_scene")).begins_with(PRINCESS_DIR): return ""
			if node.get_parent() != at.get("skeleton"): return ""
			var identity: Variant = at.get("identity")
			if identity == null or not (identity as Object).has_method("character"): return ""
			return str(identity.call("character"))
		at = at.get_parent()
	return ""


func _fit(node: Node) -> void:
	var mi := node as MeshInstance3D
	if mi == null or mi.has_meta(META) or mi.skin == null: return
	var shift: Vector3 = SHIFT[_princess_of(mi)]
	# Luna's meshes are "wing open_L_001"; Celestia's "wing open_L".
	if String(mi.name).contains("_L"): shift.x = -shift.x
	var original: Skin = mi.skin
	var skin: Skin = original.duplicate()
	for i in skin.get_bind_count():
		skin.set_bind_pose(i, skin.get_bind_pose(i) * Transform3D(Basis(), shift))
	mi.set_meta(META, original)
	mi.skin = skin
	_fitted.append(mi)


## Switched off mid-game: the wings go back to the game's own placement.
func _exit_tree() -> void:
	for mi in _fitted:
		if is_instance_valid(mi) and mi.has_meta(META):
			mi.skin = mi.get_meta(META)
			mi.remove_meta(META)
	_fitted.clear()
