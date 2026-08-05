import SwiftUI
import Charts

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
                            HStack(spacing: 6) {
                                Text(competitor.name).font(.subheadline.bold())
                                if competitor.isMarketEntrant {
                                    CapsuleLabel(text: "新規参入", color: .purple, icon: "sparkles")
                                }
                            }
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
                        let categoryText = branch.inventory.filter { $0.count > 0 }.map {
                            "\($0.category.name)/\($0.marketProductKind.name) \($0.count)"
                        }.joined(separator: "・")
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("\(district.shortName)店｜シェア\(Int(game.competitorMarketShare(competitor, in: district) * 100))%")
                                Spacer()
                                Text("価格\(Int(branch.priceIndex * 100))・広告\(branch.advertising.currency)")
                            }
                            Text("在庫 \(categoryText.isEmpty ? "なし" : categoryText)｜設備 \(branch.facilities.map(\.name).joined(separator: "・"))")
                            Text("直近 売上\(branch.lastRevenue.currency)・利益\(branch.lastProfit.currency)")
                            if !branch.productizationQueue.isEmpty {
                                Text(
                                    "商品化中 "
                                        + branch.productizationQueue.map {
                                            "\($0.marketProductKind.name) \($0.outsourced ? "外注" : "内製")・残\($0.weeksRemaining)週"
                                        }.joined(separator: "／")
                                )
                                .foregroundStyle(.purple)
                            }
                        }
                        .font(.caption2).foregroundStyle(.secondary)
                    }
                    let following = competitor.segmentResponseWeeks.filter { $0.value >= 4 }.sorted { $0.value > $1.value }
                    if !following.isEmpty {
                        Label(
                            "追随段階："
                                + following.prefix(3).map {
                                    let phase = $0.value >= 12 ? "設備投資" : $0.value >= 8 ? "広告・商品化" : "検証中"
                                    return "\($0.key.category.name)/\($0.key.productKind.name) \(phase)"
                                }.joined(separator: "・"),
                            systemImage: "eye.trianglebadge.exclamationmark.fill"
                        )
                            .font(.caption2.bold()).foregroundStyle(GameTheme.orange)
                        Text(
                            following.prefix(3).map { item in
                                let records = competitor.segmentRecords[item.key] ?? []
                                let revenue = records.suffix(4).reduce(0) { $0 + $1.competitorRevenue }
                                let cost = records.suffix(4).reduce(0) { $0 + $1.competitorCost }
                                let companySales = records.suffix(4).reduce(0) { $0 + $1.competitorSales }
                                let marketSales = game.segmentMarkets[item.key]?.recentFourWeeks.reduce(0) {
                                    $0 + $1.fulfilled
                                } ?? 0
                                let share = marketSales > 0 ? companySales * 100 / marketSales : 0
                                return "\(item.key.productKind.name)：4週粗利\((revenue - cost).currency)・成約シェア\(share)%"
                            }.joined(separator: "／")
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                        CharacterAvatarView(
                            role: offer.employee.characterAvatarRole,
                            seed: offer.employee.characterAvatarSeed,
                            size: 42
                        )
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
    @State private var selectedReport: MonthlyReport?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "週間履歴", subtitle: "前週からの変化をタップして確認")
            if game.reports.isEmpty {
                Text("1週間進めるとレポートが記録されます").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(game.reports.prefix(6)) { report in
                    Button {
                        selectedReport = report
                    } label: {
                        HStack {
                            Text("\(report.month)月\(report.week)週").font(.caption.bold().monospacedDigit()).frame(width: 64, alignment: .leading)
                            Text("\(report.sales)台").font(.subheadline.monospacedDigit())
                            if let change = game.weeklyComparison(for: report) {
                                Text(change.sales == 0 ? "±0" : String(format: "%+d", change.sales))
                                    .font(.caption2.bold().monospacedDigit())
                                    .foregroundStyle(change.sales >= 0 ? GameTheme.teal : GameTheme.orange)
                            }
                            Spacer()
                            Text(String(format: "在庫 %.1f週", report.averageInventoryWeeks))
                                .font(.caption2.bold().monospacedDigit()).foregroundStyle(.secondary)
                            Text(report.operatingProfit.currency).font(.subheadline.bold().monospacedDigit()).foregroundStyle(report.operatingProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .gameCard()
        .sheet(item: $selectedReport) { report in
            MonthlyReportView(report: report)
        }
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
                    GuideInlineCard(showing: [.readWeeklyReport])
                    VStack(spacing: 7) {
                        Image(systemName: report.operatingProfit >= 0 ? "chart.line.uptrend.xyaxis.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 48)).foregroundStyle(report.operatingProfit >= 0 ? GameTheme.teal : GameTheme.orange)
                        Text(report.headline).font(.title3.bold()).multilineTextAlignment(.center)
                        Text("\(report.year)年\(report.month)月 第\(report.week)週 週間レポート").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).gameCard()
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "1週間のまとめ", subtitle: "経営判断に必要な出来事を短く整理")
                        Text(report.headline).font(.headline)
                        ForEach(Array(report.notes.prefix(4)), id: \.self) { note in
                            Label(note, systemImage: "circle.fill")
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .gameCard()
                    VStack(alignment: .leading, spacing: 11) {
                        SectionTitle(title: "車の売買によるお金の動き", subtitle: "売上と仕入れを、実際の現金移動まで分けて表示")
                        HStack {
                            MetricView(title: "販売総額", value: report.vehicleCashSummary.salesRevenue.currency)
                            MetricView(title: "実入金", value: report.vehicleCashSummary.salesCashReceived.currency)
                            MetricView(title: "仕入支払", value: report.vehicleCashSummary.acquisitionCashPaid.currency)
                        }
                        HStack {
                            MetricView(title: "仕入価額", value: report.vehicleCashSummary.acquisitionValue.currency)
                            MetricView(title: "下取り充当", value: report.vehicleCashSummary.tradeInAllowance.currency)
                            MetricView(title: "車両純現金", value: report.vehicleCashSummary.netVehicleCash.currency, tint: report.vehicleCashSummary.netVehicleCash >= 0 ? GameTheme.teal : GameTheme.danger)
                        }
                    }
                    .gameCard()
                    let saleTransactions = report.vehicleTransactions.filter {
                        if case .sale = $0 { return true }
                        return false
                    }
                    if !saleTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(title: "販売した車", subtitle: "販売価格・仕入原価・粗利の詳細")
                            ForEach(saleTransactions) { transaction in
                                WeeklyVehicleTransactionRow(transaction: transaction, reportTurn: report.week)
                                if transaction.id != saleTransactions.last?.id { Divider() }
                            }
                        }
                        .gameCard()
                    }
                    let acquisitionTransactions = report.vehicleTransactions.filter {
                        if case .acquisition = $0 { return true }
                        return false
                    }
                    if !acquisitionTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(title: "仕入れた車", subtitle: "仕入価格・販売想定・納入予定の詳細")
                            ForEach(acquisitionTransactions) { transaction in
                                WeeklyVehicleTransactionRow(transaction: transaction, reportTurn: report.week)
                                if transaction.id != acquisitionTransactions.last?.id { Divider() }
                            }
                        }
                        .gameCard()
                    }
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
                    VStack(alignment: .leading, spacing: 11) {
                        SectionTitle(
                            title: "販売ダッシュボード",
                            subtitle: "商談から成約、見送り、販売後対応まで"
                        )
                        HStack {
                            MetricView(title: "商談", value: "\(report.salesSummary.negotiations)件")
                            MetricView(title: "成約", value: "\(report.salesSummary.sales)台")
                            MetricView(
                                title: "見送り客",
                                value: "\(report.salesSummary.missedBuyers)人",
                                tint: report.salesSummary.missedBuyers == 0 ? GameTheme.teal : GameTheme.orange
                            )
                        }
                        HStack {
                            MetricView(title: "下取り", value: "\(report.salesSummary.tradeIns)台")
                            MetricView(
                                title: "クレーム",
                                value: "\(report.salesSummary.claimCount)件",
                                tint: report.salesSummary.claimCount == 0 ? GameTheme.teal : GameTheme.danger
                            )
                            MetricView(title: "補償費", value: report.salesSummary.claimCost.currency)
                        }
                    }
                    .gameCard()
                    if let comparison = game.weeklyComparison(for: report) {
                        VStack(alignment: .leading, spacing: 11) {
                            SectionTitle(title: "前週からの変化", subtitle: "同じ指標を並べ、良化・悪化をすばやく確認")
                            HStack {
                                WeeklyDeltaMetric(title: "販売", value: "\(signed(comparison.sales))台", favorable: comparison.sales >= 0)
                                WeeklyDeltaMetric(title: "売上", value: signedCurrency(comparison.revenue), favorable: comparison.revenue >= 0)
                                WeeklyDeltaMetric(title: "営業利益", value: signedCurrency(comparison.operatingProfit), favorable: comparison.operatingProfit >= 0)
                            }
                            HStack {
                                WeeklyDeltaMetric(title: "粗利", value: signedCurrency(comparison.grossProfit), favorable: comparison.grossProfit >= 0)
                                WeeklyDeltaMetric(title: "現金増減", value: signedCurrency(comparison.cashChange), favorable: comparison.cashChange >= 0)
                                WeeklyDeltaMetric(
                                    title: "平均在庫",
                                    value: String(format: "%+.1f週", comparison.averageInventoryWeeks),
                                    favorable: comparison.averageInventoryWeeks <= 0
                                )
                            }
                        }
                        .gameCard()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "店舗別の結果", subtitle: "数字が動いた理由")
                        ForEach(report.storeResults) { store in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(store.storeName).font(.subheadline.bold())
                                    Spacer()
                                    Text("\(store.sales)台 / \(store.operatingProfit.currency)").font(.caption.bold())
                                }
                                ForEach(Array(store.causes.prefix(2))) { cause in
                                    HStack { Text(cause.effect >= 0 ? "+" : "−").foregroundStyle(cause.effect >= 0 ? GameTheme.teal : GameTheme.orange); Text(cause.title); Spacer(); Text(String(format: "%+.1f台", cause.effect)).monospacedDigit() }.font(.caption)
                                }
                                if store.causes.count > 2 {
                                    Text("ほか\(store.causes.count - 2)要因")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .gameCard()
                    if !report.procurement.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(
                                title: "仕入れ指示の実績",
                                subtitle: "指示別・仕入れ先別の取得、支出、入札実績"
                            )
                            ForEach(report.procurement) { line in
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(line.instructionName).font(.subheadline.bold())
                                        Spacer()
                                        Text(line.source?.name ?? "全経路")
                                            .font(.caption.bold())
                                            .foregroundStyle(GameTheme.teal)
                                    }
                                    HStack {
                                        MetricView(title: "取得", value: "\(line.acquiredCount)台")
                                        MetricView(title: "支出", value: line.spent.currency)
                                        MetricView(title: "入札額", value: line.reserved.currency)
                                    }
                                    Text(line.result)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .gameCard()
                    }
                    let compactEventCategories = WeeklyReportCategory.allCases.filter {
                        $0 != .market && $0 != .sales
                    }
                    if compactEventCategories.contains(where: { !report.notes(in: $0).isEmpty }) {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(
                                title: "今週の主な出来事",
                                subtitle: "市場情報は週明けの新聞に統合しました"
                            )
                            ForEach(compactEventCategories) { category in
                                let categoryNotes = report.notes(in: category)
                                if !categoryNotes.isEmpty {
                                    VStack(alignment: .leading, spacing: 7) {
                                        Label(category.title, systemImage: category.icon)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(GameTheme.teal)
                                        ForEach(Array(categoryNotes.prefix(3)), id: \.self) { note in
                                            Label(note, systemImage: "circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(GameTheme.ink)
                                                .lineLimit(2)
                                        }
                                        if categoryNotes.count > 3 {
                                            Text("ほか\(categoryNotes.count - 3)件")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                        }
                        .gameCard()
                    }
                }
                .padding(15)
            }
            .background(GameTheme.cream)
            .navigationTitle("週間レポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .bold()
                }
            }
        }
    }

    private func signed(_ value: Int) -> String {
        value == 0 ? "±0" : String(format: "%+d", value)
    }

    private func signedCurrency(_ value: Int) -> String {
        if value == 0 { return "±0" }
        return "\(value > 0 ? "+" : "−")\(abs(value).currency)"
    }
}

private struct WeeklyVehicleTransactionRow: View {
    let transaction: VehicleTransactionRecord
    let reportTurn: Int

    var body: some View {
        switch transaction {
        case .sale(_, _, _, let storeName, _, _, let powertrain, let productState, let count, let detail):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.vehicleName).font(.subheadline.bold())
                        Text("\(storeName)・\(powertrain.name)・\(productState.name)・\(detail.channel)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(count)台").font(.caption.bold())
                }
                HStack {
                    MetricView(title: "販売価格", value: detail.salePrice.currency)
                    MetricView(title: "原価", value: detail.bookCost.currency)
                    MetricView(title: "粗利", value: detail.grossProfit.currency, tint: detail.grossProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                }
            }
            .padding(.vertical, 3)
        case .acquisition(_, _, _, let storeName, _, _, let powertrain, let count, let detail):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.vehicleName).font(.subheadline.bold())
                        Text("\(storeName)・\(powertrain.name)・\(detail.source.name)・\(detail.dispositionPlan.name)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(count)台").font(.caption.bold())
                }
                HStack {
                    MetricView(title: "仕入価格", value: detail.paidAmount.currency)
                    MetricView(title: "想定売価", value: detail.expectedSalePrice.currency)
                    MetricView(title: "想定粗利", value: detail.expectedGrossProfit.currency, tint: detail.expectedGrossProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                }
                if let arrivalTurn = detail.arrivalTurn {
                    Text("納入予定：第\(arrivalTurn)週処理後")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
        }
    }
}

private struct WeeklyDeltaMetric: View {
    let title: String
    let value: String
    let favorable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 4) {
                Image(systemName: favorable ? "arrow.up.right" : "arrow.down.right")
                Text(value).monospacedDigit()
            }
            .font(.caption.bold())
            .foregroundStyle(favorable ? GameTheme.teal : GameTheme.orange)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MonthlyPLDashboardView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let report: MonthlyPLReport
    @State private var showGuideLesson = false

    private var previousReport: MonthlyPLReport? {
        guard let index = game.monthlyReports.firstIndex(where: { $0.id == report.id }),
              game.monthlyReports.indices.contains(index + 1) else { return nil }
        return game.monthlyReports[index + 1]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    VStack(spacing: 7) {
                        Image(systemName: report.operatingProfit >= 0 ? "chart.xyaxis.line" : "exclamationmark.triangle.fill")
                            .font(.system(size: 43, weight: .bold))
                            .foregroundStyle(report.operatingProfit >= 0 ? GameTheme.teal : GameTheme.orange)
                        Text("\(report.year)年\(report.month)月 月次PL")
                            .font(.title2.bold())
                        Text(report.operatingProfit >= 0 ? "月間黒字を確保しました" : "月間赤字です。費用構造と在庫回転を確認してください")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .gameCard()

                    Button { showGuideLesson = true } label: {
                        HStack(spacing: 11) {
                            GuideAvatarView(expression: .think, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PLの読み方を教わる").font(.subheadline.bold()).foregroundStyle(GameTheme.ink)
                                Text("売上高から営業利益までを、いまの数字で解説します")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
                        }
                        .gameCard(padding: 12)
                    }
                    .buttonStyle(.plain)

                    HStack {
                        MetricView(title: "販売台数", value: "\(report.sales)台")
                        MetricView(title: "売上高", value: report.revenue.currency)
                        MetricView(
                            title: "営業利益",
                            value: report.operatingProfit.currency,
                            detail: "利益率 \(percent(report.operatingMargin))",
                            tint: report.operatingProfit >= 0 ? GameTheme.teal : GameTheme.danger
                        )
                    }
                    .gameCard()

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "週ごとの営業利益", subtitle: "月内の変化と振れ幅")
                        Chart(report.weeklyReports) { week in
                            BarMark(
                                x: .value("週", "第\(week.week)週"),
                                y: .value("営業利益", week.operatingProfit)
                            )
                            .foregroundStyle(week.operatingProfit >= 0 ? GameTheme.teal : GameTheme.orange)
                            .annotation(position: week.operatingProfit >= 0 ? .top : .bottom) {
                                Text(week.operatingProfit.currency)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 180)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }
                    .gameCard()

                    VStack(alignment: .leading, spacing: 7) {
                        SectionTitle(title: "損益計算書", subtitle: "4週間を合算した月次実績")
                        MonthlyPLRow(title: "売上高", value: report.revenue)
                        MonthlyPLRow(title: "売上原価", value: -report.costOfSales, isExpense: true)
                        MonthlyPLRow(title: "売上総利益", value: report.grossProfit, isTotal: true)
                        MonthlyPLRow(title: "人件費", value: -report.personnel, isExpense: true)
                        MonthlyPLRow(title: "賃料", value: -report.rent, isExpense: true)
                        MonthlyPLRow(title: "広告費", value: -report.advertising, isExpense: true)
                        MonthlyPLRow(title: "店舗・設備固定費", value: -report.fixedCosts, isExpense: true)
                        MonthlyPLRow(title: "減価償却", value: -report.depreciation, isExpense: true)
                        MonthlyPLRow(title: "支払利息", value: -report.interest, isExpense: true)
                        if report.customerClaims > 0 {
                            MonthlyPLRow(title: "販売後補償・クレーム", value: -report.customerClaims, isExpense: true)
                        }
                        MonthlyPLRow(
                            title: "営業利益",
                            value: report.operatingProfit,
                            isTotal: true,
                            isExpense: report.operatingProfit < 0
                        )
                    }
                    .gameCard()

                    VStack(alignment: .leading, spacing: 11) {
                        SectionTitle(title: "経営状態", subtitle: "資金・在庫・収益性を月末時点で確認")
                        HStack {
                            MetricView(title: "月末現金", value: report.endingCash.currency, tint: report.endingCash >= 0 ? GameTheme.teal : GameTheme.danger)
                            MetricView(title: "現金増減", value: report.cashChange.currency, tint: report.cashChange >= 0 ? GameTheme.teal : GameTheme.orange)
                            MetricView(title: "借入金", value: report.debt.currency)
                        }
                        HStack {
                            MetricView(title: "在庫資産", value: report.inventoryAssets.currency)
                            MetricView(title: "平均在庫", value: String(format: "%.1f週", report.averageInventoryWeeks), tint: report.averageInventoryWeeks <= 12 ? GameTheme.teal : GameTheme.orange)
                            MetricView(title: "企業価値", value: report.companyValue.currency)
                        }
                        if let previousReport {
                            Divider()
                            HStack {
                                Text("前月比").font(.caption.bold()).foregroundStyle(.secondary)
                                Spacer()
                                Text("売上 \(deltaCurrency(report.revenue - previousReport.revenue))")
                                Text("営業利益 \(deltaCurrency(report.operatingProfit - previousReport.operatingProfit))")
                            }
                            .font(.caption.bold().monospacedDigit())
                        }
                    }
                    .gameCard()

                    VStack(alignment: .leading, spacing: 9) {
                        SectionTitle(title: "経営チェック", subtitle: "来月の意思決定に使う要点")
                        ForEach(managementComments, id: \.self) { comment in
                            Label(comment, systemImage: comment.contains("良好") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(comment.contains("良好") ? GameTheme.teal : GameTheme.ink)
                        }
                    }
                    .gameCard()
                }
                .padding(15)
            }
            .background(GameTheme.cream)
            .navigationTitle("月次経営レポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.bold()
                }
            }
            .sheet(isPresented: $showGuideLesson) {
                GuideProfitLossLessonView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var managementComments: [String] {
        var comments: [String] = []
        if report.operatingProfit < 0 {
            comments.append("営業赤字です。店舗別利益と固定費を確認してください")
        } else if report.operatingMargin < 0.08 {
            comments.append("黒字ですが営業利益率は8%未満です。粗利と値引きを見直しましょう")
        } else {
            comments.append("収益性は良好です。成長投資後の現金余力を確認しましょう")
        }
        if report.grossMargin < 0.18 {
            comments.append("粗利率が18%未満です。仕入原価・商品化原価・販売価格を再点検してください")
        }
        if report.averageInventoryWeeks > 12 {
            comments.append("平均在庫が12週を超えています。滞留車の値下げ・移動・AA出品を検討してください")
        }
        if report.cashChange < 0 {
            comments.append("月間で現金が減少しました。利益とキャッシュの差を仕入・投資から確認してください")
        }
        return comments
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func deltaCurrency(_ value: Int) -> String {
        if value == 0 { return "±0" }
        return "\(value > 0 ? "+" : "−")\(abs(value).currency)"
    }
}

private struct MonthlyPLRow: View {
    let title: String
    let value: Int
    var isTotal = false
    var isExpense = false

    var body: some View {
        HStack {
            Text(title).font(isTotal ? .headline : .subheadline)
            Spacer()
            Text(value.currency)
                .font((isTotal ? Font.headline : Font.subheadline).monospacedDigit())
                .foregroundStyle(isExpense ? GameTheme.danger : GameTheme.ink)
        }
        .padding(.vertical, isTotal ? 7 : 3)
        .overlay(alignment: .top) {
            if isTotal { Divider() }
        }
    }
}

struct MarketNewspaperView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIssueID: UUID?

    private var issue: MarketNewspaperIssue? {
        if let selectedIssueID,
           let selected = game.newspaperIssues.first(where: { $0.id == selectedIssueID }) {
            return selected
        }
        return game.newspaperIssues.first
    }

    private let sectionOrder = ["景気・燃料", "専門市場", "競合レポート", "街の動き"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let issue {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "newspaper.fill").font(.system(size: 36))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.isBreaking ? "号外・翠浜モビリティ経済新聞" : "翠浜モビリティ経済新聞")
                                        .font(.title2.weight(.black))
                                        .foregroundStyle(issue.isBreaking ? GameTheme.danger : GameTheme.ink)
                                    Text("\(issue.year)年\(issue.month)月 第\(issue.week)週号")
                                        .font(.caption.bold().monospacedDigit())
                                }
                                Spacer()
                            }
                            Divider().overlay(GameTheme.ink)
                            Text(issue.leadHeadline)
                                .font(.title3.weight(.black))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .gameCard()

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                            ForEach(issue.facts) { fact in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fact.label).font(.caption).foregroundStyle(.secondary)
                                    Text(fact.value).font(.headline.monospacedDigit())
                                    Text("\(fact.direction)・\(severityLabel(fact.severity))")
                                        .font(.caption2.bold())
                                        .foregroundStyle(severityColor(fact.severity))
                                    if fact.history.count >= 2 {
                                        Chart(fact.history) { point in
                                            LineMark(
                                                x: .value("週", point.turn),
                                                y: .value("値", point.value)
                                            )
                                            .interpolationMethod(.catmullRom)
                                            .foregroundStyle(severityColor(fact.severity))
                                        }
                                        .chartXAxis(.hidden)
                                        .chartYAxis(.hidden)
                                        .frame(height: 34)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(11)
                                .background(Color.white.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        ForEach(sectionOrder, id: \.self) { section in
                            let articles = issue.articles.filter { $0.section == section }
                            if !articles.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    NewspaperSectionHeader(kicker: section, title: sectionTitle(section))
                                    ForEach(articles) { article in
                                        HStack(alignment: .top, spacing: 11) {
                                            Image(systemName: article.systemImage)
                                                .foregroundStyle(article.isPositive ? GameTheme.teal : GameTheme.orange)
                                                .frame(width: 24)
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(article.headline).font(.headline)
                                                Text(article.body)
                                                    .font(.subheadline)
                                                    .foregroundStyle(GameTheme.ink.opacity(0.78))
                                                    .fixedSize(horizontal: false, vertical: true)
                                                if let kind = article.researchKind {
                                                    if let report = game.companyResearchReport(kind: kind, targetName: article.headline) {
                                                        VStack(alignment: .leading, spacing: 3) {
                                                            Text("社内調査・精度\(report.accuracyPercent)%")
                                                                .font(.caption.bold())
                                                                .foregroundStyle(GameTheme.teal)
                                                            ForEach(report.payload.detailLines, id: \.self) { line in
                                                                Text(line)
                                                                    .font(.caption)
                                                                    .foregroundStyle(GameTheme.ink.opacity(0.72))
                                                            }
                                                        }
                                                        .padding(.top, 3)
                                                    } else if !game.researchCapableStores().isEmpty {
                                                        Menu("この記事を調査") {
                                                            ForEach(game.researchCapableStores()) { store in
                                                                Button("\(store.name)で調査") {
                                                                    _ = game.enqueueResearchWork(
                                                                        storeID: store.id,
                                                                        kind: kind,
                                                                        targetName: article.headline
                                                                    )
                                                                }
                                                            }
                                                        }
                                                        .font(.caption.bold())
                                                    }
                                                }
                                            }
                                        }
                                        if article.id != articles.last?.id { Divider() }
                                    }
                                }
                                .gameCard()
                            }
                        }
                    } else {
                        ContentUnavailableView("最初の週を進めると発行されます", systemImage: "newspaper")
                    }
                }
                .padding(15)
            }
            .background(GameTheme.cream)
            .navigationTitle("市場新聞")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if game.newspaperIssues.count > 1 {
                        Menu("過去号") {
                            ForEach(game.newspaperIssues) { issue in
                                Button("\(issue.year)年\(issue.month)月 第\(issue.week)週号") {
                                    selectedIssueID = issue.id
                                }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func sectionTitle(_ section: String) -> String {
        switch section {
        case "景気・燃料": "景気とクルマ選び"
        case "専門市場": "いま注目されている市場"
        case "競合レポート": "競合各社の現在地"
        case "街の動き": "地域で起きていること"
        default: section
        }
    }

    private func severityLabel(_ severity: EconomicSeverity) -> String {
        switch severity {
        case .normal: "平常"
        case .notable: "注目"
        case .major: "重大"
        case .emergency: "緊急"
        }
    }

    private func severityColor(_ severity: EconomicSeverity) -> Color {
        switch severity {
        case .normal: GameTheme.teal
        case .notable: GameTheme.orange
        case .major, .emergency: GameTheme.danger
        }
    }
}

private struct NewspaperSectionHeader: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kicker).font(.caption2.weight(.black)).tracking(1.2).foregroundStyle(GameTheme.orange)
            Text(title).font(.title3.weight(.black))
        }
    }
}

private struct NewspaperMarketMetric: View {
    let title: String
    let value: String
    let forecast: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            Text(value).font(.caption.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.68)
            Text("予測 \(forecast)").font(.system(size: 8, weight: .medium)).foregroundStyle(GameTheme.teal).lineLimit(1).minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.subheadline.bold().monospacedDigit()).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Text(value).font(.subheadline.bold().monospacedDigit())
            }
        }
    }
}
