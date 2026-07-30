# Used Car Dealer 4x4 Concepts

Three editable Blender concepts authored for the existing city-grid contract.

## Grid contract

- Footprint: `4 x 4` cells
- World footprint: `80 x 80` units
- Origin: centre of the footprint at ground level
- Front / public road edge: Blender `-Y`
- Root objects carry matching custom properties

## Concepts and scenes

- `Scene_A_Modern_Flagship`: two-storey curtain-wall showroom and covered display pavilion
- `Scene_B_Suburban_Market`: low gabled showroom, freestanding pylon, landscaping, and open display canopy
- `Scene_C_Service_Hub`: showroom/office plus three recessed workshop bays and service-yard props
- `Scene_Showcase`: comparison layout containing all three concepts

Each design is held in its own collection and remains centred at the origin in
its individual scene.

## Visual scale policy

These assets intentionally use symbolic game scale rather than strict real-world
scale. Buildings occupy most of the rear half of the lot, their height is
exaggerated for an orthographic camera, vehicles are approximately `1.65x`
physical scale, and display stalls are kept full. Clear vehicle circulation is
not reserved because these are city-map symbols rather than driving spaces.

## Files

- `used_car_dealers_4x4.blend`: editable Blender source
- `previews/`: individual and comparison renders
- `exports/`: GLB and USDZ exports for each concept
- `../build_used_car_dealers.py`: deterministic source generator

The models are concept-quality assets and have not yet been connected to the
iOS runtime. Before runtime integration, choose a direction and create game LOD
variants, collision meshes, shared material atlases, and final node naming.
