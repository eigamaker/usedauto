# Runtime rollout — what is converted, and where to look on device

The low-poly kit is **partially** wired into the app so the old and new art can
be compared side by side in the same running map. Nothing else changed: same
100×100 map, same camera, same lighting rig.

## Converted (8 of 46)

| `CityAssetID` | Footprint | Triangles | Where it appears |
| --- | --- | --- | --- |
| `playerMediumDealer` | 3×3 | 538 | your own standard store |
| `playerLargeDealer` | 4×4 | 682 | your own roadside store |
| `downtownOffice` | 4×4 | 134 | downtown district |
| `downtownApartment` | 4×4 | 96 | downtown district |
| `commercialShopping` | 4×4 | 126 | station district |
| `residentialApartment` | 4×4 | 86 | suburb district |
| `residentialGable` | 4×4 | 126 | suburb district |
| `industrialWarehouse` | 9×4 | 106 | industrial district |

Everything else is still the original untextured library (avg 5,555 polygons,
no texture), so the difference should be obvious as you pan across a district.

Sources: `ArtSource/Blender/build_city_blocks.py`,
`build_lowpoly_car_dealer.py`. Both write to
`ArtSource/Blender/LowPolyCityKit/exports/`; the `.usdz` files were then copied
into `UsedCarCity/Art.scnassets/CityBuildings/`.

## Why no Xcode project change was needed

`Art.scnassets` is a single `wrapper.scnassets` resource reference in
`project.pbxproj`, so every file inside it ships automatically.
`CityBuildingFactory.loadAuthoredAsset` already prefers
`Art.scnassets/CityBuildings/<CityAssetID>.usdz` over the procedural fallback,
so naming the exports after their catalog id is the whole integration.

## Swift changes

1. **`CityBuildingAssets.swift` — `configureAuthored(_:)`.** Kit materials get
   `.lambert` plus clamped, mip-filtered sampling; the original library keeps
   `.physicallyBased`. The baked map already contains the painted shading and
   ambient occlusion, and physically based lighting adds a specular response
   that washes it out. A kit material is recognised by having an image in its
   diffuse slot — the original library has none.
2. **`CityBuildingFactory.lowPolyKitMarkerName`.** Assets that used a kit
   material get a `lowpoly-kit` marker child, so the rest of the app can tell
   the two generations apart while the rollout is partial.
3. **`GridCitySceneView` — lot infill suppressed for kit assets.** The legacy
   infill plate sits at `y = 0.14`, above the kit's own textured verge at
   `0.04`, so leaving it in would hide the new artwork behind a flat slab. Kit
   assets carry the same interaction metadata, so selection is unaffected.
4. **`GridMapTests`.** Two tests encoded the *old* contract — "must not be one
   colored box", "> 250 primitives". That is the exact opposite of the kit's
   rule, so they now branch on the marker: kit assets are asserted against
   their triangle budget and the presence of a baked texture instead.

## Not done

* **No lighting retune.** The spec calls for ambient 380 / directional 1250 /
  fill 240 to match the Blender preview rig, but changing it would move the
  unconverted assets too and muddy the comparison. Do it once the rollout is
  complete.
* **No shared atlas.** Each asset still carries its own 512 px (768 px for
  9×4) map, so there are eight extra materials rather than one. Fine at this
  count; section 6 of the spec covers the atlas.
* **No chunking.** Still one node per object.
* **Dealer height.** The new dealers are ~22 units tall against the ~52 the
  catalog's height multiplier implies for that slot. A dealership *is* a low
  building, but next to the exaggerated neighbours it may read as too short.

## Unverified

**None of this has been built or run.** The work was done on Windows, which
cannot build the iOS target, so the Swift edits are unchecked by a compiler and
the USDZ files are unproven against SceneKit's loader.

What *was* checked: every `.usdz` is a spec-valid container — stored (not
deflated) entries with 64-byte-aligned data — matching the byte layout of the
existing assets that already load on device.

First run should confirm, in order:

1. the target compiles;
2. `testEveryCatalogEntryLoadsItsAuthoredUSDZResource` still passes — a failure
   there means SceneKit rejected a new `.usdz` and the asset silently fell back
   to procedural geometry;
3. the eight converted assets look textured on device, not flat.
