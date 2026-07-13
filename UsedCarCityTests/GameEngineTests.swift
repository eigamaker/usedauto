import XCTest
@testable import UsedCarCity

@MainActor
final class GameEngineTests: XCTestCase {
    func testNewGameCreatesSixDistrictsAndThirtySixPlots() {
        let game = GameEngine()
        game.resetGame()
        XCTAssertEqual(game.districts.count, 6)
        XCTAssertEqual(game.plots.count, 36)
    }

    func testStartupCreatesPlayableStore() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        XCTAssertTrue(game.hasStarted)
        XCTAssertEqual(game.stores.count, 1)
        XCTAssertGreaterThan(game.totalInventory, 0)
    }

    func testAdvancingMonthCreatesReport() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .discount)
        game.advanceMonth()
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
        game.start(plan: .family)
        let store = game.stores[0]
        let beforeInventory = store.inventoryCount
        let beforeCash = game.cash
        let item = game.purchaseCases.first!

        game.inspectPurchaseCase(item.id)
        XCTAssertEqual(game.purchaseCases.first(where: { $0.id == item.id })?.appraisalAccuracy, 96)
        XCTAssertTrue(game.acceptPurchaseCase(item.id))
        XCTAssertEqual(game.purchaseCases.count, 2)
        XCTAssertEqual(game.stores[0].inventoryCount, beforeInventory + 1)
        XCTAssertLessThan(game.cash, beforeCash)
    }

    func testCityEconomyChangesWhenMonthAdvances() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        let population = game.districts.first(where: { $0.kind == .emerging })!.population
        let landPrice = game.plots[14].price

        game.advanceMonth()

        XCTAssertNotEqual(game.districts.first(where: { $0.kind == .emerging })!.population, population)
        XCTAssertNotEqual(game.plots[14].price, landPrice)
        XCTAssertNotEqual(game.plots[14].lastPriceChange, 0)
        XCTAssertFalse(game.cityEvents.isEmpty)
    }

    func testDevelopmentCompletesAndBoostsDistrict() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        let population = game.districts.first(where: { $0.kind == .emerging })!.population
        XCTAssertNotNil(game.plots[14].development)

        for _ in 0..<5 { game.advanceMonth() }

        XCTAssertNil(game.plots[14].development)
        XCTAssertGreaterThan(game.districts.first(where: { $0.kind == .emerging })!.population, population)
        XCTAssertTrue(game.cityEvents.contains { $0.kind == .development && $0.plotID == 14 && $0.title.contains("完成") })
    }

    func testAuctionBidCreatesInboundShipmentAtMonthEnd() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        let listing = game.auctionListings.first!
        let store = game.stores[0]
        let cash = game.cash

        XCTAssertTrue(game.reserveBid(listingID: listing.id, storeID: store.id, maxPrice: listing.marketPrice * 2))
        game.advanceMonth()

        XCTAssertFalse(game.bidReservations.contains { $0.listingID == listing.id })
        XCTAssertTrue(game.inboundShipments.contains { $0.source == .auction && $0.category == listing.category })
        XCTAssertLessThan(game.cash, cash)
    }

    func testDealerTradeArrivesAfterOneMonth() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        let store = game.stores[0]

        XCTAssertTrue(game.orderDealerTrade(category: .compact, count: 3, storeID: store.id))
        XCTAssertEqual(game.incomingCount(for: store.id), 3)
        game.advanceMonth()

        XCTAssertEqual(game.incomingCount(for: store.id), 0)
        XCTAssertTrue(game.lastReport?.notes.contains(where: { $0.contains("業者間取引") && $0.contains("到着") }) == true)
    }

    func testInventoryCanBeConsignedToAuction() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        let store = game.stores[0]
        let category = store.inventory[0].category
        let inventory = store.inventoryCount

        XCTAssertTrue(game.consignInventory(storeID: store.id, category: category, count: 1, venue: .east))
        XCTAssertEqual(game.stores[0].inventoryCount, inventory - 1)
        game.advanceMonth()

        XCTAssertTrue(game.auctionConsignments.isEmpty)
        XCTAssertTrue(game.lastReport?.notes.contains(where: { $0.contains("出品車") && $0.contains("成約") }) == true)
    }

    func testDelegatedManagerAdjustsStoreOperations() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        var store = game.stores[0]
        store.delegateStaff = true
        store.delegatePricing = true
        store.delegateMarketing = true
        store.delegateService = true
        let advertising = store.advertising
        let service = store.serviceAllocation
        game.updateStore(store)

        game.advanceMonth()

        XCTAssertTrue(game.lastReport?.notes.contains(where: { $0.contains("店長") }) == true)
        XCTAssertTrue(game.stores[0].advertising != advertising || game.stores[0].serviceAllocation != service)
    }

    func testStoreCanBeRenovated() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        let store = game.stores[0]
        let cash = game.cash

        XCTAssertTrue(game.renovateStore(store.id, to: .roadside))
        XCTAssertEqual(game.stores[0].type, .standard)
        XCTAssertEqual(game.stores[0].pendingType, .roadside)
        XCTAssertEqual(game.stores[0].renovationMonthsRemaining, 2)
        XCTAssertLessThan(game.cash, cash)

        game.advanceMonth()
        XCTAssertEqual(game.stores[0].type, .standard)
        XCTAssertEqual(game.stores[0].renovationMonthsRemaining, 1)
        game.advanceMonth()
        XCTAssertEqual(game.stores[0].type, .roadside)
        XCTAssertNil(game.stores[0].pendingType)
    }

    func testMapBuildingStateFollowsBuildRenovationAndClosure() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
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

        game.advanceMonth()
        XCTAssertNil(game.store(at: plot.id)?.openingMonthsRemaining)

        XCTAssertTrue(game.renovateStore(newStore.id, to: .roadside))
        XCTAssertEqual(game.store(at: plot.id)?.type.mapAssetName, "StoreSmall")
        XCTAssertEqual(game.store(at: plot.id)?.pendingType?.mapAssetName, "StoreRoadside")
        game.advanceMonth()
        game.advanceMonth()
        XCTAssertEqual(game.store(at: plot.id)?.type.mapAssetName, "StoreRoadside")

        game.closeStore(newStore.id)
        XCTAssertNil(game.store(at: plot.id))
        if case .available = game.plot(id: plot.id)?.occupant {
            // The dynamic map layer now has no building to draw on this lot.
        } else {
            XCTFail("Closed store plot should become available")
        }
    }

    func testOlderStoreSaveDecodesWithoutConstructionFields() throws {
        let store = Store(
            name: "互換性テスト店",
            plotID: 1,
            type: .standard,
            acquisition: .lease,
            focus: .family,
            inventory: []
        )
        let encoded = try JSONEncoder().encode(store)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "openingMonthsRemaining")
        object.removeValue(forKey: "pendingType")
        object.removeValue(forKey: "renovationMonthsRemaining")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(Store.self, from: legacyData)
        XCTAssertTrue(decoded.isOperational)
        XCTAssertFalse(decoded.isRenovating)
    }

    func testNationalExpansionCreatesRegionalNetwork() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
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
        game.start(plan: .family)
        game.companyValue = 100_000
        game.cash = 100_000
        XCTAssertTrue(game.establishRegionalOffice(in: "shinonome"))
        let store = game.stores[0]
        let category = store.inventory[0].category
        let before = store.inventoryCount

        XCTAssertTrue(game.shipInventoryToRegion(cityID: "shinonome", from: store.id, category: category, count: 1))
        XCTAssertEqual(game.stores[0].inventoryCount, before - 1)
        XCTAssertEqual(game.intercityShipments.count, 1)

        game.advanceMonth()

        XCTAssertTrue(game.intercityShipments.isEmpty)
        XCTAssertEqual(game.regionalOperation(for: "shinonome")?.inventoryCount, 1)
    }
}
