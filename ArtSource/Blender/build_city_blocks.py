"""Low-poly city kit: the first batch of ambient city buildings.

These are real catalog assets, not test masses. Each one is named after its
`CityAssetID`, so dropping the exported `.usdz` into
`UsedCarCity/Art.scnassets/CityBuildings/` is all the runtime needs —
`CityBuildingFactory.loadAuthoredAsset` already prefers an authored file over
the procedural fallback, and `Art.scnassets` is a folder wrapper in the Xcode
project, so no project edit is required either.

Heights are the *rendered* height, `nominalHeight x CityAssetScale
.heightMultiplier(category)`, because the authored path ignores the runtime's
height hint.

Run with::

    blender --background --factory-startup \
        --python ArtSource/Blender/build_city_blocks.py

Flags after ``--``: ``--quick``, ``--no-bake``, ``--only <assetId>``.
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
PREVIEW_DIR = OUTPUT_DIR / "previews"
EXPORT_DIR = OUTPUT_DIR / "exports"

GROUND = 0.0
PAVE = 0.10
PAD = 0.26


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def build_materials() -> None:
    kit.stylized_material(
        "Brick_Wall", "brick", shade_key="brick_dark",
        pattern=kit.facade_pattern(
            storey=5.4, bay=4.6, ground=7.4, window_w=2.2, window_h=3.4,
            surround="recessed", surround_width=0.40, sill=True, lintel=True,
            glazing_bars="cross", wall_texture="brick",
            string_course=0.8, cornice=1.4, parapet=0.05,
            ground_mode="shopfront", door_chance=0.34, lit_fraction=0.34,
            trim=kit.col("cream_trim"), accent=kit.col("red_shade"),
        ),
        edge_amount=0.14, crevice_amount=0.20, gradient_amount=0.16,
        ao_amount=0.42, roughness=0.88, bevel_radius=0.5, bump_strength=0.0,
    )
    kit.stylized_material(
        "Stucco_Wall", "sand_wall", shade_key="sand_wall_shade",
        pattern=kit.facade_pattern(
            storey=5.6, bay=5.0, ground=7.0, window_w=2.4, window_h=3.6,
            surround="raised", surround_width=0.60, sill=True,
            glazing_bars="grid", wall_texture="stucco",
            string_course=1.0, cornice=1.8, parapet=0.07,
            ground_mode="shopfront", door_chance=0.30, lit_fraction=0.30,
            trim=kit.col("cream_trim"), accent=kit.col("blue_shade"),
        ),
        edge_amount=0.14, crevice_amount=0.20, gradient_amount=0.16,
        ao_amount=0.42, roughness=0.86, bevel_radius=0.5, bump_strength=0.0,
    )
    kit.stylized_material(
        "Render_Wall", "render_grey", shade_key="concrete_shade",
        pattern=kit.facade_pattern(
            storey=5.2, bay=4.4, ground=6.2, window_w=2.3, window_h=3.0,
            surround="raised", surround_width=0.45, sill=True,
            glazing_bars="transom", wall_texture="stucco",
            string_course=0.7, cornice=1.2, parapet=0.06,
            ground_mode="plinth", lit_fraction=0.28,
            trim=kit.col("cream_trim"),
        ),
        edge_amount=0.14, gradient_amount=0.18, ao_amount=0.42,
        roughness=0.86, bevel_radius=0.5, bump_strength=0.0,
    )
    kit.stylized_material(
        "Tower_Glass", "office_spandrel",
        pattern=kit.curtainwall_pattern(storey=4.4, mullion=2.8, lit_fraction=0.24),
        edge_amount=0.06, gradient_amount=0.0, ao_amount=0.22,
        roughness=0.45, bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Shed_Metal", "metal_shed", shade_key="metal_shed_dark",
        pattern=kit.facade_pattern(
            storey=6.0, bay=6.0, ground=9.0, window_w=3.4, window_h=1.6,
            surround="flush", sill=False, glazing_bars="none",
            wall_texture="plain", string_course=0.0, cornice=0.0, parapet=0.05,
            ground_mode="dock", lit_fraction=0.10,
            wall=kit.col("metal_shed"), trim=kit.col("concrete"),
        ),
        edge_amount=0.14, gradient_amount=0.20, ao_amount=0.45,
        roughness=0.80, bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Shed_Roof", "metal_shed_dark", shade_key="asphalt_shade",
        pattern=kit.corrugated_pattern(pitch=3.2, rust=0.10),
        edge_amount=0.16, gradient_amount=0.06, ao_amount=0.38,
        roughness=0.78, bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Flat_Roof", "membrane", shade_key="asphalt_shade",
        pattern=kit.flatroof_pattern(kit_density=0.45, seam_pitch=7.0, parapet_inset=0.13),
        edge_amount=0.14, gradient_amount=0.06, ao_amount=0.40,
        roughness=0.86, bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Tower_Roof", "membrane", shade_key="asphalt_shade",
        pattern=kit.flatroof_pattern(kit_density=0.62, seam_pitch=6.0, parapet_inset=0.16),
        edge_amount=0.14, gradient_amount=0.06, ao_amount=0.40,
        roughness=0.86, bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Slate_Roof", "roof_slate", shade_key="roof_shade",
        pattern=kit.shingle_pattern(course=1.6, light=kit.col("render_grey"), dark=kit.col("roof_shade")),
        edge_key="render_grey", edge_amount=0.22, gradient_amount=0.10,
        ao_amount=0.42, roughness=0.82, bevel_radius=0.45, bump_strength=0.0,
    )
    kit.stylized_material(
        "Trim", "cream_trim", shade_key="cream_shade",
        pattern=kit.speckle_pattern(scale=0.45, amount=0.22, tint=kit.col("sand_speckle")),
        edge_amount=0.18, gradient_amount=0.18, ao_amount=0.45,
        roughness=0.82, bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Pave", "sidewalk", shade_key="sidewalk_shade",
        pattern=kit.speckle_pattern(scale=0.3, amount=0.24, tint=kit.col("concrete")),
        edge_amount=0.10, gradient_amount=0.0, ao_amount=0.40, roughness=0.94,
        bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Yard", "asphalt", shade_key="asphalt_shade",
        pattern=kit.lotmarking_pattern(bay_width=9.0, bay_depth=18.0, aisle=12.0, kerb_inset=0.05),
        edge_amount=0.12, gradient_amount=0.0, ao_amount=0.48, roughness=0.95,
        bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Verge", "grass", shade_key="grass_shade",
        pattern=kit.turf_pattern(light=kit.col("grass_light"), shade=kit.col("grass_shade")),
        edge_key="grass_light", edge_amount=0.20, gradient_amount=0.0,
        ao_amount=0.46, roughness=0.97, bevel_radius=0.5, bump_strength=0.0,
    )
    kit.stylized_material(
        "Leaf", "leaf", shade_key="leaf_shade",
        pattern=kit.speckle_pattern(scale=0.7, amount=0.45, tint=kit.col("leaf_light")),
        edge_key="leaf_light", edge_amount=0.26, gradient_amount=0.22,
        ao_amount=0.50, roughness=0.94, bevel_radius=0.6, bump_strength=0.0,
    )
    kit.stylized_material(
        "Timber", "wood", shade_key="wood_shade",
        pattern=kit.plank_pattern(scale=1.0, light=kit.col("wood_light"), dark=kit.col("wood_shade")),
        edge_key="wood_light", edge_amount=0.20, gradient_amount=0.24,
        ao_amount=0.50, roughness=0.88, bevel_radius=0.3, bump_strength=0.0,
    )
    kit.stylized_material(
        "Steel", "chrome", shade_key="asphalt_shade",
        pattern=kit.speckle_pattern(scale=0.8, amount=0.16, tint=kit.col("cream_trim")),
        edge_amount=0.28, gradient_amount=0.20, ao_amount=0.48,
        roughness=0.45, bevel_radius=0.25, bump_strength=0.0,
    )
    kit.flat_material("Backdrop", "backdrop", roughness=1.0)


def base_ground(collection, root, lot_x, lot_y, *, paved=(0.0, 0.0), pave_material="Pave"):
    kit.plane("Verge", collection, (lot_x, lot_y), (0, 0, 0.04), kit.mat("Verge"), parent=root)
    if paved[0] > 0:
        kit.plane("Pave", collection, paved, (0, 0, PAVE), kit.mat(pave_material), parent=root)


def street_trees(collection, root, lot_x, lot_y, count=2):
    for index in range(count):
        x = -lot_x / 2 + 6.0 + index * (lot_x - 12.0) / max(count - 1, 1)
        kit.prism(f"Tree_{index}_Trunk", collection, 0.9, 6.0, (x, -lot_y / 2 + 5.0, 3.0),
                  kit.mat("Timber"), sides=4, parent=root)
        kit.octahedron(f"Tree_{index}_Canopy", collection, 4.4, (x, -lot_y / 2 + 5.0, 9.4),
                       kit.mat("Leaf"), scale=(1.0, 1.0, 1.15), parent=root)


# --------------------------------------------------------------------------
# assets
# --------------------------------------------------------------------------

def build_downtown_office(collection, root, lot_x, lot_y):
    """153 units of curtain wall on a shopfront podium."""
    base_ground(collection, root, lot_x, lot_y, paved=(lot_x - 4.0, lot_y - 4.0))
    kit.parapet_box("Podium", collection, (lot_x - 12.0, lot_y - 12.0, 22.0), (0, 0, PAD),
                    [kit.mat("Render_Wall"), kit.mat("Flat_Roof")], parapet=1.8, inset=1.2, parent=root)
    rings = (
        (0.0, 27.0, 27.0), (90.0, 25.5, 25.5), (90.0, 22.0, 22.0),
        (147.0, 21.0, 21.0), (147.0, 23.0, 23.0), (153.0, 23.0, 23.0),
    )
    kit.setback_tower("Tower", collection, rings, (0, 0, PAD + 20.0),
                      [kit.mat("Tower_Glass"), kit.mat("Trim")],
                      span_materials=[0, 0, 0, 1, 1], parent=root)
    kit.plane("Tower_Roof", collection, (44.0, 44.0), (0, 0, PAD + 172.6), kit.mat("Tower_Roof"), parent=root)
    street_trees(collection, root, lot_x, lot_y, 3)


def build_downtown_apartment(collection, root, lot_x, lot_y):
    """135 units, brick, balcony bands at every storey."""
    base_ground(collection, root, lot_x, lot_y, paved=(lot_x - 8.0, lot_y - 8.0))
    kit.parapet_box("Slab", collection, (lot_x - 18.0, lot_y - 26.0, 135.0), (0, 4.0, PAD),
                    [kit.mat("Brick_Wall"), kit.mat("Flat_Roof")], parapet=2.6, inset=1.6, parent=root)
    kit.parapet_box("Wing", collection, (lot_x - 34.0, 18.0, 46.0), (0, -lot_y / 2 + 13.0, PAD),
                    [kit.mat("Render_Wall"), kit.mat("Flat_Roof")], parapet=1.6, inset=1.0, parent=root)
    street_trees(collection, root, lot_x, lot_y, 2)


def build_commercial_shopping(collection, root, lot_x, lot_y):
    """72 units, three storeys of stucco over a shopfront."""
    base_ground(collection, root, lot_x, lot_y, paved=(lot_x - 4.0, lot_y - 4.0))
    kit.parapet_box("Block", collection, (lot_x - 10.0, lot_y - 20.0, 72.0), (0, 5.0, PAD),
                    [kit.mat("Stucco_Wall"), kit.mat("Flat_Roof")], parapet=2.4, inset=1.5, parent=root)
    kit.box("Awning", collection, (lot_x - 14.0, 5.0, 1.2), (0, -lot_y / 2 + 13.0, PAD + 8.6),
            kit.mat("Trim"), parent=root)
    for index, sx in enumerate((-1, 1)):
        kit.box(f"Awning_Post_{index}", collection, (0.8, 0.8, 8.6),
                (sx * (lot_x / 2 - 12.0), -lot_y / 2 + 15.0, PAD + 4.3), kit.mat("Steel"), parent=root)
    street_trees(collection, root, lot_x, lot_y, 3)


def build_residential_apartment(collection, root, lot_x, lot_y):
    """94 units, brick, no shopfront — a plinth instead."""
    base_ground(collection, root, lot_x, lot_y, paved=(lot_x - 22.0, lot_y - 22.0))
    kit.parapet_box("Block", collection, (lot_x - 22.0, lot_y - 30.0, 94.0), (0, 3.0, PAD),
                    [kit.mat("Brick_Wall"), kit.mat("Flat_Roof")], parapet=2.2, inset=1.4, parent=root)
    for index, sx in enumerate((-1, 1)):
        kit.octahedron(f"Shrub_{index}", collection, 2.6, (sx * 14.0, -lot_y / 2 + 8.0, 2.3),
                       kit.mat("Leaf"), scale=(1.25, 1.0, 0.85), parent=root)
    street_trees(collection, root, lot_x, lot_y, 2)


def build_residential_gable(collection, root, lot_x, lot_y):
    """58 units to the ridge: a pitched-roof house with a porch."""
    base_ground(collection, root, lot_x, lot_y, paved=(24.0, lot_y / 2))
    body_h = 38.0
    kit.lofted("Body", collection, ((0.0, 22.0, 15.0), (body_h, 21.4, 14.6)), (0, 4.0, PAD),
               [kit.mat("Stucco_Wall")], cap_bottom=False, cap_top=False, parent=root)
    kit.gable("Roof", collection, (43.0, 30.0, 19.6), (0, 4.0, PAD + body_h),
              [kit.mat("Slate_Roof")], ridge_axis="X", overhang=1.8, parent=root)
    kit.box("Porch_Roof", collection, (14.0, 7.0, 1.1), (0, -12.0, PAD + 12.6), kit.mat("Trim"), parent=root)
    for index, sx in enumerate((-1, 1)):
        kit.box(f"Porch_Post_{index}", collection, (0.9, 0.9, 12.6), (sx * 6.0, -14.6, PAD + 6.3),
                kit.mat("Timber"), parent=root)
    kit.box("Chimney", collection, (3.4, 3.4, 10.0), (13.0, 10.0, PAD + body_h + 8.0),
            kit.mat("Brick_Wall"), parent=root)
    for index, sx in enumerate((-1, 1)):
        kit.octahedron(f"Shrub_{index}", collection, 2.4, (sx * 16.0, -lot_y / 2 + 8.0, 2.15),
                       kit.mat("Leaf"), scale=(1.2, 1.0, 0.85), parent=root)
    street_trees(collection, root, lot_x, lot_y, 2)


def build_industrial_warehouse(collection, root, lot_x, lot_y):
    """68 units, a long corrugated shed with a truck yard in front."""
    kit.plane("Verge", collection, (lot_x, lot_y), (0, 0, 0.04), kit.mat("Verge"), parent=root)
    kit.plane("Yard", collection, (lot_x - 6.0, lot_y * 0.56), (0, -lot_y * 0.20, PAVE),
              kit.mat("Yard"), parent=root)
    shed_h = 50.0
    kit.lofted("Shed", collection, ((0.0, lot_x / 2 - 8.0, 22.0), (shed_h, lot_x / 2 - 8.6, 21.4)),
               (0, lot_y / 2 - 26.0, PAD), [kit.mat("Shed_Metal")],
               cap_bottom=False, cap_top=False, parent=root)
    kit.gable("Shed_Roof", collection, (lot_x - 16.0, 44.0, 18.0), (0, lot_y / 2 - 26.0, PAD + shed_h),
              [kit.mat("Shed_Roof")], ridge_axis="X", overhang=2.0, parent=root)
    kit.box("Office", collection, (26.0, 16.0, 26.0), (-lot_x / 2 + 20.0, lot_y / 2 - 52.0, PAD + 13.0),
            kit.mat("Render_Wall"), parent=root)
    for index in range(3):
        x = -lot_x / 2 + 34.0 + index * 34.0
        kit.box(f"Trailer_{index}", collection, (28.0, 9.0, 9.0), (x, -lot_y / 2 + 16.0, PAVE + 5.4),
                kit.mat("Trim"), parent=root)
        kit.box(f"Cab_{index}", collection, (8.0, 8.4, 7.0), (x - 18.0, -lot_y / 2 + 16.0, PAVE + 4.0),
                kit.mat("Steel"), parent=root)


ASSETS = {
    "downtownOffice": {"cells": (4, 4), "budget": 900, "texture": 512, "build": build_downtown_office},
    "downtownApartment": {"cells": (4, 4), "budget": 900, "texture": 512, "build": build_downtown_apartment},
    "commercialShopping": {"cells": (4, 4), "budget": 900, "texture": 512, "build": build_commercial_shopping},
    "residentialApartment": {"cells": (4, 4), "budget": 900, "texture": 512, "build": build_residential_apartment},
    "residentialGable": {"cells": (4, 4), "budget": 900, "texture": 512, "build": build_residential_gable},
    "industrialWarehouse": {"cells": (9, 4), "budget": 1400, "texture": 768, "build": build_industrial_warehouse},
}


def build_asset(name: str, spec: dict) -> bpy.types.Collection:
    width, depth = spec["cells"]
    lot_x, lot_y = kit.lot_size(width), kit.lot_size(depth)
    collection = bpy.data.collections.new(f"LowPoly_{name}")
    bpy.context.scene.collection.children.link(collection)
    root = bpy.data.objects.new(f"LowPoly_{name}_Root", None)
    root.empty_display_size = 4.0
    collection.objects.link(root)
    root["city_asset_id"] = name
    root["footprint_cells"] = [width, depth]
    root["world_footprint"] = [lot_x, lot_y]
    root["origin"] = kit.ORIGIN
    root["front_edge"] = kit.FRONT_EDGE
    root["art_style"] = "lowpoly_kit_v1"
    spec["build"](collection, root, lot_x, lot_y)
    return collection


def parse_args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    if "--only" in argv:
        index = argv.index("--only")
        if index + 1 < len(argv):
            only = argv[index + 1]
    return {"quick": "--quick" in argv, "bake": "--no-bake" not in argv, "only": only}


def main() -> None:
    options = parse_args()
    quick = options["quick"]
    samples = 48 if quick else 200
    scale = 0.5 if quick else 1.0
    bake_samples = 24 if quick else 64

    for directory in (OUTPUT_DIR, PREVIEW_DIR, EXPORT_DIR):
        directory.mkdir(parents=True, exist_ok=True)

    kit.reset_file("Scene_Blocks")
    build_materials()

    last = None
    for name, spec in ASSETS.items():
        if options["only"] not in (None, name):
            continue
        design = build_asset(name, spec)
        tris = kit.validate(design, cells=spec["cells"], triangle_budget=spec["budget"])
        bpy.context.scene.collection.children.unlink(design)

        span = max(kit.lot_size(spec["cells"][0]), kit.lot_size(spec["cells"][1]))
        scene, _ = kit.make_scene(
            f"Scene_{name}", design, PREVIEW_DIR / f"{name}_game_camera.png",
            width=int(1000 * scale), height=int(1100 * scale),
            camera_location=kit.game_camera_location(420.0), target=(0, 0, 30.0),
            ortho_scale=span * 2.3, samples=samples, backdrop=(900, 900),
        )
        kit.render_scene(scene)
        last = scene
        print(f"[block] {name}: {tris} triangles")

        if options["bake"]:
            kit.bake_and_export(
                design, name, EXPORT_DIR,
                resolution=spec["texture"], samples=bake_samples, bake_normal=False,
            )

    if last is not None:
        kit.activate_scene(last)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_DIR / "lowpoly_city_blocks.blend"), compress=True)
    print("[done] city blocks")


if __name__ == "__main__":
    main()
