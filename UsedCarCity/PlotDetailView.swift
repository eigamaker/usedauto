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
                        GuideInlineCard(showing: [.chooseLocation, .planStore])
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
                                Label("この区画には出店できません", systemImage: "location.slash")
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

    private var normalizedValue: Double {
        min(1, max(0, (value - 0.5) / 0.7))
    }

    private var score: Int {
        Int((value * 100).rounded())
    }

    private var rating: String {
        if value >= 1.05 { return "良好" }
        if value >= 0.9 { return "標準" }
        return "弱い"
    }

    private var color: Color {
        if value >= 1.05 { return GameTheme.teal }
        if value >= 0.9 { return GameTheme.orange }
        return GameTheme.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(GameTheme.ink.opacity(0.10))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * normalizedValue)
                }
            }
            .frame(height: 10)
            HStack(spacing: 3) {
                Text(rating)
                    .foregroundStyle(color)
                Spacer(minLength: 2)
                Text("\(score)")
                    .foregroundStyle(GameTheme.ink.opacity(0.72))
                    .monospacedDigit()
            }
            .font(.caption.bold())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)、\(rating)、\(score)")
    }
}

private struct LandOpportunityCard: View {
    @EnvironmentObject private var game: GameEngine
    let plot: LandPlot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "物件取得と建替え")
            HStack {
                MetricView(title: "既存建物", value: structureText)
                MetricView(title: "解体費", value: plot.structure.demolitionCost.currency, tint: GameTheme.orange)
            }
            HStack {
                MetricView(title: "土地・建物価格", value: plot.price.currency)
                MetricView(title: "月額賃料", value: plot.monthlyRent.currency, detail: "地価前週比 \(String(format: "%+.1f", plot.lastPriceChange * 100))%")
            }
            Divider()
            HStack {
                MetricView(title: "近隣の競合", value: hasNearbyCompetitor ? "あり" : "なし")
            }
        }
        .gameCard()
    }

    private var structureText: String {
        plot.structure == .vacant ? "なし" : plot.structure.name
    }

    private var hasNearbyCompetitor: Bool {
        game.plots.contains { candidate in
            guard candidate.district == plot.district else { return false }
            if case .competitor = candidate.occupant { return true }
            return false
        }
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
        let priceWar = competitor.flatMap { rival in
            game.activePriceWars.first(where: { $0.competitorID == rival.id && $0.district == plot.district })
        }
        let acquisitionOffer = competitor.flatMap { rival in
            game.competitorAcquisitionOffers.first(where: { $0.competitorID == rival.id && $0.plotID == plot.id })
        }
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: name, subtitle: competitor?.strategy ?? "競合店舗")
            HStack {
                MetricView(title: "推定月販", value: "\(max(5, game.estimatedSales(for: plot).upperBound - 2))台")
                MetricView(title: "主力車種", value: competitor?.category.name ?? "不明")
            }
            HStack {
                MetricView(title: "ブランド力", value: competitor?.strength ?? 1 > 1.1 ? "強い" : "標準")
                MetricView(title: "最近の動き", value: priceWar == nil ? "価格維持" : "価格攻勢", detail: priceWar.map { "残り\($0.remainingWeeks(at: game.turn))週間" } ?? "市場調査精度 62%")
            }
            if let acquisitionOffer {
                Label("弱体化により買収交渉が可能：\(acquisitionOffer.cost.currency)。経営本部で実行できます", systemImage: "building.2.crop.circle.fill")
                    .font(.caption.bold()).foregroundStyle(.purple)
            }
            Label("詳しい内部数値は市場調査レベルを上げると判明します", systemImage: "binoculars.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
        .gameCard()
    }
}

private struct StoreDetailCard: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: store.name, subtitle: "\(store.type.name)・\(game.derivedBusinessName(for: store))")
            HStack {
                MetricView(title: "販売台数", value: "\(store.lastSales)台")
                MetricView(title: "売上高", value: store.lastRevenue.currency)
                MetricView(title: "営業利益", value: store.lastProfit.currency, tint: store.lastProfit >= 0 ? GameTheme.teal : GameTheme.danger)
            }
            HStack {
                MetricView(title: "在庫", value: "\(store.inventoryCount) / \(store.type.capacity)台")
                MetricView(title: "来店客レビュー", value: store.reviewRatingText, detail: "\(store.reviewCount)件")
                MetricView(title: "店員", value: "\(store.staff)名")
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
