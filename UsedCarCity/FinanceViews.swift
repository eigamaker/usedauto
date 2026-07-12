import SwiftUI

struct FinanceView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var statement = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    HStack {
                        MetricView(title: "企業価値", value: game.companyValue.currency, detail: "10年後の評価対象", tint: GameTheme.teal)
                        MetricView(title: "現金", value: game.cash.currency)
                        MetricView(title: "借入金", value: game.debt.currency)
                    }
                    .gameCard()
                    Picker("財務諸表", selection: $statement) {
                        Text("PL").tag(0); Text("BS").tag(1); Text("CF").tag(2)
                    }
                    .pickerStyle(.segmented)
                    if statement == 0 { ProfitLossCard() }
                    if statement == 1 { BalanceSheetCard() }
                    if statement == 2 { CashFlowCard() }
                    FinancingCard()
                    StorePLComparison()
                }
                .padding(14)
            }
            .background(GameTheme.cream)
            .navigationTitle("財務")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct FinanceRow: View {
    let title: String
    let value: Int
    var total = false
    var negative = false
    var body: some View {
        HStack {
            Text(title).font(total ? .headline : .subheadline)
            Spacer()
            Text(value.currency).font((total ? Font.headline : Font.subheadline).monospacedDigit()).foregroundStyle(negative ? GameTheme.danger : GameTheme.ink)
        }
        .padding(.vertical, total ? 8 : 3)
        .overlay(alignment: .top) { if total { Divider() } }
    }
}

private struct ProfitLossCard: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "損益計算書（当月）", subtitle: "店舗がどれだけ利益を生んだか")
            FinanceRow(title: "売上高", value: game.finance.revenue)
            FinanceRow(title: "売上原価", value: -game.finance.costOfSales, negative: true)
            FinanceRow(title: "売上総利益", value: game.finance.revenue - game.finance.costOfSales, total: true)
            FinanceRow(title: "人件費", value: -game.finance.personnel, negative: true)
            FinanceRow(title: "賃料", value: -game.finance.rent, negative: true)
            FinanceRow(title: "広告費", value: -game.finance.advertising, negative: true)
            FinanceRow(title: "減価償却", value: -game.finance.depreciation, negative: true)
            FinanceRow(title: "営業利益", value: game.finance.operatingProfit, total: true, negative: game.finance.operatingProfit < 0)
        }
        .gameCard()
    }
}

private struct BalanceSheetCard: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "貸借対照表", subtitle: "会社が持つ資産と調達した資金")
            FinanceRow(title: "現金", value: game.cash)
            FinanceRow(title: "車両在庫", value: game.finance.inventoryAssets)
            FinanceRow(title: "土地", value: game.finance.landAssets)
            FinanceRow(title: "建物・設備", value: game.finance.buildingAssets)
            FinanceRow(title: "資産合計", value: game.cash + game.finance.inventoryAssets + game.finance.landAssets + game.finance.buildingAssets, total: true)
            FinanceRow(title: "借入金", value: game.debt)
            FinanceRow(title: "純資産（概算）", value: game.cash + game.finance.inventoryAssets + game.finance.landAssets + game.finance.buildingAssets - game.debt, total: true)
        }
        .gameCard()
    }
}

private struct CashFlowCard: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "キャッシュフロー計算書", subtitle: "現金がどこから入り、どこへ出たか")
            FinanceRow(title: "営業CF", value: game.finance.operatingCF, negative: game.finance.operatingCF < 0)
            FinanceRow(title: "投資CF", value: game.finance.investingCF, negative: game.finance.investingCF < 0)
            FinanceRow(title: "財務CF", value: game.finance.financingCF, negative: game.finance.financingCF < 0)
            FinanceRow(title: "現金増減", value: game.finance.operatingCF + game.finance.investingCF + game.finance.financingCF, total: true, negative: game.finance.operatingCF + game.finance.investingCF + game.finance.financingCF < 0)
        }
        .gameCard()
    }
}

private struct FinancingCard: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "銀行取引", subtitle: "土地担保で融資枠が拡大")
            HStack { MetricView(title: "借入残高", value: game.debt.currency); MetricView(title: "融資上限", value: game.borrowingLimit.currency) }
            ProgressView(value: Double(game.debt), total: Double(max(1, game.borrowingLimit))).tint(GameTheme.orange)
            HStack {
                Button("1,000万円借入") { game.borrow(1_000) }.buttonStyle(.borderedProminent).tint(GameTheme.teal).disabled(game.debt + 1_000 > game.borrowingLimit)
                Button("1,000万円返済") { game.repay(1_000) }.buttonStyle(.bordered).tint(GameTheme.navy).disabled(game.debt == 0 || game.cash < 1_000)
            }
        }
        .gameCard()
    }
}

private struct StorePLComparison: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "店舗別PL", subtitle: "継続・改装・撤退の判断材料")
            ForEach(game.stores) { store in
                HStack {
                    VStack(alignment: .leading, spacing: 2) { Text(store.name).font(.subheadline.bold()); Text("売上 \(store.lastRevenue.currency) / \(store.lastSales)台").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(store.lastProfit.currency).font(.subheadline.bold().monospacedDigit()).foregroundStyle(store.lastProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                }
                .padding(.vertical, 4)
            }
        }
        .gameCard()
    }
}

