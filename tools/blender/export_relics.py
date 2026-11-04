"""Exports every relic shape from assets/relics/relics.blend as assets/relics/<shape>.fbx.

Run inside Blender (Scripting tab or the Blender MCP) with relics.blend open. Each collection
Relic_<shape> in the scene "Relics" is moved to the origin, exported on its own and moved back.
"""
import os

import bpy

OUT_DIR = os.path.join(os.path.dirname(bpy.data.filepath) or r"E:\RELIC-RUSH\assets\relics")
scene = bpy.data.scenes["Relics"]
bpy.context.window.scene = scene

for coll in scene.collection.children:
    if not coll.name.startswith("Relic_"):
        continue
    shape = coll.name[len("Relic_"):]
    objs = [o for o in coll.objects if o.type == "MESH"]
    offset = objs[0].location.copy()
    for o in objs:
        o.location -= offset
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, shape + ".fbx"),
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        bake_space_transform=True,
    )
    for o in objs:
        o.location += offset
    print("exported", shape)
