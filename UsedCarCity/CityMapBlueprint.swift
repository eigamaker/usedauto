import SwiftUI

/// One grid specification is shared by every city. A future map only supplies
/// placements; buildings and infrastructure keep the same cell measurements.
struct IsometricGridSpec {
    let columnCount: Int
    let rowCount: Int
    let origin: CGPoint
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let lotSize: CGSize

    func point(column: Int, row: Int) -> CGPoint {
        CGPoint(
            x: origin.x + CGFloat(column) * columnSpacing,
            y: origin.y + CGFloat(row) * rowSpacing
        )
    }

    func cellRect(column: Int, row: Int) -> CGRect {
        let center = point(column: column, row: row)
        return CGRect(
            x: center.x - columnSpacing * 0.46,
            y: center.y - rowSpacing * 0.43,
            width: columnSpacing * 0.92,
            height: rowSpacing * 0.86
        )
    }

    func lotRect(column: Int, row: Int) -> CGRect {
        let center = point(column: column, row: row)
        return CGRect(
            x: center.x - lotSize.width / 2,
            y: center.y - lotSize.height / 2,
            width: lotSize.width,
            height: lotSize.height
        )
    }
}

struct DistrictGridRegion {
    let kind: DistrictKind
    let column: Int
    let row: Int
    let columns: Int
    let rows: Int
}

enum GridRoadAxis {
    case horizontal
    case vertical
}

struct GridRoadPlacement {
    let axis: GridRoadAxis
    let position: CGFloat
    let range: ClosedRange<CGFloat>
    let width: CGFloat
    let isMajor: Bool
}

struct GridWaterPlacement {
    let rect: CGRect
    let rippleStart: CGFloat
    let rippleEnd: CGFloat
}

struct GridParkPlacement {
    let rect: CGRect
    let name: String
}

struct GridRailPlacement {
    let district: DistrictKind
    let platformDepth: CGFloat
    let extensionLength: CGFloat
}

struct GridHighwayPlacement {
    let laneYPositions: [CGFloat]
    let rampStart: CGPoint
    let rampEnd: CGPoint
    let labelPoint: CGPoint
}

struct GridTreePlacement {
    let point: CGPoint
    let variant: Int
}

/// A map is now a placement document. It contains no building artwork, so a
/// second city can reuse the complete asset library by defining another value.
struct CityMapBlueprint {
    let id: String
    let name: String
    let grid: IsometricGridSpec
    let districts: [DistrictGridRegion]
    let majorRoads: [GridRoadPlacement]
    let water: GridWaterPlacement
    let park: GridParkPlacement
    let rail: GridRailPlacement
    let highway: GridHighwayPlacement
    let trees: [GridTreePlacement]

    static let suihama = CityMapBlueprint(
        id: "suihama",
        name: "翠浜市",
        grid: IsometricGridSpec(
            columnCount: 30,
            rowCount: 20,
            origin: CGPoint(x: 0.025, y: 0.045),
            columnSpacing: 0.0325,
            rowSpacing: 0.048,
            lotSize: CGSize(width: 0.028, height: 0.040)
        ),
        districts: [
            DistrictGridRegion(kind: .downtown, column: 0, row: 0, columns: 6, rows: 5),
            DistrictGridRegion(kind: .station, column: 12, row: 0, columns: 6, rows: 5),
            DistrictGridRegion(kind: .emerging, column: 24, row: 0, columns: 6, rows: 5),
            DistrictGridRegion(kind: .suburb, column: 0, row: 10, columns: 6, rows: 5),
            DistrictGridRegion(kind: .industrial, column: 12, row: 10, columns: 6, rows: 5),
            DistrictGridRegion(kind: .highway, column: 24, row: 10, columns: 6, rows: 5)
        ],
        majorRoads: [
            GridRoadPlacement(axis: .horizontal, position: 0.250, range: 0.01...0.98, width: 0.028, isMajor: true),
            GridRoadPlacement(axis: .horizontal, position: 0.590, range: 0.01...0.94, width: 0.028, isMajor: true),
            GridRoadPlacement(axis: .vertical, position: 0.285, range: 0.01...0.94, width: 0.026, isMajor: true),
            GridRoadPlacement(axis: .vertical, position: 0.615, range: 0.01...0.94, width: 0.028, isMajor: true),
            GridRoadPlacement(axis: .vertical, position: 0.875, range: 0.01...0.94, width: 0.022, isMajor: true),
            GridRoadPlacement(axis: .vertical, position: 0.560, range: 0.590...0.94, width: 0.022, isMajor: true)
        ],
        water: GridWaterPlacement(
            rect: CGRect(x: 0.945, y: 0.16, width: 0.055, height: 0.82),
            rippleStart: 0.20,
            rippleEnd: 0.92
        ),
        park: GridParkPlacement(
            rect: CGRect(x: 0.39, y: 0.335, width: 0.17, height: 0.19),
            name: "中央公園"
        ),
        rail: GridRailPlacement(district: .station, platformDepth: 0.035, extensionLength: 0.045),
        highway: GridHighwayPlacement(
            laneYPositions: [0.655, 0.685],
            rampStart: CGPoint(x: 0.59, y: 0.67),
            rampEnd: CGPoint(x: 0.64, y: 0.60),
            labelPoint: CGPoint(x: 0.54, y: 0.67)
        ),
        trees: [
            .init(point: .init(x: 0.40, y: 0.35), variant: 0), .init(point: .init(x: 0.44, y: 0.37), variant: 1),
            .init(point: .init(x: 0.49, y: 0.35), variant: 0), .init(point: .init(x: 0.54, y: 0.38), variant: 1),
            .init(point: .init(x: 0.41, y: 0.47), variant: 0), .init(point: .init(x: 0.46, y: 0.51), variant: 1),
            .init(point: .init(x: 0.51, y: 0.48), variant: 0), .init(point: .init(x: 0.55, y: 0.45), variant: 1),
            .init(point: .init(x: 0.04, y: 0.30), variant: 0), .init(point: .init(x: 0.14, y: 0.30), variant: 1),
            .init(point: .init(x: 0.23, y: 0.30), variant: 0), .init(point: .init(x: 0.05, y: 0.38), variant: 1),
            .init(point: .init(x: 0.16, y: 0.38), variant: 0), .init(point: .init(x: 0.25, y: 0.38), variant: 1),
            .init(point: .init(x: 0.68, y: 0.31), variant: 0), .init(point: .init(x: 0.76, y: 0.31), variant: 1),
            .init(point: .init(x: 0.84, y: 0.31), variant: 0), .init(point: .init(x: 0.68, y: 0.56), variant: 1),
            .init(point: .init(x: 0.78, y: 0.56), variant: 0), .init(point: .init(x: 0.86, y: 0.56), variant: 1),
            .init(point: .init(x: 0.34, y: 0.70), variant: 0), .init(point: .init(x: 0.46, y: 0.72), variant: 1),
            .init(point: .init(x: 0.58, y: 0.72), variant: 0), .init(point: .init(x: 0.30, y: 0.91), variant: 1),
            .init(point: .init(x: 0.62, y: 0.91), variant: 0), .init(point: .init(x: 0.91, y: 0.86), variant: 1)
        ]
    )
}

struct MapLandmark: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let x: CGFloat
    let y: CGFloat
    let tint: Color
}

enum CityMapLayout {
    static let blueprint = CityMapBlueprint.suihama
    static let columnCount = blueprint.grid.columnCount
    static let rowCount = blueprint.grid.rowCount
    static let columnSpacing = blueprint.grid.columnSpacing
    static let rowSpacing = blueprint.grid.rowSpacing
    static let gridOrigin = blueprint.grid.origin
    static let districtColumnCount = blueprint.districts.first?.columns ?? 4
    static let districtRowCount = blueprint.districts.first?.rows ?? 3
    static let plotsPerDistrict = districtColumnCount * districtRowCount

    static let districtGridOrigins: [(kind: DistrictKind, column: Int, row: Int)] = blueprint.districts.map {
        ($0.kind, $0.column, $0.row)
    }

    static let plotGrid: [(column: Int, row: Int)] = blueprint.districts.flatMap { region in
        (0..<region.rows).flatMap { row in
            (0..<region.columns).map { column in
                (column: region.column + column, row: region.row + row)
            }
        }
    }

    static let plotPositions: [CGPoint] = plotGrid.map { gridPoint(column: $0.column, row: $0.row) }

    static let landmarks: [MapLandmark] = [
        landmark(id: "boutique", title: "都心商業街", subtitle: "高地価・高級車", icon: "bag.fill", kind: .downtown, tint: .purple),
        landmark(id: "station", title: "翠浜駅", subtitle: "通勤・若年層", icon: "tram.fill", kind: .station, tint: .blue),
        landmark(id: "newtown", title: "青葉ヒルズ", subtitle: "大区画・高級住宅", icon: "house.and.flag.fill", kind: .emerging, tint: .green),
        landmark(id: "residential", title: "さくら住宅街", subtitle: "一般住宅・ファミリー", icon: "house.fill", kind: .suburb, tint: GameTheme.teal),
        landmark(id: "factory", title: "臨海工業団地", subtitle: "工場・倉庫・商用車", icon: "gearshape.2.fill", kind: .industrial, tint: .gray),
        landmark(id: "roadside", title: "翠浜IC・国道8号", subtitle: "大型店・通過交通", icon: "road.lanes", kind: .highway, tint: GameTheme.orange)
    ]

    static func position(for plotID: Int) -> CGPoint {
        plotPositions.indices.contains(plotID) ? plotPositions[plotID] : .init(x: 0.5, y: 0.5)
    }

    static func gridCoordinate(for plotID: Int) -> (column: Int, row: Int)? {
        plotGrid.indices.contains(plotID) ? plotGrid[plotID] : nil
    }

    static func gridPoint(column: Int, row: Int) -> CGPoint {
        blueprint.grid.point(column: column, row: row)
    }

    static func gridCellRect(column: Int, row: Int) -> CGRect {
        blueprint.grid.cellRect(column: column, row: row)
    }

    static func lotRect(for plotID: Int) -> CGRect {
        guard let coordinate = gridCoordinate(for: plotID) else { return .zero }
        return blueprint.grid.lotRect(column: coordinate.column, row: coordinate.row)
    }

    static func lotRect(for plot: LandPlot) -> CGRect { lotRect(for: plot.id) }

    static func combinedLotRect(for plotIDs: [Int]) -> CGRect {
        let rects = plotIDs.map(lotRect(for:))
        guard var result = rects.first else { return .zero }
        for rect in rects.dropFirst() { result = result.union(rect) }
        return result
    }

    static func trafficBadgePosition(for kind: DistrictKind) -> CGPoint { districtCenter(for: kind) }

    static func districtRect(for kind: DistrictKind) -> CGRect {
        guard let region = blueprint.districts.first(where: { $0.kind == kind }) else { return .zero }
        var result = blueprint.grid.lotRect(column: region.column, row: region.row)
        for row in 0..<region.rows {
            for column in 0..<region.columns {
                result = result.union(blueprint.grid.lotRect(column: region.column + column, row: region.row + row))
            }
        }
        return result.insetBy(dx: -0.012, dy: -0.012)
    }

    static func districtCenter(for kind: DistrictKind) -> CGPoint {
        let rect = districtRect(for: kind)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private static func landmark(id: String, title: String, subtitle: String, icon: String, kind: DistrictKind, tint: Color) -> MapLandmark {
        let center = districtCenter(for: kind)
        return MapLandmark(id: id, title: title, subtitle: subtitle, icon: icon, x: center.x, y: center.y, tint: tint)
    }
}
