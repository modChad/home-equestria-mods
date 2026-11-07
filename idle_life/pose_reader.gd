extends SkeletonModifier3D
## Reads her skeleton's bone poses as drawn: kept as her skeleton's last child, it copies every
## bone's global pose during the modification pass, after the game's own modifiers (the
## princesses' flowing manes sway by one) have moved them. Outside that pass the skeleton only
## gives the poses before those modifiers. fringe.gd reads these to find and follow the
## princesses' mane swoop.

var poses: Array[Transform3D] = []


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null: return
	var count := sk.get_bone_count()
	if poses.size() != count: poses.resize(count)
	for i in count: poses[i] = sk.get_bone_global_pose(i)
