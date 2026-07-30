"""Build the complete authored city-building library for UsedCarCity.

The library follows the runtime grid contract:

* 1 cell = 20 Blender/world units.
* Origins are at the footprint centre on the ground plane.
* The public/front edge is negative Y in Blender (positive Z in SceneKit).
* Every asset has an exact-size plinth.
* Detailed source geometry is merged by material and LOD layer before export.

Run with:
    blender --background --factory-startup --python build_city_asset_library.py
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent.parent
SOURCE_DIR = SCRIPT_DIR / "CityAssetLibrary"
PREVIEW_DIR = SOURCE_DIR / "previews"
RUNTIME_DIR = PROJECT_DIR / "UsedCarCity" / "Art.scnassets" / "CityBuildings"
BLEND_PATH = SOURCE_DIR / "used_car_city_asset_library.blend"
MANIFEST_PATH = SOURCE_DIR / "city_asset_manifest.json"

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
import build_used_car_dealers as dealer  # noqa: E402


@dataclass(frozen=True)
class AssetSpec:
    asset_id: str
    category: str
    cells_w: int
    cells_d: int
    nominal_height: float
    variant: int = 0

    @property
    def width(self) -> float:
        return self.cells_w * 20.0

    @property
    def depth(self) -> float:
        return self.cells_d * 20.0


ASSETS = [
    AssetSpec("residentialCottage", "generalResidential", 4, 4, 7, 0),
    AssetSpec("residentialGable", "generalResidential", 4, 4, 8, 1),
    AssetSpec("residentialFlat", "generalResidential", 4, 4, 7, 2),
    AssetSpec("residentialTwin", "generalResidential", 4, 4, 8, 3),
    AssetSpec("residentialApartment", "generalResidential", 4, 4, 13, 4),
    AssetSpec("luxuryCourtyard", "luxuryResidential", 4, 4, 8, 0),
    AssetSpec("luxuryGarage", "luxuryResidential", 4, 4, 9, 1),
    AssetSpec("luxuryPool", "luxuryResidential", 4, 4, 8, 2),
    AssetSpec("luxuryTerrace", "luxuryResidential", 4, 4, 10, 3),
    AssetSpec("commercialAutoDealer", "commercial", 4, 4, 10, 0),
    AssetSpec("commercialGasStation", "commercial", 4, 4, 7, 1),
    AssetSpec("commercialConvenience", "commercial", 4, 4, 7, 2),
    AssetSpec("commercialRestaurant", "commercial", 4, 4, 8, 3),
    AssetSpec("commercialShopping", "commercial", 4, 4, 12, 4),
    AssetSpec("commercialRoadside", "commercial", 4, 4, 9, 5),
    AssetSpec("commercialRegionalMall", "commercial", 9, 9, 17, 6),
    AssetSpec("industrialFactory", "industrial", 9, 9, 13, 0),
    AssetSpec("industrialWarehouse", "industrial", 9, 4, 12, 1),
    AssetSpec("industrialLoadingWarehouse", "industrial", 9, 4, 11, 2),
    AssetSpec("industrialTankWorks", "industrial", 9, 9, 12, 3),
    AssetSpec("industrialSmokestack", "industrial", 9, 9, 18, 4),
    AssetSpec("downtownMixedUse", "downtown", 4, 4, 28, 0),
    AssetSpec("downtownOffice", "downtown", 4, 4, 34, 1),
    AssetSpec("downtownApartment", "downtown", 4, 4, 30, 2),
    AssetSpec("downtownParkingStructure", "downtown", 4, 4, 18, 3),
    AssetSpec("downtownCornerBlock", "downtown", 4, 4, 36, 4),
    AssetSpec("downtownOfficePlaza", "downtown", 9, 4, 44, 5),
    AssetSpec("downtownTwinTower", "downtown", 9, 4, 50, 6),
    AssetSpec("downtownResidentialTower", "downtown", 9, 4, 40, 7),
    AssetSpec("highwayLogistics", "highway", 4, 4, 12, 0),
    AssetSpec("highwayBigBox", "highway", 4, 4, 11, 1),
    AssetSpec("highwayMotorHotel", "highway", 4, 4, 15, 2),
    AssetSpec("surfaceParking", "parking", 4, 4, 1, 0),
    AssetSpec("playerSmallDealer", "playerFacility", 2, 2, 10, 0),
    AssetSpec("playerMediumDealer", "playerFacility", 3, 3, 13, 1),
    AssetSpec("playerLargeDealer", "playerFacility", 4, 4, 14, 2),
    AssetSpec("playerDisplayParking", "playerFacility", 2, 2, 1, 3),
    AssetSpec("playerServiceWorkshop", "playerFacility", 2, 3, 11, 4),
    AssetSpec("playerBodyShop", "playerFacility", 2, 3, 12, 5),
    AssetSpec("playerCarWash", "playerFacility", 1, 2, 7, 6),
    AssetSpec("playerVehicleYard", "playerFacility", 3, 3, 2, 7),
    AssetSpec("playerOffice", "playerFacility", 1, 1, 12, 8),
    AssetSpec("playerPartsWarehouse", "playerFacility", 2, 2, 10, 9),
    AssetSpec("playerAuctionHouse", "playerFacility", 4, 4, 14, 10),
    AssetSpec("playerLogisticsCenter", "playerFacility", 4, 4, 13, 11),
    AssetSpec("playerHeadquarters", "playerFacility", 3, 3, 34, 12),
]


def add_library_materials() -> None:
    dealer.material("Facade_White", (0.93, 0.92, 0.87, 1), roughness=0.56)
    dealer.material("Facade_Sand", (0.76, 0.63, 0.46, 1), roughness=0.70)
    dealer.material("Facade_Brick", (0.48, 0.13, 0.075, 1), roughness=0.76)
    dealer.material("Facade_Sage", (0.39, 0.51, 0.31, 1), roughness=0.70)
    dealer.material("Facade_Teal", (0.025, 0.36, 0.42, 1), roughness=0.42)
    dealer.material("Glass_Dark", (0.018, 0.075, 0.115, 1), roughness=0.12, metallic=0.28)
    dealer.material("Glass_Cyan", (0.055, 0.38, 0.50, 1), roughness=0.13, metallic=0.22)
    dealer.material("Glass_Gold", (0.38, 0.25, 0.10, 1), roughness=0.18, metallic=0.20)
    dealer.material("Roof_Copper", (0.08, 0.36, 0.33, 1), roughness=0.42, metallic=0.35)
    dealer.material("Roof_Orange", (0.79, 0.22, 0.035, 1), roughness=0.56)
    dealer.material("Roof_Charcoal", (0.055, 0.065, 0.075, 1), roughness=0.48, metallic=0.10)
    dealer.material("Industrial_Blue", (0.16, 0.34, 0.46, 1), roughness=0.48, metallic=0.20)
    dealer.material("Industrial_Green", (0.21, 0.34, 0.25, 1), roughness=0.56, metallic=0.14)
    dealer.material("Concrete_Dark", (0.25, 0.27, 0.27, 1), roughness=0.82)
    dealer.material("Concrete_Mid", (0.54, 0.55, 0.52, 1), roughness=0.80)
    dealer.material("Pool_Tile", (0.015, 0.43, 0.61, 1), roughness=0.18, metallic=0.08)
    dealer.material("Wood", (0.35, 0.15, 0.055, 1), roughness=0.68)
    dealer.material("Awning_Red", (0.72, 0.035, 0.025, 1), roughness=0.48)
    dealer.material("Purple", (0.31, 0.10, 0.46, 1), roughness=0.44)


def mark_new(collection: bpy.types.Collection, existing: set[str], layer: str) -> None:
    for obj in collection.all_objects:
        if obj.name not in existing:
            obj["lod_layer"] = layer


class Builder:
    def __init__(self, spec: AssetSpec):
        self.spec = spec
        self.collection = bpy.data.collections.new(f"Asset_{spec.asset_id}")
        self.root = dealer.empty(f"ROOT_{spec.asset_id}", self.collection)
        self.root["city_asset_id"] = spec.asset_id
        self.root["footprint_cells"] = f"{spec.cells_w}x{spec.cells_d}"
        self.root["front_edge"] = "negative_y"

    @property
    def width(self) -> float:
        return self.spec.width

    @property
    def depth(self) -> float:
        return self.spec.depth

    def box(
        self,
        name: str,
        dimensions: tuple[float, float, float],
        location: tuple[float, float, float],
        material: str,
        *,
        bevel: float = 0.0,
        rotation: tuple[float, float, float] = (0, 0, 0),
        layer: str = "main",
        parent: bpy.types.Object | None = None,
    ) -> bpy.types.Object:
        obj = dealer.box(
            name,
            self.collection,
            dimensions,
            location,
            dealer.MATERIALS[material],
            bevel=bevel,
            rotation=rotation,
            parent=parent or self.root,
        )
        obj["lod_layer"] = layer
        return obj

    def cylinder(
        self,
        name: str,
        radius: float,
        depth: float,
        location: tuple[float, float, float],
        material: str,
        *,
        vertices: int = 16,
        rotation: tuple[float, float, float] = (0, 0, 0),
        layer: str = "main",
    ) -> bpy.types.Object:
        obj = dealer.cylinder(
            name,
            self.collection,
            radius,
            depth,
            location,
            dealer.MATERIALS[material],
            vertices=vertices,
            rotation=rotation,
            parent=self.root,
        )
        obj["lod_layer"] = layer
        return obj

    def lot(self, surface: str, *, accent: str | None = None) -> None:
        self.box(
            "footprint-edge",
            (self.width, self.depth, 0.34),
            (0, 0, 0.17),
            "Concrete_Edge",
            bevel=min(0.48, min(self.width, self.depth) * 0.01),
        )
        self.box(
            "footprint-surface",
            (self.width - 0.8, self.depth - 0.8, 0.16),
            (0, 0, 0.42),
            surface,
            bevel=0.28,
        )
        if accent:
            inset_x = self.width / 2 - 0.65
            inset_y = self.depth / 2 - 0.65
            self.box("lot-accent-front", (self.width - 1.2, 0.45, 0.22), (0, -inset_y, 0.62), accent, bevel=0.08, layer="near")
            self.box("lot-accent-back", (self.width - 1.2, 0.45, 0.22), (0, inset_y, 0.62), accent, bevel=0.08, layer="near")
            self.box("lot-accent-left", (0.45, self.depth - 1.2, 0.22), (-inset_x, 0, 0.62), accent, bevel=0.08, layer="near")
            self.box("lot-accent-right", (0.45, self.depth - 1.2, 0.22), (inset_x, 0, 0.62), accent, bevel=0.08, layer="near")

    def car(
        self,
        name: str,
        x: float,
        y: float,
        index: int,
        *,
        rotation: float = math.radians(90),
        scale: float = 1.58,
        suv: bool = False,
    ) -> None:
        existing = {obj.name for obj in self.collection.all_objects}
        dealer.make_car(
            self.collection,
            self.root,
            name,
            (x, y, 0.68),
            dealer.CAR_COLORS[index % len(dealer.CAR_COLORS)],
            rotation_z=rotation,
            scale=scale,
            suv=suv,
        )
        mark_new(self.collection, existing, "props")

    def tree(self, name: str, x: float, y: float, scale: float = 1.0) -> None:
        existing = {obj.name for obj in self.collection.all_objects}
        dealer.make_tree(self.collection, self.root, name, x, y, scale=scale)
        mark_new(self.collection, existing, "props")

    def rooftop(self, name: str, x: float, y: float, z: float, scale: float = 1.0) -> None:
        existing = {obj.name for obj in self.collection.all_objects}
        dealer.make_rooftop_hvac(self.collection, self.root, name, (x, y, z), scale=scale)
        mark_new(self.collection, existing, "near")

    def gable(
        self,
        name: str,
        x: float,
        y: float,
        width: float,
        depth: float,
        base_z: float,
        rise: float,
        material: str,
    ) -> None:
        obj = dealer.gable_roof(
            name,
            self.collection,
            width,
            depth,
            rise,
            (x, y, base_z),
            dealer.MATERIALS[material],
            parent=self.root,
        )
        obj["lod_layer"] = "main"

    def hip(
        self,
        name: str,
        x: float,
        y: float,
        width: float,
        depth: float,
        base_z: float,
        rise: float,
        material: str,
    ) -> None:
        half_w = width / 2
        half_d = depth / 2
        ridge = min(width * 0.24, max(0.1, half_w - depth * 0.32))
        vertices = [
            (-half_w, -half_d, 0),
            (half_w, -half_d, 0),
            (half_w, half_d, 0),
            (-half_w, half_d, 0),
            (-ridge, 0, rise),
            (ridge, 0, rise),
        ]
        faces = [
            (0, 1, 5, 4),
            (1, 2, 5),
            (2, 3, 4, 5),
            (3, 0, 4),
            (0, 3, 2, 1),
        ]
        mesh = bpy.data.meshes.new(f"{name}_Mesh")
        mesh.from_pydata(vertices, [], faces)
        mesh.materials.append(dealer.MATERIALS[material])
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        obj.location = (x, y, base_z)
        obj.parent = self.root
        obj["lod_layer"] = "main"
        self.collection.objects.link(obj)
        bevel = obj.modifiers.new("Roof_Edge_Bevel", "BEVEL")
        bevel.width = 0.16
        bevel.segments = 2

    def windows(
        self,
        name: str,
        x: float,
        y: float,
        width: float,
        depth: float,
        height: float,
        *,
        base_z: float = 0.50,
        floors: int = 3,
        glass: str = "Glass_Dark",
        frame: str = "Charcoal",
        all_sides: bool = True,
    ) -> None:
        floor_height = height / max(1, floors)
        band_h = max(1.0, min(floor_height * 0.42, 3.1))
        for floor in range(floors):
            z = base_z + floor_height * (floor + 0.58)
            self.box(
                f"{name}-front-glass-{floor}",
                (width * 0.82, 0.24, band_h),
                (x, y - depth / 2 - 0.08, z),
                glass,
                bevel=0.04,
                layer="near",
            )
            self.box(
                f"{name}-back-glass-{floor}",
                (width * 0.82, 0.24, band_h),
                (x, y + depth / 2 + 0.08, z),
                glass,
                bevel=0.04,
                layer="near",
            )
            if all_sides:
                self.box(
                    f"{name}-left-glass-{floor}",
                    (0.24, depth * 0.74, band_h),
                    (x - width / 2 - 0.08, y, z),
                    glass,
                    bevel=0.04,
                    layer="near",
                )
                self.box(
                    f"{name}-right-glass-{floor}",
                    (0.24, depth * 0.74, band_h),
                    (x + width / 2 + 0.08, y, z),
                    glass,
                    bevel=0.04,
                    layer="near",
                )
        for side in (-1, 1):
            self.box(
                f"{name}-front-frame-{side}",
                (0.42, 0.42, height * 0.92),
                (x + side * width * 0.43, y - depth / 2 - 0.14, base_z + height * 0.50),
                frame,
                bevel=0.04,
                layer="near",
            )

    def mass(
        self,
        name: str,
        x: float,
        y: float,
        width: float,
        depth: float,
        height: float,
        *,
        wall: str = "Facade_White",
        glass: str = "Glass_Dark",
        floors: int | None = None,
        cap: str = "Charcoal",
        windowed: bool = True,
    ) -> None:
        base_z = 0.50
        self.box(name, (width, depth, height), (x, y, base_z + height / 2), wall, bevel=0.34)
        self.box(f"{name}-cap", (width + 0.55, depth + 0.55, 0.65), (x, y, base_z + height + 0.30), cap, bevel=0.12)
        if windowed:
            self.windows(
                f"{name}-facade",
                x,
                y,
                width,
                depth,
                height,
                base_z=base_z,
                floors=floors or max(1, round(height / 8)),
                glass=glass,
                frame=cap,
            )

    def entrance(self, name: str, x: float, y: float, width: float, height: float, accent: str) -> None:
        self.box(name, (width, 0.38, height), (x, y, 0.50 + height / 2), "Glass_Cyan", bevel=0.08, layer="near")
        self.box(f"{name}-canopy", (width + 2.2, 4.0, 0.55), (x, y - 1.55, 0.50 + height + 0.30), accent, bevel=0.12, layer="near")
        for side in (-1, 1):
            self.box(f"{name}-post-{side}", (0.34, 0.34, height + 0.4), (x + side * (width / 2 + 0.35), y - 0.3, 0.50 + height / 2), accent, bevel=0.05, layer="near")

    def parking_row(self, name: str, count: int, y: float, span: float, *, start: int = 0, rotation: float = math.radians(90), scale: float = 1.55) -> None:
        if count == 1:
            xs = [0.0]
        else:
            xs = [-span / 2 + span * i / (count - 1) for i in range(count)]
        for index, x in enumerate(xs):
            self.car(f"{name}-{index}", x, y, start + index, rotation=rotation, scale=scale, suv=index % 4 == 1)


def build_house(
    b: Builder,
    name: str,
    x: float,
    y: float,
    width: float,
    depth: float,
    height: float,
    *,
    wall: str,
    roof: str,
    modern: bool = False,
    hip: bool = True,
) -> None:
    b.mass(name, x, y, width, depth, height, wall=wall, glass="Glass_Dark", floors=max(2, round(height / 8)), cap=roof, windowed=True)
    if modern:
        b.box(f"{name}-terrace", (width * 0.64, depth * 0.48, 1.0), (x + width * 0.10, y - depth * 0.18, 0.50 + height + 0.75), "Concrete_Light", bevel=0.14)
        b.box(f"{name}-terrace-glass", (width * 0.58, 0.22, 1.5), (x + width * 0.10, y - depth * 0.43, 0.50 + height + 1.3), "Glass_Cyan", bevel=0.04, layer="near")
    else:
        if hip:
            b.hip("hipped-roof", x, y, width + 1.8, depth + 1.8, 0.50 + height + 0.62, max(3.5, depth * 0.18), roof)
        else:
            b.gable("hipped-roof", x, y, width + 1.8, depth + 1.8, 0.50 + height + 0.62, max(3.8, depth * 0.20), roof)
    b.entrance(f"{name}-entry", x, y - depth / 2 - 0.22, width * 0.18, min(5.2, height * 0.24), "Wood")


def build_residential(spec: AssetSpec) -> Builder:
    b = Builder(spec)
    b.lot("Lawn", accent="Concrete_Warm")
    if spec.variant == 0:
        build_house(b, "cottage-main", -14, 8, 42, 40, 24, wall="Facade_White", roof="Roof_Orange")
        build_house(b, "cottage-wing", 22, 17, 25, 26, 18, wall="Facade_Sage", roof="Roof_Red", hip=False)
        b.parking_row("cottage-cars", 3, -25, 35, start=0)
    elif spec.variant == 1:
        build_house(b, "gable-main", -12, 7, 44, 42, 27, wall="Concrete_Warm", roof="Roof_Red", hip=False)
        build_house(b, "gable-side", 24, 14, 24, 30, 21, wall="Facade_White", roof="Roof_Blue", hip=False)
        b.parking_row("gable-cars", 3, -26, 38, start=2)
    elif spec.variant == 2:
        build_house(b, "modern-home", -13, 5, 48, 44, 31, wall="Facade_White", roof="Charcoal", modern=True)
        b.mass("modern-studio", 25, 16, 24, 28, 22, wall="Facade_Sand", glass="Glass_Cyan", floors=3, cap="Roof_Copper")
        b.parking_row("modern-cars", 3, -26, 38, start=4)
    elif spec.variant == 3:
        build_house(b, "twin-west", -20, 7, 34, 42, 26, wall="Facade_Brick", roof="Roof_Charcoal")
        build_house(b, "twin-east", 20, 7, 34, 42, 26, wall="Facade_White", roof="Roof_Blue")
        b.parking_row("twin-cars", 4, -26, 52, start=1, scale=1.48)
    else:
        b.mass("apartment-podium", 0, 8, 68, 50, 20, wall="Facade_Brick", glass="Glass_Gold", floors=3, cap="Charcoal")
        b.mass("apartment-tower", -5, 10, 48, 40, 50, wall="Facade_Sand", glass="Glass_Dark", floors=8, cap="Roof_Copper")
        for level in range(6):
            z = 22 + level * 5.8
            b.box(f"balcony-{level}", (51, 2.2, 0.45), (-5, -11.2, z), "Concrete_Light", bevel=0.08, layer="near")
        b.parking_row("apartment-cars", 4, -29, 50, start=3, scale=1.45)
    b.tree("tree-west", -34, 30, 1.15)
    b.tree("tree-east", 34, 31, 1.0)
    return b


def build_luxury(spec: AssetSpec) -> Builder:
    b = Builder(spec)
    b.lot("Lawn", accent="Warm_White")
    if spec.variant == 0:
        b.mass("courtyard-west", -20, 8, 28, 52, 30, wall="Facade_White", glass="Glass_Cyan", floors=4, cap="Roof_Copper")
        b.mass("courtyard-east", 20, 8, 28, 52, 30, wall="Facade_Sand", glass="Glass_Dark", floors=4, cap="Roof_Copper")
        b.mass("courtyard-bridge", 0, 24, 22, 18, 20, wall="Facade_White", glass="Glass_Cyan", floors=2, cap="Roof_Copper")
        b.box("courtyard-water", (22, 19, 0.28), (0, 0, 0.68), "Pool_Tile", bevel=0.30, layer="near")
    elif spec.variant == 1:
        build_house(b, "garage-villa", -8, 8, 56, 48, 34, wall="Facade_White", roof="Roof_Charcoal", modern=True)
        b.box("garage-door-a", (14, 0.42, 8), (18, -16.2, 4.6), "Roller_Door", bevel=0.08, layer="near")
        b.box("garage-door-b", (14, 0.42, 8), (2, -16.2, 4.6), "Roller_Door", bevel=0.08, layer="near")
        b.parking_row("garage-cars", 3, -28, 35, start=0)
    elif spec.variant == 2:
        build_house(b, "pool-villa", -14, 10, 46, 48, 32, wall="Facade_White", roof="Roof_Copper", modern=True)
        b.box("pool", (28, 42, 0.34), (24, 5, 0.73), "Pool_Tile", bevel=0.55, layer="near")
        for y in (-10, 2, 14):
            b.box(f"pool-step-{y}", (4, 10, 0.3), (24, y, 0.98), "Facade_White", bevel=0.12, layer="near")
        b.parking_row("pool-cars", 2, -28, 18, start=4)
    else:
        b.mass("terrace-villa-low", 0, 8, 62, 50, 26, wall="Facade_Sand", glass="Glass_Cyan", floors=3, cap="Charcoal")
        b.mass("terrace-villa-high", -10, 12, 40, 34, 42, wall="Facade_White", glass="Glass_Dark", floors=6, cap="Roof_Copper")
        for level in (28, 34, 40):
            b.box(f"terrace-{level}", (46, 5.5, 0.52), (-5, -8.5, level), "Concrete_Light", bevel=0.12, layer="near")
        b.parking_row("terrace-cars", 3, -28, 34, start=2)
    b.tree("luxury-tree-a", -34, 31, 1.2)
    b.tree("luxury-tree-b", 34, 31, 1.15)
    return b


def build_dealer_asset(spec: AssetSpec, modern: bool) -> Builder:
    b = Builder(spec)
    b.lot("Asphalt", accent="Brand_Blue")
    if modern:
        b.mass("dealer-lower", -10, 12, 54, 43, 17, wall="Facade_White", glass="Glass_Cyan", floors=2, cap="Brand_Blue")
        b.mass("dealer-upper", -12, 16, 42, 32, 31, wall="Brand_Blue_Dark", glass="Glass_Cyan", floors=4, cap="Brand_Orange")
        b.entrance("dealer-entry", -9, -9.8, 18, 8, "Brand_Orange")
        b.box("display-canopy", (25, 24, 1.0), (26, 17, 17), "Brand_Blue", bevel=0.18)
        for x in (16, 36):
            b.box(f"display-post-{x}", (0.7, 0.7, 16), (x, 17, 8.5), "Metal", bevel=0.08)
        b.car("hero-car", 26, 17, 4, rotation=math.radians(90), scale=1.80, suv=True)
        b.parking_row("dealer-front", 6, -28, 58, start=0, scale=1.58)
        b.parking_row("dealer-mid", 5, -14, 50, start=3, rotation=-math.radians(90), scale=1.50)
    else:
        b.mass("market-hall", -12, 12, 50, 42, 24, wall="Concrete_Warm", glass="Glass_Dark", floors=3, cap="Roof_Blue")
        b.gable("hipped-roof", -12, 12, 53, 45, 25.1, 8, "Roof_Blue")
        b.mass("market-office", 26, 12, 22, 36, 30, wall="Facade_White", glass="Glass_Cyan", floors=4, cap="Brand_Orange")
        b.entrance("market-entry", -12, -9.4, 18, 7, "Brand_Orange")
        b.parking_row("market-front", 6, -28, 58, start=2, scale=1.58)
        b.parking_row("market-side", 4, 2, 36, start=5, rotation=0, scale=1.55)
    b.box("dealer-pylon", (3.2, 2.4, 18), (34, -24, 9.5), "Brand_Blue", bevel=0.20)
    b.box("dealer-pylon-sign", (12, 2.8, 6), (34, -24, 17), "Warm_White", bevel=0.25, layer="near")
    b.box("dealer-pylon-mark", (8.5, 0.35, 2.0), (34, -22.5, 17.2), "Brand_Orange", bevel=0.12, layer="near")
    return b


def build_commercial(spec: AssetSpec) -> Builder:
    if spec.variant == 0:
        return build_dealer_asset(spec, modern=False)
    b = Builder(spec)
    b.lot("Asphalt", accent="Concrete_Light")
    if spec.variant == 1:
        b.mass("gas-shop", 18, 17, 36, 34, 24, wall="Facade_White", glass="Glass_Cyan", floors=3, cap="Brand_Orange")
        b.box("gas-canopy", (55, 30, 1.4), (-11, -16, 14), "Brand_Blue", bevel=0.25)
        for x in (-34, 12):
            for y in (-25, -8):
                b.box(f"gas-post-{x}-{y}", (0.9, 0.9, 13), (x, y, 7), "Metal", bevel=0.10)
        for x in (-24, -8, 8):
            b.box(f"pump-{x}", (3.1, 2.0, 4.4), (x, -16, 2.7), "Warm_White", bevel=0.25, layer="near")
            b.box(f"pump-accent-{x}", (3.3, 2.2, 0.65), (x, -16, 4.9), "Brand_Orange", bevel=0.10, layer="near")
        b.box("gas-pylon", (3, 2, 28), (34, -25, 14.5), "Brand_Blue", bevel=0.20)
        b.box("gas-sign", (11, 2.4, 8), (34, -25, 24), "Brand_Orange", bevel=0.25, layer="near")
        b.car("fuel-car-a", -26, -16, 0, rotation=0, scale=1.58)
        b.car("fuel-car-b", 0, -16, 2, rotation=0, scale=1.58)
    elif spec.variant == 2:
        b.mass("convenience-store", 0, 9, 66, 50, 28, wall="Facade_White", glass="Glass_Cyan", floors=3, cap="Brand_Blue")
        b.box("store-band", (67, 0.8, 3.4), (0, -16.4, 22), "Brand_Orange", bevel=0.12, layer="near")
        b.entrance("store-entry", 0, -16.5, 16, 8, "Brand_Blue")
        b.parking_row("store-cars", 5, -29, 52, start=1, scale=1.52)
    elif spec.variant == 3:
        build_house(b, "restaurant", 0, 9, 62, 49, 31, wall="Facade_Brick", roof="Roof_Orange", hip=True)
        b.box("restaurant-awning", (48, 6, 1.0), (0, -17, 9), "Awning_Red", bevel=0.18, layer="near")
        b.entrance("restaurant-entry", 0, -16, 14, 7, "Wood")
        b.parking_row("restaurant-cars", 5, -29, 50, start=3, scale=1.48)
    elif spec.variant == 4:
        b.mass("shopping-podium", 0, 8, 70, 56, 30, wall="Facade_Sand", glass="Glass_Dark", floors=4, cap="Brand_Orange")
        b.mass("shopping-upper", 8, 14, 50, 38, 48, wall="Facade_White", glass="Glass_Cyan", floors=7, cap="Brand_Blue")
        b.entrance("shopping-entry", -12, -20.2, 22, 10, "Brand_Orange")
        b.parking_row("shopping-cars", 5, -29, 50, start=0, scale=1.48)
    elif spec.variant == 5:
        b.mass("roadside-store", -5, 10, 62, 52, 34, wall="Facade_Teal", glass="Glass_Cyan", floors=4, cap="Charcoal")
        b.box("roadside-crown", (66, 55, 3.0), (-5, 10, 34), "Brand_Orange", bevel=0.35)
        b.entrance("roadside-entry", -5, -16.2, 20, 9, "Brand_Orange")
        b.box("roadside-pylon", (4, 3, 26), (34, -24, 13.5), "Charcoal", bevel=0.22)
        b.box("roadside-sign", (12, 3.3, 7), (34, -24, 23), "Brand_Orange", bevel=0.25, layer="near")
        b.parking_row("roadside-cars", 5, -29, 50, start=2, scale=1.52)
    else:
        b.mass("mall-base", 0, 12, 164, 128, 36, wall="Facade_Sand", glass="Glass_Dark", floors=5, cap="Brand_Blue")
        b.mass("mall-atrium", 0, -18, 76, 50, 62, wall="Facade_White", glass="Glass_Cyan", floors=8, cap="Brand_Orange")
        b.mass("mall-west", -58, 24, 42, 76, 47, wall="Facade_Brick", glass="Glass_Gold", floors=6, cap="Roof_Copper")
        b.mass("mall-east", 58, 24, 42, 76, 47, wall="Facade_Teal", glass="Glass_Cyan", floors=6, cap="Charcoal")
        b.entrance("mall-entry", 0, -43.5, 28, 13, "Brand_Orange")
        b.parking_row("mall-front", 10, -76, 138, start=0, scale=1.50)
        b.parking_row("mall-mid", 10, -60, 138, start=4, scale=1.50)
        for x in (-80, 80):
            b.tree(f"mall-tree-{x}", x, 73, 1.4)
    return b


def add_loading_doors(b: Builder, name: str, count: int, y: float, width: float, height: float = 10) -> None:
    span = b.width * 0.60
    for index in range(count):
        x = -span / 2 + (span * index / max(1, count - 1))
        b.box(f"{name}-door-{index}", (width, 0.42, height), (x, y, 0.50 + height / 2), "Roller_Door", bevel=0.10, layer="near")
        b.box(f"{name}-dock-{index}", (width + 1.2, 5.5, 1.2), (x, y - 2.5, 1.1), "Concrete_Dark", bevel=0.15, layer="near")


def build_industrial(spec: AssetSpec) -> Builder:
    b = Builder(spec)
    b.lot("Concrete_Mid", accent="Safety_Yellow")
    if spec.variant == 0:
        b.mass("factory-main", -32, 20, 102, 116, 43, wall="Industrial_Blue", glass="Glass_Dark", floors=5, cap="Charcoal")
        b.gable("factory-roof", -32, 20, 105, 119, 44, 13, "Roof_Blue")
        b.mass("factory-admin", 53, -15, 56, 64, 48, wall="Facade_White", glass="Glass_Cyan", floors=6, cap="Brand_Orange")
        add_loading_doors(b, "factory", 5, -38.3, 15, 11)
        for x in (-65, -42, -19, 4):
            b.cylinder(f"factory-vent-{x}", 3.1, 13, (x, 40, 61), "Metal", vertices=14, layer="near")
    elif spec.variant in (1, 2):
        b.mass("warehouse-hall", 0, 5, 166, 59, 39 if spec.variant == 1 else 35, wall="Industrial_Blue" if spec.variant == 1 else "Industrial_Green", glass="Glass_Dark", floors=4, cap="Charcoal")
        b.gable("warehouse-roof", 0, 5, 169, 62, 40 if spec.variant == 1 else 36, 12, "Roof_Blue")
        add_loading_doors(b, "loading", 7 if spec.variant == 2 else 5, -25.0, 15, 10)
        for index, x in enumerate((-70, -45, -20, 5, 30, 55, 70)):
            b.car(f"loading-truck-{index}", x, -32, index, rotation=math.radians(90), scale=1.65, suv=True)
    elif spec.variant == 3:
        b.mass("tank-admin", 0, -50, 94, 48, 38, wall="Industrial_Green", glass="Glass_Dark", floors=4, cap="Charcoal")
        positions = [(-48, 27), (0, 27), (48, 27), (-24, 68), (27, 68)]
        for index, (x, y) in enumerate(positions):
            radius = 16 if index < 3 else 13
            height = 34 if index < 3 else 27
            b.cylinder(f"storage-tank-{index}", radius, height, (x, y, 0.50 + height / 2), "Metal", vertices=20)
            b.cylinder(f"tank-cap-{index}", radius + 0.5, 0.8, (x, y, 0.50 + height), "Brand_Orange", vertices=20, layer="near")
        for y in (5, 48):
            b.box(f"pipe-rack-{y}", (145, 3, 2.6), (0, y, 17), "Safety_Yellow", bevel=0.10, layer="near")
    else:
        b.mass("power-hall", -25, 18, 112, 102, 48, wall="Concrete_Dark", glass="Glass_Gold", floors=5, cap="Roof_Charcoal")
        b.mass("power-annex", 56, -20, 50, 70, 61, wall="Industrial_Blue", glass="Glass_Dark", floors=7, cap="Charcoal")
        for index, (x, y, height) in enumerate(((-56, 51, 98), (10, 55, 116), (61, 48, 88))):
            b.cylinder(f"smokestack-{index}", 7.5, height, (x, y, 0.50 + height / 2), "Facade_Brick", vertices=20)
            b.cylinder(f"smokestack-cap-{index}", 8.2, 4.0, (x, y, height - 4), "Charcoal", vertices=20, layer="near")
        add_loading_doors(b, "power", 5, -33.2, 15, 11)
    return b


def tower(
    b: Builder,
    name: str,
    x: float,
    y: float,
    width: float,
    depth: float,
    height: float,
    *,
    wall: str,
    glass: str,
    cap: str,
    setbacks: int = 2,
) -> None:
    podium_h = min(24, height * 0.20)
    b.mass(f"{name}-podium", x, y - depth * 0.08, width * 1.22, depth * 1.18, podium_h, wall=wall, glass=glass, floors=max(2, round(podium_h / 7)), cap=cap)
    current_z = 0.50 + podium_h
    remaining = height - podium_h
    for index in range(setbacks):
        tier_h = remaining / setbacks
        scale = 1.0 - index * 0.14
        w = width * scale
        d = depth * scale
        z_center = current_z + tier_h / 2
        b.box(f"{name}-tier-{index}", (w, d, tier_h), (x + index * width * 0.035, y + index * depth * 0.025, z_center), wall, bevel=0.32)
        b.windows(
            f"{name}-tier-{index}",
            x + index * width * 0.035,
            y + index * depth * 0.025,
            w,
            d,
            tier_h,
            base_z=current_z,
            floors=max(2, round(tier_h / 7)),
            glass=glass,
            frame=cap,
        )
        b.box(f"{name}-ledge-{index}", (w + 1.1, d + 1.1, 0.75), (x + index * width * 0.035, y + index * depth * 0.025, current_z + tier_h), cap, bevel=0.12, layer="near")
        current_z += tier_h
    b.rooftop(f"{name}-hvac", x, y, height + 2.1, scale=1.4)


def build_downtown(spec: AssetSpec) -> Builder:
    b = Builder(spec)
    b.lot("Concrete_Light", accent="Charcoal")
    if spec.variant == 3:
        b.mass("parking-core", 0, 5, 72, 64, 52, wall="Concrete_Dark", glass="Glass_Dark", floors=8, cap="Safety_Yellow", windowed=False)
        for floor in range(8):
            z = 4 + floor * 6
            for side in (-1, 1):
                b.box(f"parking-slat-front-{floor}-{side}", (31, 0.44, 2.8), (side * 18, -27.2, z), "Metal", bevel=0.06, layer="near")
                b.box(f"parking-slat-back-{floor}-{side}", (31, 0.44, 2.8), (side * 18, 37.2, z), "Metal", bevel=0.06, layer="near")
        b.mass("parking-lift", 24, 7, 16, 20, 61, wall="Facade_Teal", glass="Glass_Cyan", floors=9, cap="Brand_Orange")
        b.parking_row("parking-roof-cars", 4, 4, 48, start=1, scale=1.35)
        return b

    if spec.cells_w == 4:
        configs = {
            0: ("mixed", 0, 7, 43, 41, 112, "Facade_Brick", "Glass_Gold", "Roof_Copper", 3),
            1: ("office", 0, 8, 44, 42, 145, "Brand_Blue_Dark", "Glass_Cyan", "Metal", 3),
            2: ("apartment", -4, 8, 48, 44, 128, "Facade_Sand", "Glass_Dark", "Roof_Copper", 3),
            4: ("corner", 9, 6, 45, 43, 154, "Facade_Teal", "Glass_Cyan", "Brand_Orange", 4),
        }
        name, x, y, w, d, h, wall, glass, cap, tiers = configs[spec.variant]
        tower(b, name, x, y, w, d, h, wall=wall, glass=glass, cap=cap, setbacks=tiers)
        b.mass(f"{name}-streetwing", -23, -4, 24, 55, 38, wall="Facade_White", glass=glass, floors=5, cap=cap)
        b.entrance(f"{name}-entry", x, y - d * 0.59 - 0.5, 15, 10, cap)
    elif spec.variant == 5:
        tower(b, "plaza-main", -43, 8, 47, 42, 172, wall="Brand_Blue_Dark", glass="Glass_Cyan", cap="Metal", setbacks=4)
        tower(b, "plaza-side", 43, 12, 43, 39, 118, wall="Facade_White", glass="Glass_Dark", cap="Brand_Orange", setbacks=3)
        b.box("plaza-water", (45, 21, 0.30), (0, -22, 0.72), "Pool_Tile", bevel=0.50, layer="near")
        b.tree("plaza-tree-a", -10, -25, 1.25)
        b.tree("plaza-tree-b", 12, -25, 1.25)
    elif spec.variant == 6:
        tower(b, "twin-west", -45, 8, 46, 42, 186, wall="Brand_Blue_Dark", glass="Glass_Cyan", cap="Metal", setbacks=4)
        tower(b, "twin-east", 45, 8, 46, 42, 174, wall="Facade_Teal", glass="Glass_Cyan", cap="Brand_Orange", setbacks=4)
        b.mass("twin-link", 0, 10, 50, 45, 36, wall="Facade_White", glass="Glass_Gold", floors=5, cap="Brand_Orange")
        b.entrance("twin-entry", 0, -13.0, 18, 11, "Brand_Orange")
    else:
        tower(b, "residential-main", -35, 8, 48, 42, 158, wall="Facade_Sand", glass="Glass_Dark", cap="Roof_Copper", setbacks=4)
        tower(b, "residential-side", 43, 10, 42, 38, 126, wall="Facade_Brick", glass="Glass_Gold", cap="Roof_Copper", setbacks=3)
        for x in (-45, -25, 32, 52):
            b.box(f"residential-balcony-{x}", (18, 4.0, 0.55), (x, -12, 66), "Concrete_Light", bevel=0.10, layer="near")
    return b


def build_highway(spec: AssetSpec) -> Builder:
    b = Builder(spec)
    b.lot("Asphalt", accent="Safety_Yellow")
    if spec.variant == 0:
        b.mass("logistics-hall", 0, 10, 70, 52, 36, wall="Industrial_Blue", glass="Glass_Dark", floors=4, cap="Brand_Orange")
        b.gable("logistics-roof", 0, 10, 73, 55, 37, 8, "Roof_Blue")
        add_loading_doors(b, "logistics", 4, -16.4, 12, 9)
        b.parking_row("logistics-trucks", 4, -30, 48, start=1, scale=1.60)
    elif spec.variant == 1:
        b.mass("bigbox", 0, 8, 72, 58, 40, wall="Facade_Teal", glass="Glass_Cyan", floors=5, cap="Brand_Orange")
        b.box("bigbox-crown", (74, 60, 3.0), (0, 8, 40), "Charcoal", bevel=0.28)
        b.entrance("bigbox-entry", 0, -21.2, 24, 10, "Brand_Orange")
        b.parking_row("bigbox-cars", 6, -30, 56, start=0, scale=1.48)
    else:
        b.mass("motel-west", -24, 8, 24, 55, 53, wall="Facade_Sand", glass="Glass_Dark", floors=7, cap="Awning_Red")
        b.mass("motel-east", 24, 8, 24, 55, 53, wall="Facade_Sand", glass="Glass_Dark", floors=7, cap="Awning_Red")
        b.mass("motel-back", 0, 26, 28, 20, 53, wall="Facade_Brick", glass="Glass_Gold", floors=7, cap="Awning_Red")
        for floor in range(6):
            b.box(f"motel-walkway-{floor}", (70, 4.2, 0.55), (0, -18.0, 8 + floor * 7), "Concrete_Light", bevel=0.10, layer="near")
        b.parking_row("motel-cars", 5, -30, 50, start=2, scale=1.45)
        b.box("motel-sign-post", (3.0, 2.0, 25), (34, -24, 13), "Purple", bevel=0.22)
        b.box("motel-sign", (12, 2.8, 8), (34, -24, 23), "Awning_Red", bevel=0.25, layer="near")
    return b


def build_parking(spec: AssetSpec) -> Builder:
    b = Builder(spec)
    b.lot("Asphalt", accent="Parking_White")
    ys = (-26, -9, 9, 26)
    for row, y in enumerate(ys):
        b.parking_row(f"surface-row-{row}", 7, y, 58, start=row * 2, rotation=math.radians(90) if row % 2 == 0 else -math.radians(90), scale=1.42)
    b.box("parking-sign", (10, 2.0, 9), (33, -28, 5.1), "Brand_Blue", bevel=0.20, layer="near")
    return b


def build_workshop(b: Builder, *, body_shop: bool = False) -> None:
    accent = "Brand_Orange" if body_shop else "Brand_Blue"
    b.lot("Asphalt", accent=accent)
    b.mass("workshop-hall", 0, 8, b.width * 0.88, b.depth * 0.60, 30 if body_shop else 27, wall="Concrete_Dark", glass="Glass_Dark", floors=3, cap=accent, windowed=False)
    door_count = 2 if b.width <= 40 else 3
    door_span = b.width * 0.58
    for index in range(door_count):
        x = -door_span / 2 + door_span * index / max(1, door_count - 1)
        b.box(f"service-door-{index}", (11, 0.42, 12), (x, -b.depth * 0.20 - 0.2, 6.5), "Roller_Door", bevel=0.10, layer="near")
        b.box(f"service-door-band-{index}", (11.5, 0.55, 1.0), (x, -b.depth * 0.20 - 0.45, 13), accent, bevel=0.10, layer="near")
    b.mass("workshop-office", -b.width * 0.29, b.depth * 0.31, b.width * 0.25, b.depth * 0.22, 36 if body_shop else 31, wall="Facade_White", glass="Glass_Cyan", floors=4, cap=accent)
    count = 3 if b.width >= 40 else 2
    b.parking_row("workshop-cars", count, -b.depth * 0.37, b.width * 0.56, start=2 if body_shop else 0, scale=1.48)


def build_player(spec: AssetSpec) -> Builder:
    if spec.variant == 2:
        return build_dealer_asset(spec, modern=True)
    b = Builder(spec)
    if spec.variant == 0:
        b.lot("Asphalt", accent="Brand_Blue")
        b.mass("small-showroom", 0, 5, 34, 22, 22, wall="Facade_White", glass="Glass_Cyan", floors=3, cap="Brand_Blue")
        b.entrance("small-entry", 0, -6.2, 10, 6.5, "Brand_Orange")
        b.parking_row("small-cars", 4, -13, 27, start=0, scale=1.32)
    elif spec.variant == 1:
        b.lot("Asphalt", accent="Brand_Blue")
        b.mass("medium-showroom", -6, 8, 46, 34, 28, wall="Facade_White", glass="Glass_Cyan", floors=4, cap="Brand_Blue")
        b.mass("medium-office", 20, 12, 15, 28, 38, wall="Brand_Blue_Dark", glass="Glass_Cyan", floors=5, cap="Brand_Orange")
        b.entrance("medium-entry", -6, -9.2, 14, 7.5, "Brand_Orange")
        b.parking_row("medium-front", 5, -22, 45, start=0, scale=1.42)
        b.parking_row("medium-mid", 4, -10, 35, start=3, scale=1.40)
    elif spec.variant == 3:
        b.lot("Asphalt", accent="Brand_Blue")
        for row, y in enumerate((-12, 0, 12)):
            b.parking_row(f"display-row-{row}", 4, y, 28, start=row * 2, scale=1.33)
        b.box("display-pylon", (8, 2, 12), (15, -14, 6.5), "Brand_Blue", bevel=0.20, layer="near")
    elif spec.variant in (4, 5):
        build_workshop(b, body_shop=spec.variant == 5)
    elif spec.variant == 6:
        b.lot("Asphalt", accent="Brand_Blue")
        b.mass("wash-tunnel", 0, 3, 17, 28, 21, wall="Brand_Blue_Dark", glass="Glass_Cyan", floors=2, cap="Brand_Orange", windowed=False)
        for y in (-9, -2, 5, 12):
            b.box(f"wash-arch-{y}", (18, 1.0, 18), (0, y, 9.5), "Brand_Blue", bevel=0.22, layer="near")
        b.car("wash-car", 0, -13, 1, rotation=0, scale=1.30)
    elif spec.variant == 7:
        b.lot("Asphalt", accent="Brand_Blue")
        for row, y in enumerate((-20, -7, 7, 20)):
            b.parking_row(f"yard-row-{row}", 6, y, 46, start=row, scale=1.38)
        b.mass("yard-office", 20, 20, 14, 14, 20, wall="Facade_White", glass="Glass_Cyan", floors=3, cap="Brand_Blue")
    elif spec.variant == 8:
        b.lot("Concrete_Light", accent="Brand_Blue")
        b.mass("player-office", 0, 0, 17, 17, 34, wall="Brand_Blue_Dark", glass="Glass_Cyan", floors=5, cap="Brand_Orange")
        # The compact 1x1 parcel has no exterior apron; recess the canopy so
        # the complete authored silhouette remains within its 20x20 boundary.
        b.entrance("office-entry", 0, -6.3, 7, 6, "Brand_Orange")
    elif spec.variant == 9:
        b.lot("Asphalt", accent="Brand_Blue")
        b.mass("parts-hall", 0, 3, 36, 29, 27, wall="Industrial_Blue", glass="Glass_Dark", floors=3, cap="Brand_Orange", windowed=False)
        add_loading_doors(b, "parts", 2, -11.7, 11, 9)
        b.mass("parts-office", 10, 11, 12, 12, 32, wall="Facade_White", glass="Glass_Cyan", floors=4, cap="Brand_Blue")
    elif spec.variant == 10:
        b.lot("Asphalt", accent="Brand_Blue")
        b.mass("auction-hall", 0, 9, 70, 54, 38, wall="Facade_White", glass="Glass_Cyan", floors=5, cap="Brand_Blue")
        b.gable("auction-roof", 0, 9, 73, 57, 39, 10, "Roof_Blue")
        b.entrance("auction-entry", 0, -18.2, 24, 10, "Brand_Orange")
        b.parking_row("auction-cars", 6, -30, 56, start=0, scale=1.50)
    elif spec.variant == 11:
        b.lot("Asphalt", accent="Brand_Blue")
        b.mass("player-logistics", 0, 9, 72, 52, 38, wall="Industrial_Blue", glass="Glass_Dark", floors=4, cap="Brand_Orange")
        b.gable("player-logistics-roof", 0, 9, 75, 55, 39, 10, "Roof_Blue")
        add_loading_doors(b, "player-logistics", 4, -17.2, 12, 10)
        b.parking_row("player-trucks", 5, -30, 50, start=2, scale=1.52)
    else:
        b.lot("Concrete_Light", accent="Brand_Blue")
        tower(b, "headquarters", 0, 4, 37, 35, 128, wall="Brand_Blue_Dark", glass="Glass_Cyan", cap="Brand_Orange", setbacks=4)
        b.mass("hq-podium", 0, 6, 54, 43, 30, wall="Facade_White", glass="Glass_Cyan", floors=4, cap="Brand_Blue")
        b.entrance("hq-entry", 0, -16, 18, 10, "Brand_Orange")
        b.box("hq-water", (34, 10, 0.30), (0, -23, 0.72), "Pool_Tile", bevel=0.30, layer="near")
    return b


def build_asset(spec: AssetSpec) -> Builder:
    if spec.category == "generalResidential":
        return build_residential(spec)
    if spec.category == "luxuryResidential":
        return build_luxury(spec)
    if spec.category == "commercial":
        return build_commercial(spec)
    if spec.category == "industrial":
        return build_industrial(spec)
    if spec.category == "downtown":
        return build_downtown(spec)
    if spec.category == "highway":
        return build_highway(spec)
    if spec.category == "parking":
        return build_parking(spec)
    return build_player(spec)


def convert_and_merge(builder: Builder) -> dict[str, int | float]:
    """Bake modifiers and merge meshes by (LOD layer, material)."""
    collection = builder.collection
    scene = bpy.context.scene
    if collection.name not in scene.collection.children:
        scene.collection.children.link(collection)
    bpy.context.view_layer.update()

    mesh_objects: list[bpy.types.Object] = []
    for obj in list(collection.all_objects):
        if obj.type not in {"MESH", "CURVE", "FONT"}:
            continue
        layer = obj.get("lod_layer", "main")
        matrix = obj.matrix_world.copy()
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        if obj.type != "MESH" or obj.modifiers:
            bpy.ops.object.convert(target="MESH")
            obj = bpy.context.view_layer.objects.active
        obj["lod_layer"] = layer
        obj.parent = None
        obj.matrix_world = matrix
        mesh_objects.append(obj)

    for obj in list(collection.all_objects):
        if obj.type == "EMPTY":
            bpy.data.objects.remove(obj, do_unlink=True)

    root = dealer.empty(f"ROOT_{builder.spec.asset_id}", collection)
    root["city_asset_id"] = builder.spec.asset_id
    near = dealer.empty("near-details", collection)
    props = dealer.empty("prop-details", collection)
    near.parent = root
    props.parent = root

    grouped: dict[tuple[str, str], list[bpy.types.Object]] = {}
    for obj in mesh_objects:
        layer = obj.get("lod_layer", "main")
        material_name = obj.data.materials[0].name if obj.data.materials else "NoMaterial"
        grouped.setdefault((layer, material_name), []).append(obj)

    joined_count = 0
    polygon_count = 0
    for (layer, material_name), objects in sorted(grouped.items()):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        active = objects[0]
        bpy.context.view_layer.objects.active = active
        if len(objects) > 1:
            bpy.ops.object.join()
        active = bpy.context.view_layer.objects.active
        active.name = f"{layer}-{material_name}"
        active.parent = near if layer == "near" else props if layer == "props" else root
        active["lod_layer"] = layer
        joined_count += 1
        polygon_count += len(active.data.polygons)

    bpy.context.view_layer.update()
    bounds = []
    for obj in collection.all_objects:
        if obj.type != "MESH":
            continue
        bounds.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    min_z = min(point.z for point in bounds)
    max_z = max(point.z for point in bounds)
    min_x = min(point.x for point in bounds)
    max_x = max(point.x for point in bounds)
    min_y = min(point.y for point in bounds)
    max_y = max(point.y for point in bounds)
    if min_z < -0.0001:
        raise RuntimeError(f"{builder.spec.asset_id} extends below ground: {min_z}")
    if min_x < -builder.width / 2 - 0.001 or max_x > builder.width / 2 + 0.001:
        raise RuntimeError(f"{builder.spec.asset_id} exceeds footprint width: {min_x}...{max_x}")
    if min_y < -builder.depth / 2 - 0.001 or max_y > builder.depth / 2 + 0.001:
        raise RuntimeError(f"{builder.spec.asset_id} exceeds footprint depth: {min_y}...{max_y}")

    return {
        "geometry_nodes": joined_count,
        "polygons": polygon_count,
        "minimum_height": round(min_z, 4),
        "maximum_height": round(max_z, 4),
    }


def export_usdz(builder: Builder) -> Path:
    scene = bpy.data.scenes.new(f"Export_{builder.spec.asset_id}")
    scene.collection.children.link(builder.collection)
    bpy.context.window.scene = scene
    bpy.ops.object.select_all(action="DESELECT")
    for obj in builder.collection.all_objects:
        obj.select_set(True)
    root = next((obj for obj in builder.collection.objects if obj.name.startswith("ROOT_")), None)
    if root:
        bpy.context.view_layer.objects.active = root

    path = RUNTIME_DIR / f"{builder.spec.asset_id}.usdz"
    bpy.ops.wm.usd_export(
        filepath=str(path),
        selected_objects_only=True,
        export_animation=False,
        export_materials=True,
        export_normals=True,
        export_uvmaps=True,
        export_custom_properties=True,
        use_instancing=True,
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
    bpy.ops.object.select_all(action="DESELECT")
    return path


def make_preview_scene(
    name: str,
    builders: list[Builder],
    *,
    spacing_x: float,
    spacing_y: float,
    ortho_scale: float,
) -> bpy.types.Scene:
    scene = bpy.data.scenes.new(f"Preview_{name}")
    preview_collection = bpy.data.collections.new(f"Preview_{name}_Instances")
    scene.collection.children.link(preview_collection)
    columns = 3 if len(builders) <= 9 else 4
    rows = math.ceil(len(builders) / columns)
    for index, builder in enumerate(builders):
        column = index % columns
        row = index // columns
        x = (column - (columns - 1) / 2) * spacing_x
        y = (row - (rows - 1) / 2) * spacing_y
        instance = bpy.data.objects.new(f"Preview_{builder.spec.asset_id}", None)
        instance.instance_type = "COLLECTION"
        instance.instance_collection = builder.collection
        instance.location = (x, y, 0)
        preview_collection.objects.link(instance)

    rig = dealer.configure_render(scene, 1600, 1000)
    dealer.add_render_rig(
        scene,
        rig,
        camera_location=(310, -350, 315),
        target=(0, 0, 25),
        ortho_scale=ortho_scale,
        backdrop_size=(1200, 900),
    )
    scene.render.filepath = str(PREVIEW_DIR / f"{name}.png")
    return scene


def main() -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)

    dealer.reset_file()
    dealer.build_materials()
    add_library_materials()
    bpy.context.scene.name = "Library_Work"

    builders: list[Builder] = []
    manifest_entries = []
    for index, spec in enumerate(ASSETS, start=1):
        print(f"[{index:02d}/{len(ASSETS)}] Building {spec.asset_id}")
        bpy.context.window.scene = bpy.data.scenes["Library_Work"]
        builder = build_asset(spec)
        metrics = convert_and_merge(builder)
        export_path = export_usdz(builder)
        manifest_entries.append({
            **asdict(spec),
            "width": spec.width,
            "depth": spec.depth,
            "runtime_path": str(export_path.relative_to(PROJECT_DIR)),
            **metrics,
        })
        builders.append(builder)

    categories = {
        "residential": [b for b in builders if b.spec.category in {"generalResidential", "luxuryResidential"}],
        "commercial": [b for b in builders if b.spec.category in {"commercial", "highway", "parking"}],
        "industrial": [b for b in builders if b.spec.category == "industrial"],
        "downtown": [b for b in builders if b.spec.category == "downtown"],
        "player_facilities": [b for b in builders if b.spec.category == "playerFacility"],
    }
    preview_scenes = [
        make_preview_scene("residential", categories["residential"], spacing_x=105, spacing_y=105, ortho_scale=370),
        make_preview_scene("commercial", categories["commercial"], spacing_x=205, spacing_y=205, ortho_scale=700),
        make_preview_scene("industrial", categories["industrial"], spacing_x=235, spacing_y=235, ortho_scale=650),
        make_preview_scene("downtown", categories["downtown"], spacing_x=210, spacing_y=190, ortho_scale=640),
        make_preview_scene("player_facilities", categories["player_facilities"], spacing_x=115, spacing_y=115, ortho_scale=550),
    ]
    for scene in preview_scenes:
        bpy.context.window.scene = scene
        print(f"Rendering {scene.render.filepath}")
        bpy.ops.render.render(write_still=True)

    manifest = {
        "schema": 1,
        "cell_size": 20,
        "front_edge_blender": "negative_y",
        "front_edge_scenekit": "positive_z",
        "asset_count": len(manifest_entries),
        "assets": manifest_entries,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")

    bpy.context.window.scene = preview_scenes[-1]
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), compress=True)
    print(f"Saved {BLEND_PATH}")


if __name__ == "__main__":
    main()
