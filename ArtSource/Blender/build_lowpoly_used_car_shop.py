"""Low-poly city kit: the used car shop, rebuilt to a mobile triangle budget.

This is the same art direction as the earlier concept asset, re-authored under
the rule that makes a 200x200 map possible:

    geometry = silhouette only, texture = everything else

The earlier concept spent 44,168 triangles modelling trim, tile courses,
window frames and bevels. All of that is now baked into a 512px texture set on
a few hundred triangles. Window frames, mullions, timber grain, roof courses,
painted edge highlights and ambient occlusion are texture, not vertices.

Run with::

    blender --background --factory-startup \
        --python ArtSource/Blender/build_lowpoly_used_car_shop.py

Flags after ``--``: ``--quick`` (fast previews), ``--no-bake``.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import citykit as kit  # noqa: E402


OUTPUT_DIR = SCRIPT_DIR / "LowPolyCityKit"
BLEND_PATH = OUTPUT_DIR / "lowpoly_city_kit.blend"
PREVIEW_DIR = OUTPUT_DIR / "previews"
EXPORT_DIR = OUTPUT_DIR / "exports"

CELLS = 3
LOT = kit.lot_size(CELLS)
HALF = LOT / 2
TRIANGLE_BUDGET = 700
# 40 assets at 512px fit inside one 4096px city atlas with room to spare.
TEXTURE_SIZE = 512

# The asset carries no terrain tile of its own. On a map that is meant to be
# solid with buildings, per-asset grass tiles produce a checkerboard, put a
# step between every lot and the road, and waste ~30 triangles each. The city
# ground is one continuous chunked mesh instead, and assets sit on it at z=0.
SOIL_H = 1.90
GROUND = 0.0
YARD_TOP = 0.14
PAD_TOP = 0.34

BUILDING_Y = 15.0
BASE_H = 2.50
BASE_TOP = PAD_TOP + BASE_H
WALL_H = 14.60
WALL_TOP = BASE_TOP + WALL_H
EAVE_Z = WALL_TOP - 0.35
RIDGE_Z = EAVE_Z + 9.60


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def build_materials() -> None:
    kit.stylized_material(
        "Wall", "sand_wall", shade_key="sand_wall_shade",
        # The windows are painted. There are no modelled frames anywhere.
        pattern=kit.panel_pattern(rows=0.21, columns=0.175, frame=kit.col("sand_wall"),
                                  glass=kit.col("glass"), glow=kit.col("cream_trim")),
        edge_amount=0.20, crevice_amount=0.28, gradient_amount=0.34,
        ao_amount=0.52, roughness=0.86, bevel_radius=0.55, bump_strength=0.30,
    )
    kit.stylized_material(
        "Stone_Base", "stone", shade_key="stone_dark",
        pattern=kit.block_pattern(scale=2.4, mortar=kit.col("stone_dark"), light=kit.col("cream_trim")),
        edge_amount=0.18, gradient_amount=0.32, ao_amount=0.58, roughness=0.92,
        bevel_radius=0.45, bump_strength=0.65,
    )
    kit.stylized_material(
        "Showroom", "glass", shade_key="glass_dark",
        pattern=kit.panel_pattern(rows=0.24, columns=0.30, frame=kit.col("cream_trim"),
                                  glass=kit.col("glass"), glow=kit.col("cream_trim")),
        edge_key="cream_trim", edge_amount=0.24, gradient_amount=0.12, ao_amount=0.35,
        roughness=0.35, bevel_radius=0.35, bump_strength=0.45,
        emission_key="glass", emission_strength=0.55,
    )
    kit.stylized_material(
        "Roof", "roof", shade_key="roof_shade",
        # The only tile courses in the asset. Nothing is modelled.
        pattern=kit.shingle_pattern(course=1.55, light=kit.col("roof_light"), dark=kit.col("roof_shade")),
        edge_key="roof_light", edge_amount=0.30, gradient_amount=0.16, ao_amount=0.48,
        roughness=0.72, bevel_radius=0.50, bump_strength=0.85,
    )
    kit.stylized_material(
        "Cream_Trim", "cream_trim", shade_key="cream_shade",
        pattern=kit.speckle_pattern(scale=6.0, amount=0.28, tint=kit.col("sand_speckle")),
        edge_amount=0.20, gradient_amount=0.22, ao_amount=0.50, roughness=0.80, bevel_radius=0.45,
    )
    kit.stylized_material(
        "Timber", "wood", shade_key="wood_shade",
        pattern=kit.plank_pattern(scale=1.0, light=kit.col("wood_light"), dark=kit.col("wood_shade")),
        edge_key="wood_light", edge_amount=0.24, gradient_amount=0.28, ao_amount=0.55,
        roughness=0.88, bevel_radius=0.35, bump_strength=0.30,
    )
    kit.stylized_material(
        "Gold_Trim", "gold", shade_key="gold_shade",
        pattern=kit.speckle_pattern(scale=10.0, amount=0.22, tint=kit.col("cream_trim")),
        edge_key="cream_trim", edge_amount=0.38, ao_amount=0.42, roughness=0.36, bevel_radius=0.25,
    )
    kit.stylized_material(
        "Accent_Red", "red", shade_key="red_shade",
        pattern=kit.speckle_pattern(scale=7.0, amount=0.20, tint=kit.col("gold")),
        edge_amount=0.26, roughness=0.70, bevel_radius=0.30,
    )
    kit.stylized_material(
        "Accent_Blue", "blue", shade_key="blue_shade",
        pattern=kit.speckle_pattern(scale=7.0, amount=0.20, tint=kit.col("cream_trim")),
        edge_amount=0.26, roughness=0.70, bevel_radius=0.30,
    )
    kit.stylized_material(
        "Awning_Stripe", "red", shade_key="red_shade",
        pattern=kit.stripe_pattern(width=2.4, other=kit.col("cream_trim"), axis="X"),
        edge_amount=0.20, gradient_amount=0.14, ao_amount=0.45, roughness=0.82, bevel_radius=0.25,
    )
    kit.stylized_material(
        "Canopy_Stripe", "blue", shade_key="blue_shade",
        pattern=kit.stripe_pattern(width=3.0, other=kit.col("cream_trim"), axis="X"),
        edge_amount=0.20, gradient_amount=0.14, ao_amount=0.45, roughness=0.82, bevel_radius=0.25,
    )
    kit.stylized_material(
        "Grass", "grass", shade_key="grass_shade",
        pattern=kit.turf_pattern(light=kit.col("grass_light"), shade=kit.col("grass_shade")),
        edge_key="grass_light", edge_amount=0.24, gradient_amount=0.0, ao_amount=0.50,
        roughness=0.97, bevel_radius=0.60, bump_strength=0.20,
    )
    kit.stylized_material(
        "Soil", "soil", shade_key="soil_shade",
        pattern=kit.block_pattern(scale=1.6, mortar=kit.col("soil_shade"), light=kit.col("wood_light")),
        edge_key="wood_light", edge_amount=0.22, gradient_amount=0.42, roughness=0.96,
        bevel_radius=0.55, bump_strength=0.60,
    )
    kit.stylized_material(
        "Asphalt", "asphalt", shade_key="asphalt_shade",
        pattern=kit.pebble_pattern(scale=7.0, amount=0.38, tint=kit.col("asphalt_light"), dark=kit.col("asphalt_shade")),
        edge_key="asphalt_light", edge_amount=0.16, gradient_amount=0.0, ao_amount=0.55,
        roughness=0.95, bevel_radius=0.40, bump_strength=0.22,
    )
    kit.stylized_material(
        "Concrete", "concrete", shade_key="concrete_shade",
        pattern=kit.speckle_pattern(scale=5.0, amount=0.30, tint=kit.col("cream_trim")),
        edge_amount=0.20, gradient_amount=0.18, roughness=0.90, bevel_radius=0.40,
    )
    kit.stylized_material(
        "Sidewalk", "sidewalk", shade_key="sidewalk_shade",
        pattern=kit.speckle_pattern(scale=3.0, amount=0.26, tint=kit.col("concrete")),
        edge_amount=0.14, gradient_amount=0.0, ao_amount=0.45, roughness=0.94, bevel_radius=0.40,
    )
    kit.stylized_material(
        "Leaf", "leaf", shade_key="leaf_shade",
        pattern=kit.speckle_pattern(scale=6.0, amount=0.50, tint=kit.col("leaf_light")),
        edge_key="leaf_light", edge_amount=0.30, gradient_amount=0.26, ao_amount=0.55,
        roughness=0.94, bevel_radius=0.70,
    )
    kit.stylized_material(
        "Tyre", "tyre", shade_key="asphalt_shade",
        pattern=kit.speckle_pattern(scale=14.0, amount=0.18, tint=kit.col("asphalt_light")),
        edge_key="asphalt_light", edge_amount=0.24, roughness=0.90, bevel_radius=0.20,
    )
    for key, name in (
        ("red", "Car_Red"), ("blue", "Car_Blue"), ("gold", "Car_Gold"),
        ("cream_trim", "Car_Cream"), ("roof", "Car_Teal"),
    ):
        kit.stylized_material(
            name, key,
            pattern=kit.speckle_pattern(scale=9.0, amount=0.16, tint=kit.col("cream_trim")),
            edge_amount=0.34, gradient_amount=0.20, ao_amount=0.40,
            roughness=0.34, bevel_radius=0.30,
        )
    kit.flat_material("Glass_Dark", "glass_dark", roughness=0.10)
    kit.flat_material("Backdrop", "backdrop", roughness=1.0)


# --------------------------------------------------------------------------
# props — kept deliberately blocky
# --------------------------------------------------------------------------

def low_car(name, collection, location, body, *, rotation_z=0.0, parent=None):
    """36 triangles. At the locked zoom a car is a few dozen pixels."""
    root = bpy.data.objects.new(name, None)
    root.location = location
    root.rotation_euler = (0, 0, rotation_z)
    kit.link(root, collection, parent)
    kit.box(f"{name}_Body", collection, (9.4, 4.2, 2.1), (0, 0, 1.95), kit.mat(body), parent=root)
    kit.box(f"{name}_Cabin", collection, (4.8, 3.7, 1.9), (-0.6, 0, 3.60), kit.mat(body), parent=root)
    kit.box(f"{name}_Wheels", collection, (7.4, 4.4, 1.3), (0, 0, 0.70), kit.mat("Tyre"), parent=root)
    return root


def low_tree(name, collection, location, *, height=12.0, parent=None):
    """24 triangles."""
    trunk = height * 0.42
    kit.prism(
        f"{name}_Trunk", collection, 0.95, trunk, (location[0], location[1], location[2] + trunk / 2),
        kit.mat("Timber"), sides=4, parent=parent, radius_top=0.7,
    )
    kit.octahedron(
        f"{name}_Canopy_A", collection, height * 0.34,
        (location[0], location[1], location[2] + trunk + height * 0.26), kit.mat("Leaf"),
        scale=(1.0, 1.0, 0.9), parent=parent,
    )
    kit.octahedron(
        f"{name}_Canopy_B", collection, height * 0.24,
        (location[0] + 0.5, location[1] + 0.4, location[2] + trunk + height * 0.50), kit.mat("Leaf"),
        scale=(1.0, 1.0, 0.9), parent=parent,
    )


def bunting(name, collection, start, end, *, sag=3.2, count=8, parent=None):
    """A flat ribbon rope plus single-triangle pennants: 22 triangles a run."""
    from mathutils import Vector

    a, b = Vector(start), Vector(end)
    segments = 3
    points = []
    for i in range(segments + 1):
        t = i / segments
        point = a.lerp(b, t)
        point.z -= sag * math.sin(math.pi * t)
        points.append(point)
    for i in range(segments):
        p, q = points[i], points[i + 1]
        kit.quad(
            f"{name}_Rope_{i}", collection,
            [
                (p.x, p.y, p.z + 0.16), (q.x, q.y, q.z + 0.16),
                (q.x, q.y, q.z - 0.16), (p.x, p.y, p.z - 0.16),
            ],
            kit.mat("Timber"), parent=parent,
        )

    flags = ("Accent_Red", "Gold_Trim", "Cream_Trim", "Accent_Blue")
    direction = (b - a)
    direction.z = 0
    direction.normalize()
    for i in range(count):
        t = (i + 0.5) / count
        centre = a.lerp(b, t)
        centre.z -= sag * math.sin(math.pi * t)
        left = centre - direction * 0.85
        right = centre + direction * 0.85
        tip = centre - Vector((0, 0, 2.1))
        mesh = kit.mesh_from(f"{name}_Flag_{i}", [tuple(left), tuple(right), tuple(tip)], [(0, 1, 2)])
        obj = bpy.data.objects.new(f"{name}_Flag_{i}", mesh)
        obj.data.materials.append(kit.mat(flags[i % len(flags)]))
        kit.link(obj, collection, parent)


# --------------------------------------------------------------------------
# the shop
# --------------------------------------------------------------------------

def build_shop() -> bpy.types.Collection:
    collection = bpy.data.collections.new("LowPoly_Used_Car_Shop_3x3")
    bpy.context.scene.collection.children.link(collection)
    root = bpy.data.objects.new("LowPoly_Used_Car_Shop_3x3_Root", None)
    root.empty_display_size = 4.0
    collection.objects.link(root)
    root["city_asset_id"] = "playerMediumDealer"
    root["footprint_cells"] = [CELLS, CELLS]
    root["world_footprint"] = [LOT, LOT]
    root["origin"] = kit.ORIGIN
    root["front_edge"] = kit.FRONT_EDGE
    root["art_style"] = "lowpoly_kit_v1"

    # --- lot surfaces only, laid straight onto the shared city ground
    kit.plane("Lot_Verge", collection, (LOT, LOT), (0, 0, 0.04), kit.mat("Grass"), parent=root)
    kit.plane("Yard", collection, (52.0, 40.0), (0, -7.0, YARD_TOP), kit.mat("Asphalt"), parent=root)
    kit.plane("Pad", collection, (46.0, 25.0), (0, 15.8, PAD_TOP), kit.mat("Concrete"), parent=root)

    # --- building shell: stone plinth + battered wall in one loft (18 tris)
    kit.lofted(
        "Shell", collection,
        ((0.00, 20.30, 10.60), (BASE_H, 19.90, 10.20), (BASE_H + WALL_H, 18.80, 9.30)),
        (0, BUILDING_Y, PAD_TOP), [kit.mat("Stone_Base"), kit.mat("Wall")],
        span_materials=[0, 1], parent=root,
    )
    # The showroom is the one facade element worth its own geometry.
    kit.box(
        "Showroom", collection, (23.0, 1.6, 9.4), (-7.0, BUILDING_Y - 10.0, BASE_TOP + 5.6),
        kit.mat("Showroom"), parent=root,
    )
    kit.box(
        "Showroom_Head", collection, (24.4, 1.9, 1.6), (-7.0, BUILDING_Y - 10.1, BASE_TOP + 11.1),
        kit.mat("Cream_Trim"), parent=root,
    )
    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.box(
                f"Corner_Post_{sx}_{sy}", collection, (2.5, 2.5, WALL_H),
                (sx * 19.1, BUILDING_Y + sy * 9.6, BASE_TOP + WALL_H / 2),
                kit.mat("Timber"), parent=root,
            )

    # --- roof: the fascia band is the bottom span of the same loft (26 tris)
    kit.lofted(
        "Roof", collection,
        ((-2.10, 23.00, 12.80), (0.00, 23.00, 12.80), (1.10, 21.60, 11.45), (9.60, 8.50, 0.60)),
        (0, BUILDING_Y, EAVE_Z), [kit.mat("Cream_Trim"), kit.mat("Roof")],
        span_materials=[0, 1, 1], cap_bottom=False, parent=root,
    )
    kit.box("Roof_Sign_Border", collection, (26.8, 1.0, 9.6), (0, BUILDING_Y - 7.3, EAVE_Z + 5.3), kit.mat("Accent_Blue"),
            rotation=(math.radians(-14), 0, 0), parent=root)
    kit.box("Roof_Sign", collection, (24.6, 1.0, 7.6), (0, BUILDING_Y - 8.0, EAVE_Z + 5.5), kit.mat("Cream_Trim"),
            rotation=(math.radians(-14), 0, 0), parent=root)
    kit.box("Roof_Sign_Emblem", collection, (5.4, 1.0, 5.4), (0, BUILDING_Y - 8.7, EAVE_Z + 5.6), kit.mat("Gold_Trim"),
            rotation=(math.radians(-14), 0, 0), parent=root)

    # --- storefront furniture
    kit.box("Awning", collection, (24.6, 6.4, 1.5), (-7.0, BUILDING_Y - 13.0, BASE_TOP + 12.5),
            kit.mat("Awning_Stripe"), rotation=(math.radians(-11), 0, 0), parent=root)
    kit.box("Door_Canopy", collection, (13.0, 6.0, 1.4), (12.6, BUILDING_Y - 12.6, BASE_TOP + 8.4),
            kit.mat("Roof"), rotation=(math.radians(-14), 0, 0), parent=root)
    kit.box("Door", collection, (7.4, 1.4, 8.0), (12.6, BUILDING_Y - 10.0, BASE_TOP + 4.0),
            kit.mat("Timber"), parent=root)

    # --- display pavilion
    px, py = -15.0, -17.5
    kit.plane("Podium", collection, (21.0, 14.0), (px, py, YARD_TOP + 0.05), kit.mat("Concrete"), parent=root)
    for index, (dx, dy) in enumerate(((-9.0, -5.6), (9.0, -5.6), (-9.0, 5.6), (9.0, 5.6))):
        kit.box(f"Pavilion_Post_{index}", collection, (1.8, 1.8, 7.0), (px + dx, py + dy, YARD_TOP + 3.5),
                kit.mat("Timber"), parent=root)
    kit.lofted(
        "Pavilion_Canopy", collection,
        ((-1.20, 11.40, 8.00), (0.00, 11.40, 8.00), (2.40, 4.60, 1.00)),
        (px, py, YARD_TOP + 7.0), [kit.mat("Cream_Trim"), kit.mat("Canopy_Stripe")],
        span_materials=[0, 1], cap_bottom=False, parent=root,
    )
    low_car("Display_Car_A", collection, (px - 5.0, py + 0.2, YARD_TOP), "Car_Red", rotation_z=math.radians(-96), parent=root)
    low_car("Display_Car_B", collection, (px + 5.0, py + 0.2, YARD_TOP), "Car_Cream", rotation_z=math.radians(-84), parent=root)

    # --- forecourt
    low_car("Yard_Car_A", collection, (11.8, -18.0, YARD_TOP), "Car_Blue", rotation_z=math.radians(-90), parent=root)
    low_car("Yard_Car_B", collection, (23.0, -4.0, YARD_TOP), "Car_Gold", rotation_z=math.radians(188), parent=root)

    sx, sy = 24.6, -24.6
    kit.box("Pylon_Post", collection, (2.0, 2.0, 9.4), (sx, sy, YARD_TOP + 4.7), kit.mat("Timber"), parent=root)
    kit.box("Pylon_Board", collection, (10.4, 1.4, 8.4), (sx, sy, YARD_TOP + 11.5), kit.mat("Cream_Trim"),
            rotation=(0, 0, math.radians(42)), parent=root)
    kit.box("Pylon_Emblem", collection, (4.6, 1.9, 4.6), (sx, sy, YARD_TOP + 12.4), kit.mat("Gold_Trim"),
            rotation=(0, 0, math.radians(42)), parent=root)

    pole_x, pole_y = -26.0, -26.0
    kit.box("Bunting_Pole", collection, (1.7, 1.7, 13.0), (pole_x, pole_y, YARD_TOP + 6.5), kit.mat("Timber"), parent=root)
    bunting("Bunting_Front", collection, (pole_x, pole_y, YARD_TOP + 12.4), (sx, sy, YARD_TOP + 14.0),
            sag=3.6, count=8, parent=root)
    bunting("Bunting_Right", collection, (sx, sy, YARD_TOP + 14.0), (19.2, BUILDING_Y - 9.6, WALL_TOP - 1.6),
            sag=3.2, count=7, parent=root)

    # --- landscaping and clutter
    low_tree("Tree_L", collection, (-24.6, 23.0, GROUND), height=12.5, parent=root)
    low_tree("Tree_R", collection, (24.6, 23.0, GROUND), height=11.0, parent=root)
    for index, x in enumerate((-12.0, -2.0, 8.0)):
        kit.octahedron(f"Hedge_{index}", collection, 2.1, (x, 27.4, GROUND + 1.72), kit.mat("Leaf"),
                       scale=(1.25, 1.0, 0.8), parent=root)
    for name, x in (("Planter_L", 7.4), ("Planter_R", 18.6)):
        kit.octahedron(name, collection, 2.0, (x, BUILDING_Y - 13.6, PAD_TOP + 1.85), kit.mat("Leaf"),
                       scale=(1.1, 1.1, 0.9), parent=root)
    kit.prism("Tyres", collection, 1.8, 3.0, (-25.2, 6.6, YARD_TOP + 1.5), kit.mat("Tyre"), sides=6, parent=root)
    kit.prism("Drum_A", collection, 1.4, 3.4, (25.4, 6.4, YARD_TOP + 1.7), kit.mat("Accent_Blue"), sides=6, parent=root)
    kit.prism("Drum_B", collection, 1.4, 3.4, (22.6, 8.0, YARD_TOP + 1.7), kit.mat("Accent_Red"), sides=6, parent=root)
    return collection


# --------------------------------------------------------------------------
# scenes
# --------------------------------------------------------------------------

CELL_ROAD = kit.CELL


def presentation_tile(collection: bpy.types.Collection) -> None:
    """A show stand for the solo renders only.

    The shipping asset has no terrain of its own, but a single building
    floating on a backdrop reads badly, so the beauty shots get a tile that
    lives in the render rig and is excluded from the triangle budget.
    """
    kit.lofted(
        "Presentation_Tile", collection,
        ((-SOIL_H - 0.85, HALF - 1.3, HALF - 1.3), (-0.85, HALF - 1.3, HALF - 1.3),
         (-0.85, HALF, HALF), (0.0, HALF, HALF)),
        (0, 0, 0), [kit.mat("Soil"), kit.mat("Grass")],
        span_materials=[0, 0, 1],
    )


def make_district_scene(samples: int, tris: int, design: bpy.types.Collection) -> bpy.types.Scene:
    """A city block on continuous ground, so map-scale cost and read are visible."""
    scene, rig = kit.make_scene(
        "Scene_District", None, PREVIEW_DIR / "lowpoly_district.png",
        width=1800, height=1000,
        camera_location=kit.game_camera_location(1400.0), target=(0, 0, 14.0),
        ortho_scale=800.0, samples=samples, backdrop=(2400, 2400),
    )
    scene.render.resolution_y = 1300
    instances = bpy.data.collections.new("District_Instances")
    scene.collection.children.link(instances)

    columns, rows = 7, 6
    pitch = LOT + CELL_ROAD
    extent = max(columns, rows) * pitch + pitch

    # One continuous ground, exactly as the real map would be chunked.
    kit.plane("District_Ground", instances, (extent, extent), (0, 0, 0.0), kit.mat("Sidewalk"))
    for index in range(columns + 1):
        x = (index - columns / 2) * pitch
        kit.plane(f"Road_V_{index}", instances, (CELL_ROAD, extent), (x, 0, 0.02), kit.mat("Asphalt"))
    for index in range(rows + 1):
        y = (index - rows / 2) * pitch
        kit.plane(f"Road_H_{index}", instances, (extent, CELL_ROAD), (0, y, 0.03), kit.mat("Asphalt"))

    count = 0
    for row in range(rows):
        for column in range(columns):
            instance = bpy.data.objects.new(f"District_{column}_{row}", None)
            instance.instance_type = "COLLECTION"
            instance.instance_collection = design
            instance.location = (
                (column - (columns - 1) / 2) * pitch,
                (row - (rows - 1) / 2) * pitch,
                0,
            )
            instance.rotation_euler = (0, 0, math.radians(90 * ((column * 3 + row * 5) % 4)))
            instances.objects.link(instance)
            count += 1

    print(f"[district] {count} lots x {tris} tris = {count * tris} triangles in view")
    return scene


def parse_args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return {"quick": "--quick" in argv, "bake": "--no-bake" not in argv}


def main() -> None:
    options = parse_args()
    quick = options["quick"]
    samples = 48 if quick else 256
    scale = 0.5 if quick else 1.0
    bake_samples = 24 if quick else 64

    for directory in (OUTPUT_DIR, PREVIEW_DIR, EXPORT_DIR):
        directory.mkdir(parents=True, exist_ok=True)

    kit.reset_file()
    build_materials()
    design = build_shop()
    tris = kit.validate(design, cells=CELLS, triangle_budget=TRIANGLE_BUDGET)
    bpy.context.scene.collection.children.unlink(design)

    def res(w, h):
        return int(w * scale), int(h * scale)

    width, height = res(1100, 1000)
    game_scene, game_rig = kit.make_scene(
        "Scene_GameCamera", design, PREVIEW_DIR / "lowpoly_used_car_shop_game_camera.png",
        width=width, height=height,
        camera_location=kit.game_camera_location(220.0), target=(0, 0, 6.0),
        ortho_scale=82.0, samples=samples,
    )
    presentation_tile(game_rig)
    kit.render_scene(game_scene)

    width, height = res(1500, 1000)
    close_scene, close_rig = kit.make_scene(
        "Scene_Storefront", design, PREVIEW_DIR / "lowpoly_used_car_shop_storefront.png",
        width=width, height=height,
        camera_location=(34, -128, 46), target=(1.0, 2.0, 11.0),
        ortho_scale=None, samples=samples, focal=135.0,
    )
    presentation_tile(close_rig)
    kit.render_scene(close_scene)

    district = make_district_scene(samples, tris, design)
    district.render.resolution_x, district.render.resolution_y = res(1800, 1300)
    kit.render_scene(district)

    if options["bake"]:
        merged, bake_scene = kit.bake_and_export(
            design, "lowpoly_used_car_shop_3x3", EXPORT_DIR,
            resolution=TEXTURE_SIZE, samples=bake_samples,
        )
        check, rig = kit.make_scene(
            "Scene_BakedCheck", None, PREVIEW_DIR / "lowpoly_used_car_shop_baked_check.png",
            width=res(1100, 1000)[0], height=res(1100, 1000)[1],
            camera_location=kit.game_camera_location(220.0), target=(0, 0, 6.0),
            ortho_scale=82.0, samples=samples,
        )
        instance = merged.copy()
        instance.data = merged.data
        rig.objects.link(instance)
        presentation_tile(rig)
        kit.render_scene(check)

    kit.activate_scene(game_scene)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), compress=True)
    print(f"[done] saved {BLEND_PATH}")


if __name__ == "__main__":
    main()
