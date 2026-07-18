import Foundation

/// A deterministic, asset-independent city used by the first map implementation
/// and by structural tests. All authored positions are integer grid coordinates.
enum ValidationCityMap {
    static let shared: GridCityMap = makeMap()

    private static let mapSize = GridMapSize(columns: 64, rows: 38)
    private static let metrics = GridMetrics(cellSize: 20)
    private static let parcelSize = GridSize.fourByFour
    private static let vacantLocalNumbers: Set<Int> = [4, 8, 12]
    private static let parkingLocalNumbers: Set<Int> = [3]

    private struct DistrictBlock {
        let district: DistrictKind
        let startColumn: Int
        let startRow: Int
        let districtIndex: Int
    }

    private static let districtBlocks: [DistrictBlock] = [
        .init(district: .downtown, startColumn: 1, startRow: 1, districtIndex: 0),
        .init(district: .station, startColumn: 22, startRow: 1, districtIndex: 1),
        .init(district: .emerging, startColumn: 43, startRow: 1, districtIndex: 2),
        .init(district: .suburb, startColumn: 1, startRow: 18, districtIndex: 3),
        .init(district: .industrial, startColumn: 22, startRow: 18, districtIndex: 4),
        .init(district: .highway, startColumn: 43, startRow: 18, districtIndex: 5)
    ]

    private static func makeMap() -> GridCityMap {
        let roadClasses = makeRoadClasses()
        let roads = GridRoadNetwork.compile(roadClasses: roadClasses)
        let content = makeParcelsAndObjects()
        let map = GridCityMap(
            id: "suihama-grid-v1",
            name: "翠浜市 グリッド検証マップ",
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
        for separator in [5, 10, 15, 26, 31, 36, 47, 52, 57] {
            addVertical(column: separator, rows: 0...15, roadClass: .local)
            addVertical(column: separator, rows: 17...34, roadClass: .local)
        }
        for row in [5, 10] {
            addHorizontal(row: row, columns: 0...20, roadClass: .local)
            addHorizontal(row: row, columns: 21...41, roadClass: .local)
            addHorizontal(row: row, columns: 42...63, roadClass: .local)
        }
        for row in [22, 27, 32] {
            addHorizontal(row: row, columns: 0...20, roadClass: .local)
            addHorizontal(row: row, columns: 21...41, roadClass: .local)
            addHorizontal(row: row, columns: 42...63, roadClass: .local)
        }

        // A short curved feeder guarantees that corner/end tile variants are
        // represented in the validation map rather than only in unit fixtures.
        addVertical(column: 0, rows: 2...5, roadClass: .local)

        // Two vertical arterial corridors and one map-wide arterial band.
        for column in 20...21 { addVertical(column: column, rows: 0...37, roadClass: .arterial) }
        for column in 41...42 { addVertical(column: column, rows: 0...37, roadClass: .arterial) }
        for row in 15...17 { addHorizontal(row: row, columns: 0...63, roadClass: .arterial) }

        // Four cells wide: a deliberately simplified highway/IC environment.
        for row in 34...37 { addHorizontal(row: row, columns: 0...63, roadClass: .arterial) }
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
            for row in 0..<3 {
                for column in 0..<4 {
                    let localNumber = row * 4 + column + 1
                    let legacyPlotID = block.districtIndex * 12 + localNumber - 1
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
                    let access: Set<CardinalDirection> = column == 3 ? [.west] : [.east]
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
                            : asset.nominalHeight + Float(localNumber % 3) * heightVariation(for: block.district)
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
