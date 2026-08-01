import Foundation
import SwiftUI

struct SimulationVehicleTransaction {
    enum Kind {
        case acquired
        case sold
    }

    let turn: Int
    let kind: Kind
    let storeID: UUID
    let source: ProcurementSource?
    let category: VehicleCategory
    let count: Int
    let revenue: Int
    let cost: Int
    let purchaseOrigin: PurchaseCaseOrigin?

    init(
        turn: Int,
        kind: Kind,
        storeID: UUID,
        source: ProcurementSource?,
        category: VehicleCategory,
        count: Int,
        revenue: Int,
        cost: Int,
        purchaseOrigin: PurchaseCaseOrigin? = nil
    ) {
        self.turn = turn
        self.kind = kind
        self.storeID = storeID
        self.source = source
        self.category = category
        self.count = count
        self.revenue = revenue
        self.cost = cost
        self.purchaseOrigin = purchaseOrigin
    }
}

enum WeeklyPresentationStage: String, Identifiable {
    case weeklyReport
    case monthlyPL
    case newspaper

    var id: String { rawValue }
}

@MainActor
final class GameEngine: ObservableObject {
    @Published var hasStarted = false
    @Published var year = 2026
    @Published var month = 1
    @Published var weekOfMonth = 1
    @Published var turn = 0
    @Published var cash = 6_500
    @Published var debt = 3_000
    @Published var companyValue = 3_500
    @Published var hasSaveData = false
    @Published var districts: [District] = []
    @Published var plots: [LandPlot] = []
    @Published var stores: [Store] = []
    @Published var competitors: [Competitor] = []
    @Published var reports: [MonthlyReport] = []
    @Published var monthlyReports: [MonthlyPLReport] = []
    @Published var purchaseCases: [PurchaseCase] = []
    @Published var customerCustomizationOrders: [CustomerCustomizationOrder] = []
    @Published var buyerLeads: [BuyerLead] = []
    @Published var cityEvents: [CityEvent] = []
    @Published var auctionListings: [AuctionListing] = []
    @Published var bidReservations: [BidReservation] = []
    @Published var auctionBidResults: [AuctionBidResult] = []
    @Published var networkAuctionListings: [NetworkAuctionListing] = []
    @Published var networkAuctionBidReservations: [NetworkAuctionBidReservation] = []
    @Published var networkAuctionBidResults: [NetworkAuctionBidResult] = []
    @Published var procurementInstructions: [ProcurementInstruction] = []
    @Published var competitorAuctionPurchases: [CompetitorAuctionPurchase] = []
    @Published var inboundShipments: [InboundShipment] = []
    @Published var auctionConsignments: [AuctionConsignment] = []
    @Published var pendingCustomerClaims: [PendingCustomerClaim] = []
    @Published var finance = FinanceSnapshot()
    @Published var lastReport: MonthlyReport?
    @Published var lastMonthlyReport: MonthlyPLReport?
    @Published var weeklyPresentationStage: WeeklyPresentationStage?
    @Published var gameOver = false
    @Published var tutorialStep: TutorialStep?
    @Published var tutorialPlotID: Int?
    /// ガイド（浜岡ナオ）のレッスン進行。案内は助言のみで、操作を禁止しません。
    @Published var guide = GuideProgress.dismissed
    /// ガイドから店舗画面の特定タブへ誘導するためのリクエスト。
    @Published var guideStorePanelRequest: GuideStorePanel?
    @Published var unlockedFeatures: Set<String> = ["仕入", "価格設定", "出店"]
    @Published var regionalOperations: [RegionalOperation] = []
    @Published var intercityShipments: [IntercityShipment] = []
    @Published var nationalBrandStrength: Double = 0.48
    @Published private(set) var gasolinePrice: Double = 155
    @Published private(set) var nikkeiAverage: Double = 60_000
    @Published private(set) var classicMarketIndex: Double = 1.0
    @Published private(set) var marketDemandIndex: Double = 1.0
    @Published var activeMarketShocks: [ActiveMarketShock] = []
    @Published var careerStatistics = CareerStatistics()
    @Published var priceWarChallenges: [PriceWarChallenge] = []
    @Published var financialDistressWeeks = 0
    @Published var companyExpertise = BusinessExpertise()
    @Published var corporateOpportunities: [CorporateOpportunity] = []
    @Published var segmentMarkets: [MarketSegmentKey: SegmentMarketState] = [:]
    @Published var segmentTrends: [SegmentTrend] = []
    @Published private(set) var simulationSeed = 1
    var simulationTransactionHandler: ((SimulationVehicleTransaction) -> Void)?
    private var openSegmentWeek: [MarketSegmentKey: SegmentWeekRecord] = [:]
    private var procurementWeekActivities: [ProcurementActivityKey: ProcurementWeekActivity] = [:]
    private var competitorAuctionSlotsRemaining: [UUID: Int] = [:]
    private var competitorAuctionBudgetRemaining: [UUID: Int] = [:]
    private var weeklyPresentationQueue: [WeeklyPresentationStage] = []
    private let persistenceEnabled: Bool

    let maxTurns = 480

    private struct ProcurementActivityKey: Hashable {
        let instructionID: UUID
        let source: ProcurementSource?
    }

    private struct ProcurementWeekActivity {
        var acquiredCount = 0
        var spent = 0
        var reserved = 0
        var results: [String] = []
    }

    private struct SaveData: Codable {
        /// Saves are bound to the city map that produced their plots; a save
        /// from another map generation must not be restored.
        var mapID: String?
        let year: Int
        let month: Int
        let weekOfMonth: Int
        let turn: Int
        let cash: Int
        let debt: Int
        let companyValue: Int
        let districts: [District]
        let plots: [LandPlot]
        let stores: [Store]
        let competitors: [Competitor]
        let reports: [MonthlyReport]
        let monthlyReports: [MonthlyPLReport]
        let purchaseCases: [PurchaseCase]
        let customerCustomizationOrders: [CustomerCustomizationOrder]
        let buyerLeads: [BuyerLead]
        let cityEvents: [CityEvent]
        let auctionListings: [AuctionListing]
        let bidReservations: [BidReservation]
        let auctionBidResults: [AuctionBidResult]
        let networkAuctionListings: [NetworkAuctionListing]
        let networkAuctionBidReservations: [NetworkAuctionBidReservation]
        let networkAuctionBidResults: [NetworkAuctionBidResult]
        let procurementInstructions: [ProcurementInstruction]
        let competitorAuctionPurchases: [CompetitorAuctionPurchase]
        let inboundShipments: [InboundShipment]
        let auctionConsignments: [AuctionConsignment]
        let pendingCustomerClaims: [PendingCustomerClaim]
        let finance: FinanceSnapshot
        let unlockedFeatures: Set<String>
        let regionalOperations: [RegionalOperation]
        let intercityShipments: [IntercityShipment]
        let nationalBrandStrength: Double
        let gasolinePrice: Double
        let nikkeiAverage: Double
        let classicMarketIndex: Double
        let marketDemandIndex: Double
        let gasolineTrendTarget: Double
        let nikkeiTrendTarget: Double
        let demandTrendTarget: Double
        let gasolineMomentum: Double
        let nikkeiMomentum: Double
        let demandMomentum: Double
        let activeMarketShocks: [ActiveMarketShock]
        let careerStatistics: CareerStatistics
        let priceWarChallenges: [PriceWarChallenge]
        let tutorialStep: TutorialStep?
        let tutorialPlotID: Int?
        let financialDistressWeeks: Int
        let companyExpertise: BusinessExpertise
        let corporateOpportunities: [CorporateOpportunity]
        let segmentMarkets: [MarketSegmentKey: SegmentMarketState]
        let segmentTrends: [SegmentTrend]
        let simulationSeed: Int
        let openSegmentWeek: [MarketSegmentKey: SegmentWeekRecord]
        let guide: GuideProgress
    }

    private struct RegionalMonthResult {
        var sales = 0
        var revenue = 0
        var costOfSales = 0
        var fixedCosts = 0
        var advertising = 0
    }

    private struct AutomaticSaleResult {
        var sales = 0
        var revenue = 0
        var costOfSales = 0
        var cashCollected = 0
        var commission = 0
        var tradeIns = 0
        var attempts = 0
    }

    private struct UsedVehicleProfile {
        let modelYear: Int
        let mileage: Int
        let quality: Double
    }

    private struct RemovedInventory {
        let averageCost: Int
        let quality: Double
        let modelID: String
        let modelYear: Int
        let mileage: Int
        let acquiredTurn: Int
        let vehicleIssue: VehicleIssueRecord?
    }

    private static let saveKey = "UsedCarCity.save.v49"
    private static let gasolineBaseline = 155.0
    private static let gasolineRange = 105.0...205.0
    private static let nikkeiBaseline = 60_000.0
    private static let nikkeiRange = 15_000.0...120_000.0
    private var gasolineTrendTarget = 155.0
    private var nikkeiTrendTarget = 60_000.0
    private var demandTrendTarget = 1.0
    private var gasolineMomentum = 0.0
    private var nikkeiMomentum = 0.0
    private var demandMomentum = 0.0
    private static let managerCandidates = [
        StoreManager(name: "佐藤 美咲", staffingAbility: 78, salesAbility: 66, procurementAbility: 72, marketingAbility: 84, serviceAbility: 71, monthlySalary: 58),
        StoreManager(name: "高橋 健太", staffingAbility: 62, salesAbility: 88, procurementAbility: 81, marketingAbility: 58, serviceAbility: 75, monthlySalary: 59),
        StoreManager(name: "鈴木 菜月", staffingAbility: 70, salesAbility: 72, procurementAbility: 76, marketingAbility: 76, serviceAbility: 82, monthlySalary: 61),
        StoreManager(name: "伊藤 拓海", staffingAbility: 55, salesAbility: 64, procurementAbility: 59, marketingAbility: 68, serviceAbility: 59, monthlySalary: 49),
        StoreManager(name: "田中 玲奈", staffingAbility: 86, salesAbility: 80, procurementAbility: 84, marketingAbility: 73, serviceAbility: 88, monthlySalary: 66)
    ]
    private static let employeeRoster = [
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, name: "山田 悠斗", salesSkill: 62, appraisalSkill: 48, procurementSkill: 55, marketingSkill: 58, serviceSkill: 45, marketResearchSkill: 52, compensation: .fixed),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, name: "小林 美月", salesSkill: 74, appraisalSkill: 55, procurementSkill: 61, marketingSkill: 70, serviceSkill: 48, marketResearchSkill: 68, compensation: .balanced),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, name: "中村 海斗", salesSkill: 51, appraisalSkill: 76, procurementSkill: 79, marketingSkill: 46, serviceSkill: 69, marketResearchSkill: 72, compensation: .fixed),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, name: "加藤 さくら", salesSkill: 68, appraisalSkill: 69, procurementSkill: 70, marketingSkill: 66, serviceSkill: 64, marketResearchSkill: 73, compensation: .balanced),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!, name: "吉田 颯太", salesSkill: 45, appraisalSkill: 61, procurementSkill: 66, marketingSkill: 52, serviceSkill: 74, marketResearchSkill: 55, compensation: .fixed),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!, name: "佐々木 結衣", salesSkill: 80, appraisalSkill: 63, procurementSkill: 68, marketingSkill: 77, serviceSkill: 55, marketResearchSkill: 74, compensation: .performance),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!, name: "山口 陸", salesSkill: 57, appraisalSkill: 83, procurementSkill: 86, marketingSkill: 51, serviceSkill: 78, marketResearchSkill: 79, compensation: .fixed),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!, name: "松本 葵", salesSkill: 71, appraisalSkill: 73, procurementSkill: 72, marketingSkill: 75, serviceSkill: 68, marketResearchSkill: 81, compensation: .balanced),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000009")!, name: "井上 陽菜", salesSkill: 54, appraisalSkill: 52, procurementSkill: 47, marketingSkill: 82, serviceSkill: 50, marketResearchSkill: 71, compensation: .fixed),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000010")!, name: "木村 蓮", salesSkill: 77, appraisalSkill: 46, procurementSkill: 72, marketingSkill: 61, serviceSkill: 43, marketResearchSkill: 58, compensation: .performance),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000011")!, name: "清水 凛", salesSkill: 49, appraisalSkill: 79, procurementSkill: 73, marketingSkill: 55, serviceSkill: 88, marketResearchSkill: 68, compensation: .fixed),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000012")!, name: "林 直樹", salesSkill: 66, appraisalSkill: 65, procurementSkill: 68, marketingSkill: 64, serviceSkill: 67, marketResearchSkill: 66, compensation: .balanced),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000013")!, name: "斎藤 真央", salesSkill: 84, appraisalSkill: 72, procurementSkill: 77, marketingSkill: 80, serviceSkill: 60, marketResearchSkill: 83, compensation: .performance),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000014")!, name: "森 大地", salesSkill: 59, appraisalSkill: 86, procurementSkill: 88, marketingSkill: 48, serviceSkill: 82, marketResearchSkill: 84, compensation: .fixed),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000015")!, name: "池田 彩", salesSkill: 73, appraisalSkill: 81, procurementSkill: 80, marketingSkill: 78, serviceSkill: 76, marketResearchSkill: 86, compensation: .balanced),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000016")!, name: "橋本 翼", salesSkill: 88, appraisalSkill: 58, procurementSkill: 82, marketingSkill: 69, serviceSkill: 52, marketResearchSkill: 76, compensation: .performance),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000017")!, name: "阿部 千尋", salesSkill: 64, appraisalSkill: 88, procurementSkill: 90, marketingSkill: 60, serviceSkill: 91, marketResearchSkill: 85, compensation: .fixed),
        StoreEmployee(id: UUID(uuidString: "10000000-0000-0000-0000-000000000018")!, name: "石川 遥", salesSkill: 82, appraisalSkill: 84, procurementSkill: 83, marketingSkill: 86, serviceSkill: 80, marketResearchSkill: 92, compensation: .balanced)
    ]
    private var pendingSave: SaveData?

    init(persistenceEnabled: Bool = true) {
        self.persistenceEnabled = persistenceEnabled
        districts = Self.makeDistricts()
        plots = Self.makePlots()
        competitors = Self.makeCompetitors()
        placeCompetitors()
        if persistenceEnabled,
           let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data),
           saved.mapID == CityMapDefinition.suihama.id {
            pendingSave = saved
            hasSaveData = true
        }
#if DEBUG
        if CommandLine.arguments.contains("-demo-tutorial-purchase"), !hasStarted {
            startNewGame()
            if let plot = foundingCandidatePlots.first(where: { $0.district == .suburb }) ?? recommendedFoundingPlot {
                selectFoundingPlot(plot.id)
                _ = buildStore(
                    on: plot,
                    type: .standard,
                    mode: .lease,
                    marketPolicy: StoreMarketPolicy(targetPurpose: .family),
                    facilities: [.kidsSpace],
                    loanAmount: StoreFacility.kidsSpace.installationCost
                )
            }
        } else if CommandLine.arguments.contains("-demo-tutorial"), !hasStarted {
            startNewGame()
        } else if (CommandLine.arguments.contains("-demo-map") || CommandLine.arguments.contains("-demo-map-zoom") || CommandLine.arguments.contains("-demo-store") || CommandLine.arguments.contains("-demo-team") || CommandLine.arguments.contains("-demo-proposal") || CommandLine.arguments.contains("-demo-catalog") || CommandLine.arguments.contains("-demo-auction") || CommandLine.arguments.contains("-demo-workshop") || CommandLine.arguments.contains("-demo-hq") || CommandLine.arguments.contains("-demo-goals") || CommandLine.arguments.contains("-demo-ending") || CommandLine.arguments.contains("-demo-competition") || CommandLine.arguments.contains("-demo-construction") || CommandLine.arguments.contains("-demo-national")) && !hasStarted {
            prepareDemoCompany()
        }
        if CommandLine.arguments.contains("-demo-goals") {
            companyValue = 32_000
            careerStatistics.totalSales = 88
            careerStatistics.totalRevenue = 24_600
            careerStatistics.bestWeeklySales = 7
            careerStatistics.profitableWeeks = 46
            careerStatistics.salesByYear[year] = 88
            careerStatistics.completedMilestones = [.salesFoundation]
        }
        if CommandLine.arguments.contains("-demo-ending") {
            companyValue = 82_000
            nationalBrandStrength = 1.18
            careerStatistics.totalSales = 516
            careerStatistics.totalRevenue = 168_400
            careerStatistics.bestWeeklySales = 12
            careerStatistics.profitableWeeks = 326
            careerStatistics.salesByYear[year] = 112
            careerStatistics.completedMilestones = Set(BusinessMilestoneID.allCases)
            stores.indices.forEach { stores[$0].reputation = 1.12 }
        }
        if CommandLine.arguments.contains("-demo-competition"),
           let store = stores.first,
           let district = plot(id: store.plotID)?.district {
            cash = 20_000
            turn = 25
            let aggressor = competitors.first(where: { competitor in
                competitor.plotIDs.contains { plot(id: $0)?.district == district }
            }) ?? competitors[0]
            priceWarChallenges = [PriceWarChallenge(
                competitorID: aggressor.id,
                district: district,
                startedTurn: turn,
                expiresTurn: turn + 4,
                intensity: 1.08
            )]
            competitors[0].strength = 0.90
        }
        if CommandLine.arguments.contains("-demo-team"), let storeID = stores.first?.id,
           stores.first?.employees.isEmpty == true {
            _ = hireStaff(for: storeID)
            _ = hireStaff(for: storeID)
        }
        if CommandLine.arguments.contains("-demo-construction"), stores.count == 1,
           let plot = plots.first(where: { $0.district == .highway && isAvailable($0.occupant) && $0.development == nil }) {
            _ = buildStore(on: plot, type: .roadside, mode: .lease, marketPolicy: StoreMarketPolicy(priorityCategories: [.minivan, .pickup], targetPurpose: .corporate), facilities: [.corporateDesk], loanAmount: 100_000)
        }
        if CommandLine.arguments.contains("-demo-national"), regionalOperations.isEmpty {
            companyValue = 120_000
            cash = 180_000
            _ = establishRegionalOffice(in: "shinonome")
            _ = openFranchise(in: "shinonome")
            _ = acquireLocalDealer(in: "shinonome")
            _ = establishRegionalOffice(in: "naniwa")
            _ = openFranchise(in: "naniwa")
        }
#endif
    }

    var progress: Double { Double(turn) / Double(maxTurns) }
    var totalInventory: Int { stores.reduce(0) { $0 + $1.inventoryCount } }

    func canSelectFoundingInventory(storeID: UUID) -> Bool {
        turn == 0
            && tutorialStep == .purchaseInventory
            && stores.count == 1
            && stores.first?.id == storeID
            && totalInventory == 0
    }
    var gasolinePricePerLiter: Int { Int(gasolinePrice.rounded()) }
    var nikkeiAverageYen: Int { Int(nikkeiAverage.rounded()) }
    var marketDemandPercentage: Int { Int((marketDemandIndex * 100).rounded()) }
    var customerTrafficIndex: Double {
        marketDemandIndex * min(1.45, max(0.65, pow(economicIndex, 1.65)))
    }
    var customerTrafficPercentage: Int { Int((customerTrafficIndex * 100).rounded()) }

    /// Existing vehicle-demand calculations continue to consume a normalized
    /// value while the player sees the familiar yen-per-litre market price.
    var fuelPriceIndex: Double {
        get { gasolinePrice / Self.gasolineBaseline }
        set { gasolinePrice = min(Self.gasolineRange.upperBound, max(Self.gasolineRange.lowerBound, newValue * Self.gasolineBaseline)) }
    }

    /// Maps the visible Nikkei average onto the deliberately narrower gameplay
    /// range used by pricing, financing and customer simulations.
    var economicIndex: Double {
        get {
            if nikkeiAverage <= Self.nikkeiBaseline {
                return 0.72 + (nikkeiAverage - Self.nikkeiRange.lowerBound) / (Self.nikkeiBaseline - Self.nikkeiRange.lowerBound) * 0.28
            }
            return 1.0 + (nikkeiAverage - Self.nikkeiBaseline) / (Self.nikkeiRange.upperBound - Self.nikkeiBaseline) * 0.28
        }
        set {
            let normalized = min(1.28, max(0.72, newValue))
            if normalized <= 1 {
                nikkeiAverage = Self.nikkeiRange.lowerBound + (normalized - 0.72) / 0.28 * (Self.nikkeiBaseline - Self.nikkeiRange.lowerBound)
            } else {
                nikkeiAverage = Self.nikkeiBaseline + (normalized - 1) / 0.28 * (Self.nikkeiRange.upperBound - Self.nikkeiBaseline)
            }
        }
    }
    var availableVehicleCatalog: [VehicleCatalogEntry] {
        VehicleCatalog.available(through: turn).sorted {
            if $0.launchTurn != $1.launchTurn { return $0.launchTurn > $1.launchTurn }
            return $0.fullName < $1.fullName
        }
    }
    func availableOrigins(for category: VehicleCategory) -> Set<VehicleOrigin> {
        VehicleCatalog.availableOrigins(for: category, through: turn)
    }

    func hasAvailableVehicle(category: VehicleCategory, origin: VehicleOrigin?) -> Bool {
        !VehicleCatalog.available(category: category, origin: origin, through: turn).isEmpty
    }
    var recentNewVehicleReleases: [VehicleCatalogEntry] {
        VehicleCatalog.releasedNewCars(through: turn)
            .filter { $0.launchTurn > max(0, turn - 16) }
            .sorted { $0.launchTurn > $1.launchTurn }
    }
    var newCarsAwaitingUsedMarket: [VehicleCatalogEntry] {
        VehicleCatalog.releasedNewCars(through: turn)
            .filter { $0.usedMarketTurn > turn && !$0.isRareClassic }
            .sorted { $0.usedMarketTurn < $1.usedMarketTurn }
    }
    var nextNewVehicleRelease: VehicleCatalogEntry? {
        VehicleCatalog.all.filter { $0.launchTurn > turn }.min { $0.launchTurn < $1.launchTurn }
    }
    var currentDistrictsByKind: [DistrictKind: District] { Dictionary(uniqueKeysWithValues: districts.map { ($0.kind, $0) }) }
    var nationalCities: [NationalCity] { Self.makeNationalCities() }
    /// 創業（1店舗目の開店）がまだ終わっていない状態。
    var isFoundingPhase: Bool { stores.isEmpty }

    var leadingDistricts: [DistrictKind] {
        DistrictKind.allCases.filter { kind in
            let ownStores = stores.filter { $0.isOperational && plot(id: $0.plotID)?.district == kind }
            guard !ownStores.isEmpty else { return false }
            let ownShare = ownStores.reduce(0.0) { $0 + marketShare(for: $1) }
            let strongestRival = competitors.map { competitorMarketShare($0, in: kind) }.max() ?? 0
            return ownShare >= 0.34 && ownShare > strongestRival
        }
    }

    var milestoneStatuses: [MilestoneStatus] {
        let completed = careerStatistics.completedMilestones
        return [
            MilestoneStatus(id: .salesFoundation, current: careerStatistics.totalSales, target: 25, isCompleted: completed.contains(.salesFoundation)),
            MilestoneStatus(id: .annualSales100, current: careerStatistics.bestAnnualSales, target: 100, isCompleted: completed.contains(.annualSales100)),
            MilestoneStatus(id: .districtLeader, current: leadingDistricts.isEmpty ? 0 : 1, target: 1, isCompleted: completed.contains(.districtLeader)),
            MilestoneStatus(id: .nationalExpansion, current: companyValue, target: 45_000, isCompleted: completed.contains(.nationalExpansion)),
            MilestoneStatus(id: .lifetimeSales500, current: careerStatistics.totalSales, target: 500, isCompleted: completed.contains(.lifetimeSales500))
        ]
    }

    var endingEvaluation: EndingEvaluation {
        let assetScore = min(45, max(0, Int(Double(companyValue) / 100_000.0 * 45.0)))
        let nationalComponent = min(20, max(0, Int((nationalBrandStrength - 0.48) / 0.97 * 20.0)))
        let averageReputation = stores.isEmpty ? 0.65 : stores.reduce(0.0) { $0 + $1.reputation } / Double(stores.count)
        let localComponent = min(10, max(0, Int((averageReputation - 0.65) / 0.60 * 10.0)))
        let brandScore = nationalComponent + localComponent
        let salesScore = min(25, max(0, careerStatistics.totalSales / 20))
        let total = min(100, assetScore + brandScore + salesScore)
        let rank: EndingRank
        switch total {
        case 85...: rank = .s
        case 70...: rank = .a
        case 55...: rank = .b
        case 35...: rank = .c
        default: rank = .d
        }
        return EndingEvaluation(rank: rank, totalScore: total, assetScore: assetScore, brandScore: brandScore, salesScore: salesScore)
    }

    var milestoneCreditBonus: Int {
        careerStatistics.completedMilestones.contains(.annualSales100) ? 10_000 : 0
    }

    var activePriceWars: [PriceWarChallenge] {
        priceWarChallenges.filter { $0.isActive(at: turn) }
    }

    func competitorName(for competitorID: UUID) -> String {
        competitors.first(where: { $0.id == competitorID })?.name ?? "競合企業"
    }

    func bestCompetitorSaleOffer(
        category: VehicleCategory,
        purpose: CustomerPurpose,
        district: DistrictKind,
        productKind: MarketProductKind = .standard,
        desiredGrade: SpecialtyProductGrade? = nil
    ) -> CompetitorOfferBenchmark? {
        competitors.compactMap { competitor -> CompetitorOfferBenchmark? in
            let candidates = competitor.branches
                .filter { plot(id: $0.plotID)?.district == district }
                .flatMap(\.inventory)
                .filter {
                    $0.category == category
                        && $0.count > 0
                        && marketProductMatches(actual: $0.marketProductKind, desired: productKind)
                        && gradeMatches(actual: $0.productGrade, desired: desiredGrade)
                }
            guard let bucket = candidates.min(by: {
                Double($0.averageCost) * $0.averageQuality < Double($1.averageCost) * $1.averageQuality
            }), let branch = competitor.branches.first(where: {
                plot(id: $0.plotID)?.district == district && $0.inventory.contains(where: { $0.id == bucket.id })
            }) else { return nil }
            let purposeFactor = bucket.purpose == purpose ? 1.08 : 1.0
            let key = MarketSegmentKey(district: district, category: category, purpose: purpose, productKind: productKind)
            let price = max(25, Int(Double(bucket.averageCost)
                * (1.22 + competitor.strength * 0.10)
                * branch.priceIndex
                * purposeFactor
                * segmentWillingnessFactor(
                    for: key,
                    productState: bucket.productState,
                    grade: bucket.productGrade
                )))
            let cappedPrice = bucket.marketProductKind.supportsGrades
                ? min(price, competitorSpecialtyPriceCap(for: bucket))
                : price
            return CompetitorOfferBenchmark(competitorID: competitor.id, price: cappedPrice, quality: bucket.averageQuality, category: category, purpose: bucket.purpose, productKind: bucket.marketProductKind, productGrade: bucket.productGrade)
        }.min(by: { $0.price < $1.price })
    }

    private func competitorSpecialtyPriceCap(for bucket: CompetitorInventoryBucket) -> Int {
        let approximateReferenceRetail = Double(bucket.category.purchaseCost) * 1.40
        return Int(approximateReferenceRetail * specialtyPriceCeiling(
            for: bucket.marketProductKind,
            productState: bucket.productState,
            grade: bucket.productGrade
        ))
    }

    func bestCompetitorPurchaseOffer(category: VehicleCategory, condition: VehicleConditionProfile, fault: MechanicalFaultSeverity, district: DistrictKind) -> CompetitorOfferBenchmark? {
        competitors.compactMap { competitor -> CompetitorOfferBenchmark? in
            guard let branch = competitor.branches.first(where: {
                plot(id: $0.plotID)?.district == district
                    && $0.inventoryCount < $0.capacity
                    && $0.marketPolicy.acceptedConditions.contains(condition.band)
            }) else { return nil }
            let conditionFactor = 0.45 + condition.quality * 0.55
            let faultFactor: Double = switch fault { case .none: 1; case .minor: 0.78; case .major: 0.48; case .immobile: 0.25 }
            let specialty = branch.marketPolicy.priorityCategories.contains(category) ? 1.05 : 0.94
            let skill = 0.88 + Double(competitor.procurementAbility) / 1_000
            let price = max(10, Int(Double(category.purchaseCost) * conditionFactor * faultFactor * specialty * skill))
            guard competitor.cash >= price else { return nil }
            return CompetitorOfferBenchmark(competitorID: competitor.id, price: price, quality: condition.quality, category: category, purpose: branch.marketPolicy.targetPurpose)
        }.max(by: { $0.price < $1.price })
    }

    func priceWarResponseCost(_ response: PriceWarResponse, challengeID: UUID) -> Int {
        guard let challenge = priceWarChallenges.first(where: { $0.id == challengeID }) else { return 0 }
        let storeCount = stores.filter { plot(id: $0.plotID)?.district == challenge.district }.count
        switch response {
        case .counterSale: return 80 + storeCount * 25
        case .brandDefense: return 140 + storeCount * 35
        }
    }

    func priceWarCloseAdjustment(in district: DistrictKind) -> Double {
        guard let challenge = activePriceWars.first(where: { $0.district == district }) else { return 0 }
        switch challenge.response {
        case .none: return -0.12 * challenge.intensity
        case .counterSale: return 0.04
        case .brandDefense: return 0.02
        }
    }

    private func competitivePriceFactor(in district: DistrictKind) -> Double {
        guard let response = activePriceWars.first(where: { $0.district == district })?.response else { return 1 }
        return response == .counterSale ? 0.96 : 1
    }

    private func competitiveStoreMarketFactor(in district: DistrictKind) -> Double {
        guard let challenge = activePriceWars.first(where: { $0.district == district }) else { return 1 }
        switch challenge.response {
        case .none: return max(0.76, 1 - challenge.intensity * 0.16)
        case .counterSale: return 1.10
        case .brandDefense: return 1.06
        }
    }

    private func competitiveRivalMarketFactor(_ competitorID: UUID, in district: DistrictKind) -> Double {
        guard let challenge = activePriceWars.first(where: { $0.district == district && $0.competitorID == competitorID }) else { return 1 }
        switch challenge.response {
        case .none: return 1 + challenge.intensity * 0.18
        case .counterSale: return 1.04
        case .brandDefense: return 1.02
        }
    }

    var foundingCandidatePlots: [LandPlot] {
        DistrictKind.allCases.compactMap { kind in
            plots
                .filter { $0.district == kind && isAvailable($0.occupant) && $0.development == nil }
                .max { foundingPlotScore($0) < foundingPlotScore($1) }
        }
    }

    var recommendedFoundingPlot: LandPlot? {
        foundingCandidatePlots.max { foundingPlotScore($0) < foundingPlotScore($1) }
    }

    var saveSummary: String? {
        guard let saved = pendingSave else { return nil }
        return "\(saved.year)年\(saved.month)月 第\(saved.weekOfMonth)週・現金\(saved.cash.currency)"
    }

    private func foundingPlotScore(_ plot: LandPlot) -> Double {
        let rentEfficiency = Double(estimatedVisitors(for: plot)) / Double(max(1, plot.monthlyRent))
        let supplyCoverage = recommendedCategories(for: plot.district).prefix(3).reduce(0.0) {
            $0 + vehicleSupply($1, in: plot.district)
        } / 3.0
        return rentEfficiency * plot.visibility * plot.access * plot.traffic * (0.82 + supplyCoverage * 0.18)
    }

    func startNewGame(simulationSeed: Int? = nil) {
        beginNewGame(simulationSeed: simulationSeed)
    }

    private func beginNewGame(simulationSeed: Int? = nil) {
        resetState(removeSave: true, simulationSeed: simulationSeed)
        hasStarted = true
        cash = 6_500
        debt = 3_000
        companyValue = 3_500
        tutorialStep = .chooseLocation
        tutorialPlotID = nil
        guide = GuideProgress()
        cityEvents = plots.compactMap { plot in
            guard let project = plot.development else { return nil }
            return CityEvent(turn: 0, kind: .development, title: "\(project.title)が計画中", detail: "完成まで\(project.monthsRemaining)週間。周辺人口と交通量が増える見込みです", district: plot.district, plotID: plot.id)
        }
        generateAuctionListings()
        generateNetworkAuctionListings()
        generateCorporateOpportunities()
        recalculateAssets()
        save()
    }

    func loadGame() {
        guard let saved = pendingSave else { return }
        apply(saved)
        hasStarted = true
        if tutorialStep == .reviewFirstResult { completeTutorial() }
    }

    func returnToTitle() {
        save()
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data),
           saved.mapID == CityMapDefinition.suihama.id {
            pendingSave = saved
            hasSaveData = true
        }
        hasStarted = false
        weeklyPresentationStage = nil
        weeklyPresentationQueue = []
        gameOver = false
    }

    func resetGame(simulationSeed: Int? = nil) {
        resetState(removeSave: true, simulationSeed: simulationSeed)
    }

    private func resetState(removeSave: Bool, simulationSeed requestedSeed: Int? = nil) {
        hasStarted = false
        year = 2026; month = 1; weekOfMonth = 1; turn = 0; cash = 6_500; debt = 3_000; companyValue = 3_500
        districts = Self.makeDistricts(); plots = Self.makePlots(); competitors = Self.makeCompetitors()
        stores = []; reports = []; monthlyReports = []; purchaseCases = []; customerCustomizationOrders = []; buyerLeads = []; cityEvents = []; auctionListings = []; bidReservations = []; auctionBidResults = []; networkAuctionListings = []; networkAuctionBidReservations = []; networkAuctionBidResults = []; procurementInstructions = []; competitorAuctionPurchases = []; inboundShipments = []; auctionConsignments = []; pendingCustomerClaims = []; regionalOperations = []; intercityShipments = []; corporateOpportunities = []
        segmentMarkets = [:]; segmentTrends = []; openSegmentWeek = [:]
        competitorAuctionSlotsRemaining = [:]; competitorAuctionBudgetRemaining = [:]
        simulationSeed = requestedSeed ?? Int.random(in: 1...Int.max / 4)
        companyExpertise = BusinessExpertise()
        nationalBrandStrength = 0.48
        gasolinePrice = Self.gasolineBaseline
        nikkeiAverage = Self.nikkeiBaseline
        classicMarketIndex = 1.0
        marketDemandIndex = 1.0
        gasolineTrendTarget = Self.gasolineBaseline
        nikkeiTrendTarget = Self.nikkeiBaseline
        demandTrendTarget = 1.0
        gasolineMomentum = 0
        nikkeiMomentum = 0
        demandMomentum = 0
        activeMarketShocks = []
        careerStatistics = CareerStatistics(); priceWarChallenges = []; financialDistressWeeks = 0; finance = FinanceSnapshot(); lastReport = nil; lastMonthlyReport = nil; weeklyPresentationStage = nil; weeklyPresentationQueue = []; gameOver = false; tutorialStep = nil; tutorialPlotID = nil
        guide = .dismissed
        guideStorePanelRequest = nil
        unlockedFeatures = ["仕入", "価格設定", "出店"]
        placeCompetitors()
        if removeSave && persistenceEnabled {
            pendingSave = nil
            hasSaveData = false
            UserDefaults.standard.removeObject(forKey: Self.saveKey)
        }
    }

    func presentLatestWeeklyReport() {
        guard lastReport != nil else { return }
        weeklyPresentationQueue = []
        weeklyPresentationStage = .weeklyReport
    }

    func advanceWeeklyPresentationSequence() {
        weeklyPresentationStage = weeklyPresentationQueue.isEmpty
            ? nil
            : weeklyPresentationQueue.removeFirst()
    }

    func beginWeeklyPresentationSequence(
        includesWeeklyReport: Bool,
        includesMonthlyPL: Bool
    ) {
        var stages: [WeeklyPresentationStage] = []
        if includesWeeklyReport { stages.append(.weeklyReport) }
        if includesMonthlyPL { stages.append(.monthlyPL) }
        // 新しい週の市況は、自動週次レポート設定に関係なく必ず知らせる。
        stages.append(.newspaper)
        weeklyPresentationStage = stages.first
        weeklyPresentationQueue = Array(stages.dropFirst())
    }

    private func apply(_ saved: SaveData) {
        year = saved.year
        month = saved.month
        weekOfMonth = saved.weekOfMonth
        turn = saved.turn
        cash = saved.cash
        debt = saved.debt
        companyValue = saved.companyValue
        districts = saved.districts
        plots = saved.plots
        stores = saved.stores
        competitors = saved.competitors
        reports = saved.reports
        monthlyReports = saved.monthlyReports
        purchaseCases = saved.purchaseCases
        customerCustomizationOrders = saved.customerCustomizationOrders
        buyerLeads = saved.buyerLeads
        cityEvents = saved.cityEvents
        auctionListings = saved.auctionListings
        bidReservations = saved.bidReservations
        auctionBidResults = saved.auctionBidResults
        networkAuctionListings = saved.networkAuctionListings
        networkAuctionBidReservations = saved.networkAuctionBidReservations
        networkAuctionBidResults = saved.networkAuctionBidResults
        procurementInstructions = saved.procurementInstructions
        competitorAuctionPurchases = saved.competitorAuctionPurchases
        inboundShipments = saved.inboundShipments
        auctionConsignments = saved.auctionConsignments
        pendingCustomerClaims = saved.pendingCustomerClaims
        finance = saved.finance
        unlockedFeatures = saved.unlockedFeatures
        regionalOperations = saved.regionalOperations
        intercityShipments = saved.intercityShipments
        nationalBrandStrength = saved.nationalBrandStrength
        gasolinePrice = saved.gasolinePrice
        nikkeiAverage = saved.nikkeiAverage
        classicMarketIndex = saved.classicMarketIndex
        marketDemandIndex = saved.marketDemandIndex
        gasolineTrendTarget = saved.gasolineTrendTarget
        nikkeiTrendTarget = saved.nikkeiTrendTarget
        demandTrendTarget = saved.demandTrendTarget
        gasolineMomentum = saved.gasolineMomentum
        nikkeiMomentum = saved.nikkeiMomentum
        demandMomentum = saved.demandMomentum
        activeMarketShocks = saved.activeMarketShocks
        careerStatistics = saved.careerStatistics
        priceWarChallenges = saved.priceWarChallenges
        tutorialStep = saved.tutorialStep
        tutorialPlotID = saved.tutorialPlotID
        financialDistressWeeks = saved.financialDistressWeeks
        companyExpertise = saved.companyExpertise
        corporateOpportunities = saved.corporateOpportunities
        segmentMarkets = saved.segmentMarkets
        segmentTrends = saved.segmentTrends
        simulationSeed = saved.simulationSeed
        openSegmentWeek = saved.openSegmentWeek
        guide = saved.guide
        lastReport = reports.first
        lastMonthlyReport = monthlyReports.first
    }

    func district(for plot: LandPlot) -> District { districts.first(where: { $0.kind == plot.district })! }
    func plot(id: Int) -> LandPlot? { plots.first(where: { $0.id == id }) }
    func store(at plotID: Int) -> Store? { stores.first(where: { $0.plotIDs.contains(plotID) }) }

    /// Keeps the parcel's visible use in lockstep with the store lifecycle.
    /// The primary parcel owns the building or construction site; additional
    /// footprint parcels become engine-aligned display parking.
    private func synchronizeParcelUse(for store: Store) {
        let targetType = store.pendingType ?? store.type
        let isConstruction = store.openingMonthsRemaining != nil
            || store.renovationMonthsRemaining != nil
        for plotID in store.plotIDs {
            guard let index = plots.firstIndex(where: { $0.id == plotID }) else { continue }
            if plotID == store.plotID {
                plots[index].currentUse = isConstruction
                    ? .construction(storeID: store.id, targetAssetID: targetType.cityAssetID)
                    : .playerFacility(storeID: store.id, assetID: store.type.cityAssetID)
            } else {
                plots[index].currentUse = .displayParking(storeID: store.id)
            }
        }
    }

    var gridOccupancyIssues: [GridStoreOccupancyIssue] {
        GridStorePlacementAdapter.validate(
            plots: plots,
            stores: stores,
            map: CityMapDefinition.suihama
        )
    }

    func isFoundingCandidate(_ plot: LandPlot) -> Bool {
        foundingCandidatePlots.contains(where: { $0.id == plot.id })
    }

    func selectFoundingPlot(_ plotID: Int) {
        guard stores.isEmpty,
              let plot = plot(id: plotID), isAvailable(plot.occupant), plot.development == nil else { return }
        tutorialPlotID = plotID
        if tutorialStep == .chooseLocation || tutorialStep == .buildStore { tutorialStep = .buildStore }
        save()
    }

    /// 創業前でも空き区画なら計画に進めます。ガイドの有無で出店可否は変わりません。
    func canPlanStore(on plot: LandPlot) -> Bool {
        if !stores.isEmpty { return true }
        return isAvailable(plot.occupant) && plot.development == nil
    }

    func estimatedVisitors(for plot: LandPlot) -> Int {
        let district = district(for: plot)
        let base = Double(district.population) / 750
        return max(28, Int(base * district.trafficIndex * plot.traffic * plot.visibility * (1.15 - district.competition * 0.18)))
    }

    func weeklyBuyerPool(in kind: DistrictKind) -> Int {
        guard let district = districts.first(where: { $0.kind == kind }) else { return 0 }
        let season = [3, 9].contains(month) ? 1.12 : ([1, 8].contains(month) ? 0.92 : 1.0)
        // 大型店が十分な在庫と認知を用意できれば、週30〜40組を獲得できる市場規模にする。
        // 来店先は従来どおり評判・広告・在庫・立地によるウェイトで配分するため、
        // 成約率には手を入れず、資本と店舗力がある店だけが増えた母数を取り込める。
        let base = Double(district.population) / 2_500.0 * district.trafficIndex * season * customerTrafficIndex
        let index = DistrictKind.allCases.firstIndex(of: kind) ?? 0
        return max(0, Int((base * weeklyMarketShock(seed: turn * 149 + index * 37 + 11)).rounded()))
    }

    func weeklySellerPool(in kind: DistrictKind) -> Int {
        guard let district = districts.first(where: { $0.kind == kind }) else { return 0 }
        let activity: Double
        switch kind {
        case .downtown: activity = 0.72
        case .station: activity = 1.05
        case .emerging: activity = 0.82
        case .suburb: activity = 1.18
        case .industrial: activity = 1.15
        case .highway: activity = 1.25
        }
        let base = Double(district.population) / 3_000.0 * district.trafficIndex * activity
        let economy = min(1.45, max(0.70, 1.10 + (1 - economicIndex) * 0.85))
        let index = DistrictKind.allCases.firstIndex(of: kind) ?? 0
        return max(0, Int((base * economy * weeklyMarketShock(seed: turn * 173 + index * 43 + 29)).rounded()))
    }

    /// 能力表示を持たない箇所向けの基準値。実処理は担当者ごとの6〜12件を使う。
    var employeeWeeklyCaseCapacity: Int { 10 }
    var employeeWeeklyCaseCapacityRange: ClosedRange<Int> { 6...12 }

    func employeeWeeklyCaseCapacity(
        for employee: StoreEmployee,
        assignment: EmployeeAssignment? = nil
    ) -> Int {
        let resolvedAssignment = assignment ?? employee.assignment
        let score: Double
        switch resolvedAssignment {
        case .sales:
            score = employee.salesComposite
        case .procurement:
            score = employee.procurementComposite
        case .research:
            score = employee.researchComposite
        case .service:
            score = employee.serviceComposite
        case .unassigned:
            score = Double(employee.overallSkill)
        }
        switch score {
        case ..<45: return 6
        case ..<60: return 8
        case ..<75: return 10
        case ..<88: return 11
        default: return 12
        }
    }

    func weeklyOpportunityCapacity(storeID: UUID) -> Int {
        stores.contains(where: { $0.id == storeID }) ? 7 : 0
    }

    func catalogMarketIndex(for model: VehicleCatalogEntry, in kind: DistrictKind) -> Double {
        let identifierSeed = model.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let movement = deterministicVariation(seed: (turn / 13) * 97 + identifierSeed)
        let age = max(0, turn - model.launchTurn)
        let newModelLift = age <= 13 ? 1.22 : age <= 39 ? 1.12 : age <= 78 ? 1.05 : 1.0
        let economyEffect: Double
        switch model.category {
        case .suv, .sports, .sedan: economyEffect = 0.72 + economicIndex * 0.28
        case .kei, .compact: economyEffect = 1.10 - (economicIndex - 1) * 0.20
        default: economyEffect = 0.88 + economicIndex * 0.12
        }
        let newerGenerations = VehicleCatalog.releasedNewCars(through: turn).filter {
            $0.maker == model.maker && $0.category == model.category && $0.launchTurn > model.launchTurn
        }.count
        let replacementEffect = max(0.70, pow(0.93, Double(newerGenerations)))
        return min(1.85, max(0.38, vehicleDemand(model.category, in: kind) * model.customerDemandIndex * movement * newModelLift * economyEffect * powertrainDemandFactor(for: model, in: kind) * replacementEffect))
    }

    func powertrainDemandFactor(for model: VehicleCatalogEntry, in kind: DistrictKind) -> Double {
        let transition = min(1, max(0, Double(turn) / Double(maxTurns)))
        switch model.powertrain {
        case .electric:
            let infrastructure: Double
            switch kind {
            case .emerging: infrastructure = 1.14
            case .downtown: infrastructure = 1.10
            case .station: infrastructure = 1.06
            case .suburb: infrastructure = 1.00
            case .highway: infrastructure = 0.92
            case .industrial: infrastructure = 0.88
            }
            let commercialPenalty = [.minivan, .pickup].contains(model.category) ? 0.90 + transition * 0.10 : 1.0
            return min(1.75, max(0.52, (0.68 + transition * 0.72 + (fuelPriceIndex - 1) * 0.55) * infrastructure * commercialPenalty))
        case .hybrid:
            return min(1.38, max(0.82, 1.02 + transition * 0.12 + (fuelPriceIndex - 1) * 0.24))
        case .gasoline:
            let efficientSegment = [.kei, .compact].contains(model.category) ? 0.08 : 0
            return min(1.18, max(0.62, 1.06 - transition * 0.30 - max(0, fuelPriceIndex - 1) * 0.30 + efficientSegment))
        case .diesel:
            let workVehicle = [.minivan, .pickup].contains(model.category) ? 0.13 : 0
            return min(1.22, max(0.66, 1.00 - transition * 0.22 - max(0, fuelPriceIndex - 1) * 0.12 + workVehicle))
        }
    }

    func electricTrendIndex(in kind: DistrictKind) -> Int {
        let electricModels = VehicleCatalog.releasedNewCars(through: turn).filter { $0.isEV && !$0.isRareClassic }
        guard !electricModels.isEmpty else { return 0 }
        let average = electricModels.reduce(0.0) { $0 + powertrainDemandFactor(for: $1, in: kind) } / Double(electricModels.count)
        return Int((average * 100).rounded())
    }

    var usedMarketEVShare: Int {
        let available = VehicleCatalog.available(through: turn).filter { !$0.isRareClassic }
        guard !available.isEmpty else { return 0 }
        return Int((Double(available.filter(\.isEV).count) / Double(available.count) * 100).rounded())
    }

    func usedMarketSupplyFactor(for model: VehicleCatalogEntry) -> Double {
        if model.launchTurn == 0 { return 1 }
        let weeks = turn - model.usedMarketTurn
        guard weeks >= 0 else { return 0 }
        return min(1, 0.12 + Double(weeks) / 56.0)
    }

    private func usedMarketScarcityPriceFactor(for model: VehicleCatalogEntry) -> Double {
        if model.launchTurn == 0 { return 1 }
        let weeks = max(0, turn - model.usedMarketTurn)
        return 1 + max(0, 1 - Double(weeks) / 52.0) * 0.18
    }

    private func normalMarketPressure(_ category: VehicleCategory, in kind: DistrictKind) -> Double {
        let demand = vehicleDemand(category, in: kind)
        let supply = vehicleSupply(category, in: kind)
        let imbalance = demand / max(0.20, supply) - 1
        return min(1.06, max(0.94, 1 + imbalance * 0.08))
    }

    private func catalogGenerationDepreciation(for model: VehicleCatalogEntry) -> Double {
        if model.isRareClassic {
            return 1.0
        }
        let yearsSinceLaunch = Double(max(0, turn - model.launchTurn)) / 48.0
        return max(0.58, pow(0.94, yearsSinceLaunch))
    }

    func catalogWholesalePrice(for model: VehicleCatalogEntry, in kind: DistrictKind) -> Int {
        if model.isRareClassic {
            return max(25, Int(Double(model.baseWholesalePrice) * classicMarketIndex))
        }
        let index = catalogMarketIndex(for: model, in: kind)
        let aging = catalogGenerationDepreciation(for: model)
        let scarcity = usedMarketScarcityPriceFactor(for: model)
        let pressure = normalMarketPressure(model.category, in: kind)
        let wholesale = Int(
            Double(model.baseWholesalePrice)
                * (0.86 + index * 0.14)
                * aging
                * scarcity
                * pressure
        )
        let retail = rawCatalogRetailPrice(
            for: model,
            in: kind,
            index: index,
            aging: aging,
            scarcity: scarcity,
            pressure: pressure
        )
        return max(25, min(wholesale, retail * 80 / 100))
    }

    func catalogRetailPrice(for model: VehicleCatalogEntry, in kind: DistrictKind) -> Int {
        if model.isRareClassic {
            return max(35, Int(Double(model.referenceRetailPrice) * classicMarketIndex))
        }
        let index = catalogMarketIndex(for: model, in: kind)
        let aging = catalogGenerationDepreciation(for: model)
        let scarcity = usedMarketScarcityPriceFactor(for: model)
        let pressure = normalMarketPressure(model.category, in: kind)
        return rawCatalogRetailPrice(
            for: model,
            in: kind,
            index: index,
            aging: aging,
            scarcity: scarcity,
            pressure: pressure
        )
    }

    private func rawCatalogRetailPrice(
        for model: VehicleCatalogEntry,
        in kind: DistrictKind,
        index: Double,
        aging: Double,
        scarcity: Double,
        pressure: Double
    ) -> Int {
        // 軽・コンパクトは高回転型。需要は厚い一方、1台あたりの値付け余地を抑える。
        let volumeSegmentPriceFactor: Double = switch model.category {
        case .kei: 0.92
        case .compact: 0.95
        default: 1.0
        }
        return max(
            35,
            Int(
                Double(model.referenceRetailPrice)
                    * volumeSegmentPriceFactor
                    * (0.78 + index * 0.22)
                    * aging
                    * scarcity
                    * pressure
            )
        )
    }

    func vehicleWholesaleValue(modelID: String, category: VehicleCategory, modelYear: Int, mileage: Int, quality: Double, in kind: DistrictKind) -> Int {
        vehicleMarketValue(modelID: modelID, category: category, modelYear: modelYear, mileage: mileage, quality: quality, in: kind, retail: false)
    }

    func vehicleRetailValue(modelID: String, category: VehicleCategory, modelYear: Int, mileage: Int, quality: Double, in kind: DistrictKind) -> Int {
        vehicleMarketValue(modelID: modelID, category: category, modelYear: modelYear, mileage: mileage, quality: quality, in: kind, retail: true)
    }

    private func trendProcurementPriceFactor(category: VehicleCategory, district: DistrictKind) -> Double {
        segmentTrends.reduce(1.0) { result, trend in
            guard turn >= trend.startTurn + 2,
                  trend.districts.contains(district),
                  trend.categories.contains(category) else { return result }
            let representative = MarketSegmentKey(
                district: district,
                category: category,
                purpose: trend.kind.productKind.customerPurpose,
                productKind: trend.kind.productKind
            )
            let multiplier = trend.multiplier(at: turn)
            guard trend.affects(representative) else { return result }
            return max(result, 1 + max(0, multiplier - 1) * 0.18)
        }
    }

    private func vehicleMarketValue(modelID: String, category: VehicleCategory, modelYear: Int, mileage: Int, quality: Double, in kind: DistrictKind, retail: Bool) -> Int {
        let base: Int
        if let model = VehicleCatalog.entry(id: modelID) {
            base = retail ? catalogRetailPrice(for: model, in: kind) : catalogWholesalePrice(for: model, in: kind)
        } else {
            base = retail ? Int(Double(category.purchaseCost) * 1.38) : category.purchaseCost
        }
        let model = VehicleCatalog.entry(id: modelID)
        let age = max(0, year - min(year, modelYear))
        let ageFactor: Double
        let mileageFactor: Double
        if model?.isRareClassic == true {
            ageFactor = 1.0
            mileageFactor = max(0.72, 1.0 - Double(max(0, mileage)) / 500_000.0 * 0.30)
        } else if model?.origin == .imported {
            // 高額輸入車は残価が高い一方、仕入れにも同じ残価を払う。
            ageFactor = max(0.52, pow(0.925, Double(age)))
            mileageFactor = max(0.68, 1.0 - Double(max(0, mileage)) / 300_000.0 * 0.36)
        } else {
            ageFactor = max(0.38, pow(0.91, Double(age)))
            mileageFactor = max(0.56, 1.0 - Double(max(0, mileage)) / 280_000.0 * 0.45)
        }
        let qualityFactor = model?.isRareClassic == true
            ? max(0.54, 0.35 + min(0.90, max(0.35, quality)) * 0.90)
            : max(0.64, 0.42 + min(0.94, max(0.40, quality)) * 0.72)
        let procurementTrend = retail ? 1.0 : trendProcurementPriceFactor(category: category, district: kind)
        return max(retail ? 30 : 22, Int(Double(base) * ageFactor * mileageFactor * qualityFactor * procurementTrend))
    }

    func catalogPriceTrendPercent(for model: VehicleCatalogEntry, in kind: DistrictKind) -> Int {
        let current = catalogRetailPrice(for: model, in: kind)
        return Int(((Double(current) / Double(max(1, model.referenceRetailPrice))) - 1) * 100)
    }

    func inventoryCount(modelID: String, storeID: UUID? = nil) -> Int {
        stores.filter { storeID == nil || $0.id == storeID }.flatMap(\.inventory).filter { $0.modelID == modelID }.reduce(0) { $0 + $1.count }
    }

    func inventoryAgeWeeks(for batch: InventoryBatch) -> Int {
        max(0, turn - batch.acquiredTurn)
    }

    func inventoryAgingValueFactor(for batch: InventoryBatch) -> Double {
        let age = inventoryAgeWeeks(for: batch)
        guard age > 4 else { return 1.0 }
        return max(0.72, 1.0 - Double(age - 4) * 0.006)
    }

    func inventoryFreshnessCloseAdjustment(for batch: InventoryBatch) -> Double {
        let age = inventoryAgeWeeks(for: batch)
        if age <= 2 { return 0.08 }
        if age <= 4 { return 0.04 }
        if age <= 12 { return 0 }
        return -min(0.24, Double(age - 12) * 0.008)
    }

    func inventoryAgeLabel(for batch: InventoryBatch) -> String {
        let age = inventoryAgeWeeks(for: batch)
        if age <= 2 { return "新入荷" }
        if age <= 12 { return "在庫\(age)週" }
        if age <= 25 { return "滞留\(age)週" }
        return "長期在庫\(age)週"
    }

    func specialtyDemandDescription(for batch: InventoryBatch, in district: DistrictKind) -> String {
        if let purpose = batch.productState.purpose { return "\(purpose.name)向け商品" }
        if batch.productState == .refurbished { return "完全再生車" }
        if batch.isRareClassic {
            return [.downtown, .emerging].contains(district) ? "旧車需要：強い" : "旧車需要：限定的"
        }
        return "一般需要"
    }

    func marketProductKind(for batch: InventoryBatch) -> MarketProductKind {
        MarketProductKind.resolve(productState: batch.productState, isRareClassic: batch.isRareClassic)
    }

    private func marketProductMatches(actual: MarketProductKind, desired: MarketProductKind) -> Bool {
        switch desired {
        case .standard:
            [.standard, .repaired, .refurbished].contains(actual)
        case .repaired:
            [.repaired, .refurbished].contains(actual)
        case .refurbished:
            actual == .refurbished
        case .camper, .workCargo, .outdoor, .collector, .sportTuned, .welfare, .mobileShop:
            actual == desired
        }
    }

    func marketSegmentKey(for batch: InventoryBatch, purpose: CustomerPurpose, district: DistrictKind) -> MarketSegmentKey {
        MarketSegmentKey(
            district: district,
            category: batch.category,
            purpose: purpose,
            productKind: marketProductKind(for: batch)
        )
    }

    func activeTrendMultiplier(for key: MarketSegmentKey, at evaluatedTurn: Int? = nil) -> Double {
        let targetTurn = evaluatedTurn ?? turn
        return segmentTrends.reduce(1.0) { result, trend in
            trend.affects(key) ? max(result, trend.multiplier(at: targetTurn)) : result
        }
    }

    func activeTrendPhaseStrength(for key: MarketSegmentKey, at evaluatedTurn: Int? = nil) -> Double {
        let targetTurn = evaluatedTurn ?? turn
        return segmentTrends.reduce(0.0) { result, trend in
            trend.affects(key) ? max(result, trend.phaseStrength(at: targetTurn)) : result
        }
    }

    func specialtyGradeDemandShares(for key: MarketSegmentKey) -> [SpecialtyProductGrade: Double] {
        guard key.productKind.supportsGrades else { return [:] }
        let strength = activeTrendPhaseStrength(for: key)
        return [
            .low: 0.65 + (0.15 - 0.65) * strength,
            .middle: 0.30 + (0.35 - 0.30) * strength,
            .high: 0.05 + (0.50 - 0.05) * strength
        ]
    }

    private func requestedSpecialtyGrade(for key: MarketSegmentKey, seed: Int) -> SpecialtyProductGrade? {
        guard key.productKind.supportsGrades else { return nil }
        let shares = specialtyGradeDemandShares(for: key)
        let lowShare = shares[.low] ?? 0.65
        let middleShare = shares[.middle] ?? 0.30
        let roll = transactionRoll(seed: seed)
        if roll < lowShare { return .low }
        if roll < lowShare + middleShare { return .middle }
        return .high
    }

    private func gradeMatches(actual: SpecialtyProductGrade?, desired: SpecialtyProductGrade?) -> Bool {
        guard let desired else { return true }
        return (actual ?? .low) >= desired
    }

    private func specialtyPriceCeiling(
        for productKind: MarketProductKind,
        productState: VehicleProductState? = nil,
        grade: SpecialtyProductGrade? = nil
    ) -> Double {
        let stateBase: Double? = switch productState {
        case .sportStreet: 1.45
        case .sportDrift: 1.75
        case .sportCircuit: 2.00
        case .welfareLiftSeat: 1.30
        case .welfareWheelchair: 1.60
        case .mobileSales: 1.45
        case .kitchenCar: 1.90
        default: nil
        }
        if let stateBase {
            return stateBase * (grade ?? .low).priceCeilingMultiplier
        }
        let base: Double = switch productKind {
        case .standard: 1.10
        case .repaired: 1.30
        case .refurbished: 1.75
        case .camper: 2.00
        case .workCargo: 1.55
        case .outdoor: 1.60
        case .collector: 2.20
        case .sportTuned: 2.00
        case .welfare: 1.60
        case .mobileShop: 1.90
        }
        return base * (productKind.supportsGrades ? (grade ?? .low).priceCeilingMultiplier : 1)
    }

    private func specialtyReferenceRetail(for model: VehicleCatalogEntry) -> Double {
        Double(model.referenceRetailPrice) * (model.isRareClassic ? classicMarketIndex : 1)
    }

    func specialtyReadiness(for store: Store, productKind: MarketProductKind) -> Double {
        guard productKind.isNiche else { return 1 }
        let categories = Set(nicheCategories(for: productKind))
        let policyPurpose = productKind != .collector
            && store.marketPolicy.targetPurpose == productKind.customerPurpose
        let categoryFit = !store.marketPolicy.priorityCategories.isDisjoint(with: categories)
        let project = brandProjectKind(for: productKind)
        let facilityReady = project.usesCustomizationBay
            ? store.facilities.contains(.customWorkshop)
            : store.facilities.contains(.serviceWorkshop)
        let staffReady = store.employees.contains { $0.assignment == .service }
        let expertise = min(1, (store.expertise.project(project) + companyExpertise.project(project) * 0.25) / 50)
        let recognition = Double(specialtyBrandProfile(for: store, productKind: productKind).recognition) / 100
        return min(1,
            (policyPurpose ? 0.25 : 0)
            + (categoryFit ? 0.15 : 0)
            + (facilityReady ? 0.20 : 0)
            + (staffReady ? 0.10 : 0)
            + expertise * 0.20
            + recognition * 0.10
        )
    }

    private func segmentWillingnessFactor(
        for key: MarketSegmentKey,
        store: Store? = nil,
        productState: VehicleProductState? = nil,
        grade: SpecialtyProductGrade? = nil
    ) -> Double {
        let normalizedTrend = activeTrendPhaseStrength(for: key)
        let readiness = store.map { specialtyReadiness(for: $0, productKind: key.productKind) } ?? 0.65
        let ceiling = specialtyPriceCeiling(for: key.productKind, productState: productState, grade: grade)
        return 1 + (ceiling - 1) * normalizedTrend * readiness
    }

    func specialtyMarketFactor(for batch: InventoryBatch, in district: DistrictKind) -> Double {
        let productFactor: Double
        switch batch.productState {
        case .stock: productFactor = 1.0
        case .serviced: productFactor = 1.02
        case .repaired: productFactor = 1.04
        case .refurbished: productFactor = batch.isRareClassic ? 1.32 : 1.08
        case .camper, .workCargo, .outdoor,
             .sportStreet, .sportDrift, .sportCircuit,
             .welfareLiftSeat, .welfareWheelchair,
             .mobileSales, .kitchenCar:
            // 用途改装の価値は来店客の用途と一致した時にのみ上乗せする。
            productFactor = 1.0
        }
        let districtFactor: Double
        if batch.isRareClassic {
            switch district {
            case .emerging: districtFactor = 1.18
            case .downtown: districtFactor = 1.14
            case .industrial, .highway: districtFactor = 1.02
            case .suburb: districtFactor = 0.88
            case .station: districtFactor = 0.82
            }
        } else {
            districtFactor = 1.0
        }
        return productFactor * districtFactor
    }

    func productPurposeValueFactor(for batch: InventoryBatch, purpose: CustomerPurpose) -> Double {
        switch batch.productState {
        case .camper: return purpose == .camper ? 1.30 : 0.85
        case .workCargo: return [.work, .corporate].contains(purpose) ? 1.22 : 0.90
        case .outdoor: return purpose == .outdoor ? 1.15 : 0.95
        case .sportStreet, .sportDrift, .sportCircuit: return purpose == .performance ? 1.0 : 0.70
        case .welfareLiftSeat, .welfareWheelchair: return purpose == .welfare ? 1.0 : 0.78
        case .mobileSales, .kitchenCar: return purpose == .mobileBusiness ? 1.0 : 0.72
        default: return 1.0
        }
    }

    func productizationMarketValueAddition(for batch: InventoryBatch) -> Int {
        let recoveryRate: Double = switch batch.productState {
        case .stock: 0
        case .serviced: 0.30
        case .repaired: 0.50
        case .refurbished: 0.65
        case .camper, .workCargo, .outdoor,
             .sportStreet, .sportDrift, .sportCircuit,
             .welfareLiftSeat, .welfareWheelchair,
             .mobileSales, .kitchenCar:
            // 用途改装はまず架装費を全額回収する。付加価値による粗利の増加は
            // customizationValueSupportedPrice で、改造前の車両粗利を基準に加える。
            1.0
        }
        return Int((Double(batch.valueAddedInvestment) * recoveryRate).rounded())
    }

    private func customizationValueSupportedPrice(
        for batch: InventoryBatch,
        baseVehiclePrice: Int
    ) -> Int? {
        guard batch.valueAddedInvestment > 0 else { return nil }
        switch batch.productState {
        case .camper, .workCargo, .outdoor,
             .sportStreet, .sportDrift, .sportCircuit,
             .welfareLiftSeat, .welfareWheelchair,
             .mobileSales, .kitchenCar:
            break
        case .stock, .serviced, .repaired, .refurbished:
            return nil
        }

        let originalVehicleCost = max(0, batch.averageCost - batch.valueAddedInvestment)
        let baseGrossProfit = max(0, baseVehiclePrice - originalVehicleCost)
        let grade = batch.productGrade ?? .low
        let valueAddedProfit = max(
            5,
            max(
                Int((Double(baseGrossProfit) * grade.customizationBaseGrossProfitGrowthRate).rounded()),
                Int((Double(batch.valueAddedInvestment) * grade.customizationInvestmentMarginRate).rounded())
            )
        )
        return baseVehiclePrice + batch.valueAddedInvestment + valueAddedProfit
    }

    func specialtyCloseAdjustment(for batch: InventoryBatch, purpose: CustomerPurpose, in district: DistrictKind) -> Double {
        if let productPurpose = batch.productState.purpose {
            let matches = productPurpose == purpose || (productPurpose == .work && purpose == .corporate)
            return matches ? 0.14 : -0.18
        }
        if batch.isRareClassic {
            switch district {
            case .emerging: return 0.10
            case .downtown: return 0.07
            case .industrial, .highway: return -0.02
            case .suburb: return -0.16
            case .station: return -0.22
            }
        }
        return 0
    }

    func averageInventoryWeeks(storeID: UUID? = nil) -> Double {
        let inventory = stores
            .filter { storeID == nil || $0.id == storeID }
            .flatMap(\.inventory)
            .filter { $0.count > 0 }
        let units = inventory.reduce(0) { $0 + $1.count }
        guard units > 0 else { return 0 }
        let weightedWeeks = inventory.reduce(0) { $0 + inventoryAgeWeeks(for: $1) * $1.count }
        return Double(weightedWeeks) / Double(units)
    }

    func fourWeekForecast(for storeID: UUID) -> FourWeekForecast? {
        guard let store = stores.first(where: { $0.id == storeID }),
              store.isOperational,
              let plot = plot(id: store.plotID) else { return nil }
        let currentQuotes = store.inventory.compactMap { batch -> (price: Int, margin: Int, count: Int)? in
            guard batch.count > 0, !batch.isInWorkshop, !batch.isReserved,
                  let quote = manualSaleQuote(storeID: storeID, inventoryID: batch.id) else { return nil }
            return (quote.price, quote.grossProfit, batch.count)
        }
        let incoming = inboundShipments.filter { $0.storeID == storeID }
        let currentUnits = currentQuotes.reduce(0) { $0 + $1.count }
        let sellableUnits = currentUnits + incoming.reduce(0) { $0 + $1.count }
        let weeklyDemand = max(
            store.buyerArrivalsThisWeek,
            Int((Double(weeklyBuyerPool(in: plot.district)) * marketShare(for: store)).rounded())
        )
        let fourWeekDemand = weeklyDemand * 4
        let automaticSalesCapacity = store.autoSales
            ? store.employees
                .filter { $0.assignment == .sales }
                .reduce(0) {
                    $0 + employeeWeeklyCaseCapacity(for: $1, assignment: .sales)
                }
            : 0
        let fourWeekCapacity = (weeklyOpportunityCapacity(storeID: storeID) + automaticSalesCapacity) * 4
        let possibleSales = min(sellableUnits, fourWeekDemand, fourWeekCapacity)
        let skillLift = employeeSalesCloseAdjustment(for: storeID)
        let closeLow = min(0.72, max(0.28, 0.40 + skillLift + (store.reputation - 0.65) * 0.10))
        let closeHigh = min(0.88, closeLow + 0.18)
        let salesLow = min(possibleSales, Int((Double(fourWeekDemand) * closeLow).rounded(.down)))
        let salesHigh = min(possibleSales, Int((Double(fourWeekDemand) * closeHigh).rounded(.up)))

        let fallbackPrice = Int(Double((recommendedCategories(for: plot.district).first ?? .compact).purchaseCost) * 1.35)
        let fallbackMargin = max(10, fallbackPrice / 5)
        let currentPriceTotal = currentQuotes.reduce(0) { $0 + $1.price * $1.count }
        let currentMarginTotal = currentQuotes.reduce(0) { $0 + $1.margin * $1.count }
        let incomingUnits = incoming.reduce(0) { $0 + $1.count }
        let incomingPriceTotal = incoming.reduce(0) { total, shipment in
            let estimatedPrice = max(shipment.unitCost + 8, Int(Double(shipment.unitCost) * 1.30))
            return total + estimatedPrice * shipment.count
        }
        let incomingMarginTotal = incoming.reduce(0) { total, shipment in
            let estimatedPrice = max(shipment.unitCost + 8, Int(Double(shipment.unitCost) * 1.30))
            return total + (estimatedPrice - shipment.unitCost) * shipment.count
        }
        let pricedUnits = currentUnits + incomingUnits
        let averagePrice = pricedUnits > 0 ? (currentPriceTotal + incomingPriceTotal) / pricedUnits : fallbackPrice
        let averageMargin = pricedUnits > 0 ? (currentMarginTotal + incomingMarginTotal) / pricedUnits : fallbackMargin
        let grossProfitLow = salesLow * averageMargin
        let grossProfitHigh = salesHigh * averageMargin
        let monthlyRent = store.acquisition == .lease
            ? store.plotIDs.compactMap { self.plot(id: $0)?.monthlyRent }.reduce(0, +)
            : 0
        let fourWeekCashExpenses = monthlyPersonnelCost(for: store) + monthlyRent + store.advertising + store.type.monthlyFixedCost + store.facilityMonthlyCost
        let fourWeekDepreciation = (store.type.buildCost + store.facilityInvestment) / 240
        let fourWeekOperatingExpenses = fourWeekCashExpenses + fourWeekDepreciation
        let operatingProfitLow = grossProfitLow - fourWeekOperatingExpenses
        let operatingProfitHigh = grossProfitHigh - fourWeekOperatingExpenses
        let endingCashLow = cash + salesLow * averagePrice - fourWeekCashExpenses
        let endingCashHigh = cash + salesHigh * averagePrice - fourWeekCashExpenses
        let inventoryCapital = store.inventory.reduce(0) { $0 + $1.averageCost * $1.count }
            + incoming.reduce(0) { $0 + $1.unitCost * $1.count }
        let estimatedInventoryMarketValue = currentPriceTotal + incomingPriceTotal
        let bottleneck: String
        if sellableUnits == 0 {
            bottleneck = "販売可能な在庫がありません"
        } else if sellableUnits < max(2, fourWeekDemand / 2) {
            bottleneck = "需要に対して仕入れ・入庫が不足"
        } else if fourWeekCapacity < fourWeekDemand {
            bottleneck = "来店需要に対して営業枠が不足"
        } else if fourWeekDemand < max(2, sellableUnits / 2) {
            bottleneck = "在庫に対して来店需要が不足"
        } else if cash < fourWeekCashExpenses {
            bottleneck = "固定費に対して現金余力が不足"
        } else {
            bottleneck = "需要・在庫・営業枠は概ね均衡"
        }
        return FourWeekForecast(
            salesLow: salesLow,
            salesHigh: salesHigh,
            grossProfitLow: grossProfitLow,
            grossProfitHigh: grossProfitHigh,
            operatingProfitLow: operatingProfitLow,
            operatingProfitHigh: operatingProfitHigh,
            endingCashLow: endingCashLow,
            endingCashHigh: endingCashHigh,
            inventoryCapital: inventoryCapital,
            estimatedInventoryMarketValue: estimatedInventoryMarketValue,
            bottleneck: bottleneck
        )
    }

    var companyFourWeekForecast: FourWeekForecast {
        let forecasts = stores.compactMap { fourWeekForecast(for: $0.id) }
        let salesLow = forecasts.reduce(0) { $0 + $1.salesLow }
        let salesHigh = forecasts.reduce(0) { $0 + $1.salesHigh }
        let grossLow = forecasts.reduce(0) { $0 + $1.grossProfitLow }
        let grossHigh = forecasts.reduce(0) { $0 + $1.grossProfitHigh }
        let interest = debt / 9_600 * 4
        let profitLow = forecasts.reduce(0) { $0 + $1.operatingProfitLow } - interest
        let profitHigh = forecasts.reduce(0) { $0 + $1.operatingProfitHigh } - interest
        let cashDeltaLow = forecasts.reduce(0) { $0 + ($1.endingCashLow - cash) } - interest
        let cashDeltaHigh = forecasts.reduce(0) { $0 + ($1.endingCashHigh - cash) } - interest
        let inventoryCapital = forecasts.reduce(0) { $0 + $1.inventoryCapital }
        let marketValue = forecasts.reduce(0) { $0 + $1.estimatedInventoryMarketValue }
        let bottleneck = forecasts.first(where: { !$0.bottleneck.contains("概ね均衡") })?.bottleneck
            ?? (forecasts.isEmpty ? "営業中の店舗がありません" : "全店舗で大きな制約はありません")
        return FourWeekForecast(
            salesLow: salesLow,
            salesHigh: salesHigh,
            grossProfitLow: grossLow,
            grossProfitHigh: grossHigh,
            operatingProfitLow: profitLow,
            operatingProfitHigh: profitHigh,
            endingCashLow: cash + cashDeltaLow,
            endingCashHigh: cash + cashDeltaHigh,
            inventoryCapital: inventoryCapital,
            estimatedInventoryMarketValue: marketValue,
            bottleneck: bottleneck
        )
    }

    func remainingWeeklyOpportunities(storeID: UUID) -> Int {
        guard let store = stores.first(where: { $0.id == storeID }) else { return 0 }
        return max(0, weeklyOpportunityCapacity(storeID: storeID) - store.usedOpportunitiesThisWeek)
    }

    func buyerLeads(for storeID: UUID) -> [BuyerLead] {
        buyerLeads.filter { $0.storeID == storeID }
    }

    func customerTrafficFactors(for store: Store) -> [ResultCause] {
        guard let plot = plot(id: store.plotID) else { return [] }
        let district = district(for: plot)
        let stocked = store.inventory.filter { $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }
        let inventoryDemand = stocked.isEmpty ? 0.45 : stocked.reduce(0.0) {
            $0 + (district.demands[$1.category] ?? 0.55)
        } / Double(stocked.count)
        let location = plot.visibility * plot.access * plot.traffic
        let advertisingLift = min(0.42, Double(store.advertising) / 520.0)
        return [
            ResultCause("日経平均 \(nikkeiAverageYen.formatted())円", (economicIndex - 1) * 5.0),
            ResultCause("中古車需要 \(marketDemandPercentage)%", (marketDemandIndex - 1) * 5.0),
            ResultCause("地域人口 \(district.population.formatted())人", (Double(district.population) / 70_000.0 - 1) * 3.0),
            ResultCause("販売客の口コミ", (store.customerReviewAttraction(for: .buyer) - 1) * 8.0),
            ResultCause("立地・交通", (location - 1) * 3.0),
            ResultCause("広告・認知", (advertisingLift - 0.15) * 3.0),
            ResultCause(stocked.isEmpty ? "希望車種の在庫なし" : "地域需要と在庫", (inventoryDemand - 1) * 4.0),
            ResultCause("近隣競争", (marketShare(for: store) - 0.5) * 5.0)
        ]
    }

    func marketShare(for store: Store) -> Double {
        guard store.isOperational, let plot = plot(id: store.plotID) else { return 0 }
        let ownWeight = storeMarketWeight(store, plot: plot)
        let total = totalMarketWeight(in: plot.district)
        return total > 0 ? ownWeight / total : 0
    }

    func competitorMarketShare(_ competitor: Competitor, in kind: DistrictKind) -> Double {
        let weight = competitor.plotIDs.compactMap { plot(id: $0) }.filter { $0.district == kind }.reduce(0.0) {
            $0 + competitorMarketWeight(competitor, plot: $1)
        }
        let total = totalMarketWeight(in: kind)
        return total > 0 ? weight / total : 0
    }

    private func totalMarketWeight(in kind: DistrictKind) -> Double {
        let playerWeight = stores.filter { $0.isOperational && plot(id: $0.plotID)?.district == kind }.reduce(0.0) { result, store in
            guard let plot = plot(id: store.plotID) else { return result }
            return result + storeMarketWeight(store, plot: plot)
        }
        let rivalWeight = competitors.reduce(0.0) { result, competitor in
            result + competitor.plotIDs.compactMap { plot(id: $0) }.filter { $0.district == kind }.reduce(0.0) {
                $0 + competitorMarketWeight(competitor, plot: $1)
            }
        }
        return playerWeight + rivalWeight
    }

    private func storeMarketWeight(_ store: Store, plot: LandPlot) -> Double {
        let district = district(for: plot)
        let inventoryFit = demandFit(store: store, district: district)
        let location = plot.visibility * plot.access * plot.traffic
        let campaign = store.inventorySaleCampaign?.tier.trafficMultiplier ?? 1
        let marketing = advertisingAttractionFactor(store.advertising)
            * employeeMarketingEfficiency(for: store.id, buyers: true)
        let priceAppeal = max(0.62, 1.72 - store.priceIndex * 0.72)
        let reviews = store.customerReviewAttraction(for: .buyer)
        return max(0.08, inventoryFit * facilityMarketFactor(store) * location * marketing * campaign * priceAppeal * reviews * competitiveStoreMarketFactor(in: plot.district))
    }

    private func competitorMarketWeight(_ competitor: Competitor, plot: LandPlot) -> Double {
        guard let branch = competitor.branches.first(where: { $0.plotID == plot.id }) else { return 0 }
        let inventoryFit = branch.inventory.reduce(0.0) { result, bucket in
            result + vehicleDemand(bucket.category, in: plot.district) * Double(bucket.count)
        } / Double(max(1, branch.inventoryCount))
        let stockFactor = min(1.25, Double(branch.inventoryCount) / Double(max(4, branch.capacity / 2)))
        let advertising = 0.78 + min(0.48, Double(branch.advertising) / 500)
        let priceAppeal = max(0.60, 1.72 - branch.priceIndex * 0.72)
        let expertise = 1 + min(0.20, (branch.expertise.categories.values.max() ?? 0) * 0.002)
        return max(0.01, competitor.strength * inventoryFit * stockFactor * advertising * priceAppeal * branch.reputation * expertise * plot.visibility * plot.access * plot.traffic * competitiveRivalMarketFactor(competitor.id, in: plot.district))
    }

    func estimatedSales(for plot: LandPlot, type: StoreType = .standard, marketPolicy: StoreMarketPolicy = StoreMarketPolicy()) -> ClosedRange<Int> {
        if let existing = store(at: plot.id) {
            let mid = max(1, Int(Double(weeklyBuyerPool(in: plot.district) * 4) * marketShare(for: existing)))
            return max(1, Int(Double(mid) * 0.78))...max(2, Int(Double(mid) * 1.18))
        }
        let district = district(for: plot)
        let demand = district.demands.values.reduce(0, +) / Double(max(1, district.demands.count))
        let location = plot.visibility * plot.access * plot.traffic
        let focusedDemand: Double
        if marketPolicy.priorityCategories.isEmpty {
            focusedDemand = demand
        } else {
            focusedDemand = marketPolicy.priorityCategories.reduce(0) { $0 + (district.demands[$1] ?? demand) }
                / Double(marketPolicy.priorityCategories.count)
        }
        let candidateWeight = max(0.08, focusedDemand * location * type.serviceQuality)
        let share = candidateWeight / max(0.01, totalMarketWeight(in: plot.district) + candidateWeight)
        let mid = max(1, Int(Double(weeklyBuyerPool(in: plot.district) * 4) * share))
        return max(1, Int(Double(mid) * 0.78))...max(2, Int(Double(mid) * 1.18))
    }

    func breakEvenSales(
        for plot: LandPlot,
        type: StoreType,
        mode: AcquisitionMode,
        facilities: Set<StoreFacility> = []
    ) -> Int {
        let footprint = footprintPlots(startingAt: plot, type: type, mode: mode)
        let cells = footprint.count == type.requiredGridCells ? footprint : [plot]
        let occupancy: Int
        switch mode {
        case .lease:
            occupancy = cells.reduce(0) { $0 + $1.monthlyRent }
        case .purchase:
            occupancy = max(12, cells.reduce(0) { $0 + $1.price } / 360)
        }
        let facilityCost = facilities.reduce(0) { $0 + $1.monthlyCost }
        return max(3, Int(ceil(Double(type.monthlyFixedCost + facilityCost + occupancy + 80) / 32.0)))
    }

    func canBuild(on plot: LandPlot, type: StoreType, mode: AcquisitionMode) -> Bool {
        let footprint = footprintPlots(startingAt: plot, type: type, mode: mode)
        guard footprint.count == type.requiredGridCells else { return false }
        return cash >= totalBuildCost(for: footprint, type: type, mode: mode)
    }

    func footprintPlots(startingAt plot: LandPlot, type: StoreType) -> [LandPlot] {
        footprintPlots(
            startingAt: plot,
            type: type,
            mode: nil,
            occupiedBy: nil,
            requiredExistingIDs: []
        )
    }

    func footprintPlots(
        startingAt plot: LandPlot,
        type: StoreType,
        mode: AcquisitionMode
    ) -> [LandPlot] {
        footprintPlots(
            startingAt: plot,
            type: type,
            mode: mode,
            occupiedBy: nil,
            requiredExistingIDs: []
        )
    }

    func landAcquisitionCost(for footprint: [LandPlot], mode: AcquisitionMode) -> Int {
        footprint.reduce(0) { total, cell in
            total + (mode == .purchase ? cell.price : cell.monthlyRent * 3)
        }
    }

    func demolitionCost(for footprint: [LandPlot]) -> Int {
        footprint.reduce(0) { $0 + $1.structure.demolitionCost }
    }

    func totalBuildCost(
        for footprint: [LandPlot],
        type: StoreType,
        mode: AcquisitionMode,
        facilities: Set<StoreFacility> = []
    ) -> Int {
        landAcquisitionCost(for: footprint, mode: mode)
            + demolitionCost(for: footprint)
            + type.buildCost
            + facilities.reduce(0) { $0 + $1.installationCost }
    }

    @discardableResult
    func buildStore(
        on plot: LandPlot,
        type: StoreType,
        mode: AcquisitionMode,
        marketPolicy: StoreMarketPolicy = StoreMarketPolicy(),
        facilities: Set<StoreFacility> = [],
        loanAmount: Int
    ) -> Bool {
        // 1店舗目は創業店として即日開店します（案内の有無では変わりません）。
        let isFoundingStore = stores.isEmpty
        let footprint = footprintPlots(startingAt: plot, type: type, mode: mode)
        guard stores.count < 5,
              footprint.count == type.requiredGridCells,
              facilities.allSatisfy({ $0.minimumGridCells <= type.requiredGridCells }) else { return false }
        let total = totalBuildCost(for: footprint, type: type, mode: mode, facilities: facilities)
        guard cash + loanAmount >= total else { return false }
        cash += loanAmount - total
        debt += loanAmount
        finance.investingCF -= total
        finance.financingCF += loanAmount
        let store = Store(
            name: "\(plot.district.shortName)\(plot.localNumber)号店",
            plotID: plot.id,
            plotIDs: footprint.map(\.id),
            type: type,
            acquisition: mode,
            marketPolicy: marketPolicy,
            facilities: facilities,
            inventory: [],
            openingMonthsRemaining: isFoundingStore ? nil : type.constructionMonths
        )
        stores.append(store)
        for cell in footprint {
            guard let index = plots.firstIndex(where: { $0.id == cell.id }) else { continue }
            plots[index].occupant = .player(storeID: store.id)
            plots[index].structure = .vacant
        }
        synchronizeParcelUse(for: store)
        if isFoundingStore {
            tutorialStep = .purchaseInventory
            generateWeeklyCustomerLeads(forceTutorialStoreID: store.id)
            recordCityEvent(CityEvent(turn: turn, kind: .storeGrowth, title: "創業店がオープン", detail: "既存建物を解体し、\(store.plotIDs.count)セルを使った\(store.name)が営業を開始しました", district: plot.district, plotID: plot.id))
        }
        recalculateAssets()
        assertGridOccupancyIntegrity()
        save()
        return true
    }

    func closeStore(_ storeID: UUID) {
        guard stores.count > 1,
              let storeIndex = stores.firstIndex(where: { $0.id == storeID }) else { return }
        let store = stores[storeIndex]
        let storePlots = store.plotIDs.compactMap { plot(id: $0) }
        let landProceeds = store.acquisition == .purchase ? storePlots.reduce(0) { $0 + $1.price } : 0
        let equipmentProceeds = (store.type.buildCost + store.facilityInvestment) * 3 / 10
        let inventoryProceeds = store.inventory.reduce(0) { $0 + $1.averageCost * $1.count * 8 / 10 }
        let proceeds = landProceeds + equipmentProceeds + inventoryProceeds
        cash += proceeds
        finance.investingCF += landProceeds + equipmentProceeds
        for plotID in store.plotIDs {
            guard let plotIndex = plots.firstIndex(where: { $0.id == plotID }) else { continue }
            plots[plotIndex].occupant = .available
            plots[plotIndex].structure = .vacant
            plots[plotIndex].currentUse = .vacant
        }
        stores.remove(at: storeIndex)
        recalculateAssets()
        assertGridOccupancyIntegrity()
        save()
    }

    func inventoryPurchaseCost(category: VehicleCategory, count: Int, storeID: UUID) -> Int? {
        guard let store = stores.first(where: { $0.id == storeID }) else { return nil }
        return inventoryPurchaseBatches(category: category, count: count, store: store)
            .map { $0.reduce(0) { $0 + $1.averageCost } }
    }

    func buyInventory(category: VehicleCategory, count: Int, storeID: UUID) -> Bool {
        guard count > 0,
              let index = stores.firstIndex(where: { $0.id == storeID }),
              let inventory = inventoryPurchaseBatches(category: category, count: count, store: stores[index]) else { return false }
        let totalCost = inventory.reduce(0) { $0 + $1.averageCost }
        guard cash >= totalCost else { return false }
        let freeCapacity = stores[index].type.capacity - stores[index].inventoryCount
        guard freeCapacity >= count else { return false }
        cash -= totalCost
        stores[index].inventory.append(contentsOf: inventory)
        simulationTransactionHandler?(SimulationVehicleTransaction(
            turn: turn,
            kind: .acquired,
            storeID: storeID,
            source: .auction,
            category: category,
            count: count,
            revenue: 0,
            cost: totalCost
        ))
        stores[index].expertise.add(category: category, purpose: stores[index].marketPolicy.targetPurpose, source: .auction, points: 1)
        companyExpertise.add(category: category, purpose: stores[index].marketPolicy.targetPurpose, source: .auction, points: 1)
        if tutorialStep == .purchaseInventory {
            tutorialStep = .runFirstMonth
        }
        recalculateAssets()
        save()
        return true
    }

    private func inventoryPurchaseBatches(category: VehicleCategory, count: Int, store: Store) -> [InventoryBatch]? {
        guard count > 0, let plot = plot(id: store.plotID) else { return nil }
        let sourceEfficiency = 1 - min(0.15, effectiveSourceExpertise(for: store, source: .auction) * 0.0015)
        return (0..<count).map { offset in
            let model = vehicleModel(for: category, seed: turn * 101 + store.plotID * 17 + offset * 29)
            let profile = usedVehicleProfile(for: model, seed: turn * 131 + store.plotID * 23 + offset * 31, maximumAge: 8)
            let wholesale = vehicleWholesaleValue(
                modelID: model.id,
                category: category,
                modelYear: profile.modelYear,
                mileage: profile.mileage,
                quality: profile.quality,
                in: plot.district
            )
            return InventoryBatch(
                modelID: model.id,
                category: category,
                count: 1,
                averageCost: Int((Double(wholesale) * sourceEfficiency).rounded()),
                quality: profile.quality,
                modelYear: profile.modelYear,
                mileage: profile.mileage,
                acquiredTurn: turn
            )
        }
    }

    func completeTutorial() {
        tutorialStep = .completed
        save()
    }

    // MARK: - ガイド（浜岡ナオ）

    /// いま案内中のレッスン。案内オフ、または全レッスン修了なら nil。
    var currentGuideLesson: GuideLesson? {
        guard guide.mode != .off else { return nil }
        return guide.currentLesson
    }

    var isGuideRunning: Bool { currentGuideLesson != nil }

    /// 開始時の確認で選んだモードで案内を始めます。
    func beginGuide(mode: GuideMode) {
        var progress = GuideProgress(mode: mode)
        progress.hasChosenMode = true
        progress.currentLessonID = GuideCurriculum.lessons(for: mode).first?.id
        progress.speechPage = 0
        guide = progress
        refreshGuideProgress()
        save()
    }

    /// 途中から案内を呼び戻します。達成済みのレッスンは自動で読み飛ばします。
    func restartGuide(mode: GuideMode = .full) {
        beginGuide(mode: mode)
    }

    /// 指定した章の先頭から読み直します。
    func replayGuideChapter(_ chapter: GuideChapter) {
        guard guide.mode != .off else { return }
        guard let first = guide.lessons.first(where: { $0.chapter == chapter }) else { return }
        guide.completedLessons.remove(first.id)
        guide.currentLessonID = first.id
        guide.speechPage = 0
        save()
    }

    /// ふきだしを次のページへ。最終ページなら「確認済み」として次のレッスンへ進みます。
    func advanceGuide() {
        guard let lesson = currentGuideLesson else { return }
        if guide.speechPage + 1 < lesson.speech.count {
            guide.speechPage += 1
            return
        }
        acknowledgeGuide(lesson.id)
    }

    func rewindGuide() {
        guard guide.speechPage > 0 else { return }
        guide.speechPage -= 1
    }

    /// レッスンの達成条件が「確認」のものを満たしたことを記録します。
    /// 画面を開いた・商談したなど、状態から判定できない達成に使います。
    func acknowledgeGuide(_ id: GuideLessonID) {
        guard guide.mode != .off else { return }
        guard !guide.acknowledgedLessons.contains(id) else {
            refreshGuideProgress()
            return
        }
        guide.acknowledgedLessons.insert(id)
        refreshGuideProgress()
        save()
    }

    /// 現在のレッスンだけを飛ばします。
    func skipCurrentGuideLesson() {
        guard let lesson = currentGuideLesson else { return }
        guide.completedLessons.insert(lesson.id)
        guide.currentLessonID = guide.nextLessonID(after: lesson.id)
        guide.speechPage = 0
        save()
    }

    /// 案内そのものを終了します（設定からいつでも再開できます）。
    func stopGuide() {
        guide.currentLessonID = nil
        guide.speechPage = 0
        save()
    }

    func requestGuideStorePanel(_ panel: GuideStorePanel) {
        guideStorePanelRequest = panel
    }

    /// 達成済みのレッスンを畳んで、案内位置を最新へ揃えます。
    func refreshGuideProgress() {
        guard guide.mode != .off else { return }
        var safety = 0
        while let id = guide.currentLessonID, safety < GuideLessonID.allCases.count + 2 {
            safety += 1
            guard isGuideGoalSatisfied(id.lesson) else { break }
            guide.completedLessons.insert(id)
            let next = guide.nextLessonID(after: id)
            guide.currentLessonID = next
            guide.speechPage = 0
        }
    }

    private func isGuideGoalSatisfied(_ lesson: GuideLesson) -> Bool {
        switch lesson.goal {
        case .acknowledge:
            return guide.acknowledgedLessons.contains(lesson.id)
        case .plotSelected:
            return tutorialPlotID != nil || !stores.isEmpty
        case .storeOpened:
            return !stores.isEmpty
        case .inventoryStocked:
            return totalInventory > 0
        case .weekAdvanced:
            return turn >= 1
        case .staffAssigned:
            return stores.contains { store in
                store.employees.contains { $0.assignment != .unassigned }
            }
        case .automationEnabled:
            return stores.contains { $0.autoSales || $0.autoProcurement || $0.autoMarketing || $0.autoService }
        }
    }

    func incomingCount(for storeID: UUID) -> Int {
        inboundShipments.filter { $0.storeID == storeID }.reduce(0) { $0 + $1.count }
    }

    func hasProcurementEmployee(storeID: UUID) -> Bool {
        stores.first(where: { $0.id == storeID })?.employees.contains {
            $0.assignment == .procurement
        } ?? false
    }

    func procurementInstructions(for storeID: UUID) -> [ProcurementInstruction] {
        procurementInstructions
            .filter { $0.storeID == storeID }
            .sorted {
                $0.priority == $1.priority ? $0.createdTurn < $1.createdTurn : $0.priority < $1.priority
            }
    }

    @discardableResult
    func createProcurementInstruction(
        storeID: UUID,
        totalBudget: Int,
        financialRule: ProcurementFinancialRule,
        category: VehicleCategory?,
        origin: VehicleOrigin? = nil,
        modelID: String?,
        faultOnly: Bool,
        allowedSources: Set<ProcurementSource> = Set(ProcurementSource.allCases)
    ) -> UUID? {
        if let category, let origin,
           !hasAvailableVehicle(category: category, origin: origin) {
            return nil
        }
        guard stores.contains(where: { $0.id == storeID }),
              totalBudget > 0,
              financialRule.isValid else { return nil }
        let priority = (procurementInstructions(for: storeID).map(\.priority).max() ?? -1) + 1
        let instruction = ProcurementInstruction(
            storeID: storeID,
            priority: priority,
            totalBudget: totalBudget,
            financialRule: financialRule,
            category: category,
            origin: origin,
            modelID: modelID,
            faultOnly: faultOnly,
            allowedSources: normalizedInstructionSources(allowedSources, for: financialRule),
            createdTurn: turn
        )
        procurementInstructions.append(instruction)
        save()
        return instruction.id
    }

    @discardableResult
    func updateProcurementInstruction(_ changed: ProcurementInstruction) -> Bool {
        if let category = changed.category, let origin = changed.origin,
           !hasAvailableVehicle(category: category, origin: origin) {
            return false
        }
        guard let index = procurementInstructions.firstIndex(where: { $0.id == changed.id }),
              stores.contains(where: { $0.id == changed.storeID }),
              changed.totalBudget >= changed.spentBudget + changed.reservedBudget,
              changed.totalBudget > 0,
              changed.financialRule.isValid else { return false }
        var normalized = changed
        if let modelID = normalized.modelID {
            normalized.category = VehicleCatalog.entry(id: modelID)?.category
        }
        normalized.allowedSources = normalizedInstructionSources(
            normalized.allowedSources,
            for: normalized.financialRule
        )
        procurementInstructions[index] = normalized
        save()
        return true
    }

    private func normalizedInstructionSources(
        _ sources: Set<ProcurementSource>,
        for rule: ProcurementFinancialRule
    ) -> Set<ProcurementSource> {
        let executable: Set<ProcurementSource> = rule.targetUnits > 0
            ? [.auction, .networkAuction]
            : [.storePurchase, .auction, .networkAuction]
        let normalized = sources.intersection(executable)
        return normalized.isEmpty ? executable : normalized
    }

    @discardableResult
    func setProcurementInstructionStatus(_ instructionID: UUID, status: ProcurementInstructionStatus) -> Bool {
        guard let index = procurementInstructions.firstIndex(where: { $0.id == instructionID }) else { return false }
        if procurementInstructions[index].status == .completed, status != .completed { return false }
        procurementInstructions[index].status = status
        if status == .completed {
            cancelAutomaticReservations(instructionID: instructionID)
            procurementInstructions[index].reservedBudget = 0
            procurementInstructions[index].lastResult = "ユーザーが完了"
        }
        save()
        return true
    }

    @discardableResult
    func moveProcurementInstruction(_ instructionID: UUID, direction: Int) -> Bool {
        guard direction != 0,
              let instruction = procurementInstructions.first(where: { $0.id == instructionID }) else { return false }
        var ordered = procurementInstructions(for: instruction.storeID)
        guard let from = ordered.firstIndex(where: { $0.id == instructionID }) else { return false }
        let to = min(ordered.count - 1, max(0, from + (direction < 0 ? -1 : 1)))
        guard from != to else { return false }
        ordered.swapAt(from, to)
        for (priority, item) in ordered.enumerated() {
            if let index = procurementInstructions.firstIndex(where: { $0.id == item.id }) {
                procurementInstructions[index].priority = priority
            }
        }
        save()
        return true
    }

    func deleteProcurementInstruction(_ instructionID: UUID) {
        cancelAutomaticReservations(instructionID: instructionID)
        procurementInstructions.removeAll { $0.id == instructionID }
        save()
    }

    private func cancelAutomaticReservations(instructionID: UUID) {
        bidReservations.removeAll { $0.instructionID == instructionID }
        networkAuctionBidReservations.removeAll { $0.instructionID == instructionID }
    }

    func auctionBidWinChance(for listing: AuctionListing, maxPrice: Int) -> Double {
        auctionBidWinChance(for: listing, maxPrice: maxPrice, sampleCount: 120)
    }

    private func auctionBidWinChance(
        for listing: AuctionListing,
        maxPrice: Int,
        sampleCount: Int
    ) -> Double {
        var wins = 0
        let baseSeed = turn * 277 + listing.modelYear * 19 + listing.mileage / 500 + categoryIndex(listing.category) * 43
        for sample in 0..<sampleCount {
            let rival = auctionRivalBid(
                for: listing,
                seed: baseSeed + sample * 7_919,
                usesRemainingPlan: false
            )
            if maxPrice >= (rival?.maxPrice ?? listing.reservePrice) { wins += 1 }
        }
        return Double(wins) / Double(sampleCount)
    }

    func auctionBidStep(for listing: AuctionListing) -> Int {
        let rawStep = max(5, listing.marketPrice / 40)
        return max(5, Int((Double(rawStep) / 5).rounded()) * 5)
    }

    @discardableResult
    func reserveBid(
        listingID: UUID,
        storeID: UUID,
        maxPrice: Int,
        instructionID: UUID? = nil,
        handlerEmployeeID: UUID? = nil
    ) -> Bool {
        guard let listing = auctionListings.first(where: { $0.id == listingID }),
              let store = stores.first(where: { $0.id == storeID }),
              maxPrice >= listing.reservePrice else { return false }
        let otherReservedSlots = bidReservations.filter { $0.storeID == storeID && $0.listingID != listingID }.count
            + networkAuctionBidReservations.filter { $0.storeID == storeID }.count
        guard store.inventoryCount + incomingCount(for: storeID) + otherReservedSlots + 1 <= store.type.capacity else { return false }
        if let index = bidReservations.firstIndex(where: { $0.listingID == listingID }) {
            guard bidReservations[index].instructionID == instructionID else { return false }
            bidReservations[index].storeID = storeID
            bidReservations[index].maxPrice = maxPrice
            bidReservations[index].committedCost = maxPrice + listing.lane.fee + listing.lane.shippingCost
        } else {
            bidReservations.append(BidReservation(
                id: UUID(),
                listingID: listingID,
                storeID: storeID,
                maxPrice: maxPrice,
                committedCost: maxPrice + listing.lane.fee + listing.lane.shippingCost,
                resultTurn: turn + 1,
                instructionID: instructionID,
                handlerEmployeeID: handlerEmployeeID,
                targetTurn: turn + 1
            ))
        }
        save()
        return true
    }

    func cancelBid(listingID: UUID) {
        bidReservations.removeAll { $0.listingID == listingID && $0.instructionID == nil }
        save()
    }

    func networkAuctionBidWinChance(for listing: NetworkAuctionListing, maxPrice: Int) -> Double {
        networkAuctionBidWinChance(for: listing, maxPrice: maxPrice, sampleCount: 120)
    }

    private func networkAuctionBidWinChance(
        for listing: NetworkAuctionListing,
        maxPrice: Int,
        sampleCount: Int
    ) -> Double {
        var wins = 0
        let baseSeed = turn * 311 + listing.modelYear * 17 + listing.mileage / 500 + categoryIndex(listing.category) * 61
        for sample in 0..<sampleCount {
            let rival = networkAuctionRivalBid(
                for: listing,
                seed: baseSeed + sample * 7_919,
                usesRemainingPlan: false
            )
            if maxPrice >= (rival?.maxPrice ?? listing.reservePrice) { wins += 1 }
        }
        return Double(wins) / Double(sampleCount)
    }

    func networkAuctionBidStep(for listing: NetworkAuctionListing) -> Int {
        let rawStep = max(5, listing.marketPrice / 40)
        return max(5, Int((Double(rawStep) / 5).rounded()) * 5)
    }

    @discardableResult
    func reserveNetworkAuctionBid(
        listingID: UUID,
        storeID: UUID,
        maxPrice: Int,
        instructionID: UUID? = nil,
        handlerEmployeeID: UUID? = nil
    ) -> Bool {
        guard let listing = networkAuctionListings.first(where: { $0.id == listingID }),
              let store = stores.first(where: { $0.id == storeID && $0.isOperational }),
              hasProcurementEmployee(storeID: storeID),
              maxPrice >= listing.reservePrice else { return false }
        if instructionID == nil, store.autoProcurement { return false }
        let otherReservedSlots = networkAuctionBidReservations.filter { $0.storeID == storeID && $0.listingID != listingID }.count
            + bidReservations.filter { $0.storeID == storeID }.count
        guard store.inventoryCount + incomingCount(for: storeID) + otherReservedSlots + 1 <= store.type.capacity else { return false }
        if let index = networkAuctionBidReservations.firstIndex(where: { $0.listingID == listingID }) {
            guard networkAuctionBidReservations[index].instructionID == instructionID else { return false }
            networkAuctionBidReservations[index].maxPrice = maxPrice
            networkAuctionBidReservations[index].committedCost = maxPrice + listing.fee + listing.shippingCost
        } else {
            networkAuctionBidReservations.append(NetworkAuctionBidReservation(
                id: UUID(),
                listingID: listingID,
                storeID: storeID,
                maxPrice: maxPrice,
                committedCost: maxPrice + listing.fee + listing.shippingCost,
                resultTurn: turn + 1,
                instructionID: instructionID,
                handlerEmployeeID: handlerEmployeeID,
                targetTurn: turn + 1
            ))
        }
        save()
        return true
    }

    func cancelNetworkAuctionBid(listingID: UUID) {
        networkAuctionBidReservations.removeAll { $0.listingID == listingID && $0.instructionID == nil }
        save()
    }

    @discardableResult
    func submitCorporateBid(opportunityID: UUID, storeID: UUID, unitPrice: Int) -> Bool {
        guard unitPrice > 0,
              let opportunityIndex = corporateOpportunities.firstIndex(where: { $0.id == opportunityID && !$0.resolved && $0.dueTurn > turn }),
              let storeIndex = stores.firstIndex(where: { $0.id == storeID && $0.isOperational }),
              stores[storeIndex].facilities.contains(.corporateDesk) else { return false }
        releaseCorporateReservation(opportunityID: opportunityID)
        let opportunity = corporateOpportunities[opportunityIndex]
        if opportunity.kind == .fleetDisposal {
            guard stores[storeIndex].inventoryCount + incomingCount(for: storeID) + opportunity.count <= stores[storeIndex].type.capacity,
                  cash >= unitPrice * opportunity.count else { return false }
            corporateOpportunities[opportunityIndex].reservedInventoryIDs = []
        } else {
            let eligible = stores[storeIndex].inventory.filter {
                $0.category == opportunity.category && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved
            }
            var remaining = opportunity.count
            var reserved: [UUID] = []
            for batch in eligible where remaining > 0 {
                reserved.append(batch.id)
                remaining -= batch.count
            }
            guard remaining <= 0 else { return false }
            for batchIndex in stores[storeIndex].inventory.indices where reserved.contains(stores[storeIndex].inventory[batchIndex].id) {
                stores[storeIndex].inventory[batchIndex].corporateReservationID = opportunityID
            }
            corporateOpportunities[opportunityIndex].reservedInventoryIDs = reserved
        }
        corporateOpportunities[opportunityIndex].playerStoreID = storeID
        corporateOpportunities[opportunityIndex].playerUnitPrice = unitPrice
        save()
        return true
    }

    func withdrawCorporateBid(opportunityID: UUID) {
        releaseCorporateReservation(opportunityID: opportunityID)
        if let index = corporateOpportunities.firstIndex(where: { $0.id == opportunityID && !$0.resolved }) {
            corporateOpportunities[index].playerStoreID = nil
            corporateOpportunities[index].playerUnitPrice = nil
            corporateOpportunities[index].reservedInventoryIDs = []
        }
        save()
    }

    private func releaseCorporateReservation(opportunityID: UUID) {
        for storeIndex in stores.indices {
            for batchIndex in stores[storeIndex].inventory.indices where stores[storeIndex].inventory[batchIndex].corporateReservationID == opportunityID {
                stores[storeIndex].inventory[batchIndex].corporateReservationID = nil
            }
        }
    }

    func corporateDisposalExpectedGrossProfit(
        for opportunity: CorporateOpportunity,
        unitPrice: Int,
        storeID: UUID
    ) -> Int? {
        guard opportunity.kind == .fleetDisposal,
              let modelID = opportunity.modelID,
              let modelYear = opportunity.modelYear,
              let mileage = opportunity.mileage,
              let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID) else { return nil }
        let retail = vehicleRetailValue(
            modelID: modelID,
            category: opportunity.category,
            modelYear: modelYear,
            mileage: mileage,
            quality: opportunity.quality,
            in: plot.district
        )
        return retail - unitPrice
    }

    private func generateCorporateOpportunities() {
        corporateOpportunities.removeAll { $0.resolved && $0.dueTurn < turn - 3 }
        guard !corporateOpportunities.contains(where: { !$0.resolved && $0.createdTurn == turn }) else { return }
        let categories: [VehicleCategory] = [.pickup, .minivan, .kei, .compact, .sedan, .suv]
        for index in 0..<2 {
            let category = categories[(turn * 3 + index * 2) % categories.count]
            let kind: CorporateOpportunityKind = index == 0 ? .fleetDisposal : .fleetPurchase
            let count = 3 + abs((turn + index * 3) % 5)
            let district = DistrictKind.allCases[(turn + index * 2) % DistrictKind.allCases.count]
            let model = kind == .fleetDisposal
                ? vehicleModel(for: category, origin: .domestic, seed: turn * 307 + index * 41)
                : nil
            let profile = model.map {
                usedVehicleProfile(for: $0, seed: turn * 313 + index * 43, maximumAge: 8)
            }
            let unitPrice: Int
            if let model, let profile {
                let retail = DistrictKind.allCases.map {
                    vehicleRetailValue(
                        modelID: model.id,
                        category: category,
                        modelYear: profile.modelYear,
                        mileage: profile.mileage,
                        quality: profile.quality,
                        in: $0
                    )
                }.min() ?? category.purchaseCost * 13 / 10
                // 法人放出は複数台をまとめて確保できる代わりに単価利益は薄い。
                // 基準価格では店頭販売価格に対して5〜10%の粗利を残す。
                let margin = 0.05 + transactionRoll(
                    seed: turn * 347 + index * 59 + categoryIndex(category) * 17
                ) * 0.05
                unitPrice = max(
                    10,
                    retail - Int((Double(retail) * margin).rounded())
                )
            } else {
                unitPrice = Int(Double(category.purchaseCost) * 1.34)
            }
            corporateOpportunities.append(CorporateOpportunity(
                id: UUID(), kind: kind,
                district: district,
                category: category,
                purpose: kind == .fleetPurchase ? (category == .pickup ? .work : .corporate) : .general,
                count: count, unitPrice: unitPrice,
                quality: profile?.quality ?? (kind == .fleetDisposal ? 0.68 : 0.78),
                modelID: model?.id,
                modelYear: profile?.modelYear,
                mileage: profile?.mileage,
                createdTurn: turn, dueTurn: turn + 1,
                playerStoreID: nil, playerUnitPrice: nil, reservedInventoryIDs: [],
                resolved: false, winnerName: nil
            ))
        }
    }

    private func resolveCorporateOpportunities(at resolvingTurn: Int, notes: inout [String]) {
        let dueIDs = corporateOpportunities.filter { !$0.resolved && $0.dueTurn <= resolvingTurn }.map(\.id)
        for opportunityID in dueIDs {
            guard let opportunityIndex = corporateOpportunities.firstIndex(where: { $0.id == opportunityID }) else { continue }
            let opportunity = corporateOpportunities[opportunityIndex]
            let playerScore: Double = {
                guard let storeID = opportunity.playerStoreID,
                      let bid = opportunity.playerUnitPrice,
                      let store = stores.first(where: { $0.id == storeID }) else { return -1 }
                if opportunity.kind == .fleetDisposal {
                    guard cash >= bid * opportunity.count,
                          store.inventoryCount + opportunity.count <= store.type.capacity else { return -1 }
                } else {
                    let reservedCount = store.inventory.filter { $0.corporateReservationID == opportunity.id && $0.category == opportunity.category }.reduce(0) { $0 + $1.count }
                    guard reservedCount >= opportunity.count else { return -1 }
                }
                let ability = opportunity.kind == .fleetDisposal
                    ? (store.employees.filter { $0.assignment == .procurement }.map(\.procurementSkill).max() ?? 50)
                    : (store.employees.filter { $0.assignment == .sales }.map(\.salesSkill).max() ?? 50)
                let priceScore = opportunity.kind == .fleetDisposal
                    ? Double(bid) / Double(max(1, opportunity.unitPrice))
                    : Double(opportunity.unitPrice) / Double(max(1, bid))
                let expertise = min(
                    1,
                    (effectiveCategoryExpertise(for: store, category: opportunity.category) * 0.6
                        + effectiveSourceExpertise(for: store, source: .corporateLot) * 0.4) / 100
                )
                let capacity = opportunity.kind == .fleetDisposal
                    ? Double(max(0, store.type.capacity - store.inventoryCount)) / Double(max(1, opportunity.count))
                    : Double(store.inventory.filter { $0.category == opportunity.category && $0.isReserved }.reduce(0) { $0 + $1.count }) / Double(max(1, opportunity.count))
                let serviceReadiness: Double
                if opportunity.kind == .fleetDisposal {
                    serviceReadiness = store.workshopBays > 0 && store.weeklyWorkshopLabor > 0
                        ? min(1, Double(store.workshopBays * store.weeklyWorkshopLabor) / Double(max(1, opportunity.count * 2)))
                        : 0
                } else {
                    serviceReadiness = 1
                }
                return priceScore * 0.50 + Double(ability) / 100 * 0.20 + expertise * 0.12
                    + min(1, capacity) * 0.08 + serviceReadiness * 0.10
            }()

            let rivalCandidates = competitors.indices.compactMap { competitorIndex -> (Int, Int, Double)? in
                let competitor = competitors[competitorIndex]
                if opportunity.kind == .fleetDisposal {
                    guard let branchIndex = competitor.branches.indices.first(where: {
                        competitor.branches[$0].inventoryCount + opportunity.count <= competitor.branches[$0].capacity
                    }), competitor.cash >= opportunity.unitPrice * opportunity.count else { return nil }
                    let branch = competitor.branches[branchIndex]
                    let bayReadiness = branch.facilities.reduce(0) { $0 + $1.workshopBays } > 0 ? 1.0 : 0.35
                    let serviceReadiness = Double(competitor.serviceAbility) / 100 * bayReadiness
                    let score = 0.50 + Double(competitor.procurementAbility) / 100 * 0.20
                        + min(0.12, competitor.expertise.category(opportunity.category) * 0.0012)
                        + (branch.marketPolicy.priorityCategories.contains(opportunity.category) ? 0.08 : 0.02)
                        + serviceReadiness * 0.10
                    return (competitorIndex, branchIndex, score)
                }
                guard let branchIndex = competitor.branches.indices.first(where: { branchIndex in
                    competitor.branches[branchIndex].inventory.filter { $0.category == opportunity.category }.reduce(0) { $0 + $1.count } >= opportunity.count
                }) else { return nil }
                let score = 0.55 + Double(competitor.salesAbility) / 100 * 0.25
                    + min(0.18, competitor.expertise.category(opportunity.category) * 0.0018)
                return (competitorIndex, branchIndex, score)
            }
            let rival = rivalCandidates.max(by: { $0.2 < $1.2 })
            if playerScore >= (rival?.2 ?? 0), let storeID = opportunity.playerStoreID, let bid = opportunity.playerUnitPrice,
               let storeIndex = stores.firstIndex(where: { $0.id == storeID }) {
                if opportunity.kind == .fleetDisposal {
                    let total = bid * opportunity.count
                    if cash >= total && stores[storeIndex].inventoryCount + opportunity.count <= stores[storeIndex].type.capacity {
                        cash -= total
                        inboundShipments.append(InboundShipment(
                            id: UUID(),
                            storeID: storeID,
                            source: .corporateLot,
                            modelID: opportunity.modelID,
                            category: opportunity.category,
                            count: opportunity.count,
                            unitCost: bid,
                            quality: opportunity.quality,
                            modelYear: opportunity.modelYear,
                            mileage: opportunity.mileage,
                            acquiredTurn: resolvingTurn,
                            monthsRemaining: 1
                        ))
                        simulationTransactionHandler?(SimulationVehicleTransaction(
                            turn: resolvingTurn,
                            kind: .acquired,
                            storeID: storeID,
                            source: .corporateLot,
                            category: opportunity.category,
                            count: opportunity.count,
                            revenue: 0,
                            cost: total
                        ))
                        corporateOpportunities[opportunityIndex].winnerName = stores[storeIndex].name
                        stores[storeIndex].expertise.add(category: opportunity.category, purpose: opportunity.purpose, source: .corporateLot, points: 3)
                        companyExpertise.add(category: opportunity.category, purpose: opportunity.purpose, source: .corporateLot, points: 3)
                    }
                } else if let cost = removeReservedCorporateInventory(storeIndex: storeIndex, opportunityID: opportunityID, category: opportunity.category, count: opportunity.count) {
                    let revenue = bid * opportunity.count
                    cash += revenue
                    stores[storeIndex].pendingManualSales += opportunity.count
                    stores[storeIndex].pendingManualRevenue += revenue
                    stores[storeIndex].pendingManualCOGS += cost
                    simulationTransactionHandler?(SimulationVehicleTransaction(
                        turn: resolvingTurn,
                        kind: .sold,
                        storeID: storeID,
                        source: nil,
                        category: opportunity.category,
                        count: opportunity.count,
                        revenue: revenue,
                        cost: cost
                    ))
                    corporateOpportunities[opportunityIndex].winnerName = stores[storeIndex].name
                    stores[storeIndex].expertise.add(category: opportunity.category, purpose: opportunity.purpose, source: .corporateLot, points: 3)
                    companyExpertise.add(category: opportunity.category, purpose: opportunity.purpose, source: .corporateLot, points: 3)
                }
            } else if let rival {
                let competitorIndex = rival.0, branchIndex = rival.1
                if opportunity.kind == .fleetDisposal {
                    let total = opportunity.unitPrice * opportunity.count
                    competitors[competitorIndex].cash -= total
                    addCompetitorInventory(competitorIndex: competitorIndex, branchIndex: branchIndex, category: opportunity.category, purpose: opportunity.purpose, count: opportunity.count, unitCost: opportunity.unitPrice, quality: opportunity.quality, productState: .stock)
                } else {
                    let revenue = opportunity.unitPrice * opportunity.count
                    if let cost = removeCompetitorInventory(competitorIndex: competitorIndex, branchIndex: branchIndex, category: opportunity.category, count: opportunity.count) {
                        competitors[competitorIndex].cash += revenue
                        competitors[competitorIndex].branches[branchIndex].currentRevenue += revenue
                        competitors[competitorIndex].branches[branchIndex].currentProfit += revenue - cost
                    }
                }
                competitors[competitorIndex].expertise.add(category: opportunity.category, purpose: opportunity.purpose, source: .corporateLot, points: 3)
                corporateOpportunities[opportunityIndex].winnerName = competitors[competitorIndex].name
            }
            releaseCorporateReservation(opportunityID: opportunityID)
            corporateOpportunities[opportunityIndex].resolved = true
            let winner = corporateOpportunities[opportunityIndex].winnerName ?? "該当なし"
            notes.append("\(opportunity.kind.name)（\(opportunity.category.name)\(opportunity.count)台）：\(winner)が受注")
        }
    }

    private func removeReservedCorporateInventory(storeIndex: Int, opportunityID: UUID, category: VehicleCategory, count: Int) -> Int? {
        var remaining = count
        var cost = 0
        for index in stores[storeIndex].inventory.indices.reversed() where remaining > 0 {
            let batch = stores[storeIndex].inventory[index]
            guard batch.corporateReservationID == opportunityID, batch.category == category else { continue }
            let removed = min(remaining, batch.count)
            cost += removed * batch.averageCost
            remaining -= removed
            stores[storeIndex].inventory[index].count -= removed
            if stores[storeIndex].inventory[index].count == 0 { stores[storeIndex].inventory.remove(at: index) }
        }
        return remaining == 0 ? cost : nil
    }

    private func removeCompetitorInventory(competitorIndex: Int, branchIndex: Int, category: VehicleCategory, count: Int) -> Int? {
        var remaining = count
        var cost = 0
        for index in competitors[competitorIndex].branches[branchIndex].inventory.indices.reversed() where remaining > 0 {
            let bucket = competitors[competitorIndex].branches[branchIndex].inventory[index]
            guard bucket.category == category else { continue }
            let removed = min(remaining, bucket.count)
            remaining -= removed
            cost += removed * bucket.averageCost
            competitors[competitorIndex].branches[branchIndex].inventory[index].count -= removed
        }
        return remaining == 0 ? cost : nil
    }

    @discardableResult
    func consignInventory(storeID: UUID, category: VehicleCategory, count: Int) -> Bool {
        guard count > 0, let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let removed = removeInventory(category: category, count: count, from: storeIndex) else { return false }
        let lane = auctionLane(for: category)
        let specialtyBonus: Double
        switch (lane, category) {
        case (.premium, .sports), (.premium, .sedan), (.premium, .suv), (.logistics, .minivan), (.logistics, .pickup), (.logistics, .suv), (.standard, .kei), (.standard, .compact): specialtyBonus = 1.08
        default: specialtyBonus = 0.98
        }
        let expected = Int(Double(max(removed.averageCost, category.purchaseCost)) * (1.06 + removed.quality * 0.08) * specialtyBonus)
        auctionConsignments.append(AuctionConsignment(id: UUID(), storeID: storeID, lane: lane, modelID: nil, category: category, count: count, expectedUnitPrice: expected, monthsRemaining: 1))
        recalculateAssets()
        save()
        return true
    }

    @discardableResult
    func consignInventory(storeID: UUID, inventoryID: UUID) -> Bool {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }) else { return false }
        let unit = stores[storeIndex].inventory[batchIndex]
        let lane = VehicleCatalog.entry(id: unit.modelID).map { auctionLane(for: $0) }
            ?? auctionLane(for: unit.category)
        stores[storeIndex].inventory[batchIndex].count -= 1
        if stores[storeIndex].inventory[batchIndex].count == 0 {
            stores[storeIndex].inventory.remove(at: batchIndex)
        }
        let specialtyBonus: Double
        switch (lane, unit.category) {
        case (.premium, .sports), (.premium, .sedan), (.premium, .suv), (.logistics, .minivan), (.logistics, .pickup), (.logistics, .suv), (.standard, .kei), (.standard, .compact): specialtyBonus = 1.08
        default: specialtyBonus = 0.98
        }
        let expected = Int(Double(max(unit.averageCost, unit.category.purchaseCost)) * (1.06 + unit.quality * 0.08) * specialtyBonus)
        auctionConsignments.append(AuctionConsignment(id: UUID(), storeID: storeID, lane: lane, modelID: unit.modelID, category: unit.category, count: 1, expectedUnitPrice: expected, monthsRemaining: 1))
        recalculateAssets()
        save()
        return true
    }

    func updateStore(_ store: Store) {
        guard let index = stores.firstIndex(where: { $0.id == store.id }) else { return }
        var changed = store
        changed.marketPolicy.normalize()
        if changed.marketPolicy != stores[index].marketPolicy {
            changed.pendingMarketPolicy = changed.marketPolicy
            changed.marketPolicy = stores[index].marketPolicy
        }
        changed.facilities = changed.facilities.filter { $0.minimumGridCells <= changed.plotIDs.count }
        if !changed.hasManager {
            changed.delegateStaff = false
            changed.delegatePricing = false
            changed.delegateMarketing = false
            changed.delegateProcurement = false
            changed.delegateService = false
        }
        stores[index] = changed
        synchronizeParcelUse(for: changed)
        save()
    }

    @discardableResult
    func installFacility(_ facility: StoreFacility, at storeID: UUID) -> Bool {
        guard let index = stores.firstIndex(where: { $0.id == storeID }),
              !stores[index].facilities.contains(facility),
              facility.minimumGridCells <= stores[index].plotIDs.count,
              cash >= facility.installationCost else { return false }
        cash -= facility.installationCost
        finance.investingCF -= facility.installationCost
        stores[index].facilities.insert(facility)
        recalculateAssets()
        save()
        return true
    }

    var managerHiringCost: Int { 180 }
    var maxEmployeesPerStore: Int { 15 }
    var employeeTrainingCost: Int { 30 }

    func monthlyPersonnelCost(for store: Store) -> Int {
        store.employeeMonthlyPayroll + (store.manager?.monthlySalary ?? 0)
    }

    func weeklyPersonnelCost(for store: Store) -> Int {
        let monthlyCost = monthlyPersonnelCost(for: store)
        let base = monthlyCost / 4
        let remainder = monthlyCost % 4
        return base + (weekOfMonth <= remainder ? 1 : 0)
    }

    func managerCandidate(for storeID: UUID) -> StoreManager? {
        guard let store = stores.first(where: { $0.id == storeID }) else { return nil }
        let index = (store.plotID * 7 + turn / 4) % Self.managerCandidates.count
        return Self.managerCandidates[index]
    }

    func employeeCandidates(for storeID: UUID) -> [StoreEmployee] {
        guard let store = stores.first(where: { $0.id == storeID }) else { return [] }
        let employedIDs = Set(stores.flatMap(\.employees).map(\.id))
        let surnames = [
            "佐藤", "鈴木", "高橋", "田中", "伊藤", "渡辺", "山本", "中村",
            "小林", "加藤", "吉田", "山田", "佐々木", "山口", "松本", "井上"
        ]
        let givenNames = [
            "悠斗", "美月", "海斗", "さくら", "颯太", "結衣", "陸", "葵",
            "陽菜", "蓮", "凛", "直樹", "真央", "大地", "彩", "千尋"
        ]

        return (0..<6).compactMap { slot -> StoreEmployee? in
            let seed = simulationSeed
                &+ turn &* 10_007
                &+ store.plotID &* 379
                &+ slot &* 1_543
            let candidateID = deterministicEmployeeID(seed: seed)
            guard !employedIDs.contains(candidateID) else { return nil }

            let randomSkill: (ClosedRange<Int>, Int) -> Int = { range, salt in
                let count = range.upperBound - range.lowerBound + 1
                return range.lowerBound
                    + min(count - 1, Int(self.transactionRoll(seed: seed &+ salt) * Double(count)))
            }

            // 毎週、販売・仕入・調査・整備の各専門家を最低1人ずつ紹介する。
            // 残り2枠は専門を独立抽選し、若手も含む採用上の選択肢にする。
            let specialtyRotation = (turn + store.plotID) % 4
            let primary = slot < 4
                ? (slot + specialtyRotation) % 4
                : min(3, Int(transactionRoll(seed: seed &+ 101) * 4))
            let careerTier = slot < 4
                ? 1 + min(2, Int(transactionRoll(seed: seed &+ 107) * 3))
                : min(3, Int(transactionRoll(seed: seed &+ 107) * 4))

            let primaryRange: ClosedRange<Int>
            let commercialSupportRange: ClosedRange<Int>
            let crossTrackRange: ClosedRange<Int>
            switch careerTier {
            case 0:
                primaryRange = 58...72
                commercialSupportRange = 28...48
                crossTrackRange = 16...35
            case 1:
                primaryRange = 76...86
                commercialSupportRange = 38...60
                crossTrackRange = 20...40
            case 2:
                primaryRange = 87...94
                commercialSupportRange = 45...68
                crossTrackRange = 24...45
            default:
                primaryRange = 94...99
                commercialSupportRange = 52...74
                crossTrackRange = 28...50
            }

            var skills: [Int]
            if primary == 3 {
                // 整備は別職種。技術者は整備を主能力とし、営業系3能力は低く抑える。
                skills = (0..<3).map { randomSkill(crossTrackRange, 211 + $0 * 17) }
                skills.append(randomSkill(primaryRange, 281))
            } else {
                // 営業系は販売・仕入・調査のうち一分野に特化し、整備とは分離する。
                skills = (0..<3).map { randomSkill(commercialSupportRange, 311 + $0 * 17) }
                skills[primary] = randomSkill(primaryRange, 381)
                skills.append(randomSkill(crossTrackRange, 387))
            }

            let compensationIndex = min(
                EmployeeCompensationType.allCases.count - 1,
                Int(transactionRoll(seed: seed &+ 601) * Double(EmployeeCompensationType.allCases.count))
            )
            let compensation = EmployeeCompensationType.allCases[compensationIndex]
            let surname = surnames[min(
                surnames.count - 1,
                Int(transactionRoll(seed: seed &+ 607) * Double(surnames.count))
            )]
            let givenName = givenNames[min(
                givenNames.count - 1,
                Int(transactionRoll(seed: seed &+ 613) * Double(givenNames.count))
            )]
            var candidate = StoreEmployee(
                id: candidateID,
                name: "\(surname) \(givenName)",
                salesSkill: skills[0],
                procurementSkill: skills[1],
                researchSkill: skills[2],
                serviceSkill: skills[3],
                monthlySalary: 24,
                commissionRate: compensation.commissionRate
            )
            candidate.monthlySalary = Int(
                (Double(candidate.marketMonthlySalary) * compensation.salaryFactor).rounded()
            )
            return candidate
        }
    }

    private func deterministicEmployeeID(seed: Int) -> UUID {
        func mixed(_ input: UInt64) -> UInt64 {
            var value = input &+ 0x9E3779B97F4A7C15
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
        let first = mixed(UInt64(bitPattern: Int64(truncatingIfNeeded: seed)))
        let second = mixed(first ^ UInt64(bitPattern: Int64(truncatingIfNeeded: simulationSeed)))
        return UUID(uuid: (
            UInt8(truncatingIfNeeded: first >> 56),
            UInt8(truncatingIfNeeded: first >> 48),
            UInt8(truncatingIfNeeded: first >> 40),
            UInt8(truncatingIfNeeded: first >> 32),
            UInt8(truncatingIfNeeded: first >> 24),
            UInt8(truncatingIfNeeded: first >> 16),
            UInt8(truncatingIfNeeded: first >> 8),
            UInt8(truncatingIfNeeded: first),
            UInt8(truncatingIfNeeded: second >> 56),
            UInt8(truncatingIfNeeded: second >> 48),
            UInt8(truncatingIfNeeded: second >> 40),
            UInt8(truncatingIfNeeded: second >> 32),
            UInt8(truncatingIfNeeded: second >> 24),
            UInt8(truncatingIfNeeded: second >> 16),
            UInt8(truncatingIfNeeded: second >> 8),
            UInt8(truncatingIfNeeded: second)
        ))
    }

    private func interpolatedEmployeeEffect(score: Double, low: Double, high: Double) -> Double {
        let progress = min(1, max(0, (score - 20) / 79))
        return low + (high - low) * progress
    }

    func employeeSalesCloseAdjustment(_ employee: StoreEmployee) -> Double {
        interpolatedEmployeeEffect(score: employee.salesComposite, low: -0.10, high: 0.15)
    }

    func employeeSalesPriceRealization(_ employee: StoreEmployee) -> Double {
        interpolatedEmployeeEffect(score: employee.salesComposite, low: -0.04, high: 0.04)
    }

    func employeeAlternativeProposalAdjustment(_ employee: StoreEmployee, lead: BuyerLead, batch: InventoryBatch) -> Double {
        guard !inventoryPreferenceMatches(batch, preference: lead.preference) else { return 0 }
        return interpolatedEmployeeEffect(score: employee.salesComposite, low: -0.10, high: 0.40)
    }

    func employeeSalesCloseAdjustment(for storeID: UUID) -> Double {
        guard let store = stores.first(where: { $0.id == storeID }), store.autoSales,
              let employee = store.employees
            .filter({ $0.assignment == .sales })
            .max(by: { $0.salesComposite < $1.salesComposite }) else { return 0 }
        return employeeSalesCloseAdjustment(employee)
    }

    func employeeProcurementCloseAdjustment(_ employee: StoreEmployee) -> Double {
        interpolatedEmployeeEffect(score: employee.procurementComposite, low: -0.12, high: 0.15)
    }

    func employeeAppraisalAccuracyBonus(_ employee: StoreEmployee) -> Int {
        Int(interpolatedEmployeeEffect(score: employee.appraisalComposite, low: -18, high: 24).rounded())
    }

    func employeeAppraisalAccuracyBonus(for storeID: UUID) -> Int {
        guard let store = stores.first(where: { $0.id == storeID }) else { return 0 }
        let facilityBonus = store.facilities.contains(.serviceWorkshop) ? 5 : 0
        let employeeBonus = store.employees
            .filter { $0.assignment == .service }
            .map(employeeAppraisalAccuracyBonus)
            .max() ?? 0
        return facilityBonus + employeeBonus
    }

    func appraisalConfidence(
        for storeID: UUID,
        source: ProcurementSource = .storePurchase
    ) -> Int {
        guard let store = stores.first(where: { $0.id == storeID }) else { return 35 }
        let skill = store.employees
            .filter { $0.assignment == .service }
            .map(\.serviceSkill)
            .max() ?? 35
        let facilityBonus = store.facilities.contains(.serviceWorkshop)
            && [.storePurchase, .tradeIn].contains(source) ? 5 : 0
        return min(95, max(20, skill + facilityBonus))
    }

    func vehicleAssessment(
        source: ProcurementSource,
        condition: VehicleConditionProfile,
        fault: MechanicalFaultSeverity,
        actualRepairCost: Int,
        storeID: UUID,
        seed: Int,
        conditionVerified: Bool? = nil
    ) -> VehicleAssessment {
        if conditionVerified ?? source.isConditionVerified {
            return VehicleAssessment(
                source: source,
                isVerified: true,
                confidence: 100,
                conditionRange: condition.score...condition.score,
                repairCostRange: actualRepairCost...actualRepairCost,
                detectedFault: fault
            )
        }
        let confidence = appraisalConfidence(for: storeID, source: source)
        let succeeded = transactionRoll(seed: seed + 701) < Double(confidence) / 100
        let conditionRadius = max(2, Int(ceil(Double(100 - confidence) / 5)))
        let direction = transactionRoll(seed: seed + 709) < 0.5 ? -1 : 1
        let miss = succeeded ? 0 : direction * max(2, conditionRadius / 2)
        let center = min(100, max(0, condition.score + miss))
        let conditionRange = max(0, center - conditionRadius)...min(100, center + conditionRadius)
        let repairRadius = max(2, Int(ceil(Double(max(6, actualRepairCost)) * Double(100 - confidence) / 90)))
        let repairMiss = succeeded ? 0 : direction * max(2, repairRadius / 2)
        let repairCenter = max(0, actualRepairCost + repairMiss)
        return VehicleAssessment(
            source: source,
            isVerified: false,
            confidence: confidence,
            conditionRange: conditionRange,
            repairCostRange: max(0, repairCenter - repairRadius)...max(0, repairCenter + repairRadius),
            detectedFault: succeeded ? fault : nil
        )
    }

    func purchaseAssessment(for item: PurchaseCase) -> VehicleAssessment {
        let requiredFaultRepair = estimatedSourcingRepairCost(
            category: item.category,
            fault: item.fault,
            condition: item.condition,
            storeID: item.storeID
        )
        return vehicleAssessment(
            source: .storePurchase,
            condition: item.condition,
            fault: item.fault,
            actualRepairCost: purchaseRepairCost(for: item) + requiredFaultRepair,
            storeID: item.storeID,
            seed: item.modelYear * 101 + item.mileage / 100 + categoryIndex(item.category)
        )
    }

    func networkAuctionAssessment(for listing: NetworkAuctionListing, storeID: UUID) -> VehicleAssessment {
        vehicleAssessment(
            source: .networkAuction,
            condition: listing.condition,
            fault: listing.fault,
            actualRepairCost: estimatedSourcingRepairCost(
                category: listing.category,
                fault: listing.fault,
                condition: listing.condition,
                storeID: storeID
            ),
            storeID: storeID,
            seed: listing.modelYear * 103 + listing.mileage / 100 + categoryIndex(listing.category),
            conditionVerified: listing.kind.isConditionVerified
        )
    }

    func auctionExpectedGrossProfit(
        for listing: AuctionListing,
        storeID: UUID,
        maxPrice: Int
    ) -> Int? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID) else { return nil }
        let retail = vehicleRetailValue(
            modelID: listing.modelID,
            category: listing.category,
            modelYear: listing.modelYear,
            mileage: listing.mileage,
            quality: listing.condition.quality,
            in: plot.district
        )
        let repair = estimatedSourcingRepairCost(
            category: listing.category,
            fault: listing.fault,
            condition: listing.condition,
            storeID: storeID
        )
        return retail - maxPrice - listing.lane.fee - listing.lane.shippingCost - repair
    }

    func networkAuctionExpectedGrossProfit(
        for listing: NetworkAuctionListing,
        storeID: UUID,
        maxPrice: Int
    ) -> Int? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID) else { return nil }
        let assessment = networkAuctionAssessment(for: listing, storeID: storeID)
        let retail = vehicleRetailValue(
            modelID: listing.modelID,
            category: listing.category,
            modelYear: listing.modelYear,
            mileage: listing.mileage,
            quality: Double(assessment.estimatedCondition) / 100,
            in: plot.district
        )
        return retail
            - maxPrice
            - listing.fee
            - listing.shippingCost
            - assessment.repairCostRange.upperBound
    }

    func tradeInAssessment(for tradeIn: TradeInVehicle, storeID: UUID) -> VehicleAssessment {
        let score = tradeIn.conditionScore
        let profile = VehicleConditionProfile(exterior: score, interior: score, mechanical: score)
        let fault: MechanicalFaultSeverity = tradeIn.repairCost > 0 ? .minor : .none
        return vehicleAssessment(
            source: .tradeIn,
            condition: profile,
            fault: fault,
            actualRepairCost: tradeInRepairCost(for: tradeIn, storeID: storeID),
            storeID: storeID,
            seed: tradeIn.modelYear * 107 + tradeIn.mileage / 100 + categoryIndex(tradeIn.category)
        )
    }

    func hasServiceTechnician(storeID: UUID) -> Bool {
        stores.first(where: { $0.id == storeID })?.employees.contains {
            $0.assignment == .service
        } ?? false
    }

    func employeeServiceCostDiscount(for storeID: UUID) -> Int {
        guard let skill = stores.first(where: { $0.id == storeID })?.employees
            .filter({ $0.assignment == .service })
            .map(\.serviceComposite)
            .max() else { return 0 }
        return Int(interpolatedEmployeeEffect(score: skill, low: 5, high: 40).rounded())
    }

    func faultDetectionPercent(for storeID: UUID) -> Int {
        appraisalConfidence(for: storeID, source: .storePurchase)
    }

    func purchaseRepairCost(for item: PurchaseCase) -> Int {
        max(6, item.repairCost)
    }

    func purchaseExpectedGrossProfit(for item: PurchaseCase) -> Int {
        let assessment = purchaseAssessment(for: item)
        let estimatedRepairCost: Int
        if let project = item.suggestedProjectKind,
           let store = stores.first(where: { $0.id == item.storeID }) {
            let conversionBase = max(0, item.repairCost - item.asIsRepairCost)
            let partner = OutsourcePartnerKind.partner(for: project)
            let activeInventoryProjects = store.inventory.filter {
                $0.workshopProject?.outsourced == false
                    && $0.workshopProject?.kind.usesCustomizationBay == project.usesCustomizationBay
            }.count
            let activeCustomerProjects = project.usesCustomizationBay
                ? customerCustomizationOrders.filter { $0.storeID == store.id && $0.status == .active }.count
                : 0
            let canDoInHouse = store.bays(for: project) > activeInventoryProjects + activeCustomerProjects
                && store.employees.contains(where: { $0.assignment == .service })
            let staffDiscount = canDoInHouse ? employeeServiceCostDiscount(for: item.storeID) : 0
            let facilityDiscount = canDoInHouse ? 30 : 0
            let finalRate = max(30, 100 - staffDiscount - facilityDiscount)
            let conversionCost = Int(
                (Double(conversionBase) * partner.costMultiplier * Double(finalRate) / 100).rounded()
            )
            estimatedRepairCost = item.asIsRepairCost
                + conversionCost
                + estimatedSourcingRepairCost(
                    category: item.category,
                    fault: item.fault,
                    condition: item.condition,
                    storeID: item.storeID
                )
        } else {
            estimatedRepairCost = assessment.estimatedRepairCost
        }
        let uncertaintyBuffer = assessment.isVerified
            ? 0
            : max(2, estimatedRepairCost * max(0, 100 - assessment.confidence) / 250)
        return (item.expectedSaleAfterAppraisal - item.askingPrice - estimatedRepairCost - uncertaintyBuffer)
            * item.lotCount
    }

    func tradeInRepairCost(for tradeIn: TradeInVehicle, storeID: UUID) -> Int {
        guard tradeIn.repairCost > 0 else { return 0 }
        guard let store = stores.first(where: { $0.id == storeID }) else { return tradeIn.repairCost }
        let staffDiscount = employeeServiceCostDiscount(for: storeID)
        let facilityDiscount = store.serviceBays > 0 ? 30 : 0
        return max(1, tradeIn.repairCost * max(30, 100 - staffDiscount - facilityDiscount) / 100)
    }

    func assignedEmployees(storeID: UUID, assignment: EmployeeAssignment) -> [StoreEmployee] {
        stores.first(where: { $0.id == storeID })?.employees.filter { $0.assignment == assignment } ?? []
    }

    func employeeMarketingScore(for storeID: UUID) -> Double {
        guard let store = stores.first(where: { $0.id == storeID }), store.autoMarketing else { return 50 }
        let scores = store.employees.filter { $0.assignment == .research }.map(\.researchComposite).sorted(by: >)
        guard let lead = scores.first else { return 50 }
        return min(99, lead + scores.dropFirst().reduce(0) { $0 + max(0, $1 - 50) * 0.25 })
    }

    func employeeMarketingEfficiency(for storeID: UUID, buyers: Bool) -> Double {
        guard let store = stores.first(where: { $0.id == storeID }), store.autoMarketing,
              store.employees.contains(where: { $0.assignment == .research }) else { return 1 }
        let base = interpolatedEmployeeEffect(score: employeeMarketingScore(for: storeID), low: 0.65, high: 1.50)
        let policyFactor: Double
        switch (store.marketingPolicy, buyers) {
        case (.buyers, true), (.sellers, false): policyFactor = 1.15
        case (.buyers, false), (.sellers, true): policyFactor = 0.85
        default: policyFactor = 1
        }
        return base * policyFactor
    }

    func marketResearchScore(for storeID: UUID) -> Double {
        guard let store = stores.first(where: { $0.id == storeID }) else { return 50 }
        let scores = store.employees.filter { $0.assignment == .research }.map { Double($0.researchSkill) }.sorted(by: >)
        guard let lead = scores.first else { return 50 }
        return min(99, lead + scores.dropFirst().reduce(0) { $0 + max(0, $1 - 50) * 0.25 })
    }

    func hasMarketResearcher(storeID: UUID) -> Bool {
        guard let store = stores.first(where: { $0.id == storeID }) else { return false }
        return store.employees.contains { $0.assignment == .research }
    }

    func auctionWinnerName(for result: AuctionBidResult) -> String? {
        result.winningCompetitorID.map { competitorName(for: $0) }
    }

    func recentCompetitorAuctionPurchases(competitorID: UUID, weeks: Int = 12) -> [CompetitorAuctionPurchase] {
        competitorAuctionPurchases.filter {
            $0.competitorID == competitorID && $0.purchasedTurn >= max(0, turn - weeks + 1)
        }
    }

    func competitorAuctionTrend(competitorID: UUID, storeID: UUID) -> String {
        guard hasMarketResearcher(storeID: storeID) else { return "市場調査担当を配置すると仕入れ動向が判明します" }
        let purchases = recentCompetitorAuctionPurchases(competitorID: competitorID)
        guard !purchases.isEmpty else { return "直近12週間は目立ったAA仕入れなし" }
        let counts = Dictionary(grouping: purchases, by: \.category).mapValues(\.count)
        let categories = counts.sorted {
            $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value
        }.prefix(2).map { "\($0.key.name)\($0.value)台" }.joined(separator: "・")
        let visibleModels = marketResearchScore(for: storeID) >= 70 ? 3 : 1
        let models = purchases.prefix(visibleModels).map(\.vehicleName).joined(separator: "、")
        let range = marketForecastRange(value: purchases.count, storeID: storeID)
        return "推定\(range.lowerBound)〜\(range.upperBound)台増・\(categories)｜最近：\(models)"
    }

    func marketForecastErrorRate(for storeID: UUID) -> Double {
        guard hasMarketResearcher(storeID: storeID) else { return 0.25 }
        let score = marketResearchScore(for: storeID)
        return interpolatedEmployeeEffect(score: score, low: 0.18, high: 0.02)
    }

    func competitorInformationErrorRate(for storeID: UUID?) -> Double {
        guard let storeID, hasMarketResearcher(storeID: storeID) else { return 0.25 }
        let score = marketResearchScore(for: storeID)
        return interpolatedEmployeeEffect(score: score, low: 0.18, high: 0.02)
    }

    func competitorEstimateRange(value: Int, storeID: UUID?, seed: Int = 0) -> ClosedRange<Int> {
        let error = competitorInformationErrorRate(for: storeID)
        let offset = (transactionRoll(seed: turn * 613 + seed) - 0.5) * error
        let center = Double(value) * (1 + offset)
        return max(0, Int((center * (1 - error)).rounded()))...max(0, Int((center * (1 + error)).rounded()))
    }

    func segmentResearchHorizon(for storeID: UUID) -> Int {
        guard hasMarketResearcher(storeID: storeID) else { return 0 }
        let score = marketResearchScore(for: storeID)
        if score >= 90 { return 8 }
        if score >= 75 { return 5 }
        return 2
    }

    func trendSignal(for productKind: MarketProductKind, storeID: UUID) -> TrendSignal? {
        guard productKind.isNiche else { return nil }
        guard let store = stores.first(where: { $0.id == storeID }),
              let storeDistrict = plot(id: store.plotID)?.district else { return nil }
        let relevantCategories = Set(nicheCategories(for: productKind))
        func appliesToStore(_ trend: SegmentTrend) -> Bool {
            trend.kind.productKind == productKind
                && trend.districts.contains(storeDistrict)
                && !trend.categories.isDisjoint(with: relevantCategories)
        }
        let horizon = segmentResearchHorizon(for: storeID)
        let matchingActive = segmentTrends.first {
            appliesToStore($0) && $0.startTurn <= turn && $0.endTurn > turn
        }
        if let matchingActive {
            return TrendSignal(
                id: matchingActive.id.uuidString,
                kind: matchingActive.kind,
                startRange: matchingActive.startTurn...matchingActive.startTurn,
                confidenceRange: 100...100,
                isFalsePositive: false
            )
        }
        guard horizon > 0 else { return nil }
        if let upcoming = segmentTrends.first(where: {
            appliesToStore($0) && $0.startTurn > turn && $0.startTurn <= turn + horizon
        }) {
            let score = marketResearchScore(for: storeID)
            let confidence: ClosedRange<Int> = score >= 85 ? 80...95 : score >= 70 ? 70...90 : 55...75
            let uncertainty = score >= 85 ? 1 : score >= 70 ? 2 : 3
            return TrendSignal(
                id: upcoming.id.uuidString,
                kind: upcoming.kind,
                startRange: max(turn + 1, upcoming.startTurn - uncertainty)...upcoming.startTurn + uncertainty,
                confidenceRange: confidence,
                isFalsePositive: false
            )
        }
        let falseRoll = transactionRoll(seed: simulationSeed &+ turn &* 9_007 &+ productKind.rawValue.count * 131)
        guard falseRoll < 0.15 else { return nil }
        let kind = SegmentTrendKind.allCases.first(where: { $0.productKind == productKind }) ?? .valueRebuild
        return TrendSignal(
            id: "false-\(turn)-\(productKind.rawValue)",
            kind: kind,
            startRange: turn + 1...turn + max(2, horizon),
            confidenceRange: 35...60,
            isFalsePositive: true
        )
    }

    private func segmentMarginRate(for kind: MarketProductKind) -> Double {
        switch kind {
        case .standard: 0.10
        case .repaired: 0.18
        case .refurbished: 0.25
        case .camper: 0.30
        case .workCargo: 0.22
        case .outdoor: 0.22
        case .collector: 0.35
        case .sportTuned: 0.34
        case .welfare: 0.27
        case .mobileShop: 0.32
        }
    }

    private func segmentCapitalMultiplier(for kind: MarketProductKind) -> Double {
        switch kind {
        case .standard: 8.0
        case .repaired: 1.2
        case .workCargo: 1.6
        case .outdoor: 1.5
        case .refurbished: 2.4
        case .camper: 3.8
        case .collector: 4.2
        case .sportTuned: 3.0
        case .welfare: 2.2
        case .mobileShop: 2.8
        }
    }

    private func opportunityArchetype(for key: MarketSegmentKey) -> (name: String, tier: String) {
        switch key.productKind {
        case .standard: ("資本型総合量販", "後半")
        case .repaired: ("故障車再生", "序盤向け")
        case .workCargo: ("職人・配送仕様", "序盤向け")
        case .outdoor: ("アウトドア仕様", "序盤向け")
        case .camper: ("本格キャンピング", "資本型")
        case .refurbished where key.category == .sedan: ("高級セダン再生", "資本型")
        case .refurbished: ("完全再生", "中盤")
        case .collector: ("旧車・コレクター", "資本型")
        case .sportTuned: ("スポーツチューニング", "中盤")
        case .welfare: ("福祉車両", "中盤")
        case .mobileShop: ("移動販売車", "中盤")
        }
    }

    func segmentOpportunityReports(storeID: UUID, district: DistrictKind) -> [SegmentOpportunityReport] {
        guard let store = stores.first(where: { $0.id == storeID }) else { return [] }
        let fourWeekPool = max(1, weeklyBuyerPool(in: district) * 4)
        let error = marketForecastErrorRate(for: storeID)
        var reports: [SegmentOpportunityReport] = []
        for productKind in MarketProductKind.allCases {
            for category in nicheCategories(for: productKind) {
                let purpose = productKind == .standard
                    ? defaultCustomerPurpose(for: category, seed: simulationSeed + categoryIndex(category) * 31)
                    : productKind.customerPurpose
                let key = MarketSegmentKey(district: district, category: category, purpose: purpose, productKind: productKind)
                let share = productKind == .standard
                    ? max(0.72, 1 - MarketProductKind.allCases.filter(\.isNiche).reduce(0.0) { $0 + baseNicheDemandShare(for: $1, in: district) })
                        / Double(max(1, VehicleCategory.allCases.count))
                    : baseNicheDemandShare(for: productKind, in: district)
                        * categoryDemandWeight(category, among: nicheCategories(for: productKind), in: district)
                let trend = activeTrendMultiplier(for: key)
                let demandFloor = hasFourWeekNicheDemandFloor(
                    productKind: productKind,
                    district: district
                ) ? 1 : 0
                let projectedDemand = max(demandFloor, Int((Double(fourWeekPool) * share * trend).rounded()))
                let demandLow = max(demandFloor, Int(Double(projectedDemand) * (1 - error)))
                let demandHigh = max(demandFloor, Int(ceil(Double(projectedDemand) * (1 + error))))
                let demandRange: ClosedRange<Int> = demandLow...demandHigh
                let competitorInventory = competingInventory(for: key)
                let inventoryRange = competitorEstimateRange(value: competitorInventory, storeID: storeID, seed: key.id.count)
                let recent = segmentMarkets[key]?.recentFourWeeks ?? []
                let recentUnmet = recent.reduce(0) { $0 + $1.unmetDemand }
                let unmetMid = max(recentUnmet, projectedDemand - competitorInventory)
                let unmetRange = max(0, Int(Double(unmetMid) * (1 - error)))...max(0, Int(ceil(Double(unmetMid) * (1 + error))))
                let unitMargin = max(5, Int(Double(category.purchaseCost) * segmentMarginRate(for: productKind) * segmentWillingnessFactor(for: key)))
                let marginRange = max(1, Int(Double(unitMargin) * (1 - error)))...max(1, Int(ceil(Double(unitMargin) * (1 + error))))
                let requiredCapital = max(25, Int(Double(category.purchaseCost) * segmentCapitalMultiplier(for: productKind)))
                let capitalRange = max(1, Int(Double(requiredCapital) * (1 - error)))...max(1, Int(ceil(Double(requiredCapital) * (1 + error))))
                let competitorsInSegment = competitors.filter { competitor in
                    competitor.branches.contains { branch in
                        plot(id: branch.plotID)?.district == district
                            && branch.inventory.contains {
                                $0.category == category
                                    && $0.count > 0
                                    && marketProductMatches(actual: $0.marketProductKind, desired: productKind)
                            }
                    }
                }.map(\.name)
                let status: SegmentMarketStatus
                if demandRange.lowerBound > 0 && competitorInventory == 0 {
                    status = .blueOcean
                } else if trend > 1.05 {
                    status = .growing
                } else if competitorInventory > max(1, demandRange.upperBound) {
                    status = .crowded
                } else if recent.count >= 2, recent.suffix(2).last?.demand ?? 0 < recent.suffix(2).first?.demand ?? 0 {
                    status = .shrinking
                } else {
                    status = .balanced
                }
                let matchingInventory = store.inventory.filter {
                    $0.category == category && marketProductMatches(actual: marketProductKind(for: $0), desired: productKind)
                }.reduce(0) { $0 + $1.count }
                let policyFit = store.marketPolicy.priorityCategories.isEmpty || store.marketPolicy.priorityCategories.contains(category)
                let readiness = matchingInventory > 0 ? "対応在庫\(matchingInventory)台"
                    : policyFit ? "方針適合・商品化待ち" : "方針変更が必要"
                let synergy = policyFit ? 1.15 : 0.85
                let score = Double(max(0, unmetMid) * unitMargin) * synergy / Double(max(1, requiredCapital)) * 100
                let archetype = opportunityArchetype(for: key)
                reports.append(SegmentOpportunityReport(
                    key: key,
                    archetype: archetype.name,
                    capitalTier: archetype.tier,
                    fourWeekDemand: demandRange,
                    competingStores: competitorsInSegment,
                    competingInventory: inventoryRange,
                    unmetDemand: unmetRange,
                    estimatedUnitMargin: marginRange,
                    requiredWorkingCapital: capitalRange,
                    opportunityScore: score,
                    status: status,
                    trendMultiplier: trend,
                    trendSignal: trendSignal(for: productKind, storeID: storeID),
                    readiness: readiness
                ))
            }
        }
        return reports.sorted {
            if $0.status == .blueOcean && $1.status != .blueOcean { return true }
            if $1.status == .blueOcean && $0.status != .blueOcean { return false }
            return $0.opportunityScore > $1.opportunityScore
        }
    }

    private var marketOverviewSpecialtyKinds: [MarketProductKind] {
        [.camper, .workCargo, .outdoor, .collector, .sportTuned, .welfare, .mobileShop]
    }

    private func competitorTargetsSpecialty(
        _ competitor: Competitor,
        productKind: MarketProductKind,
        district: DistrictKind
    ) -> Bool {
        competitor.segmentTargetShare.contains { entry in
            entry.value > 0
                && entry.key.district == district
                && entry.key.productKind == productKind
        }
    }

    private func competitorBranchHandlesSpecialty(
        _ branch: CompetitorBranch,
        competitor: Competitor,
        productKind: MarketProductKind,
        district: DistrictKind
    ) -> Bool {
        branch.inventory.contains {
            $0.count > 0 && $0.marketProductKind == productKind
        }
            || branch.productizationQueue.contains {
                $0.count > 0 && $0.marketProductKind == productKind
            }
            || competitorTargetsSpecialty(
                competitor,
                productKind: productKind,
                district: district
            )
    }

    func districtSpecialtyReports(
        storeID: UUID,
        district: DistrictKind
    ) -> [DistrictSpecialtyReport] {
        let opportunities = segmentOpportunityReports(storeID: storeID, district: district)

        return marketOverviewSpecialtyKinds.map { productKind in
            let matchingOpportunities = opportunities.filter {
                $0.key.productKind == productKind
            }
            var branchCount = 0
            var competitorNames: Set<String> = []

            for competitor in competitors {
                let matchingBranches = competitor.branches.filter { branch in
                    plot(id: branch.plotID)?.district == district
                        && competitorBranchHandlesSpecialty(
                            branch,
                            competitor: competitor,
                            productKind: productKind,
                            district: district
                        )
                }
                if !matchingBranches.isEmpty {
                    branchCount += matchingBranches.count
                    competitorNames.insert(competitor.name)
                }
            }

            let demandLow = matchingOpportunities.reduce(0) {
                $0 + $1.fourWeekDemand.lowerBound
            }
            let demandHigh = matchingOpportunities.reduce(0) {
                $0 + $1.fourWeekDemand.upperBound
            }
            let inventoryLow = matchingOpportunities.reduce(0) {
                $0 + $1.competingInventory.lowerBound
            }
            let inventoryHigh = matchingOpportunities.reduce(0) {
                $0 + $1.competingInventory.upperBound
            }

            return DistrictSpecialtyReport(
                productKind: productKind,
                competitorBranchCount: branchCount,
                competitorNames: competitorNames.sorted(),
                fourWeekDemand: demandLow...demandHigh,
                competingInventory: inventoryLow...inventoryHigh
            )
        }
    }

    func districtSpecialtyBranchCount(in district: DistrictKind) -> Int {
        var branchIDs: Set<Int> = []
        for competitor in competitors {
            for branch in competitor.branches where plot(id: branch.plotID)?.district == district {
                let handlesSpecialty = marketOverviewSpecialtyKinds.contains { productKind in
                    competitorBranchHandlesSpecialty(
                        branch,
                        competitor: competitor,
                        productKind: productKind,
                        district: district
                    )
                }
                if handlesSpecialty {
                    branchIDs.insert(branch.plotID)
                }
            }
        }
        return branchIDs.count
    }

    func marketForecastRange(value: Int, storeID: UUID) -> ClosedRange<Int> {
        forecastRange(value: value, storeID: storeID, horizonWeeks: 1, seedSalt: 0)
    }

    private func forecastRange(value: Int, storeID: UUID, horizonWeeks: Int, seedSalt: Int) -> ClosedRange<Int> {
        let horizonPenalty = 1 + Double(max(0, horizonWeeks - 1)) * 0.08
        let error = min(0.42, marketForecastErrorRate(for: storeID) * horizonPenalty)
        let seed = turn * 401 + (stores.first(where: { $0.id == storeID })?.plotID ?? 0) + seedSalt
        let centerError = (transactionRoll(seed: seed) - 0.5) * error
        let center = Double(value) * (1 + centerError)
        let halfWidth = Double(value) * error / 2
        return max(0, Int((center - halfWidth).rounded()))...max(0, Int((center + halfWidth).rounded()))
    }

    func marketForecastHorizon(for storeID: UUID) -> Int {
        guard hasMarketResearcher(storeID: storeID) else { return 1 }
        return marketResearchScore(for: storeID) >= 70 ? 3 : 2
    }

    func marketIntelligence(for storeID: UUID) -> MarketIntelligenceReport {
        let horizon = marketForecastHorizon(for: storeID)
        let projection = projectedMarketState(weeks: horizon)
        let error = marketForecastErrorRate(for: storeID)
        let gasoline = forecastRange(value: Int(projection.gasoline.rounded()), storeID: storeID, horizonWeeks: horizon, seedSalt: 17)
        let nikkei = forecastRange(value: Int(projection.nikkei.rounded()), storeID: storeID, horizonWeeks: horizon, seedSalt: 29)
        let demand = forecastRange(value: Int((projection.demand * 100).rounded()), storeID: storeID, horizonWeeks: horizon, seedSalt: 43)
        let event = upcomingMarketShock(within: horizon)
        let shortTerm: String
        if let event {
            if !hasMarketResearcher(storeID: storeID) {
                shortTerm = "市場変動の兆候あり。専門担当なら発生要因まで先読みできます"
            } else if marketResearchScore(for: storeID) >= 70 {
                shortTerm = "\(horizon)週以内：\(event.title)の可能性が高い"
            } else {
                shortTerm = event.eventKind == .fuelPrice
                    ? "2週以内：燃料相場を大きく動かす供給・需要イベントの兆候"
                    : "2週以内：景気を大きく動かすイベントの兆候"
            }
        } else {
            shortTerm = "\(horizon)週先まで大型イベントの兆候なし"
        }

        let gasDirection = gasolineTrendTarget - gasolinePrice
        let nikkeiDirection = nikkeiTrendTarget - nikkeiAverage
        let demandDirection = demandTrendTarget - marketDemandIndex
        let longTerm = "長期：燃料\(trendWord(gasDirection, threshold: 4))・日経\(trendWord(nikkeiDirection, threshold: 4_000))・需要\(trendWord(demandDirection, threshold: 0.04))"

        let action: String
        if projection.demand >= marketDemandIndex + 0.015 {
            action = "需要増に備え、回転の速い車種を先行確保。欠品前にAA・業販の上限を見直す"
        } else if projection.demand <= marketDemandIndex - 0.015 {
            action = "需要減に備え、長期在庫を値下げ・AA出品。仕入れ量と固定費を絞る"
        } else if projection.gasoline >= gasolinePrice + 3 {
            action = "燃料高に備え、軽・コンパクト・ハイブリッドを確保。燃費重視の業態へ寄せる"
        } else if projection.nikkei >= nikkeiAverage + 2_000 {
            action = "景気上向きに備え、高品質SUV・輸入車の在庫を厚くする"
        } else {
            action = "相場は安定。現在の在庫回転を維持し、不採算車だけを処分する"
        }
        return MarketIntelligenceReport(
            horizonWeeks: horizon,
            accuracyPercent: Int(((1 - error) * 100).rounded()),
            gasolineRange: gasoline,
            nikkeiRange: nikkei,
            demandRange: demand,
            shortTermOutlook: shortTerm,
            longTermOutlook: longTerm,
            recommendedAction: action,
            upcomingEvent: event
        )
    }

    func vehicleMarketForecast(for model: VehicleCatalogEntry, in district: DistrictKind, storeID: UUID) -> VehicleMarketForecast {
        let horizon = marketForecastHorizon(for: storeID)
        let projection = projectedMarketState(weeks: horizon)
        let currentRetail = catalogRetailPrice(for: model, in: district)
        let currentAuction = catalogWholesalePrice(for: model, in: district)
        let factor = projectedVehiclePriceFactor(powertrain: model.powertrain, projection: projection)
        let projectedRetail = max(1, Int((Double(currentRetail) * factor).rounded()))
        let projectedAuction = max(1, Int((Double(currentAuction) * (1 + (factor - 1) * 0.82)).rounded()))
        let stableSeed = model.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fff }
        return VehicleMarketForecast(
            horizonWeeks: horizon,
            retailPriceRange: forecastRange(value: projectedRetail, storeID: storeID, horizonWeeks: horizon, seedSalt: stableSeed),
            auctionPriceRange: forecastRange(value: projectedAuction, storeID: storeID, horizonWeeks: horizon, seedSalt: stableSeed + 97),
            directionPercent: Int(((factor - 1) * 100).rounded())
        )
    }

    func auctionMarketForecast(for listing: AuctionListing, storeID: UUID) -> ClosedRange<Int> {
        let horizon = marketForecastHorizon(for: storeID)
        let projection = projectedMarketState(weeks: horizon)
        let powertrain = VehicleCatalog.entry(id: listing.modelID)?.powertrain ?? .gasoline
        let factor = projectedVehiclePriceFactor(powertrain: powertrain, projection: projection)
        let projected = max(1, Int((Double(listing.marketPrice) * (1 + (factor - 1) * 0.82)).rounded()))
        return forecastRange(value: projected, storeID: storeID, horizonWeeks: horizon, seedSalt: listing.modelYear + listing.mileage / 1_000)
    }

    func marketResearcherName(for storeID: UUID) -> String {
        guard let employee = stores.first(where: { $0.id == storeID })?.employees
            .filter({ $0.assignment == .research })
            .max(by: { $0.researchSkill < $1.researchSkill }) else { return "オーナー調査" }
        return employee.name
    }

    func employeePoachingRisk(_ employee: StoreEmployee) -> Double {
        guard employee.tenureWeeks >= 12, employee.overallSkill >= 70 else { return 0 }
        let marketSalary = employee.marketMonthlySalary
        let skillRisk = Double(employee.overallSkill - 70) * 0.0015
        let salaryRisk = Double(max(0, marketSalary - employee.recentTotalCompensation)) * 0.004
        let retention = Double(max(0, employee.recentTotalCompensation - marketSalary)) * 0.003
        return min(0.12, max(0, 0.01 + skillRisk + salaryRisk - retention))
    }

    var rivalTalentOffers: [RivalTalentOffer] {
        let employedIDs = Set(stores.flatMap(\.employees).map(\.id))
        let available = Self.employeeRoster
            .filter { !employedIDs.contains($0.id) }
            .sorted { $0.overallSkill > $1.overallSkill }
        guard !available.isEmpty else { return [] }
        let start = (turn / 12) % available.count
        return competitors.enumerated().map { index, competitor in
            let employee = available[(start + index) % available.count]
            return RivalTalentOffer(
                competitorID: competitor.id,
                employee: employee,
                signingCost: employee.monthlySalary * 4 + 40
            )
        }
    }

    var competitorAcquisitionOffers: [CompetitorAcquisitionOffer] {
        guard stores.count < 5 else { return [] }
        return competitors.compactMap { competitor in
            guard competitor.strength <= 0.98 || competitor.cash < 30_000,
                  let plotID = competitor.plotIDs.first,
                  let targetPlot = plot(id: plotID) else { return nil }
            let cost = max(900, targetPlot.price * 55 / 100 + StoreType.small.buildCost * 35 / 100)
            return CompetitorAcquisitionOffer(competitorID: competitor.id, plotID: plotID, cost: cost)
        }
    }

    @discardableResult
    func respondToPriceWar(_ challengeID: UUID, with response: PriceWarResponse) -> Bool {
        guard let challengeIndex = priceWarChallenges.firstIndex(where: { $0.id == challengeID }),
              priceWarChallenges[challengeIndex].isActive(at: turn),
              priceWarChallenges[challengeIndex].response == nil,
              stores.contains(where: { plot(id: $0.plotID)?.district == priceWarChallenges[challengeIndex].district }) else { return false }
        let cost = priceWarResponseCost(response, challengeID: challengeID)
        guard cash >= cost else { return false }
        let challenge = priceWarChallenges[challengeIndex]
        cash -= cost
        finance.operatingCF -= cost
        priceWarChallenges[challengeIndex].response = response
        if response == .brandDefense {
            for storeIndex in stores.indices where plot(id: stores[storeIndex].plotID)?.district == challenge.district {
                stores[storeIndex].reputation = min(1.25, stores[storeIndex].reputation + 0.04)
            }
            nationalBrandStrength = min(1.45, nationalBrandStrength + 0.01)
        }
        if let competitorIndex = competitors.firstIndex(where: { $0.id == challenge.competitorID }) {
            competitors[competitorIndex].strength = max(0.72, competitors[competitorIndex].strength - 0.015)
        }
        let event = CityEvent(
            turn: turn,
            kind: .priceWar,
            title: "価格戦争へ対抗",
            detail: "\(challenge.district.shortName)地区で\(response.name)を実施。\(response.detail)（費用\(cost.currency)）",
            district: challenge.district,
            isPositive: true
        )
        recordCityEvent(event)
        recalculateAssets()
        save()
        return true
    }

    @discardableResult
    func poachRivalTalent(_ employeeID: UUID, from competitorID: UUID, to storeID: UUID) -> Bool {
        guard let offer = rivalTalentOffers.first(where: { $0.employee.id == employeeID && $0.competitorID == competitorID }),
              let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              stores[storeIndex].staff < maxEmployeesPerStore,
              cash >= offer.signingCost else { return false }
        var employee = offer.employee
        employee.monthlySalary += 5
        employee.tenureWeeks = 0
        cash -= offer.signingCost
        finance.operatingCF -= offer.signingCost
        stores[storeIndex].employees.append(employee)
        if let competitorIndex = competitors.firstIndex(where: { $0.id == competitorID }) {
            competitors[competitorIndex].strength = max(0.72, competitors[competitorIndex].strength - 0.02)
        }
        recordCityEvent(CityEvent(
            turn: turn,
            kind: .staffPoaching,
            title: "競合から人材を獲得",
            detail: "\(competitorName(for: competitorID))から\(employee.name)を\(stores[storeIndex].name)へ迎えました。契約金\(offer.signingCost.currency)",
            district: plot(id: stores[storeIndex].plotID)?.district,
            plotID: stores[storeIndex].plotID,
            isPositive: true
        ))
        save()
        return true
    }

    @discardableResult
    func acquireCompetitorStore(competitorID: UUID, plotID: Int) -> Bool {
        guard let offer = competitorAcquisitionOffers.first(where: { $0.competitorID == competitorID && $0.plotID == plotID }),
              let competitorIndex = competitors.firstIndex(where: { $0.id == competitorID }),
              let plotIndex = plots.firstIndex(where: { $0.id == plotID }),
              competitors[competitorIndex].plotIDs.contains(plotID),
              cash >= offer.cost,
              stores.count < 5 else { return false }
        let targetPlot = plots[plotIndex]
        let category = competitors[competitorIndex].category
        var inventory: [InventoryBatch] = []
        for offset in 0..<3 {
            let model = vehicleModel(for: category, seed: turn * 211 + plotID * 29 + offset * 31)
            let profile = usedVehicleProfile(for: model, seed: turn * 223 + plotID * 37 + offset * 41, maximumAge: 9)
            let unitCost = vehicleWholesaleValue(modelID: model.id, category: category, modelYear: profile.modelYear, mileage: profile.mileage, quality: profile.quality, in: targetPlot.district)
            inventory.append(InventoryBatch(modelID: model.id, category: category, count: 1, averageCost: unitCost, quality: profile.quality, modelYear: profile.modelYear, mileage: profile.mileage, acquiredTurn: turn))
        }
        let purpose: CustomerPurpose = category == .pickup ? .work : ([.minivan, .suv].contains(category) ? .family : .general)
        cash -= offer.cost
        finance.investingCF -= offer.cost
        let store = Store(
            name: "\(targetPlot.district.shortName)買収店",
            plotID: plotID,
            plotIDs: [plotID],
            type: .small,
            acquisition: .purchase,
            marketPolicy: StoreMarketPolicy(priorityCategories: [category], targetPurpose: purpose),
            inventory: inventory
        )
        stores.append(store)
        competitors[competitorIndex].plotIDs.removeAll { $0 == plotID }
        competitors[competitorIndex].cash += offer.cost / 4
        competitors[competitorIndex].strength = max(0.72, competitors[competitorIndex].strength - 0.08)
        plots[plotIndex].occupant = .player(storeID: store.id)
        plots[plotIndex].structure = .vacant
        synchronizeParcelUse(for: store)
        recordCityEvent(CityEvent(
            turn: turn,
            kind: .competitorAcquisition,
            title: "競合店舗を買収",
            detail: "\(competitors[competitorIndex].name)の\(targetPlot.district.shortName)店を\(offer.cost.currency)で取得。在庫3台と顧客基盤を引き継ぎました",
            district: targetPlot.district,
            plotID: plotID,
            isPositive: true
        ))
        recalculateAssets()
        assertGridOccupancyIntegrity()
        save()
        return true
    }

    @discardableResult
    func hireEmployee(_ employeeID: UUID, for storeID: UUID) -> Bool {
        guard let index = stores.firstIndex(where: { $0.id == storeID }),
              stores[index].staff < maxEmployeesPerStore,
              let candidate = employeeCandidates(for: storeID).first(where: { $0.id == employeeID }) else { return false }
        stores[index].employees.append(candidate)
        save()
        return true
    }

    @discardableResult
    func hireStaff(for storeID: UUID) -> Bool {
        guard let candidate = employeeCandidates(for: storeID).first else { return false }
        return hireEmployee(candidate.id, for: storeID)
    }

    @discardableResult
    func fireEmployee(_ employeeID: UUID, from storeID: UUID) -> Bool {
        guard let index = stores.firstIndex(where: { $0.id == storeID }),
              let employeeIndex = stores[index].employees.firstIndex(where: { $0.id == employeeID }) else { return false }
        stores[index].employees.remove(at: employeeIndex)
        save()
        return true
    }

    @discardableResult
    func fireStaff(for storeID: UUID) -> Bool {
        guard let index = stores.firstIndex(where: { $0.id == storeID }),
              let employee = stores[index].employees.last else { return false }
        return fireEmployee(employee.id, from: storeID)
    }

    @discardableResult
    func assignEmployee(_ employeeID: UUID, at storeID: UUID, to assignment: EmployeeAssignment) -> Bool {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let employeeIndex = stores[storeIndex].employees.firstIndex(where: { $0.id == employeeID }) else { return false }
        stores[storeIndex].employees[employeeIndex].assignment = assignment
        save()
        return true
    }

    @discardableResult
    func trainEmployee(_ employeeID: UUID, at storeID: UUID, focus: EmployeeTrainingFocus) -> Bool {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let employeeIndex = stores[storeIndex].employees.firstIndex(where: { $0.id == employeeID }),
              stores[storeIndex].employees[employeeIndex].lastTrainingTurn != turn,
              cash >= employeeTrainingCost else { return false }
        cash -= employeeTrainingCost
        finance.operatingCF -= employeeTrainingCost
        switch focus {
        case .sales:
            stores[storeIndex].employees[employeeIndex].salesSkill = min(99, stores[storeIndex].employees[employeeIndex].salesSkill + 3)
        case .procurement:
            stores[storeIndex].employees[employeeIndex].procurementSkill = min(99, stores[storeIndex].employees[employeeIndex].procurementSkill + 3)
        case .research:
            stores[storeIndex].employees[employeeIndex].researchSkill = min(99, stores[storeIndex].employees[employeeIndex].researchSkill + 3)
        case .service:
            stores[storeIndex].employees[employeeIndex].serviceSkill = min(99, stores[storeIndex].employees[employeeIndex].serviceSkill + 3)
        }
        stores[storeIndex].employees[employeeIndex].monthlySalary += 1
        stores[storeIndex].employees[employeeIndex].lastTrainingTurn = turn
        save()
        return true
    }

    @discardableResult
    func raiseEmployeeSalary(_ employeeID: UUID, at storeID: UUID) -> Bool {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let employeeIndex = stores[storeIndex].employees.firstIndex(where: { $0.id == employeeID }),
              stores[storeIndex].employees[employeeIndex].monthlySalary < 130 else { return false }
        stores[storeIndex].employees[employeeIndex].monthlySalary += 2
        save()
        return true
    }

    @discardableResult
    func hireManager(for storeID: UUID) -> Bool {
        guard let index = stores.firstIndex(where: { $0.id == storeID }),
              !stores[index].hasManager,
              cash >= managerHiringCost,
              let candidate = managerCandidate(for: storeID) else { return false }
        cash -= managerHiringCost
        stores[index].manager = candidate
        save()
        return true
    }

    @discardableResult
    func fireManager(for storeID: UUID) -> Bool {
        guard let index = stores.firstIndex(where: { $0.id == storeID }),
              stores[index].hasManager else { return false }
        stores[index].manager = nil
        stores[index].delegateStaff = false
        stores[index].delegatePricing = false
        stores[index].delegateMarketing = false
        stores[index].delegateProcurement = false
        stores[index].delegateService = false
        save()
        return true
    }

    @discardableResult
    func increaseAdvertisingBudget(for storeID: UUID, by amount: Int) -> Bool {
        guard amount > 0,
              let index = stores.firstIndex(where: { $0.id == storeID }),
              stores[index].advertising < 500 else { return false }
        stores[index].advertising = min(500, stores[index].advertising + amount)
        save()
        return true
    }

    func canStartInventorySaleCampaign(storeID: UUID, tier: InventorySaleTier) -> Bool {
        guard let store = stores.first(where: { $0.id == storeID }),
              store.isOperational,
              store.inventorySaleCampaign == nil,
              store.inventorySaleCooldownWeeks == 0 else { return false }
        let saleableCount = store.inventory.filter {
            $0.count > 0 && !$0.isInWorkshop && !$0.isReserved
        }.reduce(0) { $0 + $1.count }
        let requiredStock = Int(ceil(Double(store.type.capacity) * 0.40))
        return saleableCount >= requiredStock
            && cash >= tier.advertisingCost(capacity: store.type.capacity)
    }

    @discardableResult
    func startInventorySaleCampaign(storeID: UUID, tier: InventorySaleTier) -> Bool {
        guard canStartInventorySaleCampaign(storeID: storeID, tier: tier),
              let index = stores.firstIndex(where: { $0.id == storeID }) else { return false }
        let cost = tier.advertisingCost(capacity: stores[index].type.capacity)
        cash -= cost
        finance.operatingCF -= cost
        stores[index].inventorySaleCampaign = InventorySaleCampaign(
            tier: tier,
            startedTurn: turn,
            remainingWeeks: 4
        )
        save()
        return true
    }

    func customizationOrders(for storeID: UUID) -> [CustomerCustomizationOrder] {
        customerCustomizationOrders
            .filter { $0.storeID == storeID }
            .sorted {
                if $0.status != $1.status { return $0.status == .active }
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.generatedTurn < $1.generatedTurn
            }
    }

    @discardableResult
    func acceptCustomizationOrder(_ orderID: UUID) -> Bool {
        guard let orderIndex = customerCustomizationOrders.firstIndex(where: {
            $0.id == orderID && $0.status == .pending
        }),
        let storeIndex = stores.firstIndex(where: {
            $0.id == customerCustomizationOrders[orderIndex].storeID
        }) else { return false }
        let order = customerCustomizationOrders[orderIndex]
        let activeInventoryBays = stores[storeIndex].inventory.filter {
            $0.workshopProject?.outsourced == false
                && $0.workshopProject?.kind.usesCustomizationBay == order.kind.usesCustomizationBay
        }.count
        let activeOrderBays = customerCustomizationOrders.filter {
            $0.storeID == order.storeID
                && $0.status == .active
                && $0.kind.usesCustomizationBay == order.kind.usesCustomizationBay
        }.count
        let requiredFacility: StoreFacility = order.kind.usesCustomizationBay ? .customWorkshop : .serviceWorkshop
        guard stores[storeIndex].facilities.contains(requiredFacility),
              stores[storeIndex].employees.contains(where: { $0.assignment == .service }),
              activeInventoryBays + activeOrderBays < stores[storeIndex].bays(for: order.kind),
              cash >= order.materialCost else { return false }
        cash -= order.materialCost
        finance.operatingCF -= order.materialCost
        customerCustomizationOrders[orderIndex].status = .active
        customerCustomizationOrders[orderIndex].startedTurn = turn
        save()
        return true
    }

    func declineCustomizationOrder(_ orderID: UUID) {
        customerCustomizationOrders.removeAll { $0.id == orderID && $0.status == .pending }
        save()
    }

    func setCustomizationOrderPriority(_ orderID: UUID, priority: Int) {
        guard let index = customerCustomizationOrders.firstIndex(where: {
            $0.id == orderID && $0.status == .active
        }) else { return }
        customerCustomizationOrders[index].priority = min(3, max(0, priority))
        save()
    }

    func manualSaleQuote(storeID: UUID, category: VehicleCategory) -> (price: Int, grossProfit: Int)? {
        guard let inventoryID = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.category == category && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved })?.id else { return nil }
        return manualSaleQuote(storeID: storeID, inventoryID: inventoryID)
    }

    func manualSaleQuote(storeID: UUID, inventoryID: UUID) -> (price: Int, grossProfit: Int)? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID),
              let batch = store.inventory.first(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }) else { return nil }
        let baseVehicleMarketValue = vehicleRetailValue(
            modelID: batch.modelID,
            category: batch.category,
            modelYear: batch.modelYear,
            mileage: batch.mileage,
            quality: batch.quality,
            in: plot.district
        )
        let ordinaryMarketValue = baseVehicleMarketValue + productizationMarketValueAddition(for: batch)
        let specialistReferenceFloor: Int
        if let model = VehicleCatalog.entry(id: batch.modelID),
           [.sportStreet, .sportDrift, .sportCircuit,
            .welfareLiftSeat, .welfareWheelchair,
            .mobileSales, .kitchenCar].contains(batch.productState) {
            specialistReferenceFloor = Int(
                Double(model.referenceRetailPrice) * (0.78 + batch.quality * 0.22)
            )
        } else {
            specialistReferenceFloor = 0
        }
        let marketValue = max(ordinaryMarketValue, specialistReferenceFloor)
        let agingFactor = inventoryAgingValueFactor(for: batch)
        let specialtyFactor = specialtyMarketFactor(for: batch, in: plot.district)
        let disclosedIssueFactor = batch.disclosedIssue?.disclosedValueFactor ?? 1.0
        let pricingFactor = store.priceIndex
            * agingFactor
            * specialtyFactor
            * disclosedIssueFactor
            * competitivePriceFactor(in: plot.district)
        let rawPrice = max(25, Int(Double(marketValue) * pricingFactor))
        let baseVehiclePrice = max(25, Int(Double(baseVehicleMarketValue) * pricingFactor))
        let valueSupportedPrice = customizationValueSupportedPrice(
            for: batch,
            baseVehiclePrice: baseVehiclePrice
        ) ?? 0
        let price = max(rawPrice, valueSupportedPrice)
        return (price, price - batch.averageCost)
    }

    func manualNegotiationLimit(storeID: UUID) -> Int {
        weeklyOpportunityCapacity(storeID: storeID)
    }

    func canSellManually(storeID: UUID) -> Bool {
        guard let store = stores.first(where: { $0.id == storeID }) else { return false }
        return store.inventory.contains(where: { $0.count > 0 && !$0.isInWorkshop && !$0.isReserved })
            && buyerLeads.contains(where: { $0.storeID == storeID })
            && remainingWeeklyOpportunities(storeID: storeID) > 0
    }

    func saleNegotiationPreview(storeID: UUID, category: VehicleCategory, strategy: SaleNegotiationStrategy) -> (price: Int, grossProfit: Int, closeChance: Double)? {
        guard let inventoryID = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.category == category && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved })?.id else { return nil }
        return saleNegotiationPreview(storeID: storeID, inventoryID: inventoryID, strategy: strategy)
    }

    func saleNegotiationPreview(storeID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy) -> (price: Int, grossProfit: Int, closeChance: Double)? {
        guard let batch = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }),
              let lead = preferredBuyerLead(storeID: storeID, batch: batch) else { return nil }
        return saleNegotiationPreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: inventoryID, strategy: strategy)
    }

    func saleNegotiationPreview(storeID: UUID, buyerLeadID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy) -> (price: Int, grossProfit: Int, closeChance: Double)? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID),
              let batch = store.inventory.first(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }),
              let lead = buyerLeads.first(where: { $0.id == buyerLeadID && $0.storeID == storeID }),
              let quote = manualSaleQuote(storeID: storeID, inventoryID: inventoryID) else { return nil }
        let purposeValue = productPurposeValueFactor(for: batch, purpose: lead.purpose)
        let desiredSegment = MarketSegmentKey(
            district: plot.district,
            category: batch.category,
            purpose: lead.purpose,
            productKind: lead.desiredProductKind
        )
        let campaignDiscount = store.inventorySaleCampaign?.tier.discountRate ?? 0
        let rawOffer = Int(Double(quote.price) * purposeValue
            * segmentWillingnessFactor(for: desiredSegment, store: store, productState: batch.productState, grade: batch.productGrade)
            * (1 - campaignDiscount) * (1 - strategy.discountRate))
        let offer: Int
        if let model = VehicleCatalog.entry(id: batch.modelID),
           marketProductKind(for: batch).supportsGrades {
            let referenceCap = specialtyReferenceRetail(for: model)
                * specialtyPriceCeiling(
                    for: marketProductKind(for: batch),
                    productState: batch.productState,
                    grade: batch.productGrade
                )
            let valueSupportedCap = Double(max(Int(referenceCap), quote.price))
                * (1 - campaignDiscount)
                * (1 - strategy.discountRate)
            offer = min(rawOffer, Int(valueSupportedCap))
        } else {
            offer = rawOffer
        }
        let demand = vehicleDemand(batch.category, in: plot.district)
        let demandEffect = (demand - 1) * 0.08
        let reputationEffect = (store.reputation - 0.65) * 0.12
        let preferenceEffect = buyerPreferenceMatchEffect(lead: lead, batch: batch, offerPrice: offer)
        let catalogEffect: Double
        if let model = VehicleCatalog.entry(id: batch.modelID) {
            catalogEffect = (catalogMarketIndex(for: model, in: plot.district) - 1) * 0.10
        } else {
            catalogEffect = 0
        }
        let qualityEffect = (batch.quality - lead.minimumQuality) * 0.42
        let yearEffect = lead.minimumModelYear == 0 ? 0 : (batch.modelYear >= lead.minimumModelYear ? 0.04 : -0.22)
        let mileageEffect = lead.maximumMileage == .max ? 0 : (batch.mileage <= lead.maximumMileage ? 0.04 : -0.20)
        let budgetEffect = buyerBudgetEffect(price: offer, lead: lead)
        let freshnessEffect = inventoryFreshnessCloseAdjustment(for: batch)
        let specialtyEffect = specialtyCloseAdjustment(for: batch, purpose: lead.purpose, in: plot.district)
        let disclosedIssueEffect = batch.disclosedIssue == nil ? 0.0 : -0.06
        let facilityEffect = facilityCloseAdjustment(
            store: store,
            category: batch.category,
            origin: VehicleCatalog.entry(id: batch.modelID)?.origin,
            purpose: lead.purpose
        )
        let certificationEffect = certifiedSpecialtyCloseBonus(for: store, batch: batch)
        let competitiveEffect = priceWarCloseAdjustment(in: plot.district)
        let expertiseEffect = effectiveCategoryExpertise(for: store, category: batch.category) * 0.0012
            + effectivePurposeExpertise(for: store, purpose: lead.purpose) * 0.0008
        let directRivalEffect: Double
        if let rival = lead.competitorOffer {
            let priceAdvantage = Double(rival.price - offer) / Double(max(1, rival.price)) * 0.42
            let qualityAdvantage = (batch.quality - rival.quality) * 0.34
            directRivalEffect = min(0.18, max(-0.28, priceAdvantage + qualityAdvantage))
        } else {
            directRivalEffect = 0.04
        }
        // Apply stock age after the common cap so a high-demand district cannot
        // completely hide the penalty for inventory that has sat for months.
        let campaignCloseBonus = store.inventorySaleCampaign?.tier.closeBonus ?? 0
        let baselineChance = min(0.97, max(0.03, strategy.baseCloseChance + campaignCloseBonus + demandEffect + reputationEffect + preferenceEffect + catalogEffect + qualityEffect + yearEffect + mileageEffect + budgetEffect + specialtyEffect + certificationEffect + disclosedIssueEffect + facilityEffect + competitiveEffect + directRivalEffect + expertiseEffect))
        let chance = min(0.93, max(0.03, baselineChance + freshnessEffect))
        return (offer, offer - batch.averageCost, chance)
    }

    private func buyerBudgetEffect(price: Int, lead: BuyerLead) -> Double {
        let budgetRatio = Double(max(0, price)) / Double(max(1, lead.budget))
        return budgetRatio <= 1 ? 0.10 : -min(0.48, (budgetRatio - 1) * 1.35 * lead.priceSensitivity)
    }

    private func clampedReviewScore(_ value: Int) -> Int {
        min(100, max(10, value))
    }

    private func recordCustomerReview(_ review: CustomerReview, storeIndex: Int) {
        guard stores.indices.contains(storeIndex) else { return }
        if let existing = stores[storeIndex].customerReviews.firstIndex(where: { $0.customerID == review.customerID }) {
            stores[storeIndex].customerReviews[existing] = review
        } else {
            stores[storeIndex].customerReviews.insert(review, at: 0)
        }
        stores[storeIndex].customerReviews.sort { $0.createdTurn > $1.createdTurn }
        if stores[storeIndex].customerReviews.count > 120 {
            stores[storeIndex].customerReviews.removeLast(stores[storeIndex].customerReviews.count - 120)
        }
        refreshReviewStanding(for: storeIndex)
    }

    private func refreshReviewStanding(for storeIndex: Int) {
        guard stores.indices.contains(storeIndex),
              let average = stores[storeIndex].averageReviewScore else {
            if stores.indices.contains(storeIndex) { stores[storeIndex].satisfaction = 0 }
            return
        }
        stores[storeIndex].satisfaction = average
        let confidence = min(1, Double(stores[storeIndex].reviewCount) / 12)
        let reviewReputation = 0.65 + (Double(average) - 70) / 55 * 0.32 * confidence
        stores[storeIndex].reputation = min(1.15, max(0.40, reviewReputation))
    }

    private func recordBuyerReview(
        lead: BuyerLead,
        batch: InventoryBatch,
        offerPrice: Int,
        succeeded: Bool,
        serviceScore: Int
    ) {
        guard let storeIndex = stores.firstIndex(where: { $0.id == lead.storeID }),
              let plot = plot(id: stores[storeIndex].plotID) else { return }
        var fairPrice = vehicleRetailValue(
            modelID: batch.modelID,
            category: batch.category,
            modelYear: batch.modelYear,
            mileage: batch.mileage,
            quality: batch.quality,
            in: plot.district
        ) + productizationMarketValueAddition(for: batch)
        let fairKey = MarketSegmentKey(
            district: plot.district,
            category: batch.category,
            purpose: lead.purpose,
            productKind: lead.desiredProductKind
        )
        fairPrice = Int(Double(fairPrice)
            * productPurposeValueFactor(for: batch, purpose: lead.purpose)
            * segmentWillingnessFactor(for: fairKey, store: stores[storeIndex], productState: batch.productState, grade: batch.productGrade))
        if let issue = batch.disclosedIssue {
            fairPrice = Int((Double(fairPrice) * issue.disclosedValueFactor).rounded())
        }
        let priceRatio = Double(offerPrice) / Double(max(1, fairPrice))
        let rawPriceScore = 88
            - Int((max(0, priceRatio - 0.95) * 170).rounded())
            + Int((max(0, 0.95 - priceRatio) * 45).rounded())
        let priceScore = clampedReviewScore(rawPriceScore)
        let matchAdjustment = inventoryPreferenceMatches(batch, preference: lead.preference) ? 9 : -18
        let issueAdjustment = batch.disclosedIssue == nil ? 0 : -12
        let vehicleScore = clampedReviewScore(Int((batch.quality * 100).rounded()) + matchAdjustment + issueAdjustment)
        let service = clampedReviewScore(serviceScore)
        let overall = clampedReviewScore(Int((Double(priceScore) * 0.40 + Double(vehicleScore) * 0.35 + Double(service) * 0.25).rounded()))
        let comment: String
        if priceScore < 55 {
            comment = "店頭価格が相場より高く感じました"
        } else if vehicleScore < 55 {
            comment = "希望条件に合う車や品質の説明が物足りませんでした"
        } else if service < 50 {
            comment = "来店しましたが、十分な対応を受けられませんでした"
        } else if succeeded {
            comment = "価格と車両説明に納得して購入できました"
        } else {
            comment = "提案は受けましたが、今回は条件が合いませんでした"
        }
        recordCustomerReview(CustomerReview(
            customerID: lead.id,
            createdTurn: turn,
            channel: .buyer,
            salesPriceScore: priceScore,
            vehicleScore: vehicleScore,
            serviceScore: service,
            overallScore: overall,
            comment: comment
        ), storeIndex: storeIndex)
    }

    private func recordSellerReview(
        item: PurchaseCase,
        offerPercent: Int?,
        succeeded: Bool,
        serviceScore: Int,
        declinedByStore: Bool = false
    ) {
        guard let storeIndex = stores.firstIndex(where: { $0.id == item.storeID }) else { return }
        let purchaseScore = offerPercent.map { clampedReviewScore(20 + ($0 - 80) * 4) }
        let service = clampedReviewScore(serviceScore)
        let overall = purchaseScore.map {
            clampedReviewScore(Int((Double($0) * 0.75 + Double(service) * 0.25).rounded()))
        } ?? service
        let comment: String
        if declinedByStore {
            comment = "査定後に買取を見送られました"
        } else if let purchaseScore, purchaseScore >= 88, succeeded {
            comment = "希望額に近い高額買取で満足しました"
        } else if let purchaseScore, purchaseScore < 55 {
            comment = "査定額が期待より低く感じました"
        } else if succeeded {
            comment = "説明のある査定で、提示条件に納得しました"
        } else {
            comment = "査定は受けましたが、提示条件が合いませんでした"
        }
        recordCustomerReview(CustomerReview(
            customerID: item.id,
            createdTurn: turn,
            channel: .seller,
            purchaseOfferScore: purchaseScore,
            serviceScore: service,
            overallScore: overall,
            comment: comment
        ), storeIndex: storeIndex)
    }

    private func recordUnattendedReview(customerID: UUID, storeID: UUID, channel: CustomerReviewChannel) {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }) else { return }
        recordCustomerReview(CustomerReview(
            customerID: customerID,
            createdTurn: turn,
            channel: channel,
            serviceScore: 20,
            overallScore: 20,
            comment: "来店しましたが、担当者に対応してもらえませんでした"
        ), storeIndex: storeIndex)
    }

    private func recordClaimReview(_ claim: PendingCustomerClaim, storeIndex: Int) {
        let existing = stores[storeIndex].customerReviews.first(where: { $0.customerID == claim.customerID })
        let priceScore = existing?.salesPriceScore
        let service = min(existing?.serviceScore ?? 30, 25)
        let overall = clampedReviewScore(Int((Double(priceScore ?? 45) * 0.30 + 10 * 0.45 + Double(service) * 0.25).rounded()))
        recordCustomerReview(CustomerReview(
            customerID: claim.customerID,
            createdTurn: turn,
            channel: .buyer,
            salesPriceScore: priceScore,
            vehicleScore: 10,
            serviceScore: service,
            overallScore: overall,
            comment: "購入後に\(claim.issue.name)が判明し、車両への評価を変更しました"
        ), storeIndex: storeIndex)
    }

    func tradeInSalePreview(storeID: UUID, buyerLeadID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy) -> TradeInSalePreview? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID),
              let lead = buyerLeads.first(where: { $0.id == buyerLeadID && $0.storeID == storeID }),
              let tradeIn = lead.tradeInVehicle,
              let sale = saleNegotiationPreview(storeID: storeID, buyerLeadID: buyerLeadID, inventoryID: inventoryID, strategy: strategy) else { return nil }
        let customerSettlement = sale.price - tradeIn.appraisedValue
        let baseRetail = vehicleRetailValue(
            modelID: tradeIn.modelID,
            category: tradeIn.category,
            modelYear: tradeIn.modelYear,
            mileage: tradeIn.mileage,
            quality: tradeIn.qualityAfterRepair,
            in: plot.district
        )
        let expectedTradeInSalePrice = max(25, Int(Double(baseRetail) * store.priceIndex))
        let improvedBudgetEffect = buyerBudgetEffect(price: max(0, customerSettlement), lead: lead) - buyerBudgetEffect(price: sale.price, lead: lead)
        let closeChance = min(0.97, max(0.03, sale.closeChance + 0.08 + max(0, improvedBudgetEffect)))
        let repairCost = tradeInRepairCost(for: tradeIn, storeID: storeID)
        return TradeInSalePreview(
            salePrice: sale.price,
            saleGrossProfit: sale.grossProfit,
            allowance: tradeIn.appraisedValue,
            repairCost: repairCost,
            customerCashSettlement: customerSettlement,
            expectedTradeInSalePrice: expectedTradeInSalePrice,
            expectedTradeInGrossProfit: expectedTradeInSalePrice - tradeIn.appraisedValue - repairCost,
            closeChance: closeChance
        )
    }

    @discardableResult
    func negotiateManualSale(storeID: UUID, category: VehicleCategory, strategy: SaleNegotiationStrategy, acceptTradeIn: Bool = false) -> SaleNegotiationResult? {
        guard let inventoryID = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.category == category && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved })?.id else { return nil }
        return negotiateManualSale(storeID: storeID, inventoryID: inventoryID, strategy: strategy, acceptTradeIn: acceptTradeIn)
    }

    @discardableResult
    func negotiateManualSale(storeID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy, acceptTradeIn: Bool = false) -> SaleNegotiationResult? {
        guard let batch = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.id == inventoryID && !$0.isInWorkshop && !$0.isReserved }),
              let lead = preferredBuyerLead(storeID: storeID, batch: batch) else { return nil }
        return negotiateManualSale(storeID: storeID, buyerLeadID: lead.id, inventoryID: inventoryID, strategy: strategy, acceptTradeIn: acceptTradeIn)
    }

    @discardableResult
    func negotiateManualSale(storeID: UUID, buyerLeadID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy, acceptTradeIn: Bool = false) -> SaleNegotiationResult? {
        guard canSellManually(storeID: storeID),
              let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }),
              let leadIndex = buyerLeads.firstIndex(where: { $0.id == buyerLeadID && $0.storeID == storeID }),
              let preview = saleNegotiationPreview(storeID: storeID, buyerLeadID: buyerLeadID, inventoryID: inventoryID, strategy: strategy) else { return nil }
        let lead = buyerLeads[leadIndex]
        let tradeInPreview = acceptTradeIn ? tradeInSalePreview(storeID: storeID, buyerLeadID: buyerLeadID, inventoryID: inventoryID, strategy: strategy) : nil
        guard !acceptTradeIn || tradeInPreview != nil,
              cash >= (tradeInPreview?.requiredDealerCash ?? 0) else { return nil }
        let category = stores[storeIndex].inventory[batchIndex].category
        let salesAttempts = stores[storeIndex].manualNegotiationsThisWeek
        let allAttempts = stores[storeIndex].usedOpportunitiesThisWeek
        let strategyIndex = SaleNegotiationStrategy.allCases.firstIndex(of: strategy) ?? 0
        let seed = turn * 97 + stores[storeIndex].plotID * 19 + categoryIndex(category) * 31 + allAttempts * 43 + strategyIndex * 11 + (acceptTradeIn ? 71 : 0)
        let closeChance = tradeInPreview?.closeChance ?? preview.closeChance
        let succeeded = transactionRoll(seed: seed) < closeChance
        stores[storeIndex].pendingManualNegotiations = salesAttempts + 1
        buyerLeads.remove(at: leadIndex)
        let proposedVehicle = stores[storeIndex].inventory[batchIndex]
        let reviewService = (succeeded ? 82 : 60) + Int((strategy.discountRate * 100).rounded()) + (acceptTradeIn ? 4 : 0)
        recordBuyerReview(
            lead: lead,
            batch: proposedVehicle,
            offerPrice: preview.price,
            succeeded: succeeded,
            serviceScore: reviewService
        )

        var acquiredTradeIn = false
        if succeeded {
            let soldVehicle = stores[storeIndex].inventory[batchIndex]
            let unitCost = soldVehicle.averageCost
            stores[storeIndex].inventory[batchIndex].count -= 1
            if stores[storeIndex].inventory[batchIndex].count == 0 {
                stores[storeIndex].inventory.remove(at: batchIndex)
            }
            if let tradeIn = lead.tradeInVehicle, let tradeInPreview {
                cash += tradeInPreview.cashImpact
                stores[storeIndex].inventory.append(InventoryBatch(
                    modelID: tradeIn.modelID,
                    category: tradeIn.category,
                    count: 1,
                    averageCost: tradeIn.appraisedValue + tradeInPreview.repairCost,
                    quality: tradeIn.qualityAfterRepair,
                    modelYear: tradeIn.modelYear,
                    mileage: tradeIn.mileage,
                    acquiredTurn: turn
                ))
                acquiredTradeIn = true
            } else {
                cash += preview.price
            }
            stores[storeIndex].pendingManualSales = stores[storeIndex].manualSalesThisWeek + 1
            stores[storeIndex].pendingManualRevenue += preview.price
            stores[storeIndex].pendingManualCOGS += unitCost
            simulationTransactionHandler?(SimulationVehicleTransaction(
                turn: turn,
                kind: .sold,
                storeID: storeID,
                source: nil,
                category: category,
                count: 1,
                revenue: preview.price,
                cost: unitCost
            ))
            if acquiredTradeIn, let tradeIn = lead.tradeInVehicle, let tradeInPreview {
                simulationTransactionHandler?(SimulationVehicleTransaction(
                    turn: turn,
                    kind: .acquired,
                    storeID: storeID,
                    source: .tradeIn,
                    category: tradeIn.category,
                    count: 1,
                    revenue: 0,
                    cost: tradeIn.appraisedValue + tradeInPreview.repairCost
                ))
            }
            stores[storeIndex].lastSales = stores[storeIndex].manualSalesThisWeek
            stores[storeIndex].lastRevenue = stores[storeIndex].pendingManualRevenue
            stores[storeIndex].lastProfit = stores[storeIndex].pendingManualRevenue - stores[storeIndex].pendingManualCOGS
            stores[storeIndex].loyalCustomers = min(
                250,
                stores[storeIndex].loyalCustomers + loyalCustomerGain(store: stores[storeIndex], category: category)
            )
            scheduleCustomerClaimIfNeeded(for: soldVehicle, customerID: lead.id, storeID: storeID, salePrice: preview.price, seed: seed + 401)
            stores[storeIndex].expertise.add(category: category, purpose: lead.purpose, points: 1)
            stores[storeIndex].lifetimeProductSales[marketProductKind(for: soldVehicle), default: 0] += 1
            companyExpertise.add(category: category, purpose: lead.purpose, points: 1)
            registerPlayerSegmentSale(
                storeID: lead.storeID,
                segmentKey(for: lead),
                revenue: preview.price,
                cost: unitCost
            )
            recalculateAssets()
        } else {
            if !competitorFulfillsBuyerLead(lead) {
                registerSegmentUnmet(segmentKey(for: lead))
            }
        }
        // 成約・不成約にかかわらず「商談を体験した」時点でレッスンは達成です。
        guide.acknowledgedLessons.insert(.sellCar)
        save()
        return SaleNegotiationResult(
            succeeded: succeeded,
            salePrice: preview.price,
            grossProfit: preview.grossProfit,
            closeChance: closeChance,
            tradeInAcquired: acquiredTradeIn,
            tradeInAllowance: acquiredTradeIn ? (tradeInPreview?.allowance ?? 0) : 0,
            tradeInRepairCost: acquiredTradeIn ? (tradeInPreview?.repairCost ?? 0) : 0,
            customerCashSettlement: acquiredTradeIn ? (tradeInPreview?.customerCashSettlement ?? 0) : preview.price,
            tradeInVehicleName: acquiredTradeIn ? lead.tradeInVehicle?.vehicleName : nil
        )
    }

    func buyerPreferenceMatchEffect(lead: BuyerLead, batch: InventoryBatch, offerPrice: Int) -> Double {
        let model = VehicleCatalog.entry(id: batch.modelID)
        let productAndGradeMatch = marketProductMatches(actual: marketProductKind(for: batch), desired: lead.desiredProductKind)
            && gradeMatches(actual: batch.productGrade, desired: lead.desiredGrade)
        let productEffect = productAndGradeMatch
            ? (lead.desiredProductKind.isNiche ? 0.12 : 0)
            : (lead.desiredProductKind.isNiche ? -0.42 : -0.08)
        let preferenceEffect: Double = switch lead.preference {
        case .category(let desiredCategory):
            batch.category == desiredCategory ? 0.16 : -0.30
        case .categoryOrigin(let desiredCategory, let origin):
            if batch.category == desiredCategory, model?.origin == origin { 0.25 }
            else if batch.category == desiredCategory { -0.36 }
            else { -0.52 }
        case .maker(let desiredCategory, let maker):
            if batch.category == desiredCategory, model?.maker == maker { 0.24 }
            else { batch.category == desiredCategory ? -0.34 : -0.48 }
        case .exactModel(let modelID):
            if batch.modelID == modelID { 0.30 }
            else if batch.category == lead.desiredCategory, model?.maker == lead.preference.preferredMaker { -0.30 }
            else { batch.category == lead.desiredCategory ? -0.58 : -0.72 }
        case .budgetFirst:
            offerPrice <= lead.budget ? 0.12 : -0.06
        }
        return preferenceEffect + productEffect
    }

    private func inventoryPreferenceMatches(_ batch: InventoryBatch, preference: BuyerVehiclePreference) -> Bool {
        let model = VehicleCatalog.entry(id: batch.modelID)
        switch preference {
        case .category(let category): return batch.category == category
        case .categoryOrigin(let category, let origin):
            return batch.category == category && model?.origin == origin
        case .maker(let category, let maker): return batch.category == category && model?.maker == maker
        case .exactModel(let modelID): return batch.modelID == modelID
        case .budgetFirst: return true
        }
    }

    func inventoryMatchesBuyer(_ batch: InventoryBatch, lead: BuyerLead, storeID: UUID) -> Bool {
        guard batch.count > 0, !batch.isInWorkshop, !batch.isReserved,
              marketProductMatches(actual: marketProductKind(for: batch), desired: lead.desiredProductKind),
              gradeMatches(actual: batch.productGrade, desired: lead.desiredGrade),
              batch.quality >= lead.minimumQuality,
              batch.modelYear >= lead.minimumModelYear,
              batch.mileage <= lead.maximumMileage,
              let price = manualSaleQuote(storeID: storeID, inventoryID: batch.id)?.price,
              price <= lead.budget else { return false }
        let model = VehicleCatalog.entry(id: batch.modelID)
        switch lead.preference {
        case .category(let category): return batch.category == category
        case .categoryOrigin(let category, let origin):
            return batch.category == category && model?.origin == origin
        case .maker(let category, let maker): return batch.category == category && model?.maker == maker
        case .exactModel(let modelID): return batch.modelID == modelID
        case .budgetFirst: return true
        }
    }

    private func preferredBuyerLead(storeID: UUID, batch: InventoryBatch) -> BuyerLead? {
        buyerLeads
            .filter {
                $0.storeID == storeID
                    && marketProductMatches(actual: marketProductKind(for: batch), desired: $0.desiredProductKind)
                    && gradeMatches(actual: batch.productGrade, desired: $0.desiredGrade)
            }
            .max { lhs, rhs in
                let lhsPrice = manualSaleQuote(storeID: storeID, inventoryID: batch.id)?.price ?? Int.max
                let rhsPrice = lhsPrice
                return buyerPreferenceMatchEffect(lead: lhs, batch: batch, offerPrice: lhsPrice)
                    + (lhsPrice <= lhs.budget ? 0.08 : 0)
                    < buyerPreferenceMatchEffect(lead: rhs, batch: batch, offerPrice: rhsPrice)
                    + (rhsPrice <= rhs.budget ? 0.08 : 0)
            }
    }

    @discardableResult
    func sellInventoryManually(storeID: UUID, category: VehicleCategory) -> Bool {
        negotiateManualSale(storeID: storeID, category: category, strategy: .smallDiscount)?.succeeded == true
    }

    @discardableResult
    func renovateStore(_ storeID: UUID, to newType: StoreType) -> Bool {
        guard let index = stores.firstIndex(where: { $0.id == storeID }),
              stores[index].isOperational,
              !stores[index].isRenovating,
              stores[index].type != newType,
              newType.capacity >= stores[index].inventoryCount else { return false }
        guard let primary = plot(id: stores[index].plotID) else { return false }
        let footprint = footprintPlots(
            startingAt: primary,
            type: newType,
            mode: stores[index].acquisition,
            occupiedBy: stores[index].id,
            requiredExistingIDs: Set(stores[index].plotIDs)
        )
        guard footprint.count >= newType.requiredGridCells else { return false }
        let existingIDs = Set(stores[index].plotIDs)
        let added = footprint.filter { !existingIDs.contains($0.id) }
        let expansionCost = landAcquisitionCost(for: added, mode: stores[index].acquisition) + demolitionCost(for: added)
        let cost = max(600, max(0, newType.buildCost - stores[index].type.buildCost) * 65 / 100) + expansionCost
        guard cash >= cost else { return false }
        cash -= cost
        finance.investingCF -= cost
        stores[index].pendingType = newType
        stores[index].plotIDs = footprint.map(\.id)
        for cell in added {
            guard let plotIndex = plots.firstIndex(where: { $0.id == cell.id }) else { continue }
            plots[plotIndex].occupant = .player(storeID: storeID)
            plots[plotIndex].structure = .vacant
        }
        stores[index].renovationMonthsRemaining = newType.renovationMonths(from: stores[index].type)
        synchronizeParcelUse(for: stores[index])
        recordCityEvent(CityEvent(turn: turn, kind: .storeGrowth, title: "\(stores[index].name)が改装着工", detail: "\(newType.name)へ改装中。完成まで\(stores[index].renovationMonthsRemaining ?? 1)週間です", plotID: stores[index].plotID))
        recalculateAssets()
        assertGridOccupancyIntegrity()
        save()
        return true
    }

    func transferInventory(category: VehicleCategory, from sourceID: UUID, to destinationID: UUID) -> Bool {
        guard sourceID != destinationID,
              let source = stores.firstIndex(where: { $0.id == sourceID }),
              let destination = stores.firstIndex(where: { $0.id == destinationID }),
              stores[destination].inventoryCount < stores[destination].type.capacity,
              let removed = removeInventory(category: category, count: 1, from: source) else { return false }
        stores[destination].inventory.append(InventoryBatch(modelID: removed.modelID, category: category, count: 1, averageCost: removed.averageCost, quality: removed.quality, modelYear: removed.modelYear, mileage: removed.mileage, acquiredTurn: removed.acquiredTurn, vehicleIssue: removed.vehicleIssue))
        save()
        return true
    }

    func transferInventory(inventoryID: UUID, from sourceID: UUID, to destinationID: UUID) -> Bool {
        guard sourceID != destinationID,
              let source = stores.firstIndex(where: { $0.id == sourceID }),
              let destination = stores.firstIndex(where: { $0.id == destinationID }),
              stores[destination].inventoryCount < stores[destination].type.capacity,
              let batchIndex = stores[source].inventory.firstIndex(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }) else { return false }
        let unit = stores[source].inventory[batchIndex]
        stores[source].inventory[batchIndex].count -= 1
        if stores[source].inventory[batchIndex].count == 0 {
            stores[source].inventory.remove(at: batchIndex)
        }
        stores[destination].inventory.append(InventoryBatch(modelID: unit.modelID, category: unit.category, count: 1, averageCost: unit.averageCost, quality: unit.quality, modelYear: unit.modelYear, mileage: unit.mileage, acquiredTurn: unit.acquiredTurn, productState: unit.productState, productGrade: unit.productGrade, valueAddedInvestment: unit.valueAddedInvestment, vehicleIssue: unit.vehicleIssue))
        save()
        return true
    }

    func regionalOperation(for cityID: String) -> RegionalOperation? {
        regionalOperations.first(where: { $0.cityID == cityID })
    }

    var canExpandNationally: Bool {
        companyValue >= 45_000 || careerStatistics.completedMilestones.contains(.nationalExpansion)
    }

    func franchiseCost(in cityID: String) -> Int {
        guard let city = nationalCities.first(where: { $0.id == cityID }) else { return 0 }
        return Int(2_200.0 * city.landPriceIndex) + 900
    }

    func acquisitionCost(in cityID: String) -> Int {
        guard let city = nationalCities.first(where: { $0.id == cityID }) else { return 0 }
        return Int(5_200.0 * city.landPriceIndex) + 1_400
    }

    @discardableResult
    func establishRegionalOffice(in cityID: String) -> Bool {
        guard cityID != "suihama",
              canExpandNationally,
              regionalOperation(for: cityID) == nil,
              let city = nationalCities.first(where: { $0.id == cityID }),
              cash >= city.expansionCost else { return false }
        cash -= city.expansionCost
        finance.investingCF -= city.expansionCost
        regionalOperations.append(RegionalOperation(cityID: cityID))
        nationalBrandStrength = min(1.35, nationalBrandStrength + 0.04)
        recordCityEvent(CityEvent(turn: turn, kind: .expansion, title: "\(city.name)へ進出", detail: "\(city.region)の地域本社を開設しました"))
        recalculateAssets()
        save()
        return true
    }

    @discardableResult
    func openFranchise(in cityID: String) -> Bool {
        guard let city = nationalCities.first(where: { $0.id == cityID }),
              let index = regionalOperations.firstIndex(where: { $0.cityID == cityID }),
              regionalOperations[index].franchiseStores < 5 else { return false }
        let cost = franchiseCost(in: cityID)
        guard cash >= cost else { return false }
        cash -= cost
        finance.investingCF -= cost
        regionalOperations[index].franchiseStores += 1
        regionalOperations[index].brandStrength = min(1.35, regionalOperations[index].brandStrength + 0.07)
        recordCityEvent(CityEvent(turn: turn, kind: .expansion, title: "\(city.name)にFC出店", detail: "地域ネットワークが\(regionalOperations[index].networkStores)店舗になりました"))
        save()
        return true
    }

    @discardableResult
    func acquireLocalDealer(in cityID: String) -> Bool {
        guard let city = nationalCities.first(where: { $0.id == cityID }),
              let index = regionalOperations.firstIndex(where: { $0.cityID == cityID }),
              regionalOperations[index].acquiredStores < 3 else { return false }
        let cost = acquisitionCost(in: cityID)
        guard cash >= cost else { return false }
        cash -= cost
        finance.investingCF -= cost
        regionalOperations[index].acquiredStores += 1
        regionalOperations[index].brandStrength = min(1.35, regionalOperations[index].brandStrength + 0.12)
        recordCityEvent(CityEvent(turn: turn, kind: .expansion, title: "\(city.name)で地場店を買収", detail: "既存顧客と販売網を引き継ぎました"))
        save()
        return true
    }

    @discardableResult
    func runNationalCampaign(amount: Int = 1_200) -> Bool {
        guard !regionalOperations.isEmpty, amount > 0, cash >= amount else { return false }
        cash -= amount
        finance.operatingCF -= amount
        nationalBrandStrength = min(1.45, nationalBrandStrength + Double(amount) / 18_000.0)
        for index in regionalOperations.indices {
            regionalOperations[index].brandStrength = min(1.40, regionalOperations[index].brandStrength + Double(amount) / 30_000.0)
        }
        recordCityEvent(CityEvent(turn: turn, kind: .expansion, title: "全国ブランド広告を実施", detail: "全国認知度が\(Int(nationalBrandStrength * 100))になりました"))
        save()
        return true
    }

    func updateRegionalAdvertising(cityID: String, budget: Int) {
        guard let index = regionalOperations.firstIndex(where: { $0.cityID == cityID }) else { return }
        regionalOperations[index].advertisingBudget = min(600, max(0, budget))
        save()
    }

    @discardableResult
    func shipInventoryToRegion(cityID: String, from storeID: UUID, category: VehicleCategory, count: Int) -> Bool {
        guard count > 0,
              let city = nationalCities.first(where: { $0.id == cityID }),
              regionalOperation(for: cityID) != nil,
              let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              stores[storeIndex].inventory.filter({ $0.category == category }).reduce(0, { $0 + $1.count }) >= count else { return false }
        let shippingCost = city.shippingCostPerVehicle * count
        guard cash >= shippingCost else { return false }
        guard let removed = removeInventory(category: category, count: count, from: storeIndex) else { return false }
        let unitCost = removed.averageCost
        cash -= shippingCost
        finance.operatingCF -= shippingCost
        intercityShipments.append(IntercityShipment(
            id: UUID(),
            sourceStoreID: storeID,
            destinationCityID: cityID,
            modelID: removed.modelID,
            category: category,
            count: count,
            unitCost: unitCost,
            quality: removed.quality,
            modelYear: removed.modelYear,
            mileage: removed.mileage,
            acquiredTurn: removed.acquiredTurn,
            vehicleIssue: removed.vehicleIssue,
            monthsRemaining: city.shippingMonths
        ))
        recalculateAssets()
        save()
        return true
    }

    func purchaseNegotiationPreview(_ caseID: UUID, offerPercent: Int) -> (price: Int, closeChance: Double)? {
        guard let item = purchaseCases.first(where: { $0.id == caseID }) else { return nil }
        let percent = min(100, max(85, offerPercent))
        let baseChance: Double = percent >= 100 ? 0.96 : percent >= 94 ? 0.80 : 0.60
        let priceGap = Double(item.askingPrice - item.appraisedPrice) / Double(max(1, item.askingPrice))
        let retryPenalty = Double(item.negotiations) * 0.08
        let expertise = stores.first(where: { $0.id == item.storeID }).map {
            min(
                0.20,
                effectiveCategoryExpertise(for: $0, category: item.category) * 0.0012
                    + effectiveSourceExpertise(for: $0, source: .storePurchase) * 0.0008
            )
        } ?? 0
        let offered = item.askingPrice * percent / 100
        let rivalEffect = item.competitorOffer.map {
            min(0.10, max(-0.24, Double(offered - $0.price) / Double(max(1, $0.price)) * 0.60))
        } ?? 0
        let chance = min(0.98, max(0.18, baseChance + priceGap * 0.20 - retryPenalty + expertise + rivalEffect))
        return (item.askingPrice * percent / 100, chance)
    }

    func procurementAppraisalAdvice(for caseID: UUID) -> String? {
        guard let item = purchaseCases.first(where: { $0.id == caseID }),
              let store = stores.first(where: { $0.id == item.storeID }),
              let appraiser = store.employees
                .filter({ $0.assignment == .service })
                .max(by: { $0.appraisalComposite < $1.appraisalComposite }) else { return nil }
        let minimumGrossProfit = max(0, Int((Double(item.expectedSaleAfterAppraisal) * 0.07).rounded()))
        guard let percent = safePurchaseOfferPercent(
            item: item,
            maximumOffer: item.askingPrice,
            minimumGrossProfit: minimumGrossProfit,
            appraiser: appraiser
        ) else {
            return "\(appraiser.name)査定：採算上限が希望額の85%未満。高値づかみを避けるため見送り推奨"
        }
        let price = item.askingPrice * percent / 100
        let issueText = item.revealedIssue.map { issue in "・\(issue.name)を価格へ反映" } ?? ""
        return "\(appraiser.name)査定：上限\(price.currency)（希望額の\(percent)%）\(issueText)"
    }

    private func safePurchaseOfferPercent(
        item: PurchaseCase,
        maximumOffer: Int,
        minimumGrossProfit: Int,
        appraiser _: StoreEmployee
    ) -> Int? {
        // The procurement handler negotiates the deal but never changes the
        // mechanical assessment. The same assessment is used manually and by
        // automatic procurement.
        let assessment = purchaseAssessment(for: item)
        let uncertaintyBuffer = max(0, assessment.repairCostRange.upperBound - assessment.estimatedRepairCost)
        let safePurchasePrice = min(
            maximumOffer,
            item.expectedSaleAfterAppraisal - assessment.estimatedRepairCost - minimumGrossProfit - uncertaintyBuffer
        )
        guard safePurchasePrice > 0 else { return nil }
        let maximumPercent = safePurchasePrice * 100 / max(1, item.askingPrice)
        guard maximumPercent >= 85 else { return nil }
        return min(100, maximumPercent)
    }

    func canNegotiatePurchaseCase(_ caseID: UUID) -> Bool {
        guard let item = purchaseCases.first(where: { $0.id == caseID }),
              stores.contains(where: { $0.id == item.storeID }) else { return false }
        return remainingWeeklyOpportunities(storeID: item.storeID) > 0
    }

    @discardableResult
    func negotiatePurchaseCase(_ caseID: UUID, offerPercent: Int, tradeIn: Bool = false) -> PurchaseNegotiationOutcome {
        guard let caseIndex = purchaseCases.firstIndex(where: { $0.id == caseID }),
              let storeIndex = stores.firstIndex(where: { $0.id == purchaseCases[caseIndex].storeID }),
              let preview = purchaseNegotiationPreview(caseID, offerPercent: offerPercent) else { return .unavailable }
        let item = purchaseCases[caseIndex]
        let repairCost = item.asIsRepairCost
        let total = (preview.price + repairCost) * item.lotCount
        guard cash >= total,
              stores[storeIndex].inventoryCount + item.lotCount <= stores[storeIndex].type.capacity,
              remainingWeeklyOpportunities(storeID: item.storeID) > 0 else { return .unavailable }

        stores[storeIndex].pendingPurchaseNegotiations = stores[storeIndex].purchaseNegotiationsThisWeek + 1

        let seed = turn * 83 + item.modelYear * 7 + item.mileage / 1_000 + offerPercent * 13 + stores[storeIndex].usedOpportunitiesThisWeek * 37
        guard transactionRoll(seed: seed) < preview.closeChance else {
            let nextAttempt = item.negotiations + 1
            let walkedAway = nextAttempt >= 2 || offerPercent <= 88
            recordSellerReview(item: item, offerPercent: min(100, max(85, offerPercent)), succeeded: false, serviceScore: walkedAway ? 48 : 58)
            if walkedAway {
                competitorAcquiresPurchaseCase(item)
                purchaseCases.remove(at: caseIndex)
            }
            else { purchaseCases[caseIndex].negotiationAttempts = nextAttempt }
            save()
            return .rejected(walkedAway: walkedAway)
        }

        cash -= total
        stores[storeIndex].inventory.append(InventoryBatch(
            modelID: item.modelID,
            category: item.category,
            count: item.lotCount,
            averageCost: preview.price + repairCost,
            quality: Double(item.qualityAfterRepairScore) / 100,
            modelYear: item.modelYear,
            mileage: item.mileage,
            acquiredTurn: turn,
            vehicleIssue: item.hiddenIssue.map {
                VehicleIssueRecord(kind: $0, status: item.issueRevealed ? .disclosed : .hidden)
            },
            condition: item.condition,
            fault: item.fault,
            faultRevealed: item.faultRevealed
        ))
        let source: ProcurementSource = tradeIn ? .tradeIn : .storePurchase
        simulationTransactionHandler?(SimulationVehicleTransaction(
            turn: turn,
            kind: .acquired,
            storeID: item.storeID,
            source: source,
            category: item.category,
            count: item.lotCount,
            revenue: 0,
            cost: total,
            purchaseOrigin: item.origin
        ))
        let purpose = stores[storeIndex].marketPolicy.targetPurpose
        stores[storeIndex].expertise.add(category: item.category, purpose: purpose, source: source, points: 1)
        companyExpertise.add(category: item.category, purpose: purpose, source: source, points: 1)
        if let suggested = item.suggestedProjectKind,
           let inventoryID = stores[storeIndex].inventory.last?.id {
            _ = startWorkshopProject(
                storeID: item.storeID,
                inventoryID: inventoryID,
                kind: suggested,
                fulfillment: .automatic
            )
        }
        recordSellerReview(item: item, offerPercent: min(100, max(85, offerPercent)), succeeded: true, serviceScore: tradeIn ? 90 : 84)
        purchaseCases.remove(at: caseIndex)
        recalculateAssets()
        save()
        return .purchased(price: preview.price * item.lotCount)
    }

    @discardableResult
    func acceptPurchaseCase(_ caseID: UUID, negotiated: Bool = false, tradeIn: Bool = false) -> Bool {
        if case .purchased = negotiatePurchaseCase(caseID, offerPercent: negotiated ? 88 : 100, tradeIn: tradeIn) {
            return true
        }
        return false
    }

    func servicePreview(storeID: UUID, inventoryID: UUID) -> (cost: Int, qualityGain: Int, resultingQuality: Int)? {
        guard let preview = workshopProjectPreview(storeID: storeID, inventoryID: inventoryID, kind: .basicService) else { return nil }
        return (preview.cost, preview.qualityGain, preview.resultingQuality)
    }

    @discardableResult
    func serviceInventory(storeID: UUID, inventoryID: UUID) -> Bool {
        startWorkshopProject(storeID: storeID, inventoryID: inventoryID, kind: .basicService)
    }

    func workshopProjectPreview(
        storeID: UUID,
        inventoryID: UUID,
        kind: WorkshopProjectKind,
        grade requestedGrade: SpecialtyProductGrade? = nil,
        fulfillment requestedMode: WorkFulfillmentMode = .automatic
    ) -> WorkshopProjectPreview? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID),
              let batch = store.inventory.first(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }),
              let model = VehicleCatalog.entry(id: batch.modelID) else { return nil }
        let proposedState = kind.productState ?? batch.productState
        let proposedProductKind = MarketProductKind.resolve(
            productState: proposedState,
            isRareClassic: model.isRareClassic
        )
        let isGradeProject = proposedProductKind.supportsGrades
            && ![WorkshopProjectKind.basicService, .repair].contains(kind)
            && (kind != .refurbishment || model.isRareClassic)
        let resolvedGrade = isGradeProject ? (requestedGrade ?? .low) : nil
        let isGradeUpgrade = resolvedGrade.map {
            batch.productState == proposedState && (batch.productGrade ?? .low) < $0
        } ?? false
        let serviceEmployees = store.employees.filter { $0.assignment == .service }
        let activeInventoryProjects = store.inventory.filter {
            $0.workshopProject?.outsourced == false
                && $0.workshopProject?.kind.usesCustomizationBay == kind.usesCustomizationBay
        }.count
        let activeCustomerProjects = kind.usesCustomizationBay
            ? customerCustomizationOrders.filter { $0.storeID == storeID && $0.status == .active }.count
            : 0
        let activeInHouse = activeInventoryProjects + activeCustomerProjects
        let compatibleBays = store.bays(for: kind)
        let hasCompatibleBay = compatibleBays > 0
        let canDoInHouse = compatibleBays > activeInHouse && !serviceEmployees.isEmpty
        let partner = OutsourcePartnerKind.partner(for: kind)
        let fulfillment: WorkFulfillmentMode
        switch requestedMode {
        case .automatic:
            fulfillment = canDoInHouse ? .inHouse : .outsourced
        case .inHouse:
            guard canDoInHouse else { return nil }
            fulfillment = .inHouse
        case .outsourced:
            fulfillment = .outsourced
        }
        let outsourced = fulfillment == .outsourced
        if kind == .camperConversion && batch.category != .minivan { return nil }
        if kind == .workConversion && ![VehicleCategory.minivan, .pickup].contains(batch.category) { return nil }
        if kind == .outdoorConversion && ![VehicleCategory.suv, .pickup, .minivan].contains(batch.category) { return nil }
        if [.streetTuning, .driftTuning, .circuitTuning].contains(kind),
           (!model.isSportTuningBase || model.isRareClassic) { return nil }
        if kind == .liftSeatConversion && ![VehicleCategory.kei, .compact, .minivan].contains(batch.category) { return nil }
        if kind == .wheelchairConversion && ![VehicleCategory.kei, .minivan].contains(batch.category) { return nil }
        if kind == .mobileSalesConversion && ![VehicleCategory.minivan, .pickup].contains(batch.category) { return nil }
        if kind == .kitchenCarConversion && ![VehicleCategory.minivan, .pickup].contains(batch.category) { return nil }
        if kind == .repair && batch.fault == .none { return nil }
        switch kind {
        case .basicService:
            guard batch.productState == .stock else { return nil }
        case .repair:
            break
        case .refurbishment:
            guard [.stock, .serviced, .repaired].contains(batch.productState) || isGradeUpgrade else { return nil }
        case .camperConversion, .workConversion, .outdoorConversion,
             .streetTuning, .driftTuning, .circuitTuning,
             .liftSeatConversion, .wheelchairConversion,
             .mobileSalesConversion, .kitchenCarConversion:
            guard [.stock, .serviced, .repaired, .refurbished].contains(batch.productState) || isGradeUpgrade else { return nil }
        }
        let currentQuality = Int((batch.quality * 100).rounded())
        var baseCost: Int
        var requiredWork: Int
        let requestedGain: Int
        let targetState: VehicleProductState
        switch kind {
        case .basicService:
            baseCost = max(12, batch.category.purchaseCost / 18); requiredWork = 1; requestedGain = 2; targetState = .serviced
        case .repair:
            requiredWork = max(2, batch.fault.requiredWork)
            baseCost = max(24, batch.category.purchaseCost * requiredWork / 15)
            requestedGain = min(14, requiredWork + 3); targetState = .repaired
        case .refurbishment:
            baseCost = max(80, Int(Double(model.baseWholesalePrice) * (model.isRareClassic ? 0.52 : 0.28)))
            requiredWork = 6; requestedGain = currentQuality < 65 ? 15 : 10; targetState = .refurbished
        case .camperConversion:
            baseCost = max(180, Int(Double(model.baseWholesalePrice) * 0.90)); requiredWork = 10; requestedGain = 3; targetState = .camper
        case .workConversion:
            baseCost = max(45, Int(Double(batch.category.purchaseCost) * 0.22)); requiredWork = 5; requestedGain = 2; targetState = .workCargo
        case .outdoorConversion:
            baseCost = max(35, Int(Double(batch.category.purchaseCost) * 0.18)); requiredWork = 4; requestedGain = 2; targetState = .outdoor
        case .streetTuning:
            baseCost = max(70, Int(Double(model.referenceRetailPrice) * 0.22)); requiredWork = 5; requestedGain = 3; targetState = .sportStreet
        case .driftTuning:
            baseCost = max(120, Int(Double(model.referenceRetailPrice) * 0.38)); requiredWork = 7; requestedGain = 4; targetState = .sportDrift
        case .circuitTuning:
            baseCost = max(180, Int(Double(model.referenceRetailPrice) * 0.55)); requiredWork = 9; requestedGain = 5; targetState = .sportCircuit
        case .liftSeatConversion:
            baseCost = max(65, Int(Double(model.referenceRetailPrice) * 0.22)); requiredWork = 5; requestedGain = 2; targetState = .welfareLiftSeat
        case .wheelchairConversion:
            baseCost = max(110, Int(Double(model.referenceRetailPrice) * 0.40)); requiredWork = 8; requestedGain = 3; targetState = .welfareWheelchair
        case .mobileSalesConversion:
            baseCost = max(90, Int(Double(model.referenceRetailPrice) * 0.30)); requiredWork = 6; requestedGain = 2; targetState = .mobileSales
        case .kitchenCarConversion:
            baseCost = max(170, Int(Double(model.referenceRetailPrice) * 0.60)); requiredWork = 10; requestedGain = 3; targetState = .kitchenCar
        }
        if let resolvedGrade {
            if isGradeUpgrade {
                let currentRank = (batch.productGrade ?? .low).rank
                requiredWork = max(1, resolvedGrade.rank - currentRank)
            } else if kind.usesCustomizationBay {
                let completionTarget = resolvedGrade.rank + 2
                requiredWork = max(1, completionTarget - kind.completionInspectionWeeks)
            }
        }
        requiredWork = min(requiredWork, kind.maximumWorkWeeks)
        let gradeCostMultiplier: Double
        if let resolvedGrade {
            let currentMultiplier = isGradeUpgrade ? (batch.productGrade ?? .low).costMultiplier : 0
            gradeCostMultiplier = max(0, resolvedGrade.costMultiplier - currentMultiplier)
        } else {
            gradeCostMultiplier = 1
        }
        baseCost = max(1, Int((Double(baseCost) * gradeCostMultiplier).rounded()))
        let outsourceBaselineCost = Int((Double(baseCost) * partner.costMultiplier).rounded())
        let staffDiscount = outsourced || serviceEmployees.isEmpty
            ? 0
            : employeeServiceCostDiscount(for: storeID)
        let facilityDiscount = outsourced || !hasCompatibleBay ? 0 : 30
        let finalCostRate = max(30, 100 - staffDiscount - facilityDiscount)
        let cost = max(1, Int((Double(outsourceBaselineCost) * Double(finalCostRate) / 100).rounded()))
        let bestSkill = serviceEmployees.map(\.serviceSkill).max() ?? 35
        let inHouseCap = min(model.isRareClassic ? 92 : 96, (model.isRareClassic ? 82 : 85) + bestSkill / 8)
        let qualityCap = outsourced ? (model.isRareClassic ? 86 : 90) : inHouseCap
        let resultingQuality = min(qualityCap, currentQuality + requestedGain)
        var projected = batch
        projected.quality = Double(resultingQuality) / 100.0
        projected.averageCost += cost
        projected.valueAddedInvestment += cost
        projected.productState = targetState
        projected.productGrade = resolvedGrade
        projected.workshopProject = nil
        let baseVehicleMarketValue = vehicleRetailValue(
            modelID: projected.modelID,
            category: projected.category,
            modelYear: projected.modelYear,
            mileage: projected.mileage,
            quality: projected.quality,
            in: plot.district
        )
        let marketValue = baseVehicleMarketValue + productizationMarketValueAddition(for: projected)
        let disclosedIssueFactor = projected.disclosedIssue?.disclosedValueFactor ?? 1.0
        let projectedPurpose = targetState.purpose ?? store.marketPolicy.targetPurpose
        let purposeValue = productPurposeValueFactor(for: projected, purpose: projectedPurpose)
        let projectedKey = MarketSegmentKey(
            district: plot.district,
            category: projected.category,
            purpose: projectedPurpose,
            productKind: proposedProductKind
        )
        let listPricingFactor = store.priceIndex
            * inventoryAgingValueFactor(for: projected)
            * specialtyMarketFactor(for: projected, in: plot.district)
            * disclosedIssueFactor
        let rawListPrice = max(25, Int(Double(marketValue) * listPricingFactor))
        let baseVehiclePrice = max(25, Int(Double(baseVehicleMarketValue) * listPricingFactor))
        let valueSupportedPrice = max(
            rawListPrice,
            customizationValueSupportedPrice(
                for: projected,
                baseVehiclePrice: baseVehiclePrice
            ) ?? 0
        )
        let uncappedProjectedPrice = max(25, Int(
            Double(marketValue)
                * listPricingFactor
                * purposeValue
                * segmentWillingnessFactor(
                    for: projectedKey,
                    store: store,
                    productState: targetState,
                    grade: resolvedGrade
                )
        ))
        let specialtyPriceCap = resolvedGrade != nil
            ? max(
                valueSupportedPrice,
                Int(specialtyReferenceRetail(for: model) * specialtyPriceCeiling(
                    for: proposedProductKind,
                    productState: targetState,
                    grade: resolvedGrade
                ))
            )
            : nil
        let projectedPrice = max(
            valueSupportedPrice,
            specialtyPriceCap.map { min(uncappedProjectedPrice, $0) } ?? uncappedProjectedPrice
        )
        let labor = max(1, store.weeklyWorkshopLabor)
        let effectiveExpertise = min(100, store.expertise.project(kind) + companyExpertise.project(kind) * 0.25)
        let expertiseEfficiency = 1 + min(0.20, effectiveExpertise / 500)
        let effectiveLabor = max(1, Int((Double(labor) * expertiseEfficiency).rounded()))
        let estimatedWeeks = min(
            kind.maximumCompletionWeeks,
            outsourced
                ? requiredWork + partner.extraWeeks + kind.completionInspectionWeeks
                : Int(ceil(Double(requiredWork) / Double(effectiveLabor))) + kind.completionInspectionWeeks
        )
        return WorkshopProjectPreview(
            kind: kind,
            grade: resolvedGrade,
            cost: cost,
            outsourceBaselineCost: outsourceBaselineCost,
            staffDiscount: staffDiscount,
            facilityDiscount: facilityDiscount,
            finalCostRate: finalCostRate,
            requiredWork: requiredWork,
            estimatedWeeks: estimatedWeeks,
            qualityGain: resultingQuality - currentQuality,
            resultingQuality: resultingQuality,
            projectedSalePrice: projectedPrice,
            outsourced: outsourced,
            fulfillmentMode: fulfillment,
            outsourcePartner: outsourced ? partner : nil,
            qualityCap: qualityCap
        )
    }

    @discardableResult
    func startWorkshopProject(
        storeID: UUID,
        inventoryID: UUID,
        kind: WorkshopProjectKind,
        grade: SpecialtyProductGrade? = nil,
        fulfillment: WorkFulfillmentMode = .automatic
    ) -> Bool {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }),
              let preview = workshopProjectPreview(storeID: storeID, inventoryID: inventoryID, kind: kind, grade: grade, fulfillment: fulfillment),
              cash >= preview.cost else { return false }
        let activeInventoryProjects = stores[storeIndex].inventory.filter {
            $0.workshopProject?.outsourced == false
                && $0.workshopProject?.kind.usesCustomizationBay == kind.usesCustomizationBay
        }.count
        let activeCustomerProjects = kind.usesCustomizationBay
            ? customerCustomizationOrders.filter { $0.storeID == storeID && $0.status == .active }.count
            : 0
        let activeInHouse = activeInventoryProjects + activeCustomerProjects
        guard preview.outsourced || activeInHouse < stores[storeIndex].bays(for: kind) else { return false }

        let original = stores[storeIndex].inventory[batchIndex]
        if original.count > 1 {
            stores[storeIndex].inventory[batchIndex].count = 1
            stores[storeIndex].inventory.append(InventoryBatch(
                modelID: original.modelID,
                category: original.category,
                count: original.count - 1,
                averageCost: original.averageCost,
                quality: original.quality,
                modelYear: original.modelYear,
                mileage: original.mileage,
                acquiredTurn: original.acquiredTurn,
                productState: original.productState,
                productGrade: original.productGrade,
                valueAddedInvestment: original.valueAddedInvestment,
                vehicleIssue: original.vehicleIssue,
                condition: original.condition,
                fault: original.fault,
                faultRevealed: original.faultRevealed
            ))
        }
        cash -= preview.cost
        finance.operatingCF -= preview.cost
        stores[storeIndex].inventory[batchIndex].averageCost += preview.cost
        stores[storeIndex].inventory[batchIndex].valueAddedInvestment += preview.cost
        stores[storeIndex].inventory[batchIndex].workshopProject = VehicleWorkshopProject(
            kind: kind,
            targetGrade: preview.grade,
            requiredWork: preview.requiredWork,
            remainingWork: preview.requiredWork,
            cost: preview.cost,
            qualityGain: preview.qualityGain,
            startedTurn: turn,
            priority: 0,
            outsourced: preview.outsourced,
            outsourcePartner: preview.outsourcePartner,
            outsourcedWeeksRemaining: preview.outsourced ? preview.estimatedWeeks : 0,
            inspectionWeeksRemaining: preview.outsourced ? 0 : kind.completionInspectionWeeks
        )
        recalculateAssets()
        save()
        return true
    }

    @discardableResult
    func setWorkshopPriority(storeID: UUID, inventoryID: UUID, priority: Int) -> Bool {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.id == inventoryID }),
              stores[storeIndex].inventory[batchIndex].workshopProject != nil else { return false }
        stores[storeIndex].inventory[batchIndex].workshopProject?.priority = min(3, max(0, priority))
        save()
        return true
    }

    func declinePurchaseCase(_ caseID: UUID) {
        if let item = purchaseCases.first(where: { $0.id == caseID }) {
            recordSellerReview(item: item, offerPercent: nil, succeeded: false, serviceScore: 42, declinedByStore: true)
            competitorAcquiresPurchaseCase(item)
        }
        purchaseCases.removeAll { $0.id == caseID }
        save()
    }

    private func competitorAcquiresPurchaseCase(_ item: PurchaseCase) {
        guard let offer = item.competitorOffer,
              let competitorIndex = competitors.firstIndex(where: { $0.id == offer.competitorID }),
              let district = stores.first(where: { $0.id == item.storeID }).flatMap({ plot(id: $0.plotID)?.district }),
              let branchIndex = competitors[competitorIndex].branches.firstIndex(where: {
                  plot(id: $0.plotID)?.district == district && $0.inventoryCount + item.lotCount <= $0.capacity
              }) else { return }
        let total = offer.price * item.lotCount
        guard competitors[competitorIndex].cash >= total else { return }
        competitors[competitorIndex].cash -= total
        addCompetitorInventory(
            competitorIndex: competitorIndex, branchIndex: branchIndex,
            category: item.category, purpose: offer.purpose, count: item.lotCount,
            unitCost: offer.price, quality: item.condition.quality, productState: .stock
        )
        competitors[competitorIndex].expertise.add(category: item.category, purpose: offer.purpose, source: .storePurchase, points: 1)
    }

    func borrow(_ amount: Int) {
        guard amount > 0, debt + amount <= borrowingLimit else { return }
        debt += amount; cash += amount; finance.financingCF += amount
        if cash >= -2_000 { financialDistressWeeks = 0 }
        save()
    }

    func repay(_ amount: Int) {
        let actual = min(amount, debt, cash)
        debt -= actual; cash -= actual; finance.financingCF -= actual
        save()
    }

    var borrowingLimit: Int {
        let base = borrowingLimitBeforeCredit
        switch creditRating {
        case "C": return base * 3 / 4
        case "B": return base * 9 / 10
        default: return base
        }
    }

    private var borrowingLimitBeforeCredit: Int {
        let collateral = finance.landAssets * 6 / 10 + finance.buildingAssets * 3 / 10
        return max(15_000, collateral + 12_000) + milestoneCreditBonus
    }

    var creditRating: String {
        let utilization = Double(debt) / Double(max(1, borrowingLimitBeforeCredit))
        let recent = reports.prefix(4)
        let losses = recent.filter { $0.operatingProfit < 0 }.count
        if financialDistressWeeks > 0 || utilization >= 0.90 || losses >= 3 { return "C" }
        if utilization >= 0.60 || losses >= 2 { return "B" }
        return "A"
    }

    var financialDistressMessage: String? {
        guard financialDistressWeeks > 0 else { return nil }
        return "資金危機 \(financialDistressWeeks)/2週：次の週間処理までに借入、在庫売却、固定費削減で現金を回復してください"
    }

    func advanceWeek() {
        guard !gameOver else { return }
        // ガイドは助言のみで、週の進行や画面操作を禁止しません。
        let isFirstTutorialMonth = tutorialStep == .runFirstMonth
        let reportYear = year, reportMonth = month, reportWeek = weekOfMonth
        var totalSales = 0, revenue = 0, costOfSales = 0, personnel = 0, rent = 0, ads = 0, depreciation = 0
        var revenueToCollect = 0
        var weeklyNegotiations = 0
        var weeklyTradeIns = 0
        var notes: [String] = []
        procurementWeekActivities = [:]
        beginProcurementWeek()
        beginEmployeeWeek()
        let resolvedClaimCount = pendingCustomerClaims.filter { $0.dueTurn <= turn + 1 }.count
        let claimCostsByStore = resolveCustomerClaims(at: turn + 1, notes: &notes)
        let claimCosts = claimCostsByStore.values.reduce(0, +)
        processInboundShipments(notes: &notes)
        processIntercityShipments(notes: &notes)
        progressWorkshopProjects(notes: &notes)
        progressStoreProjects(notes: &notes)
        settleAuctionConsignments(notes: &notes)
        prepareCompetitorAuctionPlans()
        applyDelegatedOperations(notes: &notes)
        var automaticSalesByStore: [UUID: AutomaticSaleResult] = [:]
        for index in stores.indices where stores[index].isOperational {
            progressAutomaticMarketing(for: index)
            resolveAutomaticService(for: index)
            resolveAutomaticProcurement(for: index, notes: &notes)
        }
        // 手動・自動を問わず、その週に行った入札は同じ週次締切で一度だけ確定する。
        // 自動仕入れより先に決済すると、自動入札だけ翌々週へ持ち越されてしまう。
        resolveAuctionBids(at: turn + 1, notes: &notes)
        resolveNetworkAuctionBids(at: turn + 1, notes: &notes)
        resolveCompetitorAuctionPurchases(at: turn + 1, notes: &notes)
        resolveCorporateOpportunities(at: turn + 1, notes: &notes)
        for index in stores.indices where stores[index].isOperational {
            automaticSalesByStore[stores[index].id] = resolveAutomaticSales(for: index)
        }
        finalizeEmployeeWeek(notes: &notes)

        for index in stores.indices {
            guard let plot = plot(id: stores[index].plotID) else { continue }
            guard stores[index].isOperational else {
                stores[index].lastSales = 0
                stores[index].lastRevenue = 0
                stores[index].lastProfit = 0
                stores[index].causes = [ResultCause("開店準備中", -1)]
                continue
            }
            let previousVisualTier = stores[index].visualTier
            let district = district(for: plot)
            let demand = demandFit(store: stores[index], district: district)
            let conceptMatch = 1.0
            let marketing = 0.85 + min(0.35, Double(stores[index].advertising) / 600.0)
            let share = marketShare(for: stores[index])
            let competition = 0.62 + share * 0.76
            let capacity = min(stores[index].inventoryCount, stores[index].type.capacity)
            let automatic = automaticSalesByStore[stores[index].id] ?? AutomaticSaleResult()
            let manualSales = stores[index].pendingManualSales
            let sales = automatic.sales + manualSales
            weeklyNegotiations += automatic.attempts + stores[index].pendingManualNegotiations
            weeklyTradeIns += automatic.tradeIns

            let storeRevenue = stores[index].pendingManualRevenue
                + stores[index].pendingCustomizationRevenue
                + automatic.revenue
            let storeCOGS = stores[index].pendingManualCOGS
                + stores[index].pendingCustomizationCOGS
                + automatic.costOfSales
            revenueToCollect += automatic.cashCollected
            if automatic.tradeIns > 0 {
                notes.append("\(stores[index].name)社員：販売商談と同時に下取り車\(automatic.tradeIns)台を在庫化")
            }
            let staffCost = weeklyPersonnelCost(for: stores[index]) + automatic.commission
            let combinedRent = stores[index].plotIDs.compactMap { self.plot(id: $0)?.monthlyRent }.reduce(0, +)
            let storeRent = stores[index].acquisition == .lease ? max(1, combinedRent / 4) : 0
            let weeklyAdvertising = stores[index].advertising / 4
            let weeklyFixedCost = (stores[index].type.monthlyFixedCost + stores[index].facilityMonthlyCost) / 4
            let storeDepreciation = (stores[index].type.buildCost + stores[index].facilityInvestment) / 960
            let storeClaimCosts = claimCostsByStore[stores[index].id] ?? 0
            let storeProfit = storeRevenue - storeCOGS - staffCost - storeRent - weeklyAdvertising - weeklyFixedCost - storeDepreciation - storeClaimCosts
            stores[index].lastSales = sales
            stores[index].lastRevenue = storeRevenue
            stores[index].lastProfit = storeProfit
            stores[index].causes = makeCauses(demand: demand, concept: conceptMatch, conceptName: derivedBusinessName(for: stores[index]), marketing: marketing, competition: competition, inventory: capacity)
            stores[index].causes.append(ResultCause(
                stores[index].reviewCount == 0 ? "口コミ実績なし" : "来店客口コミ",
                (stores[index].customerReviewAttraction(for: .buyer) - 1) * 5
            ))
            stores[index].pendingManualSales = 0
            stores[index].pendingManualRevenue = 0
            stores[index].pendingManualCOGS = 0
            stores[index].pendingCustomizationRevenue = 0
            stores[index].pendingCustomizationCOGS = 0
            stores[index].pendingManualNegotiations = 0
            stores[index].pendingPurchaseNegotiations = 0
            if stores[index].visualTier > previousVisualTier {
                recordCityEvent(CityEvent(turn: turn + 1, kind: .storeGrowth, title: "\(stores[index].name)が成長", detail: "評判と業績が向上し、店舗外観がレベル\(stores[index].visualTier)になりました", district: plot.district, plotID: plot.id))
                notes.append("\(stores[index].name)の店舗外観が成長しました")
            }
            totalSales += sales; revenue += storeRevenue; costOfSales += storeCOGS; personnel += staffCost; rent += storeRent; ads += weeklyAdvertising; depreciation += storeDepreciation
        }

        progressEmployeeCareers(notes: &notes)

        let regional = simulateRegionalOperations(notes: &notes)
        totalSales += regional.sales
        revenue += regional.revenue
        revenueToCollect += regional.revenue
        costOfSales += regional.costOfSales
        personnel += regional.fixedCosts
        ads += regional.advertising

        let fixed = stores.filter(\.isOperational).reduce(0) { $0 + ($1.type.monthlyFixedCost + $1.facilityMonthlyCost) / 4 }
        let interest = debt / 9_600
        let operatingProfit = revenue - costOfSales - personnel - rent - ads - depreciation - fixed - interest - claimCosts
        var cashChange = revenueToCollect - personnel - rent - ads - fixed - interest - claimCosts
        cash += cashChange
        finance = FinanceSnapshot(
            revenue: revenue,
            costOfSales: costOfSales,
            personnel: personnel,
            rent: rent,
            advertising: ads,
            depreciation: depreciation,
            fixedCosts: fixed,
            interest: interest,
            customerClaims: claimCosts,
            operatingProfit: operatingProfit,
            landAssets: finance.landAssets,
            buildingAssets: finance.buildingAssets,
            inventoryAssets: inventoryAssetValue(),
            debt: debt,
            operatingCF: operatingProfit + depreciation,
            investingCF: 0,
            financingCF: -interest
        )
        simulateDistrictDynamics(notes: &notes)
        updateMarketConditions(notes: &notes)
        updateLandValues(notes: &notes)
        progressDevelopments(notes: &notes)
        let missedBuyers = expireWeeklyCustomerLeads(notes: &notes)
        progressInventorySaleCampaigns(notes: &notes)
        finalizeSegmentWeek(notes: &notes)
        updateSegmentTrends(at: turn + 1, notes: &notes)
        simulateCompetitors(notes: &notes)
        turn += 1
        announceNewModels(notes: &notes)
        weekOfMonth += 1
        if weekOfMonth > 4 {
            weekOfMonth = 1
            month += 1
            if month > 12 { month = 1; year += 1 }
        }
        applyPendingMarketPolicies()
        updateSpecialtyCertifications(notes: &notes)
        generateWeeklyCustomerLeads()
        generateAuctionListings()
        generateNetworkAuctionListings()
        generateCorporateOpportunities()
        unlockTutorial(notes: &notes)
        recalculateAssets()
        companyValue = max(0, cash + finance.landAssets + finance.buildingAssets + finance.inventoryAssets - debt + max(0, operatingProfit * 18))
        recordCareerProgress(year: reportYear, sales: totalSales, revenue: revenue, operatingProfit: operatingProfit)
        let cashBeforeMilestones = cash
        let achievedMilestones = evaluateMilestones(notes: &notes)
        cashChange += cash - cashBeforeMilestones
        companyValue = max(0, cash + finance.landAssets + finance.buildingAssets + finance.inventoryAssets - debt + max(0, operatingProfit * 18))
        if cash < -2_000 {
            financialDistressWeeks += 1
            notes.append("資金危機\(financialDistressWeeks)/2週。融資余力\(max(0, borrowingLimit - debt).currency)、在庫売却、店舗固定費を確認してください")
            if financialDistressWeeks == 1 {
                recordCityEvent(CityEvent(turn: turn, kind: .milestone, title: "資金繰り警報", detail: "支払余力が危険水準です。次週までに資金を回復できなければ経営継続が困難になります", isPositive: false))
            }
        } else {
            financialDistressWeeks = 0
        }
        let headline: String
        if financialDistressWeeks > 0 { headline = "資金危機です。次週までに資金繰りを立て直してください" }
        else if let milestone = achievedMilestones.first { headline = "目標達成：\(milestone.title)" }
        else if claimCosts > 0 { headline = "販売後クレームが発生。査定と告知体制を見直しましょう" }
        else if operatingProfit > 100 { headline = "好調な一週間。次の仕入れを考えましょう" }
        else if operatingProfit >= 0 { headline = "黒字を確保。店舗ごとの差を確認しましょう" }
        else { headline = "赤字です。原因を確認して手を打ちましょう" }
        if totalInventory < stores.count * 5 { notes.append("在庫が少なく、販売機会を逃す店舗があります") }
        let averageInventoryWeeks = averageInventoryWeeks()
        let agingInventory = stores.flatMap(\.inventory).reduce(0) { total, batch in
            total + (inventoryAgeWeeks(for: batch) > 12 ? batch.count : 0)
        }
        if agingInventory > 0 {
            notes.append("12週超の滞留在庫が\(agingInventory)台あります。値引き販売や在庫構成の見直しを検討しましょう")
        }
        let report = MonthlyReport(
            id: UUID(),
            year: reportYear,
            month: reportMonth,
            week: reportWeek,
            sales: totalSales,
            revenue: revenue,
            costOfSales: costOfSales,
            grossProfit: revenue - costOfSales,
            personnel: personnel,
            rent: rent,
            advertising: ads,
            depreciation: depreciation,
            fixedCosts: fixed,
            interest: interest,
            customerClaims: claimCosts,
            operatingProfit: operatingProfit,
            cashChange: cashChange,
            averageInventoryWeeks: averageInventoryWeeks,
            headline: headline,
            notes: notes,
            procurement: procurementReportLines(),
            storeResults: stores.map {
                StoreWeeklyResult(
                    storeID: $0.id,
                    storeName: $0.name,
                    sales: $0.lastSales,
                    revenue: $0.lastRevenue,
                    operatingProfit: $0.lastProfit,
                    causes: $0.causes
                )
            },
            salesSummary: WeeklySalesSummary(
                negotiations: weeklyNegotiations,
                sales: totalSales,
                missedBuyers: missedBuyers,
                tradeIns: weeklyTradeIns,
                claimCount: resolvedClaimCount,
                claimCost: claimCosts
            )
        )
        reports.insert(report, at: 0); lastReport = report
        if reportWeek == 4 {
            let completedMonth = makeMonthlyPLReport(year: reportYear, month: reportMonth)
            monthlyReports.removeAll { $0.year == reportYear && $0.month == reportMonth }
            monthlyReports.insert(completedMonth, at: 0)
            lastMonthlyReport = completedMonth
        }
        if isFirstTutorialMonth || (tutorialStep != nil && tutorialStep != .completed && !stores.isEmpty) {
            tutorialStep = .completed
        }
        let automaticallyShowReport = persistenceEnabled
            ? UserDefaults.standard.object(forKey: "settings.autoShowWeeklyReport") as? Bool ?? true
            : false
        beginWeeklyPresentationSequence(
            includesWeeklyReport: automaticallyShowReport,
            includesMonthlyPL: automaticallyShowReport && reportWeek == 4
        )
        if financialDistressWeeks >= 2 { gameOver = true }
        if turn >= maxTurns { gameOver = true }
        recalculateAssets()
        save()
    }

    func weeklyComparison(for report: MonthlyReport) -> WeeklyReportComparison? {
        guard let index = reports.firstIndex(where: { $0.id == report.id }),
              reports.indices.contains(index + 1) else { return nil }
        let previous = reports[index + 1]
        return WeeklyReportComparison(
            sales: report.sales - previous.sales,
            revenue: report.revenue - previous.revenue,
            grossProfit: report.grossProfit - previous.grossProfit,
            operatingProfit: report.operatingProfit - previous.operatingProfit,
            cashChange: report.cashChange - previous.cashChange,
            averageInventoryWeeks: report.averageInventoryWeeks - previous.averageInventoryWeeks
        )
    }

    private func makeMonthlyPLReport(year: Int, month: Int) -> MonthlyPLReport {
        let weeks = reports
            .filter { $0.year == year && $0.month == month }
            .sorted { $0.week < $1.week }
        return MonthlyPLReport(
            id: UUID(),
            year: year,
            month: month,
            weeklyReports: weeks,
            sales: weeks.reduce(0) { $0 + $1.sales },
            revenue: weeks.reduce(0) { $0 + $1.revenue },
            costOfSales: weeks.reduce(0) { $0 + $1.costOfSales },
            grossProfit: weeks.reduce(0) { $0 + $1.grossProfit },
            personnel: weeks.reduce(0) { $0 + $1.personnel },
            rent: weeks.reduce(0) { $0 + $1.rent },
            advertising: weeks.reduce(0) { $0 + $1.advertising },
            depreciation: weeks.reduce(0) { $0 + $1.depreciation },
            fixedCosts: weeks.reduce(0) { $0 + $1.fixedCosts },
            interest: weeks.reduce(0) { $0 + $1.interest },
            customerClaims: weeks.reduce(0) { $0 + $1.customerClaims },
            operatingProfit: weeks.reduce(0) { $0 + $1.operatingProfit },
            cashChange: weeks.reduce(0) { $0 + $1.cashChange },
            averageInventoryWeeks: weeks.isEmpty
                ? averageInventoryWeeks()
                : weeks.reduce(0) { $0 + $1.averageInventoryWeeks } / Double(weeks.count),
            endingCash: cash,
            debt: debt,
            inventoryAssets: inventoryAssetValue(),
            companyValue: companyValue
        )
    }

    private func applyPendingMarketPolicies() {
        for index in stores.indices {
            if var policy = stores[index].pendingMarketPolicy {
                policy.normalize()
                stores[index].marketPolicy = policy
                stores[index].pendingMarketPolicy = nil
                stores[index].marketRepositioningWeeks = 2
            } else if stores[index].marketRepositioningWeeks > 0 {
                stores[index].marketRepositioningWeeks -= 1
            }
        }
    }

    func recommendedCategories(for kind: DistrictKind) -> [VehicleCategory] {
        guard let district = districts.first(where: { $0.kind == kind }) else { return [.compact] }
        return district.demands.sorted { $0.value > $1.value }.map(\.key)
    }

    func demandScore(for plot: LandPlot) -> Double {
        let d = district(for: plot)
        return d.demands.values.reduce(0, +) / Double(max(1, d.demands.count)) * d.growthRate
    }

    func vehicleDemand(_ category: VehicleCategory, in kind: DistrictKind) -> Double {
        districts.first(where: { $0.kind == kind })?.demands[category] ?? 0.55
    }

    func vehicleSupply(_ category: VehicleCategory, in kind: DistrictKind) -> Double {
        districts.first(where: { $0.kind == kind })?.supplies[category] ?? 0.42
    }

    func recommendedSupplyCategories(for kind: DistrictKind) -> [VehicleCategory] {
        guard let district = districts.first(where: { $0.kind == kind }) else { return [.compact] }
        return district.supplies.sorted { $0.value > $1.value }.map(\.key)
    }

    func catchmentStrength(for store: Store) -> Double {
        guard let plot = plot(id: store.plotID) else { return 0.7 }
        let district = district(for: plot)
        let marketing = 0.78 + min(0.42, Double(store.advertising) / 520)
        let competitivePressure = max(0.58, 1.15 - district.competition * 0.22)
        return min(1.35, max(0.55, store.reputation * marketing * plot.access * competitivePressure))
    }

    func profitabilityScore(for plot: LandPlot) -> Double {
        let sales = estimatedSales(for: plot).upperBound
        let cost = Double(plot.monthlyRent + StoreType.standard.monthlyFixedCost)
        return Double(sales * 35) / max(1, cost)
    }

    private func isAvailable(_ occupant: PlotOccupant) -> Bool {
        if case .available = occupant { return true }
        return false
    }

    private func assertGridOccupancyIntegrity() {
#if DEBUG
        let issues = gridOccupancyIssues
        assert(issues.isEmpty, issues.map(\.description).joined(separator: "\n"))
#endif
    }

    private func footprintPlots(
        startingAt plot: LandPlot,
        type: StoreType,
        mode: AcquisitionMode?,
        occupiedBy storeID: UUID?,
        requiredExistingIDs: Set<Int>
    ) -> [LandPlot] {
        GridStorePlacementAdapter.footprintPlots(
            startingAt: plot,
            type: type,
            plots: plots,
            map: CityMapDefinition.suihama,
            acquisitionMode: mode,
            occupiedBy: storeID,
            requiredExistingIDs: requiredExistingIDs
        )
    }

    private func competitorCount(in district: DistrictKind) -> Int {
        competitors.reduce(0) { $0 + $1.plotIDs.compactMap { plot(id: $0) }.filter { $0.district == district }.count }
    }

    private func demandFit(store: Store, district: District) -> Double {
        let stocked = store.inventory.filter { $0.count > 0 && !$0.isInWorkshop && !$0.isReserved }
        guard !stocked.isEmpty else { return 0.45 }
        let weighted = stocked.reduce(0.0) { $0 + (district.demands[$1.category] ?? 0.7) * Double($1.count) }
        return weighted / Double(max(1, store.inventoryCount)) * store.reputation
    }

    private func policyBuyerFactor(_ policy: StoreMarketPolicy, category: VehicleCategory?) -> Double {
        guard let category, !policy.priorityCategories.isEmpty else { return 1 }
        return policy.priorityCategories.contains(category) ? 1.20 : 0.90
    }

    private func policyOriginFactor(_ policy: StoreMarketPolicy, origin: VehicleOrigin?) -> Double {
        guard let origin, !policy.priorityOrigins.isEmpty else { return 1 }
        return policy.priorityOrigins.contains(origin) ? 1.20 : 0.90
    }

    func effectiveCategoryExpertise(for store: Store, category: VehicleCategory) -> Double {
        min(100, store.expertise.category(category) + companyExpertise.category(category) * 0.25)
    }

    func effectivePurposeExpertise(for store: Store, purpose: CustomerPurpose) -> Double {
        min(100, store.expertise.purpose(purpose) + companyExpertise.purpose(purpose) * 0.25)
    }

    func effectiveSourceExpertise(for store: Store, source: ProcurementSource) -> Double {
        min(100, store.expertise.source(source) + companyExpertise.source(source) * 0.25)
    }

    private func brandProjectKind(for productKind: MarketProductKind) -> WorkshopProjectKind {
        switch productKind {
        case .standard: .basicService
        case .repaired: .repair
        case .refurbished, .collector: .refurbishment
        case .camper: .camperConversion
        case .workCargo: .workConversion
        case .outdoor: .outdoorConversion
        case .sportTuned: .streetTuning
        case .welfare: .wheelchairConversion
        case .mobileShop: .kitchenCarConversion
        }
    }

    func specialtyBrandProfile(for store: Store, productKind: MarketProductKind) -> SpecialtyBrandProfile {
        let projectKind = brandProjectKind(for: productKind)
        let expertise = min(100, store.expertise.project(projectKind) + companyExpertise.project(projectKind) * 0.25)
        let recentSales = store.segmentRecords.reduce(0) { total, item in
            guard item.key.productKind == productKind else { return total }
            return total + item.value
                .filter { $0.turn >= max(0, turn - 11) }
                .reduce(0) { $0 + $1.playerSales }
        }
        let reputationPoints = min(15, max(0, (store.reputation - 0.40) / 0.85 * 15))
        let advertisingPoints = min(15, Double(store.advertising) / 20)
        let reviewConfidence = min(1, Double(store.reviewCount) / 12)
        let reviewPoints = Double(store.averageReviewScore ?? 50) / 100 * reviewConfidence * 10
        let salesPoints = min(25, Double(recentSales) * 2.5)
        let recognition = min(
            100,
            max(0, Int((expertise * 0.35 + salesPoints + reputationPoints + advertisingPoints + reviewPoints).rounded()))
        )
        let storeDistrict = plot(id: store.plotID)?.district
        let relevantCategories = Set(nicheCategories(for: productKind))
        let currentTrend = segmentTrends
            .filter {
                $0.kind.productKind == productKind
                    && (storeDistrict.map($0.districts.contains) ?? false)
                    && !$0.categories.isDisjoint(with: relevantCategories)
            }
            .map { $0.multiplier(at: turn) }
            .max() ?? 1
        let trendBonus = max(0, currentTrend - 1)
        let establishedRecognition = max(0, Double(recognition - 30) / 70)
        let firstMoverBonus = Int((trendBonus * establishedRecognition * 40).rounded())
        return SpecialtyBrandProfile(
            productKind: productKind,
            recognition: recognition,
            expertise: Int(expertise.rounded()),
            recentSales: recentSales,
            firstMoverBonusPercent: firstMoverBonus
        )
    }

    func specialtyBrandProfiles(for store: Store) -> [SpecialtyBrandProfile] {
        [.sportTuned, .welfare, .mobileShop, .camper, .outdoor, .collector, .workCargo, .refurbished]
            .map { specialtyBrandProfile(for: store, productKind: $0) }
            .sorted {
                $0.recognition == $1.recognition
                    ? $0.productKind.rawValue < $1.productKind.rawValue
                    : $0.recognition > $1.recognition
            }
    }

    func specialtyCertificationTier(for store: Store, productKind: MarketProductKind) -> Int {
        guard store.certifiedSpecialties.contains(productKind),
              isSpecialtyCertificationActive(for: store, productKind: productKind) else { return 0 }
        let recognition = max(40, specialtyBrandProfile(for: store, productKind: productKind).recognition)
        if recognition >= 80 { return 3 }
        if recognition >= 60 { return 2 }
        return 1
    }

    private func isSpecialtyCertificationActive(for store: Store, productKind: MarketProductKind) -> Bool {
        let hasTechnician = store.employees.contains { $0.assignment == .service }
        switch productKind {
        case .sportTuned:
            return hasTechnician
                && store.facilities.contains(.customWorkshop)
                && store.marketPolicy.priorityCategories.contains(.sports)
                && store.marketPolicy.targetPurpose == .performance
        case .collector:
            return hasTechnician && store.facilities.contains(.serviceWorkshop)
        default:
            return false
        }
    }

    private func updateSpecialtyCertifications(notes: inout [String]) {
        for storeIndex in stores.indices where stores[storeIndex].isOperational {
            let store = stores[storeIndex]
            let hasTechnician = store.employees.contains { $0.assignment == .service }
            if !store.certifiedSpecialties.contains(.sportTuned) {
                let tuningExpertise = [
                    WorkshopProjectKind.streetTuning,
                    .driftTuning,
                    .circuitTuning
                ].reduce(0.0) {
                    $0 + store.expertise.project($1) + companyExpertise.project($1) * 0.25
                }
                let completedTuning = [
                    WorkshopProjectKind.streetTuning,
                    .driftTuning,
                    .circuitTuning
                ].reduce(0) { $0 + (store.completedProjects[$1] ?? 0) }
                let recognition = specialtyBrandProfile(for: store, productKind: .sportTuned).recognition
                if store.marketPolicy.priorityCategories.contains(.sports),
                   store.marketPolicy.targetPurpose == .performance,
                   store.facilities.contains(.customWorkshop),
                   hasTechnician,
                   tuningExpertise >= 20,
                   completedTuning >= 3,
                   (store.lifetimeProductSales[.sportTuned] ?? 0) >= 2,
                   recognition >= 40 {
                    stores[storeIndex].certifiedSpecialties.insert(.sportTuned)
                    notes.append("\(store.name)がスポーツ専門店として認定されました")
                    recordCityEvent(CityEvent(
                        turn: turn,
                        kind: .milestone,
                        title: "スポーツ専門店認定",
                        detail: "\(store.name)に地区外からの指名客・買取紹介・持ち込み改造が増えます",
                        district: plot(id: store.plotID)?.district,
                        plotID: store.plotID
                    ))
                }
            }

            if !store.certifiedSpecialties.contains(.collector) {
                let refurbishmentExpertise = store.expertise.project(.refurbishment)
                    + companyExpertise.project(.refurbishment) * 0.25
                let classicInventory = store.inventory
                    .filter(\.isRareClassic)
                    .reduce(0) { $0 + $1.count }
                let recognition = specialtyBrandProfile(for: store, productKind: .collector).recognition
                if store.facilities.contains(.serviceWorkshop),
                   hasTechnician,
                   refurbishmentExpertise >= 25,
                   classicInventory >= 2,
                   (store.completedProjects[.refurbishment] ?? 0) >= 1,
                   recognition >= 40 {
                    stores[storeIndex].certifiedSpecialties.insert(.collector)
                    notes.append("\(store.name)がクラシック専門店として認定されました")
                    recordCityEvent(CityEvent(
                        turn: turn,
                        kind: .milestone,
                        title: "クラシック専門店認定",
                        detail: "\(store.name)の希少車ネットワークが開通し、広域から指名客が訪れます",
                        district: plot(id: store.plotID)?.district,
                        plotID: store.plotID
                    ))
                }
            }
        }
    }

    private func certifiedSpecialtyCloseBonus(for store: Store, batch: InventoryBatch) -> Double {
        let productKind = marketProductKind(for: batch)
        let tier = specialtyCertificationTier(for: store, productKind: productKind)
        guard tier > 0 else { return 0 }
        if productKind == .collector {
            return [0, 0.07, 0.11, 0.15][tier]
        }
        if productKind == .sportTuned {
            return [0, 0.05, 0.08, 0.12][tier]
        }
        return 0
    }

    func storeRecognitionScore(for store: Store) -> Int {
        let reputation = min(45, max(0, (store.reputation - 0.40) / 0.85 * 45))
        let advertising = min(25, Double(store.advertising) / 16)
        let reviews = min(20, Double(store.reviewCount) * Double(store.averageReviewScore ?? 50) / 100)
        let national = min(10, max(0, (nationalBrandStrength - 0.48) / 0.97 * 10))
        return min(100, max(0, Int((reputation + advertising + reviews + national).rounded())))
    }

    func specialtyBrandAttractionMultiplier(for store: Store, key: MarketSegmentKey) -> Double {
        guard key.productKind.isNiche else { return 1 }
        let recognition = Double(specialtyBrandProfile(for: store, productKind: key.productKind).recognition) / 100
        let establishedRecognition = max(0, (recognition - 0.30) / 0.70)
        let boom = max(0, activeTrendMultiplier(for: key) - 1)
        return min(1.50, 1 + boom * establishedRecognition * 0.40)
    }

    func derivedBusinessName(for store: Store) -> String {
        let category = VehicleCategory.allCases.map { (effectiveCategoryExpertise(for: store, category: $0), "\($0.name)に強い店") }
        let purpose = CustomerPurpose.allCases.map { (effectivePurposeExpertise(for: store, purpose: $0), "\($0.name)に強い店") }
        let project = WorkshopProjectKind.allCases.map {
            (min(100, store.expertise.project($0) + companyExpertise.project($0) * 0.25), "\($0.name)に強い店")
        }
        let source = ProcurementSource.allCases.map {
            (min(100, store.expertise.source($0) + companyExpertise.source($0) * 0.25), "\($0.name)に強い店")
        }
        guard let best = (category + purpose + project + source).max(by: { $0.0 < $1.0 }), best.0 >= 15 else { return "総合中古車店" }
        return best.1
    }

    func regionalNicheLeaderKey(for store: Store) -> MarketSegmentKey? {
        guard let district = plot(id: store.plotID)?.district else { return nil }
        return store.segmentRecords.compactMap { key, records -> (MarketSegmentKey, Int)? in
            guard key.district == district, key.productKind.isNiche else { return nil }
            let ownSales = records.filter { $0.turn >= turn - 7 }.reduce(0) { $0 + $1.playerSales }
            guard ownSales >= 4 else { return nil }
            let otherStoreBest = stores.filter { $0.id != store.id }.map { other in
                (other.segmentRecords[key] ?? []).filter { $0.turn >= turn - 7 }.reduce(0) {
                    $0 + $1.playerSales
                }
            }.max() ?? 0
            let competitorBest = competitors.map { competitor in
                (competitor.segmentRecords[key] ?? []).filter { $0.turn >= turn - 7 }.reduce(0) {
                    $0 + $1.competitorSales
                }
            }.max() ?? 0
            guard ownSales > max(otherStoreBest, competitorBest) else { return nil }
            return (key, ownSales)
        }.max(by: { $0.1 < $1.1 })?.0
    }

    func regionalNicheLeaderLabel(for store: Store) -> String? {
        guard let key = regionalNicheLeaderKey(for: store) else { return nil }
        return "地域ニッチNo.1・\(key.productKind.name)"
    }

    private func facilityBuyerFactor(_ store: Store, category: VehicleCategory?, origin: VehicleOrigin? = nil, purpose: CustomerPurpose?) -> Double {
        var factor = 1.0
        if store.facilities.contains(.kidsSpace), purpose == .family {
            factor *= 1.18
        }
        if store.facilities.contains(.corporateDesk), [.corporate, .work].contains(purpose) {
            factor *= 1.22
        }
        if store.facilities.contains(.importLounge), origin == .imported {
            factor *= 1.18
        }
        return factor
    }

    private func facilitySellerFactor(_ store: Store, category: VehicleCategory, origin: VehicleOrigin? = nil) -> Double {
        var factor = store.facilities.contains(.serviceWorkshop) ? 1.24 : 1.0
        if store.facilities.contains(.corporateDesk),
           [.kei, .compact, .sedan, .minivan, .pickup].contains(category) {
            factor *= 1.42
        }
        if store.facilities.contains(.importLounge), origin == .imported {
            factor *= 1.18
        }
        return factor
    }

    func buyerAttractionFactor(for store: Store, category: VehicleCategory?, origin: VehicleOrigin? = nil, purpose: CustomerPurpose? = nil) -> Double {
        let expertise = category.map { 1 + effectiveCategoryExpertise(for: store, category: $0) * 0.0018 } ?? 1
        return policyBuyerFactor(store.marketPolicy, category: category)
            * policyOriginFactor(store.marketPolicy, origin: origin)
            * facilityBuyerFactor(store, category: category, origin: origin, purpose: purpose) * expertise
    }

    /// 月額広告0〜500で集客係数0.80〜1.60。広告投資の差が来客へ明確に表れる。
    func advertisingAttractionFactor(_ advertising: Int) -> Double {
        0.80 + 0.80 * min(1, max(0, Double(advertising) / 500))
    }

    func sellerAttractionFactor(for store: Store, category: VehicleCategory, origin: VehicleOrigin? = nil) -> Double {
        let policyFactor: Double
        if store.marketPolicy.priorityCategories.isEmpty {
            policyFactor = 1
        } else {
            policyFactor = store.marketPolicy.priorityCategories.contains(category) ? 1.75 : 0.35
        }
        return policyFactor * policyOriginFactor(store.marketPolicy, origin: origin)
            * facilitySellerFactor(store, category: category, origin: origin)
            * (1 + effectiveCategoryExpertise(for: store, category: category) * 0.0015)
    }

    func procurementLotSize(for store: Store, category: VehicleCategory, seed: Int) -> Int {
        let isCorporateFleet = store.marketPolicy.targetPurpose == .corporate
            && store.facilities.contains(.corporateDesk)
            && [.kei, .compact, .sedan, .minivan, .pickup].contains(category)
        return isCorporateFleet ? 2 + abs(seed % 3) : 1
    }

    private func facilityMarketFactor(_ store: Store) -> Double {
        1 + min(0.24, Double(store.facilities.count) * 0.06)
            + min(0.20, Double(store.loyalCustomers) * 0.004)
    }

    private func facilityCloseAdjustment(store: Store, category: VehicleCategory, origin: VehicleOrigin? = nil, purpose: CustomerPurpose? = nil) -> Double {
        var adjustment = 0.0
        if store.facilities.contains(.kidsSpace), purpose == .family {
            adjustment += 0.08
        }
        if store.facilities.contains(.corporateDesk), [.corporate, .work].contains(purpose) {
            adjustment += 0.07
        }
        if store.facilities.contains(.importLounge), origin == .imported {
            adjustment += 0.07
        }
        return adjustment
    }

    func facilitySalesCloseBonus(
        for store: Store,
        category: VehicleCategory,
        origin: VehicleOrigin? = nil,
        purpose: CustomerPurpose
    ) -> Double {
        facilityCloseAdjustment(store: store, category: category, origin: origin, purpose: purpose)
    }

    private func loyalCustomerGain(store: Store, category: VehicleCategory) -> Int {
        let facilityMatches = facilityCloseAdjustment(store: store, category: category) > 0
        return store.marketPolicy.priorityCategories.contains(category) && facilityMatches ? 2 : 1
    }

    private func deterministicVariation(seed: Int) -> Double {
        let value = abs((seed &* 1_103_515_245 &+ 12_345) % 100)
        return 0.88 + Double(value) / 420.0
    }

    private func transactionRoll(seed: Int) -> Double {
        let value = abs((seed &* 1_664_525 &+ 1_013_904_223) % 10_000)
        return Double(value) / 10_000.0
    }

    private func weeklyMarketShock(seed: Int) -> Double {
        let roll = transactionRoll(seed: seed)
        if roll < 0.06 { return 0.08 }
        if roll < 0.18 { return 0.35 }
        if roll > 0.92 { return 1.80 }
        return 0.62 + roll * 0.80
    }

    private func updateMarketConditions(notes: inout [String]) {
        let previousGasoline = gasolinePrice
        let previousNikkei = nikkeiAverage
        let previousDemand = marketDemandIndex

        refreshMarketTrendTargetsIfNeeded()
        triggerMarketShockIfNeeded(notes: &notes)

        let gasolineDesiredStep = min(1.8, max(-1.8, (gasolineTrendTarget - gasolinePrice) / 18))
        gasolineMomentum = gasolineMomentum * 0.84 + gasolineDesiredStep * 0.16
        let gasolineNoise = (transactionRoll(seed: turn * 227 + 91) - 0.5) * 0.6

        let nikkeiDesiredStep = min(2_500.0, max(-2_500.0, (nikkeiTrendTarget - nikkeiAverage) / 20))
        nikkeiMomentum = nikkeiMomentum * 0.85 + nikkeiDesiredStep * 0.15
        let nikkeiNoise = (transactionRoll(seed: turn * 211 + 73) - 0.5) * 120

        let demandDesiredStep = min(0.012, max(-0.012, (demandTrendTarget - marketDemandIndex) / 18))
        demandMomentum = demandMomentum * 0.86 + demandDesiredStep * 0.14
        let demandNoise = (transactionRoll(seed: turn * 193 + 47) - 0.5) * 0.0012

        let gasolineShock = activeMarketShocks.reduce(0.0) { $0 + $1.kind.gasolineWeeklyChange }
        let nikkeiShock = activeMarketShocks.reduce(0.0) { $0 + $1.kind.nikkeiWeeklyChange }
        let demandShock = activeMarketShocks.reduce(0.0) { $0 + $1.kind.demandWeeklyChange }

        gasolinePrice = min(Self.gasolineRange.upperBound, max(Self.gasolineRange.lowerBound, gasolinePrice + gasolineMomentum + gasolineNoise + gasolineShock))
        nikkeiAverage = min(Self.nikkeiRange.upperBound, max(Self.nikkeiRange.lowerBound, nikkeiAverage + nikkeiMomentum + nikkeiNoise + nikkeiShock))
        let nikkeiReturn = previousNikkei > 0 ? (nikkeiAverage - previousNikkei) / previousNikkei : 0
        classicMarketIndex = min(
            4.0,
            max(0.85, classicMarketIndex * Self.classicMarketChangeFactor(forNikkeiReturn: nikkeiReturn))
        )
        marketDemandIndex = min(1.35, max(0.65, marketDemandIndex + demandMomentum + demandNoise + demandShock))

        if gasolinePrice == Self.gasolineRange.lowerBound || gasolinePrice == Self.gasolineRange.upperBound { gasolineMomentum *= 0.3 }
        if nikkeiAverage == Self.nikkeiRange.lowerBound || nikkeiAverage == Self.nikkeiRange.upperBound { nikkeiMomentum *= 0.3 }
        if marketDemandIndex == 0.65 || marketDemandIndex == 1.35 { demandMomentum *= 0.3 }

        activeMarketShocks = activeMarketShocks.compactMap { shock in
            var updated = shock
            updated.remainingWeeks -= 1
            return updated.remainingWeeks > 0 ? updated : nil
        }

        let gasolineChange = gasolinePrice - previousGasoline
        let nikkeiChange = nikkeiAverage - previousNikkei
        let demandChange = marketDemandIndex - previousDemand
        if abs(gasolineChange) >= 3 {
            notes.append("ガソリン価格が前週から\(signedYen(gasolineChange))/L動き、\(gasolinePricePerLiter)円/Lになりました")
        }
        if abs(nikkeiChange) >= 2_500 {
            notes.append("日経平均が前週から\(signedYen(nikkeiChange))動き、\(nikkeiAverageYen.formatted())円になりました")
        }
        if abs(demandChange) >= 0.03 {
            notes.append("中古車需要は前週比\(String(format: "%+.0f", demandChange * 100))ポイント、現在\(marketDemandPercentage)%です")
        }

        if turn.isMultiple(of: 12), activeMarketShocks.isEmpty {
            let direction = gasolineChange >= 0 ? "上昇" : "下落"
            let detail = "ガソリン\(gasolinePricePerLiter)円/L・日経平均\(nikkeiAverageYen.formatted())円・中古車需要\(marketDemandPercentage)%"
            recordCityEvent(CityEvent(turn: turn + 1, kind: .fuelPrice, title: "市場トレンド：燃料価格が\(direction)", detail: detail, isPositive: gasolinePrice <= Self.gasolineBaseline))
        }
    }

    static func classicMarketChangeFactor(forNikkeiReturn change: Double) -> Double {
        1 + change * (change >= 0 ? 1.8 : 0.2)
    }

    func competingInventory(for key: MarketSegmentKey) -> Int {
        competitors.reduce(0) { total, competitor in
            total + competitor.branches.reduce(0) { branchTotal, branch in
                guard plot(id: branch.plotID)?.district == key.district else { return branchTotal }
                return branchTotal + branch.inventory.filter {
                    $0.category == key.category
                        && marketProductMatches(actual: $0.marketProductKind, desired: key.productKind)
                }.reduce(0) { $0 + $1.count }
            }
        }
    }

    private func finalizeSegmentWeek(notes: inout [String]) {
        let keys = Set(segmentMarkets.keys).union(openSegmentWeek.keys)
        for key in keys {
            var state = segmentMarkets[key] ?? SegmentMarketState()
            let record = openSegmentWeek[key] ?? SegmentWeekRecord(turn: turn)
            state.append(record)
            if record.demand > 0, competingInventory(for: key) == 0, record.unmetDemand > 0 {
                state.blueOceanWeeks += 1
            } else {
                state.blueOceanWeeks = max(0, state.blueOceanWeeks - 1)
            }
            segmentMarkets[key] = state
        }
        if let strongest = openSegmentWeek
            .filter({ $0.value.demand > 0 && $0.key.productKind.isNiche })
            .max(by: { $0.value.unmetDemand < $1.value.unmetDemand }),
           strongest.value.unmetDemand > 0 {
            notes.append("未充足市場：\(strongest.key.name)で\(strongest.value.unmetDemand)人の需要を取り逃しました")
        }
    }

    private func trendConfiguration(
        for kind: SegmentTrendKind
    ) -> (districts: Set<DistrictKind>, categories: Set<VehicleCategory>) {
        switch kind {
        case .valueRebuild:
            return (Set(DistrictKind.allCases), Set(VehicleCategory.allCases))
        case .logistics:
            return ([.industrial, .highway], [.minivan, .pickup])
        case .outdoorBoom:
            return ([.suburb, .highway], [.suv, .pickup, .minivan])
        case .campingBoom:
            return ([.suburb, .highway], [.minivan])
        case .luxuryBoom:
            return ([.downtown, .emerging], [.sedan, .suv, .sports])
        case .collectorBoom:
            return ([.downtown, .emerging], Set(VehicleCatalog.rareClassics.map(\.category)))
        case .motorsportBoom:
            return (Set(DistrictKind.allCases), [.sports])
        case .welfareDemand:
            return (Set(DistrictKind.allCases), [.kei, .compact, .minivan])
        case .mobileBusinessBoom:
            return ([.downtown, .station, .industrial, .highway], [.minivan, .pickup])
        }
    }

    private func updateSegmentTrends(at resolvingTurn: Int, notes: inout [String]) {
        let ending = segmentTrends.filter { $0.endTurn == resolvingTurn }
        for trend in ending {
            notes.append("市場トレンド終了：\(trend.kind.name)")
        }
        segmentTrends.removeAll { $0.endTurn <= resolvingTurn }
        if segmentTrends.isEmpty {
            appendSegmentTrend(startTurn: 8)
        }
        for trend in segmentTrends where trend.startTurn == resolvingTurn {
            notes.append("市場トレンド開始：\(trend.kind.name)")
        }
        guard !segmentTrends.contains(where: { $0.startTurn > resolvingTurn }),
              let latestStart = segmentTrends.map(\.startTurn).max(),
              latestStart <= resolvingTurn else { return }
        let interval = 6 + Int(
            transactionRoll(seed: simulationSeed &+ latestStart &* 7_919) * 5
        )
        var nextStart = latestStart + interval
        let overlapping = segmentTrends.filter {
            $0.startTurn <= nextStart && $0.endTurn > nextStart
        }
        if overlapping.count >= 4, let earliestEnd = overlapping.map(\.endTurn).min() {
            nextStart = max(nextStart, earliestEnd)
        }
        appendSegmentTrend(startTurn: nextStart)
    }

    private func appendSegmentTrend(startTurn: Int) {
        let unavailableKinds = Set(segmentTrends.filter {
            $0.startTurn <= startTurn && $0.endTurn > startTurn
        }.map(\.kind))
        let kinds = SegmentTrendKind.allCases
            .filter { !unavailableKinds.contains($0) }
        guard !kinds.isEmpty else { return }
        let selection = min(
            kinds.count - 1,
            Int(transactionRoll(seed: simulationSeed &+ startTurn &* 8_111 + 31) * Double(kinds.count))
        )
        let kind = kinds[selection]
        let configuration = trendConfiguration(for: kind)
        let peakRange: ClosedRange<Double> = switch kind {
        case .valueRebuild: 2.0...2.8
        case .logistics, .outdoorBoom: 2.4...3.4
        case .campingBoom: 3.0...4.0
        case .luxuryBoom, .collectorBoom: 2.2...3.2
        case .motorsportBoom: 2.5...3.8
        case .welfareDemand: 1.8...2.6
        case .mobileBusinessBoom: 2.2...3.2
        }
        let peakMultiplier = peakRange.lowerBound
            + transactionRoll(seed: simulationSeed &+ startTurn &* 8_261 + 59)
            * (peakRange.upperBound - peakRange.lowerBound)
        segmentTrends.append(SegmentTrend(
            kind: kind,
            districts: configuration.districts,
            categories: configuration.categories,
            startTurn: startTurn,
            rampWeeks: 6,
            peakWeeks: 12,
            decayWeeks: 6,
            peakMultiplier: peakMultiplier
        ))
    }

    private func refreshMarketTrendTargetsIfNeeded() {
        if turn.isMultiple(of: 16) {
            gasolineTrendTarget = Self.gasolineRange.lowerBound
                + transactionRoll(seed: turn * 271 + 113) * (Self.gasolineRange.upperBound - Self.gasolineRange.lowerBound)
            demandTrendTarget = 0.78 + transactionRoll(seed: turn * 313 + 157) * 0.44
        }
        if turn.isMultiple(of: 20) {
            nikkeiTrendTarget = Self.nikkeiRange.lowerBound
                + transactionRoll(seed: turn * 307 + 139) * (Self.nikkeiRange.upperBound - Self.nikkeiRange.lowerBound)
        }
    }

    private struct ProjectedMarketState {
        let gasoline: Double
        let nikkei: Double
        let demand: Double
    }

    private func projectedMarketState(weeks: Int) -> ProjectedMarketState {
        var projectedGasoline = gasolinePrice
        var projectedNikkei = nikkeiAverage
        var projectedDemand = marketDemandIndex
        var gasTarget = gasolineTrendTarget
        var stockTarget = nikkeiTrendTarget
        var demandTarget = demandTrendTarget
        var gasMomentum = gasolineMomentum
        var stockMomentum = nikkeiMomentum
        var projectedDemandMomentum = demandMomentum
        var shocks = activeMarketShocks

        for offset in 0..<max(1, weeks) {
            let projectedTurn = turn + offset
            if projectedTurn.isMultiple(of: 16) {
                gasTarget = Self.gasolineRange.lowerBound
                    + transactionRoll(seed: projectedTurn * 271 + 113) * (Self.gasolineRange.upperBound - Self.gasolineRange.lowerBound)
                demandTarget = 0.78 + transactionRoll(seed: projectedTurn * 313 + 157) * 0.44
            }
            if projectedTurn.isMultiple(of: 20) {
                stockTarget = Self.nikkeiRange.lowerBound
                    + transactionRoll(seed: projectedTurn * 307 + 139) * (Self.nikkeiRange.upperBound - Self.nikkeiRange.lowerBound)
            }
            if shocks.count < 2,
               let kind = scheduledMarketShockKind(at: projectedTurn),
               !shocks.contains(where: { $0.kind == kind }) {
                shocks.append(ActiveMarketShock(kind: kind))
            }

            let gasolineDesiredStep = min(1.8, max(-1.8, (gasTarget - projectedGasoline) / 18))
            gasMomentum = gasMomentum * 0.84 + gasolineDesiredStep * 0.16
            let gasolineNoise = (transactionRoll(seed: projectedTurn * 227 + 91) - 0.5) * 0.6
            let nikkeiDesiredStep = min(2_500.0, max(-2_500.0, (stockTarget - projectedNikkei) / 20))
            stockMomentum = stockMomentum * 0.85 + nikkeiDesiredStep * 0.15
            let nikkeiNoise = (transactionRoll(seed: projectedTurn * 211 + 73) - 0.5) * 120
            let demandDesiredStep = min(0.012, max(-0.012, (demandTarget - projectedDemand) / 18))
            projectedDemandMomentum = projectedDemandMomentum * 0.86 + demandDesiredStep * 0.14
            let demandNoise = (transactionRoll(seed: projectedTurn * 193 + 47) - 0.5) * 0.0012

            projectedGasoline = min(Self.gasolineRange.upperBound, max(Self.gasolineRange.lowerBound,
                projectedGasoline + gasMomentum + gasolineNoise + shocks.reduce(0) { $0 + $1.kind.gasolineWeeklyChange }))
            projectedNikkei = min(Self.nikkeiRange.upperBound, max(Self.nikkeiRange.lowerBound,
                projectedNikkei + stockMomentum + nikkeiNoise + shocks.reduce(0) { $0 + $1.kind.nikkeiWeeklyChange }))
            projectedDemand = min(1.35, max(0.65,
                projectedDemand + projectedDemandMomentum + demandNoise + shocks.reduce(0) { $0 + $1.kind.demandWeeklyChange }))
            shocks = shocks.compactMap { shock in
                var updated = shock
                updated.remainingWeeks -= 1
                return updated.remainingWeeks > 0 ? updated : nil
            }
        }
        return ProjectedMarketState(gasoline: projectedGasoline, nikkei: projectedNikkei, demand: projectedDemand)
    }

    private func upcomingMarketShock(within weeks: Int) -> MarketShockKind? {
        for offset in 0..<max(1, weeks) {
            if let kind = scheduledMarketShockKind(at: turn + offset),
               !activeMarketShocks.contains(where: { $0.kind == kind }) {
                return kind
            }
        }
        return nil
    }

    private func scheduledMarketShockKind(at projectedTurn: Int) -> MarketShockKind? {
        guard projectedTurn >= 4 else { return nil }
        let eventRoll = transactionRoll(seed: projectedTurn * 359 + 181)
        if eventRoll < 0.010 {
            let fuelEvents: [MarketShockKind] = [.war, .oilDemandSurge, .oilProductionHalt]
            let selection = Int(transactionRoll(seed: projectedTurn * 367 + 191) * Double(fuelEvents.count))
            return fuelEvents[min(fuelEvents.count - 1, selection)]
        }
        if eventRoll > 0.993 {
            return transactionRoll(seed: projectedTurn * 373 + 197) < 0.55 ? .economicBoom : .financialCrisis
        }
        return nil
    }

    private func trendWord(_ difference: Double, threshold: Double) -> String {
        if difference >= threshold { return "上昇基調" }
        if difference <= -threshold { return "下落基調" }
        return "横ばい"
    }

    private func economicIndex(for nikkei: Double) -> Double {
        if nikkei <= Self.nikkeiBaseline {
            return 0.72 + (nikkei - Self.nikkeiRange.lowerBound) / (Self.nikkeiBaseline - Self.nikkeiRange.lowerBound) * 0.28
        }
        return 1.0 + (nikkei - Self.nikkeiBaseline) / (Self.nikkeiRange.upperBound - Self.nikkeiBaseline) * 0.28
    }

    private func projectedVehiclePriceFactor(powertrain: VehiclePowertrain, projection: ProjectedMarketState) -> Double {
        let demandEffect = (projection.demand - marketDemandIndex) * 0.30
        let economyEffect = (economicIndex(for: projection.nikkei) - economicIndex) * 0.22
        let fuelChange = (projection.gasoline - gasolinePrice) / Self.gasolineBaseline
        let fuelEffect: Double
        switch powertrain {
        case .electric: fuelEffect = fuelChange * 0.22
        case .hybrid: fuelEffect = fuelChange * 0.13
        case .gasoline: fuelEffect = -fuelChange * 0.10
        case .diesel: fuelEffect = -fuelChange * 0.05
        }
        return min(1.18, max(0.82, 1 + demandEffect + economyEffect + fuelEffect))
    }

    private func triggerMarketShockIfNeeded(notes: inout [String]) {
        guard turn >= 4, activeMarketShocks.count < 2 else { return }
        let kind = scheduledMarketShockKind(at: turn)
        guard let kind, !activeMarketShocks.contains(where: { $0.kind == kind }) else { return }

        activeMarketShocks.append(ActiveMarketShock(kind: kind))
        let detail = "\(kind.detail)。影響は約\(kind.durationWeeks)週間続く見込みです"
        notes.append("市場イベント：\(kind.title)")
        recordCityEvent(CityEvent(turn: turn + 1, kind: kind.eventKind, title: kind.title, detail: detail, isPositive: kind.isPositive))
    }

    private func signedYen(_ value: Double) -> String {
        let amount = Int(value.rounded())
        return String(format: "%+d円", amount)
    }

    private func makeCauses(demand: Double, concept: Double, conceptName: String, marketing: Double, competition: Double, inventory: Int) -> [ResultCause] {
        var causes = [ResultCause(demand >= 1 ? "地区需要との相性" : "需要とのミスマッチ", (demand - 1) * 4.2)]
        causes.append(ResultCause("\(conceptName)と立地", (concept - 1) * 4.8))
        causes.append(ResultCause("広告と認知度", (marketing - 0.9) * 5))
        causes.append(ResultCause("競合店舗の影響", (competition - 1) * 4.5))
        if inventory < 6 { causes.append(ResultCause("在庫不足", -1.4)) }
        return causes
    }

    private func unlockTutorial(notes: inout [String]) {
        switch turn {
        case 0: unlockedFeatures.insert("整備"); notes.append("整備品質が解放されました")
        case 1: unlockedFeatures.insert("広告"); notes.append("地区広告が解放されました")
        case 2: unlockedFeatures.insert("人員配置"); notes.append("採用と人員配置が解放されました")
        case 3: unlockedFeatures.insert("財務"); notes.append("PL・BS・CFの詳細が解放されました")
        default: break
        }
    }

    private func recordCareerProgress(year: Int, sales: Int, revenue: Int, operatingProfit: Int) {
        careerStatistics.totalSales += sales
        careerStatistics.totalRevenue += revenue
        careerStatistics.totalOperatingProfit += operatingProfit
        careerStatistics.bestWeeklySales = max(careerStatistics.bestWeeklySales, sales)
        if operatingProfit > 0 {
            careerStatistics.profitableWeeks += 1
        }
        careerStatistics.salesByYear[year, default: 0] += sales
    }

    private func evaluateMilestones(notes: inout [String]) -> [BusinessMilestoneID] {
        let achieved = milestoneStatuses.compactMap { status -> BusinessMilestoneID? in
            guard !status.isCompleted, status.current >= status.target else { return nil }
            return status.id
        }

        for milestone in achieved {
            careerStatistics.completedMilestones.insert(milestone)
            switch milestone {
            case .salesFoundation:
                cash += 250
                finance.financingCF += 250
            case .annualSales100:
                break
            case .districtLeader:
                for index in stores.indices where leadingDistricts.contains(where: {
                    plot(id: stores[index].plotID)?.district == $0
                }) {
                    stores[index].reputation = min(1.25, stores[index].reputation + 0.05)
                }
                nationalBrandStrength = min(1.45, nationalBrandStrength + 0.05)
            case .nationalExpansion:
                unlockedFeatures.insert("全国展開")
            case .lifetimeSales500:
                nationalBrandStrength = min(1.45, nationalBrandStrength + 0.10)
                for index in stores.indices {
                    stores[index].reputation = min(1.25, stores[index].reputation + 0.03)
                }
            }

            let event = CityEvent(
                turn: turn,
                kind: .milestone,
                title: "目標達成：\(milestone.title)",
                detail: "\(milestone.detail)。報酬：\(milestone.reward)",
                isPositive: true
            )
            recordCityEvent(event)
            notes.append("\(event.title)（\(milestone.reward)）")
        }
        return achieved
    }

    private func simulateCompetitors(notes: inout [String]) {
        progressPriceWars(notes: &notes)
        for index in competitors.indices {
            progressCompetitorProductization(competitorIndex: index, notes: &notes)
            let pressuredDistricts = Set(competitors[index].plotIDs.compactMap { plot(id: $0)?.district }).filter { district in
                let ownShare = stores
                    .filter { $0.isOperational && plot(id: $0.plotID)?.district == district }
                    .reduce(0.0) { $0 + marketShare(for: $1) }
                return ownShare > competitorMarketShare(competitors[index], in: district) + 0.08
            }.count
            let activeCampaigns = activePriceWars.filter { $0.competitorID == competitors[index].id }.count
            for branchIndex in competitors[index].branches.indices {
                let facilityCost = competitors[index].branches[branchIndex].facilities.reduce(0) { $0 + $1.monthlyCost } / 4
                let fixedCost = 35 + competitors[index].branches[branchIndex].advertising / 4 + facilityCost + activeCampaigns * 25
                competitors[index].cash -= fixedCost
                competitors[index].branches[branchIndex].lastRevenue = competitors[index].branches[branchIndex].currentRevenue
                competitors[index].branches[branchIndex].lastProfit = competitors[index].branches[branchIndex].currentProfit - fixedCost
                competitors[index].branches[branchIndex].currentRevenue = 0
                competitors[index].branches[branchIndex].currentProfit = 0
                for bucketIndex in competitors[index].branches[branchIndex].inventory.indices {
                    competitors[index].branches[branchIndex].inventory[bucketIndex].averageAgeWeeks += 1
                }
            }
            let strengthChange = pressuredDistricts > 0 ? -Double(pressuredDistricts) * 0.003 : 0.0005
            competitors[index].strength = min(1.28, max(0.72, competitors[index].strength + strengthChange))
            updateCompetitorSegmentResponse(competitorIndex: index, notes: &notes)
        }
        updateMarketEntrants(notes: &notes)

        if turn >= 40 && turn % 44 == 0 {
            let candidates = competitors.indices.flatMap { companyIndex in
                competitors[companyIndex].plotIDs.map { (companyIndex, $0) }
            }.filter { companyIndex, _ in
                !competitors[companyIndex].isMarketEntrant && competitors[companyIndex].plotIDs.count > 1
            }
            if let closing = candidates.min(by: { lhs, rhs in
                guard let left = plot(id: lhs.1), let right = plot(id: rhs.1) else { return false }
                return competitorPlotScore(company: competitors[lhs.0], plot: left) < competitorPlotScore(company: competitors[rhs.0], plot: right)
            }), let plotIndex = plots.firstIndex(where: { $0.id == closing.1 }) {
                let companyName = competitors[closing.0].name
                let closedPlot = plots[plotIndex]
                competitors[closing.0].plotIDs.removeAll { $0 == closing.1 }
                plots[plotIndex].occupant = .available
                let event = CityEvent(turn: turn + 1, kind: .competitorExit, title: "\(companyName)が閉店", detail: "採算悪化により\(closedPlot.district.shortName)地区から撤退。空き物件になりました", district: closedPlot.district, plotID: closedPlot.id, isPositive: true)
                recordCityEvent(event)
                notes.append(event.title)
                return
            }
        }

        guard turn > 0, turn % 32 == 0 else { return }
        let eligible = competitors.indices.filter { competitors[$0].plotIDs.count < 5 }
        guard let companyIndex = eligible.isEmpty ? nil : eligible[(turn / 32) % eligible.count] else { return }
        let occupied = Set(competitors.flatMap(\.plotIDs) + stores.map(\.plotID))
        let company = competitors[companyIndex]
        let candidates = plots.filter {
            !occupied.contains($0.id)
                && isAvailable($0.occupant)
                && $0.development == nil
                && $0.structure != .vacant
                && $0.price + StoreType.standard.buildCost <= company.cash
        }
        guard let candidate = candidates.max(by: {
            competitorPlotScore(company: company, plot: $0) < competitorPlotScore(company: company, plot: $1)
        }), let plotIndex = plots.firstIndex(where: { $0.id == candidate.id }) else { return }
        competitors[companyIndex].cash -= candidate.price + StoreType.standard.buildCost
        let expandingCompany = competitors[companyIndex]
        var newBranch = initialCompetitorBranch(plotID: candidate.id, competitor: expandingCompany)
        newBranch.inventory = []
        competitors[companyIndex].branches.append(newBranch)
        plots[plotIndex].occupant = .competitor(name: competitors[companyIndex].name)
        let event = CityEvent(turn: turn + 1, kind: .competitorEntry, title: "競合が新規出店", detail: "\(competitors[companyIndex].name)が\(candidate.district.shortName)地区へ参入しました", district: candidate.district, plotID: candidate.id, isPositive: false)
        recordCityEvent(event)
        notes.append(event.detail)
    }

    private func updateCompetitorSegmentResponse(competitorIndex: Int, notes: inout [String]) {
        guard competitors.indices.contains(competitorIndex) else { return }
        let branchDistricts = Set(competitors[competitorIndex].branches.compactMap { plot(id: $0.plotID)?.district })
        let candidateKeys = segmentMarkets.keys.filter {
            branchDistricts.contains($0.district) && $0.productKind.isNiche
        }.sorted { $0.id < $1.id }
        var bestWeeksByCategory: [VehicleCategory: Int] = [:]
        for key in candidateKeys {
            let recent = segmentMarkets[key]?.recentFourWeeks ?? []
            let ownRecent = (competitors[competitorIndex].segmentRecords[key] ?? []).filter {
                $0.turn >= turn - 3
            }
            let revenue = ownRecent.reduce(0) { $0 + $1.competitorRevenue }
            let cost = ownRecent.reduce(0) { $0 + $1.competitorCost }
            let grossProfit = revenue - cost
            let grossMargin = revenue > 0 ? Double(grossProfit) / Double(revenue) : segmentMarginRate(for: key.productKind)
            let averageUnmet = Double(recent.reduce(0) { $0 + $1.unmetDemand }) / Double(max(1, recent.count))
            let requiredCapital = Double(key.category.purchaseCost) * segmentCapitalMultiplier(for: key.productKind)
            let capitalFit = Double(max(0, competitors[competitorIndex].cash)) / max(1, requiredCapital)
            let trend = activeTrendMultiplier(for: key)
            let isLargeCompany = !competitors[competitorIndex].isMarketEntrant
            let profitableSignal = recent.count >= 4
                && grossMargin >= 0.12
                && averageUnmet >= (isLargeCompany ? 0.50 : 0.25)
                && capitalFit >= (isLargeCompany ? 0.75 : 0.35)
                && (isLargeCompany
                    ? grossProfit >= key.category.purchaseCost / 6 || trend >= 1.6
                    : averageUnmet >= 1 || competingInventory(for: key) == 0)
            let oldUnprofitable = competitors[competitorIndex].segmentUnprofitableWeeks[key] ?? 0
            let unprofitableWeeks = profitableSignal
                ? 0
                : (recent.count >= 4 ? oldUnprofitable + 1 : oldUnprofitable)
            competitors[competitorIndex].segmentUnprofitableWeeks[key] = unprofitableWeeks
            let oldWeeks = competitors[competitorIndex].segmentResponseWeeks[key] ?? 0
            let nextWeeks = profitableSignal ? oldWeeks + 1 : max(0, oldWeeks - 1)
            competitors[competitorIndex].segmentResponseWeeks[key] = nextWeeks
            bestWeeksByCategory[key.category] = max(bestWeeksByCategory[key.category] ?? 0, nextWeeks)
            if nextWeeks == 4 {
                notes.append("競合追随兆候：\(competitors[competitorIndex].name)が\(key.name)の実利益を検証しています")
            }
            if unprofitableWeeks == 12 {
                competitors[competitorIndex].segmentTargetShare[key] = max(
                    0,
                    (competitors[competitorIndex].segmentTargetShare[key] ?? 0) - 0.10
                )
                for branchIndex in competitors[competitorIndex].branches.indices
                where plot(id: competitors[competitorIndex].branches[branchIndex].plotID)?.district == key.district {
                    competitors[competitorIndex].branches[branchIndex].advertising = max(
                        20,
                        competitors[competitorIndex].branches[branchIndex].advertising - 10
                    )
                }
                notes.append("\(competitors[competitorIndex].name)は\(key.name)の12週不採算を受け、広告と目標在庫を縮小しました")
            }
            guard nextWeeks >= 8 else { continue }
            if nextWeeks == 8 || nextWeeks.isMultiple(of: 4) {
                let oldShare = competitors[competitorIndex].segmentTargetShare[key] ?? 0
                competitors[competitorIndex].segmentTargetShare[key] = min(0.65, oldShare + 0.10)
                for branchIndex in competitors[competitorIndex].branches.indices
                where plot(id: competitors[competitorIndex].branches[branchIndex].plotID)?.district == key.district {
                    competitors[competitorIndex].branches[branchIndex].advertising = min(
                        500,
                        competitors[competitorIndex].branches[branchIndex].advertising + 10
                    )
                    var policy = competitors[competitorIndex].branches[branchIndex].marketPolicy
                    policy.priorityCategories.insert(key.category)
                    policy.targetPurpose = key.purpose
                    policy.normalize()
                    competitors[competitorIndex].branches[branchIndex].marketPolicy = policy
                    startCompetitorProductization(
                        competitorIndex: competitorIndex,
                        branchIndex: branchIndex,
                        key: key
                    )
                }
            }
            if nextWeeks >= 12,
               competitors[competitorIndex].cash >= StoreFacility.customWorkshop.installationCost * 2 {
                let facility: StoreFacility = [.camper, .workCargo, .outdoor].contains(key.productKind)
                    ? .customWorkshop : .serviceWorkshop
                for branchIndex in competitors[competitorIndex].branches.indices
                where plot(id: competitors[competitorIndex].branches[branchIndex].plotID)?.district == key.district
                    && !competitors[competitorIndex].branches[branchIndex].facilities.contains(facility) {
                    competitors[competitorIndex].cash -= facility.installationCost
                    competitors[competitorIndex].branches[branchIndex].facilities.insert(facility)
                    break
                }
            }
        }

        for category in VehicleCategory.allCases {
            let next = bestWeeksByCategory[category] ?? 0
            competitors[competitorIndex].profitableSegmentWeeks[category] = next
            if next >= 8 {
                competitors[competitorIndex].targetInventoryShare[category] = min(
                    0.65,
                    max(competitors[competitorIndex].targetInventoryShare[category] ?? 0, 0.20)
                )
            } else if next == 0,
                      turn.isMultiple(of: 12),
                      let share = competitors[competitorIndex].targetInventoryShare[category],
                      share > 0 {
                competitors[competitorIndex].targetInventoryShare[category] = max(0, share - 0.10)
            }
        }

        let hasProfitableSegment = competitors[competitorIndex].segmentResponseWeeks.values.contains { $0 > 0 }
        if hasProfitableSegment {
            competitors[competitorIndex].unprofitableWeeks = 0
        } else {
            competitors[competitorIndex].unprofitableWeeks += 1
        }
    }

    private func competitorProductState(for kind: MarketProductKind) -> VehicleProductState {
        switch kind {
        case .standard: .serviced
        case .repaired: .repaired
        case .refurbished, .collector: .refurbished
        case .camper: .camper
        case .workCargo: .workCargo
        case .outdoor: .outdoor
        case .sportTuned: .sportStreet
        case .welfare: .welfareWheelchair
        case .mobileShop: .kitchenCar
        }
    }

    private func competitorOutsourcePartner(for kind: MarketProductKind) -> OutsourcePartnerKind {
        switch kind {
        case .standard, .repaired: .generalRepair
        case .workCargo, .outdoor, .welfare, .mobileShop: .fabrication
        case .refurbished, .camper, .collector, .sportTuned: .specialist
        }
    }

    private func competitorConversionCostRate(for kind: MarketProductKind) -> Double {
        switch kind {
        case .standard: 0.08
        case .repaired: 0.30
        case .refurbished: 0.45
        case .camper: 1.80
        case .workCargo: 0.22
        case .outdoor: 0.18
        case .collector: 0.70
        case .sportTuned: 0.38
        case .welfare: 0.40
        case .mobileShop: 0.60
        }
    }

    private func competitorHasFacility(
        branch: CompetitorBranch,
        for kind: MarketProductKind
    ) -> Bool {
        switch kind {
        case .camper, .workCargo, .outdoor, .sportTuned, .welfare, .mobileShop:
            branch.facilities.contains(.customWorkshop)
        case .standard, .repaired, .refurbished, .collector:
            branch.facilities.contains(.serviceWorkshop)
        }
    }

    private func startCompetitorProductization(
        competitorIndex: Int,
        branchIndex: Int,
        key: MarketSegmentKey
    ) {
        guard competitors.indices.contains(competitorIndex),
              competitors[competitorIndex].branches.indices.contains(branchIndex) else { return }
        let branch = competitors[competitorIndex].branches[branchIndex]
        let reservedCount = branch.productizationQueue.reduce(0) { $0 + $1.count }
        guard branch.inventoryCount + reservedCount < branch.capacity else { return }

        let partner = competitorOutsourcePartner(for: key.productKind)
        let hasFacility = competitorHasFacility(branch: branch, for: key.productKind)
        let responseWeeks = competitors[competitorIndex].segmentResponseWeeks[key] ?? 0
        let outsourced = !hasFacility || responseWeeks < 12
        if outsourced {
            let usedCapacity = competitors[competitorIndex].branches
                .flatMap(\.productizationQueue)
                .filter { $0.outsourcePartner == partner }
                .reduce(0) { $0 + $1.count }
            guard usedCapacity < partner.weeklyCapacity else { return }
        }

        let trend = activeTrendMultiplier(for: key)
        let matchingTrendStart = segmentTrends.first(where: { $0.affects(key) })?.startTurn
        let procurementTrendHasReachedMarket = matchingTrendStart.map { turn >= $0 + 2 } ?? false
        let delayedProcurementPremium = procurementTrendHasReachedMarket
            ? 1 + max(0, trend - 1) * 0.22
            : 1
        let baseCost = Int(Double(key.category.purchaseCost) * delayedProcurementPremium)
        let conversionBase = Double(baseCost) * competitorConversionCostRate(for: key.productKind)
        let requestedGrade = requestedSpecialtyGrade(
            for: key,
            seed: turn * 61_157 + competitorIndex * 307 + branchIndex * 43
        )
        let selectedGrade: SpecialtyProductGrade?
        if let requestedGrade {
            selectedGrade = SpecialtyProductGrade.allCases
                .filter { $0 <= requestedGrade }
                .sorted(by: >)
                .first(where: { grade in
                    let conversionCost = Int(conversionBase * grade.costMultiplier * (outsourced ? partner.costMultiplier : 1))
                    return competitors[competitorIndex].cash >= baseCost + conversionCost
                })
        } else {
            selectedGrade = nil
        }
        let conversionCost = Int(
            conversionBase
                * (selectedGrade?.costMultiplier ?? 1)
                * (outsourced ? partner.costMultiplier : 1)
        )
        let totalUnitCost = baseCost + conversionCost
        guard competitors[competitorIndex].cash >= totalUnitCost else { return }

        var baseWeeks: Int = switch key.productKind {
        case .standard: 1
        case .repaired: 2
        case .refurbished, .collector: 6
        case .camper: 10
        case .workCargo: 5
        case .outdoor: 4
        case .sportTuned: 7
        case .welfare: 8
        case .mobileShop: 10
        }
        if let selectedGrade {
            baseWeeks = key.productKind == .collector ? 1 : selectedGrade.rank + 2
        }
        competitors[competitorIndex].cash -= totalUnitCost
        competitors[competitorIndex].branches[branchIndex].productizationQueue.append(
            CompetitorProductizationOrder(
                category: key.category,
                purpose: key.purpose,
                productState: competitorProductState(for: key.productKind),
                marketProductKind: key.productKind,
                productGrade: selectedGrade,
                count: 1,
                unitCost: totalUnitCost,
                quality: outsourced ? (key.productKind == .collector ? 0.86 : 0.90) : (key.productKind == .collector ? 0.90 : 0.94),
                outsourced: outsourced,
                outsourcePartner: outsourced ? partner : nil,
                weeksRemaining: key.productKind.supportsGrades
                    ? min(key.productKind == .collector ? 1 : 4, max(1, baseWeeks + (outsourced ? partner.extraWeeks : 0)))
                    : max(1, baseWeeks + (outsourced ? partner.extraWeeks : 0))
            )
        )
    }

    private func progressCompetitorProductization(
        competitorIndex: Int,
        notes: inout [String]
    ) {
        guard competitors.indices.contains(competitorIndex) else { return }
        for branchIndex in competitors[competitorIndex].branches.indices {
            for orderIndex in competitors[competitorIndex].branches[branchIndex].productizationQueue.indices {
                competitors[competitorIndex].branches[branchIndex].productizationQueue[orderIndex].weeksRemaining -= 1
            }
            let completed = competitors[competitorIndex].branches[branchIndex].productizationQueue.filter {
                $0.weeksRemaining <= 0
            }
            competitors[competitorIndex].branches[branchIndex].productizationQueue.removeAll {
                $0.weeksRemaining <= 0
            }
            for order in completed {
                addCompetitorInventory(
                    competitorIndex: competitorIndex,
                    branchIndex: branchIndex,
                    category: order.category,
                    purpose: order.purpose,
                    count: order.count,
                    unitCost: order.unitCost,
                    quality: order.quality,
                    productState: order.productState,
                    marketProductKind: order.marketProductKind,
                    productGrade: order.productGrade
                )
                if order.marketProductKind.isNiche {
                    notes.append("\(competitors[competitorIndex].name)の\(order.marketProductKind.name)商品が完成しました")
                }
            }
        }
    }

    private func updateMarketEntrants(notes: inout [String]) {
        var exiting: [Int] = []
        for index in competitors.indices where competitors[index].isMarketEntrant {
            if competitors[index].cash < 0 {
                competitors[index].cashShortageWeeks += 1
            } else {
                competitors[index].cashShortageWeeks = 0
            }
            let weeklyProfit = competitors[index].branches.reduce(0) { $0 + $1.lastProfit }
            if weeklyProfit < 0 {
                competitors[index].unprofitableWeeks += 1
            } else {
                competitors[index].unprofitableWeeks = 0
            }
            if competitors[index].cashShortageWeeks >= 8 || competitors[index].unprofitableWeeks >= 12 {
                exiting.append(index)
            }
        }
        for index in exiting.sorted(by: >) {
            let company = competitors[index]
            for plotID in company.plotIDs {
                if let plotIndex = plots.firstIndex(where: { $0.id == plotID }) {
                    plots[plotIndex].occupant = .available
                }
            }
            competitors.remove(at: index)
            let event = CityEvent(
                turn: turn + 1,
                kind: .competitorExit,
                title: "\(company.name)が市場撤退",
                detail: "創業資金を使い切り、ニッチ市場から撤退しました",
                isPositive: true
            )
            recordCityEvent(event)
            notes.append(event.detail)
        }

        guard turn >= 8,
              turn.isMultiple(of: 4),
              competitors.filter(\.isMarketEntrant).count < 2 else { return }
        let candidates = segmentMarkets.compactMap { key, state -> MarketSegmentKey? in
            let recent = state.recentFourWeeks
            let averageUnmet = Double(recent.reduce(0) { $0 + $1.unmetDemand }) / Double(max(1, recent.count))
            guard key.productKind.isNiche,
                  state.blueOceanWeeks >= 8,
                  recent.count >= 4,
                  averageUnmet >= 1,
                  segmentMarginRate(for: key.productKind) >= 0.12,
                  competingInventory(for: key) == 0 else { return nil }
            return key
        }.sorted {
            let lhs = segmentMarkets[$0]?.recentFourWeeks.reduce(0) { $0 + $1.unmetDemand } ?? 0
            let rhs = segmentMarkets[$1]?.recentFourWeeks.reduce(0) { $0 + $1.unmetDemand } ?? 0
            return lhs == rhs ? $0.id < $1.id : lhs > rhs
        }
        guard let key = candidates.first else { return }
        let occupied = Set(competitors.flatMap(\.plotIDs) + stores.map(\.plotID))
        let availablePlots = plots.filter {
            $0.district == key.district
                && !occupied.contains($0.id)
                && isAvailable($0.occupant)
                && $0.development == nil
                && $0.structure != .vacant
        }
        guard let candidate = availablePlots.min(by: { $0.price < $1.price }),
              let plotIndex = plots.firstIndex(where: { $0.id == candidate.id }) else { return }

        let entrantNumber = competitors.filter(\.isMarketEntrant).count + 1
        let startupCapital = max(
            6_000,
            candidate.price + StoreType.standard.buildCost
                + Int(Double(key.category.purchaseCost) * segmentCapitalMultiplier(for: key.productKind))
                + 1_200
        )
        var entrant = Competitor(
            name: entrantNumber == 1 ? "ブルーウェーブ商会" : "ニッチモータース",
            strategy: "\(key.productKind.name)の専門参入",
            colorHex: entrantNumber == 1 ? "19A89D" : "D04D86",
            cash: startupCapital,
            plotIDs: [],
            strength: 0.78,
            category: key.category,
            salesAbility: 58,
            procurementAbility: 62,
            researchAbility: 72,
            serviceAbility: 55
        )
        entrant.cash -= candidate.price + StoreType.standard.buildCost
        entrant.isMarketEntrant = true
        entrant.segmentResponseWeeks[key] = 8
        entrant.branches = [
            CompetitorBranch(
                plotID: candidate.id,
                capacity: 16,
                inventory: [],
                priceIndex: 1.08,
                advertising: 55,
                reputation: 0.56,
                facilities: [],
                marketPolicy: StoreMarketPolicy(
                    priorityCategories: [key.category],
                    targetPurpose: key.purpose,
                    acceptedConditions: [.normal, .rough, .faulty]
                ),
                expertise: BusinessExpertise(),
                lastRevenue: 0,
                lastProfit: 0
            )
        ]
        competitors.append(entrant)
        plots[plotIndex].occupant = .competitor(name: entrant.name)
        startCompetitorProductization(
            competitorIndex: competitors.count - 1,
            branchIndex: 0,
            key: key
        )
        let event = CityEvent(
            turn: turn + 1,
            kind: .competitorEntry,
            title: "小規模競合が新規参入",
            detail: "\(entrant.name)が\(key.name)のブルーオーシャンへ参入しました",
            district: key.district,
            plotID: candidate.id,
            isPositive: false
        )
        recordCityEvent(event)
        notes.append(event.detail)
    }

    private func progressPriceWars(notes: inout [String]) {
        let resolvingTurn = turn + 1
        for challenge in priceWarChallenges where challenge.expiresTurn == resolvingTurn {
            let rivalName = competitorName(for: challenge.competitorID)
            let result: String
            let positive: Bool
            switch challenge.response {
            case .none:
                result = "対抗策を取らず、地域シェアと店舗評判に傷が残りました"
                positive = false
                for storeIndex in stores.indices where plot(id: stores[storeIndex].plotID)?.district == challenge.district {
                    stores[storeIndex].reputation = max(0.40, stores[storeIndex].reputation - 0.02)
                }
                if let competitorIndex = competitors.firstIndex(where: { $0.id == challenge.competitorID }) {
                    competitors[competitorIndex].strength = min(1.28, competitors[competitorIndex].strength + 0.025)
                }
            case .counterSale:
                result = "対抗セールで客足を奪い返し、競合の体力を削りました"
                positive = true
                if let competitorIndex = competitors.firstIndex(where: { $0.id == challenge.competitorID }) {
                    competitors[competitorIndex].cash -= 240
                    competitors[competitorIndex].strength = max(0.72, competitors[competitorIndex].strength - 0.025)
                }
            case .brandDefense:
                result = "価格を守ったまま顧客流出を抑え、ブランド優位を築きました"
                positive = true
                if let competitorIndex = competitors.firstIndex(where: { $0.id == challenge.competitorID }) {
                    competitors[competitorIndex].strength = max(0.72, competitors[competitorIndex].strength - 0.015)
                }
            }
            let event = CityEvent(
                turn: resolvingTurn,
                kind: .priceWar,
                title: "価格戦争が終結",
                detail: "\(challenge.district.shortName)地区の\(rivalName)との競争が終結。\(result)",
                district: challenge.district,
                isPositive: positive
            )
            recordCityEvent(event)
            notes.append(event.detail)
        }

        guard turn >= 12,
              turn.isMultiple(of: 24),
              !priceWarChallenges.contains(where: { $0.expiresTurn > turn }),
              !stores.isEmpty else { return }
        let playerDistricts = Set(stores.compactMap { store in
            store.isOperational ? plot(id: store.plotID)?.district : nil
        })
        let candidates = competitors.filter { competitor in
            competitor.plotIDs.contains { plotID in
                guard let district = plot(id: plotID)?.district else { return false }
                return playerDistricts.contains(district)
            }
        }
        guard !candidates.isEmpty else { return }
        let aggressor = candidates[(turn / 24) % candidates.count]
        let contestedDistricts = Set(aggressor.plotIDs.compactMap { plot(id: $0)?.district }).intersection(playerDistricts)
        guard let district = contestedDistricts.sorted(by: { $0.rawValue < $1.rawValue }).first else { return }
        let startTurn = resolvingTurn
        let challenge = PriceWarChallenge(
            competitorID: aggressor.id,
            district: district,
            startedTurn: startTurn,
            expiresTurn: startTurn + 4,
            intensity: min(1.20, max(0.85, aggressor.strength))
        )
        priceWarChallenges.append(challenge)
        priceWarChallenges.removeAll { $0.expiresTurn < resolvingTurn - 40 }
        let event = CityEvent(
            turn: resolvingTurn,
            kind: .priceWar,
            title: "競合が価格戦争を開始",
            detail: "\(aggressor.name)が\(district.shortName)地区で4週間の大幅値下げ。未対応では集客と成約率が低下します",
            district: district,
            isPositive: false
        )
        recordCityEvent(event)
        notes.append(event.detail)
    }

    private func competitorPlotScore(company: Competitor, plot: LandPlot) -> Double {
        let district = district(for: plot)
        let categoryDemand = district.demands[company.category] ?? 0.65
        let strategyFit: Double
        switch company.name {
        case "バリューオート":
            strategyFit = [.industrial, .highway].contains(plot.district) ? 1.35 : 0.9
        case "プレミアモータース":
            strategyFit = plot.district == .downtown ? 1.55 : (plot.district == .station ? 1.1 : 0.75)
        default:
            strategyFit = [.emerging, .suburb, .highway].contains(plot.district) ? 1.30 : 0.92
        }
        let affordability = max(0.55, 1.30 - Double(plot.price) / Double(max(1, company.cash)))
        return profitabilityScore(for: plot) * categoryDemand * strategyFit * affordability
    }

    private func updateLandValues(notes: inout [String]) {
        var largestChange: (plot: LandPlot, rate: Double)?
        for index in plots.indices {
            let d = district(for: plots[index])
            let weeklyGrowth = (d.growthRate - 1.0) / 52 + (deterministicVariation(seed: turn + plots[index].id) - 1) / 650
            plots[index].lastPriceChange = weeklyGrowth
            plots[index].price = max(1_200, Int(Double(plots[index].price) * (1 + weeklyGrowth)))
            plots[index].monthlyRent = max(8, Int(Double(plots[index].monthlyRent) * (1 + weeklyGrowth * 0.35)))
            if abs(weeklyGrowth) > abs(largestChange?.rate ?? 0) { largestChange = (plots[index], weeklyGrowth) }
        }
        if let change = largestChange, abs(change.rate) >= 0.002 {
            let direction = change.rate >= 0 ? "上昇" : "下落"
            recordCityEvent(CityEvent(turn: turn + 1, kind: .landPrice, title: "地価が\(direction)", detail: "\(change.plot.district.shortName)地区で前週比\(String(format: "%+.1f", change.rate * 100))%", district: change.plot.district, plotID: change.plot.id, isPositive: change.rate >= 0))
        }
    }

    private func simulateDistrictDynamics(notes: inout [String]) {
        for index in districts.indices {
            let annualGrowth = districts[index].growthRate - 1
            let noise = deterministicVariation(seed: turn * 31 + index * 9) - 1
            let populationRate = annualGrowth / 52 + noise * 0.0005
            districts[index].population = max(20_000, Int(Double(districts[index].population) * (1 + populationRate)))
            districts[index].trafficIndex = min(1.75, max(0.65, districts[index].trafficIndex * (1 + populationRate * 0.18 + noise * 0.001)))

            for category in VehicleCategory.allCases {
                let current = districts[index].demands[category] ?? 0.68
                let categoryShift = (deterministicVariation(seed: turn * 43 + index * 13 + categoryIndex(category)) - 1) * 0.004
                let nextDemand = min(1.75, max(0.38, current + categoryShift))
                districts[index].demands[category] = nextDemand

                // 持ち込み供給は地域需要を後追いする。完全一致にはせず、
                // 地域差と週ごとの品薄・だぶつきは残す。
                let currentSupply = districts[index].supplies[category] ?? 0.58
                let supplyNoise = (
                    deterministicVariation(
                        seed: turn * 47 + index * 17 + categoryIndex(category) * 3
                    ) - 1
                ) * 0.003
                let demandCorrection = (nextDemand - currentSupply) * 0.035
                districts[index].supplies[category] = min(
                    1.65,
                    max(0.34, currentSupply + demandCorrection + supplyNoise)
                )
            }
            let storesInDistrict = competitorCount(in: districts[index].kind) + stores.filter { plot(id: $0.plotID)?.district == districts[index].kind }.count
            districts[index].competition = min(1.75, max(0.42, 0.52 + Double(storesInDistrict) * 0.17 + districts[index].trafficIndex * 0.18))
        }

        if turn.isMultiple(of: 12), let hottest = districts.max(by: { $0.population < $1.population }) {
            let category = hottest.demands.max(by: { $0.value < $1.value })?.key ?? .compact
            recordCityEvent(CityEvent(turn: turn + 1, kind: .demand, title: "\(hottest.kind.shortName)地区の需要変化", detail: "人口\(hottest.population.formatted())人・\(category.name)需要が最も強い地域です", district: hottest.kind))
        }
    }

    private func progressDevelopments(notes: inout [String]) {
        for index in plots.indices where plots[index].development != nil {
            plots[index].development?.monthsRemaining -= 1
            guard let project = plots[index].development, project.monthsRemaining <= 0 else { continue }
            if let districtIndex = districts.firstIndex(where: { $0.kind == plots[index].district }) {
                districts[districtIndex].population += project.populationBoost
                districts[districtIndex].trafficIndex = min(1.8, districts[districtIndex].trafficIndex + project.trafficBoost)
                districts[districtIndex].growthRate = min(1.09, districts[districtIndex].growthRate + 0.006)
            }
            plots[index].growth += 0.06
            plots[index].visibility = min(1.2, plots[index].visibility + 0.05)
            let event = CityEvent(turn: turn + 1, kind: .development, title: "\(project.title)が完成", detail: "\(plots[index].district.shortName)地区の人口と交通量が増加しました", district: plots[index].district, plotID: plots[index].id)
            plots[index].development = nil
            recordCityEvent(event)
            notes.append(event.detail)
        }

        guard turn > 0, turn.isMultiple(of: 72), !plots.contains(where: { $0.development != nil }) else { return }
        let candidates = plots.indices.filter { isAvailable(plots[$0].occupant) }
        guard let index = candidates.max(by: { plots[$0].growth < plots[$1].growth }) else { return }
        plots[index].development = DevelopmentProject(title: "複合商業・住宅開発", monthsRemaining: 24, populationBoost: 3_600, trafficBoost: 0.08)
        let event = CityEvent(turn: turn + 1, kind: .development, title: "新しい開発計画", detail: "\(plots[index].district.shortName)地区で複合開発が始まります。完成まで24週間", district: plots[index].district, plotID: plots[index].id)
        recordCityEvent(event)
        notes.append(event.detail)
    }

    private func recordCityEvent(_ event: CityEvent) {
        cityEvents.insert(event, at: 0)
        if cityEvents.count > 24 { cityEvents.removeLast(cityEvents.count - 24) }
    }

    private func categoryIndex(_ category: VehicleCategory) -> Int {
        VehicleCategory.allCases.firstIndex(of: category) ?? 0
    }

    private func vehicleModelIfAvailable(
        for category: VehicleCategory,
        origin: VehicleOrigin? = nil,
        seed: Int
    ) -> VehicleCatalogEntry? {
        let candidates = VehicleCatalog.available(
            category: category,
            origin: origin,
            through: turn
        )
        guard !candidates.isEmpty else { return nil }
        let weighted = candidates.map { model -> (model: VehicleCatalogEntry, weight: Double) in
            let identifierSeed = model.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            let fashion = deterministicVariation(seed: (turn / 13) * 97 + identifierSeed)
            let newerGenerations = VehicleCatalog.releasedNewCars(through: turn).filter {
                $0.maker == model.maker && $0.category == model.category && $0.launchTurn > model.launchTurn
            }.count
            let replacement = max(0.68, pow(0.92, Double(newerGenerations)))
            let supply = pow(max(0.02, usedMarketSupplyFactor(for: model)), 0.78)
            let transition = powertrainDemandFactor(for: model, in: .suburb)
            let originAvailability = origin == nil && model.origin == .imported ? 0.28 : 1.0
            return (model, max(0.01, model.customerDemandIndex * fashion * replacement * supply * transition * originAvailability))
        }
        let total = weighted.reduce(0.0) { $0 + $1.weight }
        var cursor = transactionRoll(seed: seed) * total
        for item in weighted {
            cursor -= item.weight
            if cursor <= 0 { return item.model }
        }
        return weighted.last?.model
    }

    private func vehicleModel(
        for category: VehicleCategory,
        origin: VehicleOrigin? = nil,
        seed: Int
    ) -> VehicleCatalogEntry {
        if let model = vehicleModelIfAvailable(for: category, origin: origin, seed: seed) {
            return model
        }
        // Every category has a domestic or unfiltered base model. Explicitly
        // unavailable origin filters are handled by the caller before reaching here.
        return VehicleCatalog.available(category: category, through: turn).first!
    }

    private func launchYear(for model: VehicleCatalogEntry) -> Int {
        guard model.launchTurn > 0 else { return 2015 }
        return 2026 + model.launchTurn / 48
    }

    private func lastProductionYear(for model: VehicleCatalogEntry) -> Int {
        let nextLaunch = VehicleCatalog.all
            .filter { $0.maker == model.maker && $0.category == model.category && $0.launchTurn > model.launchTurn }
            .map(\.launchTurn)
            .min()
        let nominalEnd = nextLaunch.map { 2026 + $0 / 48 } ?? (launchYear(for: model) + 6)
        return min(year, nominalEnd)
    }

    private func usedVehicleProfile(for model: VehicleCatalogEntry, seed: Int, maximumAge: Int = 14) -> UsedVehicleProfile {
        if let years = model.classicProductionYears {
            let span = years.upperBound - years.lowerBound + 1
            let modelYear = years.lowerBound + Int(transactionRoll(seed: seed + 101) * Double(span)) % span
            let mileage = 45_000 + Int(transactionRoll(seed: seed + 103) * 145_001 / 1_000) * 1_000
            let qualityVariation = (transactionRoll(seed: seed + 109) - 0.5) * 0.16
            let quality = model.qualityBaseline - Double(mileage - 45_000) / 1_200_000.0 + qualityVariation
            return UsedVehicleProfile(
                modelYear: modelYear,
                mileage: mileage,
                quality: min(0.72, max(0.35, quality))
            )
        }
        if let years = model.neoClassicSportYears {
            let span = years.upperBound - years.lowerBound + 1
            let modelYear = years.lowerBound + Int(transactionRoll(seed: seed + 101) * Double(span)) % span
            let age = max(0, year - modelYear)
            let mileage = 55_000 + Int(transactionRoll(seed: seed + 103) * 155_001 / 1_000) * 1_000
            let partsRisk = Double(age) * 0.004 + Double(mileage) / 1_600_000
            let quality = model.qualityBaseline + 0.08 - partsRisk
                + (transactionRoll(seed: seed + 109) - 0.5) * 0.14
            return UsedVehicleProfile(
                modelYear: modelYear,
                mileage: mileage,
                quality: min(0.82, max(0.38, quality))
            )
        }
        let earliestYear = max(2015, max(launchYear(for: model), year - maximumAge))
        let latestYear = max(earliestYear, lastProductionYear(for: model))
        let span = max(0, latestYear - earliestYear)
        let yearRoll = pow(transactionRoll(seed: seed + 101), 1.35)
        let modelYear = latestYear - min(span, Int(yearRoll * Double(span + 1)))
        let age = max(0, year - modelYear)
        let annualMileage = 6_000 + Int(transactionRoll(seed: seed + 103) * 8_001)
        let partialYearMileage = 500 + Int(transactionRoll(seed: seed + 107) * Double(max(1, annualMileage - 500)))
        let rawMileage = age == 0 ? min(12_500, partialYearMileage) : age * annualMileage + partialYearMileage
        let mileage = max(500, Int((Double(rawMileage) / 500.0).rounded()) * 500)
        let qualityVariation = (transactionRoll(seed: seed + 109) - 0.5) * 0.10
        let quality = model.qualityBaseline + 0.10 - Double(age) * 0.018 - Double(mileage) / 800_000.0 + qualityVariation
        return UsedVehicleProfile(
            modelYear: modelYear,
            mileage: mileage,
            quality: min(0.94, max(0.48, quality))
        )
    }

    private func announceNewModels(notes: inout [String]) {
        for model in VehicleCatalog.all where model.launchTurn == turn {
            let detail = "\(model.maker)が\(model.powertrain.name)の新型 \(model.modelName) を発売。中古流通は約\(model.usedMarketDelayWeeks)週間後の見込みです"
            notes.append(detail)
            recordCityEvent(CityEvent(turn: turn, kind: .demand, title: "新型車が発売", detail: detail))
        }
        for model in VehicleCatalog.all where model.launchTurn > 0 && model.usedMarketTurn == turn {
            let detail = "\(model.fullName)の下取り・リースアップ車が中古市場へ流入し始めました。初期は台数が少なく相場が高めです"
            notes.append(detail)
            recordCityEvent(CityEvent(turn: turn, kind: .auction, title: "新型車の中古流通が開始", detail: detail))
        }
    }

    private func recalculateAssets() {
        finance.landAssets = stores.filter { $0.acquisition == .purchase }.reduce(0) { total, store in
            total + store.plotIDs.compactMap { plot(id: $0)?.price }.reduce(0, +)
        }
        finance.buildingAssets = stores.reduce(0) { $0 + $1.type.buildCost + $1.facilityInvestment }
            + regionalOperations.reduce(0) { $0 + $1.officeLevel * 2_400 + $1.franchiseStores * 1_100 + $1.acquiredStores * 4_200 }
        finance.inventoryAssets = inventoryAssetValue()
        finance.debt = debt
    }

    private func resolveCustomerClaims(at resolvingTurn: Int, notes: inout [String]) -> [UUID: Int] {
        let dueClaims = pendingCustomerClaims.filter { $0.dueTurn <= resolvingTurn }
        var costsByStore: [UUID: Int] = [:]
        for claim in dueClaims {
            costsByStore[claim.storeID, default: 0] += claim.compensationCost
            if let storeIndex = stores.firstIndex(where: { $0.id == claim.storeID }) {
                recordClaimReview(claim, storeIndex: storeIndex)
                let detail = "\(claim.vehicleName)の\(claim.issue.name)が販売後に判明。補償費\(claim.compensationCost.currency)を支払い、店舗評判が低下しました"
                notes.append("\(stores[storeIndex].name)：\(detail)")
                recordCityEvent(CityEvent(
                    turn: resolvingTurn,
                    kind: .customerClaim,
                    title: "販売後クレーム",
                    detail: detail,
                    district: plot(id: stores[storeIndex].plotID)?.district,
                    plotID: stores[storeIndex].plotID,
                    isPositive: false
                ))
            }
            pendingCustomerClaims.removeAll { $0.id == claim.id }
        }
        return costsByStore
    }

    private func progressEmployeeCareers(notes: inout [String]) {
        for storeIndex in stores.indices {
            for employeeIndex in stores[storeIndex].employees.indices {
                stores[storeIndex].employees[employeeIndex].tenureWeeks += 1
            }
            let departures = stores[storeIndex].employees.filter { employee in
                let risk = employeePoachingRisk(employee)
                guard risk > 0 else { return false }
                let nameSeed = employee.name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
                return transactionRoll(seed: (turn + 1) * 307 + stores[storeIndex].plotID * 41 + nameSeed) < risk
            }
            for employee in departures {
                stores[storeIndex].employees.removeAll { $0.id == employee.id }
                let detail = "\(employee.name)が競合店からの引き抜きに応じて退職しました。昇給で流出リスクを下げられます"
                notes.append("\(stores[storeIndex].name)：\(detail)")
                recordCityEvent(CityEvent(
                    turn: turn + 1,
                    kind: .staffPoaching,
                    title: "競合による人材引き抜き",
                    detail: detail,
                    district: plot(id: stores[storeIndex].plotID)?.district,
                    plotID: stores[storeIndex].plotID,
                    isPositive: false
                ))
            }
        }
    }

    private func progressWorkshopProjects(notes: inout [String]) {
        for storeIndex in stores.indices {
            var labor = stores[storeIndex].weeklyWorkshopLabor
            let ordered = stores[storeIndex].inventory.indices
                .filter { stores[storeIndex].inventory[$0].workshopProject != nil }
                .sorted { lhs, rhs in
                    let left = stores[storeIndex].inventory[lhs].workshopProject!
                    let right = stores[storeIndex].inventory[rhs].workshopProject!
                    if left.priority != right.priority { return left.priority > right.priority }
                    if left.startedTurn != right.startedTurn { return left.startedTurn < right.startedTurn }
                    // UUID はゲームの乱数 seed とは独立して生成されるため、
                    // 同条件の案件は永続配列上の順序で安定的に処理する。
                    return lhs < rhs
                }
            for batchIndex in ordered {
                guard var project = stores[storeIndex].inventory[batchIndex].workshopProject else { continue }
                if project.outsourced {
                    project.outsourcedWeeksRemaining -= 1
                } else if project.remainingWork > 0, labor > 0 {
                    let allocation = min(labor, project.remainingWork)
                    project.remainingWork -= allocation
                    labor -= allocation
                } else if project.remainingWork <= 0, project.inspectionWeeksRemaining > 0 {
                    project.inspectionWeeksRemaining -= 1
                }
                let completed = project.outsourced
                    ? project.outsourcedWeeksRemaining <= 0
                    : project.remainingWork <= 0 && project.inspectionWeeksRemaining <= 0
                if !completed {
                    stores[storeIndex].inventory[batchIndex].workshopProject = project
                    continue
                }
                let before = Int((stores[storeIndex].inventory[batchIndex].quality * 100).rounded())
                let cap = project.outsourced
                    ? (stores[storeIndex].inventory[batchIndex].isRareClassic ? 86 : 90)
                    : (stores[storeIndex].inventory[batchIndex].isRareClassic ? 90 : 94)
                let after = min(cap, before + project.qualityGain)
                stores[storeIndex].inventory[batchIndex].quality = Double(after) / 100.0
                stores[storeIndex].inventory[batchIndex].condition = VehicleConditionProfile(exterior: after, interior: after, mechanical: after)
                if let completedState = project.kind.productState {
                    stores[storeIndex].inventory[batchIndex].productState = completedState
                }
                stores[storeIndex].inventory[batchIndex].productGrade = project.targetGrade
                if project.kind == .repair {
                    stores[storeIndex].inventory[batchIndex].fault = .none
                    stores[storeIndex].inventory[batchIndex].faultRevealed = true
                }
                stores[storeIndex].inventory[batchIndex].workshopProject = nil
                stores[storeIndex].expertise.add(
                    category: stores[storeIndex].inventory[batchIndex].category,
                    purpose: stores[storeIndex].inventory[batchIndex].productState.purpose,
                    project: project.kind,
                    points: project.outsourced ? 1 : 2
                )
                stores[storeIndex].completedProjects[project.kind, default: 0] += 1
                companyExpertise.add(
                    category: stores[storeIndex].inventory[batchIndex].category,
                    purpose: stores[storeIndex].inventory[batchIndex].productState.purpose,
                    project: project.kind,
                    points: project.outsourced ? 1 : 2
                )
                if !project.outsourced,
                   let technicianID = stores[storeIndex].employees.filter({ $0.assignment == .service }).max(by: { $0.serviceSkill < $1.serviceSkill })?.id {
                    awardEmployeeExperience(employeeID: technicianID, storeIndex: storeIndex, focus: .service, successful: true)
                    updateEmployeePerformance(employeeID: technicianID, storeIndex: storeIndex) { $0.servicesCompleted += 1 }
                }
                let completedProductKind = marketProductKind(for: stores[storeIndex].inventory[batchIndex])
                let gradeText = project.targetGrade.map { "・\($0.name(for: completedProductKind))" } ?? ""
                notes.append("\(stores[storeIndex].name)：\(stores[storeIndex].inventory[batchIndex].vehicleName)の\(project.kind.name)\(gradeText)が完成（品質\(after)）")
            }

            let storeID = stores[storeIndex].id
            let orderIndices = customerCustomizationOrders.indices
                .filter {
                    customerCustomizationOrders[$0].storeID == storeID
                        && customerCustomizationOrders[$0].status == .active
                }
                .sorted {
                    let left = customerCustomizationOrders[$0]
                    let right = customerCustomizationOrders[$1]
                    if left.priority != right.priority { return left.priority > right.priority }
                    return (left.startedTurn ?? left.generatedTurn) < (right.startedTurn ?? right.generatedTurn)
                }
            var completedOrderIDs: Set<UUID> = []
            for orderIndex in orderIndices {
                if customerCustomizationOrders[orderIndex].remainingWork > 0, labor > 0 {
                    let allocation = min(labor, customerCustomizationOrders[orderIndex].remainingWork)
                    customerCustomizationOrders[orderIndex].remainingWork -= allocation
                    labor -= allocation
                } else if customerCustomizationOrders[orderIndex].remainingWork <= 0,
                          customerCustomizationOrders[orderIndex].inspectionWeeksRemaining > 0 {
                    customerCustomizationOrders[orderIndex].inspectionWeeksRemaining -= 1
                }
                guard customerCustomizationOrders[orderIndex].remainingWork <= 0,
                      customerCustomizationOrders[orderIndex].inspectionWeeksRemaining <= 0 else { continue }
                let order = customerCustomizationOrders[orderIndex]
                cash += order.quotedRevenue
                stores[storeIndex].pendingCustomizationRevenue += order.quotedRevenue
                stores[storeIndex].pendingCustomizationCOGS += order.materialCost
                stores[storeIndex].expertise.add(
                    category: order.category,
                    purpose: order.kind.productState?.purpose,
                    project: order.kind,
                    points: 2
                )
                stores[storeIndex].completedProjects[order.kind, default: 0] += 1
                companyExpertise.add(
                    category: order.category,
                    purpose: order.kind.productState?.purpose,
                    project: order.kind,
                    points: 2
                )
                completedOrderIDs.insert(order.id)
                let orderProductKind = MarketProductKind.resolve(
                    productState: order.kind.productState ?? .stock,
                    isRareClassic: VehicleCatalog.entry(id: order.modelID)?.isRareClassic == true
                )
                notes.append("\(stores[storeIndex].name)：持ち込み\(order.vehicleName)の\(order.kind.name)・\(order.grade.name(for: orderProductKind))が完成（売上\(order.quotedRevenue.currency)）")
            }
            if !completedOrderIDs.isEmpty {
                customerCustomizationOrders.removeAll { completedOrderIDs.contains($0.id) }
            }
        }
    }

    private func progressStoreProjects(notes: inout [String]) {
        for index in stores.indices {
            if let remaining = stores[index].openingMonthsRemaining {
                let next = remaining - 1
                if next <= 0 {
                    stores[index].openingMonthsRemaining = nil
                    let text = "\(stores[index].name)が完成し、営業を開始しました"
                    notes.append(text)
                    recordCityEvent(CityEvent(
                        turn: turn + 1,
                        kind: .storeGrowth,
                        title: "新店舗がオープン",
                        detail: text,
                        district: plot(id: stores[index].plotID)?.district,
                        plotID: stores[index].plotID
                    ))
                } else {
                    stores[index].openingMonthsRemaining = next
                    notes.append("\(stores[index].name)は建設中（完成まで\(next)週間）")
                }
            }

            if let remaining = stores[index].renovationMonthsRemaining,
               let target = stores[index].pendingType {
                let next = remaining - 1
                if next <= 0 {
                    stores[index].type = target
                    stores[index].pendingType = nil
                    stores[index].renovationMonthsRemaining = nil
                    let text = "\(stores[index].name)の改装が完了し、\(target.name)になりました"
                    notes.append(text)
                    recordCityEvent(CityEvent(
                        turn: turn + 1,
                        kind: .storeGrowth,
                        title: "店舗改装が完了",
                        detail: text,
                        district: plot(id: stores[index].plotID)?.district,
                        plotID: stores[index].plotID
                    ))
                } else {
                    stores[index].renovationMonthsRemaining = next
                    notes.append("\(stores[index].name)は改装中（完成まで\(next)週間）")
                }
            }
            synchronizeParcelUse(for: stores[index])
        }
    }

    private func inventoryAssetValue() -> Int {
        let local = stores.reduce(0) { total, store in
            let district = plot(id: store.plotID)?.district ?? .downtown
            return total + store.inventory.reduce(0) { subtotal, batch in
                guard batch.isRareClassic else { return subtotal + batch.averageCost * batch.count }
                return subtotal + vehicleWholesaleValue(
                    modelID: batch.modelID,
                    category: batch.category,
                    modelYear: batch.modelYear,
                    mileage: batch.mileage,
                    quality: batch.quality,
                    in: district
                ) * batch.count
            }
        }
        let regional = regionalOperations.flatMap(\.inventory).reduce(0) { subtotal, batch in
            guard batch.isRareClassic else { return subtotal + batch.averageCost * batch.count }
            return subtotal + vehicleWholesaleValue(
                modelID: batch.modelID,
                category: batch.category,
                modelYear: batch.modelYear,
                mileage: batch.mileage,
                quality: batch.quality,
                in: .downtown
            ) * batch.count
        }
        return local + regional
            + intercityShipments.reduce(0) { $0 + $1.unitCost * $1.count }
    }

    private func removeInventory(category: VehicleCategory, count: Int, from storeIndex: Int) -> RemovedInventory? {
        guard count > 0,
              stores.indices.contains(storeIndex),
              stores[storeIndex].inventory.filter({ $0.category == category && $0.productState == .stock && !$0.isInWorkshop && !$0.isReserved }).reduce(0, { $0 + $1.count }) >= count else { return nil }
        var remaining = count
        var totalCost = 0
        var totalQuality = 0.0
        var totalModelYear = 0
        var totalMileage = 0
        var totalAcquiredTurn = 0
        var representativeModelID: String?
        var representativeIssue: VehicleIssueRecord?
        while remaining > 0,
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.category == category && $0.count > 0 && $0.productState == .stock && !$0.isInWorkshop && !$0.isReserved }) {
            let taken = min(remaining, stores[storeIndex].inventory[batchIndex].count)
            representativeModelID = representativeModelID ?? stores[storeIndex].inventory[batchIndex].modelID
            if representativeModelID == stores[storeIndex].inventory[batchIndex].modelID, representativeIssue == nil {
                representativeIssue = stores[storeIndex].inventory[batchIndex].vehicleIssue
            }
            totalCost += stores[storeIndex].inventory[batchIndex].averageCost * taken
            totalQuality += stores[storeIndex].inventory[batchIndex].quality * Double(taken)
            totalModelYear += stores[storeIndex].inventory[batchIndex].modelYear * taken
            totalMileage += stores[storeIndex].inventory[batchIndex].mileage * taken
            totalAcquiredTurn += stores[storeIndex].inventory[batchIndex].acquiredTurn * taken
            stores[storeIndex].inventory[batchIndex].count -= taken
            remaining -= taken
            if stores[storeIndex].inventory[batchIndex].count == 0 {
                stores[storeIndex].inventory.remove(at: batchIndex)
            }
        }
        guard let representativeModelID else { return nil }
        return RemovedInventory(
            averageCost: totalCost / count,
            quality: totalQuality / Double(count),
            modelID: representativeModelID,
            modelYear: totalModelYear / count,
            mileage: totalMileage / count,
            acquiredTurn: totalAcquiredTurn / count,
            vehicleIssue: representativeIssue
        )
    }

    private func processInboundShipments(notes: inout [String]) {
        for index in inboundShipments.indices { inboundShipments[index].monthsRemaining -= 1 }
        let arriving = inboundShipments.filter { $0.monthsRemaining <= 0 }
        for shipment in arriving {
            guard let storeIndex = stores.firstIndex(where: { $0.id == shipment.storeID }) else { continue }
            let free = stores[storeIndex].type.capacity - stores[storeIndex].inventoryCount
            guard free >= shipment.count else {
                if let index = inboundShipments.firstIndex(where: { $0.id == shipment.id }) { inboundShipments[index].monthsRemaining = 1 }
                notes.append("\(stores[storeIndex].name)の入庫が展示枠不足で延期されました")
                continue
            }
            addInventory(
                category: shipment.category,
                modelID: shipment.modelID,
                origin: shipment.source == .corporateLot ? .domestic : nil,
                count: shipment.count,
                unitCost: shipment.unitCost,
                quality: shipment.quality,
                modelYear: shipment.modelYear,
                mileage: shipment.mileage,
                condition: shipment.condition,
                fault: shipment.fault,
                faultRevealed: shipment.faultRevealed,
                acquiredTurn: shipment.acquiredTurn,
                to: storeIndex
            )
            if shipment.source != .corporateLot {
                stores[storeIndex].expertise.add(category: shipment.category, purpose: stores[storeIndex].marketPolicy.targetPurpose, source: shipment.source, points: 1)
                companyExpertise.add(category: shipment.category, purpose: stores[storeIndex].marketPolicy.targetPurpose, source: shipment.source, points: 1)
            }
            inboundShipments.removeAll { $0.id == shipment.id }
            let text = "\(shipment.source.name)の\(shipment.vehicleName)\(shipment.count)台が\(stores[storeIndex].name)へ到着"
            notes.append(text)
            recordCityEvent(CityEvent(turn: turn + 1, kind: .auction, title: "車両が入庫", detail: text, plotID: stores[storeIndex].plotID))
        }
    }

    private func processIntercityShipments(notes: inout [String]) {
        for index in intercityShipments.indices {
            intercityShipments[index].monthsRemaining -= 1
        }
        let arriving = intercityShipments.filter { $0.monthsRemaining <= 0 }
        for shipment in arriving {
            guard let operationIndex = regionalOperations.firstIndex(where: { $0.cityID == shipment.destinationCityID }),
                  let city = nationalCities.first(where: { $0.id == shipment.destinationCityID }) else { continue }
            if let batchIndex = regionalOperations[operationIndex].inventory.firstIndex(where: { $0.modelID == shipment.modelID && $0.modelYear == shipment.modelYear && $0.mileage == shipment.mileage && $0.averageCost == shipment.unitCost && $0.acquiredTurn == shipment.acquiredTurn && $0.vehicleIssue == shipment.vehicleIssue }) {
                regionalOperations[operationIndex].inventory[batchIndex].count += shipment.count
            } else {
                regionalOperations[operationIndex].inventory.append(InventoryBatch(modelID: shipment.modelID, category: shipment.category, count: shipment.count, averageCost: shipment.unitCost, quality: shipment.quality, modelYear: shipment.modelYear, mileage: shipment.mileage, acquiredTurn: shipment.acquiredTurn, vehicleIssue: shipment.vehicleIssue))
            }
            intercityShipments.removeAll { $0.id == shipment.id }
            notes.append("\(city.name)へ\(shipment.category.name)\(shipment.count)台が到着しました")
        }
    }

    private func simulateRegionalOperations(notes: inout [String]) -> RegionalMonthResult {
        var result = RegionalMonthResult()
        for index in regionalOperations.indices {
            guard let city = nationalCities.first(where: { $0.id == regionalOperations[index].cityID }) else { continue }
            let operation = regionalOperations[index]
            let fixedCosts = (operation.officeLevel * 120 + operation.franchiseStores * 72 + operation.acquiredStores * 185) / 4
            let advertising = operation.advertisingBudget / 4
            let network = operation.networkStores
            let inventoryCount = operation.inventoryCount
            let baseDemand = Double(network * 3) + Double(city.population) / 180_000.0
            let appeal = city.incomeIndex * (0.72 + operation.brandStrength * 0.32) * (0.76 + nationalBrandStrength * 0.24)
            let competition = max(0.58, 1.14 - city.competitionIndex * 0.20)
            let growth = 0.94 + city.growthRate * 0.06
            let variation = deterministicVariation(seed: turn * 31 + index * 7 + city.population / 10_000)
            let targetSales = network == 0 ? 0 : max(0, Int(baseDemand * appeal * competition * growth * variation * 0.25))
            var remaining = min(inventoryCount, targetSales)
            var cityRevenue = 0
            var cityCOGS = 0

            let categoryOrder = city.primaryDemand + VehicleCategory.allCases.filter { !city.primaryDemand.contains($0) }
            for category in categoryOrder where remaining > 0 {
                for batchIndex in regionalOperations[index].inventory.indices where remaining > 0 && regionalOperations[index].inventory[batchIndex].category == category {
                    let sold = min(remaining, regionalOperations[index].inventory[batchIndex].count)
                    let batch = regionalOperations[index].inventory[batchIndex]
                    let demandBonus = city.primaryDemand.contains(category) ? 1.08 : 0.96
                    let margin = 1.16 + city.incomeIndex * 0.06 + operation.brandStrength * 0.05
                    cityRevenue += Int(Double(batch.averageCost * sold) * margin * demandBonus)
                    cityCOGS += batch.averageCost * sold
                    regionalOperations[index].inventory[batchIndex].count -= sold
                    remaining -= sold
                }
            }
            regionalOperations[index].inventory.removeAll { $0.count == 0 }
            let sales = min(inventoryCount, targetSales) - remaining
            let profit = cityRevenue - cityCOGS - fixedCosts - advertising
            regionalOperations[index].lastSales = sales
            regionalOperations[index].lastRevenue = cityRevenue
            regionalOperations[index].lastProfit = profit
            regionalOperations[index].brandStrength = min(1.40, max(0.42, operation.brandStrength + Double(advertising) / 40_000.0 - 0.00075))

            result.sales += sales
            result.revenue += cityRevenue
            result.costOfSales += cityCOGS
            result.fixedCosts += fixedCosts
            result.advertising += advertising
            if network > 0 {
                notes.append("\(city.name)：\(sales)台販売・営業利益\(profit.currency)")
            }
        }
        return result
    }

    private func resolveAutomaticSales(for storeIndex: Int) -> AutomaticSaleResult {
        guard stores.indices.contains(storeIndex), stores[storeIndex].autoSales else { return AutomaticSaleResult() }
        let storeID = stores[storeIndex].id
        let handlers = stores[storeIndex].employees
            .filter { $0.assignment == .sales }
            .sorted { $0.salesComposite > $1.salesComposite }
        guard !handlers.isEmpty else { return AutomaticSaleResult() }
        var result = AutomaticSaleResult()
        let strategy = stores[storeIndex].salesPolicy.strategy

        for handler in handlers {
            var handledByEmployee = 0
            let caseCapacity = employeeWeeklyCaseCapacity(for: handler, assignment: .sales)
            while handledByEmployee < caseCapacity,
                  let lead = buyerLeads.first(where: {
                      $0.storeID == storeID && automaticInventoryIndex(for: $0, storeIndex: storeIndex, salesperson: handler) != nil
                  }),
                  let batchIndex = automaticInventoryIndex(for: lead, storeIndex: storeIndex, salesperson: handler),
                  let preview = saleNegotiationPreview(
                      storeID: storeID,
                      buyerLeadID: lead.id,
                      inventoryID: stores[storeIndex].inventory[batchIndex].id,
                      strategy: strategy
                  ) {
                handledByEmployee += 1
                result.attempts += 1
                let category = stores[storeIndex].inventory[batchIndex].category
                let employeeSeed = handler.name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
                let seed = turn * 257 + stores[storeIndex].plotID * 47 + categoryIndex(category) * 31 + result.attempts * 17 + employeeSeed
                let tradePreview = tradeInSalePreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: stores[storeIndex].inventory[batchIndex].id, strategy: strategy)
                let canFundTradeIn = cash + min(0, result.cashCollected) >= (tradePreview?.requiredDealerCash ?? 0)
                let acceptTradeIn = tradePreview.map { $0.expectedTradeInGrossProfit >= 0 && canFundTradeIn } ?? false
                let baseChance = acceptTradeIn ? (tradePreview?.closeChance ?? preview.closeChance) : preview.closeChance
                let realizedPrice = acceptTradeIn
                    ? preview.price
                    : max(25, Int(
                        (Double(preview.price) * (1 + employeeSalesPriceRealization(handler))).rounded()
                    ))
                let priceChanceEffect = acceptTradeIn
                    ? 0
                    : buyerBudgetEffect(price: realizedPrice, lead: lead)
                        - buyerBudgetEffect(price: preview.price, lead: lead)
                let alternativeLift = employeeAlternativeProposalAdjustment(handler, lead: lead, batch: stores[storeIndex].inventory[batchIndex])
                let closeChance = min(
                    0.97,
                    max(
                        0.03,
                        baseChance
                            + employeeSalesCloseAdjustment(handler)
                            + alternativeLift
                            + priceChanceEffect
                    )
                )
                buyerLeads.removeAll { $0.id == lead.id }
                let succeeded = transactionRoll(seed: seed) < closeChance
                updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) { $0.handled += 1 }
                awardEmployeeExperience(employeeID: handler.id, storeIndex: storeIndex, focus: .sales, successful: succeeded)
                let proposedVehicle = stores[storeIndex].inventory[batchIndex]
                let reviewService = (succeeded ? 68 : 48)
                    + Int((handler.salesComposite * 0.22).rounded())
                    + Int((strategy.discountRate * 100).rounded())
                recordBuyerReview(
                    lead: lead,
                    batch: proposedVehicle,
                    offerPrice: realizedPrice,
                    succeeded: succeeded,
                    serviceScore: reviewService
                )
                guard succeeded else {
                    if !competitorFulfillsBuyerLead(lead) {
                        registerSegmentUnmet(segmentKey(for: lead))
                    }
                    continue
                }

                let soldVehicle = stores[storeIndex].inventory[batchIndex]
                let unitCost = soldVehicle.averageCost
                stores[storeIndex].inventory[batchIndex].count -= 1
                if stores[storeIndex].inventory[batchIndex].count == 0 {
                    stores[storeIndex].inventory.remove(at: batchIndex)
                }
                if acceptTradeIn, let tradeIn = lead.tradeInVehicle, let tradePreview {
                    stores[storeIndex].inventory.append(InventoryBatch(
                        modelID: tradeIn.modelID,
                        category: tradeIn.category,
                        count: 1,
                        averageCost: tradeIn.appraisedValue + tradePreview.repairCost,
                        quality: tradeIn.qualityAfterRepair,
                        modelYear: tradeIn.modelYear,
                        mileage: tradeIn.mileage,
                        acquiredTurn: turn
                    ))
                    result.cashCollected += tradePreview.cashImpact
                    result.tradeIns += 1
                } else {
                    result.cashCollected += realizedPrice
                }
                let grossProfit = realizedPrice - unitCost
                let commission = max(0, grossProfit) * handler.commissionRate / 100
                result.sales += 1
                result.revenue += realizedPrice
                result.costOfSales += unitCost
                result.commission += commission
                simulationTransactionHandler?(SimulationVehicleTransaction(
                    turn: turn,
                    kind: .sold,
                    storeID: storeID,
                    source: nil,
                    category: category,
                    count: 1,
                    revenue: realizedPrice,
                    cost: unitCost
                ))
                if acceptTradeIn, let tradeIn = lead.tradeInVehicle, let tradePreview {
                    simulationTransactionHandler?(SimulationVehicleTransaction(
                        turn: turn,
                        kind: .acquired,
                        storeID: storeID,
                        source: .tradeIn,
                        category: tradeIn.category,
                        count: 1,
                        revenue: 0,
                        cost: tradeIn.appraisedValue + tradePreview.repairCost
                    ))
                }
                updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) {
                    $0.successes += 1
                    $0.grossProfit += grossProfit
                    $0.commission += commission
                }
                stores[storeIndex].loyalCustomers = min(
                    250,
                    stores[storeIndex].loyalCustomers + loyalCustomerGain(store: stores[storeIndex], category: category)
                )
                stores[storeIndex].expertise.add(category: category, purpose: lead.purpose, points: 1)
                stores[storeIndex].lifetimeProductSales[marketProductKind(for: soldVehicle), default: 0] += 1
                companyExpertise.add(category: category, purpose: lead.purpose, points: 1)
                registerPlayerSegmentSale(
                    storeID: lead.storeID,
                    segmentKey(for: lead),
                    revenue: realizedPrice,
                    cost: unitCost
                )
                scheduleCustomerClaimIfNeeded(
                    for: soldVehicle,
                    customerID: lead.id,
                    storeID: storeID,
                    salePrice: realizedPrice,
                    seed: seed + 409
                )
            }
        }
        return result
    }

    private func updateEmployeePerformance(employeeID: UUID, storeIndex: Int, update: (inout EmployeeWeeklyPerformance) -> Void) {
        guard stores.indices.contains(storeIndex),
              let employeeIndex = stores[storeIndex].employees.firstIndex(where: { $0.id == employeeID }) else { return }
        update(&stores[storeIndex].employees[employeeIndex].currentWeekPerformance)
    }

    private func awardEmployeeExperience(employeeID: UUID, storeIndex: Int, focus: EmployeeTrainingFocus, successful: Bool) {
        guard stores.indices.contains(storeIndex),
              let employeeIndex = stores[storeIndex].employees.firstIndex(where: { $0.id == employeeID }) else { return }
        var employee = stores[storeIndex].employees[employeeIndex]
        let oldOverall = employee.overallSkill
        let gained = successful ? 4 : 2
        func advanced(_ skill: Int, _ experience: Int) -> (skill: Int, experience: Int) {
            let total = experience + gained
            guard skill < 99, total >= 12 else { return (skill, skill >= 99 ? min(12, total) : total) }
            return (skill + 1, total - 12)
        }
        switch focus {
        case .sales:
            (employee.salesSkill, employee.salesExperience) = advanced(employee.salesSkill, employee.salesExperience)
        case .procurement:
            (employee.procurementSkill, employee.procurementExperience) = advanced(employee.procurementSkill, employee.procurementExperience)
        case .research:
            (employee.researchSkill, employee.researchExperience) = advanced(employee.researchSkill, employee.researchExperience)
        case .service:
            (employee.serviceSkill, employee.serviceExperience) = advanced(employee.serviceSkill, employee.serviceExperience)
        }
        let newOverall = employee.overallSkill
        if newOverall / 5 > oldOverall / 5 {
            employee.monthlySalary += 1
        }
        stores[storeIndex].employees[employeeIndex] = employee
    }

    private func scheduleCustomerClaimIfNeeded(for batch: InventoryBatch, customerID: UUID, storeID: UUID, salePrice: Int, seed: Int) {
        guard let issue = batch.vehicleIssue, issue.status == .hidden else { return }
        let compensation = max(30, Int(Double(salePrice) * issue.kind.compensationRate))
        pendingCustomerClaims.append(PendingCustomerClaim(
            id: UUID(),
            customerID: customerID,
            storeID: storeID,
            vehicleName: batch.vehicleName,
            issue: issue.kind,
            salePrice: salePrice,
            compensationCost: compensation,
            dueTurn: turn + 1 + abs(seed % 3)
        ))
    }

    private func automaticInventoryIndex(for lead: BuyerLead, storeIndex: Int, salesperson: StoreEmployee) -> Int? {
        let candidates = stores[storeIndex].inventory.indices.filter {
            stores[storeIndex].inventory[$0].count > 0 && !stores[storeIndex].inventory[$0].isInWorkshop
        }
        return candidates.max { left, right in
            automaticProposalScore(lead: lead, batch: stores[storeIndex].inventory[left], salesperson: salesperson)
                < automaticProposalScore(lead: lead, batch: stores[storeIndex].inventory[right], salesperson: salesperson)
        }
    }

    private func automaticProposalScore(lead: BuyerLead, batch: InventoryBatch, salesperson: StoreEmployee) -> Double {
        let price = manualSaleQuote(storeID: lead.storeID, inventoryID: batch.id)?.price ?? Int.max
        let preference = buyerPreferenceMatchEffect(lead: lead, batch: batch, offerPrice: price)
        let budget = price <= lead.budget ? 0.18 : -min(0.45, Double(price - lead.budget) / Double(max(1, lead.budget)))
        let condition = (batch.quality - lead.minimumQuality) * 0.25
            + (batch.modelYear >= lead.minimumModelYear ? 0.04 : -0.16)
            + (batch.mileage <= lead.maximumMileage ? 0.04 : -0.14)
        return preference + budget + condition + employeeAlternativeProposalAdjustment(salesperson, lead: lead, batch: batch)
    }

    private enum AutomaticProcurementCandidateKind {
        case storePurchase(caseID: UUID, offerPercent: Int)
        case auction(listingID: UUID, maxPrice: Int)
        case networkAuction(listingID: UUID, maxPrice: Int)
    }

    private struct AutomaticProcurementCandidate {
        let kind: AutomaticProcurementCandidateKind
        let source: ProcurementSource
        let vehicleName: String
        let acquisitionCost: Int
        let predictedUnitGrossProfit: Int
        let successProbability: Double

        var expectedGrossProfit: Double {
            Double(predictedUnitGrossProfit) * successProbability
        }
    }

    private func recordProcurementActivity(
        instructionID: UUID,
        source: ProcurementSource?,
        acquiredCount: Int = 0,
        spent: Int = 0,
        reserved: Int = 0,
        result: String? = nil
    ) {
        let key = ProcurementActivityKey(instructionID: instructionID, source: source)
        var activity = procurementWeekActivities[key] ?? ProcurementWeekActivity()
        activity.acquiredCount += acquiredCount
        activity.spent += spent
        activity.reserved += reserved
        if let result, !activity.results.contains(result) {
            activity.results.append(result)
        }
        procurementWeekActivities[key] = activity
    }

    private func procurementReportLines() -> [ProcurementReportLine] {
        procurementWeekActivities.compactMap { key, activity in
            guard let instruction = procurementInstructions.first(where: { $0.id == key.instructionID }) else {
                return nil
            }
            return ProcurementReportLine(
                instructionID: instruction.id,
                storeID: instruction.storeID,
                instructionName: instruction.targetName,
                source: key.source,
                acquiredCount: activity.acquiredCount,
                spent: activity.spent,
                reserved: activity.reserved,
                result: activity.results.isEmpty ? "処理済み" : activity.results.joined(separator: "、")
            )
        }
        .sorted { lhs, rhs in
            let leftPriority = procurementInstructions.first(where: { $0.id == lhs.instructionID })?.priority ?? .max
            let rightPriority = procurementInstructions.first(where: { $0.id == rhs.instructionID })?.priority ?? .max
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            return (lhs.source?.name ?? "") < (rhs.source?.name ?? "")
        }
    }

    private func beginProcurementWeek() {
        for index in procurementInstructions.indices {
            procurementInstructions[index].spentBudget = 0
        }
    }

    private func instructionMatches(
        _ instruction: ProcurementInstruction,
        category: VehicleCategory,
        modelID: String,
        fault: MechanicalFaultSeverity
    ) -> Bool {
        if let targetCategory = instruction.category, targetCategory != category { return false }
        if let targetModelID = instruction.modelID, targetModelID != modelID { return false }
        if let targetOrigin = instruction.origin,
           VehicleCatalog.entry(id: modelID)?.origin != targetOrigin { return false }
        if instruction.faultOnly, fault == .none { return false }
        return true
    }

    private func estimatedSourcingRepairCost(
        category: VehicleCategory,
        fault: MechanicalFaultSeverity,
        condition: VehicleConditionProfile,
        storeID: UUID?
    ) -> Int {
        guard fault != .none else { return 0 }
        let requiredWork = max(2, fault.requiredWork)
        let base = max(24, category.purchaseCost * requiredWork / 15)
        let baseline = Int((Double(base) * OutsourcePartnerKind.generalRepair.costMultiplier).rounded())
        guard let storeID,
              let store = stores.first(where: { $0.id == storeID }) else { return baseline }
        let staffDiscount = employeeServiceCostDiscount(for: storeID)
        let facilityDiscount = store.serviceBays > 0 ? 30 : 0
        let finalRate = max(30, 100 - staffDiscount - facilityDiscount)
        return max(1, Int((Double(baseline) * Double(finalRate) / 100).rounded()))
    }

    private func predictedSourcingRetail(
        storeID: UUID,
        modelID: String,
        category: VehicleCategory,
        modelYear: Int,
        mileage: Int,
        condition: VehicleConditionProfile
    ) -> Int {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID) else { return 0 }
        // 最低粗利は「仕入れ後にそのまま店頭へ出した場合」の価格を基準にする。
        // 修理後の品質や誤差を含む市場予測を使うと、高額車ほど上振れ額が大きくなり、
        // 実際の店頭価格を超える入札上限を許してしまう。
        let retail = vehicleRetailValue(
            modelID: modelID,
            category: category,
            modelYear: modelYear,
            mileage: mileage,
            quality: condition.quality,
            in: plot.district
        )
        return max(
            25,
            Int(
                Double(retail)
                    * store.priceIndex
                    * competitivePriceFactor(in: plot.district)
            )
        )
    }

    private func maximumInstructionOffer(
        instruction: ProcurementInstruction,
        predictedRetail: Int,
        repairCost: Int,
        fixedCosts: Int
    ) -> Int {
        let financialLimit: Int
        switch instruction.financialRule {
        case .minimumGrossProfit(let minimum):
            financialLimit = predictedRetail - repairCost - fixedCosts - minimum
        case .maximumOffer(let maximum):
            financialLimit = maximum
        case .replenishment(_, let minimumGrossMarginPercent):
            let requiredProfit = predictedRetail * minimumGrossMarginPercent / 100
            financialLimit = predictedRetail - repairCost - fixedCosts - requiredProfit
        }
        return max(0, min(financialLimit, instruction.remainingBudget - fixedCosts))
    }

    private func automaticProcurementCashReserved() -> Int {
        let auction = bidReservations
            .filter { $0.instructionID != nil }
            .reduce(0) { $0 + $1.committedCost }
        let online = networkAuctionBidReservations
            .filter { $0.instructionID != nil }
            .reduce(0) { $0 + $1.committedCost }
        return auction + online
    }

    private func automaticProcurementCandidate(
        for instruction: ProcurementInstruction,
        handler: StoreEmployee,
        storeIndex: Int
    ) -> AutomaticProcurementCandidate? {
        let store = stores[storeIndex]
        let storeID = store.id
        guard instruction.remainingBudget > 0 else { return nil }
        let freeCapacity = store.type.capacity
            - store.inventoryCount
            - incomingCount(for: storeID)
            - bidReservations.filter { $0.storeID == storeID }.count
            - networkAuctionBidReservations.filter { $0.storeID == storeID }.count
        guard freeCapacity > 0 else { return nil }
        let visibility = interpolatedEmployeeEffect(
            score: handler.procurementComposite,
            low: 0.30,
            high: 0.98
        )
        let competitionSamples = handler.procurementComposite >= 85
            ? 12
            : handler.procurementComposite >= 60 ? 8 : 4
        var candidates: [AutomaticProcurementCandidate] = []

        if instruction.allowedSources.contains(.storePurchase) {
        for item in purchaseCases where item.storeID == storeID {
            let assessment = purchaseAssessment(for: item)
            let assessedFault = assessment.detectedFault ?? .none
            let assessedCondition = VehicleConditionProfile(
                exterior: assessment.conditionRange.lowerBound,
                interior: assessment.conditionRange.lowerBound,
                mechanical: assessment.conditionRange.lowerBound
            )
            guard item.lotCount <= freeCapacity,
                  instructionMatches(instruction, category: item.category, modelID: item.modelID, fault: assessedFault) else { continue }
            let seed = turn * 263 + item.modelYear * 7 + item.mileage / 1_000
            guard transactionRoll(seed: seed + instruction.priority * 31) <= visibility else { continue }
            let predictedRetail = predictedSourcingRetail(
                storeID: storeID,
                modelID: item.modelID,
                category: item.category,
                modelYear: item.modelYear,
                mileage: item.mileage,
                condition: assessedCondition
            )
            let repairCost = assessment.repairCostRange.upperBound
            let maximumOffer = maximumInstructionOffer(
                instruction: instruction,
                predictedRetail: predictedRetail,
                repairCost: repairCost,
                fixedCosts: 0
            )
            guard maximumOffer >= item.askingPrice * 85 / 100,
                  let percent = safePurchaseOfferPercent(
                    item: item,
                    maximumOffer: maximumOffer,
                    minimumGrossProfit: 0,
                    appraiser: handler
                  ),
                  let preview = purchaseNegotiationPreview(item.id, offerPercent: percent) else { continue }
            let total = preview.price * item.lotCount
            guard total <= instruction.remainingBudget, total <= cash else { continue }
            candidates.append(AutomaticProcurementCandidate(
                kind: .storePurchase(caseID: item.id, offerPercent: percent),
                source: .storePurchase,
                vehicleName: item.vehicleName,
                acquisitionCost: total,
                predictedUnitGrossProfit: predictedRetail - preview.price - repairCost,
                successProbability: min(
                    0.98,
                    max(0.05, preview.closeChance + employeeProcurementCloseAdjustment(handler))
                )
            ))
        }
        }

        if instruction.allowedSources.contains(.auction) {
        for listing in auctionListings where !bidReservations.contains(where: { $0.listingID == listing.id }) {
            guard instructionMatches(instruction, category: listing.category, modelID: listing.modelID, fault: listing.fault) else { continue }
            let seed = listing.modelYear * 19 + listing.mileage / 500 + categoryIndex(listing.category) * 43
            guard transactionRoll(seed: seed + instruction.priority * 37) <= visibility else { continue }
            let fixed = listing.lane.fee + listing.lane.shippingCost
            let predictedRetail = predictedSourcingRetail(
                storeID: storeID,
                modelID: listing.modelID,
                category: listing.category,
                modelYear: listing.modelYear,
                mileage: listing.mileage,
                condition: listing.condition
            )
            let repair = estimatedSourcingRepairCost(
                category: listing.category,
                fault: listing.fault,
                condition: listing.condition,
                storeID: storeID
            )
            let maxPrice = maximumInstructionOffer(
                instruction: instruction,
                predictedRetail: predictedRetail,
                repairCost: repair,
                fixedCosts: fixed
            )
            let committed = maxPrice + fixed
            guard maxPrice >= listing.reservePrice,
                  committed <= instruction.remainingBudget,
                  automaticProcurementCashReserved() + committed <= cash else { continue }
            let successProbability = auctionBidWinChance(
                for: listing,
                maxPrice: maxPrice,
                sampleCount: competitionSamples
            )
            guard successProbability >= 0.05 else { continue }
            candidates.append(AutomaticProcurementCandidate(
                kind: .auction(listingID: listing.id, maxPrice: maxPrice),
                source: .auction,
                vehicleName: listing.vehicleName,
                acquisitionCost: committed,
                predictedUnitGrossProfit: predictedRetail - committed - repair,
                successProbability: successProbability
            ))
        }
        }

        if instruction.allowedSources.contains(.networkAuction) {
        for listing in networkAuctionListings where !networkAuctionBidReservations.contains(where: { $0.listingID == listing.id }) {
            let assessment = networkAuctionAssessment(for: listing, storeID: storeID)
            let assessedFault = assessment.detectedFault ?? .none
            let assessedCondition = VehicleConditionProfile(
                exterior: assessment.conditionRange.lowerBound,
                interior: assessment.conditionRange.lowerBound,
                mechanical: assessment.conditionRange.lowerBound
            )
            guard instructionMatches(instruction, category: listing.category, modelID: listing.modelID, fault: assessedFault) else { continue }
            let seed = listing.modelYear * 17 + listing.mileage / 500 + categoryIndex(listing.category) * 61
            guard transactionRoll(seed: seed + instruction.priority * 41) <= visibility else { continue }
            let fixed = listing.fee + listing.shippingCost
            let predictedRetail = predictedSourcingRetail(
                storeID: storeID,
                modelID: listing.modelID,
                category: listing.category,
                modelYear: listing.modelYear,
                mileage: listing.mileage,
                condition: assessedCondition
            )
            let repair = assessment.repairCostRange.upperBound
            let maxPrice = maximumInstructionOffer(
                instruction: instruction,
                predictedRetail: predictedRetail,
                repairCost: repair,
                fixedCosts: fixed
            )
            let committed = maxPrice + fixed
            guard maxPrice >= listing.reservePrice,
                  committed <= instruction.remainingBudget,
                  automaticProcurementCashReserved() + committed <= cash else { continue }
            let successProbability = networkAuctionBidWinChance(
                for: listing,
                maxPrice: maxPrice,
                sampleCount: competitionSamples
            )
            guard successProbability >= 0.05 else { continue }
            candidates.append(AutomaticProcurementCandidate(
                kind: .networkAuction(listingID: listing.id, maxPrice: maxPrice),
                source: .networkAuction,
                vehicleName: listing.vehicleName,
                acquisitionCost: committed,
                predictedUnitGrossProfit: predictedRetail - committed - repair,
                successProbability: successProbability
            ))
        }
        }

        return candidates.max {
            if instruction.financialRule.targetUnits > 0,
               $0.successProbability != $1.successProbability {
                return $0.successProbability < $1.successProbability
            }
            if instruction.financialRule.targetUnits > 0,
               $0.acquisitionCost != $1.acquisitionCost {
                return $0.acquisitionCost > $1.acquisitionCost
            }
            if $0.expectedGrossProfit != $1.expectedGrossProfit {
                return $0.expectedGrossProfit < $1.expectedGrossProfit
            }
            return $0.acquisitionCost > $1.acquisitionCost
        }
    }

    @discardableResult
    private func executeAutomaticProcurementCandidate(
        _ candidate: AutomaticProcurementCandidate,
        instructionID: UUID,
        handler: StoreEmployee,
        storeIndex: Int,
        notes: inout [String]
    ) -> Bool {
        guard let instructionIndex = procurementInstructions.firstIndex(where: { $0.id == instructionID }) else { return false }
        let storeID = stores[storeIndex].id
        switch candidate.kind {
        case .storePurchase(let caseID, let requestedOfferPercent):
            guard let caseIndex = purchaseCases.firstIndex(where: { $0.id == caseID }) else { return false }
            let original = purchaseCases[caseIndex]
            let issueFound = original.issueRevealed
            let item = purchaseCases[caseIndex]
            let basePredictedRetail = predictedSourcingRetail(
                storeID: storeID,
                modelID: item.modelID,
                category: item.category,
                modelYear: item.modelYear,
                mileage: item.mileage,
                condition: item.condition
            )
            let predictedRetail = item.revealedIssue.map {
                Int(Double(basePredictedRetail) * $0.disclosedValueFactor)
            } ?? basePredictedRetail
            let repairCost = estimatedSourcingRepairCost(
                category: item.category,
                fault: item.fault,
                condition: item.condition,
                storeID: storeID
            )
            let maximumOffer = maximumInstructionOffer(
                instruction: procurementInstructions[instructionIndex],
                predictedRetail: predictedRetail,
                repairCost: repairCost,
                fixedCosts: 0
            )
            guard let safePercent = safePurchaseOfferPercent(
                item: item,
                maximumOffer: maximumOffer,
                minimumGrossProfit: 0,
                appraiser: handler
            ), let preview = purchaseNegotiationPreview(
                caseID,
                offerPercent: min(requestedOfferPercent, safePercent)
            ) else {
                updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) {
                    $0.handled += 1
                    if issueFound && !original.issueRevealed { $0.issuesFound += 1 }
                }
                awardEmployeeExperience(
                    employeeID: handler.id,
                    storeIndex: storeIndex,
                    focus: .procurement,
                    successful: issueFound
                )
                recordSellerReview(
                    item: item,
                    offerPercent: nil,
                    succeeded: false,
                    serviceScore: 54 + Int((handler.procurementComposite * 0.16).rounded()),
                    declinedByStore: true
                )
                procurementInstructions[instructionIndex].lastResult = "店舗買取の\(item.vehicleName)は査定後に見送り"
                recordProcurementActivity(
                    instructionID: instructionID,
                    source: .storePurchase,
                    result: "査定後に見送り"
                )
                purchaseCases.removeAll { $0.id == caseID }
                return true
            }
            let offerPercent = min(requestedOfferPercent, safePercent)
            let total = preview.price * item.lotCount
            guard total <= procurementInstructions[instructionIndex].remainingBudget,
                  cash >= total,
                  stores[storeIndex].inventoryCount + item.lotCount <= stores[storeIndex].type.capacity else { return false }
            let seed = turn * 263 + item.modelYear * 7 + item.mileage / 1_000 + offerPercent * 29
            let chance = min(0.98, max(0.05, preview.closeChance + employeeProcurementCloseAdjustment(handler)))
            let succeeded = transactionRoll(seed: seed) < chance
            updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) {
                $0.handled += 1
                if issueFound && !original.issueRevealed { $0.issuesFound += 1 }
            }
            awardEmployeeExperience(employeeID: handler.id, storeIndex: storeIndex, focus: .procurement, successful: succeeded)
            recordSellerReview(
                item: item,
                offerPercent: offerPercent,
                succeeded: succeeded,
                serviceScore: (succeeded ? 68 : 50) + Int((handler.procurementComposite * 0.20).rounded())
            )
            if succeeded {
                cash -= total
                stores[storeIndex].inventory.append(InventoryBatch(
                    modelID: item.modelID,
                    category: item.category,
                    count: item.lotCount,
                    averageCost: preview.price,
                    quality: item.condition.quality,
                    modelYear: item.modelYear,
                    mileage: item.mileage,
                    acquiredTurn: turn,
                    vehicleIssue: item.hiddenIssue.map {
                        VehicleIssueRecord(kind: $0, status: item.issueRevealed ? .disclosed : .hidden)
                    },
                    condition: item.condition,
                    fault: item.fault,
                    faultRevealed: item.faultRevealed
                ))
                if let suggested = item.suggestedProjectKind,
                   let inventoryID = stores[storeIndex].inventory.last?.id {
                    _ = startWorkshopProject(
                        storeID: item.storeID,
                        inventoryID: inventoryID,
                        kind: suggested,
                        fulfillment: .automatic
                    )
                }
                simulationTransactionHandler?(SimulationVehicleTransaction(
                    turn: turn,
                    kind: .acquired,
                    storeID: item.storeID,
                    source: .storePurchase,
                    category: item.category,
                    count: item.lotCount,
                    revenue: 0,
                    cost: total,
                    purchaseOrigin: item.origin
                ))
                procurementInstructions[instructionIndex].spentBudget += total
                procurementInstructions[instructionIndex].acquiredCount += item.lotCount
                procurementInstructions[instructionIndex].lastResult = "店舗買取で\(item.vehicleName)\(item.lotCount)台・\(total.currency)"
                let purpose = stores[storeIndex].marketPolicy.targetPurpose
                stores[storeIndex].expertise.add(
                    category: item.category,
                    purpose: purpose,
                    source: .storePurchase,
                    points: 1
                )
                companyExpertise.add(
                    category: item.category,
                    purpose: purpose,
                    source: .storePurchase,
                    points: 1
                )
                recordProcurementActivity(
                    instructionID: instructionID,
                    source: .storePurchase,
                    acquiredCount: item.lotCount,
                    spent: total,
                    result: "取得"
                )
                updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) {
                    $0.successes += 1
                    $0.grossProfit += candidate.predictedUnitGrossProfit * item.lotCount
                }
                notes.append("\(stores[storeIndex].name)仕入指示：店舗買取で\(item.vehicleName)\(item.lotCount)台を取得")
            } else {
                procurementInstructions[instructionIndex].lastResult = "店舗買取の\(item.vehicleName)は交渉不成立"
                recordProcurementActivity(
                    instructionID: instructionID,
                    source: .storePurchase,
                    result: "交渉不成立"
                )
            }
            purchaseCases.removeAll { $0.id == caseID }
            return true

        case .auction(let listingID, let maxPrice):
            guard let listing = auctionListings.first(where: { $0.id == listingID }) else { return false }
            let committed = maxPrice + listing.lane.fee + listing.lane.shippingCost
            guard committed <= procurementInstructions[instructionIndex].remainingBudget,
                  reserveBid(listingID: listingID, storeID: storeID, maxPrice: maxPrice, instructionID: instructionID, handlerEmployeeID: handler.id) else { return false }
            procurementInstructions[instructionIndex].reservedBudget += committed
            procurementInstructions[instructionIndex].lastResult = "AAで\(listing.vehicleName)へ上限\(maxPrice.currency)を入札"
            recordProcurementActivity(
                instructionID: instructionID,
                source: .auction,
                reserved: committed,
                result: "入札"
            )
            updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) { $0.handled += 1 }
            notes.append("\(stores[storeIndex].name)仕入指示：AAで\(listing.vehicleName)へ入札")
            return true

        case .networkAuction(let listingID, let maxPrice):
            guard let listing = networkAuctionListings.first(where: { $0.id == listingID }) else { return false }
            let committed = maxPrice + listing.fee + listing.shippingCost
            guard committed <= procurementInstructions[instructionIndex].remainingBudget,
                  reserveNetworkAuctionBid(listingID: listingID, storeID: storeID, maxPrice: maxPrice, instructionID: instructionID, handlerEmployeeID: handler.id) else { return false }
            procurementInstructions[instructionIndex].reservedBudget += committed
            procurementInstructions[instructionIndex].lastResult = "ネットで\(listing.vehicleName)へ上限\(maxPrice.currency)を入札"
            recordProcurementActivity(
                instructionID: instructionID,
                source: .networkAuction,
                reserved: committed,
                result: "入札"
            )
            updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) { $0.handled += 1 }
            notes.append("\(stores[storeIndex].name)仕入指示：社員専用ネットAAで\(listing.vehicleName)へ入札")
            return true
        }
    }

    private func resolveAutomaticProcurement(for storeIndex: Int, notes: inout [String]) {
        guard stores.indices.contains(storeIndex), stores[storeIndex].autoProcurement else { return }
        let storeID = stores[storeIndex].id
        let handlers = stores[storeIndex].employees
            .filter { $0.assignment == .procurement }
            .sorted { $0.procurementComposite > $1.procurementComposite }
        let activeInstructions = procurementInstructions(for: storeID).filter {
            $0.status == .active && $0.remainingBudget > 0
        }
        guard !activeInstructions.isEmpty else {
            notes.append("\(stores[storeIndex].name)自動仕入：有効な仕入れ指示なし")
            return
        }
        guard !handlers.isEmpty else {
            notes.append("\(stores[storeIndex].name)自動仕入：仕入担当が未配置のため停止")
            return
        }

        var performedInstructionIDs: Set<UUID> = []
        var replenishmentReservations: [UUID: Int] = [:]
        for reservation in bidReservations where reservation.storeID == storeID && reservation.targetTurn == turn + 1 {
            if let instructionID = reservation.instructionID {
                replenishmentReservations[instructionID, default: 0] += 1
            }
        }
        for reservation in networkAuctionBidReservations where reservation.storeID == storeID && reservation.targetTurn == turn + 1 {
            if let instructionID = reservation.instructionID {
                replenishmentReservations[instructionID, default: 0] += 1
            }
        }
        for handler in handlers {
            let caseCapacity = employeeWeeklyCaseCapacity(for: handler, assignment: .procurement)
            for _ in 0..<caseCapacity {
                var selected: (ProcurementInstruction, AutomaticProcurementCandidate)?
                for instruction in procurementInstructions(for: storeID)
                    where instruction.status == .active && instruction.remainingBudget > 0 {
                    if instruction.financialRule.targetUnits > 0,
                       replenishmentReservations[instruction.id, default: 0] >= instruction.financialRule.targetUnits {
                        continue
                    }
                    if let candidate = automaticProcurementCandidate(
                        for: instruction,
                        handler: handler,
                        storeIndex: storeIndex
                    ) {
                        selected = (instruction, candidate)
                        break
                    }
                }
                guard let selected else { break }
                let attempted = executeAutomaticProcurementCandidate(
                    selected.1,
                    instructionID: selected.0.id,
                    handler: handler,
                    storeIndex: storeIndex,
                    notes: &notes
                )
                if !attempted { break }
                performedInstructionIDs.insert(selected.0.id)
                if selected.0.financialRule.targetUnits > 0 {
                    replenishmentReservations[selected.0.id, default: 0] += 1
                }
            }
        }
        let unmatched = activeInstructions.filter { instruction in
            !performedInstructionIDs.contains(instruction.id)
                && procurementInstructions.first(where: { $0.id == instruction.id })?.status == .active
        }
        for instruction in unmatched {
            if let index = procurementInstructions.firstIndex(where: { $0.id == instruction.id }) {
                procurementInstructions[index].lastResult = "今週は条件一致なし"
            }
            recordProcurementActivity(
                instructionID: instruction.id,
                source: nil,
                result: "条件一致なし"
            )
        }
        if !unmatched.isEmpty {
            notes.append("\(stores[storeIndex].name)仕入指示：今週は予算・車両条件に合う候補なし")
        }
        for instruction in activeInstructions where instruction.financialRule.targetUnits > 0 {
            let reserved = replenishmentReservations[instruction.id, default: 0]
            let target = instruction.financialRule.targetUnits
            if reserved < target {
                let message = "台数確保 \(reserved)/\(target)台：粗利上限・予算・在庫枠の条件は緩和しません"
                if let index = procurementInstructions.firstIndex(where: { $0.id == instruction.id }) {
                    procurementInstructions[index].lastResult = message
                }
                recordProcurementActivity(instructionID: instruction.id, source: nil, result: message)
                notes.append("\(stores[storeIndex].name)仕入指示：\(message)")
            }
        }
    }

    private func resolveAutomaticService(for storeIndex: Int) {
        guard stores.indices.contains(storeIndex), stores[storeIndex].autoService else { return }
        let storeID = stores[storeIndex].id
        func projectKind(for batch: InventoryBatch) -> WorkshopProjectKind? {
            if batch.fault != .none { return .repair }
            let purpose = stores[storeIndex].marketPolicy.targetPurpose
            if purpose == .camper,
               batch.category == .minivan,
               batch.productState != .camper {
                return .camperConversion
            }
            if [.work, .corporate].contains(purpose),
               [.minivan, .pickup].contains(batch.category),
               batch.productState != .workCargo {
                return .workConversion
            }
            if purpose == .outdoor,
               [.suv, .pickup, .minivan].contains(batch.category),
               batch.productState != .outdoor {
                return .outdoorConversion
            }
            let threshold = switch stores[storeIndex].servicePolicy {
            case .cost: 70
            case .balanced: 80
            case .quality: 90
            }
            guard Int((batch.quality * 100).rounded()) < threshold else { return nil }
            return batch.productState == .stock ? .basicService : .refurbishment
        }
        let maximumStarts = max(1, stores[storeIndex].inventory.count)
        for _ in 0..<maximumStarts {
            let candidates = stores[storeIndex].inventory.filter { batch in
                batch.count > 0
                    && !batch.isInWorkshop
                    && !batch.isReserved
                    && projectKind(for: batch) != nil
            }.sorted { $0.quality < $1.quality }
            let viable = candidates.compactMap { batch -> (InventoryBatch, WorkshopProjectPreview)? in
                guard let kind = projectKind(for: batch) else { return nil }
                let productKind = MarketProductKind.resolve(
                    productState: kind.productState ?? batch.productState,
                    isRareClassic: batch.isRareClassic
                )
                let isGradeProject = productKind.supportsGrades
                    && ![WorkshopProjectKind.basicService, .repair].contains(kind)
                    && (kind != .refurbishment || batch.isRareClassic)
                let grades: [SpecialtyProductGrade?] = isGradeProject
                    ? SpecialtyProductGrade.allCases.map(Optional.some)
                    : [nil]
                let previews = grades.compactMap { grade in
                    workshopProjectPreview(
                        storeID: storeID,
                        inventoryID: batch.id,
                        kind: kind,
                        grade: grade
                    )
                }.filter { preview in
                    guard productKind.supportsGrades || preview.outsourced else { return true }
                    let totalCost = batch.averageCost + preview.cost
                    return preview.projectedSalePrice >= Int(Double(totalCost) * 1.05)
                }
                guard let preview = previews.max(by: {
                    ($0.projectedSalePrice - batch.averageCost - $0.cost)
                        < ($1.projectedSalePrice - batch.averageCost - $1.cost)
                }) else { return nil }
                return (batch, preview)
            }
            guard let selected = viable.first else { break }
            guard startWorkshopProject(
                storeID: storeID,
                inventoryID: selected.0.id,
                kind: selected.1.kind,
                grade: selected.1.grade,
                fulfillment: selected.1.fulfillmentMode
            ) else { break }
        }
    }

    private func progressAutomaticMarketing(for storeIndex: Int) {
        guard stores.indices.contains(storeIndex), stores[storeIndex].autoMarketing else { return }
        let employeeIDs = stores[storeIndex].employees.filter { $0.assignment == .research }.map(\.id)
        for employeeID in employeeIDs {
            awardEmployeeExperience(employeeID: employeeID, storeIndex: storeIndex, focus: .research, successful: true)
        }
    }

    private func beginEmployeeWeek() {
        for storeIndex in stores.indices {
            for employeeIndex in stores[storeIndex].employees.indices {
                stores[storeIndex].employees[employeeIndex].currentWeekPerformance = EmployeeWeeklyPerformance()
            }
        }
    }

    private func finalizeEmployeeWeek(notes: inout [String]) {
        for storeIndex in stores.indices {
            for employeeIndex in stores[storeIndex].employees.indices {
                let performance = stores[storeIndex].employees[employeeIndex].currentWeekPerformance
                stores[storeIndex].employees[employeeIndex].lastWeekPerformance = performance
                stores[storeIndex].employees[employeeIndex].recentCommissions.append(performance.commission)
                stores[storeIndex].employees[employeeIndex].recentCommissions = Array(stores[storeIndex].employees[employeeIndex].recentCommissions.suffix(4))
                if performance.handled > 0 || performance.servicesCompleted > 0 {
                    let employee = stores[storeIndex].employees[employeeIndex]
                    let commissionText = performance.commission > 0 ? "・歩合\(performance.commission.currency)" : ""
                    notes.append("\(stores[storeIndex].name) \(employee.name)：\(performance.summary)\(commissionText)")
                }
            }
            if stores[storeIndex].autoMarketing,
               let researcher = stores[storeIndex].employees.filter({ $0.assignment == .research }).max(by: { $0.researchSkill < $1.researchSkill }) {
                notes.append("\(stores[storeIndex].name) \(researcher.name)：広告効率\(Int((employeeMarketingEfficiency(for: stores[storeIndex].id, buyers: true) * 100).rounded()))%・市場予測±\(Int((marketForecastErrorRate(for: stores[storeIndex].id) * 100).rounded()))%")
            }
        }
    }

    @discardableResult
    private func expireWeeklyCustomerLeads(notes: inout [String]) -> Int {
        var totalMissedBuyers = 0
        for store in stores where store.isOperational {
            let missedBuyerLeads = buyerLeads.filter { $0.storeID == store.id }
            let missedSellerCases = purchaseCases.filter { $0.storeID == store.id }
            let missedBuyers = missedBuyerLeads.count
            let missedSellers = missedSellerCases.count
            totalMissedBuyers += missedBuyers
            for lead in missedBuyerLeads {
                recordUnattendedReview(customerID: lead.id, storeID: store.id, channel: .buyer)
                if !competitorFulfillsBuyerLead(lead) {
                    registerSegmentUnmet(segmentKey(for: lead))
                }
            }
            for item in missedSellerCases {
                recordUnattendedReview(customerID: item.id, storeID: store.id, channel: .seller)
                competitorAcquiresPurchaseCase(item)
            }
            if missedBuyers > 0 || missedSellers > 0 {
                notes.append("\(store.name)：未対応・不一致で販売客\(missedBuyers)人、買取客\(missedSellers)人を見送り")
            }
        }
        buyerLeads.removeAll()
        purchaseCases.removeAll()
        return totalMissedBuyers
    }

    private func progressInventorySaleCampaigns(notes: inout [String]) {
        for index in stores.indices {
            if var campaign = stores[index].inventorySaleCampaign {
                campaign.remainingWeeks -= 1
                if campaign.remainingWeeks <= 0 {
                    stores[index].inventorySaleCampaign = nil
                    stores[index].inventorySaleCooldownWeeks = 12
                    notes.append("\(stores[index].name)：\(campaign.tier.name)在庫セールが終了（12週間は再開催不可）")
                } else {
                    stores[index].inventorySaleCampaign = campaign
                }
            } else if stores[index].inventorySaleCooldownWeeks > 0 {
                stores[index].inventorySaleCooldownWeeks -= 1
            }
        }
    }

    private func applyDelegatedOperations(notes: inout [String]) {
        for index in stores.indices {
            guard stores[index].isOperational, stores[index].hasManager,
                  let plot = plot(id: stores[index].plotID) else { continue }
            var actions: [String] = []
            let manager = stores[index].manager!

            if stores[index].delegateStaff {
                let needsInstructionHandler = stores[index].autoProcurement
                    && procurementInstructions(for: stores[index].id).contains {
                        $0.status == .active && $0.remainingBudget > 0
                    }
                let automatedCases = (stores[index].autoSales ? stores[index].buyerArrivalsThisWeek : 0)
                    + (stores[index].autoProcurement
                        ? max(stores[index].sellerArrivalsThisWeek, needsInstructionHandler ? 1 : 0)
                        : 0)
                let caseWorkers = max(0, Int(ceil(Double(automatedCases) / Double(employeeWeeklyCaseCapacity))))
                let supportWorkers = (stores[index].autoMarketing ? 1 : 0)
                    + (stores[index].autoService && stores[index].inventoryCount > 0 ? 1 : 0)
                let target = min(maxEmployeesPerStore, caseWorkers + supportWorkers)
                if stores[index].staff < target, let candidate = employeeCandidates(for: stores[index].id).first {
                    stores[index].employees.append(candidate)
                    actions.append("\(candidate.name)を採用")
                } else if stores[index].staff > target + 2,
                          let employee = stores[index].employees.min(by: { $0.overallSkill < $1.overallSkill }) {
                    stores[index].employees.removeAll { $0.id == employee.id }
                    actions.append("\(employee.name)を配置から外す")
                }

                let canReassign = manager.staffingAbility >= 60 || turn.isMultiple(of: 2)
                if canReassign {
                    let reassignmentLimit = manager.staffingAbility >= 80 ? 2 : 1
                    let enabledAssignments: [EmployeeAssignment] = [
                        stores[index].autoSales ? .sales : nil,
                        stores[index].autoProcurement ? .procurement : nil,
                        stores[index].autoMarketing ? .research : nil,
                        stores[index].autoService ? .service : nil
                    ].compactMap { $0 }
                    for _ in 0..<reassignmentLimit {
                        guard !enabledAssignments.isEmpty,
                              let employeeIndex = stores[index].employees.firstIndex(where: {
                                  $0.assignment == .unassigned || !enabledAssignments.contains($0.assignment)
                              }) else { break }
                        let buyerNeed = max(
                            0,
                            stores[index].buyerArrivalsThisWeek
                                - stores[index].employees
                                    .filter { $0.assignment == .sales }
                                    .reduce(0) {
                                        $0 + employeeWeeklyCaseCapacity(for: $1, assignment: .sales)
                                    }
                        )
                        let sellerCases = max(
                            stores[index].sellerArrivalsThisWeek,
                            needsInstructionHandler ? 1 : 0
                        )
                        let sellerNeed = max(
                            0,
                            sellerCases
                                - stores[index].employees
                                    .filter { $0.assignment == .procurement }
                                    .reduce(0) {
                                        $0 + employeeWeeklyCaseCapacity(for: $1, assignment: .procurement)
                                    }
                        )
                        let assignment: EmployeeAssignment
                        if stores[index].autoMarketing && !stores[index].employees.contains(where: { $0.assignment == .research }) {
                            assignment = .research
                        } else if buyerNeed >= sellerNeed, stores[index].autoSales {
                            assignment = .sales
                        } else if stores[index].autoProcurement {
                            assignment = .procurement
                        } else {
                            assignment = enabledAssignments.first!
                        }
                        stores[index].employees[employeeIndex].assignment = assignment
                        actions.append("\(stores[index].employees[employeeIndex].name)を\(assignment.name)へ配置")
                    }
                }
            }

            if stores[index].delegateProcurement {
                let storeID = stores[index].id
                let inventoryRate = Double(stores[index].inventoryCount + incomingCount(for: storeID))
                    / Double(max(1, stores[index].type.capacity))
                let appraisalReady = appraisalConfidence(for: storeID) >= 65
                let hasRepairReadiness = stores[index].serviceBays > 0
                    && stores[index].employees.contains(where: { $0.assignment == .service })
                var sources: Set<ProcurementSource> = [.auction, .networkAuction]
                if appraisalReady {
                    sources.insert(.storePurchase)
                }
                let demandCategory = VehicleCategory.allCases.max {
                    vehicleDemand($0, in: plot.district) < vehicleDemand($1, in: plot.district)
                }
                let targetCategory = stores[index].marketPolicy.priorityCategories.first ?? demandCategory
                let reserveCash = max(300, monthlyPersonnelCost(for: stores[index]) * 2)
                let targetBudget = min(max(0, cash - reserveCash), inventoryRate < 0.35 ? 1_200 : 700)
                let minimumMargin = 24 + max(0, manager.procurementAbility - 50) / 3
                let acceptsFaulty = hasRepairReadiness
                    && stores[index].marketPolicy.acceptedConditions.contains(.faulty)
                if let instructionIndex = procurementInstructions.firstIndex(where: {
                    $0.storeID == storeID && $0.status == .active
                }) {
                    procurementInstructions[instructionIndex].priority = 0
                    procurementInstructions[instructionIndex].totalBudget = max(
                        procurementInstructions[instructionIndex].spentBudget
                            + procurementInstructions[instructionIndex].reservedBudget,
                        targetBudget
                    )
                    procurementInstructions[instructionIndex].financialRule = .minimumGrossProfit(minimumMargin)
                    procurementInstructions[instructionIndex].category = targetCategory
                    procurementInstructions[instructionIndex].modelID = nil
                    procurementInstructions[instructionIndex].faultOnly = acceptsFaulty && inventoryRate < 0.45
                    procurementInstructions[instructionIndex].allowedSources = sources
                    procurementInstructions[instructionIndex].lastResult = "店長が市場と在庫から条件を更新"
                    actions.append("仕入条件を更新")
                } else if targetBudget >= 100 {
                    procurementInstructions.append(ProcurementInstruction(
                        storeID: storeID,
                        priority: 0,
                        totalBudget: targetBudget,
                        financialRule: .minimumGrossProfit(minimumMargin),
                        category: targetCategory,
                        faultOnly: acceptsFaulty && inventoryRate < 0.45,
                        allowedSources: sources,
                        createdTurn: turn,
                        lastResult: "店長が市場と在庫から作成"
                    ))
                    stores[index].autoProcurement = true
                    actions.append("仕入指示を作成")
                }
            }

            if stores[index].delegatePricing {
                let stockRate = Double(stores[index].inventoryCount + incomingCount(for: stores[index].id)) / Double(max(1, stores[index].type.capacity))
                let priceReview = stores[index].reviewScore(for: .salesPrice)
                let reviewRequiresCorrection = (priceReview ?? 100) < 60
                let targetPrice = reviewRequiresCorrection ? 0.96 : stockRate > 0.72 ? 0.96 : stockRate < 0.30 ? 1.05 : 1.0
                let targetPolicy: SalesAutomationPolicy = reviewRequiresCorrection ? .volume : stockRate > 0.72 ? .volume : stockRate < 0.30 ? .profit : .balanced
                let canAdjust = manager.salesAbility >= 60 || turn.isMultiple(of: 2)
                var changedPolicy = false
                if canAdjust, stores[index].salesPolicy != targetPolicy {
                    stores[index].salesPolicy = targetPolicy
                    changedPolicy = true
                    actions.append("販売方針を\(targetPolicy.name)へ変更")
                }
                if canAdjust, (manager.salesAbility >= 80 || !changedPolicy), abs(stores[index].priceIndex - targetPrice) >= 0.02 {
                    let step = manager.salesAbility >= 80 ? 0.03 : manager.salesAbility >= 60 ? 0.02 : 0.01
                    stores[index].priceIndex += targetPrice > stores[index].priceIndex ? step : -step
                    actions.append("価格を調整")
                }
            }

            if stores[index].delegateMarketing {
                let marketingAbility = manager.researchAbility
                let targetPolicy: MarketingAutomationPolicy = stores[index].buyerArrivalsThisWeek < stores[index].sellerArrivalsThisWeek ? .buyers : stores[index].sellerArrivalsThisWeek < stores[index].buyerArrivalsThisWeek ? .sellers : .balanced
                let overspend = max(0, 65 - marketingAbility)
                let target = min(360, 70 + competitorCount(in: plot.district) * 45 + max(0, stores[index].lastProfit) / 12 + overspend)
                let canAdjust = marketingAbility >= 60 || turn.isMultiple(of: 2)
                var changedPolicy = false
                if canAdjust, stores[index].marketingPolicy != targetPolicy {
                    stores[index].marketingPolicy = targetPolicy
                    changedPolicy = true
                    actions.append("集客方針を\(targetPolicy.name)へ変更")
                }
                if canAdjust, (marketingAbility >= 80 || !changedPolicy), abs(stores[index].advertising - target) >= 20 {
                    let step = marketingAbility >= 80 ? 30 : marketingAbility >= 60 ? 20 : 10
                    stores[index].advertising += target > stores[index].advertising ? step : -step
                    actions.append("広告予算を調整")
                }
            }

            if stores[index].delegateService {
                let serviceAbility = manager.serviceAbility
                let averageQuality = stores[index].inventory.isEmpty ? 100 : stores[index].inventory.reduce(0.0) { $0 + $1.quality * Double($1.count) } / Double(max(1, stores[index].inventoryCount)) * 100
                let targetPolicy: ServiceAutomationPolicy = averageQuality < 70 ? .quality : cash < monthlyPersonnelCost(for: stores[index]) * 2 ? .cost : .balanced
                let reviewSatisfaction = stores[index].averageReviewScore ?? 70
                let target = reviewSatisfaction < 72 ? 0.55 : stores[index].inventoryCount > stores[index].type.capacity * 7 / 10 ? 0.35 : 0.45
                let canAdjust = serviceAbility >= 60 || turn.isMultiple(of: 2)
                var changedPolicy = false
                if canAdjust, stores[index].servicePolicy != targetPolicy {
                    stores[index].servicePolicy = targetPolicy
                    changedPolicy = true
                    actions.append("整備方針を\(targetPolicy.name)へ変更")
                }
                if canAdjust, (serviceAbility >= 80 || !changedPolicy), abs(stores[index].serviceAllocation - target) >= 0.04 {
                    let step = serviceAbility >= 80 ? 0.07 : serviceAbility >= 60 ? 0.05 : 0.03
                    stores[index].serviceAllocation += target > stores[index].serviceAllocation ? step : -step
                    actions.append("整備配分を調整")
                }
            }

            if !actions.isEmpty { notes.append("\(stores[index].name)店長：\(actions.joined(separator: "、"))") }
        }
    }

    private func resolveAuctionBids(at resolvingTurn: Int, notes: inout [String]) {
        let reservations = bidReservations.filter { $0.resultTurn <= resolvingTurn }
        for bid in reservations {
            let committedCost = bid.committedCost
            guard let listing = auctionListings.first(where: { $0.id == bid.listingID }) else {
                settleInstructionReservation(
                    instructionID: bid.instructionID,
                    committedCost: committedCost,
                    actualCost: nil,
                    vehicleName: "AA出品終了",
                    source: .auction,
                    failureReason: "出品終了"
                )
                bidReservations.removeAll { $0.id == bid.id }
                continue
            }
            guard stores.contains(where: { $0.id == bid.storeID }) else {
                settleInstructionReservation(
                    instructionID: bid.instructionID,
                    committedCost: committedCost,
                    actualCost: nil,
                    vehicleName: listing.vehicleName,
                    source: .auction,
                    failureReason: "対象店舗なし"
                )
                bidReservations.removeAll { $0.id == bid.id }
                continue
            }
            let seed = turn * 277 + listing.modelYear * 19 + listing.mileage / 500 + categoryIndex(listing.category) * 43
            let rivalBid = auctionRivalBid(for: listing, seed: seed)
            let rivalPrice = rivalBid?.maxPrice
            let wonCompetition = bid.maxPrice >= (rivalPrice ?? listing.reservePrice)
            let status: AuctionBidResultStatus
            var hammerPrice: Int
            let winningCompetitorID: UUID?
            if !wonCompetition {
                hammerPrice = rivalPrice ?? listing.reservePrice
                status = .exceededLimit
                winningCompetitorID = rivalBid?.competitorIndex.map { competitors[$0].id }
                if let competitorIndex = rivalBid?.competitorIndex {
                    recordCompetitorAuctionPurchase(listing: listing, competitorIndex: competitorIndex, hammerPrice: hammerPrice, purchasedTurn: resolvingTurn)
                }
                notes.append("\(listing.vehicleName)の入札は落札価格\(hammerPrice.currency)が上限\(bid.maxPrice.currency)を超え、\(winningCompetitorID.map(competitorName(for:)) ?? "他社")が落札しました")
            } else {
                hammerPrice = rivalPrice.map {
                    min(bid.maxPrice, max(listing.reservePrice, $0 + 1))
                } ?? listing.reservePrice
                let playerTotal = hammerPrice + listing.lane.fee + listing.lane.shippingCost
                if cash < playerTotal {
                    hammerPrice = rivalPrice ?? listing.reservePrice
                    status = .insufficientFunds
                    winningCompetitorID = rivalBid?.competitorIndex.map { competitors[$0].id }
                    if let competitorIndex = rivalBid?.competitorIndex {
                        recordCompetitorAuctionPurchase(
                            listing: listing,
                            competitorIndex: competitorIndex,
                            hammerPrice: rivalBid?.maxPrice ?? listing.reservePrice,
                            purchasedTurn: resolvingTurn
                        )
                    }
                    notes.append("\(listing.vehicleName)は落札圏内でしたが、諸費用込み\(playerTotal.currency)の資金を確保できず、\(winningCompetitorID.map(competitorName(for:)) ?? "他社")が落札しました")
                } else {
                    status = .won
                    winningCompetitorID = nil
                    cash -= playerTotal
                    inboundShipments.append(InboundShipment(
                        id: UUID(),
                        storeID: bid.storeID,
                        source: .auction,
                        modelID: listing.modelID,
                        category: listing.category,
                        count: 1,
                        unitCost: playerTotal,
                        quality: listing.quality,
                        modelYear: listing.modelYear,
                        mileage: listing.mileage,
                        condition: listing.condition,
                        fault: listing.fault,
                        faultRevealed: true,
                        instructionID: bid.instructionID,
                        acquiredTurn: resolvingTurn,
                        monthsRemaining: listing.lane.shippingMonths
                    ))
                    simulationTransactionHandler?(SimulationVehicleTransaction(
                        turn: resolvingTurn,
                        kind: .acquired,
                        storeID: bid.storeID,
                        source: .auction,
                        category: listing.category,
                        count: 1,
                        revenue: 0,
                        cost: playerTotal
                    ))
                    notes.append("翠浜AA・\(listing.lane.name)で\(listing.vehicleName)を\(hammerPrice.currency)で落札しました（会場費・輸送費込み \(playerTotal.currency)）")
                }
            }
            let total = hammerPrice + listing.lane.fee + listing.lane.shippingCost
            settleInstructionReservation(
                instructionID: bid.instructionID,
                committedCost: committedCost,
                actualCost: status == .won ? total : nil,
                vehicleName: listing.vehicleName,
                source: .auction,
                failureReason: status.name
            )
            auctionBidResults.insert(AuctionBidResult(
                id: UUID(),
                listingID: listing.id,
                storeID: bid.storeID,
                lane: listing.lane,
                modelID: listing.modelID,
                category: listing.category,
                modelYear: listing.modelYear,
                mileage: listing.mileage,
                maxPrice: bid.maxPrice,
                hammerPrice: hammerPrice,
                totalCost: total,
                status: status,
                winningCompetitorID: winningCompetitorID,
                resolvedTurn: resolvingTurn
            ), at: 0)
            attributeAuctionResolution(
                employeeID: bid.handlerEmployeeID,
                storeID: bid.storeID,
                succeeded: status == .won,
                predictedGrossProfit: status == .won ? max(0, listing.marketPrice - total) : 0
            )
            auctionListings.removeAll { $0.id == listing.id }
            bidReservations.removeAll { $0.id == bid.id }
        }
        if auctionBidResults.count > 20 {
            auctionBidResults.removeLast(auctionBidResults.count - 20)
        }
    }

    private func attributeAuctionResolution(
        employeeID: UUID?,
        storeID: UUID,
        succeeded: Bool,
        predictedGrossProfit: Int
    ) {
        guard let employeeID,
              let storeIndex = stores.firstIndex(where: { $0.id == storeID }) else { return }
        updateEmployeePerformance(employeeID: employeeID, storeIndex: storeIndex) {
            if succeeded {
                $0.successes += 1
                $0.grossProfit += predictedGrossProfit
            }
        }
        awardEmployeeExperience(
            employeeID: employeeID,
            storeIndex: storeIndex,
            focus: .procurement,
            successful: succeeded
        )
    }

    private func settleInstructionReservation(
        instructionID: UUID?,
        committedCost: Int,
        actualCost: Int?,
        vehicleName: String,
        source: ProcurementSource,
        failureReason: String = "不成立"
    ) {
        guard let instructionID,
              let index = procurementInstructions.firstIndex(where: { $0.id == instructionID }) else { return }
        procurementInstructions[index].reservedBudget = max(
            0,
            procurementInstructions[index].reservedBudget - committedCost
        )
        if let actualCost {
            procurementInstructions[index].spentBudget += actualCost
            procurementInstructions[index].acquiredCount += 1
            procurementInstructions[index].lastResult = "\(source.name)で\(vehicleName)を取得・\(actualCost.currency)"
            recordProcurementActivity(
                instructionID: instructionID,
                source: source,
                acquiredCount: 1,
                spent: actualCost,
                result: "取得"
            )
        } else {
            procurementInstructions[index].lastResult = "\(source.name)の\(vehicleName)は\(failureReason)"
            recordProcurementActivity(
                instructionID: instructionID,
                source: source,
                result: failureReason
            )
        }
    }

    private func resolveNetworkAuctionBids(at resolvingTurn: Int, notes: inout [String]) {
        let reservations = networkAuctionBidReservations.filter { $0.resultTurn <= resolvingTurn }
        for bid in reservations {
            guard let listing = networkAuctionListings.first(where: { $0.id == bid.listingID }) else {
                settleInstructionReservation(
                    instructionID: bid.instructionID,
                    committedCost: bid.committedCost,
                    actualCost: nil,
                    vehicleName: "ネット出品終了",
                    source: .networkAuction,
                    failureReason: "出品終了"
                )
                networkAuctionBidReservations.removeAll { $0.id == bid.id }
                continue
            }
            let committedCost = bid.committedCost
            guard stores.contains(where: { $0.id == bid.storeID }) else {
                settleInstructionReservation(
                    instructionID: bid.instructionID,
                    committedCost: committedCost,
                    actualCost: nil,
                    vehicleName: listing.vehicleName,
                    source: .networkAuction,
                    failureReason: "対象店舗なし"
                )
                networkAuctionBidReservations.removeAll { $0.id == bid.id }
                continue
            }
            let seed = turn * 311 + listing.modelYear * 17 + listing.mileage / 500 + categoryIndex(listing.category) * 61
            let rivalBid = networkAuctionRivalBid(for: listing, seed: seed)
            let rivalPrice = rivalBid?.maxPrice
            let wonCompetition = bid.maxPrice >= (rivalPrice ?? listing.reservePrice)
            let status: AuctionBidResultStatus
            var hammerPrice: Int
            let winningCompetitorID: UUID?
            if !wonCompetition {
                hammerPrice = rivalPrice ?? listing.reservePrice
                status = .exceededLimit
                winningCompetitorID = rivalBid?.competitorIndex.map { competitors[$0].id }
                if let competitorIndex = rivalBid?.competitorIndex {
                    recordCompetitorNetworkAuctionPurchase(
                        listing: listing,
                        competitorIndex: competitorIndex,
                        hammerPrice: hammerPrice,
                        purchasedTurn: resolvingTurn
                    )
                }
                notes.append("\(listing.vehicleName)のネット入札は落札価格\(hammerPrice.currency)が上限を超えました")
            } else {
                hammerPrice = rivalPrice.map {
                    min(bid.maxPrice, max(listing.reservePrice, $0 + 1))
                } ?? listing.reservePrice
                let playerTotal = hammerPrice + listing.fee + listing.shippingCost
                if cash < playerTotal {
                    status = .insufficientFunds
                    winningCompetitorID = rivalBid?.competitorIndex.map { competitors[$0].id }
                    if let competitorIndex = rivalBid?.competitorIndex {
                        recordCompetitorNetworkAuctionPurchase(
                            listing: listing,
                            competitorIndex: competitorIndex,
                            hammerPrice: rivalBid?.maxPrice ?? listing.reservePrice,
                            purchasedTurn: resolvingTurn
                        )
                    }
                    notes.append("\(listing.vehicleName)のネット入札は資金不足で落札できませんでした")
                } else {
                    status = .won
                    winningCompetitorID = nil
                    cash -= playerTotal
                    inboundShipments.append(InboundShipment(
                        storeID: bid.storeID,
                        source: .networkAuction,
                        modelID: listing.modelID,
                        category: listing.category,
                        count: 1,
                        unitCost: playerTotal,
                        quality: listing.quality,
                        modelYear: listing.modelYear,
                        mileage: listing.mileage,
                        condition: listing.condition,
                        fault: listing.fault,
                        faultRevealed: networkAuctionAssessment(
                            for: listing,
                            storeID: bid.storeID
                        ).detectedFault != nil,
                        instructionID: bid.instructionID,
                        acquiredTurn: resolvingTurn,
                        monthsRemaining: listing.shippingWeeks
                    ))
                    simulationTransactionHandler?(SimulationVehicleTransaction(
                        turn: resolvingTurn,
                        kind: .acquired,
                        storeID: bid.storeID,
                        source: .networkAuction,
                        category: listing.category,
                        count: 1,
                        revenue: 0,
                        cost: playerTotal
                    ))
                    notes.append("社員専用ネットAAで\(listing.vehicleName)を\(hammerPrice.currency)で落札しました（諸費用込み \(playerTotal.currency)）")
                }
            }
            let total = hammerPrice + listing.fee + listing.shippingCost
            settleInstructionReservation(
                instructionID: bid.instructionID,
                committedCost: committedCost,
                actualCost: status == .won ? total : nil,
                vehicleName: listing.vehicleName,
                source: .networkAuction,
                failureReason: status.name
            )
            networkAuctionBidResults.insert(NetworkAuctionBidResult(
                id: UUID(),
                listingID: listing.id,
                storeID: bid.storeID,
                modelID: listing.modelID,
                category: listing.category,
                modelYear: listing.modelYear,
                mileage: listing.mileage,
                maxPrice: bid.maxPrice,
                hammerPrice: hammerPrice,
                totalCost: total,
                status: status,
                winningCompetitorID: winningCompetitorID,
                resolvedTurn: resolvingTurn
            ), at: 0)
            attributeAuctionResolution(
                employeeID: bid.handlerEmployeeID,
                storeID: bid.storeID,
                succeeded: status == .won,
                predictedGrossProfit: status == .won ? max(0, listing.marketPrice - total) : 0
            )
            networkAuctionListings.removeAll { $0.id == listing.id }
            networkAuctionBidReservations.removeAll { $0.id == bid.id }
        }
        if networkAuctionBidResults.count > 20 {
            networkAuctionBidResults.removeLast(networkAuctionBidResults.count - 20)
        }
    }

    private func prepareCompetitorAuctionPlans() {
        competitorAuctionSlotsRemaining = [:]
        competitorAuctionBudgetRemaining = [:]
        for competitor in competitors {
            let slots = competitor.branches.reduce(0) { total, branch in
                let target = Int(ceil(Double(branch.capacity) * 0.60))
                return total + min(2, max(0, target - branch.inventoryCount))
            }
            competitorAuctionSlotsRemaining[competitor.id] = slots
            competitorAuctionBudgetRemaining[competitor.id] = max(0, competitor.cash * 40 / 100)
        }
    }

    private func competitorCanUseAuctionPlan(
        index: Int,
        totalCost: Int,
        usesRemainingPlan: Bool = true
    ) -> Bool {
        guard competitors.indices.contains(index) else { return false }
        let competitor = competitors[index]
        // 成約見込みは「この出品への競争」を示す値なので、直前の週次処理で
        // 使い切った競合の仕入れ枠には左右させない。実決済時だけ週次枠を使う。
        guard usesRemainingPlan else { return competitor.cash >= totalCost }
        let fallbackSlots = competitor.branches.reduce(0) { total, branch in
            let target = Int(ceil(Double(branch.capacity) * 0.60))
            return total + min(2, max(0, target - branch.inventoryCount))
        }
        let fallbackBudget = max(0, competitor.cash * 40 / 100)
        let slots = competitorAuctionSlotsRemaining[competitor.id] ?? fallbackSlots
        let budget = competitorAuctionBudgetRemaining[competitor.id] ?? fallbackBudget
        return slots > 0 && budget >= totalCost
    }

    private func consumeCompetitorAuctionPlan(index: Int, totalCost: Int) {
        guard competitors.indices.contains(index) else { return }
        let competitor = competitors[index]
        let id = competitor.id
        let fallbackSlots = competitor.branches.reduce(0) { total, branch in
            let target = Int(ceil(Double(branch.capacity) * 0.60))
            return total + min(2, max(0, target - branch.inventoryCount))
        }
        competitorAuctionSlotsRemaining[id] = max(0, (competitorAuctionSlotsRemaining[id] ?? fallbackSlots) - 1)
        competitorAuctionBudgetRemaining[id] = max(0, (competitorAuctionBudgetRemaining[id] ?? competitor.cash * 40 / 100) - totalCost)
    }

    private struct AuctionRivalBid {
        let competitorIndex: Int?
        let maxPrice: Int
    }

    private func auctionRivalBid(
        for listing: AuctionListing,
        seed: Int,
        usesRemainingPlan: Bool = true
    ) -> AuctionRivalBid? {
        let namedBid = competitorAuctionBid(
            for: listing,
            seed: seed,
            usesRemainingPlan: usesRemainingPlan
        ).map { AuctionRivalBid(competitorIndex: $0.competitorIndex, maxPrice: $0.maxPrice) }
        let marketBid = unaffiliatedWholesaleBid(
            category: listing.category,
            condition: listing.condition,
            fault: listing.fault,
            reservePrice: listing.reservePrice,
            marketPrice: listing.marketPrice,
            seed: seed + 4_099,
            onlineRisk: false
        ).map { AuctionRivalBid(competitorIndex: nil, maxPrice: $0) }
        return [namedBid, marketBid].compactMap { $0 }.max { $0.maxPrice < $1.maxPrice }
    }

    private func networkAuctionRivalBid(
        for listing: NetworkAuctionListing,
        seed: Int,
        usesRemainingPlan: Bool = true
    ) -> AuctionRivalBid? {
        let namedBid = competitorNetworkAuctionBid(
            for: listing,
            seed: seed,
            usesRemainingPlan: usesRemainingPlan
        ).map { AuctionRivalBid(competitorIndex: $0.competitorIndex, maxPrice: $0.maxPrice) }
        let marketBid = unaffiliatedWholesaleBid(
            category: listing.category,
            condition: listing.condition,
            fault: listing.fault,
            reservePrice: listing.reservePrice,
            marketPrice: listing.marketPrice,
            seed: seed + 5_033,
            onlineRisk: true
        ).map { AuctionRivalBid(competitorIndex: nil, maxPrice: $0) }
        return [namedBid, marketBid].compactMap { $0 }.max { $0.maxPrice < $1.maxPrice }
    }

    private func unaffiliatedWholesaleBid(
        category: VehicleCategory,
        condition: VehicleConditionProfile,
        fault: MechanicalFaultSeverity,
        reservePrice: Int,
        marketPrice: Int,
        seed: Int,
        onlineRisk: Bool
    ) -> Int? {
        // 一般流通の匿名業者は、専門設備が必要な重大故障・不動車には参加しない。
        // それらは従来どおり、整備環境と専門方針を持つ名前付き競合だけが判断する。
        guard fault != .major, fault != .immobile else { return nil }
        let categoryInterest: Double = switch category {
        case .kei: 0.48
        case .compact: 0.44
        case .sedan: 0.32
        case .minivan: 0.56
        case .suv: 0.52
        case .sports: 0.36
        case .pickup: 0.40
        }
        let conditionFactor = min(1.08, max(0.62, 0.62 + condition.quality * 0.46))
        let faultFactor: Double = switch fault {
        case .none: 1
        case .minor: 0.82
        case .major: 0.57
        case .immobile: 0.34
        }
        let onlineFactor = onlineRisk ? 0.78 : 1.0
        let demandFactor = min(1.35, max(0.70, competitorListingHeat(category: category)))
        let participation = min(
            0.88,
            max(0.06, categoryInterest * conditionFactor * faultFactor * onlineFactor * demandFactor)
        )
        guard transactionRoll(seed: seed) < participation else { return nil }

        // 名前付き競合の在庫枠とは別に、会場には市外の業者も参加する。
        // 開始価格と業者間相場の間で上限を作り、最低額の一律100%を防ぐ。
        let priceRoll = transactionRoll(seed: seed + 1_321)
        let marketCeiling = max(
            reservePrice + 1,
            Int((Double(marketPrice) * (0.90 + priceRoll * 0.16)).rounded())
        )
        let span = max(1, marketCeiling - reservePrice)
        let aggressiveness = 0.18 + transactionRoll(seed: seed + 2_357) * 0.82
        return reservePrice + max(1, Int((Double(span) * aggressiveness).rounded()))
    }

    private func competitorAuctionBid(
        for listing: AuctionListing,
        seed: Int,
        usesRemainingPlan: Bool = true
    ) -> (competitorIndex: Int, maxPrice: Int)? {
        let heat = competitorListingHeat(category: listing.category)
        let profiles = competitors.indices.compactMap { competitorIndex in
            competitorBidProfile(
                competitorIndex: competitorIndex,
                category: listing.category,
                condition: listing.condition,
                fault: listing.fault,
                modelID: listing.modelID,
                onlineRisk: false
            ).map { (competitorIndex: competitorIndex, profile: $0) }
        }
        let forcedCompetitor = competitorListingIsHot(category: listing.category, heat: heat)
            ? profiles.max(by: { $0.profile.score < $1.profile.score })?.competitorIndex
            : nil

        let bids = profiles.compactMap { entry -> (competitorIndex: Int, maxPrice: Int, interest: Double)? in
            let competitorIndex = entry.competitorIndex
            let competitor = competitors[competitorIndex]
            let availableCash = competitor.cash - listing.lane.fee - listing.lane.shippingCost
            guard availableCash >= listing.reservePrice else { return nil }
            guard competitorCanUseAuctionPlan(
                index: competitorIndex,
                totalCost: listing.reservePrice + listing.lane.fee + listing.lane.shippingCost,
                usesRemainingPlan: usesRemainingPlan
            ) else { return nil }
            let profitCeiling = competitorAuctionProfitCeiling(for: competitor, listing: listing)
            guard profitCeiling >= listing.reservePrice else { return nil }
            let participates = forcedCompetitor == competitorIndex
                || transactionRoll(seed: seed + competitorIndex * 997 + 83)
                    < competitorBidParticipationChance(
                        competitorIndex: competitorIndex,
                        profile: entry.profile,
                        heat: heat,
                        onlineRisk: false,
                        fault: listing.fault
                    )
            guard participates else { return nil }
            let interest = competitorAuctionInterest(competitor, listing: listing, seed: seed + competitorIndex * 31)
            let categoryFit = competitor.category == listing.category ? 0.09 : 0
            let strategyFit = competitorAuctionStrategyFit(competitor, category: listing.category)
            let variation = transactionRoll(seed: seed + competitorIndex * 47 + 19) * 0.22
            let willingness = min(1.24, max(0.78, 0.78 + categoryFit + strategyFit + variation + min(0.05, interest / 50)))
            let marketLimitedBid = Int((Double(listing.marketPrice) * willingness).rounded())
            let maxPrice = min(availableCash, min(profitCeiling, marketLimitedBid))
            guard maxPrice >= listing.reservePrice else { return nil }
            return (competitorIndex, maxPrice, interest)
        }
        return bids.max {
            $0.maxPrice == $1.maxPrice ? $0.interest < $1.interest : $0.maxPrice < $1.maxPrice
        }.map { ($0.competitorIndex, $0.maxPrice) }
    }

    private func competitorNetworkAuctionBid(
        for listing: NetworkAuctionListing,
        seed: Int,
        usesRemainingPlan: Bool = true
    ) -> (competitorIndex: Int, maxPrice: Int)? {
        let heat = competitorListingHeat(category: listing.category)
        let profiles = competitors.indices.compactMap { competitorIndex in
            competitorBidProfile(
                competitorIndex: competitorIndex,
                category: listing.category,
                condition: listing.condition,
                fault: listing.fault,
                modelID: listing.modelID,
                onlineRisk: true
            ).map { (competitorIndex: competitorIndex, profile: $0) }
        }
        let forcedCompetitor = competitorListingIsHot(category: listing.category, heat: heat)
            ? profiles.max(by: { $0.profile.score < $1.profile.score })?.competitorIndex
            : nil

        let bids = profiles.compactMap { entry -> (competitorIndex: Int, maxPrice: Int)? in
            let competitorIndex = entry.competitorIndex
            let competitor = competitors[competitorIndex]
            let availableCash = competitor.cash - listing.fee - listing.shippingCost
            guard availableCash >= listing.reservePrice else { return nil }
            guard competitorCanUseAuctionPlan(
                index: competitorIndex,
                totalCost: listing.reservePrice + listing.fee + listing.shippingCost,
                usesRemainingPlan: usesRemainingPlan
            ) else { return nil }
            let retail = competitor.plotIDs.compactMap { plot(id: $0)?.district }.map { district in
                vehicleRetailValue(
                    modelID: listing.modelID,
                    category: listing.category,
                    modelYear: listing.modelYear,
                    mileage: listing.mileage,
                    quality: listing.quality,
                    in: district
                )
            }.max() ?? 0
            let repair = estimatedSourcingRepairCost(
                category: listing.category,
                fault: listing.fault,
                condition: listing.condition,
                storeID: nil
            )
            let ceiling = retail - repair - listing.fee - listing.shippingCost - max(12, retail / 10)
            guard ceiling >= listing.reservePrice else { return nil }
            let participates = forcedCompetitor == competitorIndex
                || transactionRoll(seed: seed + competitorIndex * 991 + 97)
                    < competitorBidParticipationChance(
                        competitorIndex: competitorIndex,
                        profile: entry.profile,
                        heat: heat,
                        onlineRisk: true,
                        fault: listing.fault
                    )
            guard participates else { return nil }
            let fit = competitor.category == listing.category ? 0.10 : competitorAuctionStrategyFit(competitor, category: listing.category)
            let variation = transactionRoll(seed: seed + competitorIndex * 53 + 11) * 0.24
            let willingness = min(1.22, max(0.76, 0.80 + fit + variation))
            let maxPrice = min(availableCash, min(ceiling, Int(Double(listing.marketPrice) * willingness)))
            return maxPrice >= listing.reservePrice ? (competitorIndex, maxPrice) : nil
        }
        return bids.max { $0.maxPrice < $1.maxPrice }
    }

    private typealias CompetitorBidProfile = (
        branchIndex: Int,
        focus: Double,
        inventoryNeed: Double,
        customerFit: Double,
        score: Double
    )

    private func competitorBidProfile(
        competitorIndex: Int,
        category: VehicleCategory,
        condition: VehicleConditionProfile,
        fault: MechanicalFaultSeverity,
        modelID: String,
        onlineRisk: Bool
    ) -> CompetitorBidProfile? {
        guard competitors.indices.contains(competitorIndex) else { return nil }
        let competitor = competitors[competitorIndex]
        let categoryInventory = competitor.branches.reduce(0) { total, branch in
            total + branch.inventory
                .filter { $0.category == category }
                .reduce(0) { $0 + $1.count }
        }
        let totalInventory = competitor.branches.reduce(0) { $0 + $1.inventoryCount }
        let currentShare = Double(categoryInventory) / Double(max(1, totalInventory))
        let anyPriority = competitor.branches.contains {
            $0.marketPolicy.priorityCategories.contains(category)
        }
        let targetShare = competitor.targetInventoryShare[category]
            ?? (anyPriority ? 0.24 : 0.07)
        let inventoryNeed = min(1, max(0, 0.45 + (targetShare - currentShare) * 3.2))
        let origin = VehicleCatalog.entry(id: modelID)?.origin

        return competitor.branches.indices.compactMap { branchIndex -> CompetitorBidProfile? in
            let branch = competitor.branches[branchIndex]
            guard branch.inventoryCount < branch.capacity,
                  branch.marketPolicy.acceptedConditions.contains(condition.band) else { return nil }
            if onlineRisk, fault == .immobile,
               !branch.marketPolicy.acceptedConditions.contains(.faulty) {
                return nil
            }

            let isPriority = branch.marketPolicy.priorityCategories.contains(category)
            let isCoreCategory = isPriority || competitor.category == category
            if !isCoreCategory {
                // 専門外は、在庫を補う合理性があっても状態リスクまでは取らない。
                // 「何でも安ければ入札」にならないよう、通常・無故障車に限定する。
                guard condition.band == .normal, fault == .none else { return nil }
            }
            if fault == .major || fault == .immobile {
                guard branch.marketPolicy.acceptedConditions.contains(.faulty),
                      branch.facilities.contains(.serviceWorkshop) else { return nil }
            }
            var focus: Double
            if isCoreCategory {
                focus = 1
            } else {
                focus = max(
                    competitor.name == "ドライブMAX" ? 0.30 : 0.10,
                    0.16 + competitorAuctionStrategyFit(competitor, category: category) * 3
                )
            }
            if competitor.name == "プレミアモータース" {
                focus *= origin == .imported ? 1.12 : 0.88
            } else if competitor.name == "バリューオート", origin == .imported {
                focus *= 0.70
            }
            focus = min(1, max(0.05, focus))

            let customerFit = competitorCustomerCategoryFit(
                purpose: branch.marketPolicy.targetPurpose,
                category: category
            )
            let capacityNeed = 1 - Double(branch.inventoryCount) / Double(max(1, branch.capacity))
            let riskFit: Double
            switch (condition.band, fault) {
            case (.faulty, _), (_, .major), (_, .immobile):
                riskFit = branch.facilities.contains(.serviceWorkshop) ? 0.75 : 0.35
            case (.rough, _), (_, .minor):
                riskFit = 0.82
            default:
                riskFit = 1
            }
            let score = (
                focus * 0.47
                    + inventoryNeed * 0.25
                    + customerFit * 0.16
                    + capacityNeed * 0.12
            ) * riskFit
            guard isPriority || inventoryNeed >= 0.35 || score >= 0.42 else { return nil }
            return (
                branchIndex: branchIndex,
                focus: focus,
                inventoryNeed: inventoryNeed,
                customerFit: customerFit,
                score: score
            )
        }.max(by: { $0.score < $1.score })
    }

    private func competitorBidParticipationChance(
        competitorIndex: Int,
        profile: CompetitorBidProfile,
        heat: Double,
        onlineRisk: Bool,
        fault: MechanicalFaultSeverity
    ) -> Double {
        let competitor = competitors[competitorIndex]
        var chance = 0.03
            + profile.focus * 0.38
            + profile.inventoryNeed * 0.24
            + profile.customerFit * 0.10
        if profile.focus < 0.50 { chance *= 0.62 }
        chance += min(0.24, max(0, heat - 1) * 0.75)
        if onlineRisk {
            chance *= min(
                0.92,
                0.56
                    + Double(competitor.researchAbility) / 400
                    + Double(competitor.serviceAbility) / 650
            )
        }
        if fault == .major || fault == .immobile {
            chance *= 0.68
        }
        return min(heat >= 1.18 ? 0.92 : 0.82, max(0.03, chance))
    }

    private func competitorCustomerCategoryFit(
        purpose: CustomerPurpose,
        category: VehicleCategory
    ) -> Double {
        switch purpose {
        case .general:
            return [.kei, .compact, .minivan].contains(category) ? 1 : 0.62
        case .family:
            return [.minivan, .suv, .kei, .compact].contains(category) ? 1 : 0.42
        case .outdoor:
            return [.suv, .pickup, .minivan].contains(category) ? 1 : 0.35
        case .camper:
            return category == .minivan ? 1 : 0.25
        case .work, .mobileBusiness:
            return [.pickup, .minivan].contains(category) ? 1 : 0.28
        case .corporate:
            return [.sedan, .compact, .minivan].contains(category) ? 1 : 0.38
        case .performance:
            return [.sports, .sedan].contains(category) ? 1 : 0.22
        case .welfare:
            return [.minivan, .kei].contains(category) ? 1 : 0.30
        }
    }

    private func competitorListingHeat(category: VehicleCategory) -> Double {
        var heat = marketDemandIndex
        for competitor in competitors {
            for branch in competitor.branches {
                guard let district = plot(id: branch.plotID)?.district else { continue }
                heat = max(heat, vehicleDemand(category, in: district))
            }
        }
        for trend in segmentTrends
            where trend.categories.contains(category)
                && trend.startTurn <= turn
                && trend.endTurn > turn {
            heat = max(heat, trend.multiplier(at: turn))
        }
        return heat
    }

    private func competitorListingIsHot(category: VehicleCategory, heat: Double) -> Bool {
        if heat >= 1.45 || marketDemandIndex >= 1.18 { return true }
        return segmentTrends.contains {
            $0.categories.contains(category)
                && $0.startTurn <= turn
                && $0.endTurn > turn
                && $0.multiplier(at: turn) >= 1.12
        }
    }

    func competitorAuctionProfitCeiling(for competitor: Competitor, listing: AuctionListing) -> Int {
        let retailValues = competitor.plotIDs.compactMap { plot(id: $0)?.district }.map { district in
            vehicleRetailValue(
                modelID: listing.modelID,
                category: listing.category,
                modelYear: listing.modelYear,
                mileage: listing.mileage,
                quality: listing.quality,
                in: district
            )
        }
        guard let bestRetail = retailValues.max() else { return 0 }
        let categoryFit = competitor.category == listing.category
        let strategyFit = competitorAuctionStrategyFit(competitor, category: listing.category)
        let targetMargin = max(0.07, 0.15 - (categoryFit ? 0.035 : 0) - max(0, strategyFit) * 0.20 - competitor.strength * 0.015)
        let requiredProfit = Int((Double(bestRetail) * targetMargin).rounded())
        return max(0, bestRetail - requiredProfit - listing.lane.fee - listing.lane.shippingCost)
    }

    private func competitorAuctionStrategyFit(_ competitor: Competitor, category: VehicleCategory) -> Double {
        switch competitor.name {
        case "バリューオート": return [.kei, .compact, .minivan].contains(category) ? 0.07 : -0.05
        case "プレミアモータース": return [.sedan, .sports].contains(category) ? 0.12 : (category == .suv ? 0.04 : -0.06)
        default: return [.suv, .minivan, .pickup].contains(category) ? 0.08 : -0.02
        }
    }

    private func competitorAuctionInterest(_ competitor: Competitor, listing: AuctionListing, seed: Int) -> Double {
        let followedShare = competitor.targetInventoryShare[listing.category] ?? 0
        let specialty = competitor.category == listing.category ? 1.7 : 1.0 + followedShare * 0.9
        let scale = 0.75 + competitor.strength * 0.25
        return specialty * scale * (0.82 + transactionRoll(seed: seed) * 0.36)
    }

    func recordCompetitorAuctionPurchase(listing: AuctionListing, competitorIndex: Int, hammerPrice: Int, purchasedTurn: Int) {
        guard competitors.indices.contains(competitorIndex) else { return }
        let totalCost = hammerPrice + listing.lane.fee + listing.lane.shippingCost
        guard competitorCanUseAuctionPlan(index: competitorIndex, totalCost: totalCost),
              competitors[competitorIndex].cash >= totalCost,
              let branchIndex = competitors[competitorIndex].branches.indices
                .filter({ branchIndex in
                    let branch = competitors[competitorIndex].branches[branchIndex]
                    let target = Int(ceil(Double(branch.capacity) * 0.60))
                    return branch.inventoryCount < min(branch.capacity, target)
                })
                .max(by: {
                    let left = competitors[competitorIndex].branches[$0].marketPolicy.priorityCategories.contains(listing.category)
                    let right = competitors[competitorIndex].branches[$1].marketPolicy.priorityCategories.contains(listing.category)
                    return !left && right
                }) else { return }
        competitors[competitorIndex].cash -= totalCost
        addCompetitorInventory(competitorIndex: competitorIndex, branchIndex: branchIndex, category: listing.category, purpose: .general, count: 1, unitCost: totalCost, quality: listing.quality, productState: .stock)
        consumeCompetitorAuctionPlan(index: competitorIndex, totalCost: totalCost)
        competitorAuctionPurchases.insert(CompetitorAuctionPurchase(
            id: UUID(),
            listingID: listing.id,
            competitorID: competitors[competitorIndex].id,
            modelID: listing.modelID,
            category: listing.category,
            modelYear: listing.modelYear,
            mileage: listing.mileage,
            hammerPrice: hammerPrice,
            purchasedTurn: purchasedTurn
        ), at: 0)
        if competitorAuctionPurchases.count > 240 {
            competitorAuctionPurchases.removeLast(competitorAuctionPurchases.count - 240)
        }
    }

    private func recordCompetitorNetworkAuctionPurchase(
        listing: NetworkAuctionListing,
        competitorIndex: Int,
        hammerPrice: Int,
        purchasedTurn: Int
    ) {
        guard competitors.indices.contains(competitorIndex) else { return }
        let totalCost = hammerPrice + listing.fee + listing.shippingCost
        guard competitorCanUseAuctionPlan(index: competitorIndex, totalCost: totalCost),
              competitors[competitorIndex].cash >= totalCost,
              let branchIndex = competitors[competitorIndex].branches.indices
                .filter({ branchIndex in
                    let branch = competitors[competitorIndex].branches[branchIndex]
                    let target = Int(ceil(Double(branch.capacity) * 0.60))
                    return branch.inventoryCount < min(branch.capacity, target)
                })
                .max(by: {
                    let left = competitors[competitorIndex].branches[$0].marketPolicy.priorityCategories.contains(listing.category)
                    let right = competitors[competitorIndex].branches[$1].marketPolicy.priorityCategories.contains(listing.category)
                    return !left && right
                }) else { return }
        competitors[competitorIndex].cash -= totalCost
        addCompetitorInventory(
            competitorIndex: competitorIndex,
            branchIndex: branchIndex,
            category: listing.category,
            purpose: .general,
            count: 1,
            unitCost: totalCost,
            quality: listing.quality,
            productState: .stock
        )
        consumeCompetitorAuctionPlan(index: competitorIndex, totalCost: totalCost)
        competitorAuctionPurchases.insert(CompetitorAuctionPurchase(
            id: UUID(),
            listingID: listing.id,
            competitorID: competitors[competitorIndex].id,
            modelID: listing.modelID,
            category: listing.category,
            modelYear: listing.modelYear,
            mileage: listing.mileage,
            hammerPrice: hammerPrice,
            purchasedTurn: purchasedTurn
        ), at: 0)
    }

    private func addCompetitorInventory(
        competitorIndex: Int,
        branchIndex: Int,
        category: VehicleCategory,
        purpose: CustomerPurpose,
        count: Int,
        unitCost: Int,
        quality: Double,
        productState: VehicleProductState,
        marketProductKind: MarketProductKind? = nil,
        productGrade: SpecialtyProductGrade? = nil
    ) {
        guard competitors.indices.contains(competitorIndex), competitors[competitorIndex].branches.indices.contains(branchIndex), count > 0 else { return }
        let resolvedProductKind = marketProductKind ?? MarketProductKind.resolve(productState: productState, isRareClassic: false)
        if let bucketIndex = competitors[competitorIndex].branches[branchIndex].inventory.firstIndex(where: {
            $0.category == category
                && $0.purpose == purpose
                && $0.productState == productState
                && $0.marketProductKind == resolvedProductKind
                && $0.productGrade == productGrade
        }) {
            let old = competitors[competitorIndex].branches[branchIndex].inventory[bucketIndex]
            let newCount = old.count + count
            competitors[competitorIndex].branches[branchIndex].inventory[bucketIndex].averageCost = (old.averageCost * old.count + unitCost * count) / max(1, newCount)
            competitors[competitorIndex].branches[branchIndex].inventory[bucketIndex].averageQuality = (old.averageQuality * Double(old.count) + quality * Double(count)) / Double(max(1, newCount))
            competitors[competitorIndex].branches[branchIndex].inventory[bucketIndex].count = newCount
        } else {
            competitors[competitorIndex].branches[branchIndex].inventory.append(CompetitorInventoryBucket(
                category: category,
                purpose: purpose,
                count: count,
                averageCost: unitCost,
                averageQuality: quality,
                productState: productState,
                marketProductKind: resolvedProductKind,
                productGrade: productGrade
            ))
        }
    }

    private func resolveCompetitorAuctionPurchases(at resolvingTurn: Int, notes: inout [String]) {
        let listings = auctionListings
            .filter { listing in
                listing.createdTurn < resolvingTurn
                    && !bidReservations.contains(where: { $0.listingID == listing.id })
            }
            .sorted { $0.createdTurn < $1.createdTurn }
        var purchaseCounts: [UUID: Int] = [:]
        for listing in listings.prefix(7) {
            let seed = resolvingTurn * 359 + listing.modelYear * 17 + listing.mileage / 1_000
            guard let rivalBid = competitorAuctionBid(for: listing, seed: seed) else { continue }
            recordCompetitorAuctionPurchase(listing: listing, competitorIndex: rivalBid.competitorIndex, hammerPrice: rivalBid.maxPrice, purchasedTurn: resolvingTurn)
            purchaseCounts[competitors[rivalBid.competitorIndex].id, default: 0] += 1
            auctionListings.removeAll { $0.id == listing.id }
        }
        guard !purchaseCounts.isEmpty,
              stores.contains(where: { hasMarketResearcher(storeID: $0.id) }) else { return }
        let summary = purchaseCounts.map { "\(competitorName(for: $0.key)) \($0.value)台" }.sorted().joined(separator: "、")
        notes.append("市場調査：今週の競合AA仕入れは\(summary)")
    }

    private func settleAuctionConsignments(notes: inout [String]) {
        for index in auctionConsignments.indices { auctionConsignments[index].monthsRemaining -= 1 }
        let settled = auctionConsignments.filter { $0.monthsRemaining <= 0 }
        for order in settled {
            let variation = 94 + ((turn * 13 + order.count * 7 + categoryIndex(order.category)) % 15)
            let proceeds = max(0, order.expectedUnitPrice * order.count * variation / 100 - order.lane.fee * order.count)
            cash += proceeds
            notes.append("\(order.lane.name)への出品車 \(order.vehicleName)\(order.count)台が成約し、\(proceeds.currency)を受け取りました")
            auctionConsignments.removeAll { $0.id == order.id }
        }
    }

    private func addInventory(
        category: VehicleCategory,
        modelID: String?,
        origin: VehicleOrigin? = nil,
        count: Int,
        unitCost: Int,
        quality: Double,
        modelYear: Int?,
        mileage: Int?,
        condition: VehicleConditionProfile? = nil,
        fault: MechanicalFaultSeverity = .none,
        faultRevealed: Bool = true,
        acquiredTurn: Int,
        to storeIndex: Int
    ) {
        for offset in 0..<count {
            let qualityVariation = Double((turn + offset * 5 + categoryIndex(category)) % 7 - 3) / 100
            let model = modelID.flatMap(VehicleCatalog.entry(id:))
                ?? vehicleModel(for: category, origin: origin, seed: turn * 127 + stores[storeIndex].plotID * 19 + offset * 37)
            let profile = usedVehicleProfile(for: model, seed: turn * 149 + stores[storeIndex].plotID * 29 + offset * 41, maximumAge: 10)
            let resolvedYear = modelYear ?? profile.modelYear
            let resolvedMileage = mileage ?? profile.mileage
            let resolvedQuality = modelYear == nil || mileage == nil
                ? min(0.94, max(0.45, profile.quality * 0.70 + quality * 0.30 + qualityVariation))
                : min(0.94, max(0.45, quality))
            stores[storeIndex].inventory.append(InventoryBatch(
                modelID: model.id,
                category: category,
                count: 1,
                averageCost: unitCost,
                quality: resolvedQuality,
                modelYear: resolvedYear,
                mileage: resolvedMileage,
                acquiredTurn: acquiredTurn,
                condition: condition,
                fault: fault,
                faultRevealed: faultRevealed
            ))
        }
    }

    private func generateAuctionListings() {
        let targetCount = 72
        if turn > 0 {
            auctionListings.removeAll()
        }
        let legendary = VehicleCatalog.rareClassics.first { $0.collectorRarity == .legendary }
        let legendaryDue = turn > 0 && (turn + abs(simulationSeed % 24)).isMultiple(of: 24)
        let legendaryAlreadyListed = auctionListings.contains {
            VehicleCatalog.entry(id: $0.modelID)?.collectorRarity == .legendary
        }
        if legendaryDue, !legendaryAlreadyListed, let model = legendary {
            let profile = usedVehicleProfile(for: model, seed: turn * 1_009 + simulationSeed)
            let vehicleState = sourcingVehicleState(
                quality: profile.quality,
                seed: turn * 1_021 + simulationSeed,
                faultRate: 0.06
            )
            let market = vehicleWholesaleValue(
                modelID: model.id,
                category: model.category,
                modelYear: profile.modelYear,
                mileage: profile.mileage,
                quality: vehicleState.condition.quality,
                in: .downtown
            )
            auctionListings.append(AuctionListing(
                id: UUID(),
                lane: .premium,
                modelID: model.id,
                category: model.category,
                modelYear: profile.modelYear,
                mileage: profile.mileage,
                quality: vehicleState.condition.quality,
                condition: vehicleState.condition,
                fault: vehicleState.fault,
                reservePrice: max(6_000, market * 92 / 100),
                marketPrice: market,
                seller: "名門コレクション放出・伝説級",
                createdTurn: turn
            ))
            recordCityEvent(CityEvent(
                turn: turn,
                kind: .auction,
                title: "伝説級クラシックが出品",
                detail: "\(model.fullName)が都心プレミアAAへ出品されました"
            ))
        }
        while auctionListings.count < targetCount {
            let index = auctionListings.count + turn * 5
            let availableCombinations = VehicleCategory.allCases.flatMap { category in
                availableOrigins(for: category)
                    .sorted { $0.rawValue < $1.rawValue }
                    .map { (category: category, origin: $0) }
            }
            let missingCombination = availableCombinations.first { combination in
                !auctionListings.contains {
                    $0.category == combination.category
                        && VehicleCatalog.entry(id: $0.modelID)?.origin == combination.origin
                        && VehicleCatalog.entry(id: $0.modelID)?.isRareClassic == false
                }
            }
            var lane = AuctionLane.allCases[index % AuctionLane.allCases.count]
            let categories: [VehicleCategory]
            switch lane {
            case .standard: categories = [.kei, .compact, .minivan]
            case .logistics: categories = [.pickup, .suv, .minivan, .sedan]
            case .premium: categories = [.sports, .sports, .sedan, .suv]
            }
            let classicCandidates = VehicleCatalog.rareClassics.filter {
                $0.collectorRarity == .rare && categories.contains($0.category)
            }
            let isRareClassicListing = !classicCandidates.isEmpty && abs(index + turn * 17).isMultiple(of: 41)
            let model: VehicleCatalogEntry
            if isRareClassicListing {
                model = classicCandidates[abs(index * 7 + turn * 3) % classicCandidates.count]
            } else if let missingCombination,
                      let missingModel = vehicleModelIfAvailable(
                        for: missingCombination.category,
                        origin: missingCombination.origin,
                        seed: index * 43 + turn * 101
                      ) {
                model = missingModel
                lane = auctionLane(for: missingModel)
            } else {
                let normalCategory = categories[(index / 2 + turn) % categories.count]
                let premiumOrigin: VehicleOrigin? = lane == .premium
                    ? ((index % 5) < 3 ? .imported : .domestic)
                    : nil
                model = vehicleModel(
                    for: normalCategory,
                    origin: premiumOrigin,
                    seed: index * 43 + (index / 3) * 17 + turn * 101
                )
            }
            let category = model.category
            let profile = usedVehicleProfile(
                for: model,
                seed: index * 173 + turn * 109 + 31,
                maximumAge: lane == .premium ? 6 : 14
            )
            let pricingDistrict: DistrictKind = lane == .premium ? .downtown : lane == .logistics ? .industrial : .station
            let calculatedMarket = vehicleWholesaleValue(
                modelID: model.id,
                category: category,
                modelYear: profile.modelYear,
                mileage: profile.mileage,
                quality: profile.quality,
                in: pricingDistrict
            )
            var vehicleState = sourcingVehicleState(
                quality: profile.quality,
                seed: index * 197 + turn * 131,
                faultRate: 0.14
            )
            let faultDiscount = sourcingFaultDiscount(vehicleState.fault)
            let rawMarket = max(18, Int(Double(calculatedMarket) * faultDiscount))
            let market: Int
            let reserve: Int
            if model.isRareClassic {
                market = rawMarket
                reserve = max(28, market * (78 + (index % 13)) / 100)
            } else {
                var retail = DistrictKind.allCases.map {
                    vehicleRetailValue(
                        modelID: model.id,
                        category: category,
                        modelYear: profile.modelYear,
                        mileage: profile.mileage,
                        quality: vehicleState.condition.quality,
                        in: $0
                    )
                }.min() ?? category.purchaseCost * 13 / 10
                var repair = estimatedSourcingRepairCost(
                    category: category,
                    fault: vehicleState.fault,
                    condition: vehicleState.condition,
                    storeID: nil
                )
                let fixedCosts = lane.fee + lane.listingPricingShippingAllowance
                let minimumReserve = 10
                let minimumGross = Int((Double(retail) * 0.15).rounded())
                if vehicleState.fault != .none,
                   retail - repair - fixedCosts - minimumReserve < minimumGross {
                    // 安価な車両に重故障を組み合わせると、開始価格まで下げても
                    // 修理費込みで赤字が確定する。検査済みAAの通常枠では、
                    // そのような車両は出品前検査で除外する。
                    vehicleState = (condition: vehicleState.condition, fault: .none)
                    retail = DistrictKind.allCases.map {
                        vehicleRetailValue(
                            modelID: model.id,
                            category: category,
                            modelYear: profile.modelYear,
                            mileage: profile.mileage,
                            quality: vehicleState.condition.quality,
                            in: $0
                        )
                    }.min() ?? category.purchaseCost * 13 / 10
                    repair = 0
                }
                // AAは開始価格なら15〜25%程度の上振れ余地を持たせ、
                // 競り上がった業者間相場では概ね-5〜12%まで振れる。
                let reserveMargin = 0.15 + transactionRoll(
                    seed: index * 229 + turn * 163 + categoryIndex(category) * 19
                ) * 0.10
                let marketMargin = -0.05 + transactionRoll(
                    seed: index * 233 + turn * 167 + categoryIndex(category) * 23
                ) * 0.17
                let reserveCeiling = max(
                    10,
                    retail
                        - Int((Double(retail) * reserveMargin).rounded())
                        - repair
                        - fixedCosts
                )
                let marketTarget = max(
                    reserveCeiling,
                    retail
                        - Int((Double(retail) * marketMargin).rounded())
                        - repair
                        - fixedCosts
                )
                reserve = reserveCeiling
                market = max(reserve, marketTarget)
            }
            let seller = isRareClassicListing
                ? "コレクター放出・現状渡し"
                : lane == .premium ? "輸入車正規店・下取車" : (index.isMultiple(of: 3) ? "法人リース" : "中古車業者")
            auctionListings.append(AuctionListing(
                id: UUID(),
                lane: lane,
                modelID: model.id,
                category: category,
                modelYear: profile.modelYear,
                mileage: profile.mileage,
                quality: vehicleState.condition.quality,
                condition: vehicleState.condition,
                fault: vehicleState.fault,
                reservePrice: reserve,
                marketPrice: market,
                seller: seller,
                createdTurn: turn
            ))
        }
    }

    private func auctionLane(for model: VehicleCatalogEntry) -> AuctionLane {
        if model.isRareClassic { return .premium }
        if model.origin == .imported {
            return [.minivan, .pickup].contains(model.category) ? .logistics : .premium
        }
        return switch model.category {
        case .kei, .compact, .minivan: .standard
        case .pickup: .logistics
        case .sedan, .suv, .sports: .premium
        }
    }

    private func auctionLane(for category: VehicleCategory) -> AuctionLane {
        switch category {
        case .kei, .compact, .minivan: .standard
        case .pickup: .logistics
        case .sedan, .suv, .sports: .premium
        }
    }

    private func sourcingVehicleState(
        quality: Double,
        seed: Int,
        faultRate: Double
    ) -> (condition: VehicleConditionProfile, fault: MechanicalFaultSeverity) {
        let base = min(94, max(32, Int((quality * 100).rounded())))
        let hasFault = transactionRoll(seed: seed + 17) < faultRate
        let fault: MechanicalFaultSeverity
        if hasFault {
            let roll = transactionRoll(seed: seed + 23)
            fault = roll < 0.18 ? .immobile : (roll < 0.50 ? .major : .minor)
        } else {
            fault = .none
        }
        let condition = VehicleConditionProfile(
            exterior: max(25, base - Int(transactionRoll(seed: seed + 29) * 12)),
            interior: max(25, base - Int(transactionRoll(seed: seed + 31) * 10)),
            mechanical: max(15, base - fault.requiredWork * 8)
        )
        return (condition, fault)
    }

    private func sourcingFaultDiscount(_ fault: MechanicalFaultSeverity) -> Double {
        switch fault {
        case .none: 1
        case .minor: 0.78
        case .major: 0.48
        case .immobile: 0.25
        }
    }

    private func generateNetworkAuctionListings() {
        let targetCount = 144
        if turn > 0 {
            networkAuctionListings.removeAll()
        }
        while networkAuctionListings.count < targetCount {
            let index = networkAuctionListings.count + turn * 7
            let availableCombinations = VehicleCategory.allCases.flatMap { category in
                availableOrigins(for: category)
                    .sorted { $0.rawValue < $1.rawValue }
                    .map { (category: category, origin: $0) }
            }
            let missingCombination = availableCombinations.first { combination in
                !networkAuctionListings.contains {
                    $0.category == combination.category
                        && VehicleCatalog.entry(id: $0.modelID)?.origin == combination.origin
                }
            }
            let category = missingCombination?.category
                ?? VehicleCategory.allCases[(index * 5 + turn) % VehicleCategory.allCases.count]
            let model = vehicleModel(
                for: category,
                origin: missingCombination?.origin,
                seed: index * 73 + turn * 149
            )
            let profile = usedVehicleProfile(
                for: model,
                seed: index * 181 + turn * 127 + 47,
                maximumAge: 16
            )
            let kind: NetworkAuctionListingKind = index.isMultiple(of: 4) ? .opportunity : .flowStock
            var vehicleState = sourcingVehicleState(
                quality: profile.quality,
                seed: index * 211 + turn * 157,
                faultRate: kind == .flowStock ? 0.08 : 0.36
            )
            if kind == .flowStock {
                vehicleState = (condition: vehicleState.condition, fault: .none)
            }
            let premiumShipping = model.origin == .imported || category == .pickup
            let fee = 9
            let shippingCost = premiumShipping ? 6 : 4
            let listingPricingShippingAllowance = premiumShipping ? 18 : 12
            let cleanRetail = DistrictKind.allCases.map {
                vehicleRetailValue(
                    modelID: model.id,
                    category: category,
                    modelYear: profile.modelYear,
                    mileage: profile.mileage,
                    quality: vehicleState.condition.quality,
                    in: $0
                )
            }.min() ?? category.purchaseCost * 13 / 10
            // 流通補充枠は検査済みで、最安地域の想定小売に対して2〜10%の粗利を残す。
            // 機会枠は従来どおり状態リスクと上振れ余地を併せ持つ。
            let reserveMargin = kind == .flowStock
                ? 0.02 + transactionRoll(seed: index * 239 + turn * 173) * 0.08
                : 0.12 + transactionRoll(seed: index * 239 + turn * 173 + categoryIndex(category) * 29) * 0.13
            let marketMargin = kind == .flowStock
                ? reserveMargin
                : transactionRoll(seed: index * 241 + turn * 179 + categoryIndex(category) * 31) * 0.12
            let pricingShippingCost = kind == .flowStock
                ? shippingCost
                : listingPricingShippingAllowance
            let pricingRepairCost = kind == .flowStock
                ? estimatedSourcingRepairCost(
                    category: category,
                    fault: vehicleState.fault,
                    condition: vehicleState.condition,
                    storeID: nil
                )
                : 0
            let reserveTarget = cleanRetail
                - Int((Double(cleanRetail) * reserveMargin).rounded())
                - pricingRepairCost
                - fee
                - pricingShippingCost
            let marketTarget = cleanRetail
                - Int((Double(cleanRetail) * marketMargin).rounded())
                - pricingRepairCost
                - fee
                - pricingShippingCost
            let reserve = max(10, reserveTarget)
            let market = max(reserve, marketTarget)
            networkAuctionListings.append(NetworkAuctionListing(
                id: UUID(),
                modelID: model.id,
                category: category,
                modelYear: profile.modelYear,
                mileage: profile.mileage,
                quality: vehicleState.condition.quality,
                condition: vehicleState.condition,
                fault: vehicleState.fault,
                reservePrice: reserve,
                marketPrice: market,
                seller: kind == .flowStock ? "全国流通センター・検査済" : "全国整備工場・現状車",
                fee: fee,
                shippingCost: shippingCost,
                shippingWeeks: premiumShipping ? 2 : 1,
                kind: kind,
                createdTurn: turn
            ))
        }
    }

    private func save() {
        refreshGuideProgress()
        guard persistenceEnabled else { return }
        var snapshot = SaveData(year: year, month: month, weekOfMonth: weekOfMonth, turn: turn, cash: cash, debt: debt, companyValue: companyValue, districts: districts, plots: plots, stores: stores, competitors: competitors, reports: reports, monthlyReports: monthlyReports, purchaseCases: purchaseCases, customerCustomizationOrders: customerCustomizationOrders, buyerLeads: buyerLeads, cityEvents: cityEvents, auctionListings: auctionListings, bidReservations: bidReservations, auctionBidResults: auctionBidResults, networkAuctionListings: networkAuctionListings, networkAuctionBidReservations: networkAuctionBidReservations, networkAuctionBidResults: networkAuctionBidResults, procurementInstructions: procurementInstructions, competitorAuctionPurchases: competitorAuctionPurchases, inboundShipments: inboundShipments, auctionConsignments: auctionConsignments, pendingCustomerClaims: pendingCustomerClaims, finance: finance, unlockedFeatures: unlockedFeatures, regionalOperations: regionalOperations, intercityShipments: intercityShipments, nationalBrandStrength: nationalBrandStrength, gasolinePrice: gasolinePrice, nikkeiAverage: nikkeiAverage, classicMarketIndex: classicMarketIndex, marketDemandIndex: marketDemandIndex, gasolineTrendTarget: gasolineTrendTarget, nikkeiTrendTarget: nikkeiTrendTarget, demandTrendTarget: demandTrendTarget, gasolineMomentum: gasolineMomentum, nikkeiMomentum: nikkeiMomentum, demandMomentum: demandMomentum, activeMarketShocks: activeMarketShocks, careerStatistics: careerStatistics, priceWarChallenges: priceWarChallenges, tutorialStep: tutorialStep, tutorialPlotID: tutorialPlotID, financialDistressWeeks: financialDistressWeeks, companyExpertise: companyExpertise, corporateOpportunities: corporateOpportunities, segmentMarkets: segmentMarkets, segmentTrends: segmentTrends, simulationSeed: simulationSeed, openSegmentWeek: openSegmentWeek, guide: guide)
        snapshot.mapID = CityMapDefinition.suihama.id
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
            pendingSave = snapshot
            hasSaveData = true
        }
    }

    private func prepareDemoCompany() {
        startNewGame()
        guard let plot = foundingCandidatePlots.first(where: { $0.district == .suburb }) ?? recommendedFoundingPlot else { return }
        selectFoundingPlot(plot.id)
        _ = buildStore(
            on: plot,
            type: .standard,
            mode: .lease,
            marketPolicy: StoreMarketPolicy(targetPurpose: .family),
            facilities: [.kidsSpace],
            loanAmount: StoreFacility.kidsSpace.installationCost
        )
        if let store = stores.first {
            for category in recommendedCategories(for: plot.district).prefix(2) {
                _ = buyInventory(category: category, count: 2, storeID: store.id)
            }
        }
        completeTutorial()
    }

    private func placeCompetitors() {
        let assignments: [(district: DistrictKind, competitorIndex: Int)] = [
            (.downtown, 0), (.station, 1), (.emerging, 2),
            (.suburb, 2), (.industrial, 0), (.highway, 1)
        ]
        for assignment in assignments {
            guard competitors.indices.contains(assignment.competitorIndex) else { continue }
            let candidates = plots.filter {
                $0.district == assignment.district
                    && $0.development == nil
                    && $0.structure != .vacant
                    && isAvailable($0.occupant)
            }
            guard let candidate = candidates.max(by: { lhs, rhs in
                let lhsScore = lhs.visibility * 0.30 + lhs.access * 0.30 + lhs.traffic * 0.40
                let rhsScore = rhs.visibility * 0.30 + rhs.access * 0.30 + rhs.traffic * 0.40
                if lhsScore == rhsScore { return lhs.id > rhs.id }
                return lhsScore < rhsScore
            }),
                  let plotIndex = plots.firstIndex(where: { $0.id == candidate.id }) else { continue }
            let company = competitors[assignment.competitorIndex]
            competitors[assignment.competitorIndex].branches.append(initialCompetitorBranch(plotID: candidate.id, competitor: company))
            plots[plotIndex].occupant = .competitor(
                name: competitors[assignment.competitorIndex].name
            )
        }
    }

    private func initialCompetitorBranch(plotID: Int, competitor: Competitor) -> CompetitorBranch {
        let secondary: VehicleCategory
        let purpose: CustomerPurpose
        let priceIndex: Double
        let facilities: Set<StoreFacility>
        switch competitor.name {
        case "バリューオート":
            secondary = .kei; purpose = .general; priceIndex = 0.92; facilities = [.serviceWorkshop]
        case "プレミアモータース":
            secondary = .suv; purpose = .general; priceIndex = 1.15; facilities = [.serviceWorkshop]
        default:
            secondary = .minivan; purpose = .outdoor; priceIndex = 1.03; facilities = [.customWorkshop]
        }
        let buckets = [
            CompetitorInventoryBucket(category: competitor.category, purpose: purpose, count: 7, averageCost: competitor.category.purchaseCost, averageQuality: 0.78, productState: purpose == .outdoor ? .outdoor : .serviced),
            CompetitorInventoryBucket(category: secondary, purpose: purpose, count: 4, averageCost: secondary.purchaseCost, averageQuality: 0.74, productState: .stock)
        ]
        var expertise = BusinessExpertise()
        expertise.add(category: competitor.category, purpose: purpose, source: .auction, points: 18)
        let accepted: Set<VehicleConditionBand> = competitor.name == "バリューオート" ? [.normal, .rough, .faulty] : [.normal, .rough]
        return CompetitorBranch(
            plotID: plotID,
            capacity: 28,
            inventory: buckets,
            priceIndex: priceIndex,
            advertising: competitor.name == "バリューオート" ? 150 : 110,
            reputation: 0.70 + competitor.strength * 0.08,
            facilities: facilities,
            marketPolicy: StoreMarketPolicy(priorityCategories: [competitor.category, secondary], targetPurpose: purpose, acceptedConditions: accepted),
            expertise: expertise,
            lastRevenue: 0,
            lastProfit: 0
        )
    }

    private func nicheCategories(for kind: MarketProductKind) -> [VehicleCategory] {
        switch kind {
        case .repaired:
            return VehicleCategory.allCases
        case .workCargo:
            return [.minivan, .pickup]
        case .outdoor:
            return [.suv, .pickup, .minivan]
        case .camper:
            return [.minivan]
        case .refurbished:
            return [.sedan]
        case .collector:
            return Array(Set(VehicleCatalog.rareClassics.map(\.category))).sorted { $0.rawValue < $1.rawValue }
        case .sportTuned:
            return [.sports]
        case .welfare:
            return [.kei, .compact, .minivan]
        case .mobileShop:
            return [.minivan, .pickup]
        case .standard:
            return VehicleCategory.allCases
        }
    }

    func baseNicheDemandShare(for kind: MarketProductKind, in district: DistrictKind) -> Double {
        switch kind {
        case .repaired:
            return 0.07
        case .workCargo:
            return [.industrial, .highway].contains(district) ? 0.055 : 0.035
        case .outdoor:
            return [.suburb, .highway].contains(district) ? 0.045 : 0.025
        case .camper:
            return [.suburb, .highway].contains(district) ? 0.025 : 0.015
        case .refurbished:
            return [.downtown, .emerging].contains(district) ? 0.015 : 0.006
        case .collector:
            return [.downtown, .emerging].contains(district) ? 0.008 : 0.003
        case .sportTuned:
            return [.downtown, .emerging, .highway].contains(district) ? 0.018 : 0.010
        case .welfare:
            return [.suburb, .station].contains(district) ? 0.020 : 0.012
        case .mobileShop:
            return [.downtown, .station, .industrial, .highway].contains(district) ? 0.018 : 0.010
        case .standard:
            return 0
        }
    }

    private func hasFourWeekNicheDemandFloor(
        productKind: MarketProductKind,
        district: DistrictKind
    ) -> Bool {
        switch productKind {
        case .repaired:
            true
        case .workCargo:
            [.industrial, .highway].contains(district)
        case .outdoor:
            [.suburb, .highway].contains(district)
        case .welfare:
            true
        case .mobileShop:
            [.downtown, .station, .industrial, .highway].contains(district)
        case .sportTuned:
            [.downtown, .emerging, .highway].contains(district)
        case .standard, .refurbished, .camper, .collector:
            false
        }
    }

    private func categoryDemandWeight(_ category: VehicleCategory, among categories: [VehicleCategory], in district: DistrictKind) -> Double {
        let weights = categories.map { max(0.08, vehicleDemand($0, in: district)) }
        let total = weights.reduce(0, +)
        guard let index = categories.firstIndex(of: category), total > 0 else { return 0 }
        return weights[index] / total
    }

    private func registerSegmentDemand(_ key: MarketSegmentKey) {
        var record = openSegmentWeek[key] ?? SegmentWeekRecord(turn: turn)
        record.demand += 1
        openSegmentWeek[key] = record
    }

    private func registerSegmentUnmet(_ key: MarketSegmentKey) {
        var record = openSegmentWeek[key] ?? SegmentWeekRecord(turn: turn)
        record.unmetDemand += 1
        openSegmentWeek[key] = record
    }

    private func registerPlayerSegmentSale(
        storeID: UUID,
        _ key: MarketSegmentKey,
        revenue: Int,
        cost: Int
    ) {
        var record = openSegmentWeek[key] ?? SegmentWeekRecord(turn: turn)
        record.playerSales += 1
        record.playerRevenue += revenue
        record.playerCost += cost
        openSegmentWeek[key] = record
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }) else { return }
        var records = stores[storeIndex].segmentRecords[key] ?? []
        if let lastIndex = records.indices.last, records[lastIndex].turn == turn {
            records[lastIndex].playerSales += 1
            records[lastIndex].playerRevenue += revenue
            records[lastIndex].playerCost += cost
        } else {
            records.append(SegmentWeekRecord(
                turn: turn,
                playerSales: 1,
                playerRevenue: revenue,
                playerCost: cost
            ))
        }
        stores[storeIndex].segmentRecords[key] = Array(records.suffix(16))
    }

    private func registerCompetitorSegmentSale(
        competitorIndex: Int,
        _ key: MarketSegmentKey,
        revenue: Int,
        cost: Int
    ) {
        var record = openSegmentWeek[key] ?? SegmentWeekRecord(turn: turn)
        record.competitorSales += 1
        record.competitorRevenue += revenue
        record.competitorCost += cost
        openSegmentWeek[key] = record
        guard competitors.indices.contains(competitorIndex) else { return }
        var records = competitors[competitorIndex].segmentRecords[key] ?? []
        if let lastIndex = records.indices.last, records[lastIndex].turn == turn {
            records[lastIndex].competitorSales += 1
            records[lastIndex].competitorRevenue += revenue
            records[lastIndex].competitorCost += cost
        } else {
            records.append(SegmentWeekRecord(
                turn: turn,
                competitorSales: 1,
                competitorRevenue: revenue,
                competitorCost: cost
            ))
        }
        competitors[competitorIndex].segmentRecords[key] = Array(records.suffix(16))
    }

    private func segmentKey(for lead: BuyerLead) -> MarketSegmentKey {
        let district = stores.first(where: { $0.id == lead.storeID })
            .flatMap { plot(id: $0.plotID)?.district } ?? .suburb
        return MarketSegmentKey(
            district: district,
            category: lead.desiredCategory ?? .compact,
            purpose: lead.purpose,
            productKind: lead.desiredProductKind
        )
    }

    private func generateSegmentBuyer(
        district: DistrictKind,
        category: VehicleCategory,
        purpose: CustomerPurpose,
        productKind: MarketProductKind,
        seed: Int
    ) {
        let key = MarketSegmentKey(district: district, category: category, purpose: purpose, productKind: productKind)
        let desiredGrade = requestedSpecialtyGrade(for: key, seed: seed + 263)
        registerSegmentDemand(key)
        let preference: BuyerVehiclePreference = .category(category)
        guard let storeID = assignedStore(
            in: district,
            buyerPreference: preference,
            buyerPurpose: purpose,
            buyerProductKind: productKind,
            buyerGrade: desiredGrade,
            sellerCategory: nil,
            seed: seed
        ) else {
            if !competitorHandlesBuyer(category: category, purpose: purpose, productKind: productKind, desiredGrade: desiredGrade, district: district, seed: seed) {
                registerSegmentUnmet(key)
            }
            return
        }
        buyerLeads.append(makeBuyerLead(
            storeID: storeID,
            preference: preference,
            purpose: purpose,
            productKind: productKind,
            grade: desiredGrade,
            seed: seed
        ))
        if let storeIndex = stores.firstIndex(where: { $0.id == storeID }) {
            stores[storeIndex].weeklyBuyerArrivals = stores[storeIndex].buyerArrivalsThisWeek + 1
        }
    }

    private func generateWeeklyCustomerLeads(forceTutorialStoreID: UUID? = nil) {
        buyerLeads.removeAll()
        purchaseCases.removeAll()
        customerCustomizationOrders.removeAll { $0.status == .pending }
        openSegmentWeek = [:]
        for index in stores.indices {
            stores[index].weeklyBuyerArrivals = 0
            stores[index].weeklySellerArrivals = 0
        }

        for (districtIndex, kind) in DistrictKind.allCases.enumerated() {
            let totalBuyerPool = weeklyBuyerPool(in: kind)
            let nicheKinds = MarketProductKind.allCases.filter(\.isNiche)
            let baselineNicheShare = nicheKinds.reduce(0.0) { $0 + baseNicheDemandShare(for: $1, in: kind) }
            let standardCount = max(0, totalBuyerPool - Int((Double(totalBuyerPool) * baselineNicheShare).rounded()))
            for offset in 0..<standardCount {
                let seed = turn * 10_007 + districtIndex * 997 + offset * 61 + 17
                let preference = leadPreference(in: kind, seed: seed + 23)
                let purpose = defaultCustomerPurpose(for: preference.category, seed: seed + 29)
                generateSegmentBuyer(
                    district: kind,
                    category: preference.category ?? .compact,
                    purpose: purpose,
                    productKind: .standard,
                    seed: seed
                )
            }

            for (kindIndex, productKind) in nicheKinds.enumerated() {
                let categories = nicheCategories(for: productKind)
                for (categoryOffset, category) in categories.enumerated() {
                    let purpose = productKind.customerPurpose
                    let key = MarketSegmentKey(district: kind, category: category, purpose: purpose, productKind: productKind)
                    let expected = Double(totalBuyerPool)
                        * baseNicheDemandShare(for: productKind, in: kind)
                        * categoryDemandWeight(category, among: categories, in: kind)
                        * activeTrendMultiplier(for: key)
                    var state = segmentMarkets[key] ?? SegmentMarketState()
                    state.demandCarry += expected
                    let generated = Int(state.demandCarry.rounded(.down))
                    state.demandCarry -= Double(generated)
                    segmentMarkets[key] = state
                    for offset in 0..<generated {
                        let seed = turn * 12_011
                            + districtIndex * 1_103
                            + kindIndex * 149
                            + categoryOffset * 47
                            + offset * 71
                            + simulationSeed
                        generateSegmentBuyer(
                            district: kind,
                            category: category,
                            purpose: purpose,
                            productKind: productKind,
                            seed: seed
                        )
                    }
                }
            }

            for offset in 0..<weeklySellerPool(in: kind) {
                let seed = turn * 11_003 + districtIndex * 1_009 + offset * 67 + 41
                let category = sellerCategory(in: kind, seed: seed + 31)
                guard let storeID = assignedStore(in: kind, buyerPreference: nil, buyerPurpose: nil, buyerProductKind: nil, sellerCategory: category, seed: seed) else {
                    competitorHandlesSeller(category: category, district: kind, seed: seed)
                    continue
                }
                guard
                      let store = stores.first(where: { $0.id == storeID }),
                      let storePlot = plot(id: store.plotID) else { continue }
                purchaseCases.append(makePurchaseCase(storeID: storeID, plot: storePlot, category: category, seed: seed))
                if let storeIndex = stores.firstIndex(where: { $0.id == storeID }) {
                    stores[storeIndex].weeklySellerArrivals = stores[storeIndex].sellerArrivalsThisWeek + 1
                }
            }
        }

        // The service workshop also handles appraisal intake, guaranteeing two
        // additional weekly opportunities on top of its +24% seller attraction.
        for store in stores where store.isOperational && store.facilities.contains(.serviceWorkshop) {
            guard let storeIndex = stores.firstIndex(where: { $0.id == store.id }),
                  let storePlot = plot(id: store.plotID) else { continue }
            var added = 0
            var attempt = 0
            while added < 2 && attempt < 20 {
                let pendingCount = purchaseCases.filter { $0.storeID == store.id }.reduce(0) { $0 + $1.lotCount }
                let freeCapacity = store.type.capacity - store.inventoryCount - incomingCount(for: store.id) - pendingCount
                guard freeCapacity > 0 else { break }
                let seed = turn * 13_019 + store.plotID * 137 + attempt * 73
                attempt += 1
                let category = sellerCategory(in: storePlot.district, seed: seed + 31)
                guard store.marketPolicy.acceptedConditions.contains(sellerConditionBand(seed: seed)) else { continue }
                let item = makePurchaseCase(storeID: store.id, plot: storePlot, category: category, seed: seed)
                purchaseCases.append(item)
                stores[storeIndex].weeklySellerArrivals = stores[storeIndex].sellerArrivalsThisWeek + 1
                added += 1
            }
        }

        generateSpecialtyReferralPurchaseCases()
        generateCustomerCustomizationOrders()
        generateCertifiedSpecialtyDestinationLeads()

        if let storeID = forceTutorialStoreID,
           let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
           let storePlot = plot(id: stores[storeIndex].plotID) {
            let category = recommendedCategories(for: storePlot.district).first ?? .compact
            if !buyerLeads.contains(where: { $0.storeID == storeID }) {
                let purpose = defaultCustomerPurpose(for: category, seed: storePlot.id * 101 + 7)
                let key = MarketSegmentKey(district: storePlot.district, category: category, purpose: purpose, productKind: .standard)
                registerSegmentDemand(key)
                buyerLeads.append(makeBuyerLead(storeID: storeID, preference: .category(category), purpose: purpose, seed: storePlot.id * 101 + 7))
                stores[storeIndex].weeklyBuyerArrivals = stores[storeIndex].buyerArrivalsThisWeek + 1
            }
            if !purchaseCases.contains(where: { $0.storeID == storeID }) {
                purchaseCases.append(makePurchaseCase(storeID: storeID, plot: storePlot, category: category, seed: storePlot.id * 103 + 13))
                stores[storeIndex].weeklySellerArrivals = stores[storeIndex].sellerArrivalsThisWeek + 1
            }
        }
    }

    private func generateCertifiedSpecialtyDestinationLeads() {
        for storeIndex in stores.indices where stores[storeIndex].isOperational {
            let store = stores[storeIndex]
            guard let plot = plot(id: store.plotID) else { continue }
            for productKind in [MarketProductKind.sportTuned, .collector] {
                let tier = specialtyCertificationTier(for: store, productKind: productKind)
                guard tier > 0 else { continue }
                let pool = referralModelPool(for: productKind, store: store)
                guard !pool.isEmpty else { continue }
                for offset in 0..<tier {
                    let seed = turn * 29_011
                        + store.plotID * 521
                        + offset * 113
                        + (productKind == .collector ? 17 : 0)
                        + simulationSeed
                    let model = pool[abs(seed) % pool.count]
                    let preference: BuyerVehiclePreference = productKind == .collector
                        ? .exactModel(model.id)
                        : detailedBuyerPreference(from: .category(.sports), seed: seed + 23)
                    let lead = makeBuyerLead(
                        storeID: store.id,
                        preference: preference,
                        purpose: productKind.customerPurpose,
                        productKind: productKind,
                        seed: seed
                    )
                    buyerLeads.append(lead)
                    stores[storeIndex].weeklyBuyerArrivals += 1
                    let key = MarketSegmentKey(
                        district: plot.district,
                        category: model.category,
                        purpose: productKind.customerPurpose,
                        productKind: productKind
                    )
                    registerSegmentDemand(key)
                }
            }
        }
    }

    private func specialtyReferralProduct(for store: Store) -> MarketProductKind? {
        switch store.marketPolicy.targetPurpose {
        case .performance: return .sportTuned
        case .welfare: return .welfare
        case .mobileBusiness: return .mobileShop
        case .camper: return .camper
        case .work, .corporate: return .workCargo
        case .outdoor: return .outdoor
        case .general, .family:
            let restorationExpertise = store.expertise.project(.refurbishment)
                + companyExpertise.project(.refurbishment) * 0.25
            return restorationExpertise >= 15 ? .collector : nil
        }
    }

    private func referralProjectKind(for productKind: MarketProductKind, seed: Int) -> WorkshopProjectKind {
        let roll = transactionRoll(seed: seed + 701)
        return switch productKind {
        case .sportTuned: roll < 0.50 ? .streetTuning : (roll < 0.80 ? .driftTuning : .circuitTuning)
        case .welfare: roll < 0.55 ? .liftSeatConversion : .wheelchairConversion
        case .mobileShop: roll < 0.55 ? .mobileSalesConversion : .kitchenCarConversion
        case .camper: .camperConversion
        case .workCargo: .workConversion
        case .outdoor: .outdoorConversion
        case .collector, .refurbished: .refurbishment
        case .standard: .basicService
        case .repaired: .repair
        }
    }

    private func referralModelPool(for productKind: MarketProductKind, store: Store) -> [VehicleCatalogEntry] {
        let available = VehicleCatalog.available(through: turn)
        let pool: [VehicleCatalogEntry] = switch productKind {
        case .sportTuned: available.filter { $0.isSportTuningBase && !$0.isRareClassic }
        case .welfare: available.filter { [.kei, .compact, .minivan].contains($0.category) && !$0.isRareClassic }
        case .mobileShop: available.filter { [.minivan, .pickup].contains($0.category) && !$0.isRareClassic }
        case .camper: available.filter { $0.category == .minivan && !$0.isRareClassic }
        case .workCargo: available.filter { [.minivan, .pickup].contains($0.category) && !$0.isRareClassic }
        case .outdoor: available.filter { [.suv, .pickup, .minivan].contains($0.category) && !$0.isRareClassic }
        case .collector: VehicleCatalog.rareClassics
        case .standard, .repaired, .refurbished: []
        }
        let preferred = pool.filter { store.marketPolicy.priorityCategories.contains($0.category) }
        return preferred.isEmpty ? pool : preferred
    }

    private func generateSpecialtyReferralPurchaseCases() {
        for storeIndex in stores.indices where stores[storeIndex].isOperational {
            let store = stores[storeIndex]
            guard let plot = plot(id: store.plotID),
                  let productKind = specialtyReferralProduct(for: store) else { continue }
            let brandProject = brandProjectKind(for: productKind)
            let hasSpecialtyFacility = brandProject.usesCustomizationBay
                ? store.facilities.contains(.customWorkshop)
                : store.facilities.contains(.serviceWorkshop)
            guard hasSpecialtyFacility,
                  store.employees.contains(where: { $0.assignment == .service }) else { continue }
            let readiness = specialtyReadiness(for: store, productKind: productKind)
            guard readiness >= 0.50 else { continue }
            let certificationTier = specialtyCertificationTier(for: store, productKind: productKind)
            let referralMultiplier = certificationTier > 0 ? certificationTier + 1 : 1
            if productKind == .collector {
                let rareRoll = transactionRoll(seed: turn * 17_417 + store.plotID * 211 + simulationSeed)
                guard rareRoll < min(0.64, 0.16 * Double(referralMultiplier)) else { continue }
            }
            let pool = referralModelPool(for: productKind, store: store)
            guard !pool.isEmpty else { continue }
            let representative = pool[abs(turn * 31 + store.plotID) % pool.count]
            let trendKey = MarketSegmentKey(
                district: plot.district,
                category: representative.category,
                purpose: productKind.customerPurpose,
                productKind: productKind
            )
            let trendLift = max(0, activeTrendMultiplier(for: trendKey) - 1)
            let referralCap = productKind == .collector ? 4 : (productKind == .sportTuned ? 8 : 5)
            let desiredCount = min(
                referralCap,
                max(1, Int((readiness * 4 + trendLift).rounded(.down))) * referralMultiplier
            )
            var added = 0
            var attempt = 0
            while added < desiredCount && attempt < desiredCount * 4 {
                let pending = purchaseCases.filter { $0.storeID == store.id }.reduce(0) { $0 + $1.lotCount }
                guard store.inventoryCount + incomingCount(for: store.id) + pending < store.type.capacity else { break }
                let seed = turn * 19_019 + store.plotID * 313 + attempt * 83 + simulationSeed
                attempt += 1
                guard store.marketPolicy.acceptedConditions.contains(sellerConditionBand(seed: seed)) else { continue }
                let model = pool[abs(seed) % pool.count]
                let project = referralProjectKind(for: productKind, seed: seed)
                let key = MarketSegmentKey(
                    district: plot.district,
                    category: model.category,
                    purpose: productKind.customerPurpose,
                    productKind: productKind
                )
                let premium = min(
                    1.24,
                    1.04 + readiness * 0.10
                        + min(0.06, max(0, activeTrendMultiplier(for: key) - 1) * 0.03)
                        + transactionRoll(seed: seed + 719) * 0.04
                )
                purchaseCases.append(makePurchaseCase(
                    storeID: store.id,
                    plot: plot,
                    category: model.category,
                    seed: seed,
                    preferredModel: model,
                    origin: .specialtyReferral,
                    suggestedProjectKind: project,
                    askingPremium: premium
                ))
                stores[storeIndex].weeklySellerArrivals += 1
                added += 1
            }
        }
    }

    private func customizationOrderTerms(
        kind: WorkshopProjectKind,
        grade: SpecialtyProductGrade,
        model: VehicleCatalogEntry,
        store: Store,
        district: DistrictKind
    ) -> (cost: Int, work: Int, revenue: Int) {
        let rateAndWork: (Double, Int) = switch kind {
        case .streetTuning: (0.22, 5)
        case .driftTuning: (0.38, 7)
        case .circuitTuning: (0.55, 9)
        case .liftSeatConversion: (0.22, 5)
        case .wheelchairConversion: (0.40, 8)
        case .mobileSalesConversion: (0.30, 6)
        case .kitchenCarConversion: (0.60, 10)
        case .camperConversion: (1.80, 10)
        case .workConversion: (0.22, 5)
        case .outdoorConversion: (0.18, 4)
        case .refurbishment: (model.isRareClassic ? 0.52 : 0.28, 6)
        case .basicService: (0.06, 1)
        case .repair: (0.18, 3)
        }
        let materialCost = max(20, Int(Double(model.referenceRetailPrice) * rateAndWork.0 * grade.costMultiplier))
        let state = kind.productState ?? .stock
        let productKind = MarketProductKind.resolve(productState: state, isRareClassic: model.isRareClassic)
        let key = MarketSegmentKey(
            district: district,
            category: model.category,
            purpose: state.purpose ?? store.marketPolicy.targetPurpose,
            productKind: productKind
        )
        let readiness = specialtyReadiness(for: store, productKind: productKind)
        let trend = segmentWillingnessFactor(for: key, store: store, productState: state, grade: grade)
        let revenue = max(
            materialCost + 35,
            Int(Double(materialCost) * (1.35 + readiness * 0.50) * trend)
        )
        let completionTarget = kind.usesCustomizationBay ? grade.rank + 2 : 1
        let work = min(kind.maximumWorkWeeks, max(1, completionTarget - kind.completionInspectionWeeks))
        return (materialCost, work, revenue)
    }

    private func generateCustomerCustomizationOrders() {
        for store in stores where store.isOperational
            && store.employees.contains(where: { $0.assignment == .service }) {
            guard let plot = plot(id: store.plotID),
                  let productKind = specialtyReferralProduct(for: store) else { continue }
            let requiredFacility: StoreFacility = productKind == .collector ? .serviceWorkshop : .customWorkshop
            guard store.facilities.contains(requiredFacility) else { continue }
            let readiness = specialtyReadiness(for: store, productKind: productKind)
            guard readiness >= 0.50 else { continue }
            let certificationTier = specialtyCertificationTier(for: store, productKind: productKind)
            let orderMultiplier = certificationTier > 0 ? certificationTier + 1 : 1
            let pool = referralModelPool(for: productKind, store: store)
            guard !pool.isEmpty else { continue }
            let representative = pool[abs(turn * 47 + store.plotID) % pool.count]
            let key = MarketSegmentKey(
                district: plot.district,
                category: representative.category,
                purpose: productKind.customerPurpose,
                productKind: productKind
            )
            let orderCap = productKind == .collector ? 4.0 : (productKind == .sportTuned ? 6.0 : 3.0)
            let expected = min(
                orderCap,
                0.35 + Double(weeklyBuyerPool(in: plot.district))
                    * max(0.018, baseNicheDemandShare(for: productKind, in: plot.district))
                    * readiness
                    * activeTrendMultiplier(for: key)
                    * 0.75
                    * Double(orderMultiplier)
            )
            let whole = Int(expected.rounded(.down))
            let fractional = expected - Double(whole)
            let extra = transactionRoll(seed: turn * 23_021 + store.plotID * 419 + simulationSeed) < fractional ? 1 : 0
            let count = min(Int(orderCap), whole + extra)
            for offset in 0..<count {
                let seed = turn * 23_123 + store.plotID * 431 + offset * 97 + simulationSeed
                let model = pool[abs(seed) % pool.count]
                let kind = referralProjectKind(for: productKind, seed: seed)
                let gradeKey = MarketSegmentKey(
                    district: plot.district,
                    category: model.category,
                    purpose: productKind.customerPurpose,
                    productKind: productKind
                )
                let grade = requestedSpecialtyGrade(for: gradeKey, seed: seed + 809) ?? .low
                let terms = customizationOrderTerms(kind: kind, grade: grade, model: model, store: store, district: plot.district)
                customerCustomizationOrders.append(CustomerCustomizationOrder(
                    id: UUID(),
                    storeID: store.id,
                    modelID: model.id,
                    category: model.category,
                    kind: kind,
                    grade: grade,
                    quotedRevenue: terms.revenue,
                    materialCost: terms.cost,
                    requiredWork: terms.work,
                    remainingWork: terms.work,
                    generatedTurn: turn,
                    expiresTurn: turn + 1,
                    startedTurn: nil,
                    priority: 1,
                    status: .pending
                ))
            }
        }
    }

    private func assignedStore(
        in kind: DistrictKind,
        buyerPreference: BuyerVehiclePreference?,
        buyerPurpose: CustomerPurpose?,
        buyerProductKind: MarketProductKind?,
        buyerGrade: SpecialtyProductGrade? = nil,
        sellerCategory: VehicleCategory?,
        seed: Int
    ) -> UUID? {
        let forSeller = sellerCategory != nil
        var choices: [(storeID: UUID?, weight: Double)] = []
        for store in stores where store.isOperational && plot(id: store.plotID)?.district == kind {
            guard let storePlot = plot(id: store.plotID) else { continue }
            let weight: Double
            if forSeller {
                let freeCapacity = store.type.capacity - store.inventoryCount - incomingCount(for: store.id)
                guard freeCapacity > 0 else { continue }
                guard store.marketPolicy.acceptedConditions.contains(sellerConditionBand(seed: seed)) else { continue }
                let location = storePlot.visibility * storePlot.access * storePlot.traffic
                let marketing = advertisingAttractionFactor(store.advertising)
                    * employeeMarketingEfficiency(for: store.id, buyers: false)
                weight = max(
                    0.05,
                    store.reputation * location * marketing * (0.8 + store.serviceAllocation * 0.4)
                        * store.customerReviewAttraction(for: .seller)
                        * sellerAttractionFactor(for: store, category: sellerCategory ?? .compact)
                )
            } else {
                let desiredCategory = buyerPreference?.category
                let matchingInventory = store.inventory.reduce(0) { total, batch in
                    guard batch.count > 0, !batch.isInWorkshop, !batch.isReserved,
                          desiredCategory == nil || batch.category == desiredCategory,
                          buyerProductKind == nil || marketProductMatches(actual: marketProductKind(for: batch), desired: buyerProductKind!),
                          gradeMatches(actual: batch.productGrade, desired: buyerGrade) else {
                        return total
                    }
                    return total + batch.count
                }
                let nicheReadiness: Double
                if buyerProductKind?.isNiche == true {
                    let policyFit = store.marketPolicy.targetPurpose == buyerPurpose
                        || store.marketPolicy.priorityCategories.contains(desiredCategory ?? .compact)
                    nicheReadiness = matchingInventory > 0
                        ? 1 + min(0.60, Double(matchingInventory) * 0.16)
                        : (policyFit ? 0.32 : 0.05)
                } else {
                    nicheReadiness = 1 + min(0.18, Double(matchingInventory) * 0.03)
                }
                let repositioning = store.marketRepositioningWeeks > 0
                    ? (store.marketRepositioningWeeks == 2 ? 0.60 : 0.80)
                    : 1.0
                let desiredKey = MarketSegmentKey(
                    district: kind,
                    category: desiredCategory ?? .compact,
                    purpose: buyerPurpose ?? .general,
                    productKind: buyerProductKind ?? .standard
                )
                let referral = regionalNicheLeaderKey(for: store) == desiredKey ? 1.10 : 1.0
                let specialtyBrand = specialtyBrandAttractionMultiplier(for: store, key: desiredKey)
                weight = storeMarketWeight(store, plot: storePlot)
                    * buyerAttractionFactor(for: store, category: desiredCategory, purpose: buyerPurpose)
                    * (store.marketPolicy.targetPurpose == buyerPurpose ? 1.18 : 0.92)
                    * nicheReadiness
                    * repositioning
                    * referral
                    * specialtyBrand
            }
            choices.append((store.id, weight))
        }
        for competitor in competitors {
            for competitorPlot in competitor.plotIDs.compactMap({ plot(id: $0) }) where competitorPlot.district == kind {
                let weight = forSeller
                    ? competitor.strength * competitorPlot.visibility * competitorPlot.access * competitorPlot.traffic
                    : competitorMarketWeight(competitor, plot: competitorPlot)
                choices.append((nil, max(0.05, weight)))
            }
        }
        let total = choices.reduce(0.0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var cursor = transactionRoll(seed: seed) * total
        for choice in choices {
            cursor -= choice.weight
            if cursor <= 0 { return choice.storeID }
        }
        return choices.last?.storeID
    }

    private func sellerConditionBand(seed: Int) -> VehicleConditionBand {
        let roll = transactionRoll(seed: seed + 149)
        if roll < 0.14 { return .faulty }
        if roll < 0.34 { return .rough }
        return .normal
    }

    @discardableResult
    private func competitorHandlesBuyer(
        category: VehicleCategory,
        purpose: CustomerPurpose,
        productKind: MarketProductKind,
        desiredGrade: SpecialtyProductGrade?,
        district: DistrictKind,
        seed: Int
    ) -> Bool {
        let candidates = competitors.indices.flatMap { competitorIndex in
            competitors[competitorIndex].branches.indices.compactMap { branchIndex -> (Int, Int, Int, Double)? in
                let branch = competitors[competitorIndex].branches[branchIndex]
                guard plot(id: branch.plotID)?.district == district,
                      let bucketIndex = branch.inventory.firstIndex(where: {
                          $0.category == category
                              && $0.count > 0
                              && marketProductMatches(actual: $0.marketProductKind, desired: productKind)
                              && gradeMatches(actual: $0.productGrade, desired: desiredGrade)
                      }) else { return nil }
                let bucket = branch.inventory[bucketIndex]
                let purposeFit = bucket.purpose == purpose ? 1.18 : 0.88
                let score = purposeFit * branch.reputation * (1 + Double(branch.advertising) / 600) * (0.85 + competitors[competitorIndex].strength * 0.15)
                return (competitorIndex, branchIndex, bucketIndex, score)
            }
        }
        guard !candidates.isEmpty else { return false }
        let total = candidates.reduce(0.0) { $0 + $1.3 }
        var cursor = transactionRoll(seed: seed + 311) * total
        let selected = candidates.first(where: { candidate in cursor -= candidate.3; return cursor <= 0 }) ?? candidates[0]
        let competitorIndex = selected.0, branchIndex = selected.1, bucketIndex = selected.2
        let bucket = competitors[competitorIndex].branches[branchIndex].inventory[bucketIndex]
        let purposeFactor = bucket.purpose == purpose ? 1.08 : 0.96
        let key = MarketSegmentKey(district: district, category: category, purpose: purpose, productKind: productKind)
        let uncappedPrice = max(25, Int(Double(bucket.averageCost)
            * (1.22 + competitors[competitorIndex].strength * 0.10)
            * competitors[competitorIndex].branches[branchIndex].priceIndex
            * purposeFactor
            * segmentWillingnessFactor(for: key, productState: bucket.productState, grade: bucket.productGrade)))
        let price = bucket.marketProductKind.supportsGrades
            ? min(uncappedPrice, competitorSpecialtyPriceCap(for: bucket))
            : uncappedPrice
        competitors[competitorIndex].branches[branchIndex].inventory[bucketIndex].count -= 1
        competitors[competitorIndex].cash += price
        competitors[competitorIndex].branches[branchIndex].currentRevenue += price
        competitors[competitorIndex].branches[branchIndex].currentProfit += price - bucket.averageCost
        competitors[competitorIndex].expertise.add(category: category, purpose: purpose, points: 1)
        registerCompetitorSegmentSale(
            competitorIndex: competitorIndex,
            key,
            revenue: price,
            cost: bucket.averageCost
        )
        return true
    }

    private func competitorHandlesSeller(category: VehicleCategory, district: DistrictKind, seed: Int) {
        let band = sellerConditionBand(seed: seed)
        let candidates = competitors.indices.flatMap { competitorIndex in
            competitors[competitorIndex].branches.indices.compactMap { branchIndex -> (Int, Int, Double)? in
                let branch = competitors[competitorIndex].branches[branchIndex]
                guard plot(id: branch.plotID)?.district == district,
                      branch.inventoryCount < branch.capacity,
                      branch.marketPolicy.acceptedConditions.contains(band) else { return nil }
                let focus = branch.marketPolicy.priorityCategories.contains(category) ? 1.25 : 0.88
                return (competitorIndex, branchIndex, focus * branch.reputation * Double(competitors[competitorIndex].procurementAbility) / 70)
            }
        }
        guard let selected = candidates.max(by: { $0.2 < $1.2 }) else { return }
        let quality: Double = switch band { case .normal: 0.76; case .rough: 0.58; case .faulty: 0.42 }
        let cost = max(10, Int(Double(category.purchaseCost) * (0.40 + quality * 0.55)))
        guard competitors[selected.0].cash >= cost else { return }
        competitors[selected.0].cash -= cost
        addCompetitorInventory(competitorIndex: selected.0, branchIndex: selected.1, category: category, purpose: .general, count: 1, unitCost: cost, quality: quality, productState: .stock)
        competitors[selected.0].expertise.add(category: category, purpose: .general, source: .storePurchase, points: 1)
    }

    @discardableResult
    private func competitorFulfillsBuyerLead(_ lead: BuyerLead) -> Bool {
        guard let offer = lead.competitorOffer,
              let competitorIndex = competitors.firstIndex(where: { $0.id == offer.competitorID }) else { return false }
        for branchIndex in competitors[competitorIndex].branches.indices {
            guard let bucketIndex = competitors[competitorIndex].branches[branchIndex].inventory.firstIndex(where: {
                $0.category == offer.category
                    && $0.count > 0
                    && marketProductMatches(actual: $0.marketProductKind, desired: lead.desiredProductKind)
                    && gradeMatches(actual: $0.productGrade, desired: lead.desiredGrade)
            }) else { continue }
            let cost = competitors[competitorIndex].branches[branchIndex].inventory[bucketIndex].averageCost
            competitors[competitorIndex].branches[branchIndex].inventory[bucketIndex].count -= 1
            competitors[competitorIndex].cash += offer.price
            competitors[competitorIndex].branches[branchIndex].currentRevenue += offer.price
            competitors[competitorIndex].branches[branchIndex].currentProfit += offer.price - cost
            competitors[competitorIndex].expertise.add(category: offer.category, purpose: lead.purpose, points: 1)
            let district = plot(id: competitors[competitorIndex].branches[branchIndex].plotID)?.district ?? .suburb
            let key = MarketSegmentKey(district: district, category: offer.category, purpose: lead.purpose, productKind: lead.desiredProductKind)
            registerCompetitorSegmentSale(
                competitorIndex: competitorIndex,
                key,
                revenue: offer.price,
                cost: cost
            )
            return true
        }
        return false
    }

    private func leadCategory(in kind: DistrictKind, seed: Int) -> VehicleCategory {
        guard let district = districts.first(where: { $0.kind == kind }) else { return .compact }
        let weighted = VehicleCategory.allCases.map { category -> (VehicleCategory, Double) in
            let demand = district.demands[category] ?? 0.42
            let economyMultiplier: Double
            switch category {
            case .sedan, .suv, .sports: economyMultiplier = 0.72 + economicIndex * 0.28
            case .kei, .compact: economyMultiplier = 1.20 - (economicIndex - 0.8) * 0.22
            default: economyMultiplier = 0.88 + economicIndex * 0.12
            }
            let broadDemand = category == .compact ? 1.16 : (category == .kei ? 1.04 : 1.0)
            return (category, max(0.05, demand * economyMultiplier * broadDemand))
        }
        let total = weighted.reduce(0.0) { $0 + $1.1 }
        var cursor = transactionRoll(seed: seed) * total
        for (category, weight) in weighted {
            cursor -= weight
            if cursor <= 0 { return category }
        }
        return weighted.last?.0 ?? .compact
    }

    func sellerCategory(in kind: DistrictKind, seed: Int) -> VehicleCategory {
        guard let district = districts.first(where: { $0.kind == kind }) else { return .compact }
        let weighted = VehicleCategory.allCases.map { category in
            let ownershipTurnover: Double
            switch category {
            case .kei: ownershipTurnover = 0.92
            case .compact: ownershipTurnover = 1.0
            case .sedan: ownershipTurnover = 0.86
            case .minivan: ownershipTurnover = 0.98
            case .suv: ownershipTurnover = 0.90
            case .pickup: ownershipTurnover = 0.76
            case .sports: ownershipTurnover = 0.72
            }
            let highIncomeTurnover = [.sedan, .suv, .sports].contains(category)
                ? 0.88 + district.incomeIndex * 0.24
                : 1.0
            let supply = district.supplies[category] ?? 0.58
            let demand = district.demands[category] ?? 0.58
            let balancedAvailability = supply * 0.60 + demand * 0.40
            return (
                category,
                max(0.08, balancedAvailability * ownershipTurnover * highIncomeTurnover)
            )
        }
        let total = weighted.reduce(0.0) { $0 + $1.1 }
        var cursor = transactionRoll(seed: seed) * total
        for (category, weight) in weighted {
            cursor -= weight
            if cursor <= 0 { return category }
        }
        return weighted.last?.0 ?? .compact
    }

    private func leadPreference(in kind: DistrictKind, seed: Int) -> BuyerVehiclePreference {
        return .category(leadCategory(in: kind, seed: seed))
    }

    private func makeBuyerLead(
        storeID: UUID,
        preference: BuyerVehiclePreference,
        purpose requestedPurpose: CustomerPurpose? = nil,
        productKind: MarketProductKind = .standard,
        grade requestedGrade: SpecialtyProductGrade? = nil,
        seed: Int
    ) -> BuyerLead {
        let storePlot = stores.first(where: { $0.id == storeID }).flatMap { plot(id: $0.plotID) }
        let localDistrict = storePlot?.district ?? .suburb
        let localIncome = storePlot.map { district(for: $0).incomeIndex } ?? 1.0
        let incomeBudgetFactor = min(1.24, max(0.84, 1 + (localIncome - 1) * 0.46))
        let resolvedPreference = productKind == .collector
            ? collectorBuyerPreference(category: preference.category ?? .sports, seed: seed + 401)
            : detailedBuyerPreference(from: preference, seed: seed + 401)
        let budget: Int
        let minimumQuality: Double
        let minimumModelYear: Int
        let maximumMileage: Int
        let priceSensitivity: Double
        switch resolvedPreference {
        case .category(let category):
            let budgetRate = 1.13 + transactionRoll(seed: seed + 3) * 0.42
            budget = max(35, Int(Double(category.purchaseCost) * budgetRate * incomeBudgetFactor))
            minimumQuality = 0.56 + transactionRoll(seed: seed + 5) * 0.28
            minimumModelYear = max(2000, year - 12)
            maximumMileage = 140_000
            priceSensitivity = 0.82 + transactionRoll(seed: seed + 7) * 0.36
        case .categoryOrigin(let category, let origin):
            let representative = VehicleCatalog.available(through: turn)
                .filter { $0.category == category && $0.origin == origin && !$0.isRareClassic }
                .max { $0.customerDemandIndex < $1.customerDemandIndex }
            let reference = representative.map {
                vehicleRetailValue(modelID: $0.id, category: category, modelYear: year - 3, mileage: 38_000, quality: 0.84, in: localDistrict)
            } ?? Int(Double(category.purchaseCost) * (origin == .imported ? 2.0 : 1.4))
            budget = max(60, Int(Double(reference) * (0.86 + transactionRoll(seed: seed + 3) * 0.30) * incomeBudgetFactor))
            minimumQuality = 0.70 + transactionRoll(seed: seed + 5) * 0.20
            minimumModelYear = max(2000, year - 5 - Int(transactionRoll(seed: seed + 9) * 4))
            maximumMileage = 45_000 + Int(transactionRoll(seed: seed + 11) * 65_000)
            priceSensitivity = 0.76 + transactionRoll(seed: seed + 7) * 0.32
        case .maker(let category, let maker):
            let representative = VehicleCatalog.available(through: turn)
                .filter { $0.category == category && $0.maker == maker && !$0.isRareClassic }
                .max { $0.customerDemandIndex < $1.customerDemandIndex }
            let reference = representative.map {
                vehicleRetailValue(modelID: $0.id, category: category, modelYear: year - 2, mileage: 32_000, quality: 0.86, in: localDistrict)
            } ?? Int(Double(category.purchaseCost) * 1.4)
            budget = max(80, Int(Double(reference) * (0.88 + transactionRoll(seed: seed + 3) * 0.27) * incomeBudgetFactor))
            minimumQuality = 0.74 + transactionRoll(seed: seed + 5) * 0.18
            minimumModelYear = max(2000, year - 3 - Int(transactionRoll(seed: seed + 9) * 4))
            maximumMileage = 35_000 + Int(transactionRoll(seed: seed + 11) * 55_000)
            priceSensitivity = 0.72 + transactionRoll(seed: seed + 7) * 0.30
        case .exactModel(let modelID):
            let model = VehicleCatalog.entry(id: modelID)
            let category = model?.category ?? .sedan
            let reference = model.map {
                vehicleRetailValue(modelID: $0.id, category: category, modelYear: year - 2, mileage: 28_000, quality: 0.88, in: localDistrict)
            } ?? Int(Double(category.purchaseCost) * 1.5)
            budget = max(80, Int(Double(reference) * (0.94 + transactionRoll(seed: seed + 3) * 0.24) * incomeBudgetFactor))
            minimumQuality = 0.78 + transactionRoll(seed: seed + 5) * 0.16
            minimumModelYear = max(2000, year - 2 - Int(transactionRoll(seed: seed + 9) * 4))
            maximumMileage = 25_000 + Int(transactionRoll(seed: seed + 11) * 50_000)
            priceSensitivity = 0.66 + transactionRoll(seed: seed + 7) * 0.28
        case .budgetFirst:
            budget = Int(Double(80 + Int(transactionRoll(seed: seed + 3) * 111)) * incomeBudgetFactor)
            minimumQuality = 0.50 + transactionRoll(seed: seed + 5) * 0.24
            minimumModelYear = max(2000, year - 15)
            maximumMileage = 180_000
            priceSensitivity = 1.05 + transactionRoll(seed: seed + 7) * 0.35
        }
        let forceDemoTradeIn = CommandLine.arguments.contains("-demo-proposal")
        let tradeInVehicle = (turn > 0 || forceDemoTradeIn) && (forceDemoTradeIn || transactionRoll(seed: seed + 211) < 0.42)
            ? makeTradeInVehicle(storeID: storeID, seed: seed + 223)
            : nil
        let desiredCategory = resolvedPreference.category
        let purpose = requestedPurpose ?? defaultCustomerPurpose(for: desiredCategory, seed: seed + 257)
        let gradeKey = MarketSegmentKey(
            district: localDistrict,
            category: desiredCategory ?? .compact,
            purpose: purpose,
            productKind: productKind
        )
        let desiredGrade = productKind.supportsGrades
            ? (requestedGrade ?? requestedSpecialtyGrade(for: gradeKey, seed: seed + 263) ?? .low)
            : nil
        let nicheBudgetFactor: Double = switch productKind {
        case .standard: 1
        case .repaired: 1.04
        case .refurbished: 1.08
        case .camper: 1.30
        case .workCargo: 1.22
        case .outdoor: 1.15
        case .collector: 1.32
        case .sportTuned: 1.75
        case .welfare: 1.45
        case .mobileShop: 1.70
        }
        return BuyerLead(
            id: UUID(),
            storeID: storeID,
            preference: resolvedPreference,
            budget: Int(Double(budget) * nicheBudgetFactor * (desiredGrade?.buyerBudgetMultiplier ?? 1)),
            minimumQuality: minimumQuality,
            minimumModelYear: minimumModelYear,
            maximumMileage: maximumMileage,
            priceSensitivity: priceSensitivity,
            generatedTurn: turn,
            tradeInVehicle: tradeInVehicle,
            purpose: purpose,
            desiredProductKind: productKind,
            desiredGrade: desiredGrade,
            competitorOffer: bestCompetitorSaleOffer(
                category: desiredCategory ?? .compact,
                purpose: purpose,
                district: localDistrict,
                productKind: productKind,
                desiredGrade: desiredGrade
            )
        )
    }

    private func collectorBuyerPreference(category: VehicleCategory, seed: Int) -> BuyerVehiclePreference {
        let candidates = VehicleCatalog.rareClassics.filter { $0.category == category }
        let pool = candidates.isEmpty ? VehicleCatalog.rareClassics : candidates
        guard !pool.isEmpty else { return .category(category) }
        return .exactModel(pool[abs(seed) % pool.count].id)
    }

    private func defaultCustomerPurpose(for category: VehicleCategory?, seed: Int) -> CustomerPurpose {
        switch category {
        case .minivan: return transactionRoll(seed: seed) < 0.72 ? .family : .camper
        case .suv, .pickup: return transactionRoll(seed: seed) < 0.62 ? .outdoor : .family
        case .sedan: return transactionRoll(seed: seed) < 0.35 ? .corporate : .general
        case .kei, .compact: return transactionRoll(seed: seed) < 0.66 ? .general : .family
        case .sports: return .performance
        case nil: return .general
        }
    }

    private func detailedBuyerPreference(from preference: BuyerVehiclePreference, seed: Int) -> BuyerVehiclePreference {
        guard case .category(let category) = preference else { return preference }
        let target = vehicleModel(for: category, seed: seed)
        let roll = transactionRoll(seed: seed + 17)
        if target.origin == .imported {
            // 輸入車は車体カテゴリと独立した希望条件として扱う。
            if roll < 0.45 { return .exactModel(target.id) }
            if roll < 0.75 { return .maker(category: category, maker: target.maker) }
            return .categoryOrigin(category: category, origin: .imported)
        }
        let categoryOnlyShare: Double
        switch category {
        case .kei: categoryOnlyShare = 0.56
        case .compact: categoryOnlyShare = 0.50
        case .sedan: categoryOnlyShare = 0.34
        case .minivan, .suv: categoryOnlyShare = 0.42
        case .pickup: categoryOnlyShare = 0.48
        case .sports: categoryOnlyShare = 0.18
        }
        if roll < categoryOnlyShare { return .category(category) }
        if roll < categoryOnlyShare + 0.30 { return .maker(category: category, maker: target.maker) }
        return .exactModel(target.id)
    }

    private func makeTradeInVehicle(storeID: UUID, seed: Int) -> TradeInVehicle? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID) else { return nil }
        let category = sellerCategory(in: plot.district, seed: seed + 3)
        let model = vehicleModel(for: category, seed: seed + 5)
        let profile = usedVehicleProfile(for: model, seed: seed + 7, maximumAge: 14)
        let quality = min(0.90, max(0.50, profile.quality - transactionRoll(seed: seed + 11) * 0.06))
        let conditionScore = Int((quality * 100).rounded())
        let repairCost = hasServiceTechnician(storeID: storeID)
            ? 0
            : max(5, (100 - conditionScore) * category.purchaseCost / 280)
        let expectedRetail = vehicleRetailValue(
            modelID: model.id,
            category: category,
            modelYear: profile.modelYear,
            mileage: profile.mileage,
            quality: Double(min(94, conditionScore + (conditionScore < 75 ? 4 : 3))) / 100,
            in: plot.district
        )
        // 下取りは販売成約を助けるため店舗買取よりやや薄利。
        // 査定額どおりに販売できた場合の想定粗利率を8〜20%に置く。
        let targetMargin = 0.08 + transactionRoll(seed: seed + 13) * 0.12
        let targetAllowance = expectedRetail
            - repairCost
            - Int((Double(expectedRetail) * targetMargin).rounded())
        let allowance = max(20, targetAllowance)
        return TradeInVehicle(
            modelID: model.id,
            category: category,
            modelYear: profile.modelYear,
            mileage: profile.mileage,
            quality: quality,
            appraisedValue: allowance,
            repairCost: repairCost
        )
    }

    private func makePurchaseCase(
        storeID: UUID,
        plot: LandPlot,
        category: VehicleCategory,
        seed: Int,
        preferredModel: VehicleCatalogEntry? = nil,
        origin: PurchaseCaseOrigin = .walkIn,
        suggestedProjectKind: WorkshopProjectKind? = nil,
        askingPremium: Double? = nil
    ) -> PurchaseCase {
        let base = category.purchaseCost
        let model = preferredModel ?? vehicleModel(for: category, seed: seed + 5)
        let profile = usedVehicleProfile(for: model, seed: seed + 7, maximumAge: 14)
        let condition = min(91, max(50, Int((profile.quality * 100).rounded())))
        let conditionBand = sellerConditionBand(seed: seed)
        let fault: MechanicalFaultSeverity
        switch conditionBand {
        case .normal:
            fault = transactionRoll(seed: seed + 151) < 0.04 ? .minor : .none
        case .rough:
            fault = transactionRoll(seed: seed + 151) < 0.45 ? .minor : .none
        case .faulty:
            let roll = transactionRoll(seed: seed + 151)
            fault = roll < 0.20 ? .immobile : (roll < 0.58 ? .major : .minor)
        }
        let exterior = max(30, condition - (conditionBand == .rough ? 12 : 3))
        let interior = max(30, condition - (conditionBand == .rough ? 8 : -2))
        let mechanical = max(20, condition - fault.requiredWork * 7)
        let conditionProfile = VehicleConditionProfile(exterior: exterior, interior: interior, mechanical: mechanical)
        let wholesale = vehicleWholesaleValue(modelID: model.id, category: category, modelYear: profile.modelYear, mileage: profile.mileage, quality: Double(condition) / 100.0, in: plot.district)
        let faultDiscount: Double = switch fault { case .none: 1; case .minor: 0.78; case .major: 0.48; case .immobile: 0.25 }
        let askingFactor = askingPremium
            ?? (0.84 + transactionRoll(seed: seed + 13) * 0.22)
        var asking = max(12, Int(Double(wholesale) * min(1.24, askingFactor) * faultDiscount))
        // 部品・消耗品・清掃など、内製でも必ず発生する商品化原価。
        let asIsRepair = max(6, (100 - condition) * base / 230)
        let repairGain = condition < 75 ? 4 : 3
        let repairedQuality = Double(min(94, condition + repairGain)) / 100.0
        let asIsExpectedSale = vehicleRetailValue(modelID: model.id, category: category, modelYear: profile.modelYear, mileage: profile.mileage, quality: repairedQuality, in: plot.district)
        var repair = asIsRepair
        var expectedSale = asIsExpectedSale
        if let suggestedProjectKind,
           let store = stores.first(where: { $0.id == storeID }),
           let targetState = suggestedProjectKind.productState {
            let conversionRate: Double = switch suggestedProjectKind {
            case .streetTuning: 0.22
            case .driftTuning: 0.38
            case .circuitTuning: 0.55
            case .liftSeatConversion: 0.22
            case .wheelchairConversion: 0.40
            case .mobileSalesConversion: 0.30
            case .kitchenCarConversion: 0.60
            case .refurbishment: model.isRareClassic ? 0.52 : 0.28
            case .camperConversion: 1.80
            case .workConversion: 0.22
            case .outdoorConversion: 0.18
            case .basicService, .repair: 0
            }
            let conversionCost = max(20, Int(Double(model.referenceRetailPrice) * conversionRate))
            repair += conversionCost
            let productKind = MarketProductKind.resolve(productState: targetState, isRareClassic: model.isRareClassic)
            let key = MarketSegmentKey(
                district: plot.district,
                category: category,
                purpose: targetState.purpose ?? store.marketPolicy.targetPurpose,
                productKind: productKind
            )
            let trendPrice = segmentWillingnessFactor(for: key, store: store, productState: targetState)
            let priceCeilingFactor = specialtyPriceCeiling(for: productKind, productState: targetState)
            let ceiling = Int(specialtyReferenceRetail(for: model) * priceCeilingFactor)
            let trendProgress = min(1, max(0, activeTrendMultiplier(for: key) - 1) / 2.2)
                * specialtyReadiness(for: store, productKind: productKind)
            let specialtyReferenceValue = Int(specialtyReferenceRetail(for: model)
                * (1 + (priceCeilingFactor - 1) * trendProgress))
            expectedSale = min(
                ceiling,
                max(
                    specialtyReferenceValue,
                    asIsExpectedSale,
                    Int(Double(asIsExpectedSale + conversionCost) * trendPrice)
                )
            )
        }
        if !model.isRareClassic {
            let faultRepair = estimatedSourcingRepairCost(
                category: category,
                fault: fault,
                condition: conditionProfile,
                storeID: storeID
            )
            let targetMargin = 0.12 + transactionRoll(seed: seed + 17) * 0.16
            // 店頭買取の基準価格では12〜28%を狙う。交渉による値下げは
            // プレイヤーの上振れ、未発見の問題歴や故障は下振れとして残す。
            asking = max(
                12,
                asIsExpectedSale
                    - asIsRepair
                    - faultRepair
                    - Int((Double(asIsExpectedSale) * targetMargin).rounded())
            )
        }
        let assessment = vehicleAssessment(
            source: .storePurchase,
            condition: conditionProfile,
            fault: fault,
            actualRepairCost: repair + estimatedSourcingRepairCost(
                category: category,
                fault: fault,
                condition: conditionProfile,
                storeID: storeID
            ),
            storeID: storeID,
            seed: profile.modelYear * 101 + profile.mileage / 100 + categoryIndex(category)
        )
        let appraisalAccuracy = assessment.confidence
        let age = max(0, year - profile.modelYear)
        let issueRate = min(0.24, 0.075 + Double(age) * 0.006 + Double(profile.mileage) / 1_200_000.0)
        let issueRoll = transactionRoll(seed: seed + 31)
        let hiddenIssue: VehicleIssueKind?
        if issueRoll < issueRate {
            hiddenIssue = transactionRoll(seed: seed + 37) < 0.68 ? .repairedHistory : .odometerRollback
        } else {
            hiddenIssue = nil
        }
        let issueRevealed = hiddenIssue != nil && transactionRoll(seed: seed + 41) < Double(appraisalAccuracy) / 100.0
        let faultRevealed = assessment.detectedFault != nil
        let lotCount = stores.first(where: { $0.id == storeID })
            .map { procurementLotSize(for: $0, category: category, seed: seed) } ?? 1
        return PurchaseCase(
            id: UUID(), storeID: storeID, modelID: model.id, category: category,
            lotCount: lotCount,
            modelYear: profile.modelYear,
            mileage: profile.mileage,
            exterior: exterior, interior: interior, mechanical: mechanical,
            askingPrice: asking, appraisedPrice: wholesale, repairCost: repair,
            expectedSalePrice: expectedSale,
            asIsExpectedSalePrice: asIsExpectedSale,
            asIsRepairCost: asIsRepair,
            expectedDays: 20 + Int(transactionRoll(seed: seed + 23) * 62),
            demand: district(for: plot).demands[category] ?? 0.72,
            appraisalAccuracy: appraisalAccuracy,
            negotiationAttempts: 0,
            hiddenIssue: hiddenIssue,
            issueRevealed: issueRevealed,
            condition: conditionProfile,
            fault: fault,
            faultRevealed: faultRevealed,
            competitorOffer: bestCompetitorPurchaseOffer(category: category, condition: conditionProfile, fault: fault, district: plot.district),
            origin: origin,
            suggestedProjectKind: suggestedProjectKind
        )
    }

    static func makeDistricts() -> [District] {
        [
            District(kind: .downtown, population: 92_000, incomeIndex: 1.42, trafficIndex: 1.35, growthRate: 1.01, competition: 1.35, demands: [.compact: 1.38, .sedan: 1.52, .sports: 1.25, .suv: 1.18, .minivan: 0.88, .pickup: 0.62, .kei: 0.72], supplies: [.compact: 1.28, .sedan: 0.92, .sports: 0.85, .suv: 0.75, .minivan: 0.74, .pickup: 0.44, .kei: 0.55]),
            District(kind: .station, population: 76_000, incomeIndex: 1.03, trafficIndex: 1.42, growthRate: 1.015, competition: 1.28, demands: [.compact: 1.55, .kei: 1.25, .minivan: 1.08, .sedan: 1.02, .suv: 0.84, .sports: 0.65, .pickup: 0.52], supplies: [.compact: 1.55, .kei: 1.30, .minivan: 0.90, .sedan: 0.82, .suv: 0.72, .sports: 0.55, .pickup: 0.48]),
            District(kind: .emerging, population: 58_000, incomeIndex: 1.16, trafficIndex: 1.02, growthRate: 1.065, competition: 0.72, demands: [.compact: 1.34, .suv: 1.52, .minivan: 1.45, .sports: 1.10, .sedan: 1.04, .pickup: 0.88, .kei: 0.82], supplies: [.compact: 1.28, .suv: 1.12, .minivan: 1.05, .sedan: 0.80, .sports: 0.75, .pickup: 0.60, .kei: 0.72]),
            District(kind: .suburb, population: 88_000, incomeIndex: 1.08, trafficIndex: 1.18, growthRate: 1.02, competition: 1.02, demands: [.compact: 1.42, .minivan: 1.48, .kei: 1.30, .suv: 1.26, .sedan: 0.96, .sports: 0.90, .pickup: 0.82], supplies: [.compact: 1.40, .minivan: 1.45, .kei: 1.35, .suv: 1.15, .sedan: 0.86, .sports: 0.80, .pickup: 0.65]),
            District(kind: .industrial, population: 43_000, incomeIndex: 0.82, trafficIndex: 0.88, growthRate: 0.99, competition: 0.58, demands: [.compact: 1.30, .pickup: 1.55, .minivan: 1.42, .kei: 1.15, .sedan: 0.72, .suv: 0.66, .sports: 0.55], supplies: [.compact: 1.36, .pickup: 1.48, .minivan: 1.42, .kei: 0.92, .suv: 0.80, .sedan: 0.70, .sports: 0.45]),
            District(kind: .highway, population: 66_000, incomeIndex: 0.91, trafficIndex: 1.48, growthRate: 1.012, competition: 0.93, demands: [.compact: 1.36, .kei: 1.42, .sports: 1.35, .pickup: 1.34, .suv: 1.12, .minivan: 1.08, .sedan: 0.82], supplies: [.compact: 1.34, .pickup: 1.35, .minivan: 1.22, .suv: 1.18, .kei: 1.05, .sports: 1.0, .sedan: 0.72])
        ]
    }

    static func makePlots(map: GridCityMap = CityMapDefinition.suihama) -> [LandPlot] {
        var result: [LandPlot] = []
        var localCounts: [DistrictKind: Int] = [:]
        let objectByParcelID = Dictionary(
            map.objects.map { ($0.parcelID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let orderedParcels = map.parcels.sorted {
            ($0.legacyPlotID ?? .max) < ($1.legacyPlotID ?? .max)
        }
        for parcel in orderedParcels {
            guard let id = parcel.legacyPlotID else { continue }
            let local = localCounts[parcel.district, default: 0] + 1
            localCounts[parcel.district] = local
            let development: DevelopmentProject?
            if parcel.district == .emerging && local == 6 {
                development = DevelopmentProject(title: "ひかりニュータウン第2期", monthsRemaining: 5, populationBoost: 5_200, trafficBoost: 0.10)
            } else if parcel.district == .industrial && local == 12 {
                development = DevelopmentProject(title: "臨海物流パーク", monthsRemaining: 8, populationBoost: 1_800, trafficBoost: 0.13)
            } else {
                development = nil
            }
            let price = parcel.price ?? 0
            result.append(LandPlot(
                id: id,
                district: parcel.district,
                localNumber: local,
                area: parcel.areaSquareMeters,
                visibility: 0.78 + Double((id * 11) % 35) / 100,
                access: 0.80 + Double((id * 7) % 31) / 100,
                traffic: 0.82 + Double((id * 13) % 38) / 100,
                price: price,
                monthlyRent: max(18, price / 210),
                growth: 0.98 + Double((id * 5) % 11) / 100,
                occupant: .available,
                isForLease: parcel.isPurchasable,
                isForSale: parcel.isPurchasable,
                structure: initialStructure(
                    for: objectByParcelID[parcel.id],
                    in: parcel.district
                ),
                currentUse: initialParcelUse(for: objectByParcelID[parcel.id]),
                development: development
            ))
        }
        return result
    }

    private static func initialStructure(
        for object: GridPlacedObject?,
        in district: DistrictKind
    ) -> ParcelStructure {
        guard let object, object.kind == .building else { return .vacant }
        let definition = CityAssetCatalog.definition(for: object.assetID)
        switch definition.category {
        case .generalResidential:
            return object.assetID == .residentialApartment ? .apartment : .home
        case .luxuryResidential:
            return .villa
        case .commercial:
            return district == .highway ? .roadside : .commercial
        case .industrial:
            return [.industrialFactory, .industrialTankWorks, .industrialSmokestack]
                .contains(object.assetID) ? .factory : .warehouse
        case .downtown:
            if object.assetID == .downtownOffice { return .office }
            if object.assetID == .downtownApartment { return .apartment }
            return .commercial
        case .highway:
            return object.assetID == .highwayLogistics ? .warehouse : .roadside
        case .parking:
            return .vacant
        case .playerFacility:
            return .commercial
        }
    }

    private static func initialParcelUse(for object: GridPlacedObject?) -> CityParcelUseState {
        guard let object else { return .vacant }
        switch object.kind {
        case .building:
            return .ambientBuilding(assetID: object.assetID)
        case .parking:
            return .surfaceParking
        }
    }

    static func makeCompetitors() -> [Competitor] {
        [
            Competitor(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, name: "バリューオート", strategy: "低価格・高回転", colorHex: "E46B35", cash: 42_000, plotIDs: [], strength: 1.02, category: .compact),
            Competitor(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, name: "プレミアモータース", strategy: "輸入車と品質保証", colorHex: "7356A8", cash: 58_000, plotIDs: [], strength: 1.15, category: .sedan),
            Competitor(id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!, name: "ドライブMAX", strategy: "多店舗・大量展示", colorHex: "287DB2", cash: 64_000, plotIDs: [], strength: 1.08, category: .suv)
        ]
    }

    static func makeNationalCities() -> [NationalCity] {
        [
            NationalCity(id: "suihama", name: "翠浜市", region: "首都圏", population: 423_000, incomeIndex: 1.08, landPriceIndex: 1.00, competitionIndex: 1.02, growthRate: 1.018, primaryDemand: [.minivan, .kei, .suv], expansionCost: 0, shippingMonths: 0, shippingCostPerVehicle: 0, mapX: 0.72, mapY: 0.42),
            NationalCity(id: "hokusei", name: "北星市", region: "北日本", population: 318_000, incomeIndex: 0.91, landPriceIndex: 0.66, competitionIndex: 0.72, growthRate: 1.004, primaryDemand: [.suv, .pickup, .minivan], expansionCost: 6_800, shippingMonths: 2, shippingCostPerVehicle: 18, mapX: 0.72, mapY: 0.12),
            NationalCity(id: "shinonome", name: "東雲市", region: "中部", population: 512_000, incomeIndex: 1.04, landPriceIndex: 0.88, competitionIndex: 0.94, growthRate: 1.023, primaryDemand: [.minivan, .compact, .pickup], expansionCost: 7_600, shippingMonths: 1, shippingCostPerVehicle: 11, mapX: 0.58, mapY: 0.48),
            NationalCity(id: "naniwa", name: "浪華市", region: "関西", population: 884_000, incomeIndex: 1.16, landPriceIndex: 1.24, competitionIndex: 1.31, growthRate: 1.011, primaryDemand: [.sedan, .suv, .minivan], expansionCost: 11_500, shippingMonths: 2, shippingCostPerVehicle: 15, mapX: 0.43, mapY: 0.55),
            NationalCity(id: "setouchi", name: "瀬戸内市", region: "中国・四国", population: 276_000, incomeIndex: 0.89, landPriceIndex: 0.58, competitionIndex: 0.63, growthRate: 1.015, primaryDemand: [.kei, .minivan, .pickup], expansionCost: 5_900, shippingMonths: 2, shippingCostPerVehicle: 17, mapX: 0.28, mapY: 0.61),
            NationalCity(id: "hinata", name: "日向市", region: "九州", population: 391_000, incomeIndex: 0.94, landPriceIndex: 0.72, competitionIndex: 0.81, growthRate: 1.029, primaryDemand: [.kei, .suv, .minivan], expansionCost: 6_500, shippingMonths: 3, shippingCostPerVehicle: 22, mapX: 0.16, mapY: 0.76)
        ]
    }
}
