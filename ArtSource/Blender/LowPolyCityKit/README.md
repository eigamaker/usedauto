# Low-poly city kit

The asset pipeline for a 200×200 map that is solid with buildings. See
[`../../../ArtDirection/LOWPOLY-CITY-PLAN.md`](../../../ArtDirection/LOWPOLY-CITY-PLAN.md)
for the reasoning and the phase plan.

One rule:

> **Geometry carries silhouette. Texture carries everything else.**

## Files

- [`../citykit.py`](../citykit.py) — the shared library every asset builds
  against: palette, procedural stylized materials, cheap geometry helpers,
  contract validation, atlas bake, glTF/USDZ export.
- [`../build_lowpoly_used_car_shop.py`](../build_lowpoly_used_car_shop.py) —
  the first asset, and the template for the rest.
- `lowpoly_city_kit.blend` — editable source.
- `previews/`, `exports/`.

## The probe asset

| | |
| --- | --- |
| Slot | `playerMediumDealer` |
| Footprint | 3×3 cells = 60×60 units, origin at footprint centre, front = `-Y` |
| Triangles | **639** (budget 700) |
| Textures | 512px base colour + normal + emissive |
| Export | 0.75 MB GLB / 0.75 MB USDZ |

For comparison the earlier concept version of the same building was 44,168
triangles and 7.4 MB.

## Previews

| File | What it answers |
| --- | --- |
| `budget_comparison.png` | 44,168 tris vs 639 tris, same camera. The point of the whole branch. |
| `lowpoly_district.png` | 42 lots on continuous ground = 26,838 triangles. Does a dense block read? |
| `lowpoly_used_car_shop_game_camera.png` | Does one asset hold up at the locked projection? |
| `lowpoly_used_car_shop_baked_check.png` | Does it survive the bake? This is the runtime-equivalent mesh. |
| `lowpoly_used_car_shop_storefront.png` | How far can you zoom before the texture gives out? |

## How the detail is produced without geometry

Nothing below is modelled:

- **Windows, frames and mullions** — `panel_pattern()` paints a bay grid into
  the wall. It is driven by object-space `X+Y` rather than `X`, because `X` is
  constant across an X-facing wall and would turn the grid into horizontal
  stripes on the side elevations.
- **Roof tile courses** — `shingle_pattern()` bands object-space Z, so courses
  lie correctly on any slope of a plain 5-quad hip roof. The bump output drives
  the baked normal map.
- **Rounded edges** — the Bevel shader node, baked into the normal map. A plain
  box shades like a bevelled one.
- **Timber grain, rubble, grit, turf, awning stripes** — procedural patterns,
  baked to base colour.
- **Ambient occlusion and painted edge highlights** — an AO node and geometry
  pointiness, baked into the base colour. There is no separate AO pass: joining
  the asset into one mesh already widens the material AO to cover contact
  between parts, and a second pass double-darkens every crease into mud.

## Adding an asset

1. Copy `build_lowpoly_used_car_shop.py`.
2. Build geometry from `kit.box` / `kit.lofted` / `kit.plane` / `kit.prism` /
   `kit.octahedron` only. No bevel modifiers.
3. Reuse the materials in `build_materials()` — every asset must share the
   palette so a single atlas works later.
4. Call `kit.validate(design, cells=N, triangle_budget=B)`. It fails the build
   if the asset leaves its footprint, dips below ground, or busts the budget.

Budget ladder: 1×1 ≤ 250, 2×2 ≤ 450, 3×3 ≤ 800, 4×4 ≤ 1,200 triangles.

## Rebuild

```sh
blender --background --factory-startup --python ArtSource/Blender/build_lowpoly_used_car_shop.py
```

Flags after `--`: `--quick` (half-resolution, low-sample previews),
`--no-bake` (skip bake and export). Requires Cycles; the script enables
OPTIX/CUDA when present.

## Open items

- **Shared atlas.** Each asset currently bakes its own 512px set. Phase 1 ends
  with all assets baked into one 4096² atlas and one material.
- **Prop instancing.** Cars and trees are baked into each asset. They should
  become shared instanced meshes so their cost is paid once for the whole city.
- **Lot verge.** The probe keeps a grass plane around the lot. Commercial
  districts should have a paved variant so dense blocks do not checkerboard.
- **No device measurement yet.** See the plan's "Not yet proven" section.
