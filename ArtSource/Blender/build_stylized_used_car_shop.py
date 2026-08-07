"""Build one stylized ("Clash of Clans"-like) used car shop asset in Blender.

This is a from-scratch art direction probe. It does not replace the existing
flat low-poly library; it is a parallel pipeline so both looks can be compared
before committing.

The asset honours the existing city grid contract:

* 1 grid cell = 20 world units
* 3x3 footprint = 60x60 world units (the ``playerMediumDealer`` slot)
* origin = footprint centre at ground level
* the public/front road edge is negative Y in Blender

Style rules encoded here:

* chunky battered masses, oversized flared roofs, thick trim boards
* hand-painted look faked with procedural shading: pointiness edge highlights,
  ambient-occlusion crevice darkening, vertical paint gradients, tile courses
* warm saturated palette, no chrome, matte surfaces
* readable props (bunting, pylon sign, awning, planters) instead of text

Run with::

    blender --background --factory-startup \
        --python ArtSource/Blender/build_stylized_used_car_shop.py

Optional flags after ``--``: ``--quick`` (fast low-sample previews),
``--no-bake`` (skip the texture bake and export flat materials).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "StylizedUsedCarShop"
BLEND_PATH = OUTPUT_DIR / "stylized_used_car_shop_3x3.blend"
PREVIEW_DIR = OUTPUT_DIR / "previews"
EXPORT_DIR = OUTPUT_DIR / "exports"

CELL = 20.0
FOOTPRINT_CELLS = 3
LOT = CELL * FOOTPRINT_CELLS
HALF = LOT / 2

# --- vertical stack -------------------------------------------------------
SOIL_H = 1.90                      # chunky earth block so the tile reads as terrain
GRASS_H = 0.85
GROUND = SOIL_H + GRASS_H          # 2.75, top of the grass tile
YARD_TOP = GROUND + 0.28           # asphalt forecourt surface
PAD_TOP = GROUND + 0.46            # raised stone pad under the building

BUILDING_Y = 15.0
BASE_H = 2.50
BASE_TOP = PAD_TOP + BASE_H
WALL_H = 14.60
WALL_TOP = BASE_TOP + WALL_H
EAVE_Z = WALL_TOP - 0.35
ROOF_H = 9.60
RIDGE_Z = EAVE_Z + ROOF_H
ROOF_COURSES = 8                   # modelled tile courses, not just a texture

# Wall loft profile: (height above BASE_TOP, half width, half depth).
WALL_RINGS = ((0.00, 19.90, 10.20), (1.30, 19.60, 9.90), (12.20, 18.80, 9.30))
CORNICE_RINGS = ((11.90, 19.00, 9.50), (12.50, 20.40, 10.90), (14.60, 20.10, 10.60))
# Roof loft profile relative to EAVE_Z. The first span is deliberately much
# shallower than the second so the eave reads as a flared, hand-carved lip.
ROOF_RINGS = ((0.00, 23.00, 12.80), (1.10, 21.60, 11.45), (9.60, 8.50, 0.60))

MATERIALS: dict[str, bpy.types.Material] = {}


# --------------------------------------------------------------------------
# colour
# --------------------------------------------------------------------------

def _linear(channel: int) -> float:
    value = channel / 255.0
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def rgb(hex_code: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    """Convert an sRGB hex string to Blender's linear working space."""
    code = hex_code.lstrip("#")
    return (
        _linear(int(code[0:2], 16)),
        _linear(int(code[2:4], 16)),
        _linear(int(code[4:6], 16)),
        alpha,
    )


PALETTE = {
    "sand_wall": "#F2C874",
    "sand_wall_shade": "#9C6520",
    "sand_speckle": "#FCE3AC",
    "cream_trim": "#FBEFD2",
    "cream_shade": "#B9915A",
    "stone": "#BFAE93",
    "stone_shade": "#6E5C43",
    "stone_dark": "#6B5940",
    "roof": "#1E95A8",
    "roof_light": "#6FE2EA",
    "roof_shade": "#0A4A59",
    "roof_ridge": "#12718A",
    "wood": "#C0701C",
    "wood_light": "#EBA646",
    "wood_shade": "#5E3410",
    "wood_dark": "#7A4415",
    "gold": "#FFC03A",
    "gold_shade": "#96590A",
    "red": "#E24328",
    "red_shade": "#8A1A0C",
    "blue": "#2A63C4",
    "blue_shade": "#12306C",
    "grass": "#6FB92F",
    "grass_light": "#A5DC55",
    "grass_shade": "#2E661A",
    "soil": "#9A6027",
    "soil_shade": "#4E2F12",
    "asphalt": "#5A5A67",
    "asphalt_light": "#7C7C8B",
    "asphalt_shade": "#25252E",
    "concrete": "#D8CBAC",
    "concrete_shade": "#82755A",
    "line_paint": "#FBF6E6",
    "glass": "#FFD182",
    "glass_dark": "#12414F",
    "tyre": "#2E2E34",
    "chrome": "#CDD2D8",
    "leaf": "#4FA327",
    "leaf_light": "#8CD246",
    "leaf_shade": "#22521A",
    "backdrop": "#D9D2C2",
}


def col(key: str) -> tuple[float, float, float, float]:
    return rgb(PALETTE[key])


# --------------------------------------------------------------------------
# stylized material system
# --------------------------------------------------------------------------

def _new(nt: bpy.types.NodeTree, kind: str, x: float, y: float):
    node = nt.nodes.new(kind)
    node.location = (x, y)
    return node


def _mix(nt, x, y, color_a, color_b, fac):
    node = _new(nt, "ShaderNodeMixRGB", x, y)
    node.blend_type = "MIX"
    if isinstance(color_a, tuple):
        node.inputs["Color1"].default_value = color_a
    else:
        nt.links.new(color_a, node.inputs["Color1"])
    if isinstance(color_b, tuple):
        node.inputs["Color2"].default_value = color_b
    else:
        nt.links.new(color_b, node.inputs["Color2"])
    if isinstance(fac, (int, float)):
        node.inputs["Fac"].default_value = fac
    else:
        nt.links.new(fac, node.inputs["Fac"])
    return node


def _map_range(nt, x, y, source, from_min, from_max, to_min=0.0, to_max=1.0):
    node = _new(nt, "ShaderNodeMapRange", x, y)
    node.clamp = True
    nt.links.new(source, node.inputs["Value"])
    node.inputs["From Min"].default_value = from_min
    node.inputs["From Max"].default_value = from_max
    node.inputs["To Min"].default_value = to_min
    node.inputs["To Max"].default_value = to_max
    return node


def _scale(nt, x, y, source, factor):
    node = _new(nt, "ShaderNodeMath", x, y)
    node.operation = "MULTIPLY"
    nt.links.new(source, node.inputs[0])
    node.inputs[1].default_value = factor
    return node


def shingle_pattern(course=1.9, light=None, dark=None, distortion=0.35):
    """Horizontal roof courses driven by object-space Z.

    Constant-Z bands follow the slope of any hip or gable, so a single
    procedural pattern lays correct tile courses on every roof face.
    """

    def build(nt, coord, base):
        wave = _new(nt, "ShaderNodeTexWave", -1000, 260)
        wave.wave_type = "BANDS"
        wave.bands_direction = "Z"
        wave.wave_profile = "SAW"
        wave.inputs["Scale"].default_value = 1.0 / max(course, 0.05)
        wave.inputs["Distortion"].default_value = distortion
        wave.inputs["Detail"].default_value = 2.0
        wave.inputs["Detail Scale"].default_value = 0.8
        nt.links.new(coord, wave.inputs["Vector"])

        ramp = _new(nt, "ShaderNodeValToRGB", -820, 260)
        ramp.color_ramp.interpolation = "B_SPLINE"
        elements = ramp.color_ramp.elements
        elements[0].position = 0.0
        elements[0].color = dark or col("roof_shade")
        elements[1].position = 0.16
        elements[1].color = base
        mid = elements.new(0.82)
        mid.color = base
        top = elements.new(0.99)
        top.color = light or col("roof_light")
        nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])

        grime = _new(nt, "ShaderNodeTexNoise", -1000, 40)
        grime.inputs["Scale"].default_value = 2.4
        grime.inputs["Detail"].default_value = 4.0
        nt.links.new(coord, grime.inputs["Vector"])
        grime_fac = _map_range(nt, -820, 40, grime.outputs["Fac"], 0.35, 0.68, 0.0, 0.35)
        tinted = _mix(nt, -640, 200, ramp.outputs["Color"], dark or col("roof_shade"), grime_fac.outputs["Result"])
        return tinted.outputs["Color"], wave.outputs["Fac"]

    return build


def plank_pattern(scale=1.4, light=None, dark=None, direction="Z"):
    """Painted timber grain: soft streaks plus a couple of darker knots."""

    def build(nt, coord, base):
        wave = _new(nt, "ShaderNodeTexWave", -1000, 260)
        wave.wave_type = "BANDS"
        wave.bands_direction = direction
        wave.wave_profile = "SIN"
        wave.inputs["Scale"].default_value = scale
        wave.inputs["Distortion"].default_value = 2.4
        wave.inputs["Detail"].default_value = 2.0
        wave.inputs["Detail Scale"].default_value = 1.0
        nt.links.new(coord, wave.inputs["Vector"])
        grain = _map_range(nt, -820, 260, wave.outputs["Fac"], 0.25, 0.85, 0.0, 1.0)

        streaks = _mix(nt, -640, 260, dark or col("wood_shade"), light or col("wood_light"), grain.outputs["Result"])
        blend = _mix(nt, -460, 220, base, streaks.outputs["Color"], 0.34)
        return blend.outputs["Color"], grain.outputs["Result"]

    return build


def speckle_pattern(scale=5.0, amount=0.4, tint=None, detail=6.0, roughness=0.6):
    """Generic painted-plaster mottling."""

    def build(nt, coord, base):
        noise = _new(nt, "ShaderNodeTexNoise", -1000, 260)
        noise.inputs["Scale"].default_value = scale
        noise.inputs["Detail"].default_value = detail
        noise.inputs["Roughness"].default_value = roughness
        nt.links.new(coord, noise.inputs["Vector"])
        fac = _map_range(nt, -820, 260, noise.outputs["Fac"], 0.34, 0.72, 0.0, amount)
        mixed = _mix(nt, -640, 260, base, tint or col("cream_trim"), fac.outputs["Result"])
        return mixed.outputs["Color"], noise.outputs["Fac"]

    return build


def pebble_pattern(scale=9.0, amount=0.45, tint=None, dark=None):
    """Chunky voronoi grit for asphalt and gravel."""

    def build(nt, coord, base):
        cells = _new(nt, "ShaderNodeTexVoronoi", -1000, 300)
        cells.feature = "F1"
        cells.inputs["Scale"].default_value = scale
        nt.links.new(coord, cells.inputs["Vector"])
        grit = _map_range(nt, -820, 300, cells.outputs["Distance"], 0.0, 0.55, 0.0, amount)
        lit = _mix(nt, -640, 300, base, tint or col("asphalt_light"), grit.outputs["Result"])

        patch = _new(nt, "ShaderNodeTexNoise", -1000, 60)
        patch.inputs["Scale"].default_value = 1.1
        patch.inputs["Detail"].default_value = 4.0
        nt.links.new(coord, patch.inputs["Vector"])
        patch_fac = _map_range(nt, -820, 60, patch.outputs["Fac"], 0.42, 0.78, 0.0, 0.4)
        worn = _mix(nt, -460, 240, lit.outputs["Color"], dark or col("asphalt_shade"), patch_fac.outputs["Result"])
        return worn.outputs["Color"], cells.outputs["Distance"]

    return build


def turf_pattern(light=None, shade=None):
    """Two-tone clumpy grass."""

    def build(nt, coord, base):
        clumps = _new(nt, "ShaderNodeTexNoise", -1000, 300)
        clumps.inputs["Scale"].default_value = 1.5
        clumps.inputs["Detail"].default_value = 5.0
        nt.links.new(coord, clumps.inputs["Vector"])
        clump_fac = _map_range(nt, -820, 300, clumps.outputs["Fac"], 0.36, 0.66, 0.0, 1.0)
        broad = _mix(nt, -640, 300, shade or col("grass_shade"), light or col("grass_light"), clump_fac.outputs["Result"])
        toned = _mix(nt, -460, 300, base, broad.outputs["Color"], 0.72)

        blades = _new(nt, "ShaderNodeTexVoronoi", -1000, 60)
        blades.feature = "F1"
        blades.inputs["Scale"].default_value = 14.0
        nt.links.new(coord, blades.inputs["Vector"])
        blade_fac = _map_range(nt, -820, 60, blades.outputs["Distance"], 0.0, 0.4, 0.0, 0.28)
        final = _mix(nt, -300, 280, toned.outputs["Color"], light or col("grass_light"), blade_fac.outputs["Result"])
        return final.outputs["Color"], blades.outputs["Distance"]

    return build


def stripe_pattern(width=2.2, other=None, axis="X"):
    """Hard two-colour awning stripes in object space."""

    def build(nt, coord, base):
        wave = _new(nt, "ShaderNodeTexWave", -1000, 260)
        wave.wave_type = "BANDS"
        wave.bands_direction = axis
        wave.wave_profile = "SAW"
        wave.inputs["Scale"].default_value = 1.0 / max(width * 2.0, 0.05)
        wave.inputs["Distortion"].default_value = 0.0
        nt.links.new(coord, wave.inputs["Vector"])
        ramp = _new(nt, "ShaderNodeValToRGB", -820, 260)
        ramp.color_ramp.interpolation = "CONSTANT"
        ramp.color_ramp.elements[0].position = 0.0
        ramp.color_ramp.elements[0].color = base
        ramp.color_ramp.elements[1].position = 0.5
        ramp.color_ramp.elements[1].color = other or col("cream_trim")
        nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
        return ramp.outputs["Color"], None

    return build


def block_pattern(scale=3.2, mortar=None, light=None):
    """Rounded rubble blocks for the plinth and stone base."""

    def build(nt, coord, base):
        cells = _new(nt, "ShaderNodeTexVoronoi", -1000, 300)
        cells.feature = "SMOOTH_F1"
        cells.inputs["Scale"].default_value = scale
        cells.inputs["Smoothness"].default_value = 0.18
        nt.links.new(coord, cells.inputs["Vector"])

        joint = _map_range(nt, -820, 340, cells.outputs["Distance"], 0.26, 0.06, 0.0, 1.0)
        varied = _new(nt, "ShaderNodeValToRGB", -820, 120)
        varied.color_ramp.interpolation = "LINEAR"
        varied.color_ramp.elements[0].color = light or col("cream_trim")
        varied.color_ramp.elements[1].color = base
        nt.links.new(cells.outputs["Color"], varied.inputs["Fac"])

        toned = _mix(nt, -600, 240, base, varied.outputs["Color"], 0.55)
        grouted = _mix(nt, -420, 240, toned.outputs["Color"], mortar or col("stone_dark"), joint.outputs["Result"])
        return grouted.outputs["Color"], cells.outputs["Distance"]

    return build


def stylized_material(
    name: str,
    base_key: str,
    *,
    shade_key: str | None = None,
    pattern=None,
    edge_key: str = "cream_trim",
    edge_amount: float = 0.30,
    ao_amount: float = 0.55,
    ao_distance: float = 3.2,
    crevice_amount: float = 0.55,
    gradient_amount: float = 0.28,
    roughness: float = 0.80,
    metallic: float = 0.0,
    bevel_radius: float = 0.16,
    bump_strength: float = 0.0,
    emission_key: str | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    """Compose a hand-painted-looking material out of procedural shading.

    The painted look comes from four stacked cues, all of which a texture
    artist would normally brush in by hand:

    * mottled base colour (``pattern``)
    * a vertical gradient so every mass darkens toward the ground
    * pointiness: convex edges lighten, concave creases darken
    * a short-range ambient occlusion multiply for contact shading
    """
    cached = MATERIALS.get(name)
    if cached is not None:
        return cached

    base = col(base_key)
    shade = col(shade_key) if shade_key else tuple(c * 0.45 for c in base[:3]) + (1.0,)

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = base
    nt = mat.node_tree
    nt.nodes.clear()

    coord = _new(nt, "ShaderNodeTexCoord", -1400, 200)
    object_vec = coord.outputs["Object"]
    generated_vec = coord.outputs["Generated"]

    if pattern is not None:
        color_socket, bump_socket = pattern(nt, object_vec, base)
    else:
        color_socket, bump_socket = speckle_pattern()(nt, object_vec, base)

    # Vertical paint gradient: darker at the foot of every mass.
    height = _new(nt, "ShaderNodeSeparateXYZ", -1000, -160)
    nt.links.new(generated_vec, height.inputs["Vector"])
    gradient = _map_range(nt, -820, -160, height.outputs["Z"], 0.55, 0.02, 0.0, gradient_amount)
    graded = _mix(nt, -600, 60, color_socket, shade, gradient.outputs["Result"])

    geometry = _new(nt, "ShaderNodeNewGeometry", -1000, -420)
    convex = _map_range(nt, -820, -360, geometry.outputs["Pointiness"], 0.52, 0.64, 0.0, edge_amount)
    concave = _map_range(nt, -820, -520, geometry.outputs["Pointiness"], 0.48, 0.36, 0.0, crevice_amount)
    lit = _mix(nt, -420, 20, graded.outputs["Color"], col(edge_key), convex.outputs["Result"])
    creased = _mix(nt, -240, 0, lit.outputs["Color"], shade, concave.outputs["Result"])

    occlusion = _new(nt, "ShaderNodeAmbientOcclusion", -1000, -700)
    occlusion.samples = 4
    occlusion.only_local = True
    occlusion.inputs["Distance"].default_value = ao_distance
    ao_output = occlusion.outputs.get("AO") or occlusion.outputs[0]
    ao_fac = _map_range(nt, -820, -700, ao_output, 0.92, 0.30, 0.0, ao_amount)
    shaded = _mix(nt, -60, -20, creased.outputs["Color"], shade, ao_fac.outputs["Result"])

    bsdf = _new(nt, "ShaderNodeBsdfPrincipled", 220, 60)
    nt.links.new(shaded.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Specular IOR Level"].default_value = 0.28

    normal_socket = None
    if bevel_radius > 0:
        bevel = _new(nt, "ShaderNodeBevel", -60, -320)
        bevel.samples = 3
        bevel.inputs["Radius"].default_value = bevel_radius
        normal_socket = bevel.outputs["Normal"]
    if bump_strength > 0 and bump_socket is not None:
        bump = _new(nt, "ShaderNodeBump", 40, -520)
        bump.inputs["Strength"].default_value = bump_strength
        bump.inputs["Distance"].default_value = 0.35
        nt.links.new(bump_socket, bump.inputs["Height"])
        if normal_socket is not None:
            nt.links.new(normal_socket, bump.inputs["Normal"])
        normal_socket = bump.outputs["Normal"]
    if normal_socket is not None:
        nt.links.new(normal_socket, bsdf.inputs["Normal"])

    if emission_key:
        bsdf.inputs["Emission Color"].default_value = col(emission_key)
        bsdf.inputs["Emission Strength"].default_value = emission_strength

    output = _new(nt, "ShaderNodeOutputMaterial", 520, 60)
    nt.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    MATERIALS[name] = mat
    return mat


def flat_material(
    name: str,
    base_key: str,
    *,
    roughness: float = 0.5,
    metallic: float = 0.0,
    emission_key: str | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    """Minimal material for glass, lights and tiny props."""
    cached = MATERIALS.get(name)
    if cached is not None:
        return cached
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = col(base_key)
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = col(base_key)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission_key:
        bsdf.inputs["Emission Color"].default_value = col(emission_key)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    MATERIALS[name] = mat
    return mat


def build_materials() -> None:
    stylized_material(
        "Sand_Wall",
        "sand_wall",
        shade_key="sand_wall_shade",
        pattern=speckle_pattern(scale=4.5, amount=0.45, tint=col("sand_speckle")),
        edge_amount=0.34,
        gradient_amount=0.42,
        ao_amount=0.60,
        roughness=0.86,
        bump_strength=0.12,
    )
    stylized_material(
        "Cream_Trim",
        "cream_trim",
        shade_key="cream_shade",
        pattern=speckle_pattern(scale=6.0, amount=0.3, tint=col("sand_speckle")),
        edge_amount=0.26,
        gradient_amount=0.24,
        ao_amount=0.55,
        roughness=0.80,
    )
    stylized_material(
        "Stone_Base",
        "stone",
        shade_key="stone_dark",
        pattern=block_pattern(scale=2.4, mortar=col("stone_dark"), light=col("cream_trim")),
        edge_amount=0.24,
        gradient_amount=0.35,
        ao_amount=0.65,
        roughness=0.92,
        bevel_radius=0.22,
        bump_strength=0.5,
    )
    stylized_material(
        "Roof_Tile",
        "roof",
        shade_key="roof_shade",
        pattern=shingle_pattern(course=1.75, light=col("roof_light"), dark=col("roof_shade")),
        edge_key="roof_light",
        edge_amount=0.40,
        gradient_amount=0.18,
        ao_amount=0.55,
        roughness=0.72,
        bevel_radius=0.20,
        bump_strength=0.55,
    )
    stylized_material(
        "Roof_Ridge",
        "roof_ridge",
        shade_key="roof_shade",
        pattern=speckle_pattern(scale=8.0, amount=0.3, tint=col("roof_light")),
        edge_key="roof_light",
        edge_amount=0.38,
        roughness=0.68,
    )
    stylized_material(
        "Timber",
        "wood",
        shade_key="wood_shade",
        pattern=plank_pattern(scale=1.1, light=col("wood_light"), dark=col("wood_shade")),
        edge_key="wood_light",
        edge_amount=0.30,
        gradient_amount=0.30,
        ao_amount=0.60,
        roughness=0.88,
        bump_strength=0.28,
    )
    stylized_material(
        "Timber_Dark",
        "wood_dark",
        shade_key="wood_shade",
        pattern=plank_pattern(scale=1.6, light=col("wood"), dark=col("wood_shade"), direction="X"),
        edge_key="wood_light",
        edge_amount=0.26,
        roughness=0.88,
    )
    stylized_material(
        "Gold_Trim",
        "gold",
        shade_key="gold_shade",
        pattern=speckle_pattern(scale=10.0, amount=0.25, tint=col("cream_trim")),
        edge_key="cream_trim",
        edge_amount=0.45,
        ao_amount=0.45,
        roughness=0.36,
        metallic=0.55,
        bevel_radius=0.10,
    )
    stylized_material(
        "Accent_Red",
        "red",
        shade_key="red_shade",
        pattern=speckle_pattern(scale=7.0, amount=0.24, tint=col("gold")),
        edge_amount=0.30,
        roughness=0.70,
    )
    stylized_material(
        "Accent_Blue",
        "blue",
        shade_key="blue_shade",
        pattern=speckle_pattern(scale=7.0, amount=0.22, tint=col("cream_trim")),
        edge_amount=0.30,
        roughness=0.70,
    )
    stylized_material(
        "Grass",
        "grass",
        shade_key="grass_shade",
        pattern=turf_pattern(light=col("grass_light"), shade=col("grass_shade")),
        edge_key="grass_light",
        edge_amount=0.30,
        gradient_amount=0.0,
        ao_amount=0.55,
        roughness=0.97,
        bevel_radius=0.30,
        bump_strength=0.16,
    )
    stylized_material(
        "Soil",
        "soil",
        shade_key="soil_shade",
        pattern=block_pattern(scale=1.6, mortar=col("soil_shade"), light=col("wood_light")),
        edge_key="wood_light",
        edge_amount=0.26,
        gradient_amount=0.45,
        roughness=0.96,
        bevel_radius=0.35,
        bump_strength=0.5,
    )
    stylized_material(
        "Asphalt",
        "asphalt",
        shade_key="asphalt_shade",
        pattern=pebble_pattern(scale=7.0, amount=0.4, tint=col("asphalt_light"), dark=col("asphalt_shade")),
        edge_key="asphalt_light",
        edge_amount=0.22,
        gradient_amount=0.0,
        ao_amount=0.60,
        roughness=0.95,
        bevel_radius=0.24,
        bump_strength=0.18,
    )
    stylized_material(
        "Concrete",
        "concrete",
        shade_key="concrete_shade",
        pattern=speckle_pattern(scale=5.0, amount=0.32, tint=col("cream_trim")),
        edge_amount=0.26,
        gradient_amount=0.22,
        roughness=0.90,
    )
    stylized_material(
        "Line_Paint",
        "line_paint",
        shade_key="concrete_shade",
        pattern=speckle_pattern(scale=12.0, amount=0.2, tint=col("cream_trim")),
        edge_amount=0.18,
        gradient_amount=0.0,
        ao_amount=0.35,
        roughness=0.85,
        bevel_radius=0.05,
    )
    stylized_material(
        "Leaf",
        "leaf",
        shade_key="leaf_shade",
        pattern=speckle_pattern(scale=6.0, amount=0.55, tint=col("leaf_light")),
        edge_key="leaf_light",
        edge_amount=0.34,
        gradient_amount=0.30,
        ao_amount=0.60,
        roughness=0.94,
        bevel_radius=0.25,
    )
    stylized_material(
        "Awning_Stripe",
        "red",
        shade_key="red_shade",
        pattern=stripe_pattern(width=3.0, other=col("cream_trim"), axis="X"),
        edge_amount=0.24,
        gradient_amount=0.16,
        ao_amount=0.5,
        roughness=0.82,
        bevel_radius=0.12,
    )
    stylized_material(
        "Canopy_Stripe",
        "blue",
        shade_key="blue_shade",
        pattern=stripe_pattern(width=3.4, other=col("cream_trim"), axis="X"),
        edge_amount=0.24,
        gradient_amount=0.16,
        ao_amount=0.5,
        roughness=0.82,
        bevel_radius=0.12,
    )
    stylized_material(
        "Tyre",
        "tyre",
        shade_key="asphalt_shade",
        pattern=speckle_pattern(scale=14.0, amount=0.2, tint=col("asphalt_light")),
        edge_key="asphalt_light",
        edge_amount=0.28,
        roughness=0.90,
        bevel_radius=0.08,
    )
    stylized_material(
        "Metal_Grey",
        "chrome",
        shade_key="asphalt_shade",
        pattern=speckle_pattern(scale=9.0, amount=0.2, tint=col("cream_trim")),
        edge_amount=0.35,
        roughness=0.40,
        metallic=0.55,
        bevel_radius=0.08,
    )
    flat_material("Glass_Warm", "glass", roughness=0.16, emission_key="glass", emission_strength=2.6)
    flat_material("Glass_Dark", "glass_dark", roughness=0.10, metallic=0.2)
    flat_material("Lamp_Glow", "glass", roughness=0.20, emission_key="gold", emission_strength=7.0)
    flat_material("Backdrop", "backdrop", roughness=1.0)

    for key, name in (
        ("red", "Car_Red"),
        ("blue", "Car_Blue"),
        ("gold", "Car_Gold"),
        ("cream_trim", "Car_Cream"),
        ("roof", "Car_Teal"),
        ("leaf", "Car_Green"),
    ):
        stylized_material(
            name,
            key,
            pattern=speckle_pattern(scale=9.0, amount=0.18, tint=col("cream_trim")),
            edge_amount=0.40,
            gradient_amount=0.22,
            ao_amount=0.45,
            roughness=0.34,
            metallic=0.10,
            bevel_radius=0.10,
        )


CAR_BODY_MATERIALS = ("Car_Red", "Car_Blue", "Car_Gold", "Car_Cream", "Car_Teal", "Car_Green")


# --------------------------------------------------------------------------
# geometry helpers
# --------------------------------------------------------------------------

def link(obj: bpy.types.Object, collection: bpy.types.Collection, parent: bpy.types.Object | None):
    collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def add_bevel(obj: bpy.types.Object, width: float, segments: int = 2, angle: float = 55.0):
    if width <= 0:
        return
    modifier = obj.modifiers.new("Edge_Bevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(angle)
    modifier.miter_outer = "MITER_ARC"


def mesh_from(name: str, verts, faces) -> bpy.types.Mesh:
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    mesh.update()
    return mesh


def box(
    name, collection, dimensions, location, mat, *,
    bevel=0.14, rotation=(0, 0, 0), parent=None, segments=2,
):
    w, d, h = (v / 2 for v in dimensions)
    verts = [
        (-w, -d, -h), (w, -d, -h), (w, d, -h), (-w, d, -h),
        (-w, -d, h), (w, -d, h), (w, d, h), (-w, d, h),
    ]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (4, 0, 3, 7)]
    obj = bpy.data.objects.new(name, mesh_from(name, verts, faces))
    obj.location = location
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    link(obj, collection, parent)
    add_bevel(obj, bevel, segments)
    return obj


def lofted(
    name, collection, rings, location, mat, *,
    bevel=0.18, rotation=(0, 0, 0), parent=None, segments=2, cap_bottom=True,
):
    """Loft a stack of axis-aligned rectangles: ``rings`` = (z, half_x, half_y)."""
    verts: list[tuple[float, float, float]] = []
    for z, hx, hy in rings:
        verts.extend([(-hx, -hy, z), (hx, -hy, z), (hx, hy, z), (-hx, hy, z)])
    faces: list[tuple[int, ...]] = []
    for i in range(len(rings) - 1):
        a, b = i * 4, (i + 1) * 4
        for j in range(4):
            k = (j + 1) % 4
            faces.append((a + j, a + k, b + k, b + j))
    if cap_bottom:
        faces.append((3, 2, 1, 0))
    top = (len(rings) - 1) * 4
    faces.append((top, top + 1, top + 2, top + 3))
    obj = bpy.data.objects.new(name, mesh_from(name, verts, faces))
    obj.location = location
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    link(obj, collection, parent)
    add_bevel(obj, bevel, segments)
    return obj


def profile_solid(
    name, collection, profile, thickness, location, mat, *,
    bevel=0.10, rotation=(0, 0, 0), parent=None, segments=2,
):
    """Extrude a closed 2D profile (x, z) along Y by ``thickness``."""
    half = thickness / 2
    count = len(profile)
    verts = [(x, -half, z) for x, z in profile] + [(x, half, z) for x, z in profile]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, count + j, count + i))
    obj = bpy.data.objects.new(name, mesh_from(name, verts, faces))
    obj.location = location
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    link(obj, collection, parent)
    add_bevel(obj, bevel, segments)
    return obj


def cylinder(
    name, collection, radius, depth, location, mat, *,
    sides=16, rotation=(0, 0, 0), parent=None, bevel=0.06, radius_top=None,
):
    top_radius = radius if radius_top is None else radius_top
    half = depth / 2
    verts = []
    for i in range(sides):
        a = 2 * math.pi * i / sides
        verts.append((math.cos(a) * radius, math.sin(a) * radius, -half))
    for i in range(sides):
        a = 2 * math.pi * i / sides
        verts.append((math.cos(a) * top_radius, math.sin(a) * top_radius, half))
    faces = [tuple(range(sides - 1, -1, -1)), tuple(range(sides, sides * 2))]
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j, sides + i))
    obj = bpy.data.objects.new(name, mesh_from(name, verts, faces))
    obj.location = location
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    link(obj, collection, parent)
    add_bevel(obj, bevel, 2, angle=40.0)
    return obj


def sphere(name, collection, radius, location, mat, *, subdivisions=2, parent=None, scale=(1, 1, 1)):
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    link(obj, collection, parent)
    import bmesh

    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    bm.to_mesh(mesh)
    bm.free()
    obj.location = location
    obj.scale = scale
    obj.data.materials.append(mat)
    return obj


def tube(name, collection, points, radius, mat, *, sides=6, parent=None):
    """A swept tube through a polyline — used for bunting rope and cables."""
    pts = [Vector(p) for p in points]
    verts: list[tuple[float, float, float]] = []
    for index, point in enumerate(pts):
        if index == 0:
            tangent = (pts[1] - pts[0]).normalized()
        elif index == len(pts) - 1:
            tangent = (pts[-1] - pts[-2]).normalized()
        else:
            tangent = (pts[index + 1] - pts[index - 1]).normalized()
        reference = Vector((0, 0, 1))
        if abs(tangent.dot(reference)) > 0.95:
            reference = Vector((1, 0, 0))
        side = tangent.cross(reference).normalized()
        up = side.cross(tangent).normalized()
        for i in range(sides):
            a = 2 * math.pi * i / sides
            offset = side * (math.cos(a) * radius) + up * (math.sin(a) * radius)
            verts.append(tuple(point + offset))
    faces = []
    for seg in range(len(pts) - 1):
        a, b = seg * sides, (seg + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    obj = bpy.data.objects.new(name, mesh_from(name, verts, faces))
    obj.data.materials.append(mat)
    link(obj, collection, parent)
    return obj


def ring_at(rings, z: float) -> tuple[float, float]:
    """Interpolate a loft profile's half-extents at height ``z``."""
    if z <= rings[0][0]:
        return rings[0][1], rings[0][2]
    for i in range(len(rings) - 1):
        z0, hx0, hy0 = rings[i]
        z1, hx1, hy1 = rings[i + 1]
        if z <= z1:
            t = 0.0 if z1 == z0 else (z - z0) / (z1 - z0)
            return hx0 + (hx1 - hx0) * t, hy0 + (hy1 - hy0) * t
    return rings[-1][1], rings[-1][2]


def stepped_roof(
    name, collection, rings, location, mat, *,
    courses=8, lip=0.62, lip_height=0.45, parent=None, bevel=0.16,
):
    """A hip roof built from real tile courses.

    Each course overhangs the one above it, so the roof casts its own row of
    hard little shadows. That stepped silhouette is what separates a stylized
    mobile-game roof from a plain shaded slab.
    """
    top_z = rings[-1][0]
    bottom_z = rings[0][0]
    objects = []
    for index in range(courses):
        z0 = bottom_z + (top_z - bottom_z) * index / courses
        z1 = bottom_z + (top_z - bottom_z) * (index + 1) / courses
        hx0, hy0 = ring_at(rings, z0)
        hx1, hy1 = ring_at(rings, z1)
        overlap = 0.0 if index == 0 else 0.30
        course_rings = (
            (z0 - overlap, hx0 + lip, hy0 + lip),
            (z0 + lip_height, hx0 + lip * 0.15, hy0 + lip * 0.15),
            (z1, hx1, hy1),
        )
        objects.append(
            lofted(
                f"{name}_Course_{index}", collection, course_rings, location, mat,
                bevel=bevel, segments=2, cap_bottom=(index == 0), parent=parent,
            )
        )
    return objects


def arch_profile(width: float, height: float, rise: float, segments: int = 12):
    """Rectangle topped by a segmental (flattened) arch, centred on x=0."""
    half = width / 2
    points = [(-half, 0.0), (half, 0.0)]
    for i in range(segments + 1):
        t = math.pi * i / segments
        points.append((half * math.cos(t), height + rise * math.sin(t)))
    return points


def star_profile(radius: float, inner_ratio: float = 0.45, points: int = 5):
    result = []
    for i in range(points * 2):
        r = radius if i % 2 == 0 else radius * inner_ratio
        a = math.pi / 2 + math.pi * i / points
        result.append((math.cos(a) * r, math.sin(a) * r))
    return result


def car_icon_profile(scale: float = 1.0):
    """A chunky side-on car silhouette used as the shop emblem."""
    raw = [
        (-1.00, -0.28), (1.00, -0.28), (1.00, 0.06), (0.78, 0.10),
        (0.46, 0.44), (-0.16, 0.50), (-0.52, 0.16), (-0.94, 0.08),
    ]
    return [(x * scale, y * scale) for x, y in raw]


# --------------------------------------------------------------------------
# props
# --------------------------------------------------------------------------

def chunky_car(name, collection, location, body_mat, *, rotation_z=0.0, parent=None):
    """Toy-proportioned car: fat body, oversized wheels, big soft bevels."""
    root = bpy.data.objects.new(name, None)
    root.location = location
    root.rotation_euler = (0, 0, rotation_z)
    root.empty_display_size = 1.0
    link(root, collection, parent)

    body = MATERIALS[body_mat]
    box(f"{name}_Body", collection, (9.6, 4.3, 1.9), (0, 0, 1.55), body, bevel=0.62, segments=3, parent=root)
    box(f"{name}_Skirt", collection, (9.0, 4.5, 0.7), (0, 0, 0.85), MATERIALS["Timber_Dark"], bevel=0.28, parent=root)
    box(f"{name}_Cabin", collection, (5.0, 3.85, 1.85), (-0.55, 0, 3.25), body, bevel=0.66, segments=3, parent=root)
    box(f"{name}_Glass", collection, (5.05, 3.95, 0.95), (-0.55, 0, 3.42), MATERIALS["Glass_Dark"], bevel=0.30, parent=root)
    box(f"{name}_Roof", collection, (4.4, 3.5, 0.35), (-0.55, 0, 4.20), body, bevel=0.16, parent=root)
    box(f"{name}_Bonnet", collection, (2.6, 3.9, 0.35), (3.1, 0, 2.60), body, bevel=0.16, parent=root)

    for x in (-3.05, 3.05):
        for y in (-1.95, 1.95):
            cylinder(
                f"{name}_Tyre_{x}_{y}", collection, 1.28, 0.95, (x, y, 1.20),
                MATERIALS["Tyre"], sides=14, rotation=(math.pi / 2, 0, 0), parent=root, bevel=0.16,
            )
            cylinder(
                f"{name}_Hub_{x}_{y}", collection, 0.60, 1.05, (x, y, 1.20),
                MATERIALS["Metal_Grey"], sides=12, rotation=(math.pi / 2, 0, 0), parent=root, bevel=0.08,
            )
    for y in (-1.35, 1.35):
        box(f"{name}_Head_{y}", collection, (0.35, 1.10, 0.60), (4.72, y, 2.10), MATERIALS["Lamp_Glow"], bevel=0.14, parent=root)
        box(f"{name}_Tail_{y}", collection, (0.30, 0.95, 0.50), (-4.72, y, 2.20), MATERIALS["Accent_Red"], bevel=0.12, parent=root)
    box(f"{name}_Bumper_F", collection, (0.55, 4.2, 0.75), (4.85, 0, 1.35), MATERIALS["Metal_Grey"], bevel=0.20, parent=root)
    box(f"{name}_Bumper_R", collection, (0.55, 4.2, 0.75), (-4.85, 0, 1.35), MATERIALS["Metal_Grey"], bevel=0.20, parent=root)
    return root


def tree(name, collection, location, mat_leaf, *, height=13.0, parent=None):
    trunk_h = height * 0.40
    cylinder(
        f"{name}_Trunk", collection, 1.05, trunk_h, (location[0], location[1], location[2] + trunk_h / 2),
        MATERIALS["Timber"], sides=10, parent=parent, bevel=0.14, radius_top=0.78,
    )
    canopy_z = location[2] + trunk_h
    sizes = ((4.3, 0.0), (3.6, 3.2), (2.6, 5.6))
    for index, (radius, offset) in enumerate(sizes):
        sphere(
            f"{name}_Canopy_{index}", collection, radius,
            (location[0] + (0.6 if index == 1 else -0.4) * (index % 2), location[1] + 0.4 * index, canopy_z + offset + radius * 0.55),
            MATERIALS[mat_leaf], subdivisions=2, parent=parent, scale=(1.0, 1.0, 0.82),
        )


def bush(name, collection, location, radius, *, parent=None, mat="Leaf"):
    sphere(f"{name}_A", collection, radius, location, MATERIALS[mat], parent=parent, scale=(1.15, 1.05, 0.85))
    sphere(
        f"{name}_B", collection, radius * 0.68,
        (location[0] + radius * 0.6, location[1] - radius * 0.35, location[2] + radius * 0.2),
        MATERIALS[mat], parent=parent, scale=(1.1, 1.0, 0.85),
    )


def planter(name, collection, location, *, parent=None, radius=1.9):
    cylinder(
        f"{name}_Pot", collection, radius, 2.3, (location[0], location[1], location[2] + 1.15),
        MATERIALS["Accent_Red"], sides=12, parent=parent, bevel=0.18, radius_top=radius * 1.12,
    )
    cylinder(
        f"{name}_Rim", collection, radius * 1.2, 0.42, (location[0], location[1], location[2] + 2.35),
        MATERIALS["Gold_Trim"], sides=12, parent=parent, bevel=0.10,
    )
    bush(f"{name}_Bush", collection, (location[0], location[1], location[2] + 3.2), radius * 1.05, parent=parent)


def tyre_stack(name, collection, location, count=3, *, parent=None):
    for i in range(count):
        z = location[2] + 0.62 + i * 1.02
        cylinder(
            f"{name}_{i}", collection, 1.75, 1.0, (location[0] + (0.18 if i % 2 else -0.12), location[1] + (0.1 * i), z),
            MATERIALS["Tyre"], sides=14, parent=parent, bevel=0.22,
        )


def oil_drum(name, collection, location, mat, *, parent=None):
    cylinder(f"{name}_Body", collection, 1.35, 3.4, (location[0], location[1], location[2] + 1.7), MATERIALS[mat], sides=14, parent=parent, bevel=0.16)
    for offset in (1.0, 2.4):
        cylinder(
            f"{name}_Band_{offset}", collection, 1.45, 0.30, (location[0], location[1], location[2] + offset),
            MATERIALS["Gold_Trim"], sides=14, parent=parent, bevel=0.06,
        )


def traffic_cone(name, collection, location, *, parent=None):
    box(f"{name}_Foot", collection, (1.7, 1.7, 0.34), (location[0], location[1], location[2] + 0.17), MATERIALS["Accent_Red"], bevel=0.12, parent=parent)
    cylinder(
        f"{name}_Cone", collection, 0.78, 2.5, (location[0], location[1], location[2] + 1.55),
        MATERIALS["Accent_Red"], sides=12, parent=parent, bevel=0.05, radius_top=0.12,
    )
    cylinder(
        f"{name}_Band", collection, 0.62, 0.44, (location[0], location[1], location[2] + 1.85),
        MATERIALS["Cream_Trim"], sides=12, parent=parent, bevel=0.05, radius_top=0.52,
    )


def pennant_line(name, collection, start, end, *, sag=2.6, count=9, parent=None):
    """Bunting: a sagging rope plus alternating triangular flags."""
    start_v, end_v = Vector(start), Vector(end)
    samples = 24
    points = []
    for i in range(samples + 1):
        t = i / samples
        point = start_v.lerp(end_v, t)
        point.z -= sag * math.sin(math.pi * t)
        points.append(tuple(point))
    tube(f"{name}_Rope", collection, points, 0.14, MATERIALS["Timber_Dark"], sides=5, parent=parent)

    flag_materials = ("Accent_Red", "Gold_Trim", "Cream_Trim", "Accent_Blue")
    for i in range(count):
        t = (i + 0.5) / count
        centre = start_v.lerp(end_v, t)
        centre.z -= sag * math.sin(math.pi * t)
        direction = (end_v - start_v)
        direction.z = 0
        direction.normalize()
        span = 1.55
        left = centre - direction * (span / 2)
        right = centre + direction * (span / 2)
        tip = centre - Vector((0, 0, 2.05))
        tip += direction * 0.18
        mesh = mesh_from(f"{name}_Flag_{i}", [tuple(left), tuple(right), tuple(tip)], [(0, 1, 2)])
        obj = bpy.data.objects.new(f"{name}_Flag_{i}", mesh)
        obj.data.materials.append(MATERIALS[flag_materials[i % len(flag_materials)]])
        link(obj, collection, parent)
        solidify = obj.modifiers.new("Thickness", "SOLIDIFY")
        solidify.thickness = 0.10
        solidify.offset = 0.0


def corner_flag(name, collection, location, height, mat, *, parent=None):
    cylinder(
        f"{name}_Pole", collection, 0.24, height, (location[0], location[1], location[2] + height / 2),
        MATERIALS["Timber_Dark"], sides=8, parent=parent, bevel=0.05,
    )
    sphere(f"{name}_Finial", collection, 0.48, (location[0], location[1], location[2] + height + 0.3), MATERIALS["Gold_Trim"], parent=parent)
    top = location[2] + height - 0.6
    verts = [
        (location[0], location[1], top),
        (location[0], location[1], top - 2.1),
        (location[0], location[1] - 3.5, top - 1.35),
    ]
    mesh = mesh_from(f"{name}_Cloth", verts, [(0, 1, 2)])
    obj = bpy.data.objects.new(f"{name}_Cloth", mesh)
    obj.data.materials.append(MATERIALS[mat])
    link(obj, collection, parent)
    solidify = obj.modifiers.new("Thickness", "SOLIDIFY")
    solidify.thickness = 0.12
    solidify.offset = 0.0


def emblem(name, collection, location, mat_ring, *, parent=None, radius=2.15, thickness=0.5, rotation=(0, 0, 0)):
    """Gold ring + cream face + car silhouette, on a pivot so it can be tilted
    or turned to match whatever board it is mounted on."""
    pivot = bpy.data.objects.new(f"{name}_Pivot", None)
    pivot.location = location
    pivot.rotation_euler = rotation
    pivot.empty_display_size = 0.6
    link(pivot, collection, parent)
    cylinder(
        f"{name}_Ring", collection, radius, thickness, (0, 0, 0), MATERIALS[mat_ring],
        sides=24, rotation=(math.pi / 2, 0, 0), parent=pivot, bevel=0.10,
    )
    cylinder(
        f"{name}_Face", collection, radius * 0.84, thickness * 1.05, (0, 0.02, 0), MATERIALS["Cream_Trim"],
        sides=24, rotation=(math.pi / 2, 0, 0), parent=pivot, bevel=0.06,
    )
    profile_solid(
        f"{name}_Car", collection, car_icon_profile(radius * 0.74), thickness * 1.1,
        (0, -thickness * 0.30, -radius * 0.05), MATERIALS["Accent_Blue"], bevel=0.05, parent=pivot,
    )


# --------------------------------------------------------------------------
# the shop
# --------------------------------------------------------------------------

def wall_face_y(z_above_base: float) -> float:
    """Y of the battered front wall face at a given height above BASE_TOP."""
    rings = WALL_RINGS
    for i in range(len(rings) - 1):
        z0, _, d0 = rings[i]
        z1, _, d1 = rings[i + 1]
        if z_above_base <= z1 or i == len(rings) - 2:
            t = 0.0 if z1 == z0 else max(0.0, min(1.0, (z_above_base - z0) / (z1 - z0)))
            return BUILDING_Y - (d0 + (d1 - d0) * t)
    return BUILDING_Y - rings[-1][2]


def build_terrain(collection, root):
    # Earth block, inset, so the grass cap overhangs it like a cut turf tile.
    box("Tile_Soil", collection, (LOT - 2.6, LOT - 2.6, SOIL_H), (0, 0, SOIL_H / 2), MATERIALS["Soil"], bevel=0.75, segments=3, parent=root)
    box("Tile_Grass", collection, (LOT, LOT, GRASS_H), (0, 0, SOIL_H + GRASS_H / 2), MATERIALS["Grass"], bevel=0.62, segments=3, parent=root)

    # Rocks poking out of the earth edge. Kept inside the exact footprint and
    # above ground level so the asset still occupies precisely 60 x 60 x [0, h].
    for index, (x, y, radius) in enumerate((
        (-23.0, -28.2, 1.30), (8.0, -28.4, 1.05), (28.1, -6.0, 1.20),
        (-28.2, 12.0, 1.15), (17.0, 28.2, 1.25), (-11.0, 28.0, 1.00),
    )):
        sphere(
            f"Tile_Rock_{index}", collection, radius, (x, y, radius * 0.90),
            MATERIALS["Stone_Base"], parent=root, scale=(1.15, 1.0, 0.85),
        )

    box("Yard_Asphalt", collection, (50.0, 38.0, 0.56), (0, -8.0, YARD_TOP - 0.28), MATERIALS["Asphalt"], bevel=0.45, segments=3, parent=root)
    box("Building_Pad", collection, (44.0, 24.0, 0.92), (0, 15.8, PAD_TOP - 0.46), MATERIALS["Concrete"], bevel=0.38, segments=3, parent=root)
    box("Entry_Apron", collection, (13.0, 11.4, 0.30), (14.0, -24.2, YARD_TOP - 0.05), MATERIALS["Concrete"], bevel=0.30, parent=root)

    # Painted bay markings on the forecourt.
    for index, x in enumerate((8.0, 16.0, 24.0)):
        box(f"Bay_Line_{index}", collection, (0.46, 11.0, 0.12), (x, -18.0, YARD_TOP + 0.06), MATERIALS["Line_Paint"], bevel=0.03, parent=root)
    box("Bay_Line_Head", collection, (16.4, 0.46, 0.12), (16.0, -12.4, YARD_TOP + 0.06), MATERIALS["Line_Paint"], bevel=0.03, parent=root)

    # Kerb ring so the tile edge reads as a built lot.
    kerb_z = GROUND + 0.44
    for name, dims, loc in (
        ("Kerb_West", (1.6, 56.0, 0.90), (-28.3, 0, kerb_z)),
        ("Kerb_East", (1.6, 56.0, 0.90), (28.3, 0, kerb_z)),
        ("Kerb_Back", (56.0, 1.6, 0.90), (0, 28.3, kerb_z)),
        ("Kerb_Front_L", (28.0, 1.6, 0.90), (-13.6, -28.3, kerb_z)),
        ("Kerb_Front_R", (9.0, 1.6, 0.90), (23.8, -28.3, kerb_z)),
    ):
        box(name, collection, dims, loc, MATERIALS["Stone_Base"], bevel=0.24, parent=root)


def build_showroom(collection, root):
    box(
        "Base_Course", collection, (41.0, 21.6, BASE_H), (0, BUILDING_Y, PAD_TOP + BASE_H / 2),
        MATERIALS["Stone_Base"], bevel=0.42, segments=3, parent=root,
    )
    lofted("Wall_Main", collection, WALL_RINGS, (0, BUILDING_Y, BASE_TOP), MATERIALS["Sand_Wall"], bevel=0.35, segments=3, parent=root)
    lofted("Wall_Cornice", collection, CORNICE_RINGS, (0, BUILDING_Y, BASE_TOP), MATERIALS["Cream_Trim"], bevel=0.30, segments=3, parent=root)
    # Wainscot band so the tall wall is not one flat field of colour.
    lofted(
        "Wall_Wainscot", collection,
        ((0.00, 20.05, 10.35), (2.60, 19.95, 10.25), (3.05, 19.55, 9.85)),
        (0, BUILDING_Y, BASE_TOP), MATERIALS["Cream_Trim"], bevel=0.26, segments=2, parent=root,
    )

    # Corner timbers with gold caps.
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = sx * 19.1
            y = BUILDING_Y + sy * 9.4
            box(
                f"Corner_Post_{sx}_{sy}", collection, (2.3, 2.3, WALL_H - 1.6), (x, y, BASE_TOP + (WALL_H - 1.6) / 2),
                MATERIALS["Timber"], bevel=0.30, segments=3, parent=root,
            )
            box(f"Corner_Cap_{sx}_{sy}", collection, (2.9, 2.9, 0.7), (x, y, BASE_TOP + WALL_H - 1.4), MATERIALS["Gold_Trim"], bevel=0.18, parent=root)
            box(f"Corner_Shoe_{sx}_{sy}", collection, (2.9, 2.9, 0.8), (x, y, BASE_TOP + 0.3), MATERIALS["Gold_Trim"], bevel=0.18, parent=root)

    build_roof(collection, root)
    build_facade(collection, root)


def build_roof(collection, root):
    stepped_roof(
        "Roof", collection, ROOF_RINGS, (0, BUILDING_Y, EAVE_Z), MATERIALS["Roof_Tile"],
        courses=ROOF_COURSES, lip=0.66, lip_height=0.42, parent=root, bevel=0.14,
    )

    eave_hx, eave_hy = ROOF_RINGS[0][1] + 0.66, ROOF_RINGS[0][2] + 0.66

    # Chunky fascia board frame just under the eave.
    fascia_z = EAVE_Z - 0.95
    box("Fascia_Front", collection, (eave_hx * 2 + 0.8, 1.5, 2.0), (0, BUILDING_Y - eave_hy, fascia_z), MATERIALS["Cream_Trim"], bevel=0.30, parent=root)
    box("Fascia_Back", collection, (eave_hx * 2 + 0.8, 1.5, 2.0), (0, BUILDING_Y + eave_hy, fascia_z), MATERIALS["Cream_Trim"], bevel=0.30, parent=root)
    for sx in (-1, 1):
        box(f"Fascia_Side_{sx}", collection, (1.5, eave_hy * 2 + 0.8, 2.0), (sx * eave_hx, BUILDING_Y, fascia_z), MATERIALS["Cream_Trim"], bevel=0.30, parent=root)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(
                f"Fascia_Boss_{sx}_{sy}", collection, (2.4, 2.4, 2.7), (sx * eave_hx, BUILDING_Y + sy * eave_hy, fascia_z),
                MATERIALS["Gold_Trim"], bevel=0.34, parent=root,
            )

    # Rafter tails poking out of the front eave.
    for i in range(9):
        x = -20.0 + i * 5.0
        box(f"Rafter_{i}", collection, (1.0, 3.4, 1.0), (x, BUILDING_Y - eave_hy + 0.9, EAVE_Z - 1.95), MATERIALS["Timber_Dark"], bevel=0.18, parent=root)

    # Ridge cap and hip caps.
    cylinder(
        "Ridge_Cap", collection, 1.05, 19.6, (0, BUILDING_Y, RIDGE_Z + 0.15), MATERIALS["Roof_Ridge"],
        sides=12, rotation=(0, math.pi / 2, 0), parent=root, bevel=0.16,
    )
    ridge_half_x, ridge_half_y = ROOF_RINGS[-1][1], ROOF_RINGS[-1][2]
    eave_half_x, eave_half_y = eave_hx, eave_hy
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = Vector((sx * eave_half_x, BUILDING_Y + sy * eave_half_y, EAVE_Z + 0.2))
            b = Vector((sx * ridge_half_x, BUILDING_Y + sy * ridge_half_y, RIDGE_Z + 0.1))
            mid = (a + b) / 2
            span = (b - a)
            rotation = span.to_track_quat("Z", "Y").to_euler()
            cylinder(
                f"Hip_Cap_{sx}_{sy}", collection, 0.62, span.length, tuple(mid), MATERIALS["Roof_Ridge"],
                sides=10, rotation=tuple(rotation), parent=root, bevel=0.10,
            )

    # Rooftop signboard leaning over the front slope.
    sign_y = BUILDING_Y - 7.4
    sign_z = EAVE_Z + 4.6
    profile_solid(
        "Roof_Sign_Board", collection, arch_profile(25.0, 5.4, 2.6), 1.1, (0, sign_y, sign_z),
        MATERIALS["Cream_Trim"], bevel=0.22, rotation=(math.radians(-14), 0, 0), parent=root,
    )
    profile_solid(
        "Roof_Sign_Border", collection, arch_profile(26.6, 6.2, 3.0), 0.8, (0, sign_y + 0.42, sign_z - 0.8),
        MATERIALS["Accent_Blue"], bevel=0.24, rotation=(math.radians(-14), 0, 0), parent=root,
    )
    emblem(
        "Roof_Sign_Emblem", collection, (0, sign_y - 0.92, sign_z + 3.9), "Gold_Trim",
        parent=root, radius=2.6, thickness=0.75, rotation=(math.radians(-14), 0, 0),
    )
    for sx in (-1, 1):
        profile_solid(
            f"Roof_Sign_Star_{sx}", collection, star_profile(1.6), 0.6, (sx * 8.8, sign_y - 0.85, sign_z + 3.7),
            MATERIALS["Gold_Trim"], bevel=0.06, rotation=(math.radians(-14), 0, 0), parent=root,
        )
    for sx in (-1, 1):
        box(
            f"Roof_Sign_Leg_{sx}", collection, (1.0, 1.0, 5.4), (sx * 10.5, sign_y + 1.6, sign_z - 2.2),
            MATERIALS["Timber_Dark"], bevel=0.16, rotation=(math.radians(-14), 0, 0), parent=root,
        )
    for sx in (-1, 1):
        corner_flag(
            f"Roof_Flag_{sx}", collection, (sx * 22.4, BUILDING_Y - 12.6, EAVE_Z + 0.4), 6.4,
            "Accent_Red" if sx < 0 else "Accent_Blue", parent=root,
        )

    box("Roof_Vent", collection, (6.0, 4.2, 1.7), (13.0, BUILDING_Y + 6.5, RIDGE_Z - 3.2), MATERIALS["Metal_Grey"], bevel=0.24, parent=root)


def build_facade(collection, root):
    window_x = -8.0
    sill_rel = 1.6
    window_h = 7.0
    face_y = wall_face_y(sill_rel + window_h / 2)

    box(
        "Window_Reveal", collection, (23.4, 1.5, 11.6), (window_x, face_y + 0.15, BASE_TOP + sill_rel + 4.6),
        MATERIALS["Cream_Trim"], bevel=0.30, segments=3, parent=root,
    )
    profile_solid(
        "Window_Frame", collection, arch_profile(21.6, window_h, 2.7), 1.5,
        (window_x, face_y - 0.35, BASE_TOP + sill_rel), MATERIALS["Cream_Trim"], bevel=0.24, parent=root,
    )
    profile_solid(
        "Window_Glass", collection, arch_profile(19.6, window_h - 0.7, 2.2), 1.0,
        (window_x, face_y - 0.75, BASE_TOP + sill_rel + 0.45), MATERIALS["Glass_Warm"], bevel=0.10, parent=root,
    )
    box("Window_Sill", collection, (24.6, 2.3, 0.95), (window_x, face_y - 0.35, BASE_TOP + sill_rel - 0.3), MATERIALS["Stone_Base"], bevel=0.24, parent=root)
    for index, offset in enumerate((-6.6, 0.0, 6.6)):
        box(
            f"Mullion_{index}", collection, (0.7, 1.5, window_h + 1.4), (window_x + offset, face_y - 0.8, BASE_TOP + sill_rel + (window_h + 1.4) / 2 - 0.2),
            MATERIALS["Timber_Dark"], bevel=0.12, parent=root,
        )
    box("Transom", collection, (20.4, 1.5, 0.65), (window_x, face_y - 0.8, BASE_TOP + sill_rel + 4.6), MATERIALS["Timber_Dark"], bevel=0.12, parent=root)

    # Striped awning over the showroom glass.
    awning_z = BASE_TOP + sill_rel + window_h + 3.3
    awning = lofted(
        "Awning", collection,
        ((0.0, 13.6, 0.40), (0.6, 13.4, 3.2), (2.0, 12.4, 4.3)),
        (window_x, face_y - 2.6, awning_z), MATERIALS["Awning_Stripe"], bevel=0.24, segments=3, parent=root,
    )
    awning.rotation_euler = (math.radians(-10), 0, 0)
    for i in range(10):
        x = window_x - 11.7 + i * 2.6
        cylinder(
            f"Awning_Scallop_{i}", collection, 1.28, 2.4, (x, face_y - 6.5, awning_z - 0.55),
            MATERIALS["Awning_Stripe"], sides=12, rotation=(0, math.pi / 2, 0), parent=root, bevel=0.10,
        )
    box("Awning_Board", collection, (27.4, 1.1, 1.3), (window_x, face_y - 6.6, awning_z + 0.35), MATERIALS["Gold_Trim"], bevel=0.24, parent=root)

    # Entrance.
    door_x = 12.6
    door_face = wall_face_y(4.0)
    box("Door_Reveal", collection, (9.4, 1.5, 9.4), (door_x, door_face + 0.15, BASE_TOP + 4.5), MATERIALS["Cream_Trim"], bevel=0.28, segments=3, parent=root)
    profile_solid(
        "Door_Panel", collection, arch_profile(7.4, 6.6, 1.5), 1.1, (door_x, door_face - 0.5, BASE_TOP + 0.2),
        MATERIALS["Timber_Dark"], bevel=0.18, parent=root,
    )
    for sx in (-1, 1):
        box(f"Door_Leaf_{sx}", collection, (3.1, 1.0, 6.0), (door_x + sx * 1.75, door_face - 0.95, BASE_TOP + 3.3), MATERIALS["Timber"], bevel=0.16, parent=root)
        cylinder(
            f"Door_Handle_{sx}", collection, 0.16, 1.5, (door_x + sx * 0.55, door_face - 1.5, BASE_TOP + 3.4),
            MATERIALS["Gold_Trim"], sides=8, parent=root, bevel=0.04,
        )
    box("Door_Step", collection, (10.6, 3.2, 0.9), (door_x, door_face - 1.7, PAD_TOP + 1.1), MATERIALS["Stone_Base"], bevel=0.24, parent=root)
    box("Door_Step_Low", collection, (12.2, 4.4, 0.9), (door_x, door_face - 2.6, PAD_TOP + 0.35), MATERIALS["Stone_Base"], bevel=0.24, parent=root)

    # Small tiled canopy over the door, coursed like the main roof.
    canopy_z = BASE_TOP + 8.4
    stepped_roof(
        "Door_Canopy", collection, ((0.0, 6.8, 3.2), (2.1, 0.6, 0.4)),
        (door_x, door_face - 1.7, canopy_z), MATERIALS["Roof_Tile"],
        courses=3, lip=0.34, lip_height=0.22, parent=root, bevel=0.10,
    )
    box("Door_Canopy_Board", collection, (14.4, 1.0, 1.1), (door_x, door_face - 4.9, canopy_z - 0.15), MATERIALS["Gold_Trim"], bevel=0.22, parent=root)
    box("Door_Canopy_Fascia", collection, (14.4, 1.0, 1.1), (door_x, door_face - 4.9, canopy_z - 1.15), MATERIALS["Cream_Trim"], bevel=0.22, parent=root)
    for sx in (-1, 1):
        box(
            f"Door_Bracket_{sx}", collection, (0.9, 4.0, 0.9), (door_x + sx * 4.7, door_face - 2.4, canopy_z - 2.0),
            MATERIALS["Timber_Dark"], bevel=0.16, rotation=(math.radians(38), 0, 0), parent=root,
        )
        # Wall lanterns.
        lx = door_x + sx * 6.2
        box(f"Lantern_Arm_{sx}", collection, (0.4, 1.4, 0.4), (lx, door_face - 0.6, BASE_TOP + 7.2), MATERIALS["Timber_Dark"], bevel=0.08, parent=root)
        box(f"Lantern_Body_{sx}", collection, (1.5, 1.5, 1.9), (lx, door_face - 1.2, BASE_TOP + 6.4), MATERIALS["Gold_Trim"], bevel=0.22, parent=root)
        box(f"Lantern_Glow_{sx}", collection, (1.05, 1.05, 1.35), (lx, door_face - 1.2, BASE_TOP + 6.4), MATERIALS["Lamp_Glow"], bevel=0.14, parent=root)

    # Side wall detailing so the asset holds up when rotated.
    for index, y_offset in enumerate((-4.5, 1.5, 7.5)):
        for sx in (-1, 1):
            box(
                f"Side_Window_{sx}_{index}", collection, (1.4, 3.4, 4.6), (sx * 18.9, BUILDING_Y + y_offset, BASE_TOP + 6.4),
                MATERIALS["Cream_Trim"], bevel=0.20, parent=root,
            )
            box(
                f"Side_Glass_{sx}_{index}", collection, (1.1, 2.4, 3.5), (sx * 19.3, BUILDING_Y + y_offset, BASE_TOP + 6.4),
                MATERIALS["Glass_Warm"], bevel=0.12, parent=root,
            )
    box("Rear_Door", collection, (7.0, 1.4, 7.0), (-6.0, BUILDING_Y + 9.5, BASE_TOP + 3.5), MATERIALS["Timber_Dark"], bevel=0.20, parent=root)


def build_display_pavilion(collection, root):
    """A compact hero display stand. Deliberately short and pushed to the
    front-left corner so it frames the storefront instead of masking it."""
    centre_x, centre_y = -15.0, -17.5
    podium_z = YARD_TOP
    box(
        "Podium", collection, (21.0, 14.0, 1.0), (centre_x, centre_y, podium_z + 0.5),
        MATERIALS["Concrete"], bevel=0.32, segments=3, parent=root,
    )
    box("Podium_Trim", collection, (22.2, 15.2, 0.55), (centre_x, centre_y, podium_z + 0.28), MATERIALS["Gold_Trim"], bevel=0.20, parent=root)
    top = podium_z + 1.0

    post_h = 6.4
    posts = ((-9.0, -5.6), (9.0, -5.6), (-9.0, 5.6), (9.0, 5.6))
    for index, (dx, dy) in enumerate(posts):
        x, y = centre_x + dx, centre_y + dy
        box(f"Pavilion_Post_{index}", collection, (1.7, 1.7, post_h), (x, y, top + post_h / 2), MATERIALS["Timber"], bevel=0.24, segments=3, parent=root)
        box(f"Pavilion_Post_Cap_{index}", collection, (2.3, 2.3, 0.55), (x, y, top + post_h - 0.2), MATERIALS["Gold_Trim"], bevel=0.14, parent=root)
        box(f"Pavilion_Post_Shoe_{index}", collection, (2.3, 2.3, 0.7), (x, y, top + 0.35), MATERIALS["Gold_Trim"], bevel=0.14, parent=root)

    canopy_z = top + post_h
    lofted(
        "Pavilion_Canopy", collection,
        ((0.0, 11.4, 8.0), (0.5, 11.0, 7.6), (2.4, 4.6, 1.0)),
        (centre_x, centre_y, canopy_z), MATERIALS["Canopy_Stripe"], bevel=0.26, segments=3, cap_bottom=False, parent=root,
    )
    box("Pavilion_Fascia_F", collection, (23.4, 1.0, 1.3), (centre_x, centre_y - 7.8, canopy_z - 0.3), MATERIALS["Cream_Trim"], bevel=0.22, parent=root)
    box("Pavilion_Fascia_B", collection, (23.4, 1.0, 1.3), (centre_x, centre_y + 7.8, canopy_z - 0.3), MATERIALS["Cream_Trim"], bevel=0.22, parent=root)
    for sx in (-1, 1):
        box(f"Pavilion_Fascia_S_{sx}", collection, (1.0, 16.6, 1.3), (centre_x + sx * 11.2, centre_y, canopy_z - 0.3), MATERIALS["Cream_Trim"], bevel=0.22, parent=root)
    cylinder(
        "Pavilion_Ridge", collection, 0.68, 9.6, (centre_x, centre_y, canopy_z + 2.45), MATERIALS["Gold_Trim"],
        sides=10, rotation=(0, math.pi / 2, 0), parent=root, bevel=0.10,
    )
    for sx in (-1, 1):
        corner_flag(f"Pavilion_Flag_{sx}", collection, (centre_x + sx * 9.0, centre_y - 5.6, canopy_z + 0.4), 4.2, "Gold_Trim", parent=root)

    chunky_car("Display_Car_A", collection, (centre_x - 5.0, centre_y + 0.2, top), "Car_Red", rotation_z=math.radians(-96), parent=root)
    chunky_car("Display_Car_B", collection, (centre_x + 5.0, centre_y + 0.2, top), "Car_Cream", rotation_z=math.radians(-84), parent=root)


def build_forecourt(collection, root):
    chunky_car("Yard_Car_A", collection, (11.8, -18.0, YARD_TOP), "Car_Blue", rotation_z=math.radians(-90), parent=root)
    chunky_car("Yard_Car_B", collection, (19.8, -18.0, YARD_TOP), "Car_Teal", rotation_z=math.radians(-90), parent=root)
    chunky_car("Yard_Car_C", collection, (23.5, -3.5, YARD_TOP), "Car_Gold", rotation_z=math.radians(188), parent=root)

    # Pylon sign, kept low and pushed into the near street corner so it frames
    # the lot instead of covering the entrance in the isometric projection.
    px, py = 24.6, -24.6
    box("Pylon_Base", collection, (6.2, 6.2, 1.9), (px, py, YARD_TOP + 0.95), MATERIALS["Stone_Base"], bevel=0.32, segments=3, parent=root)
    box("Pylon_Base_Trim", collection, (7.0, 7.0, 0.6), (px, py, YARD_TOP + 0.3), MATERIALS["Gold_Trim"], bevel=0.18, parent=root)
    post_h = 7.4
    box("Pylon_Post", collection, (1.9, 1.9, post_h), (px, py, YARD_TOP + 1.9 + post_h / 2), MATERIALS["Timber"], bevel=0.26, segments=3, parent=root)
    sign_z = YARD_TOP + 1.9 + post_h - 1.0
    # Turn the board toward the locked isometric camera so the emblem reads.
    facing = math.radians(42.0)
    normal = (math.sin(facing), -math.cos(facing))
    across = (math.cos(facing), math.sin(facing))

    def on_board(dx: float, depth: float, z: float):
        return (
            px + across[0] * dx + normal[0] * depth,
            py + across[1] * dx + normal[1] * depth,
            z,
        )

    profile_solid(
        "Pylon_Board", collection, arch_profile(10.4, 6.2, 2.4), 1.2, (px, py, sign_z),
        MATERIALS["Accent_Blue"], bevel=0.24, rotation=(0, 0, facing), parent=root,
    )
    profile_solid(
        "Pylon_Face", collection, arch_profile(9.0, 5.4, 2.0), 1.5, (px, py, sign_z + 0.45),
        MATERIALS["Cream_Trim"], bevel=0.20, rotation=(0, 0, facing), parent=root,
    )
    emblem(
        "Pylon_Emblem", collection, on_board(0.0, 0.85, sign_z + 4.6), "Gold_Trim",
        parent=root, radius=2.1, thickness=0.6, rotation=(0, 0, facing),
    )
    for i, dx in enumerate((-2.9, 0.0, 2.9)):
        profile_solid(
            f"Pylon_Star_{i}", collection, star_profile(0.95), 0.5, on_board(dx, 0.85, sign_z + 1.5),
            MATERIALS["Gold_Trim"], bevel=0.05, rotation=(0, 0, facing), parent=root,
        )
    corner_flag("Pylon_Flag", collection, (px, py, sign_z + 6.6), 4.4, "Accent_Red", parent=root)

    # Bunting: two runs along the street frontage and the right flank, kept
    # clear of the storefront so the showroom glass stays readable.
    pole_x, pole_y = -26.4, -26.4
    pole_h = 13.4
    box("Bunting_Pole", collection, (1.6, 1.6, pole_h), (pole_x, pole_y, YARD_TOP + pole_h / 2), MATERIALS["Timber"], bevel=0.26, parent=root)
    sphere("Bunting_Pole_Cap", collection, 0.85, (pole_x, pole_y, YARD_TOP + pole_h + 0.3), MATERIALS["Gold_Trim"], parent=root)
    bunting_left = (pole_x, pole_y, YARD_TOP + pole_h - 0.6)
    pennant_line("Bunting_Front", collection, bunting_left, (px, py, sign_z + 2.4), sag=3.8, count=14, parent=root)
    pennant_line(
        "Bunting_Right", collection, (px, py, sign_z + 2.4), (19.4, BUILDING_Y - 9.6, BASE_TOP + WALL_H - 1.6),
        sag=3.4, count=12, parent=root,
    )

    # Ground props.
    planter("Planter_L", collection, (7.4, wall_face_y(1.0) - 4.2, PAD_TOP), parent=root)
    planter("Planter_R", collection, (18.6, wall_face_y(1.0) - 4.2, PAD_TOP), parent=root)
    tyre_stack("Tyres_A", collection, (-25.6, 6.6, YARD_TOP), 3, parent=root)
    tyre_stack("Tyres_B", collection, (-22.4, 8.2, YARD_TOP), 2, parent=root)
    oil_drum("Drum_A", collection, (25.8, 6.4, YARD_TOP), "Accent_Blue", parent=root)
    oil_drum("Drum_B", collection, (23.0, 8.0, YARD_TOP), "Accent_Red", parent=root)
    for index, (x, y) in enumerate(((1.6, -25.4), (-1.4, -22.0), (4.0, -28.0))):
        traffic_cone(f"Cone_{index}", collection, (x, y, YARD_TOP), parent=root)

    # A-frame price board.
    board_x, board_y = 3.4, -7.5
    for sy, angle in ((-1, math.radians(16)), (1, math.radians(-16))):
        box(
            f"Board_Leaf_{sy}", collection, (6.4, 0.5, 6.0), (board_x, board_y + sy * 0.9, YARD_TOP + 3.0),
            MATERIALS["Timber_Dark"] if sy > 0 else MATERIALS["Cream_Trim"], bevel=0.18, rotation=(angle, 0, 0), parent=root,
        )
    box("Board_Header", collection, (6.8, 2.4, 0.9), (board_x, board_y, YARD_TOP + 6.2), MATERIALS["Accent_Red"], bevel=0.22, parent=root)
    for i, dx in enumerate((-1.6, 0.0, 1.6)):
        profile_solid(
            f"Board_Star_{i}", collection, star_profile(0.7), 0.4, (board_x + dx, board_y - 1.1, YARD_TOP + 3.4),
            MATERIALS["Gold_Trim"], bevel=0.04, parent=root,
        )

    # Landscaping.
    tree("Tree_L", collection, (-25.0, 23.0, GROUND), "Leaf", height=13.0, parent=root)
    tree("Tree_R", collection, (25.0, 23.0, GROUND), "Leaf", height=11.5, parent=root)
    for index, x in enumerate((-14.0, -7.0, 0.0, 7.0, 14.0)):
        bush(f"Hedge_{index}", collection, (x, 27.6, GROUND + 0.6), 1.8, parent=root)
    for index, y in enumerate((-4.0, 2.0)):
        bush(f"Hedge_W_{index}", collection, (-27.2, y, GROUND + 0.6), 1.7, parent=root)
    bush("Hedge_E_0", collection, (27.2, 8.0, GROUND + 0.6), 1.7, parent=root)


def validate_bounds(design: bpy.types.Collection, *, tolerance: float = 0.02) -> None:
    """Fail the build if the asset breaks the grid contract.

    The city places assets by footprint, so anything hanging outside
    ``LOT x LOT`` or dipping below ground level would overlap a neighbouring
    cell or float. Modifiers are evaluated first — bevels and solidify move
    real geometry.
    """
    depsgraph = bpy.context.evaluated_depsgraph_get()
    low = Vector((math.inf, math.inf, math.inf))
    high = Vector((-math.inf, -math.inf, -math.inf))
    offenders: list[tuple[float, str]] = []
    for obj in design.all_objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        matrix = evaluated.matrix_world
        worst = 0.0
        for vertex in mesh.vertices:
            world = matrix @ vertex.co
            low = Vector((min(low[i], world[i]) for i in range(3)))
            high = Vector((max(high[i], world[i]) for i in range(3)))
            worst = max(worst, abs(world.x) - HALF, abs(world.y) - HALF, -world.z)
        evaluated.to_mesh_clear()
        if worst > tolerance:
            offenders.append((worst, obj.name))

    for overshoot, name in sorted(offenders, reverse=True)[:12]:
        print(f"[validate] {name} overshoots by {overshoot:.2f}")

    problems = []
    if low.x < -HALF - tolerance or high.x > HALF + tolerance:
        problems.append(f"x {low.x:.2f}..{high.x:.2f} exceeds +/-{HALF}")
    if low.y < -HALF - tolerance or high.y > HALF + tolerance:
        problems.append(f"y {low.y:.2f}..{high.y:.2f} exceeds +/-{HALF}")
    if low.z < -tolerance:
        problems.append(f"z {low.z:.2f} dips below ground")
    print(
        f"[validate] bounds x {low.x:.2f}..{high.x:.2f}  "
        f"y {low.y:.2f}..{high.y:.2f}  z {low.z:.2f}..{high.z:.2f}"
    )
    if problems:
        raise SystemExit("[validate] grid contract violated: " + "; ".join(problems))


def build_shop() -> bpy.types.Collection:
    collection = bpy.data.collections.new("Stylized_Used_Car_Shop_3x3")
    bpy.context.scene.collection.children.link(collection)

    root = bpy.data.objects.new("Stylized_Used_Car_Shop_3x3_Root", None)
    root.empty_display_size = 4.0
    collection.objects.link(root)
    root["city_asset_id"] = "playerMediumDealer"
    root["footprint_cells"] = [FOOTPRINT_CELLS, FOOTPRINT_CELLS]
    root["world_footprint"] = [LOT, LOT]
    root["origin"] = "footprintCenterAtGround"
    root["front_edge"] = "-Y"
    root["art_style"] = "stylized_v1"

    build_terrain(collection, root)
    build_showroom(collection, root)
    build_display_pavilion(collection, root)
    build_forecourt(collection, root)
    return collection


# --------------------------------------------------------------------------
# scenes, lighting, render
# --------------------------------------------------------------------------

def activate_scene(scene: bpy.types.Scene) -> bpy.types.Scene:
    for manager in bpy.data.window_managers:
        for window in manager.windows:
            window.scene = scene
            return scene
    return scene


def look_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_cycles(scene: bpy.types.Scene, samples: int) -> None:
    scene.render.engine = "CYCLES"
    cycles_prefs = bpy.context.preferences.addons.get("cycles")
    if cycles_prefs is not None:
        prefs = cycles_prefs.preferences
        for backend in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = backend
                prefs.get_devices()
                if any(device.type == backend for device in prefs.devices):
                    break
            except Exception:  # noqa: BLE001
                continue
        for device in prefs.devices:
            device.use = device.type != "CPU"
        scene.cycles.device = "GPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.adaptive_threshold = 0.02
    scene.cycles.max_bounces = 4
    scene.cycles.diffuse_bounces = 2
    scene.cycles.glossy_bounces = 2
    scene.cycles.transparent_max_bounces = 4
    scene.cycles.denoising_use_gpu = True


def configure_world(scene: bpy.types.Scene) -> None:
    world = bpy.data.worlds.new(f"{scene.name}_World")
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    coord = _new(nt, "ShaderNodeTexCoord", -800, 0)
    separate = _new(nt, "ShaderNodeSeparateXYZ", -600, 0)
    nt.links.new(coord.outputs["Generated"], separate.inputs["Vector"])
    ramp = _new(nt, "ShaderNodeValToRGB", -400, 0)
    ramp.color_ramp.elements[0].position = 0.30
    ramp.color_ramp.elements[0].color = rgb("#F4E6C8")
    ramp.color_ramp.elements[1].position = 0.78
    ramp.color_ramp.elements[1].color = rgb("#8FBEE0")
    nt.links.new(separate.outputs["Z"], ramp.inputs["Fac"])
    background = _new(nt, "ShaderNodeBackground", -160, 0)
    nt.links.new(ramp.outputs["Color"], background.inputs["Color"])
    background.inputs["Strength"].default_value = 1.05
    output = _new(nt, "ShaderNodeOutputWorld", 60, 0)
    nt.links.new(background.outputs["Background"], output.inputs["Surface"])
    scene.world = world


def configure_view(scene: bpy.types.Scene) -> None:
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.use_file_extension = True
    scene.render.filter_size = 1.3
    # "Standard" keeps the authored palette saturated. AgX rolls colour off
    # toward grey, which reads as muddy for a toy-bright mobile game look.
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    scene.view_settings.exposure = -0.05
    scene.view_settings.gamma = 1.0

    # Gentle S-curve: deepen the shadows, hold the highlights off pure white.
    scene.view_settings.use_curve_mapping = True
    mapping = scene.view_settings.curve_mapping
    curve = mapping.curves[3]
    curve.points.new(0.22, 0.16)
    curve.points.new(0.55, 0.58)
    curve.points.new(0.86, 0.92)
    mapping.white_level = (0.97, 0.97, 0.97)
    mapping.update()


def add_lighting(scene: bpy.types.Scene, collection: bpy.types.Collection, *, target=(0, 0, 8.0)) -> None:
    """Warm key from screen-upper-left, cool sky fill, cool rim from behind."""
    sun_data = bpy.data.lights.new(f"{scene.name}_Key", "SUN")
    sun_data.energy = 3.6
    sun_data.angle = math.radians(9.0)
    sun_data.color = rgb("#FFE7B8")[:3]
    sun = bpy.data.objects.new(f"{scene.name}_Key", sun_data)
    # Screen-upper-left for the locked 45 deg isometric: lights the front and
    # left faces, leaves the right face as the shade side.
    sun.location = (-112, -118, 150)
    look_at(sun, (0, 4, 4))
    collection.objects.link(sun)

    fill_data = bpy.data.lights.new(f"{scene.name}_Fill", "AREA")
    fill_data.energy = 20000
    fill_data.shape = "DISK"
    fill_data.size = 130
    fill_data.color = rgb("#C6DEF5")[:3]
    fill = bpy.data.objects.new(f"{scene.name}_Fill", fill_data)
    fill.location = (135, -95, 95)
    look_at(fill, target)
    collection.objects.link(fill)

    rim_data = bpy.data.lights.new(f"{scene.name}_Rim", "AREA")
    rim_data.energy = 20000
    rim_data.shape = "RECTANGLE"
    rim_data.size = 90
    rim_data.size_y = 60
    rim_data.color = rgb("#FFD9A8")[:3]
    rim = bpy.data.objects.new(f"{scene.name}_Rim", rim_data)
    rim.location = (70, 160, 95)
    look_at(rim, target)
    collection.objects.link(rim)

    bounce_data = bpy.data.lights.new(f"{scene.name}_Bounce", "AREA")
    bounce_data.energy = 6000
    bounce_data.shape = "RECTANGLE"
    bounce_data.size = 140
    bounce_data.size_y = 140
    bounce_data.color = rgb("#F7E4BE")[:3]
    bounce = bpy.data.objects.new(f"{scene.name}_Bounce", bounce_data)
    bounce.location = (-120, 40, 22)
    look_at(bounce, (0, 6, 10))
    collection.objects.link(bounce)


def add_backdrop(scene, collection, size=(320, 320)):
    box(f"{scene.name}_Backdrop", collection, (size[0], size[1], 1.0), (0, 0, -0.62), MATERIALS["Backdrop"], bevel=0.0)


def make_scene(
    name: str,
    design: bpy.types.Collection,
    filename: str,
    *,
    width: int,
    height: int,
    camera_location: tuple[float, float, float],
    target: tuple[float, float, float],
    ortho_scale: float | None,
    samples: int,
    focal: float = 85.0,
) -> bpy.types.Scene:
    scene = bpy.data.scenes.new(name)
    scene.collection.children.link(design)
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    configure_cycles(scene, samples)
    configure_world(scene)
    configure_view(scene)

    rig = bpy.data.collections.new(f"{name}_Rig")
    scene.collection.children.link(rig)

    camera_data = bpy.data.cameras.new(f"{name}_Camera")
    if ortho_scale is not None:
        camera_data.type = "ORTHO"
        camera_data.ortho_scale = ortho_scale
    else:
        camera_data.type = "PERSP"
        camera_data.lens = focal
    camera = bpy.data.objects.new(f"{name}_Camera", camera_data)
    camera.location = camera_location
    look_at(camera, target)
    rig.objects.link(camera)
    scene.camera = camera

    add_lighting(scene, rig, target=target)
    add_backdrop(scene, rig)
    scene.render.filepath = str(PREVIEW_DIR / filename)
    return scene


def game_camera_location(distance: float = 200.0) -> tuple[float, float, float]:
    """The locked city projection: 45 deg azimuth, 35.26439 deg elevation."""
    elevation = math.radians(35.26439)
    azimuth = math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    return (
        horizontal * math.cos(azimuth),
        -horizontal * math.sin(azimuth),
        distance * math.sin(elevation),
    )


def make_orientation_scene(design: bpy.types.Collection, samples: int) -> bpy.types.Scene:
    scene = bpy.data.scenes.new("Scene_Orientations")
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 620
    configure_cycles(scene, samples)
    configure_world(scene)
    configure_view(scene)

    instances = bpy.data.collections.new("Orientation_Instances")
    scene.collection.children.link(instances)
    # Lay the four rotations out along the camera's screen-right ground vector.
    for index, angle in enumerate((0, 90, 180, 270)):
        offset = (index - 1.5) * 72.0
        instance = bpy.data.objects.new(f"Orientation_{angle}", None)
        instance.instance_type = "COLLECTION"
        instance.instance_collection = design
        instance.location = (offset, offset, 0)
        instance.rotation_euler = (0, 0, math.radians(angle))
        instances.objects.link(instance)

    rig = bpy.data.collections.new("Orientation_Rig")
    scene.collection.children.link(rig)
    camera_data = bpy.data.cameras.new("Orientation_Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 412.0
    camera = bpy.data.objects.new("Orientation_Camera", camera_data)
    camera.location = game_camera_location(460.0)
    look_at(camera, (0, 0, 12.0))
    rig.objects.link(camera)
    scene.camera = camera
    add_lighting(scene, rig, target=(0, 0, 8.0))
    add_backdrop(scene, rig, size=(900, 900))
    scene.render.filepath = str(PREVIEW_DIR / "stylized_used_car_shop_orientations.png")
    return scene


def render_scene(scene: bpy.types.Scene) -> None:
    activate_scene(scene)
    print(f"[render] {scene.name} -> {scene.render.filepath}")
    bpy.ops.render.render(write_still=True)


# --------------------------------------------------------------------------
# bake + export
# --------------------------------------------------------------------------

def bake_and_export(design: bpy.types.Collection, stem: str, *, resolution: int, samples: int) -> None:
    """Flatten the procedural look into one baked texture set and export it."""
    scene = bpy.data.scenes.new("Scene_Bake")
    activate_scene(scene)
    configure_cycles(scene, samples)
    configure_world(scene)
    scene.cycles.bake_type = "DIFFUSE"
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.bake.margin = 6

    scene.collection.children.link(design)
    bakeable = [obj for obj in design.all_objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bakeable:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = bakeable[0]
    bpy.ops.object.duplicate()
    duplicates = list(bpy.context.selected_objects)

    work = bpy.data.collections.new("Bake_Work")
    scene.collection.children.link(work)
    for obj in duplicates:
        for parent_collection in list(obj.users_collection):
            parent_collection.objects.unlink(obj)
        work.objects.link(obj)
        # Drop the link to the design root empty: it stays behind in the
        # design collection, and glTF skips any object whose parent is not
        # part of the exported scene.
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
    scene.collection.children.unlink(design)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in duplicates:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = duplicates[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.join()
    merged = bpy.context.view_layer.objects.active
    merged.name = f"{stem}_baked"

    print(f"[bake] unwrapping {len(merged.data.polygons)} faces")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.0035, correct_aspect=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    combined = bpy.data.images.new(f"{stem}_basecolor", resolution, resolution, alpha=False)
    emissive = bpy.data.images.new(f"{stem}_emissive", resolution, resolution, alpha=False)

    targets: list[bpy.types.ShaderNodeTexImage] = []
    for slot in merged.material_slots:
        if slot.material is None:
            continue
        slot.material = slot.material.copy()
        nt = slot.material.node_tree
        # A DIFFUSE-colour bake returns base_colour * (1 - metallic), so any
        # metal reads as near-black. These are matte stylized surfaces anyway;
        # drop metallic so gold trim bakes as gold.
        for node in nt.nodes:
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Metallic"].default_value = 0.0
        node = nt.nodes.new("ShaderNodeTexImage")
        node.location = (-1800, 600)
        node.select = True
        nt.nodes.active = node
        targets.append(node)

    def bake_pass(kind: str, image: bpy.types.Image, **settings) -> None:
        for node in targets:
            node.image = image
            node.id_data.nodes.active = node
        print(f"[bake] {kind} @ {resolution}px")
        bpy.ops.object.bake(type=kind, margin=6, use_clear=True, **settings)

    # The materials already carry their own ambient occlusion, and joining the
    # asset into one mesh widens that AO to cover contact between parts. A
    # separate AO pass on top of that double-darkens every crease into mud.
    bake_pass("DIFFUSE", combined, pass_filter={"COLOR"})
    bake_pass("EMIT", emissive)

    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    for image, filename in ((combined, f"{stem}_basecolor.png"), (emissive, f"{stem}_emissive.png")):
        image.filepath_raw = str(EXPORT_DIR / filename)
        image.file_format = "PNG"
        image.save()

    export_material = bpy.data.materials.new(f"{stem}_baked")
    export_material.use_nodes = True
    nt = export_material.node_tree
    nt.nodes.clear()
    base_tex = _new(nt, "ShaderNodeTexImage", -600, 200)
    base_tex.image = combined
    emit_tex = _new(nt, "ShaderNodeTexImage", -600, -160)
    emit_tex.image = emissive
    bsdf = _new(nt, "ShaderNodeBsdfPrincipled", -200, 100)
    nt.links.new(base_tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(emit_tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.78
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
    output = _new(nt, "ShaderNodeOutputMaterial", 120, 100)
    nt.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    merged.data.materials.clear()
    merged.data.materials.append(export_material)

    bpy.ops.object.select_all(action="DESELECT")
    merged.select_set(True)
    bpy.context.view_layer.objects.active = merged
    export_selection(stem)
    print(f"[bake] exported {stem} ({len(merged.data.polygons)} tris after triangulation)")
    render_baked_check(merged, samples)


def render_baked_check(merged: bpy.types.Object, samples: int) -> None:
    """Render the flattened single-texture asset the way a runtime would see it.

    If this diverges from the beauty render, the procedural look did not
    survive the bake and the asset is not shippable.
    """
    scene = bpy.data.scenes.new("Scene_BakedCheck")
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 1000
    configure_cycles(scene, max(samples, 48))
    configure_world(scene)
    configure_view(scene)

    check = bpy.data.collections.new("Baked_Check")
    scene.collection.children.link(check)
    instance = merged.copy()
    instance.data = merged.data
    check.objects.link(instance)

    camera_data = bpy.data.cameras.new("Baked_Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 86.0
    camera = bpy.data.objects.new("Baked_Camera", camera_data)
    camera.location = game_camera_location(220.0)
    look_at(camera, (0, 0, 8.0))
    check.objects.link(camera)
    scene.camera = camera

    add_lighting(scene, check, target=(0, 0, 8.0))
    add_backdrop(scene, check)
    scene.render.filepath = str(PREVIEW_DIR / "stylized_used_car_shop_baked_check.png")
    render_scene(scene)


def export_selection(stem: str) -> None:
    glb_path = EXPORT_DIR / f"{stem}.glb"
    usdz_path = EXPORT_DIR / f"{stem}.usdz"
    print(f"[export] {glb_path.name}")
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
    print(f"[export] {usdz_path.name}")
    bpy.ops.wm.usd_export(
        filepath=str(usdz_path),
        selected_objects_only=True,
        export_animation=False,
        export_materials=True,
        export_normals=True,
        export_uvmaps=True,
        export_custom_properties=True,
        export_textures_mode="NEW",
        use_instancing=False,
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


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def reset_file() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)
    for world in list(bpy.data.worlds):
        bpy.data.worlds.remove(world)
    for scene in list(bpy.data.scenes)[1:]:
        bpy.data.scenes.remove(scene)
    bpy.context.scene.name = "Scene_Build"


def parse_args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return {
        "quick": "--quick" in argv,
        "bake": "--no-bake" not in argv,
        "hero_only": "--hero-only" in argv,
        "bake_only": "--bake-only" in argv,
    }


def main() -> None:
    options = parse_args()
    quick = options["quick"]
    samples = 48 if quick else 256
    bake_resolution = 1024 if quick else 2048
    bake_samples = 24 if quick else 96
    scale = 0.45 if quick else 1.0

    for directory in (OUTPUT_DIR, PREVIEW_DIR, EXPORT_DIR):
        directory.mkdir(parents=True, exist_ok=True)

    reset_file()
    build_materials()
    design = build_shop()
    validate_bounds(design)
    bpy.context.scene.collection.children.unlink(design)

    def res(width, height):
        return int(width * scale), int(height * scale)

    scenes = [
        make_scene(
            "Scene_Hero", design, "stylized_used_car_shop_hero.png",
            width=res(1500, 1250)[0], height=res(1500, 1250)[1],
            camera_location=(96, -104, 76), target=(0, 3.0, 13.0),
            ortho_scale=77.0, samples=samples,
        ),
    ]
    if not (options["hero_only"] or options["bake_only"]):
        scenes.extend([
            make_scene(
                "Scene_GameCamera", design, "stylized_used_car_shop_game_camera.png",
                width=res(1100, 1000)[0], height=res(1100, 1000)[1],
                camera_location=game_camera_location(220.0), target=(0, 0, 8.0),
                ortho_scale=86.0, samples=samples,
            ),
            make_scene(
                "Scene_Storefront", design, "stylized_used_car_shop_storefront.png",
                width=res(1500, 1000)[0], height=res(1500, 1000)[1],
                camera_location=(34, -128, 46), target=(1.0, 2.0, 13.0),
                ortho_scale=None, samples=samples, focal=135.0,
            ),
        ])

    if not options["bake_only"]:
        for scene in scenes:
            render_scene(scene)

    if not (options["hero_only"] or options["bake_only"]):
        render_scene(make_orientation_scene(design, samples))

    if options["bake"]:
        try:
            bake_and_export(design, "stylized_used_car_shop_3x3", resolution=bake_resolution, samples=bake_samples)
        except Exception as exc:  # noqa: BLE001
            print(f"[bake] FAILED: {exc}")
            import traceback

            traceback.print_exc()

    activate_scene(scenes[0])
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), compress=True)
    print(f"[done] saved {BLEND_PATH}")


if __name__ == "__main__":
    main()
