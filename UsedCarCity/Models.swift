import Foundation
import SwiftUI

enum DistrictKind: String, Codable, CaseIterable, Identifiable {
    case downtown, suburb, station, industrial, emerging, highway
    var id: String { rawValue }

    var name: String {
        switch self {
        case .downtown: "都心商業"
        case .suburb: "郊外住宅"
        case .station: "駅周辺"
        case .industrial: "工業地区"
        case .emerging: "新興住宅"
        case .highway: "地方幹線"
        }
    }

    var shortName: String {
        switch self {
        case .downtown: "都心"
        case .suburb: "郊外"
        case .station: "駅前"
        case .industrial: "工業"
        case .emerging: "新興"
        case .highway: "幹線"
        }
    }

    var symbol: String {
        switch self {
        case .downtown: "building.2.fill"
        case .suburb: "house.and.flag.fill"
        case .station: "tram.fill"
        case .industrial: "gearshape.2.fill"
        case .emerging: "tree.fill"
        case .highway: "road.lanes"
        }
    }

    var color: Color {
        switch self {
        case .downtown: Color(red: 0.55, green: 0.37, blue: 0.73)
        case .suburb: Color(red: 0.19, green: 0.57, blue: 0.43)
        case .station: Color(red: 0.22, green: 0.48, blue: 0.72)
        case .industrial: Color(red: 0.45, green: 0.48, blue: 0.50)
        case .emerging: Color(red: 0.39, green: 0.67, blue: 0.27)
        case .highway: Color(red: 0.85, green: 0.50, blue: 0.18)
        }
    }
}

enum VehicleCategory: String, Codable, CaseIterable, Identifiable {
    case kei, compact, minivan, suv, premium, commercial, budget
    var id: String { rawValue }

    var name: String {
        switch self {
        case .kei: "軽"
        case .compact: "コンパクト"
        case .minivan: "ミニバン"
        case .suv: "SUV"
        case .premium: "高級・輸入"
        case .commercial: "商用車"
        case .budget: "低価格車"
        }
    }

    var icon: String {
        switch self {
        case .commercial: "truck.box.fill"
        case .premium: "sparkles"
        default: "car.side.fill"
        }
    }

    var purchaseCost: Int {
        switch self {
        case .kei: 75
        case .compact: 105
        case .minivan: 180
        case .suv: 205
        case .premium: 430
        case .commercial: 145
        case .budget: 52
        }
    }
}

enum CustomerFocus: String, Codable, CaseIterable, Identifiable {
    case family, value, young, affluent, business
    var id: String { rawValue }
    var name: String {
        switch self {
        case .family: "ファミリー"
        case .value: "価格重視"
        case .young: "若年層"
        case .affluent: "高所得層"
        case .business: "法人・事業者"
        }
    }
}

enum StoreConcept: String, Codable, CaseIterable, Identifiable {
    case general, keiLocal, family, custom, premium, business
    var id: String { rawValue }

    var name: String {
        switch self {
        case .general: "総合中古車店"
        case .keiLocal: "軽・地域密着"
        case .family: "ファミリー専門"
        case .custom: "カスタム専門"
        case .premium: "プレミアム専門"
        case .business: "商用車・法人専門"
        }
    }

    var icon: String {
        switch self {
        case .general: "car.2.fill"
        case .keiLocal: "car.side.fill"
        case .family: "figure.2.and.child.holdinghands"
        case .custom: "wrench.adjustable.fill"
        case .premium: "sparkles"
        case .business: "truck.box.fill"
        }
    }

    var summary: String {
        switch self {
        case .general: "幅広い需要に対応。突出した強みは少ない"
        case .keiLocal: "住宅街で日常の足と低維持費を訴求"
        case .family: "ミニバン・SUVと保証で家族需要を獲得"
        case .custom: "工場設備を活かして改造による付加価値を作る"
        case .premium: "都心の所得・ブランド需要を高粗利へ変える"
        case .business: "工場・幹線道路の事業者へ稼働率を販売"
        }
    }
}

enum StoreType: String, Codable, CaseIterable, Identifiable {
    case small, standard, roadside, premium, service
    var id: String { rawValue }
    var name: String {
        switch self {
        case .small: "小型販売店"
        case .standard: "標準店"
        case .roadside: "大型ロードサイド店"
        case .premium: "高級車ショールーム"
        case .service: "整備併設店"
        }
    }
    var icon: String {
        switch self {
        case .small: "storefront"
        case .standard: "storefront.fill"
        case .roadside: "building.2.crop.circle.fill"
        case .premium: "sparkles.rectangle.stack.fill"
        case .service: "wrench.and.screwdriver.fill"
        }
    }
    var capacity: Int {
        switch self { case .small: 15; case .standard: 35; case .roadside: 70; case .premium: 12; case .service: 30 }
    }
    var buildCost: Int {
        switch self { case .small: 2400; case .standard: 5200; case .roadside: 9800; case .premium: 7200; case .service: 7600 }
    }
    var monthlyFixedCost: Int {
        switch self { case .small: 105; case .standard: 220; case .roadside: 410; case .premium: 330; case .service: 340 }
    }
    var serviceQuality: Double {
        switch self { case .small: 0.85; case .standard: 1.0; case .roadside: 1.05; case .premium: 1.18; case .service: 1.30 }
    }
}

enum AcquisitionMode: String, Codable, CaseIterable, Identifiable {
    case purchase, lease
    var id: String { rawValue }
    var name: String { self == .purchase ? "購入" : "賃借" }
}

enum MapLayer: String, CaseIterable, Identifiable {
    case normal, demand, vehicleDemand, price, traffic, competition, growth, profit
    var id: String { rawValue }
    var name: String {
        switch self {
        case .normal: "通常"
        case .demand: "客足・需要"
        case .vehicleDemand: "車種別需要"
        case .price: "土地価格"
        case .traffic: "交通量"
        case .competition: "競合密度"
        case .growth: "人口成長"
        case .profit: "収益予測"
        }
    }
    var icon: String {
        switch self {
        case .normal: "map.fill"
        case .demand: "person.3.fill"
        case .vehicleDemand: "car.side.fill"
        case .price: "yensign.circle.fill"
        case .traffic: "car.2.fill"
        case .competition: "flag.2.crossed.fill"
        case .growth: "chart.line.uptrend.xyaxis"
        case .profit: "chart.bar.fill"
        }
    }
}

struct DevelopmentProject: Codable, Hashable {
    var title: String
    var monthsRemaining: Int
    var populationBoost: Int
    var trafficBoost: Double
}

enum CityEventKind: String, Codable, Hashable {
    case development, competitorEntry, competitorExit, landPrice, demand, storeGrowth, auction

    var icon: String {
        switch self {
        case .development: "building.2.crop.circle.fill"
        case .competitorEntry: "flag.fill"
        case .competitorExit: "door.left.hand.open"
        case .landPrice: "yensign.arrow.trianglehead.counterclockwise.rotate.90"
        case .demand: "person.3.fill"
        case .storeGrowth: "storefront.fill"
        case .auction: "gavel.fill"
        }
    }
}

struct CityEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let turn: Int
    let kind: CityEventKind
    let title: String
    let detail: String
    let district: DistrictKind?
    let plotID: Int?
    let isPositive: Bool

    init(turn: Int, kind: CityEventKind, title: String, detail: String, district: DistrictKind? = nil, plotID: Int? = nil, isPositive: Bool = true) {
        id = UUID()
        self.turn = turn
        self.kind = kind
        self.title = title
        self.detail = detail
        self.district = district
        self.plotID = plotID
        self.isPositive = isPositive
    }
}

struct District: Identifiable, Codable, Hashable {
    let kind: DistrictKind
    var population: Int
    var incomeIndex: Double
    var trafficIndex: Double
    var growthRate: Double
    var competition: Double
    var demands: [VehicleCategory: Double]
    var id: DistrictKind { kind }
}

enum PlotOccupant: Codable, Hashable {
    case available
    case player(storeID: UUID)
    case competitor(name: String)
    case unavailable
}

struct LandPlot: Identifiable, Codable, Hashable {
    let id: Int
    let district: DistrictKind
    let localNumber: Int
    let area: Int
    var visibility: Double
    let access: Double
    let traffic: Double
    var price: Int
    var monthlyRent: Int
    var growth: Double
    var occupant: PlotOccupant
    var isForLease: Bool
    var isForSale: Bool
    var lastPriceChange: Double = 0
    var development: DevelopmentProject? = nil
}

struct InventoryBatch: Identifiable, Codable, Hashable {
    let id: UUID
    var category: VehicleCategory
    var count: Int
    var averageCost: Int
    var quality: Double

    init(category: VehicleCategory, count: Int, averageCost: Int? = nil, quality: Double = 0.75) {
        id = UUID()
        self.category = category
        self.count = count
        self.averageCost = averageCost ?? category.purchaseCost
        self.quality = quality
    }
}

enum AuctionVenue: String, Codable, CaseIterable, Identifiable {
    case east, port, premium
    var id: String { rawValue }

    var name: String {
        switch self {
        case .east: "東部オートオークション"
        case .port: "湾岸業販センター"
        case .premium: "都心プレミアAA"
        }
    }
    var specialty: String {
        switch self {
        case .east: "軽・コンパクト"
        case .port: "商用車・SUV"
        case .premium: "高級・輸入車"
        }
    }
    var fee: Int { switch self { case .east: 7; case .port: 9; case .premium: 16 } }
    var shippingCost: Int { switch self { case .east: 5; case .port: 12; case .premium: 18 } }
    var shippingMonths: Int { switch self { case .east: 1; case .port: 1; case .premium: 2 } }
    var tint: Color { switch self { case .east: .indigo; case .port: .teal; case .premium: .purple } }
}

struct AuctionListing: Identifiable, Codable, Hashable {
    let id: UUID
    let venue: AuctionVenue
    let category: VehicleCategory
    let modelYear: Int
    let mileage: Int
    let quality: Double
    let reservePrice: Int
    let marketPrice: Int
    let seller: String
}

struct BidReservation: Identifiable, Codable, Hashable {
    let id: UUID
    let listingID: UUID
    let storeID: UUID
    var maxPrice: Int
}

enum ProcurementSource: String, Codable, Hashable {
    case auction, dealerTrade, fleetPurchase
    var name: String {
        switch self { case .auction: "オークション"; case .dealerTrade: "業者間取引"; case .fleetPurchase: "法人一括仕入れ" }
    }
}

struct InboundShipment: Identifiable, Codable, Hashable {
    let id: UUID
    let storeID: UUID
    let source: ProcurementSource
    let category: VehicleCategory
    let count: Int
    let unitCost: Int
    let quality: Double
    var monthsRemaining: Int
}

struct AuctionConsignment: Identifiable, Codable, Hashable {
    let id: UUID
    let storeID: UUID
    let venue: AuctionVenue
    let category: VehicleCategory
    let count: Int
    let expectedUnitPrice: Int
    var monthsRemaining: Int
}

struct Store: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let plotID: Int
    var type: StoreType
    var acquisition: AcquisitionMode
    var focus: CustomerFocus
    var concept: StoreConcept
    var inventory: [InventoryBatch]
    var staff: Int
    var advertising: Int
    var priceIndex: Double
    var reputation: Double
    var serviceAllocation: Double
    var delegateStaff: Bool
    var delegatePricing: Bool
    var delegateMarketing: Bool
    var delegateService: Bool
    var lastSales: Int
    var lastRevenue: Int
    var lastProfit: Int
    var satisfaction: Int
    var causes: [ResultCause]

    init(name: String, plotID: Int, type: StoreType, acquisition: AcquisitionMode, focus: CustomerFocus, concept: StoreConcept = .general, inventory: [InventoryBatch], staff: Int = 4) {
        id = UUID()
        self.name = name
        self.plotID = plotID
        self.type = type
        self.acquisition = acquisition
        self.focus = focus
        self.concept = concept
        self.inventory = inventory
        self.staff = staff
        advertising = 80
        priceIndex = 1.0
        reputation = 0.65
        serviceAllocation = 0.35
        delegateStaff = false
        delegatePricing = false
        delegateMarketing = false
        delegateService = false
        lastSales = 0
        lastRevenue = 0
        lastProfit = 0
        satisfaction = 70
        causes = []
    }

    var inventoryCount: Int { inventory.reduce(0) { $0 + $1.count } }
    var visualTier: Int {
        let profitTier = lastProfit >= 500 ? 2 : lastProfit >= 120 ? 1 : 0
        let reputationTier = reputation >= 0.95 ? 1 : 0
        return min(4, max(1, 1 + profitTier + reputationTier))
    }
}

struct ResultCause: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let effect: Double
    init(_ title: String, _ effect: Double) { id = UUID(); self.title = title; self.effect = effect }
}

struct Competitor: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var strategy: String
    var colorHex: String
    var cash: Int
    var plotIDs: [Int]
    var strength: Double
    var category: VehicleCategory
}

struct MonthlyReport: Identifiable, Codable, Hashable {
    let id: UUID
    let year: Int
    let month: Int
    let sales: Int
    let revenue: Int
    let grossProfit: Int
    let operatingProfit: Int
    let cashChange: Int
    let headline: String
    let notes: [String]
}

struct PurchaseCase: Identifiable, Codable, Hashable {
    let id: UUID
    let storeID: UUID
    let category: VehicleCategory
    let modelYear: Int
    let mileage: Int
    var exterior: Int
    var interior: Int
    var mechanical: Int
    let askingPrice: Int
    let appraisedPrice: Int
    let repairCost: Int
    let expectedSalePrice: Int
    let expectedDays: Int
    let demand: Double
    var appraisalAccuracy: Int

    var expectedGrossProfit: Int { expectedSalePrice - askingPrice - repairCost }
    var conditionScore: Int { (exterior + interior + mechanical) / 3 }
}

enum StartupPlan: String, CaseIterable, Identifiable {
    case family, discount, quality
    var id: String { rawValue }
    var name: String {
        switch self { case .family: "郊外ファミリー店"; case .discount: "工業地区の格安店"; case .quality: "小型高品質店" }
    }
    var tagline: String {
        switch self {
        case .family: "安定した家族需要をつかむ王道プラン"
        case .discount: "低い固定費と価格競争力で勝負"
        case .quality: "目利きと高粗利でブランドを育てる"
        }
    }
    var icon: String { switch self { case .family: "figure.2.and.child.holdinghands"; case .discount: "tag.fill"; case .quality: "sparkles" } }
}

struct FinanceSnapshot: Codable, Hashable {
    var revenue: Int = 0
    var costOfSales: Int = 0
    var personnel: Int = 0
    var rent: Int = 0
    var advertising: Int = 0
    var depreciation: Int = 0
    var operatingProfit: Int = 0
    var landAssets: Int = 0
    var buildingAssets: Int = 0
    var inventoryAssets: Int = 0
    var debt: Int = 0
    var operatingCF: Int = 0
    var investingCF: Int = 0
    var financingCF: Int = 0
}
