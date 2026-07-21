import XCTest
@testable import UsedCarCity

@MainActor
final class GameEngineTests: XCTestCase {
    private enum BusinessProfile: CaseIterable {
        case family, discount, quality, business

        var name: String {
            switch self {
            case .family: "ファミリー"
            case .discount: "低価格"
            case .quality: "品質"
            case .business: "法人"
            }
        }
        var district: DistrictKind {
            switch self {
            case .family: .suburb
            case .discount: .station
            case .quality: .downtown
            case .business: .industrial
            }
        }
        var storeType: StoreType {
            switch self {
            case .family: .standard
            case .business: .service
            case .discount, .quality: .small
            }
        }
        var focus: CustomerFocus {
            switch self {
            case .family: .family
            case .discount: .value
            case .quality: .affluent
            case .business: .business
            }
        }
        var concept: StoreConcept {
            switch self {
            case .family: .family
            case .discount: .localValue
            case .quality: .affluent
            case .business: .business
            }
        }
    }

    private func startPlayableGame(_ game: GameEngine, plan: BusinessProfile = .family) {
        game.startNewGame()
        let preferred = game.foundingCandidatePlots.first(where: { $0.district == plan.district })
        let candidates = ([preferred].compactMap { $0 } + game.plots.filter { $0.district == plan.district })
        let plot = candidates.first { candidate in
            guard candidate.district == plan.district, candidate.development == nil else { return false }
            guard case .available = candidate.occupant else { return false }
            return game.footprintPlots(startingAt: candidate, type: plan.storeType, mode: .lease).count == plan.storeType.requiredGridCells
        }!
        let footprint = game.footprintPlots(startingAt: plot, type: plan.storeType, mode: .lease)
        let facilities = plan.concept.defaultFacilities
        let totalBuildCost = game.totalBuildCost(for: footprint, type: plan.storeType, mode: .lease, facilities: facilities)
        let loan = plan == .business ? totalBuildCost : max(0, totalBuildCost - game.cash)
        game.selectFoundingPlot(plot.id)
        XCTAssertTrue(game.buildStore(
            on: plot,
            type: plan.storeType,
            mode: .lease,
            focus: plan.focus,
            concept: plan.concept,
            loanAmount: loan
        ))
        let store = game.stores[0]
        for category in game.recommendedCategories(for: plot.district).prefix(2) {
            XCTAssertTrue(game.buyInventory(category: category, count: 2, storeID: store.id))
        }
        game.completeTutorial()
        game.tutorialMessage = nil
    }

    func testNewGameCreatesSixCoastalDistrictsWithDerivedPlots() {
        let game = GameEngine()
        game.resetGame()
        let map = CityMapDefinition.suihama
        XCTAssertEqual(game.plots.count, 147)
        XCTAssertEqual(game.districts.count, 6)
        XCTAssertEqual(game.plots.count, map.parcels.compactMap(\.legacyPlotID).count)
        for district in DistrictKind.allCases {
            let districtPlots = game.plots.filter { $0.district == district }
            XCTAssertEqual(
                districtPlots.count,
                map.parcels.filter { $0.district == district && $0.legacyPlotID != nil }.count
            )
            XCTAssertEqual(
                Set(districtPlots.map(\.localNumber)),
                Set(1...districtPlots.count)
            )
        }
    }

    func testGameplayPlotsAreDerivedFromAuthoritativeGridParcels() throws {
        let game = GameEngine()
        game.resetGame()
        let map = CityMapDefinition.suihama

        XCTAssertEqual(Set(game.plots.map(\.id)), Set(map.parcels.compactMap(\.legacyPlotID)))
        for plot in game.plots {
            let parcel = try XCTUnwrap(map.parcel(legacyPlotID: plot.id))
            XCTAssertEqual(plot.district, parcel.district)
            XCTAssertEqual(plot.area, parcel.areaSquareMeters)
            XCTAssertEqual(plot.price, try XCTUnwrap(parcel.price))
            XCTAssertEqual(plot.isForSale, parcel.isPurchasable)
            XCTAssertEqual(plot.isForLease, parcel.isPurchasable)
            let object = map.objects.first(where: { $0.parcelID == parcel.id })
            switch object?.kind {
            case .building:
                XCTAssertEqual(plot.currentUse, .ambientBuilding(assetID: try XCTUnwrap(object?.assetID)))
            case .parking:
                XCTAssertEqual(plot.currentUse, .surfaceParking)
            case nil:
                XCTAssertEqual(plot.currentUse, .vacant)
            }
        }
    }

    func testInitialCompetitorsUseSemanticDistrictPlacements() throws {
        let game = GameEngine()
        game.resetGame()

        XCTAssertTrue(game.competitors.allSatisfy { $0.plotIDs.count == 2 })
        let occupiedDistricts = try Set(game.competitors.flatMap(\.plotIDs).map { plotID in
            let plot = try XCTUnwrap(game.plot(id: plotID))
            XCTAssertNotEqual(plot.structure, .vacant)
            return plot.district
        })
        XCTAssertEqual(occupiedDistricts, Set(DistrictKind.allCases))
    }

    func testMapFocusRequestsCarryGridSemanticTargets() {
        XCTAssertEqual(MapFocusRequest(plotID: 42).target, .plot(42))
        XCTAssertEqual(MapFocusRequest(district: .industrial).target, .district(.industrial))
    }

    func testInitialVacancyMatchesTheAuthoritativeGridMap() throws {
        let game = GameEngine()
        game.resetGame()
        let map = CityMapDefinition.suihama

        for plot in game.plots {
            let parcel = try XCTUnwrap(map.parcel(legacyPlotID: plot.id))
            let hasBuilding = map.objects.contains {
                $0.parcelID == parcel.id && $0.kind == .building
            }
            XCTAssertEqual(plot.structure != .vacant, hasBuilding, parcel.id)
        }
        XCTAssertTrue(game.plots.allSatisfy { $0.isForSale && $0.isForLease })
    }

    func testStandardStoreCombinesTwoCellsAndDemolishesBothBuildings() {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        let plot = game.foundingCandidatePlots.first(where: { $0.district == .suburb })!
        let footprint = game.footprintPlots(startingAt: plot, type: .standard)

        XCTAssertEqual(footprint.count, 2)
        let demolitionCost = game.demolitionCost(for: footprint)
        game.selectFoundingPlot(plot.id)
        XCTAssertTrue(game.buildStore(on: plot, type: .standard, mode: .lease, focus: .family, concept: .family, loanAmount: 0))

        let store = game.stores[0]
        XCTAssertEqual(store.plotIDs.count, 2)
        XCTAssertEqual(Set(store.plotIDs), Set(footprint.map(\.id)))
        XCTAssertTrue(store.plotIDs.allSatisfy { game.plot(id: $0)?.structure == .vacant })
        XCTAssertGreaterThanOrEqual(demolitionCost, 0)
    }

    func testMultiCellBreakEvenIncludesEveryOccupiedPlot() {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        let plot = game.foundingCandidatePlots.first(where: { $0.district == .suburb })!
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
        let parcels = game.stores[0].plotIDs.compactMap {
            CityMapDefinition.suihama.parcel(legacyPlotID: $0)
        }
        XCTAssertTrue(
            Set(parcels.map { $0.rect.minRow }).count == 1
                || Set(parcels.map { $0.rect.minColumn }).count == 1
        )
    }

    func testFacilitiesUseNamedGridAnchorsSeparateFromStoreParcels() throws {
        let map = CityMapDefinition.suihama
        let coordinates = try MapFacility.allCases.map { facility in
            try XCTUnwrap(map.coordinate(for: facility.gridAnchorID))
        }
        XCTAssertEqual(Set(coordinates).count, MapFacility.allCases.count)
        for coordinate in coordinates {
            XCTAssertTrue(map.size.contains(coordinate))
            XCTAssertNil(map.parcel(at: coordinate))
        }
    }

    func testStartupBeginsWithLocationSelectionOnMap() {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        XCTAssertTrue(game.hasStarted)
        XCTAssertEqual(game.stores.count, 0)
        XCTAssertEqual(game.totalInventory, 0)
        XCTAssertEqual(game.tutorialStep, .chooseLocation)
        XCTAssertEqual(game.foundingCandidatePlots.count, DistrictKind.allCases.count)
        XCTAssertTrue(game.recommendedFoundingPlot.map(game.isFoundingCandidate) == true)
    }

    func testFoundingLocationIsFreelySelectableAndExpansionIsAvailableImmediately() throws {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()

        for candidate in game.foundingCandidatePlots {
            game.selectFoundingPlot(candidate.id)
            XCTAssertEqual(game.tutorialPlotID, candidate.id)
        }

        let foundingPlot = try XCTUnwrap(
            game.foundingCandidatePlots.first(where: { $0.district == .station })
        )
        game.selectFoundingPlot(foundingPlot.id)
        XCTAssertTrue(game.buildStore(
            on: foundingPlot,
            type: .small,
            mode: .lease,
            focus: .young,
            concept: .general,
            loanAmount: 0
        ))
        XCTAssertEqual(game.turn, 0)
        XCTAssertTrue(game.unlockedFeatures.contains("出店"))

        let nextPlot = try XCTUnwrap(game.plots.first { plot in
            guard plot.id != foundingPlot.id, plot.development == nil else { return false }
            if case .available = plot.occupant { return true }
            return false
        })
        XCTAssertTrue(game.canPlanStore(on: nextPlot))
    }

    func testTutorialPerformsBuildPurchaseAndFirstNegotiation() {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        let plot = game.foundingCandidatePlots.first(where: { $0.district == .station })!

        game.selectFoundingPlot(plot.id)
        XCTAssertEqual(game.tutorialStep, .buildStore)
        XCTAssertTrue(game.buildStore(on: plot, type: .small, mode: .lease, focus: .value, concept: .localValue, loanAmount: 0))
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

    func testFoundingInventoryUsesVehicleWholesaleValueAndStaysProfitableAcrossPlans() throws {
        for plan in BusinessProfile.allCases {
            for category in Array(GameEngine().recommendedCategories(for: plan.district).prefix(3)) {
                let game = GameEngine()
                game.resetGame()
                game.startNewGame()
                let preferred = game.foundingCandidatePlots.first(where: { $0.district == plan.district })
                let candidates = ([preferred].compactMap { $0 } + game.plots.filter { $0.district == plan.district })
                let plot = try XCTUnwrap(candidates.first { candidate in
                    guard candidate.district == plan.district, candidate.development == nil else { return false }
                    guard case .available = candidate.occupant else { return false }
                    return game.footprintPlots(startingAt: candidate, type: plan.storeType, mode: .lease).count == plan.storeType.requiredGridCells
                })
                let footprint = game.footprintPlots(startingAt: plot, type: plan.storeType, mode: .lease)
                let facilities = plan.concept.defaultFacilities
                let loan = max(0, game.totalBuildCost(for: footprint, type: plan.storeType, mode: .lease, facilities: facilities) - game.cash)
                game.selectFoundingPlot(plot.id)
                XCTAssertTrue(game.buildStore(
                    on: plot,
                    type: plan.storeType,
                    mode: .lease,
                    focus: plan.focus,
                    concept: plan.concept,
                    loanAmount: loan
                ))
                game.cash = 100_000
                let storeID = try XCTUnwrap(game.stores.first?.id)
                let quotedCost = try XCTUnwrap(game.inventoryPurchaseCost(category: category, count: 3, storeID: storeID))
                let cashBeforePurchase = game.cash

                XCTAssertTrue(game.buyInventory(category: category, count: 3, storeID: storeID))
                XCTAssertEqual(cashBeforePurchase - game.cash, quotedCost)

                for batch in game.stores[0].inventory {
                    let expectedWholesale = game.vehicleWholesaleValue(
                        modelID: batch.modelID,
                        category: batch.category,
                        modelYear: batch.modelYear,
                        mileage: batch.mileage,
                        quality: batch.quality,
                        in: plot.district
                    )
                    XCTAssertEqual(batch.averageCost, expectedWholesale, "\(plan.name): \(batch.vehicleName)")
                    let saleQuote = try XCTUnwrap(game.manualSaleQuote(storeID: storeID, inventoryID: batch.id))
                    let closeDealPrice = Int(Double(saleQuote.price) * (1 - SaleNegotiationStrategy.closeDeal.discountRate))
                    XCTAssertGreaterThanOrEqual(closeDealPrice - batch.averageCost, 0, "\(plan.name): \(batch.vehicleName)")
                }
            }
        }
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
            game.estimatedSales(for: industrial, concept: .outdoor).upperBound,
            game.estimatedSales(for: industrial, concept: .affluent).upperBound
        )
        XCTAssertGreaterThan(
            game.estimatedSales(for: downtown, focus: .affluent, concept: .affluent).upperBound,
            game.estimatedSales(for: downtown, focus: .affluent, concept: .outdoor).upperBound
        )
    }

    func testSegmentFootprintsAndSignatureFacilitiesAreEnforced() throws {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        let plot = try XCTUnwrap(game.foundingCandidatePlots.first(where: { $0.district == .suburb }))
        game.selectFoundingPlot(plot.id)

        XCTAssertFalse(game.buildStore(
            on: plot,
            type: .small,
            mode: .lease,
            focus: .family,
            concept: .family,
            loanAmount: 0
        ))
        XCTAssertTrue(game.buildStore(
            on: plot,
            type: .standard,
            mode: .lease,
            focus: .family,
            concept: .family,
            loanAmount: 0
        ))
        let store = try XCTUnwrap(game.stores.first)
        XCTAssertEqual(store.plotIDs.count, 2)
        XCTAssertTrue(store.facilities.contains(.kidsSpace))
        XCTAssertEqual(store.facilityInvestment, StoreFacility.kidsSpace.installationCost)
    }

    func testBusinessSegmentTargetsCorporateBuyersAndSourcesFleetCars() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .business)
        let store = game.stores[0]

        XCTAssertTrue(store.facilities.contains(.corporateDesk))
        XCTAssertGreaterThan(
            game.buyerAttractionFactor(for: store, category: .commercial),
            game.buyerAttractionFactor(for: store, category: .compact)
        )
        XCTAssertGreaterThan(
            game.sellerAttractionFactor(for: store, category: .compact),
            game.sellerAttractionFactor(for: Store(
                name: "比較店", plotID: store.plotID, type: .standard, acquisition: .lease,
                focus: .value, concept: .general, inventory: []
            ), category: .compact)
        )
        XCTAssertTrue((2...4).contains(game.procurementLotSize(for: store, category: .kei, seed: 11)))
        XCTAssertEqual(game.procurementLotSize(for: store, category: .imported, seed: 11), 1)
    }

    func testUpdatedCatalogUsesHighPriceImportsAndSixHundredClassSUVs() {
        let imports = VehicleCatalog.all.filter { $0.category == .imported && !$0.isRareClassic }
        let suvs = VehicleCatalog.all.filter { $0.category == .suv }
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        let currentImportRetailValues = imports.filter { $0.launchTurn == 0 }.map {
            game.vehicleRetailValue(
                modelID: $0.id,
                category: .imported,
                modelYear: 2028,
                mileage: 32_000,
                quality: 0.86,
                in: .downtown
            )
        }

        XCTAssertEqual(VehicleCategory.allCases.count, 7)
        XCTAssertGreaterThanOrEqual(imports.map(\.referenceRetailPrice).min() ?? 0, 800)
        XCTAssertGreaterThanOrEqual(currentImportRetailValues.min() ?? 0, 800)
        XCTAssertGreaterThanOrEqual(suvs.map(\.referenceRetailPrice).max() ?? 0, 600)
    }

    func testPremiumAuctionKeepsImportedCarsInTheirHighValueWholesaleBand() throws {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        let imports = game.auctionListings.filter { $0.venue == .premium && $0.category == .imported }

        XCTAssertFalse(imports.isEmpty)
        for listing in imports {
            let model = try XCTUnwrap(VehicleCatalog.entry(id: listing.modelID))
            XCTAssertGreaterThanOrEqual(listing.marketPrice, Int(Double(model.baseWholesalePrice) * 0.75))
            XCTAssertGreaterThan(listing.reservePrice, 250)
        }
    }

    func testDealerTradeUsesTheQuotedModelAndItsOwnMarketPrice() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .quality)
        game.cash = 100_000
        let store = try XCTUnwrap(game.stores.first)
        let quote = try XCTUnwrap(game.dealerTradeQuote(category: .imported, count: 3, storeID: store.id))
        let modelID = try XCTUnwrap(quote.modelID)
        let model = try XCTUnwrap(VehicleCatalog.entry(id: modelID))

        XCTAssertEqual(quote.vehicleName, model.fullName)
        XCTAssertGreaterThanOrEqual(quote.unitCost, Int(Double(model.baseWholesalePrice) * 0.78))
        XCTAssertTrue(game.orderDealerTrade(category: .imported, count: 3, storeID: store.id))
        XCTAssertEqual(game.inboundShipments.last?.modelID, modelID)
    }

    func testImportedBuyerStronglyPrefersTheRequestedMakerAndModel() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .quality)
        let storeID = try XCTUnwrap(game.stores.first?.id)
        let exactModel = try XCTUnwrap(VehicleCatalog.entry(id: "nord-velar"))
        let otherModel = try XCTUnwrap(VehicleCatalog.entry(id: "rossa-luce"))
        let exact = InventoryBatch(modelID: exactModel.id, category: .imported, count: 1, averageCost: 520, quality: 0.88, modelYear: 2028, mileage: 24_000, acquiredTurn: game.turn)
        let other = InventoryBatch(modelID: otherModel.id, category: .imported, count: 1, averageCost: 560, quality: 0.88, modelYear: 2028, mileage: 24_000, acquiredTurn: game.turn)
        game.stores[0].inventory.append(contentsOf: [exact, other])
        let lead = BuyerLead(
            id: UUID(), storeID: storeID, preference: .exactModel(exactModel.id),
            budget: 2_000, minimumQuality: 0.82, minimumModelYear: 2026,
            maximumMileage: 50_000, priceSensitivity: 0.8, generatedTurn: game.turn
        )
        game.buyerLeads = [lead]

        let exactPreview = try XCTUnwrap(game.saleNegotiationPreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: exact.id, strategy: .smallDiscount))
        let otherPreview = try XCTUnwrap(game.saleNegotiationPreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: other.id, strategy: .smallDiscount))

        XCTAssertTrue(game.inventoryMatchesBuyer(exact, lead: lead, storeID: storeID))
        XCTAssertFalse(game.inventoryMatchesBuyer(other, lead: lead, storeID: storeID))
        XCTAssertGreaterThan(exactPreview.closeChance, otherPreview.closeChance + 0.45)
    }

    func testEveryGeneratedBuyerHasCategoryMakerOrModelAndOrdinarySegmentsIncludeDetailedRequests() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .family)
        var observed: [BuyerVehiclePreference] = []

        for _ in 0..<8 {
            observed.append(contentsOf: game.buyerLeads.map(\.preference))
            game.advanceWeek()
        }

        XCTAssertFalse(observed.isEmpty)
        XCTAssertFalse(observed.contains { if case .budgetFirst = $0 { return true }; return false })
        XCTAssertTrue(observed.contains { preference in
            guard preference.category != .imported else { return false }
            switch preference {
            case .maker, .exactModel: return true
            case .category, .budgetFirst: return false
            }
        })
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
        game.cash = 100_000
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

    func testAuctionHasExpandedSupplyAndNamesTheCompetitorThatOutbidsPlayer() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let listing = game.auctionListings.first!
        let store = game.stores[0]

        XCTAssertEqual(game.auctionListings.count, 30)
        XCTAssertTrue(game.reserveBid(listingID: listing.id, storeID: store.id, maxPrice: listing.reservePrice))

        game.advanceWeek()

        let result = game.auctionBidResults.first(where: { $0.listingID == listing.id })
        XCTAssertEqual(result?.status, .exceededLimit)
        XCTAssertNotNil(result?.winningCompetitorID)
        XCTAssertNotNil(result.flatMap { game.auctionWinnerName(for: $0) })
        XCTAssertTrue(game.competitorAuctionPurchases.contains { purchase in
            purchase.listingID == listing.id && purchase.competitorID == result?.winningCompetitorID
        })
        XCTAssertEqual(game.auctionListings.count, 30)
    }

    func testAuctionChanceHasNoSeventySixPercentCapAndBidTicksMoveMeaningfully() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let listing = game.auctionListings.max(by: { $0.marketPrice < $1.marketPrice })!
        let store = game.stores[0]
        let district = game.plot(id: store.plotID)!.district
        let retail = game.vehicleRetailValue(
            modelID: listing.modelID,
            category: listing.category,
            modelYear: listing.modelYear,
            mileage: listing.mileage,
            quality: listing.quality,
            in: district
        )
        let step = game.auctionBidStep(for: listing)
        let maximum = max(retail, listing.marketPrice * 3 / 2)
        let highChance = game.auctionBidWinChance(for: listing, maxPrice: maximum)

        XCTAssertGreaterThan(highChance, 0.76)
        XCTAssertGreaterThan(step, 5)

        var largestTickIncrease = 0.0
        var price = listing.reservePrice
        while price + step <= maximum {
            let current = game.auctionBidWinChance(for: listing, maxPrice: price)
            let next = game.auctionBidWinChance(for: listing, maxPrice: price + step)
            largestTickIncrease = max(largestTickIncrease, next - current)
            price += step
        }
        XCTAssertGreaterThan(largestTickIncrease, 0.02)
    }

    func testCompetitorAuctionBidsNeverExceedTheirResaleProfitCeiling() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let listing = game.auctionListings.first!

        for competitor in game.competitors {
            let ceiling = game.competitorAuctionProfitCeiling(for: competitor, listing: listing)
            let retailValues = competitor.plotIDs.compactMap { plotID -> Int? in
                guard let district = game.plot(id: plotID)?.district else { return nil }
                return game.vehicleRetailValue(
                    modelID: listing.modelID,
                    category: listing.category,
                    modelYear: listing.modelYear,
                    mileage: listing.mileage,
                    quality: listing.quality,
                    in: district
                )
            }
            guard let retail = retailValues.max() else {
                XCTAssertEqual(ceiling, 0)
                continue
            }
            XCTAssertLessThan(
                ceiling + listing.venue.fee + listing.venue.shippingCost,
                retail,
                "\(competitor.name)は店頭販売時の粗利を残す"
            )
        }
    }

    func testCompetitorsBuyOnlyProfitableUnopposedAuctionCarsAndResearcherRevealsInventoryTrend() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id

        game.advanceWeek()

        XCTAssertGreaterThan(game.competitorAuctionPurchases.count, 0)
        XCTAssertLessThanOrEqual(game.competitorAuctionPurchases.count, 7)
        let activeCompetitor = try! XCTUnwrap(game.competitors.first {
            !game.recentCompetitorAuctionPurchases(competitorID: $0.id).isEmpty
        })
        XCTAssertFalse(game.hasMarketResearcher(storeID: storeID))
        XCTAssertTrue(game.competitorAuctionTrend(competitorID: activeCompetitor.id, storeID: storeID).contains("市場調査担当"))

        game.stores[0].employees = [StoreEmployee(
            name: "AA調査員", salesSkill: 55, appraisalSkill: 70,
            marketingSkill: 82, marketResearchSkill: 92,
            monthlySalary: 50, assignment: .marketingResearch
        )]

        let trend = game.competitorAuctionTrend(competitorID: activeCompetitor.id, storeID: storeID)
        XCTAssertTrue(game.hasMarketResearcher(storeID: storeID))
        XCTAssertTrue(trend.contains("台増"))
        XCTAssertTrue(trend.contains("最近："))
    }

    func testDealerTradeArrivesAfterOneWeek() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
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
        XCTAssertNotEqual(game.vehicleDemand(.imported, in: .downtown), game.vehicleSupply(.imported, in: .downtown))
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
        XCTAssertEqual(game.weeklyOpportunityCapacity(storeID: storeID), 7)

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

        let employee = StoreEmployee(
            name: "技能テスト", salesSkill: 90, appraisalSkill: 86,
            procurementSkill: 90, marketingSkill: 90, serviceSkill: 90, marketResearchSkill: 90,
            monthlySalary: 50, assignment: .sales
        )
        game.stores[0].employees = [employee]
        game.stores[0].autoSales = true

        XCTAssertGreaterThan(game.employeeSalesCloseAdjustment(for: storeID), 0.05)
        XCTAssertGreaterThanOrEqual(game.employeeAppraisalAccuracyBonus(employee), 10)
        XCTAssertGreaterThan(game.employeeProcurementCloseAdjustment(employee), 0.05)
        XCTAssertEqual(game.weeklyOpportunityCapacity(storeID: storeID), 7)
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

    func testEmployeesGainExperienceFromTheirAutomaticAssignments() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let salesEmployee = StoreEmployee(name: "自動販売", salesSkill: 90, appraisalSkill: 50, monthlySalary: 45, assignment: .sales)
        let procurementEmployee = StoreEmployee(name: "自動仕入", salesSkill: 60, appraisalSkill: 90, procurementSkill: 90, monthlySalary: 45, assignment: .procurement)
        game.stores[0].employees = [salesEmployee, procurementEmployee]
        game.stores[0].autoSales = true
        game.stores[0].autoProcurement = true
        game.stores[0].salesPolicy = .volume
        game.stores[0].procurementPolicy = .volume

        game.advanceWeek()

        let updatedSales = game.stores[0].employees.first(where: { $0.id == salesEmployee.id })!
        let updatedProcurement = game.stores[0].employees.first(where: { $0.id == procurementEmployee.id })!
        XCTAssertGreaterThan(updatedSales.salesExperience, 0)
        XCTAssertGreaterThan(updatedProcurement.procurementExperience, 0)
        XCTAssertGreaterThan(updatedSales.lastWeekPerformance.handled, 0)
        XCTAssertGreaterThan(updatedProcurement.lastWeekPerformance.handled, 0)
    }

    func testSalesSkillEnablesAutomaticAlternativeProposalForUnrelatedInventory() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .family)
        let storeID = game.stores[0].id
        let batch = game.stores[0].inventory[0]
        let desiredCategory = VehicleCategory.allCases.first { $0 != batch.category }!
        let desiredModel = VehicleCatalog.available(through: game.turn).first { $0.category == desiredCategory && !$0.isRareClassic }!
        let lead = BuyerLead(
            id: UUID(), storeID: storeID, preference: .exactModel(desiredModel.id),
            budget: 10_000, minimumQuality: 0.4, minimumModelYear: 2000,
            maximumMileage: 500_000, priceSensitivity: 0.5, generatedTurn: game.turn
        )
        let lowSkill = StoreEmployee(name: "新人営業", salesSkill: 20, appraisalSkill: 40, monthlySalary: 30, assignment: .sales)
        let highSkill = StoreEmployee(name: "提案名人", salesSkill: 95, appraisalSkill: 70, marketResearchSkill: 90, monthlySalary: 60, assignment: .sales)

        XCTAssertGreaterThan(
            game.employeeAlternativeProposalAdjustment(highSkill, lead: lead, batch: batch),
            game.employeeAlternativeProposalAdjustment(lowSkill, lead: lead, batch: batch) + 0.25
        )

        game.stores[0].employees = [highSkill]
        game.stores[0].autoSales = true
        game.stores[0].salesPolicy = .volume
        game.buyerLeads = [lead]
        game.advanceWeek()

        XCTAssertEqual(game.stores[0].employees[0].lastWeekPerformance.handled, 1)
    }

    func testEmployeeAutomationWorksWithoutManagerAndRespectsSalesToggle() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let category = game.stores[0].inventory[0].category
        let employee = StoreEmployee(
            name: "自動化テスト", salesSkill: 95, appraisalSkill: 50,
            marketResearchSkill: 95, monthlySalary: 40, assignment: .sales
        )
        game.stores[0].employees = [employee]
        game.stores[0].autoSales = false
        game.buyerLeads = [BuyerLead(id: UUID(), storeID: storeID, preference: .category(category), budget: 10_000, minimumQuality: 0.5, priceSensitivity: 0.5, generatedTurn: game.turn)]

        game.advanceWeek()
        XCTAssertEqual(game.stores[0].employees[0].lastWeekPerformance.handled, 0)
        XCTAssertFalse(game.stores[0].hasManager)

        game.stores[0].autoSales = true
        game.stores[0].salesPolicy = .volume
        game.buyerLeads = (0..<2).map { offset in
            BuyerLead(id: UUID(), storeID: storeID, preference: .category(category), budget: 10_000 + offset, minimumQuality: 0.5, priceSensitivity: 0.5, generatedTurn: game.turn)
        }
        let manuallyHandledLead = game.buyerLeads[0]
        XCTAssertNotNil(game.negotiateManualSale(
            storeID: storeID,
            buyerLeadID: manuallyHandledLead.id,
            inventoryID: game.stores[0].inventory[0].id,
            strategy: .smallDiscount
        ))
        XCTAssertEqual(game.stores[0].manualNegotiationsThisWeek, 1)
        game.advanceWeek()

        XCTAssertEqual(game.stores[0].employees[0].lastWeekPerformance.handled, 1)
        XCTAssertFalse(game.stores[0].hasManager)
    }

    func testAutomaticSalesCommissionUsesOnlyPositiveGrossProfitAndHitsPersonnelCost() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .discount)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let category = game.stores[0].inventory[0].category
        XCTAssertTrue(game.buyInventory(category: category, count: 4, storeID: storeID))
        let employee = StoreEmployee(
            name: "歩合テスト", salesSkill: 95, appraisalSkill: 50,
            marketResearchSkill: 95, monthlySalary: 40, commissionRate: 10, assignment: .sales
        )
        game.stores[0].employees = [employee]
        game.stores[0].autoSales = true
        game.stores[0].salesPolicy = .volume
        game.buyerLeads = (0..<7).map { offset in
            BuyerLead(id: UUID(), storeID: storeID, preference: .category(category), budget: 10_000 + offset, minimumQuality: 0.4, priceSensitivity: 0.5, generatedTurn: game.turn)
        }

        game.advanceWeek()

        let performance = game.stores[0].employees[0].lastWeekPerformance
        XCTAssertGreaterThan(performance.successes, 0)
        XCTAssertGreaterThan(performance.commission, 0)
        XCTAssertLessThanOrEqual(performance.commission, max(0, performance.grossProfit) * 10 / 100)
        XCTAssertLessThan(max(0, performance.grossProfit) * 10 / 100 - performance.commission, performance.successes)
        XCTAssertGreaterThanOrEqual(game.finance.personnel, game.weeklyPersonnelCost(for: game.stores[0]) + performance.commission)
    }

    func testMarketResearchAndMarketingSkillsNarrowForecastAndRaiseAdvertisingEfficiency() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let low = StoreEmployee(
            name: "低調査", salesSkill: 20, appraisalSkill: 20,
            marketingSkill: 20, marketResearchSkill: 20,
            monthlySalary: 28, assignment: .marketingResearch
        )
        game.stores[0].employees = [low]
        game.stores[0].autoMarketing = true
        let lowError = game.marketForecastErrorRate(for: storeID)
        let lowEfficiency = game.employeeMarketingEfficiency(for: storeID, buyers: true)

        game.stores[0].employees = [StoreEmployee(
            name: "高調査", salesSkill: 70, appraisalSkill: 70,
            marketingSkill: 95, marketResearchSkill: 95,
            monthlySalary: 60, assignment: .marketingResearch
        )]

        XCTAssertLessThan(game.marketForecastErrorRate(for: storeID), lowError)
        XCTAssertGreaterThan(game.employeeMarketingEfficiency(for: storeID, buyers: true), lowEfficiency)
        let range = game.marketForecastRange(value: 1_000, storeID: storeID)
        XCTAssertLessThan(range.upperBound - range.lowerBound, 100)
    }

    func testNewStoreHasNoReviewsUntilActualVisitorsAreHandledOrLeave() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let visitors = game.stores[0].buyerArrivalsThisWeek + game.stores[0].sellerArrivalsThisWeek

        XCTAssertGreaterThan(visitors, 0)
        XCTAssertEqual(game.stores[0].reviewCount, 0)
        XCTAssertNil(game.stores[0].reviewRating)
        XCTAssertEqual(game.stores[0].reviewRatingText, "未評価")

        game.advanceWeek()

        XCTAssertEqual(game.stores[0].reviewCount, visitors)
        XCTAssertTrue(game.stores[0].customerReviews.allSatisfy { $0.serviceScore == 20 })
    }

    func testPayingTooMuchForCustomerCarRaisesPurchaseReviewDespitePoorEconomics() {
        func purchaseScore(offerPercent: Int) -> (score: Int, attraction: Double) {
            let game = GameEngine()
            game.resetGame()
            startPlayableGame(game)
            game.cash = 100_000
            let item = game.purchaseCases.first!
            _ = game.negotiatePurchaseCase(item.id, offerPercent: offerPercent)
            return (
                game.stores[0].reviewScore(for: .purchaseOffer)!,
                game.stores[0].customerReviewAttraction(for: .seller)
            )
        }

        let highOffer = purchaseScore(offerPercent: 100)
        let lowOffer = purchaseScore(offerPercent: 85)

        XCTAssertGreaterThan(highOffer.score, lowOffer.score + 40)
        XCTAssertGreaterThan(highOffer.attraction, lowOffer.attraction)
    }

    func testHighRetailPriceCreatesLowerPriceReview() {
        func priceScore(priceIndex: Double) -> Int {
            let game = GameEngine()
            game.resetGame()
            startPlayableGame(game)
            game.cash = 100_000
            game.stores[0].priceIndex = priceIndex
            let lead = game.buyerLeads.first { $0.storeID == game.stores[0].id }!
            let batch = game.stores[0].inventory.first!
            _ = game.negotiateManualSale(
                storeID: game.stores[0].id,
                buyerLeadID: lead.id,
                inventoryID: batch.id,
                strategy: .holdPrice
            )
            return game.stores[0].reviewScore(for: .salesPrice)!
        }

        XCTAssertGreaterThan(priceScore(priceIndex: 0.88), priceScore(priceIndex: 1.18) + 20)
    }

    func testBuyerReviewsChangeFutureMarketShareBeyondLocation() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let baseline = game.marketShare(for: game.stores[0])

        game.stores[0].customerReviews = (0..<10).map { index in
            CustomerReview(
                customerID: UUID(),
                createdTurn: index,
                channel: .buyer,
                salesPriceScore: 95,
                vehicleScore: 95,
                serviceScore: 95,
                overallScore: 95,
                comment: "高評価"
            )
        }
        let positiveShare = game.marketShare(for: game.stores[0])

        game.stores[0].customerReviews = (0..<10).map { index in
            CustomerReview(
                customerID: UUID(),
                createdTurn: index,
                channel: .buyer,
                salesPriceScore: 25,
                vehicleScore: 25,
                serviceScore: 25,
                overallScore: 25,
                comment: "低評価"
            )
        }
        let negativeShare = game.marketShare(for: game.stores[0])

        XCTAssertEqual(game.stores[0].id, storeID)
        XCTAssertGreaterThan(positiveShare, baseline)
        XCTAssertLessThan(negativeShare, baseline)
    }

    func testMarketResearchSkillExtendsForecastFromOneToThreeWeeksAndSeesEventsEarlier() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let model = VehicleCatalog.all.first!

        let ownerReport = game.marketIntelligence(for: storeID)
        let ownerForecast = game.vehicleMarketForecast(for: model, in: .suburb, storeID: storeID)
        XCTAssertEqual(ownerReport.horizonWeeks, 1)

        let low = StoreEmployee(
            name: "低調査", salesSkill: 30, appraisalSkill: 30,
            marketingSkill: 30, marketResearchSkill: 20,
            monthlySalary: 30, assignment: .marketingResearch
        )
        game.stores[0].employees = [low]
        XCTAssertEqual(game.marketIntelligence(for: storeID).horizonWeeks, 2)

        let high = StoreEmployee(
            name: "市場分析主任", salesSkill: 70, appraisalSkill: 80,
            marketingSkill: 92, marketResearchSkill: 95,
            monthlySalary: 62, assignment: .marketingResearch
        )
        game.stores[0].employees = [high]
        let highReport = game.marketIntelligence(for: storeID)
        let highForecast = game.vehicleMarketForecast(for: model, in: .suburb, storeID: storeID)
        XCTAssertEqual(highReport.horizonWeeks, 3)
        XCTAssertGreaterThan(highReport.accuracyPercent, ownerReport.accuracyPercent)
        XCTAssertLessThan(
            highForecast.retailPriceRange.upperBound - highForecast.retailPriceRange.lowerBound,
            ownerForecast.retailPriceRange.upperBound - ownerForecast.retailPriceRange.lowerBound
        )

        var foundThreeWeekOnlySignal = false
        for candidateTurn in 4..<game.maxTurns {
            game.turn = candidateTurn
            game.stores[0].employees = [high]
            let highEvent = game.marketIntelligence(for: storeID).upcomingEvent
            game.stores[0].employees = [low]
            let lowEvent = game.marketIntelligence(for: storeID).upcomingEvent
            if highEvent != nil && lowEvent == nil {
                foundThreeWeekOnlySignal = true
                break
            }
        }
        XCTAssertTrue(foundThreeWeekOnlySignal, "高能力者は3週目に起きる大型イベントを低能力者より先に把握する")
    }

    func testHighSkillServiceEmployeeAutomaticallyProcessesThreeVehicles() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        for index in game.stores[0].inventory.indices {
            game.stores[0].inventory[index].quality = 0.50
        }
        let employee = StoreEmployee(
            name: "整備主任", salesSkill: 50, appraisalSkill: 90,
            serviceSkill: 90, monthlySalary: 55, assignment: .service
        )
        game.stores[0].employees = [employee]
        game.stores[0].autoService = true
        game.stores[0].servicePolicy = .quality

        game.advanceWeek()

        XCTAssertEqual(game.stores[0].employees[0].lastWeekPerformance.servicesCompleted, 3)
        XCTAssertGreaterThanOrEqual(game.stores[0].inventory.filter { $0.quality > 0.50 }.count, 3)
    }

    func testAssignedServiceTechnicianMakesOrdinaryServiceFree() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let pendingPurchase = game.purchaseCases.first!
        game.stores[0].employees = [StoreEmployee(
            name: "社内整備士", salesSkill: 40, appraisalSkill: 72,
            serviceSkill: 82, monthlySalary: 52, assignment: .service
        )]
        game.stores[0].inventory[0].quality = 0.60
        let batch = game.stores[0].inventory[0]
        let preview = try! XCTUnwrap(game.servicePreview(storeID: storeID, inventoryID: batch.id))
        let beforeCash = game.cash

        XCTAssertEqual(preview.cost, 0)
        XCTAssertEqual(game.purchaseRepairCost(for: pendingPurchase), 0)
        XCTAssertTrue(game.serviceInventory(storeID: storeID, inventoryID: batch.id))
        XCTAssertEqual(game.cash, beforeCash)
        XCTAssertEqual(game.stores[0].inventory.first(where: { $0.id == batch.id })?.averageCost, batch.averageCost)
    }

    func testHighSkillAppraiserFindsBadPurchaseAndAutomaticallyAvoidsOverpaying() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let appraiser = StoreEmployee(
            name: "査定主任", salesSkill: 60, appraisalSkill: 95,
            procurementSkill: 90, marketResearchSkill: 90,
            monthlySalary: 60, assignment: .procurement
        )
        game.stores[0].employees = [appraiser]
        game.stores[0].autoProcurement = true
        game.stores[0].procurementPolicy = .balanced
        XCTAssertGreaterThanOrEqual(game.employeeAppraisalAccuracyBonus(for: storeID), 14)

        let model = VehicleCatalog.all.first!
        let modelYear = game.year - 3
        let mileage = stride(from: 20_000, through: 90_000, by: 1_000).first { mileage in
            let seed = game.turn * 263 + modelYear * 7 + mileage / 1_000 + 113
            let raw = abs((seed &* 1_664_525 &+ 1_013_904_223) % 10_000)
            return Double(raw) / 10_000.0 < 0.94
        }!
        let badCase = PurchaseCase(
            id: UUID(), storeID: storeID, modelID: model.id, category: model.category,
            lotCount: 1, modelYear: modelYear, mileage: mileage,
            exterior: 76, interior: 78, mechanical: 74,
            askingPrice: 120, appraisedPrice: 112, repairCost: 5,
            expectedSalePrice: 140, expectedDays: 22, demand: 1.0,
            appraisalAccuracy: 55, negotiationAttempts: 0,
            hiddenIssue: .repairedHistory, issueRevealed: false
        )
        game.purchaseCases = [badCase]
        let inventoryBefore = game.stores[0].inventoryCount

        game.advanceWeek()

        XCTAssertEqual(game.stores[0].inventoryCount, inventoryBefore)
        XCTAssertFalse(game.purchaseCases.contains { $0.id == badCase.id })
        XCTAssertEqual(game.stores[0].employees[0].lastWeekPerformance.issuesFound, 1)
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
        store.autoSales = true
        store.autoProcurement = true
        store.autoMarketing = true
        store.autoService = true
        store.salesPolicy = .profit
        game.updateStore(store)

        XCTAssertTrue(game.fireManager(for: storeID))
        XCTAssertFalse(game.stores[0].hasManager)
        XCTAssertNil(game.stores[0].manager)
        XCTAssertFalse(game.stores[0].delegateStaff)
        XCTAssertFalse(game.stores[0].delegatePricing)
        XCTAssertFalse(game.stores[0].delegateProcurement)
        XCTAssertFalse(game.stores[0].delegateMarketing)
        XCTAssertFalse(game.stores[0].delegateService)
        XCTAssertTrue(game.stores[0].autoSales)
        XCTAssertTrue(game.stores[0].autoProcurement)
        XCTAssertTrue(game.stores[0].autoMarketing)
        XCTAssertTrue(game.stores[0].autoService)
        XCTAssertEqual(game.stores[0].salesPolicy, .profit)
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
            concept: .localValue,
            loanAmount: 100_000
        ))
        let newStore = game.store(at: plot.id)!
        XCTAssertEqual(newStore.type, .small)
        XCTAssertEqual(newStore.openingMonthsRemaining, 1)
        XCTAssertEqual(
            game.plot(id: newStore.plotID)?.currentUse,
            .construction(storeID: newStore.id, targetAssetID: .playerSmallDealer)
        )
        XCTAssertEqual(game.gridOccupancyIssues, [])

        game.advanceWeek()
        XCTAssertNil(game.store(at: plot.id)?.openingMonthsRemaining)
        XCTAssertEqual(
            game.plot(id: newStore.plotID)?.currentUse,
            .playerFacility(storeID: newStore.id, assetID: .playerSmallDealer)
        )

        XCTAssertTrue(game.renovateStore(newStore.id, to: .roadside))
        XCTAssertEqual(game.gridOccupancyIssues, [])
        XCTAssertEqual(game.store(at: plot.id)?.type, .small)
        XCTAssertEqual(game.store(at: plot.id)?.pendingType, .roadside)
        XCTAssertEqual(
            game.plot(id: newStore.plotID)?.currentUse,
            .construction(storeID: newStore.id, targetAssetID: .playerLargeDealer)
        )
        game.advanceWeek()
        game.advanceWeek()
        XCTAssertEqual(game.store(at: plot.id)?.type, .roadside)
        let renovatedStore = game.store(at: plot.id)!
        XCTAssertEqual(
            game.plot(id: renovatedStore.plotID)?.currentUse,
            .playerFacility(storeID: renovatedStore.id, assetID: .playerLargeDealer)
        )
        for plotID in renovatedStore.plotIDs where plotID != renovatedStore.plotID {
            XCTAssertEqual(
                game.plot(id: plotID)?.currentUse,
                .displayParking(storeID: renovatedStore.id)
            )
        }

        game.closeStore(newStore.id)
        XCTAssertNil(game.store(at: plot.id))
        XCTAssertEqual(game.gridOccupancyIssues, [])
        for plotID in renovatedStore.plotIDs {
            XCTAssertEqual(game.plot(id: plotID)?.currentUse, .vacant)
        }
        if case .available = game.plot(id: plot.id)?.occupant {
            // The dynamic map layer now has no building to draw on this lot.
        } else {
            XCTFail("Closed store plot should become available")
        }
    }

    func testConstructionParcelUsePersistsAcrossReload() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let plot = game.plots.first(where: {
            game.footprintPlots(startingAt: $0, type: .small).count == 1
        })!

        XCTAssertTrue(game.buildStore(
            on: plot,
            type: .small,
            mode: .lease,
            focus: .value,
            concept: .general,
            loanAmount: 100_000
        ))
        let store = game.store(at: plot.id)!

        let reloaded = GameEngine()
        reloaded.loadGame()
        XCTAssertEqual(
            reloaded.plot(id: plot.id)?.currentUse,
            .construction(storeID: store.id, targetAssetID: .playerSmallDealer)
        )
        reloaded.resetGame()
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
        XCTAssertEqual(game.year, 2026)
        XCTAssertEqual(game.month, 1)
        XCTAssertEqual(game.weekOfMonth, 1)

        for _ in 0..<3 { game.advanceWeek() }
        XCTAssertEqual(game.month, 1)
        XCTAssertEqual(game.weekOfMonth, 4)

        game.advanceWeek()
        XCTAssertEqual(game.month, 2)
        XCTAssertEqual(game.weekOfMonth, 1)
    }

    func testManagerDelegationDoesNotBlockOwnerManualSales() {
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
        XCTAssertTrue(game.canSellManually(storeID: store.id))
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
        XCTAssertTrue(game.buildStore(on: secondPlot, type: .small, mode: .lease, focus: .value, concept: .localValue, loanAmount: 0))
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
        XCTAssertEqual(game.weeklyOpportunityCapacity(storeID: storeID), 7)
        XCTAssertEqual(game.remainingWeeklyOpportunities(storeID: storeID), 6)
        XCTAssertFalse(game.canSellManually(storeID: storeID))
    }

    func testManagerControlsPoliciesWithoutTakingOwnerCases() {
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
        XCTAssertTrue(game.canSellManually(storeID: storeID))

        store = game.stores[0]
        store.delegateProcurement = true
        game.updateStore(store)
        XCTAssertTrue(game.canNegotiatePurchaseCase(purchaseCase.id))
        if case .unavailable = game.negotiatePurchaseCase(purchaseCase.id, offerPercent: 100) {
            XCTFail("Management delegation must not take the case away from the owner")
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
        let expectedMakers: Set<String> = ["アオバ", "ホシノ", "コーヨー", "セイカ", "ヒノデ", "ホクト", "ヤマト", "ノルド", "ヴォルトラ", "ロッサ"]

        XCTAssertEqual(annualModels.count, 100)
        for yearIndex in 0..<10 {
            let releases = annualModels.filter { ($0.launchTurn / 48) == yearIndex }
            XCTAssertEqual(releases.count, expectedMakers.count)
            XCTAssertEqual(Set(releases.map(\.maker)), expectedMakers)
        }
    }

    func testAnnualModelsWaitBeforeAppearingInUsedMarketAndStartWithLowSupply() {
        let model = try! XCTUnwrap(VehicleCatalog.entry(id: "annual-aoba-2026"))
        let game = GameEngine()
        game.resetGame()

        XCTAssertTrue(VehicleCatalog.releasedNewCars(through: model.launchTurn).contains { $0.id == model.id })
        XCTAssertFalse(VehicleCatalog.available(through: model.usedMarketTurn - 1).contains { $0.id == model.id })
        XCTAssertTrue(VehicleCatalog.available(through: model.usedMarketTurn).contains { $0.id == model.id })
        XCTAssertTrue((12...18).contains(model.usedMarketDelayWeeks))

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

    func testMarketConditionsStartAtFamiliarBaselinesAndMoveSmoothly() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)

        XCTAssertEqual(game.gasolinePricePerLiter, 155)
        XCTAssertEqual(game.nikkeiAverageYen, 60_000)
        XCTAssertEqual(game.marketDemandPercentage, 100)
        XCTAssertEqual(game.customerTrafficPercentage, 100)

        let previousGasoline = game.gasolinePrice
        let previousNikkei = game.nikkeiAverage
        let previousDemand = game.marketDemandIndex
        game.advanceWeek()

        XCTAssertLessThan(abs(game.gasolinePrice - previousGasoline), 2)
        XCTAssertLessThan(abs(game.nikkeiAverage - previousNikkei), 1_000)
        XCTAssertLessThan(abs(game.marketDemandIndex - previousDemand), 0.02)
        XCTAssertTrue((105.0...205.0).contains(game.gasolinePrice))
        XCTAssertTrue((15_000.0...120_000.0).contains(game.nikkeiAverage))
    }

    func testWarEventCreatesAVisibleMultiWeekMarketShock() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.activeMarketShocks = [ActiveMarketShock(kind: .war)]

        let previousGasoline = game.gasolinePrice
        let previousNikkei = game.nikkeiAverage
        let previousDemand = game.marketDemandIndex
        game.advanceWeek()

        XCTAssertGreaterThan(game.gasolinePrice, previousGasoline + 2.5)
        XCTAssertLessThan(game.nikkeiAverage, previousNikkei - 2_000)
        XCTAssertLessThan(game.marketDemandIndex, previousDemand)
        XCTAssertEqual(game.activeMarketShocks.first?.remainingWeeks, MarketShockKind.war.durationWeeks - 1)
    }

    func testOilEventsRepresentDemandGrowthAndProductionHalt() {
        XCTAssertGreaterThan(MarketShockKind.oilDemandSurge.gasolineWeeklyChange, 0)
        XCTAssertGreaterThan(MarketShockKind.oilProductionHalt.gasolineWeeklyChange, MarketShockKind.oilDemandSurge.gasolineWeeklyChange)
        XCTAssertEqual(MarketShockKind.oilDemandSurge.eventKind, .fuelPrice)
        XCTAssertEqual(MarketShockKind.oilProductionHalt.eventKind, .fuelPrice)
    }

    func testCatalogMarketInformationChangesReferencePricesByRegion() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let model = VehicleCatalog.all.first(where: { $0.category == .imported })!

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
        XCTAssertEqual(VehicleCatalog.rareClassics.count, 3)
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
        game.stores[0].facilities.insert(.customWorkshop)
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
        game.stores[0].facilities.insert(.customWorkshop)
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

    func testCamperConversionRequiresWorkshopAndMinivan() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let minivan = InventoryBatch(
            modelID: "hinode-familia", category: .minivan, count: 1,
            averageCost: 180, quality: 0.76, modelYear: 2026,
            mileage: 42_000, acquiredTurn: game.turn
        )
        game.stores[0].inventory.append(minivan)

        XCTAssertNil(game.workshopProjectPreview(storeID: storeID, inventoryID: minivan.id, kind: .camperConversion))
        game.stores[0].facilities.insert(.customWorkshop)
        let preview = game.workshopProjectPreview(storeID: storeID, inventoryID: minivan.id, kind: .camperConversion)
        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.weeks, 5)
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
        let original = VehicleCatalog.all.first(where: { $0.id == "nord-velar" })!
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
            lotCount: 1,
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
        XCTAssertEqual(game.year, 2026)
        XCTAssertEqual(game.month, 1)
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
        startPlayableGame(game)
        game.cash = 6_123
        game.fuelPriceIndex = 1.27
        game.economicIndex = 1.15
        game.activeMarketShocks = [ActiveMarketShock(kind: .oilProductionHalt, remainingWeeks: 5)]
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
        game.stores[0].employees = [StoreEmployee(
            name: "保存テスト", salesSkill: 88, appraisalSkill: 77,
            procurementSkill: 75, marketingSkill: 70, serviceSkill: 69, marketResearchSkill: 91,
            monthlySalary: 44, commissionRate: 10, assignment: .sales,
            recentCommissions: [1, 2, 3]
        )]
        game.stores[0].autoSales = true
        game.stores[0].autoMarketing = true
        game.stores[0].salesPolicy = .profit

        game.returnToTitle()
        XCTAssertFalse(game.hasStarted)
        XCTAssertTrue(game.hasSaveData)

        game.cash = 1
        game.economicIndex = 0.72
        game.activeMarketShocks = []
        game.loadGame()
        XCTAssertTrue(game.hasStarted)
        XCTAssertEqual(game.cash, 6_123)
        XCTAssertEqual(game.fuelPriceIndex, 1.27, accuracy: 0.001)
        XCTAssertEqual(game.economicIndex, 1.15, accuracy: 0.001)
        XCTAssertEqual(game.activeMarketShocks.first?.kind, .oilProductionHalt)
        XCTAssertEqual(game.activeMarketShocks.first?.remainingWeeks, 5)
        XCTAssertEqual(game.careerStatistics.totalSales, 123)
        XCTAssertTrue(game.careerStatistics.completedMilestones.contains(.salesFoundation))
        XCTAssertEqual(game.priceWarChallenges.first?.response, .brandDefense)
        XCTAssertTrue(game.stores[0].autoSales)
        XCTAssertTrue(game.stores[0].autoMarketing)
        XCTAssertEqual(game.stores[0].salesPolicy, .profit)
        XCTAssertEqual(game.stores[0].employees[0].assignment, .sales)
        XCTAssertEqual(game.stores[0].employees[0].marketResearchSkill, 91)
        XCTAssertEqual(game.stores[0].employees[0].commissionRate, 10)
        XCTAssertEqual(game.stores[0].employees[0].recentCommissions, [1, 2, 3])
    }
}
