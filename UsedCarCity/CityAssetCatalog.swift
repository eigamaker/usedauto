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
        ambient(.residentialCottage, .generalResidential, .oneByOne, [.suburb], 7),
        ambient(.residentialGable, .generalResidential, .oneByOne, [.suburb], 8),
        ambient(.residentialFlat, .generalResidential, .oneByTwo, [.suburb], 7),
        ambient(.residentialTwin, .generalResidential, .oneByTwo, [.suburb], 8),
        ambient(.residentialApartment, .generalResidential, .twoByTwo, [.suburb], 13),

        ambient(.luxuryCourtyard, .luxuryResidential, .twoByTwo, [.emerging], 8, clearance: .vehicleApron),
        ambient(.luxuryGarage, .luxuryResidential, .twoByTwo, [.emerging], 9, clearance: .frontOne),
        ambient(.luxuryPool, .luxuryResidential, .twoByThree, [.emerging], 8, clearance: .vehicleApron),
        ambient(.luxuryTerrace, .luxuryResidential, .twoByThree, [.emerging], 10, clearance: .frontOne),

        ambient(.commercialAutoDealer, .commercial, .twoByThree, [.station, .highway], 10, clearance: .frontOne),
        ambient(.commercialGasStation, .commercial, .twoByTwo, [.station, .highway], 7, clearance: .frontOne),
        ambient(.commercialConvenience, .commercial, .oneByTwo, [.station, .highway], 7, clearance: .frontOne),
        ambient(.commercialRestaurant, .commercial, .oneByTwo, [.station, .highway], 8, clearance: .frontOne),
        ambient(.commercialShopping, .commercial, .twoByThree, [.station, .highway], 12, clearance: .frontOne),
        ambient(.commercialRoadside, .commercial, .twoByTwo, [.station, .highway], 9, clearance: .frontOne),

        ambient(.industrialFactory, .industrial, .fourByFour, [.industrial], 13, clearance: .frontOne),
        ambient(.industrialWarehouse, .industrial, .threeByThree, [.industrial, .highway], 12, clearance: .frontOne),
        ambient(.industrialLoadingWarehouse, .industrial, .twoByThree, [.industrial, .highway], 11, clearance: .vehicleApron),
        ambient(.industrialTankWorks, .industrial, .twoByThree, [.industrial], 12, clearance: .frontOne),
        ambient(.industrialSmokestack, .industrial, .threeByThree, [.industrial], 18, clearance: .frontOne),

        ambient(.downtownMixedUse, .downtown, .twoByTwo, [.downtown], 28),
        ambient(.downtownOffice, .downtown, .twoByTwo, [.downtown], 34),
        ambient(.downtownApartment, .downtown, .threeByThree, [.downtown], 30),
        ambient(.downtownParkingStructure, .downtown, .twoByTwo, [.downtown], 18),
        ambient(.downtownCornerBlock, .downtown, .threeByThree, [.downtown], 36),

        ambient(.highwayLogistics, .highway, .fourByFour, [.highway, .industrial], 12, clearance: .vehicleApron),
        ambient(.highwayBigBox, .highway, .threeByThree, [.highway], 11, clearance: .vehicleApron),
        ambient(.highwayMotorHotel, .highway, .twoByThree, [.highway], 15, clearance: .frontOne),
        ambient(.surfaceParking, .parking, GridSize(width: 3, depth: 4), Set(DistrictKind.allCases), 1)
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
                maximumHeight: max(4, height * 1.25 + 4)
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
