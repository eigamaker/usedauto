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
            seeds: [29],
            strategies: [.adaptive],
            horizonWeeks: 240
        ))

        XCTAssertLessThan(report.runs.first?.completedWeeks ?? 240, 240)
        XCTAssertEqual(report.runs.first?.yearlySnapshots.last?.survived, false)
        XCTAssertEqual(report.summaries.first?.checkpoints.first?.survivalRate, 0)
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
}
