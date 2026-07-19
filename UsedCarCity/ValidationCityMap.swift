import Foundation

/// A deterministic, asset-independent city used by the first map implementation
/// and by structural tests. All authored positions are integer grid coordinates.
enum ValidationCityMap {
    static let shared: GridCityMap = makeMap()

    private static let metrics = GridMetrics(cellSize: 20)
    private static let parcelSize = GridSize.fourByFour
    private static let parcelStride = 5
    private static let districtColumns = 8
    private static let districtRows = 6
    private static let districtCellWidth = districtColumns * parcelStride
    private static let districtCellDepth = districtRows * parcelStride
    private static let lowerDistrictStartRow = districtCellDepth + 3
    private static let highwayStartRow = lowerDistrictStartRow + districtCellDepth - 1
    private static let mapSize = GridMapSize(
        columns: districtCellWidth * 3 + 3,
        rows: highwayStartRow + 5
    )
    private static let plotsPerDistrict = districtColumns * districtRows
    // Keep a repeatable but sparse mix of development sites and surface
    // parking in every expanded district. Buildings still dominate, while
    // each 8×6 district has enough open land for multi-cell player facilities.
    private static let vacantLocalNumbers: Set<Int> = [10, 24, 39, 46]
    private static let parkingLocalNumbers: Set<Int> = [3, 18, 29, 43]

    private struct DistrictBlock {
        let district: DistrictKind
        let startColumn: Int
        let startRow: Int
        let districtIndex: Int
    }

    private static let districtBlocks: [DistrictBlock] = [
        .init(district: .downtown, startColumn: 1, startRow: 1, districtIndex: 0),
        .init(district: .station, startColumn: districtCellWidth + 2, startRow: 1, districtIndex: 1),
        .init(district: .emerging, startColumn: districtCellWidth * 2 + 3, startRow: 1, districtIndex: 2),
        .init(district: .suburb, startColumn: 1, startRow: lowerDistrictStartRow, districtIndex: 3),
        .init(district: .industrial, startColumn: districtCellWidth + 2, startRow: lowerDistrictStartRow, districtIndex: 4),
        .init(district: .highway, startColumn: districtCellWidth * 2 + 3, startRow: lowerDistrictStartRow, districtIndex: 5)
    ]

    private static func makeMap() -> GridCityMap {
        let roadClasses = makeRoadClasses()
        let roads = GridRoadNetwork.compile(roadClasses: roadClasses)
        let content = makeParcelsAndObjects()
        let map = GridCityMap(
            id: "suihama-grid-v3",
            name: "翠浜市 広域グリッドマップ",
            size: mapSize,
            metrics: metrics,
            roads: roads,
            parcels: content.parcels,
            objects: content.objects,
            anchors: [
                .auction: GridCoordinate(column: districtCellWidth / 2, row: highwayStartRow + 2),
                .bank: GridCoordinate(column: 15, row: 18),
                .realEstate: GridCoordinate(column: districtCellWidth, row: 18),
                .workshop: GridCoordinate(column: districtCellWidth * 2 + 1, row: lowerDistrictStartRow + 15),
                .advertising: GridCoordinate(column: districtCellWidth + districtCellWidth / 2 + 1, row: 18),
                .recruiting: GridCoordinate(column: districtCellWidth * 2 + districtCellWidth / 2 + 2, row: 12),
                .cityHall: GridCoordinate(column: mapSize.columns - 6, row: districtCellDepth - 5)
            ]
        )
        let issues = GridMapValidator.validate(map)
        precondition(
            issues.isEmpty,
            "Validation map must satisfy the shared grid rules:\n\(issues.map(\.description).joined(separator: "\n"))"
        )
        return map
    }

    private static func makeRoadClasses() -> [GridCoordinate: GridRoadClass] {
        var result: [GridCoordinate: GridRoadClass] = [:]

        func addHorizontal(row: Int, columns: ClosedRange<Int>, roadClass: GridRoadClass) {
            for column in columns where mapSize.contains(.init(column: column, row: row)) {
                result[.init(column: column, row: row)] = roadClass
            }
        }

        func addVertical(column: Int, rows: ClosedRange<Int>, roadClass: GridRoadClass) {
            for row in rows where mapSize.contains(.init(column: column, row: row)) {
                result[.init(column: column, row: row)] = roadClass
            }
        }

        // Local streets form four-by-four parcels. Dimensions are derived from
        // the district row/column counts so expanding the city does not require
        // rewriting a coordinate table.
        let verticalSeparators = districtBlocks.flatMap { block in
            (0..<(districtColumns - 1)).map {
                block.startColumn + parcelSize.width + $0 * parcelStride
            }
        }
        for separator in verticalSeparators {
            addVertical(column: separator, rows: 0...(districtCellDepth - 1), roadClass: .local)
            addVertical(column: separator, rows: lowerDistrictStartRow...(highwayStartRow - 1), roadClass: .local)
        }

        let firstArterialStart = districtCellWidth
        let secondArterialStart = districtCellWidth * 2 + 1
        let districtColumnRanges = [
            0...(firstArterialStart - 1),
            (districtCellWidth + 2)...(secondArterialStart - 1),
            (districtCellWidth * 2 + 3)...(mapSize.columns - 1)
        ]
        let upperLocalRows = (0..<(districtRows - 1)).map { parcelStride + $0 * parcelStride }
        let lowerLocalRows = (0..<(districtRows - 1)).map {
            lowerDistrictStartRow + parcelSize.depth + $0 * parcelStride
        }
        for row in upperLocalRows + lowerLocalRows {
            for columns in districtColumnRanges {
                addHorizontal(row: row, columns: columns, roadClass: .local)
            }
        }

        // A short curved feeder guarantees that corner/end tile variants are
        // represented in the validation map rather than only in unit fixtures.
        addVertical(column: 0, rows: 2...5, roadClass: .local)

        // Two vertical arterial corridors and one map-wide arterial band.
        for column in firstArterialStart...(firstArterialStart + 1) {
            addVertical(column: column, rows: 0...(mapSize.rows - 1), roadClass: .arterial)
        }
        for column in secondArterialStart...(secondArterialStart + 1) {
            addVertical(column: column, rows: 0...(mapSize.rows - 1), roadClass: .arterial)
        }
        for row in districtCellDepth...(lowerDistrictStartRow - 1) {
            addHorizontal(row: row, columns: 0...(mapSize.columns - 1), roadClass: .arterial)
        }

        // Four cells wide: a deliberately simplified highway/IC environment.
        for row in highwayStartRow...(mapSize.rows - 1) {
            addHorizontal(row: row, columns: 0...(mapSize.columns - 1), roadClass: .arterial)
        }
        return result
    }

    private static func makeParcelsAndObjects() -> (
        parcels: [GridParcel],
        objects: [GridPlacedObject]
    ) {
        var parcels: [GridParcel] = []
        var objects: [GridPlacedObject] = []

        for block in districtBlocks {
            let districtAssets = CityAssetCatalog.ambientAssets(for: block.district)
            for row in 0..<districtRows {
                for column in 0..<districtColumns {
                    let localNumber = row * districtColumns + column + 1
                    let legacyPlotID = block.districtIndex * plotsPerDistrict + localNumber - 1
                    let parcelID = "parcel-\(legacyPlotID)"
                    let rect = GridRect(
                        origin: GridCoordinate(
                            column: block.startColumn + column * 5,
                            row: block.startRow + row * 5
                        ),
                        size: parcelSize
                    )
                    let isVacant = vacantLocalNumbers.contains(localNumber)
                    let isParking = parkingLocalNumbers.contains(localNumber)
                    let objectID = isVacant ? nil : "object-\(legacyPlotID)"
                    let access: Set<CardinalDirection> = column == districtColumns - 1 ? [.west] : [.east]
                    let parcel = GridParcel(
                        id: parcelID,
                        legacyPlotID: legacyPlotID,
                        rect: rect,
                        district: block.district,
                        areaSquareMeters: 420,
                        ownership: .market,
                        isPurchasable: true,
                        isBuildable: true,
                        roadAccess: access,
                        currentBuildingID: isParking ? nil : objectID,
                        price: basePrice(for: block.district, legacyPlotID: legacyPlotID)
                    )
                    parcels.append(parcel)

                    guard let objectID else { continue }
                    let paletteIndex = (column + row * 3 + block.districtIndex) % districtAssets.count
                    let asset = isParking
                        ? CityAssetCatalog.definition(for: .surfaceParking)
                        : districtAssets[paletteIndex]
                    let facing = access.first ?? .south
                    let footprint = asset.footprint(facing: facing)
                    let objectRect = centeredRect(footprint: footprint, inside: rect)
                    // Keep authored height variation inside the asset's
                    // declared selection volume (at most +20%).  This lets
                    // district variation remain visible without giving an
                    // object a hit region shorter than its actual geometry.
                    let heightStep = min(
                        heightVariation(for: block.district),
                        asset.nominalHeight * 0.10
                    )
                    objects.append(GridPlacedObject(
                        id: objectID,
                        parcelID: parcelID,
                        rect: objectRect,
                        kind: isParking ? .parking : .building,
                        style: isParking ? .parking : style(for: block.district),
                        assetID: asset.id,
                        facing: facing,
                        height: isParking
                            ? asset.nominalHeight
                            : asset.nominalHeight + Float((localNumber + block.districtIndex) % 3) * heightStep
                    ))
                }
            }
        }
        return (parcels, objects)
    }

    private static func centeredRect(footprint: GridSize, inside parcel: GridRect) -> GridRect {
        GridRect(
            origin: GridCoordinate(
                column: parcel.minColumn + (parcel.size.width - footprint.width) / 2,
                row: parcel.minRow + (parcel.size.depth - footprint.depth) / 2
            ),
            size: footprint
        )
    }

    private static func style(for district: DistrictKind) -> GridBuildingStyle {
        switch district {
        case .downtown: .downtown
        case .station: .commercial
        case .emerging: .luxuryResidential
        case .suburb: .generalResidential
        case .industrial: .industrial
        case .highway: .roadside
        }
    }

    private static func heightVariation(for district: DistrictKind) -> Float {
        switch district {
        case .downtown: 2.5
        case .station: 0.7
        case .emerging, .suburb: 0.35
        case .industrial, .highway: 0.6
        }
    }

    private static func basePrice(for district: DistrictKind, legacyPlotID: Int) -> Int {
        let base: Int
        switch district {
        case .downtown: base = 14_000
        case .station: base = 9_500
        case .emerging: base = 6_200
        case .suburb: base = 7_000
        case .industrial: base = 3_800
        case .highway: base = 4_700
        }
        return base * (88 + ((legacyPlotID * 17) % 27)) / 100
    }
}

/// Production entry point for authored city geometry and gameplay parcels.
/// `ValidationCityMap` remains the deterministic builder behind this value so
/// structural tests and the running game exercise the exact same definition.
enum CityMapDefinition {
    static let suihama = ValidationCityMap.shared
}
