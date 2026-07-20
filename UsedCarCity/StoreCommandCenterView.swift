import SwiftUI
import Charts

struct StoreCommandCenterView: View {
    @EnvironmentObject private var game: GameEngine
    let storeID: UUID
    @State private var panel: StorePanel = CommandLine.arguments.contains("-demo-team") ? .team : CommandLine.arguments.contains("-demo-catalog") ? .market : .store
    @State private var showSettings = false
    @State private var actionMessage: String?

    private var store: Store? { game.stores.first(where: { $0.id == storeID }) }
    private var plot: LandPlot? { store.flatMap { game.plot(id: $0.plotID) } }

    var body: some View {
        if let store, let plot {
            VStack(spacing: 14) {
                if let step = game.tutorialStep,
                   step == .purchaseInventory || step == .runFirstMonth {
                    TutorialCoachCard(step: step)
                }
                StoreSceneHeader(store: store, plot: plot, managerName: managerName)
                if store.isOperational {
                    if game.tutorialStep == .purchaseInventory {
                        FoundingInventoryTutorialPanel(store: store, plot: plot)
                    }
                    StorePanelPicker(selection: $panel)
                    Group {
                        switch panel {
                        case .store:
                            VStack(spacing: 14) {
                                WeeklyOpportunityPanel(store: store)
                                PurchaseCasesPanel(storeID: store.id)
                                ManualSalesPanel(store: store)
                                StoreInventoryPanel(store: store)
                                StoreOverviewPanel(store: store, plot: plot)
                            }
                        case .team: ManagerPanel(store: store, update: update)
                        case .market: MarketPanel(store: store, plot: plot, campaign: runCampaign)
                        case .finance: StoreFinancePanel(store: store, update: update)
                        }
                    }
                    StoreActionDock(
                        settings: { showSettings = true },
                        advertise: { runCampaign(amount: 40, message: "地域広告を強化しました") }
                    )
                } else {
                    StoreConstructionPanel(store: store, plot: plot) { showSettings = true }
                }
            }
            .sheet(isPresented: $showSettings) { StoreSettingsView(storeID: storeID) }
            .alert("アクション結果", isPresented: Binding(get: { actionMessage != nil }, set: { if !$0 { actionMessage = nil } })) {
                Button("OK") { actionMessage = nil }
            } message: { Text(actionMessage ?? "") }
        }
    }

    private var managerName: String {
        store?.manager?.name ?? "未採用"
    }

    private func update(_ changed: Store) { game.updateStore(changed) }

    private func runCampaign(amount: Int, message: String) {
        guard let current = store,
              game.increaseAdvertisingBudget(for: current.id, by: amount),
              let updated = game.stores.first(where: { $0.id == current.id }) else { return }
        actionMessage = "\(message)。広告予算は月\(updated.advertising.currency)です。"
    }

}

private struct WeeklyOpportunityPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store

    private var capacity: Int { game.weeklyOpportunityCapacity(storeID: store.id) }
    private var remaining: Int { game.remainingWeeklyOpportunities(storeID: store.id) }
    private var waitingBuyers: Int { game.buyerLeads(for: store.id).count }
    private var waitingSellers: Int { game.purchaseCases.filter { $0.storeID == store.id }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "今週の客足と営業枠", subtitle: "来店数と対応できる回数は別々に決まります")
            HStack {
                MetricView(title: "販売客", value: "\(store.buyerArrivalsThisWeek)人", detail: "未対応 \(waitingBuyers)人")
                MetricView(title: "買取客", value: "\(store.sellerArrivalsThisWeek)人", detail: "未対応 \(waitingSellers)人")
                MetricView(title: "営業枠", value: "\(store.usedOpportunitiesThisWeek)/\(capacity)", detail: "残り \(remaining)回", tint: remaining > 0 ? GameTheme.teal : GameTheme.orange)
            }
            ProgressView(value: Double(store.usedOpportunitiesThisWeek), total: Double(max(1, capacity)))
                .tint(remaining > 0 ? GameTheme.teal : GameTheme.orange)
            if store.buyerArrivalsThisWeek + store.sellerArrivalsThisWeek == 0 {
                Label("今週は来店がありません。営業枠が余っていても商談はできません。", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.caption).foregroundStyle(GameTheme.orange)
            }
            VStack(spacing: 7) {
                ForEach(game.customerTrafficFactors(for: store)) { factor in
                    HStack {
                        Image(systemName: factor.effect >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            .foregroundStyle(factor.effect >= 0 ? GameTheme.teal : GameTheme.orange)
                        Text(factor.title).font(.caption)
                        Spacer()
                        Text(String(format: "%+.1f", factor.effect))
                            .font(.caption.bold().monospacedDigit())
                    }
                }
            }
            Text("広告は地域全体の購入者を増やすのではなく、競合より自店が選ばれる確率を高めます。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .gameCard()
    }
}

private struct FoundingInventoryTutorialPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let plot: LandPlot

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionTitle(title: "最初の3台を選ぶ", subtitle: "\(plot.district.name)で需要の高い順")
            ForEach(Array(game.recommendedCategories(for: plot.district).prefix(3).enumerated()), id: \.element) { rank, category in
                let purchaseCost = game.inventoryPurchaseCost(category: category, count: 3, storeID: store.id)
                    ?? category.purchaseCost * 3
                HStack(spacing: 10) {
                    Text("\(rank + 1)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 25, height: 25)
                        .background(rank == 0 ? GameTheme.orange : GameTheme.navy.opacity(0.72))
                        .clipShape(Circle())
                    Image(systemName: category.icon).foregroundStyle(GameTheme.teal).frame(width: 25)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name).font(.subheadline.bold())
                        Text("地域需要 \(Int(game.vehicleDemand(category, in: plot.district) * 100)) / 3台の卸見積 \(purchaseCost.currency)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("3台仕入") {
                        _ = game.buyInventory(category: category, count: 3, storeID: store.id)
                    }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.teal)
                    .disabled(game.cash < purchaseCost)
                }
            }
            Label("3台は個別在庫になり、商談・移動・出品は1台ずつ行います。", systemImage: "info.circle.fill")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .gameCard()
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(GameTheme.orange, lineWidth: 2)
        }
    }
}

private struct StoreConstructionPanel: View {
    let store: Store
    let plot: LandPlot
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "開店準備中", subtitle: "建設が完了すると販売と買取を開始します")
            ProgressView(value: progress)
                .tint(GameTheme.orange)
            HStack {
                MetricView(title: "完成まで", value: "\(remaining)週間", tint: GameTheme.orange)
                MetricView(title: "店舗タイプ", value: store.type.name, tint: GameTheme.teal)
            }
            Label("開店前に設備と人員を確認できます。価格・広告方針はオーナーが直接設定できます。", systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: openSettings) {
                Label("店舗・設備を確認", systemImage: "wrench.and.screwdriver.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(GameTheme.teal)
        }
        .gameCard()
    }

    private var remaining: Int { store.openingMonthsRemaining ?? 0 }
    private var progress: Double {
        let total = max(1, store.type.constructionMonths)
        return min(1, max(0, Double(total - remaining) / Double(total)))
    }
}

private struct PurchaseCasesPanel: View {
    @EnvironmentObject private var game: GameEngine
    let storeID: UUID
    @State private var message: String?
    private var cases: [PurchaseCase] { game.purchaseCases.filter { $0.storeID == storeID } }
    private var store: Store? { game.stores.first(where: { $0.id == storeID }) }
    private var isDelegated: Bool { store?.hasManager == true && store?.delegateProcurement == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(
                    title: "今週の買取客",
                    subtitle: isDelegated ? "店長が週間処理で査定・価格交渉します" : "店舗買取は来店数が限られる一方、成約率が高く、手数料・輸送待ちはありません"
                )
                if !cases.isEmpty { Text("\(cases.count)件").font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 5).background(GameTheme.orange).clipShape(Capsule()) }
            }
            if cases.isEmpty {
                Label("現在、未処理の買取案件はありません", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(GameTheme.teal).padding(.vertical, 12)
            } else {
                ForEach(cases) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: item.category.icon).font(.title3).foregroundStyle(GameTheme.teal).frame(width: 40, height: 40).background(GameTheme.teal.opacity(0.1)).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) { Text(item.vehicleName).font(.subheadline.bold()); Text("\(item.category.name)・\(String(item.modelYear))年式・走行 \(item.mileage.formatted())km・状態 \(item.conditionScore)").font(.caption).foregroundStyle(.secondary) }
                            Spacer(); VStack(alignment: .trailing) { Text("希望 \(item.askingPrice.currency)").font(.caption.bold()); Text("粗利予測 \(item.expectedGrossProfit.currency)").font(.caption2).foregroundStyle(item.expectedGrossProfit >= 0 ? GameTheme.teal : GameTheme.danger) }
                        }
                        if item.lotCount > 1 {
                            Label("法人放出 \(item.lotCount)台一括・表示価格と整備費は1台あたり", systemImage: "building.2.fill")
                                .font(.caption2.bold()).foregroundStyle(GameTheme.orange)
                        }
                        HStack { PurchaseMetric(title: "整備 +\(item.repairQualityGain)", value: item.repairCost.currency); PurchaseMetric(title: "整備後品質", value: "\(item.qualityAfterRepairScore)/100"); PurchaseMetric(title: "販売予測", value: item.expectedSaleAfterAppraisal.currency); PurchaseMetric(title: "査定精度", value: "\(item.appraisalAccuracy)%") }
                        if let issue = item.revealedIssue {
                            Label("要告知：\(issue.name) — \(issue.detail)。販売相場を\(Int(issue.disclosedValueFactor * 100))%で再計算済みです。", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(GameTheme.danger)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(GameTheme.danger.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("未発見の修復歴・走行距離不正が残る可能性があります", systemImage: "magnifyingglass")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Text("成約時に買取額と整備費を現金から支払い、整備後の品質で即日在庫になります。")
                            .font(.caption2).foregroundStyle(.secondary)
                        if item.negotiations > 0 {
                            Label("交渉 \(item.negotiations)回・次に断られると売主が帰る可能性があります", systemImage: "exclamationmark.bubble.fill")
                                .font(.caption2)
                                .foregroundStyle(GameTheme.orange)
                        }
                        HStack(spacing: 6) {
                            Menu {
                                purchaseOfferButton(item, percent: 100, title: "希望額で提示")
                                purchaseOfferButton(item, percent: 94, title: "6%値下げを交渉")
                                purchaseOfferButton(item, percent: 88, title: "12%値下げを交渉")
                            } label: {
                                Label("価格を提示", systemImage: "bubble.left.and.bubble.right.fill")
                                    .font(.caption2.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(GameTheme.orange)
                            .disabled(!game.canNegotiatePurchaseCase(item.id))
                            CaseActionButton("詳細検査 10万円", color: .blue) {
                                switch game.inspectPurchaseCase(item.id) {
                                case .issueFound(let issue): message = "詳細検査で「\(issue.name)」を発見しました。告知前提の販売相場へ更新しました。"
                                case .noIssueDetected: message = "詳細検査が完了しました。問題は発見されず、査定精度は96%になりました。"
                                case .unavailable: message = "検査済み、または検査費用が不足しています。"
                                }
                            }
                                .disabled(isDelegated || item.appraisalAccuracy >= 96 || game.cash < 10)
                            Button(role: .destructive) { game.declinePurchaseCase(item.id) } label: { Image(systemName: "xmark").font(.caption.bold()).padding(8) }.buttonStyle(.bordered)
                                .disabled(isDelegated)
                        }
                        if isDelegated {
                            Label("この案件は店長へ委任中です", systemImage: "person.crop.circle.badge.checkmark")
                                .font(.caption2).foregroundStyle(GameTheme.teal)
                        } else if !game.canNegotiatePurchaseCase(item.id) {
                            Label("今週の営業枠を使い切っています", systemImage: "clock.badge.exclamationmark")
                                .font(.caption2).foregroundStyle(GameTheme.orange)
                        }
                    }
                    .padding(11).background(GameTheme.cream).clipShape(RoundedRectangle(cornerRadius: 13))
                }
            }
        }
        .gameCard()
        .alert("買取結果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }

    @ViewBuilder
    private func purchaseOfferButton(_ item: PurchaseCase, percent: Int, title: String) -> some View {
        if let preview = game.purchaseNegotiationPreview(item.id, offerPercent: percent) {
            Button("\(title)・\(preview.price.currency)（見込\(Int(preview.closeChance * 100))%）") {
                switch game.negotiatePurchaseCase(item.id, offerPercent: percent) {
                case let .purchased(price):
                    message = item.revealedIssue == nil
                        ? "\(item.lotCount)台を合計\(price.currency)で買取成立しました。整備費を含めて在庫へ追加しました。"
                        : "\(item.lotCount)台を合計\(price.currency)で買取成立しました。\(item.revealedIssue?.name ?? "問題歴")を告知する在庫として追加しました。"
                case let .rejected(walkedAway):
                    message = walkedAway
                        ? "提示を断られ、売主は帰りました。"
                        : "提示を断られました。条件を変えてもう一度だけ交渉できます。"
                case .unavailable:
                    message = game.remainingWeeklyOpportunities(storeID: item.storeID) == 0
                        ? "今週の営業枠を使い切っています。"
                        : "現金または展示スペースが不足しています。"
                }
            }
        }
    }
}

private struct PurchaseMetric: View {
    let title: String; let value: String
    var body: some View { VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 8)).foregroundStyle(.secondary); Text(value).font(.caption2.bold().monospacedDigit()) }.frame(maxWidth: .infinity, alignment: .leading) }
}

private struct ManualSalesPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    @State private var message: String?
    @State private var selectedLead: BuyerLead?

    private var isDelegated: Bool { store.hasManager && store.delegatePricing }
    private var leads: [BuyerLead] { game.buyerLeads(for: store.id) }
    private var capacity: Int { game.weeklyOpportunityCapacity(storeID: store.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "今週の販売客", subtitle: isDelegated ? "店長が来店客へ在庫を提案" : "顧客の希望に合う在庫車を提案")
                Spacer()
                Text("営業枠 \(store.usedOpportunitiesThisWeek)/\(capacity)・成約 \(store.manualSalesThisWeek)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(GameTheme.teal)
            }

            if isDelegated {
                Label("未対応の販売客は次の週間処理で店長が対応します。車種または予算の希望に合う在庫から提案します。", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else if leads.isEmpty {
                Label("今週は対応できる販売客がいません。広告・評判・立地・在庫構成が次週以降の来店に影響します。", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else if store.inventoryCount == 0 {
                Label("販売できる在庫がありません", systemImage: "car.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                ForEach(leads) { lead in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 11) {
                            Image(systemName: lead.preference.icon)
                            .foregroundStyle(GameTheme.teal)
                            .frame(width: 34, height: 34)
                            .background(GameTheme.teal.opacity(0.1))
                            .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lead.preference.customerDescription).font(.subheadline.bold())
                                Text("予算 \(lead.budget.currency)・希望品質 \(Int(lead.minimumQuality * 100))以上")
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                if let tradeIn = lead.tradeInVehicle {
                                    Text("下取り希望：\(tradeIn.vehicleName)・査定 \(tradeIn.appraisedValue.currency)")
                                        .font(.caption2.bold()).foregroundStyle(GameTheme.teal)
                                }
                            }
                            Spacer(minLength: 4)
                            Button {
                                selectedLead = lead
                            } label: {
                                Label("車を提案", systemImage: "bubble.left.and.bubble.right.fill")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(GameTheme.orange)
                            .disabled(!game.canSellManually(storeID: store.id))
                        }
                        let matching = fittingInventoryCount(for: lead)
                        Label(matching > 0 ? "希望条件に合う在庫 \(matching)台" : noMatchingInventoryMessage(for: lead), systemImage: matching > 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(matching > 0 ? GameTheme.teal : GameTheme.orange)
                    }
                    .padding(10)
                    .background(GameTheme.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Text("商談すると成否に関係なく営業枠を1回使い、このお客様は帰ります。値引き・予算・希望条件・品質で成約率が変わります。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .gameCard()
        .overlay {
            if game.tutorialStep == .runFirstMonth {
                RoundedRectangle(cornerRadius: 18).stroke(GameTheme.orange, lineWidth: 2)
            }
        }
        .sheet(item: $selectedLead) { lead in
            VehicleProposalSheet(storeID: store.id, lead: lead) { inventoryID, strategy, acceptTradeIn in
                negotiate(leadID: lead.id, inventoryID: inventoryID, strategy: strategy, acceptTradeIn: acceptTradeIn)
            }
        }
        .onAppear {
#if DEBUG
            if CommandLine.arguments.contains("-demo-proposal"), selectedLead == nil {
                selectedLead = leads.first
            }
#endif
        }
        .alert("販売結果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func negotiate(leadID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy, acceptTradeIn: Bool) {
        let vehicleName = store.inventory.first(where: { $0.id == inventoryID })?.vehicleName ?? "車両"
        guard let result = game.negotiateManualSale(storeID: store.id, buyerLeadID: leadID, inventoryID: inventoryID, strategy: strategy, acceptTradeIn: acceptTradeIn) else {
            message = acceptTradeIn ? "下取り差額の支払い資金、営業枠、または在庫を確認してください。" : "今週の営業枠に達したか、お客様または在庫がありません。"
            return
        }
        if result.succeeded {
            if result.tradeInAcquired {
                let settlement = result.customerCashSettlement >= 0
                    ? "お客様の差額支払い \(result.customerCashSettlement.currency)"
                    : "店舗からの差額支払い \((-result.customerCashSettlement).currency)"
                message = "交渉成立。\(vehicleName)を\(result.salePrice.currency)で販売。\(result.tradeInVehicleName ?? "下取り車")を\(result.tradeInAllowance.currency)で査定し、整備費\(result.tradeInRepairCost.currency)を含めて在庫化しました（\(settlement)）。"
            } else {
                message = "交渉成立。\(vehicleName)を\(result.salePrice.currency)で販売し、粗利は\(result.grossProfit.currency)でした。"
            }
        } else {
            message = "価格条件が合わず、お客様は購入を見送りました。在庫は残っています。"
        }
    }

    private func fittingInventoryCount(for lead: BuyerLead) -> Int {
        store.inventory.filter { batch in
            guard batch.count > 0, !batch.isInWorkshop else { return false }
            switch lead.preference {
            case .category(let category):
                return batch.category == category
            case .budgetFirst:
                return (game.manualSaleQuote(storeID: store.id, inventoryID: batch.id)?.price ?? Int.max) <= lead.budget
            }
        }.reduce(0) { $0 + $1.count }
    }

    private func noMatchingInventoryMessage(for lead: BuyerLead) -> String {
        switch lead.preference {
        case .category: "希望車種なし・代替提案は成約率が大幅に下がります"
        case .budgetFirst: "予算内の在庫なし・値引きか仕入れ構成の見直しが必要です"
        }
    }
}

private struct VehicleProposalSheet: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let storeID: UUID
    let lead: BuyerLead
    let negotiate: (UUID, SaleNegotiationStrategy, Bool) -> Void
    @State private var selectedInventoryID: UUID?
    @State private var acceptTradeIn = false

    private var store: Store? { game.stores.first(where: { $0.id == storeID }) }
    private var inventory: [InventoryBatch] {
        guard let store else { return [] }
        return store.inventory.filter { $0.count > 0 && !$0.isInWorkshop }.sorted {
            let leftMatches = proposalFits($0)
            let rightMatches = proposalFits($1)
            if leftMatches != rightMatches { return leftMatches }
            if lead.preference == .budgetFirst {
                return proposalPrice($0) < proposalPrice($1)
            }
            if $0.quality != $1.quality { return $0.quality > $1.quality }
            return $0.averageCost < $1.averageCost
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "提案する在庫車を選ぶ", subtitle: "車を選んだ後に値引き条件と提示価格が表示されます")
                        HStack {
                            MetricView(title: "希望条件", value: lead.preference.name, tint: GameTheme.teal)
                            MetricView(title: "予算", value: lead.budget.currency)
                            MetricView(title: "希望品質", value: "\(Int(lead.minimumQuality * 100))以上")
                        }
                    }
                    .gameCard()

                    if let tradeIn = lead.tradeInVehicle {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("下取り車 \(tradeIn.vehicleName)").font(.subheadline.bold())
                                    Text("\(String(tradeIn.modelYear))年式・\(tradeIn.mileage.formatted())km・品質\(tradeIn.conditionScore)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("査定 \(tradeIn.appraisedValue.currency)")
                                    .font(.subheadline.bold().monospacedDigit()).foregroundStyle(GameTheme.teal)
                            }
                            HStack {
                                ProposalMetric(title: "商品化整備", value: tradeIn.repairCost.currency)
                                ProposalMetric(title: "整備後品質", value: "\(Int((tradeIn.qualityAfterRepair * 100).rounded()))/100")
                                ProposalMetric(title: "下取り効果", value: "成約率を改善")
                            }
                            Toggle("下取り込みで商談する", isOn: $acceptTradeIn)
                                .font(.subheadline.bold()).tint(GameTheme.teal)
                        }
                        .gameCard()
                    }

                    ForEach(inventory) { batch in
                        VStack(alignment: .leading, spacing: 11) {
                            HStack(spacing: 11) {
                                Image(systemName: batch.category.icon)
                                    .font(.title3)
                                    .foregroundStyle(proposalTint(batch))
                                    .frame(width: 42, height: 42)
                                    .background(proposalTint(batch).opacity(0.11))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(batch.vehicleName).font(.headline)
                                    Text("\(batch.category.name)・在庫番号 #\(batch.id.uuidString.prefix(4).uppercased())")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if proposalFits(batch) {
                                    Text(lead.preference == .budgetFirst ? "予算内" : "希望一致").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 5).background(GameTheme.teal).clipShape(Capsule())
                                }
                            }

                            HStack {
                                ProposalMetric(title: "車両品質", value: "\(Int(batch.quality * 100))/100")
                                ProposalMetric(title: "在庫期間", value: game.inventoryAgeLabel(for: batch))
                                ProposalMetric(title: "現在の売価", value: proposalPrice(batch).currency)
                            }

                            if selectedInventoryID == batch.id {
                                Divider()
                                Text("値引き条件を選ぶ").font(.caption.bold()).foregroundStyle(.secondary)
                                ForEach(SaleNegotiationStrategy.allCases) { strategy in
                                    if let preview = game.saleNegotiationPreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: batch.id, strategy: strategy) {
                                        let tradePreview = acceptTradeIn ? game.tradeInSalePreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: batch.id, strategy: strategy) : nil
                                        Button {
                                            negotiate(batch.id, strategy, acceptTradeIn)
                                            dismiss()
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(strategy.name).font(.subheadline.bold())
                                                    Text(acceptTradeIn ? tradeInSettlementLabel(tradePreview) : strategy.detail).font(.caption2).foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text(acceptTradeIn ? "車両価格 \(preview.price.currency)" : preview.price.currency).font(.subheadline.bold().monospacedDigit())
                                                    Text("成約見込 \(Int((tradePreview?.closeChance ?? preview.closeChance) * 100))%")
                                                        .font(.caption2.bold()).foregroundStyle(GameTheme.teal)
                                                }
                                            }
                                            .padding(10)
                                            .background(GameTheme.cream)
                                            .clipShape(RoundedRectangle(cornerRadius: 11))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(acceptTradeIn && (tradePreview == nil || game.cash < (tradePreview?.requiredDealerCash ?? 0)))
                                    }
                                }
                            } else {
                                Button("この車を提案候補にする") {
                                    withAnimation(.easeInOut(duration: 0.2)) { selectedInventoryID = batch.id }
                                }
                                .font(.caption.bold())
                                .buttonStyle(.borderedProminent)
                                .tint(proposalTint(batch))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .gameCard()
                    }
                }
                .padding(14)
            }
            .background(GameTheme.cream)
            .navigationTitle("車両提案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }

    private func proposalPrice(_ batch: InventoryBatch) -> Int {
        game.manualSaleQuote(storeID: storeID, inventoryID: batch.id)?.price ?? Int.max
    }

    private func proposalFits(_ batch: InventoryBatch) -> Bool {
        switch lead.preference {
        case .category(let category): batch.category == category
        case .budgetFirst: proposalPrice(batch) <= lead.budget
        }
    }

    private func proposalTint(_ batch: InventoryBatch) -> Color {
        proposalFits(batch) ? GameTheme.teal : GameTheme.orange
    }

    private func tradeInSettlementLabel(_ preview: TradeInSalePreview?) -> String {
        guard let preview else { return "下取り条件を計算できません" }
        if preview.customerCashSettlement >= 0 {
            return "下取り\(preview.allowance.currency)・お客様差額\(preview.customerCashSettlement.currency)・下取粗利見込\(preview.expectedTradeInGrossProfit.currency)"
        }
        return "下取り\(preview.allowance.currency)・店舗支払\((-preview.customerCashSettlement).currency)・下取粗利見込\(preview.expectedTradeInGrossProfit.currency)"
    }
}

private struct ProposalMetric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StoreInventoryPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    @State private var showAll = false
    @State private var message: String?

    private var sortedInventory: [InventoryBatch] {
        store.inventory.filter { $0.count > 0 }.sorted {
            if $0.category != $1.category { return $0.category.name < $1.category.name }
            return $0.vehicleName < $1.vehicleName
        }
    }

    private var visibleInventory: [InventoryBatch] {
        showAll ? sortedInventory : Array(sortedInventory.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionTitle(title: "店舗在庫一覧", subtitle: "\(store.inventoryCount)台・平均在庫 \(String(format: "%.1f週", game.averageInventoryWeeks(storeID: store.id)))")
            if sortedInventory.isEmpty {
                Label("販売できる在庫がありません", systemImage: "car.circle")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                ForEach(visibleInventory) { batch in
                    HStack(spacing: 10) {
                        Image(systemName: batch.category.icon)
                            .foregroundStyle(GameTheme.teal)
                            .frame(width: 34, height: 34)
                            .background(GameTheme.teal.opacity(0.10))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(batch.vehicleName).font(.subheadline.bold())
                            Text("\(batch.category.name)・\(String(batch.modelYear))年式・\(batch.mileage.formatted())km・品質 \(Int((batch.quality * 100).rounded()))/100")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            HStack(spacing: 5) {
                                if batch.isRareClassic {
                                    Text("希少旧車").foregroundStyle(GameTheme.orange)
                                }
                                if batch.productState != .stock {
                                    Text(batch.productState.name).foregroundStyle(.purple)
                                }
                                if let issue = batch.disclosedIssue {
                                    Text("告知：\(issue.name)").foregroundStyle(GameTheme.danger)
                                }
                                Text(game.specialtyDemandDescription(for: batch, in: game.plot(id: store.plotID)?.district ?? .suburb))
                            }
                            .font(.caption2.bold())
                            Text("簿価 \(batch.averageCost.currency)・販売目安 \((game.manualSaleQuote(storeID: store.id, inventoryID: batch.id)?.price ?? 0).currency)")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("#\(batch.id.uuidString.prefix(4).uppercased())")
                                .font(.caption2.bold().monospaced()).foregroundStyle(.secondary)
                            Text(game.inventoryAgeLabel(for: batch))
                                .font(.caption2.bold())
                                .foregroundStyle(ageTint(for: batch))
                            if let project = batch.workshopProject {
                                Label("\(project.kind.name) あと\(project.remainingWeeks)週", systemImage: project.kind.icon)
                                    .font(.caption2.bold()).foregroundStyle(.purple)
                            } else if let preview = game.servicePreview(storeID: store.id, inventoryID: batch.id) {
                                Button("整備 +\(preview.qualityGain)・\(preview.cost.currency)") {
                                    message = game.serviceInventory(storeID: store.id, inventoryID: batch.id)
                                        ? "整備費\(preview.cost.currency)を支払い、品質が\(preview.resultingQuality)/100になりました。"
                                        : "整備を実行できませんでした。"
                                }
                                .font(.caption2.bold()).buttonStyle(.bordered).tint(GameTheme.teal)
                                .disabled(game.cash < preview.cost)
                            } else {
                                Text("整備上限").font(.caption2.bold()).foregroundStyle(GameTheme.teal)
                            }
                        }
                    }
                    if batch.id != visibleInventory.last?.id { Divider() }
                }
                if sortedInventory.count > 5 {
                    Button(showAll ? "5台だけ表示" : "全\(sortedInventory.count)台を表示") {
                        withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() }
                    }
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .gameCard()
        .alert("在庫整備", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }

    private func ageTint(for batch: InventoryBatch) -> Color {
        let weeks = game.inventoryAgeWeeks(for: batch)
        return weeks <= 2 ? GameTheme.teal : weeks <= 12 ? GameTheme.navy : weeks <= 25 ? GameTheme.orange : GameTheme.danger
    }
}

private struct CaseActionButton: View {
    let title: String; let color: Color; let action: () -> Void
    init(_ title: String, color: Color, action: @escaping () -> Void) { self.title = title; self.color = color; self.action = action }
    var body: some View { Button(title, action: action).font(.caption2.bold()).buttonStyle(.borderedProminent).tint(color) }
}

private enum StorePanel: String, CaseIterable, Identifiable {
    case store, team, market, finance
    var id: String { rawValue }
    var title: String {
        switch self { case .store: "店舗"; case .team: "店員"; case .market: "市場"; case .finance: "経営" }
    }
    var icon: String {
        switch self { case .store: "storefront.fill"; case .team: "person.3.fill"; case .market: "chart.pie.fill"; case .finance: "chart.line.uptrend.xyaxis" }
    }
}

private struct StorePanelPicker: View {
    @Binding var selection: StorePanel

    var body: some View {
        HStack(spacing: 5) {
            ForEach(StorePanel.allCases) { item in
                Button { withAnimation(.easeInOut(duration: 0.2)) { selection = item } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon).font(.subheadline)
                        Text(item.title).font(.caption2.bold())
                    }
                    .foregroundStyle(selection == item ? .white : GameTheme.navy.opacity(0.65))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(selection == item ? GameTheme.navy : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5).background(GameTheme.navy.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

private struct StoreSceneHeader: View {
    let store: Store
    let plot: LandPlot
    let managerName: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.name).font(.title3.bold()).foregroundStyle(.white)
                    Text("\(plot.district.name)・\(plot.localNumber)番区画・\(store.type.name)").font(.caption).foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                CapsuleLabel(text: store.concept.name, color: GameTheme.mint, icon: store.concept.icon)
            }
            .padding(15).background(GameTheme.ink)
            ZStack(alignment: .top) {
                StoreScene(store: store)
                    .frame(height: 258)
                HStack(spacing: 9) {
                    Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(GameTheme.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.hasManager ? "店長 \(managerName)" : "オーナー直営").font(.caption.bold()).foregroundStyle(.white.opacity(0.7))
                        Text(greeting).font(.subheadline.bold()).foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(11).background(.black.opacity(0.66))
                StoreSceneStatusOverlay(store: store)
            }
            HStack {
                MetricView(title: "今週来店", value: "\(store.buyerArrivalsThisWeek + store.sellerArrivalsThisWeek)人", tint: .white)
                MetricView(title: "販売", value: "\(store.lastSales)台", tint: .white)
                MetricView(title: "満足度", value: "\(store.satisfaction)", tint: .white)
                MetricView(title: "営業利益", value: store.lastProfit.currency, tint: store.lastProfit >= 0 ? GameTheme.mint : .red)
            }
            .padding(13).background(GameTheme.navy)
        }
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .shadow(color: GameTheme.ink.opacity(0.20), radius: 12, y: 5)
    }

    private var greeting: String {
        if let remaining = store.openingMonthsRemaining { return "建設中です。あと\(remaining)週間で開店予定です" }
        if let remaining = store.renovationMonthsRemaining { return "営業を続けながら改装中。あと\(remaining)週間です" }
        if store.inventoryCount < 5 { return "在庫が少なく、販売機会を逃しています" }
        if store.lastProfit < 0 { return "今週は赤字です。価格と広告を見直しましょう" }
        if store.satisfaction >= 80 { return "口コミが好調です。この流れを維持しましょう" }
        return store.hasManager ? "今週もお客様の動きを確認していきましょう" : "仕入れと販売はオーナーが操作します"
    }

}

private struct StoreScene: View {
    let store: Store

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                StoreSceneBackdrop(type: store.type)
                StoreSceneBuilding(type: store.type, inventoryCount: store.inventoryCount)
                StoreAccessOverlay(type: store.type)
                StoreTrafficAnimation(store: store)
            }
            .clipped()
        }
    }
}

private struct StoreSceneBuilding: View {
    let type: StoreType
    let inventoryCount: Int

    var body: some View {
        Canvas { context, size in
            let building = scaled(type.sceneBuildingRect, in: size)
            let entrance = normalized(type.sceneEntrance, in: size)
            let accent = type.sceneAccentColor

            context.fill(
                Path(roundedRect: building.offsetBy(dx: 5, dy: 5), cornerRadius: 5),
                with: .color(GameTheme.ink.opacity(0.20))
            )
            context.fill(Path(roundedRect: building, cornerRadius: 5), with: .color(Color(red: 0.91, green: 0.93, blue: 0.90)))
            context.stroke(Path(roundedRect: building, cornerRadius: 5), with: .color(.white.opacity(0.92)), lineWidth: 2)

            let roof = CGRect(x: building.minX - 4, y: building.minY - 5, width: building.width + 8, height: 16)
            context.fill(Path(roundedRect: roof, cornerRadius: 4), with: .color(accent))
            let sign = CGRect(x: building.midX - min(70, building.width * 0.32), y: building.minY + 16, width: min(140, building.width * 0.64), height: 21)
            context.fill(Path(roundedRect: sign, cornerRadius: 5), with: .color(accent.opacity(0.92)))
            context.draw(Text(type.sceneShortName).font(.system(size: 10, weight: .black)).foregroundStyle(.white), at: CGPoint(x: sign.midX, y: sign.midY))

            let windowCount = type == .small ? 2 : 3
            let windowTop = building.minY + 44
            let windowWidth = min(38, (building.width - 40) / CGFloat(windowCount))
            for index in 0..<windowCount {
                let centerX = building.minX + 22 + CGFloat(index) * (windowWidth + 8)
                let window = CGRect(x: centerX, y: windowTop, width: windowWidth, height: max(18, building.maxY - windowTop - 12))
                context.fill(Path(roundedRect: window, cornerRadius: 3), with: .color(Color.cyan.opacity(0.55)))
                context.stroke(Path(roundedRect: window, cornerRadius: 3), with: .color(accent.opacity(0.72)), lineWidth: 1.4)
            }

            let door = CGRect(x: entrance.x - 10, y: entrance.y - 28, width: 20, height: 28)
            context.fill(Path(roundedRect: door, cornerRadius: 3), with: .color(accent))
            context.fill(Path(roundedRect: door.insetBy(dx: 4, dy: 4), cornerRadius: 2), with: .color(Color.cyan.opacity(0.62)))
            context.fill(Path(ellipseIn: CGRect(x: door.maxX - 6, y: door.midY, width: 3, height: 3)), with: .color(.white))

            drawParkingBays(context: &context, size: size)
            drawFence(context: &context, size: size)
        }
        .allowsHitTesting(false)
    }

    private func drawParkingBays(context: inout GraphicsContext, size: CGSize) {
        let shown = min(4, max(1, inventoryCount))
        let positions: [CGPoint] = [
            .init(x: 0.66, y: 0.57), .init(x: 0.77, y: 0.57),
            .init(x: 0.88, y: 0.57), .init(x: 0.88, y: 0.68)
        ]
        for (index, position) in positions.enumerated() {
            let point = normalized(position, in: size)
            let bay = CGRect(x: point.x - 17, y: point.y - 11, width: 34, height: 22)
            context.stroke(Path(roundedRect: bay, cornerRadius: 2), with: .color(.white.opacity(0.72)), lineWidth: 1.3)
            guard index < shown else { continue }
            let car = bay.insetBy(dx: 5, dy: 4)
            let colors: [Color] = [.cyan, .white, .yellow, .blue]
            context.fill(Path(roundedRect: car, cornerRadius: 5), with: .color(colors[index % colors.count].opacity(0.88)))
            context.fill(Path(roundedRect: car.insetBy(dx: 6, dy: 3), cornerRadius: 2), with: .color(GameTheme.navy.opacity(0.72)))
        }
    }

    private func drawFence(context: inout GraphicsContext, size: CGSize) {
        let y = size.height * 0.71
        let pedestrianX = size.width * type.scenePedestrianGate.x
        let vehicleX = size.width * type.sceneVehicleGate.x
        let gaps = [
            (pedestrianX - 13, pedestrianX + 13),
            (vehicleX - 28, vehicleX + 28)
        ].sorted { $0.0 < $1.0 }
        var cursor = size.width * 0.055
        for gap in gaps {
            if gap.0 > cursor { drawFenceSegment(from: cursor, to: gap.0, y: y, context: &context) }
            drawGatePost(x: gap.0, y: y, context: &context)
            drawGatePost(x: gap.1, y: y, context: &context)
            cursor = max(cursor, gap.1)
        }
        drawFenceSegment(from: cursor, to: size.width * 0.945, y: y, context: &context)
    }

    private func drawFenceSegment(from start: CGFloat, to end: CGFloat, y: CGFloat, context: inout GraphicsContext) {
        guard end > start else { return }
        var path = Path()
        path.move(to: CGPoint(x: start, y: y))
        path.addLine(to: CGPoint(x: end, y: y))
        context.stroke(path, with: .color(type.sceneAccentColor.opacity(0.92)), style: StrokeStyle(lineWidth: 5, lineCap: .square))
        context.stroke(path, with: .color(.white.opacity(0.86)), style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
    }

    private func drawGatePost(x: CGFloat, y: CGFloat, context: inout GraphicsContext) {
        let post = CGRect(x: x - 3, y: y - 8, width: 6, height: 12)
        context.fill(Path(roundedRect: post, cornerRadius: 1), with: .color(.white))
        context.stroke(Path(roundedRect: post, cornerRadius: 1), with: .color(type.sceneAccentColor), lineWidth: 1)
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func scaled(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
    }
}

private struct StoreSceneBackdrop: View {
    let type: StoreType

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(
                Path(bounds),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.50, green: 0.73, blue: 0.86), Color(red: 0.88, green: 0.91, blue: 0.80)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height * 0.78)
                )
            )

            let sun = CGRect(x: size.width * 0.82, y: size.height * 0.12, width: 42, height: 42)
            context.fill(Path(ellipseIn: sun), with: .color(Color.yellow.opacity(0.30)))

            for index in 0..<7 {
                let width = size.width * (0.07 + CGFloat(index % 3) * 0.015)
                let height = size.height * (0.15 + CGFloat((index * 3) % 4) * 0.035)
                let x = CGFloat(index) * size.width / 6.2 - width * 0.2
                let rect = CGRect(x: x, y: size.height * 0.43 - height, width: width, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(GameTheme.navy.opacity(0.10)))
                for floor in 0..<2 {
                    let window = CGRect(x: rect.minX + 6, y: rect.minY + 8 + CGFloat(floor) * 11, width: max(4, rect.width - 12), height: 3)
                    context.fill(Path(window), with: .color(Color.white.opacity(0.28)))
                }
            }

            let ground = CGRect(x: 0, y: size.height * 0.43, width: size.width, height: size.height * 0.31)
            context.fill(Path(ground), with: .linearGradient(Gradient(colors: [Color(red: 0.63, green: 0.76, blue: 0.58), Color(red: 0.48, green: 0.64, blue: 0.49)]), startPoint: CGPoint(x: 0, y: ground.minY), endPoint: CGPoint(x: 0, y: ground.maxY)))

            let sidewalk = CGRect(x: 0, y: size.height * 0.73, width: size.width, height: size.height * 0.09)
            context.fill(Path(sidewalk), with: .color(Color(red: 0.72, green: 0.73, blue: 0.69)))
            context.fill(Path(CGRect(x: 0, y: sidewalk.minY, width: size.width, height: 3)), with: .color(.white.opacity(0.62)))

            let destination = normalized(type.sceneVehicleDestination, in: size)
            let vehicleGate = normalized(type.sceneVehicleGate, in: size)
            let driveway = polygon([
                CGPoint(x: destination.x - 18, y: destination.y + 5),
                CGPoint(x: destination.x + 18, y: destination.y + 5),
                CGPoint(x: vehicleGate.x + 25, y: sidewalk.maxY + 4),
                CGPoint(x: vehicleGate.x - 25, y: sidewalk.maxY + 4)
            ])
            context.fill(driveway, with: .color(GameTheme.road.opacity(0.82)))

            let pedestrianGate = normalized(type.scenePedestrianGate, in: size)
            let entrance = normalized(type.sceneEntrance, in: size)
            var walkway = Path()
            walkway.move(to: CGPoint(x: pedestrianGate.x, y: sidewalk.midY))
            walkway.addLine(to: pedestrianGate)
            walkway.addLine(to: entrance)
            context.stroke(walkway, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            context.stroke(walkway, with: .color(Color(red: 0.79, green: 0.72, blue: 0.58)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

            let road = CGRect(x: 0, y: size.height * 0.81, width: size.width, height: size.height * 0.19)
            context.fill(Path(road), with: .linearGradient(Gradient(colors: [GameTheme.road, GameTheme.ink.opacity(0.92)]), startPoint: CGPoint(x: 0, y: road.minY), endPoint: CGPoint(x: 0, y: road.maxY)))
            context.fill(Path(CGRect(x: 0, y: road.minY, width: size.width, height: 3)), with: .color(Color.white.opacity(0.75)))

            var lane = Path()
            lane.move(to: CGPoint(x: 0, y: size.height * 0.91))
            lane.addLine(to: CGPoint(x: size.width, y: size.height * 0.91))
            context.stroke(lane, with: .color(Color.white.opacity(0.75)), style: StrokeStyle(lineWidth: 2, dash: [14, 10]))

            for index in 0..<4 {
                let x = size.width * (0.08 + CGFloat(index) * 0.28)
                let trunk = CGRect(x: x, y: size.height * 0.43, width: 4, height: 18)
                let crown = CGRect(x: x - 8, y: size.height * 0.39, width: 20, height: 22)
                context.fill(Path(trunk), with: .color(Color.brown.opacity(0.55)))
                context.fill(Path(ellipseIn: crown), with: .color(Color.green.opacity(0.38)))
            }
        }
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

private struct StoreAccessOverlay: View {
    let type: StoreType

    var body: some View {
        Canvas { context, size in
            let pedestrianGate = normalized(type.scenePedestrianGate, in: size)
            let entrance = normalized(type.sceneEntrance, in: size)
            let vehicleGate = normalized(type.sceneVehicleGate, in: size)
            let destination = normalized(type.sceneVehicleDestination, in: size)

            var drivewayOpening = Path()
            drivewayOpening.move(to: CGPoint(x: vehicleGate.x, y: size.height * 0.82))
            drivewayOpening.addLine(to: vehicleGate)
            context.stroke(drivewayOpening, with: .color(.white.opacity(0.92)), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
            context.stroke(drivewayOpening, with: .color(GameTheme.road), style: StrokeStyle(lineWidth: 11, lineCap: .butt))

            var vehicleGuide = Path()
            vehicleGuide.move(to: vehicleGate)
            vehicleGuide.addLine(to: destination)
            context.stroke(vehicleGuide, with: .color(.white.opacity(0.82)), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))

            var pedestrianOpening = Path()
            pedestrianOpening.move(to: CGPoint(x: pedestrianGate.x, y: size.height * 0.78))
            pedestrianOpening.addLine(to: pedestrianGate)
            pedestrianOpening.addLine(to: entrance)
            context.stroke(pedestrianOpening, with: .color(.white.opacity(0.96)), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            context.stroke(pedestrianOpening, with: .color(Color(red: 0.80, green: 0.73, blue: 0.59)), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            context.stroke(pedestrianOpening, with: .color(GameTheme.teal.opacity(0.78)), style: StrokeStyle(lineWidth: 1.3, dash: [3, 3]))

            drawLabel("歩行入口", at: CGPoint(x: pedestrianGate.x, y: size.height * 0.745), context: &context)
            drawLabel("車両入口", at: CGPoint(x: vehicleGate.x, y: size.height * 0.79), context: &context)
        }
        .allowsHitTesting(false)
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func drawLabel(_ text: String, at point: CGPoint, context: inout GraphicsContext) {
        let background = CGRect(x: point.x - 25, y: point.y - 8, width: 50, height: 16)
        context.fill(Path(roundedRect: background, cornerRadius: 8), with: .color(GameTheme.navy.opacity(0.82)))
        context.draw(Text(text).font(.system(size: 7, weight: .black)).foregroundStyle(.white), at: point)
    }
}

private struct StoreTrafficAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: Store

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || store.weeklyVisitorCount == 0)) { timeline in
            Canvas { context, size in
                guard store.weeklyVisitorCount > 0 else { return }
                let seconds = reduceMotion ? 1.4 : timeline.date.timeIntervalSinceReferenceDate
                drawEntranceGlow(context: &context, size: size, seconds: seconds)
                drawPedestrians(context: &context, size: size, seconds: seconds)
                drawArrivingCars(context: &context, size: size, seconds: seconds)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawEntranceGlow(context: inout GraphicsContext, size: CGSize, seconds: Double) {
        let entrance = normalized(store.type.sceneEntrance, in: size)
        let pulse = reduceMotion ? 0.65 : 0.48 + (sin(seconds * 2.4) + 1) * 0.12
        let area = CGRect(x: entrance.x - 17, y: entrance.y - 10, width: 34, height: 20)
        context.fill(Path(ellipseIn: area), with: .color(GameTheme.mint.opacity(pulse * 0.28)))
        context.stroke(Path(ellipseIn: area), with: .color(GameTheme.mint.opacity(pulse)), lineWidth: 1.3)
    }

    private func drawPedestrians(context: inout GraphicsContext, size: CGSize, seconds: Double) {
        let arrivals = store.buyerArrivalsThisWeek
        guard arrivals > 0 else { return }
        let count = min(5, arrivals)
        let cycle = pedestrianCycle
        let active = pedestrianActiveFraction
        let entrance = normalized(store.type.sceneEntrance, in: size)
        let gate = normalized(store.type.scenePedestrianGate, in: size)
        let colors: [Color] = [GameTheme.orange, GameTheme.mint, .white, .yellow, .cyan]

        for index in 0..<count {
            let phase = (seconds / cycle + Double(index) / Double(max(1, count))).truncatingRemainder(dividingBy: 1)
            guard phase <= active else { continue }
            let progress = CGFloat(phase / active)
            let fromRight = index.isMultiple(of: 2)
            let start = CGPoint(x: size.width * (fromRight ? 1.04 : -0.04), y: size.height * 0.775)
            let route = [
                start,
                CGPoint(x: gate.x + (fromRight ? 18 : -18), y: size.height * 0.775),
                gate,
                entrance
            ]
            let point = sample(route: route, progress: easeInOut(progress)).point
            let fade = min(1, Double(progress) * 6, Double(1 - progress) * 8)
            drawPerson(context: &context, at: point, color: colors[index % colors.count].opacity(fade))
        }
    }

    private func drawArrivingCars(context: inout GraphicsContext, size: CGSize, seconds: Double) {
        let arrivals = store.sellerArrivalsThisWeek
        guard arrivals > 0 else { return }
        let count = min(3, arrivals)
        let cycle = vehicleCycle
        let active = vehicleActiveFraction
        let destination = normalized(store.type.sceneVehicleDestination, in: size)
        let gate = normalized(store.type.sceneVehicleGate, in: size)
        let colors: [Color] = [GameTheme.mint, Color(red: 0.96, green: 0.72, blue: 0.22), Color(red: 0.46, green: 0.75, blue: 0.94)]

        for index in 0..<count {
            let phase = (seconds / cycle + Double(index) / Double(max(1, count))).truncatingRemainder(dividingBy: 1)
            guard phase <= active else { continue }
            let progress = CGFloat(phase / active)
            let fromRight = index.isMultiple(of: 2)
            let start = CGPoint(x: size.width * (fromRight ? 1.08 : -0.08), y: size.height * 0.91)
            let route = [
                start,
                CGPoint(x: gate.x + (fromRight ? 28 : -28), y: size.height * 0.91),
                CGPoint(x: gate.x, y: size.height * 0.82),
                gate,
                destination
            ]
            let sample = sample(route: route, progress: easeInOut(progress))
            let fade = min(1, Double(progress) * 8, Double(1 - progress) * 10)
            drawCar(context: &context, at: sample.point, color: colors[index % colors.count].opacity(fade), angle: sample.angle)
        }
    }

    private var pedestrianCycle: Double {
        switch store.trafficLevel {
        case .quiet: 20
        case .light: 12
        case .steady: 9
        case .busy: 6.8
        case .packed: 5.2
        }
    }

    private var pedestrianActiveFraction: Double {
        switch store.trafficLevel {
        case .quiet: 0
        case .light: 0.36
        case .steady: 0.52
        case .busy: 0.72
        case .packed: 0.90
        }
    }

    private var vehicleCycle: Double {
        switch store.trafficLevel {
        case .quiet: 20
        case .light: 14
        case .steady: 11
        case .busy: 8.5
        case .packed: 7
        }
    }

    private var vehicleActiveFraction: Double {
        switch store.trafficLevel {
        case .quiet: 0
        case .light: 0.42
        case .steady: 0.55
        case .busy: 0.68
        case .packed: 0.80
        }
    }

    private func drawPerson(context: inout GraphicsContext, at point: CGPoint, color: Color) {
        let shadow = CGRect(x: point.x - 6, y: point.y + 8, width: 12, height: 4)
        context.fill(Path(ellipseIn: shadow), with: .color(GameTheme.ink.opacity(0.24)))
        context.fill(Path(ellipseIn: CGRect(x: point.x - 3.5, y: point.y - 10, width: 7, height: 7)), with: .color(color))
        context.fill(Path(roundedRect: CGRect(x: point.x - 4, y: point.y - 3, width: 8, height: 10), cornerRadius: 3), with: .color(color))
        var limbs = Path()
        limbs.move(to: CGPoint(x: point.x - 1.5, y: point.y + 6))
        limbs.addLine(to: CGPoint(x: point.x - 4, y: point.y + 11))
        limbs.move(to: CGPoint(x: point.x + 1.5, y: point.y + 6))
        limbs.addLine(to: CGPoint(x: point.x + 4, y: point.y + 11))
        limbs.move(to: CGPoint(x: point.x - 3, y: point.y))
        limbs.addLine(to: CGPoint(x: point.x - 7, y: point.y + 4))
        limbs.move(to: CGPoint(x: point.x + 3, y: point.y))
        limbs.addLine(to: CGPoint(x: point.x + 7, y: point.y + 4))
        context.stroke(limbs, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func drawCar(context: inout GraphicsContext, at point: CGPoint, color: Color, angle: CGFloat) {
        context.drawLayer { layer in
            layer.translateBy(x: point.x, y: point.y)
            layer.rotate(by: .radians(Double(angle)))
            let shadow = CGRect(x: -15, y: -6, width: 30, height: 14)
            layer.fill(Path(roundedRect: shadow, cornerRadius: 6), with: .color(GameTheme.ink.opacity(0.25)))
            let body = CGRect(x: -14, y: -8, width: 28, height: 14)
            layer.fill(Path(roundedRect: body, cornerRadius: 5), with: .color(color))
            let cabin = CGRect(x: -5, y: -6, width: 12, height: 10)
            layer.fill(Path(roundedRect: cabin, cornerRadius: 3), with: .color(GameTheme.navy.opacity(0.78)))
            layer.stroke(Path(roundedRect: body, cornerRadius: 5), with: .color(.white.opacity(0.70)), lineWidth: 1)
            layer.fill(Path(ellipseIn: CGRect(x: body.maxX - 3, y: -5, width: 2, height: 3)), with: .color(Color.yellow.opacity(0.95)))
            for offset in [-9.0, 7.0] {
                layer.fill(Path(roundedRect: CGRect(x: offset, y: -9, width: 5, height: 2), cornerRadius: 1), with: .color(GameTheme.ink))
                layer.fill(Path(roundedRect: CGRect(x: offset, y: 6, width: 5, height: 2), cornerRadius: 1), with: .color(GameTheme.ink))
            }
        }
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func easeInOut(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }

    private func sample(route: [CGPoint], progress: CGFloat) -> (point: CGPoint, angle: CGFloat) {
        guard route.count >= 2 else { return (route.first ?? .zero, 0) }
        let lengths = zip(route, route.dropFirst()).map { start, end in hypot(end.x - start.x, end.y - start.y) }
        let total = max(0.001, lengths.reduce(0, +))
        var remaining = min(1, max(0, progress)) * total
        for (index, length) in lengths.enumerated() {
            if remaining <= length || index == lengths.count - 1 {
                let start = route[index]
                let end = route[index + 1]
                let t = length > 0 ? remaining / length : 0
                return (
                    CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t),
                    atan2(end.y - start.y, end.x - start.x)
                )
            }
            remaining -= length
        }
        return (route.last ?? .zero, 0)
    }
}

private struct StoreSceneStatusOverlay: View {
    let store: Store

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Label(store.trafficLevel.name, systemImage: store.trafficLevel.icon)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(store.trafficLevel.color.opacity(0.92))
                    .clipShape(Capsule())
            }
            .padding(.top, 53)
            .padding(.horizontal, 10)
            Spacer()
            HStack(spacing: 14) {
                Label("販売客 \(store.buyerArrivalsThisWeek)人", systemImage: "figure.walk")
                    .foregroundStyle(GameTheme.orange)
                Label("買取車 \(store.sellerArrivalsThisWeek)台", systemImage: "car.side.fill")
                    .foregroundStyle(GameTheme.mint)
                Spacer()
                Text("週 \(store.weeklyVisitorCount)件")
                    .foregroundStyle(.white)
            }
            .font(.caption2.bold().monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.62))
        }
        .allowsHitTesting(false)
    }
}

private extension StoreTrafficLevel {
    var color: Color {
        switch self {
        case .quiet: .gray
        case .light: .blue
        case .steady: GameTheme.teal
        case .busy: GameTheme.orange
        case .packed: .red
        }
    }
}

private extension StoreType {
    var sceneAssetScale: CGFloat {
        switch self {
        case .small: 0.82
        case .standard: 0.94
        case .roadside: 1.02
        case .premium: 0.91
        case .service: 0.98
        }
    }

    var sceneAssetCenterY: CGFloat {
        switch self {
        case .small: 0.53
        case .standard: 0.54
        case .roadside: 0.53
        case .premium: 0.53
        case .service: 0.54
        }
    }

    var sceneBuildingRect: CGRect {
        switch self {
        case .small: CGRect(x: 0.13, y: 0.41, width: 0.43, height: 0.23)
        case .standard: CGRect(x: 0.09, y: 0.38, width: 0.50, height: 0.25)
        case .roadside: CGRect(x: 0.07, y: 0.34, width: 0.49, height: 0.28)
        case .premium: CGRect(x: 0.09, y: 0.35, width: 0.52, height: 0.29)
        case .service: CGRect(x: 0.07, y: 0.38, width: 0.49, height: 0.25)
        }
    }

    var sceneAccentColor: Color {
        switch self {
        case .small: GameTheme.teal
        case .standard: Color(red: 0.05, green: 0.54, blue: 0.62)
        case .roadside: GameTheme.orange
        case .premium: Color(red: 0.16, green: 0.24, blue: 0.32)
        case .service: Color(red: 0.38, green: 0.43, blue: 0.47)
        }
    }

    var sceneShortName: String {
        switch self {
        case .small: "CAR SHOP"
        case .standard: "USED CAR CITY"
        case .roadside: "MEGA AUTO"
        case .premium: "PREMIUM"
        case .service: "SALES & SERVICE"
        }
    }

    var sceneEntrance: CGPoint {
        switch self {
        case .small: CGPoint(x: 0.43, y: 0.64)
        case .standard: CGPoint(x: 0.44, y: 0.63)
        case .roadside: CGPoint(x: 0.34, y: 0.62)
        case .premium: CGPoint(x: 0.46, y: 0.64)
        case .service: CGPoint(x: 0.31, y: 0.64)
        }
    }

    var scenePedestrianGate: CGPoint {
        switch self {
        case .small: CGPoint(x: 0.43, y: 0.71)
        case .standard: CGPoint(x: 0.44, y: 0.71)
        case .roadside: CGPoint(x: 0.36, y: 0.70)
        case .premium: CGPoint(x: 0.46, y: 0.71)
        case .service: CGPoint(x: 0.31, y: 0.70)
        }
    }

    var sceneVehicleGate: CGPoint {
        switch self {
        case .small: CGPoint(x: 0.82, y: 0.71)
        case .standard: CGPoint(x: 0.66, y: 0.71)
        case .roadside: CGPoint(x: 0.52, y: 0.70)
        case .premium: CGPoint(x: 0.83, y: 0.71)
        case .service: CGPoint(x: 0.58, y: 0.70)
        }
    }

    var sceneVehicleDestination: CGPoint {
        switch self {
        case .small: CGPoint(x: 0.73, y: 0.68)
        case .standard: CGPoint(x: 0.76, y: 0.67)
        case .roadside: CGPoint(x: 0.78, y: 0.64)
        case .premium: CGPoint(x: 0.77, y: 0.66)
        case .service: CGPoint(x: 0.70, y: 0.61)
        }
    }
}

private struct StoreOverviewPanel: View {
    let store: Store
    let plot: LandPlot

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(title: "お客様レビュー", subtitle: "直近の来店・購入者評価")
                    Spacer()
                    Text(String(format: "%.1f", Double(store.satisfaction) / 20)).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(GameTheme.orange)
                }
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in Image(systemName: Double(star) <= Double(store.satisfaction) / 20 ? "star.fill" : "star").foregroundStyle(GameTheme.orange) }
                    Text("\(store.satisfaction * 6)件の評価").font(.caption).foregroundStyle(.secondary).padding(.leading, 5)
                }
                HStack {
                    ReviewMetric(name: "価格", value: 100 - Int(max(0, store.priceIndex - 0.85) * 130))
                    ReviewMetric(name: "商品", value: min(98, 48 + store.inventoryCount * 2))
                    ReviewMetric(name: "接客", value: store.satisfaction)
                    ReviewMetric(name: "立地", value: Int((plot.visibility + plot.access) * 42))
                }
            }
            .gameCard()
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "今週の経営要因", subtitle: "販売台数が動いた理由")
                if store.causes.isEmpty {
                    Text("1週間進めると分析結果が表示されます").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(store.causes) { cause in
                        HStack {
                            Image(systemName: cause.effect >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill").foregroundStyle(cause.effect >= 0 ? GameTheme.teal : GameTheme.orange)
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
}

private struct ReviewMetric: View {
    let name: String
    let value: Int
    var body: some View {
        VStack(spacing: 5) {
            Text(name).font(.caption2).foregroundStyle(.secondary)
            ZStack {
                Circle().stroke(GameTheme.navy.opacity(0.1), lineWidth: 5)
                Circle().trim(from: 0, to: min(1, Double(value) / 100)).stroke(GameTheme.teal, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(value)").font(.caption.bold().monospacedDigit())
            }.frame(width: 45, height: 45)
        }.frame(maxWidth: .infinity)
    }
}

private struct ManagerPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let update: (Store) -> Void
    @State private var confirmFireManager = false

    private var candidate: StoreManager? { game.managerCandidate(for: store.id) }
    private var employeeCandidates: [StoreEmployee] { game.employeeCandidates(for: store.id) }

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 13) {
                SectionTitle(title: "店員・育成", subtitle: "名前付きの店員がオーナーの指示で商談・査定に対応します")
                HStack {
                    MetricView(title: "在籍", value: "\(store.staff)名")
                    MetricView(title: "月額給与", value: store.employeeMonthlyPayroll.currency)
                    MetricView(title: "営業枠", value: "週\(game.weeklyOpportunityCapacity(storeID: store.id))回", detail: "オーナー分を含む")
                }
                let closeBonus = game.employeeSalesCloseAdjustment(for: store.id)
                let appraisalBonus = game.employeeAppraisalAccuracyBonus(for: store.id)
                Label("チーム補正：成約率 \(closeBonus >= 0 ? "+" : "")\(Int((closeBonus * 100).rounded()))pt・査定精度 +\(appraisalBonus)pt", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.bold())
                    .foregroundStyle(GameTheme.teal)
                Text("店員だけでは業務を自動化しません。店舗画面でオーナーが指示するか、店長へ委任してください。商談・査定を経験すると能力が成長します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.employees.isEmpty {
                    Label("在籍店員はいません", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(store.employees) { employee in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(employee.name).font(.subheadline.bold())
                                    Text("\(employee.rankName)・勤続\(employee.tenureWeeks)週・給与\(employee.monthlySalary.currency)/月")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Menu {
                                    Button("営業研修・\(game.employeeTrainingCost.currency)") {
                                        _ = game.trainEmployee(employee.id, at: store.id, focus: .sales)
                                    }
                                    .disabled(employee.lastTrainingTurn == game.turn || employee.salesSkill >= 95 || game.cash < game.employeeTrainingCost)
                                    Button("査定研修・\(game.employeeTrainingCost.currency)") {
                                        _ = game.trainEmployee(employee.id, at: store.id, focus: .appraisal)
                                    }
                                    .disabled(employee.lastTrainingTurn == game.turn || employee.appraisalSkill >= 95 || game.cash < game.employeeTrainingCost)
                                    Button("月給を2万円昇給") { _ = game.raiseEmployeeSalary(employee.id, at: store.id) }
                                        .disabled(employee.monthlySalary >= 70)
                                    Divider()
                                    Button("解雇", role: .destructive) { _ = game.fireEmployee(employee.id, from: store.id) }
                                } label: {
                                    Label("育成・待遇", systemImage: "ellipsis.circle")
                                        .font(.caption.bold())
                                }
                            }
                            AbilityBar(name: "営業", value: employee.salesSkill, color: .blue)
                            AbilityBar(name: "査定", value: employee.appraisalSkill, color: GameTheme.orange)
                            HStack {
                                Text("経験 営業\(employee.salesExperience)/12・査定\(employee.appraisalExperience)/12")
                                Spacer()
                                let risk = game.employeePoachingRisk(employee)
                                Text(risk > 0 ? "引抜リスク \(Int((risk * 100).rounded()))%/週" : "定着中")
                                    .foregroundStyle(risk >= 0.04 ? GameTheme.danger : .secondary)
                            }
                            .font(.caption2).monospacedDigit()
                        }
                        .padding(10)
                        .background(GameTheme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    }
                }
            }
            .gameCard()

            VStack(alignment: .leading, spacing: 11) {
                SectionTitle(title: "今週の店員候補", subtitle: "能力と給与を比較して採用します")
                if employeeCandidates.isEmpty {
                    Label("現在紹介できる候補者はいません", systemImage: "person.crop.circle.badge.clock")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(employeeCandidates) { employee in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(employee.name).font(.subheadline.bold())
                                Text("営業 \(employee.salesSkill)・査定 \(employee.appraisalSkill)・給与 \(employee.monthlySalary.currency)/月")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("採用") { _ = game.hireEmployee(employee.id, for: store.id) }
                                .buttonStyle(.borderedProminent).tint(.purple)
                                .disabled(store.staff >= game.maxEmployeesPerStore)
                        }
                    }
                }
            }
            .gameCard()

            if !store.hasManager {
                VStack(alignment: .leading, spacing: 13) {
                    SectionTitle(title: "店長候補", subtitle: "店長は委任した業務だけを自動化します")
                    Label("店長がいなくても、オーナーは価格・広告・整備方針を設定できます。", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let candidate {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [GameTheme.navy, GameTheme.teal], startPoint: .top, endPoint: .bottom))
                                Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 62)).foregroundStyle(GameTheme.mint)
                            }.frame(width: 100, height: 126)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(candidate.name).font(.title3.bold())
                                Text("総合能力 \(candidate.overallAbility)・給与 \(candidate.monthlySalary.currency)/月")
                                    .font(.caption.bold()).foregroundStyle(.secondary)
                                AbilityBar(name: "人員", value: candidate.staffingAbility, color: .green)
                                AbilityBar(name: "販売", value: candidate.salesAbility, color: .blue)
                                AbilityBar(name: "宣伝", value: candidate.marketingAbility, color: GameTheme.orange)
                                AbilityBar(name: "整備", value: candidate.serviceAbility, color: GameTheme.teal)
                            }
                        }
                    }
                    Button {
                        _ = game.hireManager(for: store.id)
                    } label: {
                        Label("この店長を採用・紹介料\(game.managerHiringCost.currency)", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.teal)
                    .disabled(game.cash < game.managerHiringCost)
                }
                .gameCard()
            } else if let manager = store.manager {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: "店長", subtitle: "能力に応じて委任業務の判断精度と対応速度が変わります")
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [GameTheme.navy, GameTheme.teal], startPoint: .top, endPoint: .bottom))
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 72)).foregroundStyle(GameTheme.mint)
                        }.frame(width: 112, height: 136)
                        VStack(alignment: .leading, spacing: 9) {
                            Text(manager.name).font(.title3.bold())
                            Text("総合能力 \(manager.overallAbility)・給与 \(manager.monthlySalary.currency)/月")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            AbilityBar(name: "人員", value: manager.staffingAbility, color: .green)
                            AbilityBar(name: "販売", value: manager.salesAbility, color: .blue)
                            AbilityBar(name: "宣伝", value: manager.marketingAbility, color: GameTheme.orange)
                            AbilityBar(name: "整備", value: manager.serviceAbility, color: GameTheme.teal)
                        }
                    }
                    Button(role: .destructive) {
                        confirmFireManager = true
                    } label: {
                        Label("店長を解雇", systemImage: "person.crop.circle.badge.minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }.gameCard()
                VStack(alignment: .leading, spacing: 5) {
                    SectionTitle(title: "業務委任", subtitle: "ONの業務だけを店長が週間処理で自動化します")
                    DelegationToggle(title: "採用と人員配置", icon: "person.2.fill", isOn: binding(\.delegateStaff))
                    DelegationToggle(title: "販売商談と価格設定", icon: "tag.fill", isOn: binding(\.delegatePricing))
                    DelegationToggle(title: "買取と在庫補充", icon: "car.badge.gearshape", isOn: binding(\.delegateProcurement))
                    DelegationToggle(title: "店舗マーケティング", icon: "megaphone.fill", isOn: binding(\.delegateMarketing))
                    DelegationToggle(title: "整備とトラブル対応", icon: "wrench.and.screwdriver.fill", isOn: binding(\.delegateService))
                }.gameCard()
            }
        }
        .confirmationDialog("店長を解雇しますか？", isPresented: $confirmFireManager, titleVisibility: .visible) {
            Button("店長を解雇", role: .destructive) { _ = game.fireManager(for: store.id) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべての業務委任が解除され、次週からオーナーの手動運営に戻ります。")
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Store, Bool>) -> Binding<Bool> {
        Binding(get: { store[keyPath: keyPath] }, set: { value in var changed = store; changed[keyPath: keyPath] = value; update(changed) })
    }
}

private struct AbilityBar: View {
    let name: String
    let value: Int
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(name).font(.caption2).frame(width: 27, alignment: .leading)
            ProgressView(value: Double(value), total: 100).tint(color)
            Text("\(value)").font(.caption2.bold().monospacedDigit()).frame(width: 23, alignment: .trailing)
        }
    }
}

private struct DelegationToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) { Label(title, systemImage: icon).font(.subheadline) }
            .tint(GameTheme.teal).padding(.vertical, 7)
    }
}

private struct MarketPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let plot: LandPlot
    let campaign: (Int, String) -> Void

    private var shares: [ShareSlice] {
        var result = [ShareSlice(name: store.name, value: game.marketShare(for: store) * 100, color: GameTheme.teal)]
        let otherOwnShare = game.stores
            .filter { $0.id != store.id && game.plot(id: $0.plotID)?.district == plot.district }
            .reduce(0.0) { $0 + game.marketShare(for: $1) }
        if otherOwnShare > 0.001 {
            result.append(ShareSlice(name: "自社の他店舗", value: otherOwnShare * 100, color: .blue))
        }
        let rivalColors: [Color] = [GameTheme.orange, .purple, .pink, .indigo]
        for (index, competitor) in game.competitors.enumerated() {
            let share = game.competitorMarketShare(competitor, in: plot.district)
            if share > 0.001 {
                result.append(ShareSlice(name: competitor.name, value: share * 100, color: rivalColors[index % rivalColors.count]))
            }
        }
        return result
    }

    private var selectedStoreShare: Int { Int((game.marketShare(for: store) * 100).rounded()) }

    var body: some View {
        VStack(spacing: 14) {
            ProcurementPanel(store: store, plot: plot)
            VehicleCatalogPanel(store: store, district: plot.district)
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: "\(plot.district.name)の市場シェア",
                    subtitle: "週\(game.weeklyBuyerPool(in: plot.district))台の購入需要を自社と競合で奪い合います"
                )
                HStack(spacing: 15) {
                    ZStack {
                        Chart(shares) { slice in
                            SectorMark(angle: .value("シェア", slice.value), innerRadius: .ratio(0.62), angularInset: 1.5)
                                .foregroundStyle(slice.color)
                        }
                        VStack {
                            Text("この店舗").font(.caption2)
                            Text("\(selectedStoreShare)%").font(.title2.bold()).foregroundStyle(GameTheme.teal)
                        }
                    }.frame(width: 150, height: 150)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(shares) { slice in
                            HStack {
                                Circle().fill(slice.color).frame(width: 8, height: 8)
                                Text(slice.name).font(.caption).lineLimit(1)
                                Spacer()
                                Text("\(Int(slice.value.rounded()))%").font(.caption.bold().monospacedDigit())
                            }
                        }
                    }
                }
                Label("同じ地域に出店すると、既存店と新店で同じ購入者を分け合います。", systemImage: "person.2.slash.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }.gameCard()
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "マーケティング施策", subtitle: "オーナーが広告予算を指示します")
                HStack(spacing: 10) {
                    CampaignCard(title: "地域SNS広告", detail: "+60万円/月", icon: "wifi", color: .blue) { campaign(60, "地域SNS広告を開始しました") }
                    CampaignCard(title: "ロードサイド看板", detail: "+100万円/月", icon: "signpost.right.fill", color: GameTheme.orange) { campaign(100, "幹線道路に大型看板を設置しました") }
                }
                if store.hasManager && store.delegateMarketing {
                    Label("店舗マーケティングは店長へ委任中です。次週以降、店長も能力に応じて予算を調整します。", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.caption).foregroundStyle(GameTheme.teal)
                }
            }.gameCard()
        }
    }
}

private struct ProcurementPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let plot: LandPlot
    @State private var category: VehicleCategory = .commercial
    @State private var message: String?

    private var dealerQuote: ProcurementQuote? {
        game.dealerTradeQuote(category: category, count: 3, storeID: store.id)
    }

    private var fleetQuote: ProcurementQuote? {
        game.fleetPurchaseQuote(category: category, count: 5, storeID: store.id)
    }

    private var freeCapacity: Int {
        max(0, store.type.capacity - store.inventoryCount - game.incomingCount(for: store.id))
    }

    private var isDelegated: Bool { store.hasManager && store.delegateProcurement }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "仕入れ網", subtitle: "安い偶発仕入れを待つか、費用と時間を払って必要車種を探します")
            Picker("探す車種", selection: $category) {
                ForEach(VehicleCategory.allCases) { item in Text(item.name).tag(item) }
            }
            .pickerStyle(.menu)

            HStack {
                ProposalMetric(title: "地域需要", value: "\(Int(game.vehicleDemand(category, in: plot.district) * 100))")
                ProposalMetric(title: "地域供給", value: "\(Int(game.vehicleSupply(category, in: plot.district) * 100))")
                ProposalMetric(title: "空き展示枠", value: "\(freeCapacity)台")
            }

            if let quote = dealerQuote {
                ProcurementRouteRow(
                    title: "業者間探索・3台",
                    quote: quote,
                    detail: "カテゴリ指定。希少地域では割高・納期延長",
                    disabled: isDelegated || game.cash < quote.totalCost || freeCapacity < quote.count
                ) {
                    message = game.orderDealerTrade(category: category, count: quote.count, storeID: store.id)
                        ? "\(category.name)3台を手配しました。\(quote.weeks)週間後に入庫します。"
                        : "現金または展示枠が不足しています。"
                }
            }

            if let quote = fleetQuote {
                ProcurementRouteRow(
                    title: "法人・リース入替・5台",
                    quote: quote,
                    detail: "対象車種限定。品質は低めだが一括仕入れで原価を抑制",
                    disabled: isDelegated || game.cash < quote.totalCost || freeCapacity < quote.count
                ) {
                    message = game.orderFleetPurchase(category: category, count: quote.count, storeID: store.id)
                        ? "法人入替車\(category.name)5台を契約しました。\(quote.weeks)週間後に入庫します。"
                        : "現金または展示枠が不足しています。"
                }
            } else {
                Label("法人一括仕入れは軽・ミニバン・商用車・ピックアップが対象です。地域供給または法人専門の取引網が必要です。", systemImage: "building.2.fill")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if isDelegated {
                Label("買取と在庫補充は店長へ委任中です。手動発注する場合は委任を解除してください。", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.caption).foregroundStyle(GameTheme.teal)
            }
        }
        .gameCard()
        .onAppear {
            category = game.recommendedCategories(for: plot.district).first ?? .commercial
        }
        .alert("仕入れ手配", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }
}

private struct ProcurementRouteRow: View {
    let title: String
    let quote: ProcurementQuote
    let detail: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            let tint = quote.source == .fleetPurchase ? GameTheme.orange : GameTheme.teal
            Image(systemName: quote.source == .fleetPurchase ? "building.2.fill" : "arrow.triangle.2.circlepath")
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.10))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text("\(quote.availabilityLabel)・\(quote.weeks)週・総額\(quote.totalCost.currency)")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("手配", action: action)
                .buttonStyle(.borderedProminent).tint(GameTheme.teal)
                .disabled(disabled)
        }
        .padding(10)
        .background(GameTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

private struct VehicleCatalogPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let district: DistrictKind
    @State private var selectedCategory: VehicleCategory?
    @State private var selectedPowertrain: VehiclePowertrain?

    private var models: [VehicleCatalogEntry] {
        game.availableVehicleCatalog.filter {
            (selectedCategory == nil || $0.category == selectedCategory) &&
            (selectedPowertrain == nil || $0.powertrain == selectedPowertrain)
        }
    }

    private var displayedModels: [VehicleCatalogEntry] { Array(models.prefix(36)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "車両市場カタログ", subtitle: "新車発売から中古流通まで、需要・相場・自店在庫を追跡")
            HStack {
                ProposalMetric(title: "燃料価格", value: "指数 \(Int(game.fuelPriceIndex * 100))")
                ProposalMetric(title: "EV人気", value: "指数 \(game.electricTrendIndex(in: district))")
                ProposalMetric(title: "中古EV比率", value: "\(game.usedMarketEVShare)%")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    CatalogFilterChip(title: "すべて", selected: selectedCategory == nil) { selectedCategory = nil }
                    ForEach(VehicleCategory.allCases) { category in
                        CatalogFilterChip(title: category.name, selected: selectedCategory == category) { selectedCategory = category }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    CatalogFilterChip(title: "全動力", selected: selectedPowertrain == nil) { selectedPowertrain = nil }
                    ForEach(VehiclePowertrain.allCases) { powertrain in
                        CatalogFilterChip(title: powertrain.name, selected: selectedPowertrain == powertrain) { selectedPowertrain = powertrain }
                    }
                }
            }

            if let nextRelease = game.nextNewVehicleRelease {
                Label("新車発売：\(nextRelease.fullName)（\(nextRelease.powertrain.name)）まであと\(nextRelease.launchTurn - game.turn)週", systemImage: "sparkles")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let waiting = game.newCarsAwaitingUsedMarket.first {
                Label("中古流通待ち：\(waiting.fullName)はあと\(waiting.usedMarketTurn - game.turn)週。流通初期は希少・高値", systemImage: "clock.arrow.circlepath")
                    .font(.caption2).foregroundStyle(GameTheme.orange)
            }

            ForEach(displayedModels) { model in
                CatalogVehicleRow(model: model, store: store, district: district)
                if model.id != displayedModels.last?.id { Divider() }
            }
            if models.count > displayedModels.count {
                Text("条件に一致する残り\(models.count - displayedModels.count)車種は、カテゴリまたは動力で絞り込むと表示できます。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .gameCard()
    }
}

private struct CatalogFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.caption.bold())
            .foregroundStyle(selected ? .white : GameTheme.navy)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selected ? GameTheme.navy : GameTheme.navy.opacity(0.08))
            .clipShape(Capsule())
            .buttonStyle(.plain)
    }
}

private struct CatalogVehicleRow: View {
    @EnvironmentObject private var game: GameEngine
    let model: VehicleCatalogEntry
    let store: Store
    let district: DistrictKind

    private var marketIndex: Double { game.catalogMarketIndex(for: model, in: district) }
    private var trend: Int { game.catalogPriceTrendPercent(for: model, in: district) }
    private var color: Color { marketIndex >= 1.12 ? GameTheme.teal : marketIndex >= 0.82 ? .blue : GameTheme.orange }
    private var powertrainColor: Color {
        switch model.powertrain {
        case .gasoline: return .orange
        case .hybrid: return GameTheme.teal
        case .electric: return .blue
        case .diesel: return .gray
        }
    }
    private var status: String {
        marketIndex >= 1.28 ? "需要が非常に強い" : marketIndex >= 1.12 ? "需要が強い" : marketIndex >= 0.82 ? "安定" : "弱含み"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: model.powertrain.icon)
                    .foregroundStyle(powertrainColor)
                    .frame(width: 36, height: 36)
                    .background(powertrainColor.opacity(0.11))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.fullName).font(.subheadline.bold())
                        Text(model.powertrain.name).font(.system(size: 8, weight: .black)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 3).background(powertrainColor).clipShape(Capsule())
                        if model.isRareClassic {
                            Text("希少旧車").font(.system(size: 8, weight: .black)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 3).background(GameTheme.orange).clipShape(Capsule())
                        } else if model.isPopularCustomBase {
                            Text("カスタム人気").font(.system(size: 8, weight: .black)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 3).background(Color.purple).clipShape(Capsule())
                        }
                        if !model.isRareClassic && game.turn - model.usedMarketTurn <= 3 {
                            Text("中古流入").font(.system(size: 8, weight: .black)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 3).background(GameTheme.orange).clipShape(Capsule())
                        }
                    }
                    Text(model.classicProductionYears.map { "\(model.category.name)・\($0.lowerBound)〜\($0.upperBound)年製・現状品質は低め" } ?? "\(model.category.name)・\(model.powertrain.name)・基準品質 \(Int(model.qualityBaseline * 100))/100")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Label(status, systemImage: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.bold()).foregroundStyle(color)
                    Text("価格 \(trend >= 0 ? "+" : "")\(trend)%")
                        .font(.caption2.bold().monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            HStack {
                ProposalMetric(title: "需要指数", value: "\(Int(marketIndex * 100))")
                ProposalMetric(title: "仕入相場", value: game.catalogWholesalePrice(for: model, in: district).currency)
                ProposalMetric(title: "販売参考", value: game.catalogRetailPrice(for: model, in: district).currency)
                ProposalMetric(title: "自店在庫", value: "\(game.inventoryCount(modelID: model.id, storeID: store.id))台")
            }
            if model.launchTurn > 0 {
                Label("中古流通量 \(Int(game.usedMarketSupplyFactor(for: model) * 100))%（発売から\(max(0, game.turn - model.launchTurn))週）", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct ShareSlice: Identifiable {
    var id: String { name }
    let name: String
    let value: Double
    let color: Color
}

private struct CampaignCard: View {
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundStyle(color)
                Text(title).font(.caption.bold()).multilineTextAlignment(.center)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: 102).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain)
    }
}

private struct StoreFinancePanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let update: (Store) -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                MetricView(title: "売上高", value: store.lastRevenue.currency)
                MetricView(title: "営業利益", value: store.lastProfit.currency, tint: store.lastProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                MetricView(title: "在庫回転", value: store.lastSales > 0 ? "\(store.inventoryCount * 30 / store.lastSales)日" : "—")
            }.gameCard()
            if let forecast = game.fourWeekForecast(for: store.id) {
                VStack(alignment: .leading, spacing: 11) {
                    SectionTitle(title: "4週間の店舗予測", subtitle: "現在の在庫・客足・店員体制を継続した場合")
                    HStack {
                        MetricView(title: "販売", value: "\(forecast.salesLow)〜\(forecast.salesHigh)台")
                        MetricView(title: "粗利", value: "\(forecast.grossProfitLow.currency)〜\(forecast.grossProfitHigh.currency)")
                        MetricView(title: "営業利益", value: "\(forecast.operatingProfitLow.currency)〜\(forecast.operatingProfitHigh.currency)", tint: forecast.operatingProfitHigh >= 0 ? GameTheme.teal : GameTheme.danger)
                    }
                    Label(forecast.bottleneck, systemImage: "arrow.triangle.branch")
                        .font(.caption.bold()).foregroundStyle(GameTheme.orange)
                }
                .gameCard()
            }
            VStack(alignment: .leading, spacing: 13) {
                SectionTitle(title: "オーナーの経営方針", subtitle: "店長の有無にかかわらず価格と広告を指示できます")
                Text("価格水準  \(Int(store.priceIndex * 100))").font(.subheadline.bold())
                Slider(value: binding(\.priceIndex), in: 0.88...1.18, step: 0.01).tint(GameTheme.teal)
                HStack { Text("販売量重視").font(.caption2).foregroundStyle(.secondary); Spacer(); Text("粗利重視").font(.caption2).foregroundStyle(.secondary) }
                Divider()
                Text("広告予算  \(store.advertising.currency)/月").font(.subheadline.bold())
                Slider(value: Binding(get: { Double(store.advertising) }, set: { value in var changed = store; changed.advertising = Int(value); update(changed) }), in: 0...500, step: 20).tint(GameTheme.orange)
                if store.hasManager && (store.delegatePricing || store.delegateMarketing) {
                    Label("委任中の項目は、次の週間処理で店長が能力に応じて再調整します。", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.caption).foregroundStyle(GameTheme.teal)
                }
            }.gameCard()
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Store, Double>) -> Binding<Double> {
        Binding(get: { store[keyPath: keyPath] }, set: { value in var changed = store; changed[keyPath: keyPath] = value; update(changed) })
    }
}

private struct StoreActionDock: View {
    let settings: () -> Void
    let advertise: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            DockButton(title: "店舗・設備", icon: "wrench.and.screwdriver.fill", color: GameTheme.navy, action: settings)
            DockButton(title: "広告を出す", icon: "megaphone.fill", color: GameTheme.orange, action: advertise)
        }
        .padding(8).background(GameTheme.ink).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct DockButton: View {
    let title: String
    let icon: String
    let color: Color
    var highlighted = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 11).background(color.opacity(0.82)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if highlighted {
                        RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: 2.5)
                    }
                }
        }.buttonStyle(.plain)
    }
}
