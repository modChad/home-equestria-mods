# Lighter Hair 1.0.1 lab (modChad). Blender, background:
#   blender -b --factory-startup --python mods/hair_lite/tools/_hat_lab/render_hat.py -- <project root>
# Renders Applejack's hat before (left) / after (right), shaded and wireframe, two angles.
import bpy, sys, os, math
from mathutils import Vector
root = sys.argv[sys.argv.index("--") + 1]
d = os.path.join(root, "renders", "hair_lite")
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
objs = []
for i, tag in enumerate(["before", "after"]):
    bpy.ops.import_scene.gltf(filepath=os.path.join(d, f"hat_{tag}.glb"))
    ms = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    for o in ms: o.matrix_world = o.matrix_world  # keep
    objs.append(ms)
# centre each hat and space them side by side
def bounds(ms):
    pts = [o.matrix_world @ Vector(c) for o in ms for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi
lo, hi = bounds(objs[0]); size = max(hi - lo); c0 = (lo + hi) / 2
for i, ms in enumerate(objs):
    lo, hi = bounds(ms); c = (lo + hi) / 2
    for o in ms:
        o.location += Vector(((i - 0.5) * size * 1.3, 0, 0)) - c
cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = size * 2.8
cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = 1600, 800
sc.render.image_settings.file_format = "JPEG"
views = {"front34": (math.radians(70), 0, math.radians(30)), "brim_low": (math.radians(95), 0, math.radians(-20))}
def shoot(name):
    for v, rot in views.items():
        cam.rotation_euler = rot
        cam.location = cam.rotation_euler.to_matrix() @ Vector((0, 0, size * 5))
        sc.render.filepath = os.path.join(d, f"hat_{name}_{v}.jpg")
        bpy.ops.render.render(write_still=True)
shoot("shaded")
for ms in objs:
    for o in ms:
        w = o.modifiers.new("wire", "WIREFRAME"); w.thickness = size * 0.002; w.use_replace = True
sc.display.shading.color_type = "SINGLE"
shoot("wire")
print("RENDERS IN", d)
