"""Builds the low-poly props of the player's ship and exports each as a glTF binary.

Run from the repository root (Blender 5.2):
    blender --background --python art-source/models/ship_props.py -- [--only <name>] [--preview <png path>]
Writes game/assets/models/ship/<name>.glb for every prop (or only the one named), and renders a preview PNG of all of
them in a row when asked.

A prop faces -Y (Blender's front view), Z is up, and 1 unit is 1 metre. Each is one object named after the prop.
Props that stand against a wall have their origin in the middle of their back on the floor (Y = 0 is the back, so
they span negative Y); the clone pod and the pilot seat stand free and have theirs in the middle of their foot.
    clone_pod      a tall open-fronted pod on a low plinth (step onto it), glowing strips inside and a lit ring
                   under its cap; the player stands in it, 1.05 m of opening and 0.5 m to its back wall
    stash_cabinet  a wide double-doored storage cabinet with a green status lamp, 1.6 x 0.6 x 2.0 m
    pilot_seat     a seat on a pedestal with armrests and a headrest
    console        a desk console with a sloped control panel and an upright screen (material Screen), 1.4 m wide,
                   0.55 m deep; the screen's face is 0.9 x 0.5 m, centred 1.15 m up and 0.07 m in front of the back
    bunk           a bed against the wall along its long side, 2.0 x 0.9 m, with a shelf and a reading lamp
The ship's scenes size their collision to these measurements; keep them in step.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

SHIP = Path(__file__).resolve().parents[2] / "game" / "assets" / "models" / "ship"
BEVEL = 0.008
POD_RADIUS = 0.58
POD_HEIGHT = 2.25
POD_PLINTH = 0.12
# The pod's shell covers the back, from this many degrees either side of straight behind.
POD_ARC = 115.0
STASH = (1.6, 0.6, 2.0)
CONSOLE = (1.4, 0.55, 0.8)
SCREEN = (0.9, 0.5)
SCREEN_HEIGHT = 1.15
BUNK = (2.0, 0.9)


def material(name: str, color: tuple, metallic: float, roughness: float, emission: tuple | None = None,
             strength: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
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


def materials() -> dict:
    return {
        "Shell": material("Shell", (0.42, 0.44, 0.46), 0.5, 0.45),
        "Trim": material("Trim", (0.15, 0.16, 0.18), 0.85, 0.4),
        "Fabric": material("Fabric", (0.12, 0.14, 0.17), 0.0, 0.95),
        "Blanket": material("Blanket", (0.42, 0.22, 0.12), 0.0, 0.9),
        "Pillow": material("Pillow", (0.62, 0.6, 0.56), 0.0, 0.9),
        "Glow": material("Glow", (0.05, 0.12, 0.12), 0.0, 0.3, emission=(0.45, 0.95, 0.9), strength=1.2),
        "Screen": material("Screen", (0.01, 0.02, 0.03), 0.0, 0.2, emission=(0.012, 0.03, 0.06), strength=1.0),
        "Lamp": material("Lamp", (0.1, 0.06, 0.02), 0.0, 0.3, emission=(1.0, 0.62, 0.3), strength=3.0),
        "Status": material("Status", (0.02, 0.08, 0.03), 0.0, 0.3, emission=(0.25, 1.0, 0.4), strength=3.0),
        "Hazard": material("Hazard", (0.78, 0.6, 0.08), 0.1, 0.6),
    }


class Builder:
    """Adds parts to one mesh, each with a material by name."""

    def __init__(self) -> None:
        self.bm = bmesh.new()
        self.names: list[str] = []

    def assign(self, verts: list, name: str) -> None:
        if name not in self.names:
            self.names.append(name)
        index = self.names.index(name)
        for face in {face for vert in verts for face in vert.link_faces}:
            face.material_index = index

    def box(self, size: tuple, center: tuple, name: str, turn_z: float = 0.0, tilt_x: float = 0.0) -> None:
        """A box turned turn_z degrees about Z and tilted tilt_x degrees about X, around its centre."""
        transform = (Matrix.Translation(center) @ Matrix.Rotation(math.radians(turn_z), 4, "Z")
                     @ Matrix.Rotation(math.radians(tilt_x), 4, "X") @ Matrix.Diagonal((*size, 1.0)))
        self.assign(bmesh.ops.create_cube(self.bm, size=1.0, matrix=transform)["verts"], name)

    def cylinder(self, radius: float, depth: float, center: tuple, name: str, segments: int = 16) -> None:
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius,
                                      depth=depth, matrix=Matrix.Translation(center))["verts"]
        self.assign(verts, name)

    def arc(self, radius: float, thickness: float, bottom: float, height: float, from_deg: float, to_deg: float,
            segments: int, name: str) -> None:
        """A curved wall standing on a circle about the Z axis, from from_deg to to_deg (0 is +X, 90 is +Y)."""
        step = (to_deg - from_deg) / segments
        length = 2.0 * radius * math.sin(math.radians(step) / 2.0) + 0.02
        for i in range(segments):
            angle = math.radians(from_deg + step * (i + 0.5))
            center = (math.cos(angle) * radius, math.sin(angle) * radius, bottom + height / 2.0)
            self.box((length, thickness, height), center, name, turn_z=math.degrees(angle) - 90.0)


def make_object(name: str, builder: Builder, mats: dict) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    builder.bm.to_mesh(mesh)
    builder.bm.free()
    for mat_name in builder.names:
        mesh.materials.append(mats[mat_name])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = BEVEL
    modifier.segments = 1
    modifier.limit_method = "ANGLE"
    return obj


def build_clone_pod(mats: dict) -> bpy.types.Object:
    pod = Builder()
    pod.cylinder(POD_RADIUS + 0.06, POD_PLINTH, (0.0, 0.0, POD_PLINTH / 2.0), "Trim", segments=20)
    pod.cylinder(POD_RADIUS - 0.08, 0.01, (0.0, 0.0, POD_PLINTH + 0.005), "Fabric", segments=20)
    wall_height = POD_HEIGHT - POD_PLINTH - 0.15
    pod.arc(POD_RADIUS, 0.06, POD_PLINTH, wall_height, 90.0 - POD_ARC, 90.0 + POD_ARC, 14, "Shell")
    # Ribs on the outside of the shell, and glowing strips down the inside either side of the back.
    for angle in (90.0 - POD_ARC, 90.0 - 50.0, 90.0, 90.0 + 50.0, 90.0 + POD_ARC):
        a = math.radians(angle)
        pod.box((0.07, 0.07, wall_height), (math.cos(a) * (POD_RADIUS + 0.04), math.sin(a) * (POD_RADIUS + 0.04),
                POD_PLINTH + wall_height / 2.0), "Trim", turn_z=angle - 90.0)
    for angle in (90.0 - 35.0, 90.0 + 35.0):
        a = math.radians(angle)
        pod.box((0.04, 0.02, wall_height - 0.3), (math.cos(a) * (POD_RADIUS - 0.04), math.sin(a) * (POD_RADIUS - 0.04),
                POD_PLINTH + wall_height / 2.0), "Glow", turn_z=angle - 90.0)
    cap_bottom = POD_HEIGHT - 0.15
    pod.cylinder(POD_RADIUS + 0.08, 0.15, (0.0, 0.0, cap_bottom + 0.075), "Trim", segments=20)
    pod.cylinder(POD_RADIUS - 0.12, 0.02, (0.0, 0.0, cap_bottom - 0.01), "Glow", segments=20)
    # Hoses from the cap down the back, and a hazard band round the plinth's front edge.
    for x in (-0.18, 0.18):
        pod.box((0.06, 0.06, wall_height), (x, POD_RADIUS + 0.1, POD_PLINTH + wall_height / 2.0), "Trim")
    pod.box((0.7, 0.02, 0.05), (0.0, -POD_RADIUS - 0.06, POD_PLINTH / 2.0), "Hazard")
    return make_object("clone_pod", pod, mats)


def build_stash_cabinet(mats: dict) -> bpy.types.Object:
    width, depth, height = STASH
    cabinet = Builder()
    cabinet.box((width, depth, height), (0.0, -depth / 2.0, height / 2.0), "Shell")
    cabinet.box((width + 0.02, depth + 0.02, 0.08), (0.0, -depth / 2.0, 0.04), "Trim")
    cabinet.box((width + 0.02, depth + 0.02, 0.05), (0.0, -depth / 2.0, height - 0.025), "Trim")
    door_width = width / 2.0 - 0.03
    for side in (-1.0, 1.0):
        x = side * (door_width / 2.0 + 0.015)
        cabinet.box((door_width, 0.02, height - 0.2), (x, -depth - 0.01, height / 2.0), "Shell")
        for i in range(5):
            cabinet.box((door_width * 0.7, 0.008, 0.016), (x, -depth - 0.024, height - 0.3 - i * 0.04), "Trim")
        cabinet.box((0.025, 0.04, 0.3), (side * 0.06, -depth - 0.035, 1.05), "Trim")
    cabinet.box((0.03, 0.03, height - 0.2), (0.0, -depth - 0.012, height / 2.0), "Trim")
    cabinet.box((0.5, 0.008, 0.1), (0.0, -depth - 0.024, 1.45), "Hazard")
    cabinet.box((0.05, 0.02, 0.05), (width / 2.0 - 0.1, -depth - 0.022, height - 0.12), "Status")
    return make_object("stash_cabinet", cabinet, mats)


def build_pilot_seat(mats: dict) -> bpy.types.Object:
    seat = Builder()
    seat.cylinder(0.3, 0.04, (0.0, 0.0, 0.02), "Trim")
    seat.cylinder(0.06, 0.4, (0.0, 0.0, 0.24), "Trim", segments=10)
    seat.box((0.56, 0.56, 0.1), (0.0, 0.0, 0.48), "Fabric")
    seat.box((0.6, 0.6, 0.04), (0.0, 0.0, 0.42), "Shell")
    seat.box((0.56, 0.1, 0.7), (0.0, 0.3, 0.88), "Fabric", tilt_x=-8.0)
    seat.box((0.6, 0.06, 0.74), (0.0, 0.36, 0.86), "Shell", tilt_x=-8.0)
    seat.box((0.32, 0.1, 0.2), (0.0, 0.38, 1.33), "Fabric", tilt_x=-8.0)
    for x in (-0.31, 0.31):
        seat.box((0.07, 0.42, 0.05), (x, 0.0, 0.7), "Shell")
        seat.box((0.04, 0.04, 0.2), (x, 0.15, 0.58), "Trim")
    return make_object("pilot_seat", seat, mats)


def build_console(mats: dict) -> bpy.types.Object:
    width, depth, height = CONSOLE
    console = Builder()
    console.box((width, depth, height), (0.0, -depth / 2.0, height / 2.0), "Shell")
    console.box((width + 0.02, depth + 0.02, 0.06), (0.0, -depth / 2.0, 0.03), "Trim")
    # The control panel sloping down towards the pilot, with rows of lit keys.
    console.box((width, 0.42, 0.05), (0.0, -depth + 0.18, height + 0.06), "Trim", tilt_x=-22.0)
    for row in range(3):
        for col in range(9):
            lit = "Lamp" if (row * 9 + col) % 4 == 0 else "Trim"
            console.box((0.07, 0.05, 0.02), (-0.5 + col * 0.125, -depth + 0.08 + row * 0.1, height + 0.03 + row * 0.04),
                        lit, tilt_x=-22.0)
    # The upright screen at the back, in a frame.
    screen_w, screen_h = SCREEN
    console.box((screen_w + 0.08, 0.06, screen_h + 0.08), (0.0, -0.03, SCREEN_HEIGHT), "Trim")
    console.box((screen_w, 0.01, screen_h), (0.0, -0.065, SCREEN_HEIGHT), "Screen")
    console.box((0.12, 0.05, SCREEN_HEIGHT - height - screen_h / 2.0 + 0.05),
                (0.0, -0.03, height + (SCREEN_HEIGHT - screen_h / 2.0 - height) / 2.0), "Trim")
    return make_object("console", console, mats)


def build_bunk(mats: dict) -> bpy.types.Object:
    width, depth = BUNK
    bunk = Builder()
    bunk.box((width, depth, 0.3), (0.0, -depth / 2.0, 0.2), "Shell")
    for x in (-width / 2.0 + 0.06, width / 2.0 - 0.06):
        for y in (-0.06, -depth + 0.06):
            bunk.box((0.06, 0.06, 0.06), (x, y, 0.03), "Trim")
    bunk.box((width - 0.06, depth - 0.08, 0.16), (0.0, -depth / 2.0, 0.43), "Fabric")
    bunk.box((1.25, depth - 0.04, 0.04), (0.3, -depth / 2.0, 0.52), "Blanket")
    bunk.box((0.45, 0.6, 0.1), (-width / 2.0 + 0.3, -depth / 2.0, 0.56), "Pillow")
    bunk.box((width, 0.04, 0.9), (0.0, -0.02, 0.45), "Trim")
    for x in (-width / 2.0, width / 2.0):
        bunk.box((0.05, depth, 0.15), (x + (0.025 if x < 0 else -0.025), -depth / 2.0, 0.6), "Trim")
    bunk.box((width, 0.24, 0.04), (0.0, -0.12, 1.4), "Shell")
    for x in (-0.8, 0.8):
        bunk.box((0.03, 0.2, 0.12), (x, -0.1, 1.33), "Trim")
    bunk.box((0.16, 0.12, 0.08), (-0.7, -0.14, 1.46), "Trim")
    bunk.box((0.1, 0.02, 0.05), (-0.7, -0.205, 1.46), "Lamp")
    return make_object("bunk", bunk, mats)


BUILDERS = {
    "clone_pod": build_clone_pod,
    "stash_cabinet": build_stash_cabinet,
    "pilot_seat": build_pilot_seat,
    "console": build_console,
    "bunk": build_bunk,
}


def export_prop(name: str, obj: bpy.types.Object) -> None:
    path = SHIP / f"{name}.glb"
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_apply=True, export_yup=True,
                              use_selection=True)
    print(f"🚀 Exported ship prop: name={name}, path={path}")


def render_preview(path: Path, objects: list) -> None:
    """The props in a row, seen from the front at an angle."""
    x = -3.6
    for obj in objects:
        obj.location.x = x
        x += 1.9
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 800
    scene.render.filepath = str(path)
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.lens = 30.0
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    target = Vector((0.0, -0.3, 0.9))
    camera.location = target + Vector((1.5, -7.5, 2.4))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.ops.render.render(write_still=True)
    print(f"🚀 Rendered preview: path={path}, props={len(objects)}")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    only = args[args.index("--only") + 1] if "--only" in args else None
    names = [only] if only else list(BUILDERS)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = materials()
    objects = []
    for name in names:
        obj = BUILDERS[name](mats)
        export_prop(name, obj)
        objects.append(obj)
    print(f"🚀 Exported ship props: count={len(objects)}")
    if preview:
        render_preview(preview, objects)


if __name__ == "__main__":
    main()
