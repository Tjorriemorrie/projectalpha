"""Builds the low-poly security drone and exports it as a glTF binary.

Run from the repository root (Blender 5.2):
    blender --background --python art-source/models/drone.py -- [--preview <png path>]
Writes game/content/base/enemies/drone/drone.glb, and renders a preview PNG when asked.

The drone faces -Y (Blender's front view), Z is up, and 1 unit is 1 metre. Its origin is the centre of its body,
where it hovers. It is one object, which Godot imports as one node:
    Body  an armoured, octagonal hull with a sensor eye above the emitter at the front, a band round the hull that
          glows like the eye (so its state colour shows from every side), four ducted thrusters at the corners, and
          vents on top (materials Armor, Metal, Eye, Emitter, Vents and Thrusters)
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUTPUT = Path(__file__).resolve().parents[2] / "game" / "content" / "base" / "enemies" / "drone" / "drone.glb"
BEVEL = 0.004
# How far out the thrusters sit along the diagonals, and their duct size.
THRUSTER_REACH = 0.25
THRUSTER_RADIUS = 0.07


def material(name: str, color: tuple, metallic: float, roughness: float, emission: tuple | None = None,
             strength: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
        mat.diffuse_color = (*emission, 1.0)
    return mat


def assign(verts: list, material_index: int) -> None:
    for face in {face for vert in verts for face in vert.link_faces}:
        face.material_index = material_index


def add_box(bm: bmesh.types.BMesh, size: tuple, center: tuple, material_index: int = 0,
            rotation: float = 0.0) -> None:
    transform = (Matrix.Translation(center) @ Matrix.Rotation(rotation, 4, "Z")
                 @ Matrix.Diagonal((*size, 1.0)))
    assign(bmesh.ops.create_cube(bm, size=1.0, matrix=transform)["verts"], material_index)


def add_cylinder(bm: bmesh.types.BMesh, radius: float, depth: float, center: tuple, axis: str = "Z",
                 material_index: int = 0, segments: int = 12, radius2: float | None = None) -> None:
    """A cylinder (or a cone with radius2) along Z, or along Y."""
    rotation = Matrix.Identity(4) if axis == "Z" else Matrix.Rotation(math.radians(90.0), 4, "X")
    transform = Matrix.Translation(center) @ rotation
    verts = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius,
                                  radius2=radius if radius2 is None else radius2, depth=depth,
                                  matrix=transform)["verts"]
    assign(verts, material_index)


def build_body(bm: bmesh.types.BMesh) -> None:
    armor, metal, eye, emitter, vents, thrusters = 0, 1, 2, 3, 4, 5
    # The hull: an octagonal disc, tapering to a smaller belly underneath, and a cap on top.
    add_cylinder(bm, 0.2, 0.12, (0.0, 0.0, 0.02), material_index=armor, segments=8)
    add_cylinder(bm, 0.2, 0.1, (0.0, 0.0, -0.09), material_index=armor, segments=8, radius2=0.12)
    add_cylinder(bm, 0.15, 0.05, (0.0, 0.0, 0.1), material_index=metal, segments=8, radius2=0.11)
    add_cylinder(bm, 0.204, 0.018, (0.0, 0.0, 0.06), material_index=eye, segments=8)
    # The sensor eye in its bezel at the front, and the emitter below it.
    add_cylinder(bm, 0.075, 0.05, (0.0, -0.195, 0.015), axis="Y", material_index=metal, segments=14)
    add_cylinder(bm, 0.058, 0.012, (0.0, -0.222, 0.015), axis="Y", material_index=eye, segments=14)
    add_cylinder(bm, 0.022, 0.1, (0.0, -0.2, -0.075), axis="Y", material_index=metal, segments=8)
    add_cylinder(bm, 0.015, 0.006, (0.0, -0.252, -0.075), axis="Y", material_index=emitter, segments=8)
    # Vent slats across the top cap.
    for x in (-0.06, -0.02, 0.02, 0.06):
        add_box(bm, (0.018, 0.16, 0.012), (x, 0.03, 0.13), vents)
    # Four ducted thrusters on struts at the diagonals, glowing faintly underneath.
    for i in range(4):
        angle = math.radians(45.0 + 90.0 * i)
        x, y = math.cos(angle) * THRUSTER_REACH, math.sin(angle) * THRUSTER_REACH
        add_box(bm, (0.13, 0.03, 0.025), (x * 0.6, y * 0.6, 0.0), metal, rotation=angle)
        add_cylinder(bm, THRUSTER_RADIUS, 0.06, (x, y, 0.0), material_index=armor, segments=12)
        add_cylinder(bm, THRUSTER_RADIUS * 0.7, 0.01, (x, y, -0.031), material_index=thrusters, segments=12)


def render_preview(path: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.render.filepath = str(path)
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.lens = 60.0
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    target = Vector((0.0, 0.0, 0.0))
    camera.location = target + Vector((0.8, -1.2, 0.55))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.ops.render.render(write_still=True)
    print(f"🤖 Rendered preview: path={path}")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armor = material("Armor", (0.22, 0.25, 0.3), 0.3, 0.55)
    metal = material("Metal", (0.16, 0.18, 0.21), 0.85, 0.38)
    eye = material("Eye", (0.05, 0.05, 0.06), 0.0, 0.2, emission=(0.85, 0.92, 1.0), strength=3.0)
    emitter = material("Emitter", (0.1, 0.05, 0.05), 0.0, 0.3, emission=(1.0, 0.15, 0.1), strength=1.5)
    vents = material("Vents", (0.08, 0.08, 0.09), 0.6, 0.5, emission=(1.0, 0.35, 0.08), strength=0.0)
    thrusters = material("Thrusters", (0.05, 0.06, 0.08), 0.0, 0.3, emission=(0.4, 0.65, 1.0), strength=1.2)

    body = bpy.data.meshes.new("Body")
    bm = bmesh.new()
    build_body(bm)
    bm.to_mesh(body)
    bm.free()
    for mat in (armor, metal, eye, emitter, vents, thrusters):
        body.materials.append(mat)
    obj = bpy.data.objects.new("Body", body)
    bpy.context.collection.objects.link(obj)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = BEVEL
    modifier.segments = 1
    modifier.limit_method = "ANGLE"

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_apply=True, export_yup=True)
    print(f"🤖 Exported drone: path={OUTPUT}, objects={len(bpy.data.objects)}")
    if preview:
        render_preview(preview)


if __name__ == "__main__":
    main()
