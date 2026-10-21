"""Builds the low-poly ceiling turret and exports it as a glTF binary.

Run from the repository root (Blender 5.2):
    blender --background --python art-source/models/turret.py -- [--preview <png path>]
Writes game/content/base/enemies/turret/turret.glb, and renders a preview PNG when asked.

The turret faces -Y (Blender's front view), Z is up, and 1 unit is 1 metre. Its origin is where it hangs from the
ceiling, so everything is below Z = 0. It is three objects, which Godot imports as three nodes:
    Mount  the plate bolted to the ceiling and the neck under it (materials Metal and Armor)
    Ring   the ring that turns (yaw) round the vertical axis through the origin, with the yoke that holds the head,
           and a band round the ring that glows like the eye (materials Metal, Armor and Eye)
    Head   the housing that tilts (pitch) round the X axis at HEAD_PIVOT, with the sensor eye above the emitter
           barrel, vents down both sides and a strip across the back that glows like the eye (materials Armor,
           Metal, Eye, Emitter and Vents)
The bands use the Eye material, so the robot's state colour shows from every side, not only from in front.
The turret scene turns Ring and Head round pivots at RING_PIVOT and HEAD_PIVOT; keep them in step with it.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUTPUT = Path(__file__).resolve().parents[2] / "game" / "content" / "base" / "enemies" / "turret" / "turret.glb"
# Heights of the ring's and the head's pivots (the turret scene's Ring and Head nodes).
RING_PIVOT = -0.12
HEAD_PIVOT = -0.30
BEVEL = 0.004


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


def add_box(bm: bmesh.types.BMesh, size: tuple, center: tuple, material_index: int = 0) -> None:
    transform = Matrix.Translation(center) @ Matrix.Diagonal((*size, 1.0))
    assign(bmesh.ops.create_cube(bm, size=1.0, matrix=transform)["verts"], material_index)


def add_cylinder(bm: bmesh.types.BMesh, radius: float, depth: float, center: tuple, axis: str = "Z",
                 material_index: int = 0, segments: int = 12, radius2: float | None = None) -> None:
    """A cylinder (or a cone with radius2) along Z, or along Y or X."""
    rotation = {"Z": Matrix.Identity(4), "Y": Matrix.Rotation(math.radians(90.0), 4, "X"),
                "X": Matrix.Rotation(math.radians(90.0), 4, "Y")}[axis]
    transform = Matrix.Translation(center) @ rotation
    verts = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius,
                                  radius2=radius if radius2 is None else radius2, depth=depth,
                                  matrix=transform)["verts"]
    assign(verts, material_index)


def make_object(name: str, materials: list, build, bevel: bool = True) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(mesh)
    bm.free()
    for mat in materials:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if bevel:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = BEVEL
        modifier.segments = 1
        modifier.limit_method = "ANGLE"
    return obj


def build_mount(bm: bmesh.types.BMesh) -> None:
    metal, armor = 0, 1
    add_box(bm, (0.38, 0.38, 0.035), (0.0, 0.0, -0.0175), armor)
    for x in (-0.15, 0.15):
        for y in (-0.15, 0.15):
            add_cylinder(bm, 0.014, 0.012, (x, y, -0.04), material_index=metal, segments=6)
    add_cylinder(bm, 0.07, 0.09, (0.0, 0.0, -0.08), material_index=metal)


def build_ring(bm: bmesh.types.BMesh) -> None:
    metal, armor, eye = 0, 1, 2
    add_cylinder(bm, 0.15, 0.06, (0.0, 0.0, RING_PIVOT - 0.03), material_index=armor, segments=16)
    add_cylinder(bm, 0.154, 0.014, (0.0, 0.0, RING_PIVOT - 0.03), material_index=eye, segments=16)
    add_cylinder(bm, 0.12, 0.03, (0.0, 0.0, RING_PIVOT - 0.075), material_index=metal, segments=16)
    # The yoke: an arm down each side to the head's pivot, and the pivot bosses.
    for x in (-0.145, 0.145):
        add_box(bm, (0.03, 0.08, 0.22), (x, 0.0, (RING_PIVOT + HEAD_PIVOT) / 2.0 - 0.02), armor)
        add_cylinder(bm, 0.04, 0.035, (x, 0.0, HEAD_PIVOT), axis="X", material_index=metal, segments=10)


def build_head(bm: bmesh.types.BMesh) -> None:
    armor, metal, eye, emitter, vents = 0, 1, 2, 3, 4
    centre = (0.0, -0.02, HEAD_PIVOT)
    # The housing, a little longer towards the front, with a raised brow over the eye.
    add_box(bm, (0.23, 0.32, 0.17), centre, armor)
    add_box(bm, (0.2, 0.06, 0.03), (0.0, -0.15, HEAD_PIVOT + 0.075), armor)
    # The sensor eye in its bezel, above the emitter barrel.
    add_cylinder(bm, 0.055, 0.03, (0.0, -0.19, HEAD_PIVOT + 0.03), axis="Y", material_index=metal, segments=14)
    add_cylinder(bm, 0.042, 0.012, (0.0, -0.208, HEAD_PIVOT + 0.03), axis="Y", material_index=eye, segments=14)
    add_cylinder(bm, 0.026, 0.13, (0.0, -0.235, HEAD_PIVOT - 0.045), axis="Y", material_index=metal, segments=10)
    add_cylinder(bm, 0.018, 0.006, (0.0, -0.302, HEAD_PIVOT - 0.045), axis="Y", material_index=emitter, segments=10)
    # Vent slats down both sides, and cooling fins at the back.
    for x in (-0.118, 0.118):
        for i in range(4):
            add_box(bm, (0.008, 0.045, 0.018), (x, 0.06 - i * 0.055, HEAD_PIVOT - 0.02), vents)
    for z in (-0.05, -0.02, 0.01, 0.04):
        add_box(bm, (0.18, 0.025, 0.012), (0.0, 0.15, HEAD_PIVOT + z), metal)
    add_box(bm, (0.2, 0.012, 0.014), (0.0, 0.142, HEAD_PIVOT + 0.07), eye)


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
    target = Vector((0.0, -0.02, -0.2))
    camera.location = target + Vector((0.75, -1.1, -0.35))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.ops.render.render(write_still=True)
    print(f"🤖 Rendered preview: path={path}")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    metal = material("Metal", (0.16, 0.18, 0.21), 0.85, 0.38)
    armor = material("Armor", (0.3, 0.32, 0.3), 0.3, 0.6)
    eye = material("Eye", (0.05, 0.05, 0.06), 0.0, 0.2, emission=(0.85, 0.92, 1.0), strength=3.0)
    emitter = material("Emitter", (0.1, 0.05, 0.05), 0.0, 0.3, emission=(1.0, 0.15, 0.1), strength=1.5)
    vents = material("Vents", (0.08, 0.08, 0.09), 0.6, 0.5, emission=(1.0, 0.35, 0.08), strength=0.0)

    make_object("Mount", [metal, armor], build_mount)
    make_object("Ring", [metal, armor, eye], build_ring)
    make_object("Head", [armor, metal, eye, emitter, vents], build_head)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_apply=True, export_yup=True)
    print(f"🤖 Exported turret: path={OUTPUT}, objects={len(bpy.data.objects)}")
    if preview:
        render_preview(preview)


if __name__ == "__main__":
    main()
