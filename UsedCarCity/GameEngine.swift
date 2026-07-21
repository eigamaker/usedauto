import Foundation
import SwiftUI

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
    @Published var purchaseCases: [PurchaseCase] = []
    @Published var buyerLeads: [BuyerLead] = []
    @Published var cityEvents: [CityEvent] = []
    @Published var auctionListings: [AuctionListing] = []
    @Published var bidReservations: [BidReservation] = []
    @Published var auctionBidResults: [AuctionBidResult] = []
    @Published var competitorAuctionPurchases: [CompetitorAuctionPurchase] = []
    @Published var inboundShipments: [InboundShipment] = []
    @Published var auctionConsignments: [AuctionConsignment] = []
    @Published var pendingCustomerClaims: [PendingCustomerClaim] = []
    @Published var finance = FinanceSnapshot()
    @Published var lastReport: MonthlyReport?
    @Published var showMonthlyReport = false
    @Published var gameOver = false
    @Published var tutorialMessage: String?
    @Published var tutorialStep: TutorialStep?
    @Published var tutorialPlotID: Int?
    @Published var unlockedFeatures: Set<String> = ["仕入", "価格設定", "出店"]
    @Published var regionalOperations: [RegionalOperation] = []
    @Published var intercityShipments: [IntercityShipment] = []
    @Published var nationalBrandStrength: Double = 0.48
    @Published var economicIndex: Double = 1.0
    @Published var fuelPriceIndex: Double = 1.0
    @Published var careerStatistics = CareerStatistics()
    @Published var priceWarChallenges: [PriceWarChallenge] = []
    @Published var financialDistressWeeks = 0

    let maxTurns = 480

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
        let purchaseCases: [PurchaseCase]
        let buyerLeads: [BuyerLead]
        let cityEvents: [CityEvent]
        let auctionListings: [AuctionListing]
        let bidReservations: [BidReservation]
        let auctionBidResults: [AuctionBidResult]
        let competitorAuctionPurchases: [CompetitorAuctionPurchase]
        let inboundShipments: [InboundShipment]
        let auctionConsignments: [AuctionConsignment]
        let pendingCustomerClaims: [PendingCustomerClaim]
        let finance: FinanceSnapshot
        let unlockedFeatures: Set<String>
        let regionalOperations: [RegionalOperation]
        let intercityShipments: [IntercityShipment]
        let nationalBrandStrength: Double
        let economicIndex: Double
        let fuelPriceIndex: Double
        let careerStatistics: CareerStatistics
        let priceWarChallenges: [PriceWarChallenge]
        let tutorialStep: TutorialStep?
        let tutorialPlotID: Int?
        let financialDistressWeeks: Int
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

    private static let saveKey = "UsedCarCity.save.v30"
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

    init() {
        districts = Self.makeDistricts()
        plots = Self.makePlots()
        competitors = Self.makeCompetitors()
        placeCompetitors()
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
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
                    focus: .family,
                    concept: .family,
                    loanAmount: StoreConcept.family.defaultFacilities.reduce(0) { $0 + $1.installationCost }
                )
            }
            tutorialMessage = nil
        } else if CommandLine.arguments.contains("-demo-tutorial"), !hasStarted {
            startNewGame()
            tutorialMessage = nil
        } else if (CommandLine.arguments.contains("-demo-map") || CommandLine.arguments.contains("-demo-map-zoom") || CommandLine.arguments.contains("-demo-store") || CommandLine.arguments.contains("-demo-team") || CommandLine.arguments.contains("-demo-proposal") || CommandLine.arguments.contains("-demo-catalog") || CommandLine.arguments.contains("-demo-auction") || CommandLine.arguments.contains("-demo-workshop") || CommandLine.arguments.contains("-demo-hq") || CommandLine.arguments.contains("-demo-goals") || CommandLine.arguments.contains("-demo-ending") || CommandLine.arguments.contains("-demo-competition") || CommandLine.arguments.contains("-demo-construction") || CommandLine.arguments.contains("-demo-national")) && !hasStarted {
            prepareDemoCompany()
            tutorialMessage = nil
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
            _ = buildStore(on: plot, type: .roadside, mode: .lease, focus: .business, concept: .business, loanAmount: 100_000)
            tutorialMessage = nil
        }
        if CommandLine.arguments.contains("-demo-national"), regionalOperations.isEmpty {
            companyValue = 120_000
            cash = 180_000
            _ = establishRegionalOffice(in: "shinonome")
            _ = openFranchise(in: "shinonome")
            _ = acquireLocalDealer(in: "shinonome")
            _ = establishRegionalOffice(in: "naniwa")
            _ = openFranchise(in: "naniwa")
            tutorialMessage = nil
        }
#endif
    }

    var progress: Double { Double(turn) / Double(maxTurns) }
    var totalInventory: Int { stores.reduce(0) { $0 + $1.inventoryCount } }
    var availableVehicleCatalog: [VehicleCatalogEntry] {
        VehicleCatalog.available(through: turn).sorted {
            if $0.launchTurn != $1.launchTurn { return $0.launchTurn > $1.launchTurn }
            return $0.fullName < $1.fullName
        }
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
    var isTutorialActive: Bool {
        guard let tutorialStep else { return false }
        return tutorialStep != .completed
    }

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

    func startNewGame() {
        beginNewGame()
    }

    private func beginNewGame() {
        resetState(removeSave: true)
        hasStarted = true
        cash = 6_500
        debt = 3_000
        companyValue = 3_500
        tutorialStep = .chooseLocation
        tutorialPlotID = nil
        cityEvents = plots.compactMap { plot in
            guard let project = plot.development else { return nil }
            return CityEvent(turn: 0, kind: .development, title: "\(project.title)が計画中", detail: "完成まで\(project.monthsRemaining)週間。周辺人口と交通量が増える見込みです", district: plot.district, plotID: plot.id)
        }
        tutorialMessage = nil
        generateAuctionListings()
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
        showMonthlyReport = false
        gameOver = false
    }

    func resetGame() {
        resetState(removeSave: true)
    }

    private func resetState(removeSave: Bool) {
        hasStarted = false
        year = 2026; month = 1; weekOfMonth = 1; turn = 0; cash = 6_500; debt = 3_000; companyValue = 3_500
        districts = Self.makeDistricts(); plots = Self.makePlots(); competitors = Self.makeCompetitors()
        stores = []; reports = []; purchaseCases = []; buyerLeads = []; cityEvents = []; auctionListings = []; bidReservations = []; auctionBidResults = []; competitorAuctionPurchases = []; inboundShipments = []; auctionConsignments = []; pendingCustomerClaims = []; regionalOperations = []; intercityShipments = []; nationalBrandStrength = 0.48; economicIndex = 1.0; fuelPriceIndex = 1.0; careerStatistics = CareerStatistics(); priceWarChallenges = []; financialDistressWeeks = 0; finance = FinanceSnapshot(); lastReport = nil; showMonthlyReport = false; gameOver = false; tutorialStep = nil; tutorialPlotID = nil; tutorialMessage = nil
        unlockedFeatures = ["仕入", "価格設定", "出店"]
        placeCompetitors()
        if removeSave {
            pendingSave = nil
            hasSaveData = false
            UserDefaults.standard.removeObject(forKey: Self.saveKey)
        }
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
        purchaseCases = saved.purchaseCases
        buyerLeads = saved.buyerLeads
        cityEvents = saved.cityEvents
        auctionListings = saved.auctionListings
        bidReservations = saved.bidReservations
        auctionBidResults = saved.auctionBidResults
        competitorAuctionPurchases = saved.competitorAuctionPurchases
        inboundShipments = saved.inboundShipments
        auctionConsignments = saved.auctionConsignments
        pendingCustomerClaims = saved.pendingCustomerClaims
        finance = saved.finance
        unlockedFeatures = saved.unlockedFeatures
        regionalOperations = saved.regionalOperations
        intercityShipments = saved.intercityShipments
        nationalBrandStrength = saved.nationalBrandStrength
        economicIndex = saved.economicIndex
        fuelPriceIndex = saved.fuelPriceIndex
        careerStatistics = saved.careerStatistics
        priceWarChallenges = saved.priceWarChallenges
        tutorialStep = saved.tutorialStep
        tutorialPlotID = saved.tutorialPlotID
        financialDistressWeeks = saved.financialDistressWeeks
        lastReport = reports.first
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
        guard tutorialStep == .chooseLocation || tutorialStep == .buildStore,
              let plot = plot(id: plotID), isAvailable(plot.occupant), plot.development == nil else { return }
        tutorialPlotID = plotID
        tutorialStep = .buildStore
        save()
    }

    func canPlanStore(on plot: LandPlot) -> Bool {
        if stores.isEmpty, tutorialStep == .buildStore { return tutorialPlotID == plot.id }
        return !stores.isEmpty
    }

    func estimatedVisitors(for plot: LandPlot) -> Int {
        let district = district(for: plot)
        let base = Double(district.population) / 750
        return max(28, Int(base * district.trafficIndex * plot.traffic * plot.visibility * (1.15 - district.competition * 0.18)))
    }

    func weeklyBuyerPool(in kind: DistrictKind) -> Int {
        guard let district = districts.first(where: { $0.kind == kind }) else { return 0 }
        let season = [3, 9].contains(month) ? 1.12 : ([1, 8].contains(month) ? 0.92 : 1.0)
        let economy = 0.45 + economicIndex * 0.55
        let base = Double(district.population) / 6_500.0 * district.trafficIndex * season * economy
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
        let base = Double(district.population) / 13_500.0 * district.trafficIndex * activity
        let economy = max(0.72, 1.08 + (1 - economicIndex) * 0.45)
        let index = DistrictKind.allCases.firstIndex(of: kind) ?? 0
        return max(0, Int((base * economy * weeklyMarketShock(seed: turn * 173 + index * 43 + 29)).rounded()))
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
        case .imported, .suv: economyEffect = 0.72 + economicIndex * 0.28
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
            let commercialPenalty = [.commercial, .pickup].contains(model.category) ? 0.90 + transition * 0.10 : 1.0
            return min(1.75, max(0.52, (0.68 + transition * 0.72 + (fuelPriceIndex - 1) * 0.55) * infrastructure * commercialPenalty))
        case .hybrid:
            return min(1.38, max(0.82, 1.02 + transition * 0.12 + (fuelPriceIndex - 1) * 0.24))
        case .gasoline:
            let efficientSegment = [.kei, .compact].contains(model.category) ? 0.08 : 0
            return min(1.18, max(0.62, 1.06 - transition * 0.30 - max(0, fuelPriceIndex - 1) * 0.30 + efficientSegment))
        case .diesel:
            let workVehicle = [.commercial, .pickup].contains(model.category) ? 0.13 : 0
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

    private func catalogGenerationDepreciation(for model: VehicleCatalogEntry) -> Double {
        if model.isRareClassic {
            // Collector cars do not follow ordinary model-cycle depreciation.
            return 1.0 + min(0.12, Double(turn) * 0.00025)
        }
        let yearsSinceLaunch = Double(max(0, turn - model.launchTurn)) / 48.0
        return max(0.58, pow(0.94, yearsSinceLaunch))
    }

    func catalogWholesalePrice(for model: VehicleCatalogEntry, in kind: DistrictKind) -> Int {
        let index = catalogMarketIndex(for: model, in: kind)
        let aging = catalogGenerationDepreciation(for: model)
        let scarcity = usedMarketScarcityPriceFactor(for: model)
        return max(25, Int(Double(model.baseWholesalePrice) * (0.86 + index * 0.14) * aging * scarcity))
    }

    func catalogRetailPrice(for model: VehicleCatalogEntry, in kind: DistrictKind) -> Int {
        let index = catalogMarketIndex(for: model, in: kind)
        let aging = catalogGenerationDepreciation(for: model)
        let scarcity = usedMarketScarcityPriceFactor(for: model)
        return max(35, Int(Double(model.referenceRetailPrice) * (0.78 + index * 0.22) * aging * scarcity))
    }

    func vehicleWholesaleValue(modelID: String, category: VehicleCategory, modelYear: Int, mileage: Int, quality: Double, in kind: DistrictKind) -> Int {
        vehicleMarketValue(modelID: modelID, category: category, modelYear: modelYear, mileage: mileage, quality: quality, in: kind, retail: false)
    }

    func vehicleRetailValue(modelID: String, category: VehicleCategory, modelYear: Int, mileage: Int, quality: Double, in kind: DistrictKind) -> Int {
        vehicleMarketValue(modelID: modelID, category: category, modelYear: modelYear, mileage: mileage, quality: quality, in: kind, retail: true)
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
        } else if category == .imported {
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
        return max(retail ? 30 : 22, Int(Double(base) * ageFactor * mileageFactor * qualityFactor))
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
        if batch.productState == .custom {
            return [.industrial, .highway].contains(district) ? "カスタム需要：強い" : "カスタム需要：限定的"
        }
        if batch.isRareClassic {
            return [.downtown, .emerging].contains(district) ? "旧車需要：強い" : "旧車需要：限定的"
        }
        return "一般需要"
    }

    func specialtyMarketFactor(for batch: InventoryBatch, in district: DistrictKind) -> Double {
        let model = VehicleCatalog.entry(id: batch.modelID)
        let productFactor: Double
        switch batch.productState {
        case .stock:
            productFactor = 1.0
        case .restored:
            productFactor = batch.isRareClassic ? 1.32 : 1.08
        case .custom:
            let appeal = model?.customAppeal ?? 0.48
            productFactor = batch.isRareClassic ? 1.30 + appeal * 0.16 : 1.10 + appeal * 0.16
        }

        let districtFactor: Double
        if batch.productState == .custom {
            switch district {
            case .industrial: districtFactor = 1.18
            case .highway: districtFactor = 1.14
            case .emerging: districtFactor = 1.04
            case .downtown: districtFactor = 0.90
            case .suburb: districtFactor = 0.88
            case .station: districtFactor = 0.84
            }
        } else if batch.isRareClassic {
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

    func specialtyCloseAdjustment(for batch: InventoryBatch, in district: DistrictKind) -> Double {
        if batch.productState == .custom {
            let appeal = VehicleCatalog.entry(id: batch.modelID)?.customAppeal ?? 0.48
            let appealLift = (appeal - 0.85) * 0.10
            switch district {
            case .industrial: return 0.16 + appealLift
            case .highway: return 0.12 + appealLift
            case .emerging: return 0.02 + appealLift
            case .downtown: return -0.14
            case .suburb: return -0.18
            case .station: return -0.23
            }
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
            guard batch.count > 0, !batch.isInWorkshop,
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
        let automaticSalesCapacity = store.autoSales ? store.employees.filter { $0.assignment == .sales }.count * 7 : 0
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
        let stocked = store.inventory.filter { $0.count > 0 && !$0.isInWorkshop }
        let inventoryDemand = stocked.isEmpty ? 0.45 : stocked.reduce(0.0) {
            $0 + (district.demands[$1.category] ?? 0.55)
        } / Double(stocked.count)
        let location = plot.visibility * plot.access * plot.traffic
        let advertisingLift = min(0.42, Double(store.advertising) / 520.0)
        return [
            ResultCause("景気指数 \(Int(economicIndex * 100))", (economicIndex - 1) * 5.0),
            ResultCause("地域人口 \(district.population.formatted())人", (Double(district.population) / 70_000.0 - 1) * 3.0),
            ResultCause("店舗の評判", (store.reputation - 0.65) * 5.5),
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
        let marketing = (0.82 + min(0.38, Double(store.advertising) / 550.0))
            * employeeMarketingEfficiency(for: store.id, buyers: true)
        let priceAppeal = max(0.62, 1.72 - store.priceIndex * 0.72)
        return max(0.08, inventoryFit * facilityMarketFactor(store) * location * marketing * priceAppeal * competitiveStoreMarketFactor(in: plot.district))
    }

    private func competitorMarketWeight(_ competitor: Competitor, plot: LandPlot) -> Double {
        let demand = vehicleDemand(competitor.category, in: plot.district)
        return max(0.12, competitor.strength * demand * plot.visibility * plot.access * plot.traffic * competitiveRivalMarketFactor(competitor.id, in: plot.district))
    }

    func estimatedSales(for plot: LandPlot, type: StoreType = .standard, focus: CustomerFocus = .family, concept: StoreConcept = .general) -> ClosedRange<Int> {
        if let existing = store(at: plot.id) {
            let mid = max(1, Int(Double(weeklyBuyerPool(in: plot.district) * 4) * marketShare(for: existing)))
            return max(1, Int(Double(mid) * 0.78))...max(2, Int(Double(mid) * 1.18))
        }
        let district = district(for: plot)
        let demand = district.demands.values.reduce(0, +) / Double(max(1, district.demands.count))
        let location = plot.visibility * plot.access * plot.traffic
        let candidateWeight = max(0.08, demand * focusFit(focus, district: plot.district) * conceptDemandFit(concept, district: district) * location * type.serviceQuality)
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
        focus: CustomerFocus,
        concept: StoreConcept,
        facilities requestedFacilities: Set<StoreFacility>? = nil,
        loanAmount: Int
    ) -> Bool {
        let isFoundingStore = stores.isEmpty && tutorialStep == .buildStore && tutorialPlotID == plot.id
        let footprint = footprintPlots(startingAt: plot, type: type, mode: mode)
        let facilities = requestedFacilities ?? concept.defaultFacilities
        guard stores.count < 5,
              footprint.count == type.requiredGridCells,
              type.requiredGridCells >= concept.minimumGridCells,
              concept.defaultFacilities.isSubset(of: facilities),
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
            focus: focus,
            concept: concept,
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
        if tutorialStep == .purchaseInventory, stores[index].plotID == tutorialPlotID {
            tutorialStep = .runFirstMonth
        }
        recalculateAssets()
        save()
        return true
    }

    private func inventoryPurchaseBatches(category: VehicleCategory, count: Int, store: Store) -> [InventoryBatch]? {
        guard count > 0, let plot = plot(id: store.plotID) else { return nil }
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
                averageCost: wholesale,
                quality: profile.quality,
                modelYear: profile.modelYear,
                mileage: profile.mileage,
                acquiredTurn: turn
            )
        }
    }

    func setTutorialPrice(storeID: UUID, priceIndex: Double) {
        guard tutorialStep == .setPrice,
              let index = stores.firstIndex(where: { $0.id == storeID && $0.plotID == tutorialPlotID }) else { return }
        stores[index].priceIndex = min(1.18, max(0.88, priceIndex))
        tutorialStep = .runFirstMonth
        save()
    }

    func completeTutorial() {
        tutorialStep = .completed
        tutorialMessage = "創業チュートリアル完了。ここからは自由に街と会社を育てられます。"
        save()
    }

    func incomingCount(for storeID: UUID) -> Int {
        inboundShipments.filter { $0.storeID == storeID }.reduce(0) { $0 + $1.count }
    }

    func auctionBidWinChance(for listing: AuctionListing, maxPrice: Int) -> Double {
        if maxPrice >= listing.marketPrice * 3 / 2 { return 1.0 }
        let spread = max(1, listing.marketPrice - listing.reservePrice)
        if maxPrice <= listing.reservePrice { return 0.18 }
        if maxPrice <= listing.marketPrice {
            let progress = Double(maxPrice - listing.reservePrice) / Double(spread)
            return min(0.50, 0.18 + progress * 0.32)
        }
        let premium = Double(maxPrice - listing.marketPrice) / Double(max(1, listing.marketPrice))
        return min(0.76, 0.50 + premium * 1.30)
    }

    @discardableResult
    func reserveBid(listingID: UUID, storeID: UUID, maxPrice: Int) -> Bool {
        guard let listing = auctionListings.first(where: { $0.id == listingID }),
              let store = stores.first(where: { $0.id == storeID }),
              maxPrice >= listing.reservePrice else { return false }
        let otherReservedSlots = bidReservations.filter { $0.storeID == storeID && $0.listingID != listingID }.count
        guard store.inventoryCount + incomingCount(for: storeID) + otherReservedSlots + 1 <= store.type.capacity else { return false }
        if let index = bidReservations.firstIndex(where: { $0.listingID == listingID }) {
            bidReservations[index].storeID = storeID
            bidReservations[index].maxPrice = maxPrice
        } else {
            bidReservations.append(BidReservation(
                id: UUID(),
                listingID: listingID,
                storeID: storeID,
                maxPrice: maxPrice,
                resultTurn: turn + 1
            ))
        }
        save()
        return true
    }

    func cancelBid(listingID: UUID) {
        bidReservations.removeAll { $0.listingID == listingID }
        save()
    }

    @discardableResult
    func orderDealerTrade(category: VehicleCategory, count: Int, storeID: UUID) -> Bool {
        guard let quote = dealerTradeQuote(category: category, count: count, storeID: storeID),
              let store = stores.first(where: { $0.id == storeID }),
              store.inventoryCount + incomingCount(for: storeID) + count <= store.type.capacity else { return false }
        guard cash >= quote.totalCost else { return false }
        cash -= quote.totalCost
        inboundShipments.append(InboundShipment(id: UUID(), storeID: storeID, source: .dealerTrade, modelID: quote.modelID, category: category, count: count, unitCost: quote.unitCost + quote.fee / count, quality: quote.quality, modelYear: nil, mileage: nil, acquiredTurn: turn, monthsRemaining: quote.weeks))
        save()
        return true
    }

    func dealerTradeQuote(category: VehicleCategory, count: Int, storeID: UUID) -> ProcurementQuote? {
        guard count > 0,
              let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID) else { return nil }
        let networkBonus = store.concept == .business && [.commercial, .pickup].contains(category) ? 0.18 : 0
        let availability = vehicleSupply(category, in: plot.district) + networkBonus
        let model = vehicleModel(for: category, seed: turn * 193 + categoryIndex(category) * 47)
        let profile = usedVehicleProfile(
            for: model,
            seed: turn * 211 + categoryIndex(category) * 53,
            maximumAge: category == .imported ? 6 : 10
        )
        let calculatedWholesale = vehicleWholesaleValue(
            modelID: model.id,
            category: category,
            modelYear: profile.modelYear,
            mileage: profile.mileage,
            quality: profile.quality,
            in: plot.district
        )
        let modelWholesale = category == .imported
            ? max(calculatedWholesale, Int(Double(model.baseWholesalePrice) * 0.78))
            : calculatedWholesale
        let multiplier: Double
        let weeks: Int
        let label: String
        switch availability {
        case 1.25...:
            multiplier = 1.04; weeks = 1; label = "地域流通が豊富"
        case 0.85...:
            multiplier = 1.08; weeks = 1; label = "通常流通"
        case 0.55...:
            multiplier = 1.14; weeks = 2; label = "取り寄せ"
        default:
            multiplier = 1.22; weeks = 2; label = "希少・広域探索"
        }
        return ProcurementQuote(
            source: .dealerTrade,
            modelID: model.id,
            category: category,
            count: count,
            unitCost: Int((Double(modelWholesale) * multiplier).rounded()),
            fee: 8 + max(0, count - 3) * 2,
            weeks: weeks,
            quality: availability >= 0.85 ? 0.80 : 0.77,
            availabilityLabel: label
        )
    }

    @discardableResult
    func orderFleetPurchase(category: VehicleCategory, count: Int, storeID: UUID) -> Bool {
        guard let quote = fleetPurchaseQuote(category: category, count: count, storeID: storeID),
              let store = stores.first(where: { $0.id == storeID }),
              store.inventoryCount + incomingCount(for: storeID) + count <= store.type.capacity else { return false }
        guard cash >= quote.totalCost else { return false }
        cash -= quote.totalCost
        inboundShipments.append(InboundShipment(id: UUID(), storeID: storeID, source: .fleetPurchase, modelID: nil, category: category, count: count, unitCost: quote.unitCost + quote.fee / count, quality: quote.quality, modelYear: nil, mileage: nil, acquiredTurn: turn, monthsRemaining: quote.weeks))
        save()
        return true
    }

    func fleetPurchaseQuote(category: VehicleCategory, count: Int, storeID: UUID) -> ProcurementQuote? {
        let fleetCategories: Set<VehicleCategory> = [.commercial, .pickup, .minivan, .kei]
        guard count >= 5, fleetCategories.contains(category),
              let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID) else { return nil }
        let localSupply = vehicleSupply(category, in: plot.district)
        let hasBusinessNetwork = store.concept == .business
        guard hasBusinessNetwork || localSupply >= 0.80 else { return nil }
        let strongRoute = hasBusinessNetwork || localSupply >= 1.15
        return ProcurementQuote(
            source: .fleetPurchase,
            modelID: nil,
            category: category,
            count: count,
            unitCost: Int((Double(category.purchaseCost) * (strongRoute ? 0.88 : 0.94)).rounded()),
            fee: 25,
            weeks: strongRoute ? 2 : 3,
            quality: 0.70,
            availabilityLabel: hasBusinessNetwork ? "法人仕入れ網" : "地域のリース満了車"
        )
    }

    @discardableResult
    func consignInventory(storeID: UUID, category: VehicleCategory, count: Int, venue: AuctionVenue) -> Bool {
        guard count > 0, let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let removed = removeInventory(category: category, count: count, from: storeIndex) else { return false }
        let specialtyBonus: Double
        switch (venue, category) {
        case (.premium, .imported), (.premium, .suv), (.port, .commercial), (.port, .pickup), (.port, .suv), (.east, .kei), (.east, .compact): specialtyBonus = 1.08
        default: specialtyBonus = 0.98
        }
        let expected = Int(Double(max(removed.averageCost, category.purchaseCost)) * (1.06 + removed.quality * 0.08) * specialtyBonus)
        auctionConsignments.append(AuctionConsignment(id: UUID(), storeID: storeID, venue: venue, modelID: nil, category: category, count: count, expectedUnitPrice: expected, monthsRemaining: 1))
        recalculateAssets()
        save()
        return true
    }

    @discardableResult
    func consignInventory(storeID: UUID, inventoryID: UUID, venue: AuctionVenue) -> Bool {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop }) else { return false }
        let unit = stores[storeIndex].inventory[batchIndex]
        stores[storeIndex].inventory[batchIndex].count -= 1
        if stores[storeIndex].inventory[batchIndex].count == 0 {
            stores[storeIndex].inventory.remove(at: batchIndex)
        }
        let specialtyBonus: Double
        switch (venue, unit.category) {
        case (.premium, .imported), (.premium, .suv), (.port, .commercial), (.port, .pickup), (.port, .suv), (.east, .kei), (.east, .compact): specialtyBonus = 1.08
        default: specialtyBonus = 0.98
        }
        let expected = Int(Double(max(unit.averageCost, unit.category.purchaseCost)) * (1.06 + unit.quality * 0.08) * specialtyBonus)
        auctionConsignments.append(AuctionConsignment(id: UUID(), storeID: storeID, venue: venue, modelID: unit.modelID, category: unit.category, count: 1, expectedUnitPrice: expected, monthsRemaining: 1))
        recalculateAssets()
        save()
        return true
    }

    func updateStore(_ store: Store) {
        guard let index = stores.firstIndex(where: { $0.id == store.id }) else { return }
        var changed = store
        if changed.concept.minimumGridCells > changed.plotIDs.count {
            changed.concept = stores[index].concept
        }
        changed.facilities.formUnion(changed.concept.defaultFacilities)
        changed.facilities = changed.facilities.filter { $0.minimumGridCells <= changed.plotIDs.count }
        if !changed.hasManager {
            changed.delegateStaff = false
            changed.delegatePricing = false
            changed.delegateProcurement = false
            changed.delegateMarketing = false
            changed.delegateService = false
        }
        stores[index] = changed
        synchronizeParcelUse(for: changed)
        save()
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
        let available = Self.employeeRoster.filter { !employedIDs.contains($0.id) }
        guard !available.isEmpty else { return [] }
        let count = min(3, available.count)
        let start = abs(store.plotID * 5 + turn / 4) % available.count
        return (0..<count).map { available[(start + $0) % available.count] }
    }

    private func interpolatedEmployeeEffect(score: Double, low: Double, high: Double) -> Double {
        let progress = min(1, max(0, (score - 20) / 75))
        return low + (high - low) * progress
    }

    func employeeSalesCloseAdjustment(_ employee: StoreEmployee) -> Double {
        interpolatedEmployeeEffect(score: employee.salesComposite, low: -0.05, high: 0.08)
    }

    func employeeAlternativeProposalAdjustment(_ employee: StoreEmployee, lead: BuyerLead, batch: InventoryBatch) -> Double {
        guard !inventoryPreferenceMatches(batch, preference: lead.preference) else { return 0 }
        return interpolatedEmployeeEffect(score: employee.salesComposite, low: -0.04, high: 0.30)
    }

    func employeeSalesCloseAdjustment(for storeID: UUID) -> Double {
        guard let store = stores.first(where: { $0.id == storeID }), store.autoSales,
              let employee = store.employees
            .filter({ $0.assignment == .sales })
            .max(by: { $0.salesComposite < $1.salesComposite }) else { return 0 }
        return employeeSalesCloseAdjustment(employee)
    }

    func employeeProcurementCloseAdjustment(_ employee: StoreEmployee) -> Double {
        interpolatedEmployeeEffect(score: employee.procurementComposite, low: -0.06, high: 0.09)
    }

    func employeeAppraisalAccuracyBonus(_ employee: StoreEmployee) -> Int {
        Int(interpolatedEmployeeEffect(score: employee.appraisalComposite, low: -10, high: 16).rounded())
    }

    func employeeAppraisalAccuracyBonus(for storeID: UUID) -> Int {
        guard let store = stores.first(where: { $0.id == storeID }) else { return 0 }
        let facilityBonus = store.facilities.contains(.quickAppraisal) ? 5 : 0
        return facilityBonus
    }

    func assignedEmployees(storeID: UUID, assignment: EmployeeAssignment) -> [StoreEmployee] {
        stores.first(where: { $0.id == storeID })?.employees.filter { $0.assignment == assignment } ?? []
    }

    func employeeMarketingScore(for storeID: UUID) -> Double {
        guard let store = stores.first(where: { $0.id == storeID }), store.autoMarketing else { return 50 }
        let scores = store.employees.filter { $0.assignment == .marketingResearch }.map(\.marketingComposite).sorted(by: >)
        guard let lead = scores.first else { return 50 }
        return min(95, lead + scores.dropFirst().reduce(0) { $0 + max(0, $1 - 50) * 0.25 })
    }

    func employeeMarketingEfficiency(for storeID: UUID, buyers: Bool) -> Double {
        guard let store = stores.first(where: { $0.id == storeID }), store.autoMarketing,
              store.employees.contains(where: { $0.assignment == .marketingResearch }) else { return 1 }
        let base = interpolatedEmployeeEffect(score: employeeMarketingScore(for: storeID), low: 0.80, high: 1.30)
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
        let scores = store.employees.filter { $0.assignment == .marketingResearch }.map { Double($0.marketResearchSkill) }.sorted(by: >)
        guard let lead = scores.first else { return 50 }
        return min(95, lead + scores.dropFirst().reduce(0) { $0 + max(0, $1 - 50) * 0.25 })
    }

    func hasMarketResearcher(storeID: UUID) -> Bool {
        guard let store = stores.first(where: { $0.id == storeID }) else { return false }
        return store.employees.contains { $0.assignment == .marketingResearch }
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
        interpolatedEmployeeEffect(score: marketResearchScore(for: storeID), low: 0.30, high: 0.02)
    }

    func marketForecastRange(value: Int, storeID: UUID) -> ClosedRange<Int> {
        let error = marketForecastErrorRate(for: storeID)
        let seed = turn * 401 + (stores.first(where: { $0.id == storeID })?.plotID ?? 0)
        let centerError = (transactionRoll(seed: seed) - 0.5) * error
        let center = Double(value) * (1 + centerError)
        let halfWidth = Double(value) * error / 2
        return max(0, Int((center - halfWidth).rounded()))...max(0, Int((center + halfWidth).rounded()))
    }

    func marketResearcherName(for storeID: UUID) -> String {
        guard let employee = stores.first(where: { $0.id == storeID })?.employees
            .filter({ $0.assignment == .marketingResearch })
            .max(by: { $0.marketResearchSkill < $1.marketResearchSkill }) else { return "オーナー調査" }
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
        let focus: CustomerFocus
        switch category {
        case .imported: focus = .affluent
        case .commercial, .pickup: focus = .business
        case .minivan, .suv: focus = .family
        default: focus = .value
        }
        cash -= offer.cost
        finance.investingCF -= offer.cost
        let store = Store(
            name: "\(targetPlot.district.shortName)買収店",
            plotID: plotID,
            plotIDs: [plotID],
            type: .small,
            acquisition: .purchase,
            focus: focus,
            concept: .general,
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
            stores[storeIndex].employees[employeeIndex].salesSkill = min(95, stores[storeIndex].employees[employeeIndex].salesSkill + 3)
        case .appraisal:
            stores[storeIndex].employees[employeeIndex].appraisalSkill = min(95, stores[storeIndex].employees[employeeIndex].appraisalSkill + 3)
        case .procurement:
            stores[storeIndex].employees[employeeIndex].procurementSkill = min(95, stores[storeIndex].employees[employeeIndex].procurementSkill + 3)
        case .marketing:
            stores[storeIndex].employees[employeeIndex].marketingSkill = min(95, stores[storeIndex].employees[employeeIndex].marketingSkill + 3)
        case .service:
            stores[storeIndex].employees[employeeIndex].serviceSkill = min(95, stores[storeIndex].employees[employeeIndex].serviceSkill + 3)
        case .marketResearch:
            stores[storeIndex].employees[employeeIndex].marketResearchSkill = min(95, stores[storeIndex].employees[employeeIndex].marketResearchSkill + 3)
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
              stores[storeIndex].employees[employeeIndex].monthlySalary < 70 else { return false }
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
        stores[index].delegateProcurement = false
        stores[index].delegateMarketing = false
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

    func manualSaleQuote(storeID: UUID, category: VehicleCategory) -> (price: Int, grossProfit: Int)? {
        guard let inventoryID = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.category == category && $0.count > 0 && !$0.isInWorkshop })?.id else { return nil }
        return manualSaleQuote(storeID: storeID, inventoryID: inventoryID)
    }

    func manualSaleQuote(storeID: UUID, inventoryID: UUID) -> (price: Int, grossProfit: Int)? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID),
              let batch = store.inventory.first(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop }) else { return nil }
        let marketValue = vehicleRetailValue(
            modelID: batch.modelID,
            category: batch.category,
            modelYear: batch.modelYear,
            mileage: batch.mileage,
            quality: batch.quality,
            in: plot.district
        )
        let conceptPremium = 1 + conceptMarginBonus(store.concept, category: batch.category, serviceAllocation: store.serviceAllocation) * 0.35
        let agingFactor = inventoryAgingValueFactor(for: batch)
        let specialtyFactor = specialtyMarketFactor(for: batch, in: plot.district)
        let disclosedIssueFactor = batch.disclosedIssue?.disclosedValueFactor ?? 1.0
        let price = max(25, Int(Double(marketValue) * conceptPremium * store.priceIndex * agingFactor * specialtyFactor * disclosedIssueFactor * competitivePriceFactor(in: plot.district)))
        return (price, price - batch.averageCost)
    }

    func manualNegotiationLimit(storeID: UUID) -> Int {
        weeklyOpportunityCapacity(storeID: storeID)
    }

    func canSellManually(storeID: UUID) -> Bool {
        guard let store = stores.first(where: { $0.id == storeID }) else { return false }
        return store.inventory.contains(where: { $0.count > 0 && !$0.isInWorkshop })
            && buyerLeads.contains(where: { $0.storeID == storeID })
            && remainingWeeklyOpportunities(storeID: storeID) > 0
    }

    func saleNegotiationPreview(storeID: UUID, category: VehicleCategory, strategy: SaleNegotiationStrategy) -> (price: Int, grossProfit: Int, closeChance: Double)? {
        guard let inventoryID = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.category == category && $0.count > 0 && !$0.isInWorkshop })?.id else { return nil }
        return saleNegotiationPreview(storeID: storeID, inventoryID: inventoryID, strategy: strategy)
    }

    func saleNegotiationPreview(storeID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy) -> (price: Int, grossProfit: Int, closeChance: Double)? {
        guard let batch = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop }),
              let lead = preferredBuyerLead(storeID: storeID, batch: batch) else { return nil }
        return saleNegotiationPreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: inventoryID, strategy: strategy)
    }

    func saleNegotiationPreview(storeID: UUID, buyerLeadID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy) -> (price: Int, grossProfit: Int, closeChance: Double)? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID),
              let batch = store.inventory.first(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop }),
              let lead = buyerLeads.first(where: { $0.id == buyerLeadID && $0.storeID == storeID }),
              let quote = manualSaleQuote(storeID: storeID, inventoryID: inventoryID) else { return nil }
        let offer = Int(Double(quote.price) * (1 - strategy.discountRate))
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
        let specialtyEffect = specialtyCloseAdjustment(for: batch, in: plot.district)
        let disclosedIssueEffect = batch.disclosedIssue == nil ? 0.0 : -0.06
        let facilityEffect = facilityCloseAdjustment(store: store, category: batch.category)
        let competitiveEffect = priceWarCloseAdjustment(in: plot.district)
        // Apply stock age after the common cap so a high-demand district cannot
        // completely hide the penalty for inventory that has sat for months.
        let baselineChance = min(0.93, max(0.03, strategy.baseCloseChance + demandEffect + reputationEffect + preferenceEffect + catalogEffect + qualityEffect + yearEffect + mileageEffect + budgetEffect + specialtyEffect + disclosedIssueEffect + facilityEffect + competitiveEffect))
        let chance = min(0.93, max(0.03, baselineChance + freshnessEffect))
        return (offer, offer - batch.averageCost, chance)
    }

    private func buyerBudgetEffect(price: Int, lead: BuyerLead) -> Double {
        let budgetRatio = Double(max(0, price)) / Double(max(1, lead.budget))
        return budgetRatio <= 1 ? 0.10 : -min(0.48, (budgetRatio - 1) * 1.35 * lead.priceSensitivity)
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
        let conceptPremium = 1 + conceptMarginBonus(store.concept, category: tradeIn.category, serviceAllocation: store.serviceAllocation) * 0.35
        let expectedTradeInSalePrice = max(25, Int(Double(baseRetail) * conceptPremium * store.priceIndex))
        let improvedBudgetEffect = buyerBudgetEffect(price: max(0, customerSettlement), lead: lead) - buyerBudgetEffect(price: sale.price, lead: lead)
        let closeChance = min(0.97, max(0.03, sale.closeChance + 0.08 + max(0, improvedBudgetEffect)))
        return TradeInSalePreview(
            salePrice: sale.price,
            saleGrossProfit: sale.grossProfit,
            allowance: tradeIn.appraisedValue,
            repairCost: tradeIn.repairCost,
            customerCashSettlement: customerSettlement,
            expectedTradeInSalePrice: expectedTradeInSalePrice,
            expectedTradeInGrossProfit: expectedTradeInSalePrice - tradeIn.appraisedValue - tradeIn.repairCost,
            closeChance: closeChance
        )
    }

    @discardableResult
    func negotiateManualSale(storeID: UUID, category: VehicleCategory, strategy: SaleNegotiationStrategy, acceptTradeIn: Bool = false) -> SaleNegotiationResult? {
        guard let inventoryID = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.category == category && $0.count > 0 && !$0.isInWorkshop })?.id else { return nil }
        return negotiateManualSale(storeID: storeID, inventoryID: inventoryID, strategy: strategy, acceptTradeIn: acceptTradeIn)
    }

    @discardableResult
    func negotiateManualSale(storeID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy, acceptTradeIn: Bool = false) -> SaleNegotiationResult? {
        guard let batch = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.id == inventoryID && !$0.isInWorkshop }),
              let lead = preferredBuyerLead(storeID: storeID, batch: batch) else { return nil }
        return negotiateManualSale(storeID: storeID, buyerLeadID: lead.id, inventoryID: inventoryID, strategy: strategy, acceptTradeIn: acceptTradeIn)
    }

    @discardableResult
    func negotiateManualSale(storeID: UUID, buyerLeadID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy, acceptTradeIn: Bool = false) -> SaleNegotiationResult? {
        guard canSellManually(storeID: storeID),
              let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop }),
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
                    averageCost: tradeIn.appraisedValue + tradeIn.repairCost,
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
            stores[storeIndex].lastSales = stores[storeIndex].manualSalesThisWeek
            stores[storeIndex].lastRevenue = stores[storeIndex].pendingManualRevenue
            stores[storeIndex].lastProfit = stores[storeIndex].pendingManualRevenue - stores[storeIndex].pendingManualCOGS
            stores[storeIndex].loyalCustomers = min(
                250,
                stores[storeIndex].loyalCustomers + loyalCustomerGain(store: stores[storeIndex], category: category)
            )
            scheduleCustomerClaimIfNeeded(for: soldVehicle, storeID: storeID, salePrice: preview.price, seed: seed + 401)
            recalculateAssets()
        }
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
        switch lead.preference {
        case .category(let desiredCategory):
            return batch.category == desiredCategory ? 0.16 : -0.30
        case .maker(let desiredCategory, let maker):
            if batch.category == desiredCategory, model?.maker == maker { return 0.24 }
            return batch.category == desiredCategory ? -0.34 : -0.48
        case .exactModel(let modelID):
            if batch.modelID == modelID { return 0.30 }
            if batch.category == lead.desiredCategory, model?.maker == lead.preference.preferredMaker { return -0.30 }
            return batch.category == lead.desiredCategory ? -0.58 : -0.72
        case .budgetFirst:
            return offerPrice <= lead.budget ? 0.12 : -0.06
        }
    }

    private func inventoryPreferenceMatches(_ batch: InventoryBatch, preference: BuyerVehiclePreference) -> Bool {
        let model = VehicleCatalog.entry(id: batch.modelID)
        switch preference {
        case .category(let category): return batch.category == category
        case .maker(let category, let maker): return batch.category == category && model?.maker == maker
        case .exactModel(let modelID): return batch.modelID == modelID
        case .budgetFirst: return true
        }
    }

    func inventoryMatchesBuyer(_ batch: InventoryBatch, lead: BuyerLead, storeID: UUID) -> Bool {
        guard batch.count > 0, !batch.isInWorkshop,
              batch.quality >= lead.minimumQuality,
              batch.modelYear >= lead.minimumModelYear,
              batch.mileage <= lead.maximumMileage,
              let price = manualSaleQuote(storeID: storeID, inventoryID: batch.id)?.price,
              price <= lead.budget else { return false }
        let model = VehicleCatalog.entry(id: batch.modelID)
        switch lead.preference {
        case .category(let category): return batch.category == category
        case .maker(let category, let maker): return batch.category == category && model?.maker == maker
        case .exactModel(let modelID): return batch.modelID == modelID
        case .budgetFirst: return true
        }
    }

    private func preferredBuyerLead(storeID: UUID, batch: InventoryBatch) -> BuyerLead? {
        buyerLeads
            .filter { $0.storeID == storeID }
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
              let batchIndex = stores[source].inventory.firstIndex(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop }) else { return false }
        let unit = stores[source].inventory[batchIndex]
        stores[source].inventory[batchIndex].count -= 1
        if stores[source].inventory[batchIndex].count == 0 {
            stores[source].inventory.remove(at: batchIndex)
        }
        stores[destination].inventory.append(InventoryBatch(modelID: unit.modelID, category: unit.category, count: 1, averageCost: unit.averageCost, quality: unit.quality, modelYear: unit.modelYear, mileage: unit.mileage, acquiredTurn: unit.acquiredTurn, productState: unit.productState, vehicleIssue: unit.vehicleIssue))
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
        let chance = min(0.98, max(0.28, baseChance + priceGap * 0.20 - retryPenalty))
        return (item.askingPrice * percent / 100, chance)
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
        let total = (preview.price + item.repairCost) * item.lotCount
        guard cash >= total,
              stores[storeIndex].inventoryCount + item.lotCount <= stores[storeIndex].type.capacity,
              remainingWeeklyOpportunities(storeID: item.storeID) > 0 else { return .unavailable }

        stores[storeIndex].pendingPurchaseNegotiations = stores[storeIndex].purchaseNegotiationsThisWeek + 1

        let seed = turn * 83 + item.modelYear * 7 + item.mileage / 1_000 + offerPercent * 13 + stores[storeIndex].usedOpportunitiesThisWeek * 37
        guard transactionRoll(seed: seed) < preview.closeChance else {
            let nextAttempt = item.negotiations + 1
            let walkedAway = nextAttempt >= 2 || offerPercent <= 88
            if walkedAway { purchaseCases.remove(at: caseIndex) }
            else { purchaseCases[caseIndex].negotiationAttempts = nextAttempt }
            save()
            return .rejected(walkedAway: walkedAway)
        }

        cash -= total
        stores[storeIndex].inventory.append(InventoryBatch(
            modelID: item.modelID,
            category: item.category,
            count: item.lotCount,
            averageCost: preview.price + item.repairCost,
            quality: Double(item.qualityAfterRepairScore) / 100,
            modelYear: item.modelYear,
            mileage: item.mileage,
            acquiredTurn: turn,
            vehicleIssue: item.hiddenIssue.map {
                VehicleIssueRecord(kind: $0, status: item.issueRevealed ? .disclosed : .hidden)
            }
        ))
        stores[storeIndex].reputation = min(1.25, stores[storeIndex].reputation + (tradeIn ? 0.012 : offerPercent < 94 ? -0.004 : 0.006))
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

    @discardableResult
    func inspectPurchaseCase(_ caseID: UUID) -> PurchaseInspectionResult {
        guard let index = purchaseCases.firstIndex(where: { $0.id == caseID }),
              purchaseCases[index].appraisalAccuracy < 96,
              cash >= 10 else { return .unavailable }
        cash -= 10
        purchaseCases[index].appraisalAccuracy = 96
        if let issue = purchaseCases[index].hiddenIssue {
            let item = purchaseCases[index]
            let inspectionRoll = transactionRoll(seed: item.modelYear * 43 + item.mileage / 500 + categoryIndex(item.category) * 71)
            if inspectionRoll < 0.96 {
                purchaseCases[index].issueRevealed = true
                save()
                return .issueFound(issue)
            }
        }
        save()
        return .noIssueDetected
    }

    func servicePreview(storeID: UUID, inventoryID: UUID) -> (cost: Int, qualityGain: Int, resultingQuality: Int)? {
        guard let batch = stores.first(where: { $0.id == storeID })?.inventory.first(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop }) else { return nil }
        let currentScore = Int((batch.quality * 100).rounded())
        guard currentScore <= 91 else { return nil }
        let gain = currentScore < 75 ? 4 : 3
        let resultingQuality = min(94, currentScore + gain)
        let cost = max(5, (100 - currentScore) * batch.category.purchaseCost / 350)
        return (cost, resultingQuality - currentScore, resultingQuality)
    }

    @discardableResult
    func serviceInventory(storeID: UUID, inventoryID: UUID) -> Bool {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.id == inventoryID && $0.count > 0 }),
              let preview = servicePreview(storeID: storeID, inventoryID: inventoryID),
              cash >= preview.cost else { return false }
        cash -= preview.cost
        let servicedQuality = Double(preview.resultingQuality) / 100.0
        if stores[storeIndex].inventory[batchIndex].count == 1 {
            stores[storeIndex].inventory[batchIndex].averageCost += preview.cost
            stores[storeIndex].inventory[batchIndex].quality = servicedQuality
        } else {
            let batch = stores[storeIndex].inventory[batchIndex]
            stores[storeIndex].inventory[batchIndex].count -= 1
            stores[storeIndex].inventory.append(InventoryBatch(
                modelID: batch.modelID,
                category: batch.category,
                count: 1,
                averageCost: batch.averageCost + preview.cost,
                quality: servicedQuality,
                modelYear: batch.modelYear,
                mileage: batch.mileage,
                acquiredTurn: batch.acquiredTurn,
                productState: batch.productState,
                vehicleIssue: batch.vehicleIssue
            ))
        }
        recalculateAssets()
        save()
        return true
    }

    func workshopProjectPreview(storeID: UUID, inventoryID: UUID, kind: WorkshopProjectKind) -> WorkshopProjectPreview? {
        guard let store = stores.first(where: { $0.id == storeID }),
              let plot = plot(id: store.plotID),
              let batch = store.inventory.first(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop }),
              let model = VehicleCatalog.entry(id: batch.modelID) else { return nil }
        if kind == .restoration && batch.productState != .stock { return nil }
        if kind == .customization && (!store.facilities.contains(.customWorkshop) || !model.isPopularCustomBase || batch.productState == .custom) { return nil }
        if kind == .camperConversion && (!store.facilities.contains(.customWorkshop) || batch.category != .minivan || batch.productState == .custom) { return nil }

        let currentQuality = Int((batch.quality * 100).rounded())
        let isClassic = model.isRareClassic
        let cost: Int
        let weeks: Int
        let requestedGain: Int
        let qualityCap = isClassic ? 90 : 94
        let targetState: VehicleProductState

        switch kind {
        case .restoration:
            if isClassic {
                let deterioration = max(0, 0.82 - batch.quality)
                cost = max(180, Int(Double(model.baseWholesalePrice) * (0.42 + deterioration * 1.10)))
                weeks = min(8, max(5, 5 + Int(deterioration * 8)))
                requestedGain = currentQuality < 65 ? 7 : 5
            } else {
                cost = max(18, (100 - currentQuality) * batch.category.purchaseCost / 130)
                weeks = currentQuality < 70 ? 3 : 2
                requestedGain = currentQuality < 75 ? 4 : 3
            }
            targetState = .restored
        case .customization:
            if isClassic {
                cost = max(260, Int(Double(model.baseWholesalePrice) * (0.95 + model.customAppeal * 0.25)))
                weeks = min(8, max(6, 6 + Int((0.72 - batch.quality) * 5)))
                requestedGain = 3
            } else {
                cost = max(45, Int(Double(batch.category.purchaseCost) * (0.55 + model.customAppeal * 0.35)))
                weeks = model.customAppeal >= 1.25 ? 4 : 3
                requestedGain = 2
            }
            targetState = .custom
        case .camperConversion:
            cost = max(180, Int(Double(batch.category.purchaseCost) * 1.15))
            weeks = 5
            requestedGain = 3
            targetState = .custom
        }

        let resultingQuality = min(qualityCap, currentQuality + requestedGain)
        var projected = batch
        projected.quality = Double(resultingQuality) / 100.0
        projected.averageCost += cost
        projected.productState = targetState
        projected.workshopProject = nil
        let marketValue = vehicleRetailValue(
            modelID: projected.modelID,
            category: projected.category,
            modelYear: projected.modelYear,
            mileage: projected.mileage,
            quality: projected.quality,
            in: plot.district
        )
        let conceptPremium = 1 + conceptMarginBonus(store.concept, category: projected.category, serviceAllocation: store.serviceAllocation) * 0.35
        let disclosedIssueFactor = projected.disclosedIssue?.disclosedValueFactor ?? 1.0
        let projectedPrice = max(25, Int(Double(marketValue) * conceptPremium * store.priceIndex * inventoryAgingValueFactor(for: projected) * specialtyMarketFactor(for: projected, in: plot.district) * disclosedIssueFactor))
        let serviceLead = store.autoService ? store.employees.filter { $0.assignment == .service }.max(by: { $0.serviceComposite < $1.serviceComposite }) : nil
        let effectiveWeeks = serviceLead?.serviceComposite ?? 0 >= 80 ? max(1, weeks - 1) : weeks
        return WorkshopProjectPreview(
            kind: kind,
            cost: cost,
            weeks: effectiveWeeks,
            qualityGain: resultingQuality - currentQuality,
            resultingQuality: resultingQuality,
            projectedSalePrice: projectedPrice
        )
    }

    @discardableResult
    func startWorkshopProject(storeID: UUID, inventoryID: UUID, kind: WorkshopProjectKind) -> Bool {
        guard let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.id == inventoryID && $0.count > 0 && !$0.isInWorkshop }),
              let preview = workshopProjectPreview(storeID: storeID, inventoryID: inventoryID, kind: kind),
              cash >= preview.cost else { return false }

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
                vehicleIssue: original.vehicleIssue
            ))
        }
        cash -= preview.cost
        finance.operatingCF -= preview.cost
        stores[storeIndex].inventory[batchIndex].averageCost += preview.cost
        stores[storeIndex].inventory[batchIndex].workshopProject = VehicleWorkshopProject(
            kind: kind,
            totalWeeks: preview.weeks,
            remainingWeeks: preview.weeks,
            cost: preview.cost,
            qualityGain: preview.qualityGain
        )
        recalculateAssets()
        save()
        return true
    }

    func declinePurchaseCase(_ caseID: UUID) {
        purchaseCases.removeAll { $0.id == caseID }
        save()
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
        if let tutorialStep, tutorialStep != .completed, tutorialStep != .runFirstMonth {
            tutorialMessage = "先に「\(tutorialStep.title)」を完了してください。"
            return
        }
        let isFirstTutorialMonth = tutorialStep == .runFirstMonth
        if isFirstTutorialMonth,
           !stores.contains(where: { $0.plotID == tutorialPlotID && $0.manualNegotiationsThisWeek > 0 }) {
            tutorialMessage = "店舗画面でお客様と販売価格を交渉してから、最初の1週間を完了してください。"
            return
        }
        let reportYear = year, reportMonth = month, reportWeek = weekOfMonth
        var totalSales = 0, revenue = 0, costOfSales = 0, personnel = 0, rent = 0, ads = 0, depreciation = 0
        var revenueToCollect = 0
        var notes: [String] = []
        let claimCostsByStore = resolveCustomerClaims(at: turn + 1, notes: &notes)
        let claimCosts = claimCostsByStore.values.reduce(0, +)
        progressWorkshopProjects(notes: &notes)
        progressStoreProjects(notes: &notes)
        applyDelegatedOperations(notes: &notes)
        processInboundShipments(notes: &notes)
        processIntercityShipments(notes: &notes)
        settleAuctionConsignments(notes: &notes)
        resolveAuctionBids(at: turn + 1, notes: &notes)
        resolveCompetitorAuctionPurchases(at: turn + 1, notes: &notes)
        beginEmployeeWeek()
        var automaticSalesByStore: [UUID: AutomaticSaleResult] = [:]
        for index in stores.indices where stores[index].isOperational {
            progressAutomaticMarketing(for: index)
            resolveAutomaticService(for: index)
            resolveAutomaticPurchases(for: index)
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

            let storeRevenue = stores[index].pendingManualRevenue + automatic.revenue
            let storeCOGS = stores[index].pendingManualCOGS + automatic.costOfSales
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
            let inventoryPenalty = capacity == 0 ? 0.4 : 0.0
            stores[index].lastSales = sales
            stores[index].lastRevenue = storeRevenue
            stores[index].lastProfit = storeProfit
            stores[index].satisfaction = min(96, max(42, Int(58 + stores[index].type.serviceQuality * 12 + stores[index].serviceAllocation * 20 - max(0, stores[index].priceIndex - 1) * 24 - inventoryPenalty * 12)))
            stores[index].reputation = min(1.25, max(0.4, stores[index].reputation + (Double(stores[index].satisfaction) - 70) / 4_000))
            stores[index].causes = makeCauses(demand: demand, concept: conceptMatch, conceptName: stores[index].concept.name, marketing: marketing, competition: competition, inventory: capacity)
            stores[index].pendingManualSales = 0
            stores[index].pendingManualRevenue = 0
            stores[index].pendingManualCOGS = 0
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
        finance = FinanceSnapshot(revenue: revenue, costOfSales: costOfSales, personnel: personnel, rent: rent, advertising: ads, depreciation: depreciation, customerClaims: claimCosts, operatingProfit: operatingProfit, landAssets: finance.landAssets, buildingAssets: finance.buildingAssets, inventoryAssets: inventoryAssetValue(), debt: debt, operatingCF: operatingProfit + depreciation, investingCF: 0, financingCF: -interest)
        simulateDistrictDynamics(notes: &notes)
        updateEconomicIndex(notes: &notes)
        updateFuelPrice(notes: &notes)
        updateLandValues(notes: &notes)
        progressDevelopments(notes: &notes)
        simulateCompetitors(notes: &notes)
        expireWeeklyCustomerLeads(notes: &notes)
        turn += 1
        announceNewModels(notes: &notes)
        weekOfMonth += 1
        if weekOfMonth > 4 {
            weekOfMonth = 1
            month += 1
            if month > 12 { month = 1; year += 1 }
        }
        generateWeeklyCustomerLeads()
        generateAuctionListings()
        unlockTutorial(notes: &notes)
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
        let report = MonthlyReport(id: UUID(), year: reportYear, month: reportMonth, week: reportWeek, sales: totalSales, revenue: revenue, grossProfit: revenue - costOfSales, operatingProfit: operatingProfit, cashChange: cashChange, averageInventoryWeeks: averageInventoryWeeks, headline: headline, notes: notes)
        reports.insert(report, at: 0); lastReport = report
        if isFirstTutorialMonth {
            tutorialStep = .completed
            tutorialMessage = "創業チュートリアル完了。店員で対応枠を増やし、必要になったら店長へ業務を委任しましょう。"
        }
        showMonthlyReport = UserDefaults.standard.object(forKey: "settings.autoShowWeeklyReport") as? Bool ?? true
        if financialDistressWeeks >= 2 { gameOver = true }
        if turn >= maxTurns { gameOver = true }
        recalculateAssets()
        save()
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

    private func focusFit(_ focus: CustomerFocus, district: DistrictKind) -> Double {
        switch (focus, district) {
        case (.family, .suburb), (.family, .emerging), (.value, .industrial), (.value, .highway), (.young, .station), (.affluent, .downtown), (.business, .industrial): 1.18
        case (.affluent, .industrial), (.business, .station): 0.82
        default: 1.0
        }
    }

    private func demandFit(store: Store, district: District) -> Double {
        let stocked = store.inventory.filter { $0.count > 0 && !$0.isInWorkshop }
        guard !stocked.isEmpty else { return 0.45 }
        let weighted = stocked.reduce(0.0) { $0 + (district.demands[$1.category] ?? 0.7) * Double($1.count) }
        return weighted / Double(max(1, store.inventoryCount)) * focusFit(store.focus, district: district.kind) * store.reputation
    }

    private func conceptDemandFit(_ concept: StoreConcept, district: District) -> Double {
        guard concept != .general else { return 1.0 }
        let cityAverage = district.demands.values.reduce(0, +) / Double(max(1, district.demands.count))
        let targetValues = concept.targetCategories.map { district.demands[$0] ?? cityAverage }
        let targetAverage = targetValues.reduce(0, +) / Double(max(1, targetValues.count))
        // A location changes the size of the reachable customer pool, but it
        // never invalidates a business model or applies a named district rule.
        return min(1.12, max(0.88, targetAverage / max(0.01, cityAverage)))
    }

    private func conceptMarginBonus(_ concept: StoreConcept, category: VehicleCategory, serviceAllocation: Double) -> Double {
        switch concept {
        case .outdoor:
            let suitedCategory = [.minivan, .suv, .pickup].contains(category)
            return suitedCategory ? 0.08 + serviceAllocation * 0.16 : 0.02
        case .affluent:
            return [.imported, .suv].contains(category) ? 0.13 : 0.03
        case .localValue:
            return [.kei, .compact].contains(category) ? 0.055 : 0.01
        case .family:
            return [.minivan, .suv].contains(category) ? 0.06 : 0.015
        case .business:
            return [.commercial, .pickup].contains(category) ? 0.07 : 0.015
        case .general:
            return 0
        }
    }

    private func conceptBuyerFactor(_ concept: StoreConcept, category: VehicleCategory?) -> Double {
        guard let category else {
            return switch concept {
            case .general: 1.0
            case .localValue, .family: 1.08
            case .outdoor: 0.62
            case .affluent: 0.34
            case .business: 0.08
            }
        }
        if concept.targetCategories.contains(category) { return 1.28 }
        switch concept {
        case .general: return 1.0
        case .localValue, .family: return 0.52
        case .outdoor: return 0.24
        case .affluent: return 0.12
        case .business: return 0.04
        }
    }

    private func facilityBuyerFactor(_ store: Store, category: VehicleCategory?) -> Double {
        var factor = 1.0
        if store.facilities.contains(.kidsSpace), let category,
           [.kei, .compact, .minivan, .suv].contains(category) {
            factor *= 1.18
        }
        if store.facilities.contains(.corporateDesk), let category,
           [.commercial, .pickup].contains(category) {
            factor *= 1.22
        }
        if store.facilities.contains(.importLounge), let category,
           [.imported, .suv].contains(category) {
            factor *= 1.18
        }
        if store.facilities.contains(.customWorkshop), let category,
           [.minivan, .suv, .pickup].contains(category) {
            factor *= 1.14
        }
        return factor
    }

    private func facilitySellerFactor(_ store: Store, category: VehicleCategory) -> Double {
        var factor = store.facilities.contains(.quickAppraisal) ? 1.24 : 1.0
        if store.facilities.contains(.corporateDesk),
           [.kei, .compact, .commercial, .pickup].contains(category) {
            factor *= 1.42
        }
        if store.facilities.contains(.importLounge), category == .imported {
            factor *= 1.18
        }
        return factor
    }

    func buyerAttractionFactor(for store: Store, category: VehicleCategory?) -> Double {
        conceptBuyerFactor(store.concept, category: category)
            * facilityBuyerFactor(store, category: category)
    }

    func sellerAttractionFactor(for store: Store, category: VehicleCategory) -> Double {
        facilitySellerFactor(store, category: category)
    }

    func procurementLotSize(for store: Store, category: VehicleCategory, seed: Int) -> Int {
        let isCorporateFleet = store.concept == .business
            && store.facilities.contains(.corporateDesk)
            && [.kei, .compact, .commercial, .pickup].contains(category)
        return isCorporateFleet ? 2 + abs(seed % 3) : 1
    }

    private func facilityMarketFactor(_ store: Store) -> Double {
        1 + min(0.24, Double(store.facilities.count) * 0.06)
            + min(0.20, Double(store.loyalCustomers) * 0.004)
    }

    private func facilityCloseAdjustment(store: Store, category: VehicleCategory) -> Double {
        var adjustment = 0.0
        if store.facilities.contains(.kidsSpace), [.kei, .compact, .minivan, .suv].contains(category) {
            adjustment += 0.08
        }
        if store.facilities.contains(.corporateDesk), [.commercial, .pickup].contains(category) {
            adjustment += 0.07
        }
        if store.facilities.contains(.importLounge), [.imported, .suv].contains(category) {
            adjustment += 0.07
        }
        if store.facilities.contains(.customWorkshop), [.minivan, .suv, .pickup].contains(category) {
            adjustment += 0.05
        }
        return adjustment
    }

    private func loyalCustomerGain(store: Store, category: VehicleCategory) -> Int {
        let facilityMatches = facilityCloseAdjustment(store: store, category: category) > 0
        return store.concept.targetCategories.contains(category) && facilityMatches ? 2 : 1
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
        return 0.65 + roll * 0.72
    }

    private func updateEconomicIndex(notes: inout [String]) {
        let previous = economicIndex
        let shock = (transactionRoll(seed: turn * 211 + 73) - 0.5) * 0.045
        let pullToNormal = (1 - economicIndex) * 0.06
        economicIndex = min(1.28, max(0.72, economicIndex + pullToNormal + shock))
        if abs(economicIndex - previous) >= 0.018 {
            let direction = economicIndex >= previous ? "改善" : "悪化"
            notes.append("市況が\(direction)し、景気指数は\(Int(economicIndex * 100))です")
        }
    }

    private func updateFuelPrice(notes: inout [String]) {
        let previous = fuelPriceIndex
        let roll = transactionRoll(seed: turn * 227 + 91)
        let weeklyNoise = (roll - 0.5) * 0.038
        let supplyShock: Double
        if roll < 0.035 {
            supplyShock = 0.09
        } else if roll > 0.965 {
            supplyShock = -0.075
        } else {
            supplyShock = 0
        }
        let pullToNormal = (1 - fuelPriceIndex) * 0.035
        fuelPriceIndex = min(1.48, max(0.72, fuelPriceIndex + pullToNormal + weeklyNoise + supplyShock))
        guard abs(fuelPriceIndex - previous) >= 0.045 || turn.isMultiple(of: 12) else { return }
        let direction = fuelPriceIndex >= previous ? "上昇" : "下落"
        let detail = "燃料価格が\(direction)し、指数は\(Int(fuelPriceIndex * 100))。高騰時はEV・ハイブリッド・低燃費車の人気が上がります"
        notes.append(detail)
        recordCityEvent(CityEvent(turn: turn + 1, kind: .fuelPrice, title: "燃料価格が\(direction)", detail: detail, isPositive: fuelPriceIndex <= 1.0))
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
            let pressuredDistricts = Set(competitors[index].plotIDs.compactMap { plot(id: $0)?.district }).filter { district in
                let ownShare = stores
                    .filter { $0.isOperational && plot(id: $0.plotID)?.district == district }
                    .reduce(0.0) { $0 + marketShare(for: $1) }
                return ownShare > competitorMarketShare(competitors[index], in: district) + 0.08
            }.count
            let activeCampaigns = activePriceWars.filter { $0.competitorID == competitors[index].id }.count
            competitors[index].cash += Int(competitors[index].strength * 105) - competitors[index].plotIDs.count * 20 - activeCampaigns * 100
            let strengthChange = pressuredDistricts > 0 ? -Double(pressuredDistricts) * 0.003 : 0.0005
            competitors[index].strength = min(1.28, max(0.72, competitors[index].strength + strengthChange))
        }

        if turn >= 40 && turn % 44 == 0 {
            let candidates = competitors.indices.flatMap { companyIndex in
                competitors[companyIndex].plotIDs.map { (companyIndex, $0) }
            }.filter { companyIndex, _ in competitors[companyIndex].plotIDs.count > 1 }
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
        competitors[companyIndex].plotIDs.append(candidate.id)
        plots[plotIndex].occupant = .competitor(name: competitors[companyIndex].name)
        let event = CityEvent(turn: turn + 1, kind: .competitorEntry, title: "競合が新規出店", detail: "\(competitors[companyIndex].name)が\(candidate.district.shortName)地区へ参入しました", district: candidate.district, plotID: candidate.id, isPositive: false)
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
                districts[index].demands[category] = min(1.75, max(0.38, current + categoryShift))
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

    private func vehicleModel(for category: VehicleCategory, seed: Int) -> VehicleCatalogEntry {
        let candidates = VehicleCatalog.available(through: turn).filter { $0.category == category && !$0.isRareClassic }
        precondition(!candidates.isEmpty, "Every vehicle category must have an available catalog model")
        let weighted = candidates.map { model -> (model: VehicleCatalogEntry, weight: Double) in
            let identifierSeed = model.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            let fashion = deterministicVariation(seed: (turn / 13) * 97 + identifierSeed)
            let newerGenerations = VehicleCatalog.releasedNewCars(through: turn).filter {
                $0.maker == model.maker && $0.category == model.category && $0.launchTurn > model.launchTurn
            }.count
            let replacement = max(0.68, pow(0.92, Double(newerGenerations)))
            let supply = pow(max(0.02, usedMarketSupplyFactor(for: model)), 0.78)
            let transition = powertrainDemandFactor(for: model, in: .suburb)
            return (model, max(0.01, model.customerDemandIndex * fashion * replacement * supply * transition))
        }
        let total = weighted.reduce(0.0) { $0 + $1.weight }
        var cursor = transactionRoll(seed: seed) * total
        for item in weighted {
            cursor -= item.weight
            if cursor <= 0 { return item.model }
        }
        return weighted.last!.model
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
                stores[storeIndex].reputation = max(0.40, stores[storeIndex].reputation - claim.issue.reputationPenalty)
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
            for batchIndex in stores[storeIndex].inventory.indices {
                guard var project = stores[storeIndex].inventory[batchIndex].workshopProject else { continue }
                project.remainingWeeks -= 1
                if project.remainingWeeks > 0 {
                    stores[storeIndex].inventory[batchIndex].workshopProject = project
                    continue
                }
                let before = Int((stores[storeIndex].inventory[batchIndex].quality * 100).rounded())
                let cap = stores[storeIndex].inventory[batchIndex].isRareClassic ? 90 : 94
                let after = min(cap, before + project.qualityGain)
                stores[storeIndex].inventory[batchIndex].quality = Double(after) / 100.0
                stores[storeIndex].inventory[batchIndex].productState = project.kind == .restoration ? .restored : .custom
                stores[storeIndex].inventory[batchIndex].workshopProject = nil
                if project.kind != .restoration {
                    stores[storeIndex].loyalCustomers = min(250, stores[storeIndex].loyalCustomers + 2)
                }
                notes.append("\(stores[storeIndex].name)：\(stores[storeIndex].inventory[batchIndex].vehicleName)の\(project.kind.name)が完成（品質\(after)）")
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
        stores.flatMap(\.inventory).reduce(0) { $0 + $1.averageCost * $1.count }
            + regionalOperations.flatMap(\.inventory).reduce(0) { $0 + $1.averageCost * $1.count }
            + intercityShipments.reduce(0) { $0 + $1.unitCost * $1.count }
    }

    private func removeInventory(category: VehicleCategory, count: Int, from storeIndex: Int) -> RemovedInventory? {
        guard count > 0,
              stores.indices.contains(storeIndex),
              stores[storeIndex].inventory.filter({ $0.category == category && $0.productState == .stock && !$0.isInWorkshop }).reduce(0, { $0 + $1.count }) >= count else { return nil }
        var remaining = count
        var totalCost = 0
        var totalQuality = 0.0
        var totalModelYear = 0
        var totalMileage = 0
        var totalAcquiredTurn = 0
        var representativeModelID: String?
        var representativeIssue: VehicleIssueRecord?
        while remaining > 0,
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.category == category && $0.count > 0 && $0.productState == .stock && !$0.isInWorkshop }) {
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
            addInventory(category: shipment.category, modelID: shipment.modelID, count: shipment.count, unitCost: shipment.unitCost, quality: shipment.quality, modelYear: shipment.modelYear, mileage: shipment.mileage, acquiredTurn: shipment.acquiredTurn, to: storeIndex)
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
            while handledByEmployee < 7,
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
                let alternativeLift = employeeAlternativeProposalAdjustment(handler, lead: lead, batch: stores[storeIndex].inventory[batchIndex])
                let closeChance = min(0.97, max(0.03, baseChance + employeeSalesCloseAdjustment(handler) + alternativeLift))
                buyerLeads.removeAll { $0.id == lead.id }
                let succeeded = transactionRoll(seed: seed) < closeChance
                updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) { $0.handled += 1 }
                awardEmployeeExperience(employeeID: handler.id, storeIndex: storeIndex, focus: .sales, successful: succeeded)
                guard succeeded else { continue }

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
                        averageCost: tradeIn.appraisedValue + tradeIn.repairCost,
                        quality: tradeIn.qualityAfterRepair,
                        modelYear: tradeIn.modelYear,
                        mileage: tradeIn.mileage,
                        acquiredTurn: turn
                    ))
                    result.cashCollected += tradePreview.cashImpact
                    result.tradeIns += 1
                } else {
                    result.cashCollected += preview.price
                }
                let grossProfit = preview.price - unitCost
                let commission = max(0, grossProfit) * handler.commissionRate / 100
                result.sales += 1
                result.revenue += preview.price
                result.costOfSales += unitCost
                result.commission += commission
                updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) {
                    $0.successes += 1
                    $0.grossProfit += grossProfit
                    $0.commission += commission
                }
                stores[storeIndex].loyalCustomers = min(
                    250,
                    stores[storeIndex].loyalCustomers + loyalCustomerGain(store: stores[storeIndex], category: category)
                )
                scheduleCustomerClaimIfNeeded(for: soldVehicle, storeID: storeID, salePrice: preview.price, seed: seed + 409)
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
            guard skill < 95, total >= 12 else { return (skill, skill >= 95 ? min(12, total) : total) }
            return (skill + 1, total - 12)
        }
        switch focus {
        case .sales:
            (employee.salesSkill, employee.salesExperience) = advanced(employee.salesSkill, employee.salesExperience)
        case .appraisal:
            (employee.appraisalSkill, employee.appraisalExperience) = advanced(employee.appraisalSkill, employee.appraisalExperience)
        case .procurement:
            (employee.procurementSkill, employee.procurementExperience) = advanced(employee.procurementSkill, employee.procurementExperience)
        case .marketing:
            (employee.marketingSkill, employee.marketingExperience) = advanced(employee.marketingSkill, employee.marketingExperience)
        case .service:
            (employee.serviceSkill, employee.serviceExperience) = advanced(employee.serviceSkill, employee.serviceExperience)
        case .marketResearch:
            (employee.marketResearchSkill, employee.marketResearchExperience) = advanced(employee.marketResearchSkill, employee.marketResearchExperience)
        }
        let newOverall = employee.overallSkill
        if newOverall / 5 > oldOverall / 5 {
            employee.monthlySalary += 1
        }
        stores[storeIndex].employees[employeeIndex] = employee
    }

    private func scheduleCustomerClaimIfNeeded(for batch: InventoryBatch, storeID: UUID, salePrice: Int, seed: Int) {
        guard let issue = batch.vehicleIssue, issue.status == .hidden else { return }
        let compensation = max(30, Int(Double(salePrice) * issue.kind.compensationRate))
        pendingCustomerClaims.append(PendingCustomerClaim(
            id: UUID(),
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

    private func resolveAutomaticPurchases(for storeIndex: Int) {
        guard stores.indices.contains(storeIndex), stores[storeIndex].autoProcurement else { return }
        let storeID = stores[storeIndex].id
        let handlers = stores[storeIndex].employees
            .filter { $0.assignment == .procurement }
            .sorted { $0.procurementComposite > $1.procurementComposite }
        guard !handlers.isEmpty else { return }
        let policy = stores[storeIndex].procurementPolicy
        var totalAttempts = 0

        for handler in handlers {
            var candidates = purchaseCases.filter { item in
                guard item.storeID == storeID else { return false }
                switch policy {
                case .profit: return item.expectedGrossProfit > 0
                case .balanced: return item.expectedGrossProfit >= 0
                case .volume: return true
                }
            }
            candidates.sort { $0.expectedGrossProfit > $1.expectedGrossProfit }

            for original in candidates.prefix(7) {
                guard let caseIndex = purchaseCases.firstIndex(where: { $0.id == original.id }) else { continue }
                var item = purchaseCases[caseIndex]
                let seed = turn * 263 + item.modelYear * 7 + item.mileage / 1_000 + totalAttempts * 29
                let accuracy = min(96, max(35, item.appraisalAccuracy + employeeAppraisalAccuracyBonus(handler)))
                var issueFound = item.issueRevealed
                if item.hiddenIssue != nil, !issueFound,
                   transactionRoll(seed: seed + 113) < Double(accuracy) / 100 {
                    issueFound = true
                }
                purchaseCases[caseIndex].appraisalAccuracy = accuracy
                purchaseCases[caseIndex].issueRevealed = issueFound
                item = purchaseCases[caseIndex]
                guard let basePreview = purchaseNegotiationPreview(item.id, offerPercent: policy.offerPercent) else { continue }
                let total = (basePreview.price + item.repairCost) * item.lotCount
                guard cash >= total,
                      stores[storeIndex].inventoryCount + item.lotCount <= stores[storeIndex].type.capacity else { continue }

                totalAttempts += 1
                let chance = min(0.98, max(0.05, basePreview.closeChance + employeeProcurementCloseAdjustment(handler)))
                let succeeded = transactionRoll(seed: seed) < chance
                let expectedGrossProfit = (item.expectedSaleAfterAppraisal - basePreview.price - item.repairCost) * item.lotCount
                updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) {
                    $0.handled += 1
                    if issueFound && !original.issueRevealed { $0.issuesFound += 1 }
                }
                awardEmployeeExperience(employeeID: handler.id, storeIndex: storeIndex, focus: .procurement, successful: succeeded)
                if issueFound && !original.issueRevealed {
                    awardEmployeeExperience(employeeID: handler.id, storeIndex: storeIndex, focus: .appraisal, successful: true)
                }
                if succeeded {
                    cash -= total
                    stores[storeIndex].inventory.append(InventoryBatch(
                        modelID: item.modelID,
                        category: item.category,
                        count: item.lotCount,
                        averageCost: basePreview.price + item.repairCost,
                        quality: Double(item.qualityAfterRepairScore) / 100,
                        modelYear: item.modelYear,
                        mileage: item.mileage,
                        acquiredTurn: turn,
                        vehicleIssue: item.hiddenIssue.map {
                            VehicleIssueRecord(kind: $0, status: issueFound ? .disclosed : .hidden)
                        }
                    ))
                    updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) {
                        $0.successes += 1
                        $0.grossProfit += expectedGrossProfit
                    }
                }
                purchaseCases.removeAll { $0.id == item.id }
            }
        }
    }

    private func resolveAutomaticService(for storeIndex: Int) {
        guard stores.indices.contains(storeIndex), stores[storeIndex].autoService else { return }
        let storeID = stores[storeIndex].id
        let handlers = stores[storeIndex].employees
            .filter { $0.assignment == .service }
            .sorted { $0.serviceComposite > $1.serviceComposite }
        for handler in handlers {
            let capacity = handler.serviceComposite >= 80 ? 3 : handler.serviceComposite >= 60 ? 2 : 1
            for _ in 0..<capacity {
                let candidateIndices = stores[storeIndex].inventory.indices.filter { index in
                    let batch = stores[storeIndex].inventory[index]
                    guard batch.count > 0, !batch.isInWorkshop else { return false }
                    let quality = Int((batch.quality * 100).rounded())
                    switch stores[storeIndex].servicePolicy {
                    case .cost: return quality < 70
                    case .balanced: return quality < 80
                    case .quality: return quality < 90
                    }
                }
                guard let batchIndex = candidateIndices.min(by: {
                    stores[storeIndex].inventory[$0].quality < stores[storeIndex].inventory[$1].quality
                }) else { break }
                let batch = stores[storeIndex].inventory[batchIndex]
                guard let base = servicePreview(storeID: storeID, inventoryID: batch.id) else { break }
                let costFactor = interpolatedEmployeeEffect(score: handler.serviceComposite, low: 1.10, high: 0.82)
                let cost = max(1, Int((Double(base.cost) * costFactor).rounded()))
                let bonus = handler.serviceComposite >= 90 ? 2 : handler.serviceComposite >= 70 ? 1 : 0
                let resultingQuality = min(94, base.resultingQuality + bonus)
                if stores[storeIndex].servicePolicy == .balanced {
                    let currentPrice = manualSaleQuote(storeID: storeID, inventoryID: batch.id)?.price ?? 0
                    let valueIncrease = Int(Double(currentPrice) * Double(resultingQuality - Int((batch.quality * 100).rounded())) / 100)
                    guard valueIncrease >= cost else { break }
                }
                guard cash >= cost else { break }
                cash -= cost
                let servicedQuality = Double(resultingQuality) / 100
                var issueFound = false
                var servicedIssue = batch.vehicleIssue
                if let issue = batch.vehicleIssue, issue.status == .hidden,
                   transactionRoll(seed: turn * 347 + batch.modelYear + batch.mileage / 500 + handler.id.uuidString.count) < handler.appraisalComposite / 100 {
                    servicedIssue = VehicleIssueRecord(kind: issue.kind, status: .disclosed)
                    issueFound = true
                }
                if stores[storeIndex].inventory[batchIndex].count == 1 {
                    stores[storeIndex].inventory[batchIndex].averageCost += cost
                    stores[storeIndex].inventory[batchIndex].quality = servicedQuality
                    stores[storeIndex].inventory[batchIndex].vehicleIssue = servicedIssue
                } else {
                    stores[storeIndex].inventory[batchIndex].count -= 1
                    stores[storeIndex].inventory.append(InventoryBatch(
                        modelID: batch.modelID,
                        category: batch.category,
                        count: 1,
                        averageCost: batch.averageCost + cost,
                        quality: servicedQuality,
                        modelYear: batch.modelYear,
                        mileage: batch.mileage,
                        acquiredTurn: batch.acquiredTurn,
                        productState: batch.productState,
                        vehicleIssue: servicedIssue
                    ))
                }
                updateEmployeePerformance(employeeID: handler.id, storeIndex: storeIndex) {
                    $0.handled += 1
                    $0.successes += 1
                    $0.servicesCompleted += 1
                    if issueFound { $0.issuesFound += 1 }
                }
                awardEmployeeExperience(employeeID: handler.id, storeIndex: storeIndex, focus: .service, successful: true)
                if issueFound {
                    awardEmployeeExperience(employeeID: handler.id, storeIndex: storeIndex, focus: .appraisal, successful: true)
                }
            }
        }
    }

    private func progressAutomaticMarketing(for storeIndex: Int) {
        guard stores.indices.contains(storeIndex), stores[storeIndex].autoMarketing else { return }
        let employeeIDs = stores[storeIndex].employees.filter { $0.assignment == .marketingResearch }.map(\.id)
        for employeeID in employeeIDs {
            awardEmployeeExperience(employeeID: employeeID, storeIndex: storeIndex, focus: .marketing, successful: true)
            awardEmployeeExperience(employeeID: employeeID, storeIndex: storeIndex, focus: .marketResearch, successful: true)
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
               let researcher = stores[storeIndex].employees.filter({ $0.assignment == .marketingResearch }).max(by: { $0.marketResearchSkill < $1.marketResearchSkill }) {
                notes.append("\(stores[storeIndex].name) \(researcher.name)：広告効率\(Int((employeeMarketingEfficiency(for: stores[storeIndex].id, buyers: true) * 100).rounded()))%・市場予測±\(Int((marketForecastErrorRate(for: stores[storeIndex].id) * 100).rounded()))%")
            }
        }
    }

    private func expireWeeklyCustomerLeads(notes: inout [String]) {
        for store in stores where store.isOperational {
            let missedBuyers = buyerLeads.filter { $0.storeID == store.id }.count
            let missedSellers = purchaseCases.filter { $0.storeID == store.id }.count
            if missedBuyers > 0 || missedSellers > 0 {
                notes.append("\(store.name)：未対応・不一致で販売客\(missedBuyers)人、買取客\(missedSellers)人を見送り")
            }
        }
        buyerLeads.removeAll()
        purchaseCases.removeAll()
    }

    private func applyDelegatedOperations(notes: inout [String]) {
        for index in stores.indices {
            guard stores[index].isOperational, stores[index].hasManager,
                  let plot = plot(id: stores[index].plotID) else { continue }
            var actions: [String] = []
            let manager = stores[index].manager!

            if stores[index].delegateStaff {
                let automatedCases = (stores[index].autoSales ? stores[index].buyerArrivalsThisWeek : 0)
                    + (stores[index].autoProcurement ? stores[index].sellerArrivalsThisWeek : 0)
                let caseWorkers = max(0, Int(ceil(Double(automatedCases) / 7.0)))
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
                        stores[index].autoMarketing ? .marketingResearch : nil,
                        stores[index].autoService ? .service : nil
                    ].compactMap { $0 }
                    for _ in 0..<reassignmentLimit {
                        guard !enabledAssignments.isEmpty,
                              let employeeIndex = stores[index].employees.firstIndex(where: {
                                  $0.assignment == .unassigned || !enabledAssignments.contains($0.assignment)
                              }) else { break }
                        let buyerNeed = max(0, stores[index].buyerArrivalsThisWeek - stores[index].employees.filter { $0.assignment == .sales }.count * 7)
                        let sellerNeed = max(0, stores[index].sellerArrivalsThisWeek - stores[index].employees.filter { $0.assignment == .procurement }.count * 7)
                        let assignment: EmployeeAssignment
                        if stores[index].autoMarketing && !stores[index].employees.contains(where: { $0.assignment == .marketingResearch }) {
                            assignment = .marketingResearch
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

            if stores[index].delegatePricing {
                let stockRate = Double(stores[index].inventoryCount + incomingCount(for: stores[index].id)) / Double(max(1, stores[index].type.capacity))
                let targetPrice = stockRate > 0.72 ? 0.96 : stockRate < 0.30 ? 1.05 : 1.0
                let targetPolicy: SalesAutomationPolicy = stockRate > 0.72 ? .volume : stockRate < 0.30 ? .profit : .balanced
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

            if stores[index].delegateProcurement {
                let currentStockRate = Double(stores[index].inventoryCount + incomingCount(for: stores[index].id)) / Double(max(1, stores[index].type.capacity))
                let target: ProcurementAutomationPolicy = currentStockRate < 0.28 ? .volume : cash < monthlyPersonnelCost(for: stores[index]) * 2 ? .profit : .balanced
                if (manager.procurementAbility >= 60 || turn.isMultiple(of: 2)), stores[index].procurementPolicy != target {
                    stores[index].procurementPolicy = target
                    actions.append("仕入方針を\(target.name)へ変更")
                }
            }

            if stores[index].delegateMarketing {
                let marketingAbility = manager.marketingAbility
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
                let target = stores[index].satisfaction < 72 ? 0.55 : stores[index].inventoryCount > stores[index].type.capacity * 7 / 10 ? 0.35 : 0.45
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
            guard let listing = auctionListings.first(where: { $0.id == bid.listingID }) else {
                bidReservations.removeAll { $0.id == bid.id }
                continue
            }
            guard stores.contains(where: { $0.id == bid.storeID }) else {
                bidReservations.removeAll { $0.id == bid.id }
                continue
            }
            let seed = turn * 277 + listing.modelYear * 19 + listing.mileage / 500 + categoryIndex(listing.category) * 43
            let rivalBid = competitorAuctionBid(for: listing, seed: seed)
            let rivalPrice = rivalBid?.maxPrice ?? listing.reservePrice
            let wonCompetition = bid.maxPrice >= rivalPrice
            let status: AuctionBidResultStatus
            var hammerPrice: Int
            let winningCompetitorID: UUID?
            if !wonCompetition {
                hammerPrice = rivalPrice
                status = .exceededLimit
                winningCompetitorID = rivalBid.map { competitors[$0.competitorIndex].id }
                if let rivalBid {
                    recordCompetitorAuctionPurchase(listing: listing, competitorIndex: rivalBid.competitorIndex, hammerPrice: hammerPrice, purchasedTurn: resolvingTurn)
                }
                notes.append("\(listing.vehicleName)の入札は落札価格\(hammerPrice.currency)が上限\(bid.maxPrice.currency)を超え、\(winningCompetitorID.map(competitorName(for:)) ?? "他社")が落札しました")
            } else {
                hammerPrice = min(bid.maxPrice, max(listing.reservePrice, rivalPrice + 1))
                let playerTotal = hammerPrice + listing.venue.fee + listing.venue.shippingCost
                if cash < playerTotal {
                    hammerPrice = rivalPrice
                    status = .insufficientFunds
                    winningCompetitorID = rivalBid.map { competitors[$0.competitorIndex].id }
                    if let rivalBid {
                        recordCompetitorAuctionPurchase(listing: listing, competitorIndex: rivalBid.competitorIndex, hammerPrice: rivalPrice, purchasedTurn: resolvingTurn)
                    }
                    notes.append("\(listing.vehicleName)は落札圏内でしたが、諸費用込み\(playerTotal.currency)の資金を確保できず、\(winningCompetitorID.map(competitorName(for:)) ?? "他社")が落札しました")
                } else {
                    status = .won
                    winningCompetitorID = nil
                    cash -= playerTotal
                    inboundShipments.append(InboundShipment(id: UUID(), storeID: bid.storeID, source: .auction, modelID: listing.modelID, category: listing.category, count: 1, unitCost: playerTotal, quality: listing.quality, modelYear: listing.modelYear, mileage: listing.mileage, acquiredTurn: resolvingTurn, monthsRemaining: listing.venue.shippingMonths))
                    notes.append("\(listing.venue.name)で\(listing.vehicleName)を\(hammerPrice.currency)で落札しました（会場費・輸送費込み \(playerTotal.currency)）")
                }
            }
            let total = hammerPrice + listing.venue.fee + listing.venue.shippingCost
            auctionBidResults.insert(AuctionBidResult(
                id: UUID(),
                listingID: listing.id,
                storeID: bid.storeID,
                venue: listing.venue,
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
            auctionListings.removeAll { $0.id == listing.id }
            bidReservations.removeAll { $0.id == bid.id }
        }
        if auctionBidResults.count > 20 {
            auctionBidResults.removeLast(auctionBidResults.count - 20)
        }
    }

    private func competitorAuctionBid(for listing: AuctionListing, seed: Int) -> (competitorIndex: Int, maxPrice: Int)? {
        let candidates = competitors.indices.filter { competitors[$0].cash >= listing.reservePrice }
        guard let competitorIndex = candidates.max(by: { left, right in
            competitorAuctionInterest(competitors[left], listing: listing, seed: seed + left * 31)
                < competitorAuctionInterest(competitors[right], listing: listing, seed: seed + right * 31)
        }) else { return nil }
        let competitor = competitors[competitorIndex]
        let categoryFit = competitor.category == listing.category ? 0.13 : 0
        let strategyFit: Double
        switch competitor.name {
        case "バリューオート": strategyFit = [.kei, .compact, .commercial].contains(listing.category) ? 0.07 : -0.05
        case "プレミアモータース": strategyFit = listing.category == .imported ? 0.12 : (listing.category == .suv ? 0.04 : -0.06)
        default: strategyFit = [.suv, .minivan, .pickup].contains(listing.category) ? 0.08 : -0.02
        }
        let variation = transactionRoll(seed: seed + competitorIndex * 47 + 19) * 0.30
        let willingness = min(1.34, max(0.86, 0.88 + categoryFit + strategyFit + variation))
        let maxPrice = min(competitor.cash, max(listing.reservePrice, Int(Double(listing.marketPrice) * willingness)))
        return (competitorIndex, maxPrice)
    }

    private func competitorAuctionInterest(_ competitor: Competitor, listing: AuctionListing, seed: Int) -> Double {
        let specialty = competitor.category == listing.category ? 1.7 : 1.0
        let scale = 0.75 + competitor.strength * 0.25
        return specialty * scale * (0.82 + transactionRoll(seed: seed) * 0.36)
    }

    private func recordCompetitorAuctionPurchase(listing: AuctionListing, competitorIndex: Int, hammerPrice: Int, purchasedTurn: Int) {
        guard competitors.indices.contains(competitorIndex) else { return }
        // Rival dealers recycle most auction inventory into sales quickly; only the
        // working-capital portion is tied up in this higher-level simulation.
        competitors[competitorIndex].cash = max(0, competitors[competitorIndex].cash - max(1, hammerPrice / 5))
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
            let proceeds = max(0, order.expectedUnitPrice * order.count * variation / 100 - order.venue.fee * order.count)
            cash += proceeds
            notes.append("\(order.venue.name)への出品車 \(order.vehicleName)\(order.count)台が成約し、\(proceeds.currency)を受け取りました")
            auctionConsignments.removeAll { $0.id == order.id }
        }
    }

    private func addInventory(category: VehicleCategory, modelID: String?, count: Int, unitCost: Int, quality: Double, modelYear: Int?, mileage: Int?, acquiredTurn: Int, to storeIndex: Int) {
        for offset in 0..<count {
            let qualityVariation = Double((turn + offset * 5 + categoryIndex(category)) % 7 - 3) / 100
            let model = modelID.flatMap(VehicleCatalog.entry(id:))
                ?? vehicleModel(for: category, seed: turn * 127 + stores[storeIndex].plotID * 19 + offset * 37)
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
                acquiredTurn: acquiredTurn
            ))
        }
    }

    private func generateAuctionListings() {
        if turn > 0 && auctionListings.count >= 25 {
            let stale = auctionListings.filter { listing in !bidReservations.contains(where: { $0.listingID == listing.id }) }.prefix(5).map(\.id)
            auctionListings.removeAll { stale.contains($0.id) }
        }
        while auctionListings.count < 30 {
            let index = auctionListings.count + turn * 5
            let venue = AuctionVenue.allCases[index % AuctionVenue.allCases.count]
            let categories: [VehicleCategory]
            switch venue {
            case .east: categories = [.kei, .compact, .minivan]
            case .port: categories = [.commercial, .pickup, .suv, .minivan]
            case .premium: categories = [.imported, .suv]
            }
            let classicCandidates = VehicleCatalog.rareClassics.filter { categories.contains($0.category) }
            let isRareClassicListing = !classicCandidates.isEmpty && abs(index + turn * 17).isMultiple(of: 41)
            let model: VehicleCatalogEntry
            if isRareClassicListing {
                model = classicCandidates[abs(index * 7 + turn * 3) % classicCandidates.count]
            } else {
                let normalCategory = categories[(index / 2 + turn) % categories.count]
                model = vehicleModel(for: normalCategory, seed: index * 43 + (index / 3) * 17 + turn * 101)
            }
            let category = model.category
            let profile = usedVehicleProfile(
                for: model,
                seed: index * 173 + turn * 109 + 31,
                maximumAge: venue == .premium ? 6 : 14
            )
            let pricingDistrict: DistrictKind = venue == .premium ? .downtown : venue == .port ? .industrial : .station
            let calculatedMarket = vehicleWholesaleValue(
                modelID: model.id,
                category: category,
                modelYear: profile.modelYear,
                mileage: profile.mileage,
                quality: profile.quality,
                in: pricingDistrict
            )
            let premiumImportFloor = category == .imported ? Int(Double(model.baseWholesalePrice) * 0.75) : 35
            let market = max(35, premiumImportFloor, calculatedMarket)
            let reserve = max(28, market * (78 + (index % 13)) / 100)
            let seller = isRareClassicListing
                ? "コレクター放出・現状渡し"
                : venue == .premium ? "輸入車正規店・下取車" : (index.isMultiple(of: 3) ? "法人リース" : "中古車業者")
            auctionListings.append(AuctionListing(id: UUID(), venue: venue, modelID: model.id, category: category, modelYear: profile.modelYear, mileage: profile.mileage, quality: profile.quality, reservePrice: reserve, marketPrice: market, seller: seller, createdTurn: turn))
        }
    }

    private func save() {
        var snapshot = SaveData(year: year, month: month, weekOfMonth: weekOfMonth, turn: turn, cash: cash, debt: debt, companyValue: companyValue, districts: districts, plots: plots, stores: stores, competitors: competitors, reports: reports, purchaseCases: purchaseCases, buyerLeads: buyerLeads, cityEvents: cityEvents, auctionListings: auctionListings, bidReservations: bidReservations, auctionBidResults: auctionBidResults, competitorAuctionPurchases: competitorAuctionPurchases, inboundShipments: inboundShipments, auctionConsignments: auctionConsignments, pendingCustomerClaims: pendingCustomerClaims, finance: finance, unlockedFeatures: unlockedFeatures, regionalOperations: regionalOperations, intercityShipments: intercityShipments, nationalBrandStrength: nationalBrandStrength, economicIndex: economicIndex, fuelPriceIndex: fuelPriceIndex, careerStatistics: careerStatistics, priceWarChallenges: priceWarChallenges, tutorialStep: tutorialStep, tutorialPlotID: tutorialPlotID, financialDistressWeeks: financialDistressWeeks)
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
            focus: .family,
            concept: .family,
            loanAmount: StoreConcept.family.defaultFacilities.reduce(0) { $0 + $1.installationCost }
        )
        if let store = stores.first {
            for category in recommendedCategories(for: plot.district).prefix(2) {
                _ = buyInventory(category: category, count: 2, storeID: store.id)
            }
        }
        completeTutorial()
        tutorialMessage = nil
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
            competitors[assignment.competitorIndex].plotIDs.append(candidate.id)
            plots[plotIndex].occupant = .competitor(
                name: competitors[assignment.competitorIndex].name
            )
        }
    }

    private func generateWeeklyCustomerLeads(forceTutorialStoreID: UUID? = nil) {
        buyerLeads.removeAll()
        purchaseCases.removeAll()
        for index in stores.indices {
            stores[index].weeklyBuyerArrivals = 0
            stores[index].weeklySellerArrivals = 0
        }

        for (districtIndex, kind) in DistrictKind.allCases.enumerated() {
            for offset in 0..<weeklyBuyerPool(in: kind) {
                let seed = turn * 10_007 + districtIndex * 997 + offset * 61 + 17
                let preference = leadPreference(in: kind, seed: seed + 23)
                guard let storeID = assignedStore(in: kind, buyerPreference: preference, sellerCategory: nil, seed: seed) else { continue }
                buyerLeads.append(makeBuyerLead(storeID: storeID, preference: preference, seed: seed))
                if let storeIndex = stores.firstIndex(where: { $0.id == storeID }) {
                    stores[storeIndex].weeklyBuyerArrivals = stores[storeIndex].buyerArrivalsThisWeek + 1
                }
            }

            for offset in 0..<weeklySellerPool(in: kind) {
                let seed = turn * 11_003 + districtIndex * 1_009 + offset * 67 + 41
                let category = sellerCategory(in: kind, seed: seed + 31)
                guard let storeID = assignedStore(in: kind, buyerPreference: nil, sellerCategory: category, seed: seed),
                      let store = stores.first(where: { $0.id == storeID }),
                      let storePlot = plot(id: store.plotID) else { continue }
                purchaseCases.append(makePurchaseCase(storeID: storeID, plot: storePlot, category: category, seed: seed))
                if let storeIndex = stores.firstIndex(where: { $0.id == storeID }) {
                    stores[storeIndex].weeklySellerArrivals = stores[storeIndex].sellerArrivalsThisWeek + 1
                }
            }
        }

        if let storeID = forceTutorialStoreID,
           let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
           let storePlot = plot(id: stores[storeIndex].plotID) {
            let category = recommendedCategories(for: storePlot.district).first ?? .compact
            if !buyerLeads.contains(where: { $0.storeID == storeID }) {
                buyerLeads.append(makeBuyerLead(storeID: storeID, preference: .category(category), seed: storePlot.id * 101 + 7))
                stores[storeIndex].weeklyBuyerArrivals = stores[storeIndex].buyerArrivalsThisWeek + 1
            }
            if !purchaseCases.contains(where: { $0.storeID == storeID }) {
                purchaseCases.append(makePurchaseCase(storeID: storeID, plot: storePlot, category: category, seed: storePlot.id * 103 + 13))
                stores[storeIndex].weeklySellerArrivals = stores[storeIndex].sellerArrivalsThisWeek + 1
            }
        }
    }

    private func assignedStore(
        in kind: DistrictKind,
        buyerPreference: BuyerVehiclePreference?,
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
                let location = storePlot.visibility * storePlot.access * storePlot.traffic
                let marketing = (0.78 + min(0.44, Double(store.advertising) / 500.0))
                    * employeeMarketingEfficiency(for: store.id, buyers: false)
                weight = max(
                    0.05,
                    store.reputation * location * marketing * (0.8 + store.serviceAllocation * 0.4)
                        * sellerAttractionFactor(for: store, category: sellerCategory ?? .compact)
                )
            } else {
                let desiredCategory = buyerPreference?.category
                weight = storeMarketWeight(store, plot: storePlot)
                    * buyerAttractionFactor(for: store, category: desiredCategory)
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

    private func leadCategory(in kind: DistrictKind, seed: Int) -> VehicleCategory {
        guard let district = districts.first(where: { $0.kind == kind }) else { return .compact }
        let weighted = VehicleCategory.allCases.map { category -> (VehicleCategory, Double) in
            let demand = district.demands[category] ?? 0.42
            let economyMultiplier: Double
            switch category {
            case .imported, .suv: economyMultiplier = 0.72 + economicIndex * 0.28
            case .kei, .compact: economyMultiplier = 1.20 - (economicIndex - 0.8) * 0.22
            default: economyMultiplier = 0.88 + economicIndex * 0.12
            }
            return (category, max(0.05, demand * economyMultiplier))
        }
        let total = weighted.reduce(0.0) { $0 + $1.1 }
        var cursor = transactionRoll(seed: seed) * total
        for (category, weight) in weighted {
            cursor -= weight
            if cursor <= 0 { return category }
        }
        return weighted.last?.0 ?? .compact
    }

    private func sellerCategory(in kind: DistrictKind, seed: Int) -> VehicleCategory {
        guard let district = districts.first(where: { $0.kind == kind }) else { return .compact }
        let weighted = VehicleCategory.allCases.map { category in
            (category, max(0.05, district.supplies[category] ?? 0.42))
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

    private func makeBuyerLead(storeID: UUID, preference: BuyerVehiclePreference, seed: Int) -> BuyerLead {
        let storePlot = stores.first(where: { $0.id == storeID }).flatMap { plot(id: $0.plotID) }
        let localDistrict = storePlot?.district ?? .suburb
        let localIncome = storePlot.map { district(for: $0).incomeIndex } ?? 1.0
        let incomeBudgetFactor = min(1.24, max(0.84, 1 + (localIncome - 1) * 0.46))
        let resolvedPreference = detailedBuyerPreference(from: preference, seed: seed + 401)
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
            let category = model?.category ?? .imported
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
        return BuyerLead(
            id: UUID(),
            storeID: storeID,
            preference: resolvedPreference,
            budget: budget,
            minimumQuality: minimumQuality,
            minimumModelYear: minimumModelYear,
            maximumMileage: maximumMileage,
            priceSensitivity: priceSensitivity,
            generatedTurn: turn,
            tradeInVehicle: tradeInVehicle
        )
    }

    private func detailedBuyerPreference(from preference: BuyerVehiclePreference, seed: Int) -> BuyerVehiclePreference {
        guard case .category(let category) = preference else { return preference }
        let target = vehicleModel(for: category, seed: seed)
        let roll = transactionRoll(seed: seed + 17)
        if category == .imported {
            // 高額輸入車客の多くは車種を指名し、残りもメーカーを指定する。
            return roll < 0.68
                ? .exactModel(target.id)
                : .maker(category: category, maker: target.maker)
        }
        let categoryOnlyShare: Double
        switch category {
        case .kei: categoryOnlyShare = 0.56
        case .compact: categoryOnlyShare = 0.50
        case .minivan, .suv: categoryOnlyShare = 0.42
        case .pickup, .commercial: categoryOnlyShare = 0.48
        case .imported: categoryOnlyShare = 0
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
        let marketValue = vehicleWholesaleValue(
            modelID: model.id,
            category: category,
            modelYear: profile.modelYear,
            mileage: profile.mileage,
            quality: quality,
            in: plot.district
        )
        let allowance = max(20, Int(Double(marketValue) * (0.90 + transactionRoll(seed: seed + 13) * 0.08)))
        let conditionScore = Int((quality * 100).rounded())
        let repairCost = max(5, (100 - conditionScore) * category.purchaseCost / 280)
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

    private func makePurchaseCase(storeID: UUID, plot: LandPlot, category: VehicleCategory, seed: Int) -> PurchaseCase {
        let base = category.purchaseCost
        let model = vehicleModel(for: category, seed: seed + 5)
        let profile = usedVehicleProfile(for: model, seed: seed + 7, maximumAge: 14)
        let condition = min(91, max(50, Int((profile.quality * 100).rounded())))
        let wholesale = vehicleWholesaleValue(modelID: model.id, category: category, modelYear: profile.modelYear, mileage: profile.mileage, quality: Double(condition) / 100.0, in: plot.district)
        let asking = max(25, Int(Double(wholesale) * (0.84 + transactionRoll(seed: seed + 13) * 0.22)))
        let repair = max(6, (100 - condition) * base / 230)
        let repairGain = condition < 75 ? 4 : 3
        let repairedQuality = Double(min(94, condition + repairGain)) / 100.0
        let expectedSale = vehicleRetailValue(modelID: model.id, category: category, modelYear: profile.modelYear, mileage: profile.mileage, quality: repairedQuality, in: plot.district)
        let appraisalAccuracy = min(92, 58 + Int(transactionRoll(seed: seed + 29) * 24) + employeeAppraisalAccuracyBonus(for: storeID))
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
        let lotCount = stores.first(where: { $0.id == storeID })
            .map { procurementLotSize(for: $0, category: category, seed: seed) } ?? 1
        return PurchaseCase(
            id: UUID(), storeID: storeID, modelID: model.id, category: category,
            lotCount: lotCount,
            modelYear: profile.modelYear,
            mileage: profile.mileage,
            exterior: max(40, condition - 3), interior: min(99, condition + 2), mechanical: condition,
            askingPrice: asking, appraisedPrice: wholesale, repairCost: repair,
            expectedSalePrice: expectedSale,
            expectedDays: 20 + Int(transactionRoll(seed: seed + 23) * 62),
            demand: district(for: plot).demands[category] ?? 0.72,
            appraisalAccuracy: appraisalAccuracy,
            negotiationAttempts: 0,
            hiddenIssue: hiddenIssue,
            issueRevealed: issueRevealed
        )
    }

    static func makeDistricts() -> [District] {
        [
            District(kind: .downtown, population: 92_000, incomeIndex: 1.42, trafficIndex: 1.35, growthRate: 1.01, competition: 1.35, demands: [.imported: 1.58, .suv: 1.18, .compact: 1.0, .kei: 0.72], supplies: [.compact: 0.95, .imported: 0.78, .suv: 0.75, .kei: 0.55]),
            District(kind: .station, population: 76_000, incomeIndex: 1.03, trafficIndex: 1.42, growthRate: 1.015, competition: 1.28, demands: [.compact: 1.42, .kei: 1.25, .minivan: 1.08, .imported: 0.78], supplies: [.compact: 1.45, .kei: 1.30, .minivan: 0.90, .imported: 0.55]),
            District(kind: .emerging, population: 58_000, incomeIndex: 1.16, trafficIndex: 1.02, growthRate: 1.065, competition: 0.72, demands: [.suv: 1.52, .minivan: 1.45, .compact: 0.95, .pickup: 0.88], supplies: [.suv: 1.12, .minivan: 1.05, .compact: 0.82, .pickup: 0.60]),
            District(kind: .suburb, population: 88_000, incomeIndex: 1.08, trafficIndex: 1.18, growthRate: 1.02, competition: 1.02, demands: [.minivan: 1.48, .kei: 1.30, .suv: 1.26, .compact: 1.05, .pickup: 0.82], supplies: [.minivan: 1.45, .kei: 1.35, .suv: 1.15, .compact: 1.0, .pickup: 0.65]),
            District(kind: .industrial, population: 43_000, incomeIndex: 0.82, trafficIndex: 0.88, growthRate: 0.99, competition: 0.58, demands: [.commercial: 1.55, .pickup: 1.42, .kei: 1.15, .imported: 0.32], supplies: [.commercial: 1.75, .pickup: 1.38, .kei: 0.92, .suv: 0.80, .imported: 0.20]),
            District(kind: .highway, population: 66_000, incomeIndex: 0.91, trafficIndex: 1.48, growthRate: 1.012, competition: 0.93, demands: [.kei: 1.42, .pickup: 1.34, .suv: 1.12, .commercial: 1.08], supplies: [.pickup: 1.25, .commercial: 1.22, .suv: 1.18, .kei: 1.05, .minivan: 0.80])
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
            Competitor(id: UUID(), name: "バリューオート", strategy: "低価格・高回転", colorHex: "E46B35", cash: 42_000, plotIDs: [], strength: 1.02, category: .compact),
            Competitor(id: UUID(), name: "プレミアモータース", strategy: "輸入車と品質保証", colorHex: "7356A8", cash: 58_000, plotIDs: [], strength: 1.15, category: .imported),
            Competitor(id: UUID(), name: "ドライブMAX", strategy: "多店舗・大量展示", colorHex: "287DB2", cash: 64_000, plotIDs: [], strength: 1.08, category: .suv)
        ]
    }

    static func makeNationalCities() -> [NationalCity] {
        [
            NationalCity(id: "suihama", name: "翠浜市", region: "首都圏", population: 423_000, incomeIndex: 1.08, landPriceIndex: 1.00, competitionIndex: 1.02, growthRate: 1.018, primaryDemand: [.minivan, .kei, .suv], expansionCost: 0, shippingMonths: 0, shippingCostPerVehicle: 0, mapX: 0.72, mapY: 0.42),
            NationalCity(id: "hokusei", name: "北星市", region: "北日本", population: 318_000, incomeIndex: 0.91, landPriceIndex: 0.66, competitionIndex: 0.72, growthRate: 1.004, primaryDemand: [.suv, .pickup, .commercial], expansionCost: 6_800, shippingMonths: 2, shippingCostPerVehicle: 18, mapX: 0.72, mapY: 0.12),
            NationalCity(id: "shinonome", name: "東雲市", region: "中部", population: 512_000, incomeIndex: 1.04, landPriceIndex: 0.88, competitionIndex: 0.94, growthRate: 1.023, primaryDemand: [.commercial, .compact, .pickup], expansionCost: 7_600, shippingMonths: 1, shippingCostPerVehicle: 11, mapX: 0.58, mapY: 0.48),
            NationalCity(id: "naniwa", name: "浪華市", region: "関西", population: 884_000, incomeIndex: 1.16, landPriceIndex: 1.24, competitionIndex: 1.31, growthRate: 1.011, primaryDemand: [.imported, .suv, .minivan], expansionCost: 11_500, shippingMonths: 2, shippingCostPerVehicle: 15, mapX: 0.43, mapY: 0.55),
            NationalCity(id: "setouchi", name: "瀬戸内市", region: "中国・四国", population: 276_000, incomeIndex: 0.89, landPriceIndex: 0.58, competitionIndex: 0.63, growthRate: 1.015, primaryDemand: [.kei, .commercial, .pickup], expansionCost: 5_900, shippingMonths: 2, shippingCostPerVehicle: 17, mapX: 0.28, mapY: 0.61),
            NationalCity(id: "hinata", name: "日向市", region: "九州", population: 391_000, incomeIndex: 0.94, landPriceIndex: 0.72, competitionIndex: 0.81, growthRate: 1.029, primaryDemand: [.kei, .suv, .minivan], expansionCost: 6_500, shippingMonths: 3, shippingCostPerVehicle: 22, mapX: 0.16, mapY: 0.76)
        ]
    }
}
