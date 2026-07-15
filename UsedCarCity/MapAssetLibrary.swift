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

enum MapAssetLibrary {
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
}
