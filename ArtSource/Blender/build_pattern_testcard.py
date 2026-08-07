"""Render every citykit surface pattern on a sample mass.

This is the reference sheet for the city rebuild. Before authoring an asset,
look at `LowPolyCityKit/previews/pattern_testcard.png` and pick the pattern and
parameters from what is actually on screen, rather than from the prose in
ArtDirection/CITY-REBUILD-SPEC.md.

Every sample below is the *same* geometry — a plain box or a box plus a gable.
All the difference between a London brick terrace, a stucco townhouse and an
industrial shed is texture.

Run with::

    blender --background --factory-startup \
        --python ArtSource/Blender/build_pattern_testcard.py

Flags after ``--``: ``--quick``.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import citykit as kit  # noqa: E402


PREVIEW_DIR = SCRIPT_DIR / "LowPolyCityKit" / "previews"

# (label, wall pattern, wall colour key, roof pattern, roof colour key, roof kind)
SAMPLES = [
    (
        "Brick terrace / recessed sash windows / shopfront",
        kit.facade_pattern(
            storey=5.4, bay=4.6, ground=7.4,
            window_w=2.2, window_h=3.4,
            surround="recessed", surround_width=0.40,
            sill=True, lintel=True, glazing_bars="cross",
            wall_texture="brick", string_course=0.8, cornice=1.4, parapet=0.05,
            ground_mode="shopfront", door_chance=0.34, lit_fraction=0.34,
            trim=kit.col("cream_trim"), accent=kit.col("red_shade"),
        ),
        "brick",
        kit.shingle_pattern(course=1.5, light=kit.col("render_grey"), dark=kit.col("roof_shade")),
        "roof_slate",
        "gable",
    ),
    (
        "Stucco townhouse / raised stone surrounds / string course",
        kit.facade_pattern(
            storey=5.6, bay=5.0, ground=7.0,
            window_w=2.4, window_h=3.6,
            surround="raised", surround_width=0.60,
            sill=True, lintel=False, glazing_bars="grid",
            wall_texture="stucco", string_course=1.0, cornice=1.8, parapet=0.07,
            ground_mode="shopfront", door_chance=0.30, lit_fraction=0.28,
            trim=kit.col("cream_trim"), accent=kit.col("blue_shade"),
        ),
        "sand_wall",
        kit.flatroof_pattern(kit_density=0.35, seam_pitch=5.0),
        "roof_slate",
        "flat",
    ),
    (
        "Ashlar civic / raised surround + lintel / plinth base",
        kit.facade_pattern(
            storey=6.2, bay=5.6, ground=8.0,
            window_w=2.6, window_h=4.0,
            surround="raised", surround_width=0.70,
            sill=True, lintel=True, glazing_bars="transom",
            wall_texture="ashlar", string_course=1.2, cornice=2.0, parapet=0.08,
            ground_mode="plinth", lit_fraction=0.20,
            trim=kit.col("cream_trim"),
        ),
        "render_grey",
        kit.flatroof_pattern(kit_density=0.30, seam_pitch=6.0),
        "membrane",
        "flat",
    ),
    (
        "Panel office / flush glazing / entrance door",
        kit.facade_pattern(
            storey=4.4, bay=3.6, ground=6.5,
            window_w=2.4, window_h=2.6,
            surround="flush", sill=False, lintel=False, glazing_bars="none",
            wall_texture="panel", string_course=0.0, cornice=1.0, parapet=0.06,
            ground_mode="door", lit_fraction=0.42,
            trim=kit.col("office_frame"), glass=kit.col("office_glass_lit"), glass_unlit=kit.col("office_glass"),
        ),
        "render_blue",
        kit.flatroof_pattern(kit_density=0.55, parapet_inset=0.12),
        "membrane",
        "flat",
    ),
    (
        "Curtain wall tower",
        kit.curtainwall_pattern(storey=4.2, mullion=2.6, lit_fraction=0.22),
        "office_spandrel",
        kit.flatroof_pattern(kit_density=0.60, parapet_inset=0.14),
        "membrane",
        "flat",
    ),
    (
        "Industrial shed / corrugated / roller doors",
        kit.facade_pattern(
            storey=6.0, bay=6.0, ground=9.0,
            window_w=3.4, window_h=1.6,
            surround="flush", sill=False, glazing_bars="none",
            wall_texture="plain", string_course=0.0, cornice=0.0, parapet=0.05,
            ground_mode="dock", lit_fraction=0.10,
            wall=kit.col("metal_shed"), trim=kit.col("concrete"),
        ),
        "metal_shed",
        kit.corrugated_pattern(pitch=3.2, rust=0.10),
        "metal_shed_dark",
        "flat",
    ),
    (
        "Signage band over a shopfront parade",
        kit.with_signage(
            kit.facade_pattern(
                storey=5.0, bay=4.8, ground=7.2,
                window_w=2.3, window_h=3.0,
                surround="raised", surround_width=0.5,
                sill=True, glazing_bars="transom",
                wall_texture="brick", string_course=0.8, cornice=1.4, parapet=0.06,
                ground_mode="shopfront", door_chance=0.4, lit_fraction=0.5,
                trim=kit.col("cream_trim"), accent=kit.col("gold_shade"),
            ),
            z_min=26.0, z_max=31.0, colour_key="blue", emblem="circle",
        ),
        "brick_dark",
        kit.flatroof_pattern(kit_density=0.30),
        "membrane",
        "flat",
    ),
]

GROUND_SAMPLES = [
    ("Lot markings", kit.lotmarking_pattern(), "asphalt"),
    ("Truck yard", kit.lotmarking_pattern(bay_width=9.0, bay_depth=18.0, aisle=12.0), "concrete"),
]


def build() -> bpy.types.Collection:
    collection = bpy.data.collections.new("Pattern_Testcard")
    bpy.context.scene.collection.children.link(collection)

    pitch = 52.0
    for index, (label, wall_pattern, wall_key, roof_pattern, roof_key, roof_kind) in enumerate(SAMPLES):
        wall = kit.stylized_material(
            f"TC_Wall_{index}", wall_key, pattern=wall_pattern,
            edge_amount=0.16, crevice_amount=0.22, gradient_amount=0.18,
            ao_amount=0.42, roughness=0.86, bevel_radius=0.5, bump_strength=0.0,
        )
        roof = kit.stylized_material(
            f"TC_Roof_{index}", roof_key, pattern=roof_pattern,
            edge_amount=0.18, gradient_amount=0.08, ao_amount=0.40,
            roughness=0.80, bevel_radius=0.5, bump_strength=0.0,
        )
        x = (index - (len(SAMPLES) - 1) / 2) * pitch
        if roof_kind == "gable":
            kit.lofted(
                f"TC_Mass_{index}", collection,
                ((0.0, 19.0, 13.0), (38.0, 18.4, 12.6)), (x, 0.0, 0.0), [wall],
                cap_bottom=False, cap_top=False,
            )
            kit.gable(
                f"TC_Roof_{index}", collection, (36.8, 25.2, 10.0), (x, 0.0, 38.0),
                [roof], ridge_axis="X", overhang=1.6,
            )
        else:
            kit.parapet_box(
                f"TC_Mass_{index}", collection, (38.0, 26.0, 46.0), (x, 0.0, 0.0),
                [wall, roof], parapet=2.2, inset=1.4,
            )
        print(f"[testcard] {index}: {label}")

    for index, (label, pattern, key) in enumerate(GROUND_SAMPLES):
        ground = kit.stylized_material(
            f"TC_Ground_{index}", key, pattern=pattern,
            edge_amount=0.10, gradient_amount=0.0, ao_amount=0.35,
            roughness=0.95, bevel_radius=0.4, bump_strength=0.0,
        )
        x = (index - (len(GROUND_SAMPLES) - 1) / 2) * 124.0
        kit.plane(f"TC_Lot_{index}", collection, (116.0, 62.0), (x, -64.0, 0.2), ground)
        print(f"[testcard] ground {index}: {label}")

    return collection


def main() -> None:
    quick = "--quick" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

    kit.reset_file("Scene_Testcard")
    kit.flat_material("Backdrop", "backdrop", roughness=1.0)
    design = build()
    bpy.context.scene.collection.children.unlink(design)

    scale = 0.5 if quick else 1.0
    scene, _ = kit.make_scene(
        "Scene_Testcard", design, PREVIEW_DIR / "pattern_testcard.png",
        width=int(2200 * scale), height=int(1150 * scale),
        camera_location=kit.game_camera_location(800.0), target=(0, -20.0, 16.0),
        ortho_scale=470.0, samples=48 if quick else 220, backdrop=(1400, 1400),
    )
    kit.render_scene(scene)

    close, _ = kit.make_scene(
        "Scene_TestcardClose", design, PREVIEW_DIR / "pattern_testcard_close.png",
        width=int(1800 * scale), height=int(950 * scale),
        camera_location=kit.game_camera_location(320.0), target=(-78.0, 4.0, 24.0),
        ortho_scale=124.0, samples=48 if quick else 220, backdrop=(1400, 1400),
    )
    kit.render_scene(close)
    print("[done] pattern testcard")


if __name__ == "__main__":
    main()
