import XCTest
import SceneKit
import UIKit
@testable import UsedCarCity

final class GridMapTests: XCTestCase {
    private let map = ValidationCityMap.shared

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
        XCTAssertEqual(map.parcels.count, 288)
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

    func testExpandedCityProvidesBroadDistrictsAndEnoughBuildableLand() {
        XCTAssertEqual(map.size, GridMapSize(columns: 123, rows: 67))
        XCTAssertEqual(map.objects.count, 264)
        XCTAssertGreaterThan(map.roads.count, 3_000)

        let occupiedParcelIDs = Set(map.objects.map(\.parcelID))
        for district in DistrictKind.allCases {
            let parcels = map.parcels.filter { $0.district == district }
            XCTAssertEqual(parcels.count, 48, district.rawValue)
            XCTAssertEqual(
                parcels.filter { !occupiedParcelIDs.contains($0.id) }.count,
                4,
                district.rawValue
            )
            XCTAssertEqual(
                map.objects.filter { object in
                    object.kind == .parking
                        && map.parcel(id: object.parcelID)?.district == district
                }.count,
                4,
                district.rawValue
            )
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
        XCTAssertEqual(parkingObjects.count, DistrictKind.allCases.count * 4)
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
        XCTAssertEqual(spec.orthographicScale(baseScale: 2_000, zoomStep: 0), 2_000, accuracy: 0.001)
        XCTAssertLessThan(spec.orthographicScale(baseScale: 2_000, zoomStep: 3), 2_000)
        XCTAssertEqual(spec.cameraOffset(groundDistance: 1_200), offsetBefore)
        XCTAssertEqual(map.metrics.worldBounds(of: parcel.rect, mapSize: map.size).center, positionBefore)
    }

    func testCameraFocusCannotPanOutsideAtAnyZoomLevel() {
        let bounds = map.metrics.worldBounds(of: map.size)
        let requested = GridWorldPoint(x: bounds.maxX * 10, z: bounds.minZ * 10)
        let fit = GridCameraFocusPolicy.clampedFocus(requested, in: bounds, zoomFactor: 1)
        XCTAssertEqual(fit, bounds.center)

        var previousMaximumX: Float = 0
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

    func testAllFiveDebugZoomLevelsCanBeSelectedDeterministically() {
        for step in 0...4 {
            XCTAssertEqual(
                GridCameraZoom.demoInitialStep(arguments: ["app", "-demo-map-zoom-step=\(step)"]),
                step
            )
        }
        XCTAssertEqual(GridCameraZoom.demoInitialStep(arguments: ["app", "-demo-map-zoom-step=99"]), 4)
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
        XCTAssertEqual(definitions.filter { $0.category == .commercial }.count, 6)
        XCTAssertEqual(definitions.filter { $0.category == .industrial }.count, 5)
        XCTAssertEqual(definitions.filter { $0.category == .downtown }.count, 5)
        XCTAssertEqual(definitions.filter { $0.category == .highway }.count, 3)
        XCTAssertEqual(definitions.filter(\.isPlayerFacility).count, 13)
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

    func testAssetLODPolicyPreservesSilhouetteAndProgressivelyRevealsDetails() {
        XCTAssertEqual(
            CityAssetLODPolicy.visibility(zoomFactor: GridCameraZoom.scaleFactors[0]),
            CityAssetLODVisibility(showsNearDetails: false, showsProps: false)
        )
        XCTAssertEqual(
            CityAssetLODPolicy.visibility(zoomFactor: GridCameraZoom.scaleFactors[1]),
            CityAssetLODVisibility(showsNearDetails: true, showsProps: false)
        )
        XCTAssertEqual(
            CityAssetLODPolicy.visibility(zoomFactor: GridCameraZoom.scaleFactors[2]),
            CityAssetLODVisibility(showsNearDetails: true, showsProps: true)
        )
    }

    func testCityBuildingRenderingDefaultsToGridNative3D() {
        XCTAssertEqual(CityBuildingRenderMode.selected(arguments: ["app"]), .gridNative3D)
        XCTAssertEqual(
            CityBuildingRenderMode.selected(arguments: ["app", "-legacy-iso25d-sprites"]),
            .legacyIso25DSprites
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
        for definition in CityAssetCatalog.ambientDefinitions where definition.category != .parking {
            XCTAssertEqual(definition.footprint, .fourByFour, definition.id.rawValue)
        }
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
        let factory = LowPolyCityAssetFactory(cellSize: map.metrics.cellSize)
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
        let factory = LowPolyCityAssetFactory(cellSize: map.metrics.cellSize)
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
        XCTAssertNotNil(node.childNode(withName: LowPolyCityAssetFactory.nearDetailNodeName, recursively: false))
        XCTAssertNotNil(node.childNode(withName: LowPolyCityAssetFactory.propDetailNodeName, recursively: false))
    }

    @MainActor
    func testGeneratedAssetGeometryStaysInsideItsOrientedGridFootprint() {
        let factory = LowPolyCityAssetFactory(cellSize: map.metrics.cellSize)
        for definition in CityAssetCatalog.definitions {
            for facing in CardinalDirection.allCases {
                let node = factory.makeAsset(id: definition.id, facing: facing)
                let container = SCNNode()
                container.addChildNode(node)
                let bounds = container.boundingBox
                let minimum = bounds.min
                let maximum = bounds.max
                let footprint = definition.footprint(facing: facing)
                XCTAssertLessThanOrEqual(maximum.x - minimum.x, Float(footprint.width) * map.metrics.cellSize + 0.01, definition.id.rawValue)
                XCTAssertLessThanOrEqual(maximum.z - minimum.z, Float(footprint.depth) * map.metrics.cellSize + 0.01, definition.id.rawValue)
                XCTAssertGreaterThanOrEqual(minimum.y, -0.01, definition.id.rawValue)
                XCTAssertLessThanOrEqual(maximum.y, definition.selectionVolume.maximumHeight + 0.01, definition.id.rawValue)
                XCTAssertNotNil(node.childNode(withName: LowPolyCityAssetFactory.nearDetailNodeName, recursively: false))
                XCTAssertNotNil(node.childNode(withName: LowPolyCityAssetFactory.propDetailNodeName, recursively: false))
            }
        }
    }

    @MainActor
    func testAuthoredObjectHeightsRemainGroundedAndInsideSelectionVolumes() throws {
        let factory = LowPolyCityAssetFactory(cellSize: map.metrics.cellSize)
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
        let factory = LowPolyCityAssetFactory(cellSize: map.metrics.cellSize)
        let first = factory.makeAsset(id: .residentialCottage, facing: .south)
        let second = factory.makeAsset(id: .residentialCottage, facing: .south)
        let firstGeometry = try XCTUnwrap(first.childNodes.first(where: { $0.geometry != nil })?.geometry)
        let secondGeometry = try XCTUnwrap(second.childNodes.first(where: { $0.geometry != nil })?.geometry)
        XCTAssertTrue(firstGeometry === secondGeometry)
    }

    @MainActor
    func testLowPolyAssetsHaveNormalsNoCollidersAndStayWithinNodeBudget() {
        let factory = LowPolyCityAssetFactory(cellSize: map.metrics.cellSize)
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
        let factory = LowPolyCityAssetFactory(cellSize: map.metrics.cellSize)
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
        let factory = LowPolyCityAssetFactory(cellSize: map.metrics.cellSize)
        let traditionalAssets: [CityAssetID] = [
            .residentialCottage,
            .residentialGable,
            .residentialTwin,
            .luxuryCourtyard,
            .luxuryGarage,
            .playerSmallDealer
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
    func testIso25DAssetPackMatchesGridCatalogAndLoadsTransparentImages() throws {
        XCTAssertEqual(Iso25DCityAssetCatalog.all.count, 52)
        XCTAssertEqual(
            Set(Iso25DCityAssetCatalog.all.map(\.imageName)).count,
            Iso25DCityAssetCatalog.all.count
        )
        // Every card must scale and anchor from measured artwork geometry, and
        // the generated calibration table must not carry stale extra entries.
        XCTAssertEqual(
            Set(Iso25DCityAssetCatalog.all.map(\.imageName)),
            Set(Iso25DSpriteCalibration.byImageName.keys)
        )

        for sprite in Iso25DCityAssetCatalog.all {
            let gridDefinition = CityAssetCatalog.definition(for: sprite.assetID)
            XCTAssertEqual(sprite.footprint, gridDefinition.footprint)
            XCTAssertEqual(sprite.origin, .footprintCenterAtGround)
            XCTAssertEqual(sprite.frontDirection, gridDefinition.frontDirection)
            XCTAssertEqual(sprite.roadConnectionDirections, gridDefinition.roadConnectionDirections)
            XCTAssertEqual(sprite.requiredClearance, gridDefinition.requiredClearance)
            XCTAssertEqual(sprite.allowedDistricts, gridDefinition.allowedDistricts)
            XCTAssertTrue(sprite.supports(facing: sprite.facing))
            // Measured ground plates stay near the image center; a value at
            // these bounds means broken artwork (bad matte or projection),
            // not a tuning choice.
            XCTAssertTrue((0.35...0.65).contains(sprite.groundAnchorX), sprite.imageName)
            XCTAssertTrue((0.4...0.9).contains(sprite.groundAnchorY), sprite.imageName)
            XCTAssertTrue((0.65...1).contains(sprite.projectedFootprintWidthFraction), sprite.imageName)

            let image = try XCTUnwrap(UIImage(named: sprite.imageName))
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(cgImage.width, sprite.pixelWidth)
            XCTAssertEqual(cgImage.height, sprite.pixelHeight)
            XCTAssertEqual(sprite.pixelWidth, 1_024)
            XCTAssertEqual(sprite.pixelHeight, 1_024)
            XCTAssertFalse(
                [.none, .noneSkipFirst, .noneSkipLast].contains(cgImage.alphaInfo),
                "\(sprite.imageName) must retain an alpha channel"
            )
        }

        for representative in [
            CityAssetID.residentialCottage,
            .luxuryCourtyard,
            .commercialConvenience,
            .industrialFactory,
            .downtownMixedUse,
            .highwayLogistics,
            .playerSmallDealer,
            .playerMediumDealer,
            .playerLargeDealer,
            .playerServiceWorkshop
        ] {
            for facing in CardinalDirection.allCases {
                XCTAssertNotNil(Iso25DCityAssetCatalog.definition(for: representative, facing: facing))
            }
        }
    }

    func testIso25DPlayerFacilityScaleVariantsUseDedicatedArtwork() throws {
        let dedicatedFamilies: [(CityAssetID, String)] = [
            (.playerMediumDealer, "Iso25DDealerMedium_"),
            (.playerLargeDealer, "Iso25DDealerLarge_"),
            (.playerServiceWorkshop, "Iso25DServiceWorkshop")
        ]

        for (assetID, imagePrefix) in dedicatedFamilies {
            XCTAssertEqual(Iso25DCityAssetCatalog.representativeAssetID(for: assetID), assetID)
            for facing in CardinalDirection.allCases {
                let definition = try XCTUnwrap(
                    Iso25DCityAssetCatalog.definition(for: assetID, facing: facing)
                )
                XCTAssertEqual(definition.assetID, assetID)
                XCTAssertTrue(
                    definition.imageName.hasPrefix(imagePrefix),
                    "\(assetID.rawValue) \(facing.rawValue) must not reuse a smaller facility sprite"
                )
            }
        }
    }

    func testIso25DVariantSelectionUsesAuthoredVariantAndDirectionFallback() throws {
        let authoredPairs: [(CityAssetID, String, String)] = [
            (.residentialApartment, "Iso25DResidentialApartmentB_East", "Iso25DResidentialApartmentB_West"),
            (.luxuryPool, "Iso25DLuxuryPoolB_East", "Iso25DLuxuryPoolB_West"),
            (.commercialGasStation, "Iso25DCommercialGasStationB_East", "Iso25DCommercialGasStationB_West"),
            (.industrialLoadingWarehouse, "Iso25DIndustrialLoadingWarehouseB_East", "Iso25DIndustrialLoadingWarehouseB_West"),
            (.downtownOffice, "Iso25DDowntownOfficeB_East", "Iso25DDowntownOfficeB_West"),
            (.highwayBigBox, "Iso25DHighwayBigBoxB_East", "Iso25DHighwayBigBoxB_West")
        ]

        for (assetID, eastImage, westImage) in authoredPairs {
            XCTAssertEqual(
                try XCTUnwrap(Iso25DCityAssetCatalog.definition(for: assetID, facing: .east)).imageName,
                eastImage
            )
            XCTAssertEqual(
                try XCTUnwrap(Iso25DCityAssetCatalog.definition(for: assetID, facing: .west)).imageName,
                westImage
            )
            XCTAssertNotNil(
                Iso25DCityAssetCatalog.definition(for: assetID, facing: .north),
                "\(assetID.rawValue) should fall back to its district A asset when B has no north card"
            )
        }

        XCTAssertEqual(
            Iso25DCityAssetCatalog.definition(for: .residentialGable, facing: .east)?.imageName,
            "Iso25DHouseGeneralA_East"
        )
    }

    @MainActor
    func testIso25DAmbientCoverageAndSpriteGeometryStayGridDerived() throws {
        for object in map.objects where object.kind == .building {
            XCTAssertNotNil(
                Iso25DCityAssetCatalog.definition(for: object.assetID, facing: object.facing),
                "Missing 2.5D artwork for \(object.assetID.rawValue) facing \(object.facing.rawValue)"
            )
        }

        let factory = Iso25DCitySpriteFactory()
        let worldWidth = Float(4) * map.metrics.cellSize
        let worldDepth = Float(4) * map.metrics.cellSize
        let first = try XCTUnwrap(factory.makeSprite(
            assetID: .residentialGable,
            facing: .east,
            worldWidth: worldWidth,
            worldDepth: worldDepth,
            renderingOrder: 12_345
        ))
        let second = try XCTUnwrap(factory.makeSprite(
            assetID: .residentialTwin,
            facing: .east,
            worldWidth: worldWidth,
            worldDepth: worldDepth,
            renderingOrder: 12_346
        ))
        let plane = try XCTUnwrap(first.geometry as? SCNPlane)
        let definition = try XCTUnwrap(
            Iso25DCityAssetCatalog.definition(for: .residentialGable, facing: .east)
        )
        let expectedWidth = CGFloat(
            (worldWidth + worldDepth) / sqrt(2) / definition.projectedFootprintWidthFraction
        )
        XCTAssertEqual(plane.width, expectedWidth, accuracy: 0.001)
        XCTAssertEqual(first.renderingOrder, 12_345)
        XCTAssertEqual(first.name, Iso25DCitySpriteFactory.spriteNodeName)
        XCTAssertNil(first.physicsBody)
        XCTAssertFalse(try XCTUnwrap(first.geometry?.firstMaterial).writesToDepthBuffer)
        XCTAssertFalse(try XCTUnwrap(first.geometry?.firstMaterial).readsFromDepthBuffer)
        XCTAssertTrue(first.geometry?.firstMaterial === second.geometry?.firstMaterial)
    }

    func testParcelNeighborsAreResolvedOnlyAcrossContinuousRoadBands() throws {
        let first = try XCTUnwrap(map.parcel(legacyPlotID: 0))
        XCTAssertEqual(map.neighboringParcel(of: first, in: .east)?.legacyPlotID, 1)
        XCTAssertEqual(map.neighboringParcel(of: first, in: .south)?.legacyPlotID, 8)
        XCTAssertNil(map.neighboringParcel(of: first, in: .north))
        XCTAssertNil(map.neighboringParcel(of: first, in: .west))

        let districtEdge = try XCTUnwrap(map.parcel(legacyPlotID: 7))
        XCTAssertNil(map.neighboringParcel(of: districtEdge, in: .east))
    }

    func testMultiParcelStoreUsesOneBuildingAndGridContainedParkingLots() throws {
        let store = Store(
            name: "QA店",
            plotID: 150,
            plotIDs: [150, 151, 152],
            type: .roadside,
            acquisition: .lease,
            focus: .business,
            concept: .business,
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
            anchors: anchors ?? map.anchors
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
