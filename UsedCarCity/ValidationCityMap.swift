import Foundation

/// A deterministic, asset-independent city used by the first map implementation
/// and by structural tests. All authored positions are integer grid coordinates.
enum ValidationCityMap {
    static let shared: GridCityMap = makeMap()

    private static let mapSize = GridMapSize(columns: 93, rows: 57)
    private static let metrics = GridMetrics(cellSize: 20)
    private static let parcelSize = GridSize.fourByFour
    private static let districtColumns = 6
    private static let districtRows = 5
    private static let plotsPerDistrict = districtColumns * districtRows
    // Keep two buyable lots in every district (twelve in total), but let the
    // validation city read as a settled town rather than a checkerboard of
    // empty green squares.  Parcel geometry and buildability are unchanged.
    private static let vacantLocalNumbers: Set<Int> = [10, 24]
    private static let parkingLocalNumbers: Set<Int> = [3, 21]

    private struct DistrictBlock {
        let district: DistrictKind
        let startColumn: Int
        let startRow: Int
        let districtIndex: Int
    }

    private static let districtBlocks: [DistrictBlock] = [
        .init(district: .downtown, startColumn: 1, startRow: 1, districtIndex: 0),
        .init(district: .station, startColumn: 32, startRow: 1, districtIndex: 1),
        .init(district: .emerging, startColumn: 63, startRow: 1, districtIndex: 2),
        .init(district: .suburb, startColumn: 1, startRow: 28, districtIndex: 3),
        .init(district: .industrial, startColumn: 32, startRow: 28, districtIndex: 4),
        .init(district: .highway, startColumn: 63, startRow: 28, districtIndex: 5)
    ]

    private static func makeMap() -> GridCityMap {
        let roadClasses = makeRoadClasses()
        let roads = GridRoadNetwork.compile(roadClasses: roadClasses)
        let content = makeParcelsAndObjects()
        let map = GridCityMap(
            id: "suihama-grid-v2",
            name: "翠浜市 広域グリッドマップ",
            size: mapSize,
            metrics: metrics,
            roads: roads,
            parcels: content.parcels,
            objects: content.objects
        )
        precondition(
            GridMapValidator.validate(map).isEmpty,
            "Validation map must satisfy the shared grid rules"
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

        // Local streets form four-by-four parcels. Every line reaches an arterial.
        for separator in [5, 10, 15, 20, 25, 36, 41, 46, 51, 56, 67, 72, 77, 82, 87] {
            addVertical(column: separator, rows: 0...24, roadClass: .local)
            addVertical(column: separator, rows: 28...51, roadClass: .local)
        }
        for row in [5, 10, 15, 20] {
            addHorizontal(row: row, columns: 0...29, roadClass: .local)
            addHorizontal(row: row, columns: 32...60, roadClass: .local)
            addHorizontal(row: row, columns: 63...92, roadClass: .local)
        }
        for row in [32, 37, 42, 47] {
            addHorizontal(row: row, columns: 0...29, roadClass: .local)
            addHorizontal(row: row, columns: 32...60, roadClass: .local)
            addHorizontal(row: row, columns: 63...92, roadClass: .local)
        }

        // A short curved feeder guarantees that corner/end tile variants are
        // represented in the validation map rather than only in unit fixtures.
        addVertical(column: 0, rows: 2...5, roadClass: .local)

        // Two vertical arterial corridors and one map-wide arterial band.
        for column in 30...31 { addVertical(column: column, rows: 0...56, roadClass: .arterial) }
        for column in 61...62 { addVertical(column: column, rows: 0...56, roadClass: .arterial) }
        for row in 25...27 { addHorizontal(row: row, columns: 0...92, roadClass: .arterial) }

        // Four cells wide: a deliberately simplified highway/IC environment.
        for row in 52...56 { addHorizontal(row: row, columns: 0...92, roadClass: .arterial) }
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
            var districtAssetIndex = 0
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
                        ownership: .market,
                        isPurchasable: true,
                        isBuildable: true,
                        roadAccess: access,
                        currentBuildingID: isParking ? nil : objectID,
                        price: basePrice(for: block.district, legacyPlotID: legacyPlotID)
                    )
                    parcels.append(parcel)

                    guard let objectID else { continue }
                    let asset = isParking
                        ? CityAssetCatalog.definition(for: .surfaceParking)
                        : districtAssets[districtAssetIndex % districtAssets.count]
                    if !isParking { districtAssetIndex += 1 }
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
                            : asset.nominalHeight + Float(localNumber % 3) * heightStep
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
