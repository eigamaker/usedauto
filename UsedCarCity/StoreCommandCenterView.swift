import SwiftUI
import Charts

struct StoreCommandCenterView: View {
    @EnvironmentObject private var game: GameEngine
    let storeID: UUID
    @State private var panel: StorePanel = CommandLine.arguments.contains("-demo-catalog") ? .market : .store
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
                        case .team: ManagerPanel(store: store, managerName: managerName, update: update)
                        case .market: MarketPanel(store: store, plot: plot, campaign: runCampaign)
                        case .finance: StoreFinancePanel(store: store, update: update)
                        }
                    }
                    StoreActionDock(
                        canManagePolicy: store.hasManager,
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
        let names = ["佐藤 美咲", "高橋 健太", "鈴木 菜月", "伊藤 拓海", "田中 玲奈"]
        return names[(plot?.id ?? 0) % names.count]
    }

    private func update(_ changed: Store) { game.updateStore(changed) }

    private func runCampaign(amount: Int, message: String) {
        guard var current = store, current.hasManager else { return }
        current.advertising = min(500, current.advertising + amount)
        game.updateStore(current)
        actionMessage = "\(message)。広告予算は月\(current.advertising.currency)です。"
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
                        Text("地域需要 \(Int(game.vehicleDemand(category, in: plot.district) * 100)) / 仕入原価 \(category.purchaseCost.currency)/台")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("3台仕入") {
                        _ = game.buyInventory(category: category, count: 3, storeID: store.id)
                    }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.teal)
                    .disabled(game.cash < category.purchaseCost * 3)
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
            Label("開店前に設備と人員を確認できます。運営方針は店長採用後に設定します。", systemImage: "info.circle.fill")
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
    private var isDelegated: Bool { store?.hasManager == true && store?.delegatePricing == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(
                    title: "今週の買取客",
                    subtitle: isDelegated ? "店長が週間処理で査定・価格交渉します" : "価格交渉を始めると共通営業枠を1回使います"
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
                            VStack(alignment: .leading, spacing: 2) { Text(item.vehicleName).font(.subheadline.bold()); Text("\(item.category.name)・\(item.modelYear)年式・走行 \(item.mileage.formatted())km・状態 \(item.conditionScore)").font(.caption).foregroundStyle(.secondary) }
                            Spacer(); VStack(alignment: .trailing) { Text("希望 \(item.askingPrice.currency)").font(.caption.bold()); Text("粗利予測 \(item.expectedGrossProfit.currency)").font(.caption2).foregroundStyle(item.expectedGrossProfit >= 0 ? GameTheme.teal : GameTheme.danger) }
                        }
                        HStack { PurchaseMetric(title: "整備", value: item.repairCost.currency); PurchaseMetric(title: "販売予測", value: item.expectedSalePrice.currency); PurchaseMetric(title: "期間", value: "\(item.expectedDays)日"); PurchaseMetric(title: "査定精度", value: "\(item.appraisalAccuracy)%") }
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
                            CaseActionButton("詳細検査", color: .blue) { game.inspectPurchaseCase(item.id); message = "査定士が詳細検査しました" }
                                .disabled(isDelegated)
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
                    message = "\(price.currency)で買取成立しました。整備費を含めて在庫へ追加しました。"
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
            VehicleProposalSheet(storeID: store.id, lead: lead) { inventoryID, strategy in
                negotiate(leadID: lead.id, inventoryID: inventoryID, strategy: strategy)
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

    private func negotiate(leadID: UUID, inventoryID: UUID, strategy: SaleNegotiationStrategy) {
        let vehicleName = store.inventory.first(where: { $0.id == inventoryID })?.vehicleName ?? "車両"
        guard let result = game.negotiateManualSale(storeID: store.id, buyerLeadID: leadID, inventoryID: inventoryID, strategy: strategy) else {
            message = "今週の営業枠に達したか、お客様または在庫がありません。"
            return
        }
        if result.succeeded {
            message = "交渉成立。\(vehicleName)を\(result.salePrice.currency)で販売し、粗利は\(result.grossProfit.currency)でした。"
        } else {
            message = "価格条件が合わず、お客様は購入を見送りました。在庫は残っています。"
        }
    }

    private func fittingInventoryCount(for lead: BuyerLead) -> Int {
        store.inventory.filter { batch in
            guard batch.count > 0 else { return false }
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
    let negotiate: (UUID, SaleNegotiationStrategy) -> Void
    @State private var selectedInventoryID: UUID?

    private var store: Store? { game.stores.first(where: { $0.id == storeID }) }
    private var inventory: [InventoryBatch] {
        guard let store else { return [] }
        return store.inventory.filter { $0.count > 0 }.sorted {
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
                                ProposalMetric(title: "仕入れ値", value: batch.averageCost.currency)
                                ProposalMetric(title: "粗利余地", value: qualityLabel(batch.quality))
                            }

                            if selectedInventoryID == batch.id {
                                Divider()
                                Text("値引き条件を選ぶ").font(.caption.bold()).foregroundStyle(.secondary)
                                ForEach(SaleNegotiationStrategy.allCases) { strategy in
                                    if let preview = game.saleNegotiationPreview(storeID: storeID, buyerLeadID: lead.id, inventoryID: batch.id, strategy: strategy) {
                                        Button {
                                            negotiate(batch.id, strategy)
                                            dismiss()
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(strategy.name).font(.subheadline.bold())
                                                    Text(strategy.detail).font(.caption2).foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text(preview.price.currency).font(.subheadline.bold().monospacedDigit())
                                                    Text("成約見込 \(Int(preview.closeChance * 100))%")
                                                        .font(.caption2.bold()).foregroundStyle(GameTheme.teal)
                                                }
                                            }
                                            .padding(10)
                                            .background(GameTheme.cream)
                                            .clipShape(RoundedRectangle(cornerRadius: 11))
                                        }
                                        .buttonStyle(.plain)
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

    private func qualityLabel(_ quality: Double) -> String {
        quality >= 0.85 ? "高品質" : quality >= 0.72 ? "標準" : "要注意"
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
    let store: Store
    @State private var showAll = false

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
            SectionTitle(title: "店舗在庫一覧", subtitle: "顧客へ提案できる個別車両・\(store.inventoryCount)台")
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
                            Text("\(batch.category.name)・品質 \(Int(batch.quality * 100))/100・仕入れ値 \(batch.averageCost.currency)")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("#\(batch.id.uuidString.prefix(4).uppercased())")
                            .font(.caption2.bold().monospaced()).foregroundStyle(.secondary)
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
                if store.hasManager {
                    CapsuleLabel(text: store.concept.name, color: GameTheme.mint, icon: store.concept.icon)
                }
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
                Image(store.type.mapAssetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: proxy.size.width * store.type.sceneAssetScale)
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * store.type.sceneAssetCenterY)
                    .shadow(color: GameTheme.ink.opacity(0.22), radius: 7, y: 5)
                StoreTrafficAnimation(store: store)
            }
            .clipped()
        }
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
            let driveway = polygon([
                CGPoint(x: destination.x - 20, y: destination.y + 5),
                CGPoint(x: destination.x + 20, y: destination.y + 5),
                CGPoint(x: destination.x + 31, y: sidewalk.maxY + 4),
                CGPoint(x: destination.x - 31, y: sidewalk.maxY + 4)
            ])
            context.fill(driveway, with: .color(GameTheme.road.opacity(0.82)))

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
        let colors: [Color] = [GameTheme.orange, GameTheme.mint, .white, .yellow, .cyan]

        for index in 0..<count {
            let phase = (seconds / cycle + Double(index) / Double(max(1, count))).truncatingRemainder(dividingBy: 1)
            guard phase <= active else { continue }
            let progress = CGFloat(phase / active)
            let start = CGPoint(
                x: size.width * (0.10 + CGFloat((index * 17) % 52) / 100),
                y: size.height * (0.79 + CGFloat(index % 2) * 0.012)
            )
            let control = CGPoint(x: entrance.x + (start.x - entrance.x) * 0.20, y: size.height * 0.70)
            let point = quadraticPoint(from: start, control: control, to: entrance, t: easeInOut(progress))
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
        let colors: [Color] = [GameTheme.mint, Color(red: 0.96, green: 0.72, blue: 0.22), Color(red: 0.46, green: 0.75, blue: 0.94)]

        for index in 0..<count {
            let phase = (seconds / cycle + Double(index) / Double(max(1, count))).truncatingRemainder(dividingBy: 1)
            guard phase <= active else { continue }
            let progress = CGFloat(phase / active)
            let fromRight = index.isMultiple(of: 2)
            let start = CGPoint(x: size.width * (fromRight ? 1.08 : -0.08), y: size.height * 0.91)
            let control1 = CGPoint(x: size.width * (fromRight ? 0.82 : 0.34), y: size.height * 0.91)
            let control2 = CGPoint(x: destination.x + (fromRight ? 28 : -28), y: size.height * 0.80)
            let point = cubicPoint(from: start, control1: control1, control2: control2, to: destination, t: easeInOut(progress))
            let fade = min(1, Double(progress) * 8, Double(1 - progress) * 10)
            drawCar(context: &context, at: point, color: colors[index % colors.count].opacity(fade), facingLeft: fromRight)
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

    private func drawCar(context: inout GraphicsContext, at point: CGPoint, color: Color, facingLeft: Bool) {
        let shadow = CGRect(x: point.x - 15, y: point.y - 5, width: 30, height: 14)
        context.fill(Path(roundedRect: shadow, cornerRadius: 6), with: .color(GameTheme.ink.opacity(0.25)))
        let body = CGRect(x: point.x - 14, y: point.y - 8, width: 28, height: 14)
        context.fill(Path(roundedRect: body, cornerRadius: 5), with: .color(color))
        let cabin = CGRect(x: point.x - 5, y: point.y - 6, width: 12, height: 10)
        context.fill(Path(roundedRect: cabin, cornerRadius: 3), with: .color(GameTheme.navy.opacity(0.78)))
        context.stroke(Path(roundedRect: body, cornerRadius: 5), with: .color(.white.opacity(0.70)), lineWidth: 1)
        let headlightX = facingLeft ? body.minX + 1 : body.maxX - 3
        context.fill(Path(ellipseIn: CGRect(x: headlightX, y: point.y - 5, width: 2, height: 3)), with: .color(Color.yellow.opacity(0.95)))
        for offset in [-9.0, 7.0] {
            context.fill(Path(roundedRect: CGRect(x: point.x + offset, y: point.y - 9, width: 5, height: 2), cornerRadius: 1), with: .color(GameTheme.ink))
            context.fill(Path(roundedRect: CGRect(x: point.x + offset, y: point.y + 6, width: 5, height: 2), cornerRadius: 1), with: .color(GameTheme.ink))
        }
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func easeInOut(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }

    private func quadraticPoint(from start: CGPoint, control: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
            y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
        )
    }

    private func cubicPoint(from start: CGPoint, control1: CGPoint, control2: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * u * start.x + 3 * u * u * t * control1.x + 3 * u * t * t * control2.x + t * t * t * end.x,
            y: u * u * u * start.y + 3 * u * u * t * control1.y + 3 * u * t * t * control2.y + t * t * t * end.y
        )
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

    var sceneEntrance: CGPoint {
        switch self {
        case .small: CGPoint(x: 0.43, y: 0.64)
        case .standard: CGPoint(x: 0.44, y: 0.63)
        case .roadside: CGPoint(x: 0.34, y: 0.62)
        case .premium: CGPoint(x: 0.46, y: 0.64)
        case .service: CGPoint(x: 0.31, y: 0.64)
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
    let managerName: String
    let update: (Store) -> Void

    var body: some View {
        VStack(spacing: 14) {
            if !store.hasManager {
                VStack(alignment: .leading, spacing: 13) {
                    SectionTitle(title: "店長を採用", subtitle: "採用後に仕入・販売・広告などを委任できます")
                    Label("現在はオーナー直営です。車の仕入れと販売を自分で操作してください。", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        _ = game.hireManager(for: store.id)
                    } label: {
                        Label("店長を採用・\(game.managerHiringCost.currency)", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.teal)
                    .disabled(game.cash < game.managerHiringCost)
                }
                .gameCard()
            } else {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "店長", subtitle: "店舗運営を任せる範囲を設定")
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [GameTheme.navy, GameTheme.teal], startPoint: .top, endPoint: .bottom))
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 72)).foregroundStyle(GameTheme.mint)
                    }.frame(width: 112, height: 136)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(managerName).font(.title3.bold())
                        AbilityBar(name: "人事", value: min(95, 48 + store.staff * 4), color: .green)
                        AbilityBar(name: "商品", value: min(95, 42 + store.inventoryCount), color: .blue)
                        AbilityBar(name: "宣伝", value: min(95, 38 + store.advertising / 5), color: GameTheme.orange)
                        AbilityBar(name: "整備", value: Int(store.serviceAllocation * 120), color: GameTheme.teal)
                    }
                }
            }.gameCard()
            VStack(alignment: .leading, spacing: 5) {
                SectionTitle(title: "業務委任", subtitle: "ONにすると現在方針を店長が維持します")
                DelegationToggle(title: "採用と人員配置", icon: "person.2.fill", isOn: binding(\.delegateStaff))
                DelegationToggle(title: "仕入と価格設定", icon: "tag.fill", isOn: binding(\.delegatePricing))
                DelegationToggle(title: "店舗マーケティング", icon: "megaphone.fill", isOn: binding(\.delegateMarketing))
                DelegationToggle(title: "整備とトラブル対応", icon: "wrench.and.screwdriver.fill", isOn: binding(\.delegateService))
            }.gameCard()
            }
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
            VehicleCatalogPanel(store: store, district: plot.district)
            if store.hasManager {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "マーケティング施策", subtitle: "店長が継続運用する集客方針")
                    HStack(spacing: 10) {
                        CampaignCard(title: "地域SNS広告", detail: "+60万円/月", icon: "wifi", color: .blue) { campaign(60, "地域SNS広告を開始しました") }
                        CampaignCard(title: "ロードサイド看板", detail: "+100万円/月", icon: "signpost.right.fill", color: GameTheme.orange) { campaign(100, "幹線道路に大型看板を設置しました") }
                    }
                }.gameCard()
            }
        }
    }
}

private struct VehicleCatalogPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let district: DistrictKind
    @State private var selectedCategory: VehicleCategory?

    private var models: [VehicleCatalogEntry] {
        game.availableVehicleCatalog.filter { selectedCategory == nil || $0.category == selectedCategory }
    }

    private var nextRelease: VehicleCatalogEntry? {
        VehicleCatalog.all.filter { $0.launchTurn > game.turn }.min { $0.launchTurn < $1.launchTurn }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "車両市場カタログ", subtitle: "需要・相場・自店在庫を比較して仕入れと提示価格を判断")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    CatalogFilterChip(title: "すべて", selected: selectedCategory == nil) { selectedCategory = nil }
                    ForEach(VehicleCategory.allCases) { category in
                        CatalogFilterChip(title: category.name, selected: selectedCategory == category) { selectedCategory = category }
                    }
                }
            }

            if let nextRelease {
                Label("次の新型車はあと\(nextRelease.launchTurn - game.turn)週間でカタログ追加予定", systemImage: "sparkles")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            ForEach(models) { model in
                CatalogVehicleRow(model: model, store: store, district: district)
                if model.id != models.last?.id { Divider() }
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
    private var status: String {
        marketIndex >= 1.28 ? "需要が非常に強い" : marketIndex >= 1.12 ? "需要が強い" : marketIndex >= 0.82 ? "安定" : "弱含み"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: model.category.icon)
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.11))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.fullName).font(.subheadline.bold())
                        if game.turn - model.launchTurn <= 3 {
                            Text("NEW").font(.system(size: 8, weight: .black)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 3).background(GameTheme.orange).clipShape(Capsule())
                        }
                    }
                    Text("\(model.category.name)・基準品質 \(Int(model.qualityBaseline * 100))/100")
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
    let store: Store
    let update: (Store) -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                MetricView(title: "売上高", value: store.lastRevenue.currency)
                MetricView(title: "営業利益", value: store.lastProfit.currency, tint: store.lastProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                MetricView(title: "在庫回転", value: store.lastSales > 0 ? "\(store.inventoryCount * 30 / store.lastSales)日" : "—")
            }.gameCard()
            if store.hasManager {
                VStack(alignment: .leading, spacing: 13) {
                    SectionTitle(title: "店長の経営方針", subtitle: "自動運営時の販売量と利益率を調整")
                    Text("価格水準  \(Int(store.priceIndex * 100))").font(.subheadline.bold())
                    Slider(value: binding(\.priceIndex), in: 0.88...1.18, step: 0.01).tint(GameTheme.teal)
                    HStack { Text("販売量重視").font(.caption2).foregroundStyle(.secondary); Spacer(); Text("粗利重視").font(.caption2).foregroundStyle(.secondary) }
                    Divider()
                    Text("広告予算  \(store.advertising.currency)/月").font(.subheadline.bold())
                    Slider(value: Binding(get: { Double(store.advertising) }, set: { value in var changed = store; changed.advertising = Int(value); update(changed) }), in: 0...500, step: 20).tint(GameTheme.orange)
                }.gameCard()
            } else {
                Label("店長を採用すると、自動運営の価格・広告方針を設定できます。", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .gameCard()
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Store, Double>) -> Binding<Double> {
        Binding(get: { store[keyPath: keyPath] }, set: { value in var changed = store; changed[keyPath: keyPath] = value; update(changed) })
    }
}

private struct StoreActionDock: View {
    let canManagePolicy: Bool
    let settings: () -> Void
    let advertise: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            DockButton(title: "店舗・設備", icon: "wrench.and.screwdriver.fill", color: GameTheme.navy, action: settings)
            if canManagePolicy {
                DockButton(title: "店長に広告を指示", icon: "megaphone.fill", color: GameTheme.orange, action: advertise)
            }
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
