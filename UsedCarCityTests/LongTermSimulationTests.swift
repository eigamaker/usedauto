import Foundation
import XCTest
@testable import UsedCarCity

@MainActor
final class LongTermSimulationTests: XCTestCase {
    func testFiveYearSmokeSimulationAcrossAllStrategies() {
        let report = LongTermSimulationRunner.run(configuration: .smoke)

        XCTAssertEqual(report.runs.count, SimulationStrategy.allCases.count)
        for run in report.runs {
            XCTAssertGreaterThan(run.completedWeeks, 0, "\(run.strategy.displayName)が進行していません")
            XCTAssertFalse(run.yearlySnapshots.isEmpty, "\(run.strategy.displayName)に年次記録がありません")
            XCTAssertTrue(
                run.invariantViolations.isEmpty,
                "\(run.strategy.displayName): \(run.invariantViolations.joined(separator: " / "))"
            )
        }
        XCTAssertTrue(report.markdown().contains("戦略別サマリー"))
        XCTAssertTrue(report.csv().contains("operating_profit"))
    }

    func testSimulationIsDeterministicForSameSeedAndStrategy() {
        let first = LongTermSimulationRunner.run(seed: 29, strategy: .adaptive, horizonWeeks: 240)
        let second = LongTermSimulationRunner.run(seed: 29, strategy: .adaptive, horizonWeeks: 240)
        XCTAssertEqual(first, second)
    }

    func testPersistenceCanBeDisabledWithoutCreatingSaveData() {
        let game = GameEngine(persistenceEnabled: false)
        game.startNewGame(simulationSeed: 7)
        XCTAssertFalse(game.hasSaveData)
    }

    func testBankruptcyAtCheckpointIsNotCountedAsSurvival() {
        let report = LongTermSimulationRunner.run(configuration: SimulationConfiguration(
            seeds: [3],
            strategies: [.survival],
            horizonWeeks: 240
        ))

        XCTAssertLessThan(report.runs.first?.completedWeeks ?? 240, 240)
        XCTAssertEqual(report.runs.first?.yearlySnapshots.last?.survived, false)
        XCTAssertEqual(report.summaries.first?.checkpoints.first?.survivalRate, 0)
        XCTAssertEqual(report.summaries.first?.checkpoints.first?.survivingRuns, 0)
        XCTAssertNil(report.summaries.first?.checkpoints.first?.medianOperatingProfit)
        XCTAssertTrue(report.markdown().contains("| 0/1 | 0.0% | — | — | — |"))
    }

    func testGenerateLongTermSimulationReport() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["RUN_LONG_TERM_SIMULATION"] == "1" else {
            throw XCTSkip("Tools/run-long-term-simulation.sh から明示実行する分析テストです")
        }

        let configuration = SimulationConfiguration(
            seeds: parseSeeds(environment["SIMULATION_SEEDS"]) ?? SimulationConfiguration.analysis.seeds,
            strategies: parseStrategies(environment["SIMULATION_STRATEGIES"])
                ?? SimulationConfiguration.analysis.strategies,
            horizonWeeks: min(10, max(1, Int(environment["SIMULATION_YEARS"] ?? "") ?? 10)) * 48
        )
        let report = LongTermSimulationRunner.run(configuration: configuration)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = try encoder.encode(report)
        addAttachment(data: json, name: "report.json", uniformType: "public.json")
        addAttachment(
            data: Data(report.markdown().utf8),
            name: "report.md",
            uniformType: "net.daringfireball.markdown"
        )
        addAttachment(
            data: Data(report.csv().utf8),
            name: "yearly.csv",
            uniformType: "public.comma-separated-values-text"
        )

        XCTAssertEqual(report.runs.count, configuration.seeds.count * configuration.strategies.count)
        XCTAssertTrue(report.runs.allSatisfy(\.invariantViolations.isEmpty))
    }

    func testGenerateTenYearBusinessTypeReport() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["RUN_LONG_TERM_SIMULATION"] == "1" else {
            throw XCTSkip("Tools/run-long-term-simulation.sh から明示実行する業態別分析テストです")
        }

        let seeds = parseSeeds(environment["SIMULATION_SEEDS"]) ?? SimulationConfiguration.analysis.seeds
        let businessTypes = parseBusinessTypes(environment["SIMULATION_BUSINESS_TYPES"])
            ?? SimulationBusinessType.allCases
        let years = min(10, max(1, Int(environment["SIMULATION_YEARS"] ?? "") ?? 10))
        let runs = businessTypes.flatMap { businessType in
            seeds.map {
                LongTermSimulationRunner.run(
                    seed: $0,
                    strategy: .adaptive,
                    horizonWeeks: years * 48,
                    businessType: businessType
                )
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        addAttachment(
            data: try encoder.encode(runs),
            name: "business-type-report.json",
            uniformType: "public.json"
        )
        addAttachment(
            data: Data(businessTypeMarkdown(runs: runs, years: years).utf8),
            name: "business-type-report.md",
            uniformType: "net.daringfireball.markdown"
        )

        XCTAssertEqual(runs.count, seeds.count * businessTypes.count)
        XCTAssertTrue(runs.allSatisfy(\.invariantViolations.isEmpty))
        XCTAssertTrue(runs.allSatisfy { $0.businessType != nil })
    }

    private func addAttachment(data: Data, name: String, uniformType: String) {
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: uniformType)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func parseSeeds(_ raw: String?) -> [Int]? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.contains("...") {
            let bounds = raw.components(separatedBy: "...").compactMap(Int.init)
            guard bounds.count == 2, bounds[0] <= bounds[1] else { return nil }
            return Array(bounds[0]...bounds[1])
        }
        let values = raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return values.isEmpty ? nil : values
    }

    private func parseStrategies(_ raw: String?) -> [SimulationStrategy]? {
        guard let raw, !raw.isEmpty, raw != "all" else { return nil }
        let values = raw.split(separator: ",").compactMap {
            SimulationStrategy(rawValue: $0.trimmingCharacters(in: .whitespaces))
        }
        return values.isEmpty ? nil : values
    }

    private func parseBusinessTypes(_ raw: String?) -> [SimulationBusinessType]? {
        guard let raw, !raw.isEmpty, raw != "all" else { return nil }
        let values = raw.split(separator: ",").compactMap {
            SimulationBusinessType(rawValue: $0.trimmingCharacters(in: .whitespaces))
        }
        return values.isEmpty ? nil : values
    }

    private func businessTypeMarkdown(runs: [SimulationRunResult], years: Int) -> String {
        var lines = [
            "# 業態別・専業運営シミュレーション",
            "",
            "- 期間: \(years)年",
            "- 運営方針: 創業時から業態を固定し、対象車種・顧客目的・専用設備・加工を業態に最適化",
            "- 一般店舗: 専門設備を持たない総合運営。結果は資本余力への依存を前提に解釈",
            "",
            "| 業態 | 完走数 | 生存率 | 累計販売中央値 | 累計営業利益中央値 | 企業価値中央値 | 最低現金中央値 | 最大借入中央値 |",
            "|---|---:|---:|---:|---:|---:|---:|---:|"
        ]
        for businessType in SimulationBusinessType.allCases {
            let matching = runs.filter { $0.businessType == businessType }
            guard !matching.isEmpty else { continue }
            let survivors = matching.filter { $0.completedWeeks >= years * 48 }
            let snapshots = survivors.compactMap(\.yearlySnapshots.last)
            lines.append(
                "| \(businessType.displayName) | \(survivors.count)/\(matching.count) | "
                    + "\(percent(Double(survivors.count) / Double(matching.count))) | "
                    + "\(median(snapshots.map(\.cumulativeSales))) | "
                    + "\(median(snapshots.map(\.cumulativeOperatingProfit))) | "
                    + "\(median(snapshots.map(\.companyValue))) | "
                    + "\(median(matching.map(\.minimumCash))) | \(median(matching.map(\.maximumDebt))) |"
            )
        }
        lines += [
            "",
            "## Run別結果",
            "",
            "| 業態 | Seed | 終了週 | 終了理由 | 累計販売 | 累計営業利益 | 企業価値 | 専門別粗利 |",
            "|---|---:|---:|---|---:|---:|---:|---|"
        ]
        for run in runs {
            let snapshot = run.yearlySnapshots.last
            let specialty = snapshot?.specialtyGrossProfit
                .sorted { $0.key < $1.key }
                .map { "\($0.key):\($0.value)" }
                .joined(separator: " / ")
            lines.append(
                "| \(run.businessType?.displayName ?? "—") | \(run.seed) | \(run.completedWeeks) | "
                    + "\(run.endingReason) | \(snapshot?.cumulativeSales ?? 0) | "
                    + "\(snapshot?.cumulativeOperatingProfit ?? 0) | \(snapshot?.companyValue ?? 0) | "
                    + "\((specialty?.isEmpty == false) ? specialty! : "—") |"
            )
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func median(_ values: [Int]) -> String {
        guard !values.isEmpty else { return "—" }
        let sorted = values.sorted()
        return String(sorted[(sorted.count - 1) / 2])
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
