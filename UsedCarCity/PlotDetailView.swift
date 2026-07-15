import SwiftUI

struct PlotDetailView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let plotID: Int
    @State private var showBuild = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let plot = game.plot(id: plotID) {
                    VStack(spacing: 16) {
                        if let step = game.tutorialStep, game.isTutorialActive, step == .buildStore {
                            TutorialCoachCard(step: step)
                        }
                        switch plot.occupant {
                        case .player:
                            if let store = game.store(at: plot.id) {
                                StoreCommandCenterView(storeID: store.id)
                            }
                        case .competitor(let name):
                            PlotHero(plot: plot)
                            CompetitorDetailCard(name: name, plot: plot)
                        case .available:
                            PlotHero(plot: plot)
                            LandOpportunityCard(plot: plot)
                            if let development = plot.development {
                                DevelopmentDetailCard(project: development, plot: plot)
                            } else if game.canPlanStore(on: plot) {
                                Button { showBuild = true } label: {
                                    Label(game.stores.isEmpty ? "この建物を取得して創業する" : "購入・解体・建設プランへ", systemImage: "hammer.fill")
                                        .font(.headline).frame(maxWidth: .infinity).padding(16)
                                        .foregroundStyle(.white).background(GameTheme.teal).clipShape(RoundedRectangle(cornerRadius: 15))
                                }
                            } else {
                                Label(game.stores.isEmpty ? "マップ上の出店候補地を選択してください" : "5週目の終了後に出店が解放されます", systemImage: "lock.fill")
                                    .font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(15).background(.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        case .unavailable:
                            PlotHero(plot: plot)
                            ContentUnavailableView("利用できない土地", systemImage: "nosign")
                        }
                    }
                    .padding(16)
                }
            }
            .background(GameTheme.cream)
            .navigationTitle("区画詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .sheet(isPresented: $showBuild) {
                if let plot = game.plot(id: plotID) { BuildStoreView(plot: plot) }
            }
        }
    }
}

private struct PlotHero: View {
    @EnvironmentObject private var game: GameEngine
    let plot: LandPlot

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: plot.district.symbol).font(.title2).foregroundStyle(plot.district.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(plot.district.name) \(plot.localNumber)番区画").font(.title3.bold())
                    Text("共通グリッド1セル・\(plot.area)㎡・\(plot.structure.name)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                status
            }
            HStack(spacing: 8) {
                AttributeBar(title: "視認性", value: plot.visibility)
                AttributeBar(title: "出入り", value: plot.access)
                AttributeBar(title: "交通量", value: plot.traffic)
            }
        }
        .gameCard()
    }

    @ViewBuilder private var status: some View {
        switch plot.occupant {
        case .available:
            if plot.development != nil { CapsuleLabel(text: "開発予定", color: .orange, icon: "hammer.fill") }
            else { CapsuleLabel(text: "取得・建替え可", color: GameTheme.teal, icon: "building.2.crop.circle") }
        case .player: CapsuleLabel(text: "自店舗", color: GameTheme.teal, icon: "star.fill")
        case .competitor: CapsuleLabel(text: "競合", color: GameTheme.orange, icon: "flag.fill")
        case .unavailable: CapsuleLabel(text: "対象外", color: .gray, icon: "xmark")
        }
    }
}

private struct AttributeBar: View {
    let title: String
    let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            ProgressView(value: min(value, 1.2), total: 1.2).tint(GameTheme.teal)
            Text(value >= 1.05 ? "良好" : value >= 0.9 ? "標準" : "弱い").font(.caption.bold())
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LandOpportunityCard: View {
    @EnvironmentObject private var game: GameEngine
    let plot: LandPlot

    var body: some View {
        let sales = game.estimatedSales(for: plot)
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "物件取得と建替え", subtitle: "街の建物はすべて同じグリッド上で管理されます")
            HStack {
                MetricView(title: "既存建物", value: plot.structure.name)
                MetricView(title: "解体費", value: plot.structure.demolitionCost.currency, tint: GameTheme.orange)
            }
            HStack {
                MetricView(title: "土地・建物価格", value: plot.price.currency)
                MetricView(title: "月額賃料", value: plot.monthlyRent.currency, detail: "地価前週比 \(String(format: "%+.1f", plot.lastPriceChange * 100))%")
            }
            Divider()
            HStack {
                MetricView(title: "想定来店数", value: "\(game.estimatedVisitors(for: plot))人/月")
                MetricView(title: "予想販売", value: "\(sales.lowerBound)〜\(sales.upperBound)台/月", tint: GameTheme.teal)
            }
            HStack {
                MetricView(title: "競合影響", value: competitionText, detail: "地区内の密度")
                MetricView(title: "推奨車種", value: recommendedText)
            }
            HStack(spacing: 10) {
                Image(systemName: game.recommendedConcept(for: plot.district).icon)
                    .foregroundStyle(plot.district.color)
                    .frame(width: 34, height: 34)
                    .background(plot.district.color.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("この立地の勝ち筋").font(.caption).foregroundStyle(.secondary)
                    Text(game.recommendedConcept(for: plot.district).name).font(.subheadline.bold())
                    Text(game.recommendedConcept(for: plot.district).summary).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(10).background(plot.district.color.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 11))
            DisclosureGroup("予測の計算根拠") {
                Text("地区人口 × 購入率 × 交通量 × 視認性 × 車種需要から来店と販売を試算。競合出店、在庫、価格、広告によって実績は変動します。")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            }
            .font(.subheadline.bold())
        }
        .gameCard()
    }

    private var recommendedText: String { game.recommendedCategories(for: plot.district).prefix(2).map(\.name).joined(separator: "・") }
    private var competitionText: String {
        let value = game.district(for: plot).competition
        return value > 1.2 ? "強い" : value > 0.85 ? "中程度" : "弱い"
    }
}

private struct DevelopmentDetailCard: View {
    let project: DevelopmentProject
    let plot: LandPlot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: project.title, subtitle: "都市開発計画")
            HStack {
                MetricView(title: "完成まで", value: "\(project.monthsRemaining)週間", tint: GameTheme.orange)
                MetricView(title: "人口効果", value: "+\(project.populationBoost.formatted())人")
                MetricView(title: "交通効果", value: "+\(Int(project.trafficBoost * 100))%")
            }
            Label("工事中は出店できません。完成後は客足と地価の上昇が期待できます。", systemImage: "info.circle.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
        .gameCard()
    }
}

private struct CompetitorDetailCard: View {
    @EnvironmentObject private var game: GameEngine
    let name: String
    let plot: LandPlot

    var body: some View {
        let competitor = game.competitors.first(where: { $0.name == name })
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: name, subtitle: competitor?.strategy ?? "競合店舗")
            HStack {
                MetricView(title: "推定月販", value: "\(max(5, game.estimatedSales(for: plot).upperBound - 2))台")
                MetricView(title: "主力車種", value: competitor?.category.name ?? "不明")
            }
            HStack {
                MetricView(title: "ブランド力", value: competitor?.strength ?? 1 > 1.1 ? "強い" : "標準")
                MetricView(title: "最近の動き", value: "価格維持", detail: "市場調査精度 62%")
            }
            Label("詳しい内部数値は市場調査レベルを上げると判明します", systemImage: "binoculars.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
        .gameCard()
    }
}

private struct StoreDetailCard: View {
    let store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: store.name, subtitle: "\(store.type.name)・\(store.concept.name)")
            HStack {
                MetricView(title: "販売台数", value: "\(store.lastSales)台")
                MetricView(title: "売上高", value: store.lastRevenue.currency)
                MetricView(title: "営業利益", value: store.lastProfit.currency, tint: store.lastProfit >= 0 ? GameTheme.teal : GameTheme.danger)
            }
            HStack {
                MetricView(title: "在庫", value: "\(store.inventoryCount) / \(store.type.capacity)台")
                MetricView(title: "顧客満足度", value: "\(store.satisfaction)")
                MetricView(title: "従業員", value: "\(store.staff)名")
            }
            if !store.causes.isEmpty {
                Divider()
                Text("なぜこの結果になったか").font(.subheadline.bold())
                ForEach(store.causes) { cause in
                    HStack {
                        Image(systemName: cause.effect >= 0 ? "plus.circle.fill" : "minus.circle.fill").foregroundStyle(cause.effect >= 0 ? GameTheme.teal : GameTheme.orange)
                        Text(cause.title).font(.subheadline)
                        Spacer()
                        Text(String(format: "%+.1f台", cause.effect)).font(.caption.bold().monospacedDigit())
                    }
                }
            }
        }
        .gameCard()
    }
}

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption2.bold()).multilineTextAlignment(.center)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
