# Used Car City — Visual Direction

The city uses one grid-native, toy-like low-poly art system. Runtime artwork is
procedural SceneKit geometry so placement, rotation, hit testing, and zoom never
depend on transparent sprite padding.

## Locked projection and scale

- One grid cell is `20 × 20` world units.
- The camera is orthographic at `45°` azimuth and `35.26439°` elevation.
- Every asset origin is the centre of its footprint at ground level.
- Every asset has an exact-size footprint plinth. A `2 × 3` asset therefore
  occupies `40 × 60` units, and becomes `60 × 40` after a quarter turn.
- Zoom changes orthographic scale only. It never changes camera angle or asset
  placement.

## Shape language

- Chunky masses, bevelled edges, thick roof overhangs, bold fascia bands.
- Warm cream walls, royal-blue owned-facility roofs and signs, orange/red
  accents, charcoal asphalt, yellow-green terrain.
- Warm upper-left key light, cool fill, and baked soft contact shadows.
- Props are progressively revealed by LOD; the lot and building silhouette are
  always present.

## Generated reference

[`used-car-city-visual-target.png`](used-car-city-visual-target.png) is the
approved visual target generated from the two supplied references. It is an art
direction aid; gameplay renders the corresponding geometry rather than using
the image as a sprite sheet.

Generation prompt summary: a cohesive modular family of 1×1, 1×2, 2×2, 2×3,
3×3, and 4×4 used-car-business lots; true orthographic isometric view; exact
contained bases; polished chunky toy-like low-poly finish; warm walls, royal
blue roofs, orange accents, charcoal asphalt, golden-green grass; no people,
logos, watermark, UI, or perspective distortion.

## Superseded by the low-poly city rebuild

The direction above still describes what ships today. It is being replaced —
see [`LOWPOLY-CITY-PLAN.md`](LOWPOLY-CITY-PLAN.md).

Two attempts sit behind that plan:

1. [`../ArtSource/Blender/StylizedUsedCarShop/`](../ArtSource/Blender/StylizedUsedCarShop/README.md)
   established the visual target — saturated colour, chunky battered masses,
   painted shading — but at 44,168 triangles per asset it cannot fill a map.
   Kept as an art-direction reference only; run its generator to see the
   renders, which are not committed.
2. [`../ArtSource/Blender/LowPolyCityKit/`](../ArtSource/Blender/LowPolyCityKit/README.md)
   reaches the same look at 639 triangles by moving every detail into a baked
   texture. This is the pipeline to build on.
