"""Shared library for the low-poly city kit.

Every city asset is authored against one budget and one look:

* **Geometry carries silhouette only.** No bevel modifiers, no modelled trim,
  no modelled tile courses. A 3x3 asset is a few hundred triangles.
* **Texture carries everything else.** Procedural stylized materials are baked
  down to a base colour + normal + emissive set, so panel lines, roof courses,
  timber grain, painted edge highlights, and ambient occlusion all survive as
  texture rather than as vertices.
* **Soft edges come from the Bevel shader node**, not from geometry. A plain
  box shades like a rounded one.

Import from a build script with::

    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import citykit

Requires Cycles for the Bevel / Ambient Occlusion shader nodes and for baking.
"""

from __future__ import annotations

import math

import bpy
from mathutils import Vector


# --------------------------------------------------------------------------
# grid contract (must match UsedCarCity/CityAssetCatalog.swift)
# --------------------------------------------------------------------------

CELL = 20.0
ORIGIN = "footprintCenterAtGround"
FRONT_EDGE = "-Y"


def lot_size(cells: int) -> float:
    return CELL * cells


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
    "sidewalk": "#A2977F",
    "sidewalk_shade": "#6E6653",
    "office_glass": "#7FB4C9",
    "office_glass_lit": "#FFE0A6",
    "office_spandrel": "#3E4A57",
    "office_frame": "#93A2AF",
    "membrane": "#6E6F73",
    "membrane_seam": "#4C4D51",
    "roof_unit": "#9AA0A6",
    "gravel_roof": "#8A8579",
    "metal_shed": "#8FA2A8",
    "metal_shed_dark": "#54646B",
    "rust": "#9A5A2C",
    "brick": "#B4614A",
    "brick_dark": "#7A3A2B",
    "render_grey": "#CBC6BB",
    "render_blue": "#8FA8B8",
    "roof_terracotta": "#C4633A",
    "roof_slate": "#4A5560",
    "roof_green": "#4E8C63",
    "kerb": "#B6AE9C",
    "paint_yellow": "#E8C24A",
    "glass": "#FFD182",
    "glass_cool": "#A9CBD4",
    "showroom_glass": "#B7D6E0",
    "showroom_glass_deep": "#43718A",
    "showroom_spandrel": "#2B4E60",
    "sky_reflect": "#CFE6F2",
    "showroom_interior": "#F2E3C4",
    "showroom_floor": "#CFC8BA",
    "showroom_ceiling": "#FFF6E0",
    "dealer_frame": "#EDF1F4",
    "dealer_frame_dark": "#54606B",
    "dealer_wall": "#E7E9E6",
    "canopy_soffit": "#6C7880",
    "glass_cool_dark": "#6C8E9B",
    "glass_dark": "#12414F",
    "tyre": "#2E2E34",
    "chrome": "#CDD2D8",
    "leaf": "#4FA327",
    "leaf_light": "#8CD246",
    "leaf_shade": "#22521A",
    "backdrop": "#D9D2C2",
}

MATERIALS: dict[str, bpy.types.Material] = {}


def col(key: str) -> tuple[float, float, float, float]:
    return rgb(PALETTE[key])


def mat(name: str) -> bpy.types.Material:
    return MATERIALS[name]


# --------------------------------------------------------------------------
# shader node plumbing
# --------------------------------------------------------------------------

def _new(nt, kind: str, x: float, y: float):
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


def _math(nt, operation, a, b=None, c=None, x=0, y=0):
    node = _new(nt, "ShaderNodeMath", x, y)
    node.operation = operation
    for index, value in enumerate((a, b, c)):
        if value is None:
            continue
        if isinstance(value, (int, float)):
            node.inputs[index].default_value = value
        else:
            nt.links.new(value, node.inputs[index])
    return node.outputs[0]


def _darker(colour, factor):
    return tuple(channel * factor for channel in colour[:3]) + (1.0,)


def _generated(nt, x=-1600, y=-260):
    """Normalised 0..1 bounding-box coordinates for the owning object."""
    node = _new(nt, "ShaderNodeTexCoord", x, y)
    return node.outputs["Generated"]


def _axes(nt, coord, x=-1300, y=300):
    """Split an object-space vector and return (x, y, z, x+y).

    ``x + y`` is the horizontal driver for every wall feature: plain X is
    constant across an X-facing wall and would collapse a window grid into
    horizontal stripes on the side elevations.
    """
    node = _new(nt, "ShaderNodeSeparateXYZ", x, y)
    nt.links.new(coord, node.inputs["Vector"])
    plan = _math(nt, "ADD", node.outputs["X"], node.outputs["Y"], x=x + 160, y=y + 140)
    return node.outputs["X"], node.outputs["Y"], node.outputs["Z"], plan


def _cell_distance(nt, source, period, x=-1000, y=300):
    """|frac(value / period) - 0.5| — 0 at a cell centre, 0.5 at its border."""
    scaled = _math(nt, "MULTIPLY", source, 1.0 / max(period, 1e-4), x=x, y=y)
    wrapped = _math(nt, "WRAP", scaled, 1.0, 0.0, x=x + 150, y=y)
    centred = _math(nt, "SUBTRACT", wrapped, 0.5, x=x + 300, y=y)
    return _math(nt, "ABSOLUTE", centred, x=x + 450, y=y)


def _cell_index(nt, source, period, x=-1000, y=100):
    scaled = _math(nt, "MULTIPLY", source, 1.0 / max(period, 1e-4), x=x, y=y)
    return _math(nt, "FLOOR", scaled, x=x + 150, y=y)


def _hash01(nt, a, b, x=-700, y=100):
    """A stable 0..1 value per (a, b) integer cell."""
    combine = _new(nt, "ShaderNodeCombineXYZ", x, y)
    nt.links.new(a, combine.inputs["X"])
    nt.links.new(b, combine.inputs["Y"])
    combine.inputs["Z"].default_value = 0.0
    noise = _new(nt, "ShaderNodeTexWhiteNoise", x + 160, y)
    noise.noise_dimensions = "3D"
    nt.links.new(combine.outputs["Vector"], noise.inputs["Vector"])
    return noise.outputs["Value"]


def _edge_distance(nt, x=-1300, y=-500):
    """Distance to the nearest plan edge of the object, 0 at the edge, 0.5 mid.

    Used for parapet shadows and kerbs — one gradient that does more for
    perceived depth than any amount of geometry.
    """
    generated = _generated(nt, x, y)
    split = _new(nt, "ShaderNodeSeparateXYZ", x + 180, y)
    nt.links.new(generated, split.inputs["Vector"])
    gx, gy = split.outputs["X"], split.outputs["Y"]
    inv_x = _math(nt, "SUBTRACT", 1.0, gx, x=x + 340, y=y + 120)
    inv_y = _math(nt, "SUBTRACT", 1.0, gy, x=x + 340, y=y - 120)
    min_x = _math(nt, "MINIMUM", gx, inv_x, x=x + 480, y=y + 120)
    min_y = _math(nt, "MINIMUM", gy, inv_y, x=x + 480, y=y - 120)
    return _math(nt, "MINIMUM", min_x, min_y, x=x + 620, y=y)


def _generated_z(nt, x=-1300, y=-760):
    generated = _generated(nt, x, y)
    split = _new(nt, "ShaderNodeSeparateXYZ", x + 180, y)
    nt.links.new(generated, split.inputs["Vector"])
    return split.outputs["Z"]


def _range(nt, source, from_min, from_max, to_min=0.0, to_max=1.0, x=0, y=0):
    """``_map_range`` that returns the socket rather than the node."""
    return _map_range(nt, x, y, source, from_min, from_max, to_min, to_max).outputs["Result"]


def _mixc(nt, a, b, fac, x=0, y=0):
    """``_mix`` that returns the colour socket."""
    return _mix(nt, x, y, a, b, fac).outputs["Color"]


def _bay_local(nt, source, period, x=-1000, y=300):
    """Signed offset from the centre of a cell, in world units.

    Everything about a window — its opening, its surround, its sill, its
    glazing bars — is placed relative to the centre of its bay, so this is the
    coordinate the whole facade system is built on.
    """
    scaled = _math(nt, "MULTIPLY", source, 1.0 / max(period, 1e-4), x=x, y=y)
    wrapped = _math(nt, "WRAP", scaled, 1.0, 0.0, x=x + 150, y=y)
    centred = _math(nt, "SUBTRACT", wrapped, 0.5, x=x + 300, y=y)
    return _math(nt, "MULTIPLY", centred, period, x=x + 450, y=y)


def _abs(nt, source, x=0, y=0):
    return _math(nt, "ABSOLUTE", source, x=x, y=y)


def _rect(nt, du, dv, half_w, half_h, feather=0.08, x=0, y=0):
    """1 inside an axis-aligned rectangle centred on the cell, 0 outside."""
    mx = _range(nt, du, half_w, half_w + feather, 1.0, 0.0, x=x, y=y + 60)
    my = _range(nt, dv, half_h, half_h + feather, 1.0, 0.0, x=x, y=y - 60)
    return _math(nt, "MULTIPLY", mx, my, x=x + 160, y=y)


def _ellipse(nt, du, dv, radius_u, radius_v, feather=0.14, x=0, y=0):
    """1 inside an ellipse, 0 outside.

    Rectangles at this texel size read as a pixel-art staircase. Anything
    organic — a car, a shrub, a person — needs a rounded distance field.
    """
    su = _math(nt, "DIVIDE", du, max(radius_u, 1e-4), x=x, y=y + 60)
    sv = _math(nt, "DIVIDE", dv, max(radius_v, 1e-4), x=x, y=y - 60)
    vector = _new(nt, "ShaderNodeCombineXYZ", x + 160, y)
    nt.links.new(su, vector.inputs["X"])
    nt.links.new(sv, vector.inputs["Y"])
    vector.inputs["Z"].default_value = 0.0
    length = _new(nt, "ShaderNodeVectorMath", x + 320, y)
    length.operation = "LENGTH"
    nt.links.new(vector.outputs["Vector"], length.inputs[0])
    return _range(nt, length.outputs["Value"], 1.0, 1.0 + feather, 1.0, 0.0, x=x + 480, y=y)


def _rounded_rect(nt, du, dv, half_w, half_h, radius, feather=0.12, x=0, y=0):
    """1 inside a rounded rectangle, 0 outside — the standard 2D SDF.

    A plain rectangle staircases and a plain ellipse turns a car into a heart.
    A rounded rectangle keeps the flat bottom a vehicle needs while rounding
    the corners the texel size would otherwise shatter.
    """
    qx = _math(nt, "MAXIMUM", _math(nt, "SUBTRACT", du, max(half_w - radius, 0.0), x=x, y=y + 70), 0.0, x=x + 150, y=y + 70)
    qy = _math(nt, "MAXIMUM", _math(nt, "SUBTRACT", dv, max(half_h - radius, 0.0), x=x, y=y - 70), 0.0, x=x + 150, y=y - 70)
    vector = _new(nt, "ShaderNodeCombineXYZ", x + 300, y)
    nt.links.new(qx, vector.inputs["X"])
    nt.links.new(qy, vector.inputs["Y"])
    vector.inputs["Z"].default_value = 0.0
    length = _new(nt, "ShaderNodeVectorMath", x + 450, y)
    length.operation = "LENGTH"
    nt.links.new(vector.outputs["Vector"], length.inputs[0])
    return _range(nt, length.outputs["Value"], radius, radius + feather, 1.0, 0.0, x=x + 610, y=y)


def _band(nt, source, low, high, feather=0.06, x=0, y=0):
    """1 between two values of a coordinate, 0 outside."""
    a = _range(nt, source, low, low + feather, 0.0, 1.0, x=x, y=y + 60)
    b = _range(nt, source, high, high - feather, 0.0, 1.0, x=x, y=y - 60)
    return _math(nt, "MULTIPLY", a, b, x=x + 160, y=y)


def masonry_colour(nt, coord, plan, z, base, kind, *, mortar=None, x=-1000, y=900):
    """Wall material: the thing that tells you what a building is made of.

    ``kind`` is ``"stucco"``, ``"brick"``, ``"ashlar"``, ``"panel"`` or
    ``"plain"``. Brick and ashlar use a running bond — alternate courses are
    offset by half a unit — because a stacked bond reads as graph paper.
    """
    if kind in ("brick", "ashlar"):
        course, length = (0.85, 2.0) if kind == "brick" else (2.4, 4.4)
        joint_c = mortar or (col("cream_shade") if kind == "brick" else col("cream_trim"))

        index = _math(nt, "FLOOR", _math(nt, "MULTIPLY", z, 1.0 / course, x=x, y=y), x=x + 150, y=y)
        stagger = _math(nt, "MODULO", index, 2.0, x=x + 300, y=y)
        shift = _math(nt, "MULTIPLY", stagger, length * 0.5, x=x + 450, y=y)
        shifted = _math(nt, "ADD", plan, shift, x=x + 600, y=y)

        dv = _cell_distance(nt, z, course, x=x, y=y - 200)
        du = _cell_distance(nt, shifted, length, x=x + 760, y=y - 200)
        bed = _range(nt, dv, 0.40, 0.47, 0.0, 1.0, x=x + 500, y=y - 260)
        perp = _range(nt, du, 0.43, 0.48, 0.0, 1.0, x=x + 1240, y=y - 200)
        joint = _math(nt, "MAXIMUM", bed, perp, x=x + 1400, y=y - 230)

        tone = _hash01(
            nt,
            _cell_index(nt, shifted, length, x=x + 760, y=y - 420),
            index,
            x=x + 940, y=y - 420,
        )
        varied = _mixc(nt, _darker(base, 0.86), _darker(base, 1.10), tone, x=x + 1120, y=y - 420)
        return _mixc(nt, varied, joint_c, joint, x=x + 1560, y=y - 300)

    if kind == "panel":
        du = _cell_distance(nt, plan, 3.2, x=x, y=y - 200)
        dv = _cell_distance(nt, z, 3.2, x=x, y=y - 360)
        line = _math(
            nt, "MAXIMUM",
            _range(nt, du, 0.45, 0.49, 0.0, 1.0, x=x + 500, y=y - 200),
            _range(nt, dv, 0.45, 0.49, 0.0, 1.0, x=x + 500, y=y - 360),
            x=x + 660, y=y - 280,
        )
        return _mixc(nt, base, _darker(base, 0.82), line, x=x + 820, y=y - 280)

    if kind == "plain":
        return base

    grain = _new(nt, "ShaderNodeTexNoise", x, y - 200)
    grain.inputs["Scale"].default_value = 0.45
    grain.inputs["Detail"].default_value = 4.0
    nt.links.new(coord, grain.inputs["Vector"])
    amount = _range(nt, grain.outputs["Fac"], 0.36, 0.68, 0.0, 0.30, x=x + 200, y=y - 200)
    return _mixc(nt, base, _darker(base, 1.14), amount, x=x + 380, y=y - 200)


def _wave_along(nt, plan, z, *, scale, profile="SIN", distortion=0.0, detail=2.0, x=-820, y=520):
    """A Wave texture whose bands run along the wall surface (X+Y), not along X."""
    combine = _new(nt, "ShaderNodeCombineXYZ", x, y)
    nt.links.new(plan, combine.inputs["X"])
    combine.inputs["Y"].default_value = 0.0
    nt.links.new(z, combine.inputs["Z"])
    wave = _new(nt, "ShaderNodeTexWave", x + 170, y)
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.wave_profile = profile
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = distortion
    wave.inputs["Detail"].default_value = detail
    nt.links.new(combine.outputs["Vector"], wave.inputs["Vector"])
    return wave.outputs["Fac"]


# --------------------------------------------------------------------------
# surface patterns
# --------------------------------------------------------------------------

def shingle_pattern(course=1.9, light=None, dark=None, distortion=0.3):
    """Roof courses from object-space Z, so they lie correctly on any slope.

    In the low-poly kit these are the *only* tile courses — nothing is
    modelled. The bump output drives the baked normal map.
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
        elements[1].position = 0.18
        elements[1].color = base
        elements.new(0.80).color = base
        elements.new(0.99).color = light or col("roof_light")
        nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])

        grime = _new(nt, "ShaderNodeTexNoise", -1000, 40)
        grime.inputs["Scale"].default_value = 2.4
        grime.inputs["Detail"].default_value = 4.0
        nt.links.new(coord, grime.inputs["Vector"])
        grime_fac = _map_range(nt, -820, 40, grime.outputs["Fac"], 0.35, 0.68, 0.0, 0.32)
        tinted = _mix(nt, -640, 200, ramp.outputs["Color"], dark or col("roof_shade"), grime_fac.outputs["Result"])
        return tinted.outputs["Color"], wave.outputs["Fac"]

    return build


def plank_pattern(scale=1.2, light=None, dark=None, direction="Z", blend=0.34):
    """Painted timber grain."""

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
        blended = _mix(nt, -460, 220, base, streaks.outputs["Color"], blend)
        return blended.outputs["Color"], grain.outputs["Result"]

    return build


def speckle_pattern(scale=5.0, amount=0.4, tint=None, detail=6.0, roughness=0.6):
    """Painted-plaster mottling."""

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
    """Voronoi grit for asphalt and gravel."""

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


def block_pattern(scale=3.2, mortar=None, light=None):
    """Rounded rubble blocks."""

    def build(nt, coord, base):
        cells = _new(nt, "ShaderNodeTexVoronoi", -1000, 300)
        cells.feature = "SMOOTH_F1"
        cells.inputs["Scale"].default_value = scale
        cells.inputs["Smoothness"].default_value = 0.18
        nt.links.new(coord, cells.inputs["Vector"])
        joint = _map_range(nt, -820, 340, cells.outputs["Distance"], 0.26, 0.06, 0.0, 1.0)
        varied = _new(nt, "ShaderNodeValToRGB", -820, 120)
        varied.color_ramp.elements[0].color = light or col("cream_trim")
        varied.color_ramp.elements[1].color = base
        nt.links.new(cells.outputs["Color"], varied.inputs["Fac"])
        toned = _mix(nt, -600, 240, base, varied.outputs["Color"], 0.55)
        grouted = _mix(nt, -420, 240, toned.outputs["Color"], mortar or col("stone_dark"), joint.outputs["Result"])
        return grouted.outputs["Color"], cells.outputs["Distance"]

    return build


def stripe_pattern(width=2.6, other=None, axis="X"):
    """Hard two-colour awning stripes."""

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
        ramp.color_ramp.elements[0].color = base
        ramp.color_ramp.elements[1].position = 0.5
        ramp.color_ramp.elements[1].color = other or col("cream_trim")
        nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
        return ramp.outputs["Color"], None

    return build


def panel_pattern(rows=3.0, columns=6.0, frame=None, glass=None, glow=None):
    """A facade band of windows painted straight into the wall texture.

    This is what replaces modelled window frames, mullions and reveals. At the
    locked isometric zoom it is indistinguishable from geometry, and it costs
    nothing.
    """

    def build(nt, coord, base):
        separate = _new(nt, "ShaderNodeSeparateXYZ", -1200, 300)
        nt.links.new(coord, separate.inputs["Vector"])

        def band(source, frequency, y):
            scaled = _new(nt, "ShaderNodeMath", -1040, y)
            scaled.operation = "MULTIPLY"
            nt.links.new(source, scaled.inputs[0])
            scaled.inputs[1].default_value = frequency
            wrapped = _new(nt, "ShaderNodeMath", -900, y)
            wrapped.operation = "WRAP"
            nt.links.new(scaled.outputs[0], wrapped.inputs[0])
            wrapped.inputs[1].default_value = 1.0
            wrapped.inputs[2].default_value = 0.0
            centred = _new(nt, "ShaderNodeMath", -760, y)
            centred.operation = "SUBTRACT"
            nt.links.new(wrapped.outputs[0], centred.inputs[0])
            centred.inputs[1].default_value = 0.5
            absolute = _new(nt, "ShaderNodeMath", -620, y)
            absolute.operation = "ABSOLUTE"
            nt.links.new(centred.outputs[0], absolute.inputs[0])
            return absolute.outputs[0]

        # X alone is constant across an X-facing wall, which turns the window
        # grid into horizontal stripes on the side elevations. X+Y varies
        # along the surface of every axis-aligned wall at the same pitch.
        plan = _new(nt, "ShaderNodeMath", -1080, 560)
        plan.operation = "ADD"
        nt.links.new(separate.outputs["X"], plan.inputs[0])
        nt.links.new(separate.outputs["Y"], plan.inputs[1])

        horizontal = band(plan.outputs[0], columns, 420)
        vertical = band(separate.outputs["Z"], rows, 180)
        widest = _new(nt, "ShaderNodeMath", -460, 300)
        widest.operation = "MAXIMUM"
        nt.links.new(horizontal, widest.inputs[0])
        nt.links.new(vertical, widest.inputs[1])
        # ``widest`` is 0 at the centre of a bay and 0.5 at its border, so the
        # glass sits in the low band and the surround in the high one.
        pane = _map_range(nt, -320, 380, widest.outputs[0], 0.22, 0.30, 1.0, 0.0)
        surround = _map_range(nt, -320, 200, widest.outputs[0], 0.31, 0.37, 1.0, 0.0)

        recess = tuple(c * 0.42 for c in (frame or base)[:3]) + (1.0,)
        lit = _mix(nt, -160, 420, glass or col("glass"), glow or col("cream_trim"), 0.25)
        outlined = _mix(nt, -160, 240, frame or base, recess, surround.outputs["Result"])
        framed = _mix(nt, 20, 300, outlined.outputs["Color"], lit.outputs["Color"], pane.outputs["Result"])
        return framed.outputs["Color"], pane.outputs["Result"]

    return build


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def facade_pattern(
    storey=5.0,
    bay=5.5,
    ground=7.0,
    parapet=0.09,
    window_w=2.6,
    window_h=3.0,
    surround="raised",
    surround_width=0.55,
    sill=True,
    lintel=False,
    glazing_bars="transom",
    wall_texture="stucco",
    string_course=0.9,
    cornice=1.6,
    ground_mode="shopfront",
    door_chance=0.34,
    lit_fraction=0.30,
    wall=None,
    trim=None,
    glass=None,
    glass_unlit=None,
    shade=None,
    accent=None,
):
    """A composed building facade, not a grid of holes.

    The reference this is built against is a London street: cream stucco and
    dark brick, shopfronts with pilasters and stallrisers, upper windows whose
    stone surrounds stand proud of the wall, sills that cast a shadow, glazing
    bars, a string course above the ground floor and a cornice under the roof.
    Every one of those is a parameter here, because "a square hole in a flat
    colour" is what makes a building read as a placeholder.

    Vary these per asset — that is where a city's variety comes from:

    * ``wall_texture`` ``"stucco" | "brick" | "ashlar" | "panel" | "plain"``
    * ``surround`` ``"raised"`` (stone frame proud of the wall, with its own
      cast shadow), ``"recessed"`` (opening cut into the wall, shadow along the
      head), or ``"flush"``
    * ``glazing_bars`` ``"none" | "transom" | "cross" | "grid"``
    * ``ground_mode`` ``"shopfront" | "door" | "plinth" | "dock" | "same"``

    ``window_w``/``window_h`` are world units, not ratios, so a window is the
    same physical size on a warehouse and on a townhouse.
    """

    def build(nt, coord, base):
        wall_c = wall or base
        trim_c = trim or col("cream_trim")
        glass_c = glass or col("glass")
        shade_c = shade or _darker(wall_c, 0.52)
        accent_c = accent or col("red")

        unlit_c = glass_unlit or col("glass_cool")
        dark_glass = unlit_c
        deep = _darker(wall_c, 0.34)
        bright = _darker(trim_c, 1.06)

        _, _, z, plan = _axes(nt, coord)

        # ---- wall material -------------------------------------------------
        surface = masonry_colour(nt, coord, plan, z, wall_c, wall_texture)

        # ---- upper-floor window bays ---------------------------------------
        u = _bay_local(nt, plan, bay, x=-1000, y=680)
        v = _bay_local(nt, z, storey, x=-1000, y=520)
        du = _abs(nt, u, x=-520, y=680)
        dv = _abs(nt, v, x=-520, y=520)

        hw, hh = window_w / 2.0, window_h / 2.0
        opening = _rect(nt, du, dv, hw, hh, feather=0.07, x=-360, y=600)

        lit = _hash01(
            nt,
            _cell_index(nt, plan, bay, x=-1000, y=360),
            _cell_index(nt, z, storey, x=-1000, y=240),
            x=-780, y=300,
        )
        lit_mask = _range(nt, lit, 1.0 - lit_fraction - 0.03, 1.0 - lit_fraction, 0.0, 1.0, x=-560, y=300)
        pane = _mixc(nt, dark_glass, glass_c, lit_mask, x=-380, y=300)

        # Glazing bars, drawn on the glass before it is composited in.
        if glazing_bars != "none":
            bars = None
            if glazing_bars in ("transom", "cross", "grid"):
                split_v = hh * 0.34 if glazing_bars == "transom" else 0.0
                offset = _math(nt, "SUBTRACT", v, split_v, x=-520, y=180)
                bars = _range(nt, _abs(nt, offset, x=-380, y=180), 0.10, 0.15, 1.0, 0.0, x=-220, y=180)
            if glazing_bars in ("cross", "grid"):
                vertical = _range(nt, du, 0.09, 0.14, 1.0, 0.0, x=-220, y=60)
                bars = _math(nt, "MAXIMUM", bars, vertical, x=-60, y=120) if bars else vertical
            if glazing_bars == "grid":
                second = _math(nt, "SUBTRACT", dv, hh * 0.5, x=-380, y=-20)
                extra = _range(nt, _abs(nt, second, x=-220, y=-20), 0.09, 0.14, 1.0, 0.0, x=-60, y=-20)
                bars = _math(nt, "MAXIMUM", bars, extra, x=80, y=40)
            pane = _mixc(nt, pane, trim_c, bars, x=220, y=240)

        upper = surface

        if surround == "raised":
            frame = _rect(nt, du, dv, hw + surround_width, hh + surround_width, feather=0.07, x=-360, y=440)
            band = _math(nt, "SUBTRACT", frame, opening, x=-200, y=520)
            upper = _mixc(nt, upper, trim_c, band, x=0, y=520)
            # A projecting surround is lit on its top face and casts a shadow
            # on the wall below it. Both lines are what make it read as proud
            # of the wall rather than painted on.
            top_face = _band(nt, v, hh + surround_width * 0.35, hh + surround_width, feather=0.05, x=-360, y=760)
            top_lit = _math(nt, "MULTIPLY", top_face, frame, x=-60, y=760)
            upper = _mixc(nt, upper, bright, top_lit, x=120, y=680)
            drop = _band(nt, v, -hh - surround_width - 0.42, -hh - surround_width, feather=0.06, x=-360, y=-160)
            wide = _range(nt, du, hw + surround_width, hw + surround_width + 0.1, 1.0, 0.0, x=-200, y=-220)
            cast = _math(nt, "MULTIPLY", drop, wide, x=-40, y=-190)
            upper = _mixc(nt, upper, deep, cast, x=260, y=560)
        elif surround == "recessed":
            # The reveal shadow sits inside the opening, along the head.
            head = _band(nt, v, hh - 0.42, hh, feather=0.05, x=-360, y=760)
            head_in = _math(nt, "MULTIPLY", head, opening, x=-60, y=760)
            side = _range(nt, du, hw, hw - 0.30, 0.0, 1.0, x=-200, y=-220)
            side_in = _math(nt, "MULTIPLY", side, opening, x=-40, y=-190)
            reveal = _math(nt, "MAXIMUM", head_in, side_in, x=120, y=700)
            pane = _mixc(nt, pane, col("glass_cool_dark"), reveal, x=300, y=300)

        upper = _mixc(nt, upper, pane, opening, x=420, y=520)

        if sill:
            sill_band = _band(nt, v, -hh - 0.34, -hh + 0.04, feather=0.05, x=-360, y=-320)
            sill_wide = _range(nt, du, hw + surround_width * 0.7, hw + surround_width * 0.7 + 0.1, 1.0, 0.0, x=-200, y=-380)
            sill_mask = _math(nt, "MULTIPLY", sill_band, sill_wide, x=-40, y=-350)
            upper = _mixc(nt, upper, bright, sill_mask, x=560, y=460)
        if lintel:
            head_band = _band(nt, v, hh + 0.04, hh + 0.40, feather=0.05, x=-360, y=-480)
            head_wide = _range(nt, du, hw + surround_width * 0.8, hw + surround_width * 0.8 + 0.1, 1.0, 0.0, x=-200, y=-540)
            head_mask = _math(nt, "MULTIPLY", head_band, head_wide, x=-40, y=-510)
            upper = _mixc(nt, upper, trim_c, head_mask, x=700, y=460)

        surface = upper

        # ---- ground register -----------------------------------------------
        if ground_mode != "same":
            ground_mask = _range(nt, z, ground, ground - 0.3, 0.0, 1.0, x=-360, y=-680)
            bay_index = _cell_index(nt, plan, bay, x=-1000, y=-760)
            pilaster = _range(nt, _abs(nt, u, x=-520, y=-820), bay * 0.5 - 0.55, bay * 0.5 - 0.35, 0.0, 1.0, x=-320, y=-820)

            if ground_mode == "shopfront":
                stall = _band(nt, z, 0.0, 1.35, feather=0.08, x=-1000, y=-900)
                fascia = _band(nt, z, ground - 2.1, ground, feather=0.08, x=-1000, y=-1020)
                glazed = _band(nt, z, 1.35, ground - 2.1, 0.10, x=-1000, y=-1140)

                door_hash = _hash01(nt, bay_index, bay_index, x=-800, y=-1260)
                is_door = _range(nt, door_hash, 1.0 - door_chance, 1.0 - door_chance + 0.02, 0.0, 1.0, x=-620, y=-1260)

                # Show window: a warm interior behind the glass rather than a
                # flat pane, so the shopfront reads as having something in it.
                depth = _new(nt, "ShaderNodeTexNoise", -1000, -1380)
                depth.inputs["Scale"].default_value = 0.6
                depth.inputs["Detail"].default_value = 3.0
                nt.links.new(coord, depth.inputs["Vector"])
                interior = _range(nt, depth.outputs["Fac"], 0.35, 0.68, 0.0, 0.55, x=-800, y=-1380)
                shopglass = _mixc(nt, unlit_c, glass_c, interior, x=-620, y=-1380)

                door_leaf = _range(nt, _abs(nt, u, x=-520, y=-1500), bay * 0.30, bay * 0.30 + 0.08, 1.0, 0.0, x=-320, y=-1500)
                door_split = _range(nt, _abs(nt, u, x=-520, y=-1560), 0.10, 0.16, 1.0, 0.0, x=-320, y=-1620)
                door_col = _mixc(nt, col("wood"), _darker(col("wood"), 0.55), door_split, x=-140, y=-1560)
                door_col = _mixc(nt, shopglass, door_col, door_leaf, x=20, y=-1500)

                bay_fill = _mixc(nt, shopglass, door_col, is_door, x=180, y=-1400)
                ground_col = _mixc(nt, shade_c, bay_fill, glazed, x=340, y=-1200)
                ground_col = _mixc(nt, ground_col, accent_c, fascia, x=500, y=-1100)
                ground_col = _mixc(nt, ground_col, _darker(shade_c, 0.8), stall, x=660, y=-1000)
                ground_col = _mixc(nt, ground_col, trim_c, pilaster, x=820, y=-900)
                # Transom bar over the glazing.
                transom = _band(nt, z, ground - 2.4, ground - 2.1, feather=0.04, x=-1000, y=-1680)
                ground_col = _mixc(nt, ground_col, trim_c, transom, x=980, y=-860)
            elif ground_mode == "door":
                door_v = _math(nt, "SUBTRACT", z, ground * 0.45, x=-700, y=-1000)
                leaf = _rect(
                    nt, _abs(nt, u, x=-520, y=-940), _abs(nt, door_v, x=-520, y=-1000),
                    1.5, ground * 0.42, feather=0.08, x=-320, y=-960,
                )
                split = _range(nt, _abs(nt, u, x=-520, y=-1060), 0.09, 0.15, 1.0, 0.0, x=-320, y=-1080)
                leafcol = _mixc(nt, col("wood"), _darker(col("wood"), 0.5), split, x=-140, y=-1040)
                base_wall = masonry_colour(nt, coord, plan, z, shade_c, "ashlar", x=-2400, y=-900)
                ground_col = _mixc(nt, base_wall, leafcol, leaf, x=200, y=-980)
            elif ground_mode == "plinth":
                ground_col = masonry_colour(nt, coord, plan, z, shade_c, "ashlar", x=-2400, y=-1200)
            elif ground_mode == "dock":
                door_d = _cell_distance(nt, plan, bay * 2.0, x=-1000, y=-900)
                door_x = _range(nt, door_d, 0.35, 0.31, 1.0, 0.0, x=-700, y=-900)
                door_z = _band(nt, z, 0.4, ground - 1.1, feather=0.10, x=-1000, y=-1020)
                door = _math(nt, "MULTIPLY", door_x, door_z, x=-460, y=-960)
                ribs = _range(nt, _cell_distance(nt, z, 0.75, x=-1000, y=-1140), 0.40, 0.47, 0.0, 0.55, x=-700, y=-1140)
                ribbed = _math(nt, "MULTIPLY", ribs, door, x=-460, y=-1100)
                lintel_band = _band(nt, z, ground - 1.1, ground - 0.7, feather=0.05, x=-1000, y=-1260)
                lintel_mask = _math(nt, "MULTIPLY", door_x, lintel_band, x=-460, y=-1260)
                ground_col = _mixc(nt, shade_c, _darker(wall_c, 0.46), door, x=-260, y=-1000)
                ground_col = _mixc(nt, ground_col, _darker(wall_c, 0.34), ribbed, x=-100, y=-1060)
                ground_col = _mixc(nt, ground_col, trim_c, lintel_mask, x=60, y=-1200)
            else:
                ground_col = shade_c

            surface = _mixc(nt, surface, ground_col, ground_mask, x=1100, y=300)

        # ---- string course above the ground floor --------------------------
        if string_course > 0 and ground_mode != "same":
            course = _band(nt, z, ground, ground + string_course, feather=0.05, x=-1000, y=-1800)
            course_lit = _band(nt, z, ground + string_course * 0.55, ground + string_course, feather=0.05, x=-1000, y=-1920)
            under = _band(nt, z, ground - 0.28, ground, feather=0.04, x=-1000, y=-2040)
            surface = _mixc(nt, surface, _darker(wall_c, 0.42), under, x=1240, y=200)
            surface = _mixc(nt, surface, trim_c, course, x=1400, y=260)
            surface = _mixc(nt, surface, _darker(trim_c, 1.12), course_lit, x=1560, y=320)

        # ---- cornice and parapet -------------------------------------------
        if parapet > 0 or cornice > 0:
            gz = _generated_z(nt)
            if cornice > 0:
                cor = _range(nt, gz, 1.0 - parapet - 0.012, 1.0 - parapet, 1.0, 0.0, x=-700, y=-2160)
                cor_top = _range(nt, gz, 1.0 - parapet - 0.03, 1.0 - parapet - 0.014, 0.0, 1.0, x=-700, y=-2280)
                cor_band = _math(nt, "MULTIPLY", cor, cor_top, x=-500, y=-2220)
                surface = _mixc(nt, surface, trim_c, cor_band, x=1720, y=200)
            if parapet > 0:
                band = _range(nt, gz, 1.0 - parapet, 1.0 - parapet + 0.012, 0.0, 1.0, x=-700, y=-2400)
                local = _range(nt, gz, 1.0 - parapet, 1.0, 0.0, 1.0, x=-700, y=-2520)
                cap = _range(nt, local, 0.0, 0.3, 0.0, 1.0, x=-500, y=-2520)
                parapet_col = _mixc(nt, _darker(trim_c, 0.7), trim_c, cap, x=-320, y=-2480)
                surface = _mixc(nt, surface, parapet_col, band, x=1880, y=240)

        return surface, opening

    return build


def showroom_pattern(
    mullion=4.4,
    transom=6.4,
    base=1.6,
    car_zone=9.5,
    car_pitch=9.0,
    interior_mix=0.52,
    reflection=0.12,
    frame=None,
    glass=None,
    spandrel=None,
    interior=None,
    floor=None,
    ceiling=None,
    car_colours=None,
    show_cars=True,
):
    """A car showroom you can see into.

    A dealership's whole identity is that the stock is visible through the
    glass. Modelling cars behind a transparent wall would cost geometry *and*
    break the single-material batching the city depends on, so the interior is
    painted.

    Two things were got wrong first time and are worth stating:

    * **Cars belong on the ground floor only.** Driving them from the
      per-storey coordinate scatters a car onto every floor, which reads as
      wallpaper. ``car_zone`` gates them by absolute height instead.
    * **Glass has to stay glass.** Mixing too much warm interior and too much
      reflection into it leaves a cream wall. The base stays a deep blue-teal
      and the interior only shows through inside ``car_zone``.
    """

    def build(nt, coord, base_colour):
        frame_c = frame or col("showroom_spandrel")
        glass_c = glass or col("showroom_glass_deep")
        spandrel_c = spandrel or col("showroom_spandrel")
        interior_c = interior or col("showroom_interior")
        floor_c = floor or col("showroom_floor")
        ceiling_c = ceiling or col("showroom_ceiling")
        cars = car_colours or (col("red"), col("blue"), col("cream_trim"), col("chrome"))

        _, _, z, plan = _axes(nt, coord)

        # Upper glazing: deep glass with a spandrel band at each floor line.
        v = _bay_local(nt, z, transom, x=-1000, y=760)
        spandrel_band = _band(nt, v, transom * 0.32, transom * 0.5, feather=0.10, x=-700, y=760)
        surface = _mixc(nt, glass_c, spandrel_c, spandrel_band, x=-360, y=760)

        # Ground register: the showroom proper.
        zone = _range(nt, z, car_zone, car_zone - 0.8, 0.0, 1.0, x=-700, y=560)
        inside = _mixc(nt, glass_c, interior_c, interior_mix, x=-700, y=460)
        floor_line = _band(nt, z, 0.5, 1.7, feather=0.10, x=-1000, y=380)
        inside = _mixc(nt, inside, floor_c, floor_line, x=-360, y=440)
        ceiling_line = _band(nt, z, car_zone - 2.0, car_zone - 0.7, feather=0.12, x=-1000, y=240)
        inside = _mixc(nt, inside, ceiling_c, ceiling_line, x=-200, y=380)

        if show_cars:
            cu = _bay_local(nt, plan, car_pitch, x=-1000, y=100)
            du = _abs(nt, cu, x=-520, y=100)
            # Generous feathering: sharp rectangles at this size read as a
            # pixel-art staircase, soft ones read as a car.
            body_v = _abs(nt, _math(nt, "SUBTRACT", z, 3.1, x=-520, y=20), x=-360, y=20)
            body = _rounded_rect(nt, du, body_v, 3.3, 1.00, 0.60, feather=0.14, x=-200, y=60)
            cab_u = _abs(nt, _math(nt, "ADD", cu, 0.55, x=-520, y=-200), x=-360, y=-200)
            cab_v = _abs(nt, _math(nt, "SUBTRACT", z, 4.55, x=-520, y=-300), x=-360, y=-300)
            cabin = _rounded_rect(nt, cab_u, cab_v, 1.60, 0.80, 0.55, feather=0.14, x=-200, y=-260)
            car = _math(nt, "MAXIMUM", body, cabin, x=520, y=-60)

            tone = _hash01(
                nt,
                _cell_index(nt, plan, car_pitch, x=-1000, y=-280),
                _cell_index(nt, plan, car_pitch * 3.0, x=-1000, y=-400),
                x=-800, y=-340,
            )
            low = _mixc(nt, cars[0], cars[1], _range(nt, tone, 0.25, 0.27, 0.0, 1.0, x=-600, y=-280), x=-420, y=-280)
            high = _mixc(nt, cars[2], cars[3], _range(nt, tone, 0.75, 0.77, 0.0, 1.0, x=-600, y=-400), x=-420, y=-400)
            car_c = _mixc(nt, low, high, _range(nt, tone, 0.50, 0.52, 0.0, 1.0, x=-600, y=-520), x=-240, y=-340)
            inside = _mixc(nt, inside, car_c, car, x=680, y=300)
            screen = _rounded_rect(nt, cab_u, cab_v, 1.35, 0.52, 0.35, feather=0.12, x=-200, y=-460)
            inside = _mixc(nt, inside, col("glass_dark"), screen, x=840, y=260)
            pad = _ellipse(nt, du, _abs(nt, _math(nt, "SUBTRACT", z, 2.05, x=-520, y=-620), x=-360, y=-620),
                           3.5, 0.30, feather=0.30, x=-200, y=-600)
            inside = _mixc(nt, inside, _darker(floor_c, 0.72), pad, x=280, y=260)

        surface = _mixc(nt, surface, inside, zone, x=440, y=520)

        # A cool, restrained sky reflection. This is what tells you the surface
        # is glass; overdo it and the interior disappears.
        gz = _generated_z(nt)
        refl = _range(nt, gz, 0.15, 1.0, 0.0, reflection, x=-520, y=-720)
        surface = _mixc(nt, surface, col("sky_reflect"), refl, x=600, y=460)

        mull = _range(nt, _cell_distance(nt, plan, mullion, x=-1000, y=-820), 0.42, 0.47, 0.0, 1.0, x=-520, y=-820)
        trans = _range(nt, _cell_distance(nt, z, transom, x=-1000, y=-940), 0.44, 0.48, 0.0, 1.0, x=-520, y=-940)
        grid = _math(nt, "MAXIMUM", mull, trans, x=-340, y=-880)
        surface = _mixc(nt, surface, frame_c, grid, x=760, y=420)

        base_mask = _range(nt, z, base, base - 0.25, 0.0, 1.0, x=-520, y=-1060)
        surface = _mixc(nt, surface, col("dealer_frame_dark"), base_mask, x=920, y=380)
        return surface, grid

    return build


def curtainwall_pattern(
    storey=4.2,
    mullion=2.6,
    glass=None,
    spandrel=None,
    frame=None,
    lit_fraction=0.22,
):
    """Downtown tower glazing: horizontal bands, thin mullions, scattered lights.

    Towers are the tallest silhouettes on the map, so the vertical corners get
    a pointiness lift to separate them from the sky.
    """

    def build(nt, coord, base):
        glass_c = glass or col("office_glass")
        spandrel_c = spandrel or col("office_spandrel")
        frame_c = frame or col("office_frame")
        lit_c = col("office_glass_lit")

        _, _, z, plan = _axes(nt, coord)

        band_scaled = _math(nt, "MULTIPLY", z, 1.0 / max(storey, 1e-4), x=-1000, y=520)
        band = _math(nt, "WRAP", band_scaled, 1.0, 0.0, x=-840, y=520)
        glass_mask = _map_range(nt, -680, 520, band, 0.62, 0.56, 1.0, 0.0)
        join = _map_range(nt, -680, 400, band, 0.62, 0.68, 1.0, 0.0)

        lit = _hash01(
            nt,
            _cell_index(nt, plan, mullion * 3.0, x=-1000, y=240),
            _cell_index(nt, z, storey, x=-1000, y=120),
            x=-700, y=180,
        )
        lit_mask = _map_range(nt, -520, 180, lit, 1.0 - lit_fraction - 0.03, 1.0 - lit_fraction, 0.0, 1.0)
        glazing = _mix(nt, -340, 180, glass_c, lit_c, lit_mask.outputs["Result"])

        surface = _mix(nt, -160, 460, spandrel_c, glazing.outputs["Color"], glass_mask.outputs["Result"])
        surface = _mix(nt, 0, 460, surface.outputs["Color"], _darker(spandrel_c, 0.6), join.outputs["Result"])

        mullion_d = _cell_distance(nt, plan, mullion, x=-1000, y=-60)
        mullion_mask = _map_range(nt, -520, -60, mullion_d, 0.43, 0.47, 0.0, 1.0)
        surface = _mix(nt, 160, 400, surface.outputs["Color"], frame_c, mullion_mask.outputs["Result"])

        geometry = _new(nt, "ShaderNodeNewGeometry", -1000, -300)
        corner = _map_range(nt, -700, -300, geometry.outputs["Pointiness"], 0.52, 0.62, 0.0, 0.18)
        surface = _mix(nt, 320, 360, surface.outputs["Color"], col("cream_trim"), corner.outputs["Result"])
        return surface.outputs["Color"], glass_mask.outputs["Result"]

    return build


def corrugated_pattern(pitch=2.6, base_key=None, light=None, dark=None, rust=0.15, seam=8.0):
    """Industrial sheet metal: lit and shaded rib faces plus a ground-up stain.

    The three-stop ramp is what sells corrugation at low resolution — a
    two-stop ramp reads as stripes.
    """

    def build(nt, coord, base):
        base_c = col(base_key) if base_key else base
        light_c = light or col("cream_trim")
        dark_c = dark or _darker(base_c, 0.55)

        _, _, z, plan = _axes(nt, coord)
        ribs = _wave_along(nt, plan, z, scale=1.0 / max(pitch, 1e-4), profile="SIN", x=-820, y=560)
        ramp = _new(nt, "ShaderNodeValToRGB", -600, 560)
        ramp.color_ramp.interpolation = "B_SPLINE"
        ramp.color_ramp.elements[0].position = 0.0
        ramp.color_ramp.elements[0].color = dark_c
        ramp.color_ramp.elements[1].position = 0.45
        ramp.color_ramp.elements[1].color = base_c
        ramp.color_ramp.elements.new(1.0).color = light_c
        nt.links.new(ribs, ramp.inputs["Fac"])
        surface = ramp.outputs["Color"]

        if rust > 0:
            stain = _new(nt, "ShaderNodeTexNoise", -1000, 200)
            stain.inputs["Scale"].default_value = 0.08
            stain.inputs["Detail"].default_value = 4.0
            nt.links.new(coord, stain.inputs["Vector"])
            gz = _generated_z(nt)
            low = _map_range(nt, -820, 100, gz, 0.55, 0.02, 0.0, 1.0)
            amount = _map_range(nt, -820, 200, stain.outputs["Fac"], 0.42, 0.72, 0.0, rust)
            gated = _math(nt, "MULTIPLY", amount.outputs["Result"], low.outputs["Result"], x=-620, y=160)
            surface = _mix(nt, -420, 300, surface, col("rust"), gated).outputs["Color"]

        seam_d = _cell_distance(nt, z, seam, x=-1000, y=-120)
        seam_mask = _map_range(nt, -700, -120, seam_d, 0.47, 0.495, 0.0, 1.0)
        surface = _mix(nt, -200, 260, surface, dark_c, seam_mask.outputs["Result"])
        return surface.outputs["Color"], ribs

    return build


def flatroof_pattern(
    membrane=None,
    seam=None,
    unit=None,
    seam_pitch=6.0,
    kit_density=0.35,
    parapet_inset=0.10,
    unit_pitch=9.0,
):
    """The highest-value pattern in the kit.

    At a 35 degree isometric the roof is roughly half of a building's visible
    pixels, and a flat colour there is what makes a city look unfinished. Five
    layers, all required: membrane mottle, seams, parapet shadow, rooftop
    plant with its own cast shadow, and pooling.

    ``parapet_inset`` is a fraction of the object's plan size, not world units.
    """

    def build(nt, coord, base):
        membrane_c = membrane or col("membrane")
        seam_c = seam or col("membrane_seam")
        unit_c = unit or col("roof_unit")

        px, py, _, _ = _axes(nt, coord, x=-1300, y=700)

        # Texture scales here are in cycles per *world unit*, and a roof is
        # tens of units across. Anything above ~0.5 becomes sub-pixel noise at
        # map zoom and the whole pattern collapses into grey static.
        mottle = _new(nt, "ShaderNodeTexNoise", -1100, 560)
        mottle.inputs["Scale"].default_value = 0.35
        mottle.inputs["Detail"].default_value = 3.0
        nt.links.new(coord, mottle.inputs["Vector"])
        mottle_fac = _map_range(nt, -920, 560, mottle.outputs["Fac"], 0.36, 0.68, 0.0, 0.22)
        surface = _mix(nt, -740, 560, membrane_c, _darker(membrane_c, 1.25), mottle_fac.outputs["Result"]).outputs["Color"]

        # Seams run in plan, so X and Y are the correct drivers here. The
        # X+Y rule applies to walls, not to horizontal surfaces.
        seam_x = _cell_distance(nt, px, seam_pitch, x=-1100, y=400)
        seam_y = _cell_distance(nt, py, seam_pitch, x=-1100, y=260)
        line_x = _map_range(nt, -620, 400, seam_x, 0.43, 0.48, 0.0, 1.0)
        line_y = _map_range(nt, -620, 260, seam_y, 0.43, 0.48, 0.0, 1.0)
        seam_mask = _math(nt, "MAXIMUM", line_x.outputs["Result"], line_y.outputs["Result"], x=-440, y=330)
        surface = _mix(nt, -260, 460, surface, seam_c, seam_mask).outputs["Color"]

        pool = _new(nt, "ShaderNodeTexNoise", -1100, 120)
        pool.inputs["Scale"].default_value = 0.06
        pool.inputs["Detail"].default_value = 2.0
        nt.links.new(coord, pool.inputs["Vector"])
        pool_fac = _map_range(nt, -920, 120, pool.outputs["Fac"], 0.44, 0.74, 0.0, 0.12)
        surface = _mix(nt, -100, 400, surface, _darker(membrane_c, 0.7), pool_fac.outputs["Result"]).outputs["Color"]

        if kit_density > 0:
            # Rooftop plant is laid on a coarse grid and filled as rectangles.
            # Voronoi cells read as torn patches; real AC units, vents and
            # stair boxes are axis-aligned boxes, and at 150 px on screen the
            # difference between "roof kit" and "damage" is exactly that.
            threshold = 1.0 - min(kit_density, 0.9) * 0.62

            def plant_mask(offset, y):
                ox = px if offset == 0.0 else _math(nt, "SUBTRACT", px, offset, x=-1240, y=y + 60)
                oy = py if offset == 0.0 else _math(nt, "SUBTRACT", py, offset, x=-1240, y=y - 60)
                dx = _cell_distance(nt, ox, unit_pitch, x=-1080, y=y + 60)
                dy = _cell_distance(nt, oy, unit_pitch, x=-1080, y=y - 60)
                widest = _math(nt, "MAXIMUM", dx, dy, x=-560, y=y)
                inside = _map_range(nt, -400, y, widest, 0.30, 0.27, 1.0, 0.0)
                chance = _hash01(
                    nt,
                    _cell_index(nt, ox, unit_pitch, x=-1080, y=y + 180),
                    _cell_index(nt, oy, unit_pitch, x=-1080, y=y - 180),
                    x=-820, y=y + 120,
                )
                present = _map_range(nt, -560, y + 120, chance, threshold, threshold + 0.02, 0.0, 1.0)
                return _math(nt, "MULTIPLY", inside.outputs["Result"], present.outputs["Result"], x=-240, y=y)

            plant = plant_mask(0.0, -200)
            behind = plant_mask(2.4, -620)
            only_shadow = _math(nt, "SUBTRACT", behind, plant, x=-80, y=-620)
            shadow = _math(nt, "MAXIMUM", only_shadow, 0.0, x=60, y=-620)
            surface = _mix(nt, 200, 120, surface, _darker(membrane_c, 0.55), shadow).outputs["Color"]
            surface = _mix(nt, 360, 200, surface, unit_c, plant).outputs["Color"]

        if parapet_inset > 0:
            edge = _edge_distance(nt)
            edge_dark = _map_range(nt, -520, -500, edge, 0.0, parapet_inset, 1.0, 0.0)
            surface = _mix(nt, 380, 220, surface, _darker(membrane_c, 0.62), edge_dark.outputs["Result"]).outputs["Color"]

        return surface, seam_mask

    return build


def lotmarking_pattern(
    surface_key="asphalt",
    paint=None,
    kerb=None,
    bay_width=4.6,
    bay_depth=9.5,
    aisle=7.0,
    kerb_inset=0.06,
):
    """Parking bays painted into a plane.

    ``surfaceParking`` is 11,522 polygons today; with this it is a ten-triangle
    asset. Rows alternate with clean aisles so the lot reads as usable.
    """

    def build(nt, coord, base):
        paint_c = paint or col("line_paint")
        kerb_c = kerb or col("kerb")

        asphalt, _ = pebble_pattern(
            scale=7.0, amount=0.34, tint=col("asphalt_light"), dark=col("asphalt_shade")
        )(nt, coord, col(surface_key))
        surface = asphalt

        px, py, _, _ = _axes(nt, coord, x=-1300, y=760)
        row_period = bay_depth * 2.0 + aisle
        row_d = _cell_distance(nt, py, row_period, x=-1100, y=620)
        in_row = _map_range(nt, -620, 620, row_d, bay_depth / row_period, bay_depth / row_period + 0.02, 1.0, 0.0)

        bay_d = _cell_distance(nt, px, bay_width, x=-1100, y=460)
        bay_line = _map_range(nt, -620, 460, bay_d, 0.455, 0.492, 0.0, 1.0)
        marks = _math(nt, "MULTIPLY", bay_line.outputs["Result"], in_row.outputs["Result"], x=-420, y=520)
        surface = _mix(nt, -240, 560, surface, paint_c, marks).outputs["Color"]

        head = _map_range(nt, -620, 300, row_d, 0.008, 0.0, 0.0, 1.0)
        surface = _mix(nt, -60, 500, surface, paint_c, head.outputs["Result"]).outputs["Color"]

        wear = _new(nt, "ShaderNodeTexNoise", -1100, 160)
        wear.inputs["Scale"].default_value = 0.12
        nt.links.new(coord, wear.inputs["Vector"])
        wear_fac = _map_range(nt, -920, 160, wear.outputs["Fac"], 0.44, 0.7, 0.0, 0.18)
        surface = _mix(nt, 100, 440, surface, col("asphalt_shade"), wear_fac.outputs["Result"]).outputs["Color"]

        if kerb_inset > 0:
            edge = _edge_distance(nt)
            band = _map_range(nt, -520, -560, edge, kerb_inset, kerb_inset - 0.02, 0.0, 1.0)
            outer = _map_range(nt, -520, -660, edge, kerb_inset * 0.35, 0.0, 0.0, 1.0)
            kerb_col = _mix(nt, -340, -620, kerb_c, _darker(kerb_c, 0.7), outer.outputs["Result"])
            surface = _mix(nt, 260, 400, surface, kerb_col.outputs["Color"], band.outputs["Result"]).outputs["Color"]

        return surface, marks

    return build


def with_signage(
    inner,
    z_min,
    z_max,
    colour_key="red",
    emblem="circle",
    emblem_colour_key="cream_trim",
    emblem_pitch=26.0,
    emblem_size=2.4,
):
    """Overlay a coloured signage band, with an abstract emblem repeated along it.

    Deliberately not text: nothing needs localising, and a shape stays legible
    at 150 px. Assign one emblem per category so the city is readable at a
    glance — commercial ``circle``, highway ``chevron``, industrial ``bar``,
    player ``square``.
    """

    def build(nt, coord, base):
        surface, bump = inner(nt, coord, base)
        band_c = col(colour_key)
        emblem_c = col(emblem_colour_key)

        _, _, z, plan = _axes(nt, coord, x=-1300, y=-1000)
        low = _map_range(nt, -1000, -1000, z, z_min, z_min + 0.25, 0.0, 1.0)
        high = _map_range(nt, -1000, -1120, z, z_max, z_max - 0.25, 0.0, 1.0)
        band = _math(nt, "MULTIPLY", low.outputs["Result"], high.outputs["Result"], x=-820, y=-1060)
        surface = _mix(nt, 480, -900, surface, band_c, band).outputs["Color"]

        centre = (z_min + z_max) / 2.0
        offset_z = _math(nt, "SUBTRACT", z, centre, x=-820, y=-1240)
        along = _cell_distance(nt, plan, emblem_pitch, x=-1000, y=-1360)
        offset_x = _math(nt, "MULTIPLY", along, emblem_pitch, x=-520, y=-1360)

        if emblem == "bar":
            shape = _map_range(nt, -340, -1300, offset_x, emblem_size * 1.6, emblem_size * 1.4, 0.0, 1.0)
        else:
            vector = _new(nt, "ShaderNodeCombineXYZ", -340, -1300)
            nt.links.new(offset_x, vector.inputs["X"])
            nt.links.new(offset_z, vector.inputs["Y"])
            vector.inputs["Z"].default_value = 0.0
            length = _new(nt, "ShaderNodeVectorMath", -180, -1300)
            length.operation = "LENGTH"
            nt.links.new(vector.outputs["Vector"], length.inputs[0])
            if emblem == "square":
                separate = _new(nt, "ShaderNodeSeparateXYZ", -180, -1460)
                nt.links.new(vector.outputs["Vector"], separate.inputs["Vector"])
                ax = _math(nt, "ABSOLUTE", separate.outputs["X"], x=-20, y=-1420)
                az = _math(nt, "ABSOLUTE", separate.outputs["Y"], x=-20, y=-1520)
                metric = _math(nt, "MAXIMUM", ax, az, x=120, y=-1460)
            else:
                metric = length.outputs["Value"]
            shape = _map_range(nt, 280, -1360, metric, emblem_size, emblem_size * 0.86, 0.0, 1.0)

        emblem_mask = _math(nt, "MULTIPLY", shape.outputs["Result"], band, x=460, y=-1200)
        surface = _mix(nt, 620, -1000, surface, emblem_c, emblem_mask).outputs["Color"]
        return surface, bump

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
    crevice_amount: float = 0.50,
    gradient_amount: float = 0.28,
    roughness: float = 0.80,
    metallic: float = 0.0,
    bevel_radius: float = 0.45,
    bump_strength: float = 0.35,
    emission_key: str | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    """Compose the painted look out of procedural shading.

    ``bevel_radius`` defaults large here: low-poly meshes have no bevelled
    geometry, so the shader has to supply the whole rounded-edge read.
    """
    cached = MATERIALS.get(name)
    if cached is not None:
        return cached

    base = col(base_key)
    shade = col(shade_key) if shade_key else tuple(c * 0.45 for c in base[:3]) + (1.0,)

    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = base
    nt = material.node_tree
    nt.nodes.clear()

    coord = _new(nt, "ShaderNodeTexCoord", -1400, 200)
    object_vec = coord.outputs["Object"]
    generated_vec = coord.outputs["Generated"]

    builder = pattern if pattern is not None else speckle_pattern()
    color_socket, bump_socket = builder(nt, object_vec, base)

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
        bevel.samples = 4
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

    MATERIALS[name] = material
    return material


def flat_material(
    name: str,
    base_key: str,
    *,
    roughness: float = 0.5,
    metallic: float = 0.0,
    emission_key: str | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    cached = MATERIALS.get(name)
    if cached is not None:
        return cached
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = col(base_key)
    bsdf = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = col(base_key)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission_key:
        bsdf.inputs["Emission Color"].default_value = col(emission_key)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    MATERIALS[name] = material
    return material


# --------------------------------------------------------------------------
# geometry — everything is unbevelled and quad-cheap
# --------------------------------------------------------------------------

def link(obj, collection, parent):
    collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def mesh_from(name: str, verts, faces, material_indices=None) -> bpy.types.Mesh:
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    if material_indices:
        for polygon, index in zip(mesh.polygons, material_indices):
            polygon.material_index = index
    mesh.update()
    return mesh


def _finish(name, mesh, collection, location, rotation, materials, parent):
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    obj.rotation_euler = rotation
    for material in materials:
        obj.data.materials.append(material)
    link(obj, collection, parent)
    return obj


def box(name, collection, dimensions, location, material, *, rotation=(0, 0, 0), parent=None):
    """6 quads. The workhorse."""
    w, d, h = (v / 2 for v in dimensions)
    verts = [
        (-w, -d, -h), (w, -d, -h), (w, d, -h), (-w, d, -h),
        (-w, -d, h), (w, -d, h), (w, d, h), (-w, d, h),
    ]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (4, 0, 3, 7)]
    return _finish(name, mesh_from(name, verts, faces), collection, location, rotation, [material], parent)


def lofted(
    name, collection, rings, location, materials, *,
    rotation=(0, 0, 0), parent=None, cap_bottom=True, cap_top=True, span_materials=None,
):
    """Loft axis-aligned rectangles: ``rings`` = (z, half_x, half_y).

    ``span_materials`` assigns a material slot per vertical span, which is how
    a single object gets, say, a cream fascia band under a teal roof without
    adding a second mesh.
    """
    if not isinstance(materials, (list, tuple)):
        materials = [materials]
    verts: list[tuple[float, float, float]] = []
    for z, hx, hy in rings:
        verts.extend([(-hx, -hy, z), (hx, -hy, z), (hx, hy, z), (-hx, hy, z)])
    faces: list[tuple[int, ...]] = []
    indices: list[int] = []
    for i in range(len(rings) - 1):
        a, b = i * 4, (i + 1) * 4
        slot = span_materials[i] if span_materials else 0
        for j in range(4):
            k = (j + 1) % 4
            faces.append((a + j, a + k, b + k, b + j))
            indices.append(slot)
    if cap_bottom:
        faces.append((3, 2, 1, 0))
        indices.append(span_materials[0] if span_materials else 0)
    if cap_top:
        top = (len(rings) - 1) * 4
        faces.append((top, top + 1, top + 2, top + 3))
        indices.append(span_materials[-1] if span_materials else 0)
    mesh = mesh_from(name, verts, faces, indices)
    return _finish(name, mesh, collection, location, rotation, list(materials), parent)


def plane(name, collection, dimensions, location, material, *, rotation=(0, 0, 0), parent=None):
    """1 quad. Use for ground decals and flat signage."""
    w, d = (v / 2 for v in dimensions)
    verts = [(-w, -d, 0), (w, -d, 0), (w, d, 0), (-w, d, 0)]
    return _finish(name, mesh_from(name, verts, [(0, 1, 2, 3)]), collection, location, rotation, [material], parent)


def quad(name, collection, points, material, *, parent=None):
    """1 quad from explicit world-space corners."""
    return _finish(name, mesh_from(name, list(points), [(0, 1, 2, 3)]), collection, (0, 0, 0), (0, 0, 0), [material], parent)


def prism(name, collection, radius, height, location, material, *, sides=6, rotation=(0, 0, 0), parent=None, radius_top=None):
    """A cheap n-gon prism. ``sides=4`` is a rotated box for trunks and posts."""
    top_radius = radius if radius_top is None else radius_top
    half = height / 2
    verts = []
    for i in range(sides):
        a = 2 * math.pi * (i + 0.5) / sides
        verts.append((math.cos(a) * radius, math.sin(a) * radius, -half))
    for i in range(sides):
        a = 2 * math.pi * (i + 0.5) / sides
        verts.append((math.cos(a) * top_radius, math.sin(a) * top_radius, half))
    faces = [tuple(range(sides - 1, -1, -1)), tuple(range(sides, sides * 2))]
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j, sides + i))
    return _finish(name, mesh_from(name, verts, faces), collection, location, rotation, [material], parent)


def parapet_box(
    name, collection, dimensions, location, materials, *,
    parapet=1.4, inset=0.9, rotation=(0, 0, 0), parent=None,
):
    """A flat-roofed block whose top ring steps in and up: 20 triangles.

    Use this instead of ``box`` for every flat-roofed building. A bare box top
    has no edge and reads as a slab; the stepped parapet is what gives a flat
    roof a silhouette and lets ``flatroof_pattern`` cast its edge shadow.

    ``materials`` is ``[wall, roof]``.
    """
    width, depth, height = dimensions
    hx, hy = width / 2, depth / 2
    rings = (
        (0.0, hx, hy),
        (height - parapet, hx, hy),
        (height, hx, hy),
        (height, hx - inset, hy - inset),
    )
    return lofted(
        name, collection, rings, location, materials,
        rotation=rotation, parent=parent, cap_bottom=False, cap_top=True,
        span_materials=[0, 0, 1],
    )


def gable(
    name, collection, dimensions, location, materials, *,
    ridge_axis="X", overhang=1.2, rotation=(0, 0, 0), parent=None,
):
    """A pitched roof with an eave overhang: 12 triangles.

    ``materials`` is ``[roof]`` or ``[roof, soffit]``. ``dimensions`` is the
    roof's own (width, depth, rise) — pass the wall footprint plus overhang.
    """
    width, depth, rise = dimensions
    hx, hy = width / 2 + overhang, depth / 2 + overhang
    if ridge_axis == "X":
        rings = ((0.0, hx, hy), (rise, hx, 0.35))
    else:
        rings = ((0.0, hx, hy), (rise, 0.35, hy))
    return lofted(
        name, collection, rings, location, materials,
        rotation=rotation, parent=parent, cap_bottom=False, cap_top=True,
    )


def setback_tower(name, collection, rings, location, materials, *, span_materials=None, parent=None):
    """A tower that steps in as it rises.

    ``rings`` is the usual ``(z, half_x, half_y)`` list. Give the top two rings
    the same z with the upper one inset to get a parapet, exactly as
    ``parapet_box`` does.
    """
    return lofted(
        name, collection, rings, location, materials,
        parent=parent, cap_bottom=False, cap_top=True, span_materials=span_materials,
    )


def octahedron(name, collection, radius, location, material, *, scale=(1, 1, 1), parent=None):
    """8 tris. The cheapest thing that still reads as a bush or tree canopy."""
    r = radius
    verts = [(0, 0, -r), (r, 0, 0), (0, r, 0), (-r, 0, 0), (0, -r, 0), (0, 0, r)]
    faces = [
        (0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1),
        (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4),
    ]
    obj = _finish(name, mesh_from(name, verts, faces), collection, location, (0, 0, 0), [material], parent)
    obj.scale = scale
    return obj


# --------------------------------------------------------------------------
# validation
# --------------------------------------------------------------------------

def triangle_count(design: bpy.types.Collection) -> int:
    total = 0
    for obj in design.all_objects:
        if obj.type != "MESH":
            continue
        for polygon in obj.data.polygons:
            total += max(1, len(polygon.vertices) - 2)
    return total


def validate(design: bpy.types.Collection, *, cells, triangle_budget: int, tolerance: float = 0.02) -> int:
    """Enforce both halves of the contract: the grid footprint and the budget.

    ``cells`` is an int for square footprints or a ``(width, depth)`` tuple —
    the catalog has 9x4 and 2x3 assets as well as square ones.
    """
    width, depth = cells if isinstance(cells, (tuple, list)) else (cells, cells)
    half_x, half_y = lot_size(width) / 2, lot_size(depth) / 2
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
            worst = max(worst, abs(world.x) - half_x, abs(world.y) - half_y, -world.z)
        evaluated.to_mesh_clear()
        if worst > tolerance:
            offenders.append((worst, obj.name))

    tris = triangle_count(design)
    print(
        f"[validate] bounds x {low.x:.2f}..{high.x:.2f}  y {low.y:.2f}..{high.y:.2f}  "
        f"z {low.z:.2f}..{high.z:.2f}"
    )
    print(f"[validate] triangles {tris} / budget {triangle_budget}")
    for overshoot, name in sorted(offenders, reverse=True)[:10]:
        print(f"[validate] {name} overshoots by {overshoot:.2f}")

    problems = []
    if low.x < -half_x - tolerance or high.x > half_x + tolerance:
        problems.append(f"x {low.x:.2f}..{high.x:.2f} exceeds +/-{half_x}")
    if low.y < -half_y - tolerance or high.y > half_y + tolerance:
        problems.append(f"y {low.y:.2f}..{high.y:.2f} exceeds +/-{half_y}")
    if low.z < -tolerance:
        problems.append(f"z {low.z:.2f} dips below ground")
    if tris > triangle_budget:
        problems.append(f"{tris} triangles exceeds the {triangle_budget} budget")
    if problems:
        raise SystemExit("[validate] contract violated: " + "; ".join(problems))
    return tris


# --------------------------------------------------------------------------
# scenes, lighting, render
# --------------------------------------------------------------------------

def activate_scene(scene: bpy.types.Scene) -> bpy.types.Scene:
    for manager in bpy.data.window_managers:
        for window in manager.windows:
            window.scene = scene
            return scene
    return scene


def look_at(obj: bpy.types.Object, target) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def game_camera_location(distance: float = 220.0) -> tuple[float, float, float]:
    """The locked city projection: 45 deg azimuth, 35.26439 deg elevation."""
    elevation = math.radians(35.26439)
    azimuth = math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    return (
        horizontal * math.cos(azimuth),
        -horizontal * math.sin(azimuth),
        distance * math.sin(elevation),
    )


def configure_cycles(scene: bpy.types.Scene, samples: int) -> None:
    scene.render.engine = "CYCLES"
    addon = bpy.context.preferences.addons.get("cycles")
    if addon is not None:
        prefs = addon.preferences
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
    scene.cycles.denoising_use_gpu = True
    scene.cycles.adaptive_threshold = 0.02
    scene.cycles.max_bounces = 4
    scene.cycles.diffuse_bounces = 2
    scene.cycles.glossy_bounces = 2


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
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    scene.view_settings.exposure = -0.05
    scene.view_settings.use_curve_mapping = True
    mapping = scene.view_settings.curve_mapping
    curve = mapping.curves[3]
    curve.points.new(0.22, 0.16)
    curve.points.new(0.55, 0.58)
    curve.points.new(0.86, 0.92)
    mapping.white_level = (0.97, 0.97, 0.97)
    mapping.update()


def add_lighting(scene: bpy.types.Scene, collection: bpy.types.Collection, *, target=(0, 0, 8.0)) -> None:
    """Warm key from screen-upper-left of the locked isometric, cool sky fill,
    warm rim from behind. The right-hand face is always the shade side."""
    sun_data = bpy.data.lights.new(f"{scene.name}_Key", "SUN")
    sun_data.energy = 3.6
    sun_data.angle = math.radians(9.0)
    sun_data.color = rgb("#FFE7B8")[:3]
    sun = bpy.data.objects.new(f"{scene.name}_Key", sun_data)
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
    box(f"{scene.name}_Backdrop", collection, (size[0], size[1], 1.0), (0, 0, -0.62), mat("Backdrop"))


def make_scene(
    name: str,
    design: bpy.types.Collection,
    filepath,
    *,
    width: int,
    height: int,
    camera_location,
    target,
    ortho_scale: float | None,
    samples: int,
    focal: float = 85.0,
    backdrop=(320, 320),
) -> bpy.types.Scene:
    scene = bpy.data.scenes.new(name)
    if design is not None:
        scene.collection.children.link(design)
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    configure_cycles(scene, samples)
    configure_world(scene)
    configure_view(scene)

    rig = bpy.data.collections.new(f"{name}_Rig")
    scene.collection.children.link(rig)
    camera_data = bpy.data.cameras.new(f"{name}_Camera")
    # The city works in 20-unit cells, so cameras sit hundreds of units out.
    # Blender's 100-unit default far clip would render an empty frame.
    camera_data.clip_start = 0.1
    camera_data.clip_end = 20000.0
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
    add_backdrop(scene, rig, size=backdrop)
    scene.render.filepath = str(filepath)
    return scene, rig


def render_scene(scene: bpy.types.Scene) -> None:
    activate_scene(scene)
    print(f"[render] {scene.name} -> {scene.render.filepath}")
    bpy.ops.render.render(write_still=True)


# --------------------------------------------------------------------------
# bake + export
# --------------------------------------------------------------------------

def bake_and_export(
    design: bpy.types.Collection,
    stem: str,
    export_dir,
    *,
    resolution: int,
    samples: int,
    bake_normal: bool = True,
):
    """Flatten the asset to one mesh with one base colour / normal / emissive set.

    Returns the merged object so the caller can render a runtime-equivalent
    check or export variants from it.
    """
    scene = bpy.data.scenes.new(f"Scene_Bake_{stem}")
    activate_scene(scene)
    configure_cycles(scene, samples)
    configure_world(scene)
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.bake.margin = 4

    scene.collection.children.link(design)
    sources = [obj for obj in design.all_objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in sources:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = sources[0]
    bpy.ops.object.duplicate()
    duplicates = list(bpy.context.selected_objects)

    work = bpy.data.collections.new(f"Bake_Work_{stem}")
    scene.collection.children.link(work)
    for obj in duplicates:
        for parent_collection in list(obj.users_collection):
            parent_collection.objects.unlink(obj)
        work.objects.link(obj)
        # glTF skips any object whose parent is not part of the exported
        # scene, and the design root empty stays behind in the design
        # collection.
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
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.012, correct_aspect=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    basecolor = bpy.data.images.new(f"{stem}_basecolor", resolution, resolution, alpha=False)
    emissive = bpy.data.images.new(f"{stem}_emissive", resolution, resolution, alpha=False)
    normal = bpy.data.images.new(f"{stem}_normal", resolution, resolution, alpha=False, is_data=True)

    targets = []
    for slot in merged.material_slots:
        if slot.material is None:
            continue
        slot.material = slot.material.copy()
        nt = slot.material.node_tree
        # A DIFFUSE-colour bake returns base_colour * (1 - metallic), so metal
        # would read near-black. These are matte stylized surfaces anyway.
        for node in nt.nodes:
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Metallic"].default_value = 0.0
        node = nt.nodes.new("ShaderNodeTexImage")
        node.location = (-1800, 600)
        node.select = True
        nt.nodes.active = node
        targets.append(node)

    def bake_pass(kind, image, **settings):
        for target in targets:
            target.image = image
            target.id_data.nodes.active = target
        print(f"[bake] {kind} @ {resolution}px")
        bpy.ops.object.bake(type=kind, margin=4, use_clear=True, **settings)

    # The materials already carry their own ambient occlusion; joining widens
    # it to cover contact between parts. A separate AO pass on top of that
    # double-darkens every crease into mud.
    bake_pass("DIFFUSE", basecolor, pass_filter={"COLOR"})
    bake_pass("EMIT", emissive)
    if bake_normal:
        # Captures both the procedural bump detail and the Bevel node, so a
        # plain box keeps rounded edges and a flat roof keeps tile courses.
        bake_pass("NORMAL", normal)

    export_dir.mkdir(parents=True, exist_ok=True)
    written = [(basecolor, f"{stem}_basecolor.png"), (emissive, f"{stem}_emissive.png")]
    if bake_normal:
        written.append((normal, f"{stem}_normal.png"))
    for image, filename in written:
        image.filepath_raw = str(export_dir / filename)
        image.file_format = "PNG"
        image.save()

    export_material = bpy.data.materials.new(f"{stem}_baked")
    export_material.use_nodes = True
    nt = export_material.node_tree
    nt.nodes.clear()
    base_tex = _new(nt, "ShaderNodeTexImage", -700, 220)
    base_tex.image = basecolor
    emit_tex = _new(nt, "ShaderNodeTexImage", -700, -140)
    emit_tex.image = emissive
    bsdf = _new(nt, "ShaderNodeBsdfPrincipled", -240, 120)
    nt.links.new(base_tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(emit_tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.78
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
    if bake_normal:
        normal_tex = _new(nt, "ShaderNodeTexImage", -700, -500)
        normal_tex.image = normal
        normal_tex.image.colorspace_settings.name = "Non-Color"
        normal_map = _new(nt, "ShaderNodeNormalMap", -450, -500)
        nt.links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
        nt.links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    output = _new(nt, "ShaderNodeOutputMaterial", 60, 120)
    nt.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    merged.data.materials.clear()
    merged.data.materials.append(export_material)

    bpy.ops.object.select_all(action="DESELECT")
    merged.select_set(True)
    bpy.context.view_layer.objects.active = merged
    export_selection(stem, export_dir)
    tris = sum(max(1, len(p.vertices) - 2) for p in merged.data.polygons)
    print(f"[bake] exported {stem}: {tris} triangles, {resolution}px maps")
    return merged, scene


def export_selection(stem: str, export_dir) -> None:
    glb_path = export_dir / f"{stem}.glb"
    usdz_path = export_dir / f"{stem}.usdz"
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


def reset_file(scene_name: str = "Scene_Build") -> None:
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
    MATERIALS.clear()
    bpy.context.scene.name = scene_name
