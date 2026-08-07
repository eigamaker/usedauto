# Rebuilding the city: 200×200, solid with buildings

Plan for doubling the map in each dimension, filling it with buildings, and
raising the visual bar — without a 20-million-triangle scene.

> **The executable version of this is
> [`CITY-REBUILD-SPEC.md`](CITY-REBUILD-SPEC.md).** Read this document for the
> reasoning; work from that one. The shared library and the whole texture
> pattern set are already built — see
> `ArtSource/Blender/LowPolyCityKit/previews/pattern_testcard.png`.

## 1. Why the current city looks cheap

It is not the renderer. It is that **the buildings have no textures at all**.

| | today |
| --- | --- |
| Ground | procedurally drawn textures (`CityGroundArt.swift`) — grass, park, sand, plaza |
| Buildings | flat per-material colours on procedural boxes, no texture, no baked light |

That mismatch is the whole effect. The ground reads as a painted surface and
the buildings read as untextured primitives sitting on it. Every reference
that looks good — Coffee Inc 2 included — is carrying its detail in the
texture, not in the mesh.

The second problem is cost. The authored library is 46 assets averaging
**5,555 polygons** each (max 15,336), 23 MB of USDZ, and it only covers a
fraction of a 100×100 map.

## 2. What a 200×200 solid map actually costs

* 200 × 200 cells = 40,000 cells (4× today's 100×100).
* After roads, water and parks, roughly 3,000–4,000 building instances.

| tris per asset | total scene | verdict |
| --- | --- | --- |
| 5,555 (today) | ~20,000,000 | impossible |
| 639 (this branch's probe) | ~2,400,000 | fine — and only 100–400 instances are ever on screen |

At the locked isometric zoom the visible set is roughly 150–400 lots, so the
real per-frame load lands around **100–250k triangles**. That is comfortable
on any iPhone that can run the app today.

In SceneKit the harder limit is draw calls, not triangles. That is what the
single shared atlas below is for.

## 3. Unity?

**Recommendation: stay on SceneKit.**

* Unity does not fix the look. Untextured flat boxes render exactly as badly
  in Unity. The fix is the asset pipeline, and that pipeline (Blender →
  low-poly + baked atlas → glTF/USDZ) is engine-agnostic — everything on this
  branch works for either engine.
* SceneKit already has what this needs, and the code already uses some of it:
  geometry sharing via `clone()`, static batching via `flattenedClone()`
  (`GridCitySceneView.swift:970`), and a zoom-driven LOD gate
  (`CityAssetLODPolicy`).
* A port means rewriting ~7,000 lines of Swift game logic plus every SwiftUI
  screen, for the same pixels.

**The one honest argument for Unity** is the Asset Store: if the intention is
to *buy* a stylized city pack rather than author one, Unity is where those
packs live and it would save months of art time. That is a business decision
about art sourcing, not a rendering one. If we author the art ourselves,
SceneKit wins.

## 4. The rule that makes it work

> **Geometry carries silhouette. Texture carries everything else.**

Proven on this branch with the used car shop:

| | concept (rejected) | low-poly kit |
| --- | --- | --- |
| Triangles | 44,168 | **639** |
| Export size | 7.4 MB | **0.75 MB** |
| Roof tile courses | 8 modelled lofted rings | wave pattern in the baked normal map |
| Window frames / mullions | modelled boxes | painted into the wall texture |
| Rounded edges | bevel modifiers | Bevel shader node, baked to normal map |
| Trim, grain, AO | geometry + shading | baked into the 512px base colour |

See `previews/budget_comparison.png` in
[`../ArtSource/Blender/LowPolyCityKit/`](../ArtSource/Blender/LowPolyCityKit/README.md).
At map zoom the two are indistinguishable; the low-poly one is 1/69th the cost.

## 5. Phases

### Phase 1 — asset kit (probe complete, needs scaling)

* `ArtSource/Blender/citykit.py` — shared palette, procedural stylized
  materials, cheap geometry helpers, contract validation, atlas bake, export.
* Every asset validated against **footprint + triangle budget** at build time,
  so nothing over budget can be committed by accident.
* Budget ladder: 1×1 ≤ 250 tris, 2×2 ≤ 450, 3×3 ≤ 800, 4×4 ≤ 1,200.
* Scale to ~35 asset types, all baked into **one shared 4096² atlas** so the
  whole city is a single material. 40 assets at 512px each fit with room over.

### Phase 2 — ground and roads become one system

Buildings no longer carry a terrain tile of their own. On a dense map a
per-asset grass tile produces a checkerboard, puts a step between every lot and
the road, and wastes ~30 triangles each. Instead:

* the city ground is a chunked textured mesh with roads, sidewalks and verges
  in the texture;
* assets sit on it at `z = 0` and only own their lot paving.

This change is already made in the probe asset.

### Phase 3 — the 200×200 map

* Rewrite the generator in `SuihamaCityMap.swift` so districts fill their
  blocks solid rather than scattering a handful of parcels.
* Keep the cell size at 20 units and the existing grid contract, so gameplay,
  hit testing and placement are untouched.
* Chunk the map into 20×20-cell tiles.

### Phase 4 — runtime

* One atlas material for all buildings.
* One `SCNGeometry` per asset type, shared across every instance.
* Per-chunk `flattenedClone()` static batching; show/hide chunks against the
  camera frustum.
* Keep the existing `CityAssetLODPolicy` zoom gates for props.
* Measure on device and adjust the budget ladder from real numbers.

## 6. Targets

| | now | target |
| --- | --- | --- |
| Map | 100×100, sparsely built | 200×200, solid |
| Avg triangles per asset | 5,555 | ≤ 800 |
| Building textures | none | one shared 4096² atlas |
| Distinct building materials | 46 assets × several each | 1 |
| Runtime art payload | 23 MB USDZ | ~2 MB atlas + small meshes |

## 7. Not yet proven

* **No on-device measurement.** All numbers here are geometry maths plus
  desktop renders; the work was done on Windows and cannot build the iOS app.
  Phase 4 has to start with a real profile on hardware.
* The 3,000–4,000 instance estimate assumes a district mix similar to today's.
* Whether SceneKit batches well enough at that instance count is the main
  remaining risk. Chunked `flattenedClone()` is the mitigation, and it needs
  measuring before the full map is authored.
