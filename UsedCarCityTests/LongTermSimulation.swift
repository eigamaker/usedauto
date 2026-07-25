import Foundation
import XCTest
@testable import UsedCarCity

enum SimulationStrategy: String, Codable, CaseIterable {
    case survival
    case growth
    case adaptive

    var displayName: String {
        switch self {
        case .survival: "生存優先"
        case .growth: "成長優先"
        case .adaptive: "適応型"
        }
    }

    var reserveMonths: Double {
        switch self {
        case .survival: 3
        case .growth: 1.5
        case .adaptive: 2
        }
    }

    var inventoryRatio: Double {
        switch self {
        case .survival: 0.30
        case .growth: 0.65
        case .adaptive: 0.50
        }
    }

    var maximumStaffPerStore: Int {
        switch self {
        case .survival: 3
        case .growth: 8
        case .adaptive: 6
        }
    }
}

struct SimulationConfiguration: Codable, Equatable {
    var seeds: [Int]
    var strategies: [SimulationStrategy]
    var horizonWeeks: Int

    static let smoke = SimulationConfiguration(
        seeds: [11],
        strategies: SimulationStrategy.allCases,
        horizonWeeks: 240
    )

    static let analysis = SimulationConfiguration(
        seeds: Array(1...30),
        strategies: SimulationStrategy.allCases,
        horizonWeeks: 480
    )
}

struct SimulationDecisionEvent: Codable, Equatable {
    var turn: Int
    var year: Int
    var month: Int
    var strategy: SimulationStrategy
    var storeName: String?
    var action: String
    var reason: String
    var profitBefore: Int?
    var profitAfter: Int?
}

struct SimulationYearSnapshot: Codable, Equatable {
    var turn: Int
    var elapsedYears: Int
    var reachedCheckpoint: Bool
    var survived: Bool
    var cash: Int
    var debt: Int
    var companyValue: Int
    var cumulativeAcquisitions: Int
    var cumulativeSales: Int
    var cumulativeRevenue: Int
    var cumulativeGrossProfit: Int
    var cumulativeOperatingProfit: Int
    var acquisitionsBySource: [String: Int]
    var salesByCategory: [String: Int]
    var inventoryCount: Int
    var inventoryValue: Int
    var averageInventoryWeeks: Double
    var storeCount: Int
    var operationalStoreCount: Int
    var storeTypes: [String: Int]
    var employeeCount: Int
    var facilities: [String: Int]
    var maximumMarketShare: Double
    var policyChangeCount: Int
    var expansionCount: Int
    var renovationCount: Int
    var isSpecialized: Bool
    var hasAdvancedSpecialistStore: Bool
    var hasRoadsideStore: Bool
    var topExpertiseName: String
    var topExpertiseScore: Double
}

struct SimulationRunResult: Codable, Equatable {
    var seed: Int
    var strategy: SimulationStrategy
    var requestedWeeks: Int
    var completedWeeks: Int
    var endingReason: String
    var minimumCash: Int
    var maximumDebt: Int
    var firstSpecializationTurn: Int?
    var firstAdvancedStoreTurn: Int?
    var firstRoadsideStoreTurn: Int?
    var firstExpansionTurn: Int?
    var decisions: [SimulationDecisionEvent]
    var yearlySnapshots: [SimulationYearSnapshot]
    var invariantViolations: [String]
}

struct SimulationCheckpointSummary: Codable, Equatable {
    var years: Int
    var runs: Int
    var survivalRate: Double
    var medianSales: Int
    var medianOperatingProfit: Int
    var medianCompanyValue: Int
    var lowerQuartileCompanyValue: Int
    var upperQuartileCompanyValue: Int
    var specializationRate: Double
    var advancedStoreRate: Double
    var roadsideStoreRate: Double
    var multipleStoreRate: Double
    var averagePolicyChanges: Double
    var profitableRepositionRate: Double
}

struct SimulationStrategySummary: Codable, Equatable {
    var strategy: SimulationStrategy
    var checkpoints: [SimulationCheckpointSummary]
}

struct SimulationReport: Codable, Equatable {
    var generatedAt: String
    var configuration: SimulationConfiguration
    var summaries: [SimulationStrategySummary]
    var runs: [SimulationRunResult]

    func markdown() -> String {
        var lines = [
            "# 中古車ビジネス長期シミュレーション",
            "",
            "- 実行日時: \(generatedAt)",
            "- シード: \(configuration.seeds.count)件",
            "- 戦略: \(configuration.strategies.map(\.displayName).joined(separator: "・"))",
            "- 最長期間: \(configuration.horizonWeeks / 48)年",
            "",
            "## 戦略別サマリー",
            "",
            "| 戦略 | 時点 | 生存率 | 販売中央値 | 営業利益中央値 | 企業価値中央値 | 専門化到達率 | 上位専門店到達率 | 大型店到達率 | 多店舗到達率 |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
        ]
        for summary in summaries {
            for checkpoint in summary.checkpoints {
                lines.append(
                    "| \(summary.strategy.displayName) | \(checkpoint.years)年 | "
                        + "\(percent(checkpoint.survivalRate)) | \(checkpoint.medianSales) | "
                        + "\(checkpoint.medianOperatingProfit) | \(checkpoint.medianCompanyValue) | "
                        + "\(percent(checkpoint.specializationRate)) | \(percent(checkpoint.advancedStoreRate)) | "
                        + "\(percent(checkpoint.roadsideStoreRate)) | \(percent(checkpoint.multipleStoreRate)) |"
                )
            }
        }

        lines += [
            "",
            "## 到達状況",
            "",
            "| 戦略 | Seed | 終了週 | 終了理由 | 最低現金 | 最大借入 | 専門化 | 上位専門店 | 大型店 | 2店舗目 | 方針変更 |",
            "|---|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|"
        ]
        for run in runs {
            lines.append(
                "| \(run.strategy.displayName) | \(run.seed) | \(run.completedWeeks) | \(run.endingReason) | "
                    + "\(run.minimumCash) | \(run.maximumDebt) | \(turnText(run.firstSpecializationTurn)) | "
                    + "\(turnText(run.firstAdvancedStoreTurn)) | \(turnText(run.firstRoadsideStoreTurn)) | "
                    + "\(turnText(run.firstExpansionTurn)) | \(run.decisions.filter { $0.action == "業態転換" }.count) |"
            )
        }

        let violations = runs.flatMap { run in
            run.invariantViolations.map { "\(run.strategy.displayName) seed \(run.seed): \($0)" }
        }
        lines += ["", "## 整合性チェック", ""]
        lines.append(violations.isEmpty ? "- 違反なし" : violations.map { "- \($0)" }.joined(separator: "\n"))
        return lines.joined(separator: "\n") + "\n"
    }

    func csv() -> String {
        var rows = [
            [
                "strategy", "seed", "elapsed_years", "turn", "survived", "cash", "debt",
                "company_value", "acquisitions", "sales", "revenue", "gross_profit",
                "operating_profit", "inventory", "inventory_value", "average_inventory_weeks",
                "stores", "operational_stores", "employees", "maximum_market_share",
                "policy_changes", "expansions", "renovations", "specialized",
                "advanced_specialist_store", "roadside_store", "top_expertise", "top_expertise_score"
            ]
        ]
        for run in runs {
            for snapshot in run.yearlySnapshots {
                rows.append([
                    run.strategy.rawValue,
                    String(run.seed),
                    String(snapshot.elapsedYears),
                    String(snapshot.turn),
                    String(snapshot.survived),
                    String(snapshot.cash),
                    String(snapshot.debt),
                    String(snapshot.companyValue),
                    String(snapshot.cumulativeAcquisitions),
                    String(snapshot.cumulativeSales),
                    String(snapshot.cumulativeRevenue),
                    String(snapshot.cumulativeGrossProfit),
                    String(snapshot.cumulativeOperatingProfit),
                    String(snapshot.inventoryCount),
                    String(snapshot.inventoryValue),
                    String(format: "%.2f", snapshot.averageInventoryWeeks),
                    String(snapshot.storeCount),
                    String(snapshot.operationalStoreCount),
                    String(snapshot.employeeCount),
                    String(format: "%.4f", snapshot.maximumMarketShare),
                    String(snapshot.policyChangeCount),
                    String(snapshot.expansionCount),
                    String(snapshot.renovationCount),
                    String(snapshot.isSpecialized),
                    String(snapshot.hasAdvancedSpecialistStore),
                    String(snapshot.hasRoadsideStore),
                    snapshot.topExpertiseName,
                    String(format: "%.2f", snapshot.topExpertiseScore)
                ])
            }
        }
        return rows.map { $0.map(csvEscape).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func turnText(_ turn: Int?) -> String {
        guard let turn else { return "未到達" }
        return String(format: "%.1f年", Double(turn) / 48)
    }

    private func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

@MainActor
final class LongTermSimulationRunner {
    private struct Ledger {
        var acquisitions = 0
        var acquisitionCost = 0
        var acquisitionsBySource: [String: Int] = [:]
        var sales = 0
        var revenue = 0
        var costOfSales = 0
        var salesByCategory: [String: Int] = [:]

        mutating func record(_ transaction: SimulationVehicleTransaction) {
            switch transaction.kind {
            case .acquired:
                acquisitions += transaction.count
                acquisitionCost += transaction.cost
                acquisitionsBySource[transaction.source?.rawValue ?? "unknown", default: 0] += transaction.count
            case .sold:
                sales += transaction.count
                revenue += transaction.revenue
                costOfSales += transaction.cost
                salesByCategory[transaction.category.rawValue, default: 0] += transaction.count
            }
        }
    }

    private struct RunState {
        var decisions: [SimulationDecisionEvent] = []
        var weeklyOperatingProfit: [Int: Int] = [:]
        var lastRepositionTurnByStore: [UUID: Int] = [:]
        var foundingPolicies: [UUID: StoreMarketPolicy] = [:]
        var minimumCash = Int.max
        var maximumDebt = 0
        var firstSpecializationTurn: Int?
        var firstAdvancedStoreTurn: Int?
        var firstRoadsideStoreTurn: Int?
        var firstExpansionTurn: Int?
        var expansionCount = 0
        var renovationCount = 0
        var policyChangeCount = 0
        var invariantViolations: [String] = []
    }

    static func run(configuration: SimulationConfiguration) -> SimulationReport {
        let boundedWeeks = min(480, max(1, configuration.horizonWeeks))
        var runs: [SimulationRunResult] = []
        for strategy in configuration.strategies {
            for seed in configuration.seeds {
                runs.append(run(seed: seed, strategy: strategy, horizonWeeks: boundedWeeks))
            }
        }
        return SimulationReport(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            configuration: SimulationConfiguration(
                seeds: configuration.seeds,
                strategies: configuration.strategies,
                horizonWeeks: boundedWeeks
            ),
            summaries: makeSummaries(runs: runs, horizonWeeks: boundedWeeks),
            runs: runs
        )
    }

    static func run(seed: Int, strategy: SimulationStrategy, horizonWeeks: Int) -> SimulationRunResult {
        let game = GameEngine(persistenceEnabled: false)
        var ledger = Ledger()
        var state = RunState()
        game.simulationTransactionHandler = { transaction in
            ledger.record(transaction)
        }

        game.startNewGame(simulationSeed: seed)
        guard bootstrap(game: game, strategy: strategy, state: &state) else {
            return SimulationRunResult(
                seed: seed,
                strategy: strategy,
                requestedWeeks: horizonWeeks,
                completedWeeks: game.turn,
                endingReason: "創業失敗",
                minimumCash: game.cash,
                maximumDebt: game.debt,
                firstSpecializationTurn: nil,
                firstAdvancedStoreTurn: nil,
                firstRoadsideStoreTurn: nil,
                firstExpansionTurn: nil,
                decisions: state.decisions,
                yearlySnapshots: [],
                invariantViolations: ["通常の創業条件で店舗を開設できませんでした"]
            )
        }

        var snapshots: [SimulationYearSnapshot] = []
        let targetWeeks = min(480, max(1, horizonWeeks))
        while game.turn < targetWeeks && !game.gameOver {
            state.minimumCash = min(state.minimumCash, game.cash)
            state.maximumDebt = max(state.maximumDebt, game.debt)
            handleEmergency(game: game, strategy: strategy, state: &state)
            if game.turn.isMultiple(of: 4) {
                makeMonthlyDecisions(game: game, strategy: strategy, state: &state)
            }

            let previousTurn = game.turn
            game.advanceWeek()
            guard game.turn == previousTurn + 1 else {
                state.invariantViolations.append("週進行が turn \(previousTurn) で停止")
                break
            }
            if let report = game.lastReport {
                state.weeklyOperatingProfit[game.turn] = report.operatingProfit
            }
            finishRepositionEvaluations(game: game, strategy: strategy, state: &state)
            updateMilestones(game: game, state: &state)
            validate(game: game, state: &state)

            if game.turn.isMultiple(of: 48) || game.gameOver || game.turn == targetWeeks {
                snapshots.append(makeSnapshot(
                    game: game,
                    ledger: ledger,
                    state: state,
                    reachedCheckpoint: true
                ))
            }
        }

        if snapshots.last?.turn != game.turn {
            snapshots.append(makeSnapshot(
                game: game,
                ledger: ledger,
                state: state,
                reachedCheckpoint: game.turn >= targetWeeks
            ))
        }
        state.minimumCash = min(state.minimumCash, game.cash)
        state.maximumDebt = max(state.maximumDebt, game.debt)

        let endingReason: String
        if game.turn >= targetWeeks {
            endingReason = game.turn >= game.maxTurns ? "10年完走" : "\(game.turn / 48)年到達"
        } else if game.financialDistressWeeks >= 2 {
            endingReason = "資金破綻"
        } else if !state.invariantViolations.isEmpty {
            endingReason = "整合性違反"
        } else {
            endingReason = "途中終了"
        }

        return SimulationRunResult(
            seed: seed,
            strategy: strategy,
            requestedWeeks: targetWeeks,
            completedWeeks: game.turn,
            endingReason: endingReason,
            minimumCash: state.minimumCash,
            maximumDebt: state.maximumDebt,
            firstSpecializationTurn: state.firstSpecializationTurn,
            firstAdvancedStoreTurn: state.firstAdvancedStoreTurn,
            firstRoadsideStoreTurn: state.firstRoadsideStoreTurn,
            firstExpansionTurn: state.firstExpansionTurn,
            decisions: state.decisions,
            yearlySnapshots: snapshots,
            invariantViolations: state.invariantViolations
        )
    }

    private static func bootstrap(
        game: GameEngine,
        strategy: SimulationStrategy,
        state: inout RunState
    ) -> Bool {
        let candidates = ([game.recommendedFoundingPlot].compactMap { $0 } + game.foundingCandidatePlots)
        guard let plot = candidates.first(where: {
            game.footprintPlots(startingAt: $0, type: .standard, mode: .lease).count
                == StoreType.standard.requiredGridCells
        }) else { return false }

        let categories = Array(game.recommendedCategories(for: plot.district).prefix(2))
        let policy = StoreMarketPolicy(
            priorityCategories: Set(categories),
            targetPurpose: foundingPurpose(for: plot.district)
        )
        let footprint = game.footprintPlots(startingAt: plot, type: .standard, mode: .lease)
        let buildCost = game.totalBuildCost(
            for: footprint,
            type: .standard,
            mode: .lease,
            facilities: []
        )
        let availableBorrowing = max(0, game.borrowingLimit - game.debt)
        let desiredLoan = roundedUpToThousand(max(0, buildCost + 2_000 - game.cash))
        let loan = min(availableBorrowing, desiredLoan)
        guard game.cash + loan >= buildCost else { return false }

        game.selectFoundingPlot(plot.id)
        guard game.buildStore(
            on: plot,
            type: .standard,
            mode: .lease,
            marketPolicy: policy,
            facilities: [],
            loanAmount: loan
        ), let storeID = game.stores.first?.id else { return false }

        for category in categories {
            _ = game.buyInventory(category: category, count: 2, storeID: storeID)
        }
        game.completeTutorial()
        hireBestEmployee(for: .sales, storeID: storeID, game: game)
        hireBestEmployee(for: .procurement, storeID: storeID, game: game)
        configureAutomation(storeID: storeID, game: game, strategy: strategy)
        state.foundingPolicies[storeID] = policy
        state.decisions.append(SimulationDecisionEvent(
            turn: 0,
            year: game.year,
            month: game.month,
            strategy: strategy,
            storeName: game.stores.first?.name,
            action: "創業",
            reason: "推奨区画・標準店・通常融資枠で開業",
            profitBefore: nil,
            profitAfter: nil
        ))
        return true
    }

    private static func makeMonthlyDecisions(
        game: GameEngine,
        strategy: SimulationStrategy,
        state: inout RunState
    ) {
        for store in game.stores where store.isOperational {
            configureAutomation(storeID: store.id, game: game, strategy: strategy)
            manageStaff(storeID: store.id, game: game, strategy: strategy)
            managePricing(storeID: store.id, game: game, strategy: strategy)
        }

        switch strategy {
        case .survival:
            break
        case .growth:
            attemptGrowth(game: game, strategy: strategy, state: &state, adaptivePolicy: nil)
        case .adaptive:
            attemptReposition(game: game, state: &state)
            let policy = game.stores.first?.marketPolicy
            attemptGrowth(game: game, strategy: strategy, state: &state, adaptivePolicy: policy)
        }

        for store in game.stores where store.isOperational {
            manageProcurement(storeID: store.id, game: game, strategy: strategy)
        }
    }

    private static func configureAutomation(
        storeID: UUID,
        game: GameEngine,
        strategy: SimulationStrategy
    ) {
        guard var store = game.stores.first(where: { $0.id == storeID }) else { return }
        store.autoSales = true
        store.autoProcurement = true
        store.autoMarketing = true
        store.autoService = true
        store.marketingPolicy = .balanced
        store.servicePolicy = strategy == .survival ? .cost : .balanced
        game.updateStore(store)
    }

    private static func handleEmergency(
        game: GameEngine,
        strategy: SimulationStrategy,
        state: inout RunState
    ) {
        let monthlyCost = max(1, companyMonthlyCashCost(game))
        let emergencyFloor = monthlyCost / 2
        guard game.cash < emergencyFloor else { return }

        let target = max(monthlyCost, reserveAmount(game: game, strategy: strategy))
        let available = max(0, game.borrowingLimit - game.debt)
        let requested = min(available, roundedUpToThousand(max(0, target - game.cash)))
        if requested > 0 {
            let before = game.cash
            game.borrow(requested)
            if game.cash > before {
                state.decisions.append(SimulationDecisionEvent(
                    turn: game.turn,
                    year: game.year,
                    month: game.month,
                    strategy: strategy,
                    storeName: nil,
                    action: "緊急融資",
                    reason: "現金\(before)が月間支出\(monthlyCost)の半分未満",
                    profitBefore: rollingProfit(game: game, weeks: 4),
                    profitAfter: nil
                ))
            }
        }

        if game.cash < emergencyFloor {
            for store in game.stores {
                var changed = store
                changed.advertising = min(changed.advertising, 40)
                changed.salesPolicy = .volume
                game.updateStore(changed)
                for instruction in game.procurementInstructions(for: store.id) where instruction.status == .active {
                    _ = game.setProcurementInstructionStatus(instruction.id, status: .paused)
                }
                if changed.employees.count > 2,
                   let removable = changed.employees
                    .filter({ ![EmployeeAssignment.sales, .procurement].contains($0.assignment) })
                    .min(by: { $0.overallSkill < $1.overallSkill }) {
                    _ = game.fireEmployee(removable.id, from: store.id)
                }
            }
        }
    }

    private static func manageStaff(
        storeID: UUID,
        game: GameEngine,
        strategy: SimulationStrategy
    ) {
        guard game.stores.contains(where: { $0.id == storeID }) else { return }
        for role in [EmployeeAssignment.sales, .procurement] {
            guard let current = game.stores.first(where: { $0.id == storeID }),
                  !current.employees.contains(where: { $0.assignment == role }) else { continue }
            hireBestEmployee(for: role, storeID: storeID, game: game)
        }

        guard let store = game.stores.first(where: { $0.id == storeID }) else { return }
        let reserve = reserveAmount(game: game, strategy: strategy)
        guard game.cash > reserve else { return }

        let inventoryDriven = 2 + store.inventoryCount / 8
        let desired = min(strategy.maximumStaffPerStore, max(2, inventoryDriven))
        guard store.employees.count < desired else { return }

        let assignments: [EmployeeAssignment] = [.sales, .procurement, .research, .service]
        let role = assignments.min { lhs, rhs in
            store.employees.filter { $0.assignment == lhs }.count
                < store.employees.filter { $0.assignment == rhs }.count
        } ?? .sales
        hireBestEmployee(for: role, storeID: storeID, game: game)
    }

    private static func hireBestEmployee(
        for assignment: EmployeeAssignment,
        storeID: UUID,
        game: GameEngine
    ) {
        let candidates = game.employeeCandidates(for: storeID)
        let candidate = candidates.max { skill($0, for: assignment) < skill($1, for: assignment) }
        guard let candidate, game.hireEmployee(candidate.id, for: storeID) else { return }
        _ = game.assignEmployee(candidate.id, at: storeID, to: assignment)
    }

    private static func skill(_ employee: StoreEmployee, for assignment: EmployeeAssignment) -> Int {
        switch assignment {
        case .sales: employee.salesSkill
        case .procurement: employee.procurementSkill
        case .research: employee.researchSkill
        case .service: employee.serviceSkill
        case .unassigned: employee.overallSkill
        }
    }

    private static func managePricing(
        storeID: UUID,
        game: GameEngine,
        strategy: SimulationStrategy
    ) {
        guard var store = game.stores.first(where: { $0.id == storeID }) else { return }
        let age = game.averageInventoryWeeks(storeID: storeID)
        if age > 12 {
            store.salesPolicy = .volume
            store.priceIndex = 0.94
        } else if age > 8 {
            store.salesPolicy = .balanced
            store.priceIndex = 0.99
        } else {
            store.salesPolicy = strategy == .survival ? .profit : .balanced
            store.priceIndex = strategy == .growth ? 0.99 : 1.03
        }

        switch strategy {
        case .survival:
            store.advertising = 60
        case .growth:
            let profitableWeeks = game.reports.prefix(12).filter { $0.operatingProfit > 0 }.count
            store.advertising = min(320, 120 + profitableWeeks * 15)
        case .adaptive:
            store.advertising = rollingProfit(game: game, weeks: 8) >= 0 ? 120 : 80
        }
        game.updateStore(store)
    }

    private static func manageProcurement(
        storeID: UUID,
        game: GameEngine,
        strategy: SimulationStrategy
    ) {
        for instruction in game.procurementInstructions(for: storeID) {
            game.deleteProcurementInstruction(instruction.id)
        }
        guard let store = game.stores.first(where: { $0.id == storeID }),
              store.employees.contains(where: { $0.assignment == .procurement }) else { return }

        let target = max(2, Int((Double(store.type.capacity) * strategy.inventoryRatio).rounded()))
        let availableUnits = store.inventoryCount + game.incomingCount(for: storeID)
        let gap = max(0, target - availableUnits)
        let monthlyCost = companyMonthlyCashCost(game)
        let workingCapitalFloor = switch strategy {
        case .survival: max(150, monthlyCost / 2)
        case .growth: max(75, monthlyCost / 5)
        case .adaptive: max(100, monthlyCost / 3)
        }
        let availableCash = max(0, game.cash - workingCapitalFloor)
        guard gap > 0, availableCash >= 50 else { return }

        let categories = store.marketPolicy.priorityCategories.isEmpty
            ? Array(VehicleCategory.allCases.prefix(2))
            : store.marketPolicy.priorityCategories.sorted { $0.rawValue < $1.rawValue }
        let perCategoryGap = max(1, Int(ceil(Double(gap) / Double(max(1, categories.count)))))
        var remainingCash = availableCash
        for category in categories where remainingCash >= 50 {
            let estimated = max(50, category.purchaseCost * perCategoryGap)
            let budget = min(remainingCash, estimated)
            let faultOnly = store.marketPolicy.acceptedConditions.contains(.faulty)
                && store.marketPolicy.targetPurpose == .general
            _ = game.createProcurementInstruction(
                storeID: storeID,
                totalBudget: budget,
                financialRule: .minimumGrossProfit(max(20, category.purchaseCost / 8)),
                category: category,
                modelID: nil,
                faultOnly: faultOnly
            )
            remainingCash -= budget
        }
    }

    private static func attemptReposition(game: GameEngine, state: inout RunState) {
        guard game.turn >= 24 else { return }
        for store in game.stores where store.isOperational {
            let lastTurn = state.lastRepositionTurnByStore[store.id] ?? -24
            guard game.turn - lastTurn >= 24,
                  let district = game.plot(id: store.plotID)?.district else { continue }

            let reserve = reserveAmount(game: game, strategy: .adaptive)
            let candidates = game.segmentOpportunityReports(storeID: store.id, district: district)
                .filter {
                    $0.key.productKind != .collector
                        && ![SegmentMarketStatus.crowded, .shrinking].contains($0.status)
                        && $0.unmetDemand.upperBound > 0
                        && $0.requiredWorkingCapital.upperBound <= max(0, game.cash - reserve)
                }
            guard let best = candidates.first else { continue }
            let currentScore = candidates
                .filter {
                    store.marketPolicy.priorityCategories.contains($0.key.category)
                        && $0.key.purpose == store.marketPolicy.targetPurpose
                }
                .map(\.opportunityScore)
                .max() ?? 0.05
            let recentProfit = rollingProfit(game: game, weeks: 8)
            let multiplier = recentProfit < 0 ? 1.10 : 1.30
            guard best.opportunityScore >= max(0.05, currentScore) * multiplier else { continue }

            let requiredFacility = facility(for: best.key.productKind)
            if let requiredFacility,
               !store.facilities.contains(requiredFacility),
               game.cash - requiredFacility.installationCost >= reserve {
                _ = game.installFacility(requiredFacility, at: store.id)
            }

            guard var changed = game.stores.first(where: { $0.id == store.id }) else { continue }
            let before = "\(changed.marketPolicy.targetPurpose.name)・\(changed.marketPolicy.priorityCategories.map(\.name).sorted().joined(separator: "・"))"
            changed.marketPolicy = StoreMarketPolicy(
                priorityCategories: [best.key.category],
                targetPurpose: best.key.purpose,
                acceptedConditions: acceptedConditions(for: best.key.productKind)
            )
            changed.servicePolicy = [.repaired, .refurbished].contains(best.key.productKind) ? .quality : .balanced
            game.updateStore(changed)
            state.lastRepositionTurnByStore[store.id] = game.turn
            state.policyChangeCount += 1
            state.decisions.append(SimulationDecisionEvent(
                turn: game.turn,
                year: game.year,
                month: game.month,
                strategy: .adaptive,
                storeName: store.name,
                action: "業態転換",
                reason: "\(before)から\(best.key.name)へ。機会スコア\(format(best.opportunityScore))、現方針\(format(currentScore))",
                profitBefore: recentProfit,
                profitAfter: nil
            ))
        }
    }

    private static func attemptGrowth(
        game: GameEngine,
        strategy: SimulationStrategy,
        state: inout RunState,
        adaptivePolicy: StoreMarketPolicy?
    ) {
        guard game.turn >= 24 else { return }
        let recent = Array(game.reports.prefix(12))
        guard recent.count >= 8,
              recent.reduce(0, { $0 + $1.operatingProfit }) > 0,
              recent.filter({ $0.operatingProfit > 0 }).count > recent.count / 2 else { return }
        let reserve = reserveAmount(game: game, strategy: strategy)

        if let candidate = game.stores.first(where: {
            $0.isOperational && !$0.isRenovating && $0.type != .roadside
                && Double($0.inventoryCount) / Double(max(1, $0.type.capacity)) >= 0.70
        }), game.cash >= reserve + 4_000,
           game.renovateStore(candidate.id, to: .roadside) {
            state.renovationCount += 1
            state.decisions.append(SimulationDecisionEvent(
                turn: game.turn,
                year: game.year,
                month: game.month,
                strategy: strategy,
                storeName: candidate.name,
                action: "大型店へ改装",
                reason: "12週黒字かつ在庫利用率70%以上、投資後準備金を確保",
                profitBefore: rollingProfit(game: game, weeks: 12),
                profitAfter: nil
            ))
            return
        }

        guard game.turn >= 48,
              game.stores.count < 5,
              game.stores.allSatisfy({ $0.isOperational }),
              let referenceStore = game.stores.first else { return }
        let policy = adaptivePolicy ?? referenceStore.marketPolicy
        let candidates = game.plots.filter {
            guard $0.development == nil, case .available = $0.occupant else { return false }
            return game.footprintPlots(startingAt: $0, type: .small, mode: .lease).count == 1
        }
        let ranked = candidates.sorted {
            let left = game.estimatedSales(for: $0, type: .small, marketPolicy: policy).upperBound
            let right = game.estimatedSales(for: $1, type: .small, marketPolicy: policy).upperBound
            return left == right ? $0.monthlyRent < $1.monthlyRent : left > right
        }
        guard let plot = ranked.first else { return }
        let footprint = game.footprintPlots(startingAt: plot, type: .small, mode: .lease)
        let total = game.totalBuildCost(for: footprint, type: .small, mode: .lease)
        let remainingCredit = max(0, game.borrowingLimit - game.debt)
        let desiredLoan = max(0, total + reserve - game.cash)
        let loan = min(remainingCredit, total / 2, roundedUpToThousand(desiredLoan))
        guard game.cash + loan >= total + reserve,
              game.buildStore(
                on: plot,
                type: .small,
                mode: .lease,
                marketPolicy: policy,
                facilities: [],
                loanAmount: loan
              ) else { return }

        state.expansionCount += 1
        state.decisions.append(SimulationDecisionEvent(
            turn: game.turn,
            year: game.year,
            month: game.month,
            strategy: strategy,
            storeName: game.stores.last?.name,
            action: "新規出店",
            reason: "12週累計黒字・黒字週過半数・投資後準備金を確保",
            profitBefore: rollingProfit(game: game, weeks: 12),
            profitAfter: nil
        ))
    }

    private static func finishRepositionEvaluations(
        game: GameEngine,
        strategy: SimulationStrategy,
        state: inout RunState
    ) {
        for index in state.decisions.indices {
            guard state.decisions[index].action == "業態転換",
                  state.decisions[index].profitAfter == nil,
                  game.turn >= state.decisions[index].turn + 12 else { continue }
            let start = state.decisions[index].turn + 1
            let end = state.decisions[index].turn + 12
            state.decisions[index].profitAfter = (start...end).reduce(0) {
                $0 + (state.weeklyOperatingProfit[$1] ?? 0)
            }
        }
    }

    private static func updateMilestones(game: GameEngine, state: inout RunState) {
        if state.firstExpansionTurn == nil, game.stores.count >= 2 {
            state.firstExpansionTurn = game.turn
        }
        if state.firstRoadsideStoreTurn == nil, game.stores.contains(where: { $0.type == .roadside }) {
            state.firstRoadsideStoreTurn = game.turn
        }
        if state.firstAdvancedStoreTurn == nil,
           game.stores.contains(where: { [.premium, .service].contains($0.type) }) {
            state.firstAdvancedStoreTurn = game.turn
        }
        if state.firstSpecializationTurn == nil,
           game.stores.contains(where: {
               $0.marketPolicy.priorityCategories.count <= 2
                   && game.derivedBusinessName(for: $0) != "総合中古車店"
           }) {
            state.firstSpecializationTurn = game.turn
        }
    }

    private static func validate(game: GameEngine, state: inout RunState) {
        func add(_ text: String) {
            guard !state.invariantViolations.contains(text) else { return }
            state.invariantViolations.append(text)
        }
        if game.debt < 0 { add("借入残高が負数") }
        if game.stores.count > 5 { add("店舗上限5店を超過") }
        if !game.averageInventoryWeeks().isFinite { add("在庫回転期間が非有限") }

        var occupiedPlots: Set<Int> = []
        for store in game.stores {
            if store.inventoryCount > store.type.capacity {
                add("\(store.name)の在庫\(store.inventoryCount)台が容量\(store.type.capacity)台を超過")
            }
            for plotID in store.plotIDs {
                if occupiedPlots.contains(plotID) {
                    add("区画\(plotID)が複数店舗に重複")
                }
                occupiedPlots.insert(plotID)
                guard let plot = game.plot(id: plotID),
                      case .player(let ownerID) = plot.occupant,
                      ownerID == store.id else {
                    add("\(store.name)の区画\(plotID)の所有状態が不正")
                    continue
                }
            }
        }
    }

    private static func makeSnapshot(
        game: GameEngine,
        ledger: Ledger,
        state: RunState,
        reachedCheckpoint: Bool
    ) -> SimulationYearSnapshot {
        let inventory = game.stores.flatMap(\.inventory)
        let inventoryCount = inventory.reduce(0) { $0 + $1.count }
        let inventoryValue = inventory.reduce(0) { $0 + $1.averageCost * $1.count }
        let storeTypes = Dictionary(grouping: game.stores, by: { $0.type.rawValue })
            .mapValues(\.count)
        let facilities = Dictionary(
            grouping: game.stores.flatMap { $0.facilities.map(\.rawValue) },
            by: { $0 }
        ).mapValues(\.count)
        let expertise = topExpertise(game: game)
        let specialized = game.stores.contains {
            $0.marketPolicy.priorityCategories.count <= 2
                && game.derivedBusinessName(for: $0) != "総合中古車店"
        }
        return SimulationYearSnapshot(
            turn: game.turn,
            elapsedYears: Int(ceil(Double(game.turn) / 48)),
            reachedCheckpoint: reachedCheckpoint,
            survived: !game.gameOver || game.turn >= game.maxTurns,
            cash: game.cash,
            debt: game.debt,
            companyValue: game.companyValue,
            cumulativeAcquisitions: ledger.acquisitions,
            cumulativeSales: game.careerStatistics.totalSales,
            cumulativeRevenue: game.careerStatistics.totalRevenue,
            cumulativeGrossProfit: ledger.revenue - ledger.costOfSales,
            cumulativeOperatingProfit: game.careerStatistics.totalOperatingProfit,
            acquisitionsBySource: ledger.acquisitionsBySource,
            salesByCategory: ledger.salesByCategory,
            inventoryCount: inventoryCount,
            inventoryValue: inventoryValue,
            averageInventoryWeeks: game.averageInventoryWeeks(),
            storeCount: game.stores.count,
            operationalStoreCount: game.stores.filter(\.isOperational).count,
            storeTypes: storeTypes,
            employeeCount: game.stores.reduce(0) { $0 + $1.employees.count },
            facilities: facilities,
            maximumMarketShare: game.stores.map { game.marketShare(for: $0) }.max() ?? 0,
            policyChangeCount: state.policyChangeCount,
            expansionCount: state.expansionCount,
            renovationCount: state.renovationCount,
            isSpecialized: specialized,
            hasAdvancedSpecialistStore: game.stores.contains { [.premium, .service].contains($0.type) },
            hasRoadsideStore: game.stores.contains { $0.type == .roadside },
            topExpertiseName: expertise.name,
            topExpertiseScore: expertise.score
        )
    }

    private static func topExpertise(game: GameEngine) -> (name: String, score: Double) {
        var values: [(String, Double)] = []
        values += VehicleCategory.allCases.map { ($0.name, game.companyExpertise.category($0)) }
        values += CustomerPurpose.allCases.map { ($0.name, game.companyExpertise.purpose($0)) }
        values += WorkshopProjectKind.allCases.map { ($0.name, game.companyExpertise.project($0)) }
        values += ProcurementSource.allCases.map { ($0.name, game.companyExpertise.source($0)) }
        return values.max(by: { $0.1 < $1.1 }) ?? ("なし", 0)
    }

    private static func makeSummaries(
        runs: [SimulationRunResult],
        horizonWeeks: Int
    ) -> [SimulationStrategySummary] {
        let checkpoints = [240, 480].filter { $0 <= horizonWeeks }
        return SimulationStrategy.allCases.compactMap { strategy in
            let matching = runs.filter { $0.strategy == strategy }
            guard !matching.isEmpty else { return nil }
            return SimulationStrategySummary(
                strategy: strategy,
                checkpoints: checkpoints.map { checkpoint in
                    let snapshots = matching.compactMap { run in
                        run.yearlySnapshots.first(where: { $0.turn >= checkpoint })
                    }.filter(\.survived)
                    let completedRepositions = matching.flatMap(\.decisions).filter {
                        $0.action == "業態転換"
                            && $0.turn + 12 <= checkpoint
                            && $0.profitAfter != nil
                    }
                    let improved = completedRepositions.filter {
                        ($0.profitAfter ?? Int.min) > ($0.profitBefore ?? 0)
                    }
                    let policyChanges = matching.flatMap(\.decisions).filter {
                        $0.action == "業態転換" && $0.turn <= checkpoint
                    }
                    return SimulationCheckpointSummary(
                        years: checkpoint / 48,
                        runs: matching.count,
                        survivalRate: Double(snapshots.count) / Double(matching.count),
                        medianSales: percentile(snapshots.map(\.cumulativeSales), 0.5),
                        medianOperatingProfit: percentile(snapshots.map(\.cumulativeOperatingProfit), 0.5),
                        medianCompanyValue: percentile(snapshots.map(\.companyValue), 0.5),
                        lowerQuartileCompanyValue: percentile(snapshots.map(\.companyValue), 0.25),
                        upperQuartileCompanyValue: percentile(snapshots.map(\.companyValue), 0.75),
                        specializationRate: milestoneRate(
                            matching.map(\.firstSpecializationTurn),
                            by: checkpoint
                        ),
                        advancedStoreRate: milestoneRate(
                            matching.map(\.firstAdvancedStoreTurn),
                            by: checkpoint
                        ),
                        roadsideStoreRate: milestoneRate(
                            matching.map(\.firstRoadsideStoreTurn),
                            by: checkpoint
                        ),
                        multipleStoreRate: milestoneRate(
                            matching.map(\.firstExpansionTurn),
                            by: checkpoint
                        ),
                        averagePolicyChanges: Double(policyChanges.count) / Double(matching.count),
                        profitableRepositionRate: completedRepositions.isEmpty ? 0
                            : Double(improved.count) / Double(completedRepositions.count)
                    )
                }
            )
        }
    }

    private static func milestoneRate(_ turns: [Int?], by checkpoint: Int) -> Double {
        guard !turns.isEmpty else { return 0 }
        let reached = turns.compactMap { $0 }.filter { $0 <= checkpoint }
        return Double(reached.count) / Double(turns.count)
    }

    private static func percentile(_ values: [Int], _ percentile: Double) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * percentile).rounded())
        return sorted[min(sorted.count - 1, max(0, index))]
    }

    private static func foundingPurpose(for district: DistrictKind) -> CustomerPurpose {
        switch district {
        case .suburb, .emerging: .family
        case .industrial: .work
        case .highway: .outdoor
        case .downtown, .station: .general
        }
    }

    private static func facility(for productKind: MarketProductKind) -> StoreFacility? {
        switch productKind {
        case .repaired, .refurbished: .serviceWorkshop
        case .camper, .workCargo, .outdoor: .customWorkshop
        case .standard, .collector: nil
        }
    }

    private static func acceptedConditions(
        for productKind: MarketProductKind
    ) -> Set<VehicleConditionBand> {
        switch productKind {
        case .repaired, .refurbished: [.normal, .rough, .faulty]
        case .camper, .workCargo, .outdoor: [.normal, .rough]
        case .standard, .collector: [.normal]
        }
    }

    private static func companyMonthlyCashCost(_ game: GameEngine) -> Int {
        game.stores.reduce(0) { total, store in
            let rent = store.acquisition == .lease
                ? store.plotIDs.compactMap { game.plot(id: $0)?.monthlyRent }.reduce(0, +)
                : 0
            return total + game.monthlyPersonnelCost(for: store) + rent + store.advertising
                + store.type.monthlyFixedCost + store.facilityMonthlyCost
        }
    }

    private static func reserveAmount(game: GameEngine, strategy: SimulationStrategy) -> Int {
        max(600, Int((Double(companyMonthlyCashCost(game)) * strategy.reserveMonths).rounded(.up)))
    }

    private static func rollingProfit(game: GameEngine, weeks: Int) -> Int {
        game.reports.prefix(weeks).reduce(0) { $0 + $1.operatingProfit }
    }

    private static func roundedUpToThousand(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        return ((amount + 999) / 1_000) * 1_000
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
