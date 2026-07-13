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
    @State private var loan = 0
    @State private var completed = false
    @State private var foundingBuildCompleted = false
    @State private var appliedStartupDefaults = false

    init(plot: LandPlot) {
        self.plot = plot
        let recommended: StoreConcept
        switch plot.district {
        case .downtown: recommended = .premium
        case .suburb, .station: recommended = .keiLocal
        case .industrial: recommended = .custom
        case .emerging: recommended = .family
        case .highway: recommended = .business
        }
        _concept = State(initialValue: recommended)
    }

    private var landCost: Int { mode == .purchase ? plot.price : plot.monthlyRent * 6 }
    private var total: Int { landCost + type.buildCost }
    private var neededLoan: Int { max(0, total - game.cash) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: 4).tint(GameTheme.teal).padding()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if game.tutorialStep == .buildStore {
                            TutorialCoachCard(step: .buildStore)
                        }
                        Text(stepTitle).font(.title2.bold()).foregroundStyle(GameTheme.ink)
                        if step == 0 { acquisitionStep }
                        if step == 1 { storeTypeStep }
                        if step == 2 { focusStep }
                        if step == 3 { forecastStep }
                    }
                    .padding(18)
                }
                HStack(spacing: 12) {
                    if step > 0 { Button("戻る") { step -= 1 }.buttonStyle(.bordered) }
                    Button(step == 3 ? "契約して出店" : "次へ") {
                        if step < 3 { step += 1 }
                        else { completeBuild() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.teal)
                    .frame(maxWidth: .infinity)
                    .disabled(step == 3 && game.cash + loan < total)
                }
                .padding()
                .background(.white)
            }
            .background(GameTheme.cream)
            .navigationTitle("出店計画 \(step + 1)/4")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .alert(foundingBuildCompleted ? "創業店がオープンしました" : "新店舗の建設を開始しました", isPresented: $completed) {
                Button("マップへ戻る") { dismiss() }
            } message: {
                if foundingBuildCompleted {
                    Text("\(plot.district.shortName)地区の居抜き物件に\(type.name)を開業しました。在庫はまだ0台です。次は店舗画面から販売車を仕入れましょう。")
                } else {
                    Text("\(plot.district.shortName)地区で\(type.name)を着工しました。完成まで\(type.constructionMonths)か月です。マップ上で工事の進行を確認できます。")
                }
            }
            .onAppear { applyStartupDefaultsIfNeeded() }
        }
    }

    private var stepTitle: String { ["土地の使い方", "店舗タイプ", "狙う客層", "収支予測と資金"][step] }

    private var acquisitionStep: some View {
        VStack(spacing: 12) {
            ChoiceCard(title: "購入", subtitle: "初期 \(plot.price.currency)・地価上昇と担保価値を得る", icon: "building.columns.fill", selected: mode == .purchase) { mode = .purchase }
            ChoiceCard(title: "賃借", subtitle: "保証金 \((plot.monthlyRent * 6).currency)・毎月 \(plot.monthlyRent.currency)", icon: "key.fill", selected: mode == .lease) { mode = .lease }
            Text(mode == .purchase ? "多額の現金を使いますが、土地を資産として保有し融資枠を広げられます。" : "初期資金を守りながら出店でき、撤退もしやすい一方、毎月の賃料が利益を圧迫します。")
                .font(.subheadline).foregroundStyle(.secondary).gameCard()
        }
    }

    private var storeTypeStep: some View {
        VStack(spacing: 10) {
            ForEach(StoreType.allCases) { item in
                ChoiceCard(title: item.name, subtitle: "展示\(item.capacity)台・工期\(item.constructionMonths)か月・建設 \(item.buildCost.currency)・固定費 \(item.monthlyFixedCost.currency)/月", icon: item.icon, selected: type == item) { type = item }
            }
        }
    }

    private var focusStep: some View {
        VStack(spacing: 10) {
            Text("店舗の魅力は立地とコンセプトで変わります。この地区で作る店の強みを選びましょう。")
                .font(.subheadline).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("店舗コンセプト").font(.headline)
                ForEach(StoreConcept.allCases) { item in
                    ChoiceCard(title: item.name, subtitle: item.summary, icon: item.icon, selected: concept == item) { concept = item }
                }
            }
            Text("狙う客層").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            ForEach(CustomerFocus.allCases) { item in
                ChoiceCard(title: item.name, subtitle: focusDescription(item), icon: "person.crop.circle", selected: focus == item) { focus = item }
            }
        }
    }

    private var forecastStep: some View {
        VStack(spacing: 14) {
            let sales = game.estimatedSales(for: plot, type: type, focus: focus, concept: concept)
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "標準シナリオ", subtitle: "予測値は競合や景気で変動します")
                HStack { MetricView(title: "初期投資", value: total.currency); MetricView(title: "想定販売", value: "\(sales.lowerBound)〜\(sales.upperBound)台/月", tint: GameTheme.teal) }
                HStack { MetricView(title: "損益分岐", value: "\(game.breakEvenSales(for: plot, type: type, mode: mode))台/月"); MetricView(title: "開店まで", value: "\(type.constructionMonths)か月") }
                Divider()
                ScenarioRow(name: "最悪", sales: max(1, sales.lowerBound - 3), profit: (sales.lowerBound - 3) * 32 - type.monthlyFixedCost - (mode == .lease ? plot.monthlyRent : 0), color: GameTheme.danger)
                ScenarioRow(name: "標準", sales: (sales.lowerBound + sales.upperBound) / 2, profit: ((sales.lowerBound + sales.upperBound) / 2) * 32 - type.monthlyFixedCost - (mode == .lease ? plot.monthlyRent : 0), color: GameTheme.teal)
                ScenarioRow(name: "好調", sales: sales.upperBound + 2, profit: (sales.upperBound + 2) * 32 - type.monthlyFixedCost - (mode == .lease ? plot.monthlyRent : 0), color: .blue)
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

    private func focusDescription(_ focus: CustomerFocus) -> String {
        switch focus { case .family: "保証・整備品質・ミニバンを重視"; case .value: "安さと維持費を重視"; case .young: "コンパクトさとデザインを重視"; case .affluent: "ブランドと車両状態を重視"; case .business: "稼働率と商用性を重視" }
    }

    private func completeBuild() {
        let isFounding = game.stores.isEmpty && game.tutorialStep == .buildStore
        if game.buildStore(on: plot, type: type, mode: mode, focus: focus, concept: concept, loanAmount: loan) {
            foundingBuildCompleted = isFounding
            completed = true
        }
    }

    private func applyStartupDefaultsIfNeeded() {
        guard !appliedStartupDefaults, game.stores.isEmpty, let plan = game.startupPlan else { return }
        appliedStartupDefaults = true
        type = plan.recommendedStoreType
        focus = plan.recommendedFocus
        concept = plan.recommendedConcept
    }
}

private struct ChoiceCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).foregroundStyle(selected ? .white : GameTheme.teal).frame(width: 42, height: 42).background(selected ? GameTheme.teal : GameTheme.teal.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(GameTheme.ink); Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? GameTheme.teal : .gray.opacity(0.4))
            }
            .padding(13).background(.white).overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? GameTheme.teal : .clear, lineWidth: 2)).clipShape(RoundedRectangle(cornerRadius: 15)).shadow(color: .black.opacity(0.04), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
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
