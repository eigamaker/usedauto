import Foundation

enum CityAssetCategory: String, Codable, CaseIterable, Sendable {
    case generalResidential
    case luxuryResidential
    case commercial
    case industrial
    case downtown
    case highway
    case parking
    case playerFacility
}

enum CityAssetID: String, Codable, CaseIterable, Sendable {
    // General residential: five controlled silhouette variants.
    case residentialCottage
    case residentialGable
    case residentialFlat
    case residentialTwin
    case residentialApartment

    // Luxury residential: four low-density variants.
    case luxuryCourtyard
    case luxuryGarage
    case luxuryPool
    case luxuryTerrace

    // Road-facing commercial: six variants.
    case commercialAutoDealer
    case commercialGasStation
    case commercialConvenience
    case commercialRestaurant
    case commercialShopping
    case commercialRoadside

    // Industrial: five large-mass variants.
    case industrialFactory
    case industrialWarehouse
    case industrialLoadingWarehouse
    case industrialTankWorks
    case industrialSmokestack

    // Downtown: five medium-rise variants.
    case downtownMixedUse
    case downtownOffice
    case downtownApartment
    case downtownParkingStructure
    case downtownCornerBlock

    // Highway / interchange surroundings.
    case highwayLogistics
    case highwayBigBox
    case highwayMotorHotel
    case surfaceParking

    // Reusable player facilities.
    case playerSmallDealer
    case playerMediumDealer
    case playerLargeDealer
    case playerDisplayParking
    case playerServiceWorkshop
    case playerBodyShop
    case playerCarWash
    case playerVehicleYard
    case playerOffice
    case playerPartsWarehouse
    case playerAuctionHouse
    case playerLogisticsCenter
    case playerHeadquarters
}

enum CityAssetOrigin: String, Codable, Sendable {
    case footprintCenterAtGround
}

struct GridClearance: Hashable, Codable, Sendable {
    let north: Int
    let east: Int
    let south: Int
    let west: Int

    static let none = GridClearance(north: 0, east: 0, south: 0, west: 0)
    static let frontOne = GridClearance(north: 0, east: 0, south: 1, west: 0)
    static let vehicleApron = GridClearance(north: 0, east: 1, south: 1, west: 1)

    var isValid: Bool { min(north, east, south, west) >= 0 }
}

struct GridSelectionVolume: Hashable, Codable, Sendable {
    let footprint: GridSize
    let horizontalInset: Float
    let maximumHeight: Float
}

struct CityAssetDefinition: Identifiable, Hashable, Codable, Sendable {
    let id: CityAssetID
    let category: CityAssetCategory
    let footprint: GridSize
    let origin: CityAssetOrigin
    let frontDirection: CardinalDirection
    let roadConnectionDirections: Set<CardinalDirection>
    let requiredClearance: GridClearance
    let allowedDistricts: Set<DistrictKind>
    let upgradeTo: CityAssetID?
    let selectionVolume: GridSelectionVolume
    let nominalHeight: Float

    var isPlayerFacility: Bool { category == .playerFacility }

    func footprint(facing worldDirection: CardinalDirection) -> GridSize {
        let turns = worldDirection.quarterTurnsClockwise(from: frontDirection)
        guard turns.isMultiple(of: 2) else {
            return GridSize(width: footprint.depth, depth: footprint.width)
        }
        return footprint
    }

    func roadConnections(facing worldDirection: CardinalDirection) -> Set<CardinalDirection> {
        let turns = worldDirection.quarterTurnsClockwise(from: frontDirection)
        return Set(roadConnectionDirections.map { $0.rotatedClockwise(turns: turns) })
    }

    func clearance(facing worldDirection: CardinalDirection) -> GridClearance {
        let turns = worldDirection.quarterTurnsClockwise(from: frontDirection)
        return requiredClearance.rotatedClockwise(turns: turns)
    }

    func selectionVolume(facing worldDirection: CardinalDirection) -> GridSelectionVolume {
        GridSelectionVolume(
            footprint: footprint(facing: worldDirection),
            horizontalInset: selectionVolume.horizontalInset,
            maximumHeight: selectionVolume.maximumHeight
        )
    }
}

extension GridClearance {
    fileprivate func rotatedClockwise(turns: Int) -> GridClearance {
        var result = self
        for _ in 0..<(turns % 4) {
            result = GridClearance(
                north: result.west,
                east: result.north,
                south: result.east,
                west: result.south
            )
        }
        return result
    }
}

struct CityAssetLODVisibility: Equatable, Sendable {
    let showsNearDetails: Bool
    let showsProps: Bool
}

enum CityAssetLODPolicy {
    static func visibility(zoomFactor: CGFloat) -> CityAssetLODVisibility {
        CityAssetLODVisibility(
            showsNearDetails: zoomFactor <= GridCameraZoom.scaleFactors[1] + 0.02,
            showsProps: zoomFactor <= GridCameraZoom.scaleFactors[2] + 0.02
        )
    }
}

/// Metadata for camera-baked 2.5D sprites. Grid/gameplay facts remain sourced
/// from `CityAssetCatalog`; this descriptor only adds raster-specific facts so
/// the artwork cannot silently diverge from collision or placement rules.
struct Iso25DSpriteDefinition: Identifiable, Equatable, Sendable {
    let assetID: CityAssetID
    let facing: CardinalDirection
    let imageName: String
    let pixelWidth: Int
    let pixelHeight: Int
    /// Normalized point inside the source image that represents the center of
    /// the ground footprint. Renderers align this point to the grid rect center.
    let groundAnchorX: Float
    let groundAnchorY: Float
    /// Fraction of the source image occupied by the projected ground diamond.
    /// This keeps every card scaled from its authoritative grid footprint rather
    /// than from arbitrary per-scene tuning values.
    let projectedFootprintWidthFraction: Float

    var id: String { "\(assetID.rawValue):\(facing.rawValue)" }
    var asset: CityAssetDefinition { CityAssetCatalog.definition(for: assetID) }
    var footprint: GridSize { asset.footprint }
    var origin: CityAssetOrigin { asset.origin }
    var frontDirection: CardinalDirection { asset.frontDirection }
    var roadConnectionDirections: Set<CardinalDirection> { asset.roadConnectionDirections }
    var requiredClearance: GridClearance { asset.requiredClearance }
    var allowedDistricts: Set<DistrictKind> { asset.allowedDistricts }
    var upgradeTo: CityAssetID? { asset.upgradeTo }
    var selectionVolume: GridSelectionVolume { asset.selectionVolume }

    var aspectRatio: Float { Float(pixelWidth) / Float(pixelHeight) }

    func supports(facing requestedFacing: CardinalDirection) -> Bool { facing == requestedFacing }
}

/// Camera-baked 2.5D artwork used by the fixed orthographic city camera. The
/// catalogue can select a small number of authored silhouette variants while
/// the grid catalogue remains the authority for placement, collision, road
/// access and selection.
enum Iso25DCityAssetCatalog {
    static let all: [Iso25DSpriteDefinition] = [
        sprite(.residentialCottage, facing: .north, imageName: "Iso25DHouseGeneralA_North"),
        sprite(.residentialCottage, facing: .south, imageName: "Iso25DHouseGeneralA"),
        sprite(.residentialCottage, facing: .east, imageName: "Iso25DHouseGeneralA_East"),
        sprite(.residentialCottage, facing: .west, imageName: "Iso25DHouseGeneralA_West"),
        sprite(.residentialApartment, facing: .east, imageName: "Iso25DResidentialApartmentB_East"),
        sprite(.residentialApartment, facing: .west, imageName: "Iso25DResidentialApartmentB_West"),

        sprite(.luxuryCourtyard, facing: .north, imageName: "Iso25DLuxuryVillaA_North"),
        sprite(.luxuryCourtyard, facing: .south, imageName: "Iso25DLuxuryVillaA"),
        sprite(.luxuryCourtyard, facing: .east, imageName: "Iso25DLuxuryVillaA_East"),
        sprite(.luxuryCourtyard, facing: .west, imageName: "Iso25DLuxuryVillaA_West"),
        sprite(.luxuryPool, facing: .east, imageName: "Iso25DLuxuryPoolB_East"),
        sprite(.luxuryPool, facing: .west, imageName: "Iso25DLuxuryPoolB_West"),

        sprite(.commercialConvenience, facing: .north, imageName: "Iso25DConvenienceStore_North"),
        sprite(.commercialConvenience, facing: .south, imageName: "Iso25DConvenienceStore"),
        sprite(.commercialConvenience, facing: .east, imageName: "Iso25DConvenienceStore_East"),
        sprite(.commercialConvenience, facing: .west, imageName: "Iso25DConvenienceStore_West"),
        sprite(.commercialGasStation, facing: .east, imageName: "Iso25DCommercialGasStationB_East"),
        sprite(.commercialGasStation, facing: .west, imageName: "Iso25DCommercialGasStationB_West"),

        sprite(.industrialFactory, facing: .north, imageName: "Iso25DIndustrialFactoryA_North"),
        sprite(.industrialFactory, facing: .south, imageName: "Iso25DIndustrialFactoryA"),
        sprite(.industrialFactory, facing: .east, imageName: "Iso25DIndustrialFactoryA_East"),
        sprite(.industrialFactory, facing: .west, imageName: "Iso25DIndustrialFactoryA_West"),
        sprite(.industrialLoadingWarehouse, facing: .east, imageName: "Iso25DIndustrialLoadingWarehouseB_East"),
        sprite(.industrialLoadingWarehouse, facing: .west, imageName: "Iso25DIndustrialLoadingWarehouseB_West"),

        sprite(.downtownMixedUse, facing: .north, imageName: "Iso25DDowntownMixedUseA_North"),
        sprite(.downtownMixedUse, facing: .south, imageName: "Iso25DDowntownMixedUseA"),
        sprite(.downtownMixedUse, facing: .east, imageName: "Iso25DDowntownMixedUseA_East"),
        sprite(.downtownMixedUse, facing: .west, imageName: "Iso25DDowntownMixedUseA_West"),
        sprite(.downtownOffice, facing: .east, imageName: "Iso25DDowntownOfficeB_East"),
        sprite(.downtownOffice, facing: .west, imageName: "Iso25DDowntownOfficeB_West"),

        sprite(.highwayLogistics, facing: .north, imageName: "Iso25DHighwayLogisticsA_North"),
        sprite(.highwayLogistics, facing: .south, imageName: "Iso25DHighwayLogisticsA"),
        sprite(.highwayLogistics, facing: .east, imageName: "Iso25DHighwayLogisticsA_East"),
        sprite(.highwayLogistics, facing: .west, imageName: "Iso25DHighwayLogisticsA_West"),
        sprite(.highwayBigBox, facing: .east, imageName: "Iso25DHighwayBigBoxB_East"),
        sprite(.highwayBigBox, facing: .west, imageName: "Iso25DHighwayBigBoxB_West"),

        sprite(.playerSmallDealer, facing: .north, imageName: "Iso25DDealer_North"),
        sprite(.playerSmallDealer, facing: .south, imageName: "Iso25DDealerSmall"),
        sprite(.playerSmallDealer, facing: .east, imageName: "Iso25DDealer_East"),
        sprite(.playerSmallDealer, facing: .west, imageName: "Iso25DDealer_West"),
        sprite(.playerMediumDealer, facing: .north, imageName: "Iso25DDealerMedium_North"),
        sprite(.playerMediumDealer, facing: .south, imageName: "Iso25DDealerMedium_South"),
        sprite(.playerMediumDealer, facing: .east, imageName: "Iso25DDealerMedium_East"),
        sprite(.playerMediumDealer, facing: .west, imageName: "Iso25DDealerMedium_West"),
        sprite(.playerLargeDealer, facing: .north, imageName: "Iso25DDealerLarge_North"),
        sprite(.playerLargeDealer, facing: .south, imageName: "Iso25DDealerLarge_South"),
        sprite(.playerLargeDealer, facing: .east, imageName: "Iso25DDealerLarge_East"),
        sprite(.playerLargeDealer, facing: .west, imageName: "Iso25DDealerLarge_West"),
        sprite(.playerServiceWorkshop, facing: .north, imageName: "Iso25DServiceWorkshop_North"),
        sprite(.playerServiceWorkshop, facing: .south, imageName: "Iso25DServiceWorkshop"),
        sprite(.playerServiceWorkshop, facing: .east, imageName: "Iso25DServiceWorkshop_East"),
        sprite(.playerServiceWorkshop, facing: .west, imageName: "Iso25DServiceWorkshop_West")
    ]

    private static let byKey = Dictionary(uniqueKeysWithValues: all.map {
        (key(assetID: $0.assetID, facing: $0.facing), $0)
    })

    static func definition(
        for id: CityAssetID,
        facing: CardinalDirection
    ) -> Iso25DSpriteDefinition? {
        let preferred = representativeAssetID(for: id)
        if let authoredVariant = byKey[key(assetID: preferred, facing: facing)] {
            return authoredVariant
        }
        let fallback = fallbackAssetID(for: id)
        return byKey[key(assetID: fallback, facing: facing)]
    }

    static func representativeAssetID(for id: CityAssetID) -> CityAssetID {
        switch id {
        case .residentialApartment,
             .luxuryPool,
             .commercialGasStation,
             .industrialLoadingWarehouse,
             .downtownOffice,
             .highwayBigBox:
            return id
        case .playerSmallDealer,
             .playerMediumDealer,
             .playerLargeDealer,
             .playerServiceWorkshop:
            return id
        default:
            return fallbackAssetID(for: id)
        }
    }

    private static func fallbackAssetID(for id: CityAssetID) -> CityAssetID {
        switch CityAssetCatalog.definition(for: id).category {
        case .generalResidential: return .residentialCottage
        case .luxuryResidential: return .luxuryCourtyard
        case .commercial: return .commercialConvenience
        case .industrial: return .industrialFactory
        case .downtown: return .downtownMixedUse
        case .highway: return .highwayLogistics
        case .parking: return id
        case .playerFacility:
            return switch id {
            case .playerSmallDealer, .playerMediumDealer, .playerLargeDealer: .playerSmallDealer
            case .playerServiceWorkshop: .playerServiceWorkshop
            default: id
            }
        }
    }

    private static func sprite(
        _ id: CityAssetID,
        facing: CardinalDirection,
        imageName: String,
        pixels: (width: Int, height: Int) = (1_024, 1_024)
    ) -> Iso25DSpriteDefinition {
        guard let calibration = Iso25DSpriteCalibration.byImageName[imageName] else {
            preconditionFailure(
                "No measured calibration for \(imageName) — run Tools/calibrate_iso25d_sprites.swift"
            )
        }
        return Iso25DSpriteDefinition(
            assetID: id,
            facing: facing,
            imageName: imageName,
            pixelWidth: pixels.width,
            pixelHeight: pixels.height,
            groundAnchorX: calibration.groundAnchorX,
            groundAnchorY: calibration.groundAnchorY,
            projectedFootprintWidthFraction: calibration.footprintWidthFraction
        )
    }

    private static func key(assetID: CityAssetID, facing: CardinalDirection) -> String {
        "\(assetID.rawValue):\(facing.rawValue)"
    }
}

extension CardinalDirection {
    fileprivate var clockwiseIndex: Int {
        switch self {
        case .north: 0
        case .east: 1
        case .south: 2
        case .west: 3
        }
    }

    fileprivate func quarterTurnsClockwise(from source: CardinalDirection) -> Int {
        (clockwiseIndex - source.clockwiseIndex + 4) % 4
    }

    fileprivate func rotatedClockwise(turns: Int) -> CardinalDirection {
        let target = (clockwiseIndex + turns) % 4
        return switch target {
        case 0: .north
        case 1: .east
        case 2: .south
        default: .west
        }
    }
}

enum CityAssetCatalog {
    static let definitions: [CityAssetDefinition] = ambientDefinitions + playerFacilityDefinitions

    static let ambientDefinitions: [CityAssetDefinition] = [
        // Ambient buildings occupy their entire four-by-four city parcel. The
        // parcel count, not an arbitrary lawn around a miniature building,
        // communicates land area on the city map.
        ambient(.residentialCottage, .generalResidential, .fourByFour, [.suburb], 7),
        ambient(.residentialGable, .generalResidential, .fourByFour, [.suburb], 8),
        ambient(.residentialFlat, .generalResidential, .fourByFour, [.suburb], 7),
        ambient(.residentialTwin, .generalResidential, .fourByFour, [.suburb], 8),
        ambient(.residentialApartment, .generalResidential, .fourByFour, [.suburb], 13),

        ambient(.luxuryCourtyard, .luxuryResidential, .fourByFour, [.emerging], 8, clearance: .vehicleApron),
        ambient(.luxuryGarage, .luxuryResidential, .fourByFour, [.emerging], 9, clearance: .frontOne),
        ambient(.luxuryPool, .luxuryResidential, .fourByFour, [.emerging], 8, clearance: .vehicleApron),
        ambient(.luxuryTerrace, .luxuryResidential, .fourByFour, [.emerging], 10, clearance: .frontOne),

        ambient(.commercialAutoDealer, .commercial, .fourByFour, [.station, .highway], 10, clearance: .frontOne),
        ambient(.commercialGasStation, .commercial, .fourByFour, [.station, .highway], 7, clearance: .frontOne),
        ambient(.commercialConvenience, .commercial, .fourByFour, [.station, .highway], 7, clearance: .frontOne),
        ambient(.commercialRestaurant, .commercial, .fourByFour, [.station, .highway], 8, clearance: .frontOne),
        ambient(.commercialShopping, .commercial, .fourByFour, [.station, .highway], 12, clearance: .frontOne),
        ambient(.commercialRoadside, .commercial, .fourByFour, [.station, .highway], 9, clearance: .frontOne),

        ambient(.industrialFactory, .industrial, .fourByFour, [.industrial], 13, clearance: .frontOne),
        ambient(.industrialWarehouse, .industrial, .fourByFour, [.industrial, .highway], 12, clearance: .frontOne),
        ambient(.industrialLoadingWarehouse, .industrial, .fourByFour, [.industrial, .highway], 11, clearance: .vehicleApron),
        ambient(.industrialTankWorks, .industrial, .fourByFour, [.industrial], 12, clearance: .frontOne),
        ambient(.industrialSmokestack, .industrial, .fourByFour, [.industrial], 18, clearance: .frontOne),

        ambient(.downtownMixedUse, .downtown, .fourByFour, [.downtown], 28),
        ambient(.downtownOffice, .downtown, .fourByFour, [.downtown], 34),
        ambient(.downtownApartment, .downtown, .fourByFour, [.downtown], 30),
        ambient(.downtownParkingStructure, .downtown, .fourByFour, [.downtown], 18),
        ambient(.downtownCornerBlock, .downtown, .fourByFour, [.downtown], 36),

        ambient(.highwayLogistics, .highway, .fourByFour, [.highway, .industrial], 12, clearance: .vehicleApron),
        ambient(.highwayBigBox, .highway, .fourByFour, [.highway], 11, clearance: .vehicleApron),
        ambient(.highwayMotorHotel, .highway, .fourByFour, [.highway], 15, clearance: .frontOne),
        ambient(.surfaceParking, .parking, .fourByFour, Set(DistrictKind.allCases), 1)
    ]

    static let playerFacilityDefinitions: [CityAssetDefinition] = [
        facility(.playerSmallDealer, .twoByTwo, Set(DistrictKind.allCases), 10, .frontOne, .playerMediumDealer),
        facility(.playerMediumDealer, .threeByThree, [.downtown, .station, .suburb, .emerging, .highway], 13, .frontOne, .playerLargeDealer),
        facility(.playerLargeDealer, .fourByFour, [.suburb, .industrial, .highway], 14, .vehicleApron, nil),
        facility(.playerDisplayParking, .twoByTwo, Set(DistrictKind.allCases), 1, .frontOne, .playerVehicleYard),
        facility(.playerServiceWorkshop, .twoByThree, [.station, .industrial, .highway], 11, .vehicleApron, .playerBodyShop),
        facility(.playerBodyShop, .twoByThree, [.industrial, .highway], 12, .vehicleApron, nil),
        facility(.playerCarWash, .oneByTwo, [.station, .industrial, .highway], 7, .frontOne, nil),
        facility(.playerVehicleYard, .threeByThree, [.industrial, .highway], 2, .vehicleApron, nil),
        facility(.playerOffice, .oneByOne, Set(DistrictKind.allCases), 12, .frontOne, .playerHeadquarters),
        facility(.playerPartsWarehouse, .twoByTwo, [.industrial, .highway], 10, .vehicleApron, .playerLogisticsCenter),
        facility(.playerAuctionHouse, .fourByFour, [.industrial, .highway], 14, .vehicleApron, nil),
        facility(.playerLogisticsCenter, .fourByFour, [.industrial, .highway], 13, .vehicleApron, nil),
        facility(.playerHeadquarters, .threeByThree, [.downtown, .station], 34, .frontOne, nil)
    ]

    static func definition(for id: CityAssetID) -> CityAssetDefinition {
        guard let definition = definitions.first(where: { $0.id == id }) else {
            preconditionFailure("Missing city asset definition: \(id.rawValue)")
        }
        return definition
    }

    static func ambientAssets(for district: DistrictKind) -> [CityAssetDefinition] {
        if district == .highway {
            // Interchanges naturally mix logistics, roadside retail, service
            // stations, and large commercial buildings. Using every compatible
            // non-parking asset prevents a highway district made from only the
            // same three silhouettes.
            return ambientDefinitions.filter {
                $0.category != .parking && $0.allowedDistricts.contains(.highway)
            }
        }
        let category: CityAssetCategory = switch district {
        case .suburb: .generalResidential
        case .emerging: .luxuryResidential
        case .station: .commercial
        case .industrial: .industrial
        case .downtown: .downtown
        case .highway: .highway
        }
        return ambientDefinitions.filter { $0.category == category }
    }

    private static func ambient(
        _ id: CityAssetID,
        _ category: CityAssetCategory,
        _ footprint: GridSize,
        _ districts: Set<DistrictKind>,
        _ height: Float,
        clearance: GridClearance = .none
    ) -> CityAssetDefinition {
        CityAssetDefinition(
            id: id,
            category: category,
            footprint: footprint,
            origin: .footprintCenterAtGround,
            frontDirection: .south,
            roadConnectionDirections: [.south],
            requiredClearance: clearance,
            allowedDistricts: districts,
            upgradeTo: nil,
            selectionVolume: .init(
                footprint: footprint,
                horizontalInset: 0.4,
                // Include the distinct roof, tower and sign silhouettes as
                // well as authored map height variation.  The horizontal
                // volume remains the exact grid footprint.
                maximumHeight: max(5, height * 1.25 + 10)
            ),
            nominalHeight: height
        )
    }

    private static func facility(
        _ id: CityAssetID,
        _ footprint: GridSize,
        _ districts: Set<DistrictKind>,
        _ height: Float,
        _ clearance: GridClearance,
        _ upgrade: CityAssetID?
    ) -> CityAssetDefinition {
        CityAssetDefinition(
            id: id,
            category: .playerFacility,
            footprint: footprint,
            origin: .footprintCenterAtGround,
            frontDirection: .south,
            roadConnectionDirections: [.south],
            requiredClearance: clearance,
            allowedDistricts: districts,
            upgradeTo: upgrade,
            selectionVolume: .init(
                footprint: footprint,
                horizontalInset: 0.25,
                maximumHeight: max(5, height * 1.25 + 5)
            ),
            nominalHeight: height
        )
    }
}

extension StoreType {
    var cityAssetID: CityAssetID {
        switch self {
        case .small: .playerSmallDealer
        case .standard, .premium: .playerMediumDealer
        case .roadside: .playerLargeDealer
        case .service: .playerServiceWorkshop
        }
    }

    var cityAssetHeight: Float {
        switch self {
        case .small: 10
        case .standard: 13
        case .roadside: 14
        case .premium: 16
        case .service: 11
        }
    }
}
