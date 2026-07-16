import SwiftUI

/// Reusable vector asset descriptions. They are defined in grid/world units,
/// so the same asset can be placed in any cell of any city blueprint.
enum IsoRoofAsset {
    case flat
    case house
    case sawtooth
}

enum IsoBuildingDetailAsset {
    case retail
    case windows
    case factory
    case home
    case station
    case roadside
    case dealership
}

struct IsoBuildingAsset {
    let rect: CGRect
    let height: CGFloat
    let color: Color
    let roof: IsoRoofAsset
    let detail: IsoBuildingDetailAsset
}

/// Raster sprites share one normalized ground anchor so their property pads
/// can be snapped to any cell without depending on the source image size.
struct IsoMapSpriteAsset {
    let imageName: String
    let pixelSize: CGSize
    let groundAnchorY: CGFloat
    let widthScale: CGFloat
}

/// Zoom-dependent rendering policy shared by the raster tile, vector road,
/// and building sprite layers. Keeping the thresholds in one place prevents
/// the layers from changing detail at visibly different moments.
enum CityMapLevelOfDetail: Equatable {
    case overview
    case district
    case street

    init(cameraScale: CGFloat) {
        if cameraScale >= 2.15 {
            self = .street
        } else if cameraScale >= 1.35 {
            self = .district
        } else {
            self = .overview
        }
    }

    var label: String {
        switch self {
        case .overview: "広域全景"
        case .district: "地区表示"
        case .street: "街区詳細"
        }
    }

    var usesHighResolutionTiles: Bool { self != .overview }
    var showsParcelSprites: Bool { self == .street }
    var showsMinorRoads: Bool { self == .street }
}

/// One source tile in the 4 x 3 high-resolution city mosaic. The complete
/// mosaic is 7,240 x 5,430 pixels, while the overview image remains a small,
/// inexpensive texture for the far camera.
struct CityMapRasterTile: Identifiable, Equatable {
    static let columnCount = 4
    static let rowCount = 3
    static let tilePixelSize = CGSize(width: 1_810, height: 1_810)
    static let mosaicPixelSize = CGSize(
        width: tilePixelSize.width * CGFloat(columnCount),
        height: tilePixelSize.height * CGFloat(rowCount)
    )
    static let all: [CityMapRasterTile] = (0..<rowCount).flatMap { row in
        (0..<columnCount).map { column in
            CityMapRasterTile(row: row, column: column)
        }
    }

    let row: Int
    let column: Int

    var id: String { imageName }
    var imageName: String { "CityMapTile_\(row)_\(column)" }

    func frame(in mapRect: CGRect, overlap: CGFloat = 0) -> CGRect {
        let width = mapRect.width / CGFloat(Self.columnCount)
        let height = mapRect.height / CGFloat(Self.rowCount)
        return CGRect(
            x: mapRect.minX + CGFloat(column) * width - overlap,
            y: mapRect.minY + CGFloat(row) * height - overlap,
            width: width + overlap * 2,
            height: height + overlap * 2
        )
    }
}

enum MapAssetLibrary {
    static func parcelSprite(for plot: LandPlot) -> IsoMapSpriteAsset? {
        switch plot.structure {
        case .commercial:
            return sprite("ParcelCommercial", 430, 273, anchorY: 0.76)
        case .office:
            return sprite("ParcelCommercial", 430, 273, anchorY: 0.76, widthScale: 1.06)
        case .apartment:
            return sprite("ParcelApartment", 377, 285, anchorY: 0.74, widthScale: 0.98)
        case .home:
            return sprite("ParcelHome", 287, 194, anchorY: 0.67, widthScale: 0.95)
        case .villa:
            return sprite("ParcelVilla", 456, 298, anchorY: 0.68)
        case .factory:
            return sprite("ParcelFactory", 405, 291, anchorY: 0.74, widthScale: 1.04)
        case .warehouse:
            return sprite("ParcelWarehouse", 421, 244, anchorY: 0.72, widthScale: 1.04)
        case .roadside:
            let imageName = plot.id.isMultiple(of: 3) ? "ParcelServiceStation" : "ParcelRoadside"
            let size = imageName == "ParcelServiceStation" ? CGSize(width: 336, height: 213) : CGSize(width: 389, height: 242)
            return IsoMapSpriteAsset(imageName: imageName, pixelSize: size, groundAnchorY: 0.72, widthScale: 1.02)
        case .vacant:
            return nil
        }
    }

    static func storeSprite(for type: StoreType) -> IsoMapSpriteAsset {
        switch type {
        case .small:
            return sprite("MapStoreSmall", 1102, 738, anchorY: 0.62, widthScale: 0.94)
        case .standard:
            return sprite("MapStoreStandard", 1420, 878, anchorY: 0.62, widthScale: 0.96)
        case .roadside:
            return sprite("MapStoreRoadside", 1485, 754, anchorY: 0.62, widthScale: 0.98)
        case .premium:
            return sprite("MapStorePremium", 1312, 895, anchorY: 0.64, widthScale: 0.94)
        case .service:
            return sprite("MapStoreService", 1429, 807, anchorY: 0.62, widthScale: 0.97)
        }
    }

    /// Rival outlets currently own one model cell each, so their artwork must
    /// also remain a one-cell sprite even when the player builds larger stores.
    static func competitorSprite(for plotID: Int) -> IsoMapSpriteAsset {
        if plotID.isMultiple(of: 2) {
            return sprite("ParcelWorkshop", 361, 234, anchorY: 0.72, widthScale: 1.02)
        }
        return sprite("ParcelRoadside", 389, 242, anchorY: 0.72, widthScale: 1.02)
    }

    static func parcelBuilding(for plot: LandPlot, in rect: CGRect) -> IsoBuildingAsset? {
        let variation = CGFloat((plot.id * 7) % 9)
        switch plot.structure {
        case .commercial:
            let colors = [Color(red: 0.55, green: 0.38, blue: 0.65), Color(red: 0.65, green: 0.43, blue: 0.42), Color(red: 0.35, green: 0.55, blue: 0.65)]
            return IsoBuildingAsset(rect: rect, height: 39 + variation, color: colors[plot.id % colors.count], roof: .flat, detail: .retail)
        case .office:
            let colors = [Color(red: 0.30, green: 0.52, blue: 0.70), Color(red: 0.37, green: 0.57, blue: 0.63), Color(red: 0.46, green: 0.49, blue: 0.61)]
            return IsoBuildingAsset(rect: rect, height: 47 + variation * 1.4, color: colors[plot.id % colors.count], roof: .flat, detail: .windows)
        case .apartment:
            let colors = [Color(red: 0.74, green: 0.69, blue: 0.61), Color(red: 0.70, green: 0.62, blue: 0.57), Color(red: 0.64, green: 0.67, blue: 0.65)]
            return IsoBuildingAsset(rect: rect.insetBy(dx: 0.002, dy: 0), height: 34 + variation, color: colors[plot.id % colors.count], roof: .flat, detail: .windows)
        case .home:
            let house = scaledRect(rect, width: 0.78, height: 0.72, x: 0.08, y: 0.08)
            let colors = [Color(red: 0.90, green: 0.69, blue: 0.44), Color(red: 0.82, green: 0.72, blue: 0.59), Color(red: 0.72, green: 0.77, blue: 0.73)]
            return IsoBuildingAsset(rect: house, height: 19 + variation * 0.35, color: colors[plot.id % colors.count], roof: .house, detail: .home)
        case .villa:
            let house = scaledRect(rect, width: 0.72, height: 0.68, x: 0.09, y: 0.09)
            let colors = [Color(red: 0.87, green: 0.80, blue: 0.65), Color(red: 0.78, green: 0.82, blue: 0.75), Color(red: 0.84, green: 0.72, blue: 0.65)]
            return IsoBuildingAsset(rect: house, height: 24 + variation * 0.45, color: colors[plot.id % colors.count], roof: .house, detail: .home)
        case .factory:
            return IsoBuildingAsset(rect: rect, height: 29 + variation * 0.45, color: Color(red: 0.43, green: 0.48, blue: 0.50), roof: .sawtooth, detail: .factory)
        case .warehouse:
            return IsoBuildingAsset(rect: rect, height: 24 + variation * 0.35, color: Color(red: 0.50, green: 0.56, blue: 0.59), roof: .flat, detail: .factory)
        case .roadside:
            let colors = [Color(red: 0.84, green: 0.50, blue: 0.23), Color(red: 0.25, green: 0.58, blue: 0.56), Color(red: 0.71, green: 0.38, blue: 0.32)]
            return IsoBuildingAsset(rect: scaledRect(rect, width: 0.88, height: 0.72, x: 0.04, y: 0.06), height: 23 + variation * 0.35, color: colors[plot.id % colors.count], roof: .flat, detail: .roadside)
        case .vacant:
            return nil
        }
    }

    static func dealership(in lot: CGRect, type: StoreType, color: Color) -> IsoBuildingAsset {
        let rect = CGRect(
            x: lot.minX + lot.width * 0.06,
            y: lot.minY + lot.height * 0.08,
            width: lot.width * (type.requiredGridCells == 1 ? 0.58 : 0.46),
            height: lot.height * 0.58
        )
        let height: CGFloat = type == .premium ? 34 : type == .roadside ? 27 : 30
        return IsoBuildingAsset(rect: rect, height: height, color: color, roof: .flat, detail: .dealership)
    }

    static func facility(_ facility: MapFacility, in rect: CGRect) -> IsoBuildingAsset {
        switch facility {
        case .auction:
            return IsoBuildingAsset(rect: rect, height: 18, color: facility.color, roof: .sawtooth, detail: .factory)
        case .bank, .cityHall:
            return IsoBuildingAsset(rect: rect, height: 34, color: facility.color, roof: .flat, detail: .windows)
        case .workshop:
            return IsoBuildingAsset(rect: rect, height: 21, color: facility.color, roof: .sawtooth, detail: .factory)
        case .realEstate, .advertising, .recruiting:
            return IsoBuildingAsset(rect: rect, height: 25, color: facility.color, roof: .flat, detail: .retail)
        }
    }

    private static func scaledRect(_ rect: CGRect, width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX + rect.width * x,
            y: rect.minY + rect.height * y,
            width: rect.width * width,
            height: rect.height * height
        )
    }

    private static func sprite(
        _ imageName: String,
        _ width: CGFloat,
        _ height: CGFloat,
        anchorY: CGFloat,
        widthScale: CGFloat = 1
    ) -> IsoMapSpriteAsset {
        IsoMapSpriteAsset(
            imageName: imageName,
            pixelSize: CGSize(width: width, height: height),
            groundAnchorY: anchorY,
            widthScale: widthScale
        )
    }
}
