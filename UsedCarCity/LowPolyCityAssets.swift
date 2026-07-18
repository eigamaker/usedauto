import SceneKit
import UIKit

/// Programmatic PS1-late / PS2-density assets. There are no baked camera angles,
/// shadows, labels, or per-building textures; silhouette and shared materials do
/// the visual work and keep the map deterministic on the common grid.
@MainActor
final class LowPolyCityAssetFactory {
    static let nearDetailNodeName = "asset-lod-near"
    static let propDetailNodeName = "asset-lod-prop"

    private let cellSize: Float
    private let resources = LowPolyAssetResources()

    init(cellSize: Float) {
        self.cellSize = cellSize
    }

    func makeAsset(
        id: CityAssetID,
        facing: CardinalDirection,
        heightHint: Float? = nil
    ) -> SCNNode {
        let definition = CityAssetCatalog.definition(for: id)
        let width = Float(definition.footprint.width) * cellSize - 2
        let depth = Float(definition.footprint.depth) * cellSize - 2
        let height = max(1, heightHint ?? definition.nominalHeight)
        let context = AssetBuildContext(width: width, depth: depth, height: height)
        let root = SCNNode()
        root.name = "city-asset:\(id.rawValue)"
        let near = SCNNode()
        near.name = Self.nearDetailNodeName
        let props = SCNNode()
        props.name = Self.propDetailNodeName
        root.addChildNode(near)
        root.addChildNode(props)

        switch id {
        case .residentialCottage: buildResidential(context, variant: 0, root: root, near: near, props: props)
        case .residentialGable: buildResidential(context, variant: 1, root: root, near: near, props: props)
        case .residentialFlat: buildResidential(context, variant: 2, root: root, near: near, props: props)
        case .residentialTwin: buildResidential(context, variant: 3, root: root, near: near, props: props)
        case .residentialApartment: buildResidential(context, variant: 4, root: root, near: near, props: props)

        case .luxuryCourtyard: buildLuxury(context, variant: 0, root: root, near: near, props: props)
        case .luxuryGarage: buildLuxury(context, variant: 1, root: root, near: near, props: props)
        case .luxuryPool: buildLuxury(context, variant: 2, root: root, near: near, props: props)
        case .luxuryTerrace: buildLuxury(context, variant: 3, root: root, near: near, props: props)

        case .commercialAutoDealer: buildCommercial(context, variant: 0, root: root, near: near, props: props)
        case .commercialGasStation: buildCommercial(context, variant: 1, root: root, near: near, props: props)
        case .commercialConvenience: buildCommercial(context, variant: 2, root: root, near: near, props: props)
        case .commercialRestaurant: buildCommercial(context, variant: 3, root: root, near: near, props: props)
        case .commercialShopping: buildCommercial(context, variant: 4, root: root, near: near, props: props)
        case .commercialRoadside: buildCommercial(context, variant: 5, root: root, near: near, props: props)

        case .industrialFactory: buildIndustrial(context, variant: 0, root: root, near: near, props: props)
        case .industrialWarehouse: buildIndustrial(context, variant: 1, root: root, near: near, props: props)
        case .industrialLoadingWarehouse: buildIndustrial(context, variant: 2, root: root, near: near, props: props)
        case .industrialTankWorks: buildIndustrial(context, variant: 3, root: root, near: near, props: props)
        case .industrialSmokestack: buildIndustrial(context, variant: 4, root: root, near: near, props: props)

        case .downtownMixedUse: buildDowntown(context, variant: 0, root: root, near: near, props: props)
        case .downtownOffice: buildDowntown(context, variant: 1, root: root, near: near, props: props)
        case .downtownApartment: buildDowntown(context, variant: 2, root: root, near: near, props: props)
        case .downtownParkingStructure: buildDowntown(context, variant: 3, root: root, near: near, props: props)
        case .downtownCornerBlock: buildDowntown(context, variant: 4, root: root, near: near, props: props)

        case .highwayLogistics: buildHighway(context, variant: 0, root: root, near: near, props: props)
        case .highwayBigBox: buildHighway(context, variant: 1, root: root, near: near, props: props)
        case .highwayMotorHotel: buildHighway(context, variant: 2, root: root, near: near, props: props)
        case .surfaceParking: buildParking(context, playerOwned: false, root: root, near: near, props: props)

        case .playerSmallDealer: buildPlayerDealer(context, size: 0, root: root, near: near, props: props)
        case .playerMediumDealer: buildPlayerDealer(context, size: 1, root: root, near: near, props: props)
        case .playerLargeDealer: buildPlayerDealer(context, size: 2, root: root, near: near, props: props)
        case .playerDisplayParking: buildParking(context, playerOwned: true, root: root, near: near, props: props)
        case .playerServiceWorkshop: buildPlayerWorkshop(context, bodyShop: false, root: root, near: near, props: props)
        case .playerBodyShop: buildPlayerWorkshop(context, bodyShop: true, root: root, near: near, props: props)
        case .playerCarWash: buildPlayerCarWash(context, root: root, near: near, props: props)
        case .playerVehicleYard: buildPlayerYard(context, root: root, near: near, props: props)
        case .playerOffice: buildPlayerOffice(context, headquarters: false, root: root, near: near, props: props)
        case .playerPartsWarehouse: buildPlayerWarehouse(context, logistics: false, root: root, near: near, props: props)
        case .playerAuctionHouse: buildPlayerAuction(context, root: root, near: near, props: props)
        case .playerLogisticsCenter: buildPlayerWarehouse(context, logistics: true, root: root, near: near, props: props)
        case .playerHeadquarters: buildPlayerOffice(context, headquarters: true, root: root, near: near, props: props)
        }

        root.eulerAngles.y = rotation(for: facing)
        return root
    }

    /// Adds low-profile parcel composition around an ambient asset without
    /// changing its occupied grid footprint. The building remains collision-
    /// accurate while the rest of the purchased parcel reads as a deliberate
    /// yard, forecourt or plaza instead of unused background.
    func makeLotInfill(
        category: CityAssetCategory,
        facing: CardinalDirection,
        width: Float,
        depth: Float
    ) -> SCNNode {
        let c = AssetBuildContext(
            width: max(4, width - 4),
            depth: max(4, depth - 4),
            height: 1
        )
        let root = SCNNode()
        root.name = "asset-lot-infill:\(category.rawValue)"
        let near = SCNNode()
        near.name = Self.nearDetailNodeName
        let props = SCNNode()
        props.name = Self.propDetailNodeName
        root.addChildNode(near)
        root.addChildNode(props)

        switch category {
        case .generalResidential:
            addBox(to: root, width: c.width * 0.13, height: 0.12, depth: c.depth * 0.58,
                   x: c.width * 0.24, y: 0.06, z: c.depth * 0.18, material: .pavement, chamfer: 0.5)
            addHedge(to: props, width: c.width * 0.72, x: 0, z: -c.depth * 0.45)
            addTree(to: props, x: -c.width * 0.38, z: c.depth * 0.34, scale: 0.82)
            addTree(to: props, x: c.width * 0.39, z: -c.depth * 0.31, scale: 0.72)
        case .luxuryResidential:
            addBox(to: root, width: c.width * 0.24, height: 0.12, depth: c.depth * 0.74,
                   x: c.width * 0.27, y: 0.06, z: c.depth * 0.08, material: .pavement, chamfer: 0.7)
            addBox(to: near, width: c.width * 0.24, height: 0.16, depth: c.depth * 0.22,
                   x: -c.width * 0.27, y: 0.08, z: c.depth * 0.30, material: .poolBlue, chamfer: 0.8)
            addHedge(to: props, width: c.width * 0.76, x: 0, z: -c.depth * 0.45)
            addTree(to: props, x: -c.width * 0.40, z: -c.depth * 0.31, scale: 0.94)
            addTree(to: props, x: c.width * 0.40, z: c.depth * 0.33, scale: 0.90)
        case .commercial:
            addBox(to: root, width: c.width * 0.90, height: 0.12, depth: c.depth * 0.38,
                   x: 0, y: 0.06, z: c.depth * 0.27, material: .parkingAsphalt, chamfer: 0.6)
            addParkingBayLines(to: near, props: props, c: c, carCount: 4)
            addStreetLight(to: props, x: -c.width * 0.42, z: c.depth * 0.38)
        case .industrial:
            addBox(to: root, width: c.width * 0.92, height: 0.12, depth: c.depth * 0.40,
                   x: 0, y: 0.06, z: c.depth * 0.26, material: .industrialPavement, chamfer: 0.45)
            addFence(to: props, width: c.width * 0.86, x: 0, z: -c.depth * 0.45)
            addTruck(to: props, x: c.width * 0.28, z: c.depth * 0.29)
        case .downtown:
            addBox(to: root, width: c.width * 0.92, height: 0.12, depth: c.depth * 0.24,
                   x: 0, y: 0.06, z: c.depth * 0.37, material: .downtownPaving, chamfer: 0.45)
            addBox(to: root, width: c.width * 0.18, height: 0.12, depth: c.depth * 0.70,
                   x: -c.width * 0.36, y: 0.06, z: 0, material: .downtownPaving, chamfer: 0.45)
            addStreetLight(to: props, x: -c.width * 0.40, z: c.depth * 0.37)
            addStreetLight(to: props, x: c.width * 0.40, z: c.depth * 0.37)
        case .highway:
            addBox(to: root, width: c.width * 0.92, height: 0.12, depth: c.depth * 0.42,
                   x: 0, y: 0.06, z: c.depth * 0.25, material: .parkingAsphalt, chamfer: 0.55)
            addParkingBayLines(to: near, props: props, c: c, carCount: 3)
            addTruck(to: props, x: -c.width * 0.30, z: c.depth * 0.25)
        case .parking, .playerFacility:
            break
        }

        root.eulerAngles.y = rotation(for: facing)
        return root
    }

    private func addParkingBayLines(
        to near: SCNNode,
        props: SCNNode,
        c: AssetBuildContext,
        carCount: Int
    ) {
        let spacing = c.width * 0.72 / Float(max(1, carCount - 1))
        for index in 0..<carCount {
            let x = -c.width * 0.36 + Float(index) * spacing
            addBox(to: near, width: 0.24, height: 0.08, depth: c.depth * 0.30,
                   x: x, y: 0.12, z: c.depth * 0.27, material: .parkingLine, chamfer: 0)
            if index.isMultiple(of: 2) {
                addParkedCar(to: props, x: x + min(2.6, spacing * 0.30), z: c.depth * 0.27,
                             color: index.isMultiple(of: 4) ? .vehicleBlue : .vehicleNeutral)
            }
        }
    }

    private func buildResidential(
        _ c: AssetBuildContext,
        variant: Int,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .residentialGarden)
        let bodyHeight = variant == 4 ? c.height * 0.82 : c.height * 0.68
        switch variant {
        case 0:
            addBox(to: root, width: c.width * 0.86, height: bodyHeight, depth: c.depth * 0.78,
                   x: 0, y: bodyHeight / 2, z: -c.depth * 0.06, material: .residentialWarm)
            addGable(to: root, width: c.width * 0.90, depth: c.depth * 0.82, height: c.height * 0.28,
                     x: 0, y: bodyHeight, z: -c.depth * 0.06, material: .roofBrown)
        case 1:
            addBox(to: root, width: c.width * 0.88, height: bodyHeight, depth: c.depth * 0.78,
                   x: 0, y: bodyHeight / 2, z: -c.depth * 0.05, material: .residentialCool)
            addGable(to: root, width: c.width * 0.92, depth: c.depth * 0.82, height: c.height * 0.30,
                     x: 0, y: bodyHeight, z: -c.depth * 0.05, material: .roofSlate)
        case 2:
            addBox(to: root, width: c.width * 0.82, height: bodyHeight, depth: c.depth * 0.72,
                   x: -c.width * 0.06, y: bodyHeight / 2, z: -c.depth * 0.08, material: .residentialLight)
            addBox(to: root, width: c.width * 0.38, height: bodyHeight * 0.76, depth: c.depth * 0.36,
                   x: c.width * 0.24, y: bodyHeight * 0.38, z: c.depth * 0.24, material: .residentialWarm)
        case 3:
            let halfWidth = c.width * 0.42
            for x in [-c.width * 0.22, c.width * 0.22] {
                addBox(to: root, width: halfWidth, height: bodyHeight, depth: c.depth * 0.80,
                       x: x, y: bodyHeight / 2, z: -c.depth * 0.05, material: .residentialWarm)
                addGable(to: root, width: halfWidth * 1.04, depth: c.depth * 0.84, height: c.height * 0.24,
                         x: x, y: bodyHeight, z: -c.depth * 0.05, material: .roofBrown)
            }
        default:
            addBox(to: root, width: c.width * 0.88, height: bodyHeight, depth: c.depth * 0.80,
                   x: 0, y: bodyHeight / 2, z: -c.depth * 0.03, material: .residentialCool)
            addBox(to: root, width: c.width * 0.92, height: 0.7, depth: c.depth * 0.84,
                   x: 0, y: bodyHeight + 0.35, z: -c.depth * 0.05, material: .roofSlate)
        }
        if variant < 4 {
            addBox(to: root, width: c.width * 0.34, height: 0.55, depth: c.depth * 0.18,
                   x: c.width * 0.08, y: bodyHeight * 0.42, z: c.depth * 0.29,
                   material: variant.isMultiple(of: 2) ? .roofBrown : .roofSlate)
        }
        if variant == 0 || variant == 1 {
            addBox(to: root, width: 1.4, height: c.height * 0.38, depth: 1.4,
                   x: c.width * 0.22, y: bodyHeight + c.height * 0.12,
                   z: -c.depth * 0.18, material: .smokestackBrick)
        }
        addFacadeStrip(to: near, width: c.width * 0.44, height: 1.0, z: c.depth * 0.22, y: bodyHeight * 0.55)
        addBox(to: near, width: max(1.4, c.width * 0.12), height: bodyHeight * 0.42, depth: 0.42,
               x: c.width * 0.18, y: bodyHeight * 0.21, z: c.depth * 0.305, material: .woodAccent)
        addTree(to: props, x: -c.width * 0.34, z: c.depth * 0.31, scale: 0.75)
        addHedge(to: props, width: c.width * 0.44, x: c.width * 0.18, z: c.depth * 0.42)
    }

    private func buildLuxury(
        _ c: AssetBuildContext,
        variant: Int,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .luxuryGarden)
        let mainHeight = c.height * 0.72
        if variant == 0 {
            addBox(to: root, width: c.width * 0.70, height: mainHeight, depth: c.depth * 0.56,
                   x: 0, y: mainHeight / 2, z: -c.depth * 0.16, material: .luxuryStone)
            addBox(to: root, width: c.width * 0.28, height: mainHeight * 0.75, depth: c.depth * 0.42,
                   x: -c.width * 0.31, y: mainHeight * 0.375, z: c.depth * 0.12, material: .luxuryLight)
            addBox(to: root, width: c.width * 0.28, height: mainHeight * 0.75, depth: c.depth * 0.42,
                   x: c.width * 0.31, y: mainHeight * 0.375, z: c.depth * 0.12, material: .luxuryLight)
        } else {
            addBox(to: root, width: c.width * 0.68, height: mainHeight, depth: c.depth * 0.58,
                   x: -c.width * 0.08, y: mainHeight / 2, z: -c.depth * 0.14, material: variant == 3 ? .luxuryStone : .luxuryLight)
            addBox(to: root, width: c.width * 0.34, height: mainHeight * 0.62, depth: c.depth * 0.42,
                   x: c.width * 0.29, y: mainHeight * 0.31, z: c.depth * 0.14, material: .garageGray)
        }
        addBox(to: root, width: c.width * 0.76, height: 0.7, depth: c.depth * 0.62,
               x: -c.width * 0.05, y: mainHeight + 0.35, z: -c.depth * 0.12, material: .roofLight)
        addBox(to: root, width: c.width * 0.30, height: 0.65, depth: c.depth * 0.20,
               x: -c.width * 0.08, y: mainHeight * 0.48, z: c.depth * 0.18, material: .woodAccent)
        if variant == 2 {
            addBox(to: root, width: c.width * 0.42, height: 0.24, depth: c.depth * 0.24,
                   x: -c.width * 0.12, y: 0.20, z: c.depth * 0.31, material: .poolBlue, chamfer: 0.5)
        }
        if variant == 3 {
            addBox(to: near, width: c.width * 0.48, height: 0.5, depth: c.depth * 0.16,
                   x: -c.width * 0.05, y: mainHeight * 0.58, z: c.depth * 0.10, material: .woodAccent)
        }
        addBox(to: near, width: c.width * 0.24, height: mainHeight * 0.40, depth: 0.55,
               x: c.width * 0.27, y: mainHeight * 0.22, z: c.depth * 0.295, material: .garageGray)
        addFacadeStrip(to: near, width: c.width * 0.40, height: 1.2, z: c.depth * 0.08, y: mainHeight * 0.55)
        addTree(to: props, x: -c.width * 0.38, z: c.depth * 0.34, scale: 0.95)
        addTree(to: props, x: c.width * 0.39, z: -c.depth * 0.30, scale: 0.90)
        addHedge(to: props, width: c.width * 0.52, x: 0, z: c.depth * 0.44)
    }

    private func buildCommercial(
        _ c: AssetBuildContext,
        variant: Int,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .pavement)
        let bodyHeight = c.height * (variant == 4 ? 0.90 : 0.72)
        if variant == 1 {
            addBox(to: root, width: c.width * 0.90, height: 1.0, depth: c.depth * 0.54,
                   x: 0, y: c.height * 0.68, z: -c.depth * 0.09, material: .commercialCanopy)
            for x in [-c.width * 0.35, c.width * 0.35] {
                addBox(to: root, width: 0.8, height: c.height * 0.68, depth: 0.8,
                       x: x, y: c.height * 0.34, z: -c.depth * 0.09, material: .metalLight)
            }
            addBox(to: root, width: c.width * 0.42, height: c.height * 0.55, depth: c.depth * 0.34,
                   x: c.width * 0.23, y: c.height * 0.275, z: -c.depth * 0.30, material: .commercialLight)
            addBox(to: near, width: 1.4, height: 2.2, depth: 1.4, x: 0, y: 1.1, z: 0, material: .commercialAccent)
        } else {
            let width = variant == 2 || variant == 3 ? c.width * 0.88 : c.width * 0.92
            addBox(to: root, width: width, height: bodyHeight, depth: c.depth * 0.60,
                   x: 0, y: bodyHeight / 2, z: -c.depth * 0.17,
                   material: variant == 0 ? .commercialGlass : .commercialLight)
            addBox(to: root, width: width * 1.03, height: 0.8, depth: c.depth * 0.64,
                   x: 0, y: bodyHeight + 0.4, z: -c.depth * 0.17, material: .roofSlate)
            addBox(to: near, width: width * 0.72, height: 1.0, depth: 0.6,
                   x: 0, y: bodyHeight * 0.58, z: c.depth * 0.02, material: .commercialGlass)
        }
        addBox(to: root, width: c.width * 0.72, height: 0.75, depth: 0.8,
               x: 0, y: max(2.8, bodyHeight * 0.62), z: c.depth * 0.035,
               material: variant.isMultiple(of: 2) ? .commercialAccent : .commercialCanopy)
        addPylonSign(
            to: root,
            c: c,
            x: c.width * 0.35,
            z: c.depth * 0.34,
            height: max(5.5, c.height * 0.86),
            material: variant.isMultiple(of: 2) ? .commercialAccent : .commercialCanopy
        )
        addBlankSign(to: near, x: c.width * 0.32, y: max(3, bodyHeight * 0.72), z: c.depth * 0.06,
                     width: c.width * 0.22, material: variant.isMultiple(of: 2) ? .commercialAccent : .commercialCanopy)
        for x in [-c.width * 0.25, 0, c.width * 0.25] {
            addParkedCar(to: props, x: x, z: c.depth * 0.30, color: x == 0 ? .vehicleBlue : .vehicleNeutral)
        }
        addStreetLight(to: props, x: -c.width * 0.42, z: c.depth * 0.37)
    }

    private func buildIndustrial(
        _ c: AssetBuildContext,
        variant: Int,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .industrialPavement)
        let bodyHeight = min(c.height * 0.72, 13)
        if variant == 3 {
            addBox(to: root, width: c.width * 0.58, height: bodyHeight * 0.72, depth: c.depth * 0.72,
                   x: -c.width * 0.16, y: bodyHeight * 0.36, z: -c.depth * 0.06, material: .industrialWall)
            for x in [c.width * 0.16, c.width * 0.34] {
                addCylinder(to: root, radius: min(c.width, c.depth) * 0.12, height: bodyHeight * 0.72,
                            x: x, y: bodyHeight * 0.36, z: -c.depth * 0.10, material: .metalLight)
            }
        } else {
            addBox(to: root, width: c.width * 0.86, height: bodyHeight, depth: c.depth * 0.72,
                   x: 0, y: bodyHeight / 2, z: -c.depth * 0.05,
                   material: variant == 0 ? .factoryBlue : .industrialWall)
            if variant == 0 {
                for x in [-c.width * 0.26, 0, c.width * 0.26] {
                    addGable(to: root, width: c.width * 0.27, depth: c.depth * 0.76, height: 2.8,
                             x: x, y: bodyHeight, z: -c.depth * 0.05, material: .roofMetal)
                }
            } else {
                addBox(to: root, width: c.width * 0.90, height: 0.8, depth: c.depth * 0.76,
                       x: 0, y: bodyHeight + 0.4, z: -c.depth * 0.05, material: .roofMetal)
            }
        }
        if variant == 4 {
            addCylinder(to: root, radius: 2.0, height: c.height,
                        x: c.width * 0.30, y: c.height / 2, z: -c.depth * 0.18, material: .smokestackBrick)
        }
        if variant == 1 || variant == 2 {
            for x in [-c.width * 0.20, 0, c.width * 0.20] {
                addCylinder(to: root, radius: 1.0, height: 1.8,
                            x: x, y: bodyHeight + 0.9, z: -c.depth * 0.08, material: .rooftopEquipment)
            }
        }
        addBox(to: root, width: c.width * 0.56, height: 0.7, depth: 0.6,
               x: 0, y: max(2.8, bodyHeight * 0.56), z: c.depth * 0.235,
               material: variant.isMultiple(of: 2) ? .factoryBlue : .smokestackBrick)
        for x in [-c.width * 0.23, 0, c.width * 0.23] {
            addBox(to: near, width: c.width * 0.16, height: 3.0, depth: 0.8,
                   x: x, y: 1.5, z: c.depth * 0.24, material: .loadingDoor)
        }
        addTruck(to: props, x: c.width * 0.25, z: c.depth * 0.34)
        addFence(to: props, width: c.width * 0.50, x: -c.width * 0.12, z: c.depth * 0.44)
    }

    private func buildDowntown(
        _ c: AssetBuildContext,
        variant: Int,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .downtownPaving)
        if variant == 3 {
            let floorHeight = c.height / 4
            for floor in 0..<4 {
                addBox(to: root, width: c.width * 0.82, height: floorHeight * 0.72, depth: c.depth * 0.78,
                       x: 0, y: Float(floor) * floorHeight + floorHeight * 0.36, z: 0, material: .parkingConcrete)
                addBox(to: near, width: c.width * 0.86, height: 0.45, depth: c.depth * 0.82,
                       x: 0, y: Float(floor + 1) * floorHeight, z: 0, material: .roofSlate)
            }
            return
        }
        let podiumHeight = min(5, c.height * 0.22)
        addBox(to: root, width: c.width * 0.88, height: podiumHeight, depth: c.depth * 0.84,
               x: 0, y: podiumHeight / 2, z: 0, material: .storefrontDark)
        let towerHeight = c.height - podiumHeight
        let towerWidth = c.width * (variant == 1 ? 0.62 : 0.72)
        let towerDepth = c.depth * (variant == 4 ? 0.58 : 0.68)
        addBox(to: root, width: towerWidth, height: towerHeight, depth: towerDepth,
               x: variant == 4 ? -c.width * 0.08 : 0,
               y: podiumHeight + towerHeight / 2,
               z: variant == 2 ? -c.depth * 0.05 : 0,
               material: variant == 1 ? .officeBlue : .downtownWall)
        addBox(to: root, width: towerWidth * 1.03, height: 0.8, depth: towerDepth * 1.03,
               x: variant == 4 ? -c.width * 0.08 : 0, y: c.height + 0.4,
               z: variant == 2 ? -c.depth * 0.05 : 0, material: .roofSlate)
        if variant == 0 || variant == 4 {
            let wingHeight = c.height * (variant == 4 ? 0.58 : 0.42)
            addBox(to: root, width: c.width * 0.28, height: wingHeight, depth: c.depth * 0.42,
                   x: c.width * 0.30, y: podiumHeight + wingHeight / 2,
                   z: c.depth * 0.10, material: .officeBlue)
        }
        if variant == 1 {
            addBox(to: root, width: towerWidth * 0.46, height: 2.6, depth: towerDepth * 0.40,
                   x: 0, y: c.height + 1.7, z: 0, material: .commercialAccent)
        }
        for level in stride(from: Float(8), to: c.height - 1, by: 5) {
            addBox(to: near, width: towerWidth * 0.74, height: 0.7, depth: 0.35,
                   x: 0, y: level, z: towerDepth / 2 + 0.2, material: .windowBlue)
        }
        addBox(to: props, width: 4, height: 1.8, depth: 4,
               x: towerWidth * 0.22, y: c.height + 1.7, z: -towerDepth * 0.15, material: .rooftopEquipment)
    }

    private func buildHighway(
        _ c: AssetBuildContext,
        variant: Int,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .industrialPavement)
        if variant == 2 {
            let wingHeight = c.height * 0.82
            addBox(to: root, width: c.width * 0.88, height: wingHeight, depth: c.depth * 0.64,
                   x: 0, y: wingHeight / 2, z: -c.depth * 0.10, material: .roadsideWarm)
            addBox(to: root, width: c.width * 0.20, height: c.height, depth: c.depth * 0.24,
                   x: c.width * 0.34, y: c.height / 2, z: c.depth * 0.22, material: .roadsideAccent)
        } else {
            let height = c.height * 0.76
            addBox(to: root, width: c.width * 0.86, height: height, depth: c.depth * 0.68,
                   x: 0, y: height / 2, z: -c.depth * 0.08,
                   material: variant == 0 ? .industrialWall : .roadsideWarm)
            addBox(to: root, width: c.width * 0.90, height: 0.8, depth: c.depth * 0.72,
                   x: 0, y: height + 0.4, z: -c.depth * 0.08, material: .roofMetal)
        }
        addBox(to: root, width: c.width * 0.58, height: 0.8, depth: 0.75,
               x: 0, y: max(3.2, c.height * 0.58), z: c.depth * 0.17, material: .roadsideAccent)
        addPylonSign(to: root, c: c, x: c.width * 0.36, z: c.depth * 0.34,
                     height: c.height * 0.92, material: variant == 0 ? .commercialCanopy : .roadsideAccent)
        addBlankSign(to: near, x: c.width * 0.30, y: c.height * 0.58, z: c.depth * 0.18,
                     width: c.width * 0.20, material: .roadsideAccent)
        addTruck(to: props, x: -c.width * 0.24, z: c.depth * 0.33)
        addParkedCar(to: props, x: c.width * 0.17, z: c.depth * 0.34, color: .vehicleNeutral)
    }

    private func buildPlayerDealer(
        _ c: AssetBuildContext,
        size: Int,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .playerPaving)
        let bodyHeight = c.height * 0.75
        addBox(to: root, width: c.width * 0.84, height: bodyHeight, depth: c.depth * 0.56,
               x: 0, y: bodyHeight / 2, z: -c.depth * 0.18, material: .playerWall)
        addBox(to: root, width: c.width * 0.88, height: 0.9, depth: c.depth * 0.60,
               x: 0, y: bodyHeight + 0.45, z: -c.depth * 0.18, material: .playerNavy)
        addBox(to: root, width: c.width * 0.52, height: 0.85, depth: 0.75,
               x: 0, y: bodyHeight * 0.66, z: -c.depth * 0.005, material: .playerAccent)
        addPylonSign(to: root, c: c, x: c.width * 0.36, z: c.depth * 0.34,
                     height: c.height * 0.92, material: .playerAccent)
        addBox(to: near, width: c.width * 0.54, height: 1.5, depth: 0.55,
               x: 0, y: bodyHeight * 0.52, z: -c.depth * 0.01, material: .commercialGlass)
        addBox(to: near, width: c.width * 0.25, height: 1.2, depth: 0.7,
               x: c.width * 0.25, y: bodyHeight * 0.82, z: 0, material: .playerAccent)
        let carCount = size + 3
        for index in 0..<carCount {
            let columns = max(2, size + 2)
            let column = index % columns
            let row = index / columns
            let x = (Float(column) - Float(columns - 1) / 2) * min(8, c.width / Float(columns + 1))
            let z = c.depth * 0.17 + Float(row) * 6
            addParkedCar(to: props, x: x, z: min(c.depth * 0.39, z), color: index.isMultiple(of: 2) ? .vehicleBlue : .vehicleNeutral)
        }
    }

    private func buildParking(
        _ c: AssetBuildContext,
        playerOwned: Bool,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: playerOwned ? .playerPaving : .parkingAsphalt)
        let columns = max(2, Int(c.width / 12))
        for index in 0..<columns {
            let x = (Float(index) - Float(columns - 1) / 2) * (c.width * 0.75 / Float(max(1, columns - 1)))
            addBox(to: near, width: 0.35, height: 0.08, depth: c.depth * 0.72,
                   x: x, y: 0.18, z: 0, material: .parkingLine)
            if index < columns - 1 {
                addParkedCar(to: props, x: x + c.width * 0.75 / Float(max(2, columns)) / 2,
                             z: -c.depth * 0.18, color: index.isMultiple(of: 2) ? .vehicleBlue : .vehicleNeutral)
            }
        }
        if playerOwned {
            addBlankSign(to: near, x: c.width * 0.34, y: 3.8, z: c.depth * 0.35,
                         width: min(8, c.width * 0.22), material: .playerAccent)
        }
    }

    private func buildPlayerWorkshop(
        _ c: AssetBuildContext,
        bodyShop: Bool,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .playerPaving)
        let bodyHeight = c.height * 0.78
        addBox(to: root, width: c.width * 0.80, height: bodyHeight, depth: c.depth * 0.64,
               x: 0, y: bodyHeight / 2, z: -c.depth * 0.08,
               material: bodyShop ? .bodyShopWall : .playerWall)
        addGable(to: root, width: c.width * 0.84, depth: c.depth * 0.68, height: 2.6,
                 x: 0, y: bodyHeight, z: -c.depth * 0.08, material: .playerNavy)
        for x in [-c.width * 0.22, c.width * 0.22] {
            addBox(to: near, width: c.width * 0.26, height: bodyHeight * 0.58, depth: 0.7,
                   x: x, y: bodyHeight * 0.29, z: c.depth * 0.245, material: .loadingDoor)
        }
        addParkedCar(to: props, x: 0, z: c.depth * 0.38, color: .vehicleBlue)
    }

    private func buildPlayerCarWash(
        _ c: AssetBuildContext,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .wetPaving)
        let roofY = c.height * 0.72
        addBox(to: root, width: c.width * 0.78, height: 0.9, depth: c.depth * 0.72,
               x: 0, y: roofY, z: 0, material: .playerNavy)
        for x in [-c.width * 0.31, c.width * 0.31] {
            for z in [-c.depth * 0.26, c.depth * 0.26] {
                addBox(to: root, width: 0.9, height: roofY, depth: 0.9,
                       x: x, y: roofY / 2, z: z, material: .metalLight)
            }
        }
        addBox(to: near, width: c.width * 0.12, height: roofY * 0.60, depth: 0.5,
               x: 0, y: roofY * 0.35, z: -c.depth * 0.12, material: .playerAccent)
        addParkedCar(to: props, x: 0, z: 0, color: .vehicleNeutral)
    }

    private func buildPlayerYard(
        _ c: AssetBuildContext,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .playerPaving)
        addFence(to: root, width: c.width * 0.88, x: 0, z: -c.depth * 0.44)
        addFence(to: root, width: c.width * 0.88, x: 0, z: c.depth * 0.44)
        for row in 0..<2 {
            for column in 0..<3 {
                addParkedCar(to: props,
                             x: (Float(column) - 1) * c.width * 0.24,
                             z: (Float(row) - 0.5) * c.depth * 0.30,
                             color: (row + column).isMultiple(of: 2) ? .vehicleBlue : .vehicleNeutral)
            }
        }
        addBlankSign(to: near, x: c.width * 0.34, y: 4, z: c.depth * 0.34,
                     width: c.width * 0.18, material: .playerAccent)
    }

    private func buildPlayerOffice(
        _ c: AssetBuildContext,
        headquarters: Bool,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .playerPaving)
        if headquarters {
            let podium = 5 as Float
            addBox(to: root, width: c.width * 0.82, height: podium, depth: c.depth * 0.74,
                   x: 0, y: podium / 2, z: 0, material: .playerNavy)
            addBox(to: root, width: c.width * 0.58, height: c.height - podium, depth: c.depth * 0.54,
                   x: 0, y: podium + (c.height - podium) / 2, z: -c.depth * 0.04, material: .officeBlue)
            for y in stride(from: Float(9), to: c.height - 1, by: 5) {
                addBox(to: near, width: c.width * 0.44, height: 0.7, depth: 0.4,
                       x: 0, y: y, z: c.depth * 0.235, material: .windowBlue)
            }
        } else {
            addBox(to: root, width: c.width * 0.72, height: c.height, depth: c.depth * 0.66,
                   x: 0, y: c.height / 2, z: -c.depth * 0.05, material: .playerWall)
            addBox(to: near, width: c.width * 0.46, height: 1.3, depth: 0.5,
                   x: 0, y: c.height * 0.58, z: c.depth * 0.285, material: .commercialGlass)
        }
        addBox(to: props, width: 3.5, height: 1.5, depth: 3.5,
               x: c.width * 0.20, y: c.height + 0.75, z: -c.depth * 0.16, material: .rooftopEquipment)
    }

    private func buildPlayerWarehouse(
        _ c: AssetBuildContext,
        logistics: Bool,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .playerPaving)
        let height = c.height * 0.78
        addBox(to: root, width: c.width * 0.78, height: height, depth: c.depth * 0.62,
               x: 0, y: height / 2, z: -c.depth * 0.08, material: .playerWall)
        addBox(to: root, width: c.width * 0.82, height: 0.9, depth: c.depth * 0.66,
               x: 0, y: height + 0.45, z: -c.depth * 0.08, material: .playerNavy)
        let doors = logistics ? 4 : 2
        for index in 0..<doors {
            let x = (Float(index) - Float(doors - 1) / 2) * c.width * 0.16
            addBox(to: near, width: c.width * 0.12, height: height * 0.48, depth: 0.7,
                   x: x, y: height * 0.24, z: c.depth * 0.235, material: .loadingDoor)
        }
        addTruck(to: props, x: c.width * 0.24, z: c.depth * 0.34)
    }

    private func buildPlayerAuction(
        _ c: AssetBuildContext,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .playerPaving)
        let height = c.height * 0.76
        addBox(to: root, width: c.width * 0.76, height: height, depth: c.depth * 0.50,
               x: 0, y: height / 2, z: -c.depth * 0.20, material: .playerWall)
        addGable(to: root, width: c.width * 0.80, depth: c.depth * 0.54, height: 3.0,
                 x: 0, y: height, z: -c.depth * 0.20, material: .playerNavy)
        addBox(to: root, width: c.width * 0.70, height: 1.0, depth: c.depth * 0.20,
               x: 0, y: 5.8, z: c.depth * 0.20, material: .playerNavy)
        for x in [-c.width * 0.30, 0, c.width * 0.30] {
            addBox(to: root, width: 0.8, height: 5.8, depth: 0.8,
                   x: x, y: 2.9, z: c.depth * 0.20, material: .metalLight)
            addParkedCar(to: props, x: x, z: c.depth * 0.34, color: .vehicleNeutral)
        }
        addBlankSign(to: near, x: 0, y: height * 0.64, z: c.depth * 0.055,
                     width: c.width * 0.30, material: .playerAccent)
    }

    private func addGround(to parent: SCNNode, c: AssetBuildContext, material: AssetMaterialKey) {
        addBox(to: parent, width: c.width, height: 0.20, depth: c.depth,
               x: 0, y: 0.10, z: 0, material: material, chamfer: 0.35)
    }

    private func addFacadeStrip(to parent: SCNNode, width: Float, height: Float, z: Float, y: Float) {
        addBox(to: parent, width: width, height: height, depth: 0.35,
               x: 0, y: y, z: z, material: .windowBlue)
    }

    private func addBlankSign(
        to parent: SCNNode,
        x: Float,
        y: Float,
        z: Float,
        width: Float,
        material: AssetMaterialKey
    ) {
        addBox(to: parent, width: max(2, width), height: max(1.4, width * 0.22), depth: 0.55,
               x: x, y: y, z: z, material: material, chamfer: 0.25)
    }

    private func addPylonSign(
        to parent: SCNNode,
        c: AssetBuildContext,
        x: Float,
        z: Float,
        height: Float,
        material: AssetMaterialKey
    ) {
        let clampedHeight = min(c.height * 1.05, max(4.5, height))
        addCylinder(to: parent, radius: 0.32, height: clampedHeight,
                    x: x, y: clampedHeight / 2, z: z, material: .streetMetal)
        addBox(to: parent, width: min(8, max(3, c.width * 0.18)), height: 2.4, depth: 0.75,
               x: x, y: clampedHeight * 0.82, z: z, material: material, chamfer: 0.35)
    }

    private func addTree(to parent: SCNNode, x: Float, z: Float, scale: Float) {
        addCylinder(to: parent, radius: 0.55 * scale, height: 3.8 * scale,
                    x: x, y: 1.9 * scale, z: z, material: .treeTrunk)
        addPyramid(to: parent, width: 4.0 * scale, height: 5.0 * scale, length: 4.0 * scale,
                   x: x, y: 5.2 * scale, z: z, material: .treeLeaf)
    }

    private func addHedge(to parent: SCNNode, width: Float, x: Float, z: Float) {
        addBox(to: parent, width: width, height: 1.3, depth: 1.2,
               x: x, y: 0.65, z: z, material: .hedge, chamfer: 0.3)
    }

    private func addStreetLight(to parent: SCNNode, x: Float, z: Float) {
        addCylinder(to: parent, radius: 0.22, height: 5.5, x: x, y: 2.75, z: z, material: .streetMetal)
        addBox(to: parent, width: 1.2, height: 0.35, depth: 0.8,
               x: x, y: 5.55, z: z, material: .lampLight)
    }

    private func addFence(to parent: SCNNode, width: Float, x: Float, z: Float) {
        addBox(to: parent, width: width, height: 1.3, depth: 0.28,
               x: x, y: 0.65, z: z, material: .fenceMetal)
    }

    private func addParkedCar(to parent: SCNNode, x: Float, z: Float, color: AssetMaterialKey) {
        addBox(to: parent, width: 3.2, height: 1.0, depth: 5.6,
               x: x, y: 0.60, z: z, material: color, chamfer: 0.65)
        addBox(to: parent, width: 2.7, height: 0.8, depth: 2.8,
               x: x, y: 1.45, z: z - 0.3, material: .vehicleGlass, chamfer: 0.45)
    }

    private func addTruck(to parent: SCNNode, x: Float, z: Float) {
        addBox(to: parent, width: 4.2, height: 2.7, depth: 8.4,
               x: x, y: 1.45, z: z, material: .truckWhite, chamfer: 0.35)
        addBox(to: parent, width: 4.0, height: 2.4, depth: 2.4,
               x: x, y: 1.30, z: z + 4.2, material: .vehicleBlue, chamfer: 0.45)
    }

    private func addBox(
        to parent: SCNNode,
        width: Float,
        height: Float,
        depth: Float,
        x: Float,
        y: Float,
        z: Float,
        material: AssetMaterialKey,
        chamfer: Float = 0.25
    ) {
        let node = SCNNode(geometry: resources.box(
            width: max(0.05, width),
            height: max(0.05, height),
            depth: max(0.05, depth),
            chamfer: max(0, chamfer),
            material: material
        ))
        node.position = SCNVector3(x, y, z)
        parent.addChildNode(node)
    }

    private func addCylinder(
        to parent: SCNNode,
        radius: Float,
        height: Float,
        x: Float,
        y: Float,
        z: Float,
        material: AssetMaterialKey
    ) {
        let node = SCNNode(geometry: resources.cylinder(radius: radius, height: height, material: material))
        node.position = SCNVector3(x, y, z)
        parent.addChildNode(node)
    }

    private func addPyramid(
        to parent: SCNNode,
        width: Float,
        height: Float,
        length: Float,
        x: Float,
        y: Float,
        z: Float,
        material: AssetMaterialKey
    ) {
        let node = SCNNode(geometry: resources.pyramid(width: width, height: height, length: length, material: material))
        node.position = SCNVector3(x, y, z)
        parent.addChildNode(node)
    }

    private func addGable(
        to parent: SCNNode,
        width: Float,
        depth: Float,
        height: Float,
        x: Float,
        y: Float,
        z: Float,
        material: AssetMaterialKey
    ) {
        let node = SCNNode(geometry: resources.gable(width: width, depth: depth, height: height, material: material))
        node.position = SCNVector3(x, y, z)
        parent.addChildNode(node)
    }

    private func rotation(for direction: CardinalDirection) -> Float {
        switch direction {
        case .south: 0
        case .east: .pi / 2
        case .north: .pi
        case .west: -.pi / 2
        }
    }
}

private struct AssetBuildContext {
    let width: Float
    let depth: Float
    let height: Float
}

private enum AssetMaterialKey: String, Hashable {
    case residentialGarden, luxuryGarden, pavement, industrialPavement, downtownPaving, parkingAsphalt
    case residentialWarm, residentialCool, residentialLight, luxuryStone, luxuryLight, garageGray
    case commercialLight, commercialGlass, commercialAccent, commercialCanopy
    case industrialWall, factoryBlue, metalLight, loadingDoor, smokestackBrick
    case downtownWall, officeBlue, storefrontDark, parkingConcrete, roadsideWarm, roadsideAccent
    case roofBrown, roofSlate, roofLight, roofMetal, windowBlue, woodAccent, poolBlue
    case playerPaving, playerWall, playerNavy, playerAccent, bodyShopWall, wetPaving
    case parkingLine, rooftopEquipment, treeTrunk, treeLeaf, hedge, streetMetal, lampLight, fenceMetal
    case vehicleBlue, vehicleNeutral, vehicleGlass, truckWhite

    var color: UIColor {
        switch self {
        case .residentialGarden: UIColor(red: 0.38, green: 0.66, blue: 0.36, alpha: 1)
        case .luxuryGarden: UIColor(red: 0.32, green: 0.69, blue: 0.35, alpha: 1)
        case .pavement: UIColor(red: 0.42, green: 0.47, blue: 0.48, alpha: 1)
        case .industrialPavement: UIColor(red: 0.39, green: 0.41, blue: 0.40, alpha: 1)
        case .downtownPaving: UIColor(red: 0.46, green: 0.45, blue: 0.47, alpha: 1)
        case .parkingAsphalt: UIColor(red: 0.25, green: 0.27, blue: 0.28, alpha: 1)
        case .residentialWarm: UIColor(red: 0.88, green: 0.61, blue: 0.40, alpha: 1)
        case .residentialCool: UIColor(red: 0.56, green: 0.69, blue: 0.76, alpha: 1)
        case .residentialLight: UIColor(red: 0.90, green: 0.82, blue: 0.67, alpha: 1)
        case .luxuryStone: UIColor(red: 0.78, green: 0.73, blue: 0.64, alpha: 1)
        case .luxuryLight: UIColor(red: 0.94, green: 0.87, blue: 0.70, alpha: 1)
        case .garageGray: UIColor(red: 0.51, green: 0.53, blue: 0.52, alpha: 1)
        case .commercialLight: UIColor(red: 0.82, green: 0.78, blue: 0.66, alpha: 1)
        case .commercialGlass: UIColor(red: 0.18, green: 0.56, blue: 0.70, alpha: 1)
        case .commercialAccent: UIColor(red: 0.87, green: 0.29, blue: 0.14, alpha: 1)
        case .commercialCanopy: UIColor(red: 0.95, green: 0.63, blue: 0.12, alpha: 1)
        case .industrialWall: UIColor(red: 0.47, green: 0.54, blue: 0.58, alpha: 1)
        case .factoryBlue: UIColor(red: 0.29, green: 0.53, blue: 0.65, alpha: 1)
        case .metalLight: UIColor(red: 0.68, green: 0.70, blue: 0.69, alpha: 1)
        case .loadingDoor: UIColor(red: 0.25, green: 0.28, blue: 0.29, alpha: 1)
        case .smokestackBrick: UIColor(red: 0.49, green: 0.32, blue: 0.27, alpha: 1)
        case .downtownWall: UIColor(red: 0.57, green: 0.49, blue: 0.67, alpha: 1)
        case .officeBlue: UIColor(red: 0.28, green: 0.52, blue: 0.68, alpha: 1)
        case .storefrontDark: UIColor(red: 0.23, green: 0.29, blue: 0.32, alpha: 1)
        case .parkingConcrete: UIColor(red: 0.54, green: 0.53, blue: 0.52, alpha: 1)
        case .roadsideWarm: UIColor(red: 0.76, green: 0.51, blue: 0.29, alpha: 1)
        case .roadsideAccent: UIColor(red: 0.80, green: 0.25, blue: 0.12, alpha: 1)
        case .roofBrown: UIColor(red: 0.56, green: 0.27, blue: 0.17, alpha: 1)
        case .roofSlate: UIColor(red: 0.18, green: 0.28, blue: 0.34, alpha: 1)
        case .roofLight: UIColor(red: 0.71, green: 0.72, blue: 0.69, alpha: 1)
        case .roofMetal: UIColor(red: 0.40, green: 0.44, blue: 0.45, alpha: 1)
        case .windowBlue: UIColor(red: 0.12, green: 0.47, blue: 0.62, alpha: 1)
        case .woodAccent: UIColor(red: 0.55, green: 0.35, blue: 0.22, alpha: 1)
        case .poolBlue: UIColor(red: 0.24, green: 0.68, blue: 0.76, alpha: 1)
        case .playerPaving: UIColor(red: 0.39, green: 0.45, blue: 0.44, alpha: 1)
        case .playerWall: UIColor(red: 0.67, green: 0.75, blue: 0.72, alpha: 1)
        case .playerNavy: UIColor(red: 0.10, green: 0.25, blue: 0.32, alpha: 1)
        case .playerAccent: UIColor(red: 0.12, green: 0.58, blue: 0.54, alpha: 1)
        case .bodyShopWall: UIColor(red: 0.64, green: 0.70, blue: 0.69, alpha: 1)
        case .wetPaving: UIColor(red: 0.32, green: 0.46, blue: 0.49, alpha: 1)
        case .parkingLine: UIColor(red: 0.88, green: 0.85, blue: 0.67, alpha: 1)
        case .rooftopEquipment: UIColor(red: 0.38, green: 0.40, blue: 0.40, alpha: 1)
        case .treeTrunk: UIColor(red: 0.34, green: 0.23, blue: 0.14, alpha: 1)
        case .treeLeaf: UIColor(red: 0.19, green: 0.55, blue: 0.24, alpha: 1)
        case .hedge: UIColor(red: 0.22, green: 0.58, blue: 0.23, alpha: 1)
        case .streetMetal, .fenceMetal: UIColor(red: 0.28, green: 0.31, blue: 0.32, alpha: 1)
        case .lampLight: UIColor(red: 0.90, green: 0.84, blue: 0.56, alpha: 1)
        case .vehicleBlue: UIColor(red: 0.19, green: 0.44, blue: 0.62, alpha: 1)
        case .vehicleNeutral: UIColor(red: 0.69, green: 0.69, blue: 0.66, alpha: 1)
        case .vehicleGlass: UIColor(red: 0.15, green: 0.26, blue: 0.31, alpha: 1)
        case .truckWhite: UIColor(red: 0.78, green: 0.79, blue: 0.76, alpha: 1)
        }
    }
}

@MainActor
private final class LowPolyAssetResources {
    private struct BoxKey: Hashable {
        let width: Int
        let height: Int
        let depth: Int
        let chamfer: Int
        let material: AssetMaterialKey
    }

    private struct ShapeKey: Hashable {
        let kind: String
        let a: Int
        let b: Int
        let c: Int
        let material: AssetMaterialKey
    }

    private var materials: [AssetMaterialKey: SCNMaterial] = [:]
    private var boxes: [BoxKey: SCNGeometry] = [:]
    private var shapes: [ShapeKey: SCNGeometry] = [:]

    func box(width: Float, height: Float, depth: Float, chamfer: Float, material: AssetMaterialKey) -> SCNGeometry {
        let key = BoxKey(
            width: quantize(width),
            height: quantize(height),
            depth: quantize(depth),
            chamfer: quantize(chamfer),
            material: material
        )
        if let geometry = boxes[key] { return geometry }
        let geometry = SCNBox(
            width: CGFloat(width),
            height: CGFloat(height),
            length: CGFloat(depth),
            chamferRadius: CGFloat(min(chamfer, min(width, height, depth) * 0.20))
        )
        geometry.chamferSegmentCount = 1
        geometry.firstMaterial = self.material(material)
        boxes[key] = geometry
        return geometry
    }

    func cylinder(radius: Float, height: Float, material: AssetMaterialKey) -> SCNGeometry {
        let key = ShapeKey(kind: "cylinder", a: quantize(radius), b: quantize(height), c: 0, material: material)
        if let geometry = shapes[key] { return geometry }
        let geometry = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        geometry.radialSegmentCount = 8
        geometry.heightSegmentCount = 1
        geometry.firstMaterial = self.material(material)
        shapes[key] = geometry
        return geometry
    }

    func pyramid(width: Float, height: Float, length: Float, material: AssetMaterialKey) -> SCNGeometry {
        let key = ShapeKey(kind: "pyramid", a: quantize(width), b: quantize(height), c: quantize(length), material: material)
        if let geometry = shapes[key] { return geometry }
        let geometry = SCNPyramid(
            width: CGFloat(width),
            height: CGFloat(height),
            length: CGFloat(length)
        )
        geometry.widthSegmentCount = 1
        geometry.heightSegmentCount = 1
        geometry.lengthSegmentCount = 1
        geometry.firstMaterial = self.material(material)
        shapes[key] = geometry
        return geometry
    }

    func gable(width: Float, depth: Float, height: Float, material: AssetMaterialKey) -> SCNGeometry {
        let key = ShapeKey(kind: "gable", a: quantize(width), b: quantize(depth), c: quantize(height), material: material)
        if let geometry = shapes[key] { return geometry }
        let halfWidth = width / 2
        let halfDepth = depth / 2
        let sourceVertices: [SCNVector3] = [
            .init(-halfWidth, 0, -halfDepth), .init(halfWidth, 0, -halfDepth), .init(0, height, -halfDepth),
            .init(-halfWidth, 0, halfDepth), .init(halfWidth, 0, halfDepth), .init(0, height, halfDepth)
        ]
        let sourceIndices: [UInt32] = [
            0, 2, 1, 3, 4, 5,
            0, 3, 5, 0, 5, 2,
            1, 2, 5, 1, 5, 4,
            0, 1, 4, 0, 4, 3
        ]
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt32] = []
        for triangleStart in stride(from: 0, to: sourceIndices.count, by: 3) {
            let a = sourceVertices[Int(sourceIndices[triangleStart])]
            let b = sourceVertices[Int(sourceIndices[triangleStart + 1])]
            let c = sourceVertices[Int(sourceIndices[triangleStart + 2])]
            let ab = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
            let ac = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
            let cross = SCNVector3(
                ab.y * ac.z - ab.z * ac.y,
                ab.z * ac.x - ab.x * ac.z,
                ab.x * ac.y - ab.y * ac.x
            )
            let length = max(0.0001, sqrt(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z))
            let normal = SCNVector3(cross.x / length, cross.y / length, cross.z / length)
            let start = UInt32(vertices.count)
            vertices.append(contentsOf: [a, b, c])
            normals.append(contentsOf: [normal, normal, normal])
            indices.append(contentsOf: [start, start + 1, start + 2])
        }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.firstMaterial = self.material(material)
        shapes[key] = geometry
        return geometry
    }

    private func material(_ key: AssetMaterialKey) -> SCNMaterial {
        if let material = materials[key] { return material }
        let material = SCNMaterial()
        material.name = key.rawValue
        material.diffuse.contents = key.color
        material.roughness.contents = 0.88
        material.metalness.contents = 0
        material.lightingModel = .physicallyBased
        material.isDoubleSided = false
        materials[key] = material
        return material
    }

    private func quantize(_ value: Float) -> Int { Int((value * 100).rounded()) }
}
