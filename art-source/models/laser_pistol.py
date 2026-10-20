"""Builds the low-poly laser pistol and exports it as a glTF binary.

Run from the repository root (Blender 5.2):
    blender --background --python art-source/models/laser_pistol.py -- [--preview <png path>]
Writes game/content/base/weapons/laser_pistol/laser_pistol.glb, and renders a preview PNG when asked.

The pistol faces -Y (Blender's front view), Z is up, and 1 unit is 1 metre. Its origin is the rear sight, with the
sight line running along -Y at Z = 0, so the viewmodel can line the sights up with the centre of the screen. It is
three objects, which Godot imports as three nodes:
    Body     the slide, frame, grip, sights and trigger (materials Metal and Polymer)
    Emitter  the lens at the muzzle and the strips along the slide, which glow (material Emitter)
    Clip     the thermal clip in the grip, with its own origin and axes along the grip so it can slide out
             (materials Metal and ClipHeat, the band that glows from cool to hot)
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUTPUT = (Path(__file__).resolve().parents[2] / "game" / "content" / "base" / "weapons" / "laser_pistol"
          / "laser_pistol.glb")
# The grip leans back this many degrees, like a real pistol's.
GRIP_TILT = math.radians(15.0)
GRIP_TOP = Vector((0.0, -0.012, -0.06))
GRIP_LENGTH = 0.1
BEVEL = 0.0012


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


def add_box(bm: bmesh.types.BMesh, size: tuple, center: tuple, material_index: int = 0,
            tilt: float = 0.0) -> None:
    """A box of size (x, y, z) centred on center, leaning back by tilt radians around X."""
    transform = (Matrix.Translation(center) @ Matrix.Rotation(tilt, 4, "X")
                 @ Matrix.Diagonal((*size, 1.0)))
    verts = bmesh.ops.create_cube(bm, size=1.0, matrix=transform)["verts"]
    for face in {face for vert in verts for face in vert.link_faces}:
        face.material_index = material_index


def add_cylinder_y(bm: bmesh.types.BMesh, radius: float, depth: float, center: tuple, material_index: int = 0,
                   segments: int = 12) -> None:
    """A cylinder lying along Y (the barrel's axis)."""
    transform = Matrix.Translation(center) @ Matrix.Rotation(math.radians(90.0), 4, "X")
    verts = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius,
                                  depth=depth, matrix=transform)["verts"]
    for face in {face for vert in verts for face in vert.link_faces}:
        face.material_index = material_index


def make_object(name: str, materials: list, build, location=(0.0, 0.0, 0.0), tilt: float = 0.0,
                bevel: bool = True) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(mesh)
    bm.free()
    for mat in materials:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    obj.rotation_euler = (tilt, 0.0, 0.0)
    bpy.context.collection.objects.link(obj)
    if bevel:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = BEVEL
        modifier.segments = 1
        modifier.limit_method = "ANGLE"
    return obj


def build_body(bm: bmesh.types.BMesh) -> None:
    metal, polymer = 0, 1
    # The slide, from the muzzle end (y = -0.18) back past the rear sight, with heat-sink fins on top.
    add_box(bm, (0.03, 0.192, 0.036), (0.0, -0.084, -0.024), metal)
    for y in (-0.135, -0.115, -0.095, -0.075, -0.055):
        add_box(bm, (0.024, 0.005, 0.003), (0.0, y, -0.0045), metal)
    # Sights: a front post whose top is on the sight line, and a rear notch at the origin.
    add_box(bm, (0.003, 0.005, 0.006), (0.0, -0.165, -0.003), metal)
    add_box(bm, (0.02, 0.008, 0.004), (0.0, 0.0, -0.004), metal)
    for x in (-0.006, 0.006):
        add_box(bm, (0.006, 0.006, 0.007), (x, 0.0, -0.0005), metal)
    # The shroud round the emitter, in front of the slide.
    add_cylinder_y(bm, 0.013, 0.022, (0.0, -0.191, -0.026), metal)
    # The frame under the slide, the trigger guard and trigger, and the beavertail over the hand.
    add_box(bm, (0.026, 0.135, 0.02), (0.0, -0.0825, -0.052), polymer)
    add_box(bm, (0.008, 0.05, 0.005), (0.0, -0.045, -0.085), metal)
    add_box(bm, (0.008, 0.005, 0.025), (0.0, -0.07, -0.0745), metal)
    add_box(bm, (0.005, 0.006, 0.016), (0.0, -0.045, -0.07), metal, tilt=math.radians(-10.0))
    add_box(bm, (0.024, 0.012, 0.008), (0.0, 0.012, -0.058), metal)
    # The grip, leaning back; the clip slides into its bottom.
    grip_down = Matrix.Rotation(GRIP_TILT, 3, "X") @ Vector((0.0, 0.0, -1.0))
    add_box(bm, (0.028, 0.036, GRIP_LENGTH), tuple(GRIP_TOP + grip_down * GRIP_LENGTH / 2.0), polymer, GRIP_TILT)


def build_emitter(bm: bmesh.types.BMesh) -> None:
    add_cylinder_y(bm, 0.009, 0.003, (0.0, -0.2035, -0.026))
    for x in (-0.0155, 0.0155):
        add_box(bm, (0.0015, 0.09, 0.003), (x, -0.09, -0.03))


def build_clip(bm: bmesh.types.BMesh) -> None:
    """In the clip's own axes: it lies along Z, and its bottom plate sticks out of the grip."""
    metal, heat = 0, 1
    add_box(bm, (0.024, 0.03, 0.06), (0.0, 0.0, 0.0), metal)
    add_box(bm, (0.0255, 0.0315, 0.008), (0.0, 0.0, -0.018), heat)
    add_box(bm, (0.026, 0.034, 0.005), (0.0, 0.0, -0.031), metal)


def render_preview(path: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 600
    scene.render.filepath = str(path)
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.lens = 85.0
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    target = Vector((0.0, -0.09, -0.07))
    camera.location = target + Vector((0.55, -0.25, 0.22))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.ops.render.render(write_still=True)
    print(f"🔫 Rendered preview: path={path}")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = Path(args[args.index("--preview") + 1]) if "--preview" in args else None

    bpy.ops.wm.read_factory_settings(use_empty=True)
    metal = material("Metal", (0.16, 0.18, 0.21), 0.85, 0.38)
    polymer = material("Polymer", (0.06, 0.065, 0.07), 0.0, 0.75)
    emitter = material("Emitter", (0.1, 0.12, 0.14), 0.0, 0.3, emission=(0.6, 0.85, 1.0), strength=3.0)
    clip_heat = material("ClipHeat", (0.1, 0.1, 0.1), 0.0, 0.4, emission=(0.35, 0.65, 1.0), strength=2.0)

    make_object("Body", [metal, polymer], build_body)
    make_object("Emitter", [emitter], build_emitter, bevel=False)
    grip_down = Matrix.Rotation(GRIP_TILT, 3, "X") @ Vector((0.0, 0.0, -1.0))
    # Deep enough that the heat band shows below the grip.
    clip_centre = GRIP_TOP + grip_down * 0.09
    make_object("Clip", [metal, clip_heat], build_clip, location=tuple(clip_centre), tilt=GRIP_TILT)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_apply=True, export_yup=True)
    print(f"🔫 Exported laser pistol: path={OUTPUT}, objects={len(bpy.data.objects)}")
    if preview:
        render_preview(preview)


if __name__ == "__main__":
    main()
