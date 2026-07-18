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

    func testNewGameCreatesSixExpandedDistrictsAndOneHundredEightyPlots() {
        let game = GameEngine()
        game.resetGame()
        XCTAssertEqual(game.districts.count, 6)
        XCTAssertEqual(game.plots.count, 180)
        for district in DistrictKind.allCases {
            XCTAssertEqual(game.plots.filter { $0.district == district }.count, CityMapLayout.plotsPerDistrict)
        }
    }

    func testAllCityPlotsAreUniqueGridAlignedCells() {
        XCTAssertEqual(Set(CityMapLayout.plotPositions.map { "\($0.x),\($0.y)" }).count, 180)
        for point in CityMapLayout.plotPositions {
            let column = (point.x - CityMapLayout.gridOrigin.x) / CityMapLayout.columnSpacing
            let row = (point.y - CityMapLayout.gridOrigin.y) / CityMapLayout.rowSpacing
            XCTAssertEqual(column, column.rounded(), accuracy: 0.0001)
            XCTAssertEqual(row, row.rounded(), accuracy: 0.0001)
            XCTAssertTrue((0...1).contains(point.x))
            XCTAssertTrue((0...1).contains(point.y))
        }
    }

    func testCityBlueprintKeepsReusablePlacementsInsideWorldBounds() {
        let blueprint = CityMapLayout.blueprint
        XCTAssertEqual(blueprint.grid.columnCount, 30)
        XCTAssertEqual(blueprint.grid.rowCount, 20)
        XCTAssertEqual(blueprint.districts.reduce(0) { $0 + $1.columns * $1.rows }, 180)
        XCTAssertTrue(blueprint.majorRoads.allSatisfy { (0...1).contains($0.position) })
        XCTAssertTrue(blueprint.trees.allSatisfy { (0...1).contains($0.point.x) && (0...1).contains($0.point.y) })
    }

    func testEveryParcelStructureUsesAReusableAssetThatFitsItsGridCell() {
        let game = GameEngine()
        game.resetGame()

        for plot in game.plots where plot.structure != .vacant {
            let lot = CityMapLayout.lotRect(for: plot).insetBy(dx: 0.007, dy: 0.006)
            let asset = MapAssetLibrary.parcelBuilding(for: plot, in: lot)
            XCTAssertNotNil(asset)
            XCTAssertTrue(lot.contains(asset!.rect))
        }

        let combinedLot = CityMapLayout.combinedLotRect(for: [0, 1, 2]).insetBy(dx: 0.004, dy: 0.004)
        let dealership = MapAssetLibrary.dealership(in: combinedLot, type: .roadside, color: .orange)
        XCTAssertTrue(combinedLot.contains(dealership.rect))
    }

    func testEveryVisibleParcelAndStoreTypeHasAnIsometricRasterSprite() {
        let game = GameEngine()
        game.resetGame()

        for plot in game.plots where plot.structure != .vacant {
            let sprite = MapAssetLibrary.parcelSprite(for: plot)
            XCTAssertNotNil(sprite, "Missing raster sprite for \(plot.structure)")
            XCTAssertGreaterThan(sprite!.pixelSize.width, 0)
            XCTAssertGreaterThan(sprite!.pixelSize.height, 0)
            XCTAssertTrue((0...1).contains(sprite!.groundAnchorY))
        }

        for type in StoreType.allCases {
            let sprite = MapAssetLibrary.storeSprite(for: type)
            XCTAssertFalse(sprite.imageName.isEmpty)
            XCTAssertGreaterThan(sprite.pixelSize.width, sprite.pixelSize.height)
            XCTAssertGreaterThan(sprite.widthScale, 0)
        }
    }

    func testCityMapLODTransitionsAllRenderingLayersTogether() {
        XCTAssertEqual(CityMapLevelOfDetail(cameraScale: 1.0), .overview)
        XCTAssertEqual(CityMapLevelOfDetail(cameraScale: 1.35), .district)
        XCTAssertEqual(CityMapLevelOfDetail(cameraScale: 2.15), .street)
        XCTAssertFalse(CityMapLevelOfDetail.overview.usesHighResolutionTiles)
        XCTAssertTrue(CityMapLevelOfDetail.district.usesHighResolutionTiles)
        XCTAssertFalse(CityMapLevelOfDetail.district.showsParcelSprites)
        XCTAssertTrue(CityMapLevelOfDetail.street.showsParcelSprites)
        XCTAssertTrue(CityMapLevelOfDetail.street.showsMinorRoads)
    }

    func testHighResolutionCityMosaicHasTwelveGaplessTiles() {
        XCTAssertEqual(CityMapRasterTile.all.count, 12)
        XCTAssertEqual(Set(CityMapRasterTile.all.map(\.imageName)).count, 12)
        XCTAssertEqual(CityMapRasterTile.mosaicPixelSize, CGSize(width: 7_240, height: 5_430))

        let mapRect = CGRect(x: 20, y: 40, width: 800, height: 600)
        let frames = CityMapRasterTile.all.map { $0.frame(in: mapRect) }
        XCTAssertEqual(frames.map(\.width).min(), 200)
        XCTAssertEqual(frames.map(\.height).min(), 200)
        XCTAssertEqual(frames.map(\.minX).min(), mapRect.minX)
        XCTAssertEqual(frames.map(\.minY).min(), mapRect.minY)
        XCTAssertEqual(frames.map(\.maxX).max(), mapRect.maxX)
        XCTAssertEqual(frames.map(\.maxY).max(), mapRect.maxY)
    }

    func testEveryCityCellStartsWithAPurchasableGridBuilding() {
        let game = GameEngine()
        game.resetGame()

        XCTAssertEqual(game.plots.count, 180)
        XCTAssertTrue(game.plots.allSatisfy { $0.structure != .vacant })
        XCTAssertTrue(game.plots.allSatisfy { $0.isForSale && $0.isForLease })
    }

    func testStandardStoreCombinesTwoCellsAndDemolishesBothBuildings() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        let plot = game.recommendedFoundingPlot!
        let footprint = game.footprintPlots(startingAt: plot, type: .standard)

        XCTAssertEqual(footprint.count, 2)
        XCTAssertTrue(footprint.allSatisfy { $0.structure != .vacant })
        game.selectFoundingPlot(plot.id)
        XCTAssertTrue(game.buildStore(on: plot, type: .standard, mode: .lease, focus: .family, concept: .family, loanAmount: 0))

        let store = game.stores[0]
        XCTAssertEqual(store.plotIDs.count, 2)
        XCTAssertEqual(Set(store.plotIDs), Set(footprint.map(\.id)))
        XCTAssertTrue(store.plotIDs.allSatisfy { game.plot(id: $0)?.structure == .vacant })
    }

    func testMultiCellBreakEvenIncludesEveryOccupiedPlot() {
        let game = GameEngine()
        game.resetGame()
        game.start(plan: .family)
        let plot = game.recommendedFoundingPlot!
        let footprint = game.footprintPlots(startingAt: plot, type: .standard)
        XCTAssertEqual(footprint.count, StoreType.standard.requiredGridCells)

        let rent = footprint.reduce(0) { $0 + $1.monthlyRent }
        let expectedLease = max(3, Int(ceil(Double(StoreType.standard.monthlyFixedCost + rent + 80) / 32.0)))
        XCTAssertEqual(game.breakEvenSales(for: plot, type: .standard, mode: .lease), expectedLease)

        let landValue = footprint.reduce(0) { $0 + $1.price }
        let expectedPurchase = max(3, Int(ceil(Double(StoreType.standard.monthlyFixedCost + max(12, landValue / 360) + 80) / 32.0)))
        XCTAssertEqual(game.breakEvenSales(for: plot, type: .standard, mode: .purchase), expectedPurchase)
    }

    func testRoadsideStoreUsesThreeContiguousGridCells() {
        let game = GameEngine()
        game.resetGame()
        game.cash = 100_000
        let plot = game.plots.first(where: {
            if case .available = $0.occupant {
                return game.footprintPlots(startingAt: $0, type: .roadside).count == 3
            }
            return false
        })!

        XCTAssertTrue(game.buildStore(on: plot, type: .roadside, mode: .purchase, focus: .business, concept: .business, loanAmount: 0))
        XCTAssertEqual(game.stores[0].plotIDs.count, 3)
        let coordinates = game.stores[0].plotIDs.compactMap(CityMapLayout.gridCoordinate(for:))
        XCTAssertTrue(Set(coordinates.map { $0.row }).count == 1 || Set(coordinates.map { $0.column }).count == 1)
    }

    func testFacilitiesUseGridCellsSeparateFromStorePlots() {
        let plotPoints = Set(CityMapLayout.plotPositions.map { "\($0.x),\($0.y)" })
        let facilityPoints = MapFacility.allCases.map(\.worldPoint)
        XCTAssertEqual(Set(facilityPoints.map { "\($0.x),\($0.y)" }).count, MapFacility.allCases.count)
        for point in facilityPoints {
            XCTAssertFalse(plotPoints.contains("\(point.x),\(point.y)"))
            let column = (point.x - CityMapLayout.gridOrigin.x) / CityMapLayout.columnSpacing
            let row = (point.y - CityMapLayout.gridOrigin.y) / CityMapLayout.rowSpacing
            XCTAssertEqual(column, column.rounded(), accuracy: 0.0001)
            XCTAssertEqual(row, row.rounded(), accuracy: 0.0001)
        }
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
        let developmentPlotID = game.plots.first(where: { $0.development != nil })!.id
        XCTAssertNotNil(game.plot(id: developmentPlotID)?.development)

        for _ in 0..<5 { game.advanceWeek() }

        XCTAssertNil(game.plot(id: developmentPlotID)?.development)
        XCTAssertGreaterThan(game.districts.first(where: { $0.kind == .emerging })!.population, population)
        XCTAssertTrue(game.cityEvents.contains { $0.kind == .development && $0.plotID == developmentPlotID && $0.title.contains("完成") })
    }

    func testAuctionBidResultIsKnownNextWeekAndKeepsExactVehicleModel() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let listing = game.auctionListings.first!
        let store = game.stores[0]
        let cash = game.cash

        XCTAssertTrue(game.auctionListings.allSatisfy {
            VehicleCatalog.entry(id: $0.modelID)?.category == $0.category
        })
        XCTAssertEqual(VehicleCatalog.entry(id: listing.modelID)?.category, listing.category)
        XCTAssertTrue(game.reserveBid(listingID: listing.id, storeID: store.id, maxPrice: listing.marketPrice * 2))
        XCTAssertEqual(game.bidReservations.first(where: { $0.listingID == listing.id })?.resultTurn, game.turn + 1)
        XCTAssertFalse(game.auctionBidResults.contains { $0.listingID == listing.id })

        game.advanceWeek()

        XCTAssertFalse(game.bidReservations.contains { $0.listingID == listing.id })
        let result = game.auctionBidResults.first(where: { $0.listingID == listing.id })
        XCTAssertEqual(result?.status, .won)
        XCTAssertEqual(result?.resolvedTurn, game.turn)
        XCTAssertEqual(result?.modelID, listing.modelID)
        XCTAssertTrue(game.inboundShipments.contains { $0.source == .auction && $0.modelID == listing.modelID })
        XCTAssertTrue(game.lastReport?.notes.contains { $0.contains(listing.vehicleName) } == true)
        XCTAssertLessThan(game.cash, cash)

        game.advanceWeek()

        XCTAssertTrue(game.stores[0].inventory.contains {
            $0.modelID == listing.modelID && $0.modelYear == listing.modelYear && $0.mileage == listing.mileage
        })
    }

    func testAuctionBidReportsInsufficientFundsNextWeek() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let listing = game.auctionListings.first!
        let store = game.stores[0]

        XCTAssertTrue(game.reserveBid(listingID: listing.id, storeID: store.id, maxPrice: listing.marketPrice * 2))
        game.cash = 0
        game.advanceWeek()

        XCTAssertEqual(game.auctionBidResults.first(where: { $0.listingID == listing.id })?.status, .insufficientFunds)
        XCTAssertFalse(game.inboundShipments.contains { $0.modelID == listing.modelID })
        XCTAssertTrue(game.lastReport?.notes.contains { $0.contains(listing.vehicleName) && $0.contains("資金") } == true)
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

    func testBusinessDistrictSeparatesVehicleSupplyFromCustomerDemand() {
        let game = GameEngine()
        game.resetGame()

        XCTAssertGreaterThan(game.vehicleDemand(.commercial, in: .industrial), 1.5)
        XCTAssertGreaterThan(game.vehicleSupply(.commercial, in: .industrial), game.vehicleSupply(.commercial, in: .suburb))
        XCTAssertGreaterThan(game.vehicleSupply(.pickup, in: .highway), game.vehicleSupply(.pickup, in: .downtown))
        XCTAssertNotEqual(game.vehicleDemand(.premium, in: .downtown), game.vehicleSupply(.premium, in: .downtown))
    }

    func testPickupCanAlwaysBeSourcedAtARegionalScarcityPremium() {
        let businessGame = GameEngine()
        businessGame.resetGame()
        startPlayableGame(businessGame, plan: .business)
        let businessStore = businessGame.stores[0]
        let localQuote = businessGame.dealerTradeQuote(category: .pickup, count: 3, storeID: businessStore.id)

        let premiumGame = GameEngine()
        premiumGame.resetGame()
        startPlayableGame(premiumGame, plan: .quality)
        let premiumStore = premiumGame.stores[0]
        let remoteQuote = premiumGame.dealerTradeQuote(category: .pickup, count: 3, storeID: premiumStore.id)

        XCTAssertNotNil(localQuote)
        XCTAssertNotNil(remoteQuote)
        XCTAssertLessThan(localQuote?.unitCost ?? .max, remoteQuote?.unitCost ?? .min)
        XCTAssertLessThanOrEqual(localQuote?.weeks ?? .max, remoteQuote?.weeks ?? .min)
    }

    func testBusinessConceptUnlocksBulkFleetPickupPurchase() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .business)
        game.cash = 100_000
        let store = game.stores[0]
        let quote = game.fleetPurchaseQuote(category: .pickup, count: 5, storeID: store.id)

        XCTAssertNotNil(quote)
        XCTAssertEqual(quote?.count, 5)
        XCTAssertTrue(game.orderFleetPurchase(category: .pickup, count: 5, storeID: store.id))
        XCTAssertEqual(game.incomingCount(for: store.id), 5)
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
        store.delegateProcurement = true
        store.delegateMarketing = true
        store.delegateService = true
        let advertising = store.advertising
        let service = store.serviceAllocation
        game.updateStore(store)

        game.advanceWeek()

        XCTAssertTrue(game.lastReport?.notes.contains(where: { $0.contains("店長") }) == true)
        XCTAssertTrue(game.stores[0].advertising != advertising || game.stores[0].serviceAllocation != service)
    }

    func testStaffCanBeHiredAndFiredWithoutManager() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id

        XCTAssertFalse(game.stores[0].hasManager)
        XCTAssertEqual(game.stores[0].staff, 0)
        XCTAssertEqual(game.weeklyOpportunityCapacity(storeID: storeID), 7)

        XCTAssertTrue(game.hireStaff(for: storeID))
        XCTAssertEqual(game.stores[0].staff, 1)
        XCTAssertFalse(game.stores[0].employees[0].name.isEmpty)
        XCTAssertGreaterThan(game.stores[0].employees[0].monthlySalary, 0)
        XCTAssertEqual(game.weeklyOpportunityCapacity(storeID: storeID), 14)

        XCTAssertTrue(game.fireStaff(for: storeID))
        XCTAssertEqual(game.stores[0].staff, 0)
        XCTAssertFalse(game.fireStaff(for: storeID))
    }

    func testNamedEmployeeCandidateHasIndividualSkillsAndPayroll() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let candidates = game.employeeCandidates(for: storeID)

        XCTAssertEqual(candidates.count, 3)
        XCTAssertEqual(Set(candidates.map(\.id)).count, candidates.count)
        let candidate = candidates[1]
        XCTAssertTrue(game.hireEmployee(candidate.id, for: storeID))

        XCTAssertEqual(game.stores[0].employees, [candidate])
        XCTAssertEqual(game.stores[0].employeeMonthlyPayroll, candidate.monthlySalary)
        XCTAssertEqual(game.monthlyPersonnelCost(for: game.stores[0]), candidate.monthlySalary)
        XCTAssertFalse(game.employeeCandidates(for: storeID).contains { $0.id == candidate.id })
    }

    func testEmployeeSkillsImproveSalesAndAppraisalAccuracy() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id

        XCTAssertEqual(game.employeeSalesCloseAdjustment(for: storeID), 0)
        XCTAssertEqual(game.employeeAppraisalAccuracyBonus(for: storeID), 0)

        game.stores[0].employees = [StoreEmployee(name: "技能テスト", salesSkill: 90, appraisalSkill: 86, monthlySalary: 50)]

        XCTAssertGreaterThan(game.employeeSalesCloseAdjustment(for: storeID), 0.05)
        XCTAssertGreaterThanOrEqual(game.employeeAppraisalAccuracyBonus(for: storeID), 10)
        XCTAssertEqual(game.weeklyOpportunityCapacity(storeID: storeID), 14)
    }

    func testEmployeeTrainingCostsCashRaisesSkillAndSalaryOnlyOncePerWeek() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 10_000
        let storeID = game.stores[0].id
        XCTAssertTrue(game.hireStaff(for: storeID))
        let employee = game.stores[0].employees[0]
        let beforeCash = game.cash

        XCTAssertTrue(game.trainEmployee(employee.id, at: storeID, focus: .appraisal))
        XCTAssertEqual(game.cash, beforeCash - game.employeeTrainingCost)
        XCTAssertEqual(game.stores[0].employees[0].appraisalSkill, employee.appraisalSkill + 3)
        XCTAssertEqual(game.stores[0].employees[0].monthlySalary, employee.monthlySalary + 1)
        XCTAssertFalse(game.trainEmployee(employee.id, at: storeID, focus: .sales))

        game.turn += 1
        XCTAssertTrue(game.trainEmployee(employee.id, at: storeID, focus: .sales))
    }

    func testEmployeesGainExperienceFromOwnerDirectedSalesAndAppraisals() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        XCTAssertTrue(game.hireStaff(for: storeID))
        let employeeID = game.stores[0].employees[0].id
        let lead = game.buyerLeads[0]
        let inventory = game.stores[0].inventory[0]

        XCTAssertNotNil(game.negotiateManualSale(
            storeID: storeID,
            buyerLeadID: lead.id,
            inventoryID: inventory.id,
            strategy: .smallDiscount
        ))
        XCTAssertGreaterThan(game.stores[0].employees.first(where: { $0.id == employeeID })?.salesExperience ?? 0, 0)

        let purchase = game.purchaseCases[0]
        if case .unavailable = game.negotiatePurchaseCase(purchase.id, offerPercent: 100) {
            XCTFail("Employee should be able to assist the appraisal")
        }
        XCTAssertGreaterThan(game.stores[0].employees.first(where: { $0.id == employeeID })?.appraisalExperience ?? 0, 0)
    }

    func testExperiencedUnderpaidEmployeeCanBePoachedByCompetitor() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let employee = StoreEmployee(name: "引抜 太郎", salesSkill: 95, appraisalSkill: 95, monthlySalary: 10, tenureWeeks: 12)
        game.stores[0].employees = [employee]
        XCTAssertEqual(game.employeePoachingRisk(employee), 0.12, accuracy: 0.0001)

        let plotID = game.stores[0].plotID
        let nameSeed = employee.name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let selectedTurn = (0..<200).first { candidate in
            let seed = (candidate + 1) * 307 + plotID * 41 + nameSeed
            let raw = abs((seed &* 1_664_525 &+ 1_013_904_223) % 10_000)
            return Double(raw) / 10_000.0 < 0.12
        }!
        game.turn = selectedTurn

        game.advanceWeek()

        XCTAssertTrue(game.stores[0].employees.isEmpty)
        XCTAssertTrue(game.lastReport?.notes.contains { $0.contains("引き抜き") && $0.contains(employee.name) } == true)
        XCTAssertTrue(game.cityEvents.contains { $0.kind == .staffPoaching && !$0.isPositive })
    }

    func testManagerCanBeFiredAndDelegationIsCleared() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let candidate = game.managerCandidate(for: storeID)

        XCTAssertNotNil(candidate)
        XCTAssertTrue(game.hireManager(for: storeID))
        XCTAssertEqual(game.stores[0].manager, candidate)

        var store = game.stores[0]
        store.delegateStaff = true
        store.delegatePricing = true
        store.delegateProcurement = true
        store.delegateMarketing = true
        store.delegateService = true
        game.updateStore(store)

        XCTAssertTrue(game.fireManager(for: storeID))
        XCTAssertFalse(game.stores[0].hasManager)
        XCTAssertNil(game.stores[0].manager)
        XCTAssertFalse(game.stores[0].delegateStaff)
        XCTAssertFalse(game.stores[0].delegatePricing)
        XCTAssertFalse(game.stores[0].delegateProcurement)
        XCTAssertFalse(game.stores[0].delegateMarketing)
        XCTAssertFalse(game.stores[0].delegateService)
    }

    func testOwnerCanIncreaseAdvertisingWithoutManager() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let advertising = game.stores[0].advertising

        XCTAssertFalse(game.stores[0].hasManager)
        XCTAssertTrue(game.increaseAdvertisingBudget(for: storeID, by: 40))
        XCTAssertEqual(game.stores[0].advertising, advertising + 40)
    }

    func testStaffAndManagerSalaryAreFullyRecordedAcrossFourWeeks() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id

        XCTAssertTrue(game.hireStaff(for: storeID))
        XCTAssertTrue(game.hireManager(for: storeID))
        let monthlyPersonnel = game.monthlyPersonnelCost(for: game.stores[0])
        var recordedPersonnel = 0

        for _ in 0..<4 {
            game.advanceWeek()
            recordedPersonnel += game.finance.personnel
        }

        XCTAssertEqual(recordedPersonnel, monthlyPersonnel)
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
            if case .available = $0.occupant {
                return $0.district == .highway && $0.development == nil
            }
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
        XCTAssertEqual(game.gridOccupancyIssues, [])

        game.advanceWeek()
        XCTAssertNil(game.store(at: plot.id)?.openingMonthsRemaining)

        XCTAssertTrue(game.renovateStore(newStore.id, to: .roadside))
        XCTAssertEqual(game.gridOccupancyIssues, [])
        XCTAssertEqual(game.store(at: plot.id)?.type.mapAssetName, "StoreSmall")
        XCTAssertEqual(game.store(at: plot.id)?.pendingType?.mapAssetName, "StoreRoadside")
        game.advanceWeek()
        game.advanceWeek()
        XCTAssertEqual(game.store(at: plot.id)?.type.mapAssetName, "StoreRoadside")

        game.closeStore(newStore.id)
        XCTAssertNil(game.store(at: plot.id))
        XCTAssertEqual(game.gridOccupancyIssues, [])
        if case .available = game.plot(id: plot.id)?.occupant {
            // The dynamic map layer now has no building to draw on this lot.
        } else {
            XCTFail("Closed store plot should become available")
        }
    }

    func testStoreTypesUseCatalogDistrictRestrictions() {
        let game = GameEngine()
        game.resetGame()

        let downtown = game.plots.first {
            $0.district == .downtown && game.footprintPlots(startingAt: $0, type: .small).count == 1
        }!
        XCTAssertEqual(game.footprintPlots(startingAt: downtown, type: .small).count, 1)
        XCTAssertTrue(game.footprintPlots(startingAt: downtown, type: .roadside).isEmpty)
        XCTAssertTrue(game.footprintPlots(startingAt: downtown, type: .service).isEmpty)

        let highway = game.plots.first {
            $0.district == .highway
                && game.footprintPlots(startingAt: $0, type: .roadside).count == StoreType.roadside.requiredGridCells
        }!
        XCTAssertEqual(
            game.footprintPlots(startingAt: highway, type: .roadside).count,
            StoreType.roadside.requiredGridCells
        )
    }

    func testAcquisitionModeRejectsUnavailableLandBeforeBuild() {
        let game = GameEngine()
        game.resetGame()
        let candidate = game.plots.first {
            if case .available = $0.occupant { return $0.development == nil }
            return false
        }!
        let index = game.plots.firstIndex(where: { $0.id == candidate.id })!
        game.plots[index].isForSale = false
        game.plots[index].isForLease = true

        XCTAssertTrue(game.footprintPlots(startingAt: candidate, type: .small, mode: .purchase).isEmpty)
        XCTAssertEqual(game.footprintPlots(startingAt: candidate, type: .small, mode: .lease).map(\.id), [candidate.id])
    }

    func testGridOccupancyValidatorDetectsRuntimePlotMismatch() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        XCTAssertEqual(game.gridOccupancyIssues, [])

        let store = game.stores[0]
        let plotIndex = game.plots.firstIndex(where: { $0.id == store.plotID })!
        game.plots[plotIndex].occupant = .available

        XCTAssertTrue(game.gridOccupancyIssues.contains(.occupantMismatch(store.id, store.plotID)))
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

    func testUnansweredPriceWarLowersCloseChanceAndCounterSaleTradesMarginForRecovery() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 10_000
        let store = game.stores[0]
        let inventory = store.inventory[0]
        let district = game.plot(id: store.plotID)!.district
        let lead = BuyerLead(
            id: UUID(), storeID: store.id, preference: .category(inventory.category),
            budget: 10_000, minimumQuality: 0.4,
            priceSensitivity: 1.0, generatedTurn: game.turn
        )
        game.buyerLeads = [lead]
        let baselineQuote = game.manualSaleQuote(storeID: store.id, inventoryID: inventory.id)!
        let baseline = game.saleNegotiationPreview(storeID: store.id, buyerLeadID: lead.id, inventoryID: inventory.id, strategy: .holdPrice)!
        let challenge = PriceWarChallenge(
            competitorID: game.competitors[0].id, district: district,
            startedTurn: game.turn, expiresTurn: game.turn + 4, intensity: 1.0
        )
        game.priceWarChallenges = [challenge]

        let unanswered = game.saleNegotiationPreview(storeID: store.id, buyerLeadID: lead.id, inventoryID: inventory.id, strategy: .holdPrice)!
        XCTAssertLessThan(unanswered.closeChance, baseline.closeChance)
        XCTAssertEqual(game.manualSaleQuote(storeID: store.id, inventoryID: inventory.id)?.price, baselineQuote.price)

        XCTAssertTrue(game.respondToPriceWar(challenge.id, with: .counterSale))
        let countered = game.saleNegotiationPreview(storeID: store.id, buyerLeadID: lead.id, inventoryID: inventory.id, strategy: .holdPrice)!
        XCTAssertGreaterThan(countered.closeChance, unanswered.closeChance)
        XCTAssertLessThan(game.manualSaleQuote(storeID: store.id, inventoryID: inventory.id)!.price, baselineQuote.price)
        XCTAssertEqual(game.priceWarChallenges[0].response, .counterSale)
    }

    func testBrandDefensePreservesPriceAndRaisesStoreReputation() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 10_000
        let store = game.stores[0]
        let inventory = store.inventory[0]
        let district = game.plot(id: store.plotID)!.district
        let priceBefore = game.manualSaleQuote(storeID: store.id, inventoryID: inventory.id)!.price
        let reputationBefore = store.reputation
        let challenge = PriceWarChallenge(
            competitorID: game.competitors[0].id, district: district,
            startedTurn: game.turn, expiresTurn: game.turn + 4, intensity: 1.0
        )
        game.priceWarChallenges = [challenge]

        XCTAssertTrue(game.respondToPriceWar(challenge.id, with: .brandDefense))

        XCTAssertEqual(game.manualSaleQuote(storeID: store.id, inventoryID: inventory.id)?.price, priceBefore)
        XCTAssertEqual(game.stores[0].reputation, reputationBefore + 0.04, accuracy: 0.0001)
        XCTAssertEqual(game.priceWarChallenges[0].response, .brandDefense)
    }

    func testPlayerCanPoachSkilledEmployeeFromCompetitor() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 10_000
        let storeID = game.stores[0].id
        let offer = game.rivalTalentOffers[0]
        let strengthBefore = game.competitors.first(where: { $0.id == offer.competitorID })!.strength
        let cashBefore = game.cash

        XCTAssertTrue(game.poachRivalTalent(offer.employee.id, from: offer.competitorID, to: storeID))

        XCTAssertEqual(game.cash, cashBefore - offer.signingCost)
        XCTAssertEqual(game.stores[0].employees.first?.name, offer.employee.name)
        XCTAssertEqual(game.stores[0].employees.first?.monthlySalary, offer.employee.monthlySalary + 5)
        XCTAssertLessThan(game.competitors.first(where: { $0.id == offer.competitorID })!.strength, strengthBefore)
        XCTAssertTrue(game.cityEvents.contains { $0.kind == .staffPoaching && $0.isPositive })
    }

    func testWeakCompetitorStoreCanBeAcquiredWithInventoryAndCustomers() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.competitors[0].strength = 0.90
        let offer = game.competitorAcquisitionOffers.first(where: { $0.competitorID == game.competitors[0].id })!
        let rivalPlotsBefore = game.competitors[0].plotIDs.count

        XCTAssertTrue(game.acquireCompetitorStore(competitorID: offer.competitorID, plotID: offer.plotID))

        XCTAssertEqual(game.stores.count, 2)
        XCTAssertEqual(game.stores.last?.inventoryCount, 3)
        XCTAssertEqual(game.competitors[0].plotIDs.count, rivalPlotsBefore - 1)
        XCTAssertTrue(game.stores.last?.plotIDs.contains(offer.plotID) == true)
        if case .player(let storeID) = game.plot(id: offer.plotID)?.occupant {
            XCTAssertEqual(storeID, game.stores.last?.id)
        } else {
            XCTFail("Acquired competitor plot should belong to the new player store")
        }
        XCTAssertTrue(game.cityEvents.contains { $0.kind == .competitorAcquisition && $0.plotID == offer.plotID })
    }

    func testCompetitorStartsActionablePriceWarInSharedDistrict() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeDistrict = game.plot(id: game.stores[0].plotID)!.district
        XCTAssertTrue(game.competitors.contains { competitor in
            competitor.plotIDs.contains { game.plot(id: $0)?.district == storeDistrict }
        })
        game.turn = 24

        game.advanceWeek()

        XCTAssertEqual(game.turn, 25)
        XCTAssertTrue(game.activePriceWars.contains { $0.district == storeDistrict && $0.response == nil })
        XCTAssertTrue(game.cityEvents.contains { $0.kind == .priceWar && !$0.isPositive })
    }

    func testWeeklyResultsAccumulateCareerStatistics() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let reportYear = game.year
        game.stores[0].pendingManualSales = 3
        game.stores[0].pendingManualRevenue = 600
        game.stores[0].pendingManualCOGS = 300

        game.advanceWeek()

        XCTAssertEqual(game.careerStatistics.totalSales, 3)
        XCTAssertEqual(game.careerStatistics.totalRevenue, game.lastReport?.revenue)
        XCTAssertEqual(game.careerStatistics.totalOperatingProfit, game.lastReport?.operatingProfit)
        XCTAssertEqual(game.careerStatistics.bestWeeklySales, 3)
        XCTAssertEqual(game.careerStatistics.salesByYear[reportYear], 3)
    }

    func testSalesFoundationMilestonePaysRewardAndCreatesNews() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.careerStatistics.totalSales = 24
        game.careerStatistics.salesByYear[game.year] = 24
        game.stores[0].pendingManualSales = 1
        let cashBefore = game.cash

        game.advanceWeek()

        XCTAssertTrue(game.careerStatistics.completedMilestones.contains(.salesFoundation))
        XCTAssertEqual(game.lastReport?.cashChange, game.cash - cashBefore)
        XCTAssertTrue(game.lastReport?.notes.contains { $0.contains("累計販売25台") && $0.contains("報奨金250万円") } == true)
        XCTAssertTrue(game.cityEvents.contains { $0.kind == .milestone && $0.title.contains("累計販売25台") })
    }

    func testAnnualSalesMilestoneRaisesBorrowingLimit() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.careerStatistics.completedMilestones.insert(.salesFoundation)
        game.careerStatistics.totalSales = 99
        game.careerStatistics.salesByYear[game.year] = 99
        game.stores[0].pendingManualSales = 1
        let borrowingLimitBefore = game.borrowingLimit

        game.advanceWeek()

        XCTAssertTrue(game.careerStatistics.completedMilestones.contains(.annualSales100))
        XCTAssertEqual(game.borrowingLimit, borrowingLimitBefore + 10_000)
        XCTAssertEqual(game.milestoneCreditBonus, 10_000)
    }

    func testNationalExpansionQuestUsesExplicitCompanyValueTarget() {
        let game = GameEngine()
        game.resetGame()
        game.companyValue = 44_999
        XCTAssertFalse(game.canExpandNationally)

        game.companyValue = 45_000
        XCTAssertTrue(game.canExpandNationally)
        XCTAssertEqual(game.milestoneStatuses.first(where: { $0.id == .nationalExpansion })?.progress, 1)
    }

    func testEndingEvaluationCombinesAssetsBrandAndSales() {
        let game = GameEngine()
        game.resetGame()
        XCTAssertEqual(game.endingEvaluation.rank, .d)

        startPlayableGame(game)
        game.companyValue = 100_000
        game.nationalBrandStrength = 1.45
        game.stores[0].reputation = 1.25
        game.careerStatistics.totalSales = 500

        XCTAssertEqual(game.endingEvaluation.rank, .s)
        XCTAssertEqual(game.endingEvaluation.totalScore, 100)
        XCTAssertEqual(game.endingEvaluation.assetScore, 45)
        XCTAssertEqual(game.endingEvaluation.brandScore, 30)
        XCTAssertEqual(game.endingEvaluation.salesScore, 25)
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

    func testOwnerHasSevenSharedBuyAndSellOpportunitiesWithoutStaff() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        game.cash = 100_000
        let storeID = game.stores[0].id
        XCTAssertEqual(game.stores[0].staff, 0)
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
                id: UUID(), storeID: storeID, preference: .category(.kei),
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
        for _ in 0..<3 { XCTAssertTrue(game.hireStaff(for: storeID)) }
        game.buyerLeads = [
            BuyerLead(
                id: UUID(), storeID: storeID,
                preference: .category(game.stores[0].inventory[0].category),
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
        XCTAssertEqual(game.weeklyOpportunityCapacity(storeID: storeID), 28)
        XCTAssertEqual(game.remainingWeeklyOpportunities(storeID: storeID), 27)
        XCTAssertFalse(game.canSellManually(storeID: storeID))
    }

    func testSalesAndProcurementCanBeDelegatedSeparately() {
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

        XCTAssertTrue(game.canNegotiatePurchaseCase(purchaseCase.id))
        XCTAssertFalse(game.canSellManually(storeID: storeID))

        store = game.stores[0]
        store.delegateProcurement = true
        game.updateStore(store)
        XCTAssertFalse(game.canNegotiatePurchaseCase(purchaseCase.id))
        if case .unavailable = game.negotiatePurchaseCase(purchaseCase.id, offerPercent: 100) {
            // The manager owns delegated purchase negotiations until the week is processed.
        } else {
            XCTFail("The owner should not handle a purchase case delegated to the manager")
        }
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
        startPlayableGame(game, plan: .business)
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

    func testNewModelLaunchPrecedesItsUsedMarketArrival() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let initialCount = game.availableVehicleCatalog.count
        let model = try! XCTUnwrap(VehicleCatalog.entry(id: "aoba-basicneo"))
        XCTAssertFalse(game.availableVehicleCatalog.contains { $0.id == "aoba-basicneo" })

        for _ in 0..<model.launchTurn { game.advanceWeek() }

        XCTAssertTrue(VehicleCatalog.releasedNewCars(through: game.turn).contains { $0.id == model.id })
        XCTAssertFalse(game.availableVehicleCatalog.contains { $0.id == model.id })
        XCTAssertTrue(game.newCarsAwaitingUsedMarket.contains { $0.id == model.id })
        XCTAssertTrue(game.cityEvents.contains { $0.title == "新型車が発売" && $0.detail.contains("BASIC NEO") })

        for _ in game.turn..<model.usedMarketTurn { game.advanceWeek() }

        XCTAssertGreaterThan(game.availableVehicleCatalog.count, initialCount)
        XCTAssertTrue(game.availableVehicleCatalog.contains { $0.id == model.id })
        XCTAssertTrue(game.cityEvents.contains { $0.title == "新型車の中古流通が開始" && $0.detail.contains("BASIC NEO") })
    }

    func testEveryManufacturerReleasesOneAnnualModelEachGameYear() {
        let annualModels = VehicleCatalog.all.filter { $0.id.hasPrefix("annual-") }
        let expectedMakers: Set<String> = ["アオバ", "ホシノ", "コーヨー", "セイカ", "ヒノデ", "ホクト", "ミカド", "ヤマト", "ノルド", "ヴォルトラ", "ロッサ"]

        XCTAssertEqual(annualModels.count, 110)
        for yearIndex in 0..<10 {
            let releases = annualModels.filter { ($0.launchTurn / 48) == yearIndex }
            XCTAssertEqual(releases.count, expectedMakers.count)
            XCTAssertEqual(Set(releases.map(\.maker)), expectedMakers)
        }
    }

    func testAnnualModelsWaitBeforeAppearingInUsedMarketAndStartWithLowSupply() {
        let model = try! XCTUnwrap(VehicleCatalog.entry(id: "annual-aoba-2030"))
        let game = GameEngine()
        game.resetGame()

        XCTAssertTrue(VehicleCatalog.releasedNewCars(through: model.launchTurn).contains { $0.id == model.id })
        XCTAssertFalse(VehicleCatalog.available(through: model.usedMarketTurn - 1).contains { $0.id == model.id })
        XCTAssertTrue(VehicleCatalog.available(through: model.usedMarketTurn).contains { $0.id == model.id })

        game.turn = model.usedMarketTurn
        XCTAssertEqual(game.usedMarketSupplyFactor(for: model), 0.12, accuracy: 0.001)
        game.turn = model.usedMarketTurn + 28
        XCTAssertEqual(game.usedMarketSupplyFactor(for: model), 0.62, accuracy: 0.001)
        game.turn = model.usedMarketTurn + 56
        XCTAssertEqual(game.usedMarketSupplyFactor(for: model), 1.0, accuracy: 0.001)
    }

    func testFuelPriceAndTimeShiftDemandFromGasolineTowardEVs() {
        let game = GameEngine()
        game.resetGame()
        let ev = try! XCTUnwrap(VehicleCatalog.entry(id: "voltra-aurex"))
        let gasoline = try! XCTUnwrap(VehicleCatalog.entry(id: "aoba-pico"))

        game.turn = 0
        game.fuelPriceIndex = 0.82
        let earlyEV = game.powertrainDemandFactor(for: ev, in: .emerging)
        let earlyGasoline = game.powertrainDemandFactor(for: gasoline, in: .emerging)

        game.turn = 400
        game.fuelPriceIndex = 1.38
        let lateEV = game.powertrainDemandFactor(for: ev, in: .emerging)
        let lateGasoline = game.powertrainDemandFactor(for: gasoline, in: .emerging)

        XCTAssertGreaterThan(lateEV, earlyEV)
        XCTAssertLessThan(lateGasoline, earlyGasoline)
        XCTAssertGreaterThan(lateEV, lateGasoline)
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

    func testVehicleCategoriesSeparateBodyAndMarketSegmentsFromBudget() {
        XCTAssertFalse(VehicleCategory.allCases.map(\.name).contains("低価格車"))
        XCTAssertEqual(VehicleCategory.imported.name, "輸入車")
        XCTAssertEqual(VehicleCategory.pickup.name, "ピックアップトラック")
        XCTAssertTrue(VehicleCatalog.all.contains { $0.category == .imported })
        XCTAssertTrue(VehicleCatalog.all.contains { $0.category == .pickup })
        for category in VehicleCategory.allCases {
            XCTAssertTrue(VehicleCatalog.available(through: 0).contains { $0.category == category })
        }
    }

    func testBudgetFirstCustomerCanConsiderDifferentVehicleCategories() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        game.cash = 100_000
        let storeID = game.stores[0].id
        XCTAssertTrue(game.buyInventory(category: .kei, count: 1, storeID: storeID))
        XCTAssertTrue(game.buyInventory(category: .compact, count: 1, storeID: storeID))
        let candidates = game.stores[0].inventory.filter { [.kei, .compact].contains($0.category) }
        XCTAssertGreaterThanOrEqual(candidates.count, 2)

        let lead = BuyerLead(
            id: UUID(), storeID: storeID, preference: .budgetFirst,
            budget: 1_000, minimumQuality: 0.5,
            priceSensitivity: 1.2, generatedTurn: game.turn
        )
        game.buyerLeads = [lead]

        for inventory in candidates.prefix(2) {
            XCTAssertNotNil(game.saleNegotiationPreview(
                storeID: storeID,
                buyerLeadID: lead.id,
                inventoryID: inventory.id,
                strategy: .smallDiscount
            ))
        }
    }

    func testTradeInSaleUsesNetCashAndAddsCustomerVehicleToInventory() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let soldBatch = game.stores[0].inventory[0]
        let tradeModel = VehicleCatalog.all.first(where: { $0.id == "aoba-pico" })!
        let tradeIn = TradeInVehicle(
            modelID: tradeModel.id,
            category: tradeModel.category,
            modelYear: 2027,
            mileage: 28_000,
            quality: 0.72,
            appraisedValue: 40,
            repairCost: 6
        )
        let lead = BuyerLead(
            id: UUID(), storeID: storeID, preference: .category(soldBatch.category),
            budget: 10_000, minimumQuality: 0.4,
            priceSensitivity: 1.0, generatedTurn: game.turn,
            tradeInVehicle: tradeIn
        )
        game.buyerLeads = [lead]

        var selectedTurn = 0
        for candidate in 0..<100 {
            game.turn = candidate
            let closeChance = game.tradeInSalePreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: soldBatch.id, strategy: .closeDeal)!.closeChance
            let categoryIndex = VehicleCategory.allCases.firstIndex(of: soldBatch.category)!
            let seed = candidate * 97 + game.stores[0].plotID * 19 + categoryIndex * 31 + 2 * 11 + 71
            let raw = abs((seed &* 1_664_525 &+ 1_013_904_223) % 10_000)
            if Double(raw) / 10_000.0 < closeChance {
                selectedTurn = candidate
                break
            }
        }
        game.turn = selectedTurn
        let regular = game.saleNegotiationPreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: soldBatch.id, strategy: .closeDeal)!
        let tradePreview = game.tradeInSalePreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: soldBatch.id, strategy: .closeDeal)!
        let beforeCash = game.cash
        let beforeCount = game.stores[0].inventoryCount

        let result = game.negotiateManualSale(storeID: storeID, buyerLeadID: lead.id, inventoryID: soldBatch.id, strategy: .closeDeal, acceptTradeIn: true)!

        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(result.tradeInAcquired)
        XCTAssertGreaterThan(tradePreview.closeChance, regular.closeChance)
        XCTAssertEqual(game.cash - beforeCash, tradePreview.cashImpact)
        XCTAssertEqual(game.stores[0].inventoryCount, beforeCount)
        XCTAssertFalse(game.stores[0].inventory.contains { $0.id == soldBatch.id })
        let acquired = game.stores[0].inventory.first(where: { $0.modelID == tradeIn.modelID && $0.modelYear == tradeIn.modelYear && $0.mileage == tradeIn.mileage })
        XCTAssertEqual(acquired?.averageCost, tradeIn.appraisedValue + tradeIn.repairCost)
        XCTAssertEqual(acquired?.quality, tradeIn.qualityAfterRepair)
        XCTAssertEqual(acquired?.acquiredTurn, selectedTurn)
        XCTAssertEqual(result.customerCashSettlement, result.salePrice - tradeIn.appraisedValue)
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

    func testVehicleValueRespondsToYearMileageAndQuality() {
        let game = GameEngine()
        game.resetGame()
        let model = VehicleCatalog.all.first(where: { $0.category == .compact })!

        let baseline = game.vehicleRetailValue(modelID: model.id, category: model.category, modelYear: 2028, mileage: 30_000, quality: 0.82, in: .station)
        let older = game.vehicleRetailValue(modelID: model.id, category: model.category, modelYear: 2020, mileage: 30_000, quality: 0.82, in: .station)
        let higherMileage = game.vehicleRetailValue(modelID: model.id, category: model.category, modelYear: 2028, mileage: 120_000, quality: 0.82, in: .station)
        let lowerQuality = game.vehicleRetailValue(modelID: model.id, category: model.category, modelYear: 2028, mileage: 30_000, quality: 0.58, in: .station)

        XCTAssertGreaterThan(baseline, older)
        XCTAssertGreaterThan(baseline, higherMileage)
        XCTAssertGreaterThan(baseline, lowerQuality)
    }

    func testGeneratedVehiclesKeepMileagePlausibleForModelYear() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let profiles = game.auctionListings.map { ($0.modelYear, $0.mileage) }
            + game.purchaseCases.map { ($0.modelYear, $0.mileage) }

        XCTAssertFalse(profiles.isEmpty)
        for (modelYear, mileage) in profiles {
            XCTAssertLessThanOrEqual(modelYear, game.year)
            XCTAssertGreaterThan(mileage, 0)
            if modelYear == game.year {
                XCTAssertLessThanOrEqual(mileage, 12_500)
            }
        }
    }

    func testInventoryServiceChargesCashAndRaisesQualityByThreeOrFour() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let batch = game.stores[0].inventory.first { game.servicePreview(storeID: storeID, inventoryID: $0.id) != nil }!
        let preview = game.servicePreview(storeID: storeID, inventoryID: batch.id)!
        let beforeCash = game.cash

        XCTAssertTrue(game.serviceInventory(storeID: storeID, inventoryID: batch.id))
        let serviced = game.stores[0].inventory.first(where: { $0.id == batch.id })!
        XCTAssertEqual(beforeCash - game.cash, preview.cost)
        XCTAssertEqual(serviced.averageCost, batch.averageCost + preview.cost)
        XCTAssertEqual(Int((serviced.quality * 100).rounded()) - Int((batch.quality * 100).rounded()), preview.qualityGain)
        XCTAssertTrue([3, 4].contains(preview.qualityGain))
        XCTAssertLessThanOrEqual(serviced.quality, 0.94)
        XCTAssertEqual(serviced.acquiredTurn, batch.acquiredTurn)
    }

    func testRareClassicAuctionCarsUse1970sOr1980sYearsAndCollectorPrices() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)

        let classics = game.auctionListings.filter { VehicleCatalog.entry(id: $0.modelID)?.isRareClassic == true }
        XCTAssertEqual(VehicleCatalog.rareClassics.count, 4)
        XCTAssertEqual(classics.count, 1, "希少旧車は通常18台の出品枠に常時並ばない")
        let listing = try! XCTUnwrap(classics.first)
        let model = try! XCTUnwrap(VehicleCatalog.entry(id: listing.modelID))
        XCTAssertTrue(model.classicProductionYears?.contains(listing.modelYear) == true)
        XCTAssertTrue((1970...1989).contains(listing.modelYear))
        XCTAssertGreaterThan(listing.marketPrice, listing.category.purchaseCost * 2)
        XCTAssertLessThan(listing.quality, 0.73)
        XCTAssertTrue(listing.seller.contains("現状渡し"))
        XCTAssertFalse(game.stores.flatMap(\.inventory).contains(where: \.isRareClassic))
    }

    func testClassicRestorationAndCustomizationAreMuchMoreExpensive() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let normal = InventoryBatch(modelID: "hokuto-ridge", category: .suv, count: 1, averageCost: 180, quality: 0.62, modelYear: 2024, mileage: 72_000, acquiredTurn: game.turn)
        let classic = InventoryBatch(modelID: "hokuto-trailclassic", category: .pickup, count: 1, averageCost: 500, quality: 0.50, modelYear: 1985, mileage: 128_000, acquiredTurn: game.turn)
        game.stores[0].inventory.append(contentsOf: [normal, classic])

        let normalCustom = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: normal.id, kind: .customization))
        let classicCustom = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: classic.id, kind: .customization))
        let normalRestoration = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: normal.id, kind: .restoration))
        let classicRestoration = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: classic.id, kind: .restoration))

        XCTAssertGreaterThan(classicCustom.cost, normalCustom.cost * 2)
        XCTAssertGreaterThan(classicRestoration.cost, normalRestoration.cost * 2)
        XCTAssertGreaterThan(classicCustom.weeks, normalCustom.weeks)
        XCTAssertGreaterThanOrEqual(classicRestoration.weeks, 5)
        XCTAssertLessThanOrEqual(classicRestoration.resultingQuality, 90)
    }

    func testCustomProjectChargesCashBlocksSaleAndCompletesAfterSeveralWeeks() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let batch = InventoryBatch(modelID: "hokuto-ridge", category: .suv, count: 1, averageCost: 180, quality: 0.68, modelYear: 2025, mileage: 58_000, acquiredTurn: game.turn)
        game.stores[0].inventory.append(batch)
        let stockQuote = try! XCTUnwrap(game.manualSaleQuote(storeID: storeID, inventoryID: batch.id))
        let preview = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: batch.id, kind: .customization))
        let beforeCash = game.cash

        XCTAssertGreaterThanOrEqual(preview.weeks, 3)
        XCTAssertTrue(game.startWorkshopProject(storeID: storeID, inventoryID: batch.id, kind: .customization))
        XCTAssertEqual(beforeCash - game.cash, preview.cost)
        XCTAssertNil(game.manualSaleQuote(storeID: storeID, inventoryID: batch.id))
        XCTAssertNil(game.servicePreview(storeID: storeID, inventoryID: batch.id))

        for _ in 0..<preview.weeks { game.advanceWeek() }

        let completed = try! XCTUnwrap(game.stores[0].inventory.first(where: { $0.id == batch.id }))
        XCTAssertNil(completed.workshopProject)
        XCTAssertEqual(completed.productState, .custom)
        XCTAssertEqual(Int((completed.quality * 100).rounded()), preview.resultingQuality)
        XCTAssertEqual(completed.averageCost, batch.averageCost + preview.cost)
        XCTAssertGreaterThan(game.manualSaleQuote(storeID: storeID, inventoryID: batch.id)?.price ?? 0, stockQuote.price)
    }

    func testCustomAndClassicDemandIsConcentratedInSpecificDistricts() {
        let game = GameEngine()
        game.resetGame()
        let custom = InventoryBatch(modelID: "hokuto-ridge", category: .suv, count: 1, averageCost: 300, quality: 0.80, modelYear: 2025, mileage: 48_000, acquiredTurn: 0, productState: .custom)
        let classic = InventoryBatch(modelID: "rossa-stellagt", category: .imported, count: 1, averageCost: 1_200, quality: 0.70, modelYear: 1978, mileage: 94_000, acquiredTurn: 0, productState: .restored)

        XCTAssertGreaterThan(game.specialtyCloseAdjustment(for: custom, in: .industrial), game.specialtyCloseAdjustment(for: custom, in: .station))
        XCTAssertGreaterThan(game.specialtyMarketFactor(for: custom, in: .highway), game.specialtyMarketFactor(for: custom, in: .suburb))
        XCTAssertGreaterThan(game.specialtyCloseAdjustment(for: classic, in: .emerging), game.specialtyCloseAdjustment(for: classic, in: .station))
        XCTAssertGreaterThan(game.specialtyMarketFactor(for: classic, in: .downtown), game.specialtyMarketFactor(for: classic, in: .station))
    }

    func testInventoryAgingLowersPriceAndCloseChanceAfterFreshnessBoost() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.turn = 30
        let storeID = game.stores[0].id
        let inventoryID = game.stores[0].inventory[0].id
        let category = game.stores[0].inventory[0].category
        game.buyerLeads = [BuyerLead(
            id: UUID(), storeID: storeID, preference: .category(category),
            budget: 10_000, minimumQuality: 0.4,
            priceSensitivity: 1.0, generatedTurn: game.turn
        )]

        game.stores[0].inventory[0].acquiredTurn = game.turn
        let freshBatch = game.stores[0].inventory[0]
        let freshQuote = game.manualSaleQuote(storeID: storeID, inventoryID: inventoryID)!
        let freshPreview = game.saleNegotiationPreview(storeID: storeID, inventoryID: inventoryID, strategy: .smallDiscount)!

        game.stores[0].inventory[0].acquiredTurn = 0
        let agedBatch = game.stores[0].inventory[0]
        let agedQuote = game.manualSaleQuote(storeID: storeID, inventoryID: inventoryID)!
        let agedPreview = game.saleNegotiationPreview(storeID: storeID, inventoryID: inventoryID, strategy: .smallDiscount)!

        XCTAssertEqual(game.inventoryAgeLabel(for: freshBatch), "新入荷")
        XCTAssertEqual(game.inventoryAgeWeeks(for: agedBatch), 30)
        XCTAssertLessThan(game.inventoryAgingValueFactor(for: agedBatch), 1)
        XCTAssertLessThan(game.inventoryFreshnessCloseAdjustment(for: agedBatch), 0)
        XCTAssertLessThan(agedQuote.price, freshQuote.price)
        XCTAssertLessThan(agedPreview.closeChance, freshPreview.closeChance)
    }

    func testWeeklyReportRecordsAverageInventoryWeeksAndAgingWarning() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.turn = 20

        game.advanceWeek()

        XCTAssertEqual(game.lastReport?.averageInventoryWeeks ?? 0, 21, accuracy: 0.001)
        XCTAssertTrue(game.lastReport?.notes.contains { $0.contains("12週超") && $0.contains("滞留在庫") } == true)
    }

    func testStorePurchaseChanceIsHigherThanNormalAuctionBidChance() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let purchase = game.purchaseCases[0]
        let listing = game.auctionListings[0]
        let storeChance = game.purchaseNegotiationPreview(purchase.id, offerPercent: 94)!.closeChance
        let auctionChance = game.auctionBidWinChance(for: listing, maxPrice: listing.marketPrice)

        XCTAssertGreaterThan(storeChance, auctionChance)
        XCTAssertGreaterThan(game.auctionListings.count, game.purchaseCases.filter { $0.storeID == game.stores[0].id }.count)
    }

    func testCatalogModelsDepreciateAndContinueLaunchingAcrossGame() {
        let game = GameEngine()
        game.resetGame()
        let original = VehicleCatalog.all.first(where: { $0.id == "mikado-celest" })!
        let initialPrice = game.catalogRetailPrice(for: original, in: .downtown)

        game.turn = 240
        game.year = 2035
        let agedPrice = game.catalogRetailPrice(for: original, in: .downtown)

        XCTAssertLessThan(agedPrice, initialPrice)
        XCTAssertTrue(VehicleCatalog.available(through: 240).contains { $0.launchTurn > 32 })
        XCTAssertTrue(VehicleCatalog.all.contains { $0.launchTurn > 400 })
    }

    func testDetailedInspectionRevealsHiddenIssueAndRecalculatesExpectedValue() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 10_000
        let storeID = game.stores[0].id
        let model = VehicleCatalog.all.first(where: { $0.id == "aoba-pico" })!
        let modelYear = 2024
        let categoryIndex = VehicleCategory.allCases.firstIndex(of: model.category)!
        let mileage = stride(from: 20_000, through: 80_000, by: 500).first { candidate in
            let seed = modelYear * 43 + candidate / 500 + categoryIndex * 71
            let raw = abs((seed &* 1_664_525 &+ 1_013_904_223) % 10_000)
            return Double(raw) / 10_000.0 < 0.96
        }!
        let purchase = PurchaseCase(
            id: UUID(), storeID: storeID, modelID: model.id, category: model.category,
            modelYear: modelYear, mileage: mileage,
            exterior: 72, interior: 74, mechanical: 68,
            askingPrice: 80, appraisedPrice: 96, repairCost: 12,
            expectedSalePrice: 150, expectedDays: 18, demand: 1.0,
            appraisalAccuracy: 62, negotiationAttempts: 0,
            hiddenIssue: .repairedHistory, issueRevealed: false
        )
        game.purchaseCases = [purchase]
        let beforeCash = game.cash

        let result = game.inspectPurchaseCase(purchase.id)

        XCTAssertEqual(result, .issueFound(.repairedHistory))
        XCTAssertEqual(game.cash, beforeCash - 10)
        XCTAssertEqual(game.purchaseCases[0].appraisalAccuracy, 96)
        XCTAssertEqual(game.purchaseCases[0].revealedIssue, .repairedHistory)
        XCTAssertEqual(game.purchaseCases[0].expectedSaleAfterAppraisal, Int(Double(purchase.expectedSalePrice) * VehicleIssueKind.repairedHistory.disclosedValueFactor))
        XCTAssertLessThan(game.purchaseCases[0].expectedGrossProfit, purchase.expectedGrossProfit)
    }

    func testDisclosedVehicleIssueLowersSaleQuote() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let clean = game.stores[0].inventory[0]
        let disclosed = InventoryBatch(
            modelID: clean.modelID, category: clean.category, count: 1,
            averageCost: clean.averageCost, quality: clean.quality,
            modelYear: clean.modelYear, mileage: clean.mileage,
            acquiredTurn: clean.acquiredTurn, productState: clean.productState,
            vehicleIssue: VehicleIssueRecord(kind: .odometerRollback, status: .disclosed)
        )
        game.stores[0].inventory.append(disclosed)

        let cleanQuote = game.manualSaleQuote(storeID: storeID, inventoryID: clean.id)!
        let disclosedQuote = game.manualSaleQuote(storeID: storeID, inventoryID: disclosed.id)!

        XCTAssertLessThan(disclosedQuote.price, cleanQuote.price)
        XCTAssertEqual(game.stores[0].inventory.last?.disclosedIssue, .odometerRollback)
    }

    func testUndisclosedIssueTriggersDelayedClaimCostAndReputationLossAfterSale() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        game.stores[0].inventory[0].vehicleIssue = VehicleIssueRecord(kind: .odometerRollback, status: .hidden)
        let inventoryID = game.stores[0].inventory[0].id
        let category = game.stores[0].inventory[0].category
        let lead = BuyerLead(
            id: UUID(), storeID: storeID, preference: .category(category),
            budget: 10_000, minimumQuality: 0.4,
            priceSensitivity: 1.0, generatedTurn: game.turn
        )
        game.buyerLeads = [lead]

        var selectedTurn = 0
        for candidate in 0..<100 {
            game.turn = candidate
            game.stores[0].inventory[0].acquiredTurn = candidate
            let closeChance = game.saleNegotiationPreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: inventoryID, strategy: .closeDeal)!.closeChance
            let categoryIndex = VehicleCategory.allCases.firstIndex(of: category)!
            let seed = candidate * 97 + game.stores[0].plotID * 19 + categoryIndex * 31 + 2 * 11
            let raw = abs((seed &* 1_664_525 &+ 1_013_904_223) % 10_000)
            if Double(raw) / 10_000.0 < closeChance {
                selectedTurn = candidate
                break
            }
        }
        game.turn = selectedTurn
        game.stores[0].inventory[0].acquiredTurn = selectedTurn
        let result = game.negotiateManualSale(storeID: storeID, buyerLeadID: lead.id, inventoryID: inventoryID, strategy: .closeDeal)!

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(game.pendingCustomerClaims.count, 1)
        let claim = game.pendingCustomerClaims[0]
        XCTAssertEqual(claim.issue, .odometerRollback)
        XCTAssertGreaterThanOrEqual(claim.compensationCost, 30)
        let reputationBeforeClaim = game.stores[0].reputation

        var weeksAdvanced = 0
        while !game.pendingCustomerClaims.isEmpty && weeksAdvanced < 3 {
            game.advanceWeek()
            weeksAdvanced += 1
        }

        XCTAssertTrue(game.pendingCustomerClaims.isEmpty)
        XCTAssertEqual(game.finance.customerClaims, claim.compensationCost)
        XCTAssertLessThan(game.stores[0].reputation, reputationBeforeClaim)
        XCTAssertTrue(game.lastReport?.notes.contains { $0.contains("販売後") && $0.contains("メーター改ざん") } == true)
        XCTAssertTrue(game.cityEvents.contains { $0.kind == .customerClaim && !$0.isPositive })
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

    func testFourWeekForecastShowsInventoryCapitalAndAnOperatingRange() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .family)
        let store = game.stores[0]

        let forecast = game.fourWeekForecast(for: store.id)

        XCTAssertNotNil(forecast)
        XCTAssertGreaterThan(forecast?.inventoryCapital ?? 0, 0)
        XCTAssertGreaterThanOrEqual(forecast?.salesHigh ?? -1, forecast?.salesLow ?? 0)
        XCTAssertGreaterThanOrEqual(forecast?.grossProfitHigh ?? Int.min, forecast?.grossProfitLow ?? Int.max)
        XCTAssertFalse(forecast?.bottleneck.isEmpty ?? true)
    }

    func testCashCrisisAllowsOneRecoveryWeekBeforeGameOver() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        game.cash = -100_000

        game.advanceWeek()

        XCTAssertEqual(game.financialDistressWeeks, 1)
        XCTAssertFalse(game.gameOver)
        XCTAssertNotNil(game.financialDistressMessage)

        game.advanceWeek()

        XCTAssertEqual(game.financialDistressWeeks, 2)
        XCTAssertTrue(game.gameOver)
    }

    func testCashRecoveryClearsFinancialDistress() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        game.cash = -100_000
        game.advanceWeek()
        XCTAssertEqual(game.financialDistressWeeks, 1)

        game.cash = 5_000
        game.advanceWeek()

        XCTAssertEqual(game.financialDistressWeeks, 0)
        XCTAssertFalse(game.gameOver)
    }

    func testFinancialDistressLowersTheAvailableCreditLimit() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        let healthyLimit = game.borrowingLimit

        game.financialDistressWeeks = 1

        XCTAssertEqual(game.creditRating, "C")
        XCTAssertEqual(game.borrowingLimit, healthyLimit * 3 / 4)
    }

    func testReturnToTitlePreservesSaveAndLoadRestoresIt() {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        game.cash = 6_123
        game.fuelPriceIndex = 1.27
        game.careerStatistics.totalSales = 123
        game.careerStatistics.completedMilestones.insert(.salesFoundation)
        game.priceWarChallenges = [PriceWarChallenge(
            competitorID: game.competitors[0].id,
            district: .downtown,
            startedTurn: 0,
            expiresTurn: 4,
            intensity: 1.0,
            response: .brandDefense
        )]

        game.returnToTitle()
        XCTAssertFalse(game.hasStarted)
        XCTAssertTrue(game.hasSaveData)

        game.cash = 1
        game.loadGame()
        XCTAssertTrue(game.hasStarted)
        XCTAssertEqual(game.cash, 6_123)
        XCTAssertEqual(game.fuelPriceIndex, 1.27, accuracy: 0.001)
        XCTAssertEqual(game.careerStatistics.totalSales, 123)
        XCTAssertTrue(game.careerStatistics.completedMilestones.contains(.salesFoundation))
        XCTAssertEqual(game.priceWarChallenges.first?.response, .brandDefense)
    }
}
