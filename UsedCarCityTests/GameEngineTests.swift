import XCTest
@testable import UsedCarCity

@MainActor
final class GameEngineTests: XCTestCase {
    private struct BalanceSnapshot {
        let cash: Int
        let companyValue: Int
        let sales: Int
        let survived: Bool
        let maximumShare: Double
    }

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
            case .discount: .standard
            case .quality: .standard
            }
        }
        var purpose: CustomerPurpose {
            switch self {
            case .family: .family
            case .discount, .quality: .general
            case .business: .corporate
            }
        }
        var categories: Set<VehicleCategory> {
            switch self {
            case .family: [.kei, .compact, .minivan]
            case .discount: [.kei, .compact]
            case .quality: [.sedan, .suv]
            case .business: [.minivan, .pickup]
            }
        }
        var facilities: Set<StoreFacility> {
            switch self {
            case .family: [.kidsSpace]
            case .discount: [.serviceWorkshop]
            case .quality: [.importLounge]
            case .business: [.corporateDesk]
            }
        }
    }

    private func startPlayableGame(
        _ game: GameEngine,
        plan: BusinessProfile = .family,
        simulationSeed: Int? = nil
    ) {
        game.startNewGame(simulationSeed: simulationSeed)
        let preferred = game.foundingCandidatePlots.first(where: { $0.district == plan.district })
        let candidates = ([preferred].compactMap { $0 } + game.plots.filter { $0.district == plan.district })
        let plot = candidates.first { candidate in
            guard candidate.district == plan.district, candidate.development == nil else { return false }
            guard case .available = candidate.occupant else { return false }
            return game.footprintPlots(startingAt: candidate, type: plan.storeType, mode: .lease).count == plan.storeType.requiredGridCells
        }!
        let footprint = game.footprintPlots(startingAt: plot, type: plan.storeType, mode: .lease)
        let facilities = plan.facilities
        let totalBuildCost = game.totalBuildCost(for: footprint, type: plan.storeType, mode: .lease, facilities: facilities)
        let openingWorkingCapital = 2_500
        let loan = max(0, totalBuildCost + openingWorkingCapital - game.cash)
        game.selectFoundingPlot(plot.id)
        XCTAssertTrue(game.buildStore(
            on: plot,
            type: plan.storeType,
            mode: .lease,
            marketPolicy: StoreMarketPolicy(priorityCategories: plan.categories, targetPurpose: plan.purpose),
            facilities: facilities,
            loanAmount: loan
        ))
        let store = game.stores[0]
        for category in game.recommendedCategories(for: plot.district).prefix(2) {
            XCTAssertTrue(game.buyInventory(category: category, count: 2, storeID: store.id))
        }
        game.completeTutorial()
    }

    private func runBalanceScenario(
        plan: BusinessProfile,
        capital: Int,
        policy: StoreMarketPolicy,
        employeeScale: Int,
        advertising: Int,
        openingInventoryTarget: Int,
        scenarioSeed: Int,
        weeks: Int = 52
    ) -> BalanceSnapshot {
        let game = GameEngine()
        game.resetGame(simulationSeed: scenarioSeed)
        startPlayableGame(game, plan: plan, simulationSeed: scenarioSeed)
        game.cash = capital
        game.stores[0].marketPolicy = policy
        game.stores[0].pendingMarketPolicy = nil
        game.stores[0].advertising = advertising
        let roles: [EmployeeAssignment] = [.sales, .procurement, .research, .service]
        game.stores[0].employees = (0..<employeeScale).map { index in
            let role = roles[index % roles.count]
            return StoreEmployee(
                name: "固定\(scenarioSeed)-\(index)",
                salesSkill: 72 + (scenarioSeed + index * 3) % 18,
                procurementSkill: 72 + (scenarioSeed * 2 + index * 5) % 18,
                researchSkill: 70 + (scenarioSeed * 3 + index * 7) % 18,
                serviceSkill: 70 + (scenarioSeed * 5 + index * 2) % 18,
                monthlySalary: 40, assignment: role
            )
        }
        game.stores[0].autoSales = true
        game.stores[0].autoProcurement = true
        game.stores[0].autoMarketing = true
        game.stores[0].autoService = true
        game.stores[0].salesPolicy = .balanced
        game.stores[0].servicePolicy = .balanced

        let stockingOrder = policy.priorityCategories.isEmpty
            ? VehicleCategory.allCases
            : policy.priorityCategories.sorted { $0.rawValue < $1.rawValue }
        var orderIndex = scenarioSeed
        while game.stores[0].inventoryCount < openingInventoryTarget {
            let category = stockingOrder[orderIndex % stockingOrder.count]
            let count = min(3, openingInventoryTarget - game.stores[0].inventoryCount)
            guard game.buyInventory(category: category, count: count, storeID: game.stores[0].id) else { break }
            orderIndex += 1
        }

        for _ in 0..<weeks where !game.gameOver { game.advanceWeek() }
        return BalanceSnapshot(
            cash: game.cash,
            companyValue: game.companyValue,
            sales: game.reports.reduce(0) { $0 + $1.sales },
            survived: !game.gameOver && game.turn >= weeks,
            maximumShare: game.stores.map { game.marketShare(for: $0) }.max() ?? 0
        )
    }

    func testNewGameCreatesSixCoastalDistrictsWithDerivedPlots() {
        let game = GameEngine()
        game.resetGame()
        let map = CityMapDefinition.suihama
        XCTAssertEqual(game.plots.count, 179)
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
        XCTAssertTrue(game.buildStore(on: plot, type: .standard, mode: .lease, marketPolicy: StoreMarketPolicy(priorityCategories: [.minivan], targetPurpose: .family), facilities: [.kidsSpace], loanAmount: 0))

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

        XCTAssertTrue(game.buildStore(on: plot, type: .roadside, mode: .purchase, marketPolicy: StoreMarketPolicy(priorityCategories: [.minivan, .pickup], targetPurpose: .corporate), facilities: [.corporateDesk], loanAmount: 0))
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
            marketPolicy: StoreMarketPolicy(),
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
        XCTAssertTrue(game.buildStore(on: plot, type: .small, mode: .lease, marketPolicy: StoreMarketPolicy(priorityCategories: [.kei, .compact]), loanAmount: 0))
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
                let facilities = plan.facilities
                let loan = max(0, game.totalBuildCost(for: footprint, type: plan.storeType, mode: .lease, facilities: facilities) - game.cash)
                game.selectFoundingPlot(plot.id)
                XCTAssertTrue(game.buildStore(
                    on: plot,
                    type: plan.storeType,
                    mode: .lease,
                    marketPolicy: StoreMarketPolicy(priorityCategories: plan.categories, targetPurpose: plan.purpose),
                    facilities: facilities,
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
                    // 同一カテゴリをまとめて買うと需給が動くため、後続車の現在相場は
                    // 約定時の原価より高くなり得る。保存原価が現在相場以下であることを確認する。
                    XCTAssertLessThanOrEqual(batch.averageCost, expectedWholesale, "\(plan.name): \(batch.vehicleName)")
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

    func testWeeklyReportHasStructuredSalesSummaryAndAlwaysOpensNewspaper() throws {
        let game = GameEngine(persistenceEnabled: false)
        game.resetGame(simulationSeed: 31)
        startPlayableGame(game, plan: .discount, simulationSeed: 31)

        game.advanceWeek()

        let summary = try XCTUnwrap(game.lastReport?.salesSummary)
        XCTAssertEqual(summary.sales, game.lastReport?.sales)
        XCTAssertGreaterThanOrEqual(summary.negotiations, summary.sales)
        XCTAssertGreaterThanOrEqual(summary.missedBuyers, 0)
        XCTAssertGreaterThanOrEqual(summary.claimCost, 0)
        XCTAssertEqual(game.weeklyPresentationStage, .newspaper)
    }

    func testWeeklyPresentationRunsReportThenMonthlyPLThenNewspaper() {
        let game = GameEngine(persistenceEnabled: false)

        game.beginWeeklyPresentationSequence(
            includesWeeklyReport: true,
            includesMonthlyPL: true
        )
        XCTAssertEqual(game.weeklyPresentationStage, .weeklyReport)

        game.advanceWeeklyPresentationSequence()
        XCTAssertEqual(game.weeklyPresentationStage, .monthlyPL)

        game.advanceWeeklyPresentationSequence()
        XCTAssertEqual(game.weeklyPresentationStage, .newspaper)

        game.advanceWeeklyPresentationSequence()
        XCTAssertNil(game.weeklyPresentationStage)
    }

    func testFourthWeekCreatesMonthlyPLFromFourWeeklyReports() throws {
        let game = GameEngine(persistenceEnabled: false)
        game.resetGame(simulationSeed: 41)
        startPlayableGame(game, plan: .discount, simulationSeed: 41)
        game.cash = 100_000

        for _ in 0..<4 { game.advanceWeek() }

        let monthly = try XCTUnwrap(game.lastMonthlyReport)
        XCTAssertEqual(game.monthlyReports.count, 1)
        XCTAssertEqual(monthly.year, 2026)
        XCTAssertEqual(monthly.month, 1)
        XCTAssertEqual(monthly.weeklyReports.map(\.week), [1, 2, 3, 4])
        XCTAssertEqual(monthly.sales, monthly.weeklyReports.reduce(0) { $0 + $1.sales })
        XCTAssertEqual(monthly.revenue, monthly.weeklyReports.reduce(0) { $0 + $1.revenue })
        XCTAssertEqual(monthly.costOfSales, monthly.weeklyReports.reduce(0) { $0 + $1.costOfSales })
        XCTAssertEqual(monthly.operatingProfit, monthly.weeklyReports.reduce(0) { $0 + $1.operatingProfit })
        XCTAssertEqual(monthly.cashChange, monthly.weeklyReports.reduce(0) { $0 + $1.cashChange })
        XCTAssertEqual(game.month, 2)
        XCTAssertEqual(game.weekOfMonth, 1)
    }

    func testWeeklyComparisonReportsChangesFromPreviousWeek() throws {
        let game = GameEngine(persistenceEnabled: false)
        game.resetGame(simulationSeed: 73)
        startPlayableGame(game, plan: .discount, simulationSeed: 73)
        game.cash = 100_000

        game.advanceWeek()
        game.advanceWeek()

        let current = try XCTUnwrap(game.reports.first)
        let previous = try XCTUnwrap(game.reports.dropFirst().first)
        let comparison = try XCTUnwrap(game.weeklyComparison(for: current))
        XCTAssertEqual(comparison.sales, current.sales - previous.sales)
        XCTAssertEqual(comparison.revenue, current.revenue - previous.revenue)
        XCTAssertEqual(comparison.operatingProfit, current.operatingProfit - previous.operatingProfit)
        XCTAssertEqual(comparison.cashChange, current.cashChange - previous.cashChange)
        XCTAssertEqual(
            comparison.averageInventoryWeeks,
            current.averageInventoryWeeks - previous.averageInventoryWeeks,
            accuracy: 0.001
        )
    }

    func testEstablishedSpecialtyBrandGainsFirstMoverAttractionDuringBoom() throws {
        let game = GameEngine(persistenceEnabled: false)
        game.resetGame(simulationSeed: 97)
        startPlayableGame(game, simulationSeed: 97)
        let storeID = try XCTUnwrap(game.stores.first?.id)
        let district = try XCTUnwrap(game.plot(id: game.stores[0].plotID)?.district)
        let key = MarketSegmentKey(
            district: district,
            category: .minivan,
            purpose: .camper,
            productKind: .camper
        )
        let baseline = game.specialtyBrandAttractionMultiplier(for: game.stores[0], key: key)

        game.stores[0].expertise.productization[.camperConversion] = 100
        game.stores[0].advertising = 500
        game.stores[0].reputation = 1.20
        game.segmentTrends = [
            SegmentTrend(
                kind: .campingBoom,
                districts: [district],
                categories: [.minivan],
                startTurn: game.turn,
                peakWeeks: 8,
                peakMultiplier: 2.2
            )
        ]

        let profile = game.specialtyBrandProfile(for: game.stores[0], productKind: .camper)
        let boosted = game.specialtyBrandAttractionMultiplier(for: game.stores[0], key: key)
        XCTAssertEqual(game.stores[0].id, storeID)
        XCTAssertGreaterThan(profile.recognition, 40)
        XCTAssertGreaterThan(profile.firstMoverBonusPercent, 0)
        XCTAssertGreaterThan(boosted, baseline)
        XCTAssertGreaterThan(boosted, 1)
    }

    func testMarketPolicyChangesLocationFit() {
        let game = GameEngine()
        game.resetGame()
        let industrial = game.plots.first(where: { $0.district == .industrial })!
        let downtown = game.plots.first(where: { $0.district == .downtown })!

        XCTAssertGreaterThan(
            game.estimatedSales(for: industrial, marketPolicy: StoreMarketPolicy(priorityCategories: [.minivan, .pickup], targetPurpose: .work)).upperBound,
            game.estimatedSales(for: industrial, marketPolicy: StoreMarketPolicy(priorityCategories: [.sports], targetPurpose: .general)).upperBound
        )
        XCTAssertGreaterThan(
            game.estimatedSales(for: downtown, marketPolicy: StoreMarketPolicy(priorityCategories: [.sedan, .sports], priorityOrigins: [.imported], targetPurpose: .general)).upperBound,
            game.estimatedSales(for: downtown, marketPolicy: StoreMarketPolicy(priorityCategories: [.pickup], targetPurpose: .work)).upperBound
        )
    }

    func testStorePolicyDoesNotForceAConceptOrSignatureFacility() throws {
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        let plot = try XCTUnwrap(game.foundingCandidatePlots.first(where: { $0.district == .suburb }))
        game.selectFoundingPlot(plot.id)

        XCTAssertTrue(game.buildStore(
            on: plot,
            type: .standard,
            mode: .lease,
            marketPolicy: StoreMarketPolicy(priorityCategories: [.minivan], targetPurpose: .family),
            loanAmount: 0
        ))
        let store = try XCTUnwrap(game.stores.first)
        XCTAssertEqual(store.plotIDs.count, 2)
        XCTAssertTrue(store.facilities.isEmpty)
        game.cash = 10_000
        XCTAssertTrue(game.installFacility(.kidsSpace, at: store.id))
    }

    func testBusinessSegmentTargetsCorporateBuyersAndSourcesFleetCars() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .business)
        let store = game.stores[0]

        XCTAssertTrue(store.facilities.contains(.corporateDesk))
        XCTAssertGreaterThan(
            game.buyerAttractionFactor(for: store, category: .pickup, purpose: .corporate),
            game.buyerAttractionFactor(for: store, category: .pickup, purpose: .family)
        )
        XCTAssertGreaterThan(
            game.sellerAttractionFactor(for: store, category: .pickup),
            game.sellerAttractionFactor(for: Store(
                name: "比較店", plotID: store.plotID, type: .standard, acquisition: .lease,
                marketPolicy: StoreMarketPolicy(), inventory: []
            ), category: .pickup)
        )
        XCTAssertTrue((2...4).contains(game.procurementLotSize(for: store, category: .kei, seed: 11)))
        XCTAssertEqual(game.procurementLotSize(for: store, category: .sports, seed: 11), 1)
    }

    func testSpecialFacilitiesApplyOnlyToTheirDeclaredPurposeOrVehicle() {
        let game = GameEngine()
        game.resetGame()
        let base = Store(
            name: "設備比較店", plotID: 1, type: .standard, acquisition: .lease,
            inventory: []
        )

        var kids = base
        kids.facilities = [.kidsSpace]
        XCTAssertEqual(game.buyerAttractionFactor(for: kids, category: .suv, purpose: .family), 1.18, accuracy: 0.001)
        XCTAssertEqual(game.buyerAttractionFactor(for: kids, category: .suv, purpose: .general), 1.0, accuracy: 0.001)
        XCTAssertEqual(game.facilitySalesCloseBonus(for: kids, category: .compact, purpose: .family), 0.08, accuracy: 0.001)

        var corporate = base
        corporate.facilities = [.corporateDesk]
        XCTAssertEqual(game.buyerAttractionFactor(for: corporate, category: .compact, purpose: .corporate), 1.22, accuracy: 0.001)
        XCTAssertEqual(game.buyerAttractionFactor(for: corporate, category: .compact, purpose: .general), 1.0, accuracy: 0.001)
        XCTAssertEqual(game.facilitySalesCloseBonus(for: corporate, category: .compact, purpose: .work), 0.07, accuracy: 0.001)

        var imports = base
        imports.facilities = [.importLounge]
        XCTAssertEqual(game.buyerAttractionFactor(for: imports, category: .sedan, origin: .imported, purpose: .general), 1.18, accuracy: 0.001)
        XCTAssertEqual(game.buyerAttractionFactor(for: imports, category: .suv, purpose: .general), 1.0, accuracy: 0.001)
        XCTAssertEqual(game.facilitySalesCloseBonus(for: imports, category: .sedan, origin: .imported, purpose: .general), 0.07, accuracy: 0.001)
        XCTAssertEqual(game.facilitySalesCloseBonus(for: imports, category: .suv, purpose: .general), 0, accuracy: 0.001)
    }

    func testHighValueVehiclesAppearInDowntownSellerMix() {
        let game = GameEngine()
        game.resetGame()
        let categories = (0..<1_000).map { game.sellerCategory(in: .downtown, seed: $0 * 97 + 13) }

        XCTAssertGreaterThan(categories.filter { $0 == .suv }.count, 120)
        XCTAssertGreaterThan(categories.filter { $0 == .sedan }.count, 90)
        XCTAssertLessThan(categories.filter { $0 == .sports }.count, categories.filter { $0 == .compact }.count)
    }

    func testProcurementEmployeeAutomaticallySourcesMatchingInstruction() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        game.stores[0].inventory = []
        game.stores[0].employees = [StoreEmployee(
            name: "自動仕入", salesSkill: 50, appraisalSkill: 85,
            procurementSkill: 90, monthlySalary: 45, assignment: .procurement
        )]
        game.stores[0].autoProcurement = true
        game.purchaseCases = []
        XCTAssertNotNil(game.createProcurementInstruction(
            storeID: storeID,
            totalBudget: 20_000,
            financialRule: .maximumOffer(10_000),
            category: .suv,
            modelID: nil,
            faultOnly: false
        ))

        game.advanceWeek()

        let instruction = try! XCTUnwrap(game.procurementInstructions(for: storeID).first)
        XCTAssertNotEqual(instruction.lastResult, "今週は条件一致なし")
        XCTAssertTrue(
            game.inboundShipments.contains { $0.storeID == storeID && $0.category == .suv }
                || game.bidReservations.contains { $0.storeID == storeID && $0.instructionID == instruction.id }
                || game.onlineBidReservations.contains { $0.storeID == storeID && $0.instructionID == instruction.id }
        )
    }

    func testUpdatedCatalogUsesHighPriceImportsAndSixHundredClassSUVs() {
        let imports = VehicleCatalog.all.filter { $0.origin == .imported && !$0.isRareClassic }
        let suvs = VehicleCatalog.all.filter { $0.category == .suv }
        let game = GameEngine()
        game.resetGame()
        game.startNewGame()
        let currentImportRetailValues = imports.filter { $0.launchTurn == 0 }.map {
            game.vehicleRetailValue(
                modelID: $0.id,
                category: $0.category,
                modelYear: 2028,
                mileage: 32_000,
                quality: 0.86,
                in: .downtown
            )
        }

        XCTAssertEqual(VehicleCategory.allCases.count, 7)
        XCTAssertGreaterThanOrEqual(imports.map(\.referenceRetailPrice).max() ?? 0, 800)
        XCTAssertGreaterThanOrEqual(currentImportRetailValues.max() ?? 0, 800)
        XCTAssertGreaterThanOrEqual(suvs.map(\.referenceRetailPrice).max() ?? 0, 600)
    }

    func testVerifiedAuctionStartsWithProfitableUpsideAtPricePolicyOneHundred() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .quality)
        let storeID = try XCTUnwrap(game.stores.first?.id)
        let normalListings = game.auctionListings.filter {
            VehicleCatalog.entry(id: $0.modelID)?.isRareClassic == false
        }

        XCTAssertFalse(normalListings.isEmpty)
        for listing in normalListings {
            let minimumRetail = try XCTUnwrap(DistrictKind.allCases.map {
                game.vehicleRetailValue(
                    modelID: listing.modelID,
                    category: listing.category,
                    modelYear: listing.modelYear,
                    mileage: listing.mileage,
                    quality: listing.condition.quality,
                    in: $0
                )
            }.min())
            let sourceCosts = listing.reservePrice
                + listing.venue.fee
                + listing.venue.shippingCost
            XCTAssertLessThanOrEqual(sourceCosts, minimumRetail * 85 / 100)
            XCTAssertGreaterThanOrEqual(
                try XCTUnwrap(
                    game.auctionExpectedGrossProfit(
                        for: listing,
                        storeID: storeID,
                        maxPrice: listing.reservePrice
                    )
                ),
                minimumRetail * 15 / 100
            )
        }
    }

    func testAuctionAndOnlineShippingCostsAreAboutOneThirdOfPreviousRates() {
        XCTAssertEqual(AuctionVenue.east.shippingCost, 2)
        XCTAssertEqual(AuctionVenue.port.shippingCost, 4)
        XCTAssertEqual(AuctionVenue.premium.shippingCost, 6)
        XCTAssertEqual(AuctionVenue.east.listingPricingShippingAllowance, 5)
        XCTAssertEqual(AuctionVenue.port.listingPricingShippingAllowance, 12)
        XCTAssertEqual(AuctionVenue.premium.listingPricingShippingAllowance, 18)

        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)

        XCTAssertFalse(game.onlineListings.isEmpty)
        XCTAssertTrue(game.onlineListings.allSatisfy { [4, 6].contains($0.shippingCost) })
    }

    func testDealerTradeUsesTheQuotedModelAndItsOwnMarketPrice() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .quality)
        game.cash = 100_000
        let store = try XCTUnwrap(game.stores.first)
        let quote = try XCTUnwrap(game.dealerTradeQuote(category: .sedan, count: 3, storeID: store.id, origin: .imported))
        let modelID = try XCTUnwrap(quote.modelID)
        let model = try XCTUnwrap(VehicleCatalog.entry(id: modelID))

        XCTAssertEqual(quote.vehicleName, model.fullName)
        let expectedMargin = Double(quote.expectedGrossProfit) / Double(quote.expectedRetailPrice)
        XCTAssertGreaterThanOrEqual(expectedMargin, 0.00)
        XCTAssertLessThanOrEqual(expectedMargin, 0.08)
        XCTAssertTrue(game.orderDealerTrade(category: .sedan, count: 3, storeID: store.id, origin: .imported))
        XCTAssertEqual(game.inboundShipments.last?.modelID, modelID)
        XCTAssertEqual(game.inboundShipments.last?.modelYear, quote.modelYear)
        XCTAssertEqual(game.inboundShipments.last?.mileage, quote.mileage)
    }

    func testImportedBuyerStronglyPrefersTheRequestedMakerAndModel() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .quality)
        let storeID = try XCTUnwrap(game.stores.first?.id)
        let exactModel = try XCTUnwrap(VehicleCatalog.entry(id: "nord-velar"))
        let otherModel = try XCTUnwrap(VehicleCatalog.entry(id: "rossa-luce"))
        let exact = InventoryBatch(modelID: exactModel.id, category: exactModel.category, count: 1, averageCost: 520, quality: 0.88, modelYear: 2028, mileage: 24_000, acquiredTurn: game.turn)
        let other = InventoryBatch(modelID: otherModel.id, category: otherModel.category, count: 1, averageCost: 560, quality: 0.88, modelYear: 2028, mileage: 24_000, acquiredTurn: game.turn)
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
        XCTAssertGreaterThan(exactPreview.closeChance, otherPreview.closeChance + 0.35)
    }

    func testEveryGeneratedBuyerHasCategoryMakerOrModelAndOrdinarySegmentsIncludeDetailedRequests() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .family, simulationSeed: 1)
        var observed: [BuyerVehiclePreference] = []

        for _ in 0..<24 {
            observed.append(contentsOf: game.buyerLeads.map(\.preference))
            game.advanceWeek()
        }

        XCTAssertFalse(observed.isEmpty)
        XCTAssertFalse(observed.contains { if case .budgetFirst = $0 { return true }; return false })
        XCTAssertTrue(observed.contains { preference in
            switch preference {
            case .maker, .exactModel: return true
            case .category, .categoryOrigin, .budgetFirst: return false
            }
        })
    }

    func testCustomerPurchaseCaseCanBecomeInventory() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let store = game.stores[0]
        let beforeInventory = store.inventoryCount
        let beforeCash = game.cash
        let item = game.purchaseCases.first!
        let beforeCases = game.purchaseCases.count

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

    func testHotAuctionHasExpandedSupplyAndNamesTheCompetitorThatOutbidsPlayer() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let listing = try XCTUnwrap(game.auctionListings.first {
            game.auctionBidWinChance(for: $0, maxPrice: $0.reservePrice) == 0
        })
        let store = game.stores[0]
        game.auctionListings = [listing]
        game.buyerLeads = []
        game.purchaseCases = []
        game.corporateOpportunities = []
        XCTAssertEqual(game.auctionListings.count, 1)
        XCTAssertTrue(game.reserveBid(listingID: listing.id, storeID: store.id, maxPrice: listing.reservePrice))

        game.advanceWeek()

        let result = game.auctionBidResults.first(where: { $0.listingID == listing.id })
        XCTAssertEqual(result?.status, .exceededLimit)
        XCTAssertNotNil(result?.winningCompetitorID)
        XCTAssertNotNil(result.flatMap { game.auctionWinnerName(for: $0) })
        XCTAssertTrue(game.competitorAuctionPurchases.contains { purchase in
            purchase.listingID == listing.id && purchase.competitorID == result?.winningCompetitorID
        })
        XCTAssertEqual(game.auctionListings.count, 72)
    }

    func testOrdinaryAuctionCompetitionIsSelectiveInsteadOfEveryListing() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, simulationSeed: 17)

        let listing = try XCTUnwrap(game.auctionListings.first { listing in
            let chance = game.auctionBidWinChance(
                for: listing,
                maxPrice: listing.reservePrice
            )
            return chance > 0 && chance < 1
        })
        let chance = game.auctionBidWinChance(for: listing, maxPrice: listing.reservePrice)

        XCTAssertGreaterThan(chance, 0, "競合が見送る回がある")
        XCTAssertLessThan(chance, 1, "店舗方針に合えば競合が参加する回もある")
    }

    func testCompetitorsAvoidConditionRiskOutsideTheirSpecialties() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, simulationSeed: 17)
        let sports = try XCTUnwrap(game.auctionListings.first { $0.category == .sports })
        let riskyOutsideSpecialty = AuctionListing(
            id: UUID(),
            venue: sports.venue,
            modelID: sports.modelID,
            category: .sports,
            modelYear: sports.modelYear,
            mileage: sports.mileage,
            quality: 0.42,
            condition: VehicleConditionProfile(exterior: 45, interior: 43, mechanical: 25),
            fault: .major,
            reservePrice: 1,
            marketPrice: max(100, sports.marketPrice),
            seller: "専門外リスク検証",
            createdTurn: game.turn
        )

        XCTAssertEqual(
            game.auctionBidWinChance(for: riskyOutsideSpecialty, maxPrice: 1),
            1,
            accuracy: 0.001
        )
    }

    func testCompetitorAuctionPurchasePaysAllCostsAndAddsActualInventory() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let listing = try XCTUnwrap(game.auctionListings.first)
        let competitorIndex = try XCTUnwrap(game.competitors.indices.first(where: {
            game.competitors[$0].cash > listing.marketPrice + listing.venue.fee + listing.venue.shippingCost
                && game.competitors[$0].branches.contains { $0.inventoryCount < $0.capacity }
        }))
        let cashBefore = game.competitors[competitorIndex].cash
        let stockBefore = game.competitors[competitorIndex].branches.flatMap(\.inventory)
            .filter { $0.category == listing.category }.reduce(0) { $0 + $1.count }

        game.recordCompetitorAuctionPurchase(
            listing: listing, competitorIndex: competitorIndex,
            hammerPrice: listing.marketPrice, purchasedTurn: game.turn + 1
        )

        let competitor = game.competitors[competitorIndex]
        XCTAssertEqual(
            competitor.cash,
            cashBefore - listing.marketPrice - listing.venue.fee - listing.venue.shippingCost
        )
        XCTAssertEqual(
            competitor.branches.flatMap(\.inventory)
                .filter { $0.category == listing.category }.reduce(0) { $0 + $1.count },
            stockBefore + 1
        )
        XCTAssertTrue(game.competitorAuctionPurchases.contains { $0.listingID == listing.id && $0.competitorID == competitor.id })
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

        XCTAssertGreaterThan(game.vehicleDemand(.pickup, in: .industrial), 1.5)
        XCTAssertGreaterThan(game.vehicleSupply(.pickup, in: .industrial), game.vehicleSupply(.pickup, in: .suburb))
        XCTAssertGreaterThan(game.vehicleSupply(.pickup, in: .highway), game.vehicleSupply(.pickup, in: .downtown))
        XCTAssertNotEqual(game.vehicleDemand(.sports, in: .downtown), game.vehicleSupply(.sports, in: .downtown))
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
        let localMargin = localQuote.map {
            Double($0.expectedGrossProfit) / Double(max(1, $0.expectedRetailPrice))
        } ?? -.infinity
        let remoteMargin = remoteQuote.map {
            Double($0.expectedGrossProfit) / Double(max(1, $0.expectedRetailPrice))
        } ?? .infinity
        XCTAssertGreaterThan(localMargin, remoteMargin)
        XCTAssertLessThanOrEqual(localQuote?.weeks ?? .max, remoteQuote?.weeks ?? .min)
    }

    func testCorporateFleetSupplyIsAFiniteSharedOpportunity() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .business)
        game.cash = 100_000
        let store = game.stores[0]
        let opportunity = try XCTUnwrap(game.corporateOpportunities.first(where: { $0.kind == .fleetDisposal && !$0.resolved }))

        XCTAssertTrue(game.submitCorporateBid(opportunityID: opportunity.id, storeID: store.id, unitPrice: opportunity.unitPrice * 140 / 100))
        game.advanceWeek()

        let resolved = try XCTUnwrap(game.corporateOpportunities.first(where: { $0.id == opportunity.id }))
        XCTAssertTrue(resolved.resolved)
        XCTAssertEqual(resolved.winnerName, store.name)
        XCTAssertEqual(game.incomingCount(for: store.id), opportunity.count)
    }

    func testCorporateDisposalReferenceTargetsFiveToTenPercentGrossMargin() throws {
        let game = GameEngine(persistenceEnabled: false)
        game.resetGame(simulationSeed: 47)
        game.startNewGame(simulationSeed: 47)
        let opportunities = game.corporateOpportunities.filter {
            $0.kind == .fleetDisposal
        }

        XCTAssertFalse(opportunities.isEmpty)
        for opportunity in opportunities {
            let modelID = try XCTUnwrap(opportunity.modelID)
            let modelYear = try XCTUnwrap(opportunity.modelYear)
            let mileage = try XCTUnwrap(opportunity.mileage)
            let minimumRetail = try XCTUnwrap(DistrictKind.allCases.map {
                game.vehicleRetailValue(
                    modelID: modelID,
                    category: opportunity.category,
                    modelYear: modelYear,
                    mileage: mileage,
                    quality: opportunity.quality,
                    in: $0
                )
            }.min())
            let margin = Double(minimumRetail - opportunity.unitPrice) / Double(minimumRetail)
            XCTAssertGreaterThanOrEqual(margin, 0.045)
            XCTAssertLessThanOrEqual(margin, 0.105)
        }
    }

    func testProcurementSourcesExposePricePolicyOneHundredMarginGuides() {
        XCTAssertEqual(ProcurementSource.storePurchase.baselineGrossMarginLabel, "12〜28%")
        XCTAssertEqual(ProcurementSource.tradeIn.baselineGrossMarginLabel, "8〜20%")
        XCTAssertEqual(ProcurementSource.auction.baselineGrossMarginLabel, "-5〜25%")
        XCTAssertEqual(ProcurementSource.dealerTrade.baselineGrossMarginLabel, "2〜6%")
        XCTAssertEqual(ProcurementSource.corporateLot.baselineGrossMarginLabel, "5〜10%")
        XCTAssertEqual(ProcurementSource.online.baselineGrossMarginLabel, "-10〜25%")
    }

    func testCorporatePurchaseBidReservesInventoryUntilWithdrawal() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .business)
        let storeID = try XCTUnwrap(game.stores.first?.id)
        let opportunity = try XCTUnwrap(game.corporateOpportunities.first(where: { $0.kind == .fleetPurchase && !$0.resolved }))
        let model = try XCTUnwrap(VehicleCatalog.available(through: game.turn).first(where: { $0.category == opportunity.category && !$0.isRareClassic }))
        let batch = InventoryBatch(
            modelID: model.id, category: opportunity.category, count: opportunity.count,
            averageCost: opportunity.category.purchaseCost, quality: 0.80,
            modelYear: game.year - 2, mileage: 30_000, acquiredTurn: game.turn
        )
        game.stores[0].inventory = [batch]

        XCTAssertTrue(game.submitCorporateBid(
            opportunityID: opportunity.id,
            storeID: storeID,
            unitPrice: opportunity.unitPrice
        ))
        XCTAssertTrue(game.stores[0].inventory[0].isReserved)
        XCTAssertNil(game.manualSaleQuote(storeID: storeID, inventoryID: batch.id))

        game.withdrawCorporateBid(opportunityID: opportunity.id)
        XCTAssertFalse(game.stores[0].inventory[0].isReserved)
        XCTAssertNotNil(game.manualSaleQuote(storeID: storeID, inventoryID: batch.id))
    }

    func testDeclinedPurchaseMovesVehicleAndCashIntoCompetitorInventory() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let item = try XCTUnwrap(game.purchaseCases.first(where: { $0.competitorOffer != nil }))
        let offer = try XCTUnwrap(item.competitorOffer)
        let competitorIndex = try XCTUnwrap(game.competitors.firstIndex(where: { $0.id == offer.competitorID }))
        let cashBefore = game.competitors[competitorIndex].cash
        let stockBefore = game.competitors[competitorIndex].branches.flatMap(\.inventory)
            .filter { $0.category == item.category }.reduce(0) { $0 + $1.count }

        game.declinePurchaseCase(item.id)

        let competitor = game.competitors[competitorIndex]
        let stockAfter = competitor.branches.flatMap(\.inventory)
            .filter { $0.category == item.category }.reduce(0) { $0 + $1.count }
        XCTAssertEqual(competitor.cash, cashBefore - offer.price * item.lotCount)
        XCTAssertEqual(stockAfter, stockBefore + item.lotCount)
    }

    func testLostSaleConsumesCompetitorStockAndCreditsActualRevenue() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = try XCTUnwrap(game.stores.first?.id)
        let rivalIndex = try XCTUnwrap(game.competitors.indices.first(where: {
            game.competitors[$0].branches.contains { branch in branch.inventory.contains { $0.count > 0 } }
        }))
        let rival = game.competitors[rivalIndex]
        let rivalBucket = try XCTUnwrap(rival.branches.flatMap(\.inventory).first(where: { $0.count > 0 }))
        let model = try XCTUnwrap(VehicleCatalog.available(through: game.turn).first(where: { $0.category == rivalBucket.category && !$0.isRareClassic }))
        let playerBatch = InventoryBatch(
            modelID: model.id, category: rivalBucket.category, count: 1,
            averageCost: model.baseWholesalePrice, quality: 0.45,
            modelYear: game.year - 8, mileage: 160_000, acquiredTurn: game.turn
        )
        game.stores[0].inventory = [playerBatch]
        let offer = CompetitorOfferBenchmark(
            competitorID: rival.id, price: max(30, model.referenceRetailPrice),
            quality: rivalBucket.averageQuality,
            category: rivalBucket.category, purpose: rivalBucket.purpose
        )
        let lead = BuyerLead(
            id: UUID(), storeID: storeID, preference: .category(rivalBucket.category),
            budget: 1, minimumQuality: 0.95, priceSensitivity: 1,
            generatedTurn: game.turn, purpose: rivalBucket.purpose,
            competitorOffer: offer
        )
        game.buyerLeads = [lead]

        let categoryIndex = VehicleCategory.allCases.firstIndex(of: rivalBucket.category) ?? 0
        let plotID = game.stores[0].plotID
        func roll(_ turn: Int) -> Double {
            let seed = turn * 97 + plotID * 19 + categoryIndex * 31
            return Double(abs((seed &* 1_664_525 &+ 1_013_904_223) % 10_000)) / 10_000
        }
        while roll(game.turn) <= 0.03 { game.turn += 1 }
        let cashBefore = game.competitors[rivalIndex].cash
        let stockBefore = game.competitors[rivalIndex].branches.flatMap(\.inventory)
            .filter { $0.category == rivalBucket.category }.reduce(0) { $0 + $1.count }

        let result = try XCTUnwrap(game.negotiateManualSale(
            storeID: storeID, buyerLeadID: lead.id,
            inventoryID: playerBatch.id, strategy: .holdPrice
        ))

        XCTAssertFalse(result.succeeded)
        XCTAssertLessThan(result.closeChance, 0.25)
        XCTAssertEqual(game.competitors[rivalIndex].cash, cashBefore + offer.price)
        XCTAssertEqual(
            game.competitors[rivalIndex].branches.flatMap(\.inventory)
                .filter { $0.category == rivalBucket.category }.reduce(0) { $0 + $1.count },
            stockBefore - 1
        )
    }

    func testCompanyExpertiseContributesTwentyFivePercentAndDerivesBusinessName() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.stores[0].expertise.categories[.suv] = 10
        game.companyExpertise.categories[.suv] = 40
        game.stores[0].expertise.procurementSources[.auction] = 8
        game.companyExpertise.procurementSources[.auction] = 40

        XCTAssertEqual(game.effectiveCategoryExpertise(for: game.stores[0], category: .suv), 20, accuracy: 0.001)
        XCTAssertEqual(game.effectiveSourceExpertise(for: game.stores[0], source: .auction), 18, accuracy: 0.001)
        XCTAssertEqual(game.derivedBusinessName(for: game.stores[0]), "SUVに強い店")
    }

    func testCompetitorsSignalAtFourWeeksAndShiftResourcesByEightWeeks() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        func seedProfitableSegments() {
            for competitorIndex in game.competitors.indices {
                guard let district = game.competitors[competitorIndex].branches.first
                    .flatMap({ game.plot(id: $0.plotID)?.district }) else { continue }
                let key = MarketSegmentKey(
                    district: district,
                    category: .suv,
                    purpose: .outdoor,
                    productKind: .outdoor
                )
                let records = (0..<4).map { offset in
                    SegmentWeekRecord(
                        turn: game.turn - 3 + offset,
                        demand: 3,
                        competitorSales: 1,
                        unmetDemand: 2,
                        competitorRevenue: 520,
                        competitorCost: 340
                    )
                }
                game.segmentMarkets[key] = SegmentMarketState(
                    demandCarry: 0,
                    records: records,
                    blueOceanWeeks: 0
                )
                game.competitors[competitorIndex].segmentRecords[key] = records
            }
        }
        let initialAdvertising = game.competitors.flatMap(\.branches).reduce(0) { $0 + $1.advertising }

        for _ in 0..<4 {
            seedProfitableSegments()
            game.advanceWeek()
        }

        XCTAssertTrue(game.competitors.allSatisfy { ($0.profitableSegmentWeeks[.suv] ?? 0) >= 4 })
        XCTAssertTrue(game.reports.flatMap(\.notes).contains { $0.contains("競合追随兆候") && $0.contains("SUV") })

        for _ in 0..<4 {
            seedProfitableSegments()
            game.advanceWeek()
        }

        let shiftedCompetitors = game.competitors.filter { $0.category != .suv }
        XCTAssertTrue(shiftedCompetitors.allSatisfy { ($0.targetInventoryShare[.suv] ?? 0) >= 0.20 })
        XCTAssertGreaterThan(game.competitors.flatMap(\.branches).reduce(0) { $0 + $1.advertising }, initialAdvertising)
        XCTAssertTrue(game.competitors.flatMap(\.branches).contains { !$0.productizationQueue.isEmpty })
    }

    func testFiftyTwoWeekBalanceScenariosAcrossFixedSeeds() {
        let seeds = [3, 11, 29]
        var largeGeneral: [BalanceSnapshot] = []
        var smallGeneral: [BalanceSnapshot] = []
        var smallSpecialist: [BalanceSnapshot] = []
        for seed in seeds {
            largeGeneral.append(runBalanceScenario(
                plan: .business,
                capital: 50_000,
                policy: StoreMarketPolicy(),
                employeeScale: 8,
                advertising: 500,
                openingInventoryTarget: 25,
                scenarioSeed: seed
            ))
            smallGeneral.append(runBalanceScenario(
                plan: .business,
                capital: 3_500,
                policy: StoreMarketPolicy(),
                employeeScale: 4,
                advertising: 80,
                openingInventoryTarget: 4,
                scenarioSeed: seed
            ))
            smallSpecialist.append(runBalanceScenario(
                plan: .business,
                capital: 3_500,
                policy: StoreMarketPolicy(
                    priorityCategories: [.minivan, .pickup],
                    targetPurpose: .work,
                    acceptedConditions: [.normal, .rough, .faulty]
                ),
                employeeScale: 4,
                advertising: 80,
                openingInventoryTarget: 4,
                scenarioSeed: seed
            ))
        }

        let largeSales = largeGeneral.reduce(0) { $0 + $1.sales }
        let smallSales = smallGeneral.reduce(0) { $0 + $1.sales }
        let generalCash = smallGeneral.reduce(0) { $0 + $1.cash }
        let specialistCash = smallSpecialist.reduce(0) { $0 + $1.cash }
        XCTAssertGreaterThan(largeSales, smallSales)
        XCTAssertGreaterThanOrEqual(largeGeneral.map(\.maximumShare).reduce(0, +), smallGeneral.map(\.maximumShare).reduce(0, +))
        XCTAssertGreaterThanOrEqual(
            specialistCash,
            generalCash - 300,
            "専門化はトレンド次第で総合店を下回り得るが、対象市場への適合で大幅な不利にはならない"
        )
        XCTAssertGreaterThanOrEqual(smallSpecialist.filter(\.survived).count, smallGeneral.filter(\.survived).count)
    }

    func testRobustGeneralStoresRunFor156WeeksAcrossFixedSeeds() {
        let snapshots = [5, 17, 43].map { seed in
            runBalanceScenario(
                plan: .business,
                capital: 100_000,
                policy: StoreMarketPolicy(),
                employeeScale: 8,
                advertising: 320,
                openingInventoryTarget: 24,
                scenarioSeed: seed,
                weeks: 156
            )
        }

        XCTAssertTrue(snapshots.allSatisfy(\.survived))
        XCTAssertTrue(snapshots.allSatisfy { $0.sales > 0 })
        XCTAssertTrue(snapshots.allSatisfy { $0.cash > -2_000 })
    }

    func testAllWorkshopKindsExposeAnExternalPartnerFromTheStart() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities = []
        game.stores[0].employees = []
        let storeID = game.stores[0].id
        let normal = InventoryBatch(
            modelID: "hinode-familia",
            category: .minivan,
            count: 1,
            averageCost: 180,
            quality: 0.64,
            modelYear: 2023,
            mileage: 68_000,
            acquiredTurn: game.turn
        )
        let faulty = InventoryBatch(
            modelID: "hinode-familia",
            category: .minivan,
            count: 1,
            averageCost: 70,
            quality: 0.45,
            modelYear: 2020,
            mileage: 120_000,
            acquiredTurn: game.turn,
            condition: VehicleConditionProfile(exterior: 50, interior: 48, mechanical: 30),
            fault: .major
        )
        game.stores[0].inventory = [normal, faulty]

        let expected: [(WorkshopProjectKind, OutsourcePartnerKind)] = [
            (.basicService, .generalRepair),
            (.refurbishment, .specialist),
            (.camperConversion, .specialist),
            (.workConversion, .fabrication),
            (.outdoorConversion, .fabrication)
        ]
        for (kind, partner) in expected {
            let preview = try! XCTUnwrap(game.workshopProjectPreview(
                storeID: storeID,
                inventoryID: normal.id,
                kind: kind,
                fulfillment: .outsourced
            ))
            XCTAssertEqual(preview.outsourcePartner, partner)
        }
        XCTAssertEqual(game.workshopProjectPreview(
            storeID: storeID,
            inventoryID: faulty.id,
            kind: .repair,
            fulfillment: .outsourced
        )?.outsourcePartner, .generalRepair)
    }

    func testTrendMultipliesDemandAndRaisesProcurementOnlyAfterTwoWeeks() {
        let game = GameEngine()
        game.resetGame(simulationSeed: 31)
        startPlayableGame(game)
        game.stores[0].employees = [StoreEmployee(
            name: "市場調査",
            salesSkill: 45,
            procurementSkill: 55,
            researchSkill: 90,
            serviceSkill: 40,
            monthlySalary: 48,
            assignment: .research
        )]
        let storeID = game.stores[0].id
        let district = game.plot(id: game.stores[0].plotID)!.district
        let baseline = try! XCTUnwrap(game.segmentOpportunityReports(storeID: storeID, district: district).first {
            $0.key.productKind == .camper && $0.key.category == .minivan
        })
        let model = VehicleCatalog.entry(id: "hinode-familia")!
        let beforeWholesale = game.vehicleWholesaleValue(
            modelID: model.id,
            category: .minivan,
            modelYear: game.year - 3,
            mileage: 45_000,
            quality: 0.78,
            in: district
        )
        game.segmentTrends = [SegmentTrend(
            kind: .campingBoom,
            districts: [district],
            categories: [.minivan],
            startTurn: game.turn,
            peakWeeks: 8,
            peakMultiplier: 2.4
        )]
        let startWholesale = game.vehicleWholesaleValue(
            modelID: model.id,
            category: .minivan,
            modelYear: game.year - 3,
            mileage: 45_000,
            quality: 0.78,
            in: district
        )
        XCTAssertEqual(startWholesale, beforeWholesale)

        game.turn += 2
        let peak = try! XCTUnwrap(game.segmentOpportunityReports(storeID: storeID, district: district).first {
            $0.key.productKind == .camper && $0.key.category == .minivan
        })
        let afterWholesale = game.vehicleWholesaleValue(
            modelID: model.id,
            category: .minivan,
            modelYear: game.year - 3,
            mileage: 45_000,
            quality: 0.78,
            in: district
        )
        XCTAssertGreaterThan(peak.trendMultiplier, 1.0)
        XCTAssertLessThan(peak.trendMultiplier, 2.4)
        XCTAssertGreaterThan(peak.fourWeekDemand.upperBound, baseline.fourWeekDemand.upperBound)
        let marginLift = Double(peak.estimatedUnitMargin.upperBound)
            / Double(max(1, baseline.estimatedUnitMargin.upperBound))
        XCTAssertGreaterThan(marginLift, 1.25)
        XCTAssertLessThanOrEqual(marginLift, 2.0)
        XCTAssertGreaterThan(afterWholesale, startWholesale)
    }

    func testBlueOceanCanCreateFundedEntrantWithRealProductizationQueue() {
        let game = GameEngine()
        game.resetGame(simulationSeed: 53)
        startPlayableGame(game)
        game.turn = 8
        let key = MarketSegmentKey(
            district: .industrial,
            category: .pickup,
            purpose: .work,
            productKind: .workCargo
        )
        let records = (0..<4).map {
            SegmentWeekRecord(turn: game.turn - 3 + $0, demand: 3, unmetDemand: 2)
        }
        game.segmentMarkets[key] = SegmentMarketState(
            demandCarry: 0,
            records: records,
            blueOceanWeeks: 9
        )
        for competitorIndex in game.competitors.indices {
            for branchIndex in game.competitors[competitorIndex].branches.indices
            where game.plot(id: game.competitors[competitorIndex].branches[branchIndex].plotID)?.district == key.district {
                game.competitors[competitorIndex].branches[branchIndex].inventory.removeAll()
            }
        }
        let beforeCount = game.competitors.count

        game.advanceWeek()

        XCTAssertEqual(game.competitors.count, beforeCount + 1)
        let entrant = try! XCTUnwrap(game.competitors.first(where: \.isMarketEntrant))
        XCTAssertEqual(entrant.category, .pickup)
        XCTAssertGreaterThan(entrant.cash, 0)
        XCTAssertEqual(entrant.branches.count, 1)
        XCTAssertEqual(entrant.branches[0].productizationQueue.first?.marketProductKind, .workCargo)
        XCTAssertTrue(entrant.branches[0].productizationQueue.first?.outsourced == true)
    }

    func testFourSalesCanEarnRegionalNicheLeadershipAndReferralLabel() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let district = game.plot(id: game.stores[0].plotID)!.district
        let key = MarketSegmentKey(
            district: district,
            category: .suv,
            purpose: .outdoor,
            productKind: .outdoor
        )
        game.stores[0].segmentRecords[key] = [
            SegmentWeekRecord(turn: game.turn, playerSales: 4)
        ]
        for competitorIndex in game.competitors.indices {
            game.competitors[competitorIndex].segmentRecords[key] = [
                SegmentWeekRecord(turn: game.turn, competitorSales: 3)
            ]
        }

        XCTAssertEqual(game.regionalNicheLeaderKey(for: game.stores[0]), key)
        XCTAssertEqual(
            game.regionalNicheLeaderLabel(for: game.stores[0]),
            "地域ニッチNo.1・\(MarketProductKind.outdoor.name)"
        )
    }

    func testBuyingShareWithAdvertisingRaisesWeeklyFixedBurden() {
        func noSalesWeek(advertising: Int) -> (profit: Int, advertisingCost: Int) {
            let game = GameEngine()
            game.resetGame()
            startPlayableGame(game)
            game.stores[0].inventory = []
            game.stores[0].advertising = advertising
            game.buyerLeads = []
            game.purchaseCases = []
            game.corporateOpportunities = []
            game.advanceWeek()
            return (game.stores[0].lastProfit, game.finance.advertising)
        }

        let normal = noSalesWeek(advertising: 80)
        let volume = noSalesWeek(advertising: 500)
        XCTAssertGreaterThan(volume.advertisingCost, normal.advertisingCost)
        XCTAssertLessThan(volume.profit, normal.profit)
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
        game.cash = 100_000
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

    func testManagerDelegatesProcurementPolicyWithoutProcessingCases() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        game.procurementInstructions.removeAll()
        game.stores[0].employees = []
        XCTAssertTrue(game.hireManager(for: storeID))
        game.stores[0].delegateProcurement = true

        game.advanceWeek()

        let cautious = try! XCTUnwrap(game.procurementInstructions(for: storeID).first)
        XCTAssertTrue(cautious.allowedSources.isSuperset(of: [.auction, .dealerTrade, .corporateLot]))
        XCTAssertFalse(cautious.allowedSources.contains(.storePurchase))
        XCTAssertFalse(cautious.allowedSources.contains(.online))
        XCTAssertTrue(game.stores[0].employees.isEmpty, "店長は仕入担当の実働を代行しない")

        game.stores[0].employees = [StoreEmployee(
            name: "査定整備責任者", salesSkill: 40, procurementSkill: 30,
            researchSkill: 50, serviceSkill: 90,
            monthlySalary: 52, assignment: .service
        )]
        game.advanceWeek()

        let expanded = try! XCTUnwrap(game.procurementInstructions(for: storeID).first)
        XCTAssertTrue(expanded.allowedSources.contains(.storePurchase))
        XCTAssertTrue(expanded.allowedSources.contains(.online))
        XCTAssertEqual(game.stores[0].employees[0].lastWeekPerformance.handled, 0)
    }

    func testStaffCanBeHiredAndFiredWithoutManager() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
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
        game.cash = 100_000
        let storeID = game.stores[0].id
        let candidates = game.employeeCandidates(for: storeID)

        XCTAssertEqual(candidates.count, 6)
        XCTAssertEqual(Set(candidates.map(\.id)).count, candidates.count)
        let candidate = candidates[1]
        XCTAssertTrue(game.hireEmployee(candidate.id, for: storeID))

        XCTAssertEqual(game.stores[0].employees, [candidate])
        XCTAssertEqual(game.stores[0].employeeMonthlyPayroll, candidate.monthlySalary)
        XCTAssertEqual(game.monthlyPersonnelCost(for: game.stores[0]), candidate.monthlySalary)
        XCTAssertFalse(game.employeeCandidates(for: storeID).contains { $0.id == candidate.id })
    }

    func testEmployeeCandidatesRefreshEveryWeekAndDoNotGuaranteeATypeMix() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, simulationSeed: 29)
        let storeID = game.stores[0].id
        let firstWeek = game.employeeCandidates(for: storeID)

        game.turn += 1
        let secondWeek = game.employeeCandidates(for: storeID)

        XCTAssertEqual(firstWeek.count, 6)
        XCTAssertEqual(secondWeek.count, 6)
        XCTAssertNotEqual(Set(firstWeek.map(\.id)), Set(secondWeek.map(\.id)))
        XCTAssertLessThan(Set(firstWeek.map(\.rankName)).count, 4)
    }

    func testEliteAbilityDoublesAutomationCapacityAndCommandsHigherSalary() {
        let game = GameEngine()
        let low = StoreEmployee(
            name: "新人", salesSkill: 20, procurementSkill: 20,
            researchSkill: 20, serviceSkill: 20, monthlySalary: 24
        )
        let elite = StoreEmployee(
            name: "エース", salesSkill: 99, procurementSkill: 99,
            researchSkill: 99, serviceSkill: 99, monthlySalary: 100
        )

        XCTAssertEqual(game.employeeWeeklyCaseCapacity(for: low, assignment: .sales), 6)
        XCTAssertEqual(game.employeeWeeklyCaseCapacity(for: elite, assignment: .sales), 12)
        XCTAssertGreaterThanOrEqual(elite.marketMonthlySalary, low.marketMonthlySalary * 2)
        XCTAssertGreaterThan(
            game.employeeSalesCloseAdjustment(elite),
            game.employeeSalesCloseAdjustment(low) + 0.20
        )
    }

    func testCompensationPlansKeepSalesCommissionWithinEightPercent() {
        XCTAssertEqual(EmployeeCompensationType.fixed.commissionRate, 2)
        XCTAssertEqual(EmployeeCompensationType.balanced.commissionRate, 4)
        XCTAssertEqual(EmployeeCompensationType.performance.commissionRate, 8)
        let minimumEmployee = StoreEmployee(
            name: "歩合下限", salesSkill: 50, procurementSkill: 50,
            researchSkill: 50, serviceSkill: 50,
            monthlySalary: 40, commissionRate: 0
        )
        let employee = StoreEmployee(
            name: "歩合上限", salesSkill: 70, procurementSkill: 70,
            researchSkill: 70, serviceSkill: 70,
            monthlySalary: 60, commissionRate: 20
        )
        XCTAssertEqual(minimumEmployee.commissionRate, 2)
        XCTAssertEqual(employee.commissionRate, 8)
    }

    func testEmployeeSkillsImproveSalesAndAppraisalAccuracy() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
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

    func testEmployeeAbilityLabelsUseSalesProcurementResearchAndAppraisalService() {
        XCTAssertEqual(EmployeeAssignment.sales.name, "販売")
        XCTAssertEqual(EmployeeAssignment.procurement.name, "仕入")
        XCTAssertEqual(EmployeeAssignment.research.name, "調査")
        XCTAssertEqual(EmployeeAssignment.service.name, "査定・整備")
        XCTAssertEqual(EmployeeTrainingFocus.procurement.name, "仕入")
        XCTAssertEqual(EmployeeTrainingFocus.service.name, "査定・整備")
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

        XCTAssertTrue(game.trainEmployee(employee.id, at: storeID, focus: .procurement))
        XCTAssertEqual(game.cash, beforeCash - game.employeeTrainingCost)
        XCTAssertEqual(game.stores[0].employees[0].procurementSkill, employee.procurementSkill + 3)
        XCTAssertEqual(game.stores[0].employees[0].monthlySalary, employee.monthlySalary + 1)
        XCTAssertFalse(game.trainEmployee(employee.id, at: storeID, focus: .sales))

        game.turn += 1
        XCTAssertTrue(game.trainEmployee(employee.id, at: storeID, focus: .sales))
    }

    func testEmployeeModelExposesOnlyFourAbilityTracksAndFiveAssignments() {
        XCTAssertEqual(Set(EmployeeTrainingFocus.allCases.map(\.rawValue)), ["sales", "procurement", "research", "service"])
        XCTAssertEqual(Set(EmployeeAssignment.allCases.map(\.rawValue)), ["unassigned", "sales", "procurement", "research", "service"])

        let employee = StoreEmployee(
            name: "4能力", salesSkill: 61, procurementSkill: 62,
            researchSkill: 63, serviceSkill: 64,
            monthlySalary: 40, assignment: .unassigned
        )
        XCTAssertEqual(employee.salesSkill, 61)
        XCTAssertEqual(employee.procurementSkill, 62)
        XCTAssertEqual(employee.researchSkill, 63)
        XCTAssertEqual(employee.serviceSkill, 64)
    }

    func testMarketPolicyChangeIsStagedUntilTheFollowingWeek() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let original = game.stores[0].marketPolicy
        var edited = game.stores[0]
        let next = StoreMarketPolicy(
            priorityCategories: [.suv, .pickup, .sports],
            priorityOrigins: [.imported],
            targetPurpose: .outdoor,
            acceptedConditions: [.normal, .rough, .faulty]
        )
        edited.marketPolicy = next

        game.updateStore(edited)

        XCTAssertEqual(game.stores[0].marketPolicy, original)
        XCTAssertEqual(game.stores[0].pendingMarketPolicy, next)
        game.advanceWeek()
        XCTAssertEqual(game.stores[0].marketPolicy, next)
        XCTAssertNil(game.stores[0].pendingMarketPolicy)
    }

    func testMarketPolicyCanSpecializeInFaultyVehiclesWithoutAcceptingNormalCars() {
        var policy = StoreMarketPolicy(
            priorityCategories: [.pickup], targetPurpose: .work,
            acceptedConditions: [.faulty]
        )
        policy.normalize()
        XCTAssertEqual(policy.acceptedConditions, [.faulty])

        policy.acceptedConditions = []
        policy.normalize()
        XCTAssertEqual(policy.acceptedConditions, [.normal])
    }

    func testWorkshopLaborAndBaysAreIndependentBottlenecksAndWorkPausesWithoutTechnician() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities.insert(.serviceWorkshop)
        game.stores[0].employees = [StoreEmployee(
            name: "一人工数", salesSkill: 40, procurementSkill: 40,
            researchSkill: 40, serviceSkill: 25,
            monthlySalary: 35, assignment: .service
        )]
        let storeID = game.stores[0].id
        let batches = (0..<3).map { offset in
            InventoryBatch(
                modelID: "hokuto-ridge", category: .suv, count: 1,
                averageCost: 180, quality: 0.62,
                modelYear: 2024, mileage: 70_000 + offset * 1_000,
                acquiredTurn: game.turn
            )
        }
        game.stores[0].inventory = batches

        XCTAssertEqual(game.stores[0].workshopBays, 2)
        let weeklyLabor = game.stores[0].weeklyWorkshopLabor
        XCTAssertEqual(weeklyLabor, 2)
        XCTAssertTrue(game.startWorkshopProject(storeID: storeID, inventoryID: batches[0].id, kind: .refurbishment))
        XCTAssertTrue(game.startWorkshopProject(storeID: storeID, inventoryID: batches[1].id, kind: .refurbishment))
        XCTAssertNil(game.workshopProjectPreview(
            storeID: storeID,
            inventoryID: batches[2].id,
            kind: .refurbishment,
            fulfillment: .inHouse
        ))
        XCTAssertNotNil(game.workshopProjectPreview(
            storeID: storeID,
            inventoryID: batches[2].id,
            kind: .refurbishment,
            fulfillment: .outsourced
        ))

        let before = game.stores[0].inventory.compactMap { $0.workshopProject?.remainingWork }.reduce(0, +)
        game.advanceWeek()
        let afterOneTechnicianWeek = game.stores[0].inventory.compactMap { $0.workshopProject?.remainingWork }.reduce(0, +)
        XCTAssertEqual(before - afterOneTechnicianWeek, weeklyLabor)

        game.stores[0].employees = []
        game.advanceWeek()
        let afterPausedWeek = game.stores[0].inventory.compactMap { $0.workshopProject?.remainingWork }.reduce(0, +)
        XCTAssertEqual(afterPausedWeek, afterOneTechnicianWeek)
    }

    func testEveryProductizationCanBeOutsourcedAndInHouseIsCheaperWhenAvailable() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let batch = InventoryBatch(
            modelID: "hokuto-ridge", category: .suv, count: 1,
            averageCost: 30, quality: 0.48, modelYear: 2022,
            mileage: 110_000, acquiredTurn: game.turn,
            condition: VehicleConditionProfile(exterior: 52, interior: 50, mechanical: 30),
            fault: .major
        )
        game.stores[0].inventory = [batch]

        let outsourced = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: batch.id, kind: .repair))
        XCTAssertTrue(outsourced.outsourced)
        XCTAssertEqual(outsourced.requiredWork, 1)
        XCTAssertEqual(outsourced.weeks, 1)
        let outsourcedRefurbishment = try! XCTUnwrap(game.workshopProjectPreview(
            storeID: storeID,
            inventoryID: batch.id,
            kind: .refurbishment,
            fulfillment: .outsourced
        ))
        XCTAssertEqual(outsourcedRefurbishment.outsourcePartner, .specialist)
        XCTAssertEqual(outsourcedRefurbishment.qualityCap, 90)

        game.stores[0].facilities.insert(.serviceWorkshop)
        game.stores[0].employees = [StoreEmployee(
            name: "再生整備士", salesSkill: 40, procurementSkill: 70,
            researchSkill: 40, serviceSkill: 75,
            monthlySalary: 45, assignment: .service
        )]
        let inHouse = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: batch.id, kind: .repair))
        XCTAssertFalse(inHouse.outsourced)
        XCTAssertEqual(outsourced.finalCostRate, 100)
        let expectedRate = 100 - game.employeeServiceCostDiscount(for: storeID) - 30
        XCTAssertEqual(inHouse.finalCostRate, expectedRate)
        XCTAssertEqual(
            inHouse.cost,
            Int((Double(inHouse.outsourceBaselineCost) * Double(expectedRate) / 100).rounded())
        )
        let refurbishment = try! XCTUnwrap(game.workshopProjectPreview(
            storeID: storeID,
            inventoryID: batch.id,
            kind: .refurbishment,
            fulfillment: .inHouse
        ))
        XCTAssertLessThan(refurbishment.cost, outsourcedRefurbishment.cost)
        XCTAssertLessThanOrEqual(refurbishment.weeks, outsourcedRefurbishment.weeks)
        XCTAssertGreaterThan(refurbishment.projectedSalePrice, batch.averageCost + refurbishment.cost)
    }

    func testAllWorkshopKindsUseSkillBasedInHouseCostsAndCompatibleBays() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let technician = StoreEmployee(
            name: "査定整備士", salesSkill: 40, procurementSkill: 40,
            researchSkill: 40, serviceSkill: 85,
            monthlySalary: 50, assignment: .service
        )

        for kind in WorkshopProjectKind.allCases {
            let category: VehicleCategory = switch kind {
            case .camperConversion: .minivan
            case .workConversion: .pickup
            case .outdoorConversion: .suv
            case .streetTuning, .driftTuning, .circuitTuning: .sports
            case .liftSeatConversion: .compact
            case .wheelchairConversion: .minivan
            case .mobileSalesConversion: .pickup
            case .kitchenCarConversion: .pickup
            default: .compact
            }
            let model = try! XCTUnwrap(VehicleCatalog.all.first {
                $0.category == category && !$0.isRareClassic
            })
            let batch = InventoryBatch(
                modelID: model.id, category: category, count: 1,
                averageCost: 70, quality: 0.58, modelYear: game.year - 4,
                mileage: 68_000, acquiredTurn: game.turn,
                condition: VehicleConditionProfile(exterior: 62, interior: 60, mechanical: 42),
                fault: kind == .repair ? .major : .none
            )
            game.stores[0].inventory = [batch]
            game.stores[0].facilities.remove(.serviceWorkshop)
            game.stores[0].facilities.remove(.customWorkshop)
            game.stores[0].employees = []

            let baseline = try! XCTUnwrap(game.workshopProjectPreview(
                storeID: storeID, inventoryID: batch.id, kind: kind
            ))
            XCTAssertEqual(baseline.finalCostRate, 100, kind.name)

            game.stores[0].employees = [technician]
            let staffOnly = try! XCTUnwrap(game.workshopProjectPreview(
                storeID: storeID, inventoryID: batch.id, kind: kind
            ))
            XCTAssertEqual(staffOnly.finalCostRate, 100, kind.name)
            XCTAssertTrue(staffOnly.outsourced)

            game.stores[0].employees = []
            game.stores[0].facilities.insert(kind.usesCustomizationBay ? .customWorkshop : .serviceWorkshop)
            let bayOnly = try! XCTUnwrap(game.workshopProjectPreview(
                storeID: storeID, inventoryID: batch.id, kind: kind
            ))
            XCTAssertEqual(bayOnly.finalCostRate, 100, kind.name)
            XCTAssertTrue(bayOnly.outsourced)

            game.stores[0].employees = [technician]
            let complete = try! XCTUnwrap(game.workshopProjectPreview(
                storeID: storeID, inventoryID: batch.id, kind: kind
            ))
            let expectedRate = 100 - game.employeeServiceCostDiscount(for: storeID) - 30
            XCTAssertEqual(complete.finalCostRate, expectedRate, kind.name)
            XCTAssertFalse(complete.outsourced)
            XCTAssertEqual(
                complete.cost,
                Int((Double(complete.outsourceBaselineCost) * Double(expectedRate) / 100).rounded()),
                kind.name
            )
        }
    }

    func testWrongWorkshopBayCannotRunWorkInHouse() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let model = try! XCTUnwrap(VehicleCatalog.all.first { $0.category == .compact })
        let batch = InventoryBatch(
            modelID: model.id, category: .compact, count: 1,
            averageCost: 60, quality: 0.55, modelYear: game.year - 5,
            mileage: 72_000, acquiredTurn: game.turn,
            fault: .major
        )
        game.stores[0].inventory = [batch]
        game.stores[0].facilities = [.customWorkshop]
        game.stores[0].employees = [StoreEmployee(
            name: "査定整備士", salesSkill: 40, procurementSkill: 40,
            researchSkill: 40, serviceSkill: 80,
            monthlySalary: 48, assignment: .service
        )]

        XCTAssertNil(game.workshopProjectPreview(
            storeID: storeID, inventoryID: batch.id, kind: .repair, fulfillment: .inHouse
        ))
        let fallback = try! XCTUnwrap(game.workshopProjectPreview(
            storeID: storeID, inventoryID: batch.id, kind: .repair
        ))
        XCTAssertTrue(fallback.outsourced)
        XCTAssertEqual(fallback.finalCostRate, 100)
        XCTAssertEqual(fallback.facilityDiscount, 0)
    }

    func testBulkPlayerStockDoesNotArtificiallyRaiseNormalMarketPrices() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game, plan: .quality)
        let model = VehicleCatalog.entry(id: "hokuto-ridge")!
        let district = DistrictKind.downtown
        let beforeWholesale = game.vehicleWholesaleValue(
            modelID: model.id, category: .suv, modelYear: game.year - 3,
            mileage: 40_000, quality: 0.82, in: district
        )
        let beforeRetail = game.vehicleRetailValue(
            modelID: model.id, category: .suv, modelYear: game.year - 3,
            mileage: 40_000, quality: 0.82, in: district
        )
        game.stores[0].inventory.append(InventoryBatch(
            modelID: model.id, category: .suv, count: 30,
            averageCost: beforeWholesale, quality: 0.82,
            modelYear: game.year - 3, mileage: 40_000, acquiredTurn: game.turn
        ))
        let afterWholesale = game.vehicleWholesaleValue(
            modelID: model.id, category: .suv, modelYear: game.year - 3,
            mileage: 40_000, quality: 0.82, in: district
        )
        let afterRetail = game.vehicleRetailValue(
            modelID: model.id, category: .suv, modelYear: game.year - 3,
            mileage: 40_000, quality: 0.82, in: district
        )

        XCTAssertEqual(afterWholesale, beforeWholesale)
        XCTAssertEqual(afterRetail, beforeRetail)
        XCTAssertLessThanOrEqual(afterWholesale, afterRetail * 80 / 100)
    }

    func testFaultDetectionUsesOnlyBestAppraisalServiceAbility() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        game.stores[0].employees = [
            StoreEmployee(name: "仕入", salesSkill: 40, procurementSkill: 80, researchSkill: 40, serviceSkill: 40, monthlySalary: 40, assignment: .procurement),
            StoreEmployee(name: "整備", salesSkill: 40, procurementSkill: 40, researchSkill: 40, serviceSkill: 60, monthlySalary: 40, assignment: .service)
        ]
        XCTAssertEqual(game.faultDetectionPercent(for: storeID), 60)

        game.stores[0].employees.removeAll { $0.assignment == .service }
        XCTAssertEqual(game.faultDetectionPercent(for: storeID), 35)
    }

    func testCompetitorInformationErrorShrinksAtResearchThresholds() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        XCTAssertEqual(game.competitorInformationErrorRate(for: storeID), 0.25, accuracy: 0.001)

        var previousError = 1.0
        for skill in [20, 50, 75, 85, 99] {
            game.stores[0].employees = [StoreEmployee(
                name: "調査\(skill)", salesSkill: 40, procurementSkill: 40,
                researchSkill: skill, serviceSkill: 40,
                monthlySalary: 40, assignment: .research
            )]
            let expected = 0.18 + (0.02 - 0.18) * Double(skill - 20) / 79
            XCTAssertEqual(game.competitorInformationErrorRate(for: storeID), expected, accuracy: 0.001)
            XCTAssertLessThan(game.competitorInformationErrorRate(for: storeID), previousError)
            previousError = expected
        }
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
        _ = game.createProcurementInstruction(
            storeID: game.stores[0].id,
            totalBudget: 20_000,
            financialRule: .maximumOffer(10_000),
            category: nil,
            modelID: nil,
            faultOnly: false,
            allowedSources: [.dealerTrade]
        )

        for _ in 0..<4 {
            game.advanceWeek()
            let salesProgress = game.stores[0].employees.first {
                $0.id == salesEmployee.id
            }?.salesExperience ?? 0
            let procurementProgress = game.stores[0].employees.first {
                $0.id == procurementEmployee.id
            }?.procurementExperience ?? 0
            if salesProgress > 0, procurementProgress > 0 { break }
        }

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
            marketResearchSkill: 95, monthlySalary: 40, commissionRate: 8, assignment: .sales
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
        XCTAssertLessThanOrEqual(performance.commission, max(0, performance.grossProfit) * 8 / 100)
        XCTAssertLessThan(max(0, performance.grossProfit) * 8 / 100 - performance.commission, performance.successes)
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

    func testHighSkillServiceEmployeeIsStillLimitedByTwoWorkshopBays() {
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
        game.stores[0].facilities.insert(.serviceWorkshop)
        game.stores[0].autoService = true
        game.stores[0].servicePolicy = .quality

        game.advanceWeek()
        XCTAssertEqual(game.stores[0].inventory.filter {
            $0.workshopProject?.outsourced == false
        }.count, 2)
        game.advanceWeek()

        XCTAssertEqual(game.stores[0].employees[0].lastWeekPerformance.servicesCompleted, 2)
        XCTAssertGreaterThanOrEqual(game.stores[0].inventory.filter { $0.quality > 0.50 }.count, 2)
    }

    func testAssignedServiceTechnicianAndWorkshopQueueOrdinaryService() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let pendingPurchase = game.purchaseCases.first!
        game.stores[0].employees = [StoreEmployee(
            name: "社内整備士", salesSkill: 40, appraisalSkill: 72,
            serviceSkill: 82, monthlySalary: 52, assignment: .service
        )]
        game.stores[0].facilities.insert(.serviceWorkshop)
        game.stores[0].inventory[0].quality = 0.60
        let batch = game.stores[0].inventory[0]
        let preview = try! XCTUnwrap(game.servicePreview(storeID: storeID, inventoryID: batch.id))
        let beforeCash = game.cash

        XCTAssertGreaterThan(preview.cost, 0)
        XCTAssertGreaterThan(game.purchaseRepairCost(for: pendingPurchase), 0)
        XCTAssertTrue(game.serviceInventory(storeID: storeID, inventoryID: batch.id))
        XCTAssertEqual(beforeCash - game.cash, preview.cost)
        XCTAssertNotNil(game.stores[0].inventory.first(where: { $0.id == batch.id })?.workshopProject)
        game.advanceWeek()
        XCTAssertNil(game.stores[0].inventory.first(where: { $0.id == batch.id })?.workshopProject)
    }

    func testUnverifiedAssessmentUsesServiceSkillAndNotProcurementSkill() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let condition = VehicleConditionProfile(exterior: 76, interior: 78, mechanical: 74)
        let owner = game.vehicleAssessment(
            source: .storePurchase,
            condition: condition,
            fault: .major,
            actualRepairCost: 80,
            storeID: storeID,
            seed: 101
        )
        game.stores[0].employees = [StoreEmployee(
            name: "仕入名人", salesSkill: 50, procurementSkill: 95,
            researchSkill: 50, serviceSkill: 20,
            monthlySalary: 50, assignment: .procurement
        )]
        let procurementOnly = game.vehicleAssessment(
            source: .storePurchase, condition: condition, fault: .major,
            actualRepairCost: 80, storeID: storeID, seed: 101
        )
        XCTAssertEqual(procurementOnly.confidence, owner.confidence)
        XCTAssertEqual(procurementOnly.conditionRange, owner.conditionRange)

        game.stores[0].employees.append(StoreEmployee(
            name: "査定整備士", salesSkill: 40, procurementSkill: 30,
            researchSkill: 40, serviceSkill: 90,
            monthlySalary: 55, assignment: .service
        ))
        let skilled = game.vehicleAssessment(
            source: .storePurchase, condition: condition, fault: .major,
            actualRepairCost: 80, storeID: storeID, seed: 101
        )
        XCTAssertEqual(skilled.confidence, 90)
        XCTAssertLessThan(
            skilled.conditionRange.upperBound - skilled.conditionRange.lowerBound,
            owner.conditionRange.upperBound - owner.conditionRange.lowerBound
        )
        game.stores[0].facilities.insert(.serviceWorkshop)
        XCTAssertEqual(game.appraisalConfidence(for: storeID), 95)
        XCTAssertEqual(game.appraisalConfidence(for: storeID, source: .online), 90)
    }

    func testVerifiedAssessmentIsExactRegardlessOfEmployeeSkill() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        game.stores[0].employees = []
        let condition = VehicleConditionProfile(exterior: 61, interior: 73, mechanical: 52)
        for source in [ProcurementSource.auction, .dealerTrade, .corporateLot] {
            let assessment = game.vehicleAssessment(
                source: source, condition: condition, fault: .major,
                actualRepairCost: 74, storeID: storeID, seed: 5
            )
            XCTAssertTrue(assessment.isVerified)
            XCTAssertEqual(assessment.confidence, 100)
            XCTAssertEqual(assessment.conditionRange, condition.score...condition.score)
            XCTAssertEqual(assessment.repairCostRange, 74...74)
            XCTAssertEqual(assessment.detectedFault, .major)
        }
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
        game.cash = 100_000
        let storeID = game.stores[0].id
        let candidate = game.managerCandidate(for: storeID)

        XCTAssertNotNil(candidate)
        XCTAssertTrue(game.hireManager(for: storeID))
        XCTAssertEqual(game.stores[0].manager, candidate)

        var store = game.stores[0]
        store.delegateStaff = true
        store.delegatePricing = true
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
        game.cash = 100_000
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
            marketPolicy: StoreMarketPolicy(priorityCategories: [.kei, .compact]),
            facilities: [],
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
            marketPolicy: StoreMarketPolicy(),
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
        XCTAssertTrue(game.buildStore(on: secondPlot, type: .small, mode: .lease, marketPolicy: StoreMarketPolicy(priorityCategories: [.kei, .compact]), loanAmount: 0))
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
        XCTAssertEqual(StoreTrafficLevel.from(visitorCount: 9), .light)
        XCTAssertEqual(StoreTrafficLevel.from(visitorCount: 10), .steady)
        XCTAssertEqual(StoreTrafficLevel.from(visitorCount: 25), .busy)
        XCTAssertEqual(StoreTrafficLevel.from(visitorCount: 50), .packed)
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
        let model = VehicleCatalog.all.first(where: { $0.origin == .imported })!

        let downtown = game.catalogRetailPrice(for: model, in: .downtown)
        let industrial = game.catalogRetailPrice(for: model, in: .industrial)

        XCTAssertGreaterThan(downtown, industrial)
        XCTAssertGreaterThan(game.catalogWholesalePrice(for: model, in: .downtown), 0)
    }

    func testVehicleCategoriesSeparateBodyAndMarketSegmentsFromBudget() {
        XCTAssertFalse(VehicleCategory.allCases.map(\.name).contains("低価格車"))
        XCTAssertFalse(VehicleCategory.allCases.map(\.name).contains("輸入車"))
        XCTAssertFalse(VehicleCategory.allCases.map(\.name).contains("商用車"))
        XCTAssertEqual(VehicleOrigin.imported.name, "輸入車")
        XCTAssertEqual(VehicleCategory.pickup.name, "ピックアップトラック")
        XCTAssertTrue(VehicleCatalog.all.contains { $0.origin == .imported })
        XCTAssertTrue(VehicleCatalog.all.contains { $0.category == .pickup })
        for category in VehicleCategory.allCases {
            XCTAssertTrue(VehicleCatalog.available(through: 0).contains { $0.category == category })
        }
        XCTAssertFalse(VehicleCatalog.all.contains { $0.category == .kei && $0.origin == .imported })
        for category in VehicleCategory.allCases where category != .kei {
            XCTAssertTrue(VehicleCatalog.all.contains { $0.category == category && $0.origin == .domestic })
            XCTAssertTrue(VehicleCatalog.all.contains { $0.category == category && $0.origin == .imported })
        }
    }

    func testUnavailableImportedKeiIsRejectedWithoutFallbackOrCrash() throws {
        let game = GameEngine(persistenceEnabled: false)
        game.resetGame(simulationSeed: 17)
        startPlayableGame(game, simulationSeed: 17)
        let storeID = try XCTUnwrap(game.stores.first?.id)

        XCTAssertFalse(game.hasAvailableVehicle(category: .kei, origin: .imported))
        XCTAssertNil(
            game.dealerTradeQuote(
                category: .kei,
                count: 1,
                storeID: storeID,
                origin: .imported
            )
        )
        XCTAssertNil(
            game.createProcurementInstruction(
                storeID: storeID,
                totalBudget: 1_000,
                financialRule: .minimumGrossProfit(30),
                category: .kei,
                origin: .imported,
                modelID: nil,
                faultOnly: false
            )
        )
    }

    func testImportedMinivanAppearsInAuctionAndOnlineSupply() {
        let game = GameEngine(persistenceEnabled: false)
        game.resetGame(simulationSeed: 23)
        game.startNewGame(simulationSeed: 23)

        XCTAssertTrue(game.auctionListings.contains {
            $0.category == .minivan
                && VehicleCatalog.entry(id: $0.modelID)?.origin == .imported
        })
        XCTAssertTrue(game.onlineListings.contains {
            $0.category == .minivan
                && VehicleCatalog.entry(id: $0.modelID)?.origin == .imported
        })
    }

    func testSportsProcurementExistsInAuctionAndNeverInCorporateLots() {
        let game = GameEngine()
        game.resetGame(simulationSeed: 21)
        game.startNewGame(simulationSeed: 21)

        XCTAssertTrue(game.auctionListings.contains {
            $0.category == .sports && $0.venue == .premium
        })
        var sawClassicSport = game.auctionListings.contains {
            $0.category == .sports && VehicleCatalog.entry(id: $0.modelID)?.isRareClassic == true
        }
        for _ in 0..<41 where !sawClassicSport {
            game.advanceWeek()
            sawClassicSport = game.auctionListings.contains {
                $0.category == .sports && VehicleCatalog.entry(id: $0.modelID)?.isRareClassic == true
            }
        }
        XCTAssertTrue(sawClassicSport)
        XCTAssertFalse(game.corporateOpportunities.contains { $0.category == .sports })
    }

    func testMobileShopConversionRejectsKeiAndAcceptsPickup() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = try XCTUnwrap(game.stores.first?.id)
        let kei = try XCTUnwrap(VehicleCatalog.all.first {
            $0.category == .kei && !$0.isRareClassic
        })
        let pickup = try XCTUnwrap(VehicleCatalog.all.first {
            $0.category == .pickup && !$0.isRareClassic
        })
        let keiBatch = InventoryBatch(
            modelID: kei.id, category: .kei, count: 1, averageCost: 60,
            quality: 0.72, modelYear: game.year - 3, mileage: 30_000, acquiredTurn: game.turn
        )
        let pickupBatch = InventoryBatch(
            modelID: pickup.id, category: .pickup, count: 1, averageCost: 180,
            quality: 0.72, modelYear: game.year - 3, mileage: 30_000, acquiredTurn: game.turn
        )
        game.stores[0].inventory = [keiBatch, pickupBatch]

        XCTAssertNil(game.workshopProjectPreview(
            storeID: storeID, inventoryID: keiBatch.id,
            kind: .mobileSalesConversion, fulfillment: .outsourced
        ))
        XCTAssertNotNil(game.workshopProjectPreview(
            storeID: storeID, inventoryID: pickupBatch.id,
            kind: .mobileSalesConversion, fulfillment: .outsourced
        ))
    }

    func testClassicMarketTracksRisesStronglyAndFallsSlowly() {
        XCTAssertEqual(
            GameEngine.classicMarketChangeFactor(forNikkeiReturn: 0.10),
            1.18,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            GameEngine.classicMarketChangeFactor(forNikkeiReturn: -0.10),
            0.98,
            accuracy: 0.0001
        )
    }

    func testSportsAndClassicCertificationRequireTheirOwnPrerequisites() throws {
        let game = GameEngine()
        game.resetGame(simulationSeed: 33)
        startPlayableGame(game, simulationSeed: 33)
        let classic = try XCTUnwrap(VehicleCatalog.rareClassics.first)
        let classicBatch = {
            InventoryBatch(
                modelID: classic.id, category: classic.category, count: 1,
                averageCost: classic.baseWholesalePrice, quality: 0.60,
                modelYear: classic.classicProductionYears?.lowerBound ?? 1968,
                mileage: 80_000, acquiredTurn: game.turn
            )
        }
        game.stores[0].facilities = [.customWorkshop, .serviceWorkshop]
        game.stores[0].employees = [StoreEmployee(
            name: "専門整備士", salesSkill: 60, procurementSkill: 70,
            researchSkill: 60, serviceSkill: 90, monthlySalary: 55,
            assignment: .service
        )]
        game.stores[0].marketPolicy = StoreMarketPolicy(
            priorityCategories: [.sports], targetPurpose: .performance
        )
        game.stores[0].advertising = 500
        game.stores[0].reputation = 1.25
        game.stores[0].expertise.productization[.streetTuning] = 100
        game.stores[0].expertise.productization[.refurbishment] = 100
        game.stores[0].completedProjects[.streetTuning] = 3
        game.stores[0].completedProjects[.refurbishment] = 1
        game.stores[0].lifetimeProductSales[.sportTuned] = 2
        game.stores[0].inventory = [classicBatch(), classicBatch()]

        game.advanceWeek()

        XCTAssertTrue(game.stores[0].certifiedSpecialties.contains(.sportTuned))
        XCTAssertTrue(game.stores[0].certifiedSpecialties.contains(.collector))
        XCTAssertGreaterThanOrEqual(game.specialtyCertificationTier(for: game.stores[0], productKind: .sportTuned), 1)
        XCTAssertGreaterThanOrEqual(game.specialtyCertificationTier(for: game.stores[0], productKind: .collector), 1)
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
        game.cash = 100_000
        let storeID = game.stores[0].id
        let batch = game.stores[0].inventory.first { game.servicePreview(storeID: storeID, inventoryID: $0.id) != nil }!
        let preview = game.servicePreview(storeID: storeID, inventoryID: batch.id)!
        let beforeCash = game.cash

        XCTAssertTrue(game.serviceInventory(storeID: storeID, inventoryID: batch.id))
        XCTAssertEqual(beforeCash - game.cash, preview.cost)
        XCTAssertNotNil(game.stores[0].inventory.first(where: { $0.id == batch.id })?.workshopProject)
        for _ in 0..<3 { game.advanceWeek() }
        let serviced = game.stores[0].inventory.first(where: { $0.id == batch.id })!
        XCTAssertEqual(serviced.averageCost, batch.averageCost + preview.cost)
        XCTAssertEqual(Int((serviced.quality * 100).rounded()) - Int((batch.quality * 100).rounded()), preview.qualityGain)
        XCTAssertEqual(preview.qualityGain, 2)
        XCTAssertLessThanOrEqual(serviced.quality, 0.94)
        XCTAssertEqual(serviced.acquiredTurn, batch.acquiredTurn)
    }

    func testRareClassicAuctionCarsUse1970sOr1980sYearsAndCollectorPrices() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)

        let classics = game.auctionListings.filter { VehicleCatalog.entry(id: $0.modelID)?.isRareClassic == true }
        XCTAssertEqual(VehicleCatalog.rareClassics.count, 5)
        XCTAssertEqual(classics.count, 2, "通常72台の出品枠では希少旧車を周期的な2枠に限定する")
        let listing = try! XCTUnwrap(classics.first)
        let model = try! XCTUnwrap(VehicleCatalog.entry(id: listing.modelID))
        XCTAssertTrue(model.classicProductionYears?.contains(listing.modelYear) == true)
        XCTAssertLessThanOrEqual(listing.modelYear, 1970)
        XCTAssertGreaterThan(listing.marketPrice, listing.category.purchaseCost * 2)
        XCTAssertLessThan(listing.quality, 0.73)
        XCTAssertTrue(listing.seller.contains("現状渡し"))
        XCTAssertFalse(game.stores.flatMap(\.inventory).contains(where: \.isRareClassic))
    }

    func testRefurbishmentAndConversionExposeIndependentWorkRequirements() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities.insert(.customWorkshop)
        game.stores[0].employees = [StoreEmployee(name: "整備士", salesSkill: 50, procurementSkill: 65, researchSkill: 55, serviceSkill: 75, monthlySalary: 48, assignment: .service)]
        let storeID = game.stores[0].id
        let normal = InventoryBatch(modelID: "hokuto-ridge", category: .suv, count: 1, averageCost: 180, quality: 0.62, modelYear: 2024, mileage: 72_000, acquiredTurn: game.turn)
        let classic = InventoryBatch(modelID: "hokuto-trailclassic", category: .pickup, count: 1, averageCost: 500, quality: 0.50, modelYear: 1985, mileage: 128_000, acquiredTurn: game.turn)
        game.stores[0].inventory.append(contentsOf: [normal, classic])

        let outdoor = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: normal.id, kind: .outdoorConversion))
        let normalRefurbishment = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: normal.id, kind: .refurbishment))
        let classicRefurbishment = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: classic.id, kind: .refurbishment))

        XCTAssertEqual(outdoor.requiredWork, 2)
        XCTAssertEqual(normalRefurbishment.requiredWork, 1)
        XCTAssertEqual(normalRefurbishment.estimatedWeeks, 1)
        XCTAssertLessThanOrEqual(outdoor.estimatedWeeks, 4)
        XCTAssertGreaterThan(classicRefurbishment.cost, normalRefurbishment.cost)
        XCTAssertLessThanOrEqual(classicRefurbishment.resultingQuality, 90)
    }

    func testCustomProjectChargesCashBlocksSaleAndCompletesAfterSeveralWeeks() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities.insert(.customWorkshop)
        game.stores[0].employees = [StoreEmployee(name: "整備士", salesSkill: 50, procurementSkill: 65, researchSkill: 55, serviceSkill: 75, monthlySalary: 48, assignment: .service)]
        let storeID = game.stores[0].id
        let batch = InventoryBatch(modelID: "hokuto-ridge", category: .suv, count: 1, averageCost: 180, quality: 0.68, modelYear: 2025, mileage: 58_000, acquiredTurn: game.turn)
        game.stores[0].inventory.append(batch)
        XCTAssertNotNil(game.manualSaleQuote(storeID: storeID, inventoryID: batch.id))
        let preview = try! XCTUnwrap(game.workshopProjectPreview(storeID: storeID, inventoryID: batch.id, kind: .outdoorConversion))
        let beforeCash = game.cash

        XCTAssertEqual(preview.requiredWork, 2)
        XCTAssertTrue(game.startWorkshopProject(storeID: storeID, inventoryID: batch.id, kind: .outdoorConversion))
        XCTAssertEqual(beforeCash - game.cash, preview.cost)
        XCTAssertNil(game.manualSaleQuote(storeID: storeID, inventoryID: batch.id))
        XCTAssertNil(game.servicePreview(storeID: storeID, inventoryID: batch.id))

        for _ in 0..<preview.weeks { game.advanceWeek() }

        let completed = try! XCTUnwrap(game.stores[0].inventory.first(where: { $0.id == batch.id }))
        XCTAssertNil(completed.workshopProject)
        XCTAssertEqual(completed.productState, .outdoor)
        XCTAssertEqual(Int((completed.quality * 100).rounded()), preview.resultingQuality)
        XCTAssertEqual(completed.averageCost, batch.averageCost + preview.cost)
        XCTAssertEqual(completed.valueAddedInvestment, preview.cost)
        // 改装は無条件の店頭価格加算ではなく、用途が一致した顧客の支払意思額を上げる。
        XCTAssertGreaterThan(game.productPurposeValueFactor(for: completed, purpose: .outdoor), 1)
        XCTAssertGreaterThan(game.manualSaleQuote(storeID: storeID, inventoryID: batch.id)?.price ?? 0, 0)
    }

    func testCamperConversionCanBeOutsourcedButStillRequiresMinivan() {
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

        let outsourced = try! XCTUnwrap(game.workshopProjectPreview(
            storeID: storeID,
            inventoryID: minivan.id,
            kind: .camperConversion,
            fulfillment: .outsourced
        ))
        XCTAssertEqual(outsourced.outsourcePartner, .specialist)
        XCTAssertEqual(outsourced.weeks, 4)
        game.stores[0].facilities.insert(.customWorkshop)
        game.stores[0].employees = [StoreEmployee(name: "整備士", salesSkill: 50, procurementSkill: 65, researchSkill: 55, serviceSkill: 75, monthlySalary: 48, assignment: .service)]
        let preview = game.workshopProjectPreview(
            storeID: storeID,
            inventoryID: minivan.id,
            kind: .camperConversion,
            fulfillment: .inHouse
        )
        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.requiredWork, 2)
        XCTAssertLessThanOrEqual(preview?.estimatedWeeks ?? .max, 4)
        XCTAssertGreaterThan(preview?.cost ?? 0, minivan.category.purchaseCost)
    }

    func testConversionValueDependsOnBuyerPurposeWhileRefurbishmentAddsEightPercent() {
        let game = GameEngine()
        game.resetGame()
        let outdoor = InventoryBatch(modelID: "hokuto-ridge", category: .suv, count: 1, averageCost: 300, quality: 0.80, modelYear: 2025, mileage: 48_000, acquiredTurn: 0, productState: .outdoor)
        let refurbished = InventoryBatch(modelID: "hokuto-ridge", category: .suv, count: 1, averageCost: 300, quality: 0.80, modelYear: 2025, mileage: 48_000, acquiredTurn: 0, productState: .refurbished)

        XCTAssertEqual(game.productPurposeValueFactor(for: outdoor, purpose: .outdoor), 1.15, accuracy: 0.001)
        XCTAssertEqual(game.productPurposeValueFactor(for: outdoor, purpose: .general), 0.95, accuracy: 0.001)
        XCTAssertGreaterThan(game.specialtyCloseAdjustment(for: outdoor, purpose: .outdoor, in: .industrial), game.specialtyCloseAdjustment(for: outdoor, purpose: .general, in: .industrial))
        XCTAssertEqual(game.specialtyMarketFactor(for: refurbished, in: .suburb), 1.08, accuracy: 0.001)
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

    func testSelectiveAuctionCanBeMoreAccessibleThanStorePurchase() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let purchase = game.purchaseCases[0]
        let storeChance = game.purchaseNegotiationPreview(purchase.id, offerPercent: 94)!.closeChance
        let bestAuctionChance = game.auctionListings.map {
            game.auctionBidWinChance(for: $0, maxPrice: $0.marketPrice)
        }.max() ?? 0

        XCTAssertGreaterThan(bestAuctionChance, storeChance)
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

    func testMarketProductKindsSeparateStandardNichesAndCollectorCars() {
        XCTAssertEqual(MarketProductKind.resolve(productState: .stock, isRareClassic: false), .standard)
        XCTAssertEqual(MarketProductKind.resolve(productState: .serviced, isRareClassic: false), .standard)
        XCTAssertEqual(MarketProductKind.resolve(productState: .repaired, isRareClassic: false), .repaired)
        XCTAssertEqual(MarketProductKind.resolve(productState: .refurbished, isRareClassic: false), .refurbished)
        XCTAssertEqual(MarketProductKind.resolve(productState: .camper, isRareClassic: false), .camper)
        XCTAssertEqual(MarketProductKind.resolve(productState: .refurbished, isRareClassic: true), .collector)
    }

    func testNicheOpportunityHasLessDemandAndCanBeBlueOcean() {
        let game = GameEngine()
        game.resetGame(simulationSeed: 7)
        startPlayableGame(game)
        let store = game.stores[0]
        let district = game.plot(id: store.plotID)!.district
        for competitorIndex in game.competitors.indices {
            for branchIndex in game.competitors[competitorIndex].branches.indices
            where game.plot(id: game.competitors[competitorIndex].branches[branchIndex].plotID)?.district == district {
                game.competitors[competitorIndex].branches[branchIndex].inventory.removeAll()
            }
        }

        let reports = game.segmentOpportunityReports(storeID: store.id, district: district)
        let outdoor = try! XCTUnwrap(reports.first {
            $0.key.productKind == .outdoor && $0.key.category == .suv
        })
        let standard = try! XCTUnwrap(reports.first {
            $0.key.productKind == .standard && $0.key.category == .suv
        })

        XCTAssertGreaterThanOrEqual(outdoor.fourWeekDemand.lowerBound, 1)
        XCTAssertLessThan(outdoor.fourWeekDemand.upperBound, standard.fourWeekDemand.upperBound)
        XCTAssertEqual(outdoor.competingInventory, 0...0)
        XCTAssertEqual(outdoor.status, .blueOcean)
    }

    func testDistrictSpecialtyReportsUseOnlyCustomFocusedProductKinds() {
        let game = GameEngine()
        game.resetGame(simulationSeed: 71)
        startPlayableGame(game)
        let store = game.stores[0]
        let district = game.plot(id: store.plotID)!.district

        let reports = game.districtSpecialtyReports(
            storeID: store.id,
            district: district
        )
        let productKinds = Set(reports.map(\.productKind))

        XCTAssertEqual(productKinds, [
            .camper,
            .workCargo,
            .outdoor,
            .collector,
            .sportTuned,
            .welfare,
            .mobileShop
        ])
        XCTAssertFalse(productKinds.contains(.standard))
        XCTAssertFalse(productKinds.contains(.repaired))
        XCTAssertFalse(productKinds.contains(.refurbished))
    }

    func testDistrictSpecialtyReportsCountInventoryQueueAndTargetPolicyInDistrict() {
        let game = GameEngine()
        game.resetGame(simulationSeed: 73)
        startPlayableGame(game)
        let store = game.stores[0]
        let district = game.plot(id: store.plotID)!.district

        for competitorIndex in game.competitors.indices {
            game.competitors[competitorIndex].segmentTargetShare = [:]
            for branchIndex in game.competitors[competitorIndex].branches.indices {
                game.competitors[competitorIndex].branches[branchIndex].inventory.removeAll()
                game.competitors[competitorIndex].branches[branchIndex].productizationQueue.removeAll()
            }
        }

        let localCompetitorIndex = try! XCTUnwrap(
            game.competitors.indices.first { competitorIndex in
                game.competitors[competitorIndex].branches.contains {
                    game.plot(id: $0.plotID)?.district == district
                }
            }
        )
        let localBranchIndex = try! XCTUnwrap(
            game.competitors[localCompetitorIndex].branches.firstIndex {
                game.plot(id: $0.plotID)?.district == district
            }
        )
        let remoteLocation = try! XCTUnwrap(
            game.competitors.enumerated().compactMap { competitorIndex, competitor in
                competitor.branches.enumerated().first {
                    game.plot(id: $0.element.plotID)?.district != district
                }.map { (competitorIndex, $0.offset) }
            }.first
        )

        let camperInventory = CompetitorInventoryBucket(
            category: .minivan,
            purpose: .camper,
            count: 2,
            averageCost: 180,
            averageQuality: 0.82,
            productState: .camper,
            marketProductKind: .camper,
            productGrade: .middle
        )
        game.competitors[remoteLocation.0].branches[remoteLocation.1].inventory = [
            camperInventory
        ]

        var camper = try! XCTUnwrap(
            game.districtSpecialtyReports(storeID: store.id, district: district)
                .first { $0.productKind == .camper }
        )
        XCTAssertTrue(camper.isAbsent)
        XCTAssertEqual(camper.competitorBranchCount, 0)

        game.competitors[localCompetitorIndex].branches[localBranchIndex].inventory = [
            camperInventory
        ]
        camper = try! XCTUnwrap(
            game.districtSpecialtyReports(storeID: store.id, district: district)
                .first { $0.productKind == .camper }
        )
        XCTAssertEqual(camper.competitorBranchCount, 1)
        XCTAssertEqual(camper.competitorNames, [
            game.competitors[localCompetitorIndex].name
        ])
        XCTAssertEqual(game.districtSpecialtyBranchCount(in: district), 1)

        game.competitors[localCompetitorIndex].branches[localBranchIndex].inventory = []
        game.competitors[localCompetitorIndex].branches[localBranchIndex].productizationQueue = [
            CompetitorProductizationOrder(
                category: .minivan,
                purpose: .camper,
                productState: .camper,
                marketProductKind: .camper,
                productGrade: .middle,
                count: 1,
                unitCost: 240,
                quality: 0.86,
                outsourced: false,
                outsourcePartner: nil,
                weeksRemaining: 2
            )
        ]
        camper = try! XCTUnwrap(
            game.districtSpecialtyReports(storeID: store.id, district: district)
                .first { $0.productKind == .camper }
        )
        XCTAssertEqual(camper.competitorBranchCount, 1)

        game.competitors[localCompetitorIndex].branches[localBranchIndex].productizationQueue = []
        let camperKey = MarketSegmentKey(
            district: district,
            category: .minivan,
            purpose: .camper,
            productKind: .camper
        )
        game.competitors[localCompetitorIndex].segmentTargetShare[camperKey] = 0.25
        camper = try! XCTUnwrap(
            game.districtSpecialtyReports(storeID: store.id, district: district)
                .first { $0.productKind == .camper }
        )
        XCTAssertEqual(camper.competitorBranchCount, 1)

        let camperOpportunities = game.segmentOpportunityReports(
            storeID: store.id,
            district: district
        ).filter { $0.key.productKind == .camper }
        XCTAssertEqual(
            camper.fourWeekDemand,
            camperOpportunities.reduce(0) {
                $0 + $1.fourWeekDemand.lowerBound
            }...camperOpportunities.reduce(0) {
                $0 + $1.fourWeekDemand.upperBound
            }
        )
    }

    func testOutsourcedServiceHasNoBayOrWeeklyPartnerLimit() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities = []
        game.stores[0].employees = []
        let storeID = game.stores[0].id
        let batches = (0..<4).map { offset in
            InventoryBatch(
                modelID: "hokuto-ridge",
                category: .suv,
                count: 1,
                averageCost: 80,
                quality: 0.52,
                modelYear: 2022,
                mileage: 90_000 + offset * 1_000,
                acquiredTurn: game.turn,
                condition: VehicleConditionProfile(exterior: 55, interior: 54, mechanical: 42),
                fault: .minor
            )
        }
        game.stores[0].inventory = batches

        for batch in batches {
            let preview = try! XCTUnwrap(game.workshopProjectPreview(
                storeID: storeID,
                inventoryID: batch.id,
                kind: .repair,
                fulfillment: .outsourced
            ))
            XCTAssertEqual(preview.finalCostRate, 100)
            XCTAssertTrue(game.startWorkshopProject(
                storeID: storeID,
                inventoryID: batch.id,
                kind: .repair,
                fulfillment: .outsourced
            ))
        }
        XCTAssertEqual(game.stores[0].weeklyWorkshopLabor, 0)
        XCTAssertEqual(game.stores[0].inventory.filter {
            $0.workshopProject?.kind == .repair
                && $0.workshopProject?.outsourced == true
        }.count, batches.count)
    }

    func testOutsourcedCustomizationsHaveNoBayOrWeeklyPartnerLimit() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities = []
        game.stores[0].employees = []
        let storeID = game.stores[0].id
        let batches = (0..<5).map { offset in
            InventoryBatch(
                modelID: "hokuto-ridge",
                category: .suv,
                count: 1,
                averageCost: 180,
                quality: 0.72,
                modelYear: 2024,
                mileage: 40_000 + offset * 1_000,
                acquiredTurn: game.turn
            )
        }
        game.stores[0].inventory = batches

        for batch in batches {
            let preview = try! XCTUnwrap(game.workshopProjectPreview(
                storeID: storeID,
                inventoryID: batch.id,
                kind: .outdoorConversion,
                fulfillment: .outsourced
            ))
            XCTAssertEqual(preview.finalCostRate, 100)
            XCTAssertTrue(game.startWorkshopProject(
                storeID: storeID,
                inventoryID: batch.id,
                kind: .outdoorConversion,
                fulfillment: .outsourced
            ))
        }

        XCTAssertEqual(game.stores[0].customizationBays, 0)
        XCTAssertEqual(game.stores[0].inventory.filter {
            $0.workshopProject?.kind == .outdoorConversion
                && $0.workshopProject?.outsourced == true
        }.count, batches.count)
    }

    func testResearchSkillRevealsUpcomingTrendWithoutMakingItCertain() {
        let game = GameEngine()
        game.resetGame(simulationSeed: 19)
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let district = game.plot(id: game.stores[0].plotID)!.district
        game.stores[0].employees = []
        game.segmentTrends = [SegmentTrend(
            kind: .outdoorBoom,
            districts: [district],
            categories: [.suv, .pickup, .minivan],
            startTurn: game.turn + 6,
            peakWeeks: 8,
            peakMultiplier: 2.1
        )]

        let noResearch = game.segmentOpportunityReports(storeID: storeID, district: district)
            .first { $0.key.productKind == .outdoor && $0.key.category == .suv }
        XCTAssertNil(noResearch?.trendSignal)

        game.stores[0].employees = [StoreEmployee(
            name: "先読み調査員",
            salesSkill: 45,
            procurementSkill: 55,
            researchSkill: 90,
            serviceSkill: 40,
            monthlySalary: 48,
            assignment: .research
        )]
        let researched = game.segmentOpportunityReports(storeID: storeID, district: district)
            .first { $0.key.productKind == .outdoor && $0.key.category == .suv }
        let signal = try! XCTUnwrap(researched?.trendSignal)
        XCTAssertEqual(signal.kind, .outdoorBoom)
        XCTAssertEqual(signal.confidenceRange, 80...95)
        XCTAssertNotEqual(signal.confidenceRange, 100...100)
    }

    func testMarketPivotKeepsAssetsAndUsesTwoWeekRecognitionRamp() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.stores[0].facilities.insert(.serviceWorkshop)
        game.stores[0].employees = [StoreEmployee(
            name: "残留整備士",
            salesSkill: 50,
            procurementSkill: 65,
            researchSkill: 45,
            serviceSkill: 80,
            monthlySalary: 50,
            assignment: .service
        )]
        game.stores[0].expertise.productization[.repair] = 22
        var changed = game.stores[0]
        changed.marketPolicy = StoreMarketPolicy(
            priorityCategories: [.pickup],
            targetPurpose: .work,
            acceptedConditions: [.normal, .rough, .faulty]
        )
        game.updateStore(changed)

        game.advanceWeek()
        XCTAssertEqual(game.stores[0].marketPolicy.targetPurpose, .work)
        XCTAssertEqual(game.stores[0].marketRepositioningWeeks, 2)
        XCTAssertTrue(game.stores[0].facilities.contains(.serviceWorkshop))
        XCTAssertEqual(game.stores[0].employees.first?.name, "残留整備士")
        XCTAssertEqual(game.stores[0].expertise.productization[.repair], 22)

        game.advanceWeek()
        XCTAssertEqual(game.stores[0].marketRepositioningWeeks, 1)
        game.advanceWeek()
        XCTAssertEqual(game.stores[0].marketRepositioningWeeks, 0)
    }

    func testVintageAndNeoClassicSportsAreDisjointAndVintageEndsBy1970() {
        let vintageIDs = Set(VehicleCatalog.rareClassics.map(\.id))
        let neoClassicIDs = Set(VehicleCatalog.all.filter(\.isNeoClassicSport).map(\.id))

        XCTAssertEqual(vintageIDs.count, 5)
        XCTAssertEqual(neoClassicIDs.count, 6)
        XCTAssertTrue(vintageIDs.isDisjoint(with: neoClassicIDs))
        XCTAssertTrue(VehicleCatalog.rareClassics.allSatisfy {
            ($0.classicProductionYears?.upperBound ?? Int.max) <= 1970
        })
        XCTAssertTrue(VehicleCatalog.rareClassics.allSatisfy { !$0.isSportTuningBase || $0.isRareClassic })
    }

    func testNewSpecialtyPackagesExposePlannedCostsWorkAndPriceCaps() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities.insert(.customWorkshop)
        game.stores[0].employees.append(StoreEmployee(
            name: "専門整備士", salesSkill: 45, procurementSkill: 55,
            researchSkill: 45, serviceSkill: 90,
            monthlySalary: 55, assignment: .service
        ))
        let storeID = game.stores[0].id
        let specifications: [(WorkshopProjectKind, VehicleCategory, Double, Int, Double)] = [
            (.streetTuning, .sports, 0.22, 5, 1.45),
            (.driftTuning, .sports, 0.38, 7, 1.75),
            (.circuitTuning, .sports, 0.55, 9, 2.00),
            (.liftSeatConversion, .compact, 0.22, 5, 1.30),
            (.wheelchairConversion, .minivan, 0.40, 8, 1.60),
            (.mobileSalesConversion, .pickup, 0.30, 6, 1.45),
            (.kitchenCarConversion, .pickup, 0.60, 10, 1.90)
        ]

        for (kind, category, costRate, _, priceCap) in specifications {
            let model = try XCTUnwrap(VehicleCatalog.all.first {
                $0.category == category && !$0.isRareClassic
            })
            let batch = InventoryBatch(
                modelID: model.id,
                category: category,
                count: 1,
                averageCost: model.baseWholesalePrice,
                quality: 0.74,
                modelYear: game.year - 4,
                mileage: 52_000,
                acquiredTurn: game.turn
            )
            game.stores[0].inventory = [batch]
            let preview = try XCTUnwrap(game.workshopProjectPreview(
                storeID: storeID,
                inventoryID: batch.id,
                kind: kind,
                fulfillment: .inHouse
            ), kind.name)
            let minimumCost: Int = switch kind {
            case .streetTuning: 70
            case .driftTuning: 120
            case .circuitTuning: 180
            case .liftSeatConversion: 65
            case .wheelchairConversion: 110
            case .mobileSalesConversion: 90
            case .kitchenCarConversion: 170
            default: 0
            }
            let rawCost = max(minimumCost, Int(Double(model.referenceRetailPrice) * costRate))
            let partner = OutsourcePartnerKind.partner(for: kind)
            XCTAssertEqual(
                preview.outsourceBaselineCost,
                Int((Double(rawCost) * partner.costMultiplier).rounded()),
                kind.name
            )
            XCTAssertEqual(
                preview.requiredWork,
                max(1, 2 - kind.completionInspectionWeeks),
                kind.name
            )
            XCTAssertGreaterThanOrEqual(
                preview.estimatedWeeks,
                kind.completionInspectionWeeks + 1,
                kind.name
            )
            XCTAssertLessThanOrEqual(
                preview.estimatedWeeks,
                4,
                kind.name
            )
            XCTAssertLessThanOrEqual(
                preview.projectedSalePrice,
                Int(Double(model.referenceRetailPrice) * priceCap),
                kind.name
            )
            XCTAssertEqual(kind.productState?.purpose, MarketProductKind.resolve(
                productState: kind.productState ?? .stock,
                isRareClassic: false
            ).customerPurpose)
        }

        let vintage = try XCTUnwrap(VehicleCatalog.rareClassics.first)
        let vintageBatch = InventoryBatch(
            modelID: vintage.id,
            category: vintage.category,
            count: 1,
            averageCost: vintage.baseWholesalePrice,
            quality: 0.60,
            modelYear: vintage.classicProductionYears!.upperBound,
            mileage: 80_000,
            acquiredTurn: game.turn
        )
        game.stores[0].inventory = [vintageBatch]
        XCTAssertNil(game.workshopProjectPreview(
            storeID: storeID,
            inventoryID: vintageBatch.id,
            kind: .streetTuning
        ))
    }

    func testSpecialtyGradesScaleCostPriceAndSupportIncrementalUpgrades() throws {
        let game = GameEngine()
        game.resetGame(simulationSeed: 301)
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities.insert(.customWorkshop)
        game.stores[0].employees = [StoreEmployee(
            name: "グレード担当", salesSkill: 50, procurementSkill: 60,
            researchSkill: 55, serviceSkill: 90,
            monthlySalary: 55, assignment: .service
        )]
        let storeID = game.stores[0].id
        let district = try XCTUnwrap(game.plot(id: game.stores[0].plotID)?.district)
        let batch = InventoryBatch(
            modelID: "hokuto-ridge",
            category: .suv,
            count: 1,
            averageCost: 220,
            quality: 0.76,
            modelYear: game.year - 3,
            mileage: 42_000,
            acquiredTurn: game.turn
        )
        game.stores[0].inventory = [batch]
        game.segmentTrends = [SegmentTrend(
            kind: .outdoorBoom,
            districts: [district],
            categories: [.suv],
            startTurn: game.turn - 6,
            rampWeeks: 6,
            peakWeeks: 12,
            decayWeeks: 6,
            peakMultiplier: 3.4
        )]

        let low = try XCTUnwrap(game.workshopProjectPreview(
            storeID: storeID, inventoryID: batch.id, kind: .outdoorConversion,
            grade: .low, fulfillment: .inHouse
        ))
        let middle = try XCTUnwrap(game.workshopProjectPreview(
            storeID: storeID, inventoryID: batch.id, kind: .outdoorConversion,
            grade: .middle, fulfillment: .inHouse
        ))
        let high = try XCTUnwrap(game.workshopProjectPreview(
            storeID: storeID, inventoryID: batch.id, kind: .outdoorConversion,
            grade: .high, fulfillment: .inHouse
        ))

        XCTAssertEqual(low.grade, .low)
        XCTAssertEqual(middle.grade, .middle)
        XCTAssertEqual(high.grade, .high)
        XCTAssertEqual(SpecialtyProductGrade.high.name(for: .camper), "ラグジュアリー")
        XCTAssertEqual(SpecialtyProductGrade.high.name(for: .collector), "純正フルレストア")
        XCTAssertGreaterThan(middle.cost, low.cost)
        XCTAssertGreaterThan(high.cost, middle.cost)
        XCTAssertGreaterThan(Double(high.cost) / Double(low.cost), 2.5)
        XCTAssertGreaterThan(high.projectedSalePrice, low.projectedSalePrice)
        let model = try XCTUnwrap(VehicleCatalog.entry(id: batch.modelID))
        XCTAssertLessThanOrEqual(
            high.projectedSalePrice,
            Int(Double(model.referenceRetailPrice) * 3.2)
        )
        XCTAssertEqual(low.requiredWork, 2)
        XCTAssertEqual(middle.requiredWork, 3)
        XCTAssertEqual(high.requiredWork, 4)

        XCTAssertTrue(game.startWorkshopProject(
            storeID: storeID, inventoryID: batch.id, kind: .outdoorConversion,
            grade: .low, fulfillment: .inHouse
        ))
        for _ in 0..<low.estimatedWeeks { game.advanceWeek() }
        XCTAssertEqual(game.stores[0].inventory.first?.productGrade, .low)
        XCTAssertNil(game.workshopProjectPreview(
            storeID: storeID, inventoryID: batch.id, kind: .outdoorConversion,
            grade: .low, fulfillment: .inHouse
        ))
        let upgrade = try XCTUnwrap(game.workshopProjectPreview(
            storeID: storeID, inventoryID: batch.id, kind: .outdoorConversion,
            grade: .middle, fulfillment: .inHouse
        ))
        XCTAssertLessThan(upgrade.cost, middle.cost)
        XCTAssertTrue(game.startWorkshopProject(
            storeID: storeID, inventoryID: batch.id, kind: .outdoorConversion,
            grade: .middle, fulfillment: .inHouse
        ))
        for _ in 0..<upgrade.estimatedWeeks { game.advanceWeek() }
        XCTAssertEqual(game.stores[0].inventory.first?.productGrade, .middle)
    }

    func testBuyerGradeIsMinimumAndHigherGradeInventoryIsAccepted() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let high = InventoryBatch(
            modelID: "hokuto-ridge", category: .suv, count: 1,
            averageCost: 300, quality: 0.90, modelYear: game.year - 2,
            mileage: 30_000, acquiredTurn: game.turn,
            productState: .outdoor, productGrade: .high
        )
        let low = InventoryBatch(
            modelID: "hokuto-ridge", category: .suv, count: 1,
            averageCost: 200, quality: 0.90, modelYear: game.year - 2,
            mileage: 30_000, acquiredTurn: game.turn,
            productState: .outdoor, productGrade: .low
        )
        game.stores[0].inventory = [high, low]
        let lead = BuyerLead(
            id: UUID(), storeID: storeID, preference: .category(.suv),
            budget: 100_000, minimumQuality: 0.70,
            priceSensitivity: 1, generatedTurn: game.turn,
            purpose: .outdoor, desiredProductKind: .outdoor, desiredGrade: .middle
        )

        XCTAssertTrue(game.inventoryMatchesBuyer(high, lead: lead, storeID: storeID))
        XCTAssertFalse(game.inventoryMatchesBuyer(low, lead: lead, storeID: storeID))
    }

    func testCollectorCustomizationOrderUsesServiceBayAndKeepsExactGrade() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities = [.serviceWorkshop]
        game.stores[0].employees = [StoreEmployee(
            name: "旧車職人", salesSkill: 45, procurementSkill: 55,
            researchSkill: 45, serviceSkill: 90,
            monthlySalary: 58, assignment: .service
        )]
        let classic = try XCTUnwrap(VehicleCatalog.rareClassics.first)
        let order = CustomerCustomizationOrder(
            id: UUID(), storeID: game.stores[0].id,
            modelID: classic.id, category: classic.category,
            kind: .refurbishment, grade: .high,
            quotedRevenue: 2_000, materialCost: 900,
            requiredWork: 1, remainingWork: 1,
            generatedTurn: game.turn, expiresTurn: game.turn + 1,
            startedTurn: nil, priority: 1, status: .pending
        )
        game.customerCustomizationOrders = [order]

        XCTAssertTrue(game.acceptCustomizationOrder(order.id))
        XCTAssertEqual(game.customerCustomizationOrders.first?.grade, .high)
        XCTAssertEqual(game.customerCustomizationOrders.first?.status, .active)
    }

    func testSegmentTrendUsesSixTwelveSixProfile() {
        let trend = SegmentTrend(
            kind: .campingBoom,
            districts: [.suburb],
            categories: [.minivan],
            startTurn: 10,
            rampWeeks: 6,
            peakWeeks: 12,
            decayWeeks: 6,
            peakMultiplier: 4
        )

        XCTAssertEqual(trend.endTurn, 34)
        XCTAssertGreaterThan(trend.multiplier(at: 10), 1)
        XCTAssertLessThan(trend.multiplier(at: 10), 4)
        XCTAssertEqual(trend.multiplier(at: 15), 4, accuracy: 0.001)
        XCTAssertEqual(trend.multiplier(at: 27), 4, accuracy: 0.001)
        XCTAssertLessThan(trend.multiplier(at: 28), 4)
        XCTAssertEqual(trend.multiplier(at: 34), 1, accuracy: 0.001)
    }

    func testSpecialtyGradeDemandShiftsToHighGradeAtTrendPeak() {
        let game = GameEngine()
        game.resetGame(simulationSeed: 812)
        startPlayableGame(game)
        let district = try! XCTUnwrap(game.plot(id: game.stores[0].plotID)?.district)
        let key = MarketSegmentKey(
            district: district,
            category: .suv,
            purpose: .outdoor,
            productKind: .outdoor
        )

        let baseline = game.specialtyGradeDemandShares(for: key)
        XCTAssertEqual(baseline[.low] ?? 0, 0.65, accuracy: 0.001)
        XCTAssertEqual(baseline[.middle] ?? 0, 0.30, accuracy: 0.001)
        XCTAssertEqual(baseline[.high] ?? 0, 0.05, accuracy: 0.001)

        game.segmentTrends = [SegmentTrend(
            kind: .outdoorBoom,
            districts: [key.district],
            categories: [key.category],
            startTurn: game.turn - 6,
            peakWeeks: 12,
            peakMultiplier: 4
        )]
        let peak = game.specialtyGradeDemandShares(for: key)
        XCTAssertEqual(peak[.low] ?? 0, 0.15, accuracy: 0.001)
        XCTAssertEqual(peak[.middle] ?? 0, 0.35, accuracy: 0.001)
        XCTAssertEqual(peak[.high] ?? 0, 0.50, accuracy: 0.001)
    }

    func testScheduledTrendsStartSixToTenWeeksApartWithoutSameKindOverlap() {
        let game = GameEngine()
        game.resetGame(simulationSeed: 811)
        startPlayableGame(game)
        game.cash = 1_000_000
        game.debt = 0
        var observed: [UUID: SegmentTrend] = [:]

        for _ in 0..<72 {
            game.advanceWeek()
            for trend in game.segmentTrends { observed[trend.id] = trend }
            let active = game.segmentTrends.filter {
                $0.startTurn <= game.turn && $0.endTurn > game.turn
            }
            XCTAssertLessThanOrEqual(active.count, 4)
            XCTAssertEqual(Set(active.map(\.kind)).count, active.count)
        }

        let starts = observed.values.map(\.startTurn).sorted()
        XCTAssertGreaterThan(starts.count, 6)
        XCTAssertEqual(starts.first, 8)
        for pair in zip(starts, starts.dropFirst()) {
            XCTAssertTrue((6...10).contains(pair.1 - pair.0))
        }
        XCTAssertTrue(observed.values.allSatisfy { $0.endTurn - $0.startTurn == 24 })
    }

    func testSpecialtyStorePurchasesAreMostlyPriorityCategoryAndReferralPriceIsCapped() throws {
        let game = GameEngine()
        game.resetGame(simulationSeed: 91)
        startPlayableGame(game, simulationSeed: 91)
        game.cash = 100_000
        game.stores[0].marketPolicy = StoreMarketPolicy(
            priorityCategories: [.sports],
            targetPurpose: .performance,
            acceptedConditions: [.normal, .rough]
        )
        game.stores[0].facilities.insert(.customWorkshop)
        game.stores[0].employees.append(StoreEmployee(
            name: "チューナー", salesSkill: 50, procurementSkill: 70,
            researchSkill: 50, serviceSkill: 90,
            monthlySalary: 58, assignment: .service
        ))
        game.stores[0].expertise.productization[.streetTuning] = 50
        let district = game.plot(id: game.stores[0].plotID)!.district
        game.segmentTrends = [SegmentTrend(
            kind: .motorsportBoom,
            districts: [district],
            categories: [.sports],
            startTurn: game.turn,
            peakWeeks: 12,
            peakMultiplier: 3.8
        )]

        var total = 0
        var priority = 0
        var referrals: [PurchaseCase] = []
        for _ in 0..<8 {
            game.advanceWeek()
            let weekly = game.purchaseCases.filter { $0.storeID == game.stores[0].id }
            total += weekly.count
            priority += weekly.filter { $0.category == .sports }.count
            referrals += weekly.filter { $0.origin == .specialtyReferral }
        }

        XCTAssertGreaterThan(total, 0)
        XCTAssertGreaterThanOrEqual(Double(priority) / Double(total), 0.65)
        let referral = try XCTUnwrap(referrals.first)
        XCTAssertLessThanOrEqual(Double(referral.askingPrice), Double(referral.appraisedPrice) * 1.24)
        XCTAssertNotNil(referral.suggestedProjectKind)
        XCTAssertGreaterThan(game.purchaseExpectedGrossProfit(for: referral), referral.asIsExpectedGrossProfit)
    }

    func testCustomerOrdersCompeteWithInventoryForCustomizationBaysAndLabor() throws {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        game.stores[0].facilities.insert(.customWorkshop)
        game.stores[0].employees = [StoreEmployee(
            name: "工房担当", salesSkill: 40, procurementSkill: 50,
            researchSkill: 40, serviceSkill: 80,
            monthlySalary: 50, assignment: .service
        )]
        let storeID = game.stores[0].id
        let model = try XCTUnwrap(VehicleCatalog.all.first { $0.category == .sports && !$0.isRareClassic })
        let batch = InventoryBatch(
            modelID: model.id,
            category: .sports,
            count: 1,
            averageCost: model.baseWholesalePrice,
            quality: 0.70,
            modelYear: 1999,
            mileage: 82_000,
            acquiredTurn: game.turn
        )
        game.stores[0].inventory = [batch]
        XCTAssertTrue(game.startWorkshopProject(
            storeID: storeID,
            inventoryID: batch.id,
            kind: .circuitTuning,
            fulfillment: .inHouse
        ))
        let orders = (0..<2).map { offset in
            CustomerCustomizationOrder(
                id: UUID(),
                storeID: storeID,
                modelID: model.id,
                category: .sports,
                kind: .streetTuning,
                quotedRevenue: 300,
                materialCost: 100,
                requiredWork: 5,
                remainingWork: 5,
                generatedTurn: game.turn,
                expiresTurn: game.turn + 1,
                startedTurn: nil,
                priority: offset,
                status: .pending
            )
        }
        game.customerCustomizationOrders = orders
        XCTAssertTrue(game.acceptCustomizationOrder(orders[0].id))
        XCTAssertFalse(game.acceptCustomizationOrder(orders[1].id), "2ベイを在庫改造と持ち込み案件が占有する")
        game.advanceWeek()
        XCTAssertEqual(
            game.customerCustomizationOrders.first(where: { $0.id == orders[0].id })?.remainingWork,
            3,
            "在庫改造が先に工数を使い、残った工数だけが持ち込み案件へ配分される"
        )
    }

    func testInventorySaleRequiresFortyPercentStockRunsFourWeeksAndSetsCooldown() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let required = Int(ceil(Double(game.stores[0].type.capacity) * 0.40))
        let model = VehicleCatalog.all.first { $0.category == .compact && !$0.isRareClassic }!
        game.stores[0].inventory = [InventoryBatch(
            modelID: model.id,
            category: .compact,
            count: required,
            modelYear: game.year - 3,
            mileage: 40_000,
            acquiredTurn: game.turn
        )]
        let cost = InventorySaleTier.twenty.advertisingCost(capacity: game.stores[0].type.capacity)
        let beforeCash = game.cash

        XCTAssertTrue(game.startInventorySaleCampaign(storeID: game.stores[0].id, tier: .twenty))
        XCTAssertEqual(beforeCash - game.cash, cost)
        XCTAssertEqual(game.stores[0].inventorySaleCampaign?.remainingWeeks, 4)
        XCTAssertEqual(InventorySaleTier.twenty.trafficMultiplier, 2.4)
        XCTAssertEqual(InventorySaleTier.twenty.closeBonus, 0.16)
        for _ in 0..<4 { game.advanceWeek() }
        XCTAssertNil(game.stores[0].inventorySaleCampaign)
        XCTAssertEqual(game.stores[0].inventorySaleCooldownWeeks, 12)
        XCTAssertFalse(game.canStartInventorySaleCampaign(storeID: game.stores[0].id, tier: .ten))
        XCTAssertEqual(game.advertisingAttractionFactor(0), 0.80, accuracy: 0.001)
        XCTAssertEqual(game.advertisingAttractionFactor(500), 1.60, accuracy: 0.001)
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
            monthlySalary: 44, commissionRate: 8, assignment: .sales,
            recentCommissions: [1, 2, 3]
        )]
        game.stores[0].autoSales = true
        game.stores[0].autoMarketing = true
        game.stores[0].salesPolicy = .profit
        game.stores[0].manager = StoreManager(
            name: "保存店長", staffingAbility: 70, salesAbility: 71,
            procurementAbility: 88, researchAbility: 72,
            serviceAbility: 76, monthlySalary: 60
        )
        game.stores[0].delegateProcurement = true
        let savedInstructionID = game.createProcurementInstruction(
            storeID: game.stores[0].id,
            totalBudget: 900,
            financialRule: .minimumGrossProfit(55),
            category: .suv,
            modelID: nil,
            faultOnly: true,
            allowedSources: [.auction, .dealerTrade]
        )
        XCTAssertNotNil(savedInstructionID)
        game.stores[0].marketPolicy = StoreMarketPolicy(
            priorityCategories: [.suv], targetPurpose: .outdoor,
            acceptedConditions: [.normal, .rough, .faulty]
        )
        game.stores[0].expertise.productization[.outdoorConversion] = 18
        game.companyExpertise.categories[.suv] = 24
        let savedSeed = game.simulationSeed
        let segmentKey = MarketSegmentKey(
            district: game.plot(id: game.stores[0].plotID)!.district,
            category: .suv,
            purpose: .outdoor,
            productKind: .outdoor
        )
        let segmentRecord = SegmentWeekRecord(
            turn: game.turn,
            demand: 3,
            playerSales: 1,
            unmetDemand: 2,
            playerRevenue: 500,
            playerCost: 310
        )
        game.segmentMarkets[segmentKey] = SegmentMarketState(
            demandCarry: 0.4,
            records: [segmentRecord],
            blueOceanWeeks: 5
        )
        game.segmentTrends = [SegmentTrend(
            kind: .outdoorBoom,
            districts: [segmentKey.district],
            categories: [.suv],
            startTurn: game.turn + 2,
            peakWeeks: 8,
            peakMultiplier: 2.1
        )]
        game.stores[0].segmentRecords[segmentKey] = [segmentRecord]
        game.stores[0].marketRepositioningWeeks = 2
        game.stores[0].inventorySaleCampaign = InventorySaleCampaign(
            tier: .fifteen,
            startedTurn: game.turn,
            remainingWeeks: 3
        )
        game.stores[0].inventory[0].productState = .outdoor
        game.stores[0].inventory[0].productGrade = .high
        game.stores[0].inventorySaleCooldownWeeks = 0
        let savedCustomizationOrder = CustomerCustomizationOrder(
            id: UUID(),
            storeID: game.stores[0].id,
            modelID: "aoba-razor-s13",
            category: .sports,
            kind: .driftTuning,
            grade: .high,
            quotedRevenue: 440,
            materialCost: 220,
            requiredWork: 7,
            remainingWork: 5,
            generatedTurn: game.turn,
            expiresTurn: game.turn + 1,
            startedTurn: game.turn,
            priority: 2,
            status: .active
        )
        game.customerCustomizationOrders = [savedCustomizationOrder]
        game.competitors[0].segmentResponseWeeks[segmentKey] = 8
        game.competitors[0].segmentRecords[segmentKey] = [segmentRecord]
        game.competitors[0].branches[0].productizationQueue = [
            CompetitorProductizationOrder(
                category: .suv,
                purpose: .outdoor,
                productState: .outdoor,
                marketProductKind: .outdoor,
                productGrade: .middle,
                count: 1,
                unitCost: 420,
                quality: 0.9,
                outsourced: true,
                outsourcePartner: .fabrication,
                weeksRemaining: 4
            )
        ]

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
        XCTAssertEqual(game.stores[0].employees[0].commissionRate, 8)
        XCTAssertEqual(game.stores[0].employees[0].recentCommissions, [1, 2, 3])
        XCTAssertEqual(game.procurementInstructions.first?.id, savedInstructionID)
        XCTAssertEqual(game.procurementInstructions.first?.financialRule, .minimumGrossProfit(55))
        XCTAssertTrue(game.procurementInstructions.first?.faultOnly == true)
        XCTAssertEqual(game.procurementInstructions.first?.allowedSources, [.auction, .dealerTrade])
        XCTAssertTrue(game.stores[0].delegateProcurement)
        XCTAssertEqual(game.stores[0].manager?.procurementAbility, 88)
        XCTAssertFalse(game.onlineListings.isEmpty)
        XCTAssertEqual(game.stores[0].marketPolicy.targetPurpose, .outdoor)
        XCTAssertEqual(game.stores[0].marketPolicy.acceptedConditions, [.normal, .rough, .faulty])
        XCTAssertEqual(game.stores[0].expertise.productization[.outdoorConversion], 18)
        XCTAssertEqual(game.companyExpertise.categories[.suv], 24)
        XCTAssertEqual(game.simulationSeed, savedSeed)
        XCTAssertEqual(game.segmentMarkets[segmentKey]?.demandCarry, 0.4)
        XCTAssertEqual(game.segmentMarkets[segmentKey]?.blueOceanWeeks, 5)
        XCTAssertEqual(game.segmentTrends.first?.peakMultiplier, 2.1)
        XCTAssertEqual(game.stores[0].segmentRecords[segmentKey]?.first?.playerSales, 1)
        XCTAssertEqual(game.stores[0].marketRepositioningWeeks, 2)
        XCTAssertEqual(game.stores[0].inventorySaleCampaign?.tier, .fifteen)
        XCTAssertEqual(game.stores[0].inventorySaleCampaign?.remainingWeeks, 3)
        XCTAssertEqual(game.stores[0].inventory.first?.productGrade, .high)
        XCTAssertEqual(game.customerCustomizationOrders.first?.id, savedCustomizationOrder.id)
        XCTAssertEqual(game.customerCustomizationOrders.first?.grade, .high)
        XCTAssertEqual(game.customerCustomizationOrders.first?.remainingWork, 5)
        XCTAssertEqual(game.competitors[0].segmentResponseWeeks[segmentKey], 8)
        XCTAssertEqual(game.competitors[0].branches[0].productizationQueue.first?.outsourcePartner, .fabrication)
        XCTAssertEqual(game.competitors[0].branches[0].productizationQueue.first?.productGrade, .middle)
    }

    func testVersion47SaveIsNotLoadedAfterVersion48ModelChange() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "UsedCarCity.save.v48")
        defaults.set(Data([0x01, 0x02, 0x03]), forKey: "UsedCarCity.save.v47")
        defer {
            defaults.removeObject(forKey: "UsedCarCity.save.v47")
            defaults.removeObject(forKey: "UsedCarCity.save.v48")
        }

        let game = GameEngine()
        XCTAssertFalse(game.hasSaveData)
        XCTAssertFalse(game.hasStarted)
    }

    func testProcurementInstructionNormalizesModelAndSupportsLifecycle() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id
        let model = VehicleCatalog.all.first { $0.usedMarketTurn <= game.turn }!

        let instructionID = try! XCTUnwrap(game.createProcurementInstruction(
            storeID: storeID,
            totalBudget: 1_000,
            financialRule: .maximumOffer(180),
            category: model.category == .suv ? .kei : .suv,
            modelID: model.id,
            faultOnly: false
        ))
        var instruction = try! XCTUnwrap(game.procurementInstructions(for: storeID).first)
        XCTAssertEqual(instruction.id, instructionID)
        XCTAssertEqual(instruction.category, model.category)
        XCTAssertEqual(instruction.remainingBudget, 1_000)

        XCTAssertTrue(game.setProcurementInstructionStatus(instructionID, status: .paused))
        XCTAssertEqual(game.procurementInstructions(for: storeID).first?.status, .paused)
        instruction = game.procurementInstructions(for: storeID).first!
        instruction.totalBudget = 1_200
        instruction.financialRule = .minimumGrossProfit(60)
        XCTAssertTrue(game.updateProcurementInstruction(instruction))
        XCTAssertEqual(game.procurementInstructions(for: storeID).first?.financialRule, .minimumGrossProfit(60))

        game.deleteProcurementInstruction(instructionID)
        XCTAssertTrue(game.procurementInstructions(for: storeID).isEmpty)
    }

    func testOnlineManualBidRequiresProcurementEmployeeAndAutomationOff() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let listing = game.onlineListings[0]

        game.stores[0].employees = []
        XCTAssertFalse(game.reserveOnlineBid(
            listingID: listing.id,
            storeID: storeID,
            maxPrice: listing.marketPrice
        ))

        game.stores[0].employees = [StoreEmployee(
            name: "ネット仕入",
            salesSkill: 60,
            procurementSkill: 90,
            researchSkill: 60,
            serviceSkill: 50,
            monthlySalary: 45,
            assignment: .procurement
        )]
        XCTAssertTrue(game.reserveOnlineBid(
            listingID: listing.id,
            storeID: storeID,
            maxPrice: max(listing.reservePrice, listing.marketPrice)
        ))
        game.cancelOnlineBid(listingID: listing.id)
        XCTAssertFalse(game.onlineBidReservations.contains { $0.listingID == listing.id })

        game.stores[0].autoProcurement = true
        XCTAssertFalse(game.reserveOnlineBid(
            listingID: listing.id,
            storeID: storeID,
            maxPrice: listing.marketPrice
        ))
    }

    func testAutomaticFaultOnlyOnlineBidReservesAndReleasesInstructionBudget() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        game.stores[0].employees = [
            StoreEmployee(
                name: "故障車バイヤー",
                salesSkill: 50, procurementSkill: 95,
                researchSkill: 85, serviceSkill: 50,
                monthlySalary: 55, assignment: .procurement
            ),
            StoreEmployee(
                name: "ネット査定整備士",
                salesSkill: 40, procurementSkill: 40,
                researchSkill: 55, serviceSkill: 95,
                monthlySalary: 55, assignment: .service
            )
        ]
        game.stores[0].autoProcurement = true
        game.purchaseCases = []
        game.auctionListings = []
        let listing = try! XCTUnwrap(game.onlineListings.first { listing in
            guard listing.fault != .none,
                  game.onlineAssessment(for: listing, storeID: storeID).detectedFault != nil,
                  let categoryIndex = VehicleCategory.allCases.firstIndex(of: listing.category) else { return false }
            let seed = listing.modelYear * 17 + listing.mileage / 500 + categoryIndex * 61
            let raw = abs((seed &* 1_664_525 &+ 1_013_904_223) % 10_000)
            return Double(raw) / 10_000 <= 0.89
        })
        game.onlineListings = [listing]
        let instructionID = try! XCTUnwrap(game.createProcurementInstruction(
            storeID: storeID,
            totalBudget: 10_000,
            financialRule: .maximumOffer(8_000),
            category: listing.category,
            modelID: listing.modelID,
            faultOnly: true
        ))

        game.advanceWeek()

        let reservation = try! XCTUnwrap(game.onlineBidReservations.first {
            $0.instructionID == instructionID
        })
        let reservedInstruction = game.procurementInstructions.first { $0.id == instructionID }!
        XCTAssertEqual(
            reservedInstruction.reservedBudget,
            reservation.maxPrice + listing.fee + listing.shippingCost
        )
        let reservationReport = try! XCTUnwrap(game.lastReport?.procurement.first {
            $0.instructionID == instructionID && $0.source == .online
        })
        XCTAssertEqual(reservationReport.reserved, reservation.committedCost)
        XCTAssertEqual(reservationReport.result, "入札予約")
        XCTAssertLessThanOrEqual(
            reservedInstruction.spentBudget + reservedInstruction.reservedBudget,
            reservedInstruction.totalBudget
        )
        XCTAssertEqual(listing.fault == .none, false)

        XCTAssertTrue(game.setProcurementInstructionStatus(instructionID, status: .paused))
        game.stores[0].autoProcurement = false
        game.stores[0].employees = []
        game.advanceWeek()

        let settledInstruction = game.procurementInstructions.first { $0.id == instructionID }!
        XCTAssertEqual(settledInstruction.reservedBudget, 0)
        XCTAssertLessThanOrEqual(settledInstruction.spentBudget, settledInstruction.totalBudget)
        XCTAssertFalse(game.onlineBidReservations.contains { $0.instructionID == instructionID })
        XCTAssertNotNil(game.lastReport?.procurement.first {
            $0.instructionID == instructionID && $0.source == .online
        })
    }

    func testMinimumGrossProfitRejectsImportedAuctionAboveActualRetailCeiling() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        game.stores[0].priceIndex = 0.60
        game.stores[0].employees = [StoreEmployee(
            name: "輸入車仕入88",
            salesSkill: 60,
            procurementSkill: 95,
            researchSkill: 60,
            serviceSkill: 50,
            monthlySalary: 55,
            assignment: .procurement
        )]
        game.stores[0].autoProcurement = true
        game.purchaseCases = []
        game.onlineListings = []
        let model = try! XCTUnwrap(VehicleCatalog.available(through: game.turn).first {
            $0.origin == .imported && !$0.isRareClassic
        })
        let condition = VehicleConditionProfile(exterior: 70, interior: 70, mechanical: 70)
        let comparisonBatch = InventoryBatch(
            modelID: model.id,
            category: model.category,
            count: 1,
            averageCost: 1,
            quality: condition.quality,
            modelYear: game.year - 2,
            mileage: 10_000,
            acquiredTurn: game.turn,
            condition: condition
        )
        game.stores[0].inventory = [comparisonBatch]
        let actualRetail = try! XCTUnwrap(game.manualSaleQuote(
            storeID: storeID,
            inventoryID: comparisonBatch.id
        )).price
        game.stores[0].inventory = []

        let listing = AuctionListing(
            id: UUID(),
            venue: .premium,
            modelID: model.id,
            category: model.category,
            modelYear: game.year - 2,
            mileage: 10_000,
            quality: condition.quality,
            condition: condition,
            fault: .none,
            reservePrice: actualRetail - 50,
            marketPrice: actualRetail,
            seller: "高値輸入車",
            createdTurn: game.turn
        )
        game.auctionListings = [listing]
        let instructionID = try! XCTUnwrap(game.createProcurementInstruction(
            storeID: storeID,
            totalBudget: 10_000,
            financialRule: .minimumGrossProfit(100),
            category: model.category,
            origin: .imported,
            modelID: model.id,
            faultOnly: false,
            allowedSources: [.auction]
        ))

        game.advanceWeek()

        XCTAssertFalse(game.bidReservations.contains {
            $0.listingID == listing.id && $0.instructionID == instructionID
        })
        XCTAssertEqual(
            game.procurementInstructions.first { $0.id == instructionID }?.lastResult,
            "今週は条件一致なし"
        )
    }

    func testMaximumOfferBlocksThenAllowsDealerTradeWithoutExceedingBudget() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        game.stores[0].employees = [StoreEmployee(
            name: "業販担当",
            salesSkill: 60,
            procurementSkill: 95,
            researchSkill: 80,
            serviceSkill: 50,
            monthlySalary: 52,
            assignment: .procurement
        )]
        game.stores[0].autoProcurement = true
        game.purchaseCases = []
        game.auctionListings = []
        game.onlineListings = []
        let initialQuote = try! XCTUnwrap(game.dealerTradeQuote(category: .compact, count: 1, storeID: storeID))
        let instructionID = try! XCTUnwrap(game.createProcurementInstruction(
            storeID: storeID,
            totalBudget: initialQuote.totalCost + 100,
            financialRule: .maximumOffer(max(0, initialQuote.unitCost - 1)),
            category: .compact,
            modelID: initialQuote.modelID,
            faultOnly: false
        ))

        game.advanceWeek()
        XCTAssertFalse(game.inboundShipments.contains {
            $0.instructionID == instructionID && $0.source == .dealerTrade
        })

        game.auctionListings = []
        game.onlineListings = []
        let currentQuote = try! XCTUnwrap(game.dealerTradeQuote(
            category: .compact,
            count: 1,
            storeID: storeID,
            modelID: initialQuote.modelID
        ))
        var instruction = game.procurementInstructions.first { $0.id == instructionID }!
        instruction.totalBudget = max(instruction.totalBudget, currentQuote.totalCost + instruction.spentBudget + 1_000)
        instruction.financialRule = .maximumOffer(currentQuote.unitCost + 1_000)
        XCTAssertTrue(game.updateProcurementInstruction(instruction))

        game.advanceWeek()

        let shipment = try! XCTUnwrap(game.inboundShipments.first {
            $0.instructionID == instructionID && $0.source == .dealerTrade
        })
        XCTAssertEqual(shipment.modelID, initialQuote.modelID)
        let updated = game.procurementInstructions.first { $0.id == instructionID }!
        XCTAssertLessThanOrEqual(updated.spentBudget + updated.reservedBudget, updated.totalBudget)
    }

    func testDealerTradeWeeklyBudgetRenewsAfterBeingFullySpent() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        game.stores[0].employees = [StoreEmployee(
            name: "完遂担当",
            salesSkill: 60,
            procurementSkill: 95,
            researchSkill: 80,
            serviceSkill: 50,
            monthlySalary: 52,
            assignment: .procurement
        )]
        game.stores[0].autoProcurement = true
        game.purchaseCases = []
        game.auctionListings = []
        game.onlineListings = []
        let quote = try! XCTUnwrap(game.dealerTradeQuote(
            category: .compact,
            count: 1,
            storeID: storeID
        ))
        let instructionID = try! XCTUnwrap(game.createProcurementInstruction(
            storeID: storeID,
            totalBudget: quote.totalCost,
            financialRule: .maximumOffer(quote.unitCost),
            category: .compact,
            modelID: quote.modelID,
            faultOnly: false
        ))

        game.advanceWeek()

        let instruction = try! XCTUnwrap(game.procurementInstructions.first {
            $0.id == instructionID
        })
        XCTAssertEqual(instruction.spentBudget, instruction.totalBudget)
        XCTAssertEqual(instruction.status, .active)
        let line = try! XCTUnwrap(game.lastReport?.procurement.first {
            $0.instructionID == instructionID && $0.source == .dealerTrade
        })
        XCTAssertEqual(line.acquiredCount, 1)
        XCTAssertEqual(line.spent, quote.totalCost)

        game.stores[0].autoProcurement = false
        game.advanceWeek()

        let renewed = try! XCTUnwrap(game.procurementInstructions.first {
            $0.id == instructionID
        })
        XCTAssertEqual(renewed.spentBudget, 0)
        XCTAssertEqual(renewed.remainingBudget, renewed.totalBudget)
        XCTAssertEqual(renewed.status, .active)
    }

    func testFoundingInventorySelectionDoesNotReturnWhenInventoryLaterReachesZero() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        let storeID = game.stores[0].id

        game.stores[0].inventory = []

        XCTAssertFalse(game.canSelectFoundingInventory(storeID: storeID))
    }

    func testWeeklyReportNotesAreSeparatedIntoCategories() {
        XCTAssertEqual(
            WeeklyReportCategory.category(for: "中央店仕入指示：AAでコンパクトへ入札予約"),
            .procurement
        )
        XCTAssertEqual(
            WeeklyReportCategory.category(for: "中央店で販売商談が3台成約"),
            .sales
        )
        XCTAssertEqual(
            WeeklyReportCategory.category(for: "ガソリン価格が前週から上昇しました"),
            .market
        )
        XCTAssertEqual(
            WeeklyReportCategory.category(for: "中央店の店舗外観が成長しました"),
            .operations
        )
        XCTAssertEqual(
            WeeklyReportCategory.category(for: "資金危機1/2週"),
            .management
        )
    }

    func testFaultyInboundWaitsUntilServiceAutomationIsEnabled() {
        let game = GameEngine()
        game.resetGame()
        startPlayableGame(game)
        game.cash = 100_000
        let storeID = game.stores[0].id
        let model = VehicleCatalog.all.first { $0.category == .compact }!
        game.stores[0].inventory = []
        game.stores[0].facilities.insert(.serviceWorkshop)
        game.stores[0].employees = [StoreEmployee(
            name: "故障車整備",
            salesSkill: 40,
            procurementSkill: 60,
            researchSkill: 60,
            serviceSkill: 90,
            monthlySalary: 55,
            assignment: .service
        )]
        game.stores[0].autoService = false
        game.inboundShipments = [InboundShipment(
            storeID: storeID,
            source: .online,
            modelID: model.id,
            category: model.category,
            count: 1,
            unitCost: 60,
            quality: 0.52,
            modelYear: game.year - 6,
            mileage: 82_000,
            condition: VehicleConditionProfile(exterior: 58, interior: 55, mechanical: 38),
            fault: .major,
            acquiredTurn: game.turn,
            monthsRemaining: 1
        )]

        game.advanceWeek()

        let waiting = try! XCTUnwrap(game.stores[0].inventory.first {
            $0.modelID == model.id && $0.fault == .major
        })
        XCTAssertNil(waiting.workshopProject)

        game.stores[0].autoService = true
        game.advanceWeek()

        let repairing = try! XCTUnwrap(game.stores[0].inventory.first {
            $0.id == waiting.id
        })
        XCTAssertEqual(repairing.workshopProject?.kind, .repair)
    }
}
