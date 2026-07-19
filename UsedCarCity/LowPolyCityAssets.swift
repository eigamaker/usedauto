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
        let authoredHeight = max(1, heightHint ?? definition.nominalHeight)
        // The city uses deliberately broad four-cell parcels.  A realistic
        // metre-for-metre height makes low-rise buildings look like coloured
        // floor tiles from the fixed camera, so low-rise categories use a
        // controlled vertical exaggeration while their grid footprint stays
        // exact.  Downtown towers already have sufficient height.
        let height = authoredHeight * visualHeightScale(for: definition.category)
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

    private func visualHeightScale(for category: CityAssetCategory) -> Float {
        switch category {
        case .generalResidential: 1.80
        case .luxuryResidential: 1.70
        case .commercial: 1.45
        case .industrial: 1.20
        case .highway: 1.30
        case .playerFacility: 1.30
        case .downtown, .parking: 1.00
        }
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
            addFlowerBed(to: props, width: c.width * 0.20, x: -c.width * 0.22, z: c.depth * 0.40)
        case .luxuryResidential:
            addBox(to: root, width: c.width * 0.24, height: 0.12, depth: c.depth * 0.74,
                   x: c.width * 0.27, y: 0.06, z: c.depth * 0.08, material: .pavement, chamfer: 0.7)
            addBox(to: near, width: c.width * 0.24, height: 0.16, depth: c.depth * 0.22,
                   x: -c.width * 0.27, y: 0.08, z: c.depth * 0.30, material: .poolBlue, chamfer: 0.8)
            addHedge(to: props, width: c.width * 0.76, x: 0, z: -c.depth * 0.45)
            addTree(to: props, x: -c.width * 0.40, z: -c.depth * 0.31, scale: 0.94)
            addTree(to: props, x: c.width * 0.40, z: c.depth * 0.33, scale: 0.90)
            addFlowerBed(to: props, width: c.width * 0.24, x: 0, z: c.depth * 0.41)
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
            addFlowerBed(to: props, width: c.width * 0.18, x: c.width * 0.22, z: c.depth * 0.40)
        case .highway:
            addBox(to: root, width: c.width * 0.92, height: 0.12, depth: c.depth * 0.42,
                   x: 0, y: 0.06, z: c.depth * 0.25, material: .parkingAsphalt, chamfer: 0.55)
            addParkingBayLines(to: near, props: props, c: c, carCount: 3)
            addTruck(to: props, x: -c.width * 0.30, z: c.depth * 0.25)
        case .parking, .playerFacility:
            // Player facilities often occupy only part of a purchased parcel.
            // Fill the authoritative parcel rect with a deliberate forecourt
            // instead of stretching the building beyond its grid footprint.
            addBox(to: root, width: c.width * 0.96, height: 0.12, depth: c.depth * 0.92,
                   x: 0, y: 0.06, z: 0, material: .parkingAsphalt, chamfer: 0.55)
            addParkingBayLines(to: near, props: props, c: c, carCount: 4)
            addStreetLight(to: props, x: -c.width * 0.42, z: c.depth * 0.37)
            addStreetLight(to: props, x: c.width * 0.42, z: c.depth * 0.37)
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
        addGround(to: root, c: c, material: .residentialLot)
        // A house parcel reads as a built block first.  Green is kept to small
        // planted beds, never used as a full-size lawn around a miniature box.
        addGardenBed(to: root, width: c.width * 0.16, depth: c.depth * 0.23,
                     x: -c.width * 0.39, z: c.depth * 0.28)
        addGardenBed(to: root, width: c.width * 0.12, depth: c.depth * 0.20,
                     x: c.width * 0.39, z: -c.depth * 0.32)
        addBox(to: root, width: c.width * 0.88, height: 0.14, depth: c.depth * 0.14,
               x: 0, y: 0.27, z: c.depth * 0.38, material: .pavement, chamfer: 0.25)
        let bodyHeight = variant == 4 ? c.height * 0.88 : c.height * 0.78
        switch variant {
        case 0: // Cottage: compact main house, projecting entry and a real porch.
            addBox(to: root, width: c.width * 0.78, height: bodyHeight, depth: c.depth * 0.74,
                   x: -c.width * 0.06, y: bodyHeight / 2, z: -c.depth * 0.08,
                   material: .residentialWarm)
            addHippedRoof(to: root, width: c.width * 0.82, depth: c.depth * 0.78, height: c.height * 0.30,
                          x: -c.width * 0.06, y: bodyHeight, z: -c.depth * 0.08, material: .roofBrown)
            addDormer(to: root, width: c.width * 0.16, depth: c.depth * 0.20,
                      x: -c.width * 0.16, baseY: bodyHeight + c.height * 0.08,
                      z: c.depth * 0.08, roofMaterial: .roofBrown)
            let entryHeight = bodyHeight * 0.58
            addBox(to: root, width: c.width * 0.34, height: entryHeight, depth: c.depth * 0.42,
                   x: c.width * 0.24, y: entryHeight / 2, z: c.depth * 0.22,
                   material: .residentialLight)
            addGable(to: root, width: c.depth * 0.46, depth: c.width * 0.38, height: c.height * 0.22,
                     x: c.width * 0.24, y: entryHeight, z: c.depth * 0.22,
                     material: .roofBrown, rotationY: .pi / 2)
            addPorch(to: root, width: c.width * 0.48, depth: c.depth * 0.13,
                     x: -c.width * 0.10, z: c.depth * 0.40, roofY: bodyHeight * 0.58,
                     roofMaterial: .roofBrown)
        case 1: // Family house: L-shaped plan and crossing roof ridges.
            addBox(to: root, width: c.width * 0.70, height: bodyHeight, depth: c.depth * 0.76,
                   x: -c.width * 0.10, y: bodyHeight / 2, z: -c.depth * 0.06,
                   material: .residentialCool)
            addHippedRoof(to: root, width: c.width * 0.74, depth: c.depth * 0.80, height: c.height * 0.32,
                          x: -c.width * 0.10, y: bodyHeight, z: -c.depth * 0.06, material: .roofGreen)
            addDormer(to: root, width: c.width * 0.15, depth: c.depth * 0.22,
                      x: -c.width * 0.20, baseY: bodyHeight + c.height * 0.08,
                      z: c.depth * 0.10, roofMaterial: .roofGreen)
            let wingHeight = bodyHeight * 0.78
            addBox(to: root, width: c.width * 0.36, height: wingHeight, depth: c.depth * 0.52,
                   x: c.width * 0.28, y: wingHeight / 2, z: c.depth * 0.12,
                   material: .residentialLight)
            addGable(to: root, width: c.depth * 0.56, depth: c.width * 0.40, height: c.height * 0.24,
                     x: c.width * 0.28, y: wingHeight, z: c.depth * 0.12,
                     material: .roofOrange, rotationY: .pi / 2)
            addPorch(to: root, width: c.width * 0.34, depth: c.depth * 0.14,
                     x: -c.width * 0.12, z: c.depth * 0.40, roofY: bodyHeight * 0.55,
                     roofMaterial: .roofGreen)
        case 2: // Modern split-level: offset volumes, parapets and a roof terrace.
            let lowerHeight = bodyHeight * 0.56
            let upperHeight = bodyHeight * 0.62
            addBox(to: root, width: c.width * 0.92, height: lowerHeight, depth: c.depth * 0.80,
                   x: 0, y: lowerHeight / 2, z: -c.depth * 0.05, material: .residentialLight)
            addBox(to: root, width: c.width * 0.68, height: upperHeight, depth: c.depth * 0.60,
                   x: -c.width * 0.10, y: lowerHeight + upperHeight / 2,
                   z: -c.depth * 0.12, material: .residentialCool)
            addBox(to: root, width: c.width * 0.72, height: 0.62, depth: c.depth * 0.64,
                   x: -c.width * 0.10, y: lowerHeight + upperHeight + 0.31,
                   z: -c.depth * 0.12, material: .roofOrange)
            addBox(to: root, width: c.width * 0.30, height: lowerHeight * 0.82, depth: c.depth * 0.46,
                   x: c.width * 0.29, y: lowerHeight * 0.41, z: c.depth * 0.20,
                   material: .woodAccent)
            addBox(to: near, width: c.width * 0.22, height: 0.36, depth: c.depth * 0.38,
                   x: c.width * 0.25, y: lowerHeight + 0.18, z: c.depth * 0.10,
                   material: .roofSlate)
        case 3: // Duplex: two independently readable homes sharing one lot.
            let halfWidth = c.width * 0.46
            for x in [-c.width * 0.23, c.width * 0.23] {
                addBox(to: root, width: halfWidth, height: bodyHeight, depth: c.depth * 0.80,
                       x: x, y: bodyHeight / 2, z: -c.depth * 0.05, material: .residentialWarm)
                addHippedRoof(to: root, width: halfWidth * 1.04, depth: c.depth * 0.84, height: c.height * 0.24,
                              x: x, y: bodyHeight, z: -c.depth * 0.05, material: .roofBrown)
                addBox(to: root, width: halfWidth * 0.34, height: 0.14, depth: c.depth * 0.26,
                       x: x, y: bodyHeight + c.height * 0.15, z: -c.depth * 0.08,
                       material: .windowBlue, chamfer: 0.06)
                addBox(to: root, width: halfWidth * 0.72, height: 0.42, depth: c.depth * 0.15,
                       x: x, y: bodyHeight * 0.54, z: c.depth * 0.40, material: .roofGreen)
            }
        default: // Small apartment: podium, recessed upper floors and balconies.
            let podiumHeight = bodyHeight * 0.30
            let upperHeight = bodyHeight * 0.78
            addBox(to: root, width: c.width * 0.94, height: podiumHeight, depth: c.depth * 0.88,
                   x: 0, y: podiumHeight / 2, z: c.depth * 0.02, material: .residentialWarm)
            addBox(to: root, width: c.width * 0.76, height: upperHeight, depth: c.depth * 0.72,
                   x: -c.width * 0.06, y: podiumHeight + upperHeight / 2,
                   z: -c.depth * 0.08, material: .residentialCool)
            addBox(to: root, width: c.width * 0.80, height: 0.70, depth: c.depth * 0.76,
                   x: -c.width * 0.06, y: podiumHeight + upperHeight + 0.35,
                   z: -c.depth * 0.08, material: .roofBlue)
            for level in [podiumHeight + upperHeight * 0.34, podiumHeight + upperHeight * 0.70] {
                addBox(to: near, width: c.width * 0.48, height: 0.38, depth: 1.9,
                       x: -c.width * 0.06, y: level, z: c.depth * 0.255, material: .roofSlate)
                for x in [-c.width * 0.26, c.width * 0.14] {
                    addBox(to: near, width: 0.38, height: 1.25, depth: 0.38,
                           x: x, y: level + 0.52, z: c.depth * 0.29, material: .metalLight)
                }
            }
        }
        if variant == 0 || variant == 1 {
            addBox(to: root, width: 1.4, height: c.height * 0.38, depth: 1.4,
                   x: c.width * 0.22, y: bodyHeight + c.height * 0.12,
                   z: -c.depth * 0.18, material: .smokestackBrick)
        }
        addHouseFacadeDetails(
            to: near,
            c: c,
            bodyHeight: bodyHeight,
            levels: variant == 4 ? 2 : 1,
            accent: variant.isMultiple(of: 2) ? .roofBrown : .roofSlate
        )
        addTree(to: props, x: -c.width * 0.42, z: c.depth * 0.40, scale: 0.55)
        addHedge(to: props, width: c.width * 0.24, x: c.width * 0.30, z: c.depth * 0.43)
    }

    private func buildLuxury(
        _ c: AssetBuildContext,
        variant: Int,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .luxuryLot)
        addGardenBed(to: root, width: c.width * 0.20, depth: c.depth * 0.26,
                     x: -c.width * 0.37, z: c.depth * 0.27)
        addGardenBed(to: root, width: c.width * 0.14, depth: c.depth * 0.20,
                     x: c.width * 0.37, z: -c.depth * 0.31)
        addBox(to: root, width: c.width * 0.86, height: 0.14, depth: c.depth * 0.14,
               x: 0, y: 0.27, z: c.depth * 0.38, material: .pavement, chamfer: 0.25)
        addBox(to: root, width: c.width * 0.14, height: 0.14, depth: c.depth * 0.72,
               x: c.width * 0.39, y: 0.27, z: c.depth * 0.04, material: .pavement, chamfer: 0.25)
        let mainHeight = c.height * 0.80
        switch variant {
        case 0: // Courtyard villa: three masses frame a readable front court.
            addBox(to: root, width: c.width * 0.70, height: mainHeight, depth: c.depth * 0.56,
                   x: 0, y: mainHeight / 2, z: -c.depth * 0.16, material: .luxuryStone)
            addHippedRoof(to: root, width: c.width * 0.74, depth: c.depth * 0.60, height: 2.6,
                          x: 0, y: mainHeight, z: -c.depth * 0.16, material: .roofBrown)
            addDormer(to: root, width: c.width * 0.16, depth: c.depth * 0.18,
                      x: -c.width * 0.18, baseY: mainHeight + 0.26,
                      z: c.depth * 0.05, roofMaterial: .roofBrown)
            let wingHeight = mainHeight * 0.72
            for x in [-c.width * 0.31, c.width * 0.31] {
                addBox(to: root, width: c.width * 0.25, height: wingHeight, depth: c.depth * 0.42,
                       x: x, y: wingHeight / 2, z: c.depth * 0.12, material: .luxuryLight)
                addGable(to: root, width: c.depth * 0.46, depth: c.width * 0.28, height: 1.9,
                         x: x, y: wingHeight, z: c.depth * 0.12,
                         material: .roofOrange, rotationY: .pi / 2)
            }
            addBox(to: root, width: c.width * 0.34, height: 0.20, depth: c.depth * 0.24,
                   x: 0, y: 0.22, z: c.depth * 0.25, material: .pavement, chamfer: 0.5)
        case 1: // Garage residence: house, garage and entry tower are separate silhouettes.
            addBox(to: root, width: c.width * 0.62, height: mainHeight, depth: c.depth * 0.62,
                   x: -c.width * 0.12, y: mainHeight / 2, z: -c.depth * 0.12, material: .luxuryLight)
            addHippedRoof(to: root, width: c.width * 0.66, depth: c.depth * 0.66, height: 2.7,
                          x: -c.width * 0.12, y: mainHeight, z: -c.depth * 0.12, material: .roofGreen)
            addDormer(to: root, width: c.width * 0.15, depth: c.depth * 0.18,
                      x: -c.width * 0.24, baseY: mainHeight + 0.26,
                      z: c.depth * 0.05, roofMaterial: .roofGreen)
            let garageHeight = mainHeight * 0.62
            addBox(to: root, width: c.width * 0.34, height: garageHeight, depth: c.depth * 0.44,
                   x: c.width * 0.29, y: garageHeight / 2, z: c.depth * 0.14, material: .garageGray)
            addGable(to: root, width: c.depth * 0.48, depth: c.width * 0.38, height: 2.0,
                     x: c.width * 0.29, y: garageHeight, z: c.depth * 0.14,
                     material: .roofGreen, rotationY: .pi / 2)
            addBox(to: root, width: c.width * 0.17, height: mainHeight * 1.12, depth: c.depth * 0.22,
                   x: c.width * 0.21, y: mainHeight * 0.56, z: -c.depth * 0.12,
                   material: .luxuryStone)
            addBox(to: near, width: c.width * 0.25, height: garageHeight * 0.58, depth: 0.58,
                   x: c.width * 0.29, y: garageHeight * 0.29, z: c.depth * 0.365, material: .garageGray)
        case 2: // Pool house: modern stacked L-shape and an exposed terrace.
            let lowerHeight = mainHeight * 0.64
            let upperHeight = mainHeight * 0.72
            addBox(to: root, width: c.width * 0.82, height: lowerHeight, depth: c.depth * 0.50,
                   x: 0, y: lowerHeight / 2, z: -c.depth * 0.20, material: .luxuryLight)
            addBox(to: root, width: c.width * 0.34, height: lowerHeight, depth: c.depth * 0.42,
                   x: c.width * 0.27, y: lowerHeight / 2, z: c.depth * 0.18, material: .luxuryStone)
            addBox(to: root, width: c.width * 0.54, height: upperHeight, depth: c.depth * 0.42,
                   x: -c.width * 0.10, y: lowerHeight + upperHeight / 2,
                   z: -c.depth * 0.19, material: .luxuryStone)
            addBox(to: root, width: c.width * 0.58, height: 0.70, depth: c.depth * 0.46,
                   x: -c.width * 0.10, y: lowerHeight + upperHeight + 0.35,
                   z: -c.depth * 0.19, material: .roofBlue)
            addBox(to: root, width: c.width * 0.42, height: 0.24, depth: c.depth * 0.24,
                   x: -c.width * 0.12, y: 0.20, z: c.depth * 0.31, material: .poolBlue, chamfer: 0.5)
            addBox(to: near, width: c.width * 0.34, height: 0.42, depth: c.depth * 0.22,
                   x: c.width * 0.12, y: lowerHeight + 0.21, z: c.depth * 0.07, material: .roofLight)
        default: // Terrace house: broad lower level, offset upper floor and pergola.
            let lowerHeight = mainHeight * 0.62
            let upperHeight = mainHeight * 0.70
            addBox(to: root, width: c.width * 0.84, height: lowerHeight, depth: c.depth * 0.64,
                   x: 0, y: lowerHeight / 2, z: -c.depth * 0.08, material: .luxuryStone)
            addBox(to: root, width: c.width * 0.58, height: upperHeight, depth: c.depth * 0.48,
                   x: -c.width * 0.09, y: lowerHeight + upperHeight / 2,
                   z: -c.depth * 0.16, material: .luxuryLight)
            addBox(to: root, width: c.width * 0.62, height: 0.75, depth: c.depth * 0.52,
                   x: -c.width * 0.09, y: lowerHeight + upperHeight + 0.375,
                   z: -c.depth * 0.16, material: .roofOrange)
            let pergolaY = lowerHeight + 1.15
            for x in [c.width * 0.12, c.width * 0.26, c.width * 0.40] {
                addBox(to: near, width: 0.55, height: 0.42, depth: c.depth * 0.28,
                       x: x, y: pergolaY, z: c.depth * 0.18, material: .woodAccent)
            }
            for x in [c.width * 0.12, c.width * 0.40] {
                addBox(to: near, width: 0.48, height: lowerHeight, depth: 0.48,
                       x: x, y: lowerHeight / 2, z: c.depth * 0.30, material: .roofLight)
            }
        }
        if variant == 0 {
            addPorch(to: root, width: c.width * 0.26, depth: c.depth * 0.13,
                     x: 0, z: c.depth * 0.36, roofY: mainHeight * 0.54, roofMaterial: .roofBrown)
        } else if variant == 3 {
            addBox(to: root, width: c.width * 0.78, height: 0.75, depth: c.depth * 0.64,
                   x: 0, y: 0.375, z: -c.depth * 0.08, material: .pavement)
        }
        addHouseFacadeDetails(
            to: near,
            c: c,
            bodyHeight: mainHeight,
            levels: variant == 2 || variant == 3 ? 2 : 1,
            accent: variant.isMultiple(of: 2) ? .roofBrown : .roofGreen
        )
        addTree(to: props, x: -c.width * 0.42, z: c.depth * 0.40, scale: 0.62)
        addHedge(to: props, width: c.width * 0.28, x: c.width * 0.24, z: c.depth * 0.43)
    }

    private func buildCommercial(
        _ c: AssetBuildContext,
        variant: Int,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        addGround(to: root, c: c, material: .pavement)
        let bodyHeight = c.height * (variant == 4 ? 0.88 : 0.72)

        switch variant {
        case 0: // Glass-fronted auto dealer with a stepped office/showroom mass.
            let officeHeight = bodyHeight
            let showroomHeight = bodyHeight * 0.58
            addBox(to: root, width: c.width * 0.82, height: officeHeight, depth: c.depth * 0.36,
                   x: 0, y: officeHeight / 2, z: -c.depth * 0.27, material: .commercialLight)
            addBox(to: root, width: c.width * 0.86, height: 0.75, depth: c.depth * 0.40,
                   x: 0, y: officeHeight + 0.375, z: -c.depth * 0.27, material: .roofBlue)
            addBox(to: root, width: c.width * 0.72, height: showroomHeight, depth: c.depth * 0.34,
                   x: -c.width * 0.06, y: showroomHeight / 2, z: c.depth * 0.10, material: .commercialGlass)
            addBox(to: root, width: c.width * 0.78, height: 0.70, depth: c.depth * 0.38,
                   x: -c.width * 0.06, y: showroomHeight + 0.35, z: c.depth * 0.10, material: .roofBlue)
            for x in [-c.width * 0.25, -c.width * 0.08, c.width * 0.09] {
                addBox(to: near, width: c.width * 0.13, height: showroomHeight * 0.62, depth: 0.48,
                       x: x, y: showroomHeight * 0.36, z: c.depth * 0.275, material: .windowBlue)
            }
        case 1: // Gas station: canopy, kiosk and freestanding pumps.
            addBox(to: root, width: c.width * 0.92, height: 1.0, depth: c.depth * 0.60,
                   x: 0, y: c.height * 0.70, z: c.depth * 0.03, material: .commercialCanopy)
            for x in [-c.width * 0.35, c.width * 0.35] {
                for z in [-c.depth * 0.19, c.depth * 0.19] {
                    addBox(to: root, width: 0.8, height: c.height * 0.68, depth: 0.8,
                           x: x, y: c.height * 0.34, z: z, material: .metalLight)
                }
            }
            addBox(to: root, width: c.width * 0.40, height: c.height * 0.55, depth: c.depth * 0.38,
                   x: c.width * 0.26, y: c.height * 0.275, z: -c.depth * 0.28, material: .commercialLight)
            addBox(to: root, width: c.width * 0.44, height: 0.55, depth: c.depth * 0.42,
                   x: c.width * 0.26, y: c.height * 0.55 + 0.275, z: -c.depth * 0.28,
                   material: .roofOrange)
            for x in [-c.width * 0.20, 0, c.width * 0.20] {
                addBox(to: near, width: 1.5, height: 2.4, depth: 1.5,
                       x: x, y: 1.2, z: c.depth * 0.03, material: .commercialAccent)
            }
        case 2: // Convenience store with a pitched roof and deep striped fascia.
            addBox(to: root, width: c.width * 0.90, height: bodyHeight, depth: c.depth * 0.58,
                   x: 0, y: bodyHeight / 2, z: -c.depth * 0.13, material: .commercialLight)
            addGable(to: root, width: c.width * 0.94, depth: c.depth * 0.62, height: 2.1,
                     x: 0, y: bodyHeight, z: -c.depth * 0.13, material: .roofOrange)
            addBox(to: root, width: c.width * 0.88, height: 0.72, depth: 1.7,
                   x: 0, y: bodyHeight * 0.70, z: c.depth * 0.185, material: .commercialAccent)
            for x in [-c.width * 0.28, -c.width * 0.09, c.width * 0.10, c.width * 0.29] {
                addBox(to: near, width: c.width * 0.15, height: bodyHeight * 0.44, depth: 0.50,
                       x: x, y: bodyHeight * 0.27, z: c.depth * 0.18, material: .commercialGlass)
            }
        case 3: // Restaurant: round dining hall, conical roof, kitchen wing and chimney.
            let diningRadius = min(c.width, c.depth) * 0.24
            let diningHeight = bodyHeight * 0.68
            addCylinder(to: root, radius: diningRadius, height: diningHeight,
                        x: -c.width * 0.13, y: diningHeight / 2, z: -c.depth * 0.04,
                        material: .residentialWarm)
            addCone(to: root, radius: diningRadius * 1.08, height: 3.2,
                    x: -c.width * 0.13, y: diningHeight + 1.6, z: -c.depth * 0.04, material: .roofGreen)
            addBox(to: root, width: c.width * 0.38, height: bodyHeight * 0.70, depth: c.depth * 0.48,
                   x: c.width * 0.27, y: bodyHeight * 0.35, z: -c.depth * 0.08, material: .commercialLight)
            addGable(to: root, width: c.depth * 0.52, depth: c.width * 0.42, height: 2.3,
                     x: c.width * 0.27, y: bodyHeight * 0.70, z: -c.depth * 0.08,
                     material: .roofBrown, rotationY: .pi / 2)
            addBox(to: root, width: 1.7, height: c.height * 0.72, depth: 1.7,
                   x: c.width * 0.23, y: c.height * 0.36, z: -c.depth * 0.18, material: .smokestackBrick)
            addBox(to: root, width: c.width * 0.58, height: 0.62, depth: 2.4,
                   x: -c.width * 0.10, y: diningHeight * 0.58, z: c.depth * 0.255, material: .commercialCanopy)
        case 4: // Small shopping block with a rear floor and front arcade wing.
            addBox(to: root, width: c.width * 0.92, height: bodyHeight, depth: c.depth * 0.42,
                   x: 0, y: bodyHeight / 2, z: -c.depth * 0.25, material: .commercialLight)
            addBox(to: root, width: c.width * 0.34, height: bodyHeight * 0.70, depth: c.depth * 0.44,
                   x: -c.width * 0.28, y: bodyHeight * 0.35, z: c.depth * 0.15, material: .officeBlue)
            addBox(to: root, width: c.width * 0.96, height: 0.75, depth: c.depth * 0.46,
                   x: 0, y: bodyHeight + 0.375, z: -c.depth * 0.25, material: .roofSlate)
            addBox(to: root, width: c.width * 0.38, height: 0.65, depth: c.depth * 0.48,
                   x: -c.width * 0.28, y: bodyHeight * 0.70 + 0.325, z: c.depth * 0.15,
                   material: .roofBlue)
            addBox(to: root, width: c.width * 0.80, height: 0.70, depth: 2.4,
                   x: c.width * 0.04, y: 4.6, z: c.depth * 0.20, material: .commercialCanopy)
            for x in [-c.width * 0.28, 0, c.width * 0.28] {
                addBox(to: root, width: 0.65, height: 4.6, depth: 0.65,
                       x: x, y: 2.3, z: c.depth * 0.20, material: .metalLight)
            }
        default: // Roadside shop with a landmark tower and asymmetrical roof.
            addBox(to: root, width: c.width * 0.78, height: bodyHeight, depth: c.depth * 0.56,
                   x: -c.width * 0.06, y: bodyHeight / 2, z: -c.depth * 0.14, material: .roadsideWarm)
            addGable(to: root, width: c.width * 0.84, depth: c.depth * 0.62, height: 2.4,
                     x: -c.width * 0.06, y: bodyHeight, z: -c.depth * 0.14, material: .roofBrown)
            addBox(to: root, width: c.width * 0.20, height: c.height * 1.02, depth: c.depth * 0.25,
                   x: c.width * 0.34, y: c.height * 0.51, z: c.depth * 0.16, material: .roadsideAccent)
            addBox(to: near, width: c.width * 0.56, height: bodyHeight * 0.42, depth: 0.52,
                   x: -c.width * 0.08, y: bodyHeight * 0.30, z: c.depth * 0.145, material: .commercialGlass)
        }

        addPylonSign(
            to: root,
            c: c,
            x: c.width * 0.35,
            z: c.depth * 0.34,
            height: max(5.5, c.height * 0.86),
            material: variant.isMultiple(of: 2) ? .commercialAccent : .commercialCanopy
        )
        addBlankSign(to: near, x: c.width * 0.31, y: max(3, bodyHeight * 0.72), z: c.depth * 0.21,
                     width: c.width * 0.20,
                     material: variant.isMultiple(of: 2) ? .commercialAccent : .commercialCanopy)
        addCommercialSideFacade(
            to: near,
            c: c,
            bodyHeight: max(4.5, bodyHeight),
            accent: variant.isMultiple(of: 2) ? .commercialAccent : .commercialCanopy
        )
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
                addCone(to: root, radius: min(c.width, c.depth) * 0.125, height: 2.5,
                        x: x, y: bodyHeight * 0.72 + 1.25, z: -c.depth * 0.10, material: .roofOrange)
            }
        } else {
            addBox(to: root, width: c.width * 0.86, height: bodyHeight, depth: c.depth * 0.72,
                   x: 0, y: bodyHeight / 2, z: -c.depth * 0.05,
                   material: variant == 0 ? .factoryBlue : .industrialWall)
            switch variant {
            case 0:
                for x in [-c.width * 0.26, 0, c.width * 0.26] {
                    addGable(to: root, width: c.width * 0.27, depth: c.depth * 0.76, height: 2.8,
                             x: x, y: bodyHeight, z: -c.depth * 0.05, material: .roofMetal)
                }
            case 1:
                addGable(to: root, width: c.width * 0.90, depth: c.depth * 0.76, height: 3.2,
                         x: 0, y: bodyHeight, z: -c.depth * 0.05, material: .roofMetal)
            case 2:
                addBox(to: root, width: c.width * 0.90, height: 0.8, depth: c.depth * 0.76,
                       x: 0, y: bodyHeight + 0.4, z: -c.depth * 0.05, material: .roofMetal)
                addBox(to: root, width: c.width * 0.42, height: 2.2, depth: c.depth * 0.34,
                       x: -c.width * 0.14, y: bodyHeight + 1.1, z: -c.depth * 0.09,
                       material: .factoryBlue)
                addGable(to: root, width: c.width * 0.46, depth: c.depth * 0.38, height: 1.6,
                         x: -c.width * 0.14, y: bodyHeight + 2.2, z: -c.depth * 0.09,
                         material: .roofOrange)
            default:
                for x in [-c.width * 0.22, c.width * 0.22] {
                    addGable(to: root, width: c.width * 0.44, depth: c.depth * 0.76, height: 3.0,
                             x: x, y: bodyHeight, z: -c.depth * 0.05, material: .roofMetal)
                }
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
               x: 0, y: max(2.8, bodyHeight * 0.56), z: c.depth * 0.325,
               material: variant.isMultiple(of: 2) ? .factoryBlue : .smokestackBrick)
        if variant == 2 {
            addBox(to: root, width: c.width * 0.66, height: 0.72, depth: 2.8,
                   x: 0, y: bodyHeight * 0.58, z: c.depth * 0.37, material: .roofOrange)
            for x in [-c.width * 0.28, c.width * 0.28] {
                addBox(to: root, width: 0.66, height: bodyHeight * 0.58, depth: 0.66,
                       x: x, y: bodyHeight * 0.29, z: c.depth * 0.37, material: .metalLight)
            }
        }
        for x in [-c.width * 0.23, 0, c.width * 0.23] {
            addBox(to: near, width: c.width * 0.16, height: 3.0, depth: 0.8,
                   x: x, y: 1.5, z: c.depth * 0.315, material: .loadingDoor)
        }
        addIndustrialSideFacade(to: near, c: c, bodyHeight: bodyHeight)
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
        let podiumHeight = min(5, c.height * 0.22)
        switch variant {
        case 0: // Mixed-use block: shop podium, small tower and a corner turret.
            addBox(to: root, width: c.width * 0.92, height: podiumHeight, depth: c.depth * 0.88,
                   x: 0, y: podiumHeight / 2, z: 0, material: .storefrontDark)
            let lowerHeight = (c.height - podiumHeight) * 0.54
            let upperHeight = c.height - podiumHeight - lowerHeight
            addBox(to: root, width: c.width * 0.66, height: lowerHeight, depth: c.depth * 0.58,
                   x: -c.width * 0.08, y: podiumHeight + lowerHeight / 2,
                   z: -c.depth * 0.07, material: .downtownWall)
            addBox(to: root, width: c.width * 0.54, height: upperHeight, depth: c.depth * 0.46,
                   x: -c.width * 0.11, y: podiumHeight + lowerHeight + upperHeight / 2,
                   z: -c.depth * 0.09, material: .officeBlue)
            addGable(to: root, width: c.width * 0.58, depth: c.depth * 0.50, height: 3.0,
                     x: -c.width * 0.11, y: c.height, z: -c.depth * 0.09, material: .roofOrange)
            let turretRadius = min(c.width, c.depth) * 0.12
            addCylinder(to: root, radius: turretRadius, height: c.height * 0.56,
                        x: c.width * 0.31, y: podiumHeight + c.height * 0.28,
                        z: c.depth * 0.22, material: .commercialLight)
            addCone(to: root, radius: turretRadius * 1.08, height: 3.8,
                    x: c.width * 0.31, y: podiumHeight + c.height * 0.56 + 1.9,
                    z: c.depth * 0.22, material: .roofGreen)
        case 1: // Office: slender glazed tower, crown and lower atrium wing.
            addBox(to: root, width: c.width * 0.72, height: podiumHeight, depth: c.depth * 0.76,
                   x: -c.width * 0.08, y: podiumHeight / 2, z: 0, material: .storefrontDark)
            let lowerHeight = (c.height - podiumHeight) * 0.62
            let upperHeight = c.height - podiumHeight - lowerHeight
            addBox(to: root, width: c.width * 0.46, height: lowerHeight, depth: c.depth * 0.50,
                   x: -c.width * 0.08, y: podiumHeight + lowerHeight / 2,
                   z: -c.depth * 0.05, material: .officeBlue)
            addBox(to: root, width: c.width * 0.34, height: upperHeight, depth: c.depth * 0.38,
                   x: -c.width * 0.12, y: podiumHeight + lowerHeight + upperHeight / 2,
                   z: -c.depth * 0.08, material: .commercialGlass)
            addBox(to: root, width: c.width * 0.40, height: 0.84, depth: c.depth * 0.44,
                   x: -c.width * 0.12, y: c.height + 0.42, z: -c.depth * 0.08, material: .roofBlue)
            addBox(to: root, width: c.width * 0.30, height: c.height * 0.40, depth: c.depth * 0.52,
                   x: c.width * 0.25, y: podiumHeight + c.height * 0.20,
                   z: c.depth * 0.06, material: .commercialLight)
            addBox(to: root, width: c.width * 0.34, height: 0.64, depth: c.depth * 0.56,
                   x: c.width * 0.25, y: podiumHeight + c.height * 0.40 + 0.32,
                   z: c.depth * 0.06, material: .commercialCanopy)
            addCylinder(to: props, radius: 0.38, height: 5.4,
                        x: -c.width * 0.12, y: c.height + 3.1, z: -c.depth * 0.08, material: .streetMetal)
        case 2: // Apartment: three staggered residential bars with balconies and a pitched roof.
            addBox(to: root, width: c.width * 0.92, height: podiumHeight, depth: c.depth * 0.84,
                   x: 0, y: podiumHeight / 2, z: 0, material: .storefrontDark)
            let floorHeight = (c.height - podiumHeight) / 3
            for floor in 0..<3 {
                let inset = Float(floor) * c.width * 0.045
                addBox(to: root, width: c.width * (0.78 - Float(floor) * 0.06), height: floorHeight,
                       depth: c.depth * (0.68 - Float(floor) * 0.05),
                       x: -inset, y: podiumHeight + Float(floor) * floorHeight + floorHeight / 2,
                       z: -c.depth * 0.04, material: floor == 0 ? .downtownWall : .residentialCool)
                addBox(to: near, width: c.width * (0.72 - Float(floor) * 0.06), height: 0.38,
                       depth: 1.9, x: -inset, y: podiumHeight + Float(floor + 1) * floorHeight - 0.38,
                       z: c.depth * 0.31, material: .roofLight)
            }
            addGable(to: root, width: c.width * 0.70, depth: c.depth * 0.58, height: 3.3,
                     x: -c.width * 0.09, y: c.height, z: -c.depth * 0.04, material: .roofBrown)
        case 3: // Parking structure: visible decks, corner columns and open rails.
            let deckHeight = c.height / 4
            for floor in 0..<4 {
                let y = Float(floor) * deckHeight + 0.40
                addBox(to: root, width: c.width * 0.90, height: 0.80, depth: c.depth * 0.86,
                       x: 0, y: y, z: 0, material: .parkingConcrete)
                addBox(to: near, width: c.width * 0.92, height: 0.40, depth: 0.70,
                       x: 0, y: y + 1.25, z: c.depth * 0.35, material: .roofSlate)
            }
            for x in [-c.width * 0.36, c.width * 0.36] {
                for z in [-c.depth * 0.31, c.depth * 0.31] {
                    addBox(to: root, width: 0.72, height: c.height * 0.88, depth: 0.72,
                           x: x, y: c.height * 0.44, z: z, material: .parkingConcrete)
                }
            }
            addBox(to: root, width: c.width * 0.22, height: c.height * 0.30, depth: c.depth * 0.28,
                   x: c.width * 0.28, y: c.height * 0.15, z: c.depth * 0.18, material: .officeBlue)
        default: // Corner block: an L-shaped department store with a rounded landmark corner.
            addBox(to: root, width: c.width * 0.88, height: podiumHeight, depth: c.depth * 0.86,
                   x: 0, y: podiumHeight / 2, z: 0, material: .storefrontDark)
            let tallHeight = c.height - podiumHeight
            addBox(to: root, width: c.width * 0.40, height: tallHeight, depth: c.depth * 0.62,
                   x: -c.width * 0.22, y: podiumHeight + tallHeight / 2,
                   z: -c.depth * 0.06, material: .downtownWall)
            addBox(to: root, width: c.width * 0.60, height: tallHeight * 0.58, depth: c.depth * 0.32,
                   x: c.width * 0.10, y: podiumHeight + tallHeight * 0.29,
                   z: c.depth * 0.20, material: .officeBlue)
            addBox(to: root, width: c.width * 0.44, height: 0.78, depth: c.depth * 0.66,
                   x: -c.width * 0.22, y: c.height + 0.39, z: -c.depth * 0.06, material: .roofOrange)
            addBox(to: root, width: c.width * 0.64, height: 0.70, depth: c.depth * 0.36,
                   x: c.width * 0.10, y: podiumHeight + tallHeight * 0.58 + 0.35,
                   z: c.depth * 0.20, material: .roofBlue)
            let turretRadius = min(c.width, c.depth) * 0.115
            addCylinder(to: root, radius: turretRadius, height: c.height * 0.68,
                        x: c.width * 0.26, y: podiumHeight + c.height * 0.34,
                        z: -c.depth * 0.20, material: .commercialLight)
            addCone(to: root, radius: turretRadius * 1.12, height: 4.2,
                    x: c.width * 0.26, y: podiumHeight + c.height * 0.68 + 2.1,
                    z: -c.depth * 0.20, material: .roofGreen)
        }

        for x in [-c.width * 0.30, -c.width * 0.10, c.width * 0.10, c.width * 0.30] {
            addBox(to: near, width: c.width * 0.15, height: min(2.6, podiumHeight * 0.58), depth: 0.48,
                   x: x, y: podiumHeight * 0.46, z: c.depth * 0.425, material: .commercialGlass)
        }
        addBox(to: near, width: c.width * 0.74, height: 0.46, depth: 1.35,
               x: 0, y: podiumHeight * 0.76, z: c.depth * 0.43,
               material: variant.isMultiple(of: 2) ? .commercialCanopy : .commercialAccent)
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
            addGable(to: root, width: c.width * 0.92, depth: c.depth * 0.68, height: 2.6,
                     x: 0, y: wingHeight, z: -c.depth * 0.10, material: .roofGreen)
            for level in [wingHeight * 0.36, wingHeight * 0.70] {
                addBox(to: near, width: c.width * 0.72, height: 0.38, depth: 1.5,
                       x: -c.width * 0.04, y: level, z: c.depth * 0.225, material: .roofLight)
            }
        } else {
            let height = c.height * 0.76
            addBox(to: root, width: c.width * 0.86, height: height, depth: c.depth * 0.68,
                   x: 0, y: height / 2, z: -c.depth * 0.08,
                   material: variant == 0 ? .industrialWall : .roadsideWarm)
            if variant == 0 {
                for x in [-c.width * 0.28, 0, c.width * 0.28] {
                    addGable(to: root, width: c.width * 0.29, depth: c.depth * 0.72, height: 2.6,
                             x: x, y: height, z: -c.depth * 0.08, material: .roofMetal)
                }
            } else {
                addBox(to: root, width: c.width * 0.90, height: 0.8, depth: c.depth * 0.72,
                       x: 0, y: height + 0.4, z: -c.depth * 0.08, material: .roofOrange)
                addBox(to: root, width: c.width * 0.24, height: height * 1.10, depth: c.depth * 0.30,
                       x: c.width * 0.27, y: height * 0.55, z: c.depth * 0.15, material: .commercialLight)
                addBox(to: root, width: c.width * 0.28, height: 0.70, depth: c.depth * 0.34,
                       x: c.width * 0.27, y: height * 1.10 + 0.35,
                       z: c.depth * 0.15, material: .roadsideAccent)
            }
        }
        addBox(to: root, width: c.width * 0.58, height: 0.8, depth: 0.75,
               x: 0, y: max(3.2, c.height * 0.58), z: c.depth * 0.275, material: .roadsideAccent)
        addPylonSign(to: root, c: c, x: c.width * 0.36, z: c.depth * 0.34,
                     height: c.height * 0.92, material: variant == 0 ? .commercialCanopy : .roadsideAccent)
        addBlankSign(to: near, x: c.width * 0.30, y: c.height * 0.58, z: c.depth * 0.29,
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
        switch size {
        case 0: // Small dealer: pitched-roof office plus a glass display wing.
            addBox(to: root, width: c.width * 0.52, height: bodyHeight, depth: c.depth * 0.52,
                   x: -c.width * 0.13, y: bodyHeight / 2, z: -c.depth * 0.18, material: .playerWall)
            addHippedRoof(to: root, width: c.width * 0.56, depth: c.depth * 0.56, height: 2.4,
                          x: -c.width * 0.13, y: bodyHeight, z: -c.depth * 0.18, material: .playerNavy)
            let displayHeight = bodyHeight * 0.58
            addBox(to: root, width: c.width * 0.42, height: displayHeight, depth: c.depth * 0.38,
                   x: c.width * 0.23, y: displayHeight / 2, z: c.depth * 0.13, material: .commercialGlass)
            addBox(to: root, width: c.width * 0.46, height: 0.75, depth: c.depth * 0.42,
                   x: c.width * 0.23, y: displayHeight + 0.375, z: c.depth * 0.13, material: .playerAccent)
        case 1: // Medium dealer: two-level office and a broad stepped showroom.
            addBox(to: root, width: c.width * 0.72, height: bodyHeight, depth: c.depth * 0.38,
                   x: 0, y: bodyHeight / 2, z: -c.depth * 0.27, material: .playerWall)
            addBox(to: root, width: c.width * 0.76, height: 0.85, depth: c.depth * 0.42,
                   x: 0, y: bodyHeight + 0.425, z: -c.depth * 0.27, material: .playerNavy)
            let showroomHeight = bodyHeight * 0.62
            addBox(to: root, width: c.width * 0.66, height: showroomHeight, depth: c.depth * 0.36,
                   x: -c.width * 0.05, y: showroomHeight / 2, z: c.depth * 0.10, material: .commercialGlass)
            addBox(to: root, width: c.width * 0.72, height: 0.76, depth: c.depth * 0.40,
                   x: -c.width * 0.05, y: showroomHeight + 0.38, z: c.depth * 0.10, material: .playerAccent)
            addBox(to: root, width: c.width * 0.15, height: bodyHeight * 1.10, depth: c.depth * 0.22,
                   x: c.width * 0.32, y: bodyHeight * 0.55, z: -c.depth * 0.12, material: .playerNavy)
        default: // Large dealer: two rear wings, central hall and a landmark entry tower.
            addBox(to: root, width: c.width * 0.40, height: bodyHeight, depth: c.depth * 0.48,
                   x: -c.width * 0.23, y: bodyHeight / 2, z: -c.depth * 0.19, material: .playerWall)
            addBox(to: root, width: c.width * 0.40, height: bodyHeight * 0.78, depth: c.depth * 0.48,
                   x: c.width * 0.23, y: bodyHeight * 0.39, z: -c.depth * 0.19, material: .playerWall)
            addBox(to: root, width: c.width * 0.88, height: 0.86, depth: c.depth * 0.52,
                   x: 0, y: bodyHeight + 0.43, z: -c.depth * 0.19, material: .playerNavy)
            let showroomHeight = bodyHeight * 0.54
            addBox(to: root, width: c.width * 0.68, height: showroomHeight, depth: c.depth * 0.34,
                   x: 0, y: showroomHeight / 2, z: c.depth * 0.18, material: .commercialGlass)
            addBox(to: root, width: c.width * 0.74, height: 0.82, depth: c.depth * 0.38,
                   x: 0, y: showroomHeight + 0.41, z: c.depth * 0.18, material: .playerAccent)
            addBox(to: root, width: c.width * 0.16, height: c.height, depth: c.depth * 0.22,
                   x: 0, y: c.height / 2, z: -c.depth * 0.02, material: .playerNavy)
        }
        addPylonSign(to: root, c: c, x: c.width * 0.36, z: c.depth * 0.34,
                     height: c.height * 0.92, material: .playerAccent)
        addBox(to: near, width: c.width * 0.46, height: 0.72, depth: 0.55,
               x: -c.width * 0.12, y: bodyHeight * 0.68, z: c.depth * 0.07, material: .playerAccent)
        addBlankSign(to: near, x: c.width * 0.24, y: bodyHeight * 0.82, z: c.depth * 0.18,
                     width: c.width * 0.18, material: .playerAccent)
        addCommercialSideFacade(to: near, c: c, bodyHeight: bodyHeight, accent: .playerAccent)
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
            let towerHeight = c.height - podium
            let lowerTower = towerHeight * 0.58
            let upperTower = towerHeight - lowerTower
            addBox(to: root, width: c.width * 0.62, height: lowerTower, depth: c.depth * 0.58,
                   x: 0, y: podium + lowerTower / 2, z: -c.depth * 0.04, material: .officeBlue)
            addBox(to: root, width: c.width * 0.66, height: 0.70, depth: c.depth * 0.62,
                   x: 0, y: podium + lowerTower, z: -c.depth * 0.04, material: .playerAccent)
            addBox(to: root, width: c.width * 0.48, height: upperTower, depth: c.depth * 0.46,
                   x: -c.width * 0.04, y: podium + lowerTower + upperTower / 2,
                   z: -c.depth * 0.07, material: .playerWall)
            addBox(to: root, width: c.width * 0.52, height: 0.82, depth: c.depth * 0.50,
                   x: -c.width * 0.04, y: c.height + 0.41,
                   z: -c.depth * 0.07, material: .playerNavy)
            for y in stride(from: Float(9), to: c.height - 1, by: 5) {
                addBox(to: near, width: c.width * 0.40, height: 0.7, depth: 0.4,
                       x: 0, y: y, z: c.depth * 0.235, material: .windowBlue)
            }
            addPorch(to: root, width: c.width * 0.34, depth: c.depth * 0.13,
                     x: 0, z: c.depth * 0.36, roofY: 4.2, roofMaterial: .playerAccent)
        } else {
            let lowerHeight = c.height * 0.42
            let upperHeight = c.height - lowerHeight
            addBox(to: root, width: c.width * 0.78, height: lowerHeight, depth: c.depth * 0.70,
                   x: 0, y: lowerHeight / 2, z: 0, material: .playerNavy)
            addBox(to: root, width: c.width * 0.62, height: upperHeight, depth: c.depth * 0.58,
                   x: -c.width * 0.06, y: lowerHeight + upperHeight / 2,
                   z: -c.depth * 0.08, material: .playerWall)
            addGable(to: root, width: c.width * 0.66, depth: c.depth * 0.62, height: 2.2,
                     x: -c.width * 0.06, y: c.height, z: -c.depth * 0.08, material: .playerNavy)
            for x in [-c.width * 0.20, c.width * 0.08] {
                addBox(to: near, width: c.width * 0.18, height: 1.3, depth: 0.5,
                       x: x, y: lowerHeight + upperHeight * 0.52,
                       z: c.depth * 0.215, material: .commercialGlass)
            }
            addBox(to: near, width: c.width * 0.38, height: 0.62, depth: 1.15,
                   x: 0, y: lowerHeight * 0.72, z: c.depth * 0.35, material: .playerAccent)
        }
        if headquarters {
            addBox(to: props, width: 3.5, height: 1.5, depth: 3.5,
                   x: c.width * 0.16, y: c.height + 1.2, z: -c.depth * 0.14, material: .rooftopEquipment)
        }
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
        if logistics {
            for x in [-c.width * 0.25, 0, c.width * 0.25] {
                addGable(to: root, width: c.width * 0.26, depth: c.depth * 0.66, height: 2.7,
                         x: x, y: height, z: -c.depth * 0.08, material: .playerNavy)
            }
            addBox(to: root, width: c.width * 0.20, height: 2.2, depth: c.depth * 0.26,
                   x: c.width * 0.26, y: height + 1.1, z: -c.depth * 0.10, material: .playerAccent)
        } else {
            addGable(to: root, width: c.width * 0.82, depth: c.depth * 0.66, height: 2.8,
                     x: 0, y: height, z: -c.depth * 0.08, material: .playerNavy)
        }
        let doors = logistics ? 4 : 2
        for index in 0..<doors {
            let x = (Float(index) - Float(doors - 1) / 2) * c.width * 0.16
            addBox(to: near, width: c.width * 0.12, height: height * 0.48, depth: 0.7,
                   x: x, y: height * 0.24, z: c.depth * 0.235, material: .loadingDoor)
        }
        addBox(to: root, width: c.width * 0.64, height: 0.68, depth: 2.4,
               x: 0, y: height * 0.57, z: c.depth * 0.28, material: .playerAccent)
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
        addBox(to: parent, width: c.width + 1, height: 0.10, depth: c.depth + 1,
               x: 0, y: 0.05, z: 0, material: .baseShadow, chamfer: 0.45)
        addBox(to: parent, width: c.width, height: 0.20, depth: c.depth,
               x: 0, y: 0.13, z: 0, material: material, chamfer: 0.35)
    }

    private func addGardenBed(
        to parent: SCNNode,
        width: Float,
        depth: Float,
        x: Float,
        z: Float
    ) {
        addBox(to: parent, width: width, height: 0.12, depth: depth,
               x: x, y: 0.27, z: z, material: .residentialGarden, chamfer: 0.18)
    }

    private func addPorch(
        to parent: SCNNode,
        width: Float,
        depth: Float,
        x: Float,
        z: Float,
        roofY: Float,
        roofMaterial: AssetMaterialKey
    ) {
        addBox(to: parent, width: width, height: 0.52, depth: depth,
               x: x, y: roofY, z: z, material: roofMaterial, chamfer: 0.16)
        for columnX in [x - width * 0.38, x + width * 0.38] {
            addBox(to: parent, width: 0.48, height: roofY, depth: 0.48,
                   x: columnX, y: roofY / 2, z: z + depth * 0.28,
                   material: .roofLight, chamfer: 0.08)
        }
    }

    /// A small raised roof volume is much more legible from the fixed
    /// isometric camera than a coloured roof slab.  It stays entirely inside
    /// the parent footprint and is shared by house and villa variants.
    private func addDormer(
        to parent: SCNNode,
        width: Float,
        depth: Float,
        x: Float,
        baseY: Float,
        z: Float,
        roofMaterial: AssetMaterialKey
    ) {
        let wallHeight: Float = 1.05
        addBox(to: parent, width: width, height: wallHeight, depth: depth,
               x: x, y: baseY + wallHeight / 2, z: z,
               material: .residentialLight, chamfer: 0.10)
        addGable(to: parent, width: width * 1.10, depth: depth * 1.10, height: 0.95,
                 x: x, y: baseY + wallHeight, z: z,
                 material: roofMaterial, ridgeMaterial: .roofLight)
        addBox(to: parent, width: width * 0.42, height: 0.42, depth: 0.16,
               x: x, y: baseY + wallHeight * 0.55, z: z + depth * 0.53,
               material: .windowBlue, chamfer: 0.04)
    }

    private func addHouseFacadeDetails(
        to parent: SCNNode,
        c: AssetBuildContext,
        bodyHeight: Float,
        levels: Int,
        accent: AssetMaterialKey
    ) {
        let frontZ = c.depth * 0.365
        let sideX = c.width * 0.365
        let safeLevels = max(1, levels)
        for level in 0..<safeLevels {
            let y = bodyHeight * (safeLevels == 1
                ? 0.54
                : 0.28 + Float(level) * 0.38)
            for x in [-c.width * 0.24, -c.width * 0.03] {
                addBox(to: parent, width: c.width * 0.145, height: 2.35, depth: 0.34,
                       x: x, y: y, z: frontZ, material: .roofLight, chamfer: 0.05)
                addBox(to: parent, width: c.width * 0.12, height: 1.90, depth: 0.42,
                       x: x, y: y, z: frontZ + 0.10, material: .windowBlue, chamfer: 0.04)
            }
            for z in [-c.depth * 0.20, c.depth * 0.02] {
                addBox(to: parent, width: 0.34, height: 2.35, depth: c.depth * 0.145,
                       x: sideX, y: y, z: z, material: .roofLight, chamfer: 0.05)
                addBox(to: parent, width: 0.42, height: 1.90, depth: c.depth * 0.12,
                       x: sideX + 0.10, y: y, z: z, material: .windowBlue, chamfer: 0.04)
            }
        }

        let doorHeight = min(4.2, bodyHeight * 0.62)
        addBox(to: parent, width: max(2.2, c.width * 0.095), height: doorHeight, depth: 0.48,
               x: c.width * 0.19, y: doorHeight / 2, z: frontZ + 0.10,
               material: .woodAccent, chamfer: 0.08)
        addBox(to: parent, width: c.width * 0.22, height: 0.42, depth: 1.45,
               x: c.width * 0.19, y: min(bodyHeight * 0.70, doorHeight + 0.36),
               z: frontZ + 0.42, material: accent, chamfer: 0.10)
    }

    private func addCommercialSideFacade(
        to parent: SCNNode,
        c: AssetBuildContext,
        bodyHeight: Float,
        accent: AssetMaterialKey
    ) {
        let sideX = c.width * 0.445
        let windowY = min(bodyHeight * 0.44, 5.0)
        for z in [-c.depth * 0.22, 0, c.depth * 0.22] {
            addBox(to: parent, width: 0.34, height: 2.75, depth: c.depth * 0.145,
                   x: sideX, y: windowY, z: z, material: .roofLight, chamfer: 0.04)
            addBox(to: parent, width: 0.44, height: 2.28, depth: c.depth * 0.12,
                   x: sideX + 0.10, y: windowY, z: z, material: .commercialGlass, chamfer: 0.04)
        }
        addBox(to: parent, width: 1.25, height: 0.52, depth: c.depth * 0.72,
               x: sideX + 0.45, y: min(bodyHeight * 0.68, 7.0), z: 0,
               material: accent, chamfer: 0.10)
    }

    private func addIndustrialSideFacade(
        to parent: SCNNode,
        c: AssetBuildContext,
        bodyHeight: Float
    ) {
        let sideX = c.width * 0.435
        for z in [-c.depth * 0.22, 0, c.depth * 0.22] {
            addBox(to: parent, width: 0.42, height: 2.35, depth: c.depth * 0.13,
                   x: sideX, y: bodyHeight * 0.62, z: z,
                   material: .windowBlue, chamfer: 0.03)
        }
        addBox(to: parent, width: 1.15, height: 0.62, depth: c.depth * 0.66,
               x: sideX + 0.35, y: bodyHeight * 0.76, z: 0,
               material: .roofMetal, chamfer: 0.08)
        for z in [-c.depth * 0.26, c.depth * 0.26] {
            addBox(to: parent, width: 0.64, height: bodyHeight * 0.58, depth: 0.64,
                   x: sideX + 0.20, y: bodyHeight * 0.29, z: z,
                   material: .metalLight, chamfer: 0.04)
        }
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
        addBox(to: parent, width: 4.8 * scale, height: 3.3 * scale, depth: 4.8 * scale,
               x: x, y: 4.6 * scale, z: z, material: .treeLeaf, chamfer: 0.55 * scale)
        addBox(to: parent, width: 3.4 * scale, height: 2.5 * scale, depth: 3.4 * scale,
               x: x - 0.35 * scale, y: 6.7 * scale, z: z + 0.25 * scale,
               material: .treeLeaf, chamfer: 0.45 * scale)
    }

    private func addFlowerBed(to parent: SCNNode, width: Float, x: Float, z: Float) {
        let spacing = width / 4
        for index in 0..<5 {
            addBox(
                to: parent,
                width: 1.15,
                height: 0.65,
                depth: 1.15,
                x: x - width / 2 + Float(index) * spacing,
                y: 0.34,
                z: z,
                material: index.isMultiple(of: 2) ? .flowerPink : .flowerYellow,
                chamfer: 0.24
            )
        }
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

    private func addCone(
        to parent: SCNNode,
        radius: Float,
        height: Float,
        x: Float,
        y: Float,
        z: Float,
        material: AssetMaterialKey
    ) {
        let node = SCNNode(geometry: resources.cone(radius: radius, height: height, material: material))
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
        material: AssetMaterialKey,
        rotationY: Float = 0,
        ridgeMaterial: AssetMaterialKey? = .roofLight
    ) {
        let node = SCNNode(geometry: resources.gable(width: width, depth: depth, height: height, material: material))
        node.position = SCNVector3(x, y, z)
        node.eulerAngles.y = rotationY
        parent.addChildNode(node)
        if let ridgeMaterial {
            let ridge = SCNNode(geometry: resources.box(
                width: max(0.34, min(width, depth) * 0.028),
                height: 0.32,
                depth: depth * 0.92,
                chamfer: 0.08,
                material: ridgeMaterial
            ))
            ridge.position = SCNVector3(x, y + height + 0.16, z)
            ridge.eulerAngles.y = rotationY
            parent.addChildNode(ridge)
        }
    }

    private func addHippedRoof(
        to parent: SCNNode,
        width: Float,
        depth: Float,
        height: Float,
        x: Float,
        y: Float,
        z: Float,
        material: AssetMaterialKey
    ) {
        let eave = SCNNode(geometry: resources.box(
            width: width * 1.025,
            height: 0.28,
            depth: depth * 1.025,
            chamfer: 0.08,
            material: material
        ))
        eave.name = "hipped-roof-eave"
        eave.position = SCNVector3(x, y + 0.14, z)
        parent.addChildNode(eave)

        let roof = SCNNode(geometry: resources.hippedRoof(
            width: width,
            depth: depth,
            height: height,
            material: material
        ))
        roof.name = "hipped-roof"
        roof.position = SCNVector3(x, y + 0.28, z)
        parent.addChildNode(roof)

        let ridge = SCNNode(geometry: resources.box(
            width: max(0.38, min(width, depth) * 0.026),
            height: 0.34,
            depth: depth * 0.32,
            chamfer: 0.08,
            material: .roofLight
        ))
        ridge.name = "hipped-roof-ridge"
        ridge.position = SCNVector3(x, y + height + 0.45, z)
        parent.addChildNode(ridge)
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
    case baseShadow, residentialGarden, luxuryGarden, residentialLot, luxuryLot, pavement, industrialPavement, downtownPaving, parkingAsphalt
    case residentialWarm, residentialCool, residentialLight, luxuryStone, luxuryLight, garageGray
    case commercialLight, commercialGlass, commercialAccent, commercialCanopy
    case industrialWall, factoryBlue, metalLight, loadingDoor, smokestackBrick
    case downtownWall, officeBlue, storefrontDark, parkingConcrete, roadsideWarm, roadsideAccent
    case roofBrown, roofSlate, roofGreen, roofBlue, roofOrange, roofLight, roofMetal
    case windowBlue, woodAccent, poolBlue
    case playerPaving, playerWall, playerNavy, playerAccent, bodyShopWall, wetPaving
    case parkingLine, rooftopEquipment, treeTrunk, treeLeaf, hedge, flowerPink, flowerYellow
    case streetMetal, lampLight, fenceMetal
    case vehicleBlue, vehicleNeutral, vehicleGlass, truckWhite

    var color: UIColor {
        switch self {
        case .baseShadow: UIColor(red: 0.16, green: 0.25, blue: 0.24, alpha: 1)
        case .residentialGarden: UIColor(red: 0.63, green: 0.76, blue: 0.48, alpha: 1)
        case .luxuryGarden: UIColor(red: 0.60, green: 0.74, blue: 0.47, alpha: 1)
        case .residentialLot: UIColor(red: 0.76, green: 0.72, blue: 0.61, alpha: 1)
        case .luxuryLot: UIColor(red: 0.82, green: 0.78, blue: 0.66, alpha: 1)
        case .pavement: UIColor(red: 0.69, green: 0.69, blue: 0.63, alpha: 1)
        case .industrialPavement: UIColor(red: 0.55, green: 0.58, blue: 0.57, alpha: 1)
        case .downtownPaving: UIColor(red: 0.73, green: 0.68, blue: 0.65, alpha: 1)
        case .parkingAsphalt: UIColor(red: 0.32, green: 0.36, blue: 0.38, alpha: 1)
        case .residentialWarm: UIColor(red: 0.98, green: 0.68, blue: 0.42, alpha: 1)
        case .residentialCool: UIColor(red: 0.49, green: 0.76, blue: 0.82, alpha: 1)
        case .residentialLight: UIColor(red: 1.00, green: 0.91, blue: 0.67, alpha: 1)
        case .luxuryStone: UIColor(red: 0.91, green: 0.75, blue: 0.58, alpha: 1)
        case .luxuryLight: UIColor(red: 1.00, green: 0.92, blue: 0.70, alpha: 1)
        case .garageGray: UIColor(red: 0.62, green: 0.66, blue: 0.65, alpha: 1)
        case .commercialLight: UIColor(red: 0.98, green: 0.87, blue: 0.62, alpha: 1)
        case .commercialGlass: UIColor(red: 0.14, green: 0.64, blue: 0.80, alpha: 1)
        case .commercialAccent: UIColor(red: 0.94, green: 0.25, blue: 0.18, alpha: 1)
        case .commercialCanopy: UIColor(red: 1.00, green: 0.70, blue: 0.10, alpha: 1)
        case .industrialWall: UIColor(red: 0.58, green: 0.68, blue: 0.72, alpha: 1)
        case .factoryBlue: UIColor(red: 0.24, green: 0.61, blue: 0.75, alpha: 1)
        case .metalLight: UIColor(red: 0.78, green: 0.81, blue: 0.78, alpha: 1)
        case .loadingDoor: UIColor(red: 0.25, green: 0.28, blue: 0.29, alpha: 1)
        case .smokestackBrick: UIColor(red: 0.72, green: 0.34, blue: 0.24, alpha: 1)
        case .downtownWall: UIColor(red: 0.73, green: 0.55, blue: 0.78, alpha: 1)
        case .officeBlue: UIColor(red: 0.31, green: 0.63, blue: 0.82, alpha: 1)
        case .storefrontDark: UIColor(red: 0.20, green: 0.34, blue: 0.39, alpha: 1)
        case .parkingConcrete: UIColor(red: 0.66, green: 0.64, blue: 0.60, alpha: 1)
        case .roadsideWarm: UIColor(red: 0.93, green: 0.57, blue: 0.28, alpha: 1)
        case .roadsideAccent: UIColor(red: 0.94, green: 0.25, blue: 0.13, alpha: 1)
        case .roofBrown: UIColor(red: 0.86, green: 0.29, blue: 0.20, alpha: 1)
        case .roofSlate: UIColor(red: 0.12, green: 0.42, blue: 0.48, alpha: 1)
        case .roofGreen: UIColor(red: 0.10, green: 0.38, blue: 0.34, alpha: 1)
        case .roofBlue: UIColor(red: 0.18, green: 0.49, blue: 0.78, alpha: 1)
        case .roofOrange: UIColor(red: 0.96, green: 0.48, blue: 0.16, alpha: 1)
        case .roofLight: UIColor(red: 0.97, green: 0.86, blue: 0.54, alpha: 1)
        case .roofMetal: UIColor(red: 0.47, green: 0.57, blue: 0.60, alpha: 1)
        case .windowBlue: UIColor(red: 0.10, green: 0.57, blue: 0.74, alpha: 1)
        case .woodAccent: UIColor(red: 0.68, green: 0.39, blue: 0.20, alpha: 1)
        case .poolBlue: UIColor(red: 0.20, green: 0.76, blue: 0.86, alpha: 1)
        case .playerPaving: UIColor(red: 0.55, green: 0.65, blue: 0.61, alpha: 1)
        case .playerWall: UIColor(red: 0.78, green: 0.88, blue: 0.79, alpha: 1)
        case .playerNavy: UIColor(red: 0.10, green: 0.35, blue: 0.43, alpha: 1)
        case .playerAccent: UIColor(red: 0.08, green: 0.72, blue: 0.60, alpha: 1)
        case .bodyShopWall: UIColor(red: 0.72, green: 0.82, blue: 0.78, alpha: 1)
        case .wetPaving: UIColor(red: 0.36, green: 0.59, blue: 0.64, alpha: 1)
        case .parkingLine: UIColor(red: 1.00, green: 0.91, blue: 0.48, alpha: 1)
        case .rooftopEquipment: UIColor(red: 0.38, green: 0.40, blue: 0.40, alpha: 1)
        case .treeTrunk: UIColor(red: 0.34, green: 0.23, blue: 0.14, alpha: 1)
        case .treeLeaf: UIColor(red: 0.24, green: 0.70, blue: 0.25, alpha: 1)
        case .hedge: UIColor(red: 0.18, green: 0.64, blue: 0.20, alpha: 1)
        case .flowerPink: UIColor(red: 1.00, green: 0.36, blue: 0.56, alpha: 1)
        case .flowerYellow: UIColor(red: 1.00, green: 0.82, blue: 0.18, alpha: 1)
        case .streetMetal, .fenceMetal: UIColor(red: 0.27, green: 0.36, blue: 0.38, alpha: 1)
        case .lampLight: UIColor(red: 1.00, green: 0.88, blue: 0.30, alpha: 1)
        case .vehicleBlue: UIColor(red: 0.12, green: 0.55, blue: 0.86, alpha: 1)
        case .vehicleNeutral: UIColor(red: 0.96, green: 0.82, blue: 0.42, alpha: 1)
        case .vehicleGlass: UIColor(red: 0.10, green: 0.31, blue: 0.39, alpha: 1)
        case .truckWhite: UIColor(red: 0.93, green: 0.91, blue: 0.78, alpha: 1)
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

    func cone(radius: Float, height: Float, material: AssetMaterialKey) -> SCNGeometry {
        let key = ShapeKey(kind: "cone", a: quantize(radius), b: quantize(height), c: 0, material: material)
        if let geometry = shapes[key] { return geometry }
        let geometry = SCNCone(topRadius: 0, bottomRadius: CGFloat(radius), height: CGFloat(height))
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

    func hippedRoof(width: Float, depth: Float, height: Float, material: AssetMaterialKey) -> SCNGeometry {
        let key = ShapeKey(kind: "hipped-roof", a: quantize(width), b: quantize(depth), c: quantize(height), material: material)
        if let geometry = shapes[key] { return geometry }

        let halfWidth = width / 2
        let halfDepth = depth / 2
        let halfRidge = depth * 0.16
        let sourceVertices: [SCNVector3] = [
            .init(-halfWidth, 0, -halfDepth),
            .init(halfWidth, 0, -halfDepth),
            .init(halfWidth, 0, halfDepth),
            .init(-halfWidth, 0, halfDepth),
            .init(0, height, -halfRidge),
            .init(0, height, halfRidge)
        ]
        let sourceIndices: [UInt32] = [
            0, 4, 1,             // back hip
            3, 2, 5,             // front hip
            0, 3, 5, 0, 5, 4,   // left roof plane
            1, 4, 5, 1, 5, 2,   // right roof plane
            0, 2, 1, 0, 3, 2    // underside
        ]
        let geometry = facetedGeometry(
            sourceVertices: sourceVertices,
            sourceIndices: sourceIndices,
            material: material
        )
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
        let geometry = facetedGeometry(
            sourceVertices: sourceVertices,
            sourceIndices: sourceIndices,
            material: material
        )
        shapes[key] = geometry
        return geometry
    }

    private func facetedGeometry(
        sourceVertices: [SCNVector3],
        sourceIndices: [UInt32],
        material: AssetMaterialKey
    ) -> SCNGeometry {
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
        return geometry
    }

    private func material(_ key: AssetMaterialKey) -> SCNMaterial {
        if let material = materials[key] { return material }
        let material = SCNMaterial()
        material.name = key.rawValue
        material.diffuse.contents = key.color
        material.lightingModel = .lambert
        material.isDoubleSided = false
        materials[key] = material
        return material
    }

    private func quantize(_ value: Float) -> Int { Int((value * 100).rounded()) }
}
