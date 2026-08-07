"""Low-poly city kit: the modern used car dealership.

Authored against `ArtSource/Blender/UsedCarDealers/previews/dealer_a_modern_flagship.png`
— the glass-showroom flagship concept — rather than against the Clash-style
market stall in `build_lowpoly_used_car_shop.py`. A car dealership reads as a
dealership because of two things:

1. **the showroom is glass and you can see the stock inside it**, and
2. **there is a covered structure** — a canopy or service garage — beside it.

Both are here. The showroom interior is painted by `kit.showroom_pattern`
rather than modelled, and the garage is real geometry because its roof changes
the silhouette.

Builds two assets from one design:

* `playerMediumDealer` — 3x3, 700 triangles
* `playerLargeDealer`  — 4x4, 900 triangles

Run with::

    blender --background --factory-startup \
        --python ArtSource/Blender/build_lowpoly_car_dealer.py

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

YARD_TOP = 0.14
PAD_TOP = 0.34

VARIANTS = {
    "playerMediumDealer": {
        "cells": (3, 3),
        "budget": 700,
        "texture": 512,
        "scale": 0.75,
        "yard_cars": 7,
        "garage_cars": 2,
        "storeys": 2,
    },
    "playerLargeDealer": {
        "cells": (4, 4),
        "budget": 900,
        "texture": 512,
        "scale": 1.0,
        "yard_cars": 12,
        "garage_cars": 3,
        "storeys": 2,
    },
}


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def build_materials() -> None:
    kit.stylized_material(
        "Showroom_Glass", "showroom_glass",
        pattern=kit.showroom_pattern(mullion=4.6, transom=7.6, base=1.6, car_zone=10.5, car_pitch=9.6),
        edge_key="cream_trim", edge_amount=0.05, gradient_amount=0.0, ao_amount=0.20,
        roughness=0.48, bevel_radius=0.35, bump_strength=0.0,
    )
    kit.stylized_material(
        "Showroom_Glass_Side", "showroom_glass",
        # The flanks get the same glass without stock behind it, so the
        # silhouettes do not repeat identically on every elevation.
        pattern=kit.showroom_pattern(mullion=4.6, transom=7.6, base=1.6, reflection=0.26, show_cars=False),
        edge_key="cream_trim", edge_amount=0.05, gradient_amount=0.0, ao_amount=0.20,
        roughness=0.48, bevel_radius=0.35, bump_strength=0.0,
    )
    kit.stylized_material(
        "Dealer_Wall", "dealer_wall", shade_key="concrete_shade",
        pattern=kit.facade_pattern(
            storey=6.4, bay=5.2, ground=7.0,
            window_w=2.6, window_h=2.4, surround="flush",
            sill=False, glazing_bars="none", wall_texture="panel",
            string_course=0.0, cornice=0.0, parapet=0.05,
            ground_mode="same", lit_fraction=0.30,
            glass=kit.col("glass"), glass_unlit=kit.col("showroom_glass"),
            trim=kit.col("dealer_frame"),
        ),
        edge_amount=0.18, gradient_amount=0.16, ao_amount=0.45,
        roughness=0.80, bevel_radius=0.45, bump_strength=0.0,
    )
    kit.stylized_material(
        "Dealer_Roof", "membrane", shade_key="asphalt_shade",
        pattern=kit.flatroof_pattern(kit_density=0.35, seam_pitch=9.0, parapet_inset=0.16),
        edge_amount=0.16, gradient_amount=0.06, ao_amount=0.40,
        roughness=0.85, bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Canopy_Top", "blue", shade_key="blue_shade",
        pattern=kit.speckle_pattern(scale=0.4, amount=0.14, tint=kit.col("cream_trim")),
        edge_key="cream_trim", edge_amount=0.28, gradient_amount=0.10,
        ao_amount=0.35, roughness=0.55, bevel_radius=0.35, bump_strength=0.0,
    )
    kit.stylized_material(
        "Canopy_Soffit", "canopy_soffit", shade_key="asphalt_shade",
        pattern=kit.speckle_pattern(scale=0.5, amount=0.18, tint=kit.col("dealer_frame")),
        edge_amount=0.14, gradient_amount=0.0, ao_amount=0.55, roughness=0.90,
        bevel_radius=0.35, bump_strength=0.0,
    )
    kit.stylized_material(
        "Garage_Wall", "concrete", shade_key="concrete_shade",
        pattern=kit.facade_pattern(
            storey=5.0, bay=7.5, ground=8.4,
            window_w=3.0, window_h=1.4, surround="flush",
            sill=False, glazing_bars="none", wall_texture="panel",
            string_course=0.0, cornice=0.0, parapet=0.0,
            ground_mode="dock", lit_fraction=0.12,
            trim=kit.col("dealer_frame"), wall=kit.col("concrete"),
        ),
        edge_amount=0.16, gradient_amount=0.22, ao_amount=0.50,
        roughness=0.88, bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Sign_Band", "blue", shade_key="blue_shade",
        pattern=kit.speckle_pattern(scale=0.6, amount=0.16, tint=kit.col("cream_trim")),
        edge_key="cream_trim", edge_amount=0.30, gradient_amount=0.08,
        ao_amount=0.35, roughness=0.55, bevel_radius=0.3, bump_strength=0.0,
    )
    kit.stylized_material(
        "Metal_Column", "chrome", shade_key="asphalt_shade",
        pattern=kit.speckle_pattern(scale=0.8, amount=0.18, tint=kit.col("cream_trim")),
        edge_amount=0.32, gradient_amount=0.22, ao_amount=0.50,
        roughness=0.42, bevel_radius=0.25, bump_strength=0.0,
    )
    kit.stylized_material(
        "Yard", "asphalt", shade_key="asphalt_shade",
        pattern=kit.lotmarking_pattern(bay_width=4.8, bay_depth=9.6, aisle=8.0, kerb_inset=0.05),
        edge_key="asphalt_light", edge_amount=0.14, gradient_amount=0.0,
        ao_amount=0.50, roughness=0.95, bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Forecourt", "concrete", shade_key="concrete_shade",
        pattern=kit.speckle_pattern(scale=0.35, amount=0.26, tint=kit.col("cream_trim")),
        edge_amount=0.14, gradient_amount=0.0, ao_amount=0.40, roughness=0.92,
        bevel_radius=0.4, bump_strength=0.0,
    )
    kit.stylized_material(
        "Verge", "grass", shade_key="grass_shade",
        pattern=kit.turf_pattern(light=kit.col("grass_light"), shade=kit.col("grass_shade")),
        edge_key="grass_light", edge_amount=0.22, gradient_amount=0.0,
        ao_amount=0.48, roughness=0.97, bevel_radius=0.5, bump_strength=0.0,
    )
    kit.stylized_material(
        "Leaf", "leaf", shade_key="leaf_shade",
        pattern=kit.speckle_pattern(scale=0.7, amount=0.45, tint=kit.col("leaf_light")),
        edge_key="leaf_light", edge_amount=0.28, gradient_amount=0.24,
        ao_amount=0.52, roughness=0.94, bevel_radius=0.6, bump_strength=0.0,
    )
    kit.stylized_material(
        "Timber", "wood", shade_key="wood_shade",
        pattern=kit.plank_pattern(scale=1.0, light=kit.col("wood_light"), dark=kit.col("wood_shade")),
        edge_key="wood_light", edge_amount=0.22, gradient_amount=0.26,
        ao_amount=0.52, roughness=0.88, bevel_radius=0.3, bump_strength=0.0,
    )
    for key, name in (
        ("red", "Car_Red"), ("blue", "Car_Blue"), ("gold", "Car_Gold"),
        ("cream_trim", "Car_Cream"), ("roof", "Car_Teal"), ("chrome", "Car_Silver"),
    ):
        kit.stylized_material(
            name, key,
            pattern=kit.speckle_pattern(scale=1.2, amount=0.14, tint=kit.col("cream_trim")),
            edge_amount=0.34,
            # A strong base gradient is doing the job of modelled wheels: at
            # this size a car is ~12 px and only its dark underside reads.
            gradient_amount=0.55, ao_amount=0.42,
            roughness=0.34, bevel_radius=0.28, bump_strength=0.0,
        )
    kit.flat_material("Backdrop", "backdrop", roughness=1.0)


CAR_MATERIALS = ("Car_Red", "Car_Blue", "Car_Gold", "Car_Cream", "Car_Teal", "Car_Silver")


def stock_car(name, collection, location, material, *, rotation_z=0.0, parent=None, scale=1.0):
    """24 triangles: body and cabin. Wheels are the material's base gradient."""
    root = bpy.data.objects.new(name, None)
    root.location = location
    root.rotation_euler = (0, 0, rotation_z)
    root.scale = (scale, scale, scale)
    kit.link(root, collection, parent)
    kit.box(f"{name}_Body", collection, (9.2, 4.2, 2.7), (0, 0, 1.35), kit.mat(material), parent=root)
    kit.box(f"{name}_Cabin", collection, (5.0, 3.7, 1.9), (-0.6, 0, 3.35), kit.mat(material), parent=root)
    return root


# --------------------------------------------------------------------------
# the dealership
# --------------------------------------------------------------------------

def build_dealer(name: str, spec: dict) -> bpy.types.Collection:
    width, depth = spec["cells"]
    lot_x, lot_y = kit.lot_size(width), kit.lot_size(depth)
    hx, hy = lot_x / 2, lot_y / 2
    s = spec["scale"]

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

    # ---- ground -----------------------------------------------------------
    kit.plane("Verge", collection, (lot_x, lot_y), (0, 0, 0.04), kit.mat("Verge"), parent=root)
    kit.plane("Yard", collection, (lot_x - 6.0, lot_y * 0.62), (0, -hy * 0.34, YARD_TOP),
              kit.mat("Yard"), parent=root)

    # ---- showroom: a glass box with a deep flat roof ----------------------
    sw, sd, sh = 44.0 * s, 26.0 * s, 19.5 * s
    eave = 2.2 * s
    # The roof overhang, not the wall, is what has to stay inside the lot.
    scx, scy = hx - sw / 2 - eave - 0.6, hy - sd / 2 - eave - 0.6
    kit.plane("Showroom_Pad", collection, (sw + eave * 2, sd + eave * 2), (scx, scy, PAD_TOP),
              kit.mat("Forecourt"), parent=root)

    # Front and side glazing are separate objects so the front can carry the
    # stock silhouettes and the flanks cannot.
    kit.lofted(
        "Showroom_Mass", collection,
        ((0.0, sw / 2, sd / 2), (sh, sw / 2, sd / 2)),
        (scx, scy, PAD_TOP), [kit.mat("Showroom_Glass")],
        cap_bottom=False, cap_top=True, parent=root,
    )
    kit.box("Showroom_Flank", collection, (1.0, sd - 1.0, sh - 1.2),
            (scx + sw / 2 - 0.2, scy, PAD_TOP + sh / 2), kit.mat("Showroom_Glass_Side"), parent=root)
    kit.box("Showroom_Back", collection, (sw - 1.0, 1.0, sh - 1.2),
            (scx, scy + sd / 2 - 0.2, PAD_TOP + sh / 2), kit.mat("Dealer_Wall"), parent=root)

    roof_z = PAD_TOP + sh
    kit.lofted(
        "Showroom_Roof", collection,
        ((0.0, sw / 2 + eave, sd / 2 + eave), (0.5, sw / 2 + eave, sd / 2 + eave),
         (2.0, sw / 2 + eave * 0.8, sd / 2 + eave * 0.8)),
        (scx, scy, roof_z), [kit.mat("Canopy_Soffit"), kit.mat("Dealer_Roof")],
        span_materials=[0, 1], cap_bottom=True, cap_top=True, parent=root,
    )

    # Fascia sign across the front of the showroom, as in the reference.
    kit.box("Sign_Band", collection, (sw * 0.62, 1.3, 4.0 * s),
            (scx, scy - sd / 2 - 0.5, PAD_TOP + sh * 0.72), kit.mat("Sign_Band"), parent=root)
    kit.box("Sign_Panel", collection, (sw * 0.44, 0.8, 2.2 * s),
            (scx, scy - sd / 2 - 1.1, PAD_TOP + sh * 0.72), kit.mat("Forecourt"), parent=root)

    # Entrance canopy on two slim columns.
    ent_y = scy - sd / 2 - 3.4
    kit.box("Entry_Canopy", collection, (15.0 * s, 7.0, 1.1), (scx, ent_y, PAD_TOP + 9.6 * s),
            kit.mat("Sign_Band"), parent=root)
    for sx in (-1, 1):
        kit.box(f"Entry_Column_{sx}", collection, (1.0, 1.0, 9.6 * s),
                (scx + sx * (6.6 * s), ent_y - 2.6, PAD_TOP + 4.8 * s), kit.mat("Metal_Column"), parent=root)

    # ---- covered garage ---------------------------------------------------
    gw, gd, gh = 34.0 * s, 25.0 * s, 12.0 * s
    gcx, gcy = -hx + gw / 2 + 3.0 * s, hy - gd / 2 - 4.0 * s
    kit.plane("Garage_Floor", collection, (gw + 2.0, gd + 2.0), (gcx, gcy, YARD_TOP + 0.06),
              kit.mat("Forecourt"), parent=root)
    kit.lofted(
        "Garage_Roof", collection,
        ((0.0, gw / 2, gd / 2), (0.4, gw / 2, gd / 2), (1.8, gw / 2 - 0.8, gd / 2 - 0.8)),
        (gcx, gcy, gh), [kit.mat("Canopy_Soffit"), kit.mat("Canopy_Top")],
        span_materials=[0, 1], cap_bottom=True, cap_top=True, parent=root,
    )
    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.box(
                f"Garage_Column_{sx}_{sy}", collection, (1.5, 1.5, gh),
                (gcx + sx * (gw / 2 - 1.4), gcy + sy * (gd / 2 - 1.4), gh / 2),
                kit.mat("Metal_Column"), parent=root,
            )
    # Two enclosed sides turn the canopy into a garage rather than a carport.
    kit.box("Garage_Back", collection, (gw, 1.4, gh - 1.0), (gcx, gcy + gd / 2 - 0.7, (gh - 1.0) / 2),
            kit.mat("Garage_Wall"), parent=root)
    kit.box("Garage_Side", collection, (1.4, gd - 1.4, gh - 1.0),
            (gcx - gw / 2 + 0.7, gcy, (gh - 1.0) / 2), kit.mat("Garage_Wall"), parent=root)

    for index in range(spec["garage_cars"]):
        stock_car(
            f"Garage_Car_{index}", collection,
            (gcx - gw / 2 + 7.5 + index * 9.6, gcy - 2.5, YARD_TOP),
            CAR_MATERIALS[(index * 2 + 1) % len(CAR_MATERIALS)],
            rotation_z=math.radians(-90), parent=root, scale=0.92,
        )

    # ---- stock in the yard -------------------------------------------------
    rows = 2
    per_row = max(1, math.ceil(spec["yard_cars"] / rows))
    for index in range(spec["yard_cars"]):
        row, column = divmod(index, per_row)
        x = -hx + 10.0 + column * (11.0 * s)
        y = -hy + 9.0 + row * (13.0 * s)
        stock_car(
            f"Yard_Car_{index}", collection, (x, y, YARD_TOP),
            CAR_MATERIALS[index % len(CAR_MATERIALS)],
            rotation_z=math.radians(-90), parent=root, scale=0.95,
        )

    # ---- street furniture --------------------------------------------------
    px, py = hx - 6.0, -hy + 6.0
    kit.box("Pylon_Post", collection, (1.7, 1.7, 15.0), (px, py, 7.5), kit.mat("Metal_Column"), parent=root)
    kit.box("Pylon_Board", collection, (9.6, 1.6, 6.6), (px, py, 17.6),
            kit.mat("Sign_Band"), rotation=(0, 0, math.radians(42)), parent=root)
    for index, sy in enumerate((-1, 1)):
        lx = -hx + 3.0
        ly = -hy + 8.0 + (0 if sy < 0 else lot_y * 0.34)
        kit.box(f"Light_Pole_{index}", collection, (0.7, 0.7, 12.0), (lx, ly, 6.0),
                kit.mat("Metal_Column"), parent=root)
        kit.box(f"Light_Head_{index}", collection, (3.2, 1.2, 0.6), (lx + 1.2, ly, 12.2),
                kit.mat("Metal_Column"), parent=root)

    kit.octahedron("Tree_A", collection, 4.6, (hx - 5.2, hy - 5.2, 8.0), kit.mat("Leaf"),
                   scale=(1.0, 1.0, 1.15), parent=root)
    kit.prism("Tree_A_Trunk", collection, 0.9, 6.0, (hx - 5.2, hy - 5.2, 3.0), kit.mat("Timber"),
              sides=4, parent=root)
    for index, x in enumerate((-hx + 5.0, -hx + 12.0)):
        kit.octahedron(f"Shrub_{index}", collection, 2.2, (x, -hy + 4.0, 1.8), kit.mat("Leaf"),
                       scale=(1.2, 1.0, 0.8), parent=root)
    return collection


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

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
    samples = 48 if quick else 220
    scale = 0.5 if quick else 1.0
    bake_samples = 24 if quick else 64

    for directory in (OUTPUT_DIR, PREVIEW_DIR, EXPORT_DIR):
        directory.mkdir(parents=True, exist_ok=True)

    kit.reset_file("Scene_Dealer")
    build_materials()

    targets = {k: v for k, v in VARIANTS.items() if options["only"] in (None, k)}
    last_scene = None
    for name, spec in targets.items():
        design = build_dealer(name, spec)
        tris = kit.validate(design, cells=spec["cells"], triangle_budget=spec["budget"])
        bpy.context.scene.collection.children.unlink(design)

        scene, _ = kit.make_scene(
            f"Scene_{name}", design, PREVIEW_DIR / f"{name}_game_camera.png",
            width=int(1150 * scale), height=int(1050 * scale),
            camera_location=kit.game_camera_location(240.0), target=(0, 0, 8.0),
            ortho_scale=kit.lot_size(spec["cells"][0]) * 1.62, samples=samples,
        )
        kit.render_scene(scene)
        last_scene = scene

        close, _ = kit.make_scene(
            f"Scene_{name}_Close", design, PREVIEW_DIR / f"{name}_storefront.png",
            width=int(1500 * scale), height=int(950 * scale),
            camera_location=(40, -150, 58), target=(6.0, 6.0, 15.0),
            ortho_scale=None, samples=samples, focal=140.0,
        )
        kit.render_scene(close)
        print(f"[dealer] {name}: {tris} triangles")

        if options["bake"]:
            merged, _ = kit.bake_and_export(
                design, name, EXPORT_DIR,
                resolution=spec["texture"], samples=bake_samples, bake_normal=False,
            )
            check, rig = kit.make_scene(
                f"Scene_{name}_Baked", None, PREVIEW_DIR / f"{name}_baked_check.png",
                width=int(1150 * scale), height=int(1050 * scale),
                camera_location=kit.game_camera_location(240.0), target=(0, 0, 8.0),
                ortho_scale=kit.lot_size(spec["cells"][0]) * 1.62, samples=samples,
            )
            instance = merged.copy()
            instance.data = merged.data
            rig.objects.link(instance)
            kit.render_scene(check)

    if last_scene is not None:
        kit.activate_scene(last_scene)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_DIR / "lowpoly_car_dealer.blend"), compress=True)
    print("[done] car dealer")


if __name__ == "__main__":
    main()
