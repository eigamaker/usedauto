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
}
