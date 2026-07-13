import Foundation
import SwiftUI

@MainActor
final class GameEngine: ObservableObject {
    @Published var hasStarted = false
    @Published var year = 2030
    @Published var month = 4
    @Published var turn = 0
    @Published var cash = 28_000
    @Published var debt = 8_000
    @Published var companyValue = 25_000
    @Published var districts: [District] = []
    @Published var plots: [LandPlot] = []
    @Published var stores: [Store] = []
    @Published var competitors: [Competitor] = []
    @Published var reports: [MonthlyReport] = []
    @Published var purchaseCases: [PurchaseCase] = []
    @Published var cityEvents: [CityEvent] = []
    @Published var auctionListings: [AuctionListing] = []
    @Published var bidReservations: [BidReservation] = []
    @Published var inboundShipments: [InboundShipment] = []
    @Published var auctionConsignments: [AuctionConsignment] = []
    @Published var finance = FinanceSnapshot()
    @Published var lastReport: MonthlyReport?
    @Published var showMonthlyReport = false
    @Published var gameOver = false
    @Published var tutorialMessage: String?
    @Published var tutorialStep: TutorialStep?
    @Published var tutorialPlotID: Int?
    @Published var startupPlan: StartupPlan?
    @Published var unlockedFeatures: Set<String> = ["仕入", "価格設定"]
    @Published var regionalOperations: [RegionalOperation] = []
    @Published var intercityShipments: [IntercityShipment] = []
    @Published var nationalBrandStrength: Double = 0.48

    let maxTurns = 120

    private struct SaveData: Codable {
        let hasStarted: Bool
        let year: Int
        let month: Int
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
        let cityEvents: [CityEvent]
        let auctionListings: [AuctionListing]
        let bidReservations: [BidReservation]
        let inboundShipments: [InboundShipment]
        let auctionConsignments: [AuctionConsignment]
        let finance: FinanceSnapshot
        let unlockedFeatures: Set<String>
        let regionalOperations: [RegionalOperation]?
        let intercityShipments: [IntercityShipment]?
        let nationalBrandStrength: Double?
        let tutorialStep: TutorialStep?
        let tutorialPlotID: Int?
        let startupPlan: StartupPlan?
    }

    private struct RegionalMonthResult {
        var sales = 0
        var revenue = 0
        var costOfSales = 0
        var fixedCosts = 0
        var advertising = 0
    }

    private static let saveKey = "UsedCarCity.save.v6"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let saved = try? JSONDecoder().decode(SaveData.self, from: data) {
            hasStarted = saved.hasStarted
            year = saved.year
            month = saved.month
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
            cityEvents = saved.cityEvents
            auctionListings = saved.auctionListings
            bidReservations = saved.bidReservations
            inboundShipments = saved.inboundShipments
            auctionConsignments = saved.auctionConsignments
            finance = saved.finance
            unlockedFeatures = saved.unlockedFeatures
            regionalOperations = saved.regionalOperations ?? []
            intercityShipments = saved.intercityShipments ?? []
            nationalBrandStrength = saved.nationalBrandStrength ?? 0.48
            tutorialStep = saved.tutorialStep
            tutorialPlotID = saved.tutorialPlotID
            startupPlan = saved.startupPlan
        } else {
            districts = Self.makeDistricts()
            plots = Self.makePlots()
            competitors = Self.makeCompetitors()
            placeCompetitors()
        }
#if DEBUG
        if CommandLine.arguments.contains("-demo-tutorial-purchase"), !hasStarted {
            start(plan: .family)
            if let plot = recommendedFoundingPlot {
                selectFoundingPlot(plot.id)
                _ = buildStore(on: plot, type: .standard, mode: .lease, focus: .family, concept: .family, loanAmount: 0)
            }
            tutorialMessage = nil
        } else if CommandLine.arguments.contains("-demo-tutorial"), !hasStarted {
            start(plan: .family)
            tutorialMessage = nil
        } else if (CommandLine.arguments.contains("-demo-map") || CommandLine.arguments.contains("-demo-store") || CommandLine.arguments.contains("-demo-auction") || CommandLine.arguments.contains("-demo-hq") || CommandLine.arguments.contains("-demo-construction") || CommandLine.arguments.contains("-demo-national")) && !hasStarted {
            prepareDemoCompany(plan: .family)
            tutorialMessage = nil
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
    var currentDistrictsByKind: [DistrictKind: District] { Dictionary(uniqueKeysWithValues: districts.map { ($0.kind, $0) }) }
    var nationalCities: [NationalCity] { Self.makeNationalCities() }
    var isTutorialActive: Bool {
        guard let tutorialStep else { return false }
        return tutorialStep != .completed
    }

    var foundingCandidatePlots: [LandPlot] {
        DistrictKind.allCases.compactMap { kind in
            plots
                .filter { $0.district == kind && isAvailable($0.occupant) && $0.development == nil }
                .max { foundingPlotScore($0) < foundingPlotScore($1) }
        }
    }

    var recommendedFoundingPlot: LandPlot? {
        guard let preferred = startupPlan?.recommendedDistrict else { return foundingCandidatePlots.first }
        return foundingCandidatePlots.first(where: { $0.district == preferred }) ?? foundingCandidatePlots.first
    }

    private func foundingPlotScore(_ plot: LandPlot) -> Double {
        let rentEfficiency = Double(estimatedVisitors(for: plot)) / Double(max(1, plot.monthlyRent))
        return rentEfficiency * plot.visibility * plot.access * plot.traffic
    }

    func start(plan: StartupPlan) {
        hasStarted = true
        startupPlan = plan
        cash = plan.startingCash
        tutorialStep = .chooseLocation
        tutorialPlotID = nil
        cityEvents = plots.compactMap { plot in
            guard let project = plot.development else { return nil }
            return CityEvent(turn: 0, kind: .development, title: "\(project.title)が計画中", detail: "完成まで\(project.monthsRemaining)か月。周辺人口と交通量が増える見込みです", district: plot.district, plotID: plot.id)
        }
        tutorialMessage = nil
        generateAuctionListings()
        recalculateAssets()
        save()
    }

    func resetGame() {
        hasStarted = false
        year = 2030; month = 4; turn = 0; cash = 28_000; debt = 8_000; companyValue = 25_000
        districts = Self.makeDistricts(); plots = Self.makePlots(); competitors = Self.makeCompetitors()
        stores = []; reports = []; purchaseCases = []; cityEvents = []; auctionListings = []; bidReservations = []; inboundShipments = []; auctionConsignments = []; regionalOperations = []; intercityShipments = []; nationalBrandStrength = 0.48; finance = FinanceSnapshot(); lastReport = nil; showMonthlyReport = false; gameOver = false; tutorialStep = nil; tutorialPlotID = nil; startupPlan = nil; tutorialMessage = nil
        unlockedFeatures = ["仕入", "価格設定"]
        placeCompetitors()
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
    }

    func district(for plot: LandPlot) -> District { districts.first(where: { $0.kind == plot.district })! }
    func plot(id: Int) -> LandPlot? { plots.first(where: { $0.id == id }) }
    func store(at plotID: Int) -> Store? { stores.first(where: { $0.plotID == plotID }) }

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
        return unlockedFeatures.contains("出店")
    }

    func estimatedVisitors(for plot: LandPlot) -> Int {
        let district = district(for: plot)
        let base = Double(district.population) / 750
        return max(28, Int(base * district.trafficIndex * plot.traffic * plot.visibility * (1.15 - district.competition * 0.18)))
    }

    func estimatedSales(for plot: LandPlot, type: StoreType = .standard, focus: CustomerFocus = .family, concept: StoreConcept = .general) -> ClosedRange<Int> {
        let visitors = estimatedVisitors(for: plot)
        let fit = focusFit(focus, district: plot.district)
        let mid = max(2, Int(Double(visitors) * 0.105 * fit * conceptFit(concept, district: plot.district) * type.serviceQuality))
        return max(1, Int(Double(mid) * 0.78))...max(2, Int(Double(mid) * 1.18))
    }

    func breakEvenSales(for plot: LandPlot, type: StoreType, mode: AcquisitionMode) -> Int {
        let occupancy = mode == .lease ? plot.monthlyRent : max(12, plot.price / 360)
        return max(3, Int(ceil(Double(type.monthlyFixedCost + occupancy + 80) / 32.0)))
    }

    func canBuild(on plot: LandPlot, type: StoreType, mode: AcquisitionMode) -> Bool {
        guard isAvailable(plot.occupant), plot.development == nil else { return false }
        let landCost = mode == .purchase ? plot.price : plot.monthlyRent * 6
        return cash >= landCost + type.buildCost
    }

    @discardableResult
    func buildStore(on plot: LandPlot, type: StoreType, mode: AcquisitionMode, focus: CustomerFocus, concept: StoreConcept, loanAmount: Int) -> Bool {
        let isFoundingStore = stores.isEmpty && tutorialStep == .buildStore && tutorialPlotID == plot.id
        guard stores.count < 5,
              let index = plots.firstIndex(where: { $0.id == plot.id }),
              isAvailable(plots[index].occupant), plots[index].development == nil else { return false }
        let landCost = mode == .purchase ? plot.price : plot.monthlyRent * 6
        let total = landCost + type.buildCost
        guard cash + loanAmount >= total else { return false }
        cash += loanAmount - total
        debt += loanAmount
        finance.investingCF -= total
        finance.financingCF += loanAmount
        let categories = recommendedCategories(for: plot.district)
        let starterStock = isFoundingStore ? [] : categories.prefix(2).map { InventoryBatch(category: $0, count: 3) }
        let store = Store(
            name: "\(plot.district.shortName)\(plot.localNumber)号店",
            plotID: plot.id,
            type: type,
            acquisition: mode,
            focus: focus,
            concept: concept,
            inventory: starterStock,
            openingMonthsRemaining: isFoundingStore ? nil : type.constructionMonths
        )
        stores.append(store)
        plots[index].occupant = .player(storeID: store.id)
        if isFoundingStore {
            tutorialStep = .purchaseInventory
            generatePurchaseCases()
            recordCityEvent(CityEvent(turn: turn, kind: .storeGrowth, title: "創業店がオープン", detail: "\(store.name)が居抜き店舗を改装し、営業を開始しました", district: plot.district, plotID: plot.id))
        }
        recalculateAssets()
        save()
        return true
    }

    func closeStore(_ storeID: UUID) {
        guard stores.count > 1,
              let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let plotIndex = plots.firstIndex(where: { $0.id == stores[storeIndex].plotID }) else { return }
        let store = stores[storeIndex]
        let landProceeds = store.acquisition == .purchase ? plots[plotIndex].price : 0
        let equipmentProceeds = store.type.buildCost * 3 / 10
        let inventoryProceeds = store.inventory.reduce(0) { $0 + $1.averageCost * $1.count * 8 / 10 }
        let proceeds = landProceeds + equipmentProceeds + inventoryProceeds
        cash += proceeds
        finance.investingCF += landProceeds + equipmentProceeds
        plots[plotIndex].occupant = .available
        stores.remove(at: storeIndex)
        recalculateAssets()
        save()
    }

    func buyInventory(category: VehicleCategory, count: Int, storeID: UUID) -> Bool {
        let totalCost = category.purchaseCost * count
        guard cash >= totalCost, let index = stores.firstIndex(where: { $0.id == storeID }) else { return false }
        let freeCapacity = stores[index].type.capacity - stores[index].inventoryCount
        guard freeCapacity >= count else { return false }
        cash -= totalCost
        if let batch = stores[index].inventory.firstIndex(where: { $0.category == category }) {
            stores[index].inventory[batch].count += count
        } else {
            stores[index].inventory.append(InventoryBatch(category: category, count: count))
        }
        if tutorialStep == .purchaseInventory, stores[index].plotID == tutorialPlotID {
            tutorialStep = .setPrice
        }
        recalculateAssets()
        save()
        return true
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

    @discardableResult
    func reserveBid(listingID: UUID, storeID: UUID, maxPrice: Int) -> Bool {
        guard let listing = auctionListings.first(where: { $0.id == listingID }),
              let store = stores.first(where: { $0.id == storeID }),
              maxPrice >= listing.reservePrice,
              store.inventoryCount + incomingCount(for: storeID) + bidReservations.filter({ $0.storeID == storeID }).count < store.type.capacity else { return false }
        if let index = bidReservations.firstIndex(where: { $0.listingID == listingID }) {
            bidReservations[index].maxPrice = maxPrice
        } else {
            bidReservations.append(BidReservation(id: UUID(), listingID: listingID, storeID: storeID, maxPrice: maxPrice))
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
        guard let store = stores.first(where: { $0.id == storeID }),
              store.inventoryCount + incomingCount(for: storeID) + count <= store.type.capacity else { return false }
        let unitCost = Int(Double(category.purchaseCost) * 1.08)
        let total = unitCost * count + 8
        guard cash >= total else { return false }
        cash -= total
        inboundShipments.append(InboundShipment(id: UUID(), storeID: storeID, source: .dealerTrade, category: category, count: count, unitCost: unitCost, quality: 0.80, monthsRemaining: 1))
        save()
        return true
    }

    @discardableResult
    func orderFleetPurchase(category: VehicleCategory, count: Int, storeID: UUID) -> Bool {
        guard count >= 5, let store = stores.first(where: { $0.id == storeID }),
              store.inventoryCount + incomingCount(for: storeID) + count <= store.type.capacity else { return false }
        let unitCost = Int(Double(category.purchaseCost) * 0.88)
        let total = unitCost * count + 25
        guard cash >= total else { return false }
        cash -= total
        inboundShipments.append(InboundShipment(id: UUID(), storeID: storeID, source: .fleetPurchase, category: category, count: count, unitCost: unitCost, quality: 0.70, monthsRemaining: 2))
        save()
        return true
    }

    @discardableResult
    func consignInventory(storeID: UUID, category: VehicleCategory, count: Int, venue: AuctionVenue) -> Bool {
        guard count > 0, let storeIndex = stores.firstIndex(where: { $0.id == storeID }),
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.category == category && $0.count >= count }) else { return false }
        let batch = stores[storeIndex].inventory[batchIndex]
        stores[storeIndex].inventory[batchIndex].count -= count
        if stores[storeIndex].inventory[batchIndex].count == 0 { stores[storeIndex].inventory.remove(at: batchIndex) }
        let specialtyBonus: Double
        switch (venue, category) {
        case (.premium, .premium), (.port, .commercial), (.port, .suv), (.east, .kei), (.east, .compact): specialtyBonus = 1.08
        default: specialtyBonus = 0.98
        }
        let expected = Int(Double(max(batch.averageCost, category.purchaseCost)) * (1.06 + batch.quality * 0.08) * specialtyBonus)
        auctionConsignments.append(AuctionConsignment(id: UUID(), storeID: storeID, venue: venue, category: category, count: count, expectedUnitPrice: expected, monthsRemaining: 1))
        recalculateAssets()
        save()
        return true
    }

    func updateStore(_ store: Store) {
        guard let index = stores.firstIndex(where: { $0.id == store.id }) else { return }
        stores[index] = store
        save()
    }

    @discardableResult
    func renovateStore(_ storeID: UUID, to newType: StoreType) -> Bool {
        guard let index = stores.firstIndex(where: { $0.id == storeID }),
              stores[index].isOperational,
              !stores[index].isRenovating,
              stores[index].type != newType,
              newType.capacity >= stores[index].inventoryCount else { return false }
        let cost = max(600, max(0, newType.buildCost - stores[index].type.buildCost) * 65 / 100)
        guard cash >= cost else { return false }
        cash -= cost
        finance.investingCF -= cost
        stores[index].pendingType = newType
        stores[index].renovationMonthsRemaining = newType.renovationMonths(from: stores[index].type)
        recordCityEvent(CityEvent(turn: turn, kind: .storeGrowth, title: "\(stores[index].name)が改装着工", detail: "\(newType.name)へ改装中。完成まで\(stores[index].renovationMonthsRemaining ?? 1)か月です", plotID: stores[index].plotID))
        recalculateAssets()
        save()
        return true
    }

    func transferInventory(category: VehicleCategory, from sourceID: UUID, to destinationID: UUID) -> Bool {
        guard sourceID != destinationID,
              let source = stores.firstIndex(where: { $0.id == sourceID }),
              let destination = stores.firstIndex(where: { $0.id == destinationID }),
              stores[destination].inventoryCount < stores[destination].type.capacity,
              let batch = stores[source].inventory.firstIndex(where: { $0.category == category && $0.count > 0 }) else { return false }
        let cost = stores[source].inventory[batch].averageCost
        let quality = stores[source].inventory[batch].quality
        stores[source].inventory[batch].count -= 1
        if stores[source].inventory[batch].count == 0 { stores[source].inventory.remove(at: batch) }
        if let targetBatch = stores[destination].inventory.firstIndex(where: { $0.category == category }) {
            stores[destination].inventory[targetBatch].count += 1
        } else {
            stores[destination].inventory.append(InventoryBatch(category: category, count: 1, averageCost: cost, quality: quality))
        }
        save()
        return true
    }

    func regionalOperation(for cityID: String) -> RegionalOperation? {
        regionalOperations.first(where: { $0.cityID == cityID })
    }

    var canExpandNationally: Bool {
        stores.count >= 2 || companyValue >= 45_000
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
              let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.category == category && $0.count >= count }) else { return false }
        let shippingCost = city.shippingCostPerVehicle * count
        guard cash >= shippingCost else { return false }
        let unitCost = stores[storeIndex].inventory[batchIndex].averageCost
        cash -= shippingCost
        finance.operatingCF -= shippingCost
        stores[storeIndex].inventory[batchIndex].count -= count
        if stores[storeIndex].inventory[batchIndex].count == 0 {
            stores[storeIndex].inventory.remove(at: batchIndex)
        }
        intercityShipments.append(IntercityShipment(
            id: UUID(),
            sourceStoreID: storeID,
            destinationCityID: cityID,
            category: category,
            count: count,
            unitCost: unitCost,
            monthsRemaining: city.shippingMonths
        ))
        recalculateAssets()
        save()
        return true
    }

    @discardableResult
    func acceptPurchaseCase(_ caseID: UUID, negotiated: Bool = false, tradeIn: Bool = false) -> Bool {
        guard let caseIndex = purchaseCases.firstIndex(where: { $0.id == caseID }),
              let storeIndex = stores.firstIndex(where: { $0.id == purchaseCases[caseIndex].storeID }) else { return false }
        let item = purchaseCases[caseIndex]
        if negotiated && (turn + item.appraisedPrice) % 4 == 0 { return false }
        let purchasePrice = negotiated ? item.askingPrice * 88 / 100 : item.askingPrice
        let total = purchasePrice + item.repairCost
        guard cash >= total, stores[storeIndex].inventoryCount < stores[storeIndex].type.capacity else { return false }
        cash -= total
        if let batch = stores[storeIndex].inventory.firstIndex(where: { $0.category == item.category }) {
            stores[storeIndex].inventory[batch].count += 1
        } else {
            stores[storeIndex].inventory.append(InventoryBatch(category: item.category, count: 1, averageCost: total, quality: Double(item.conditionScore) / 100))
        }
        stores[storeIndex].reputation = min(1.25, stores[storeIndex].reputation + (tradeIn ? 0.012 : negotiated ? -0.004 : 0.006))
        purchaseCases.remove(at: caseIndex)
        recalculateAssets(); save()
        return true
    }

    func inspectPurchaseCase(_ caseID: UUID) {
        guard let index = purchaseCases.firstIndex(where: { $0.id == caseID }), cash >= 10 else { return }
        cash -= 10
        purchaseCases[index].appraisalAccuracy = 96
        save()
    }

    func declinePurchaseCase(_ caseID: UUID) {
        purchaseCases.removeAll { $0.id == caseID }
        save()
    }

    func borrow(_ amount: Int) {
        guard amount > 0, debt + amount <= borrowingLimit else { return }
        debt += amount; cash += amount; finance.financingCF += amount
        save()
    }

    func repay(_ amount: Int) {
        let actual = min(amount, debt, cash)
        debt -= actual; cash -= actual; finance.financingCF -= actual
        save()
    }

    var borrowingLimit: Int {
        let collateral = finance.landAssets * 6 / 10 + finance.buildingAssets * 3 / 10
        return max(15_000, collateral + 12_000)
    }

    func advanceMonth() {
        guard !gameOver else { return }
        if let tutorialStep, tutorialStep != .completed, tutorialStep != .runFirstMonth {
            tutorialMessage = "先に「\(tutorialStep.title)」を完了してください。"
            return
        }
        let isFirstTutorialMonth = tutorialStep == .runFirstMonth
        var totalSales = 0, revenue = 0, costOfSales = 0, personnel = 0, rent = 0, ads = 0, depreciation = 0
        var notes: [String] = []
        progressStoreProjects(notes: &notes)
        applyDelegatedOperations(notes: &notes)
        processInboundShipments(notes: &notes)
        processIntercityShipments(notes: &notes)
        settleAuctionConsignments(notes: &notes)
        resolveAuctionBids(notes: &notes)

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
            let conceptMatch = conceptFit(stores[index].concept, district: district.kind)
            let location = plot.visibility * plot.access * plot.traffic
            let marketing = 0.85 + min(0.35, Double(stores[index].advertising) / 600.0)
            let priceAppeal = max(0.65, 1.7 - stores[index].priceIndex * 0.7)
            let competition = max(0.54, 1.10 - district.competition * 0.20 - Double(competitorCount(in: plot.district)) * 0.035)
            let season = [3, 9].contains(month) ? 1.13 : ([1, 8].contains(month) ? 0.92 : 1.0)
            let capacity = min(stores[index].inventoryCount, stores[index].type.capacity)
            let potential = Double(estimatedVisitors(for: plot)) * 0.105 * demand * conceptMatch * location * marketing * priceAppeal * competition * season
            let random = deterministicVariation(seed: turn * 17 + plot.id)
            let tutorialMinimum = isFirstTutorialMonth && stores[index].plotID == tutorialPlotID && capacity > 0 ? 1 : 0
            let sales = min(capacity, max(tutorialMinimum, Int(potential * random)))

            let available = stores[index].inventory.filter { $0.count > 0 }
            var remaining = sales, storeRevenue = 0, storeCOGS = 0
            for batchIndex in stores[index].inventory.indices where remaining > 0 {
                let sold = min(remaining, stores[index].inventory[batchIndex].count)
                let batch = stores[index].inventory[batchIndex]
                let margin = 1.18 + batch.quality * 0.10 + conceptMarginBonus(stores[index].concept, category: batch.category, district: district.kind, serviceAllocation: stores[index].serviceAllocation)
                let salePrice = Int(Double(batch.averageCost) * margin * stores[index].priceIndex)
                storeRevenue += salePrice * sold
                storeCOGS += batch.averageCost * sold
                stores[index].inventory[batchIndex].count -= sold
                remaining -= sold
            }
            stores[index].inventory.removeAll { $0.count == 0 }
            let staffCost = stores[index].staff * 34
            let storeRent = stores[index].acquisition == .lease ? plot.monthlyRent : 0
            let storeDepreciation = stores[index].type.buildCost / 240
            let storeProfit = storeRevenue - storeCOGS - staffCost - storeRent - stores[index].advertising - stores[index].type.monthlyFixedCost - storeDepreciation
            let inventoryPenalty = available.isEmpty ? 0.4 : 0.0
            stores[index].lastSales = sales
            stores[index].lastRevenue = storeRevenue
            stores[index].lastProfit = storeProfit
            stores[index].satisfaction = min(96, max(42, Int(58 + stores[index].type.serviceQuality * 12 + stores[index].serviceAllocation * 20 - max(0, stores[index].priceIndex - 1) * 24 - inventoryPenalty * 12)))
            stores[index].reputation = min(1.25, max(0.4, stores[index].reputation + (Double(stores[index].satisfaction) - 70) / 4_000))
            stores[index].causes = makeCauses(demand: demand, concept: conceptMatch, conceptName: stores[index].concept.name, marketing: marketing, competition: competition, inventory: capacity)
            if stores[index].visualTier > previousVisualTier {
                recordCityEvent(CityEvent(turn: turn + 1, kind: .storeGrowth, title: "\(stores[index].name)が成長", detail: "評判と業績が向上し、店舗外観がレベル\(stores[index].visualTier)になりました", district: plot.district, plotID: plot.id))
                notes.append("\(stores[index].name)の店舗外観が成長しました")
            }
            totalSales += sales; revenue += storeRevenue; costOfSales += storeCOGS; personnel += staffCost; rent += storeRent; ads += stores[index].advertising; depreciation += storeDepreciation
        }

        let regional = simulateRegionalOperations(notes: &notes)
        totalSales += regional.sales
        revenue += regional.revenue
        costOfSales += regional.costOfSales
        personnel += regional.fixedCosts
        ads += regional.advertising

        let fixed = stores.filter(\.isOperational).reduce(0) { $0 + $1.type.monthlyFixedCost }
        let interest = debt / 2_400
        let operatingProfit = revenue - costOfSales - personnel - rent - ads - depreciation - fixed - interest
        cash += operatingProfit + depreciation
        finance = FinanceSnapshot(revenue: revenue, costOfSales: costOfSales, personnel: personnel, rent: rent, advertising: ads, depreciation: depreciation, operatingProfit: operatingProfit, landAssets: finance.landAssets, buildingAssets: finance.buildingAssets, inventoryAssets: inventoryAssetValue(), debt: debt, operatingCF: operatingProfit + depreciation, investingCF: 0, financingCF: -interest)
        simulateDistrictDynamics(notes: &notes)
        updateLandValues(notes: &notes)
        progressDevelopments(notes: &notes)
        simulateCompetitors(notes: &notes)
        generatePurchaseCases()
        generateAuctionListings()
        unlockTutorial(notes: &notes)
        turn += 1
        month += 1
        if month > 12 { month = 1; year += 1 }
        companyValue = max(0, cash + finance.landAssets + finance.buildingAssets + finance.inventoryAssets - debt + max(0, operatingProfit * 18))
        let headline: String
        if operatingProfit > 300 { headline = "好調な一か月。成長投資を考えましょう" }
        else if operatingProfit >= 0 { headline = "黒字を確保。店舗ごとの差を確認しましょう" }
        else { headline = "赤字です。原因を確認して手を打ちましょう" }
        if totalInventory < stores.count * 5 { notes.append("在庫が少なく、販売機会を逃す店舗があります") }
        let report = MonthlyReport(id: UUID(), year: year, month: month, sales: totalSales, revenue: revenue, grossProfit: revenue - costOfSales, operatingProfit: operatingProfit, cashChange: operatingProfit + depreciation, headline: headline, notes: notes)
        reports.insert(report, at: 0); lastReport = report
        if isFirstTutorialMonth { tutorialStep = .reviewFirstResult }
        showMonthlyReport = true
        if cash < -2_000 { gameOver = true }
        if turn >= maxTurns { gameOver = true }
        recalculateAssets()
        save()
    }

    func recommendedCategories(for kind: DistrictKind) -> [VehicleCategory] {
        guard let district = districts.first(where: { $0.kind == kind }) else { return [.compact] }
        return district.demands.sorted { $0.value > $1.value }.map(\.key)
    }

    func recommendedConcept(for kind: DistrictKind) -> StoreConcept {
        switch kind {
        case .downtown: .premium
        case .suburb: .keiLocal
        case .station: .keiLocal
        case .industrial: .custom
        case .emerging: .family
        case .highway: .business
        }
    }

    func demandScore(for plot: LandPlot) -> Double {
        let d = district(for: plot)
        return d.demands.values.reduce(0, +) / Double(max(1, d.demands.count)) * d.growthRate
    }

    func vehicleDemand(_ category: VehicleCategory, in kind: DistrictKind) -> Double {
        districts.first(where: { $0.kind == kind })?.demands[category] ?? 0.55
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
        let stocked = store.inventory.filter { $0.count > 0 }
        guard !stocked.isEmpty else { return 0.45 }
        let weighted = stocked.reduce(0.0) { $0 + (district.demands[$1.category] ?? 0.7) * Double($1.count) }
        return weighted / Double(max(1, store.inventoryCount)) * focusFit(store.focus, district: district.kind) * store.reputation
    }

    private func conceptFit(_ concept: StoreConcept, district: DistrictKind) -> Double {
        switch (concept, district) {
        case (.general, _): 1.0
        case (.keiLocal, .suburb), (.keiLocal, .station): 1.20
        case (.family, .suburb), (.family, .emerging): 1.22
        case (.custom, .industrial), (.custom, .highway): 1.24
        case (.premium, .downtown): 1.28
        case (.business, .industrial), (.business, .highway): 1.23
        case (.premium, .industrial), (.custom, .downtown), (.business, .station): 0.76
        default: 0.94
        }
    }

    private func conceptMarginBonus(_ concept: StoreConcept, category: VehicleCategory, district: DistrictKind, serviceAllocation: Double) -> Double {
        switch concept {
        case .custom:
            let suitedCategory = [.suv, .budget, .commercial].contains(category)
            return district == .industrial && suitedCategory ? 0.08 + serviceAllocation * 0.16 : 0.02
        case .premium:
            return district == .downtown && category == .premium ? 0.13 : 0.03
        case .keiLocal:
            return [.suburb, .station].contains(district) && category == .kei ? 0.055 : 0.01
        case .family:
            return [.minivan, .suv].contains(category) ? 0.06 : 0.015
        case .business:
            return category == .commercial ? 0.07 : 0.015
        case .general:
            return 0
        }
    }

    private func deterministicVariation(seed: Int) -> Double {
        let value = abs((seed &* 1_103_515_245 &+ 12_345) % 100)
        return 0.88 + Double(value) / 420.0
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
        case 4: unlockedFeatures.insert("出店"); notes.append("土地取得と2店舗目の出店が解放されました")
        default: break
        }
    }

    private func simulateCompetitors(notes: inout [String]) {
        for index in competitors.indices {
            competitors[index].cash += Int(competitors[index].strength * 420)
        }

        if turn >= 10 && turn % 11 == 0 {
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

        guard turn > 0, turn % 8 == 0 else { return }
        let eligible = competitors.indices.filter { competitors[$0].plotIDs.count < 5 }
        guard let companyIndex = eligible.isEmpty ? nil : eligible[(turn / 8) % eligible.count] else { return }
        let occupied = Set(competitors.flatMap(\.plotIDs) + stores.map(\.plotID))
        let company = competitors[companyIndex]
        let candidates = plots.filter {
            !occupied.contains($0.id) && isAvailable($0.occupant) && $0.development == nil && $0.price + StoreType.standard.buildCost <= company.cash
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
            let monthlyGrowth = (d.growthRate - 1.0) / 18 + deterministicVariation(seed: turn + plots[index].id) / 200 - 0.005
            plots[index].lastPriceChange = monthlyGrowth
            plots[index].price = max(1_200, Int(Double(plots[index].price) * (1 + monthlyGrowth)))
            plots[index].monthlyRent = max(8, Int(Double(plots[index].monthlyRent) * (1 + monthlyGrowth * 0.35)))
            if abs(monthlyGrowth) > abs(largestChange?.rate ?? 0) { largestChange = (plots[index], monthlyGrowth) }
        }
        if let change = largestChange, abs(change.rate) >= 0.006 {
            let direction = change.rate >= 0 ? "上昇" : "下落"
            recordCityEvent(CityEvent(turn: turn + 1, kind: .landPrice, title: "地価が\(direction)", detail: "\(change.plot.district.shortName)地区で前月比\(String(format: "%+.1f", change.rate * 100))%", district: change.plot.district, plotID: change.plot.id, isPositive: change.rate >= 0))
        }
    }

    private func simulateDistrictDynamics(notes: inout [String]) {
        for index in districts.indices {
            let annualGrowth = districts[index].growthRate - 1
            let noise = deterministicVariation(seed: turn * 31 + index * 9) - 1
            let populationRate = annualGrowth / 12 + noise * 0.0015
            districts[index].population = max(20_000, Int(Double(districts[index].population) * (1 + populationRate)))
            districts[index].trafficIndex = min(1.75, max(0.65, districts[index].trafficIndex * (1 + populationRate * 0.18 + noise * 0.003)))

            for category in VehicleCategory.allCases {
                let current = districts[index].demands[category] ?? 0.68
                let categoryShift = (deterministicVariation(seed: turn * 43 + index * 13 + categoryIndex(category)) - 1) * 0.012
                districts[index].demands[category] = min(1.75, max(0.38, current + categoryShift))
            }
            let storesInDistrict = competitorCount(in: districts[index].kind) + stores.filter { plot(id: $0.plotID)?.district == districts[index].kind }.count
            districts[index].competition = min(1.75, max(0.42, 0.52 + Double(storesInDistrict) * 0.17 + districts[index].trafficIndex * 0.18))
        }

        if turn.isMultiple(of: 3), let hottest = districts.max(by: { $0.population < $1.population }) {
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

        guard turn > 0, turn.isMultiple(of: 18), !plots.contains(where: { $0.development != nil }) else { return }
        let candidates = plots.indices.filter { isAvailable(plots[$0].occupant) }
        guard let index = candidates.max(by: { plots[$0].growth < plots[$1].growth }) else { return }
        plots[index].development = DevelopmentProject(title: "複合商業・住宅開発", monthsRemaining: 6, populationBoost: 3_600, trafficBoost: 0.08)
        let event = CityEvent(turn: turn + 1, kind: .development, title: "新しい開発計画", detail: "\(plots[index].district.shortName)地区で複合開発が始まります。完成まで6か月", district: plots[index].district, plotID: plots[index].id)
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

    private func recalculateAssets() {
        finance.landAssets = stores.compactMap { store -> Int? in
            guard store.acquisition == .purchase, let p = plot(id: store.plotID) else { return nil }
            return p.price
        }.reduce(0, +)
        finance.buildingAssets = stores.reduce(0) { $0 + $1.type.buildCost }
            + regionalOperations.reduce(0) { $0 + $1.officeLevel * 2_400 + $1.franchiseStores * 1_100 + $1.acquiredStores * 4_200 }
        finance.inventoryAssets = inventoryAssetValue()
        finance.debt = debt
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
                    notes.append("\(stores[index].name)は建設中（完成まで\(next)か月）")
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
                    notes.append("\(stores[index].name)は改装中（完成まで\(next)か月）")
                }
            }
        }
    }

    private func inventoryAssetValue() -> Int {
        stores.flatMap(\.inventory).reduce(0) { $0 + $1.averageCost * $1.count }
            + regionalOperations.flatMap(\.inventory).reduce(0) { $0 + $1.averageCost * $1.count }
            + intercityShipments.reduce(0) { $0 + $1.unitCost * $1.count }
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
            addInventory(category: shipment.category, count: shipment.count, unitCost: shipment.unitCost, quality: shipment.quality, to: storeIndex)
            inboundShipments.removeAll { $0.id == shipment.id }
            let text = "\(shipment.source.name)の\(shipment.category.name)\(shipment.count)台が\(stores[storeIndex].name)へ到着"
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
            if let batchIndex = regionalOperations[operationIndex].inventory.firstIndex(where: { $0.category == shipment.category && $0.averageCost == shipment.unitCost }) {
                regionalOperations[operationIndex].inventory[batchIndex].count += shipment.count
            } else {
                regionalOperations[operationIndex].inventory.append(InventoryBatch(category: shipment.category, count: shipment.count, averageCost: shipment.unitCost, quality: 0.78))
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
            let fixedCosts = operation.officeLevel * 120 + operation.franchiseStores * 72 + operation.acquiredStores * 185
            let advertising = operation.advertisingBudget
            let network = operation.networkStores
            let inventoryCount = operation.inventoryCount
            let baseDemand = Double(network * 3) + Double(city.population) / 180_000.0
            let appeal = city.incomeIndex * (0.72 + operation.brandStrength * 0.32) * (0.76 + nationalBrandStrength * 0.24)
            let competition = max(0.58, 1.14 - city.competitionIndex * 0.20)
            let growth = 0.94 + city.growthRate * 0.06
            let variation = deterministicVariation(seed: turn * 31 + index * 7 + city.population / 10_000)
            let targetSales = network == 0 ? 0 : max(0, Int(baseDemand * appeal * competition * growth * variation))
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
            regionalOperations[index].brandStrength = min(1.40, max(0.42, operation.brandStrength + Double(advertising) / 40_000.0 - 0.003))

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

    private func applyDelegatedOperations(notes: inout [String]) {
        for index in stores.indices {
            guard stores[index].isOperational,
                  let plot = plot(id: stores[index].plotID) else { continue }
            var actions: [String] = []

            if stores[index].delegateStaff {
                let target = min(12, max(3, 2 + stores[index].inventoryCount / 7 + stores[index].lastSales / 6))
                if stores[index].staff < target { stores[index].staff += 1; actions.append("1名採用") }
                else if stores[index].staff > target + 2 { stores[index].staff -= 1; actions.append("人員を適正化") }
            }

            if stores[index].delegatePricing {
                let stockRate = Double(stores[index].inventoryCount + incomingCount(for: stores[index].id)) / Double(max(1, stores[index].type.capacity))
                let targetPrice = stockRate > 0.72 ? 0.96 : stockRate < 0.30 ? 1.05 : 1.0
                if abs(stores[index].priceIndex - targetPrice) >= 0.02 {
                    stores[index].priceIndex += targetPrice > stores[index].priceIndex ? 0.02 : -0.02
                    actions.append("価格を調整")
                }
                let freeCapacity = stores[index].type.capacity - stores[index].inventoryCount - incomingCount(for: stores[index].id)
                if stockRate < 0.28, freeCapacity >= 3 {
                    let category = recommendedCategories(for: plot.district).first ?? .compact
                    let unitCost = Int(Double(category.purchaseCost) * 1.08)
                    let total = unitCost * 3 + 8
                    if cash >= total {
                        cash -= total
                        inboundShipments.append(InboundShipment(id: UUID(), storeID: stores[index].id, source: .dealerTrade, category: category, count: 3, unitCost: unitCost, quality: 0.80, monthsRemaining: 1))
                        actions.append("\(category.name)3台を自動発注")
                    }
                }
            }

            if stores[index].delegateMarketing {
                let target = min(360, 70 + competitorCount(in: plot.district) * 45 + max(0, stores[index].lastProfit) / 12)
                if abs(stores[index].advertising - target) >= 20 {
                    stores[index].advertising += target > stores[index].advertising ? 20 : -20
                    actions.append("広告予算を調整")
                }
            }

            if stores[index].delegateService {
                let target = stores[index].satisfaction < 72 ? 0.55 : stores[index].inventoryCount > stores[index].type.capacity * 7 / 10 ? 0.35 : 0.45
                if abs(stores[index].serviceAllocation - target) >= 0.04 {
                    stores[index].serviceAllocation += target > stores[index].serviceAllocation ? 0.05 : -0.05
                    actions.append("整備配分を調整")
                }
            }

            if !actions.isEmpty { notes.append("\(stores[index].name)店長：\(actions.joined(separator: "、"))") }
        }
    }

    private func resolveAuctionBids(notes: inout [String]) {
        let reservations = bidReservations
        for bid in reservations {
            guard let listing = auctionListings.first(where: { $0.id == bid.listingID }),
                  let storeIndex = stores.firstIndex(where: { $0.id == bid.storeID }) else { continue }
            let spread = max(4, listing.marketPrice - listing.reservePrice)
            let rivalBid = listing.reservePrice + ((turn * 17 + listing.modelYear + listing.mileage / 1_000) % (spread + 12))
            let hammerPrice = min(listing.marketPrice + spread / 2, rivalBid)
            let total = hammerPrice + listing.venue.fee + listing.venue.shippingCost
            if hammerPrice <= bid.maxPrice && cash >= total {
                cash -= total
                inboundShipments.append(InboundShipment(id: UUID(), storeID: bid.storeID, source: .auction, category: listing.category, count: 1, unitCost: total, quality: listing.quality, monthsRemaining: listing.venue.shippingMonths))
                notes.append("\(listing.venue.name)で\(listing.category.name)を\(hammerPrice.currency)で落札しました")
            } else {
                notes.append("\(listing.category.name)の入札は上限\(bid.maxPrice.currency)を超えて見送りました")
            }
            auctionListings.removeAll { $0.id == listing.id }
            bidReservations.removeAll { $0.id == bid.id }
            _ = storeIndex
        }
    }

    private func settleAuctionConsignments(notes: inout [String]) {
        for index in auctionConsignments.indices { auctionConsignments[index].monthsRemaining -= 1 }
        let settled = auctionConsignments.filter { $0.monthsRemaining <= 0 }
        for order in settled {
            let variation = 94 + ((turn * 13 + order.count * 7 + categoryIndex(order.category)) % 15)
            let proceeds = max(0, order.expectedUnitPrice * order.count * variation / 100 - order.venue.fee * order.count)
            cash += proceeds
            notes.append("\(order.venue.name)への出品車\(order.count)台が成約し、\(proceeds.currency)を受け取りました")
            auctionConsignments.removeAll { $0.id == order.id }
        }
    }

    private func addInventory(category: VehicleCategory, count: Int, unitCost: Int, quality: Double, to storeIndex: Int) {
        if let batchIndex = stores[storeIndex].inventory.firstIndex(where: { $0.category == category && abs($0.averageCost - unitCost) < 20 }) {
            let batch = stores[storeIndex].inventory[batchIndex]
            let totalCount = batch.count + count
            stores[storeIndex].inventory[batchIndex].averageCost = (batch.averageCost * batch.count + unitCost * count) / max(1, totalCount)
            stores[storeIndex].inventory[batchIndex].quality = (batch.quality * Double(batch.count) + quality * Double(count)) / Double(max(1, totalCount))
            stores[storeIndex].inventory[batchIndex].count = totalCount
        } else {
            stores[storeIndex].inventory.append(InventoryBatch(category: category, count: count, averageCost: unitCost, quality: quality))
        }
    }

    private func generateAuctionListings() {
        if turn > 0 && auctionListings.count >= 15 {
            let stale = auctionListings.filter { listing in !bidReservations.contains(where: { $0.listingID == listing.id }) }.prefix(3).map(\.id)
            auctionListings.removeAll { stale.contains($0.id) }
        }
        while auctionListings.count < 18 {
            let index = auctionListings.count + turn * 5
            let venue = AuctionVenue.allCases[index % AuctionVenue.allCases.count]
            let categories: [VehicleCategory]
            switch venue {
            case .east: categories = [.kei, .compact, .budget, .minivan]
            case .port: categories = [.commercial, .suv, .budget, .minivan]
            case .premium: categories = [.premium, .suv, .compact]
            }
            let category = categories[(index / 2 + turn) % categories.count]
            let quality = 0.58 + Double((index * 11 + turn * 7) % 37) / 100
            let market = Int(Double(category.purchaseCost) * (0.88 + quality * 0.24))
            let reserve = max(28, market * (78 + (index % 13)) / 100)
            auctionListings.append(AuctionListing(id: UUID(), venue: venue, category: category, modelYear: 2016 + ((index + turn) % 10), mileage: 16_000 + ((index * 9_700 + turn * 4_100) % 128_000), quality: quality, reservePrice: reserve, marketPrice: market, seller: index.isMultiple(of: 3) ? "法人リース" : "中古車業者"))
        }
    }

    private func save() {
        let snapshot = SaveData(hasStarted: hasStarted, year: year, month: month, turn: turn, cash: cash, debt: debt, companyValue: companyValue, districts: districts, plots: plots, stores: stores, competitors: competitors, reports: reports, purchaseCases: purchaseCases, cityEvents: cityEvents, auctionListings: auctionListings, bidReservations: bidReservations, inboundShipments: inboundShipments, auctionConsignments: auctionConsignments, finance: finance, unlockedFeatures: unlockedFeatures, regionalOperations: regionalOperations, intercityShipments: intercityShipments, nationalBrandStrength: nationalBrandStrength, tutorialStep: tutorialStep, tutorialPlotID: tutorialPlotID, startupPlan: startupPlan)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    private func prepareDemoCompany(plan: StartupPlan) {
        start(plan: plan)
        guard let plot = recommendedFoundingPlot else { return }
        selectFoundingPlot(plot.id)
        _ = buildStore(
            on: plot,
            type: plan.recommendedStoreType,
            mode: .lease,
            focus: plan.recommendedFocus,
            concept: plan.recommendedConcept,
            loanAmount: 0
        )
        if let store = stores.first {
            for category in recommendedCategories(for: plot.district).prefix(2) {
                _ = buyInventory(category: category, count: 6, storeID: store.id)
            }
        }
        completeTutorial()
        tutorialMessage = nil
    }

    private func placeCompetitors() {
        let placements: [(Int, Int)] = [(0, 3), (1, 8), (2, 16), (0, 24), (1, 31)]
        for (competitorIndex, plotID) in placements {
            guard plots.indices.contains(plotID), competitors.indices.contains(competitorIndex) else { continue }
            competitors[competitorIndex].plotIDs.append(plotID)
            plots[plotID].occupant = .competitor(name: competitors[competitorIndex].name)
        }
    }

    private func generatePurchaseCases() {
        for store in stores where store.isOperational {
            let existing = purchaseCases.filter { $0.storeID == store.id }.count
            guard existing < 3, let plot = plot(id: store.plotID) else { continue }
            let recommended = recommendedCategories(for: plot.district)
            for offset in 0..<(3 - existing) {
                let category = recommended[(turn + offset) % max(1, recommended.count)]
                let base = category.purchaseCost
                let condition = 62 + ((plot.id * 13 + turn * 7 + offset * 11) % 31)
                let asking = max(35, base * (82 + ((turn + offset * 3) % 19)) / 100)
                let repair = max(6, (100 - condition) * base / 230)
                purchaseCases.append(PurchaseCase(
                    id: UUID(), storeID: store.id, category: category,
                    modelYear: 2017 + ((plot.id + turn + offset) % 9),
                    mileage: 18_000 + ((plot.id * 8_300 + turn * 5_700 + offset * 13_000) % 94_000),
                    exterior: condition - 3, interior: condition + 2, mechanical: condition,
                    askingPrice: asking, appraisedPrice: max(30, asking * 92 / 100), repairCost: repair,
                    expectedSalePrice: Int(Double(base) * (1.22 + Double(condition) / 520)),
                    expectedDays: 25 + ((plot.id + turn + offset * 9) % 54),
                    demand: district(for: plot).demands[category] ?? 0.85,
                    appraisalAccuracy: 68 + ((plot.id + turn + offset) % 17)
                ))
            }
        }
    }

    static func makeDistricts() -> [District] {
        [
            District(kind: .downtown, population: 92_000, incomeIndex: 1.42, trafficIndex: 1.35, growthRate: 1.01, competition: 1.35, demands: [.premium: 1.48, .suv: 1.12, .compact: 1.0, .kei: 0.72]),
            District(kind: .station, population: 76_000, incomeIndex: 1.03, trafficIndex: 1.42, growthRate: 1.015, competition: 1.28, demands: [.compact: 1.42, .kei: 1.25, .budget: 1.08, .premium: 0.78]),
            District(kind: .emerging, population: 58_000, incomeIndex: 1.16, trafficIndex: 1.02, growthRate: 1.065, competition: 0.72, demands: [.suv: 1.52, .minivan: 1.45, .compact: 0.95]),
            District(kind: .suburb, population: 88_000, incomeIndex: 1.08, trafficIndex: 1.18, growthRate: 1.02, competition: 1.02, demands: [.minivan: 1.48, .kei: 1.30, .suv: 1.26, .compact: 1.05]),
            District(kind: .industrial, population: 43_000, incomeIndex: 0.82, trafficIndex: 0.88, growthRate: 0.99, competition: 0.58, demands: [.commercial: 1.55, .budget: 1.42, .kei: 1.15, .premium: 0.42]),
            District(kind: .highway, population: 66_000, incomeIndex: 0.91, trafficIndex: 1.48, growthRate: 1.012, competition: 0.93, demands: [.kei: 1.42, .budget: 1.34, .suv: 1.12, .commercial: 1.08])
        ]
    }

    static func makePlots() -> [LandPlot] {
        let order: [DistrictKind] = [.downtown, .station, .emerging, .suburb, .industrial, .highway]
        var result: [LandPlot] = []
        for (districtIndex, district) in order.enumerated() {
            for local in 1...6 {
                let id = districtIndex * 6 + local - 1
                let base: Int
                switch district { case .downtown: base = 14_000; case .station: base = 9_500; case .suburb: base = 7_000; case .emerging: base = 6_200; case .industrial: base = 3_800; case .highway: base = 4_700 }
                let variation = 88 + ((id * 17) % 27)
                let price = base * variation / 100
                let development: DevelopmentProject?
                switch id {
                case 14: development = DevelopmentProject(title: "ひかりニュータウン第2期", monthsRemaining: 5, populationBoost: 5_200, trafficBoost: 0.10)
                case 29: development = DevelopmentProject(title: "臨海物流パーク", monthsRemaining: 8, populationBoost: 1_800, trafficBoost: 0.13)
                default: development = nil
                }
                result.append(LandPlot(id: id, district: district, localNumber: local, area: 320 + ((id * 73) % 680), visibility: 0.78 + Double((id * 11) % 35) / 100, access: 0.80 + Double((id * 7) % 31) / 100, traffic: 0.82 + Double((id * 13) % 38) / 100, price: price, monthlyRent: max(18, price / 210), growth: 0.98 + Double((id * 5) % 11) / 100, occupant: .available, isForLease: local % 3 != 0, isForSale: local % 4 != 0, development: development))
            }
        }
        return result
    }

    static func makeCompetitors() -> [Competitor] {
        [
            Competitor(id: UUID(), name: "バリューオート", strategy: "低価格・高回転", colorHex: "E46B35", cash: 42_000, plotIDs: [], strength: 1.02, category: .budget),
            Competitor(id: UUID(), name: "プレミアモータース", strategy: "品質と保証", colorHex: "7356A8", cash: 58_000, plotIDs: [], strength: 1.15, category: .premium),
            Competitor(id: UUID(), name: "ドライブMAX", strategy: "多店舗・大量展示", colorHex: "287DB2", cash: 64_000, plotIDs: [], strength: 1.08, category: .suv)
        ]
    }

    static func makeNationalCities() -> [NationalCity] {
        [
            NationalCity(id: "suihama", name: "翠浜市", region: "首都圏", population: 423_000, incomeIndex: 1.08, landPriceIndex: 1.00, competitionIndex: 1.02, growthRate: 1.018, primaryDemand: [.minivan, .kei, .suv], expansionCost: 0, shippingMonths: 0, shippingCostPerVehicle: 0, mapX: 0.72, mapY: 0.42),
            NationalCity(id: "hokusei", name: "北星市", region: "北日本", population: 318_000, incomeIndex: 0.91, landPriceIndex: 0.66, competitionIndex: 0.72, growthRate: 1.004, primaryDemand: [.suv, .kei, .commercial], expansionCost: 6_800, shippingMonths: 2, shippingCostPerVehicle: 18, mapX: 0.72, mapY: 0.12),
            NationalCity(id: "shinonome", name: "東雲市", region: "中部", population: 512_000, incomeIndex: 1.04, landPriceIndex: 0.88, competitionIndex: 0.94, growthRate: 1.023, primaryDemand: [.commercial, .compact, .suv], expansionCost: 7_600, shippingMonths: 1, shippingCostPerVehicle: 11, mapX: 0.58, mapY: 0.48),
            NationalCity(id: "naniwa", name: "浪華市", region: "関西", population: 884_000, incomeIndex: 1.16, landPriceIndex: 1.24, competitionIndex: 1.31, growthRate: 1.011, primaryDemand: [.premium, .minivan, .compact], expansionCost: 11_500, shippingMonths: 2, shippingCostPerVehicle: 15, mapX: 0.43, mapY: 0.55),
            NationalCity(id: "setouchi", name: "瀬戸内市", region: "中国・四国", population: 276_000, incomeIndex: 0.89, landPriceIndex: 0.58, competitionIndex: 0.63, growthRate: 1.015, primaryDemand: [.kei, .commercial, .budget], expansionCost: 5_900, shippingMonths: 2, shippingCostPerVehicle: 17, mapX: 0.28, mapY: 0.61),
            NationalCity(id: "hinata", name: "日向市", region: "九州", population: 391_000, incomeIndex: 0.94, landPriceIndex: 0.72, competitionIndex: 0.81, growthRate: 1.029, primaryDemand: [.kei, .suv, .minivan], expansionCost: 6_500, shippingMonths: 3, shippingCostPerVehicle: 22, mapX: 0.16, mapY: 0.76)
        ]
    }
}
