extends RefCounted
## The mod pack stores original GLBs without editor import sidecars.
static func instantiate(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_buffer(FileAccess.get_file_as_bytes(path), "", state) != OK:
		push_error("Cannot load kiss model " + path)
		return null
	return doc.generate_scene(state) as Node3D
