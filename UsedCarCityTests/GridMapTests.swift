import XCTest
import SceneKit
import UIKit
@testable import UsedCarCity

final class GridMapTests: XCTestCase {
    private let map = CityMapDefinition.suihama

    func testValidationMapSatisfiesEveryStructuralRule() {
        XCTAssertEqual(GridMapValidator.validate(map), [])
    }

    func testGridAndWorldCoordinatesRoundTripWithoutDrift() {
        for row in 0..<map.size.rows {
            for column in 0..<map.size.columns {
                let coordinate = GridCoordinate(column: column, row: row)
                let center = map.metrics.worldCenter(of: coordinate, mapSize: map.size)
                XCTAssertEqual(map.metrics.gridCoordinate(at: center, mapSize: map.size), coordinate)

                if column + 1 < map.size.columns {
                    let current = GridRect(origin: coordinate, size: .oneByOne)
                    let next = GridRect(
                        origin: .init(column: column + 1, row: row),
                        size: .oneByOne
                    )
                    XCTAssertEqual(
                        map.metrics.worldBounds(of: current, mapSize: map.size).maxX,
                        map.metrics.worldBounds(of: next, mapSize: map.size).minX,
                        accuracy: 0.0001
                    )
                }
            }
        }
    }

    func testMapBoundsCoverEveryEdgeExactly() {
        let bounds = map.metrics.worldBounds(of: map.size)
        XCTAssertEqual(bounds.width, Float(map.size.columns) * map.metrics.cellSize, accuracy: 0.0001)
        XCTAssertEqual(bounds.depth, Float(map.size.rows) * map.metrics.cellSize, accuracy: 0.0001)
        XCTAssertNil(map.metrics.gridCoordinate(
            at: GridWorldPoint(x: bounds.maxX, z: bounds.maxZ),
            mapSize: map.size
        ))
        XCTAssertEqual(
            map.metrics.gridCoordinate(
                at: GridWorldPoint(x: bounds.maxX - 0.001, z: bounds.maxZ - 0.001),
                mapSize: map.size
            ),
            GridCoordinate(column: map.size.columns - 1, row: map.size.rows - 1)
        )
    }

    func testCameraContentBoundsFitParcelsWithSceneryExcluded() {
        let cameraBounds = map.cameraContentBounds
        let mapBounds = map.metrics.worldBounds(of: map.size)

        XCTAssertLessThan(cameraBounds.width, mapBounds.width)
        XCTAssertLessThanOrEqual(cameraBounds.depth, mapBounds.depth)
        XCTAssertNotEqual(cameraBounds.center, mapBounds.center)

        for parcel in map.parcels {
            let parcelBounds = map.metrics.worldBounds(of: parcel.rect, mapSize: map.size)
            XCTAssertLessThanOrEqual(cameraBounds.minX, parcelBounds.minX)
            XCTAssertGreaterThanOrEqual(cameraBounds.maxX, parcelBounds.maxX)
            XCTAssertLessThanOrEqual(cameraBounds.minZ, parcelBounds.minZ)
            XCTAssertGreaterThanOrEqual(cameraBounds.maxZ, parcelBounds.maxZ)
        }
    }

    func testRoadConnectionsAreReciprocalAndRemainInsideMap() {
        for road in map.roads.values {
            XCTAssertTrue(map.size.contains(road.coordinate))
            for direction in road.connections.directions {
                let neighbor = road.coordinate.neighbor(in: direction)
                XCTAssertTrue(map.size.contains(neighbor))
                XCTAssertNotNil(map.roads[neighbor])
                XCTAssertTrue(map.roads[neighbor]?.connections.contains(direction.opposite.connection) == true)
            }
        }
    }

    func testValidationMapContainsAllRequiredRoadTileShapes() {
        let shapes = Set(map.roads.values.map(\.tileShape))
        XCTAssertTrue(shapes.isSuperset(of: [.end, .straight, .corner, .tee, .cross]))
    }

    func testRoadArmsReachTheExactSharedCellBoundary() {
        let halfCell = map.metrics.cellSize / 2
        for road in map.roads.values {
            let surfaceWidth = road.roadClass.pavementWidth(cellSize: map.metrics.cellSize)
            let pieces = GridRoadSurfaceLayout.pieces(
                connections: road.connections,
                cellSize: map.metrics.cellSize,
                surfaceWidth: surfaceWidth
            )
            for direction in road.connections.directions {
                switch direction {
                case .north:
                    XCTAssertTrue(pieces.contains { abs($0.minZ + halfCell) < 0.0001 })
                case .east:
                    XCTAssertTrue(pieces.contains { abs($0.maxX - halfCell) < 0.0001 })
                case .south:
                    XCTAssertTrue(pieces.contains { abs($0.maxZ - halfCell) < 0.0001 })
                case .west:
                    XCTAssertTrue(pieces.contains { abs($0.minX + halfCell) < 0.0001 })
                }
            }
        }
    }

    func testRoadPiecesStayInsideCellsAndDoNotOverlapEachOther() {
        let epsilon: Float = 0.0001
        for road in map.roads.values {
            for isSidewalk in [false, true] {
                let pieces = GridRoadSurfaceLayout.pieces(
                    for: road,
                    in: map.roads,
                    cellSize: map.metrics.cellSize,
                    isSidewalk: isSidewalk
                )
                let halfCell = map.metrics.cellSize / 2
                for piece in pieces {
                    XCTAssertGreaterThanOrEqual(piece.minX, -halfCell - epsilon)
                    XCTAssertLessThanOrEqual(piece.maxX, halfCell + epsilon)
                    XCTAssertGreaterThanOrEqual(piece.minZ, -halfCell - epsilon)
                    XCTAssertLessThanOrEqual(piece.maxZ, halfCell + epsilon)
                }
                for firstIndex in pieces.indices {
                    for secondIndex in pieces.indices where secondIndex > firstIndex {
                        let first = pieces[firstIndex]
                        let second = pieces[secondIndex]
                        let overlapX = min(first.maxX, second.maxX) - max(first.minX, second.minX)
                        let overlapZ = min(first.maxZ, second.maxZ) - max(first.minZ, second.minZ)
                        XCTAssertFalse(overlapX > epsilon && overlapZ > epsilon, "\(road.coordinate)")
                    }
                }
            }
        }
    }

    func testConnectedRoadEdgesUseTheSameWidthAcrossClassTransitions() throws {
        let halfCell = map.metrics.cellSize / 2
        for road in map.roads.values {
            for direction in [CardinalDirection.east, .south]
            where road.connections.contains(direction.connection) {
                let neighbor = try XCTUnwrap(map.roads[road.coordinate.neighbor(in: direction)])
                let firstPieces = GridRoadSurfaceLayout.pieces(
                    for: road,
                    in: map.roads,
                    cellSize: map.metrics.cellSize,
                    isSidewalk: false
                )
                let secondPieces = GridRoadSurfaceLayout.pieces(
                    for: neighbor,
                    in: map.roads,
                    cellSize: map.metrics.cellSize,
                    isSidewalk: false
                )
                let firstSpan = try XCTUnwrap(boundarySpan(
                    pieces: firstPieces,
                    direction: direction,
                    halfCell: halfCell
                ))
                let secondSpan = try XCTUnwrap(boundarySpan(
                    pieces: secondPieces,
                    direction: direction.opposite,
                    halfCell: halfCell
                ))
                XCTAssertEqual(firstSpan.lowerBound, secondSpan.lowerBound, accuracy: 0.0001)
                XCTAssertEqual(firstSpan.upperBound, secondSpan.upperBound, accuracy: 0.0001)
            }
        }
    }

    func testRoadEndsDoNotLeakAcrossUnconnectedCellEdges() {
        let halfCell = map.metrics.cellSize / 2
        for road in map.roads.values {
            let pieces = GridRoadSurfaceLayout.pieces(
                for: road,
                in: map.roads,
                cellSize: map.metrics.cellSize,
                isSidewalk: false
            )
            for direction in CardinalDirection.allCases
            where !road.connections.contains(direction.connection) {
                XCTAssertNil(boundarySpan(pieces: pieces, direction: direction, halfCell: halfCell))
            }
        }
    }

    func testRoadClassesHaveFixedWidths() {
        let localWidths = Set(map.roads.values.filter { $0.roadClass == .local }.map {
            $0.roadClass.pavementWidth(cellSize: map.metrics.cellSize)
        })
        let arterialWidths = Set(map.roads.values.filter { $0.roadClass == .arterial }.map {
            $0.roadClass.pavementWidth(cellSize: map.metrics.cellSize)
        })
        XCTAssertEqual(localWidths, Set([map.metrics.cellSize * 0.60]))
        XCTAssertEqual(arterialWidths, Set([map.metrics.cellSize * 0.90]))
    }

    func testParcelsCarryRequiredGameplayFieldsAndRoadAccess() {
        XCTAssertEqual(map.parcels.count, 179)
        XCTAssertEqual(Set(map.parcels.map(\.district)), Set(DistrictKind.allCases))
        for parcel in map.parcels {
            XCTAssertNotNil(parcel.legacyPlotID)
            XCTAssertTrue(parcel.rect.size.isValid)
            XCTAssertGreaterThan(parcel.areaSquareMeters, 0)
            XCTAssertTrue(parcel.isPurchasable)
            XCTAssertTrue(parcel.isBuildable)
            XCTAssertFalse(parcel.roadAccess.isEmpty)
            XCTAssertNotNil(parcel.price)
            XCTAssertEqual(parcel.ownership, .market)
        }
    }

    func testProductionCityDefinitionUsesTheValidatedGridAndNamedAnchors() {
        XCTAssertEqual(CityMapDefinition.suihama, map)
        XCTAssertEqual(Set(map.anchors.keys), Set(GridMapAnchorID.allCases))
        XCTAssertTrue(map.anchors.values.allSatisfy(map.size.contains))
    }

    func testMapValidatorRejectsAnAnchorOutsideTheGrid() {
        var anchors = map.anchors
        let invalid = GridCoordinate(column: map.size.columns, row: map.size.rows)
        anchors[.bank] = invalid
        XCTAssertTrue(
            GridMapValidator.validate(replacingMap(anchors: anchors))
                .contains(.anchorOutsideMap(.bank, invalid))
        )
    }

    func testCoastalCityProvidesVariedDistrictsAndEnoughBuildableLand() {
        XCTAssertEqual(map.size, GridMapSize(columns: 100, rows: 100))

        // Districts intentionally differ in size so the city reads as a
        // place: dense center, broad residential, compact station quarter.
        let expectedParcelCounts: [DistrictKind: Int] = [
            .downtown: 36, .station: 13, .emerging: 24,
            .suburb: 38, .industrial: 6, .highway: 62
        ]
        let expectedVacantCounts: [DistrictKind: Int] = [
            .downtown: 3, .station: 1, .emerging: 2,
            .suburb: 3, .industrial: 1, .highway: 4
        ]
        let expectedParkingCounts: [DistrictKind: Int] = [
            .downtown: 2, .station: 1, .emerging: 1,
            .suburb: 2, .industrial: 0, .highway: 4
        ]

        let occupiedParcelIDs = Set(map.objects.map(\.parcelID))
        for district in DistrictKind.allCases {
            let parcels = map.parcels.filter { $0.district == district }
            XCTAssertEqual(parcels.count, expectedParcelCounts[district], district.rawValue)
            XCTAssertEqual(
                parcels.filter { !occupiedParcelIDs.contains($0.id) }.count,
                expectedVacantCounts[district],
                district.rawValue
            )
            XCTAssertEqual(
                map.objects.filter { object in
                    object.kind == .parking
                        && map.parcel(id: object.parcelID)?.district == district
                }.count,
                expectedParkingCounts[district],
                district.rawValue
            )
        }
        XCTAssertEqual(map.objects.count, map.parcels.count - 14)

        // Scenery terrain must be present and can never intrude on parcels.
        XCTAssertFalse(map.terrain.filter { $0.value == .water }.isEmpty)
        XCTAssertFalse(map.terrain.filter { $0.value == .park }.isEmpty)
        XCTAssertFalse(map.terrain.filter { $0.value == .beach }.isEmpty)
        XCTAssertFalse(map.terrain.filter { $0.value == .plaza }.isEmpty)
        for parcel in map.parcels {
            XCTAssertTrue(parcel.rect.cells.allSatisfy { map.terrain[$0] == nil }, parcel.id)
        }
    }

    func testRoadsBridgeWaterOnlyOnExpresswayAndArterialCrossings() {
        let bridgeCells = map.roads.keys.filter { map.terrain[$0] == .water }
        XCTAssertFalse(bridgeCells.isEmpty)
        for cell in bridgeCells {
            XCTAssertNotEqual(map.roads[cell]?.roadClass, GridRoadClass.local, "\(cell)")
        }
    }

    func testExpandedDistrictsUseMultipleBuildingSilhouettes() {
        for district in DistrictKind.allCases {
            let assetIDs = Set(map.objects.compactMap { object -> CityAssetID? in
                guard object.kind == .building,
                      map.parcel(id: object.parcelID)?.district == district else { return nil }
                return object.assetID
            })
            XCTAssertGreaterThanOrEqual(assetIDs.count, 4, district.rawValue)
        }
        XCTAssertGreaterThanOrEqual(CityAssetCatalog.ambientAssets(for: .highway).count, 8)
    }

    func testVacantLandIsASelectableBuildableParcelObject() {
        let vacantParcels = map.parcels.filter { parcel in
            parcel.currentBuildingID == nil
                && !map.objects.contains(where: { $0.parcelID == parcel.id })
        }
        XCTAssertGreaterThanOrEqual(vacantParcels.count, 12)
        for parcel in vacantParcels {
            XCTAssertNotNil(parcel.legacyPlotID)
            XCTAssertTrue(parcel.isPurchasable)
            XCTAssertTrue(parcel.isBuildable)
            XCTAssertTrue(parcel.isVacant)
        }
    }

    func testPlaceholderBuildingsIncludeEveryRequiredFootprint() {
        let buildingFootprints = Set(
            CityAssetCatalog.definitions.filter { $0.category != .parking }.map {
                GridSize(width: min($0.footprint.width, $0.footprint.depth),
                         depth: max($0.footprint.width, $0.footprint.depth))
            }
        )
        let required: Set<GridSize> = [
            .oneByOne, .oneByTwo, .twoByTwo, .twoByThree, .threeByThree, .fourByFour
        ]
        XCTAssertTrue(buildingFootprints.isSuperset(of: required))
    }

    func testEveryObjectFitsItsParcelWithoutRoadOrObjectOverlap() {
        var occupied: [GridCoordinate: String] = [:]
        for object in map.objects {
            let parcel = try! XCTUnwrap(map.parcel(id: object.parcelID))
            XCTAssertTrue(parcel.rect.contains(object.rect))
            for coordinate in object.rect.cells {
                XCTAssertNil(map.roads[coordinate])
                XCTAssertNil(occupied[coordinate])
                occupied[coordinate] = object.id
            }
        }
    }

    func testParkingUsesTheSameIntegerGridAsBuildings() {
        let parkingObjects = map.objects.filter { $0.kind == .parking }
        XCTAssertEqual(parkingObjects.count, 10)
        for parking in parkingObjects {
            XCTAssertTrue(parking.rect.size.isValid)
            XCTAssertTrue(parking.rect.cells.allSatisfy(map.size.contains))
            XCTAssertTrue(parking.rect.cells.allSatisfy { map.roads[$0] == nil })
        }
    }

    func testPlacementRulesAcceptVacantLandAndRejectInvalidOccupancy() throws {
        let vacant = try XCTUnwrap(map.parcels.first { parcel in
            parcel.currentBuildingID == nil
                && !map.objects.contains(where: { $0.parcelID == parcel.id })
        })
        let validRect = GridRect(origin: vacant.rect.origin, size: .oneByOne)
        XCTAssertTrue(GridPlacementRules.canPlace(validRect, in: vacant.id, map: map))

        let outsideRect = GridRect(
            origin: .init(column: vacant.rect.minColumn - 1, row: vacant.rect.minRow),
            size: .oneByOne
        )
        XCTAssertTrue(GridPlacementRules.failures(
            placing: outsideRect,
            in: vacant.id,
            map: map
        ).contains(.outsideParcel))

        let roadCoordinate = try XCTUnwrap(map.roads.keys.first)
        let roadRect = GridRect(origin: roadCoordinate, size: .oneByOne)
        XCTAssertTrue(GridPlacementRules.failures(
            placing: roadRect,
            in: vacant.id,
            map: map
        ).contains(.intersectsRoad(roadCoordinate)))

        let existing = try XCTUnwrap(map.objects.first)
        XCTAssertTrue(GridPlacementRules.failures(
            placing: existing.rect,
            in: existing.parcelID,
            map: map
        ).contains(.overlapsObject(existing.id)))
    }

    func testAssetPlacementEnforcesDistrictRoadDirectionAndWholeParcelOccupancy() throws {
        let vacant = try XCTUnwrap(vacantParcel(in: .suburb))
        let facing = try XCTUnwrap(vacant.roadAccess.first)
        XCTAssertTrue(GridPlacementRules.canPlace(
            .playerOffice,
            facing: facing,
            in: vacant.id,
            map: map
        ))

        let districtFailures = GridPlacementRules.failures(
            placing: .playerServiceWorkshop,
            facing: facing,
            in: vacant.id,
            map: map
        )
        XCTAssertTrue(districtFailures.contains(.assetNotAllowedInDistrict(.playerServiceWorkshop, .suburb)))

        let wrongFacing = facing.opposite
        XCTAssertTrue(GridPlacementRules.failures(
            placing: .playerOffice,
            facing: wrongFacing,
            in: vacant.id,
            map: map
        ).contains(.assetHasNoRoadConnection(.playerOffice)))

        let objectRect = GridPlacementRules.centeredRect(for: .playerOffice, facing: facing, in: vacant)
        let object = GridPlacedObject(
            id: "qa-office",
            parcelID: vacant.id,
            rect: objectRect,
            kind: .building,
            style: .commercial,
            assetID: .playerOffice,
            facing: facing,
            height: CityAssetCatalog.definition(for: .playerOffice).nominalHeight
        )
        let occupiedMap = replacingMap(objects: map.objects + [object])
        let nonOverlappingCorner = GridRect(
            origin: GridCoordinate(
                column: vacant.rect.maxColumnExclusive - 1,
                row: vacant.rect.maxRowExclusive - 1
            ),
            size: .oneByOne
        )
        let occupiedFailures = GridPlacementRules.failures(
            placing: nonOverlappingCorner,
            in: vacant.id,
            map: occupiedMap
        )
        XCTAssertTrue(occupiedFailures.contains(.parcelIsOccupied(object.id)))
        XCTAssertFalse(occupiedFailures.contains(.overlapsObject(object.id)))
    }

    func testBuildRemoveAndRebuildClearsGridOccupancy() throws {
        let vacant = try XCTUnwrap(vacantParcel(in: .station))
        let facing = try XCTUnwrap(vacant.roadAccess.first)
        let rect = GridPlacementRules.centeredRect(for: .playerOffice, facing: facing, in: vacant)
        XCTAssertTrue(GridPlacementRules.canPlace(.playerOffice, facing: facing, in: vacant.id, map: map))

        let placed = GridPlacedObject(
            id: "qa-rebuild-office",
            parcelID: vacant.id,
            rect: rect,
            kind: .building,
            style: .commercial,
            assetID: .playerOffice,
            facing: facing,
            height: 12
        )
        var occupiedParcels = map.parcels
        let parcelIndex = try XCTUnwrap(occupiedParcels.firstIndex(where: { $0.id == vacant.id }))
        occupiedParcels[parcelIndex].currentBuildingID = placed.id
        let occupiedMap = replacingMap(parcels: occupiedParcels, objects: map.objects + [placed])
        XCTAssertFalse(GridPlacementRules.canPlace(.playerOffice, facing: facing, in: vacant.id, map: occupiedMap))

        occupiedParcels[parcelIndex].currentBuildingID = nil
        let removedMap = replacingMap(parcels: occupiedParcels)
        XCTAssertTrue(removedMap.isParcelVacant(vacant.id))
        XCTAssertTrue(GridPlacementRules.canPlace(.playerOffice, facing: facing, in: vacant.id, map: removedMap))
    }

    func testRotatedAssetOccupancyAndUpgradeAreRecenteredInsideParcel() throws {
        let vacant = try XCTUnwrap(vacantParcel(in: .highway))
        let southRect = GridPlacementRules.centeredRect(
            for: .playerServiceWorkshop,
            facing: .south,
            in: vacant
        )
        let eastRect = GridPlacementRules.centeredRect(
            for: .playerServiceWorkshop,
            facing: .east,
            in: vacant
        )
        XCTAssertEqual(southRect.size, .twoByThree)
        XCTAssertEqual(eastRect.size, GridSize(width: 3, depth: 2))
        XCTAssertEqual(southRect.cells.count, 6)
        XCTAssertEqual(eastRect.cells.count, 6)
        XCTAssertTrue(vacant.rect.contains(southRect))
        XCTAssertTrue(vacant.rect.contains(eastRect))

        let facing = try XCTUnwrap(vacant.roadAccess.first)
        let mediumRect = GridPlacementRules.centeredRect(for: .playerMediumDealer, facing: facing, in: vacant)
        let medium = GridPlacedObject(
            id: "qa-medium-dealer",
            parcelID: vacant.id,
            rect: mediumRect,
            kind: .building,
            style: .commercial,
            assetID: .playerMediumDealer,
            facing: facing,
            height: 13
        )
        var parcels = map.parcels
        let parcelIndex = try XCTUnwrap(parcels.firstIndex(where: { $0.id == vacant.id }))
        parcels[parcelIndex].currentBuildingID = medium.id
        let upgradeMap = replacingMap(parcels: parcels, objects: map.objects + [medium])
        XCTAssertEqual(
            GridPlacementRules.failures(
                upgrading: medium.id,
                to: .playerLargeDealer,
                facing: facing,
                map: upgradeMap
            ),
            []
        )
        let largeRect = GridPlacementRules.centeredRect(for: .playerLargeDealer, facing: facing, in: vacant)
        XCTAssertTrue(vacant.rect.contains(largeRect))
    }

    func testRoadlessBuildableParcelAndMalformedObjectsAreReported() throws {
        let vacant = try XCTUnwrap(vacantParcel(in: .suburb))
        var parcels = map.parcels
        let parcelIndex = try XCTUnwrap(parcels.firstIndex(where: { $0.id == vacant.id }))
        parcels[parcelIndex] = GridParcel(
            id: vacant.id,
            legacyPlotID: vacant.legacyPlotID,
            rect: vacant.rect,
            district: vacant.district,
            areaSquareMeters: vacant.areaSquareMeters,
            ownership: vacant.ownership,
            isPurchasable: vacant.isPurchasable,
            isBuildable: true,
            roadAccess: [],
            currentBuildingID: nil,
            price: vacant.price
        )
        let roadlessMap = replacingMap(parcels: parcels)
        XCTAssertTrue(GridMapValidator.validate(roadlessMap).contains(.buildableParcelHasNoRoadAccess(vacant.id)))
        XCTAssertTrue(GridPlacementRules.failures(
            placing: vacant.rect,
            in: vacant.id,
            map: roadlessMap
        ).contains(.parcelHasNoRoadAccess))

        let original = try XCTUnwrap(map.objects.first)
        let parcel = try XCTUnwrap(map.parcel(id: original.parcelID))
        let malformed = GridPlacedObject(
            id: original.id,
            parcelID: original.parcelID,
            rect: GridRect(origin: original.rect.origin, size: .oneByOne),
            kind: original.kind,
            style: original.style,
            assetID: original.assetID,
            facing: original.facing.opposite,
            height: 0
        )
        let malformedMap = replacingMap(objects: map.objects.map { $0.id == original.id ? malformed : $0 })
        let issues = GridMapValidator.validate(malformedMap)
        let expected = CityAssetCatalog.definition(for: original.assetID).footprint(facing: malformed.facing)
        XCTAssertTrue(issues.contains(.objectFootprintMismatch(original.id, expected, .oneByOne)))
        XCTAssertTrue(issues.contains(.objectRoadConnectionMissing(original.id)))
        XCTAssertTrue(issues.contains(.invalidObjectHeight(original.id)))
        XCTAssertTrue(parcel.rect.contains(malformed.rect))
    }

    func testDuplicateMapIdentifiersAreReported() throws {
        let parcel = try XCTUnwrap(map.parcels.first)
        let object = try XCTUnwrap(map.objects.first)
        let duplicated = replacingMap(
            parcels: map.parcels + [parcel],
            objects: map.objects + [object]
        )
        let issues = GridMapValidator.validate(duplicated)
        XCTAssertTrue(issues.contains(.duplicateParcelID(parcel.id)))
        XCTAssertTrue(issues.contains(.duplicateLegacyPlotID(try XCTUnwrap(parcel.legacyPlotID))))
        XCTAssertTrue(issues.contains(.duplicateObjectID(object.id)))
    }

    func testValidationMapRoundTripsThroughCodableDataLoading() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(map)
        let decoded = try JSONDecoder().decode(GridCityMap.self, from: data)
        XCTAssertEqual(decoded, map)
        XCTAssertEqual(GridMapValidator.validate(decoded), [])
    }

    func testOrthographicZoomDoesNotChangeCameraAngleOrWorldPlacement() {
        let spec = GridOrthographicCameraSpec.foundation
        let offsetBefore = spec.cameraOffset(groundDistance: 1_200)
        let parcel = map.parcels[0]
        let positionBefore = map.metrics.worldBounds(of: parcel.rect, mapSize: map.size).center

        XCTAssertEqual(spec.azimuthDegrees, 45, accuracy: 0.001)
        XCTAssertEqual(spec.elevationDegrees, 35.26439, accuracy: 0.001)
        XCTAssertEqual(spec.orthographicScale(baseScale: 2_000, zoomStep: 0), 1_760, accuracy: 0.001)
        XCTAssertEqual(spec.orthographicScale(baseScale: 2_000, zoomStep: GridCameraZoom.defaultStep), 440, accuracy: 0.001)
        XCTAssertLessThan(spec.orthographicScale(baseScale: 2_000, zoomStep: 6), 440)
        XCTAssertEqual(spec.cameraOffset(groundDistance: 1_200), offsetBefore)
        XCTAssertEqual(map.metrics.worldBounds(of: parcel.rect, mapSize: map.size).center, positionBefore)
    }

    func testCameraFocusCannotPanOutsideAtAnyZoomLevel() {
        let bounds = map.cameraContentBounds
        let requested = GridWorldPoint(x: bounds.maxX * 10, z: bounds.minZ * 10)
        let fit = GridCameraFocusPolicy.clampedFocus(requested, in: bounds, zoomFactor: 1)
        XCTAssertEqual(fit, bounds.center)

        var previousMaximumX = fit.x
        for factor in GridOrthographicCameraSpec.foundation.zoomScaleFactors {
            let clamped = GridCameraFocusPolicy.clampedFocus(requested, in: bounds, zoomFactor: factor)
            XCTAssertGreaterThanOrEqual(clamped.x, bounds.minX)
            XCTAssertLessThanOrEqual(clamped.x, bounds.maxX)
            XCTAssertGreaterThanOrEqual(clamped.z, bounds.minZ)
            XCTAssertLessThanOrEqual(clamped.z, bounds.maxZ)
            XCTAssertGreaterThanOrEqual(clamped.x, previousMaximumX)
            previousMaximumX = clamped.x
        }
    }

    func testOverviewAndInspectionZoomLevelsCanBeSelectedDeterministically() {
        for step in 0...9 {
            XCTAssertEqual(
                GridCameraZoom.demoInitialStep(arguments: ["app", "-demo-map-zoom-step=\(step)"]),
                step
            )
        }
        XCTAssertEqual(GridCameraZoom.demoInitialStep(arguments: ["app", "-demo-map-zoom-step=99"]), 9)
        XCTAssertEqual(GridCameraZoom.demoInitialStep(arguments: ["app"]), GridCameraZoom.defaultStep)
        XCTAssertEqual((0...9).map(GridCameraZoom.percentage), [25, 50, 75, 100, 200, 300, 400, 500, 600, 700])
        XCTAssertEqual(
            GridCameraZoom.demoFocusPlotID(arguments: ["app", "-demo-map-focus-plot=36"]),
            36
        )
        XCTAssertNil(GridCameraZoom.demoFocusPlotID(arguments: ["app"]))
    }

    func testAssetCatalogHasControlledVariantCountsAndUniqueDefinitions() {
        let definitions = CityAssetCatalog.definitions
        XCTAssertEqual(definitions.count, CityAssetID.allCases.count)
        XCTAssertEqual(Set(definitions.map(\.id)).count, definitions.count)
        XCTAssertEqual(definitions.filter { $0.category == .generalResidential }.count, 5)
        XCTAssertEqual(definitions.filter { $0.category == .luxuryResidential }.count, 4)
        XCTAssertEqual(definitions.filter { $0.category == .commercial }.count, 7)
        XCTAssertEqual(definitions.filter { $0.category == .industrial }.count, 5)
        XCTAssertEqual(definitions.filter { $0.category == .downtown }.count, 8)
        XCTAssertEqual(definitions.filter { $0.category == .highway }.count, 3)
        XCTAssertEqual(definitions.filter(\.isPlayerFacility).count, 13)
    }

    func testBuildingHeightPolicyIsAboutThreeTimesThePreviousRenderedScale() {
        let previousMultipliers: [CityAssetCategory: Float] = [
            .generalResidential: 2.4,
            .luxuryResidential: 2.2,
            .commercial: 2.0,
            .industrial: 1.9,
            .downtown: 1.5,
            .highway: 1.9,
            .parking: 1.0,
            .playerFacility: 1.25
        ]
        for (category, previous) in previousMultipliers where category != .parking {
            XCTAssertEqual(
                CityAssetScale.heightMultiplier(for: category),
                previous * 3,
                accuracy: 0.001,
                category.rawValue
            )
        }
    }

    @MainActor
    func testVehiclePropsUseTheRequestedDoubleScale() throws {
        let factory = CityBuildingFactory(cellSize: map.metrics.cellSize)
        let cottage = factory.makeAsset(id: .residentialCottage, facing: .south)
        let car = try XCTUnwrap(cottage.childNode(withName: "vehicle:car", recursively: true))
        XCTAssertEqual(car.scale.x, 2, accuracy: 0.001)
        XCTAssertEqual(car.scale.y, 2, accuracy: 0.001)
        XCTAssertEqual(car.scale.z, 2, accuracy: 0.001)
        XCTAssertEqual(CityBuildingFactory.vehicleScale, 2)
    }

    func testPlayerFacilityDefinitionsContainEveryPlacementRequirement() {
        let facilities = CityAssetCatalog.playerFacilityDefinitions
        XCTAssertEqual(facilities.count, 13)
        for facility in facilities {
            XCTAssertTrue(facility.footprint.isValid)
            XCTAssertEqual(facility.origin, .footprintCenterAtGround)
            XCTAssertEqual(facility.frontDirection, .south)
            XCTAssertFalse(facility.roadConnectionDirections.isEmpty)
            XCTAssertTrue(facility.requiredClearance.isValid)
            XCTAssertFalse(facility.allowedDistricts.isEmpty)
            XCTAssertEqual(facility.selectionVolume.footprint, facility.footprint)
            XCTAssertGreaterThan(facility.selectionVolume.maximumHeight, facility.nominalHeight)
            if let upgrade = facility.upgradeTo {
                XCTAssertTrue(CityAssetCatalog.definition(for: upgrade).isPlayerFacility)
            }
        }
    }

    func testRectangularAssetsRotateTheirFootprintsAndRoadConnections() {
        let definition = CityAssetCatalog.definition(for: .playerServiceWorkshop)
        XCTAssertEqual(definition.footprint, .twoByThree)
        XCTAssertEqual(definition.footprint(facing: .south), .twoByThree)
        XCTAssertEqual(definition.footprint(facing: .north), .twoByThree)
        XCTAssertEqual(definition.footprint(facing: .east), GridSize(width: 3, depth: 2))
        XCTAssertEqual(definition.footprint(facing: .west), GridSize(width: 3, depth: 2))
        XCTAssertEqual(definition.roadConnections(facing: .east), [.east])
        XCTAssertEqual(definition.roadConnections(facing: .west), [.west])
        XCTAssertEqual(definition.clearance(facing: .south), .vehicleApron)
        XCTAssertEqual(
            definition.clearance(facing: .east),
            GridClearance(north: 1, east: 1, south: 1, west: 0)
        )
        XCTAssertEqual(definition.selectionVolume(facing: .east).footprint, GridSize(width: 3, depth: 2))
    }

    func testAssetLODPolicyShowsInspectionDetailsThroughoutNewZoomRange() {
        XCTAssertEqual(
            CityAssetLODPolicy.visibility(zoomFactor: GridCameraZoom.scaleFactors[0]),
            CityAssetLODVisibility(showsNearDetails: false, showsProps: false)
        )
        XCTAssertEqual(
            CityAssetLODPolicy.visibility(zoomFactor: GridCameraZoom.scaleFactors[GridCameraZoom.defaultStep]),
            CityAssetLODVisibility(showsNearDetails: true, showsProps: true)
        )
        XCTAssertEqual(
            CityAssetLODPolicy.visibility(zoomFactor: GridCameraZoom.scaleFactors[9]),
            CityAssetLODVisibility(showsNearDetails: true, showsProps: true)
        )
    }

    func testValidationMapUsesDistrictAppropriateAssetsFacingTheirRoads() {
        for object in map.objects {
            let parcel = try! XCTUnwrap(map.parcel(id: object.parcelID))
            let definition = CityAssetCatalog.definition(for: object.assetID)
            XCTAssertEqual(object.rect.size, definition.footprint(facing: object.facing))
            if object.kind == .building {
                XCTAssertTrue(definition.allowedDistricts.contains(parcel.district))
            } else {
                XCTAssertEqual(object.assetID, .surfaceParking)
            }
            XCTAssertFalse(definition.roadConnections(facing: object.facing).isDisjoint(with: parcel.roadAccess))
        }
    }

    func testAmbientBuildingsUseStreetBlockScaleFootprints() {
        for definition in CityAssetCatalog.ambientDefinitions
        where definition.category != .parking
            && definition.category != .industrial
            && ![.commercialRegionalMall, .downtownOfficePlaza,
                  .downtownTwinTower, .downtownResidentialTower].contains(definition.id) {
            XCTAssertEqual(definition.footprint, .fourByFour, definition.id.rawValue)
        }

        let industrial = CityAssetCatalog.ambientDefinitions.filter { $0.category == .industrial }
        XCTAssertEqual(industrial.filter { $0.footprint == .nineByFour }.count, 2)
        XCTAssertEqual(industrial.filter { $0.footprint == .nineByNine }.count, 3)

        XCTAssertEqual(
            CityAssetCatalog.definition(for: .commercialRegionalMall).footprint,
            .nineByNine
        )
        for assetID in [CityAssetID.downtownOfficePlaza, .downtownTwinTower,
                        .downtownResidentialTower] {
            XCTAssertEqual(CityAssetCatalog.definition(for: assetID).footprint, .nineByFour)
        }
    }

    func testIndustrialCampusesSecureTwoOrFourFormerPlotsWithoutInternalRoadCuts() throws {
        let industrialParcels = map.parcels.filter { $0.district == .industrial }
        XCTAssertEqual(Set(industrialParcels.map(\.rect.size)), [.nineByFour, .nineByNine])

        for parcel in industrialParcels {
            let plotCount = parcel.rect.size == .nineByNine ? 4 : 2
            XCTAssertEqual(parcel.areaSquareMeters, 420 * plotCount)
            XCTAssertTrue(parcel.rect.cells.allSatisfy { map.roads[$0] == nil }, parcel.id)
            if let object = map.objects.first(where: { $0.parcelID == parcel.id }) {
                XCTAssertEqual(object.rect, parcel.rect, object.id)
            }
        }
    }

    func testMallAndTowerCampusesCrossFormerPlotLinesAsContinuousSites() throws {
        let campusIDs: Set<CityAssetID> = [
            .commercialRegionalMall,
            .downtownOfficePlaza,
            .downtownTwinTower,
            .downtownResidentialTower
        ]
        let campuses = map.objects.filter { campusIDs.contains($0.assetID) }
        XCTAssertEqual(campuses.count, 6)
        XCTAssertEqual(campuses.filter { $0.assetID == .commercialRegionalMall }.count, 2)

        for object in campuses {
            let parcel = try XCTUnwrap(map.parcel(id: object.parcelID))
            let cellCount = parcel.rect.size.width * parcel.rect.size.depth
            let plotCount = cellCount == 81 ? 4 : 2
            XCTAssertEqual(parcel.areaSquareMeters, 420 * plotCount)
            XCTAssertEqual(object.rect, parcel.rect)
            XCTAssertTrue(parcel.rect.cells.allSatisfy { map.roads[$0] == nil }, object.id)
        }
    }

    func testCityDevelopmentReachesTheCoastAndSouthernMapEdge() {
        let southernParcels = map.parcels.filter { $0.rect.minRow >= 90 }
        let coastalParcels = map.parcels.filter { $0.rect.minColumn >= 76 }
        let buildingCount = map.objects.filter { $0.kind == .building }.count

        XCTAssertEqual(southernParcels.count, 26)
        XCTAssertEqual(coastalParcels.count, 5)
        XCTAssertGreaterThanOrEqual(buildingCount, 150)
        XCTAssertGreaterThanOrEqual(map.parcels.map(\.rect.maxRowExclusive).max() ?? 0, 99)
        XCTAssertGreaterThanOrEqual(map.parcels.map(\.rect.maxColumnExclusive).max() ?? 0, 81)
    }

    func testAmbientBuildingsOccupyTheirWholeParcelInsteadOfLeavingMiniatureLawns() throws {
        for object in map.objects where object.kind == .building {
            let parcel = try XCTUnwrap(map.parcel(id: object.parcelID))
            let definition = CityAssetCatalog.definition(for: object.assetID)
            guard !definition.isPlayerFacility else { continue }
            XCTAssertEqual(object.rect, parcel.rect, object.id)
        }
    }

    @MainActor
    func testAmbientLotInfillStaysInsideItsParcelAtEveryRotation() {
        let factory = CityBuildingFactory(cellSize: map.metrics.cellSize)
        let parcelWidth = Float(GridSize.fourByFour.width) * map.metrics.cellSize
        let parcelDepth = Float(GridSize.fourByFour.depth) * map.metrics.cellSize
        let categories: [CityAssetCategory] = [
            .generalResidential, .luxuryResidential, .commercial,
            .industrial, .downtown, .highway, .parking, .playerFacility
        ]

        for category in categories {
            for facing in CardinalDirection.allCases {
                let node = factory.makeLotInfill(
                    category: category,
                    facing: facing,
                    width: parcelWidth,
                    depth: parcelDepth
                )
                let bounds = node.boundingBox
                var geometryNodeCount = 0
                node.enumerateChildNodes { child, _ in
                    XCTAssertNil(child.physicsBody, category.rawValue)
                    if child.geometry != nil { geometryNodeCount += 1 }
                }
                XCTAssertGreaterThanOrEqual(bounds.min.x, -parcelWidth / 2, category.rawValue)
                XCTAssertLessThanOrEqual(bounds.max.x, parcelWidth / 2, category.rawValue)
                XCTAssertGreaterThanOrEqual(bounds.min.z, -parcelDepth / 2, category.rawValue)
                XCTAssertLessThanOrEqual(bounds.max.z, parcelDepth / 2, category.rawValue)
                XCTAssertGreaterThanOrEqual(bounds.min.y, -0.01, category.rawValue)
                XCTAssertLessThanOrEqual(geometryNodeCount, 24, category.rawValue)
            }
        }
    }

    @MainActor
    func testPlayerFacilityLotInfillVisuallyUsesMostOfPurchasedParcel() {
        let factory = CityBuildingFactory(cellSize: map.metrics.cellSize)
        let parcelWidth = Float(GridSize.fourByFour.width) * map.metrics.cellSize
        let parcelDepth = Float(GridSize.fourByFour.depth) * map.metrics.cellSize
        let node = factory.makeLotInfill(
            category: .playerFacility,
            facing: .south,
            width: parcelWidth,
            depth: parcelDepth
        )
        let bounds = node.boundingBox
        XCTAssertGreaterThan(bounds.max.x - bounds.min.x, parcelWidth * 0.80)
        XCTAssertGreaterThan(bounds.max.z - bounds.min.z, parcelDepth * 0.80)
        XCTAssertNotNil(node.childNode(withName: CityBuildingFactory.nearDetailNodeName, recursively: false))
        XCTAssertNotNil(node.childNode(withName: CityBuildingFactory.propDetailNodeName, recursively: false))
    }

    @MainActor
    func testGeneratedAssetGeometryStaysInsideItsOrientedGridFootprint() {
        let factory = CityBuildingFactory(cellSize: map.metrics.cellSize)
        for definition in CityAssetCatalog.definitions {
            for facing in CardinalDirection.allCases {
                let node = factory.makeAsset(id: definition.id, facing: facing)
                let container = SCNNode()
                container.addChildNode(node)
                let bounds = container.boundingBox
                let minimum = bounds.min
                let maximum = bounds.max
                let footprint = definition.footprint(facing: facing)
                // The plinth is the visible, exact footprint contract. It
                // guarantees the artwork touches the same grid bounds used by
                // placement and hit testing, including quarter-turn rotation.
                XCTAssertEqual(maximum.x - minimum.x, Float(footprint.width) * map.metrics.cellSize, accuracy: 0.01, definition.id.rawValue)
                XCTAssertEqual(maximum.z - minimum.z, Float(footprint.depth) * map.metrics.cellSize, accuracy: 0.01, definition.id.rawValue)
                XCTAssertLessThanOrEqual(maximum.x - minimum.x, Float(footprint.width) * map.metrics.cellSize + 0.01, definition.id.rawValue)
                XCTAssertLessThanOrEqual(maximum.z - minimum.z, Float(footprint.depth) * map.metrics.cellSize + 0.01, definition.id.rawValue)
                XCTAssertGreaterThanOrEqual(minimum.y, -0.01, definition.id.rawValue)
                XCTAssertLessThanOrEqual(maximum.y, definition.selectionVolume.maximumHeight + 0.01, definition.id.rawValue)
                XCTAssertNotNil(node.childNode(withName: CityBuildingFactory.nearDetailNodeName, recursively: false))
                XCTAssertNotNil(node.childNode(withName: CityBuildingFactory.propDetailNodeName, recursively: false))
            }
        }
    }

    @MainActor
    func testAuthoredObjectHeightsRemainGroundedAndInsideSelectionVolumes() throws {
        let factory = CityBuildingFactory(cellSize: map.metrics.cellSize)
        for object in map.objects {
            let definition = CityAssetCatalog.definition(for: object.assetID)
            let node = factory.makeAsset(
                id: object.assetID,
                facing: object.facing,
                heightHint: object.kind == .parking ? nil : object.height
            )
            let container = SCNNode()
            container.addChildNode(node)
            let bounds = container.boundingBox
            XCTAssertEqual(bounds.min.y + GridSceneElevation.assetBase, GridSceneElevation.parcelSurface, accuracy: 0.001, object.id)
            XCTAssertLessThanOrEqual(
                bounds.max.y,
                definition.selectionVolume(facing: object.facing).maximumHeight + 0.01,
                object.id
            )
            XCTAssertGreaterThanOrEqual(object.height, definition.nominalHeight, object.id)
            XCTAssertLessThanOrEqual(object.height, definition.nominalHeight * 1.20, object.id)
        }
    }

    @MainActor
    func testRepeatedAssetsReuseGeometryResources() throws {
        let factory = CityBuildingFactory(cellSize: map.metrics.cellSize)
        let first = factory.makeAsset(id: .residentialCottage, facing: .south)
        let second = factory.makeAsset(id: .residentialCottage, facing: .south)
        let firstGeometry = try XCTUnwrap(first.childNodes.first(where: { $0.geometry != nil })?.geometry)
        let secondGeometry = try XCTUnwrap(second.childNodes.first(where: { $0.geometry != nil })?.geometry)
        XCTAssertTrue(firstGeometry === secondGeometry)
    }

    @MainActor
    func testLowPolyAssetsHaveNormalsNoCollidersAndStayWithinNodeBudget() {
        let factory = CityBuildingFactory(cellSize: map.metrics.cellSize)
        var totalGeometryNodes = 0
        var uniqueMaterials: Set<ObjectIdentifier> = []
        for definition in CityAssetCatalog.definitions {
            let node = factory.makeAsset(id: definition.id, facing: .south)
            var assetGeometryNodes = 0
            node.enumerateChildNodes { child, _ in
                XCTAssertNil(child.physicsBody, definition.id.rawValue)
                guard let geometry = child.geometry else { return }
                assetGeometryNodes += 1
                totalGeometryNodes += 1
                XCTAssertFalse(geometry.sources(for: .normal).isEmpty, definition.id.rawValue)
                for material in geometry.materials {
                    XCTAssertFalse(material.isDoubleSided, definition.id.rawValue)
                    uniqueMaterials.insert(ObjectIdentifier(material))
                }
            }
            XCTAssertLessThanOrEqual(assetGeometryNodes, 64, definition.id.rawValue)
        }
        XCTAssertLessThan(uniqueMaterials.count, totalGeometryNodes)
    }

    @MainActor
    func testAmbientBuildingsUseLayeredSilhouettesInsteadOfSingleBoxMasses() {
        let factory = CityBuildingFactory(cellSize: map.metrics.cellSize)
        for definition in CityAssetCatalog.ambientDefinitions where definition.category != .parking {
            let node = factory.makeAsset(id: definition.id, facing: .south)
            let footprintWidth = Float(definition.footprint.width) * map.metrics.cellSize
            let footprintDepth = Float(definition.footprint.depth) * map.metrics.cellSize
            let majorMasses = node.childNodes.filter { child in
                guard let geometry = child.geometry else { return false }
                let bounds = geometry.boundingBox
                let width = bounds.max.x - bounds.min.x
                let height = bounds.max.y - bounds.min.y
                let depth = bounds.max.z - bounds.min.z
                return width >= footprintWidth * 0.15
                    && depth >= footprintDepth * 0.15
                    && height >= 0.5
            }

            XCTAssertGreaterThanOrEqual(
                majorMasses.count,
                2,
                "\(definition.id.rawValue) must read as a composed 3D silhouette, not one colored box"
            )
        }
    }

    @MainActor
    func testTraditionalLowRiseAssetsUseFacetedRoofsInsteadOfBoxSlabs() {
        let factory = CityBuildingFactory(cellSize: map.metrics.cellSize)
        let traditionalAssets: [CityAssetID] = [
            .residentialCottage,
            .residentialGable,
            .residentialTwin,
            .luxuryCourtyard,
            .luxuryGarage,
            .commercialRestaurant
        ]

        for assetID in traditionalAssets {
            let node = factory.makeAsset(id: assetID, facing: .south)
            let roof = node.childNode(withName: "hipped-roof", recursively: true)
            XCTAssertNotNil(roof, "\(assetID.rawValue) needs a reusable faceted roof mesh")
            XCTAssertFalse(roof?.geometry is SCNBox, "\(assetID.rawValue) roof cannot be a box slab")
            XCTAssertGreaterThan(roof?.geometry?.elements.first?.primitiveCount ?? 0, 4, assetID.rawValue)
        }
    }

    @MainActor
    func testParcelNeighborsAreResolvedOnlyAcrossContinuousRoadBands() throws {
        // Downtown plot 0 sits at the block's north-west corner.
        let first = try XCTUnwrap(map.parcel(legacyPlotID: 0))
        XCTAssertEqual(map.neighboringParcel(of: first, in: .east)?.legacyPlotID, 1)
        XCTAssertEqual(map.neighboringParcel(of: first, in: .south)?.legacyPlotID, 4)
        XCTAssertNil(map.neighboringParcel(of: first, in: .north))
        XCTAssertNil(map.neighboringParcel(of: first, in: .west))

        // The northern half of the old central-park carve now contains one
        // continuous two-plot tower campus, reached across its perimeter road.
        let besidePark = try XCTUnwrap(map.parcel(legacyPlotID: 1))
        let towerCampus = try XCTUnwrap(map.neighboringParcel(of: besidePark, in: .east))
        XCTAssertEqual(towerCampus.rect.size, .nineByFour)
        XCTAssertEqual(towerCampus.district, .downtown)

        // The former eastern green finger is now an infill block connected
        // across the original downtown perimeter street.
        let districtEdge = try XCTUnwrap(map.parcel(legacyPlotID: 3))
        let easternInfill = try XCTUnwrap(map.neighboringParcel(of: districtEdge, in: .east))
        XCTAssertEqual(easternInfill.rect.origin, GridCoordinate(column: 38, row: 32))
        XCTAssertEqual(easternInfill.district, .downtown)
    }

    func testMultiParcelStoreUsesOneBuildingAndGridContainedParkingLots() throws {
        let store = Store(
            name: "QA店",
            plotID: 108,
            plotIDs: [108, 109, 110],
            type: .roadside,
            acquisition: .lease,
            marketPolicy: StoreMarketPolicy(priorityCategories: [.commercial, .pickup], targetPurpose: .corporate),
            facilities: [.corporateDesk],
            inventory: []
        )
        let placements = GridStorePlacementAdapter.visualPlacements(for: store, map: map)
        XCTAssertEqual(placements.count, 3)
        XCTAssertEqual(placements.filter { $0.role == .primaryBuilding }.count, 1)
        XCTAssertEqual(placements.filter { $0.role == .displayParking }.count, 2)

        for placement in placements {
            let parcel = try XCTUnwrap(map.parcel(id: placement.parcelID))
            XCTAssertTrue(parcel.rect.contains(placement.rect))
            XCTAssertFalse(placement.rect.cells.contains { map.roads[$0] != nil })
            let definition = CityAssetCatalog.definition(for: placement.assetID)
            XCTAssertFalse(
                definition.roadConnections(facing: placement.facing)
                    .isDisjoint(with: map.usableRoadAccess(for: parcel))
            )
        }
    }


    private func vacantParcel(in district: DistrictKind) -> GridParcel? {
        map.parcels.first { parcel in
            parcel.district == district
                && parcel.currentBuildingID == nil
                && map.isParcelVacant(parcel.id)
        }
    }

    private func replacingMap(
        parcels: [GridParcel]? = nil,
        objects: [GridPlacedObject]? = nil,
        anchors: [GridMapAnchorID: GridCoordinate]? = nil
    ) -> GridCityMap {
        GridCityMap(
            id: map.id,
            name: map.name,
            size: map.size,
            metrics: map.metrics,
            roads: map.roads,
            parcels: parcels ?? map.parcels,
            objects: objects ?? map.objects,
            anchors: anchors ?? map.anchors,
            terrain: map.terrain
        )
    }

    private func boundarySpan(
        pieces: [GridLocalSurfaceRect],
        direction: CardinalDirection,
        halfCell: Float
    ) -> ClosedRange<Float>? {
        let epsilon: Float = 0.0001
        let touching = pieces.filter { piece in
            switch direction {
            case .north: abs(piece.minZ + halfCell) < epsilon
            case .east: abs(piece.maxX - halfCell) < epsilon
            case .south: abs(piece.maxZ - halfCell) < epsilon
            case .west: abs(piece.minX + halfCell) < epsilon
            }
        }
        guard !touching.isEmpty else { return nil }
        switch direction {
        case .north, .south:
            return touching.map(\.minX).min()!...touching.map(\.maxX).max()!
        case .east, .west:
            return touching.map(\.minZ).min()!...touching.map(\.maxZ).max()!
        }
    }
}
