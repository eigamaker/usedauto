import XCTest
@testable import UsedCarCity

@MainActor
final class GameEngineTests: XCTestCase {
    private func startPlayableGame(_ game: GameEngine, plan: StartupPlan = .family) {
        game.start(plan: plan)
        let plot = game.recommendedFoundingPlot!
        game.selectFoundingPlot(plot.id)
        XCTAssertTrue(game.buildStore(
            on: plot,
            type: plan.recommendedStoreType,
            mode: .lease,
            focus: plan.recommendedFocus,
            concept: plan.recommendedConcept,
            loanAmount: 0
        ))
        let store = game.stores[0]
        for category in game.recommendedCategories(for: plot.district).prefix(2) {
            XCTAssertTrue(game.buyInventory(category: category, count: 2, storeID: store.id))
        }
        game.completeTutorial()
        game.tutorialMessage = nil
    }

    func testNewGameCreatesSixDistrictsAndThirtySixPlots() {
        let game = GameEngine()
        game.resetGame()
        XCTAssertEqual(game.districts.count, 6)
        XCTAssertEqual(game.plots.count, 36)
    }

    func testStartupBeginsWithLocationSelectionOnMap() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        XCTAssertTrue(game.hasStarted)
        XCTAssertEqual(game.stores.count, 0)
        XCTAssertEqual(game.totalInventory, 0)
        XCTAssertEqual(game.tutorialStep, .chooseLocation)
        XCTAssertEqual(game.foundingCandidatePlots.count, DistrictKind.allCases.count)
        XCTAssertEqual(game.recommendedFoundingPlot?.district, .suburb)
    }

    func testTutorialPerformsBuildPurchaseAndFirstNegotiation() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .discount)
        let plot = game.recommendedFoundingPlot!

        game.selectFoundingPlot(plot.id)
        XCTAssertEqual(game.tutorialStep, .buildStore)
        XCTAssertTrue(game.buildStore(on: plot, type: .small, mode: .lease, focus: .value, concept: .custom, loanAmount: 0))
        XCTAssertEqual(game.tutorialStep, .purchaseInventory)
        XCTAssertTrue(game.stores[0].isOperational)
        XCTAssertEqual(game.totalInventory, 0)

        let store = game.stores[0]
        let category = game.recommendedCategories(for: plot.district)[0]
        XCTAssertTrue(game.buyInventory(category: category, count: 3, storeID: store.id))
        XCTAssertEqual(game.tutorialStep, .runFirstMonth)

        XCTAssertNotNil(game.negotiateManualSale(storeID: store.id, category: category, strategy: .smallDiscount))
        game.advanceWeek()

        XCTAssertEqual(game.tutorialStep, .completed)
        XCTAssertEqual(game.reports.count, 1)
    }

    func testAdvancingWeekCreatesReport() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        game.advanceWeek()
        XCTAssertEqual(game.turn, 1)
        XCTAssertEqual(game.reports.count, 1)
    }

    func testStoreConceptChangesLocationFit() {
        let game = GameEngine()
        game.resetGame()
        let industrial = game.plots.first(where: { $0.district == .industrial })!
        let downtown = game.plots.first(where: { $0.district == .downtown })!

        XCTAssertGreaterThan(
            game.estimatedSales(for: industrial, concept: .custom).upperBound,
            game.estimatedSales(for: industrial, concept: .premium).upperBound
        )
        XCTAssertGreaterThan(
            game.estimatedSales(for: downtown, focus: .affluent, concept: .premium).upperBound,
            game.estimatedSales(for: downtown, focus: .affluent, concept: .custom).upperBound
        )
    }

    func testCustomerPurchaseCaseCanBecomeInventory() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let store = game.stores[0]
        let beforeInventory = store.inventoryCount
        let beforeCash = game.cash
        let item = game.purchaseCases.first!
        let beforeCases = game.purchaseCases.count

        game.inspectPurchaseCase(item.id)
        XCTAssertEqual(game.purchaseCases.first(where: { $0.id == item.id })?.appraisalAccuracy, 96)
        XCTAssertTrue(game.acceptPurchaseCase(item.id))
        XCTAssertEqual(game.purchaseCases.count, beforeCases - 1)
        XCTAssertEqual(game.stores[0].inventoryCount, beforeInventory + 1)
        XCTAssertLessThan(game.cash, beforeCash)
    }

    func testCityEconomyChangesWhenWeekAdvances() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let population = game.districts.first(where: { $0.kind == .emerging })!.population
        let landPrice = game.plots[14].price

        game.advanceWeek()

        XCTAssertNotEqual(game.districts.first(where: { $0.kind == .emerging })!.population, population)
        XCTAssertNotEqual(game.plots[14].price, landPrice)
        XCTAssertNotEqual(game.plots[14].lastPriceChange, 0)
        XCTAssertFalse(game.cityEvents.isEmpty)
    }

    func testDevelopmentCompletesAndBoostsDistrict() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let population = game.districts.first(where: { $0.kind == .emerging })!.population
        XCTAssertNotNil(game.plots[14].development)

        for _ in 0..<5 { game.advanceWeek() }

        XCTAssertNil(game.plots[14].development)
        XCTAssertGreaterThan(game.districts.first(where: { $0.kind == .emerging })!.population, population)
        XCTAssertTrue(game.cityEvents.contains { $0.kind == .development && $0.plotID == 14 && $0.title.contains("完成") })
    }

    func testAuctionBidCreatesInboundShipmentAtWeekEnd() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let listing = game.auctionListings.first!
        let store = game.stores[0]
        let cash = game.cash

        XCTAssertTrue(game.reserveBid(listingID: listing.id, storeID: store.id, maxPrice: listing.marketPrice * 2))
        game.advanceWeek()

        XCTAssertFalse(game.bidReservations.contains { $0.listingID == listing.id })
        XCTAssertTrue(game.inboundShipments.contains { $0.source == .auction && $0.category == listing.category })
        XCTAssertLessThan(game.cash, cash)
    }

    func testDealerTradeArrivesAfterOneWeek() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let store = game.stores[0]

        XCTAssertTrue(game.orderDealerTrade(category: .compact, count: 3, storeID: store.id))
        XCTAssertEqual(game.incomingCount(for: store.id), 3)
        game.advanceWeek()

        XCTAssertEqual(game.incomingCount(for: store.id), 0)
        XCTAssertTrue(game.lastReport?.notes.contains(where: { $0.contains("業者間取引") && $0.contains("到着") }) == true)
    }

    func testInventoryCanBeConsignedToAuction() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let store = game.stores[0]
        let category = store.inventory[0].category
        let inventory = store.inventoryCount

        XCTAssertTrue(game.consignInventory(storeID: store.id, category: category, count: 1, venue: .east))
        XCTAssertEqual(game.stores[0].inventoryCount, inventory - 1)
        game.advanceWeek()

        XCTAssertTrue(game.auctionConsignments.isEmpty)
        XCTAssertTrue(game.lastReport?.notes.contains(where: { $0.contains("出品車") && $0.contains("成約") }) == true)
    }

    func testDelegatedManagerAdjustsStoreOperations() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        var store = game.stores[0]
        XCTAssertTrue(game.hireManager(for: store.id))
        store = game.stores[0]
        store.delegateStaff = true
        store.delegatePricing = true
        store.delegateMarketing = true
        store.delegateService = true
        let advertising = store.advertising
        let service = store.serviceAllocation
        game.updateStore(store)

        game.advanceWeek()

        XCTAssertTrue(game.lastReport?.notes.contains(where: { $0.contains("店長") }) == true)
        XCTAssertTrue(game.stores[0].advertising != advertising || game.stores[0].serviceAllocation != service)
    }

    func testStoreCanBeRenovated() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let store = game.stores[0]
        game.cash = 10_000
        let cash = game.cash

        XCTAssertTrue(game.renovateStore(store.id, to: .roadside))
        XCTAssertEqual(game.stores[0].type, .standard)
        XCTAssertEqual(game.stores[0].pendingType, .roadside)
        XCTAssertEqual(game.stores[0].renovationMonthsRemaining, 2)
        XCTAssertLessThan(game.cash, cash)

        game.advanceWeek()
        XCTAssertEqual(game.stores[0].type, .standard)
        XCTAssertEqual(game.stores[0].renovationMonthsRemaining, 1)
        game.advanceWeek()
        XCTAssertEqual(game.stores[0].type, .roadside)
        XCTAssertNil(game.stores[0].pendingType)
    }

    func testMapBuildingStateFollowsBuildRenovationAndClosure() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let plot = game.plots.first(where: {
            if case .available = $0.occupant { return $0.development == nil }
            return false
        })!

        XCTAssertTrue(game.buildStore(
            on: plot,
            type: .small,
            mode: .lease,
            focus: .value,
            concept: .keiLocal,
            loanAmount: 100_000
        ))
        let newStore = game.store(at: plot.id)!
        XCTAssertEqual(newStore.type.mapAssetName, "StoreSmall")
        XCTAssertEqual(newStore.openingMonthsRemaining, 1)

        game.advanceWeek()
        XCTAssertNil(game.store(at: plot.id)?.openingMonthsRemaining)

        XCTAssertTrue(game.renovateStore(newStore.id, to: .roadside))
        XCTAssertEqual(game.store(at: plot.id)?.type.mapAssetName, "StoreSmall")
        XCTAssertEqual(game.store(at: plot.id)?.pendingType?.mapAssetName, "StoreRoadside")
        game.advanceWeek()
        game.advanceWeek()
        XCTAssertEqual(game.store(at: plot.id)?.type.mapAssetName, "StoreRoadside")

        game.closeStore(newStore.id)
        XCTAssertNil(game.store(at: plot.id))
        if case .available = game.plot(id: plot.id)?.occupant {
            // The dynamic map layer now has no building to draw on this lot.
        } else {
            XCTFail("Closed store plot should become available")
        }
    }

    func testNationalExpansionCreatesRegionalNetwork() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.companyValue = 100_000
        game.cash = 100_000

        XCTAssertEqual(game.nationalCities.count, 6)
        XCTAssertTrue(game.establishRegionalOffice(in: "shinonome"))
        XCTAssertTrue(game.openFranchise(in: "shinonome"))
        XCTAssertTrue(game.acquireLocalDealer(in: "shinonome"))
        XCTAssertTrue(game.runNationalCampaign())

        let operation = game.regionalOperation(for: "shinonome")
        XCTAssertEqual(operation?.networkStores, 2)
        XCTAssertGreaterThan(game.nationalBrandStrength, 0.48)
    }

    func testIntercityShipmentArrivesAtRegionalOffice() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.companyValue = 100_000
        game.cash = 100_000
        XCTAssertTrue(game.establishRegionalOffice(in: "shinonome"))
        let store = game.stores[0]
        let category = store.inventory[0].category
        let before = store.inventoryCount

        XCTAssertTrue(game.shipInventoryToRegion(cityID: "shinonome", from: store.id, category: category, count: 1))
        XCTAssertEqual(game.stores[0].inventoryCount, before - 1)
        XCTAssertEqual(game.intercityShipments.count, 1)

        game.advanceWeek()

        XCTAssertTrue(game.intercityShipments.isEmpty)
        XCTAssertEqual(game.regionalOperation(for: "shinonome")?.inventoryCount, 1)
    }

    func testWeekAdvancesCalendarMonthAfterFourTurns() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        XCTAssertEqual(game.month, 4)
        XCTAssertEqual(game.weekOfMonth, 1)

        for _ in 0..<3 { game.advanceWeek() }
        XCTAssertEqual(game.month, 4)
        XCTAssertEqual(game.weekOfMonth, 4)

        game.advanceWeek()
        XCTAssertEqual(game.month, 5)
        XCTAssertEqual(game.weekOfMonth, 1)
    }

    func testOwnerMustSellManuallyUntilManagerIsHired() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        let store = game.stores[0]
        let category = store.inventory[0].category
        let inventoryBefore = store.inventoryCount
        let preview = game.saleNegotiationPreview(storeID: store.id, category: category, strategy: .smallDiscount)
        XCTAssertNotNil(preview)
        XCTAssertLessThan(preview?.closeChance ?? 1, 1)
        let result = game.negotiateManualSale(storeID: store.id, category: category, strategy: .smallDiscount)
        XCTAssertNotNil(result)
        XCTAssertEqual(game.stores[0].manualNegotiationsThisWeek, 1)
        XCTAssertEqual(game.stores[0].inventoryCount, result?.succeeded == true ? inventoryBefore - 1 : inventoryBefore)

        XCTAssertTrue(game.hireManager(for: store.id))
        var managedStore = game.stores[0]
        managedStore.delegatePricing = true
        game.updateStore(managedStore)
        XCTAssertFalse(game.canSellManually(storeID: store.id))
    }

    func testDiscountImprovesButNeverGuaranteesCustomerPurchase() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        let store = game.stores[0]
        let category = store.inventory[0].category

        let hold = game.saleNegotiationPreview(storeID: store.id, category: category, strategy: .holdPrice)
        let discount = game.saleNegotiationPreview(storeID: store.id, category: category, strategy: .closeDeal)
        XCTAssertNotNil(hold)
        XCTAssertNotNil(discount)
        XCTAssertGreaterThan(discount?.closeChance ?? 0, hold?.closeChance ?? 1)
        XCTAssertLessThan(discount?.closeChance ?? 1, 1)
        XCTAssertLessThan(discount?.price ?? 0, hold?.price ?? 0)
    }

    func testBulkPurchaseCreatesSeparateVehicleRecords() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        let store = game.stores[0]
        let existingIDs = Set(store.inventory.map(\.id))

        XCTAssertTrue(game.buyInventory(category: .kei, count: 3, storeID: store.id))

        let added = game.stores[0].inventory.filter { !existingIDs.contains($0.id) }
        XCTAssertEqual(added.count, 3)
        XCTAssertEqual(Set(added.map(\.id)).count, 3)
        XCTAssertTrue(added.allSatisfy { $0.count == 1 })
    }

    func testOneRetailNegotiationCanSellAtMostOneSpecificVehicle() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        let store = game.stores[0]
        let target = store.inventory[0]
        let otherIDs = Set(store.inventory.dropFirst().map(\.id))
        let before = store.inventoryCount

        let result = game.negotiateManualSale(storeID: store.id, inventoryID: target.id, strategy: .closeDeal)

        XCTAssertNotNil(result)
        XCTAssertEqual(game.stores[0].inventoryCount, before - (result?.succeeded == true ? 1 : 0))
        XCTAssertTrue(otherIDs.isSubset(of: Set(game.stores[0].inventory.map(\.id))))
        if result?.succeeded == true {
            XCTAssertFalse(game.stores[0].inventory.contains { $0.id == target.id })
        }
    }

    func testEveryDistrictHasCompetitionAndNewStoreDividesFixedDemand() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        for kind in DistrictKind.allCases {
            XCTAssertTrue(game.competitors.contains { competitor in
                competitor.plotIDs.contains { game.plot(id: $0)?.district == kind }
            })
        }

        game.cash = 100_000
        let originalStore = game.stores[0]
        let district = game.plot(id: originalStore.plotID)!.district
        let originalShare = game.marketShare(for: originalStore)
        let buyerPool = game.weeklyBuyerPool(in: district)
        let secondPlot = game.plots.first { plot in
            guard plot.district == district, plot.development == nil else { return false }
            if case .available = plot.occupant { return true }
            return false
        }!
        XCTAssertTrue(game.buildStore(on: secondPlot, type: .small, mode: .lease, focus: .value, concept: .custom, loanAmount: 0))
        XCTAssertEqual(game.store(at: secondPlot.id)?.inventoryCount, 0)

        XCTAssertEqual(game.weeklyBuyerPool(in: district), buyerPool)
        let playerShare = game.stores
            .filter { game.plot(id: $0.plotID)?.district == district }
            .reduce(0.0) { $0 + game.marketShare(for: $1) }
        let rivalShare = game.competitors.reduce(0.0) { $0 + game.competitorMarketShare($1, in: district) }
        XCTAssertEqual(playerShare + rivalShare, 1, accuracy: 0.0001)

        game.advanceWeek()
        XCTAssertLessThan(game.marketShare(for: game.stores[0]), originalShare)
        for store in game.stores where game.plot(id: store.plotID)?.district == district {
            XCTAssertTrue(game.hireManager(for: store.id))
            var delegated = game.stores.first(where: { $0.id == store.id })!
            delegated.delegatePricing = true
            game.updateStore(delegated)
        }
        let availableBuyers = game.weeklyBuyerPool(in: district)
        game.advanceWeek()
        let districtSales = game.stores
            .filter { game.plot(id: $0.plotID)?.district == district }
            .reduce(0) { $0 + $1.lastSales }
        XCTAssertLessThanOrEqual(districtSales, availableBuyers)
    }

    func testOneWorkerHasSevenSharedBuyAndSellOpportunities() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        game.cash = 100_000
        let storeID = game.stores[0].id
        XCTAssertEqual(game.stores[0].staff, 1)
        XCTAssertEqual(game.weeklyOpportunityCapacity(storeID: storeID), 7)
        XCTAssertTrue(game.buyInventory(category: .kei, count: 6, storeID: storeID))

        let purchaseCase = game.purchaseCases.first!
        switch game.negotiatePurchaseCase(purchaseCase.id, offerPercent: 100) {
        case .unavailable: XCTFail("The first purchase negotiation should use one opportunity")
        case .purchased, .rejected: break
        }
        XCTAssertEqual(game.stores[0].purchaseNegotiationsThisWeek, 1)

        game.buyerLeads = (0..<7).map { offset in
            BuyerLead(
                id: UUID(), storeID: storeID, desiredCategory: .kei,
                budget: 200 + offset, minimumQuality: 0.5,
                priceSensitivity: 1, generatedTurn: game.turn
            )
        }
        for _ in 0..<6 {
            let lead = game.buyerLeads.first!
            let inventory = game.stores[0].inventory.first!
            XCTAssertNotNil(game.negotiateManualSale(
                storeID: storeID,
                buyerLeadID: lead.id,
                inventoryID: inventory.id,
                strategy: .smallDiscount
            ))
        }

        XCTAssertEqual(game.stores[0].usedOpportunitiesThisWeek, 7)
        XCTAssertEqual(game.remainingWeeklyOpportunities(storeID: storeID), 0)
        let extraLead = game.buyerLeads.first!
        let extraInventory = game.stores[0].inventory.first!
        XCTAssertNil(game.negotiateManualSale(
            storeID: storeID,
            buyerLeadID: extraLead.id,
            inventoryID: extraInventory.id,
            strategy: .closeDeal
        ))
    }

    func testThreeWorkersCannotCreateCustomersWhenOnlyOneArrives() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        let storeID = game.stores[0].id
        game.stores[0].staff = 3
        game.buyerLeads = [
            BuyerLead(
                id: UUID(), storeID: storeID,
                desiredCategory: game.stores[0].inventory[0].category,
                budget: 300, minimumQuality: 0.5,
                priceSensitivity: 1, generatedTurn: game.turn
            )
        ]

        let lead = game.buyerLeads[0]
        let inventory = game.stores[0].inventory[0]
        XCTAssertNotNil(game.negotiateManualSale(
            storeID: storeID,
            buyerLeadID: lead.id,
            inventoryID: inventory.id,
            strategy: .smallDiscount
        ))
        XCTAssertEqual(game.weeklyOpportunityCapacity(storeID: storeID), 21)
        XCTAssertEqual(game.remainingWeeklyOpportunities(storeID: storeID), 20)
        XCTAssertFalse(game.canSellManually(storeID: storeID))
    }

    func testDelegatingPricingPreventsOwnerFromHandlingTheSameCustomers() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let purchaseCase = game.purchaseCases.first!

        XCTAssertTrue(game.hireManager(for: storeID))
        var store = game.stores[0]
        store.delegatePricing = true
        game.updateStore(store)

        XCTAssertFalse(game.canNegotiatePurchaseCase(purchaseCase.id))
        if case .unavailable = game.negotiatePurchaseCase(purchaseCase.id, offerPercent: 100) {
            // The manager owns delegated customer negotiations until the week is processed.
        } else {
            XCTFail("The owner should not handle a purchase case delegated to the manager")
        }
        XCTAssertFalse(game.canSellManually(storeID: storeID))
    }

    func testAdvertisingAndReputationRaiseShareWithoutCreatingRegionalDemand() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        var store = game.stores[0]
        let district = game.plot(id: store.plotID)!.district
        let regionalDemand = game.weeklyBuyerPool(in: district)
        let originalShare = game.marketShare(for: store)

        store.advertising = 500
        store.reputation = 1.1
        game.updateStore(store)

        XCTAssertGreaterThan(game.marketShare(for: game.stores[0]), originalShare)
        XCTAssertEqual(game.weeklyBuyerPool(in: district), regionalDemand)
    }

    func testNormalWeeksCanProduceZeroOrOneVisitorAtAStore() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        var observedQuietWeek = false

        for _ in 0..<40 {
            game.advanceWeek()
            let store = game.stores[0]
            if store.buyerArrivalsThisWeek + store.sellerArrivalsThisWeek <= 1 {
                observedQuietWeek = true
                break
            }
        }

        XCTAssertTrue(observedQuietWeek)
    }

    func testStoreTrafficLevelVisuallyTracksWeeklyVisitors() {
        XCTAssertEqual(StoreTrafficLevel.from(visitorCount: 0), .quiet)
        XCTAssertEqual(StoreTrafficLevel.from(visitorCount: 1), .light)
        XCTAssertEqual(StoreTrafficLevel.from(visitorCount: 4), .steady)
        XCTAssertEqual(StoreTrafficLevel.from(visitorCount: 8), .busy)
        XCTAssertEqual(StoreTrafficLevel.from(visitorCount: 12), .packed)
    }

    func testInventoryVehiclesReceiveCatalogNamesAndRetainBusinessDetails() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)

        for vehicle in game.stores[0].inventory {
            let model = VehicleCatalog.entry(id: vehicle.modelID)
            XCTAssertNotNil(model)
            XCTAssertEqual(model?.category, vehicle.category)
            XCTAssertFalse(vehicle.vehicleName.contains("スタンダード"))
            XCTAssertGreaterThan(vehicle.averageCost, 0)
            XCTAssertGreaterThan(vehicle.quality, 0)
        }
    }

    func testVehicleCatalogAddsNewModelsAsWeeksAdvance() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let initialCount = game.availableVehicleCatalog.count
        XCTAssertFalse(game.availableVehicleCatalog.contains { $0.id == "aoba-basicneo" })

        for _ in 0..<8 { game.advanceWeek() }

        XCTAssertGreaterThan(game.availableVehicleCatalog.count, initialCount)
        XCTAssertTrue(game.availableVehicleCatalog.contains { $0.id == "aoba-basicneo" })
        XCTAssertTrue(game.cityEvents.contains { $0.title == "新型車が発売" && $0.detail.contains("BASIC NEO") })
    }

    func testCatalogMarketInformationChangesReferencePricesByRegion() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let model = VehicleCatalog.all.first(where: { $0.category == .premium })!

        let downtown = game.catalogRetailPrice(for: model, in: .downtown)
        let industrial = game.catalogRetailPrice(for: model, in: .industrial)

        XCTAssertGreaterThan(downtown, industrial)
        XCTAssertGreaterThan(game.catalogWholesalePrice(for: model, in: .downtown), 0)
    }

    func testVehicleSellerCanRejectDealerLowballOffer() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let item = game.purchaseCases[0]
        let fullOffer = game.purchaseNegotiationPreview(item.id, offerPercent: 100)
        let lowOffer = game.purchaseNegotiationPreview(item.id, offerPercent: 88)

        XCTAssertGreaterThan(fullOffer?.closeChance ?? 0, lowOffer?.closeChance ?? 1)
        XCTAssertLessThan(fullOffer?.closeChance ?? 1, 1)
        XCTAssertLessThan(lowOffer?.price ?? 0, fullOffer?.price ?? 0)
    }

    func testNewGameUsesConstrainedStartingCapital() {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()

        XCTAssertEqual(game.cash, 6_500)
        XCTAssertEqual(game.debt, 3_000)
        XCTAssertEqual(game.weekOfMonth, 1)
        XCTAssertLessThan(game.cash, 10_000)
    }

    func testReturnToTitlePreservesSaveAndLoadRestoresIt() {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        game.cash = 6_123

        game.returnToTitle()
        XCTAssertFalse(game.hasStarted)
        XCTAssertTrue(game.hasSaveData)

        game.cash = 1
        game.loadGame()
        XCTAssertTrue(game.hasStarted)
        XCTAssertEqual(game.cash, 6_123)
    }
}
