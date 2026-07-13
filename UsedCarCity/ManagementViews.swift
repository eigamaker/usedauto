import SwiftUI

struct ManagementView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    CompanyScoreCard()
                    TutorialProgressCard()
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
                VStack(alignment: .leading, spacing: 3) { Text("翠浜ユーズドカー").font(.title3.bold()); Text("経営 \(game.turn + 1)か月目").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                CapsuleLabel(text: rank, color: GameTheme.teal, icon: "trophy.fill")
            }
            Text(game.companyValue.currency).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(GameTheme.ink)
            Text("現在の企業価値").font(.caption).foregroundStyle(.secondary)
            ProgressView(value: game.progress).tint(GameTheme.teal)
            HStack { Text("創業").font(.caption); Spacer(); Text("10年後の評価").font(.caption) }
        }
        .gameCard()
    }
    private var rank: String { game.companyValue > 80_000 ? "Aランク" : game.companyValue > 40_000 ? "Bランク" : "Cランク" }
}

private struct TutorialProgressCard: View {
    @EnvironmentObject private var game: GameEngine
    let features = ["仕入", "価格設定", "整備", "広告", "人員配置", "財務", "出店"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "経営機能", subtitle: "最初の6か月で段階的に解放")
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "競合企業", subtitle: "各社は同じ土地市場で出店します")
            ForEach(game.competitors) { competitor in
                HStack(spacing: 11) {
                    Image(systemName: "flag.fill").foregroundStyle(GameTheme.orange).frame(width: 38, height: 38).background(GameTheme.orange.opacity(0.1)).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) { Text(competitor.name).font(.subheadline.bold()); Text("\(competitor.strategy)・\(competitor.plotIDs.count)店舗").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(competitor.category.name).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 5).background(.gray.opacity(0.1)).clipShape(Capsule())
                }
            }
        }
        .gameCard()
    }
}

private struct RecentReportsCard: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "月次履歴", subtitle: "最近の業績")
            if game.reports.isEmpty {
                Text("月を進めるとレポートが記録されます").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(game.reports.prefix(6)) { report in
                    HStack {
                        Text("\(report.year).\(String(format: "%02d", report.month))").font(.caption.bold().monospacedDigit()).frame(width: 64, alignment: .leading)
                        Text("\(report.sales)台").font(.subheadline.monospacedDigit())
                        Spacer()
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
                        Text("\(report.year)年\(report.month)月 月次レポート").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).gameCard()
                    HStack {
                        MetricView(title: "販売台数", value: "\(report.sales)台")
                        MetricView(title: "売上高", value: report.revenue.currency)
                        MetricView(title: "営業利益", value: report.operatingProfit.currency, tint: report.operatingProfit >= 0 ? GameTheme.teal : GameTheme.danger)
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
                            SectionTitle(title: "今月のニュース")
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
            .navigationTitle("月次レポート")
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
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: game.cash < 0 ? "building.2.crop.circle" : "trophy.circle.fill").font(.system(size: 72)).foregroundStyle(game.cash < 0 ? GameTheme.orange : GameTheme.teal)
            Text(game.cash < 0 ? "資金が尽きました" : "10年間の経営完了").font(.largeTitle.bold())
            Text(game.cash < 0 ? "在庫、価格、立地、固定費を見直して再挑戦しましょう。" : "最終企業価値は \(game.companyValue.currency) です。").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("新しい会社で再挑戦") { dismiss(); game.resetGame() }.buttonStyle(.borderedProminent).tint(GameTheme.teal)
        }
        .padding(28)
        .interactiveDismissDisabled()
    }
}
