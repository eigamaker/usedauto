"""Build three production-oriented 4x4 used-car dealer concepts in Blender.

The authored footprint matches the game contract:

* 1 grid cell = 20 world units
* 4x4 footprint = 80x80 world units
* origin = footprint centre at ground level
* the public/front road edge is negative Y in Blender

Run with:
    blender --background --factory-startup --python build_used_car_dealers.py
"""

from __future__ import annotations

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "UsedCarDealers"
BLEND_PATH = OUTPUT_DIR / "used_car_dealers_4x4.blend"
PREVIEW_DIR = OUTPUT_DIR / "previews"
EXPORT_DIR = OUTPUT_DIR / "exports"

LOT_SIZE = 80.0
FRONT_EDGE_Y = -LOT_SIZE / 2

MATERIALS: dict[str, bpy.types.Material] = {}
CAR_COLORS: list[bpy.types.Material] = []


def reset_file() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)
    for scene in list(bpy.data.scenes)[1:]:
        bpy.data.scenes.remove(scene)
    bpy.context.scene.name = "Scene_Showcase"


def material(
    name: str,
    color: tuple[float, float, float, float],
    *,
    roughness: float = 0.55,
    metallic: float = 0.0,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    cached = MATERIALS.get(name)
    if cached:
        return cached

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    MATERIALS[name] = mat
    return mat


def build_materials() -> None:
    material("Concrete_Edge", (0.48, 0.50, 0.49, 1), roughness=0.82)
    material("Concrete_Light", (0.77, 0.75, 0.69, 1), roughness=0.74)
    material("Concrete_Warm", (0.89, 0.85, 0.75, 1), roughness=0.70)
    material("Asphalt", (0.105, 0.12, 0.13, 1), roughness=0.90)
    material("Asphalt_Light", (0.18, 0.20, 0.21, 1), roughness=0.84)
    material("Brand_Blue", (0.035, 0.22, 0.52, 1), roughness=0.34, metallic=0.05)
    material("Brand_Blue_Dark", (0.025, 0.075, 0.15, 1), roughness=0.38)
    material("Brand_Orange", (1.0, 0.30, 0.045, 1), roughness=0.42)
    material("Cream", (0.94, 0.88, 0.72, 1), roughness=0.66)
    material("Warm_White", (0.95, 0.94, 0.88, 1), roughness=0.60)
    material("Charcoal", (0.075, 0.085, 0.095, 1), roughness=0.42, metallic=0.08)
    material("Metal", (0.42, 0.46, 0.49, 1), roughness=0.30, metallic=0.72)
    material("Glass_Blue", (0.035, 0.18, 0.25, 1), roughness=0.15, metallic=0.18)
    material(
        "Interior_Warm",
        (0.90, 0.62, 0.29, 1),
        roughness=0.55,
        emission=(1.0, 0.48, 0.16, 1),
        emission_strength=1.7,
    )
    material(
        "Light_Emissive",
        (1.0, 0.78, 0.38, 1),
        roughness=0.28,
        emission=(1.0, 0.55, 0.18, 1),
        emission_strength=4.5,
    )
    material("Parking_White", (0.90, 0.89, 0.80, 1), roughness=0.68)
    material("Safety_Yellow", (1.0, 0.60, 0.04, 1), roughness=0.52)
    material("Lawn", (0.27, 0.48, 0.095, 1), roughness=0.95)
    material("Hedge", (0.12, 0.35, 0.075, 1), roughness=0.94)
    material("Leaf_Light", (0.28, 0.55, 0.10, 1), roughness=0.93)
    material("Trunk", (0.24, 0.11, 0.045, 1), roughness=0.92)
    material("Tire", (0.018, 0.022, 0.025, 1), roughness=0.76)
    material("Wheel", (0.52, 0.55, 0.57, 1), roughness=0.24, metallic=0.80)
    material("Roller_Door", (0.08, 0.18, 0.24, 1), roughness=0.48, metallic=0.12)
    material("Roof_Blue", (0.04, 0.28, 0.56, 1), roughness=0.44, metallic=0.08)
    material("Roof_Red", (0.62, 0.11, 0.055, 1), roughness=0.62)
    material("Render_Background", (0.78, 0.73, 0.63, 1), roughness=1.0)

    global CAR_COLORS
    CAR_COLORS = [
        material("Car_Red", (0.66, 0.035, 0.025, 1), roughness=0.24, metallic=0.30),
        material("Car_Blue", (0.025, 0.19, 0.52, 1), roughness=0.22, metallic=0.34),
        material("Car_White", (0.88, 0.87, 0.82, 1), roughness=0.30, metallic=0.10),
        material("Car_Silver", (0.43, 0.47, 0.51, 1), roughness=0.22, metallic=0.58),
        material("Car_Orange", (0.92, 0.22, 0.035, 1), roughness=0.28, metallic=0.22),
        material("Car_Teal", (0.015, 0.35, 0.40, 1), roughness=0.24, metallic=0.28),
        material("Car_Black", (0.025, 0.03, 0.035, 1), roughness=0.20, metallic=0.30),
    ]


def link_object(obj: bpy.types.Object, collection: bpy.types.Collection) -> bpy.types.Object:
    collection.objects.link(obj)
    return obj


def parent_to(obj: bpy.types.Object, parent: bpy.types.Object | None) -> None:
    if parent:
        obj.parent = parent


def empty(
    name: str,
    collection: bpy.types.Collection,
    location: tuple[float, float, float] = (0, 0, 0),
) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "CUBE"
    obj.empty_display_size = 2.0
    obj.location = location
    return link_object(obj, collection)


def box_mesh(name: str, dimensions: tuple[float, float, float]) -> bpy.types.Mesh:
    width, depth, height = dimensions
    x = width / 2
    y = depth / 2
    z = height / 2
    vertices = [
        (-x, -y, -z),
        (x, -y, -z),
        (x, y, -z),
        (-x, y, -z),
        (-x, -y, z),
        (x, -y, z),
        (x, y, z),
        (-x, y, z),
    ]
    faces = [
        (0, 1, 2, 3),
        (4, 7, 6, 5),
        (0, 4, 5, 1),
        (1, 5, 6, 2),
        (2, 6, 7, 3),
        (4, 0, 3, 7),
    ]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    return mesh


def box(
    name: str,
    collection: bpy.types.Collection,
    dimensions: tuple[float, float, float],
    location: tuple[float, float, float],
    mat: bpy.types.Material,
    *,
    bevel: float = 0.0,
    rotation: tuple[float, float, float] = (0, 0, 0),
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, box_mesh(name, dimensions))
    obj.location = location
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    link_object(obj, collection)
    parent_to(obj, parent)
    if bevel > 0:
        modifier = obj.modifiers.new("Edge_Bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
    return obj


def cylinder(
    name: str,
    collection: bpy.types.Collection,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    mat: bpy.types.Material,
    *,
    vertices: int = 16,
    rotation: tuple[float, float, float] = (0, 0, 0),
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=vertices,
        radius1=radius,
        radius2=radius,
        depth=depth,
    )
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    link_object(obj, collection)
    parent_to(obj, parent)
    return obj


def ico_sphere(
    name: str,
    collection: bpy.types.Collection,
    radius: float,
    location: tuple[float, float, float],
    mat: bpy.types.Material,
    *,
    subdivisions: int = 2,
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    obj.data.materials.append(mat)
    link_object(obj, collection)
    parent_to(obj, parent)
    return obj


def gable_roof(
    name: str,
    collection: bpy.types.Collection,
    width: float,
    depth: float,
    rise: float,
    location: tuple[float, float, float],
    mat: bpy.types.Material,
    *,
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    x = width / 2
    y = depth / 2
    vertices = [
        (-x, -y, 0),
        (-x, y, 0),
        (-x, 0, rise),
        (x, -y, 0),
        (x, y, 0),
        (x, 0, rise),
    ]
    faces = [
        (0, 3, 4, 1),
        (0, 2, 5, 3),
        (2, 1, 4, 5),
        (0, 1, 2),
        (3, 5, 4),
    ]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    obj.data.materials.append(mat)
    link_object(obj, collection)
    parent_to(obj, parent)
    bevel_modifier = obj.modifiers.new("Roof_Edge_Bevel", "BEVEL")
    bevel_modifier.width = 0.18
    bevel_modifier.segments = 2
    return obj


def text_object(
    name: str,
    collection: bpy.types.Collection,
    text: str,
    location: tuple[float, float, float],
    mat: bpy.types.Material,
    *,
    size: float = 1.8,
    rotation: tuple[float, float, float] = (math.radians(90), 0, 0),
    extrude: float = 0.10,
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(f"{name}_Curve", "FONT")
    curve.body = text
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = extrude
    curve.bevel_depth = 0.025
    curve.materials.append(mat)
    obj = bpy.data.objects.new(name, curve)
    obj.location = location
    obj.rotation_euler = rotation
    link_object(obj, collection)
    parent_to(obj, parent)
    return obj


def make_lot_base(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    *,
    accent: bpy.types.Material,
    front_gap: float = 15.0,
) -> None:
    box(
        "Footprint_80x80",
        collection,
        (LOT_SIZE, LOT_SIZE, 0.50),
        (0, 0, 0.25),
        MATERIALS["Concrete_Edge"],
        bevel=0.55,
        parent=root,
    )
    box(
        "Lot_Asphalt",
        collection,
        (77.8, 77.8, 0.22),
        (0, 0, 0.56),
        MATERIALS["Asphalt"],
        bevel=0.35,
        parent=root,
    )

    curb_height = 0.72
    curb_z = 0.86
    box("Curb_West", collection, (1.1, 77.4, curb_height), (-39.15, 0, curb_z), MATERIALS["Concrete_Light"], bevel=0.12, parent=root)
    box("Curb_East", collection, (1.1, 77.4, curb_height), (39.15, 0, curb_z), MATERIALS["Concrete_Light"], bevel=0.12, parent=root)
    box("Curb_Back", collection, (77.4, 1.1, curb_height), (0, 39.15, curb_z), MATERIALS["Concrete_Light"], bevel=0.12, parent=root)
    side_width = (77.4 - front_gap) / 2
    box(
        "Curb_Front_Left",
        collection,
        (side_width, 1.1, curb_height),
        (-(front_gap + side_width) / 2, -39.15, curb_z),
        MATERIALS["Concrete_Light"],
        bevel=0.12,
        parent=root,
    )
    box(
        "Curb_Front_Right",
        collection,
        (side_width, 1.1, curb_height),
        ((front_gap + side_width) / 2, -39.15, curb_z),
        MATERIALS["Concrete_Light"],
        bevel=0.12,
        parent=root,
    )
    box(
        "Entry_Apron",
        collection,
        (front_gap - 0.5, 8.0, 0.12),
        (0, -35.6, 0.72),
        MATERIALS["Asphalt_Light"],
        bevel=0.18,
        parent=root,
    )
    for x in (-39.1, 39.1):
        for y in (-39.1, 39.1):
            box(
                f"Corner_Post_{x}_{y}",
                collection,
                (1.8, 1.8, 2.5),
                (x, y, 1.75),
                accent,
                bevel=0.20,
                parent=root,
            )


def make_parking_stall(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    x: float,
    y: float,
    *,
    width: float = 6.2,
    depth: float = 10.5,
    rotation: float = 0.0,
    name: str,
) -> None:
    line_width = 0.20
    stripe_z = 0.75
    parking = empty(name, collection, (x, y, stripe_z))
    parking.rotation_euler.z = rotation
    parking.parent = root
    box(
        f"{name}_Left",
        collection,
        (line_width, depth, 0.06),
        (-width / 2, 0, 0),
        MATERIALS["Parking_White"],
        parent=parking,
    )
    box(
        f"{name}_Right",
        collection,
        (line_width, depth, 0.06),
        (width / 2, 0, 0),
        MATERIALS["Parking_White"],
        parent=parking,
    )
    box(
        f"{name}_Stop",
        collection,
        (width, line_width, 0.06),
        (0, depth / 2, 0),
        MATERIALS["Parking_White"],
        parent=parking,
    )


def make_car(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    location: tuple[float, float, float],
    color: bpy.types.Material,
    *,
    rotation_z: float = math.radians(90),
    scale: float = 1.65,
    suv: bool = False,
) -> bpy.types.Object:
    car = empty(name, collection, location)
    car.rotation_euler.z = rotation_z
    car.scale = (scale, scale, scale)
    car.parent = root
    car["role"] = "vehicle"

    body_height = 1.10 if not suv else 1.28
    cabin_height = 0.86 if not suv else 1.02
    box(
        f"{name}_Body",
        collection,
        (5.3, 2.25, body_height),
        (0, 0, 0.88),
        color,
        bevel=0.42,
        parent=car,
    )
    box(
        f"{name}_Cabin",
        collection,
        (2.75, 1.92, cabin_height),
        (-0.25, 0, 1.58 if not suv else 1.74),
        MATERIALS["Glass_Blue"],
        bevel=0.38,
        parent=car,
    )
    box(
        f"{name}_Hood",
        collection,
        (1.35, 2.08, 0.22),
        (1.86, 0, 1.32),
        color,
        bevel=0.18,
        parent=car,
    )
    for axle_x in (-1.65, 1.65):
        for side_y in (-1.10, 1.10):
            cylinder(
                f"{name}_Wheel_{axle_x}_{side_y}",
                collection,
                0.45,
                0.34,
                (axle_x, side_y, 0.58),
                MATERIALS["Tire"],
                vertices=16,
                rotation=(math.radians(90), 0, 0),
                parent=car,
            )
            cylinder(
                f"{name}_Rim_{axle_x}_{side_y}",
                collection,
                0.24,
                0.36,
                (axle_x, side_y, 0.58),
                MATERIALS["Wheel"],
                vertices=12,
                rotation=(math.radians(90), 0, 0),
                parent=car,
            )
    for side_y in (-0.67, 0.67):
        box(
            f"{name}_Headlight_{side_y}",
            collection,
            (0.14, 0.46, 0.25),
            (2.68, side_y, 0.98),
            MATERIALS["Light_Emissive"],
            bevel=0.06,
            parent=car,
        )
    return car


def make_tree(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    x: float,
    y: float,
    *,
    scale: float = 1.0,
) -> None:
    cylinder(
        f"{name}_Trunk",
        collection,
        0.44 * scale,
        3.8 * scale,
        (x, y, 2.55 * scale),
        MATERIALS["Trunk"],
        vertices=10,
        parent=root,
    )
    ico_sphere(
        f"{name}_Canopy_Low",
        collection,
        2.5 * scale,
        (x, y, 5.35 * scale),
        MATERIALS["Hedge"],
        subdivisions=2,
        parent=root,
    )
    ico_sphere(
        f"{name}_Canopy_High",
        collection,
        2.05 * scale,
        (x + 0.65 * scale, y - 0.20 * scale, 7.10 * scale),
        MATERIALS["Leaf_Light"],
        subdivisions=2,
        parent=root,
    )


def make_hedge(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    dimensions: tuple[float, float, float],
    location: tuple[float, float, float],
) -> None:
    box(name, collection, dimensions, location, MATERIALS["Hedge"], bevel=0.55, parent=root)


def make_lamp(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    x: float,
    y: float,
) -> None:
    cylinder(name + "_Pole", collection, 0.18, 5.8, (x, y, 3.65), MATERIALS["Metal"], vertices=12, parent=root)
    box(name + "_Head", collection, (0.85, 0.85, 0.34), (x, y, 6.65), MATERIALS["Charcoal"], bevel=0.12, parent=root)
    box(name + "_Light", collection, (0.56, 0.56, 0.10), (x, y, 6.46), MATERIALS["Light_Emissive"], bevel=0.06, parent=root)


def make_rooftop_hvac(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    location: tuple[float, float, float],
    *,
    scale: float = 1.0,
) -> None:
    box(name + "_Base", collection, (4.0 * scale, 3.0 * scale, 1.7 * scale), location, MATERIALS["Metal"], bevel=0.16, parent=root)
    x, y, z = location
    for offset in (-1.05, -0.35, 0.35, 1.05):
        box(
            f"{name}_Vent_{offset}",
            collection,
            (0.12, 2.45 * scale, 0.45 * scale),
            (x + offset * scale, y - 1.53 * scale, z),
            MATERIALS["Charcoal"],
            bevel=0.03,
            parent=root,
        )


def make_glass_grid(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    *,
    width: float,
    height: float,
    x: float,
    y: float,
    bottom_z: float,
    columns: int,
    rows: int = 1,
    frame_mat: bpy.types.Material | None = None,
) -> None:
    frame_mat = frame_mat or MATERIALS["Brand_Blue_Dark"]
    glass_depth = 0.24
    box(
        name + "_Glass",
        collection,
        (width, glass_depth, height),
        (x, y, bottom_z + height / 2),
        MATERIALS["Glass_Blue"],
        bevel=0.04,
        parent=root,
    )
    box(
        name + "_WarmInterior",
        collection,
        (width - 0.8, 0.12, height - 0.8),
        (x, y + 0.30, bottom_z + height / 2),
        MATERIALS["Interior_Warm"],
        parent=root,
    )
    frame = 0.27
    for index in range(columns + 1):
        fx = x - width / 2 + width * index / columns
        box(
            f"{name}_Mullion_{index}",
            collection,
            (frame, 0.42, height + 0.4),
            (fx, y - 0.10, bottom_z + height / 2),
            frame_mat,
            bevel=0.035,
            parent=root,
        )
    for index in range(rows + 1):
        fz = bottom_z + height * index / rows
        box(
            f"{name}_Transom_{index}",
            collection,
            (width + 0.4, 0.42, frame),
            (x, y - 0.10, fz),
            frame_mat,
            bevel=0.035,
            parent=root,
        )


def make_sign(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    text: str,
    *,
    width: float,
    height: float,
    location: tuple[float, float, float],
    board_mat: bpy.types.Material,
    text_mat: bpy.types.Material,
    text_size: float,
) -> None:
    x, y, z = location
    box(name + "_Board", collection, (width, 0.52, height), location, board_mat, bevel=0.24, parent=root)
    text_object(
        name + "_Text",
        collection,
        text,
        (x, y - 0.31, z),
        text_mat,
        size=text_size,
        extrude=0.08,
        parent=root,
    )


def make_pylon_sign(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    text: str,
    x: float,
    y: float,
    *,
    accent: bpy.types.Material,
) -> None:
    box(name + "_Base", collection, (4.6, 3.0, 0.7), (x, y, 1.05), MATERIALS["Concrete_Edge"], bevel=0.22, parent=root)
    box(name + "_Pillar", collection, (2.0, 1.5, 11.5), (x, y, 6.8), accent, bevel=0.22, parent=root)
    make_sign(
        collection,
        root,
        name + "_Panel",
        text,
        width=8.2,
        height=4.6,
        location=(x, y - 0.10, 11.4),
        board_mat=MATERIALS["Warm_White"],
        text_mat=accent,
        text_size=1.30,
    )
    box(name + "_OrangeCap", collection, (8.5, 0.70, 0.45), (x, y - 0.10, 13.9), MATERIALS["Brand_Orange"], bevel=0.10, parent=root)


def make_planter(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    x: float,
    y: float,
    *,
    width: float = 6.0,
    depth: float = 2.6,
) -> None:
    box(name + "_Box", collection, (width, depth, 0.85), (x, y, 1.15), MATERIALS["Concrete_Warm"], bevel=0.25, parent=root)
    make_hedge(collection, root, name + "_Hedge", (width - 0.65, depth - 0.65, 1.20), (x, y, 2.05))


def rollup_door(
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    name: str,
    *,
    x: float,
    y: float,
    width: float,
    height: float,
) -> None:
    box(name + "_Recess", collection, (width, 0.34, height), (x, y, 0.82 + height / 2), MATERIALS["Charcoal"], bevel=0.08, parent=root)
    box(name + "_Door", collection, (width - 0.65, 0.30, height - 0.55), (x, y - 0.23, 0.82 + height / 2), MATERIALS["Roller_Door"], bevel=0.06, parent=root)
    for index in range(8):
        z = 1.18 + (height - 0.95) * index / 7
        box(
            f"{name}_Slat_{index}",
            collection,
            (width - 0.80, 0.16, 0.10),
            (x, y - 0.42, z),
            MATERIALS["Metal"],
            parent=root,
        )
    for side in (-1, 1):
        box(
            f"{name}_Frame_{side}",
            collection,
            (0.42, 0.62, height + 0.5),
            (x + side * width / 2, y - 0.12, 0.82 + height / 2),
            MATERIALS["Brand_Blue"],
            bevel=0.08,
            parent=root,
        )


def build_modern_flagship() -> bpy.types.Collection:
    collection = bpy.data.collections.new("Dealer_A_Modern_Flagship")
    root = empty("ROOT_Dealer_A_Modern_Flagship", collection)
    root["asset_id"] = "player_large_dealer_modern"
    root["footprint_cells"] = "4x4"
    root["footprint_world"] = "80x80"
    root["front_direction"] = "-Y"
    root["origin"] = "footprint_center_at_ground"
    make_lot_base(collection, root, accent=MATERIALS["Brand_Blue"], front_gap=17.0)

    # Building envelope, recessed curtain wall, and projecting portal.
    box("A_Main_Mass", collection, (55.0, 31.0, 23.0), (-9.0, 19.0, 12.15), MATERIALS["Warm_White"], bevel=0.52, parent=root)
    box("A_Ground_Reveal", collection, (56.0, 32.0, 1.1), (-9.0, 19.0, 1.33), MATERIALS["Charcoal"], bevel=0.22, parent=root)
    box("A_Top_Fascia", collection, (57.0, 32.5, 2.6), (-9.0, 19.0, 22.0), MATERIALS["Brand_Blue"], bevel=0.38, parent=root)
    box("A_Roof_Deck", collection, (56.5, 32.0, 0.75), (-9.0, 19.0, 24.0), MATERIALS["Charcoal"], bevel=0.28, parent=root)
    for px, py, pw, pd in [
        (-9.0, 3.4, 57.0, 0.80),
        (-9.0, 34.6, 57.0, 0.80),
        (-37.1, 19.0, 0.80, 32.0),
        (19.1, 19.0, 0.80, 32.0),
    ]:
        box(f"A_Parapet_{px}_{py}", collection, (pw, pd, 1.4), (px, py, 24.85), MATERIALS["Concrete_Light"], bevel=0.14, parent=root)
    make_glass_grid(
        collection,
        root,
        "A_Curtain_Wall",
        width=49.0,
        height=17.8,
        x=-9.0,
        y=3.24,
        bottom_z=2.15,
        columns=8,
        rows=3,
    )
    box("A_Floor_Band", collection, (50.5, 0.72, 0.85), (-9.0, 2.92, 8.0), MATERIALS["Brand_Blue"], bevel=0.10, parent=root)
    box("A_Upper_Floor_Band", collection, (50.5, 0.72, 0.85), (-9.0, 2.92, 14.0), MATERIALS["Brand_Blue"], bevel=0.10, parent=root)
    box("A_Entrance_Canopy", collection, (14.5, 5.8, 1.3), (-9.0, 0.65, 9.35), MATERIALS["Brand_Blue"], bevel=0.28, parent=root)
    for x in (-15.0, -3.0):
        box(f"A_Entrance_Column_{x}", collection, (1.15, 1.15, 8.8), (x, 0.85, 5.15), MATERIALS["Brand_Blue"], bevel=0.17, parent=root)
    make_sign(
        collection,
        root,
        "A_Main_Sign",
        "SUIHAMA SELECT",
        width=30.0,
        height=4.2,
        location=(-9.0, 2.75, 20.0),
        board_mat=MATERIALS["Brand_Blue_Dark"],
        text_mat=MATERIALS["Warm_White"],
        text_size=1.75,
    )

    # Side display canopy creates a second, readable silhouette.
    box("A_Canopy_Roof", collection, (23.0, 31.0, 1.6), (27.0, 19.0, 17.3), MATERIALS["Roof_Blue"], bevel=0.44, parent=root)
    box("A_Canopy_Orange_Line", collection, (23.6, 31.6, 0.55), (27.0, 19.0, 16.38), MATERIALS["Brand_Orange"], bevel=0.12, parent=root)
    for x in (17.0, 37.0):
        for y in (5.6, 32.4):
            box(f"A_Canopy_Column_{x}_{y}", collection, (1.35, 1.35, 16.1), (x, y, 8.85), MATERIALS["Charcoal"], bevel=0.20, parent=root)
    make_car(collection, root, "A_Showcase_Car", (27.0, 18.5, 0.78), CAR_COLORS[4], rotation_z=math.radians(90), scale=1.80)

    make_rooftop_hvac(collection, root, "A_HVAC_1", (-20.0, 20.5, 26.1), scale=1.0)
    make_rooftop_hvac(collection, root, "A_HVAC_2", (0.0, 22.5, 25.95), scale=0.88)

    # Two parking rows and clear circulation aisle.
    front_xs = [-30, -20, -10, 0, 10, 20, 30]
    for index, x in enumerate(front_xs):
        make_parking_stall(collection, root, x, -27.5, name=f"A_Front_Stall_{index}")
        make_car(collection, root, f"A_Front_Car_{index}", (x, -27.5, 0.78), CAR_COLORS[index % len(CAR_COLORS)], suv=index in (1, 5))
    second_xs = [-29, -19, -9, 1, 11]
    for index, x in enumerate(second_xs):
        make_parking_stall(collection, root, x, -12.2, name=f"A_Second_Stall_{index}")
        make_car(collection, root, f"A_Second_Car_{index}", (x, -12.2, 0.78), CAR_COLORS[(index + 2) % len(CAR_COLORS)], rotation_z=-math.radians(90))

    make_planter(collection, root, "A_Planter_Left", -34.5, -5.0, width=7.0, depth=3.0)
    make_planter(collection, root, "A_Planter_Right", 34.4, -5.0, width=7.0, depth=3.0)
    for index, (x, y) in enumerate([(-36, 35), (35.5, 34.5), (35.5, -34.0)]):
        make_lamp(collection, root, f"A_Lamp_{index}", x, y)
    return collection


def build_suburban_market() -> bpy.types.Collection:
    collection = bpy.data.collections.new("Dealer_B_Suburban_Market")
    root = empty("ROOT_Dealer_B_Suburban_Market", collection)
    root["asset_id"] = "player_large_dealer_suburban"
    root["footprint_cells"] = "4x4"
    root["footprint_world"] = "80x80"
    root["front_direction"] = "-Y"
    root["origin"] = "footprint_center_at_ground"
    make_lot_base(collection, root, accent=MATERIALS["Brand_Orange"], front_gap=18.0)

    # A lower, welcoming gabled showroom with a clearly recessed storefront.
    box("B_Showroom_Mass", collection, (54.0, 31.0, 15.0), (-8.0, 19.0, 8.15), MATERIALS["Cream"], bevel=0.48, parent=root)
    gable_roof("B_Gable_Roof", collection, 57.0, 34.0, 7.5, (-8.0, 19.0, 15.65), MATERIALS["Roof_Red"], parent=root)
    box("B_Roof_Ridge", collection, (57.6, 0.95, 0.80), (-8.0, 19.0, 23.35), MATERIALS["Concrete_Light"], bevel=0.18, parent=root)
    make_glass_grid(
        collection,
        root,
        "B_Storefront",
        width=44.0,
        height=10.6,
        x=-8.0,
        y=3.24,
        bottom_z=1.15,
        columns=7,
        rows=2,
        frame_mat=MATERIALS["Brand_Blue"],
    )
    box("B_Awning", collection, (45.5, 5.0, 0.95), (-8.0, 1.1, 12.5), MATERIALS["Brand_Orange"], bevel=0.27, parent=root)
    for x in (-28.5, 12.5):
        box(f"B_Awning_Support_{x}", collection, (0.85, 0.85, 11.4), (x, 1.4, 6.45), MATERIALS["Brand_Blue"], bevel=0.14, parent=root)
    make_sign(
        collection,
        root,
        "B_Main_Sign",
        "CITY AUTO MARKET",
        width=32.0,
        height=4.2,
        location=(-8.0, 2.72, 14.4),
        board_mat=MATERIALS["Warm_White"],
        text_mat=MATERIALS["Brand_Blue"],
        text_size=1.50,
    )

    # Open-air display pavilion on the right.
    box("B_Display_Canopy", collection, (23.0, 32.0, 1.3), (27.0, 18.5, 14.6), MATERIALS["Roof_Blue"], bevel=0.34, parent=root)
    box("B_Canopy_White_Trim", collection, (24.0, 33.0, 0.48), (27.0, 18.5, 13.78), MATERIALS["Warm_White"], bevel=0.14, parent=root)
    for x in (17.0, 37.0):
        for y in (4.5, 32.5):
            box(f"B_Canopy_Post_{x}_{y}", collection, (1.15, 1.15, 13.6), (x, y, 7.5), MATERIALS["Warm_White"], bevel=0.16, parent=root)
    for index, y in enumerate((14.5, 24.0)):
        make_car(collection, root, f"B_Canopy_Car_{index}", (27.0, y, 0.78), CAR_COLORS[(index + 1) % len(CAR_COLORS)], rotation_z=0, scale=1.80)

    make_pylon_sign(collection, root, "B_Pylon", "CITY AUTO", 31.5, -10.0, accent=MATERIALS["Brand_Blue"])

    xs = [-31, -21, -11, -1, 9, 19]
    for index, x in enumerate(xs):
        make_parking_stall(collection, root, x, -27.5, name=f"B_Front_Stall_{index}")
        make_car(collection, root, f"B_Front_Car_{index}", (x, -27.5, 0.78), CAR_COLORS[(index + 5) % len(CAR_COLORS)], suv=index in (2, 5))
    for index, x in enumerate([-28, -18, -8, 2, 12]):
        make_parking_stall(collection, root, x, -12.0, name=f"B_Inner_Stall_{index}")
        make_car(collection, root, f"B_Inner_Car_{index}", (x, -12.0, 0.78), CAR_COLORS[index % len(CAR_COLORS)], rotation_z=-math.radians(90))

    # Landscaping softens the lower suburban silhouette.
    for index, (x, y, scale) in enumerate([(-34, 34, 0.85), (35, 34, 0.78), (-35, -6, 0.72)]):
        make_tree(collection, root, f"B_Tree_{index}", x, y, scale=scale)
    make_hedge(collection, root, "B_Hedge_Back", (73.0, 2.0, 1.6), (0, 36.5, 1.58))
    make_hedge(collection, root, "B_Hedge_West", (2.0, 24.0, 1.6), (-36.5, 22.0, 1.58))
    make_planter(collection, root, "B_Center_Planter", 7.0, -3.3, width=8.0, depth=3.0)
    return collection


def build_service_hub() -> bpy.types.Collection:
    collection = bpy.data.collections.new("Dealer_C_Service_Hub")
    root = empty("ROOT_Dealer_C_Service_Hub", collection)
    root["asset_id"] = "player_large_dealer_service_hub"
    root["footprint_cells"] = "4x4"
    root["footprint_world"] = "80x80"
    root["front_direction"] = "-Y"
    root["origin"] = "footprint_center_at_ground"
    make_lot_base(collection, root, accent=MATERIALS["Brand_Blue"], front_gap=19.0)

    # Left showroom/office volume.
    box("C_Showroom_Mass", collection, (30.0, 34.0, 17.0), (-24.0, 20.0, 9.15), MATERIALS["Warm_White"], bevel=0.46, parent=root)
    box("C_Showroom_Fascia", collection, (31.0, 35.0, 2.1), (-24.0, 20.0, 16.5), MATERIALS["Brand_Blue"], bevel=0.32, parent=root)
    make_glass_grid(
        collection,
        root,
        "C_Showroom_Glass",
        width=25.0,
        height=11.0,
        x=-24.0,
        y=2.74,
        bottom_z=1.25,
        columns=5,
        rows=2,
        frame_mat=MATERIALS["Brand_Blue"],
    )
    box("C_Showroom_Awning", collection, (17.0, 4.8, 1.0), (-24.0, 0.7, 12.5), MATERIALS["Brand_Orange"], bevel=0.25, parent=root)
    make_sign(
        collection,
        root,
        "C_Office_Sign",
        "GARAGE 24",
        width=22.0,
        height=3.8,
        location=(-24.0, 2.20, 15.2),
        board_mat=MATERIALS["Brand_Blue_Dark"],
        text_mat=MATERIALS["Warm_White"],
        text_size=1.65,
    )

    # Workshop mass with three real recessed service bays.
    box("C_Workshop_Mass", collection, (48.0, 35.0, 18.0), (15.0, 20.5, 9.65), MATERIALS["Concrete_Warm"], bevel=0.42, parent=root)
    box("C_Workshop_Roof", collection, (49.0, 36.0, 1.3), (15.0, 20.5, 19.3), MATERIALS["Charcoal"], bevel=0.34, parent=root)
    box("C_Workshop_Fascia", collection, (49.0, 36.0, 1.9), (15.0, 20.5, 17.35), MATERIALS["Brand_Blue"], bevel=0.28, parent=root)
    for index, x in enumerate((-0.5, 14.5, 29.5)):
        rollup_door(collection, root, f"C_Bay_{index + 1}", x=x, y=2.72, width=11.4, height=12.0)
        box(
            f"C_Bay_Number_Board_{index}",
            collection,
            (4.0, 0.50, 1.9),
            (x, 2.40, 15.25),
            MATERIALS["Brand_Orange"],
            bevel=0.14,
            parent=root,
        )
        text_object(
            f"C_Bay_Number_{index}",
            collection,
            str(index + 1),
            (x, 2.12, 15.25),
            MATERIALS["Warm_White"],
            size=1.15,
            extrude=0.06,
            parent=root,
        )
    for x in (-0.5, 14.5, 29.5):
        box(f"C_Bay_Apron_{x}", collection, (12.5, 12.0, 0.12), (x, -3.2, 0.73), MATERIALS["Asphalt_Light"], bevel=0.10, parent=root)
        box(f"C_Bay_Centerline_{x}", collection, (0.24, 10.0, 0.06), (x, -3.5, 0.82), MATERIALS["Safety_Yellow"], parent=root)

    make_rooftop_hvac(collection, root, "C_HVAC_Office", (-24.0, 20.0, 19.4), scale=0.95)
    make_rooftop_hvac(collection, root, "C_HVAC_Shop", (16.0, 21.0, 21.0), scale=1.15)
    for x in (0.0, 10.0, 20.0, 30.0):
        box(f"C_Roof_Rib_{x}", collection, (0.42, 32.0, 0.68), (x, 20.5, 20.35), MATERIALS["Metal"], bevel=0.07, parent=root)

    # Tire and tool props make the workshop use legible at game zoom.
    for stack_index, (x, y) in enumerate([(35.5, 5.5), (35.5, 9.0), (-36.0, 8.0)]):
        for tire_index in range(3):
            cylinder(
                f"C_Tire_{stack_index}_{tire_index}",
                collection,
                1.25,
                0.55,
                (x, y, 1.15 + tire_index * 0.58),
                MATERIALS["Tire"],
                vertices=18,
                parent=root,
            )
    box("C_Tool_Cabinet", collection, (3.0, 1.8, 4.5), (35.0, 14.0, 3.0), MATERIALS["Brand_Orange"], bevel=0.18, parent=root)
    for index in range(5):
        box(f"C_Tool_Drawer_{index}", collection, (2.55, 0.15, 0.22), (35.0, 13.05, 1.55 + index * 0.62), MATERIALS["Charcoal"], bevel=0.04, parent=root)

    front_xs = [-31, -21, -11, -1, 9, 19, 29]
    for index, x in enumerate(front_xs):
        make_parking_stall(collection, root, x, -28.0, name=f"C_Front_Stall_{index}")
        make_car(collection, root, f"C_Front_Car_{index}", (x, -28.0, 0.78), CAR_COLORS[(index + 1) % len(CAR_COLORS)], suv=index in (1, 6))
    for index, (x, y) in enumerate([(-28, -12), (-17, -12), (25, -10)]):
        make_car(collection, root, f"C_Waiting_Car_{index}", (x, y, 0.78), CAR_COLORS[(index + 4) % len(CAR_COLORS)], rotation_z=-math.radians(90))

    for index, (x, y) in enumerate([(-36, 35), (36, 35), (-36, -5), (36, -5)]):
        make_lamp(collection, root, f"C_Lamp_{index}", x, y)
    make_planter(collection, root, "C_Office_Planter", -34.0, 1.0, width=6.0, depth=2.8)
    return collection


def look_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_world(scene: bpy.types.Scene) -> None:
    scene.world = bpy.data.worlds.new(f"{scene.name}_World")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.72, 0.77, 0.79, 1)
    background.inputs["Strength"].default_value = 0.62


def configure_render(scene: bpy.types.Scene, width: int, height: int) -> bpy.types.Collection:
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.use_file_extension = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.exposure = 0.45
    scene.view_settings.gamma = 1.0
    configure_world(scene)

    render_collection = bpy.data.collections.new(f"{scene.name}_Render_Rig")
    scene.collection.children.link(render_collection)
    return render_collection


def add_render_rig(
    scene: bpy.types.Scene,
    collection: bpy.types.Collection,
    *,
    camera_location: tuple[float, float, float],
    target: tuple[float, float, float],
    ortho_scale: float,
    backdrop_size: tuple[float, float],
) -> None:
    camera_data = bpy.data.cameras.new(f"{scene.name}_Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = ortho_scale
    camera_data.lens = 52
    camera = bpy.data.objects.new(f"{scene.name}_Camera", camera_data)
    camera.location = camera_location
    look_at(camera, target)
    collection.objects.link(camera)
    scene.camera = camera

    sun_data = bpy.data.lights.new(f"{scene.name}_Sun", "SUN")
    sun_data.energy = 2.7
    sun_data.angle = math.radians(7.5)
    sun = bpy.data.objects.new(f"{scene.name}_Sun", sun_data)
    sun.location = (-85, -95, 145)
    look_at(sun, (0, 0, 0))
    collection.objects.link(sun)

    area_data = bpy.data.lights.new(f"{scene.name}_Fill", "AREA")
    area_data.energy = 900
    area_data.shape = "DISK"
    area_data.size = 95
    area = bpy.data.objects.new(f"{scene.name}_Fill", area_data)
    area.location = (60, -85, 105)
    look_at(area, (0, 0, 8))
    collection.objects.link(area)

    rim_data = bpy.data.lights.new(f"{scene.name}_Rim", "AREA")
    rim_data.energy = 650
    rim_data.shape = "RECTANGLE"
    rim_data.size = 70
    rim_data.size_y = 70
    rim = bpy.data.objects.new(f"{scene.name}_Rim", rim_data)
    rim.location = (-70, 75, 80)
    look_at(rim, (0, 0, 8))
    collection.objects.link(rim)

    box(
        f"{scene.name}_Backdrop",
        collection,
        (backdrop_size[0], backdrop_size[1], 0.35),
        (0, 0, -0.38),
        MATERIALS["Render_Background"],
        bevel=0.25,
    )


def make_individual_scene(
    scene_name: str,
    design_collection: bpy.types.Collection,
    preview_name: str,
) -> bpy.types.Scene:
    scene = bpy.data.scenes.new(scene_name)
    scene.collection.children.link(design_collection)
    rig = configure_render(scene, 1200, 1000)
    add_render_rig(
        scene,
        rig,
        camera_location=(112, -112, 112),
        target=(0, 0, 5.0),
        ortho_scale=100.0,
        backdrop_size=(220, 220),
    )
    scene.render.filepath = str(PREVIEW_DIR / preview_name)
    return scene


def make_showcase_scene(
    scene: bpy.types.Scene,
    designs: list[tuple[bpy.types.Collection, str]],
) -> bpy.types.Scene:
    scene.name = "Scene_Showcase"
    showcase_collection = bpy.data.collections.new("Showcase_Instances")
    scene.collection.children.link(showcase_collection)

    # The camera looks from +X/-Y. Placing the concepts along its screen-right
    # ground vector (+X/+Y) keeps all three lots on one visual baseline.
    showcase_positions = ((-84.0, -84.0), (0.0, 0.0), (84.0, 84.0))
    for index, ((design, label), (x, y)) in enumerate(zip(designs, showcase_positions)):
        instance = bpy.data.objects.new(f"Showcase_{design.name}", None)
        instance.instance_type = "COLLECTION"
        instance.instance_collection = design
        instance.location = (x, y, 0)
        showcase_collection.objects.link(instance)
        board = box(
            f"Showcase_Label_Board_{index}",
            showcase_collection,
            (42.0, 2.0, 4.8),
            (x, y - 44.5, 3.0),
            MATERIALS["Brand_Blue_Dark"],
            bevel=0.24,
        )
        text_object(
            f"Showcase_Label_{index}",
            showcase_collection,
            label,
            (x, y - 45.56, 3.0),
            MATERIALS["Warm_White"],
            size=1.35,
            extrude=0.08,
            parent=None,
        )
        board["render_only"] = True

    rig = configure_render(scene, 2100, 900)
    add_render_rig(
        scene,
        rig,
        camera_location=(260, -260, 260),
        target=(0, 0, 3.0),
        ortho_scale=380.0,
        backdrop_size=(800, 600),
    )
    scene.render.filepath = str(PREVIEW_DIR / "dealer_showcase.png")
    return scene


def render_scene(scene: bpy.types.Scene) -> None:
    bpy.context.window.scene = scene
    print(f"Rendering {scene.name} -> {scene.render.filepath}")
    bpy.ops.render.render(write_still=True)


def export_collection(
    collection: bpy.types.Collection,
    scene: bpy.types.Scene,
    stem: str,
) -> None:
    glb_path = EXPORT_DIR / f"{stem}.glb"
    usdz_path = EXPORT_DIR / f"{stem}.usdz"
    bpy.context.window.scene = scene
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.all_objects:
        obj.select_set(True)
    root = next((obj for obj in collection.objects if obj.parent is None), None)
    if root:
        bpy.context.view_layer.objects.active = root

    print(f"Exporting {collection.name} -> {glb_path.name}")
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=True,
        use_active_scene=True,
        export_apply=True,
        export_extras=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
    )
    print(f"Exporting {collection.name} -> {usdz_path.name}")
    bpy.ops.wm.usd_export(
        filepath=str(usdz_path),
        selected_objects_only=True,
        export_animation=False,
        export_materials=True,
        export_normals=True,
        export_uvmaps=True,
        export_custom_properties=True,
        use_instancing=True,
        triangulate_meshes=True,
        generate_preview_surface=True,
        export_lights=False,
        export_cameras=False,
        convert_orientation=True,
        export_global_forward_selection="NEGATIVE_Z",
        export_global_up_selection="Y",
        convert_scene_units="METERS",
        meters_per_unit=1.0,
    )
    bpy.ops.object.select_all(action="DESELECT")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)

    reset_file()
    build_materials()

    modern = build_modern_flagship()
    suburban = build_suburban_market()
    service = build_service_hub()

    scene_a = make_individual_scene("Scene_A_Modern_Flagship", modern, "dealer_a_modern_flagship.png")
    scene_b = make_individual_scene("Scene_B_Suburban_Market", suburban, "dealer_b_suburban_market.png")
    scene_c = make_individual_scene("Scene_C_Service_Hub", service, "dealer_c_service_hub.png")
    showcase = make_showcase_scene(
        bpy.context.scene,
        [
            (modern, "A  MODERN FLAGSHIP"),
            (suburban, "B  SUBURBAN MARKET"),
            (service, "C  SERVICE HUB"),
        ],
    )

    for scene in (scene_a, scene_b, scene_c, showcase):
        render_scene(scene)

    export_collection(modern, scene_a, "dealer_a_modern_flagship_4x4")
    export_collection(suburban, scene_b, "dealer_b_suburban_market_4x4")
    export_collection(service, scene_c, "dealer_c_service_hub_4x4")

    bpy.context.window.scene = showcase
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), compress=True)
    print(f"Saved Blender source: {BLEND_PATH}")


if __name__ == "__main__":
    main()
