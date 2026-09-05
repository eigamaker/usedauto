# Used Car City — Visual Direction

The runtime city is a sunny, miniature coastal town, with the legible silhouettes
and tactile architecture of a casual city-building game. The map uses 46 authored
Blender assets, exported as SceneKit USDZ geometry; no building is a billboard.

## Projection and placement

- One grid cell is `20 × 20` world units.
- The orthographic camera is fixed at `45°` azimuth and `35.26439°` elevation.
- Asset origins are at the footprint centre, on the ground.
- Plinths match the exact catalog footprint; quarter turns preserve grid placement.
- Zoom changes camera scale only. Gameplay parcels and saves are unchanged.

## Architecture

- Homes have overlapping hip-roof courses, thick eaves, masonry bases,
  projecting porch gables, chimneys, separate framed windows and garden walls.
- Shops have deep glazing, striped awnings, raised signs, terraces and roof equipment.
- Dealers use cobalt-blue fascia, cream masonry, orange accents and marked car bays.
- Garages have recessed ribbed shutters and bollards; the car wash has an open tunnel.
- Towers keep a constant floor plate and parallel vertical edges, with low street
  podiums, curtain-wall piers or residential balconies, flat roofs and small
  mechanical rooms. Industrial halls have standing-seam roofs and loading docks.
- Grass, hedges, stone planters and flowers soften the edges of developed lots.

## Rendering

- Warm directional sun, cool ambient and opposite fill preserve shaded wall colour.
- Two 2048-pixel shadow cascades cover the actual camera distance; ambient
  occlusion adds contact at roof courses, window reveals and building bases.
- Essential windows and architectural silhouettes stay in the main LOD. Fine
  reflections, lettering, equipment, vehicles and flowers have separate detail layers.
- USDZ scenes are loaded once per asset type and cloned with shared geometry.
- Street furniture is batched by material, including raised curbs and streetlights.
- Runtime ground textures use normal alpha compositing and restrained grain so
  translucent texture detail never creates dark holes in grass or asphalt.
- Silhouette-shaped, cached contact shadows keep buildings grounded across devices.

## Source and previews

`ArtSource/Blender/build_city_asset_library.py` is the editable, deterministic
source for all 46 assets. Rebuilding produces the `.blend`, runtime `.usdz`
files, footprint manifest, and category contact sheets. See the
[asset library README](../ArtSource/Blender/CityAssetLibrary/README.md).

[`used-car-city-visual-target.png`](used-car-city-visual-target.png) remains the
original art-direction reference. Runtime screenshots document the implemented
appearance, rather than a concept rendering.
