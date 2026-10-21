"""Builds the low-poly loot items and exports each as a glTF binary.

Run from the repository root (Blender 5.2):
    blender --background --python art-source/models/items.py -- [--only <name>] [--preview <png path>]
Writes game/content/base/items/<name>/<name>.glb for every item (or only the one named), and renders a preview PNG
of all of them in a row when asked.

Each item is built to its grid shape (see SHAPES, which must match the shapes in the items' .tres files): a cell is
CELL metres, rows run towards -Y (Blender's front, which Godot imports as +Z, where the grid's rows go down), Z is up
and 1 unit is 1 metre. The origin is the middle of the shape's footprint on the floor, so seen from straight above
the model covers its cells; the game renders the item's grid icon that way. Every item is one object, named after
the item.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ITEMS = Path(__file__).resolve().parents[2] / "game" / "content" / "base" / "items"
CELL = 0.15
BEVEL = 0.002
# The cells of each item, as rows: "#" is a cell. Keep these in step with the items' definitions.
SHAPES = {
    "data_drive": ["#"],
    "circuit_board": ["##"],
    "conduit": ["###"],
    "servo_motor": ["#.", "##"],
    "gyroscope": ["##", "##"],
    "hull_plating": [".##", "##."],
    "plasma_coil": ["###", ".#."],
    "power_cell": ["#.", "#.", "##"],
    "thermal_clip": ["#"],
    "spent_thermal_clip": ["#"],
}


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
        "Metal": material("Metal", (0.16, 0.18, 0.21), 0.85, 0.38),
        "Armor": material("Armor", (0.22, 0.25, 0.3), 0.3, 0.55),
        "Polymer": material("Polymer", (0.06, 0.065, 0.07), 0.0, 0.75),
        "Label": material("Label", (0.55, 0.58, 0.62), 0.0, 0.6),
        "Paint": material("Paint", (0.3, 0.35, 0.42), 0.2, 0.7),
        "Hazard": material("Hazard", (0.78, 0.6, 0.08), 0.1, 0.6),
        "Board": material("Board", (0.05, 0.24, 0.13), 0.0, 0.55),
        "Gold": material("Gold", (0.85, 0.62, 0.22), 1.0, 0.3),
        "Copper": material("Copper", (0.75, 0.38, 0.18), 1.0, 0.35),
        "Scorched": material("Scorched", (0.07, 0.065, 0.06), 0.6, 0.7),
        "Led": material("Led", (0.05, 0.08, 0.1), 0.0, 0.3, emission=(0.3, 0.9, 1.0), strength=3.0),
        "Charge": material("Charge", (0.05, 0.1, 0.06), 0.0, 0.3, emission=(0.35, 1.0, 0.5), strength=2.5),
        "Plasma": material("Plasma", (0.1, 0.08, 0.15), 0.0, 0.2, emission=(0.62, 0.55, 1.0), strength=4.0),
        "ClipHeat": material("ClipHeat", (0.1, 0.1, 0.1), 0.0, 0.4, emission=(0.35, 0.65, 1.0), strength=2.0),
        "ClipSpent": material("ClipSpent", (0.12, 0.07, 0.05), 0.0, 0.5, emission=(1.0, 0.3, 0.06), strength=0.5),
    }


class Builder:
    """Adds parts to one mesh, each with a material by name."""

    def __init__(self, shape: list) -> None:
        self.bm = bmesh.new()
        self.names: list[str] = []
        self.width = max(len(row) for row in shape)
        self.height = len(shape)

    def index(self, name: str) -> int:
        if name not in self.names:
            self.names.append(name)
        return self.names.index(name)

    def cell(self, column: int, row: int) -> tuple:
        """The centre of a grid cell on the floor, in Blender's axes."""
        return ((column + 0.5) * CELL - self.width * CELL / 2.0, -((row + 0.5) * CELL - self.height * CELL / 2.0))

    def assign(self, verts: list, name: str) -> None:
        index = self.index(name)
        for face in {face for vert in verts for face in vert.link_faces}:
            face.material_index = index

    def box(self, size: tuple, center: tuple, name: str, rotation: float = 0.0) -> None:
        transform = (Matrix.Translation(center) @ Matrix.Rotation(rotation, 4, "Z")
                     @ Matrix.Diagonal((*size, 1.0)))
        self.assign(bmesh.ops.create_cube(self.bm, size=1.0, matrix=transform)["verts"], name)

    def cylinder(self, radius: float, depth: float, center: tuple, name: str, axis: str = "Z",
                 segments: int = 12, radius2: float | None = None) -> None:
        """A cylinder (or a cone with radius2) along Z, Y or X."""
        rotation = {"Z": Matrix.Identity(4), "Y": Matrix.Rotation(math.radians(90.0), 4, "X"),
                    "X": Matrix.Rotation(math.radians(90.0), 4, "Y")}[axis]
        transform = Matrix.Translation(center) @ rotation
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=segments, radius1=radius,
                                      radius2=radius if radius2 is None else radius2, depth=depth,
                                      matrix=transform)["verts"]
        self.assign(verts, name)

    def torus(self, major: float, minor: float, center: tuple, name: str, axis: str = "Z",
              segments: int = 20, sides: int = 6) -> None:
        """A ring round the axis."""
        rotation = {"Z": Matrix.Identity(4), "Y": Matrix.Rotation(math.radians(90.0), 4, "X"),
                    "X": Matrix.Rotation(math.radians(90.0), 4, "Y")}[axis]
        transform = Matrix.Translation(center) @ rotation
        rings = []
        for i in range(segments):
            around = 2.0 * math.pi * i / segments
            ring = []
            for j in range(sides):
                tube = 2.0 * math.pi * j / sides
                radius = major + minor * math.cos(tube)
                point = Vector((radius * math.cos(around), radius * math.sin(around), minor * math.sin(tube)))
                ring.append(self.bm.verts.new(transform @ point))
            rings.append(ring)
        verts = []
        for i in range(segments):
            for j in range(sides):
                a, b = rings[i][j], rings[(i + 1) % segments][j]
                c, d = rings[(i + 1) % segments][(j + 1) % sides], rings[i][(j + 1) % sides]
                self.bm.faces.new((a, b, c, d))
                verts.append(a)
        self.assign(verts, name)


def build_data_drive(b: Builder) -> None:
    b.box((0.12, 0.12, 0.028), (0.0, 0.0, 0.014), "Armor")
    b.box((0.075, 0.06, 0.003), (-0.012, 0.012, 0.0295), "Label")
    b.box((0.012, 0.09, 0.004), (0.043, 0.0, 0.0295), "Led")
    b.box((0.06, 0.016, 0.012), (0.0, -0.066, 0.01), "Gold")
    for x in (-0.05, 0.05):
        for y in (-0.05, 0.05):
            b.cylinder(0.006, 0.004, (x, y, 0.029), "Metal", segments=6)


def build_circuit_board(b: Builder) -> None:
    b.box((0.28, 0.125, 0.012), (0.0, 0.0, 0.006), "Board")
    b.box((0.21, 0.014, 0.013), (0.0, -0.054, 0.0065), "Gold")
    b.box((0.055, 0.055, 0.008), (-0.075, 0.012, 0.016), "Polymer")
    b.box((0.035, 0.025, 0.006), (0.0, 0.032, 0.015), "Polymer")
    b.box((0.035, 0.025, 0.006), (0.0, -0.018, 0.015), "Polymer")
    b.box((0.06, 0.035, 0.007), (0.085, 0.015, 0.0155), "Polymer")
    for x, y in ((-0.125, 0.045), (-0.125, -0.02), (0.045, 0.045), (0.125, -0.035)):
        b.cylinder(0.008, 0.016, (x, y, 0.02), "Metal", segments=8)
    b.box((0.008, 0.008, 0.004), (0.125, 0.05, 0.014), "Charge")
    # Traces between the chips.
    for y in (-0.005, 0.005):
        b.box((0.1, 0.003, 0.001), (-0.01, y, 0.0125), "Gold")


def build_conduit(b: Builder) -> None:
    b.cylinder(0.03, 0.42, (0.0, 0.0, 0.042), "Metal", axis="X", segments=12)
    for x in (-0.2, 0.2):
        b.cylinder(0.042, 0.02, (x, 0.0, 0.042), "Armor", axis="X", segments=12)
    b.box((0.04, 0.09, 0.012), (0.0, 0.0, 0.006), "Armor")
    b.cylinder(0.036, 0.04, (0.0, 0.0, 0.042), "Armor", axis="X", segments=12)
    b.cylinder(0.0315, 0.035, (-0.1, 0.0, 0.042), "Hazard", axis="X", segments=12)
    b.cylinder(0.0315, 0.035, (0.1, 0.0, 0.042), "Hazard", axis="X", segments=12)


def build_servo_motor(b: Builder) -> None:
    top_x, top_y = b.cell(0, 0)
    foot_x, foot_y = b.cell(1, 1)
    # The motor lies along the long arm of the L, its gearbox across the foot.
    b.cylinder(0.055, 0.22, (top_x, top_y - 0.04, 0.058), "Armor", axis="Y", segments=14)
    b.cylinder(0.05, 0.02, (top_x, top_y + 0.06, 0.058), "Metal", axis="Y", segments=14)
    for offset in (-0.02, 0.01, 0.04):
        b.cylinder(0.06, 0.008, (top_x, top_y + offset, 0.058), "Metal", axis="Y", segments=14)
    b.box((0.27, 0.12, 0.085), (0.0, foot_y, 0.0425), "Metal")
    b.box((0.12, 0.1, 0.004), (top_x, foot_y, 0.087), "Label")
    b.cylinder(0.038, 0.016, (foot_x + 0.055, foot_y, 0.045), "Copper", axis="X", segments=16)
    b.cylinder(0.014, 0.03, (foot_x + 0.06, foot_y, 0.045), "Metal", axis="X", segments=8)
    b.box((0.03, 0.03, 0.006), (foot_x - 0.02, foot_y + 0.02, 0.088), "Led")


def build_gyroscope(b: Builder) -> None:
    b.box((0.27, 0.27, 0.03), (0.0, 0.0, 0.015), "Armor")
    for x in (-0.11, 0.11):
        for y in (-0.11, 0.11):
            b.cylinder(0.009, 0.006, (x, y, 0.032), "Metal", segments=6)
    b.torus(0.075, 0.005, (0.0, 0.0, 0.031), "Led", segments=24, sides=4)
    for x in (-0.118, 0.118):
        b.box((0.02, 0.03, 0.12), (x, 0.0, 0.09), "Metal")
    b.torus(0.105, 0.011, (0.0, 0.0, 0.12), "Metal", axis="X", segments=24)
    b.torus(0.085, 0.01, (0.0, 0.0, 0.12), "Armor", axis="Y", segments=24)
    b.torus(0.105, 0.009, (0.0, 0.0, 0.12), "Copper", segments=24)
    b.cylinder(0.045, 0.03, (0.0, 0.0, 0.12), "Copper", segments=16)
    b.cylinder(0.012, 0.13, (0.0, 0.0, 0.12), "Metal", segments=8)


def build_hull_plating(b: Builder) -> None:
    for column, row in ((1, 0), (2, 0), (0, 1), (1, 1)):
        x, y = b.cell(column, row)
        b.box((0.149, 0.149, 0.024), (x, y, 0.012), "Paint")
        for dx in (-0.055, 0.055):
            for dy in (-0.055, 0.055):
                b.cylinder(0.006, 0.004, (x + dx, y + dy, 0.025), "Metal", segments=6)
    # Hazard stripes painted across the plates.
    for column, row in ((1, 0), (2, 0)):
        x, y = b.cell(column, row)
        b.box((0.149, 0.028, 0.002), (x, y + 0.035, 0.025), "Hazard")
    for column, row in ((0, 1), (1, 1)):
        x, y = b.cell(column, row)
        b.box((0.149, 0.028, 0.002), (x, y - 0.035, 0.025), "Hazard")
    b.box((0.05, 0.03, 0.003), b.cell(2, 0) + (0.026,), "Scorched", rotation=0.5)


def build_plasma_coil(b: Builder) -> None:
    left_x, bar_y = b.cell(0, 0)
    _, stem_y = b.cell(1, 1)
    b.cylinder(0.027, 0.42, (0.0, bar_y, 0.05), "Plasma", axis="X", segments=12)
    for x in (-0.17, -0.12, -0.07, 0.07, 0.12, 0.17):
        b.cylinder(0.042, 0.03, (x, bar_y, 0.05), "Copper", axis="X", segments=14)
    for x in (-0.205, 0.205):
        b.cylinder(0.046, 0.016, (x, bar_y, 0.05), "Metal", axis="X", segments=14)
    b.box((0.08, 0.1, 0.1), (0.0, bar_y, 0.05), "Armor")
    b.box((0.07, 0.15, 0.05), (0.0, stem_y + 0.03, 0.025), "Armor")
    b.box((0.11, 0.03, 0.065), (0.0, stem_y - 0.055, 0.0325), "Metal")
    for x in (-0.03, 0.03):
        b.cylinder(0.01, 0.015, (x, stem_y - 0.055, 0.072), "Gold", segments=8)
    b.box((0.05, 0.04, 0.004), (0.0, bar_y, 0.101), "Led")


def build_power_cell(b: Builder) -> None:
    x, top_y = b.cell(0, 0)
    _, mid_y = b.cell(0, 1)
    foot_x, foot_y = b.cell(1, 2)
    body_length = 0.43
    body_y = mid_y - 0.005
    b.box((0.125, body_length, 0.1), (x, body_y, 0.05), "Armor")
    b.box((0.13, 0.02, 0.105), (x, body_y + body_length / 2.0 - 0.01, 0.0525), "Metal")
    b.box((0.13, 0.02, 0.105), (x, body_y - body_length / 2.0 + 0.01, 0.0525), "Metal")
    b.box((0.032, 0.28, 0.004), (x, top_y - 0.08, 0.101), "Charge")
    b.box((0.126, 0.03, 0.101), (x, top_y + 0.02, 0.0505), "Hazard")
    b.box((0.15, 0.12, 0.07), (foot_x - 0.02, foot_y, 0.035), "Metal")
    for dy in (-0.03, 0.03):
        b.cylinder(0.013, 0.025, (foot_x, foot_y + dy, 0.08), "Copper", segments=10)


def build_clip(b: Builder, band: str, shell: str) -> None:
    b.box((0.07, 0.12, 0.04), (0.0, 0.005, 0.02), shell)
    b.box((0.072, 0.026, 0.042), (0.0, 0.015, 0.021), band)
    b.box((0.076, 0.012, 0.046), (0.0, -0.058, 0.023), "Metal")
    b.box((0.03, 0.04, 0.003), (0.0, -0.025, 0.0405), "Label")


BUILDERS = {
    "data_drive": build_data_drive,
    "circuit_board": build_circuit_board,
    "conduit": build_conduit,
    "servo_motor": build_servo_motor,
    "gyroscope": build_gyroscope,
    "hull_plating": build_hull_plating,
    "plasma_coil": build_plasma_coil,
    "power_cell": build_power_cell,
    "thermal_clip": lambda b: build_clip(b, "ClipHeat", "Metal"),
    "spent_thermal_clip": lambda b: build_clip(b, "ClipSpent", "Scorched"),
}


def build_item(name: str, mats: dict) -> bpy.types.Object:
    builder = Builder(SHAPES[name])
    BUILDERS[name](builder)
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


def export_item(obj: bpy.types.Object, name: str) -> None:
    path = ITEMS / name / f"{name}.glb"
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_apply=True, export_yup=True,
                              use_selection=True)
    print(f"🎒 Exported item: name={name}, path={path}, cells={sum(row.count('#') for row in SHAPES[name])}")


def render_preview(path: Path, objects: list) -> None:
    """Every item in a row, seen from above at an angle, a metre apart."""
    for i, obj in enumerate(objects):
        obj.location.x = i * 0.6
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 500
    scene.render.filepath = str(path)
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 0.6 * len(objects) + 0.3
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    target = Vector((0.6 * (len(objects) - 1) / 2.0, 0.0, 0.0))
    camera.location = target + Vector((0.0, -2.0, 2.4))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.ops.render.render(write_still=True)
    print(f"🎒 Rendered preview: path={path}, items={len(objects)}")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    only = args[args.index("--only") + 1] if "--only" in args else None
    names = [only] if only else list(SHAPES)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = materials()
    objects = []
    for name in names:
        obj = build_item(name, mats)
        export_item(obj, name)
        objects.append(obj)
    print(f"🎒 Exported items: count={len(objects)}")
    if preview:
        render_preview(preview, objects)


if __name__ == "__main__":
    main()
