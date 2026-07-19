import Foundation

/// The authored production city: a coastal town on a 100×100 grid.
///
/// Geography (all integer grid coordinates, row 0 = north):
/// - A stair-stepped bay occupies the east and south-east. The expressway
///   crosses it on a long bay bridge.
/// - A river enters at the north edge, flows south between the suburb and the
///   hillside residential quarter, then bends east into the bay. Arterial
///   crossings render as bridges.
/// - Six gameplay districts sit between green belts, a central park, a station
///   plaza, a beach esplanade and an industrial quay, so the city reads as a
///   place rather than a uniform board.
///
/// Every value is deterministic and must satisfy `GridMapValidator` exactly
/// like any future city definition.
enum SuihamaCityMap {
    static let shared: GridCityMap = makeMap()

    private static let metrics = GridMetrics(cellSize: 20)
    private static let mapSize = GridMapSize(columns: 100, rows: 100)
    private static let parcelSize = GridSize.fourByFour
    private static let slotStride = 5

    // MARK: - Water geometry

    /// Bay: everything at or east of the stair-stepped coastline.
    static func bayStartColumn(row: Int) -> Int {
        switch row {
        case ..<20: 86
        case ..<40: 80
        case ..<60: 72
        case ..<80: 68
        default: 66
        }
    }

    private static let riverColumns = 48...49
    private static let riverVerticalRows = 0...37
    private static let riverBendRows = 36...37

    static func isWater(_ coordinate: GridCoordinate) -> Bool {
        if coordinate.column >= bayStartColumn(row: coordinate.row) { return true }
        if riverColumns.contains(coordinate.column), riverVerticalRows.contains(coordinate.row) {
            return true
        }
        if riverBendRows.contains(coordinate.row),
           coordinate.column > riverColumns.upperBound,
           coordinate.column < bayStartColumn(row: coordinate.row) {
            return true
        }
        return false
    }

    // MARK: - District blocks

    struct DistrictBlock {
        let district: DistrictKind
        let origin: GridCoordinate
        let slotColumns: Int
        let slotRows: Int
        /// Slots removed from the parcel grid and turned into pocket parks.
        let parkSlots: Set<SlotIndex>
        /// One-based district-local numbers left as purchasable vacant land.
        let vacantLocals: Set<Int>
        /// One-based district-local numbers used as surface parking lots.
        let parkingLocals: Set<Int>

        struct SlotIndex: Hashable {
            let column: Int
            let row: Int
        }

        func slotRect(column: Int, row: Int) -> GridRect {
            GridRect(
                origin: GridCoordinate(
                    column: origin.column + column * SuihamaCityMap.slotStride,
                    row: origin.row + row * SuihamaCityMap.slotStride
                ),
                size: SuihamaCityMap.parcelSize
            )
        }
    }

    /// Authoring order also fixes legacy plot ID assignment.
    static let districtBlocks: [DistrictBlock] = [
        DistrictBlock(
            district: .downtown,
            origin: GridCoordinate(column: 8, row: 32),
            slotColumns: 6,
            slotRows: 5,
            parkSlots: [.init(column: 2, row: 0), .init(column: 3, row: 0),
                        .init(column: 2, row: 1), .init(column: 3, row: 1)],
            vacantLocals: [5, 14, 22],
            parkingLocals: [9, 18]
        ),
        DistrictBlock(
            district: .station,
            origin: GridCoordinate(column: 56, row: 42),
            slotColumns: 3,
            slotRows: 3,
            parkSlots: [],
            vacantLocals: [3],
            parkingLocals: [7]
        ),
        DistrictBlock(
            district: .emerging,
            origin: GridCoordinate(column: 56, row: 2),
            slotColumns: 4,
            slotRows: 4,
            parkSlots: [.init(column: 1, row: 2)],
            vacantLocals: [4, 9],
            parkingLocals: [13]
        ),
        DistrictBlock(
            district: .suburb,
            origin: GridCoordinate(column: 2, row: 2),
            slotColumns: 8,
            slotRows: 5,
            parkSlots: [.init(column: 2, row: 1), .init(column: 5, row: 3)],
            vacantLocals: [6, 19, 31],
            parkingLocals: [11, 27]
        ),
        DistrictBlock(
            district: .industrial,
            origin: GridCoordinate(column: 46, row: 62),
            slotColumns: 4,
            slotRows: 5,
            parkSlots: [],
            vacantLocals: [8, 15],
            parkingLocals: [5, 12]
        ),
        DistrictBlock(
            district: .highway,
            origin: GridCoordinate(column: 2, row: 62),
            slotColumns: 8,
            slotRows: 5,
            parkSlots: [.init(column: 4, row: 2)],
            vacantLocals: [7, 21, 33],
            parkingLocals: [14, 28]
        )
    ]

    // MARK: - Map assembly

    private static func makeMap() -> GridCityMap {
        let roadClasses = makeRoadClasses()
        let roads = GridRoadNetwork.compile(roadClasses: roadClasses)
        let content = makeParcelsAndObjects()
        let map = GridCityMap(
            id: "suihama-coastal-v1",
            name: "翠浜市 湾岸シティマップ",
            size: mapSize,
            metrics: metrics,
            roads: roads,
            parcels: content.parcels,
            objects: content.objects,
            anchors: [
                .auction: GridCoordinate(column: 43, row: 84),
                .bank: GridCoordinate(column: 39, row: 44),
                .realEstate: GridCoordinate(column: 43, row: 12),
                .workshop: GridCoordinate(column: 66, row: 70),
                .advertising: GridCoordinate(column: 57, row: 40),
                .recruiting: GridCoordinate(column: 76, row: 21),
                .cityHall: GridCoordinate(column: 20, row: 34)
            ],
            terrain: makeTerrain(roadClasses: roadClasses)
        )
        let issues = GridMapValidator.validate(map)
        precondition(
            issues.isEmpty,
            "Suihama map must satisfy the shared grid rules:\n\(issues.map(\.description).joined(separator: "\n"))"
        )
        return map
    }

    // MARK: - Roads

    private static func makeRoadClasses() -> [GridCoordinate: GridRoadClass] {
        var result: [GridCoordinate: GridRoadClass] = [:]

        func addHorizontal(row: Int, columns: ClosedRange<Int>, _ roadClass: GridRoadClass) {
            for column in columns where mapSize.contains(.init(column: column, row: row)) {
                result[.init(column: column, row: row)] = roadClass
            }
        }

        func addVertical(column: Int, rows: ClosedRange<Int>, _ roadClass: GridRoadClass) {
            for row in rows where mapSize.contains(.init(column: column, row: row)) {
                result[.init(column: column, row: row)] = roadClass
            }
        }

        // District local streets (parcel stride: 4 cells + 1 road).
        for column in [6, 11, 16, 21, 26, 31, 36, 41] {  // suburb
            addVertical(column: column, rows: 2...27, .local)
        }
        for row in [6, 11, 16, 21, 26] {
            addHorizontal(row: row, columns: 2...43, .local)
        }
        for column in [60, 65, 70, 75] {  // emerging hills
            addVertical(column: column, rows: 2...27, .local)
        }
        for row in [6, 11, 16, 21] {
            addHorizontal(row: row, columns: 54...75, .local)
        }
        for column in [12, 17, 22, 27, 32, 37] {  // downtown
            addVertical(column: column, rows: 30...57, .local)
        }
        for row in [36, 41, 46, 51] {
            addHorizontal(row: row, columns: 8...43, .local)
        }
        for column in [60, 65] {  // station quarter
            addVertical(column: column, rows: 42...57, .local)
        }
        for row in [46, 51] {
            addHorizontal(row: row, columns: 54...69, .local)
        }
        addVertical(column: 70, rows: 42...57, .local)  // shore drive
        for column in [50, 55, 60, 65] {  // industrial port
            addVertical(column: column, rows: 60...87, .local)
        }
        for row in [66, 71, 76, 81, 86] {
            addHorizontal(row: row, columns: 44...65, .local)
        }
        for column in [6, 11, 16, 21, 26, 31, 36, 41] {  // roadside strip
            addVertical(column: column, rows: 60...87, .local)
        }
        for row in [66, 71, 76, 81, 86] {
            addHorizontal(row: row, columns: 2...45, .local)
        }

        // Arterials overwrite locals at shared cells so junctions carry the
        // wider class.
        for row in [28, 29] {  // 中央大通り, bridges the river
            addHorizontal(row: row, columns: 0...77, .arterial)
        }
        for row in [58, 59] {  // 港南通り
            addHorizontal(row: row, columns: 0...69, .arterial)
        }
        for column in [44, 45] {  // 翠浜縦貫道
            addVertical(column: column, rows: 0...89, .arterial)
        }
        for column in [52, 53] {  // 駅前大通り, bridges the river bend
            addVertical(column: column, rows: 28...59, .arterial)
        }

        // Bay-shore expressway: land viaduct in the west, sea bridge in the
        // east.
        for row in [88, 89] {
            addHorizontal(row: row, columns: 0...99, .expressway)
        }
        return result
    }

    // MARK: - Terrain

    private static func makeTerrain(
        roadClasses: [GridCoordinate: GridRoadClass]
    ) -> [GridCoordinate: GridTerrainFeature] {
        var result: [GridCoordinate: GridTerrainFeature] = [:]

        func fill(
            columns: ClosedRange<Int>,
            rows: ClosedRange<Int>,
            _ feature: GridTerrainFeature
        ) {
            for row in rows {
                for column in columns {
                    let coordinate = GridCoordinate(column: column, row: row)
                    guard mapSize.contains(coordinate) else { continue }
                    // Lanes may pass through a park band; pavement keeps the
                    // cell, scenery fills the rest.
                    guard feature == .water || roadClasses[coordinate] == nil else { continue }
                    result[coordinate] = feature
                }
            }
        }

        // Riverside greens.
        fill(columns: 46...47, rows: 0...35, .park)
        fill(columns: 50...51, rows: 0...33, .park)
        fill(columns: 50...79, rows: 34...35, .park)
        fill(columns: 50...79, rows: 38...39, .park)

        // Central park inside the downtown grid and the green fingers that
        // link it to the riverside.
        fill(columns: 18...26, rows: 32...40, .park)
        fill(columns: 38...43, rows: 30...57, .park)

        // Hillside esplanade above the beach.
        fill(columns: 76...83, rows: 2...19, .park)
        fill(columns: 76...77, rows: 20...27, .park)

        // Pocket parks carved out of the residential and roadside grids.
        fill(columns: 12...15, rows: 7...10, .park)
        fill(columns: 27...30, rows: 17...20, .park)
        fill(columns: 61...64, rows: 12...15, .park)
        fill(columns: 22...25, rows: 72...75, .park)

        // Southern green belt in front of the expressway.
        fill(columns: 0...65, rows: 90...92, .park)

        // Civic paving.
        fill(columns: 54...69, rows: 40...41, .plaza)
        fill(columns: 66...67, rows: 62...79, .plaza)

        // Sand follows the northern and station shorelines.
        fill(columns: 84...85, rows: 0...19, .beach)
        fill(columns: 78...79, rows: 20...39, .beach)
        fill(columns: 71...71, rows: 40...59, .beach)

        // Bay and river last: water legitimately passes under bridge decks,
        // and must win over any scenery authored into the same cell.
        for row in 0..<mapSize.rows {
            for column in 0..<mapSize.columns {
                let coordinate = GridCoordinate(column: column, row: row)
                if isWater(coordinate) { result[coordinate] = .water }
            }
        }
        return result
    }

    // MARK: - Parcels and ambient buildings

    private static func makeParcelsAndObjects() -> (
        parcels: [GridParcel],
        objects: [GridPlacedObject]
    ) {
        var parcels: [GridParcel] = []
        var objects: [GridPlacedObject] = []
        var nextPlotID = 0

        for (districtIndex, block) in districtBlocks.enumerated() {
            let districtAssets = CityAssetCatalog.ambientAssets(for: block.district)
            var localNumber = 0
            for slotRow in 0..<block.slotRows {
                for slotColumn in 0..<block.slotColumns {
                    let slot = DistrictBlock.SlotIndex(column: slotColumn, row: slotRow)
                    guard !block.parkSlots.contains(slot) else { continue }
                    localNumber += 1
                    let plotID = nextPlotID
                    nextPlotID += 1

                    let rect = block.slotRect(column: slotColumn, row: slotRow)
                    let facing: CardinalDirection = slotColumn == 0
                        ? .east
                        : ((slotColumn + slotRow).isMultiple(of: 2) ? .east : .west)
                    let isVacant = block.vacantLocals.contains(localNumber)
                    let isParking = block.parkingLocals.contains(localNumber)
                    let objectID = isVacant ? nil : "object-\(plotID)"
                    let parcelID = "parcel-\(plotID)"

                    parcels.append(GridParcel(
                        id: parcelID,
                        legacyPlotID: plotID,
                        rect: rect,
                        district: block.district,
                        areaSquareMeters: 420,
                        ownership: .market,
                        isPurchasable: true,
                        isBuildable: true,
                        roadAccess: [facing],
                        currentBuildingID: isParking ? nil : objectID,
                        price: basePrice(for: block.district, plotID: plotID)
                    ))

                    guard let objectID else { continue }
                    let paletteIndex = (slotColumn + slotRow * 3 + districtIndex)
                        % districtAssets.count
                    let asset = isParking
                        ? CityAssetCatalog.definition(for: .surfaceParking)
                        : districtAssets[paletteIndex]
                    let footprint = asset.footprint(facing: facing)
                    let objectRect = GridRect(
                        origin: GridCoordinate(
                            column: rect.minColumn + (rect.size.width - footprint.width) / 2,
                            row: rect.minRow + (rect.size.depth - footprint.depth) / 2
                        ),
                        size: footprint
                    )
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
                            : asset.nominalHeight
                                + Float((localNumber + districtIndex) % 3) * heightStep
                    ))
                }
            }
        }
        return (parcels, objects)
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

    private static func basePrice(for district: DistrictKind, plotID: Int) -> Int {
        let base: Int
        switch district {
        case .downtown: base = 14_000
        case .station: base = 9_500
        case .emerging: base = 6_200
        case .suburb: base = 7_000
        case .industrial: base = 3_800
        case .highway: base = 4_700
        }
        return base * (88 + ((plotID * 17) % 27)) / 100
    }
}

/// Production entry point for authored city geometry and gameplay parcels.
enum CityMapDefinition {
    static let suihama = SuihamaCityMap.shared
}
