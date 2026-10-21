"""Builds the low-poly loot containers and exports each as a glTF binary.

Run from the repository root (Blender 5.2):
    blender --background --python art-source/models/containers.py -- [--only <name>] [--preview <png path>]
Writes game/content/base/containers/<name>/<name>.glb for every container (or only the one named), and renders a
preview PNG of all of them, lids open, when asked.

A container faces -Y (Blender's front view), Z is up, and 1 unit is 1 metre. Its origin is the middle of its back
on the floor (Y = 0 is the back, so it spans negative Y), so it stands flush against the wall its marker is on. Each
is two objects, which Godot imports as two nodes:
    Body  the hollow shell, open where the lid closes it, with its trim, stencils and a status lamp (materials
          Shell, Trim, Interior, Hazard and Lamp)
    Lid   the lid (the locker's door), with its origin on the hinge, so the container scene swings it open by turning
          the node: the crate's and the case's lids hinge along the back of the top, the locker's door down its left
          side
The container scenes' collision boxes and open angles match the sizes here; keep them in step.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

CONTAINERS = Path(__file__).resolve().parents[2] / "game" / "content" / "base" / "containers"
BEVEL = 0.006
# Outer sizes (width, depth, height) and shell thickness.
CRATE = (1.0, 0.6, 1.0)
CRATE_LID = 0.08
LOCKER = (0.8, 0.5, 1.9)
CASE = (0.5, 0.32, 0.16)
CASE_LID = 0.06
WALL = 0.03


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

    def box(self, size: tuple, center: tuple, name: str) -> None:
        transform = Matrix.Translation(center) @ Matrix.Diagonal((*size, 1.0))
        self.assign(bmesh.ops.create_cube(self.bm, size=1.0, matrix=transform)["verts"], name)

    def cylinder(self, radius: float, depth: float, center: tuple, name: str, axis: str = "Z",
                 segments: int = 10) -> None:
        rotation = {"Z": Matrix.Identity(4), "Y": Matrix.Rotation(math.radians(90.0), 4, "X"),
                    "X": Matrix.Rotation(math.radians(90.0), 4, "Y")}[axis]
        transform = Matrix.Translation(center) @ rotation
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius,
                                      depth=depth, matrix=transform)["verts"]
        self.assign(verts, name)

    def shell(self, width: float, depth: float, height: float, open_side: str, name: str, inside: str) -> None:
        """A hollow box from y = -depth to 0, open on its top or its front; the inside faces get their own
        material by a thin lining."""
        half = width / 2.0
        walls = {
            "bottom": ((width, depth, WALL), (0.0, -depth / 2.0, WALL / 2.0)),
            "top": ((width, depth, WALL), (0.0, -depth / 2.0, height - WALL / 2.0)),
            "back": ((width, WALL, height), (0.0, -WALL / 2.0, height / 2.0)),
            "front": ((width, WALL, height), (0.0, -depth + WALL / 2.0, height / 2.0)),
            "left": ((WALL, depth, height), (-half + WALL / 2.0, -depth / 2.0, height / 2.0)),
            "right": ((WALL, depth, height), (half - WALL / 2.0, -depth / 2.0, height / 2.0)),
        }
        del walls[open_side]
        for size, center in walls.values():
            self.box(size, center, name)
        # A dark lining, so the inside reads as a cavity when the lid opens.
        lining = 0.004
        self.box((width - 2.0 * WALL, depth - 2.0 * WALL, lining),
                 (0.0, -depth / 2.0, WALL + lining / 2.0), inside)
        self.box((width - 2.0 * WALL, lining, height - 2.0 * WALL),
                 (0.0, -WALL - lining / 2.0, height / 2.0), inside)


def make_object(name: str, builder: Builder, mats: dict, origin: tuple = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    """An object from the builder's mesh, its origin moved to origin (the mesh was built in container space)."""
    mesh = bpy.data.meshes.new(name)
    builder.bm.transform(Matrix.Translation(Vector(origin) * -1.0))
    builder.bm.to_mesh(mesh)
    builder.bm.free()
    for mat_name in builder.names:
        mesh.materials.append(mats[mat_name])
    obj = bpy.data.objects.new(name, mesh)
    obj.location = origin
    bpy.context.collection.objects.link(obj)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = BEVEL
    modifier.segments = 1
    modifier.limit_method = "ANGLE"
    return obj


def build_crate(mats: dict) -> list:
    width, depth, height = CRATE
    body_height = height - CRATE_LID
    body = Builder()
    body.shell(width, depth, body_height, "top", "Shell", "Interior")
    # Corner posts and rails, and hazard bands across the front.
    for x in (-width / 2.0 + 0.03, width / 2.0 - 0.03):
        for y in (-0.03, -depth + 0.03):
            body.box((0.07, 0.07, body_height), (x, y, body_height / 2.0), "Trim")
    for z in (0.06, body_height - 0.05):
        body.box((width + 0.01, 0.02, 0.06), (0.0, -depth - 0.005, z), "Trim")
    body.box((0.5, 0.012, 0.12), (0.0, -depth - 0.006, body_height * 0.55), "Hazard")
    body.box((0.22, 0.012, 0.08), (0.0, -depth - 0.006, body_height * 0.32), "Stencil")
    body.box((0.04, 0.02, 0.04), (width / 2.0 - 0.12, -depth - 0.01, body_height - 0.12), "Lamp")
    lid = Builder()
    lid.box((width + 0.02, depth + 0.02, CRATE_LID), (0.0, -depth / 2.0, body_height + CRATE_LID / 2.0), "Shell")
    lid.box((width - 0.12, depth - 0.12, 0.012), (0.0, -depth / 2.0, height + 0.006), "Trim")
    for x in (-0.3, 0.3):
        lid.box((0.08, 0.04, 0.03), (x, -depth - 0.02, body_height + 0.03), "Trim")
    return [make_object("Body", body, mats), make_object("Lid", lid, mats, (0.0, 0.0, body_height))]


def build_locker(mats: dict) -> list:
    width, depth, height = LOCKER
    base = 0.06
    body = Builder()
    body.shell(width, depth, height, "front", "Shell", "Interior")
    body.box((width, depth, base), (0.0, -depth / 2.0, base / 2.0), "Trim")
    for z in (0.65, 1.25):
        body.box((width - 2.0 * WALL, depth - 2.0 * WALL, 0.02), (0.0, -depth / 2.0, z), "Trim")
    body.box((width + 0.01, 0.03, 0.05), (0.0, -depth + 0.015, height - 0.025), "Trim")
    body.box((0.04, 0.02, 0.04), (width / 2.0 - 0.07, -depth - 0.01, height - 0.09), "Lamp")
    door_width = width - 0.02
    door_bottom = base + 0.01
    door_height = height - door_bottom - 0.06
    hinge = (-width / 2.0 + 0.01, -depth - 0.015, door_bottom)
    door = Builder()
    centre_x = hinge[0] + door_width / 2.0
    door.box((door_width, 0.025, door_height), (centre_x, hinge[1], door_bottom + door_height / 2.0), "Shell")
    for i in range(6):
        door.box((door_width * 0.6, 0.008, 0.018), (centre_x, hinge[1] - 0.014, height - 0.25 - i * 0.04), "Trim")
    door.box((0.025, 0.04, 0.2), (hinge[0] + door_width - 0.07, hinge[1] - 0.025, 1.0), "Trim")
    door.box((0.24, 0.006, 0.08), (centre_x, hinge[1] - 0.014, 1.35), "Stencil")
    door.box((door_width * 0.8, 0.006, 0.05), (centre_x, hinge[1] - 0.014, 0.35), "Hazard")
    return [make_object("Body", body, mats), make_object("Lid", door, mats, hinge)]


def build_case(mats: dict) -> list:
    width, depth, height = CASE
    body_height = height - CASE_LID
    body = Builder()
    body.shell(width, depth, body_height, "top", "Shell", "Interior")
    body.box((width + 0.01, depth + 0.01, 0.015), (0.0, -depth / 2.0, body_height - 0.0075), "Trim")
    for x in (-0.15, 0.15):
        body.box((0.04, 0.015, 0.05), (x, -depth - 0.008, body_height - 0.02), "Trim")
    body.box((0.03, 0.015, 0.025), (0.0, -depth - 0.008, body_height * 0.5), "Lamp")
    lid = Builder()
    lid.box((width, depth, CASE_LID), (0.0, -depth / 2.0, body_height + CASE_LID / 2.0), "Shell")
    lid.box((width * 0.7, depth * 0.55, 0.008), (0.0, -depth / 2.0, height + 0.004), "Hazard")
    lid.box((0.16, 0.03, 0.02), (0.0, -depth - 0.015, body_height + 0.02), "Trim")
    return [make_object("Body", body, mats), make_object("Lid", lid, mats, (0.0, 0.0, body_height))]


BUILDERS = {
    "supply_crate": build_crate,
    "locker": build_locker,
    "small_case": build_case,
}
# How far each lid swings open, about its hinge, for the preview (the scenes have their own copy).
OPEN = {
    "supply_crate": ("X", -100.0),
    "locker": ("Z", -110.0),
    "small_case": ("X", -95.0),
}


def container_materials(name: str) -> dict:
    shells = {
        "supply_crate": ((0.25, 0.3, 0.27), 0.25, 0.65),
        "locker": ((0.28, 0.31, 0.36), 0.6, 0.45),
        "small_case": ((0.08, 0.085, 0.09), 0.0, 0.7),
    }
    color, metallic, roughness = shells[name]
    return {
        "Shell": material(f"Shell_{name}", color, metallic, roughness),
        "Trim": material("Trim", (0.15, 0.17, 0.2), 0.85, 0.4),
        "Interior": material("Interior", (0.03, 0.035, 0.04), 0.0, 0.9),
        "Hazard": material("Hazard", (0.78, 0.6, 0.08), 0.1, 0.6),
        "Stencil": material("Stencil", (0.75, 0.78, 0.8), 0.0, 0.7),
        "Lamp": material("Lamp", (0.1, 0.06, 0.02), 0.0, 0.3, emission=(1.0, 0.55, 0.12), strength=3.0),
    }


def export_container(name: str, objects: list) -> None:
    path = CONTAINERS / name / f"{name}.glb"
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_apply=True, export_yup=True,
                              use_selection=True)
    print(f"🎒 Exported container: name={name}, path={path}, objects={len(objects)}")


def render_preview(path: Path, groups: list) -> None:
    """The containers in a row, lids open, seen from the front at an angle."""
    for i, (name, objects) in enumerate(groups):
        axis, angle = OPEN[name]
        for obj in objects:
            obj.location.x += i * 1.5 - 1.5
        objects[1].rotation_euler["XYZ".index(axis)] = math.radians(angle)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 800
    scene.render.filepath = str(path)
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.lens = 35.0
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    target = Vector((0.0, -0.3, 0.7))
    camera.location = target + Vector((1.2, -4.2, 1.8))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.ops.render.render(write_still=True)
    print(f"🎒 Rendered preview: path={path}, containers={len(groups)}")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    only = args[args.index("--only") + 1] if "--only" in args else None
    names = [only] if only else list(BUILDERS)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    groups = []
    for name in names:
        objects = BUILDERS[name](container_materials(name))
        export_container(name, objects)
        # Exported; the next container's objects must not clash with these names.
        for obj in objects:
            obj.name = f"{name}_{obj.name}"
        groups.append((name, objects))
    print(f"🎒 Exported containers: count={len(groups)}")
    if preview:
        render_preview(preview, groups)


if __name__ == "__main__":
    main()
