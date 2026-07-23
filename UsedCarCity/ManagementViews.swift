import SwiftUI

struct ManagementView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    CompanyScoreCard()
                    MilestonesCard()
                    TutorialProgressCard()
                    CompetitiveBattleCard()
                    CompetitorsCard()
                    RecentReportsCard()
                    Button(role: .destructive) { showReset = true } label: { Label("最初からやり直す", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                }
                .padding(14)
            }
            .background(GameTheme.cream)
            .navigationTitle("経営本部")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("現在のゲームを終了しますか？", isPresented: $showReset) {
                Button("最初からやり直す", role: .destructive) { game.resetGame() }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}

private struct CompanyScoreCard: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) { Text("翠浜ユーズドカー").font(.title3.bold()); Text("経営 \(game.turn + 1)週目").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                CapsuleLabel(text: "\(game.endingEvaluation.rank.rawValue)ランク", color: GameTheme.teal, icon: "trophy.fill")
            }
            Text(game.companyValue.currency).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(GameTheme.ink)
            Text("現在の企業価値").font(.caption).foregroundStyle(.secondary)
            ProgressView(value: game.progress).tint(GameTheme.teal)
            HStack {
                Text("創業").font(.caption)
                Spacer()
                Text("現時点 \(game.endingEvaluation.totalScore)点・\(game.endingEvaluation.rank.title)").font(.caption)
            }
        }
        .gameCard()
    }
}

private struct MilestonesCard: View {
    @EnvironmentObject private var game: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionTitle(
                title: "経営目標",
                subtitle: "達成すると報奨や新しい経営機会を獲得"
            )
            HStack(spacing: 18) {
                Label("達成 \(completedCount)/\(game.milestoneStatuses.count)", systemImage: "checkmark.seal.fill")
                Label("累計 \(game.careerStatistics.totalSales.formatted())台", systemImage: "car.2.fill")
                Label("年間最高 \(game.careerStatistics.bestAnnualSales.formatted())台", systemImage: "calendar")
            }
            .font(.caption.bold())
            .foregroundStyle(GameTheme.navy)

            ForEach(game.milestoneStatuses) { status in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: status.isCompleted ? "checkmark.circle.fill" : status.id.icon)
                            .foregroundStyle(status.isCompleted ? GameTheme.teal : GameTheme.orange)
                            .frame(width: 25)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.id.title).font(.subheadline.bold())
                            Text(status.id.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(status.isCompleted ? "達成済" : status.progressText)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(status.isCompleted ? GameTheme.teal : GameTheme.ink)
                    }
                    ProgressView(value: status.progress)
                        .tint(status.isCompleted ? GameTheme.teal : GameTheme.orange)
                    Label(status.id.reward, systemImage: "gift.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 35)
                }
                if status.id != game.milestoneStatuses.last?.id {
                    Divider()
                }
            }
        }
        .gameCard()
    }

    private var completedCount: Int {
        game.milestoneStatuses.filter(\.isCompleted).count
    }
}

private struct TutorialProgressCard: View {
    @EnvironmentObject private var game: GameEngine
    let features = ["仕入", "価格設定", "整備", "広告", "人員配置", "財務", "出店"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "経営機能", subtitle: "最初の6週間で段階的に解放")
            ForEach(features, id: \.self) { feature in
                HStack {
                    Image(systemName: game.unlockedFeatures.contains(feature) ? "checkmark.circle.fill" : "lock.circle.fill").foregroundStyle(game.unlockedFeatures.contains(feature) ? GameTheme.teal : .gray.opacity(0.5))
                    Text(feature).font(.subheadline)
                    Spacer()
                    Text(game.unlockedFeatures.contains(feature) ? "利用可能" : "未解放").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .gameCard()
    }
}

private struct CompetitorsCard: View {
    @EnvironmentObject private var game: GameEngine
    @State private var selectedOffer: CompetitorAcquisitionOffer?
    @State private var resultMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "競合企業", subtitle: "実在庫・価格・広告・設備・資金と、利益市場への追随状況")
            ForEach(game.competitors) { competitor in
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 11) {
                        Image(systemName: "flag.fill").foregroundStyle(GameTheme.orange).frame(width: 38, height: 38).background(GameTheme.orange.opacity(0.1)).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(competitor.name).font(.subheadline.bold())
                            Text("\(competitor.strategy)・\(competitor.plotIDs.count)店舗・勢力\(Int(competitor.strength * 100))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(competitor.category.name).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 5).background(.gray.opacity(0.1)).clipShape(Capsule())
                    }
                    let researchStoreID = game.stores.first?.id
                    let cashRange = game.competitorEstimateRange(value: competitor.cash, storeID: researchStoreID, seed: competitor.name.count)
                    let inventoryCount = competitor.branches.reduce(0) { $0 + $1.inventoryCount }
                    let inventoryRange = game.competitorEstimateRange(value: inventoryCount, storeID: researchStoreID, seed: competitor.name.count + 19)
                    Text("推定現金 \(cashRange.lowerBound.currency)〜\(cashRange.upperBound.currency)・在庫 \(inventoryRange.lowerBound)〜\(inventoryRange.upperBound)台・誤差±\(Int(game.competitorInformationErrorRate(for: researchStoreID) * 100))%")
                        .font(.caption2.bold()).foregroundStyle(GameTheme.navy)
                    ForEach(competitor.branches) { branch in
                        let district = game.plot(id: branch.plotID)?.district ?? .suburb
                        let categoryText = branch.inventory.filter { $0.count > 0 }.map { "\($0.category.name)/\($0.purpose.name) \($0.count)" }.joined(separator: "・")
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("\(district.shortName)店｜シェア\(Int(game.competitorMarketShare(competitor, in: district) * 100))%")
                                Spacer()
                                Text("価格\(Int(branch.priceIndex * 100))・広告\(branch.advertising.currency)")
                            }
                            Text("在庫 \(categoryText.isEmpty ? "なし" : categoryText)｜設備 \(branch.facilities.map(\.name).joined(separator: "・"))")
                            Text("直近 売上\(branch.lastRevenue.currency)・利益\(branch.lastProfit.currency)")
                        }
                        .font(.caption2).foregroundStyle(.secondary)
                    }
                    let following = competitor.profitableSegmentWeeks.filter { $0.value >= 4 }.sorted { $0.value > $1.value }
                    if !following.isEmpty {
                        Label("追随兆候：\(following.prefix(3).map { "\($0.key.name) \($0.value)週" }.joined(separator: "・"))", systemImage: "eye.trianglebadge.exclamationmark.fill")
                            .font(.caption2.bold()).foregroundStyle(GameTheme.orange)
                    }
                    if let offer = game.competitorAcquisitionOffers.first(where: { $0.competitorID == competitor.id }),
                       let targetPlot = game.plot(id: offer.plotID) {
                        Button {
                            selectedOffer = offer
                        } label: {
                            Label("\(targetPlot.district.shortName)店を買収・\(offer.cost.currency)", systemImage: "building.2.crop.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(game.cash < offer.cost)
                    }
                }
                if competitor.id != game.competitors.last?.id { Divider() }
            }
        }
        .gameCard()
        .confirmationDialog("競合店舗を買収しますか？", isPresented: Binding(get: { selectedOffer != nil }, set: { if !$0 { selectedOffer = nil } }), titleVisibility: .visible) {
            if let offer = selectedOffer {
                Button("\(offer.cost.currency)で買収") {
                    let competitorName = game.competitorName(for: offer.competitorID)
                    resultMessage = game.acquireCompetitorStore(competitorID: offer.competitorID, plotID: offer.plotID)
                        ? "\(competitorName)の店舗を買収しました"
                        : "資金、店舗上限、買収条件を確認してください"
                    selectedOffer = nil
                }
                Button("キャンセル", role: .cancel) { selectedOffer = nil }
            }
        } message: {
            Text("土地・小型店舗・在庫3台と既存顧客を引き継ぎます。")
        }
        .alert("競合店舗買収", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("OK") { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
    }
}

private struct CompetitiveBattleCard: View {
    @EnvironmentObject private var game: GameEngine
    @State private var destinationStoreID: UUID?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "競合対策本部", subtitle: "価格戦争への対応と人材獲得を選択")
            if game.activePriceWars.isEmpty {
                Label("現在、対応が必要な価格戦争はありません", systemImage: "checkmark.shield.fill")
                    .font(.subheadline).foregroundStyle(GameTheme.teal)
            } else {
                ForEach(game.activePriceWars) { challenge in
                    priceWarRow(challenge)
                    if challenge.id != game.activePriceWars.last?.id { Divider() }
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 9) {
                Text("競合からの人材獲得").font(.subheadline.bold())
                if game.stores.count > 1 {
                    Picker("配属先", selection: $destinationStoreID) {
                        ForEach(game.stores) { store in Text(store.name).tag(Optional(store.id)) }
                    }
                    .pickerStyle(.menu)
                }
                ForEach(game.rivalTalentOffers) { offer in
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundStyle(.purple).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(offer.employee.name).font(.subheadline.bold())
                            Text("\(game.competitorName(for: offer.competitorID))・販売\(offer.employee.salesSkill) / 仕入\(offer.employee.procurementSkill)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("獲得 \(offer.signingCost.currency)") {
                            guard let storeID = destinationStoreID ?? game.stores.first?.id else { return }
                            message = game.poachRivalTalent(offer.employee.id, from: offer.competitorID, to: storeID)
                                ? "\(offer.employee.name)を獲得しました"
                                : "資金または配属先の人員上限を確認してください"
                        }
                        .buttonStyle(.bordered)
                        .font(.caption.bold())
                        .disabled(game.cash < offer.signingCost || game.stores.isEmpty)
                    }
                }
            }
        }
        .gameCard()
        .onAppear { destinationStoreID = destinationStoreID ?? game.stores.first?.id }
        .alert("競合対策", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func priceWarRow(_ challenge: PriceWarChallenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "tag.fill").foregroundStyle(GameTheme.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(challenge.district.shortName)地区の価格戦争").font(.subheadline.bold())
                    Text("\(game.competitorName(for: challenge.competitorID))・残り\(challenge.remainingWeeks(at: game.turn))週間")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(challenge.response?.name ?? "未対応")
                    .font(.caption.bold())
                    .foregroundStyle(challenge.response == nil ? GameTheme.orange : GameTheme.teal)
            }
            if let response = challenge.response {
                Label(response.detail, systemImage: response.icon)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("未対応では成約率と地域シェアが低下します", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(GameTheme.orange)
                HStack(spacing: 8) {
                    ForEach(PriceWarResponse.allCases) { response in
                        let cost = game.priceWarResponseCost(response, challengeID: challenge.id)
                        Button {
                            message = game.respondToPriceWar(challenge.id, with: response)
                                ? "\(response.name)を開始しました"
                                : "資金または対応期限を確認してください"
                        } label: {
                            VStack(spacing: 2) {
                                Label(response.name, systemImage: response.icon)
                                Text(cost.currency).font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(response == .counterSale ? GameTheme.orange : GameTheme.teal)
                        .disabled(game.cash < cost)
                    }
                }
            }
        }
    }
}

struct CompetitionDemoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    CompetitiveBattleCard()
                    CompetitorsCard()
                }
                .padding(14)
            }
            .background(GameTheme.cream)
            .navigationTitle("競合対策本部")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct RecentReportsCard: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "週間履歴", subtitle: "最近の業績")
            if game.reports.isEmpty {
                Text("1週間進めるとレポートが記録されます").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(game.reports.prefix(6)) { report in
                    HStack {
                        Text("\(report.month)月\(report.week)週").font(.caption.bold().monospacedDigit()).frame(width: 64, alignment: .leading)
                        Text("\(report.sales)台").font(.subheadline.monospacedDigit())
                        Spacer()
                        Text(String(format: "在庫 %.1f週", report.averageInventoryWeeks))
                            .font(.caption2.bold().monospacedDigit()).foregroundStyle(.secondary)
                        Text(report.operatingProfit.currency).font(.subheadline.bold().monospacedDigit()).foregroundStyle(report.operatingProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                    }
                }
            }
        }
        .gameCard()
    }
}

struct MonthlyReportView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let report: MonthlyReport

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if game.tutorialStep == .reviewFirstResult {
                        TutorialCoachCard(step: .reviewFirstResult)
                    }
                    VStack(spacing: 7) {
                        Image(systemName: report.operatingProfit >= 0 ? "chart.line.uptrend.xyaxis.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 48)).foregroundStyle(report.operatingProfit >= 0 ? GameTheme.teal : GameTheme.orange)
                        Text(report.headline).font(.title3.bold()).multilineTextAlignment(.center)
                        Text("\(report.year)年\(report.month)月 第\(report.week)週 週間レポート").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).gameCard()
                    HStack {
                        MetricView(title: "販売台数", value: "\(report.sales)台")
                        MetricView(title: "売上高", value: report.revenue.currency)
                        MetricView(title: "営業利益", value: report.operatingProfit.currency, tint: report.operatingProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                    }
                    .gameCard()
                    HStack {
                        MetricView(title: "平均在庫週数", value: String(format: "%.1f週", report.averageInventoryWeeks), detail: "12週超は滞留在庫")
                        MetricView(title: "売上総利益", value: report.grossProfit.currency)
                        MetricView(title: "現金増減", value: report.cashChange.currency, tint: report.cashChange >= 0 ? GameTheme.teal : GameTheme.danger)
                    }
                    .gameCard()
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "店舗別の結果", subtitle: "数字が動いた理由")
                        ForEach(game.stores) { store in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Text(store.name).font(.subheadline.bold()); Spacer(); Text("\(store.lastSales)台 / \(store.lastProfit.currency)").font(.caption.bold()) }
                                ForEach(store.causes) { cause in
                                    HStack { Text(cause.effect >= 0 ? "+" : "−").foregroundStyle(cause.effect >= 0 ? GameTheme.teal : GameTheme.orange); Text(cause.title); Spacer(); Text(String(format: "%+.1f台", cause.effect)).monospacedDigit() }.font(.caption)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .gameCard()
                    if !report.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(title: "今週のニュース")
                            ForEach(report.notes, id: \.self) { note in Label(note, systemImage: "bell.fill").font(.subheadline).foregroundStyle(GameTheme.ink) }
                        }
                        .gameCard()
                    }
                    if game.tutorialStep == .reviewFirstResult {
                        Button(action: finishTutorial) {
                            Label("結果を確認して自由経営へ", systemImage: "checkmark.seal.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GameTheme.teal)
                    }
                }
                .padding(15)
            }
            .background(GameTheme.cream)
            .navigationTitle("週間レポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(game.tutorialStep == .reviewFirstResult ? "完了" : "閉じる") {
                        if game.tutorialStep == .reviewFirstResult { game.completeTutorial() }
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .interactiveDismissDisabled(game.tutorialStep == .reviewFirstResult)
    }

    private func finishTutorial() {
        game.completeTutorial()
        dismiss()
    }
}

struct GameEndView: View {
    @EnvironmentObject private var game: GameEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if isBankrupt {
                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: 72)).foregroundStyle(GameTheme.orange)
                    Text("資金が尽きました").font(.largeTitle.bold())
                    Text("在庫、価格、立地、固定費を見直して再挑戦しましょう。")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                } else {
                    finalEvaluation
                    careerRecord
                }
                Button("スタート画面に戻って再挑戦") { game.resetGame() }
                    .buttonStyle(.borderedProminent).tint(GameTheme.teal)
            }
            .padding(28)
        }
        .background(GameTheme.cream)
        .interactiveDismissDisabled()
    }

    private var isBankrupt: Bool { game.financialDistressWeeks >= 2 }

    private var finalEvaluation: some View {
        let evaluation = game.endingEvaluation
        return VStack(spacing: 14) {
            Image(systemName: "trophy.circle.fill")
                .font(.system(size: 66)).foregroundStyle(GameTheme.teal)
            Text("10年間の経営完了").font(.title.bold())
            Text("\(evaluation.rank.rawValue)ランク")
                .font(.system(size: 54, weight: .black, design: .rounded))
                .foregroundStyle(GameTheme.navy)
            Text(evaluation.rank.title).font(.headline)
            Text("総合 \(evaluation.totalScore) / 100点").font(.subheadline.bold().monospacedDigit())
            HStack {
                MetricView(title: "資産", value: "\(evaluation.assetScore)/45")
                MetricView(title: "ブランド", value: "\(evaluation.brandScore)/30")
                MetricView(title: "販売実績", value: "\(evaluation.salesScore)/25")
            }
            Text("最終企業価値 \(game.companyValue.currency)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .gameCard()
    }

    private var careerRecord: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "10年間の経営記録")
            recordRow("累計販売台数", "\(game.careerStatistics.totalSales.formatted())台")
            recordRow("累計売上高", game.careerStatistics.totalRevenue.currency)
            recordRow("黒字週", "\(game.careerStatistics.profitableWeeks.formatted())週")
            recordRow("週間最高販売", "\(game.careerStatistics.bestWeeklySales.formatted())台")
            recordRow("達成目標", "\(game.careerStatistics.completedMilestones.count)/\(BusinessMilestoneID.allCases.count)")
        }
        .gameCard()
    }

    private func recordRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.bold().monospacedDigit())
        }
    }
}
