# City rebuild — implementation spec

Executable specification for the low-poly / rich-texture city. Strategy and
rationale live in [`LOWPOLY-CITY-PLAN.md`](LOWPOLY-CITY-PLAN.md); **this**
document is the one to work from. It is written so that every number is given
and no design decision is left to the implementer.

Work through the steps in order. Each step ends with a **Gate** — a command to
run and the output that must appear before moving on.

**Steps 1 and 2 of section 8 are already done.** The shared library
`ArtSource/Blender/citykit.py` has the full pattern set, the geometry helpers
and the validator; `ArtSource/Blender/build_pattern_testcard.py` renders the
reference sheet. Start at step 3.

---

## 0. Measured constraints (do not re-derive)

| Fact | Value | Source |
| --- | --- | --- |
| Cell size | 20 world units | `GridCityMetrics`, `citykit.CELL` |
| Camera | orthographic, azimuth 45°, elevation 35.26439°, fixed | `GridOrthographicCameraSpec.foundation` |
| Zoom range | factor 0.88 → 0.0314286 (10 steps), baseline step 3 = 0.22 | same |
| Max zoom on-screen density | **≈ 1.34 px per world unit** | measured from `ArtDirection/runtime-preview.png` at 714% |
| A 4×4 building at max zoom | **≈ 150 px wide on screen** | 80 units × √2 × 1.34 |
| Runtime lights | ambient 520 cool, directional 1450 warm (no shadows), fill 280 cool | `GridCitySceneView.buildLighting()` |
| Asset origin | footprint centre at ground, front = `-Y` (Blender) / south (SceneKit) | `CityAssetCatalog` |
| Current library | 46 assets, avg 5,555 polys, 23 MB USDZ, **no textures** | `city_asset_manifest.json` |

Two consequences drive every decision below:

1. **Textures can be small.** A 4×4 asset never exceeds ~150 px on screen, so a
   512 px atlas region is already ~2.5× oversampled. The whole library fits in
   one 4096² page.
2. **The roof is roughly half of every building's visible pixels** at a 35°
   isometric. Roof texture quality is the single largest visual lever, and the
   current library spends nothing on it. Section 3.4 exists because of this.

### Not doing in v1

* **No normal maps.** At 150 px on screen they are invisible, and they double
  texture memory. The painted relief (AO, pointiness, pattern shading) is baked
  into base colour instead. Revisit only for player facilities if a close-up
  view is ever added. Remove `bake_normal` usage from `citykit.bake_and_export`
  call sites; keep the parameter.
* **No per-instance colourways.** Variation comes from asset count, height
  variation and 4 rotations, all of which already exist. Section 9 records the
  mechanism to add colourways later if repetition proves visible.
* **No engine change.** SceneKit stays. See the plan document.

---

## 1. Triangle and texture budget ladder

Every asset is validated against this at build time by
`citykit.validate(design, cells=…, triangle_budget=…)`. The build **fails** if
an asset busts its budget, leaves its footprint, or dips below `z = 0`.

| Footprint | World size | Triangles | Atlas region |
| --- | --- | --- | --- |
| 1×1 | 20×20 | 120 | 256² |
| 1×2 | 20×40 | 160 | 256² |
| 2×2 | 40×40 | 260 | 256² |
| 2×3 | 40×60 | 320 | 256² |
| 3×3 | 60×60 | 700 | 512² |
| 4×4 | 80×80 | 900 | 512² |
| 9×4 | 180×80 | 1,400 | 768² |
| 9×9 | 180×180 | 1,800 | 768² |

`validate()` currently takes a single `cells` int. **Change it to take a
`GridSize`-equivalent `(width, depth)` tuple** so 9×4 works:

```python
def validate(design, *, cells, triangle_budget, tolerance=0.02):
    width, depth = cells if isinstance(cells, tuple) else (cells, cells)
    half_x, half_y = lot_size(width) / 2, lot_size(depth) / 2
```

Whole-library totals at these budgets: **≈ 40,000 triangles for all 46 assets**
— less than three of today's single assets.

Atlas occupancy: 7 × 256² + 30 × 512² + 9 × 768² = 13.6 M px² of a 4096² page
(16.8 M). 19 % slack for later additions.

---

## 2. Where the code goes

```
ArtSource/Blender/
  citykit.py                     # shared library — extend, do not fork
  build_city_kit.py              # NEW: builds all 46 assets in one run
  assets/                        # NEW: one module per category
    residential.py
    luxury.py
    commercial.py
    industrial.py
    downtown.py
    highway.py
    player.py
  pack_atlas.py                  # NEW: packs per-asset bakes into one page
  CityKit/
    previews/                    # per-asset + contact sheets
    exports/                     # per-asset glb/usdz + atlas page
```

Each category module exposes:

```python
ASSETS = {
    "residentialCottage": {
        "cells": (4, 4),
        "triangle_budget": 900,
        "texture": 512,
        "build": build_cottage,       # (collection, root) -> None
    },
    ...
}
```

`build_city_kit.py` iterates every module's `ASSETS`, builds, validates, bakes,
renders a preview, and writes a manifest. It takes `--only <assetId>` so a
single asset can be iterated on in seconds.

---

## 3. The texture system — **already implemented**

The pattern library is built and tuned. Do not re-derive it from prose: call
the functions and look at the rendered reference.

> **Reference sheet:**
> `ArtSource/Blender/LowPolyCityKit/previews/pattern_testcard.png` and
> `pattern_testcard_close.png`, produced by
> `ArtSource/Blender/build_pattern_testcard.py`. Every pattern below appears
> there on a sample mass at the real game camera. **Pick parameters by looking
> at that image, not by reading this section.** Re-run the test card after any
> change to `citykit.py`.

All patterns share one contract:

```python
def some_pattern(**params):
    def build(nt, coord, base):     # coord = object-space vector socket
        ...
        return colour_socket, bump_socket_or_None
    return build
```

and are passed to `kit.stylized_material(name, base_key, pattern=…)`.

### 3.0 Two rules that will silently ruin a pattern

**Rule 1 — horizontal wall features must use X + Y, never X.**
Object-space X is constant across an X-facing wall, so anything driven by X
alone collapses into horizontal stripes on the side elevations. `_axes()`
returns `plan = X + Y` for exactly this. Vertical features use Z directly.
Horizontal *surfaces* (roofs, lots) are the exception: there X and Y both vary,
and seams and bay lines should use them directly.

**Rule 2 — texture Scale is in cycles per world unit, and the city works in
tens of units.** A `Noise Texture` at `Scale = 7` has a 0.14-unit period; on a
40-unit wall that is 280 cycles, which at 150 px on screen is grey static. This
mistake was made once already and turned every roof into sand. Working ranges:

| Feature | Scale |
| --- | --- |
| Broad tonal patches (pooling, stains) | 0.05 – 0.10 |
| Surface mottle (membrane, plaster) | 0.25 – 0.5 |
| Fine grain (asphalt grit) | 3 – 8 |
| Rib / course pitch, expressed as world units | ≥ 2.0 |

Anything with a period below ~1.5 world units will not survive the bake.

### 3.1 `facade_pattern` — the workhorse

A composed building facade, not a grid of holes. Built against a London street
reference: cream stucco and dark brick, shopfronts with pilasters and
stallrisers, upper windows whose stone surrounds stand proud of the wall, sills
that cast a shadow, glazing bars, a string course above the ground floor and a
cornice under the roof.

```python
kit.facade_pattern(
    storey=5.0,              # world units per floor
    bay=5.5,                 # world units per window bay
    ground=7.0,              # world units of ground-floor register
    parapet=0.09,            # fraction of the object's height, from the top
    cornice=1.6,             # projecting band under the parapet, 0 = none
    string_course=0.9,       # projecting band above the ground floor, 0 = none

    window_w=2.6,            # WORLD UNITS, not a ratio — a window is the same
    window_h=3.0,            #   physical size on a warehouse and a townhouse
    surround="raised",       # "raised" | "recessed" | "flush"
    surround_width=0.55,
    sill=True, lintel=False,
    glazing_bars="transom",  # "none" | "transom" | "cross" | "grid"

    wall_texture="stucco",   # "stucco" | "brick" | "ashlar" | "panel" | "plain"
    ground_mode="shopfront", # "shopfront" | "door" | "plinth" | "dock" | "same"
    door_chance=0.34,        # shopfront bays that become a door instead

    lit_fraction=0.30,
    wall=None, trim=None, glass=None, glass_unlit=None,
    shade=None, accent=None,
)
```

**Vary these per asset — this is where the city's variety comes from.** Two
buildings with the same geometry and different `wall_texture` + `surround` +
`glazing_bars` read as two different buildings.

What each mode gives you:

* `surround="raised"` — a stone frame proud of the wall, with a lit top face
  and a shadow cast on the wall below it. Georgian / stucco townhouse.
* `surround="recessed"` — the opening cut into the wall, with the reveal
  shadow along the head and one side. Brick terrace.
* `ground_mode="shopfront"` — stallriser, display glazing with a warm interior
  behind it, transom bar, signage fascia in `accent`, pilasters between bays,
  and timber double doors in a `door_chance` fraction of the bays.
* `wall_texture="brick"/"ashlar"` — running bond with per-brick tone variation.
  A stacked bond reads as graph paper, so the courses are offset.

Five things are load-bearing and must not be tuned away:

* the **surround** (raised or recessed) — a bare rectangle reads as a sticker;
* the **sill**, a bright line under the opening with the wall darkened beneath;
* the **lit hash** — a facade where every window is identically lit reads as
  wallpaper;
* the **string course and cornice** — the strongest horizontals in the
  reference, and what separates a building from an extruded box;
* **cool unlit glass** (`glass_cool`), never a darkened version of the lit
  colour. Dark panes read as holes punched in the wall; pale teal panes read as
  glass. This was the single biggest fix in the whole pattern set.

### 3.1b `showroom_pattern` — car dealerships

A dealership reads as a dealership because the stock is visible through the
glass. Modelling cars behind a transparent wall would cost geometry *and*
break the single-material batching, so the interior is painted.

```python
kit.showroom_pattern(
    mullion=4.6, transom=7.6, base=1.6,
    car_zone=10.5,        # cars appear only BELOW this height, in world units
    car_pitch=9.6,
    interior_mix=0.52, reflection=0.12,
    frame=None, glass=None, spandrel=None,
    interior=None, floor=None, ceiling=None,
    car_colours=None, show_cars=True,
)
```

Three things were got wrong on the first pass and are worth stating:

* **Cars belong on the ground floor only.** Driving them from the per-storey
  coordinate scatters a car onto every floor and reads as wallpaper.
  `car_zone` gates them by absolute height.
* **Silhouettes need `_rounded_rect`, not `_rect` or `_ellipse`.** A plain
  rectangle staircases; two overlapping ellipses make a heart. A rounded
  rectangle keeps the flat bottom a vehicle needs.
* **Glass has to stay glass.** Deep base colour, dark mullions, restrained
  reflection, and `edge_amount` near zero — pointiness on a four-vertex wall is
  a full-face gradient and washes a curtain wall to near-white.

Use `show_cars=False` on the flanks so the same silhouettes do not repeat on
every elevation.

### 3.2 `curtainwall_pattern` — downtown towers

```python
kit.curtainwall_pattern(storey=4.2, mullion=2.6, glass=None,
                        spandrel=None, frame=None, lit_fraction=0.22)
```

Horizontal glazing bands with spandrels, fine vertical mullions, a scattered
lit hash, and a pointiness lift on the vertical corners so towers separate from
the sky.

### 3.3 `corrugated_pattern` — industrial sheds

```python
kit.corrugated_pattern(pitch=2.6, base_key=None, light=None,
                       dark=None, rust=0.15, seam=8.0)
```

A three-stop ramp gives every rib a lit and a shaded face — a two-stop ramp
reads as stripes. Rust is gated by `Generated.z` so sheds stain from the ground
up. **`pitch` below ~2.0 aliases to flat at map zoom** (see Rule 2).

### 3.4 `flatroof_pattern` — the highest-value pattern in the kit

**Use this on every flat-roofed asset.** At a 35° isometric the roof is roughly
half of a building's visible pixels, and today's library spends a flat colour
there. That alone is most of why the city looks unfinished.

```python
kit.flatroof_pattern(
    membrane=None, seam=None, unit=None,
    seam_pitch=6.0,      # world units between membrane seams
    kit_density=0.35,    # 0..0.9 — how crowded with rooftop plant
    parapet_inset=0.10,  # FRACTION of the plan half-size, not world units
    unit_pitch=9.0,      # world units between rooftop plant slots
)
```

Five layers, all required: membrane mottle, seams, pooling, rooftop plant with
its own cast shadow, and the parapet edge shadow. The plant is laid on a
**rectangular grid**, not a Voronoi — Voronoi cells read as torn patches, and at
this size the difference between "roof kit" and "damage" is exactly that.

Never substitute a plain colour "for now"; the whole visual case rests on this.

### 3.5 `lotmarking_pattern` — parking and yards without geometry

```python
kit.lotmarking_pattern(
    surface_key="asphalt", paint=None, kerb=None,
    bay_width=4.6, bay_depth=9.5, aisle=7.0,
    kerb_inset=0.06,     # FRACTION of the plan half-size
)
```

Rows of bays separated by clean aisles, head lines, tyre wear, and a kerb band.
`surfaceParking` is 11,522 polygons today; with this it is a **10 triangle**
asset. That one change pays for a large part of the map expansion.

### 3.6 `with_signage` — the colour accent

A wrapper, not a standalone pattern:

```python
kit.with_signage(inner_pattern, z_min, z_max, colour_key="red",
                 emblem="circle",          # "circle" | "square" | "bar"
                 emblem_colour_key="cream_trim",
                 emblem_pitch=26.0, emblem_size=2.4)
```

Abstract shapes, no text, so nothing needs localising. Assign one emblem per
category so the city is readable at a glance: commercial `circle`, highway
`circle` at 1.6× size, industrial `bar`, player `square`.

### 3.7 `masonry_colour` — wall material

Called by `facade_pattern` via its `wall_texture` argument, and available
directly for any surface that needs a material rather than a colour:

```python
kit.masonry_colour(nt, coord, plan, z, base, kind, mortar=None)
# kind = "stucco" | "brick" | "ashlar" | "panel" | "plain"
```

Brick is 0.85 x 2.0 units, ashlar 2.4 x 4.4, both in running bond with a
per-unit tone hash. This is what answers "what is this building made of" at a
glance, and it costs nothing.

### 3.8 Palette

The additions listed in the plan are already in `citykit.PALETTE`, plus
`glass_cool` / `glass_cool_dark` for unlit panes:
`office_glass`, `office_glass_lit`, `office_spandrel`, `office_frame`,
`membrane`, `membrane_seam`, `roof_unit`, `gravel_roof`, `metal_shed`,
`metal_shed_dark`, `rust`, `brick`, `brick_dark`, `render_grey`, `render_blue`,
`roof_terracotta`, `roof_slate`, `roof_green`, `kerb`, `paint_yellow`.

Every asset must draw from this palette. A one-off colour in one asset is what
breaks a city's sense of belonging to one place.

---

## 4. Silhouette kit

Geometry is silhouette only. The only primitives permitted are the existing
`kit.box`, `kit.lofted`, `kit.plane`, `kit.quad`, `kit.prism`,
`kit.octahedron`. **No bevel modifiers anywhere** — soft edges come from the
Bevel shader node, which is already wired into `stylized_material`.

Shape helpers for painted detail, all in `citykit.py`:
`_rect`, `_rounded_rect`, `_ellipse`, `_band`, `_bay_local`, `_cell_distance`,
`_hash01`, `_edge_distance`. Prefer `_rounded_rect` for anything that
represents an object rather than a panel.

Three geometry helpers are **already implemented**:

```python
kit.parapet_box(name, collection, (w, d, h), location, [wall, roof],
                parapet=1.4, inset=0.9, parent=None)
# 20 triangles. Use instead of kit.box for EVERY flat-roofed building: a bare
# box top has no edge, reads as a slab, and gives flatroof_pattern nothing to
# cast its edge shadow against.

kit.gable(name, collection, (w, d, rise), location, [roof],
          ridge_axis="X", overhang=1.2, parent=None)
# 12 triangles. Pitched roof with an eave overhang.

kit.setback_tower(name, collection, rings, location, materials,
                  span_materials=None, parent=None)
# A loft that steps in as it rises. Repeat the top z with an inset ring to get
# a parapet, exactly as parapet_box does.
```

`kit.validate()` now accepts `cells=(width, depth)` as well as a plain int, so
9×4 and 2×3 footprints validate correctly.

Reference costs, so budgets can be checked by hand before running the build:

| Element | Triangles |
| --- | --- |
| `kit.box` | 12 |
| `kit.plane` / `kit.quad` | 2 |
| `kit.lofted`, n rings | `8(n-1) + 4` (both caps) |
| `parapet_box` | 20 |
| `gable` | 12 |
| `kit.prism` sides=4 / 6 / 8 | 12 / 20 / 28 |
| `kit.octahedron` | 8 |
| low car (3 boxes) | 36 |
| low tree (prism + 2 octahedra) | 28 |

---

## 5. Per-asset specifications

Organised as **category recipe → per-asset deltas**. The recipe fixes the
silhouette kit, materials and texture parameters for the whole category; the
delta table gives only what differs. Build every asset in a category from its
recipe — consistency across a category is what makes a district read as a
district.

All heights below are the *rendered* height:
`nominalHeight × CityAssetScale.heightMultiplier(category)`. The build script
must read both from a table mirroring `CityAssetCatalog.swift` so the two never
drift.

---

### 5.1 General residential — 5 assets, 4×4, 900 tris, 512²

Rendered heights 50–94 units (`nominal × 7.2`).

**Silhouette:** front garden plane + driveway plane + `parapet_box`-free
construction — these are pitched-roof houses. Body = `kit.lofted` 2 rings with a
0.4-unit batter. Roof = `gable`. Plus: porch box, chimney prism, 1 low tree,
2 octahedron shrubs, a boundary hedge run of 3 octahedra, 1 low car on the
driveway.

**Materials:** `Wall_Render`, `Roof_Shingle`, `Trim_Cream`, `Timber`, `Grass`,
`Asphalt_Drive`.

**Texture:**
```
wall  = facade_pattern(storey=5.2, bay=5.6, ground=5.2, parapet=0.0,
                       window_ratio=0.40, ground_mode="same", lit_fraction=0.25)
roof  = shingle_pattern(course=1.7)
lot   = turf_pattern() with a lotmarking_pattern drive strip
```
Residential roofs are pitched, so `shingle_pattern` applies and
`flatroof_pattern` does not.

| Asset | Height | Roof colour | Delta |
| --- | --- | --- | --- |
| `residentialCottage` | 50 | `roof_terracotta` | single storey, wide gable, 1 dormer box |
| `residentialGable` | 58 | `roof_slate` | steep gable, ridge axis `Y` |
| `residentialFlat` | 50 | `membrane` | **flat roof** — use `parapet_box` + `flatroof_pattern`, `kit_density=0.15` |
| `residentialTwin` | 58 | `roof_terracotta` | two mirrored bodies with a 1-unit gap, one gable each |
| `residentialApartment` | 94 | `roof_slate` | 4 storeys, `ground_mode="plinth"`, balcony band: `signage_band` in `render_grey` at each storey |

---

### 5.2 Luxury residential — 4 assets, 4×4, 900 tris, 512²

Rendered heights 53–66 (`nominal × 6.6`).

**Silhouette:** low wide body (`kit.lofted`, 2 rings) + flat roof via
`parapet_box` + a `gable` wing. Walled garden: a 4-run kerb loft around the plot.
2 trees, 4 shrubs, 1 car, 1 pool/court plane.

**Materials:** `Wall_Render_Light`, `Roof_Flat_Membrane`, `Trim_Cream`, `Timber`.

**Texture:**
```
wall  = facade_pattern(storey=5.6, bay=7.0, ground=6.0, parapet=0.06,
                       window_ratio=0.56, ground_mode="same", lit_fraction=0.35)
roof  = flatroof_pattern(kit_density=0.12, parapet_inset=2.0)
lot   = turf_pattern() + a paved court plane
```
Large `window_ratio` and low `kit_density` are what distinguish luxury from
general residential at a glance.

| Asset | Height | Delta |
| --- | --- | --- |
| `luxuryCourtyard` | 53 | U-plan: three body lofts around a court plane |
| `luxuryGarage` | 59 | garage wing with a `dock` ground band, 2 cars on the apron |
| `luxuryPool` | 53 | pool plane in `#3FA9C9` with a `paint` coping ring, 2 lounger boxes |
| `luxuryTerrace` | 66 | two-storey stepped body, roof terrace plane with 4 planter octahedra |

---

### 5.3 Commercial — 7 assets, 4×4 (mall 9×9), 900 / 1,800 tris, 512² / 768²

Rendered heights 42–102 (`nominal × 6.0`).

**Silhouette:** `parapet_box` body + forecourt plane + pylon sign (prism + box)
+ 3–6 cars + kerb loft.

**Materials:** `Wall_Render`, `Roof_Flat_Membrane`, `Trim_Cream`, `Accent_*`,
`Asphalt`.

**Texture:**
```
wall  = facade_pattern(storey=5.0, bay=5.2, ground=7.0, parapet=0.10,
                       window_ratio=0.46, ground_mode="shopfront", lit_fraction=0.55)
roof  = flatroof_pattern(kit_density=0.45)
lot   = lotmarking_pattern()
sign  = signage_band(z_min=ground-1.6, z_max=ground, emblem="circle")
```
`ground_mode="shopfront"` plus a high `lit_fraction` is the whole commercial
read: a bright glazed base under a plainer upper wall.

| Asset | Height | Accent | Delta |
| --- | --- | --- | --- |
| `commercialAutoDealer` | 60 | `blue` | glazed showroom wall (`window_ratio=0.72`), 8 cars, bunting run |
| `commercialGasStation` | 42 | `red` | small kiosk box + 4-prism canopy on 4 posts, 2 pump boxes |
| `commercialConvenience` | 42 | `gold` | single storey, full-width shopfront, 3 cars |
| `commercialRestaurant` | 48 | `red` | `gable` roof over the entry, terrace plane with 4 umbrella prisms |
| `commercialShopping` | 72 | `blue` | 3 storeys, `window_ratio=0.58`, roof plant `kit_density=0.55` |
| `commercialRoadside` | 54 | `gold` | long low body, pylon sign at 1.6× scale |
| `commercialRegionalMall` | 102, 9×9 | `blue` | 1,800 tris: two linked `parapet_box` masses, 5 roof units as real boxes, 24-bay `lotmarking_pattern` car park, 4 trees |

---

### 5.4 Industrial — 5 assets, 9×9 / 9×4, 1,800 / 1,400 tris, 768²

Rendered heights 63–103 (`nominal × 5.7`).

**Silhouette:** long shed via `kit.lofted` with a shallow `gable`, plus stacks
and tanks as prisms. Yard plane, 2–4 container boxes, 1 truck (low car at 1.4×).

**Materials:** `Metal_Shed`, `Roof_Metal`, `Concrete`, `Accent_Red`.

**Texture:**
```
wall  = corrugated_pattern(pitch=1.1, rust=0.18) with a
        facade_pattern(ground_mode="dock", ground=9.0) band composited at the base
roof  = corrugated_pattern(pitch=1.4) on pitched sheds,
        flatroof_pattern(kit_density=0.55, gravel=…) on flat ones
lot   = lotmarking_pattern(bay_width=9.0, bay_depth=18.0)   # truck bays
```
Industrial sites are the most repeated large mass on the map; the rust gradient
and the dock band carry nearly all their character.

| Asset | Footprint | Height | Delta |
| --- | --- | --- | --- |
| `industrialFactory` | 9×9 | 74 | 3 parallel sheds, 2 stacks (8-prisms), 6 roof vents |
| `industrialWarehouse` | 9×4 | 68 | one long shed, 6 dock doors on the front |
| `industrialLoadingWarehouse` | 9×4 | 63 | as above + a 2-unit-deep loading apron with 3 trucks |
| `industrialTankWorks` | 9×9 | 68 | 4 tank prisms (sides=12) with `signage_band` bar emblems, pipe boxes |
| `industrialSmokestack` | 9×9 | 103 | one tall 8-prism stack with 3 banded rings, plant block at the base |

---

### 5.5 Downtown — 8 assets, 4×4 / 9×4, 900 / 1,400 tris, 512² / 768²

Rendered heights 81–225 (`nominal × 4.5`). These are the tallest silhouettes on
the map.

**Silhouette:** `setback_tower` — 2 to 4 lofted spans stepping in as they rise,
capped with `parapet_box`. Podium at the base with a `shopfront` band. Plaza
plane. No props above the podium.

**Materials:** `Office_Curtainwall`, `Wall_Render_Grey`, `Roof_Flat_Membrane`,
`Trim_Cream`.

**Texture:**
```
wall   = curtainwall_pattern(storey=4.2, mullion=2.6, lit_fraction=0.22)
podium = facade_pattern(storey=5.0, bay=5.0, ground=8.0,
                        ground_mode="shopfront", parapet=0.0)
roof   = flatroof_pattern(kit_density=0.6, parapet_inset=3.2)
plaza  = speckle_pattern() paving with a kerb ring
```
`kit_density=0.6` matters: a tower roof crowded with plant is the difference
between a skyscraper and a painted block, and from this camera the roof of a
tall building is fully visible.

| Asset | Footprint | Height | Delta |
| --- | --- | --- | --- |
| `downtownMixedUse` | 4×4 | 126 | 2 setbacks, `facade_pattern` not curtainwall (masonry upper) |
| `downtownOffice` | 4×4 | 153 | 1 setback, full curtainwall |
| `downtownApartment` | 4×4 | 135 | `facade_pattern(window_ratio=0.38)`, balcony bands every storey |
| `downtownParkingStructure` | 4×4 | 81 | **open deck**: horizontal `signage_band` slabs every 4.5 units, no glass; roof = `lotmarking_pattern`, not membrane |
| `downtownCornerBlock` | 4×4 | 162 | chamfered corner (5-sided loft), curtainwall |
| `downtownOfficePlaza` | 9×4 | 198 | two towers of unequal height on a shared podium |
| `downtownTwinTower` | 9×4 | 225 | two equal towers + a 3-span link bridge box |
| `downtownResidentialTower` | 9×4 | 180 | slab tower, `facade_pattern` with balcony bands, roof `kit_density=0.35` |

---

### 5.6 Highway and parking — 4 assets, 4×4, 900 tris, 512²

Rendered heights 6–86 (`nominal × 5.7`, parking × 1.0).

| Asset | Height | Recipe |
| --- | --- | --- |
| `highwayLogistics` | 68 | industrial recipe, 4 dock doors, 2 trailer boxes |
| `highwayBigBox` | 63 | commercial recipe, single huge `shopfront` band, `lotmarking_pattern` with 30 bays, 4 cars, tall pylon with `chevron` emblem |
| `highwayMotorHotel` | 86 | 3-storey L-plan, `facade_pattern(bay=4.2, window_ratio=0.34)` — many small identical windows is the motel read; external walkway `signage_band` at each storey |
| `surfaceParking` | 6 | **10 triangles.** One `kit.plane` with `lotmarking_pattern` + a 4-run kerb loft. Down from 11,522 polygons. |

---

### 5.7 Player facilities — 13 assets

These are the buildings the player looks at most. They keep the saturated
Clash-of-Clans-adjacent treatment already proven on
`playerMediumDealer` (639 tris): warm sand walls, teal shingle roof, gold trim,
timber corner posts, awning, bunting, pylon sign.

**Materials:** the set already in
`ArtSource/Blender/build_lowpoly_used_car_shop.py::build_materials()`. Move it
verbatim into `assets/player.py` as `PLAYER_MATERIALS` and reuse.

| Asset | Footprint | Tris | Tex | Height | Recipe |
| --- | --- | --- | --- | --- | --- |
| `playerOffice` | 1×1 | 120 | 256² | 45 | single `parapet_box`, `shopfront` ground, gold band |
| `playerCarWash` | 1×2 | 160 | 256² | 26 | tunnel box + `gable`, 2 blue roller-door bands |
| `playerSmallDealer` | 2×2 | 260 | 256² | 38 | body + `gable`, 1 awning, 2 cars, small pylon |
| `playerDisplayParking` | 2×2 | 260 | 256² | 4 | `lotmarking_pattern` plane + bunting + 4 cars |
| `playerPartsWarehouse` | 2×2 | 260 | 256² | 38 | shed + 2 dock doors, `corrugated_pattern` |
| `playerServiceWorkshop` | 2×3 | 320 | 256² | 41 | 3 bay doors, ramp plane, 2 cars |
| `playerBodyShop` | 2×3 | 320 | 256² | 45 | as workshop + spray-booth box, `Accent_Red` band |
| `playerMediumDealer` | 3×3 | 700 | 512² | 49 | **already built** — port unchanged into the kit |
| `playerVehicleYard` | 3×3 | 700 | 512² | 8 | `lotmarking_pattern` yard, 10 cars, fence run of 12 thin boxes, gate |
| `playerHeadquarters` | 3×3 | 700 | 512² | 128 | `setback_tower`, curtainwall + gold parapet, plaza, flag prisms |
| `playerLargeDealer` | 4×4 | 900 | 512² | 53 | medium dealer scaled up: 2 display pavilions, 12 cars, big roof sign |
| `playerAuctionHouse` | 4×4 | 900 | 512² | 53 | wide hall with a `gable`, entrance canopy, 14 cars in ranked bays |
| `playerLogisticsCenter` | 4×4 | 900 | 512² | 49 | 6-dock shed, 3 trailers, yard markings |

---

## 6. Atlas packing

`pack_atlas.py`, run after all assets are baked. Deterministic, no cleverness.

1. Read `CityKit/exports/<assetId>_basecolor.png` for all assets plus the
   manifest's per-asset texture size.
2. Sort by size descending, then by asset id (stable).
3. Shelf-pack into a 4096×4096 page: fill a row left to right, start a new shelf
   when the row is full. With three sizes that are powers of two this wastes
   almost nothing.
4. Write `CityKit/exports/city_atlas.png` and `city_atlas.json`
   (`{assetId: [u0, v0, w, h]}` in normalised 0–1 coordinates).
5. Rewrite each asset's UVs: `u' = u0 + u × w`, `v' = v0 + v × h`. Apply to the
   `.glb`/`.usdz` exports by re-exporting from Blender after transforming the
   UV layer — do **not** try to patch the binary.
6. Re-run the per-asset preview renders using the atlas to confirm nothing
   shifted.

**Gate 6:** `city_atlas.json` has 46 entries; every rect lies inside 0–1; no two
rects overlap (assert this in the script).

---

## 7. Ground, roads and the 200×200 map

### 7.1 Map size and generator

`SuihamaCityMap.mapSize` becomes `GridMapSize(columns: 200, rows: 200)`.

The current layout is ~500 lines of hand-placed coordinates and cannot be
doubled by hand. Replace `makeRoads`, `makeScenery` and
`makeParcelsAndObjects` with a parametric generator:

```
BLOCK_PITCH = 10 cells        # 1 road cell + 9 usable
```

A 9×9 usable block accepts exactly one 9×9 campus, or two 9×4 slabs, or four
4×4 parcels with a 1-cell rear alley. Every footprint in the catalog fits;
nothing needs a special case.

Generation order:

1. **Water** — bay in the north-east, one river running south-west. Define as
   two analytic half-planes plus a width function so it is deterministic and
   trivially re-tunable.
2. **Expressway** — one horizontal at row 178, one vertical at column 22.
3. **Arterials** — every 4th block line (i.e. every 40 cells), class `.arterial`.
4. **Locals** — every `BLOCK_PITCH`, class `.local`, skipped where water.
5. **Districts** — a list of `DistrictBlock(rect, kind)` covering the land in
   whole blocks. Target mix over ~360 land blocks: downtown 8 %, station 14 %,
   suburb 34 %, emerging 12 %, industrial 16 %, highway 10 %, parks/plaza 6 %.
6. **Parcels** — for each block, pick a subdivision by district:
   * downtown → one 9×4 campus + one 9×4, or four 4×4
   * industrial → one 9×9 campus
   * everything else → four 4×4
7. **Assets** — `CityAssetCatalog.ambientAssets(for: district)` chosen by
   `hash(column, row)`, with height jittered ±15 % so identical types differ.

Expected result: **≈ 1,150 ambient buildings** on a solid map. At an 800-triangle
average that is ~920 k triangles total, of which 100–400 are ever in frustum.

### 7.2 Ground rendering

`buildTerrainGround()`'s run-length strip merge already scales; keep it. Two
changes:

* Retune `CityGroundArt` colours to the `citykit.PALETTE` values so the ground
  and the buildings belong to one palette. Today's green is the most saturated
  thing on screen and fights every building.
* Add a second, much lower-frequency tonal layer to `grassTexture()` and
  `plazaTexture()` — currently they tile visibly at 20 units. A 4-cell-period
  variation breaks the grid.

### 7.3 Chunking

New in `GridCitySceneView`:

* Chunk the map into **20×20-cell tiles** → 100 chunks of 400×400 world units.
* Ambient buildings are added to their chunk's container, then
  `container.flattenedClone()` is added to the scene. With one atlas material
  this is **one draw call per chunk**.
* Player facilities, runtime stores, vacant markers and selection affordances
  stay as individual nodes — they change at runtime and must stay addressable.
* Toggle `chunkNode.isHidden` against the camera frustum on zoom/pan. At the
  baseline zoom expect 9–25 visible chunks.

### 7.4 Hit testing

With ambient buildings flattened, per-parcel nodes can no longer carry
identity — and 1,150 individual parcel quads would be 1,150 draw calls anyway.

Replace SceneKit hit-testing for parcel selection with arithmetic: unproject the
tap to a ray, intersect the plane `y = GridSceneElevation.parcelSurface`, convert
world x/z to a `GridCoordinate` via `GridCityMetrics`, and look the parcel up.
O(1), exact for a flat grid, and it deletes `buildParcelNodes()` entirely.

Keep SceneKit hit-testing only for player facilities and stores, which remain
real nodes.

### 7.5 Runtime material

One `SCNMaterial` for all ambient buildings:

```swift
material.diffuse.contents = <city_atlas.png>
material.diffuse.wrapS = .clamp        // atlas regions must not bleed
material.diffuse.wrapT = .clamp
material.diffuse.mipFilter = .linear
material.lightingModel = .lambert       // baked AO carries the detail
material.isDoubleSided = false
```

`.lambert`, not `.physicallyBased`: the texture already contains the painted
shading, and PBR would add a specular response the art direction does not want.

Retune `buildLighting()` to match the Blender preview rig, otherwise the baked
art will look wrong in situ: ambient **380** (cool `#C6DEF5`), directional
**1,250** warm `#FFE7B8` from the screen-upper-left of the isometric, fill
**240** from behind. Compare against
`ArtSource/Blender/LowPolyCityKit/previews/lowpoly_district.png`.

---

## 8. Work order and gates

Do not reorder. Each gate must pass before the next step.

| # | Step | Gate |
| --- | --- | --- |
| ~~1~~ | ~~Extend `citykit.py`: non-square `validate()`, palette, `gable`/`parapet_box`/`setback_tower`~~ | **DONE** — shop still builds at 639 tris |
| ~~2~~ | ~~Patterns 3.1–3.6 plus the test card~~ | **DONE** — see `pattern_testcard.png` |
| 3 | `build_city_kit.py` skeleton + `assets/player.py` with `playerMediumDealer` ported | `--only playerMediumDealer` reproduces today's 639-tri result |
| 4 | Remaining 12 player facilities | All pass `validate()`; contact sheet rendered |
| 5 | Residential (5) + luxury (4) | Contact sheet; no asset over budget |
| 6 | Commercial (7) + highway/parking (4) | `surfaceParking` ≤ 10 triangles |
| 7 | Industrial (5) + downtown (8) | Contact sheet; towers read against sky |
| 8 | `pack_atlas.py` | 46 rects, none overlapping, all inside 0–1 |
| 9 | Swift: atlas material + `.lambert` + light retune, existing 100×100 map | App builds; screenshot matches the Blender district preview |
| 10 | Swift: chunking + arithmetic hit testing | Selection still works; frame time measured on device |
| 11 | Swift: 200×200 parametric map generator | ~1,150 buildings; profile on device |
| 12 | Tune density mix and heights from the device profile | Sustained 60 fps at baseline zoom |

**Step 9 is the first point where anything is visible on a phone.** If the
device profile at step 10 is bad, stop and re-measure before authoring the
200×200 map — do not build the big map on an unproven runtime.

---

## 9. Deferred, with the mechanism recorded

* **Per-instance colourways.** Bake N wall/roof colourways per repeated ambient
  asset into adjacent atlas regions; build N `SCNGeometry` objects sharing one
  vertex buffer and differing only in their UV source; pick by
  `hash(column,row) % N` at placement. Costs `N ×` the atlas area for those
  assets; the 4096² page has 19 % slack, enough for two extra colourways on the
  five most-repeated residential types.
* **Normal maps** for player facilities only, if a close-up inspection view is
  added.
* **ASTC compression** of the atlas via the asset catalog. A 4096² RGBA8 page is
  64 MB resident; ASTC 6×6 is ~5.6 MB. Not needed for one page, required before
  a second.
* **Night lighting.** `facade_pattern`'s lit-window hash is already a mask; bake
  it to the emissive map and drive its strength from game time.

---

## 10. Definition of done

* 46 assets, all inside their triangle and footprint budgets, total ≈ 40 k
  triangles for the library.
* One 4096² atlas, one `SCNMaterial` for every ambient building.
* 200×200 map, ~1,150 buildings, no empty ground inside the coastline.
* Sustained 60 fps at baseline zoom on the oldest supported device.
* The runtime screenshot is indistinguishable from
  `ArtSource/Blender/CityKit/previews/district_contact.png`.
