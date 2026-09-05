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
    # Hand-painted, sunlit toy-town colours (linear Blender colour space).
    palette = {
        "Facade_White": (0.93, 0.85, 0.65, 1), "Facade_Sand": (0.83, 0.61, 0.36, 1),
        "Facade_Brick": (0.64, 0.24, 0.13, 1), "Facade_Sage": (0.43, 0.64, 0.40, 1),
        "Facade_Teal": (0.10, 0.43, 0.44, 1), "Glass_Cyan": (0.10, 0.38, 0.52, 1),
        "Glass_Dark": (0.035, 0.12, 0.19, 1), "Glass_Gold": (0.18, 0.30, 0.34, 1),
        "Roof_Orange": (0.83, 0.22, 0.07, 1), "Roof_Red": (0.60, 0.12, 0.09, 1),
        "Roof_Blue": (0.045, 0.23, 0.49, 1), "Roof_Copper": (0.055, 0.34, 0.31, 1),
        "Lawn": (0.33, 0.55, 0.14, 1), "Hedge": (0.10, 0.32, 0.085, 1),
        "Leaf_Light": (0.34, 0.59, 0.12, 1), "Metal": (0.37, 0.45, 0.48, 1),
    }
    for name, color in palette.items():
        mat = dealer.MATERIALS[name]
        mat.diffuse_color = color
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.68
    dealer.material("Glass_Glint", (0.40, 0.70, 0.78, 1), roughness=0.42)
    dealer.material("Stone_Trim", (0.89, 0.78, 0.55, 1), roughness=0.78)
    dealer.material("Flower_Coral", (0.95, 0.23, 0.16, 1), roughness=0.8)
    dealer.material("Flower_Gold", (1.0, 0.66, 0.075, 1), roughness=0.8)


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
        self.box(name + "-fascia", (width, depth, 0.8), (x, y, base_z), "Stone_Trim", bevel=0.18)
        angle = math.atan2(rise, depth / 2)
        length = math.hypot(rise, depth / 2)
        for i in range(max(3, round(width / 7))):
            px = x + (i + 0.5) * width / max(3, round(width / 7)) - width / 2
            for side in (-1, 1):
                self.box(name + "-standing-seam", (0.32, length * 0.97, 0.27),
                         (px, y + side * depth / 4, base_z + rise / 2 + 0.20), material,
                         rotation=(-side * angle, 0, 0), layer="near")
        self.box(name + "-ridge-cap", (width * 0.98, 1.2, 0.75),
                 (x, y, base_z + rise + 0.25), material, bevel=0.25)

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
        self, name: str, x: float, y: float, width: float, depth: float,
        height: float, *, base_z: float = 0.50, floors: int = 3,
        glass: str = "Glass_Dark", frame: str = "Charcoal", all_sides: bool = True,
        sides: tuple[int, ...] | None = None,
    ) -> None:
        """Deep individual window openings, retained even at the far LOD."""
        floors = max(1, min(floors, round(height / 8)))
        floor_h = height / floors
        window_h = min(floor_h * 0.52, 5.5)
        for side in (sides if sides is not None else range(4 if all_sides else 2)):
            front = side < 2
            span = width if front else depth
            columns = max(2, min(7, round(span / 9)))
            spacing = span * 0.82 / columns
            window_w = spacing * 0.62
            outward = -1 if side % 2 == 0 else 1
            for floor in range(floors):
                z = base_z + floor_h * (floor + 0.57)
                for col in range(columns):
                    offset = (col - (columns - 1) / 2) * spacing
                    px = x + (offset if front else outward * (width / 2 + 0.20))
                    py = y + (outward * (depth / 2 + 0.20) if front else offset)
                    def panel(label, w, h, inset, material):
                        self.box(f"{name}-{side}-{floor}-{col}-{label}",
                                 (w, 0.22, h) if front else (0.22, w, h),
                                 (px + (0 if front else outward * inset),
                                  py + (outward * inset if front else 0), z), material)
                    panel("reveal", window_w + 0.85, window_h + 0.85, 0, frame)
                    panel("glass", window_w, window_h, 0.15, glass)
                    # A single broad reflection, rather than tiny noisy mullions.
                    glint_x = px + (-window_w * 0.27 if front else outward * 0.29)
                    glint_y = py + (outward * 0.29 if front else -window_w * 0.27)
                    self.box(f"{name}-reflection", (window_w * 0.18, 0.08, window_h * 0.8)
                             if front else (0.08, window_w * 0.18, window_h * 0.8),
                             (glint_x, glint_y, z + window_h * 0.04), "Glass_Glint", layer="near")
                # Projecting masonry sills separate stories in the silhouette.
                self.box(f"{name}-sill-{side}-{floor}",
                         (span * 0.92, 0.8, 0.42) if front else (0.8, span * 0.92, 0.42),
                         (x if front else x + outward * (width / 2 + 0.18),
                          y + outward * (depth / 2 + 0.18) if front else y,
                          z - window_h / 2 - 0.42), "Stone_Trim", layer="near")

    def roof_tiles(self, name, x, y, width, depth, base_z, rise, material):
        """Separate trapezoidal tile courses: no overlapping coplanar roofs."""
        self.box(name + "-eaves", (width, depth, 1.35), (x, y, base_z), "Wood", bevel=0.25)
        ridge = width * 0.28
        for course in range(5):
            t0, t1 = course / 5, (course + 1) / 5
            w0, d0 = width * (1-t0) + ridge * t0, depth * (1-t0)
            w1, d1 = width * (1-t1) + ridge * t1, depth * (1-t1)
            z0 = base_z + 0.65 + rise * t0 + course * 0.18
            z1 = base_z + 0.65 + rise * t1 + course * 0.18
            outer = [(-w0/2,-d0/2), (w0/2,-d0/2), (w0/2,d0/2), (-w0/2,d0/2)]
            inner = [(-w1/2,-d1/2), (w1/2,-d1/2), (w1/2,d1/2), (-w1/2,d1/2)]
            vertices = [(x+px,y+py,z0) for px,py in outer]
            vertices += [(x+px,y+py,z1) for px,py in inner]
            vertices += [(x+px,y+py,z0-0.40) for px,py in outer]
            faces = []
            for i in range(4):
                j = (i+1) % 4
                if course == 4 and i in (1,3):
                    faces.append((i,j,4+i))
                else:
                    faces.append((i,j,4+j,4+i))
                faces.append((i,8+i,8+j,j))
            mesh = bpy.data.meshes.new(name + "-tiles")
            mesh.from_pydata(vertices, [], faces)
            mesh.materials.append(dealer.MATERIALS[material])
            mesh.update()
            obj = bpy.data.objects.new(name + f"-course-{course}", mesh)
            obj.parent = self.root
            obj["lod_layer"] = "main"
            self.collection.objects.link(obj)
        self.box(name + "-ridge", (ridge + 0.5, 1.3, 0.9),
                 (x, y, base_z + rise + 1.5), material, bevel=0.35)

    def planter(self, name, x, y, width=9, depth=3):
        self.box(name + "-stone", (width, depth, 1.3), (x, y, 1.1), "Stone_Trim", bevel=0.35)
        self.box(name + "-hedge", (width - 0.6, depth - 0.5, 1.8), (x, y, 2.2), "Hedge", bevel=0.65)
        for i in range(3):
            self.box(name + f"-flowers-{i}", (1.0, 0.9, 0.6),
                     (x + (i - 1) * width * 0.26, y - depth * 0.15, 3.2),
                     "Flower_Coral" if i % 2 else "Flower_Gold", bevel=0.28, layer="props")

    def sign(self, name, text, x, y, z, width, height, accent="Brand_Blue"):
        self.box(name + "-frame", (width + 0.8, 0.75, height + 0.7),
                 (x, y, z), "Stone_Trim", bevel=0.22)
        self.box(name + "-board", (width, 0.2, height), (x, y - 0.48, z), accent, bevel=0.12)
        curve = bpy.data.curves.new(name + "-letters", "FONT")
        curve.body = text
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        curve.size = min(height * 0.68, width / max(1, len(text)) * 1.25)
        curve.extrude = 0.025
        curve.resolution_u = 2
        curve.materials.append(dealer.MATERIALS["Warm_White"])
        obj = bpy.data.objects.new(name + "-letters", curve)
        obj.location = (x, y - 0.61, z)
        obj.rotation_euler = (math.pi / 2, 0, 0)
        obj.parent = self.root
        obj["lod_layer"] = "near"
        self.collection.objects.link(obj)

    def awning(self, name, x, y, z, width, accent="Awning_Red", depth=4.5):
        stripes = max(4, round(width / 2.2))
        for i in range(stripes):
            px = x + (i - (stripes - 1) / 2) * width / stripes
            color = accent if i % 2 == 0 else "Warm_White"
            self.box(name + "-stripe", (width / stripes + 0.02, depth, 0.5),
                     (px, y - depth * 0.44, z), color,
                     rotation=(0.16, 0, 0), bevel=0.08)
            self.box(name + "-valance", (width / stripes, 0.32, 1.0),
                     (px, y - depth * 0.93, z - 0.6), color, bevel=0.12)

    def shopfront(self, name, x, y, width, height, accent="Brand_Blue"):
        self.box(name + "-reveal", (width, 0.6, height), (x, y, 0.7 + height / 2), "Charcoal")
        for i in range(5):
            px = x + (i - 2) * width / 5
            self.box(name + "-glass", (width / 5 - 0.65, 0.18, height - 0.9),
                     (px, y - 0.4, 1.0 + height / 2), "Glass_Cyan")
            self.box(name + "-reflection", (width / 5 * 0.28, 0.1, height * 0.72),
                     (px - width / 5 * 0.22, y - 0.52, 1.25 + height / 2), "Glass_Glint", layer="near")
        self.box(name + "-step", (width + 1, 3, 0.4), (x, y - 1, 0.7), "Stone_Trim", bevel=0.12)
        self.awning(name + "-awning", x, y - 0.5, height + 1.5, width + 1.2, accent, depth=3)

    def garage_door(self, name, x, y, width, height, accent="Brand_Blue"):
        self.box(name + "-recess", (width + 1.2, 0.7, height + 1),
                 (x, y, 0.6 + height / 2), "Charcoal", bevel=0.15)
        self.box(name + "-shutter", (width, 0.18, height),
                 (x, y - 0.48, 0.6 + height / 2), "Roller_Door")
        for i in range(1, 7):
            self.box(name + "-rib", (width - 0.3, 0.16, 0.18),
                     (x, y - 0.61, 0.6 + height * i / 7), "Metal", layer="near")
        self.box(name + "-lintel", (width + 2, 1.0, 1.2),
                 (x, y - 0.15, height + 1.35), accent, bevel=0.2)
        for side in (-1, 1):
            self.box(name + "-bollard", (0.65, 0.65, 2.6),
                     (x + side * (width / 2 + 0.45), y - 1.5, 1.8), "Safety_Yellow", bevel=0.16, layer="props")

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
        side_windows: bool = True,
    ) -> None:
        base_z = 0.50
        self.box(name, (width, depth, height), (x, y, base_z + height / 2), wall, bevel=0.65)
        self.box(f"{name}-foundation", (width + 0.55, depth + 0.55, 1.6), (x, y, 1.30), "Stone_Trim", bevel=0.18)
        self.box(f"{name}-cap", (width + 1.2, depth + 1.2, 1.3), (x, y, base_z + height + 0.30), cap, bevel=0.12)
        if windowed:
            self.windows(
                f"{name}-facade",
                x,
                y,
                width,
                depth,
                height,
                base_z=base_z,
                floors=floors or max(1, round(height / 10)),
                glass=glass,
                frame=cap,
            )
        elif side_windows:
            # Custom storefronts face the road; rear and side clerestories
            # keep the architecture legible from all four map orientations.
            self.windows(name + "-clerestory", x, y, width, depth, height * 0.34,
                         base_z=0.5 + height * 0.49, floors=1, glass=glass,
                         frame="Stone_Trim", sides=(1, 2, 3))

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
        bay_w = min(8.8, span / max(1, count - 1) * 0.86) if count > 1 else 9
        pad_w = span + bay_w + 1
        self.box(name + "-drive", (pad_w, 10.8, 0.10), (0, y, 0.57), "Asphalt_Light", bevel=0.15)
        for index, x in enumerate(xs):
            for side in (-1, 1):
                self.box(name + "-bay-line", (0.22, 9.4, 0.035), (x + side * bay_w / 2, y, 0.65), "Parking_White", layer="near")
            self.box(name + "-wheel-stop", (bay_w * 0.62, 0.55, 0.3), (x, y + 4.1, 0.81), "Stone_Trim", bevel=0.08, layer="near")
            self.car(f"{name}-{index}", x, y, start + index, rotation=rotation, scale=scale, suv=index % 4 == 1)


def build_house(b, name, x, y, width, depth, height, *, wall, roof, modern=False, hip=True):
    b.mass(name, x, y, width, depth, height, wall=wall, cap="Stone_Trim", windowed=False, side_windows=False)
    b.windows(name, x, y, width, depth, height, floors=2 if height > 17 else 1,
              glass="Glass_Dark", frame="Warm_White")
    if modern:
        b.box(name + "-roof-deck", (width - 1, depth - 1, 0.7), (x, y, height + 1.5), "Wood", bevel=0.12)
        for dx in (-1, 1):
            b.box(name + "-parapet", (0.7, depth, 2.1), (x + dx * width / 2, y, height + 2.2), "Warm_White", bevel=0.16)
        b.box(name + "-terrace-rail", (width, 0.5, 1.8), (x, y - depth / 2, height + 2.4), "Glass_Cyan")
        b.planter(name + "-garden", x, y + depth / 2 - 2, width * 0.4)
        b.rooftop(name + "-solar", x + width * 0.2, y, height + 2, scale=0.9)
    else:
        b.roof_tiles(name, x, y, width + 2.2, depth + 2.2, height + 1.1, depth * 0.30, roof)
        # A projecting front gable and shaded porch give each home a face.
        porch_w = width * 0.30
        porch_y = y - depth / 2 - 1.3
        b.box(name + "-porch", (porch_w, 5.5, 0.5), (x, porch_y, 0.9), "Stone_Trim", bevel=0.15)
        b.gable(name + "-porch-gable", x, porch_y, porch_w + 1, 5.8, 8, 3.5, roof)
        for side in (-1, 1):
            b.box(name + "-porch-post", (0.7, 0.7, 7), (x + side * porch_w * 0.43, porch_y - 2, 4.4), "Warm_White", bevel=0.14)
        b.box(name + "-chimney", (2.7, 3, 7), (x - width * 0.25, y + depth * 0.1, height + 6), "Facade_Brick", bevel=0.25)
        b.box(name + "-chimney-cap", (3.6, 3.9, 0.9), (x - width * 0.25, y + depth * 0.1, height + 9.7), "Stone_Trim", bevel=0.2)
        # Blue shutters and a flower box on the front upper windows.
        for side in (-1, 1):
            b.box(name + "-shutters", (3, 0.5, 4.6), (x + side * width * 0.34, y - depth / 2 - 0.5, height * 0.71), roof, bevel=0.10)
    b.box(name + "-door", (3.2, 0.5, 5.8), (x, y - depth / 2 - 0.35, 3.5), "Wood", bevel=0.2)
    b.box(name + "-door-light", (1.8, 0.16, 2.2), (x, y - depth / 2 - 0.68, 4.5), "Glass_Glint")


def build_residential(spec):
    b = Builder(spec)
    b.lot("Lawn")
    if spec.variant < 4:
        palettes = [("Facade_White", "Roof_Orange"), ("Facade_Sand", "Roof_Red"),
                    ("Facade_White", "Roof_Copper"), ("Facade_Sage", "Roof_Blue")]
        wall, roof = palettes[spec.variant]
        build_house(b, "home-main", -17, 8, 35, 36, 19 if spec.variant != 2 else 22,
                    wall=wall, roof=roof, modern=spec.variant == 2)
        build_house(b, "home-neighbour", 22, 16, 27, 29, 15,
                    wall="Facade_White" if spec.variant % 2 else "Facade_Sage",
                    roof="Roof_Blue" if spec.variant % 2 else "Roof_Red", modern=spec.variant == 2)
        b.box("garden-path", (4.4, 19, 0.14), (-17, -19, 0.64), "Concrete_Warm", bevel=0.18)
        b.parking_row("driveway", 2, -27, 18, start=spec.variant)
        b.tree("garden-tree", 31, -16, 1.7)
        b.planter("front-flowers", -26, -34, 17, 3.2)
        b.planter("side-hedge", 23, 34, 23, 3)
        for x in (-37, 37):
            b.box("garden-wall", (1.0, 68, 1.7), (x, 0, 1.4), "Stone_Trim", bevel=0.18)
    else:
        b.mass("apartment", -6, 9, 50, 42, 44, wall="Facade_White", floors=5, cap="Roof_Copper")
        b.mass("stair-tower", 24, 13, 15, 34, 48, wall="Facade_Brick", floors=5, cap="Roof_Copper")
        for floor in range(1, 5):
            for x in (-22, -6, 10):
                z = floor * 8.4 + 0.8
                b.box("balcony-slab", (11, 4.5, 0.65), (x, -14, z), "Stone_Trim", bevel=0.12)
                b.box("balcony-rail", (11, 0.6, 2), (x, -16, z + 1.2), "Warm_White", bevel=0.12)
                b.box("balcony-green", (4, 1.2, 1.5), (x - 2, -15, z + 1.5), "Hedge", bevel=0.4, layer="props")
        b.rooftop("apartment-hvac", 0, 12, 46, scale=1.3)
        b.parking_row("apartment-cars", 4, -29, 49, start=3, scale=1.4)
    b.tree("tree-west", -33, 32, 1.6)
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


def build_dealer_asset(spec, modern):
    b = Builder(spec)
    b.lot("Asphalt", accent="Brand_Blue")
    b.mass("showroom", -9, 13, 54, 39, 20, wall="Facade_White", cap="Brand_Blue", windowed=False, side_windows=False)
    b.shopfront("showroom", -9, -6.8, 49, 11, "Brand_Blue")
    b.windows("showroom-side", -9, 13, 54, 39, 20, floors=1, glass="Glass_Cyan", frame="Stone_Trim")
    if modern:
        b.mass("office-tower", -24, 22, 20, 24, 35, wall="Facade_White", cap="Brand_Orange", floors=3)
        b.box("roof-terrace", (28, 28, 0.8), (2, 15, 22), "Charcoal", bevel=0.25)
        b.rooftop("showroom-hvac", 1, 18, 23, scale=1.2)
    else:
        b.roof_tiles("blue-roof", -9, 13, 56, 41, 21.5, 8, "Roof_Blue")
    b.sign("dealer-brand", "AUTO CITY", -9, -7.8, 17, 34, 4.4)
    b.box("display-canopy", (19, 29, 1.5), (28, 16, 12.5), "Brand_Blue", bevel=0.45)
    for x in (20, 36):
        for y in (4, 28):
            b.box("display-column", (0.9, 0.9, 11.5), (x, y, 6.4), "Stone_Trim", bevel=0.16)
    b.car("hero-car", 28, 12, 4, scale=1.7)
    b.parking_row("dealer-front", 6, -29, 55, start=0, scale=1.5)
    b.parking_row("dealer-display", 4, -16, 37, start=2, scale=1.5)
    b.box("pylon-post", (1.4, 1.4, 18), (33, -15, 9.5), "Stone_Trim", bevel=0.18)
    b.sign("road-sign", "AUTO", 33, -15, 17, 10, 5)
    b.planter("dealer-flowers", -24, 35, 23)
    b.tree("dealer-tree", 33, 34, 1.5)
    return b


def build_commercial(spec):
    if spec.variant == 0:
        return build_dealer_asset(spec, modern=False)
    b = Builder(spec)
    b.lot("Asphalt", accent="Stone_Trim")
    if spec.variant == 1:
        b.mass("fuel-shop", 12, 19, 45, 30, 17, wall="Facade_White", cap="Brand_Orange", windowed=False)
        b.shopfront("fuel-market", 12, 3.7, 36, 8, "Brand_Blue")
        b.box("fuel-canopy", (57, 29, 2.3), (-9, -16, 14), "Brand_Blue", bevel=0.65)
        b.box("fuel-fascia", (58, 1.1, 2.0), (-9, -30.2, 14), "Brand_Orange", bevel=0.24)
        for x in (-31, 12):
            b.box("fuel-column", (1.2, 1.2, 12), (x, -16, 6.6), "Warm_White", bevel=0.22)
        for x in (-24, -6, 10):
            b.box("pump-island", (6, 10, 0.55), (x, -15, 0.9), "Stone_Trim", bevel=0.5)
            b.box("pump", (2.7, 2.3, 4.8), (x, -15, 3.5), "Warm_White", bevel=0.4)
            b.box("pump-head", (3, 2.5, 1.3), (x, -15, 5.5), "Brand_Orange", bevel=0.22)
            b.box("pump-display", (1.7, 0.15, 1.4), (x, -16.25, 4.2), "Glass_Dark", layer="near")
            b.box("pump-hose", (0.4, 0.6, 3.4), (x + 1.8, -15, 3.1), "Tire", bevel=0.18, layer="near")
        b.box("fuel-pylon", (2, 2, 22), (33, -24, 11.5), "Stone_Trim", bevel=0.22)
        b.sign("fuel-brand", "FUEL", 33, -24, 21, 10, 6, "Brand_Orange")
        b.car("fuel-car", -16, -17, 0, rotation=0)
    elif spec.variant == 3:
        b.mass("cafe", -4, 13, 57, 38, 20, wall="Facade_Brick", cap="Stone_Trim", windowed=False)
        b.roof_tiles("cafe-roof", -4, 13, 60, 41, 21.5, 11, "Roof_Orange")
        b.shopfront("cafe-windows", -4, -6.4, 46, 8.5, "Awning_Red")
        b.sign("cafe-sign", "CAFE", -4, -7.1, 16, 19, 4, "Roof_Copper")
        b.box("cafe-terrace", (58, 13, 0.2), (-4, -17, 0.7), "Concrete_Warm", bevel=0.45)
        for x in (-24, -7, 10):
            b.cylinder("cafe-table", 2.6, 0.45, (x, -17, 3.5), "Wood")
            b.cylinder("table-foot", 0.4, 2.5, (x, -17, 2), "Charcoal", vertices=8)
            for dx in (-3.8, 3.8):
                b.box("cafe-chair", (2.1, 2.1, 1.7), (x + dx, -17, 1.5), "Wood", bevel=0.4, layer="props")
        b.cylinder("umbrella-pole", 0.2, 8, (24, -14, 4.6), "Wood", vertices=8)
        b.hip("terrace-umbrella", 24, -14, 12, 12, 8.7, 3, "Awning_Red")
        b.parking_row("cafe-cars", 3, -30, 29, start=3, scale=1.45)
        b.planter("cafe-garden", 33, 8, 5, 19)
    elif spec.variant == 6:
        b.mass("mall", 0, 20, 159, 112, 32, wall="Facade_White", cap="Roof_Copper", floors=3)
        b.mass("mall-atrium", 0, -15, 52, 50, 49, wall="Facade_Sand", cap="Roof_Copper", floors=4)
        b.roof_tiles("atrium-roof", 0, -15, 55, 53, 50.8, 15, "Roof_Copper")
        for x, accent in [(-55, "Awning_Red"), (0, "Brand_Blue"), (55, "Roof_Copper")]:
            b.shopfront("mall-store", x, -40.4 if x == 0 else -36.4, 40, 14, accent)
        b.sign("mall-sign", "CITY MARKET", 0, -41.1, 36, 43, 6, "Roof_Copper")
        b.parking_row("mall-front", 10, -76, 138, start=0, scale=1.5)
        b.parking_row("mall-middle", 10, -60, 138, start=4, scale=1.5)
        for x in (-81, 81):
            b.tree("mall-tree", x, 74, 2)
            b.planter("mall-planter", x, -12, 5, 30)
    else:
        height = 19 if spec.variant == 2 else 30 if spec.variant == 4 else 23
        accent = "Brand_Blue" if spec.variant == 2 else "Roof_Copper" if spec.variant == 4 else "Brand_Orange"
        b.mass("retail-hall", 0, 12, 65, 43, height, wall="Facade_White" if spec.variant != 5 else "Facade_Teal", cap=accent, windowed=False)
        b.shopfront("retail", 0, -9.8, 58, 10, accent)
        b.sign("retail-brand", "MART" if spec.variant == 2 else "CITY SHOPS" if spec.variant == 4 else "MOTOR PARTS", 0, -10.4, 16, 39, 4.4, accent)
        if spec.variant == 4:
            b.windows("upper-shops", 0, 12, 65, 43, 12, base_z=18, floors=1, frame="Warm_White")
            b.roof_tiles("retail-roof", 0, 12, 67, 45, 31.5, 10, accent)
        else:
            b.box("roof-inset", (59, 37, 0.4), (0, 12, height + 1.55), "Charcoal", bevel=0.2)
            b.rooftop("retail-hvac", -17, 20, height + 2.5, scale=1.3)
        b.parking_row("retail-cars", 5, -29, 51, start=spec.variant, scale=1.48)
        b.planter("retail-hedge", -20, 36, 25)
        b.tree("retail-tree", 34, 31, 1.45)
    return b


def add_loading_doors(b, name, count, y, width, height=10):
    span = b.width * 0.60
    for index in range(count):
        x = -span / 2 + span * index / max(1, count - 1)
        b.garage_door(f"{name}-{index}", x, y, width, height, "Brand_Orange")
        b.box(name + "-dock", (width + 1.2, 3.5, 0.8), (x, y - 1.7, 1), "Concrete_Dark", bevel=0.15)


def build_industrial(spec: AssetSpec) -> Builder:
    b = Builder(spec)
    b.lot("Concrete_Mid", accent="Safety_Yellow")
    if spec.variant == 0:
        b.mass("factory-main", -32, 20, 102, 116, 43, wall="Industrial_Blue", glass="Glass_Dark", floors=2, cap="Charcoal")
        b.gable("factory-roof", -32, 20, 105, 119, 44, 13, "Roof_Blue")
        b.mass("factory-admin", 53, -15, 56, 64, 48, wall="Facade_White", glass="Glass_Cyan", floors=6, cap="Brand_Orange")
        add_loading_doors(b, "factory", 5, -38.3, 15, 11)
        for x in (-65, -42, -19, 4):
            b.cylinder(f"factory-vent-{x}", 3.1, 13, (x, 40, 61), "Metal", vertices=14, layer="near")
    elif spec.variant in (1, 2):
        b.mass("warehouse-hall", 0, 5, 166, 59, 39 if spec.variant == 1 else 35, wall="Industrial_Blue" if spec.variant == 1 else "Industrial_Green", glass="Glass_Dark", floors=2, cap="Charcoal")
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


def tower(b, name, x, y, width, depth, height, *, wall, glass, cap):
    """A vertical tower over a low street podium, with a flat service roof.

    The floor plate is constant from the lobby to the crown. Identity comes
    from the facade, balconies and adjacent wings, never a pyramid of tiers.
    """
    podium_h = min(13, height * 0.10)
    glazed = wall in {"Brand_Blue_Dark", "Facade_Teal"}
    residential = "apartment" in name or "residential" in name
    trim = "Metal" if glazed else "Stone_Trim"
    b.mass(name + "-street-podium", x, y - depth * 0.07,
           width * 1.18, depth * 1.16, podium_h,
           wall="Facade_White" if glazed else wall, glass=glass, floors=1,
           cap=trim)
    shaft_h = height - podium_h
    base = podium_h + 0.5
    b.box(name + "-vertical-shaft", (width, depth, shaft_h),
          (x, y, base + shaft_h / 2), "Glass_Cyan" if glazed else wall,
          bevel=0.55)
    floors = max(4, round(shaft_h / 8.6))
    b.windows(name + "-tower-facade", x, y, width, depth, shaft_h,
              base_z=base, floors=floors, glass=glass,
              frame="Metal" if glazed else "Warm_White")
    # Full-height corner piers emphasise parallel, vertical edges.
    for dx in (-1, 1):
        for dy in (-1, 1):
            b.box(name + "-corner-pier", (1.0, 1.0, shaft_h),
                  (x + dx * (width/2 - 0.25), y + dy * (depth/2 - 0.25), base + shaft_h/2),
                  trim, bevel=0.14)
    if glazed:
        for dx in (-width * 0.25, width * 0.25):
            for dy in (-1, 1):
                b.box(name + "-vertical-mullion", (0.5, 0.7, shaft_h),
                      (x + dx, y + dy * (depth/2 + 0.28), base + shaft_h/2), trim)
    if residential:
        for floor in range(1, floors):
            z = base + shaft_h * floor / floors
            for side in (-1, 1):
                py = y + side * (depth/2 + 1.2)
                b.box(name + "-balcony-floor", (width * 0.87, 3.2, 0.55),
                      (x, py, z), "Stone_Trim", bevel=0.12)
                b.box(name + "-balcony-glass", (width * 0.85, 0.35, 1.8),
                      (x, py + side * 1.35, z + 1.25), "Glass_Cyan", layer="near")
    # A thin parapet, recessed roof and modest mechanical room finish the
    # full-width shaft. There are no repeated setbacks or oversized roof plates.
    b.box(name + "-roof-deck", (width + 0.7, depth + 0.7, 0.9),
          (x, y, height + 0.95), trim, bevel=0.18)
    b.box(name + "-roof-inset", (width - 2, depth - 2, 0.30),
          (x, y, height + 1.6), "Charcoal", bevel=0.12)
    for dy in (-1, 1):
        b.box(name + "-parapet", (width, 0.75, 1.25),
              (x, y + dy * (depth/2 - 0.3), height + 1.9), trim, bevel=0.14)
    for dx in (-1, 1):
        b.box(name + "-parapet-side", (0.75, depth, 1.25),
              (x + dx * (width/2 - 0.3), y, height + 1.9), trim, bevel=0.14)
    b.box(name + "-mechanical-room", (width * 0.32, depth * 0.32, 4.8),
          (x + width * 0.12, y + depth * 0.12, height + 3.7), "Concrete_Mid", bevel=0.28)
    b.rooftop(name + "-hvac", x - width * 0.22, y - depth * 0.16, height + 2.6, scale=1.25)


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
            0: ("mixed", 0, 7, 43, 41, 112, "Facade_Brick", "Glass_Gold", "Roof_Copper"),
            1: ("office", 0, 8, 44, 42, 145, "Brand_Blue_Dark", "Glass_Cyan", "Metal"),
            2: ("apartment", -4, 8, 48, 44, 128, "Facade_Sand", "Glass_Dark", "Roof_Copper"),
            4: ("corner", 9, 6, 45, 43, 154, "Facade_Teal", "Glass_Cyan", "Brand_Orange"),
        }
        name, x, y, w, d, h, wall, glass, cap = configs[spec.variant]
        tower(b, name, x, y, w, d, h, wall=wall, glass=glass, cap=cap)
        b.mass(f"{name}-streetwing", -23, -4, 24, 55, 38, wall="Facade_White", glass=glass, floors=5, cap=cap)
        b.entrance(f"{name}-entry", x, y - d * 0.59 - 0.5, 15, 10, cap)
    elif spec.variant == 5:
        tower(b, "plaza-main", -43, 8, 47, 42, 172, wall="Brand_Blue_Dark", glass="Glass_Cyan", cap="Metal")
        tower(b, "plaza-side", 43, 12, 43, 39, 118, wall="Facade_White", glass="Glass_Dark", cap="Brand_Orange")
        b.box("plaza-water", (45, 21, 0.30), (0, -22, 0.72), "Pool_Tile", bevel=0.50, layer="near")
        b.tree("plaza-tree-a", -10, -25, 1.25)
        b.tree("plaza-tree-b", 12, -25, 1.25)
    elif spec.variant == 6:
        tower(b, "twin-west", -45, 8, 46, 42, 186, wall="Brand_Blue_Dark", glass="Glass_Cyan", cap="Metal")
        tower(b, "twin-east", 45, 8, 46, 42, 174, wall="Facade_Teal", glass="Glass_Cyan", cap="Brand_Orange")
        b.mass("twin-link", 0, 10, 50, 45, 36, wall="Facade_White", glass="Glass_Gold", floors=5, cap="Brand_Orange")
        b.entrance("twin-entry", 0, -13.0, 18, 11, "Brand_Orange")
    else:
        tower(b, "residential-main", -35, 8, 48, 42, 158, wall="Facade_Sand", glass="Glass_Dark", cap="Roof_Copper")
        tower(b, "residential-side", 43, 10, 42, 38, 126, wall="Facade_Brick", glass="Glass_Gold", cap="Roof_Copper")
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


def build_workshop(b, *, body_shop=False):
    accent = "Brand_Orange" if body_shop else "Brand_Blue"
    b.lot("Asphalt", accent=accent)
    w, d = b.width * 0.86, b.depth * 0.55
    y = b.depth * 0.16
    b.mass("service-hall", 0, y, w, d, 18, wall="Facade_White", cap=accent, windowed=False)
    b.gable("service-roof", 0, y, w + 1.4, d + 1.4, 19.5, 5.5, "Roof_Blue")
    for i in range(2):
        x = (i - 0.5) * w * 0.48
        b.garage_door("service-bay", x, y - d / 2 - 0.3, w * 0.37, 10.5, accent)
    b.sign("service-sign", "BODY SHOP" if body_shop else "SERVICE", 0, y - d / 2 - 0.9, 15.2, w * 0.82, 3, accent)
    b.rooftop("service-extractor", 0, y + 3, 24.5, scale=0.9)
    b.parking_row("service-cars", 3, -b.depth * 0.36, b.width * 0.55, start=2 if body_shop else 0, scale=1.38)
    b.planter("service-hedge", 0, b.depth * 0.46, b.width * 0.72, 2)


def build_player(spec: AssetSpec) -> Builder:
    if spec.variant == 2:
        return build_dealer_asset(spec, modern=True)
    b = Builder(spec)
    if spec.variant in (0, 1):
        small = spec.variant == 0
        b.lot("Asphalt", accent="Brand_Blue")
        w, d = (33, 22) if small else (49, 32)
        x, y = (0, 5) if small else (-3, 10)
        height = 15 if small else 21
        b.mass("showroom", x, y, w, d, height, wall="Facade_White", cap="Brand_Blue", windowed=False, side_windows=False)
        b.shopfront("showroom-front", x, y - d / 2 - 0.3, w * 0.9, height * 0.50, "Brand_Blue")
        b.sign("showroom-brand", "AUTO CITY", x, y - d / 2 - 0.8, height * 0.81, w * 0.81, 2.8 if small else 4)
        b.box("showroom-roof", (w - 2, d - 2, 0.5), (x, y, height + 1.6), "Charcoal", bevel=0.2)
        b.rooftop("showroom-ac", x - w * 0.24, y + 3, height + 2.3, scale=0.8 if small else 1.2)
        b.windows("showroom-side", x, y, w, d, height, floors=1, frame="Stone_Trim", glass="Glass_Cyan")
        b.parking_row("showroom-cars", 4 if small else 5, -13 if small else -22, 26 if small else 44, start=0, scale=1.3 if small else 1.42)
        if not small:
            b.mass("dealer-office", 17, 17, 14, 18, 31, wall="Facade_White", cap="Brand_Orange", floors=3)
            b.planter("dealer-garden", -15, 27, 20, 2)
    elif spec.variant == 3:
        b.lot("Asphalt", accent="Brand_Blue")
        for row, y in enumerate((-12, 0, 12)):
            b.parking_row(f"display-row-{row}", 4, y, 28, start=row * 2, scale=1.33)
        b.box("display-pylon", (8, 2, 12), (15, -14, 6.5), "Brand_Blue", bevel=0.20, layer="near")
    elif spec.variant in (4, 5):
        build_workshop(b, body_shop=spec.variant == 5)
    elif spec.variant == 6:
        b.lot("Asphalt", accent="Brand_Blue")
        for x in (-7.2, 7.2):
            b.box("wash-sidewall", (3, 26, 14), (x, 3, 7.5), "Facade_White", bevel=0.45)
            for y in (-5, 5, 12):
                b.cylinder("wash-brush", 1.25, 8, (x * 0.67, y, 5.0), "Brand_Blue", vertices=14, layer="near")
        b.box("wash-roof", (18.5, 28, 2), (0, 3, 15), "Brand_Blue", bevel=0.65)
        b.sign("wash-sign", "WASH", 0, -11.5, 13.4, 14, 3, "Brand_Blue")
        b.car("wash-car", 0, -13, 1, rotation=0, scale=1.3)
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
        tower(b, "headquarters", 0, 4, 37, 35, 128, wall="Brand_Blue_Dark", glass="Glass_Cyan", cap="Brand_Orange")
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

    # Read evaluated geometry directly instead of invoking an operator for
    # each tiny window/roof piece. The output is one mesh per material and LOD,
    # in world coordinates, so rotated roof seams cannot inflate export bounds.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    grouped = {}
    for obj in list(collection.all_objects):
        if obj.type not in {"MESH", "CURVE", "FONT"}:
            continue
        temporary = obj.type != "MESH" or bool(obj.modifiers)
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph) if temporary else obj.data
        if mesh is None:
            continue
        layer = obj.get("lod_layer", "main")
        material = mesh.materials[0] if mesh.materials else dealer.MATERIALS["Concrete_Light"]
        key = (layer, material.name)
        vertices, faces, smoothing = grouped.setdefault(key, ([], [], []))
        offset = len(vertices)
        matrix = obj.matrix_world
        vertices.extend(tuple(matrix @ vertex.co) for vertex in mesh.vertices)
        faces.extend(tuple(offset + i for i in polygon.vertices) for polygon in mesh.polygons)
        smoothing.extend(polygon.use_smooth for polygon in mesh.polygons)
        if temporary:
            bpy.data.meshes.remove(mesh)

    for obj in list(collection.all_objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    root = dealer.empty(f"ROOT_{builder.spec.asset_id}", collection)
    root["city_asset_id"] = builder.spec.asset_id
    near = dealer.empty("near-details", collection)
    props = dealer.empty("prop-details", collection)
    near.parent = root
    props.parent = root
    joined_count = 0
    polygon_count = 0
    for (layer, material_name), (vertices, faces, smoothing) in sorted(grouped.items()):
        mesh = bpy.data.meshes.new(f"{layer}-{material_name}")
        mesh.from_pydata(vertices, [], faces)
        mesh.materials.append(dealer.MATERIALS[material_name])
        for polygon, smooth in zip(mesh.polygons, smoothing):
            polygon.use_smooth = smooth
        mesh.update()
        node = bpy.data.objects.new(f"{layer}-{material_name}", mesh)
        collection.objects.link(node)
        node.parent = near if layer == "near" else props if layer == "props" else root
        node["lod_layer"] = layer
        joined_count += 1
        polygon_count += len(faces)

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
        raise RuntimeError(f"{builder.spec.asset_id} extends below ground: {min_z}; " + str([(o.name, min((o.matrix_world @ Vector(v)).z for v in o.bound_box)) for o in collection.all_objects if o.type == "MESH" and min((o.matrix_world @ Vector(v)).z for v in o.bound_box) < -0.001]))
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

    rig = dealer.configure_render(scene, 1600, 1100)
    scene.view_settings.exposure = 0
    scene.view_settings.view_transform = "Standard"
    dealer.add_render_rig(
        scene,
        rig,
        camera_location=(310, -350, 315),
        target=(0, 0, 65 if name == "downtown" else 25),
        ortho_scale=ortho_scale * (1.15 if name == "downtown" else 1),
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
        print(f"[{index:02d}/{len(ASSETS)}] Building {spec.asset_id}", flush=True)
        bpy.context.window.scene = bpy.data.scenes["Library_Work"]
        builder = build_asset(spec)
        metrics = convert_and_merge(builder)
        export_path = export_usdz(builder)
        # Each export scene keeps its asset alive. Remove finished collections
        # from the work scene so later builders do not reevaluate the whole city.
        bpy.data.scenes["Library_Work"].collection.children.unlink(builder.collection)
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
        print(f"Rendering {scene.render.filepath}", flush=True)
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
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), compress=True)
    print(f"Saved {BLEND_PATH}")


if __name__ == "__main__":
    main()
