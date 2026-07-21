import Foundation

struct GridCoordinate: Hashable, Codable, Sendable, Comparable {
    let column: Int
    let row: Int

    static func < (lhs: GridCoordinate, rhs: GridCoordinate) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }

    func neighbor(in direction: CardinalDirection) -> GridCoordinate {
        GridCoordinate(column: column + direction.columnDelta, row: row + direction.rowDelta)
    }
}

struct GridSize: Hashable, Codable, Sendable {
    let width: Int
    let depth: Int

    var isValid: Bool { width > 0 && depth > 0 }

    static let oneByOne = GridSize(width: 1, depth: 1)
    static let oneByTwo = GridSize(width: 1, depth: 2)
    static let twoByTwo = GridSize(width: 2, depth: 2)
    static let twoByThree = GridSize(width: 2, depth: 3)
    static let threeByThree = GridSize(width: 3, depth: 3)
    static let fourByFour = GridSize(width: 4, depth: 4)
}

struct GridRect: Hashable, Codable, Sendable {
    let origin: GridCoordinate
    let size: GridSize

    var minColumn: Int { origin.column }
    var minRow: Int { origin.row }
    var maxColumnExclusive: Int { origin.column + size.width }
    var maxRowExclusive: Int { origin.row + size.depth }

    var cells: [GridCoordinate] {
        guard size.isValid else { return [] }
        return (minRow..<maxRowExclusive).flatMap { row in
            (minColumn..<maxColumnExclusive).map { column in
                GridCoordinate(column: column, row: row)
            }
        }
    }

    func contains(_ coordinate: GridCoordinate) -> Bool {
        coordinate.column >= minColumn && coordinate.column < maxColumnExclusive
            && coordinate.row >= minRow && coordinate.row < maxRowExclusive
    }

    func contains(_ other: GridRect) -> Bool {
        other.size.isValid
            && other.minColumn >= minColumn
            && other.maxColumnExclusive <= maxColumnExclusive
            && other.minRow >= minRow
            && other.maxRowExclusive <= maxRowExclusive
    }

    func intersects(_ other: GridRect) -> Bool {
        minColumn < other.maxColumnExclusive
            && maxColumnExclusive > other.minColumn
            && minRow < other.maxRowExclusive
            && maxRowExclusive > other.minRow
    }

    func edgeCells(for direction: CardinalDirection) -> [GridCoordinate] {
        guard size.isValid else { return [] }
        switch direction {
        case .north:
            return (minColumn..<maxColumnExclusive).map { GridCoordinate(column: $0, row: minRow) }
        case .east:
            return (minRow..<maxRowExclusive).map { GridCoordinate(column: maxColumnExclusive - 1, row: $0) }
        case .south:
            return (minColumn..<maxColumnExclusive).map { GridCoordinate(column: $0, row: maxRowExclusive - 1) }
        case .west:
            return (minRow..<maxRowExclusive).map { GridCoordinate(column: minColumn, row: $0) }
        }
    }
}

struct GridMapSize: Hashable, Codable, Sendable {
    let columns: Int
    let rows: Int

    var isValid: Bool { columns > 0 && rows > 0 }

    func contains(_ coordinate: GridCoordinate) -> Bool {
        coordinate.column >= 0 && coordinate.column < columns
            && coordinate.row >= 0 && coordinate.row < rows
    }

    func contains(_ rect: GridRect) -> Bool {
        rect.size.isValid
            && rect.minColumn >= 0
            && rect.minRow >= 0
            && rect.maxColumnExclusive <= columns
            && rect.maxRowExclusive <= rows
    }
}

enum CardinalDirection: String, Codable, CaseIterable, Sendable {
    case north
    case east
    case south
    case west

    var columnDelta: Int {
        switch self {
        case .east: 1
        case .west: -1
        case .north, .south: 0
        }
    }

    var rowDelta: Int {
        switch self {
        case .south: 1
        case .north: -1
        case .east, .west: 0
        }
    }

    var opposite: CardinalDirection {
        switch self {
        case .north: .south
        case .east: .west
        case .south: .north
        case .west: .east
        }
    }
}

struct RoadConnections: OptionSet, Hashable, Codable, Sendable {
    let rawValue: UInt8

    static let north = RoadConnections(rawValue: 1 << 0)
    static let east = RoadConnections(rawValue: 1 << 1)
    static let south = RoadConnections(rawValue: 1 << 2)
    static let west = RoadConnections(rawValue: 1 << 3)

    static let all: RoadConnections = [.north, .east, .south, .west]

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    init(directions: some Sequence<CardinalDirection>) {
        self = directions.reduce(into: RoadConnections()) { result, direction in
            result.insert(direction.connection)
        }
    }

    var directions: [CardinalDirection] {
        CardinalDirection.allCases.filter { contains($0.connection) }
    }
}

extension CardinalDirection {
    var connection: RoadConnections {
        switch self {
        case .north: .north
        case .east: .east
        case .south: .south
        case .west: .west
        }
    }
}

enum RoadTileShape: String, Codable, CaseIterable, Sendable {
    case isolated
    case end
    case straight
    case corner
    case tee
    case cross
}

enum GridRoadClass: String, Codable, CaseIterable, Sendable {
    case local
    case arterial
    case expressway

    func pavementWidth(cellSize: Float) -> Float {
        switch self {
        case .local: cellSize * 0.60
        case .arterial: cellSize * 0.90
        case .expressway: cellSize * 0.94
        }
    }

    func sidewalkWidth(cellSize: Float) -> Float {
        switch self {
        case .expressway:
            // A grade-separated corridor has shoulders instead of sidewalks.
            return pavementWidth(cellSize: cellSize)
        case .local, .arterial:
            return min(cellSize, pavementWidth(cellSize: cellSize) + cellSize * 0.20)
        }
    }
}

struct GridRoadCell: Hashable, Codable, Sendable {
    let coordinate: GridCoordinate
    let roadClass: GridRoadClass
    let connections: RoadConnections

    var tileShape: RoadTileShape {
        switch connections.directions.count {
        case 0: return .isolated
        case 1: return .end
        case 2:
            if connections == [.north, .south] || connections == [.east, .west] {
                return .straight
            }
            return .corner
        case 3: return .tee
        default: return .cross
        }
    }
}

enum GridRoadNetwork {
    static func compile(
        roadClasses: [GridCoordinate: GridRoadClass]
    ) -> [GridCoordinate: GridRoadCell] {
        roadClasses.reduce(into: [:]) { result, entry in
            let directions = CardinalDirection.allCases.filter {
                roadClasses[entry.key.neighbor(in: $0)] != nil
            }
            result[entry.key] = GridRoadCell(
                coordinate: entry.key,
                roadClass: entry.value,
                connections: RoadConnections(directions: directions)
            )
        }
    }
}

struct GridLocalSurfaceRect: Hashable, Sendable {
    let centerX: Float
    let centerZ: Float
    let width: Float
    let depth: Float

    var minX: Float { centerX - width / 2 }
    var maxX: Float { centerX + width / 2 }
    var minZ: Float { centerZ - depth / 2 }
    var maxZ: Float { centerZ + depth / 2 }
}

enum GridRoadSurfaceLayout {
    /// Produces one center pad and exact edge-reaching arms. Adjacent cells use
    /// the same cell boundary, preventing cumulative floating-point seams.
    static func pieces(
        connections: RoadConnections,
        cellSize: Float,
        surfaceWidth: Float,
        connectionWidths: [CardinalDirection: Float] = [:]
    ) -> [GridLocalSurfaceRect] {
        guard cellSize > 0, surfaceWidth > 0, surfaceWidth <= cellSize else { return [] }
        var result = [GridLocalSurfaceRect(
            centerX: 0,
            centerZ: 0,
            width: surfaceWidth,
            depth: surfaceWidth
        )]
        let armLength = (cellSize - surfaceWidth) / 2
        guard armLength > 0 else { return result }
        let armOffset = surfaceWidth / 2 + armLength / 2

        for direction in connections.directions {
            let connectionWidth = min(
                surfaceWidth,
                max(0, connectionWidths[direction] ?? surfaceWidth)
            )
            guard connectionWidth > 0 else { continue }
            switch direction {
            case .north:
                result.append(.init(centerX: 0, centerZ: -armOffset, width: connectionWidth, depth: armLength))
            case .east:
                result.append(.init(centerX: armOffset, centerZ: 0, width: armLength, depth: connectionWidth))
            case .south:
                result.append(.init(centerX: 0, centerZ: armOffset, width: connectionWidth, depth: armLength))
            case .west:
                result.append(.init(centerX: -armOffset, centerZ: 0, width: armLength, depth: connectionWidth))
            }
        }
        return result
    }

    /// Both sides of a class transition use the narrower edge width. The
    /// wider road keeps its authored center width but narrows before the shared
    /// cell boundary, so local/arterial joins cannot leave a shoulder gap.
    static func pieces(
        for road: GridRoadCell,
        in network: [GridCoordinate: GridRoadCell],
        cellSize: Float,
        isSidewalk: Bool
    ) -> [GridLocalSurfaceRect] {
        let width: (GridRoadClass) -> Float = { roadClass in
            isSidewalk
                ? roadClass.sidewalkWidth(cellSize: cellSize)
                : roadClass.pavementWidth(cellSize: cellSize)
        }
        let surfaceWidth = width(road.roadClass)
        let connectionWidths: [CardinalDirection: Float] = road.connections.directions.reduce(into: [:]) {
            result, direction in
            guard let neighbor = network[road.coordinate.neighbor(in: direction)] else { return }
            result[direction] = min(surfaceWidth, width(neighbor.roadClass))
        }
        return pieces(
            connections: road.connections,
            cellSize: cellSize,
            surfaceWidth: surfaceWidth,
            connectionWidths: connectionWidths
        )
    }
}

struct GridWorldPoint: Hashable, Sendable {
    let x: Float
    let z: Float
}

struct GridWorldBounds: Hashable, Sendable {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float

    var width: Float { maxX - minX }
    var depth: Float { maxZ - minZ }
    var center: GridWorldPoint { GridWorldPoint(x: (minX + maxX) / 2, z: (minZ + maxZ) / 2) }
}

struct GridMetrics: Hashable, Codable, Sendable {
    let cellSize: Float

    func worldCenter(of coordinate: GridCoordinate, mapSize: GridMapSize) -> GridWorldPoint {
        let halfWidth = Float(mapSize.columns) * cellSize / 2
        let halfDepth = Float(mapSize.rows) * cellSize / 2
        return GridWorldPoint(
            x: (Float(coordinate.column) + 0.5) * cellSize - halfWidth,
            z: (Float(coordinate.row) + 0.5) * cellSize - halfDepth
        )
    }

    func worldBounds(of rect: GridRect, mapSize: GridMapSize) -> GridWorldBounds {
        let halfWidth = Float(mapSize.columns) * cellSize / 2
        let halfDepth = Float(mapSize.rows) * cellSize / 2
        return GridWorldBounds(
            minX: Float(rect.minColumn) * cellSize - halfWidth,
            maxX: Float(rect.maxColumnExclusive) * cellSize - halfWidth,
            minZ: Float(rect.minRow) * cellSize - halfDepth,
            maxZ: Float(rect.maxRowExclusive) * cellSize - halfDepth
        )
    }

    func worldBounds(of mapSize: GridMapSize) -> GridWorldBounds {
        worldBounds(
            of: GridRect(
                origin: GridCoordinate(column: 0, row: 0),
                size: GridSize(width: mapSize.columns, depth: mapSize.rows)
            ),
            mapSize: mapSize
        )
    }

    func gridCoordinate(at worldPoint: GridWorldPoint, mapSize: GridMapSize) -> GridCoordinate? {
        guard cellSize > 0 else { return nil }
        let halfWidth = Float(mapSize.columns) * cellSize / 2
        let halfDepth = Float(mapSize.rows) * cellSize / 2
        let coordinate = GridCoordinate(
            column: Int(floor((worldPoint.x + halfWidth) / cellSize)),
            row: Int(floor((worldPoint.z + halfDepth) / cellSize))
        )
        return mapSize.contains(coordinate) ? coordinate : nil
    }
}

struct GridCameraOffset: Hashable, Sendable {
    let x: Float
    let y: Float
    let z: Float
}

/// The view angle is authored once for the whole city. Zoom changes only the
/// orthographic scale, never the camera angle or any world-space placement.
struct GridOrthographicCameraSpec: Hashable, Sendable {
    let azimuthDegrees: Float
    let elevationDegrees: Float
    let zoomScaleFactors: [Float]

    static let foundation = GridOrthographicCameraSpec(
        azimuthDegrees: 45,
        // True isometric elevation. Combined with the 45 degree azimuth this
        // keeps both ground axes at the same on-screen scale as the artwork
        // reference, at every zoom level.
        elevationDegrees: 35.26439,
        // The former roughly 400% view (0.22) remains the 100% baseline.
        // Wider overview steps sit before it, while closer inspection steps
        // continue through 700% without changing the camera angle.
        zoomScaleFactors: [
            0.88,
            0.44,
            0.2933333,
            0.22,
            0.11,
            0.0733333,
            0.055,
            0.044,
            0.0366667,
            0.0314286
        ]
    )

    func cameraOffset(groundDistance: Float) -> GridCameraOffset {
        let azimuth = azimuthDegrees * .pi / 180
        let elevation = elevationDegrees * .pi / 180
        return GridCameraOffset(
            x: cos(azimuth) * groundDistance,
            y: tan(elevation) * groundDistance,
            z: sin(azimuth) * groundDistance
        )
    }

    func orthographicScale(baseScale: Float, zoomStep: Int) -> Float {
        guard !zoomScaleFactors.isEmpty else { return baseScale }
        let step = min(zoomScaleFactors.count - 1, max(0, zoomStep))
        return baseScale * zoomScaleFactors[step]
    }
}

enum GridCameraFocusPolicy {
    /// At the fit-to-bounds level the focus is locked to the bounds center. Each
    /// closer zoom level releases a proportional amount of pan range while
    /// keeping the focus inside those bounds, preventing a blank-screen pan.
    static func clampedFocus(
        _ requested: GridWorldPoint,
        in bounds: GridWorldBounds,
        zoomFactor: Float
    ) -> GridWorldPoint {
        let visibleFraction = min(1, max(0, zoomFactor))
        let insetX = bounds.width * visibleFraction / 2
        let insetZ = bounds.depth * visibleFraction / 2
        let minimumX = bounds.minX + insetX
        let maximumX = bounds.maxX - insetX
        let minimumZ = bounds.minZ + insetZ
        let maximumZ = bounds.maxZ - insetZ
        return GridWorldPoint(
            x: min(maximumX, max(minimumX, requested.x)),
            z: min(maximumZ, max(minimumZ, requested.z))
        )
    }
}

enum GridSceneElevation {
    static let groundSurface: Float = 0
    static let parcelSurface: Float = 0.40
    static let sidewalkSurface: Float = 0.45
    static let pavementSurface: Float = 0.50
    static let assetBase: Float = parcelSurface
    static let debugOverlay: Float = 0.62
}

enum GridParcelOwnership: String, Codable, Sendable {
    case market
    case player
    case competitor
    case municipal
    case unavailable
}

enum GridObjectKind: String, Codable, Sendable {
    case building
    case parking
}

enum GridBuildingStyle: String, Codable, Sendable {
    case generalResidential
    case luxuryResidential
    case commercial
    case industrial
    case downtown
    case roadside
    case parking
}

struct GridPlacedObject: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let parcelID: String
    let rect: GridRect
    let kind: GridObjectKind
    let style: GridBuildingStyle
    let assetID: CityAssetID
    let facing: CardinalDirection
    let height: Float
}

struct GridParcel: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let legacyPlotID: Int?
    let rect: GridRect
    let district: DistrictKind
    let areaSquareMeters: Int
    var ownership: GridParcelOwnership
    var isPurchasable: Bool
    var isBuildable: Bool
    let roadAccess: Set<CardinalDirection>
    var currentBuildingID: String?
    var price: Int?

    var isVacant: Bool { currentBuildingID == nil }
}

enum GridMapAnchorID: String, Hashable, Codable, Sendable, CaseIterable {
    case auction
    case bank
    case realEstate
    case workshop
    case advertising
    case recruiting
    case cityHall
}

/// Scenery-only ground cover. Terrain never hosts parcels or objects; the
/// only permitted overlap is a road crossing water, which renders as a bridge.
enum GridTerrainFeature: String, Codable, Sendable {
    case water
    case beach
    case park
    case plaza
}

struct GridCityMap: Hashable, Codable, Sendable {
    /// The authored city footprint used by the camera, excluding scenery-only
    /// map apron. A small gutter keeps edge parcels clear of the viewport.
    var cameraContentBounds: GridWorldBounds {
        let mapBounds = metrics.worldBounds(of: size)
        guard let firstParcel = parcels.first else { return mapBounds }

        var contentBounds = metrics.worldBounds(of: firstParcel.rect, mapSize: size)
        for parcel in parcels.dropFirst() {
            let parcelBounds = metrics.worldBounds(of: parcel.rect, mapSize: size)
            contentBounds = GridWorldBounds(
                minX: min(contentBounds.minX, parcelBounds.minX),
                maxX: max(contentBounds.maxX, parcelBounds.maxX),
                minZ: min(contentBounds.minZ, parcelBounds.minZ),
                maxZ: max(contentBounds.maxZ, parcelBounds.maxZ)
            )
        }

        let padding = metrics.cellSize * 2
        return GridWorldBounds(
            minX: max(mapBounds.minX, contentBounds.minX - padding),
            maxX: min(mapBounds.maxX, contentBounds.maxX + padding),
            minZ: max(mapBounds.minZ, contentBounds.minZ - padding),
            maxZ: min(mapBounds.maxZ, contentBounds.maxZ + padding)
        )
    }

    let id: String
    let name: String
    let size: GridMapSize
    let metrics: GridMetrics
    let roads: [GridCoordinate: GridRoadCell]
    let parcels: [GridParcel]
    let objects: [GridPlacedObject]
    let anchors: [GridMapAnchorID: GridCoordinate]
    let terrain: [GridCoordinate: GridTerrainFeature]

    init(
        id: String,
        name: String,
        size: GridMapSize,
        metrics: GridMetrics,
        roads: [GridCoordinate: GridRoadCell],
        parcels: [GridParcel],
        objects: [GridPlacedObject],
        anchors: [GridMapAnchorID: GridCoordinate],
        terrain: [GridCoordinate: GridTerrainFeature] = [:]
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.metrics = metrics
        self.roads = roads
        self.parcels = parcels
        self.objects = objects
        self.anchors = anchors
        self.terrain = terrain
    }

    func road(at coordinate: GridCoordinate) -> GridRoadCell? { roads[coordinate] }

    func terrainFeature(at coordinate: GridCoordinate) -> GridTerrainFeature? {
        terrain[coordinate]
    }

    func parcel(id: String) -> GridParcel? { parcels.first(where: { $0.id == id }) }

    func parcel(legacyPlotID: Int) -> GridParcel? {
        parcels.first(where: { $0.legacyPlotID == legacyPlotID })
    }

    func parcel(at coordinate: GridCoordinate) -> GridParcel? {
        parcels.first(where: { $0.rect.contains(coordinate) })
    }

    func object(id: String) -> GridPlacedObject? { objects.first(where: { $0.id == id }) }

    func coordinate(for anchorID: GridMapAnchorID) -> GridCoordinate? {
        anchors[anchorID]
    }

    func worldCenter(of district: DistrictKind) -> GridWorldPoint? {
        let districtParcels = parcels.filter { $0.district == district }
        guard let first = districtParcels.first else { return nil }
        var bounds = metrics.worldBounds(of: first.rect, mapSize: size)
        for parcel in districtParcels.dropFirst() {
            let parcelBounds = metrics.worldBounds(of: parcel.rect, mapSize: size)
            bounds = GridWorldBounds(
                minX: min(bounds.minX, parcelBounds.minX),
                maxX: max(bounds.maxX, parcelBounds.maxX),
                minZ: min(bounds.minZ, parcelBounds.minZ),
                maxZ: max(bounds.maxZ, parcelBounds.maxZ)
            )
        }
        return bounds.center
    }

    func actualRoadAccess(for parcel: GridParcel) -> Set<CardinalDirection> {
        Set(CardinalDirection.allCases.filter { direction in
            parcel.rect.edgeCells(for: direction).contains { edgeCell in
                roads[edgeCell.neighbor(in: direction)] != nil
            }
        })
    }

    func usableRoadAccess(for parcel: GridParcel) -> Set<CardinalDirection> {
        actualRoadAccess(for: parcel).intersection(parcel.roadAccess)
    }

    func isParcelVacant(_ parcelID: String, ignoringObjectID: String? = nil) -> Bool {
        !objects.contains { object in
            object.parcelID == parcelID && object.id != ignoringObjectID
        }
    }

    /// Returns the next parcel across a continuous road band. This makes the
    /// authored grid map, rather than the legacy screen-space blueprint, the
    /// authority for multi-parcel store expansion.
    func neighboringParcel(
        of parcel: GridParcel,
        in direction: CardinalDirection
    ) -> GridParcel? {
        let candidates = parcels.filter { candidate in
            guard candidate.id != parcel.id, candidate.district == parcel.district else { return false }
            switch direction {
            case .north:
                return candidate.rect.minColumn == parcel.rect.minColumn
                    && candidate.rect.maxColumnExclusive == parcel.rect.maxColumnExclusive
                    && candidate.rect.maxRowExclusive < parcel.rect.minRow
            case .east:
                return candidate.rect.minRow == parcel.rect.minRow
                    && candidate.rect.maxRowExclusive == parcel.rect.maxRowExclusive
                    && candidate.rect.minColumn > parcel.rect.maxColumnExclusive
            case .south:
                return candidate.rect.minColumn == parcel.rect.minColumn
                    && candidate.rect.maxColumnExclusive == parcel.rect.maxColumnExclusive
                    && candidate.rect.minRow > parcel.rect.maxRowExclusive
            case .west:
                return candidate.rect.minRow == parcel.rect.minRow
                    && candidate.rect.maxRowExclusive == parcel.rect.maxRowExclusive
                    && candidate.rect.maxColumnExclusive < parcel.rect.minColumn
            }
        }.sorted { lhs, rhs in
            parcelGap(from: parcel, to: lhs, direction: direction)
                < parcelGap(from: parcel, to: rhs, direction: direction)
        }

        return candidates.first { candidate in
            let corridor: GridRect
            switch direction {
            case .north:
                corridor = GridRect(
                    origin: GridCoordinate(column: parcel.rect.minColumn, row: candidate.rect.maxRowExclusive),
                    size: GridSize(
                        width: parcel.rect.size.width,
                        depth: parcel.rect.minRow - candidate.rect.maxRowExclusive
                    )
                )
            case .east:
                corridor = GridRect(
                    origin: GridCoordinate(column: parcel.rect.maxColumnExclusive, row: parcel.rect.minRow),
                    size: GridSize(
                        width: candidate.rect.minColumn - parcel.rect.maxColumnExclusive,
                        depth: parcel.rect.size.depth
                    )
                )
            case .south:
                corridor = GridRect(
                    origin: GridCoordinate(column: parcel.rect.minColumn, row: parcel.rect.maxRowExclusive),
                    size: GridSize(
                        width: parcel.rect.size.width,
                        depth: candidate.rect.minRow - parcel.rect.maxRowExclusive
                    )
                )
            case .west:
                corridor = GridRect(
                    origin: GridCoordinate(column: candidate.rect.maxColumnExclusive, row: parcel.rect.minRow),
                    size: GridSize(
                        width: parcel.rect.minColumn - candidate.rect.maxColumnExclusive,
                        depth: parcel.rect.size.depth
                    )
                )
            }
            return corridor.size.isValid && corridor.cells.allSatisfy { roads[$0] != nil }
        }
    }

    private func parcelGap(
        from parcel: GridParcel,
        to candidate: GridParcel,
        direction: CardinalDirection
    ) -> Int {
        switch direction {
        case .north: parcel.rect.minRow - candidate.rect.maxRowExclusive
        case .east: candidate.rect.minColumn - parcel.rect.maxColumnExclusive
        case .south: candidate.rect.minRow - parcel.rect.maxRowExclusive
        case .west: parcel.rect.minColumn - candidate.rect.maxColumnExclusive
        }
    }
}

enum GridPlacementFailure: Hashable, Sendable {
    case unknownParcel
    case unknownObject(String)
    case parcelIsNotBuildable
    case parcelIsOccupied(String)
    case parcelHasNoRoadAccess
    case outsideParcel
    case intersectsRoad(GridCoordinate)
    case overlapsObject(String)
    case assetNotAllowedInDistrict(CityAssetID, DistrictKind)
    case assetHasNoRoadConnection(CityAssetID)
    case invalidUpgradePath(CityAssetID, CityAssetID)
}

enum GridPlacementRules {
    private static func failures(
        placing rect: GridRect,
        in parcelID: String,
        map: GridCityMap,
        ignoringObjectIDs: Set<String>
    ) -> [GridPlacementFailure] {
        guard let parcel = map.parcel(id: parcelID) else { return [.unknownParcel] }
        var failures: [GridPlacementFailure] = []
        if !parcel.isBuildable { failures.append(.parcelIsNotBuildable) }
        if let object = map.objects.first(where: {
            $0.parcelID == parcelID && !ignoringObjectIDs.contains($0.id)
        }) {
            failures.append(.parcelIsOccupied(object.id))
        }
        if map.usableRoadAccess(for: parcel).isEmpty {
            failures.append(.parcelHasNoRoadAccess)
        }
        if !parcel.rect.contains(rect) { failures.append(.outsideParcel) }
        if let roadCell = rect.cells.first(where: { map.roads[$0] != nil }) {
            failures.append(.intersectsRoad(roadCell))
        }
        if let object = map.objects.first(where: {
            !ignoringObjectIDs.contains($0.id) && $0.rect.intersects(rect)
        }) {
            failures.append(.overlapsObject(object.id))
        }
        return failures
    }

    static func failures(
        placing rect: GridRect,
        in parcelID: String,
        map: GridCityMap,
        ignoringObjectID: String? = nil
    ) -> [GridPlacementFailure] {
        failures(
            placing: rect,
            in: parcelID,
            map: map,
            ignoringObjectIDs: Set([ignoringObjectID].compactMap { $0 })
        )
    }

    /// Integer division floors toward the parcel origin, so an odd
    /// width/depth difference lands half a cell off true center. Collision
    /// and road checks use this rect as-is; renderers place the visuals on
    /// the true parcel center to close that half cell.
    static func centeredRect(
        for assetID: CityAssetID,
        facing: CardinalDirection,
        in parcel: GridParcel
    ) -> GridRect {
        let footprint = CityAssetCatalog.definition(for: assetID).footprint(facing: facing)
        return GridRect(
            origin: GridCoordinate(
                column: parcel.rect.minColumn + (parcel.rect.size.width - footprint.width) / 2,
                row: parcel.rect.minRow + (parcel.rect.size.depth - footprint.depth) / 2
            ),
            size: footprint
        )
    }

    static func failures(
        placing assetID: CityAssetID,
        facing: CardinalDirection,
        in parcelID: String,
        map: GridCityMap,
        ignoringObjectID: String? = nil
    ) -> [GridPlacementFailure] {
        guard let parcel = map.parcel(id: parcelID) else { return [.unknownParcel] }
        let definition = CityAssetCatalog.definition(for: assetID)
        let rect = centeredRect(for: assetID, facing: facing, in: parcel)
        var result = failures(
            placing: rect,
            in: parcelID,
            map: map,
            ignoringObjectID: ignoringObjectID
        )
        if !definition.allowedDistricts.contains(parcel.district) {
            result.append(.assetNotAllowedInDistrict(assetID, parcel.district))
        }
        let usableAccess = map.usableRoadAccess(for: parcel)
        if definition.roadConnections(facing: facing).isDisjoint(with: usableAccess) {
            result.append(.assetHasNoRoadConnection(assetID))
        }
        return result
    }

    static func failures(
        placing assetID: CityAssetID,
        facing: CardinalDirection,
        in parcelID: String,
        map: GridCityMap,
        ignoringObjectIDs: Set<String>
    ) -> [GridPlacementFailure] {
        guard let parcel = map.parcel(id: parcelID) else { return [.unknownParcel] }
        let definition = CityAssetCatalog.definition(for: assetID)
        let rect = centeredRect(for: assetID, facing: facing, in: parcel)
        var result = failures(
            placing: rect,
            in: parcelID,
            map: map,
            ignoringObjectIDs: ignoringObjectIDs
        )
        if !definition.allowedDistricts.contains(parcel.district) {
            result.append(.assetNotAllowedInDistrict(assetID, parcel.district))
        }
        let usableAccess = map.usableRoadAccess(for: parcel)
        if definition.roadConnections(facing: facing).isDisjoint(with: usableAccess) {
            result.append(.assetHasNoRoadConnection(assetID))
        }
        return result
    }

    static func failures(
        upgrading objectID: String,
        to assetID: CityAssetID,
        facing: CardinalDirection,
        map: GridCityMap
    ) -> [GridPlacementFailure] {
        guard let object = map.object(id: objectID) else { return [.unknownObject(objectID)] }
        let current = CityAssetCatalog.definition(for: object.assetID)
        guard current.upgradeTo == assetID else {
            return [.invalidUpgradePath(object.assetID, assetID)]
        }
        return failures(
            placing: assetID,
            facing: facing,
            in: object.parcelID,
            map: map,
            ignoringObjectID: objectID
        )
    }

    static func canPlace(
        _ rect: GridRect,
        in parcelID: String,
        map: GridCityMap,
        ignoringObjectID: String? = nil
    ) -> Bool {
        failures(
            placing: rect,
            in: parcelID,
            map: map,
            ignoringObjectID: ignoringObjectID
        ).isEmpty
    }

    static func canPlace(
        _ assetID: CityAssetID,
        facing: CardinalDirection,
        in parcelID: String,
        map: GridCityMap,
        ignoringObjectID: String? = nil
    ) -> Bool {
        failures(
            placing: assetID,
            facing: facing,
            in: parcelID,
            map: map,
            ignoringObjectID: ignoringObjectID
        ).isEmpty
    }
}

enum GridStoreParcelRole: Hashable, Sendable {
    case primaryBuilding
    case displayParking
}

struct GridStoreParcelPlacement: Hashable, Sendable {
    let plotID: Int
    let parcelID: String
    let role: GridStoreParcelRole
    let assetID: CityAssetID
    let facing: CardinalDirection
    let rect: GridRect
    let height: Float
}

enum GridStoreOccupancyIssue: Hashable, Sendable, CustomStringConvertible {
    case duplicatePlotClaim(Int, UUID, UUID)
    case missingPlot(UUID, Int)
    case missingParcel(UUID, Int)
    case occupantMismatch(UUID, Int)
    case orphanedPlayerOccupant(Int, UUID)
    case invalidFootprint(UUID)
    case missingVisualPlacement(UUID, Int)

    var description: String {
        switch self {
        case .duplicatePlotClaim(let plotID, let first, let second):
            "Plot \(plotID) is claimed by stores \(first) and \(second)"
        case .missingPlot(let storeID, let plotID):
            "Store \(storeID) references missing plot \(plotID)"
        case .missingParcel(let storeID, let plotID):
            "Store \(storeID) plot \(plotID) has no grid parcel"
        case .occupantMismatch(let storeID, let plotID):
            "Store \(storeID) does not own plot \(plotID) in runtime occupancy"
        case .orphanedPlayerOccupant(let plotID, let storeID):
            "Plot \(plotID) references missing or unrelated store \(storeID)"
        case .invalidFootprint(let storeID):
            "Store \(storeID) plot IDs do not form its required grid footprint"
        case .missingVisualPlacement(let storeID, let plotID):
            "Store \(storeID) plot \(plotID) has no valid visual placement"
        }
    }
}

/// Bridges gameplay LandPlot occupancy to the modular 3D grid. Every build,
/// renovation and renderer placement uses the same parcel adjacency, district,
/// road-access and asset-fit rules from GridCityMap.
enum GridStorePlacementAdapter {
    static func footprintPlots(
        startingAt plot: LandPlot,
        type: StoreType,
        plots: [LandPlot],
        map: GridCityMap,
        acquisitionMode: AcquisitionMode? = nil,
        occupiedBy storeID: UUID? = nil,
        requiredExistingIDs: Set<Int> = []
    ) -> [LandPlot] {
        guard let anchor = map.parcel(legacyPlotID: plot.id),
              anchor.district == plot.district else { return [] }

        let plotByID = Dictionary(uniqueKeysWithValues: plots.map { ($0.id, $0) })
        let patterns = offsetPatterns(cellCount: type.requiredGridCells)
        for pattern in patterns {
            let candidateParcels = pattern.compactMap { offset in
                parcel(atColumnOffset: offset.column, rowOffset: offset.row, from: anchor, map: map)
            }
            guard candidateParcels.count == pattern.count,
                  Set(candidateParcels.map(\.id)).count == pattern.count else { continue }

            let candidatePlots = candidateParcels.compactMap { parcel in
                parcel.legacyPlotID.flatMap { plotByID[$0] }
            }
            guard candidatePlots.count == pattern.count,
                  candidatePlots.allSatisfy({ $0.district == plot.district && $0.development == nil }),
                  candidatePlots.allSatisfy({ isUsable($0, acquisitionMode: acquisitionMode, occupiedBy: storeID) }) else {
                continue
            }

            let candidateIDs = Set(candidatePlots.map(\.id))
            guard requiredExistingIDs.isSubset(of: candidateIDs) else { continue }
            let ignoredObjectIDs = Set(map.objects.compactMap { object in
                candidateParcels.contains(where: { $0.id == object.parcelID }) ? object.id : nil
            })
            guard visualPlacementIsValid(
                assetID: type.cityAssetID,
                parcel: anchor,
                map: map,
                ignoringObjectIDs: ignoredObjectIDs
            ) else { continue }
            guard candidateParcels.filter({ $0.id != anchor.id }).allSatisfy({ parcel in
                visualPlacementIsValid(
                    assetID: .playerDisplayParking,
                    parcel: parcel,
                    map: map,
                    ignoringObjectIDs: ignoredObjectIDs
                )
            }) else { continue }

            return candidatePlots.sorted { lhs, rhs in
                guard let lhsParcel = map.parcel(legacyPlotID: lhs.id),
                      let rhsParcel = map.parcel(legacyPlotID: rhs.id) else { return lhs.id < rhs.id }
                if lhsParcel.rect.minRow != rhsParcel.rect.minRow { return lhsParcel.rect.minRow < rhsParcel.rect.minRow }
                return lhsParcel.rect.minColumn < rhsParcel.rect.minColumn
            }
        }
        return []
    }

    static func visualPlacements(
        for store: Store,
        map: GridCityMap
    ) -> [GridStoreParcelPlacement] {
        let orderedPlotIDs = [store.plotID] + store.plotIDs.filter { $0 != store.plotID }
        return orderedPlotIDs.compactMap { plotID in
            guard let parcel = map.parcel(legacyPlotID: plotID) else { return nil }
            let isPrimary = plotID == store.plotID
            let assetID: CityAssetID = isPrimary ? store.type.cityAssetID : .playerDisplayParking
            let definition = CityAssetCatalog.definition(for: assetID)
            guard definition.allowedDistricts.contains(parcel.district),
                  let facing = facingDirection(for: assetID, parcel: parcel, map: map) else { return nil }
            let rect = GridPlacementRules.centeredRect(for: assetID, facing: facing, in: parcel)
            guard parcel.rect.contains(rect),
                  !rect.cells.contains(where: { map.roads[$0] != nil }) else { return nil }
            return GridStoreParcelPlacement(
                plotID: plotID,
                parcelID: parcel.id,
                role: isPrimary ? .primaryBuilding : .displayParking,
                assetID: assetID,
                facing: facing,
                rect: rect,
                height: isPrimary
                    ? store.type.cityAssetHeight
                    : CityAssetCatalog.definition(for: assetID).nominalHeight
            )
        }
    }

    static func validate(
        plots: [LandPlot],
        stores: [Store],
        map: GridCityMap
    ) -> [GridStoreOccupancyIssue] {
        let plotByID = Dictionary(uniqueKeysWithValues: plots.map { ($0.id, $0) })
        let storeByID = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0) })
        var issues: [GridStoreOccupancyIssue] = []
        var claims: [Int: UUID] = [:]

        for store in stores {
            for plotID in store.plotIDs {
                if let existing = claims[plotID] {
                    issues.append(.duplicatePlotClaim(plotID, existing, store.id))
                } else {
                    claims[plotID] = store.id
                }
                guard let plot = plotByID[plotID] else {
                    issues.append(.missingPlot(store.id, plotID))
                    continue
                }
                if map.parcel(legacyPlotID: plotID) == nil {
                    issues.append(.missingParcel(store.id, plotID))
                }
                guard case .player(let occupantStoreID) = plot.occupant,
                      occupantStoreID == store.id else {
                    issues.append(.occupantMismatch(store.id, plotID))
                    continue
                }
            }

            if let primary = plotByID[store.plotID] {
                let effectiveType = store.pendingType ?? store.type
                let resolved = footprintPlots(
                    startingAt: primary,
                    type: effectiveType,
                    plots: plots,
                    map: map,
                    acquisitionMode: store.acquisition,
                    occupiedBy: store.id,
                    requiredExistingIDs: Set(store.plotIDs)
                )
                if Set(resolved.map(\.id)) != Set(store.plotIDs) {
                    issues.append(.invalidFootprint(store.id))
                }
            }

            let placements = visualPlacements(for: store, map: map)
            let placedPlotIDs = Set(placements.map(\.plotID))
            for plotID in store.plotIDs where !placedPlotIDs.contains(plotID) {
                issues.append(.missingVisualPlacement(store.id, plotID))
            }
        }

        for plot in plots {
            guard case .player(let storeID) = plot.occupant else { continue }
            if storeByID[storeID]?.plotIDs.contains(plot.id) != true {
                issues.append(.orphanedPlayerOccupant(plot.id, storeID))
            }
        }
        return issues
    }

    private static func offsetPatterns(cellCount: Int) -> [[(column: Int, row: Int)]] {
        switch cellCount {
        case 1:
            [[(0, 0)]]
        case 2:
            [
                [(0, 0), (1, 0)], [(0, 0), (-1, 0)],
                [(0, 0), (0, 1)], [(0, 0), (0, -1)]
            ]
        case 3:
            [
                [(0, 0), (1, 0), (2, 0)],
                [(-1, 0), (0, 0), (1, 0)],
                [(-2, 0), (-1, 0), (0, 0)],
                [(0, 0), (0, 1), (0, 2)],
                [(0, -1), (0, 0), (0, 1)],
                [(0, -2), (0, -1), (0, 0)]
            ]
        default:
            []
        }
    }

    private static func parcel(
        atColumnOffset columnOffset: Int,
        rowOffset: Int,
        from anchor: GridParcel,
        map: GridCityMap
    ) -> GridParcel? {
        guard columnOffset == 0 || rowOffset == 0 else { return nil }
        var result = anchor
        let direction: CardinalDirection
        let distance: Int
        if columnOffset > 0 { direction = .east; distance = columnOffset }
        else if columnOffset < 0 { direction = .west; distance = -columnOffset }
        else if rowOffset > 0 { direction = .south; distance = rowOffset }
        else if rowOffset < 0 { direction = .north; distance = -rowOffset }
        else { return anchor }
        for _ in 0..<distance {
            guard let next = map.neighboringParcel(of: result, in: direction) else { return nil }
            result = next
        }
        return result
    }

    private static func isUsable(
        _ plot: LandPlot,
        acquisitionMode: AcquisitionMode?,
        occupiedBy storeID: UUID?
    ) -> Bool {
        switch plot.occupant {
        case .available:
            switch acquisitionMode {
            case .purchase?: return plot.isForSale
            case .lease?: return plot.isForLease
            case nil: return plot.isForSale || plot.isForLease
            }
        case .player(let occupantStoreID):
            return occupantStoreID == storeID
        case .competitor, .unavailable:
            return false
        }
    }

    private static func facingDirection(
        for assetID: CityAssetID,
        parcel: GridParcel,
        map: GridCityMap
    ) -> CardinalDirection? {
        let definition = CityAssetCatalog.definition(for: assetID)
        let usableAccess = map.usableRoadAccess(for: parcel)
        return CardinalDirection.allCases.first { facing in
            !definition.roadConnections(facing: facing).isDisjoint(with: usableAccess)
        }
    }

    private static func visualPlacementIsValid(
        assetID: CityAssetID,
        parcel: GridParcel,
        map: GridCityMap,
        ignoringObjectIDs: Set<String>
    ) -> Bool {
        guard let facing = facingDirection(for: assetID, parcel: parcel, map: map) else { return false }
        return GridPlacementRules.failures(
            placing: assetID,
            facing: facing,
            in: parcel.id,
            map: map,
            ignoringObjectIDs: ignoringObjectIDs
        ).isEmpty
    }
}

enum GridMapValidationIssue: Hashable, Sendable, CustomStringConvertible {
    case invalidMapSize
    case invalidCellSize
    case roadOutsideMap(GridCoordinate)
    case roadConnectionMissing(GridCoordinate, CardinalDirection)
    case roadConnectionNotReciprocal(GridCoordinate, CardinalDirection)
    case duplicateParcelID(String)
    case duplicateLegacyPlotID(Int)
    case parcelOutsideMap(String)
    case parcelOverlapsRoad(String, GridCoordinate)
    case parcelsOverlap(String, String, GridCoordinate)
    case parcelRoadAccessMissing(String, CardinalDirection)
    case buildableParcelHasNoRoadAccess(String)
    case currentBuildingMissing(String, String)
    case currentBuildingWrongParcel(String, String)
    case duplicateObjectID(String)
    case objectUsesUnknownParcel(String, String)
    case objectOutsideMap(String)
    case objectOutsideParcel(String, String)
    case objectOverlapsRoad(String, GridCoordinate)
    case objectsOverlap(String, String, GridCoordinate)
    case objectReferenceMismatch(String, String)
    case objectFootprintMismatch(String, GridSize, GridSize)
    case objectDistrictNotAllowed(String, DistrictKind)
    case objectRoadConnectionMissing(String)
    case objectKindMismatch(String)
    case invalidObjectHeight(String)
    case anchorOutsideMap(GridMapAnchorID, GridCoordinate)
    case terrainOutsideMap(GridCoordinate)
    case terrainOverlapsRoad(GridCoordinate)
    case terrainOverlapsParcel(GridCoordinate, String)

    var description: String {
        switch self {
        case .invalidMapSize: "Map size must be positive"
        case .invalidCellSize: "Cell size must be positive"
        case .roadOutsideMap(let coordinate): "Road is outside map at \(coordinate)"
        case .roadConnectionMissing(let coordinate, let direction): "Road at \(coordinate) is missing \(direction) neighbor"
        case .roadConnectionNotReciprocal(let coordinate, let direction): "Road at \(coordinate) has non-reciprocal \(direction) connection"
        case .duplicateParcelID(let id): "Parcel id \(id) is duplicated"
        case .duplicateLegacyPlotID(let id): "Legacy plot id \(id) is duplicated"
        case .parcelOutsideMap(let id): "Parcel \(id) is outside map"
        case .parcelOverlapsRoad(let id, let coordinate): "Parcel \(id) overlaps road at \(coordinate)"
        case .parcelsOverlap(let first, let second, let coordinate): "Parcels \(first) and \(second) overlap at \(coordinate)"
        case .parcelRoadAccessMissing(let id, let direction): "Parcel \(id) has no road on \(direction) edge"
        case .buildableParcelHasNoRoadAccess(let id): "Buildable parcel \(id) has no adjacent road"
        case .currentBuildingMissing(let parcel, let object): "Parcel \(parcel) references missing building \(object)"
        case .currentBuildingWrongParcel(let parcel, let object): "Parcel \(parcel) references building \(object) on another parcel"
        case .duplicateObjectID(let id): "Object id \(id) is duplicated"
        case .objectUsesUnknownParcel(let object, let parcel): "Object \(object) references unknown parcel \(parcel)"
        case .objectOutsideMap(let object): "Object \(object) is outside map"
        case .objectOutsideParcel(let object, let parcel): "Object \(object) is outside parcel \(parcel)"
        case .objectOverlapsRoad(let object, let coordinate): "Object \(object) overlaps road at \(coordinate)"
        case .objectsOverlap(let first, let second, let coordinate): "Objects \(first) and \(second) overlap at \(coordinate)"
        case .objectReferenceMismatch(let object, let parcel): "Object \(object) is not the current building of parcel \(parcel)"
        case .objectFootprintMismatch(let object, let expected, let actual): "Object \(object) footprint \(actual) does not match \(expected)"
        case .objectDistrictNotAllowed(let object, let district): "Object \(object) is not allowed in \(district)"
        case .objectRoadConnectionMissing(let object): "Object \(object) does not face an adjacent road"
        case .objectKindMismatch(let object): "Object \(object) kind does not match its asset category"
        case .invalidObjectHeight(let object): "Object \(object) has an invalid height"
        case .anchorOutsideMap(let anchor, let coordinate): "Anchor \(anchor.rawValue) is outside map at \(coordinate)"
        case .terrainOutsideMap(let coordinate): "Terrain is outside map at \(coordinate)"
        case .terrainOverlapsRoad(let coordinate): "Non-water terrain overlaps road at \(coordinate)"
        case .terrainOverlapsParcel(let coordinate, let parcel): "Terrain overlaps parcel \(parcel) at \(coordinate)"
        }
    }
}

enum GridMapValidator {
    static func validate(_ map: GridCityMap) -> [GridMapValidationIssue] {
        var issues: [GridMapValidationIssue] = []
        if !map.size.isValid { issues.append(.invalidMapSize) }
        if map.metrics.cellSize <= 0 { issues.append(.invalidCellSize) }
        for (anchor, coordinate) in map.anchors where !map.size.contains(coordinate) {
            issues.append(.anchorOutsideMap(anchor, coordinate))
        }
        for (coordinate, feature) in map.terrain {
            if !map.size.contains(coordinate) {
                issues.append(.terrainOutsideMap(coordinate))
            }
            // Water may pass under a road as a bridge; every other feature is
            // pedestrian ground and must not coincide with pavement.
            if feature != .water, map.roads[coordinate] != nil {
                issues.append(.terrainOverlapsRoad(coordinate))
            }
        }
        for parcel in map.parcels {
            for coordinate in parcel.rect.cells where map.terrain[coordinate] != nil {
                issues.append(.terrainOverlapsParcel(coordinate, parcel.id))
            }
        }

        var seenParcelIDs: Set<String> = []
        var seenLegacyPlotIDs: Set<Int> = []
        for parcel in map.parcels {
            if !seenParcelIDs.insert(parcel.id).inserted {
                issues.append(.duplicateParcelID(parcel.id))
            }
            if let legacyPlotID = parcel.legacyPlotID,
               !seenLegacyPlotIDs.insert(legacyPlotID).inserted {
                issues.append(.duplicateLegacyPlotID(legacyPlotID))
            }
        }
        var seenObjectIDs: Set<String> = []
        for object in map.objects where !seenObjectIDs.insert(object.id).inserted {
            issues.append(.duplicateObjectID(object.id))
        }

        for road in map.roads.values {
            if !map.size.contains(road.coordinate) {
                issues.append(.roadOutsideMap(road.coordinate))
            }
            for direction in road.connections.directions {
                let neighborCoordinate = road.coordinate.neighbor(in: direction)
                guard let neighbor = map.roads[neighborCoordinate] else {
                    issues.append(.roadConnectionMissing(road.coordinate, direction))
                    continue
                }
                if !neighbor.connections.contains(direction.opposite.connection) {
                    issues.append(.roadConnectionNotReciprocal(road.coordinate, direction))
                }
            }
            for direction in CardinalDirection.allCases {
                let hasNeighbor = map.roads[road.coordinate.neighbor(in: direction)] != nil
                if hasNeighbor && !road.connections.contains(direction.connection) {
                    issues.append(.roadConnectionMissing(road.coordinate, direction))
                }
            }
        }

        var parcelOccupancy: [GridCoordinate: String] = [:]
        let objectByID = Dictionary(map.objects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for parcel in map.parcels {
            if !map.size.contains(parcel.rect) {
                issues.append(.parcelOutsideMap(parcel.id))
            }
            for coordinate in parcel.rect.cells {
                if map.roads[coordinate] != nil {
                    issues.append(.parcelOverlapsRoad(parcel.id, coordinate))
                }
                if let existing = parcelOccupancy[coordinate], existing != parcel.id {
                    issues.append(.parcelsOverlap(existing, parcel.id, coordinate))
                } else {
                    parcelOccupancy[coordinate] = parcel.id
                }
            }
            let actualRoadAccess = map.actualRoadAccess(for: parcel)
            if parcel.isBuildable && map.usableRoadAccess(for: parcel).isEmpty {
                issues.append(.buildableParcelHasNoRoadAccess(parcel.id))
            }
            for direction in parcel.roadAccess where !actualRoadAccess.contains(direction) {
                    issues.append(.parcelRoadAccessMissing(parcel.id, direction))
            }
            if let buildingID = parcel.currentBuildingID {
                guard let building = objectByID[buildingID] else {
                    issues.append(.currentBuildingMissing(parcel.id, buildingID))
                    continue
                }
                if building.parcelID != parcel.id || building.kind != .building {
                    issues.append(.currentBuildingWrongParcel(parcel.id, buildingID))
                }
            }
        }

        var objectOccupancy: [GridCoordinate: String] = [:]
        for object in map.objects {
            guard let parcel = map.parcel(id: object.parcelID) else {
                issues.append(.objectUsesUnknownParcel(object.id, object.parcelID))
                continue
            }
            if !map.size.contains(object.rect) {
                issues.append(.objectOutsideMap(object.id))
            }
            if !parcel.rect.contains(object.rect) {
                issues.append(.objectOutsideParcel(object.id, parcel.id))
            }
            let definition = CityAssetCatalog.definition(for: object.assetID)
            let expectedFootprint = definition.footprint(facing: object.facing)
            if object.rect.size != expectedFootprint {
                issues.append(.objectFootprintMismatch(object.id, expectedFootprint, object.rect.size))
            }
            if !definition.allowedDistricts.contains(parcel.district) {
                issues.append(.objectDistrictNotAllowed(object.id, parcel.district))
            }
            if definition.roadConnections(facing: object.facing).isDisjoint(with: map.usableRoadAccess(for: parcel)) {
                issues.append(.objectRoadConnectionMissing(object.id))
            }
            let expectsParking = definition.category == .parking
            if (object.kind == .parking) != expectsParking {
                issues.append(.objectKindMismatch(object.id))
            }
            if !object.height.isFinite || object.height <= 0 {
                issues.append(.invalidObjectHeight(object.id))
            }
            if object.kind == .building, parcel.currentBuildingID != object.id {
                issues.append(.objectReferenceMismatch(object.id, parcel.id))
            }
            for coordinate in object.rect.cells {
                if map.roads[coordinate] != nil {
                    issues.append(.objectOverlapsRoad(object.id, coordinate))
                }
                if let existing = objectOccupancy[coordinate], existing != object.id {
                    issues.append(.objectsOverlap(existing, object.id, coordinate))
                } else {
                    objectOccupancy[coordinate] = object.id
                }
            }
        }
        return issues
    }
}
