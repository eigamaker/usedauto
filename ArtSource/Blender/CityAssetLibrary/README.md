# UsedCarCity Blender Asset Library

This library contains the 46 authored city assets used by the SceneKit map.

## Files

- `used_car_city_asset_library.blend` — editable Blender source with one
  collection per `CityAssetID` and category preview scenes.
- `previews/` — rendered isometric contact sheets for visual review.
- `city_asset_manifest.json` — footprint, height, polygon, node, and runtime
  path validation results.
- `../../../UsedCarCity/Art.scnassets/CityBuildings/*.usdz` — material-merged
  runtime exports copied into the iOS app bundle.

## Art and scale contract

- One grid cell is 20 world units.
- The origin is the footprint centre at ground level.
- Negative Y in Blender is the public/front edge. It becomes positive Z in
  SceneKit and corresponds to the catalog's south-facing default.
- Every asset has an exact-size plinth.
- Buildings and vehicles intentionally use symbolic game scale. Architecture
  occupies most of its parcel and cars are oversized for isometric readability.
- Main silhouettes and window openings stay visible at every zoom. Reflections,
  letters, roof equipment and vehicle/landscape props use separate LOD layers.
- Tower floor plates remain constant above a low street podium. Flat parapets
  and compact roof plant replace the old repeated stepped tiers.
- Roof tile courses are separate non-coplanar meshes; shop awnings, porch
  gables, ribbed garage shutters and open wash portals identify the buildings.

## Rebuild

From the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup \
  --python ArtSource/Blender/build_city_asset_library.py
```

The build evaluates modifiers directly, batches meshes by material and LOD,
and validates ground and footprint bounds before producing the `.blend`,
previews, manifest, and runtime USDZ files. Finished assets are removed from the
work scene to keep subsequent builds independent of the library's size.

The actual app appearance is recorded in `ArtDirection/runtime-preview.png`
and `ArtDirection/runtime-neighborhood.png` at the project root. The Blender
contact sheets are model previews with their own studio lighting.
