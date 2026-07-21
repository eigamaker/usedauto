import SceneKit
import UIKit

/// Procedural building factory for the 2.5D city.
///
/// Every asset is composed from a small silhouette grammar — plinth, massing
/// volumes, faceted roofs with real eaves, facade bands with baked window
/// textures, and LOD-gated props — under one curated palette, so the city
/// reads as one professionally art-directed set instead of colored boxes.
///
/// Contract shared with tests and the scene controller:
/// - assets stay inside their oriented grid footprint and below their
///   selection volume, grounded at y = 0
/// - at most 64 geometry nodes per asset, 16 per lot infill
/// - geometries and materials are cached and reused between builds
/// - `nearDetailNodeName` / `propDetailNodeName` children gate zoom detail
@MainActor
final class CityBuildingFactory {
    static let nearDetailNodeName = "near-details"
    static let propDetailNodeName = "prop-details"

    private let cellSize: Float
    private var assetTemplates: [String: SCNNode] = [:]
    private var infillTemplates: [String: SCNNode] = [:]
    private var materials: [String: SCNMaterial] = [:]
    private var geometries: [String: SCNGeometry] = [:]

    init(cellSize: Float) {
        self.cellSize = cellSize
    }

    // MARK: - Palette

    /// A saturated, toy-like palette shared by every district. Player-owned
    /// facilities use royal blue, while warm walls and orange accents keep the
    /// whole set readable against yellow-green terrain.
    enum Paint: String {
        case cream, warmWhite, sand, terracottaWall, brick, sage, slateWall
        case graphite, concrete, glassTower
        case roofTerracotta, roofBrickRed, roofSlate, roofCharcoal, roofSage
        case roofNavy, roofSand, roofTeal
        case glazing, glazingSky, doorWood, metalLight, metalDark
        case signWhite, brandBlue, brandOrange, asphalt, lotConcrete, lawn
        case poolWater, gravel, safetyYellow, brandRed, treeGreen

        var color: UIColor {
            switch self {
            case .cream: UIColor(red: 0.96, green: 0.86, blue: 0.66, alpha: 1)
            case .warmWhite: UIColor(red: 0.98, green: 0.93, blue: 0.80, alpha: 1)
            case .sand: UIColor(red: 0.91, green: 0.76, blue: 0.50, alpha: 1)
            case .terracottaWall: UIColor(red: 0.91, green: 0.57, blue: 0.37, alpha: 1)
            case .brick: UIColor(red: 0.72, green: 0.30, blue: 0.22, alpha: 1)
            case .sage: UIColor(red: 0.70, green: 0.78, blue: 0.49, alpha: 1)
            case .slateWall: UIColor(red: 0.56, green: 0.69, blue: 0.76, alpha: 1)
            case .graphite: UIColor(red: 0.26, green: 0.29, blue: 0.32, alpha: 1)
            case .concrete: UIColor(red: 0.78, green: 0.73, blue: 0.63, alpha: 1)
            case .glassTower: UIColor(red: 0.30, green: 0.61, blue: 0.76, alpha: 1)
            case .roofTerracotta: UIColor(red: 0.91, green: 0.38, blue: 0.18, alpha: 1)
            case .roofBrickRed: UIColor(red: 0.76, green: 0.25, blue: 0.17, alpha: 1)
            case .roofSlate: UIColor(red: 0.25, green: 0.34, blue: 0.49, alpha: 1)
            case .roofCharcoal: UIColor(red: 0.20, green: 0.23, blue: 0.27, alpha: 1)
            case .roofSage: UIColor(red: 0.30, green: 0.50, blue: 0.29, alpha: 1)
            case .roofNavy: UIColor(red: 0.10, green: 0.30, blue: 0.58, alpha: 1)
            case .roofSand: UIColor(red: 0.88, green: 0.63, blue: 0.27, alpha: 1)
            case .roofTeal: UIColor(red: 0.06, green: 0.55, blue: 0.57, alpha: 1)
            case .glazing: UIColor(red: 0.16, green: 0.28, blue: 0.38, alpha: 1)
            case .glazingSky: UIColor(red: 0.34, green: 0.67, blue: 0.82, alpha: 1)
            case .doorWood: UIColor(red: 0.48, green: 0.27, blue: 0.14, alpha: 1)
            case .metalLight: UIColor(red: 0.86, green: 0.84, blue: 0.78, alpha: 1)
            case .metalDark: UIColor(red: 0.39, green: 0.41, blue: 0.40, alpha: 1)
            case .signWhite: UIColor(red: 1.00, green: 0.95, blue: 0.82, alpha: 1)
            case .brandBlue: UIColor(red: 0.08, green: 0.38, blue: 0.72, alpha: 1)
            case .brandOrange: UIColor(red: 1.00, green: 0.49, blue: 0.10, alpha: 1)
            case .brandRed: UIColor(red: 0.87, green: 0.20, blue: 0.13, alpha: 1)
            case .asphalt: UIColor(red: 0.27, green: 0.28, blue: 0.29, alpha: 1)
            case .lotConcrete: UIColor(red: 0.70, green: 0.66, blue: 0.57, alpha: 1)
            case .lawn: UIColor(red: 0.51, green: 0.68, blue: 0.22, alpha: 1)
            case .poolWater: UIColor(red: 0.18, green: 0.67, blue: 0.86, alpha: 1)
            case .gravel: UIColor(red: 0.69, green: 0.59, blue: 0.43, alpha: 1)
            case .safetyYellow: UIColor(red: 1.00, green: 0.72, blue: 0.10, alpha: 1)
            case .treeGreen: UIColor(red: 0.24, green: 0.51, blue: 0.14, alpha: 1)
            }
        }
    }

    // MARK: - Public API

    func makeAsset(
        id: CityAssetID,
        facing: CardinalDirection,
        heightHint: Float? = nil
    ) -> SCNNode {
        let definition = CityAssetCatalog.definition(for: id)
        let height = heightHint ?? definition.nominalHeight
        let key = "\(id.rawValue)|\(facing.rawValue)|\(Int((height * 10).rounded()))"
        if let template = assetTemplates[key] { return template.clone() }

        // Orthographic 2.5D flattens vertical scale, so buildings carry a
        // per-category height exaggeration. The visual height still leaves
        // prop headroom inside the selection volume, whose cap is tighter
        // for player facilities than for ambient buildings.
        let headroomBudget = definition.isPlayerFacility
            ? definition.nominalHeight * 1.25
            : definition.nominalHeight * 1.25 + 7
        let visualHeight = min(headroomBudget, height * Self.heightExaggeration(definition.category))
        let footprint = definition.footprint
        let context = BuildContext(
            width: Float(footprint.width) * cellSize,
            depth: Float(footprint.depth) * cellSize,
            height: visualHeight
        )
        let built = SCNNode()
        built.name = "asset:\(id.rawValue)"
        let near = SCNNode()
        near.name = Self.nearDetailNodeName
        let props = SCNNode()
        props.name = Self.propDetailNodeName
        let parts = AssetParts(root: built, near: near, props: props)

        addFootprintPlinth(to: built, context: context, category: definition.category)
        build(id: id, context: context, into: parts)
        built.addChildNode(near)
        built.addChildNode(props)
        built.eulerAngles.y = Self.rotation(for: facing, from: definition.frontDirection)

        assetTemplates[key] = built
        return built.clone()
    }

    func makeLotInfill(
        category: CityAssetCategory,
        facing: CardinalDirection,
        width: Float,
        depth: Float
    ) -> SCNNode {
        let key = "\(category.rawValue)|\(facing.rawValue)|\(Int(width))x\(Int(depth))"
        if let template = infillTemplates[key] { return template.clone() }

        let node = SCNNode()
        node.name = "lot-infill:\(category.rawValue)"
        let near = SCNNode()
        near.name = Self.nearDetailNodeName
        let props = SCNNode()
        props.name = Self.propDetailNodeName
        buildInfill(
            category: category,
            width: width,
            depth: depth,
            root: node,
            near: near,
            props: props
        )
        node.addChildNode(near)
        node.addChildNode(props)
        node.eulerAngles.y = Self.rotation(for: facing, from: .south)

        infillTemplates[key] = node
        return node.clone()
    }

    private static func heightExaggeration(_ category: CityAssetCategory) -> Float {
        switch category {
        case .generalResidential: 2.4
        case .luxuryResidential: 2.2
        case .commercial: 2.0
        case .industrial: 1.9
        case .downtown: 1.5
        case .highway: 1.9
        case .parking: 1.0
        case .playerFacility: 2.0
        }
    }

    private static func rotation(
        for facing: CardinalDirection,
        from front: CardinalDirection
    ) -> Float {
        func index(_ direction: CardinalDirection) -> Int {
            switch direction {
            case .south: 0
            case .east: 1
            case .north: 2
            case .west: 3
            }
        }
        let turns = (index(facing) - index(front) + 4) % 4
        return Float(turns) * .pi / 2
    }

    // MARK: - Build plumbing

    private struct BuildContext {
        let width: Float
        let depth: Float
        let height: Float

        var halfWidth: Float { width / 2 }
        var halfDepth: Float { depth / 2 }
    }

    private struct AssetParts {
        let root: SCNNode
        let near: SCNNode
        let props: SCNNode
    }

    /// A thin exact-size base makes the grid contract visible. Its outer edge
    /// follows the authored footprint after rotation, while all decorative
    /// geometry remains slightly inset from it.
    private func addFootprintPlinth(
        to root: SCNNode,
        context: BuildContext,
        category: CityAssetCategory
    ) {
        let surface: Paint = switch category {
        case .generalResidential, .luxuryResidential: .lawn
        case .commercial, .highway, .parking, .playerFacility: .asphalt
        case .industrial, .downtown: .lotConcrete
        }
        let edge = SCNNode(geometry: box(
            width: context.width,
            height: 0.22,
            depth: context.depth,
            chamfer: 0.55,
            paint: .concrete
        ))
        edge.name = "footprint-edge"
        edge.position.y = 0.11
        root.addChildNode(edge)

        let top = SCNNode(geometry: box(
            width: max(0.1, context.width - 1.0),
            height: 0.10,
            depth: max(0.1, context.depth - 1.0),
            chamfer: 0.40,
            paint: surface
        ))
        top.name = "footprint-surface"
        top.position.y = 0.25
        root.addChildNode(top)
    }

    private func build(id: CityAssetID, context: BuildContext, into parts: AssetParts) {
        switch id {
        case .residentialCottage: buildCottageBlock(context, parts, twin: false)
        case .residentialGable: buildGableBlock(context, parts)
        case .residentialFlat: buildFlatHomes(context, parts)
        case .residentialTwin: buildCottageBlock(context, parts, twin: true)
        case .residentialApartment: buildApartment(context, parts)
        case .luxuryCourtyard: buildLuxuryVilla(context, parts, kind: .courtyard)
        case .luxuryGarage: buildLuxuryVilla(context, parts, kind: .garage)
        case .luxuryPool: buildLuxuryVilla(context, parts, kind: .pool)
        case .luxuryTerrace: buildLuxuryVilla(context, parts, kind: .terrace)
        case .commercialAutoDealer: buildAutoDealer(context, parts, brand: .brandOrange)
        case .commercialGasStation: buildGasStation(context, parts)
        case .commercialConvenience: buildConvenience(context, parts)
        case .commercialRestaurant: buildRestaurant(context, parts)
        case .commercialShopping: buildShopping(context, parts)
        case .commercialRoadside: buildRoadsideRetail(context, parts)
        case .industrialFactory: buildFactory(context, parts)
        case .industrialWarehouse: buildWarehouse(context, parts, loading: false)
        case .industrialLoadingWarehouse: buildWarehouse(context, parts, loading: true)
        case .industrialTankWorks: buildTankWorks(context, parts)
        case .industrialSmokestack: buildSmokestackPlant(context, parts)
        case .downtownMixedUse: buildTower(context, parts, kind: .mixedUse)
        case .downtownOffice: buildTower(context, parts, kind: .office)
        case .downtownApartment: buildTower(context, parts, kind: .apartment)
        case .downtownParkingStructure: buildParkingStructure(context, parts)
        case .downtownCornerBlock: buildTower(context, parts, kind: .cornerBlock)
        case .highwayLogistics: buildLogistics(context, parts)
        case .highwayBigBox: buildBigBox(context, parts)
        case .highwayMotorHotel: buildMotorHotel(context, parts)
        case .surfaceParking: buildSurfaceParking(context, parts)
        case .playerSmallDealer: buildPlayerDealer(context, parts, tier: 0)
        case .playerMediumDealer: buildPlayerDealer(context, parts, tier: 1)
        case .playerLargeDealer: buildPlayerDealer(context, parts, tier: 2)
        case .playerDisplayParking: buildDisplayParking(context, parts)
        case .playerServiceWorkshop: buildPlayerWorkshop(context, parts, body: false)
        case .playerBodyShop: buildPlayerWorkshop(context, parts, body: true)
        case .playerCarWash: buildCarWash(context, parts)
        case .playerVehicleYard: buildVehicleYard(context, parts)
        case .playerOffice: buildPlayerOffice(context, parts)
        case .playerPartsWarehouse: buildPartsWarehouse(context, parts)
        case .playerAuctionHouse: buildAuctionHouse(context, parts)
        case .playerLogisticsCenter: buildLogisticsCenter(context, parts)
        case .playerHeadquarters: buildHeadquarters(context, parts)
        }
    }

    // MARK: - Residential

    /// One 4×4 suburb lot reads as a small neighborhood corner: a main house,
    /// a second smaller house, gardens and a shed.
    private func buildCottageBlock(_ c: BuildContext, _ p: AssetParts, twin: Bool) {
        let roof: Paint = twin ? .roofSlate : .roofTerracotta
        let wall: Paint = twin ? .warmWhite : .cream

        let mainWidth = c.width * 0.42
        let mainDepth = c.depth * 0.34
        let mainHeight = c.height * 0.58
        addHouse(
            to: p, x: -c.width * 0.20, z: c.depth * 0.20,
            width: mainWidth, depth: mainDepth, wallHeight: mainHeight,
            wall: wall, roof: roof, roofStyle: .hipped, withChimney: true
        )
        addHouse(
            to: p, x: c.width * 0.24, z: -c.depth * 0.16,
            width: c.width * 0.34, depth: c.depth * 0.30, wallHeight: mainHeight * 0.88,
            wall: twin ? .cream : .sage, roof: twin ? .roofSlate : .roofBrickRed,
            roofStyle: .hipped, withChimney: false
        )
        if twin {
            addHouse(
                to: p, x: -c.width * 0.26, z: -c.depth * 0.28,
                width: c.width * 0.30, depth: c.depth * 0.24, wallHeight: mainHeight * 0.82,
                wall: .warmWhite, roof: .roofSlate, roofStyle: .gabled, withChimney: false
            )
        } else {
            let shed = box(width: c.width * 0.14, height: 2.6, depth: c.depth * 0.12, chamfer: 0.15, paint: .doorWood)
            let shedNode = SCNNode(geometry: shed)
            shedNode.position = SCNVector3(-c.width * 0.30, 1.3, -c.depth * 0.30)
            p.near.addChildNode(shedNode)
        }
        addGardenTree(to: p.props, x: c.width * 0.36, z: c.depth * 0.34, scale: 1.0)
        addGardenTree(to: p.props, x: -c.width * 0.38, z: -c.depth * 0.05, scale: 0.8)
        addHedge(to: p.near, width: c.width * 0.5, x: -c.width * 0.2, z: c.depth * 0.44)
        addCar(to: p.props, x: c.width * 0.30, z: c.depth * 0.30, paint: .slateWall, rotated: false)
    }

    private func buildGableBlock(_ c: BuildContext, _ p: AssetParts) {
        addHouse(
            to: p, x: -c.width * 0.18, z: c.depth * 0.16,
            width: c.width * 0.46, depth: c.depth * 0.32, wallHeight: c.height * 0.55,
            wall: .warmWhite, roof: .roofBrickRed, roofStyle: .gabled, withChimney: true
        )
        addHouse(
            to: p, x: c.width * 0.26, z: -c.depth * 0.22,
            width: c.width * 0.32, depth: c.depth * 0.28, wallHeight: c.height * 0.48,
            wall: .cream, roof: .roofSage, roofStyle: .gabled, withChimney: false
        )
        addGardenTree(to: p.props, x: -c.width * 0.38, z: -c.depth * 0.32, scale: 1.05)
        addHedge(to: p.near, width: c.width * 0.44, x: c.width * 0.22, z: c.depth * 0.44)
        addCar(to: p.props, x: -c.width * 0.33, z: c.depth * 0.34, paint: .brick, rotated: false)
    }

    /// Two modern flat-roofed homes with parapets and a shared court.
    private func buildFlatHomes(_ c: BuildContext, _ p: AssetParts) {
        for (dx, dz, w, d, h, wall) in [
            (-c.width * 0.20, c.depth * 0.18, c.width * 0.42, c.depth * 0.34, c.height * 0.72, Paint.warmWhite),
            (c.width * 0.24, -c.depth * 0.20, c.width * 0.36, c.depth * 0.30, c.height * 0.58, Paint.sand)
        ] {
            addGroundShadow(to: p, x: dx, z: dz, width: w + 2, depth: d + 2)
            let body = SCNNode(geometry: box(width: w, height: h, depth: d, chamfer: 0.2, paint: wall))
            body.position = SCNVector3(dx, h / 2, dz)
            p.root.addChildNode(body)

            let parapet = SCNNode(geometry: box(width: w + 0.8, height: 0.8, depth: d + 0.8, chamfer: 0.15, paint: .graphite))
            parapet.position = SCNVector3(dx, h + 0.4, dz)
            p.root.addChildNode(parapet)

            let glassBand = SCNNode(geometry: box(width: w * 0.72, height: h * 0.30, depth: 0.5, chamfer: 0.1, paint: .glazing))
            glassBand.position = SCNVector3(dx, h * 0.42, dz + d / 2 + 0.05)
            p.near.addChildNode(glassBand)
        }
        addGardenTree(to: p.props, x: -c.width * 0.40, z: -c.depth * 0.34, scale: 0.9)
        addCar(to: p.props, x: c.width * 0.02, z: c.depth * 0.38, paint: .graphite, rotated: false)
    }

    private func buildApartment(_ c: BuildContext, _ p: AssetParts) {
        let bodyWidth = c.width * 0.72
        let bodyDepth = c.depth * 0.40
        let bodyHeight = c.height * 0.92
        let floors = max(3, Int((bodyHeight / 3.1).rounded()))
        addGroundShadow(to: p, x: -c.width * 0.06, z: c.depth * 0.10, width: bodyWidth + 4, depth: bodyDepth + 4)
        let body = SCNNode(geometry: facadeBox(
            width: bodyWidth, height: bodyHeight, depth: bodyDepth, chamfer: 0.2,
            wall: .cream, style: .punched(floors: floors, columns: 7, balconies: true)
        ))
        body.position = SCNVector3(-c.width * 0.06, bodyHeight / 2, c.depth * 0.10)
        p.root.addChildNode(body)

        let stair = SCNNode(geometry: box(
            width: bodyWidth * 0.24, height: bodyHeight + 1.4, depth: bodyDepth * 0.56,
            chamfer: 0.2, paint: .terracottaWall
        ))
        stair.position = SCNVector3(bodyWidth * 0.46 - c.width * 0.06, (bodyHeight + 1.4) / 2, c.depth * 0.10)
        p.root.addChildNode(stair)

        let roofDeck = SCNNode(geometry: box(width: bodyWidth * 0.5, height: 1.2, depth: bodyDepth * 0.5, chamfer: 0.15, paint: .concrete))
        roofDeck.position = SCNVector3(-c.width * 0.14, bodyHeight + 0.6, c.depth * 0.10)
        p.near.addChildNode(roofDeck)

        addParkingRow(to: p, carCount: 3, z: -c.depth * 0.34, width: c.width * 0.7)
        addGardenTree(to: p.props, x: c.width * 0.38, z: -c.depth * 0.30, scale: 0.95)
        addHedge(to: p.near, width: c.width * 0.62, x: -c.width * 0.08, z: c.depth * 0.42)
    }

    // MARK: - Luxury residential

    private enum VillaKind { case courtyard, garage, pool, terrace }

    private func buildLuxuryVilla(_ c: BuildContext, _ p: AssetParts, kind: VillaKind) {
        let wall: Paint = kind == .terrace ? .warmWhite : .sand
        let roof: Paint = kind == .pool ? .roofSand : .roofSlate

        addHouse(
            to: p, x: -c.width * 0.16, z: -c.depth * 0.12,
            width: c.width * 0.50, depth: c.depth * 0.34, wallHeight: c.height * 0.55,
            wall: wall, roof: roof, roofStyle: .hipped, withChimney: kind == .courtyard
        )
        let wingHeight = c.height * (kind == .terrace ? 0.34 : 0.42)
        addHouse(
            to: p, x: c.width * 0.22, z: c.depth * 0.16,
            width: c.width * 0.34, depth: c.depth * 0.30, wallHeight: wingHeight,
            wall: wall, roof: roof, roofStyle: kind == .terrace ? .flat : .hipped, withChimney: false
        )

        switch kind {
        case .courtyard:
            let court = SCNNode(geometry: box(width: c.width * 0.30, height: 0.3, depth: c.depth * 0.26, chamfer: 0.2, paint: .lotConcrete))
            court.position = SCNVector3(c.width * 0.05, 0.15, -c.depth * 0.33)
            p.near.addChildNode(court)
            addGardenTree(to: p.props, x: c.width * 0.05, z: -c.depth * 0.33, scale: 0.85)
        case .garage:
            let garage = SCNNode(geometry: facadeBox(
                width: c.width * 0.24, height: 3.4, depth: c.depth * 0.22, chamfer: 0.2,
                wall: wall, style: .rollerDoors(count: 2)
            ))
            garage.position = SCNVector3(-c.width * 0.30, 1.7, c.depth * 0.30)
            p.root.addChildNode(garage)
            addCar(to: p.props, x: -c.width * 0.06, z: c.depth * 0.34, paint: .brandRed, rotated: false)
        case .pool:
            let deck = SCNNode(geometry: box(width: c.width * 0.36, height: 0.3, depth: c.depth * 0.28, chamfer: 0.2, paint: .warmWhite))
            deck.position = SCNVector3(-c.width * 0.22, 0.15, c.depth * 0.30)
            p.root.addChildNode(deck)
            let pool = SCNNode(geometry: box(width: c.width * 0.26, height: 0.34, depth: c.depth * 0.18, chamfer: 0.3, paint: .poolWater))
            pool.position = SCNVector3(-c.width * 0.22, 0.22, c.depth * 0.30)
            p.near.addChildNode(pool)
        case .terrace:
            let pergola = SCNNode(geometry: box(width: c.width * 0.28, height: 0.5, depth: c.depth * 0.22, chamfer: 0.1, paint: .doorWood))
            pergola.position = SCNVector3(c.width * 0.22, wingHeight + 1.6, c.depth * 0.16)
            p.near.addChildNode(pergola)
        }
        addHedge(to: p.near, width: c.width * 0.86, x: 0, z: -c.depth * 0.45)
        addGardenTree(to: p.props, x: c.width * 0.40, z: -c.depth * 0.36, scale: 1.1)
    }

    // MARK: - Commercial

    private func buildAutoDealer(_ c: BuildContext, _ p: AssetParts, brand: Paint) {
        let showroomWidth = c.width * 0.56
        let showroomDepth = c.depth * 0.42
        let showroomHeight = c.height * 0.62
        addGroundShadow(to: p, x: -c.width * 0.14, z: -c.depth * 0.18, width: showroomWidth + 4, depth: showroomDepth + 4)
        let showroom = SCNNode(geometry: facadeBox(
            width: showroomWidth, height: showroomHeight, depth: showroomDepth, chamfer: 0.2,
            wall: .warmWhite, style: .curtain(floors: 2)
        ))
        showroom.position = SCNVector3(-c.width * 0.14, showroomHeight / 2, -c.depth * 0.18)
        p.root.addChildNode(showroom)

        let fascia = SCNNode(geometry: box(width: showroomWidth + 1.2, height: 1.6, depth: showroomDepth + 1.2, chamfer: 0.2, paint: brand))
        fascia.position = SCNVector3(-c.width * 0.14, showroomHeight + 0.8, -c.depth * 0.18)
        p.root.addChildNode(fascia)

        let service = SCNNode(geometry: facadeBox(
            width: c.width * 0.30, height: showroomHeight * 0.62, depth: showroomDepth * 0.9, chamfer: 0.2,
            wall: .concrete, style: .rollerDoors(count: 2)
        ))
        service.position = SCNVector3(c.width * 0.28, showroomHeight * 0.31, -c.depth * 0.20)
        p.root.addChildNode(service)

        addPylonSign(to: p, x: c.width * 0.40, z: c.depth * 0.38, height: c.height * 0.9, brand: brand)
        addParkingRow(to: p, carCount: 4, z: c.depth * 0.26, width: c.width * 0.8)
    }

    private func buildGasStation(_ c: BuildContext, _ p: AssetParts) {
        let kiosk = SCNNode(geometry: facadeBox(
            width: c.width * 0.30, height: 3.6, depth: c.depth * 0.24, chamfer: 0.2,
            wall: .warmWhite, style: .shopfront(fascia: .brandOrange)
        ))
        kiosk.position = SCNVector3(-c.width * 0.28, 1.8, -c.depth * 0.28)
        p.root.addChildNode(kiosk)

        addGroundShadow(to: p, x: c.width * 0.06, z: 0, width: c.width * 0.58, depth: c.depth * 0.46)
        let canopy = SCNNode(geometry: box(width: c.width * 0.58, height: 0.9, depth: c.depth * 0.46, chamfer: 0.25, paint: .signWhite))
        canopy.position = SCNVector3(c.width * 0.06, 5.4, 0)
        p.root.addChildNode(canopy)
        let canopyBand = SCNNode(geometry: box(width: c.width * 0.58 + 0.6, height: 0.7, depth: c.depth * 0.46 + 0.6, chamfer: 0.2, paint: .brandOrange))
        canopyBand.position = SCNVector3(c.width * 0.06, 4.7, 0)
        p.root.addChildNode(canopyBand)

        for (dx, dz) in [(-c.width * 0.06, -c.depth * 0.10), (c.width * 0.18, -c.depth * 0.10),
                         (-c.width * 0.06, c.depth * 0.12), (c.width * 0.18, c.depth * 0.12)] {
            let column = SCNNode(geometry: cylinder(radius: 0.4, height: 5.0, paint: .metalLight))
            column.position = SCNVector3(dx, 2.5, dz)
            p.near.addChildNode(column)
        }
        for (dx, dz) in [(c.width * 0.06, -c.depth * 0.10), (c.width * 0.06, c.depth * 0.12)] {
            let island = SCNNode(geometry: box(width: 3.6, height: 1.5, depth: 1.4, chamfer: 0.2, paint: .brandRed))
            island.position = SCNVector3(dx, 0.75, dz)
            p.near.addChildNode(island)
        }
        addPylonSign(to: p, x: -c.width * 0.40, z: c.depth * 0.40, height: c.height * 0.95, brand: .brandOrange)
        addCar(to: p.props, x: c.width * 0.32, z: c.depth * 0.30, paint: .glazingSky, rotated: true)
    }

    private func buildConvenience(_ c: BuildContext, _ p: AssetParts) {
        addGroundShadow(to: p, x: -c.width * 0.14, z: -c.depth * 0.20, width: c.width * 0.56 + 4, depth: c.depth * 0.38 + 4)
        let store = SCNNode(geometry: facadeBox(
            width: c.width * 0.56, height: 4.4, depth: c.depth * 0.38, chamfer: 0.2,
            wall: .warmWhite, style: .shopfront(fascia: .brandBlue)
        ))
        store.position = SCNVector3(-c.width * 0.14, 2.2, -c.depth * 0.20)
        p.root.addChildNode(store)

        let backroom = SCNNode(geometry: box(width: c.width * 0.30, height: 3.8, depth: c.depth * 0.30, chamfer: 0.2, paint: .concrete))
        backroom.position = SCNVector3(c.width * 0.26, 1.9, -c.depth * 0.24)
        p.root.addChildNode(backroom)

        addParkingRow(to: p, carCount: 4, z: c.depth * 0.22, width: c.width * 0.82)
        addHedge(to: p.near, width: c.width * 0.8, x: 0, z: -c.depth * 0.44)
    }

    private func buildRestaurant(_ c: BuildContext, _ p: AssetParts) {
        addHouse(
            to: p, x: -c.width * 0.12, z: -c.depth * 0.14,
            width: c.width * 0.52, depth: c.depth * 0.40, wallHeight: c.height * 0.46,
            wall: .cream, roof: .roofBrickRed, roofStyle: .gabled, withChimney: true
        )
        let porch = SCNNode(geometry: box(width: c.width * 0.24, height: 3.0, depth: c.depth * 0.12, chamfer: 0.2, paint: .doorWood))
        porch.position = SCNVector3(-c.width * 0.12, 1.5, c.depth * 0.10)
        p.root.addChildNode(porch)

        for (dx, dz) in [(c.width * 0.24, c.depth * 0.06), (c.width * 0.36, -c.depth * 0.10)] {
            let umbrella = SCNNode(geometry: cone(topRadius: 0.05, bottomRadius: 1.8, height: 1.2, paint: .brandRed))
            umbrella.position = SCNVector3(dx, 2.6, dz)
            p.props.addChildNode(umbrella)
            let pole = SCNNode(geometry: cylinder(radius: 0.12, height: 2.6, paint: .metalLight))
            pole.position = SCNVector3(dx, 1.3, dz)
            p.props.addChildNode(pole)
        }
        addParkingRow(to: p, carCount: 3, z: c.depth * 0.30, width: c.width * 0.66)
    }

    private func buildShopping(_ c: BuildContext, _ p: AssetParts) {
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.20, width: c.width * 0.78 + 4, depth: c.depth * 0.44 + 4)
        let mall = SCNNode(geometry: facadeBox(
            width: c.width * 0.78, height: c.height * 0.62, depth: c.depth * 0.44, chamfer: 0.25,
            wall: .warmWhite, style: .ribbon(floors: 2)
        ))
        mall.position = SCNVector3(0, c.height * 0.31, -c.depth * 0.20)
        p.root.addChildNode(mall)

        let wing = SCNNode(geometry: box(
            width: c.width * 0.26, height: c.height * 0.40, depth: c.depth * 0.24,
            chamfer: 0.2, paint: .concrete
        ))
        wing.position = SCNVector3(c.width * 0.30, c.height * 0.20, c.depth * 0.16)
        p.root.addChildNode(wing)

        let arcade = SCNNode(geometry: box(width: c.width * 0.78, height: 0.7, depth: c.depth * 0.14, chamfer: 0.2, paint: .brandBlue))
        arcade.position = SCNVector3(0, 3.5, c.depth * 0.06)
        p.root.addChildNode(arcade)
        let roofSign = SCNNode(geometry: box(width: c.width * 0.30, height: 2.6, depth: 0.7, chamfer: 0.2, paint: .signWhite))
        roofSign.position = SCNVector3(-c.width * 0.14, c.height * 0.62 + 1.3, -c.depth * 0.10)
        p.near.addChildNode(roofSign)

        addParkingRow(to: p, carCount: 5, z: c.depth * 0.30, width: c.width * 0.9)
    }

    private func buildRoadsideRetail(_ c: BuildContext, _ p: AssetParts) {
        addGroundShadow(to: p, x: -c.width * 0.10, z: -c.depth * 0.18, width: c.width * 0.60 + 4, depth: c.depth * 0.40 + 4)
        let store = SCNNode(geometry: facadeBox(
            width: c.width * 0.60, height: c.height * 0.52, depth: c.depth * 0.40, chamfer: 0.2,
            wall: .sand, style: .shopfront(fascia: .brandRed)
        ))
        store.position = SCNVector3(-c.width * 0.10, c.height * 0.26, -c.depth * 0.18)
        p.root.addChildNode(store)

        let tower = SCNNode(geometry: box(width: c.width * 0.17, height: c.height * 0.78, depth: c.depth * 0.17, chamfer: 0.2, paint: .brandRed))
        tower.position = SCNVector3(c.width * 0.28, c.height * 0.39, -c.depth * 0.16)
        p.root.addChildNode(tower)

        addPylonSign(to: p, x: c.width * 0.40, z: c.depth * 0.36, height: c.height * 0.85, brand: .brandRed)
        addParkingRow(to: p, carCount: 4, z: c.depth * 0.26, width: c.width * 0.8)
    }

    // MARK: - Industrial

    private func buildFactory(_ c: BuildContext, _ p: AssetParts) {
        let hallWidth = c.width * 0.66
        let hallDepth = c.depth * 0.46
        let hallHeight = c.height * 0.48
        addGroundShadow(to: p, x: -c.width * 0.10, z: -c.depth * 0.16, width: hallWidth + 4, depth: hallDepth + 4)
        let hall = SCNNode(geometry: box(width: hallWidth, height: hallHeight, depth: hallDepth, chamfer: 0.2, paint: .concrete))
        hall.position = SCNVector3(-c.width * 0.10, hallHeight / 2, -c.depth * 0.16)
        p.root.addChildNode(hall)

        let sawtooth = SCNNode(geometry: sawtoothRoof(
            width: hallWidth + 1.0, depth: hallDepth + 1.0, teeth: 4, rise: c.height * 0.16
        ))
        sawtooth.position = SCNVector3(-c.width * 0.10, hallHeight, -c.depth * 0.16)
        sawtooth.name = "sawtooth-roof"
        p.root.addChildNode(sawtooth)

        let office = SCNNode(geometry: facadeBox(
            width: c.width * 0.26, height: c.height * 0.36, depth: c.depth * 0.24, chamfer: 0.2,
            wall: .warmWhite, style: .punched(floors: 2, columns: 4, balconies: false)
        ))
        office.position = SCNVector3(c.width * 0.30, c.height * 0.18, c.depth * 0.18)
        p.root.addChildNode(office)

        let stack = SCNNode(geometry: cylinder(radius: 1.1, height: c.height * 0.92, paint: .brick))
        stack.position = SCNVector3(c.width * 0.34, c.height * 0.46, -c.depth * 0.30)
        p.root.addChildNode(stack)
        let stackTip = SCNNode(geometry: cylinder(radius: 1.2, height: 1.4, paint: .metalLight))
        stackTip.position = SCNVector3(c.width * 0.34, c.height * 0.92, -c.depth * 0.30)
        p.near.addChildNode(stackTip)

        addTruck(to: p.props, x: -c.width * 0.16, z: c.depth * 0.30)
    }

    private func buildWarehouse(_ c: BuildContext, _ p: AssetParts, loading: Bool) {
        let hallWidth = c.width * 0.74
        let hallDepth = c.depth * 0.48
        let hallHeight = c.height * 0.62
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.14, width: hallWidth + 4, depth: hallDepth + 4)
        let hall = SCNNode(geometry: facadeBox(
            width: hallWidth, height: hallHeight, depth: hallDepth, chamfer: 0.25,
            wall: loading ? .slateWall : .sage, style: .rollerDoors(count: 3)
        ))
        hall.position = SCNVector3(0, hallHeight / 2, -c.depth * 0.14)
        p.root.addChildNode(hall)

        let roofCap = SCNNode(geometry: gableRoof(
            width: hallWidth + 1.4, depth: hallDepth + 1.4, rise: c.height * 0.22
        ))
        roofCap.position = SCNVector3(0, hallHeight, -c.depth * 0.14)
        p.root.addChildNode(roofCap)

        if loading {
            let canopy = SCNNode(geometry: box(width: hallWidth * 0.8, height: 0.5, depth: c.depth * 0.14, chamfer: 0.15, paint: .metalDark))
            canopy.position = SCNVector3(0, hallHeight * 0.55, c.depth * 0.14)
            p.near.addChildNode(canopy)
            for index in 0..<3 {
                let dock = SCNNode(geometry: box(width: 2.6, height: 1.1, depth: 2.2, chamfer: 0.1, paint: .metalDark))
                dock.position = SCNVector3(Float(index - 1) * hallWidth * 0.26, 0.55, c.depth * 0.13)
                p.near.addChildNode(dock)
            }
            addTruck(to: p.props, x: -c.width * 0.20, z: c.depth * 0.32)
            addTruck(to: p.props, x: c.width * 0.16, z: c.depth * 0.32)
        } else {
            addTruck(to: p.props, x: c.width * 0.24, z: c.depth * 0.32)
            addCrate(to: p.props, x: -c.width * 0.30, z: c.depth * 0.30)
        }
    }

    private func buildTankWorks(_ c: BuildContext, _ p: AssetParts) {
        for (index, dx) in [-c.width * 0.24, 0, c.width * 0.24].enumerated() {
            let radius = c.width * 0.11
            let height = c.height * (index == 1 ? 0.72 : 0.58)
            addGroundShadow(to: p, x: dx, z: -c.depth * 0.16, width: radius * 2.4, depth: radius * 2.4)
            let tank = SCNNode(geometry: cylinder(radius: radius, height: height, paint: .metalLight))
            tank.position = SCNVector3(dx, height / 2, -c.depth * 0.16)
            p.root.addChildNode(tank)
            let cap = SCNNode(geometry: cone(topRadius: 0.1, bottomRadius: radius, height: radius * 0.5, paint: .metalDark))
            cap.position = SCNVector3(dx, height + radius * 0.25, -c.depth * 0.16)
            p.near.addChildNode(cap)
        }
        let control = SCNNode(geometry: facadeBox(
            width: c.width * 0.30, height: c.height * 0.30, depth: c.depth * 0.20, chamfer: 0.2,
            wall: .concrete, style: .punched(floors: 1, columns: 3, balconies: false)
        ))
        control.position = SCNVector3(-c.width * 0.22, c.height * 0.15, c.depth * 0.26)
        p.root.addChildNode(control)

        let pipeRack = SCNNode(geometry: box(width: c.width * 0.6, height: 0.5, depth: 0.8, chamfer: 0.1, paint: .safetyYellow))
        pipeRack.position = SCNVector3(0, c.height * 0.30, c.depth * 0.06)
        p.near.addChildNode(pipeRack)
        addCrate(to: p.props, x: c.width * 0.30, z: c.depth * 0.30)
    }

    private func buildSmokestackPlant(_ c: BuildContext, _ p: AssetParts) {
        let hallHeight = c.height * 0.34
        addGroundShadow(to: p, x: -c.width * 0.08, z: -c.depth * 0.12, width: c.width * 0.62 + 4, depth: c.depth * 0.42 + 4)
        let hall = SCNNode(geometry: box(width: c.width * 0.62, height: hallHeight, depth: c.depth * 0.42, chamfer: 0.2, paint: .brick))
        hall.position = SCNVector3(-c.width * 0.08, hallHeight / 2, -c.depth * 0.12)
        p.root.addChildNode(hall)
        let hallRoof = SCNNode(geometry: gableRoof(width: c.width * 0.62 + 1.2, depth: c.depth * 0.42 + 1.2, rise: c.height * 0.10))
        hallRoof.position = SCNVector3(-c.width * 0.08, hallHeight, -c.depth * 0.12)
        p.root.addChildNode(hallRoof)

        for (dx, heightScale) in [(c.width * 0.26, 1.0), (c.width * 0.36, 0.82)] {
            let stackHeight = c.height * Float(heightScale) * 0.92
            let stack = SCNNode(geometry: cylinder(radius: 1.3, height: stackHeight, paint: .concrete))
            stack.position = SCNVector3(dx, stackHeight / 2, -c.depth * 0.26)
            p.root.addChildNode(stack)
            let band = SCNNode(geometry: cylinder(radius: 1.4, height: 1.6, paint: .brandRed))
            band.position = SCNVector3(dx, stackHeight - 0.9, -c.depth * 0.26)
            p.near.addChildNode(band)
        }
        addCrate(to: p.props, x: -c.width * 0.32, z: c.depth * 0.30)
        addTruck(to: p.props, x: c.width * 0.10, z: c.depth * 0.32)
    }

    // MARK: - Downtown towers

    private enum TowerKind { case mixedUse, office, apartment, cornerBlock }

    private func buildTower(_ c: BuildContext, _ p: AssetParts, kind: TowerKind) {
        let podiumHeight = c.height * 0.22
        let podiumWidth = c.width * 0.86
        let podiumDepth = c.depth * 0.66
        addGroundShadow(to: p, x: 0, z: c.depth * 0.05, width: podiumWidth + 5, depth: podiumDepth + 5)
        let podium = SCNNode(geometry: facadeBox(
            width: podiumWidth, height: podiumHeight, depth: podiumDepth, chamfer: 0.25,
            wall: kind == .apartment ? .cream : .concrete,
            style: .shopfront(fascia: kind == .mixedUse ? .brandBlue : .graphite)
        ))
        podium.position = SCNVector3(0, podiumHeight / 2, c.depth * 0.05)
        p.root.addChildNode(podium)

        let towerHeight = c.height * 0.98 - podiumHeight
        let floors = max(4, Int((towerHeight / 3.4).rounded()))
        switch kind {
        case .mixedUse:
            let tower = SCNNode(geometry: facadeBox(
                width: c.width * 0.52, height: towerHeight, depth: c.depth * 0.44, chamfer: 0.25,
                wall: .cream, style: .punched(floors: floors, columns: 6, balconies: false)
            ))
            tower.position = SCNVector3(-c.width * 0.10, podiumHeight + towerHeight / 2, -c.depth * 0.02)
            p.root.addChildNode(tower)
        case .office:
            let tower = SCNNode(geometry: facadeBox(
                width: c.width * 0.50, height: towerHeight, depth: c.depth * 0.42, chamfer: 0.25,
                wall: .glassTower, style: .curtain(floors: floors)
            ))
            tower.position = SCNVector3(-c.width * 0.06, podiumHeight + towerHeight / 2, -c.depth * 0.04)
            p.root.addChildNode(tower)
            let fin = SCNNode(geometry: box(width: 0.8, height: towerHeight, depth: c.depth * 0.44, chamfer: 0.1, paint: .warmWhite))
            fin.position = SCNVector3(-c.width * 0.06 - c.width * 0.25, podiumHeight + towerHeight / 2, -c.depth * 0.04)
            p.near.addChildNode(fin)
        case .apartment:
            let tower = SCNNode(geometry: facadeBox(
                width: c.width * 0.56, height: towerHeight, depth: c.depth * 0.38, chamfer: 0.25,
                wall: .warmWhite, style: .punched(floors: floors, columns: 7, balconies: true)
            ))
            tower.position = SCNVector3(-c.width * 0.04, podiumHeight + towerHeight / 2, -c.depth * 0.06)
            p.root.addChildNode(tower)
        case .cornerBlock:
            let towerA = SCNNode(geometry: facadeBox(
                width: c.width * 0.40, height: towerHeight, depth: c.depth * 0.36, chamfer: 0.25,
                wall: .slateWall, style: .punched(floors: floors, columns: 5, balconies: false)
            ))
            towerA.position = SCNVector3(-c.width * 0.18, podiumHeight + towerHeight / 2, -c.depth * 0.08)
            p.root.addChildNode(towerA)
            let towerBHeight = towerHeight * 0.74
            let towerB = SCNNode(geometry: facadeBox(
                width: c.width * 0.32, height: towerBHeight, depth: c.depth * 0.32, chamfer: 0.25,
                wall: .brick, style: .punched(floors: max(3, floors - 3), columns: 4, balconies: false)
            ))
            towerB.position = SCNVector3(c.width * 0.20, podiumHeight + towerBHeight / 2, c.depth * 0.02)
            p.root.addChildNode(towerB)
        }

        let crown = SCNNode(geometry: box(
            width: c.width * (kind == .cornerBlock ? 0.30 : 0.40),
            height: 1.4,
            depth: c.depth * 0.28, chamfer: 0.2, paint: .graphite
        ))
        crown.position = SCNVector3(
            kind == .cornerBlock ? -c.width * 0.18 : -c.width * 0.08,
            podiumHeight + towerHeight + 0.7,
            -c.depth * 0.04
        )
        p.near.addChildNode(crown)
        let vents = SCNNode(geometry: box(width: 2.4, height: 1.8, depth: 2.4, chamfer: 0.2, paint: .metalDark))
        vents.position = SCNVector3(c.width * 0.06, podiumHeight + towerHeight + 0.9, -c.depth * 0.10)
        p.props.addChildNode(vents)
        addGardenTree(to: p.props, x: c.width * 0.34, z: c.depth * 0.36, scale: 0.8)
    }

    private func buildParkingStructure(_ c: BuildContext, _ p: AssetParts) {
        let height = c.height * 0.92
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.04, width: c.width * 0.78 + 5, depth: c.depth * 0.62 + 5)
        let deck = SCNNode(geometry: facadeBox(
            width: c.width * 0.78, height: height, depth: c.depth * 0.62, chamfer: 0.25,
            wall: .concrete, style: .parkingDecks(levels: max(3, Int(height / 4.4)))
        ))
        deck.position = SCNVector3(0, height / 2, -c.depth * 0.04)
        p.root.addChildNode(deck)

        let core = SCNNode(geometry: box(width: c.width * 0.16, height: height + 2.0, depth: c.depth * 0.18, chamfer: 0.2, paint: .brandBlue))
        core.position = SCNVector3(c.width * 0.30, (height + 2.0) / 2, c.depth * 0.16)
        p.root.addChildNode(core)

        addCar(to: p.props, x: -c.width * 0.22, z: height >= 0 ? c.depth * 0.36 : 0, paint: .brandRed, rotated: true)
        addCar(to: p.props, x: -c.width * 0.02, z: c.depth * 0.36, paint: .glazingSky, rotated: true)
    }

    // MARK: - Highway

    private func buildLogistics(_ c: BuildContext, _ p: AssetParts) {
        let hallHeight = c.height * 0.58
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.18, width: c.width * 0.80 + 4, depth: c.depth * 0.44 + 4)
        let hall = SCNNode(geometry: facadeBox(
            width: c.width * 0.80, height: hallHeight, depth: c.depth * 0.44, chamfer: 0.25,
            wall: .warmWhite, style: .rollerDoors(count: 4)
        ))
        hall.position = SCNVector3(0, hallHeight / 2, -c.depth * 0.18)
        p.root.addChildNode(hall)
        let band = SCNNode(geometry: box(width: c.width * 0.80 + 1.0, height: 1.4, depth: c.depth * 0.44 + 1.0, chamfer: 0.2, paint: .brandBlue))
        band.position = SCNVector3(0, hallHeight + 0.7, -c.depth * 0.18)
        p.root.addChildNode(band)

        for index in 0..<3 {
            addTrailer(to: p.props, x: Float(index - 1) * c.width * 0.24, z: c.depth * 0.20)
        }
        addTruck(to: p.props, x: c.width * 0.30, z: c.depth * 0.38)
    }

    private func buildBigBox(_ c: BuildContext, _ p: AssetParts) {
        let height = c.height * 0.62
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.20, width: c.width * 0.74 + 4, depth: c.depth * 0.5 + 4)
        let store = SCNNode(geometry: facadeBox(
            width: c.width * 0.74, height: height, depth: c.depth * 0.5, chamfer: 0.25,
            wall: .sand, style: .shopfront(fascia: .brandOrange)
        ))
        store.position = SCNVector3(0, height / 2, -c.depth * 0.20)
        p.root.addChildNode(store)

        let entry = SCNNode(geometry: box(width: c.width * 0.20, height: height * 0.7, depth: c.depth * 0.16, chamfer: 0.2, paint: .brandOrange))
        entry.position = SCNVector3(-c.width * 0.12, height * 0.35, c.depth * 0.06)
        p.root.addChildNode(entry)

        addParkingRow(to: p, carCount: 5, z: c.depth * 0.28, width: c.width * 0.9)
        addPylonSign(to: p, x: c.width * 0.42, z: c.depth * 0.40, height: c.height * 0.9, brand: .brandOrange)
    }

    private func buildMotorHotel(_ c: BuildContext, _ p: AssetParts) {
        let wingHeight = c.height * 0.52
        let floors = 2
        addGroundShadow(to: p, x: -c.width * 0.02, z: -c.depth * 0.30, width: c.width * 0.76 + 4, depth: c.depth * 0.24 + 4)
        let longWing = SCNNode(geometry: facadeBox(
            width: c.width * 0.76, height: wingHeight, depth: c.depth * 0.24, chamfer: 0.2,
            wall: .warmWhite, style: .punched(floors: floors, columns: 8, balconies: true)
        ))
        longWing.position = SCNVector3(-c.width * 0.02, wingHeight / 2, -c.depth * 0.30)
        p.root.addChildNode(longWing)

        let shortWing = SCNNode(geometry: facadeBox(
            width: c.width * 0.24, height: wingHeight, depth: c.depth * 0.42, chamfer: 0.2,
            wall: .warmWhite, style: .punched(floors: floors, columns: 4, balconies: true)
        ))
        shortWing.position = SCNVector3(-c.width * 0.28, wingHeight / 2, c.depth * 0.02)
        p.root.addChildNode(shortWing)

        let lobbyRoof = SCNNode(geometry: gableRoof(width: c.width * 0.26, depth: c.depth * 0.20, rise: 2.4))
        lobbyRoof.position = SCNVector3(c.width * 0.24, wingHeight * 0.7, c.depth * 0.10)
        p.near.addChildNode(lobbyRoof)
        let lobby = SCNNode(geometry: facadeBox(
            width: c.width * 0.24, height: wingHeight * 0.7, depth: c.depth * 0.18, chamfer: 0.2,
            wall: .brick, style: .shopfront(fascia: .roofNavy)
        ))
        lobby.position = SCNVector3(c.width * 0.24, wingHeight * 0.35, c.depth * 0.10)
        p.root.addChildNode(lobby)

        addPylonSign(to: p, x: c.width * 0.42, z: c.depth * 0.40, height: c.height * 0.88, brand: .roofNavy)
        addParkingRow(to: p, carCount: 4, z: c.depth * 0.32, width: c.width * 0.7)
    }

    private func buildSurfaceParking(_ c: BuildContext, _ p: AssetParts) {
        let lot = SCNNode(geometry: bayLotGeometry(width: c.width * 0.92, depth: c.depth * 0.92, rows: 3))
        lot.position = SCNVector3(0, 0.10, 0)
        p.root.addChildNode(lot)

        let booth = SCNNode(geometry: box(width: 2.4, height: 2.6, depth: 2.0, chamfer: 0.15, paint: .warmWhite))
        booth.position = SCNVector3(-c.width * 0.38, 1.3, c.depth * 0.38)
        p.near.addChildNode(booth)
        let barrier = SCNNode(geometry: box(width: 4.6, height: 0.3, depth: 0.3, chamfer: 0.1, paint: .safetyYellow))
        barrier.position = SCNVector3(-c.width * 0.30, 1.0, c.depth * 0.38)
        p.near.addChildNode(barrier)

        let carPaints: [Paint] = [.brandRed, .glazingSky, .graphite, .warmWhite, .roofNavy]
        for index in 0..<5 {
            addCar(
                to: p.props,
                x: -c.width * 0.30 + Float(index) * c.width * 0.15,
                z: -c.depth * 0.22 + (index.isMultiple(of: 2) ? 0 : c.depth * 0.24),
                paint: carPaints[index],
                rotated: true
            )
        }
    }

    // MARK: - Player facilities

    private func buildPlayerDealer(_ c: BuildContext, _ p: AssetParts, tier: Int) {
        let showroomWidth = c.width * (tier == 0 ? 0.66 : 0.56)
        let showroomDepth = c.depth * (tier == 0 ? 0.44 : 0.40)
        let showroomHeight = c.height * (tier == 2 ? 0.66 : 0.58)
        let floors = tier == 2 ? 2 : 1

        addGroundShadow(to: p, x: -c.width * 0.10, z: -c.depth * 0.18, width: showroomWidth + 4, depth: showroomDepth + 4)
        let showroom = SCNNode(geometry: facadeBox(
            width: showroomWidth, height: showroomHeight, depth: showroomDepth, chamfer: 0.3,
            wall: .warmWhite, style: tier == 2 ? .curtain(floors: floors + 1) : .shopfront(fascia: .brandBlue)
        ))
        showroom.position = SCNVector3(-c.width * 0.10, showroomHeight / 2, -c.depth * 0.18)
        p.root.addChildNode(showroom)

        let fascia = SCNNode(geometry: box(
            width: showroomWidth + 1.4, height: 1.7, depth: showroomDepth + 1.4,
            chamfer: 0.3, paint: .brandBlue
        ))
        fascia.position = SCNVector3(-c.width * 0.10, showroomHeight + 0.85, -c.depth * 0.18)
        p.root.addChildNode(fascia)

        let roofDeck = SCNNode(geometry: box(
            width: showroomWidth * 0.82,
            height: 0.42,
            depth: showroomDepth * 0.76,
            chamfer: 0.18,
            paint: .roofCharcoal
        ))
        roofDeck.position = SCNVector3(
            -c.width * 0.10,
            showroomHeight + 1.78,
            -c.depth * 0.18
        )
        p.near.addChildNode(roofDeck)

        let entrance = SCNNode(geometry: box(
            width: max(3.6, showroomWidth * 0.22),
            height: min(3.8, showroomHeight * 0.54),
            depth: 2.0,
            chamfer: 0.28,
            paint: .brandOrange
        ))
        entrance.position = SCNVector3(
            -c.width * 0.10,
            min(3.8, showroomHeight * 0.54) / 2,
            -c.depth * 0.18 + showroomDepth / 2 + 0.72
        )
        p.near.addChildNode(entrance)

        if tier >= 1 {
            let service = SCNNode(geometry: facadeBox(
                width: c.width * 0.28, height: showroomHeight * 0.66, depth: showroomDepth * 0.86, chamfer: 0.2,
                wall: .concrete, style: .rollerDoors(count: 2)
            ))
            service.position = SCNVector3(c.width * 0.30, showroomHeight * 0.33, -c.depth * 0.20)
            p.root.addChildNode(service)
        }
        if tier == 2 {
            let roofSign = SCNNode(geometry: signBoard(width: showroomWidth * 0.6, height: 2.6))
            roofSign.position = SCNVector3(-c.width * 0.10, showroomHeight + 1.7 + 1.3, -c.depth * 0.18)
            p.near.addChildNode(roofSign)
        }

        let carPaints: [Paint] = [.brandRed, .glazingSky, .warmWhite, .roofNavy, .graphite, .brandOrange]
        let displayCount = tier == 0 ? 3 : (tier == 1 ? 4 : 6)
        for index in 0..<displayCount {
            let column = index % 3
            let row = index / 3
            addCar(
                to: p.props,
                x: -c.width * 0.26 + Float(column) * c.width * 0.26,
                z: c.depth * (0.18 + Float(row) * 0.17),
                paint: carPaints[index % carPaints.count],
                rotated: false
            )
        }
        for index in 0..<(tier + 2) {
            addFlag(to: p.near, x: -c.width * 0.38 + Float(index) * c.width * 0.16, z: c.depth * 0.42)
        }
        addPylonSign(to: p, x: c.width * 0.40, z: c.depth * 0.38, height: c.height * 0.92, brand: .brandBlue)
    }

    private func buildDisplayParking(_ c: BuildContext, _ p: AssetParts) {
        let lot = SCNNode(geometry: bayLotGeometry(width: c.width * 0.92, depth: c.depth * 0.92, rows: 2))
        lot.position = SCNVector3(0, 0.10, 0)
        p.root.addChildNode(lot)

        let banner = SCNNode(geometry: box(width: c.width * 0.7, height: 1.1, depth: 0.3, chamfer: 0.1, paint: .brandBlue))
        banner.position = SCNVector3(0, 1.5, -c.depth * 0.42)
        p.near.addChildNode(banner)

        let carPaints: [Paint] = [.brandRed, .warmWhite, .glazingSky, .roofNavy]
        for index in 0..<4 {
            addCar(
                to: p.props,
                x: -c.width * 0.30 + Float(index % 2) * c.width * 0.32,
                z: -c.depth * 0.14 + Float(index / 2) * c.depth * 0.30,
                paint: carPaints[index],
                rotated: false
            )
        }
        addFlag(to: p.near, x: -c.width * 0.40, z: -c.depth * 0.40)
        addFlag(to: p.near, x: c.width * 0.40, z: -c.depth * 0.40)
    }

    private func buildPlayerWorkshop(_ c: BuildContext, _ p: AssetParts, body: Bool) {
        let hallHeight = c.height * 0.60
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.14, width: c.width * 0.72 + 4, depth: c.depth * 0.46 + 4)
        let hall = SCNNode(geometry: facadeBox(
            width: c.width * 0.72, height: hallHeight, depth: c.depth * 0.46, chamfer: 0.25,
            wall: body ? .slateWall : .concrete, style: .rollerDoors(count: 3)
        ))
        hall.position = SCNVector3(0, hallHeight / 2, -c.depth * 0.14)
        p.root.addChildNode(hall)

        let roofCap = SCNNode(geometry: gableRoof(width: c.width * 0.72 + 1.2, depth: c.depth * 0.46 + 1.2, rise: c.height * 0.16))
        roofCap.position = SCNVector3(0, hallHeight, -c.depth * 0.14)
        p.root.addChildNode(roofCap)

        let band = SCNNode(geometry: box(width: c.width * 0.72, height: 1.0, depth: 0.5, chamfer: 0.15, paint: .brandBlue))
        band.position = SCNVector3(0, hallHeight * 0.78, c.depth * 0.10)
        p.near.addChildNode(band)

        if body {
            let vent = SCNNode(geometry: cylinder(radius: 0.8, height: c.height * 0.28, paint: .metalLight))
            vent.position = SCNVector3(c.width * 0.28, hallHeight + c.height * 0.14, -c.depth * 0.26)
            p.near.addChildNode(vent)
        }
        addCar(to: p.props, x: -c.width * 0.26, z: c.depth * 0.32, paint: .graphite, rotated: false)
        addCrate(to: p.props, x: c.width * 0.30, z: c.depth * 0.32)
    }

    private func buildCarWash(_ c: BuildContext, _ p: AssetParts) {
        let tunnelHeight = c.height * 0.62
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.10, width: c.width * 0.72 + 3, depth: c.depth * 0.52 + 3)
        let tunnel = SCNNode(geometry: box(width: c.width * 0.72, height: tunnelHeight, depth: c.depth * 0.52, chamfer: 0.3, paint: .glazingSky))
        tunnel.position = SCNVector3(0, tunnelHeight / 2, -c.depth * 0.10)
        p.root.addChildNode(tunnel)

        let roofBand = SCNNode(geometry: box(width: c.width * 0.78, height: 0.9, depth: c.depth * 0.58, chamfer: 0.3, paint: .roofNavy))
        roofBand.position = SCNVector3(0, tunnelHeight + 0.45, -c.depth * 0.10)
        p.root.addChildNode(roofBand)

        let sign = SCNNode(geometry: box(width: 1.6, height: 2.6, depth: 0.5, chamfer: 0.2, paint: .brandBlue))
        sign.position = SCNVector3(-c.width * 0.30, 1.3, c.depth * 0.36)
        p.near.addChildNode(sign)
        addCar(to: p.props, x: c.width * 0.10, z: c.depth * 0.32, paint: .brandRed, rotated: false)
    }

    private func buildVehicleYard(_ c: BuildContext, _ p: AssetParts) {
        let yard = SCNNode(geometry: box(width: c.width * 0.92, height: 0.24, depth: c.depth * 0.92, chamfer: 0.2, paint: .gravel))
        yard.position = SCNVector3(0, 0.12, 0)
        p.root.addChildNode(yard)

        let office = SCNNode(geometry: box(width: c.width * 0.22, height: 3.2, depth: c.depth * 0.14, chamfer: 0.2, paint: .brandBlue))
        office.position = SCNVector3(-c.width * 0.32, 1.8, c.depth * 0.36)
        p.root.addChildNode(office)

        let carPaints: [Paint] = [.warmWhite, .graphite, .glazingSky, .brandRed, .roofNavy, .sand]
        for index in 0..<6 {
            addCar(
                to: p.props,
                x: -c.width * 0.28 + Float(index % 3) * c.width * 0.28,
                z: -c.depth * 0.24 + Float(index / 3) * c.depth * 0.28,
                paint: carPaints[index],
                rotated: true
            )
        }
        addFence(to: p.near, width: c.width * 0.92, depth: c.depth * 0.92)
    }

    private func buildPlayerOffice(_ c: BuildContext, _ p: AssetParts) {
        let height = c.height * 0.92
        let floors = max(3, Int((height / 3.2).rounded()))
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.04, width: c.width * 0.72 + 3, depth: c.depth * 0.62 + 3)
        let body = SCNNode(geometry: facadeBox(
            width: c.width * 0.72, height: height, depth: c.depth * 0.62, chamfer: 0.25,
            wall: .warmWhite, style: .punched(floors: floors, columns: 4, balconies: false)
        ))
        body.position = SCNVector3(0, height / 2, -c.depth * 0.04)
        p.root.addChildNode(body)

        let entrance = SCNNode(geometry: box(width: c.width * 0.30, height: 3.0, depth: c.depth * 0.14, chamfer: 0.2, paint: .brandBlue))
        entrance.position = SCNVector3(0, 1.5, c.depth * 0.32)
        p.root.addChildNode(entrance)
        let crown = SCNNode(geometry: box(width: c.width * 0.5, height: 1.0, depth: c.depth * 0.4, chamfer: 0.2, paint: .graphite))
        crown.position = SCNVector3(0, height + 0.5, -c.depth * 0.04)
        p.near.addChildNode(crown)
    }

    private func buildPartsWarehouse(_ c: BuildContext, _ p: AssetParts) {
        let hallHeight = c.height * 0.66
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.12, width: c.width * 0.76 + 4, depth: c.depth * 0.52 + 4)
        let hall = SCNNode(geometry: facadeBox(
            width: c.width * 0.76, height: hallHeight, depth: c.depth * 0.52, chamfer: 0.25,
            wall: .sage, style: .rollerDoors(count: 2)
        ))
        hall.position = SCNVector3(0, hallHeight / 2, -c.depth * 0.12)
        p.root.addChildNode(hall)
        let band = SCNNode(geometry: box(width: c.width * 0.76 + 1.0, height: 1.2, depth: c.depth * 0.52 + 1.0, chamfer: 0.2, paint: .brandBlue))
        band.position = SCNVector3(0, hallHeight + 0.6, -c.depth * 0.12)
        p.root.addChildNode(band)

        addCrate(to: p.props, x: -c.width * 0.28, z: c.depth * 0.30)
        addCrate(to: p.props, x: -c.width * 0.10, z: c.depth * 0.34)
        addTruck(to: p.props, x: c.width * 0.24, z: c.depth * 0.32)
    }

    private func buildAuctionHouse(_ c: BuildContext, _ p: AssetParts) {
        let hallHeight = c.height * 0.60
        addGroundShadow(to: p, x: -c.width * 0.08, z: -c.depth * 0.16, width: c.width * 0.64 + 4, depth: c.depth * 0.44 + 4)
        let hall = SCNNode(geometry: box(width: c.width * 0.64, height: hallHeight, depth: c.depth * 0.44, chamfer: 0.3, paint: .warmWhite))
        hall.position = SCNVector3(-c.width * 0.08, hallHeight / 2, -c.depth * 0.16)
        p.root.addChildNode(hall)
        let hallRoof = SCNNode(geometry: gableRoof(width: c.width * 0.64 + 1.6, depth: c.depth * 0.44 + 1.6, rise: c.height * 0.18))
        hallRoof.position = SCNVector3(-c.width * 0.08, hallHeight, -c.depth * 0.16)
        p.root.addChildNode(hallRoof)

        let lobby = SCNNode(geometry: facadeBox(
            width: c.width * 0.30, height: hallHeight * 0.6, depth: c.depth * 0.20, chamfer: 0.25,
            wall: .glassTower, style: .curtain(floors: 2)
        ))
        lobby.position = SCNVector3(c.width * 0.26, hallHeight * 0.3, c.depth * 0.10)
        p.root.addChildNode(lobby)

        for index in 0..<4 {
            addFlag(to: p.near, x: -c.width * 0.34 + Float(index) * c.width * 0.22, z: c.depth * 0.40)
        }
        addParkingRow(to: p, carCount: 5, z: c.depth * 0.26, width: c.width * 0.9)
    }

    private func buildLogisticsCenter(_ c: BuildContext, _ p: AssetParts) {
        let hallHeight = c.height * 0.62
        addGroundShadow(to: p, x: 0, z: -c.depth * 0.20, width: c.width * 0.82 + 4, depth: c.depth * 0.42 + 4)
        let hall = SCNNode(geometry: facadeBox(
            width: c.width * 0.82, height: hallHeight, depth: c.depth * 0.42, chamfer: 0.25,
            wall: .warmWhite, style: .rollerDoors(count: 5)
        ))
        hall.position = SCNVector3(0, hallHeight / 2, -c.depth * 0.20)
        p.root.addChildNode(hall)
        let band = SCNNode(geometry: box(width: c.width * 0.82 + 1.2, height: 1.5, depth: c.depth * 0.42 + 1.2, chamfer: 0.2, paint: .brandBlue))
        band.position = SCNVector3(0, hallHeight + 0.75, -c.depth * 0.20)
        p.root.addChildNode(band)

        for index in 0..<4 {
            addTrailer(to: p.props, x: -c.width * 0.30 + Float(index) * c.width * 0.20, z: c.depth * 0.16)
        }
        addTruck(to: p.props, x: c.width * 0.34, z: c.depth * 0.36)
    }

    private func buildHeadquarters(_ c: BuildContext, _ p: AssetParts) {
        let podiumHeight = c.height * 0.14
        let podium = SCNNode(geometry: facadeBox(
            width: c.width * 0.84, height: podiumHeight, depth: c.depth * 0.64, chamfer: 0.3,
            wall: .warmWhite, style: .shopfront(fascia: .brandBlue)
        ))
        podium.position = SCNVector3(0, podiumHeight / 2, c.depth * 0.04)
        p.root.addChildNode(podium)

        let towerHeight = c.height * 0.98 - podiumHeight
        addGroundShadow(to: p, x: -c.width * 0.08, z: -c.depth * 0.05, width: c.width * 0.60, depth: c.depth * 0.55)
        let tower = SCNNode(geometry: facadeBox(
            width: c.width * 0.46, height: towerHeight, depth: c.depth * 0.40, chamfer: 0.3,
            wall: .glassTower, style: .curtain(floors: max(6, Int(towerHeight / 3.4)))
        ))
        tower.position = SCNVector3(-c.width * 0.08, podiumHeight + towerHeight / 2, -c.depth * 0.05)
        p.root.addChildNode(tower)

        let crown = SCNNode(geometry: box(width: c.width * 0.34, height: 1.6, depth: c.depth * 0.30, chamfer: 0.25, paint: .brandBlue))
        crown.position = SCNVector3(-c.width * 0.08, podiumHeight + towerHeight + 0.8, -c.depth * 0.05)
        p.near.addChildNode(crown)

        for index in 0..<3 {
            addFlag(to: p.near, x: -c.width * 0.20 + Float(index) * c.width * 0.20, z: c.depth * 0.42)
        }
        addGardenTree(to: p.props, x: c.width * 0.36, z: c.depth * 0.32, scale: 0.85)
    }

    // MARK: - Lot infill

    private func buildInfill(
        category: CityAssetCategory,
        width: Float,
        depth: Float,
        root: SCNNode,
        near: SCNNode,
        props: SCNNode
    ) {
        let plateHeight: Float = 0.14
        let plateWidth = width - 2.4
        let plateDepth = depth - 2.4

        func addPlate(_ paint: Paint) {
            let plate = SCNNode(geometry: box(width: plateWidth, height: plateHeight, depth: plateDepth, chamfer: 0.5, paint: paint))
            plate.position = SCNVector3(0, plateHeight / 2, 0)
            root.addChildNode(plate)
        }

        switch category {
        case .generalResidential, .luxuryResidential:
            addPlate(.lawn)
            let path = SCNNode(geometry: box(width: width * 0.14, height: 0.06, depth: plateDepth * 0.5, chamfer: 0.1, paint: .lotConcrete))
            path.position = SCNVector3(0, plateHeight + 0.03, plateDepth * 0.25)
            near.addChildNode(path)
        case .commercial, .highway:
            addPlate(.asphalt)
            let apron = SCNNode(geometry: box(width: width * 0.3, height: 0.06, depth: depth * 0.16, chamfer: 0.1, paint: .lotConcrete))
            apron.position = SCNVector3(0, plateHeight + 0.03, plateDepth / 2 - depth * 0.08)
            near.addChildNode(apron)
        case .industrial:
            addPlate(.lotConcrete)
            let markings = SCNNode(geometry: box(width: width * 0.4, height: 0.05, depth: 0.5, chamfer: 0, paint: .safetyYellow))
            markings.position = SCNVector3(0, plateHeight + 0.025, plateDepth * 0.3)
            near.addChildNode(markings)
        case .downtown:
            addPlate(.lotConcrete)
            for x in [-plateWidth * 0.36, plateWidth * 0.36] {
                let planter = SCNNode(geometry: box(width: 2.6, height: 0.8, depth: 2.6, chamfer: 0.2, paint: .concrete))
                planter.position = SCNVector3(x, plateHeight + 0.4, plateDepth * 0.38)
                near.addChildNode(planter)
            }
        case .parking:
            addPlate(.asphalt)
        case .playerFacility:
            addPlate(.asphalt)
            let welcome = SCNNode(geometry: box(width: width * 0.24, height: 0.06, depth: depth * 0.10, chamfer: 0.1, paint: .brandBlue))
            welcome.position = SCNVector3(0, plateHeight + 0.03, plateDepth / 2 - depth * 0.05)
            near.addChildNode(welcome)
        }
    }

    // MARK: - Shared components

    /// Soft baked shadow that grounds a mass on its lot. Sized generously
    /// beyond the mass so the penumbra reads at map zoom.
    private func addGroundShadow(
        to parts: AssetParts,
        x: Float,
        z: Float,
        width: Float,
        depth: Float
    ) {
        let key = "shadow-\(Int(width))x\(Int(depth))"
        let geometry: SCNGeometry
        if let cached = geometries[key] {
            geometry = cached
        } else {
            let plane = SCNPlane(width: CGFloat(width), height: CGFloat(depth))
            let material = SCNMaterial()
            material.diffuse.contents = CityGroundArt.blobShadowTexture()
            material.lightingModel = .constant
            material.blendMode = .alpha
            material.writesToDepthBuffer = false
            plane.firstMaterial = material
            geometries[key] = plane
            geometry = plane
        }
        let node = SCNNode(geometry: geometry)
        node.eulerAngles.x = -.pi / 2
        node.position = SCNVector3(x, 0.17, z)
        parts.root.addChildNode(node)
    }

    private enum RoofStyle { case hipped, gabled, flat }

    /// A house = wall mass + faceted overhanging roof (+ optional chimney).
    private func addHouse(
        to parts: AssetParts,
        x: Float,
        z: Float,
        width: Float,
        depth: Float,
        wallHeight: Float,
        wall: Paint,
        roof: Paint,
        roofStyle: RoofStyle,
        withChimney: Bool
    ) {
        addGroundShadow(to: parts, x: x, z: z, width: width + 2.2, depth: depth + 2.2)
        let body = SCNNode(geometry: facadeBox(
            width: width, height: wallHeight, depth: depth, chamfer: 0.18,
            wall: wall, style: .cottage
        ))
        body.position = SCNVector3(x, wallHeight / 2, z)
        parts.root.addChildNode(body)

        let overhang: Float = 1.1
        switch roofStyle {
        case .hipped:
            let roofNode = SCNNode(geometry: hippedRoof(
                width: width + overhang * 2, depth: depth + overhang * 2,
                rise: max(2.2, wallHeight * 0.62), paint: roof
            ))
            roofNode.name = "hipped-roof"
            roofNode.position = SCNVector3(x, wallHeight + 0.06, z)
            parts.root.addChildNode(roofNode)
        case .gabled:
            let roofNode = SCNNode(geometry: gableRoof(
                width: width + overhang * 2, depth: depth + overhang * 2,
                rise: max(2.4, wallHeight * 0.66), paint: roof
            ))
            roofNode.name = "hipped-roof"
            roofNode.position = SCNVector3(x, wallHeight + 0.06, z)
            parts.root.addChildNode(roofNode)
        case .flat:
            let parapet = SCNNode(geometry: box(width: width + 0.8, height: 0.7, depth: depth + 0.8, chamfer: 0.15, paint: roof))
            parapet.position = SCNVector3(x, wallHeight + 0.35, z)
            parts.root.addChildNode(parapet)
        }
        if withChimney {
            let chimney = SCNNode(geometry: box(width: 0.9, height: 2.4, depth: 0.9, chamfer: 0.1, paint: .brick))
            chimney.position = SCNVector3(x + width * 0.28, wallHeight + 1.6, z - depth * 0.2)
            parts.near.addChildNode(chimney)
        }
    }

    private func addParkingRow(to parts: AssetParts, carCount: Int, z: Float, width: Float) {
        let strip = SCNNode(geometry: bayLotGeometry(width: width, depth: 7.4, rows: 1))
        strip.position = SCNVector3(0, 0.11, z)
        parts.near.addChildNode(strip)
        let paints: [Paint] = [.brandRed, .glazingSky, .warmWhite, .graphite, .roofNavy]
        for index in 0..<carCount where index.isMultiple(of: 2) {
            addCar(
                to: parts.props,
                x: -width / 2 + width * (Float(index) + 0.5) / Float(carCount),
                z: z,
                paint: paints[index % paints.count],
                rotated: false
            )
        }
    }

    private func addPylonSign(to parts: AssetParts, x: Float, z: Float, height: Float, brand: Paint) {
        let pole = SCNNode(geometry: box(width: 0.8, height: height, depth: 0.8, chamfer: 0.1, paint: .metalDark))
        pole.position = SCNVector3(x, height / 2, z)
        parts.near.addChildNode(pole)
        let panel = SCNNode(geometry: box(width: 4.6, height: 2.6, depth: 0.6, chamfer: 0.2, paint: brand))
        panel.position = SCNVector3(x, height - 1.4, z)
        parts.near.addChildNode(panel)
        let cap = SCNNode(geometry: box(width: 4.6, height: 0.5, depth: 0.6, chamfer: 0.1, paint: .signWhite))
        cap.position = SCNVector3(x, height + 0.15, z)
        parts.near.addChildNode(cap)
    }

    private func addFlag(to parent: SCNNode, x: Float, z: Float) {
        let pole = SCNNode(geometry: cylinder(radius: 0.10, height: 5.4, paint: .metalLight))
        pole.position = SCNVector3(x, 2.7, z)
        parent.addChildNode(pole)
        let flag = SCNNode(geometry: box(width: 1.7, height: 1.1, depth: 0.08, chamfer: 0, paint: .brandBlue))
        flag.position = SCNVector3(x + 0.9, 4.7, z)
        parent.addChildNode(flag)
    }

    private func addGardenTree(to parent: SCNNode, x: Float, z: Float, scale: Float) {
        let trunk = SCNNode(geometry: cylinder(radius: 0.5, height: 2.4, paint: .doorWood))
        trunk.position = SCNVector3(x, 1.2 * scale, z)
        trunk.scale = SCNVector3(scale, scale, scale)
        parent.addChildNode(trunk)
        let canopy = SCNNode(geometry: sphere(radius: 3.0, paint: .treeGreen))
        canopy.position = SCNVector3(x, 4.4 * scale, z)
        canopy.scale = SCNVector3(scale, scale, scale)
        parent.addChildNode(canopy)
    }

    private func addHedge(to parent: SCNNode, width: Float, x: Float, z: Float) {
        let hedge = SCNNode(geometry: box(width: width, height: 1.2, depth: 1.3, chamfer: 0.35, paint: .treeGreen))
        hedge.position = SCNVector3(x, 0.62, z)
        parent.addChildNode(hedge)
    }

    private func addFence(to parent: SCNNode, width: Float, depth: Float) {
        for (w, d, x, z) in [
            (width, Float(0.3), Float(0), -depth / 2),
            (width, 0.3, 0, depth / 2),
            (0.3, depth, -width / 2, 0),
            (0.3, depth, width / 2, 0)
        ] {
            let rail = SCNNode(geometry: box(width: w, height: 1.2, depth: d, chamfer: 0.05, paint: .metalDark))
            rail.position = SCNVector3(x, 0.85, z)
            parent.addChildNode(rail)
        }
    }

    private func addCar(to parent: SCNNode, x: Float, z: Float, paint: Paint, rotated: Bool) {
        let car = SCNNode()
        let body = SCNNode(geometry: box(width: 6.0, height: 1.65, depth: 2.8, chamfer: 0.58, paint: paint))
        body.position.y = 1.15
        car.addChildNode(body)
        let cabin = SCNNode(geometry: box(width: 3.2, height: 1.25, depth: 2.4, chamfer: 0.50, paint: .glazing))
        cabin.position = SCNVector3(-0.30, 2.30, 0)
        car.addChildNode(cabin)
        for zOffset in [-1.32 as Float, 1.32] {
            let wheels = SCNNode(geometry: box(
                width: 4.5,
                height: 0.72,
                depth: 0.34,
                chamfer: 0.12,
                paint: .graphite
            ))
            wheels.position = SCNVector3(0, 0.58, zOffset)
            car.addChildNode(wheels)
        }
        car.position = SCNVector3(x, 0, z)
        if rotated { car.eulerAngles.y = .pi / 2 }
        parent.addChildNode(car)
    }

    private func addTruck(to parent: SCNNode, x: Float, z: Float) {
        let truck = SCNNode()
        let cab = SCNNode(geometry: box(width: 1.9, height: 2.3, depth: 2.2, chamfer: 0.25, paint: .brandBlue))
        cab.position = SCNVector3(-2.9, 1.35, 0)
        truck.addChildNode(cab)
        let cargo = SCNNode(geometry: box(width: 5.4, height: 2.7, depth: 2.3, chamfer: 0.15, paint: .warmWhite))
        cargo.position = SCNVector3(0.5, 1.55, 0)
        truck.addChildNode(cargo)
        truck.position = SCNVector3(x, 0, z)
        parent.addChildNode(truck)
    }

    private func addTrailer(to parent: SCNNode, x: Float, z: Float) {
        let trailer = SCNNode(geometry: box(width: 3.4, height: 2.5, depth: 2.2, chamfer: 0.12, paint: .metalLight))
        trailer.position = SCNVector3(x, 1.45, z)
        parent.addChildNode(trailer)
    }

    private func addCrate(to parent: SCNNode, x: Float, z: Float) {
        let crate = SCNNode(geometry: box(width: 2.6, height: 1.7, depth: 2.0, chamfer: 0.1, paint: .doorWood))
        crate.position = SCNVector3(x, 0.85, z)
        parent.addChildNode(crate)
    }

    private func signBoard(width: Float, height: Float) -> SCNGeometry {
        let key = "sign-\(Int(width * 10))x\(Int(height * 10))"
        if let cached = geometries[key] { return cached }
        let geometry = SCNBox(width: CGFloat(width), height: CGFloat(height), length: 0.6, chamferRadius: 0.2)
        let face = SCNMaterial()
        face.diffuse.contents = CityFacadeArt.dealerSignTexture()
        face.lightingModel = .lambert
        let side = material(.brandBlue)
        geometry.materials = [face, side, face, side, side, side]
        geometries[key] = geometry
        return geometry
    }

    // MARK: - Geometry cache

    private func box(width: Float, height: Float, depth: Float, chamfer: Float, paint: Paint) -> SCNGeometry {
        let key = "box-\(Int(width * 10))-\(Int(height * 10))-\(Int(depth * 10))-\(Int(chamfer * 100))-\(paint.rawValue)"
        if let cached = geometries[key] { return cached }
        let geometry = SCNBox(
            width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth),
            chamferRadius: CGFloat(min(chamfer, min(width, height, depth) / 2))
        )
        geometry.firstMaterial = material(paint)
        geometries[key] = geometry
        return geometry
    }

    private func cylinder(radius: Float, height: Float, paint: Paint) -> SCNGeometry {
        let key = "cyl-\(Int(radius * 10))-\(Int(height * 10))-\(paint.rawValue)"
        if let cached = geometries[key] { return cached }
        let geometry = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        geometry.radialSegmentCount = 12
        geometry.firstMaterial = material(paint)
        geometries[key] = geometry
        return geometry
    }

    private func cone(topRadius: Float, bottomRadius: Float, height: Float, paint: Paint) -> SCNGeometry {
        let key = "cone-\(Int(topRadius * 10))-\(Int(bottomRadius * 10))-\(Int(height * 10))-\(paint.rawValue)"
        if let cached = geometries[key] { return cached }
        let geometry = SCNCone(topRadius: CGFloat(topRadius), bottomRadius: CGFloat(bottomRadius), height: CGFloat(height))
        geometry.radialSegmentCount = 10
        geometry.firstMaterial = material(paint)
        geometries[key] = geometry
        return geometry
    }

    private func sphere(radius: Float, paint: Paint) -> SCNGeometry {
        let key = "sphere-\(Int(radius * 10))-\(paint.rawValue)"
        if let cached = geometries[key] { return cached }
        let geometry = SCNSphere(radius: CGFloat(radius))
        geometry.segmentCount = 10
        geometry.firstMaterial = material(paint)
        geometries[key] = geometry
        return geometry
    }

    /// Wall box whose four sides carry a baked facade texture.
    private func facadeBox(
        width: Float,
        height: Float,
        depth: Float,
        chamfer: Float,
        wall: Paint,
        style: CityFacadeArt.Style
    ) -> SCNGeometry {
        let key = "facade-\(Int(width * 10))-\(Int(height * 10))-\(Int(depth * 10))-\(wall.rawValue)-\(style.cacheKey)"
        if let cached = geometries[key] { return cached }
        let geometry = SCNBox(
            width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth),
            chamferRadius: CGFloat(chamfer)
        )
        let front = facadeMaterial(wall: wall, style: style, wide: true)
        let side = facadeMaterial(wall: wall, style: style, wide: false)
        let top = material(wall)
        // SCNBox side order: +z, +x, -z, -x, top, bottom.
        geometry.materials = [front, side, front, side, top, top]
        geometries[key] = geometry
        return geometry
    }

    private func facadeMaterial(wall: Paint, style: CityFacadeArt.Style, wide: Bool) -> SCNMaterial {
        let key = "facade-\(wall.rawValue)-\(style.cacheKey)-\(wide ? "w" : "n")"
        if let cached = materials[key] { return cached }
        let result = SCNMaterial()
        result.diffuse.contents = CityFacadeArt.texture(style: style, wall: wall.color, wide: wide)
        result.lightingModel = .blinn
        result.shininess = 0.12
        result.locksAmbientWithDiffuse = true
        materials[key] = result
        return result
    }

    private func material(_ paint: Paint) -> SCNMaterial {
        if let cached = materials[paint.rawValue] { return cached }
        let result = SCNMaterial()
        // Broad ground plates read as painted surfaces instead of plastic
        // when they carry the shared noise textures.
        switch paint {
        case .lawn:
            result.diffuse.contents = CityGroundArt.parkTexture()
            result.diffuse.wrapS = .repeat
            result.diffuse.wrapT = .repeat
            result.diffuse.contentsTransform = SCNMatrix4MakeScale(3.2, 3.2, 1)
        case .asphalt:
            result.diffuse.contents = CityGroundArt.asphaltTexture(brightness: 0.36)
            result.diffuse.wrapS = .repeat
            result.diffuse.wrapT = .repeat
            result.diffuse.contentsTransform = SCNMatrix4MakeScale(3.2, 3.2, 1)
        case .lotConcrete:
            result.diffuse.contents = CityGroundArt.sidewalkTexture()
            result.diffuse.wrapS = .repeat
            result.diffuse.wrapT = .repeat
            result.diffuse.contentsTransform = SCNMatrix4MakeScale(3.2, 3.2, 1)
        case .gravel:
            result.diffuse.contents = CityGroundArt.gravelTexture()
            result.diffuse.wrapS = .repeat
            result.diffuse.wrapT = .repeat
            result.diffuse.contentsTransform = SCNMatrix4MakeScale(3.2, 3.2, 1)
        default:
            result.diffuse.contents = paint.color
        }
        result.lightingModel = .blinn
        result.shininess = switch paint {
        case .glazing, .glazingSky, .glassTower, .metalLight, .metalDark: 0.42
        default: 0.10
        }
        result.locksAmbientWithDiffuse = true
        materials[paint.rawValue] = result
        return result
    }

    // MARK: - Faceted roofs (shared, cached, normal-correct)

    private func hippedRoof(width: Float, depth: Float, rise: Float, paint: Paint) -> SCNGeometry {
        let key = "hip-\(Int(width * 10))-\(Int(depth * 10))-\(Int(rise * 10))-\(paint.rawValue)"
        if let cached = geometries[key] { return cached }

        let halfWidth = width / 2
        let halfDepth = depth / 2
        let ridgeHalf = max(0.5, (width - depth) / 2)
        let base = [
            SCNVector3(-halfWidth, 0, -halfDepth),
            SCNVector3(halfWidth, 0, -halfDepth),
            SCNVector3(halfWidth, 0, halfDepth),
            SCNVector3(-halfWidth, 0, halfDepth)
        ]
        let ridgeA = SCNVector3(-ridgeHalf, rise, 0)
        let ridgeB = SCNVector3(ridgeHalf, rise, 0)
        var faces: [[SCNVector3]] = [
            [base[0], base[1], ridgeB, ridgeA],
            [base[2], base[3], ridgeA, ridgeB],
            [base[1], base[2], ridgeB],
            [base[3], base[0], ridgeA]
        ]
        // A thin underside plate closes the eaves so the roof never shows a
        // hollow shell from street level.
        faces.append([base[3], base[2], base[1], base[0]])
        let geometry = facetedGeometry(faces: faces, paint: paint)
        geometries[key] = geometry
        return geometry
    }

    private func gableRoof(width: Float, depth: Float, rise: Float, paint: Paint = .roofCharcoal) -> SCNGeometry {
        let key = "gable-\(Int(width * 10))-\(Int(depth * 10))-\(Int(rise * 10))-\(paint.rawValue)"
        if let cached = geometries[key] { return cached }

        let halfWidth = width / 2
        let halfDepth = depth / 2
        let base = [
            SCNVector3(-halfWidth, 0, -halfDepth),
            SCNVector3(halfWidth, 0, -halfDepth),
            SCNVector3(halfWidth, 0, halfDepth),
            SCNVector3(-halfWidth, 0, halfDepth)
        ]
        let ridgeA = SCNVector3(-halfWidth, rise, 0)
        let ridgeB = SCNVector3(halfWidth, rise, 0)
        let faces: [[SCNVector3]] = [
            [base[0], base[1], ridgeB, ridgeA],
            [base[2], base[3], ridgeA, ridgeB],
            [base[1], base[2], ridgeB],
            [base[3], base[0], ridgeA],
            [base[3], base[2], base[1], base[0]]
        ]
        let geometry = facetedGeometry(faces: faces, paint: paint)
        geometries[key] = geometry
        return geometry
    }

    /// North-lit factory roof: sloped panels with vertical glass faces.
    private func sawtoothRoof(width: Float, depth: Float, teeth: Int, rise: Float) -> SCNGeometry {
        let key = "saw-\(Int(width * 10))-\(Int(depth * 10))-\(teeth)-\(Int(rise * 10))"
        if let cached = geometries[key] { return cached }

        let halfWidth = width / 2
        let halfDepth = depth / 2
        let toothWidth = width / Float(teeth)
        var slopeFaces: [[SCNVector3]] = []
        var glassFaces: [[SCNVector3]] = []
        for index in 0..<teeth {
            let x0 = -halfWidth + Float(index) * toothWidth
            let x1 = x0 + toothWidth
            slopeFaces.append([
                SCNVector3(x0, 0, -halfDepth),
                SCNVector3(x1, rise, -halfDepth),
                SCNVector3(x1, rise, halfDepth),
                SCNVector3(x0, 0, halfDepth)
            ])
            glassFaces.append([
                SCNVector3(x1, rise, -halfDepth),
                SCNVector3(x1, 0, -halfDepth),
                SCNVector3(x1, 0, halfDepth),
                SCNVector3(x1, rise, halfDepth)
            ])
        }
        let geometry = facetedGeometry(
            faceGroups: [
                (slopeFaces, material(.roofSlate)),
                (glassFaces, material(.glazingSky))
            ]
        )
        geometries[key] = geometry
        return geometry
    }

    private func facetedGeometry(faces: [[SCNVector3]], paint: Paint) -> SCNGeometry {
        facetedGeometry(faceGroups: [(faces, material(paint))])
    }

    private func facetedGeometry(
        faceGroups: [([[SCNVector3]], SCNMaterial)]
    ) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var elements: [SCNGeometryElement] = []
        var elementMaterials: [SCNMaterial] = []

        // Back-face culling depends on triangle winding, so every face is
        // re-wound to face away from the shape's centroid before indexing.
        let allVertices = faceGroups.flatMap { $0.0.flatMap { $0 } }
        let centroid = allVertices.reduce(SCNVector3Zero) {
            SCNVector3($0.x + $1.x / Float(allVertices.count),
                       $0.y + $1.y / Float(allVertices.count),
                       $0.z + $1.z / Float(allVertices.count))
        }

        for (faces, faceMaterial) in faceGroups {
            var indices: [UInt32] = []
            for rawFace in faces {
                guard rawFace.count >= 3 else { continue }
                var face = rawFace
                var normal = faceNormal(face)
                let faceCenter = face.reduce(SCNVector3Zero) {
                    SCNVector3($0.x + $1.x / Float(face.count),
                               $0.y + $1.y / Float(face.count),
                               $0.z + $1.z / Float(face.count))
                }
                let outward = SCNVector3(
                    faceCenter.x - centroid.x,
                    faceCenter.y - centroid.y,
                    faceCenter.z - centroid.z
                )
                if normal.x * outward.x + normal.y * outward.y + normal.z * outward.z < 0 {
                    face.reverse()
                    normal = SCNVector3(-normal.x, -normal.y, -normal.z)
                }
                let start = UInt32(vertices.count)
                vertices.append(contentsOf: face)
                normals.append(contentsOf: Array(repeating: normal, count: face.count))
                for index in 1..<(face.count - 1) {
                    indices.append(start)
                    indices.append(start + UInt32(index))
                    indices.append(start + UInt32(index + 1))
                }
            }
            elements.append(SCNGeometryElement(indices: indices, primitiveType: .triangles))
            elementMaterials.append(faceMaterial)
        }

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals)
            ],
            elements: elements
        )
        geometry.materials = elementMaterials
        return geometry
    }

    private func faceNormal(_ face: [SCNVector3]) -> SCNVector3 {
        let a = face[0]
        let b = face[1]
        let c = face[2]
        let ab = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
        let ac = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
        var normal = SCNVector3(
            ab.y * ac.z - ab.z * ac.y,
            ab.z * ac.x - ab.x * ac.z,
            ab.x * ac.y - ab.y * ac.x
        )
        let length = max(0.0001, sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z))
        normal.x /= length
        normal.y /= length
        normal.z /= length
        return normal
    }

    /// Painted parking bays on a thin asphalt slab, baked as one geometry.
    private func bayLotGeometry(width: Float, depth: Float, rows: Int) -> SCNGeometry {
        let key = "baylot-\(Int(width))x\(Int(depth))x\(rows)"
        if let cached = geometries[key] { return cached }
        let geometry = SCNBox(width: CGFloat(width), height: 0.2, length: CGFloat(depth), chamferRadius: 0.1)
        let top = SCNMaterial()
        top.diffuse.contents = CityFacadeArt.parkingBayTexture(rows: rows)
        top.lightingModel = .lambert
        let side = material(.asphalt)
        geometry.materials = [side, side, side, side, top, side]
        geometries[key] = geometry
        return geometry
    }
}

// MARK: - Facade textures

/// Baked facade artwork. Windows, shopfronts, roller doors and parking bays
/// are drawn once per style and shared, which keeps geometry counts tiny while
/// killing the flat "colored box" look.
@MainActor
enum CityFacadeArt {
    enum Style {
        case punched(floors: Int, columns: Int, balconies: Bool)
        case ribbon(floors: Int)
        case curtain(floors: Int)
        case shopfront(fascia: CityBuildingFactory.Paint)
        case rollerDoors(count: Int)
        case parkingDecks(levels: Int)
        case cottage

        var cacheKey: String {
            switch self {
            case .punched(let floors, let columns, let balconies):
                "p\(floors)-\(columns)-\(balconies ? 1 : 0)"
            case .ribbon(let floors): "r\(floors)"
            case .curtain(let floors): "c\(floors)"
            case .shopfront(let fascia): "s\(fascia.rawValue)"
            case .rollerDoors(let count): "d\(count)"
            case .parkingDecks(let levels): "k\(levels)"
            case .cottage: "h"
            }
        }
    }

    private static var cache: [String: UIImage] = [:]

    static func texture(style: Style, wall: UIColor, wide: Bool) -> UIImage {
        let key = "\(style.cacheKey)-\(wall.description)-\(wide ? "w" : "n")"
        if let image = cache[key] { return image }

        let size = CGSize(width: wide ? 256 : 160, height: 192)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            wall.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            draw(style: style, wall: wall, size: size, context: context.cgContext)
        }
        cache[key] = image
        return image
    }

    private static let glass = UIColor(red: 0.28, green: 0.37, blue: 0.46, alpha: 1)
    private static let glassLight = UIColor(red: 0.55, green: 0.68, blue: 0.78, alpha: 1)
    private static let frame = UIColor(white: 0.22, alpha: 0.35)

    private static func draw(style: Style, wall: UIColor, size: CGSize, context: CGContext) {
        switch style {
        case .punched(let floors, let columns, let balconies):
            let marginY = size.height * 0.06
            let floorHeight = (size.height - marginY * 2) / CGFloat(floors)
            let columnWidth = size.width / CGFloat(columns)
            for floor in 0..<floors {
                let y = marginY + CGFloat(floor) * floorHeight
                for column in 0..<columns {
                    let x = CGFloat(column) * columnWidth
                    let window = CGRect(
                        x: x + columnWidth * 0.22,
                        y: y + floorHeight * 0.20,
                        width: columnWidth * 0.56,
                        height: floorHeight * 0.52
                    )
                    frame.setFill()
                    UIRectFill(window.insetBy(dx: -1.5, dy: -1.5))
                    ((floor + column).isMultiple(of: 3) ? glassLight : glass).setFill()
                    UIRectFill(window)
                }
                if balconies {
                    UIColor(white: 1, alpha: 0.5).setFill()
                    UIRectFill(CGRect(x: 0, y: y + floorHeight * 0.78, width: size.width, height: 2.5))
                }
            }
        case .ribbon(let floors):
            let floorHeight = size.height / CGFloat(floors + 1)
            for floor in 0..<floors {
                let y = floorHeight * (0.55 + CGFloat(floor))
                frame.setFill()
                UIRectFill(CGRect(x: 4, y: y - 1.5, width: size.width - 8, height: floorHeight * 0.42 + 3))
                glass.setFill()
                UIRectFill(CGRect(x: 4, y: y, width: size.width - 8, height: floorHeight * 0.42))
                glassLight.setFill()
                var x: CGFloat = 4
                while x < size.width - 8 {
                    UIRectFill(CGRect(x: x, y: y, width: 1.4, height: floorHeight * 0.42))
                    x += size.width / 9
                }
            }
        case .curtain(let floors):
            glass.setFill()
            UIRectFill(CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))
            glassLight.withAlphaComponent(0.7).setFill()
            for floor in 0...floors {
                let y = 2 + (size.height - 4) * CGFloat(floor) / CGFloat(floors)
                UIRectFill(CGRect(x: 2, y: y - 0.7, width: size.width - 4, height: 1.4))
            }
            for column in 0...8 {
                let x = 2 + (size.width - 4) * CGFloat(column) / 8
                UIRectFill(CGRect(x: x - 0.7, y: 2, width: 1.4, height: size.height - 4))
            }
            // Sky reflection gradient band.
            UIColor(red: 0.72, green: 0.83, blue: 0.90, alpha: 0.35).setFill()
            context.beginPath()
            context.move(to: CGPoint(x: 0, y: size.height * 0.12))
            context.addLine(to: CGPoint(x: size.width, y: 0))
            context.addLine(to: CGPoint(x: size.width, y: size.height * 0.30))
            context.addLine(to: CGPoint(x: 0, y: size.height * 0.46))
            context.closePath()
            context.fillPath()
        case .shopfront(let fascia):
            glass.setFill()
            UIRectFill(CGRect(x: size.width * 0.06, y: size.height * 0.34, width: size.width * 0.88, height: size.height * 0.60))
            glassLight.setFill()
            for index in 0..<5 {
                let x = size.width * (0.06 + 0.88 * CGFloat(index) / 5)
                UIRectFill(CGRect(x: x, y: size.height * 0.34, width: 2, height: size.height * 0.60))
            }
            fascia.color.setFill()
            UIRectFill(CGRect(x: 0, y: size.height * 0.10, width: size.width, height: size.height * 0.18))
            UIColor(white: 1, alpha: 0.92).setFill()
            UIRectFill(CGRect(x: size.width * 0.30, y: size.height * 0.145, width: size.width * 0.4, height: size.height * 0.09))
        case .rollerDoors(let count):
            let doorWidth = size.width / CGFloat(count)
            for index in 0..<count {
                let x = CGFloat(index) * doorWidth
                let door = CGRect(
                    x: x + doorWidth * 0.14,
                    y: size.height * 0.30,
                    width: doorWidth * 0.72,
                    height: size.height * 0.64
                )
                UIColor(white: 0.35, alpha: 1).setFill()
                UIRectFill(door.insetBy(dx: -2, dy: -2))
                UIColor(white: 0.62, alpha: 1).setFill()
                UIRectFill(door)
                UIColor(white: 0.48, alpha: 1).setFill()
                var y = door.minY + 4
                while y < door.maxY {
                    UIRectFill(CGRect(x: door.minX, y: y, width: door.width, height: 1.6))
                    y += 7
                }
            }
        case .parkingDecks(let levels):
            let levelHeight = size.height / CGFloat(levels)
            for level in 0..<levels {
                let y = CGFloat(level) * levelHeight
                UIColor(white: 0.16, alpha: 1).setFill()
                UIRectFill(CGRect(x: 4, y: y + levelHeight * 0.30, width: size.width - 8, height: levelHeight * 0.44))
                UIColor(white: 0.86, alpha: 1).setFill()
                UIRectFill(CGRect(x: 0, y: y + levelHeight * 0.80, width: size.width, height: levelHeight * 0.16))
            }
        case .cottage:
            let windowWidth = size.width * 0.18
            let windowHeight = size.height * 0.30
            for x in [size.width * 0.16, size.width * 0.64] {
                let window = CGRect(x: x, y: size.height * 0.30, width: windowWidth, height: windowHeight)
                UIColor(white: 1, alpha: 0.9).setFill()
                UIRectFill(window.insetBy(dx: -2.5, dy: -2.5))
                glass.setFill()
                UIRectFill(window)
                UIColor(white: 1, alpha: 0.9).setFill()
                UIRectFill(CGRect(x: window.midX - 1, y: window.minY, width: 2, height: window.height))
                UIRectFill(CGRect(x: window.minX, y: window.midY - 1, width: window.width, height: 2))
            }
            let door = CGRect(x: size.width * 0.44, y: size.height * 0.42, width: size.width * 0.13, height: size.height * 0.52)
            UIColor(red: 0.49, green: 0.35, blue: 0.25, alpha: 1).setFill()
            UIRectFill(door)
        }
    }

    static func parkingBayTexture(rows: Int) -> UIImage {
        let key = "bays-\(rows)"
        if let image = cache[key] { return image }
        let size = CGSize(width: 256, height: 128 * max(1, rows))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(red: 0.36, green: 0.38, blue: 0.41, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.92, alpha: 0.85).setFill()
            let rowHeight = size.height / CGFloat(rows)
            for row in 0..<rows {
                let top = CGFloat(row) * rowHeight + rowHeight * 0.12
                let bottom = rowHeight * 0.55
                for index in 0...8 {
                    let x = size.width * CGFloat(index) / 8
                    UIRectFill(CGRect(x: x - 1.2, y: top, width: 2.4, height: bottom))
                }
                UIRectFill(CGRect(x: 0, y: top - 1.2, width: size.width, height: 2.4))
            }
        }
        cache[key] = image
        return image
    }

    static func dealerSignTexture() -> UIImage {
        let key = "dealer-sign"
        if let image = cache[key] { return image }
        let size = CGSize(width: 512, height: 128)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(red: 0.11, green: 0.62, blue: 0.60, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let text = "SUIHAMA MOTORS" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .black),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
        cache[key] = image
        return image
    }
}
