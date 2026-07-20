import SwiftUI

struct BuildStoreView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let plot: LandPlot
    @State private var step = 0
    @State private var mode: AcquisitionMode = .lease
    @State private var type: StoreType = .standard
    @State private var focus: CustomerFocus = .family
    @State private var concept: StoreConcept = .general
    @State private var facilities: Set<StoreFacility> = []
    @State private var loan = 0
    @State private var completed = false
    @State private var foundingBuildCompleted = false

    private var footprint: [LandPlot] { game.footprintPlots(startingAt: plot, type: type, mode: mode) }
    private var availableTypes: [StoreType] {
        StoreType.allCases.filter {
            $0.requiredGridCells >= concept.minimumGridCells
                && game.footprintPlots(startingAt: plot, type: $0, mode: mode).count == $0.requiredGridCells
        }
    }
    private var landCost: Int { game.landAcquisitionCost(for: footprint, mode: mode) }
    private var demolitionCost: Int { game.demolitionCost(for: footprint) }
    private var total: Int { game.totalBuildCost(for: footprint, type: type, mode: mode, facilities: facilities) }
    private var neededLoan: Int { max(0, total - game.cash) }
    private var monthlyOccupancyCost: Int { mode == .lease ? footprint.reduce(0) { $0 + $1.monthlyRent } : 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: 3).tint(GameTheme.teal).padding()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if game.tutorialStep == .buildStore {
                            TutorialCoachCard(step: .buildStore)
                        }
                        Text(stepTitle).font(.title2.bold()).foregroundStyle(GameTheme.ink)
                        if step == 0 { acquisitionStep }
                        if step == 1 { storeTypeStep }
                        if step == 2 { forecastStep }
                    }
                    .padding(18)
                }
                HStack(spacing: 12) {
                    if step > 0 { Button("戻る") { step -= 1 }.buttonStyle(.bordered) }
                    Button(step == 2 ? "契約して出店" : "次へ") {
                        if step < 2 { step += 1 }
                        else { completeBuild() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.teal)
                    .frame(maxWidth: .infinity)
                    .disabled(step == 2 && (game.cash + loan < total || footprint.count != type.requiredGridCells || !concept.defaultFacilities.isSubset(of: facilities)))
                }
                .padding()
                .background(.white)
            }
            .background(GameTheme.cream)
            .navigationTitle("出店計画 \(step + 1)/3")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .alert(foundingBuildCompleted ? "創業店がオープンしました" : "新店舗の建設を開始しました", isPresented: $completed) {
                Button("マップへ戻る") { dismiss() }
            } message: {
                if foundingBuildCompleted {
                    Text("既存建物を解体し、\(type.requiredGridCells)セルを連結した敷地に\(type.name)を開業しました。在庫はまだ0台です。")
                } else {
                    Text("\(type.requiredGridCells)セルの既存建物を解体し、\(type.name)を着工しました。完成まで\(type.constructionMonths)週間です。")
                }
            }
            .onAppear {
                type = availableTypes.contains(.standard) ? .standard : (availableTypes.first ?? type)
                facilities = concept.defaultFacilities
                ensureCompatibleStoreType()
            }
            .onChange(of: mode) { _, _ in
                if !availableTypes.contains(type), let fallback = availableTypes.first {
                    type = fallback
                }
            }
            .onChange(of: concept) { _, _ in
                facilities.formUnion(concept.defaultFacilities)
                ensureCompatibleStoreType()
                facilities = facilities.filter { $0.minimumGridCells <= type.requiredGridCells }
            }
            .onChange(of: type) { _, _ in
                facilities = facilities.filter { $0.minimumGridCells <= type.requiredGridCells }
                facilities.formUnion(concept.defaultFacilities)
            }
        }
    }

    private var stepTitle: String { ["物件取得と解体", "店舗と使用グリッド", "収支予測と資金"][step] }

    private var acquisitionStep: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: plot.structure.icon).foregroundStyle(plot.district.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("現在：\(plot.structure.name)").font(.subheadline.bold())
                    Text("選んだ店舗に必要な\(type.requiredGridCells)セルをまとめて取得し、建物を解体します").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .gameCard()
            ChoiceCard(title: "購入", subtitle: "\(type.footprintName)合計 \(landCost.currency)・土地を資産保有", icon: "building.columns.fill", selected: mode == .purchase) { mode = .purchase }
            ChoiceCard(title: "借地", subtitle: "\(type.footprintName)分の保証金 \(landCost.currency)・建替え可能", icon: "key.fill", selected: mode == .lease) { mode = .lease }
            Label("解体費 \(demolitionCost.currency) は初期投資に含まれます", systemImage: "hammer.fill")
                .font(.subheadline.bold()).foregroundStyle(GameTheme.orange)
            Text(mode == .purchase ? "多額の現金を使いますが、土地を資産として保有し融資枠を広げられます。" : "初期資金を守りながら出店でき、撤退もしやすい一方、毎月の賃料が利益を圧迫します。")
                .font(.subheadline).foregroundStyle(.secondary).gameCard()
        }
    }

    private var storeTypeStep: some View {
        VStack(spacing: 10) {
            ForEach(availableTypes) { item in
                ChoiceCard(title: item.name, subtitle: "\(item.footprintName)連結・展示\(item.capacity)台・工期\(item.constructionMonths)週間・建設 \(item.buildCost.currency)", icon: item.icon, gridCells: item.requiredGridCells, selected: type == item) { type = item }
            }
            Label("大きい店舗ほど隣接する同一サイズのセルを多く使用します", systemImage: "square.grid.3x3.fill")
                .font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "商売の方針", subtitle: "業態と客層は自由に選択。立地は需要・供給の傾向として反映")
                Picker("狙う客層", selection: $focus) {
                    ForEach(CustomerFocus.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.menu)
                Picker("店舗コンセプト", selection: $concept) {
                    ForEach(StoreConcept.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.menu)
                Text(concept.summary).font(.caption).foregroundStyle(.secondary)
                Label("この業態は最低(concept.minimumGridCells)区画必要", systemImage: "square.grid.2x2.fill")
                    .font(.caption.bold())
                    .foregroundStyle(concept.minimumGridCells > 1 ? GameTheme.orange : .secondary)
                Divider()
                Text("店舗施設").font(.subheadline.bold())
                ForEach(StoreFacility.allCases) { facility in
                    let required = concept.defaultFacilities.contains(facility)
                    let compatible = facility.minimumGridCells <= type.requiredGridCells
                    Button {
                        guard compatible, !required else { return }
                        if facilities.contains(facility) { facilities.remove(facility) }
                        else { facilities.insert(facility) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: facility.icon).foregroundStyle(GameTheme.teal).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(facility.name).font(.subheadline.bold())
                                Text("設置 (facility.installationCost.currency)・月(facility.monthlyCost.currency)　\(facility.summary)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if required { Text("必須").font(.caption2.bold()).foregroundStyle(GameTheme.orange) }
                            Image(systemName: facilities.contains(facility) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(facilities.contains(facility) ? GameTheme.teal : .gray)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!compatible)
                    .opacity(compatible ? 1 : 0.42)
                }
                HStack {
                    MetricView(title: "需要上位", value: game.recommendedCategories(for: plot.district).prefix(2).map(\.name).joined(separator: "・"))
                    MetricView(title: "供給上位", value: game.recommendedSupplyCategories(for: plot.district).prefix(2).map(\.name).joined(separator: "・"))
                }
            }
            .gameCard()
        }
    }

    private var forecastStep: some View {
        VStack(spacing: 14) {
            let sales = game.estimatedSales(for: plot, type: type, focus: focus, concept: concept)
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "\(concept.name)のシナリオ", subtitle: "需要・供給と客層を含む初期計画")
                HStack { MetricView(title: "初期投資", value: total.currency, detail: "土地 \(landCost.currency)＋解体 \(demolitionCost.currency)"); MetricView(title: "想定販売", value: "\(sales.lowerBound)〜\(sales.upperBound)台/月", tint: GameTheme.teal) }
                HStack { MetricView(title: "損益分岐", value: "\(game.breakEvenSales(for: plot, type: type, mode: mode, facilities: facilities))台/月"); MetricView(title: "開店まで", value: "\(type.constructionMonths)週間") }
                Divider()
                let facilityCost = facilities.reduce(0) { $0 + $1.monthlyCost }
                ScenarioRow(name: "最悪", sales: max(1, sales.lowerBound - 3), profit: (sales.lowerBound - 3) * 32 - type.monthlyFixedCost - facilityCost - monthlyOccupancyCost, color: GameTheme.danger)
                ScenarioRow(name: "標準", sales: (sales.lowerBound + sales.upperBound) / 2, profit: ((sales.lowerBound + sales.upperBound) / 2) * 32 - type.monthlyFixedCost - facilityCost - monthlyOccupancyCost, color: GameTheme.teal)
                ScenarioRow(name: "好調", sales: sales.upperBound + 2, profit: (sales.upperBound + 2) * 32 - type.monthlyFixedCost - facilityCost - monthlyOccupancyCost, color: .blue)
            }
            .gameCard()
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("資金調達").font(.headline); Spacer(); Text("現金 \(game.cash.currency)").font(.caption).foregroundStyle(.secondary) }
                Stepper(value: $loan, in: 0...max(0, game.borrowingLimit - game.debt), step: 1_000) {
                    Text("新規借入  \(loan.currency)").font(.subheadline.bold())
                }
                if neededLoan > 0 && loan < neededLoan { Label("あと \((neededLoan - loan).currency) 必要です", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(GameTheme.danger) }
            }
            .gameCard()
        }
    }

    private func completeBuild() {
        let isFounding = game.stores.isEmpty && game.tutorialStep == .buildStore
        if game.buildStore(on: plot, type: type, mode: mode, focus: focus, concept: concept, facilities: facilities, loanAmount: loan) {
            foundingBuildCompleted = isFounding
            completed = true
        }
    }

    private func ensureCompatibleStoreType() {
        if !availableTypes.contains(type), let fallback = availableTypes.first {
            type = fallback
        }
    }

}

private struct ChoiceCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var gridCells: Int? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if let gridCells {
                        IsometricFootprintIcon(cells: gridCells, selected: selected)
                    } else {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(selected ? .white : GameTheme.teal)
                    }
                }
                .frame(width: 48, height: 42)
                .background(selected ? GameTheme.teal : GameTheme.teal.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(GameTheme.ink); Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? GameTheme.teal : .gray.opacity(0.4))
            }
            .padding(13).background(.white).overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? GameTheme.teal : .clear, lineWidth: 2)).clipShape(RoundedRectangle(cornerRadius: 15)).shadow(color: .black.opacity(0.04), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct IsometricFootprintIcon: View {
    let cells: Int
    let selected: Bool

    var body: some View {
        ZStack {
            ForEach(0..<cells, id: \.self) { index in
                IsometricCellShape()
                    .fill(selected ? Color.white.opacity(0.96) : GameTheme.teal.opacity(0.88))
                    .overlay {
                        IsometricCellShape().stroke(selected ? GameTheme.teal.opacity(0.45) : Color.white.opacity(0.92), lineWidth: 1)
                    }
                    .frame(width: 22, height: 13)
                    .offset(
                        x: (CGFloat(index) - CGFloat(cells - 1) / 2) * 9,
                        y: (CGFloat(index) - CGFloat(cells - 1) / 2) * 5
                    )
            }
        }
        .accessibilityLabel("同一サイズの区画を\(cells)セル使用")
    }
}

private struct IsometricCellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct ScenarioRow: View {
    let name: String
    let sales: Int
    let profit: Int
    let color: Color
    var body: some View {
        HStack { Text(name).font(.caption.bold()).foregroundStyle(color).frame(width: 42, alignment: .leading); Text("\(sales)台").font(.subheadline.monospacedDigit()); Spacer(); Text(profit.currency).font(.subheadline.bold().monospacedDigit()).foregroundStyle(profit >= 0 ? GameTheme.teal : GameTheme.danger) }
    }
}
