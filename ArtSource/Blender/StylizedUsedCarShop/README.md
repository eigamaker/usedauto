# Stylized Used Car Shop (3×3) — art direction reference (superseded)

> **Not a shippable asset.** At 44,168 triangles it is roughly 69× the budget a
> map-filling city can afford. It survives only as the visual target. The
> shippable pipeline is [`../LowPolyCityKit/`](../LowPolyCityKit/README.md);
> the reasoning is in
> [`../../../ArtDirection/LOWPOLY-CITY-PLAN.md`](../../../ArtDirection/LOWPOLY-CITY-PLAN.md).
> The `.blend`, the exports and the renders are not in the repository.
> Re-create the renders with the generator below when the visual target
> needs to be looked at again.


A single from-scratch asset in a **bright, saturated, chunky mobile-game style**
(Clash of Clans family), built to test whether the whole city should move to
this look. It does not replace anything yet; the existing flat low-poly library
in `../CityAssetLibrary/` is untouched.

## What this is

| | |
| --- | --- |
| Slot | `playerMediumDealer` (the standard player shop) |
| Footprint | `3 × 3` cells = `60 × 60` world units |
| Height | `≈ 29.5` units to the ridge |
| Origin | footprint centre at ground level |
| Front / public road edge | Blender `-Y` |
| Triangles | `44,168` in the export (22,752 polygons before triangulation) — concept quality, see *Open items* |
| Runtime material | one baked base-colour map + one emissive map |

## Files

- `../build_stylized_used_car_shop.py` — deterministic generator (geometry,
  materials, lighting, renders, bake, export)
- `stylized_used_car_shop_3x3.blend` — editable source
- `previews/` — beauty and validation renders
- `exports/` — `.glb`, `.usdz`, and the baked `*_basecolor.png` / `*_emissive.png`

### Previews

| File | What it answers |
| --- | --- |
| `stylized_used_car_shop_hero.png` | Does the style work at all? |
| `stylized_used_car_shop_game_camera.png` | Does it read at the locked city projection and zoom? |
| `stylized_used_car_shop_storefront.png` | Does the surface detail hold up close? |
| `stylized_used_car_shop_orientations.png` | Does it hold up rotated 0/90/180/270? |
| `stylized_used_car_shop_baked_check.png` | Does the look survive the bake into a shippable single-texture mesh? |
| `style_comparison_old_vs_new.png` | Side by side with the previous dealer concept. Composited outside Blender, not produced by the build script. |

## How the "hand-painted" look is produced

There is no painted texture work here. Everything is procedural, so the whole
city can be regenerated deterministically. Four cues are stacked in
`stylized_material()`:

1. **Mottled base colour** — a per-surface pattern (plaster speckle, rubble
   blocks, timber grain, roof courses, asphalt grit, turf clumps).
2. **Vertical paint gradient** — every mass darkens toward its own base, using
   normalised generated coordinates so it works at any object size.
3. **Pointiness** — convex edges lighten, concave creases darken. This is the
   brushed-in edge highlight that separates a stylized asset from a flat one.
4. **Short-range ambient occlusion** — contact shading multiplied into the
   albedo.

Plus a Bevel shader node so no edge shades perfectly sharp.

Two things are modelled rather than shaded because shading alone reads flat at
game zoom:

- **The roof is real tile courses** (`stepped_roof()`): eight lofted rings, each
  overhanging the one above, so the roof casts its own row of hard shadows.
- **Every mass is battered** — walls, plinths and roofs taper, and nothing is a
  plain box.

## Art rules this asset establishes

- Warm saturated palette: golden sand walls, teal roof, terracotta and gold
  accents, high-chroma grass. No chrome, no grey-blue realism.
- Chunky silhouette: oversized flared roof, heavy fascia boards, thick corner
  timbers with gold caps.
- Terrain reads as a *cut tile*: earth block, grass cap overhanging it, loose
  rocks at the edge.
- Story props over text: bunting, pylon sign, striped awning, planters, tyre
  stacks, cones. The emblem is a car silhouette so nothing needs localising.
- Lighting: warm key from screen-upper-left of the locked isometric, cool sky
  fill, warm rim from behind. The right-hand face is always the shade side.
- Tone mapping is **Standard**, not AgX — AgX rolls saturated colour toward grey
  and reads muddy for this style.

## Rebuild

From the project root:

```sh
blender --background --factory-startup \
  --python ArtSource/Blender/build_stylized_used_car_shop.py
```

Flags after `--`:

- `--quick` — low-sample previews at 45% resolution (a few seconds per image)
- `--no-bake` — skip the bake and export step
- `--hero-only` — render only the hero image

Requires Cycles. The script enables OPTIX/CUDA automatically when present.

## Open items before this could ship

- **Triangle budget.** `44k` tris is far too heavy for a map full of these.
  Most of it is bevel-modifier geometry. Needs lower bevel segment counts, a
  decimated LOD set, and prop culling matching `CityAssetLODVisibility`.
- **File size.** `7.4 MB` GLB / `6.9 MB` USDZ, dominated by the 2048² base
  colour map. A shared atlas and 1024² per asset would fix this.
- **Node naming and LOD layers.** The existing library exports separate silhouette
  / facade / prop layers; this asset is one flat hierarchy.
- **Texture atlas sharing.** Each asset currently bakes its own 2048² map. A
  shared atlas across the family is needed before the whole city moves over.
- **Collision / hit-testing volume.** Not authored.
- **Runtime lighting.** These previews are Cycles. The SceneKit scene needs its
  lighting matched, or the baked map needs to carry more of the lighting.
