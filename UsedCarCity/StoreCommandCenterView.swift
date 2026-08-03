import SwiftUI
import Charts

private func assessmentRangeText(_ range: ClosedRange<Int>) -> String {
    range.lowerBound == range.upperBound
        ? "\(range.lowerBound)"
        : "\(range.lowerBound)〜\(range.upperBound)"
}

private func assessmentConditionText(_ estimate: VehicleConditionEstimate) -> String {
    "外装\(assessmentRangeText(estimate.exterior))・"
        + "内装\(assessmentRangeText(estimate.interior))・"
        + "機関\(estimate.mechanical.map(assessmentRangeText) ?? "不明")"
}

private func customerFacingRequirementText(_ lead: BuyerLead) -> String {
    var parts = [lead.minimumModelYear > 0 ? "\(lead.minimumModelYear)年式以降" : "年式不問"]
    if let grade = lead.desiredGrade {
        parts.append("\(grade.name(for: lead.desiredProductKind))以上")
    }
    return parts.joined(separator: "・")
}

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
                GuideInlineCard(showing: [.stockInventory, .sellCar, .hireStaff, .delegateWork])
                StoreSceneHeader(store: store, plot: plot)
                if store.isOperational {
                    if game.canSelectFoundingInventory(storeID: store.id) {
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
                                StoreOverviewPanel(store: store)
                        }
                        case .team: ManagerPanel(store: store, update: update)
                        case .market: MarketPanel(store: store, plot: plot, campaign: runCampaign)
                        case .finance:
                            StoreFinancePanel(
                                store: store,
                                update: update,
                                openSettings: { showSettings = true },
                                openTeam: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        panel = .team
                                    }
                                }
                            )
                        }
                    }
                } else {
                    StoreConstructionPanel(store: store, plot: plot) { showSettings = true }
                }
            }
            .sheet(isPresented: $showSettings) { StoreSettingsView(storeID: storeID) }
            .alert("アクション結果", isPresented: Binding(get: { actionMessage != nil }, set: { if !$0 { actionMessage = nil } })) {
                Button("OK") { actionMessage = nil }
            } message: { Text(actionMessage ?? "") }
            .onAppear(perform: applyGuidePanelRequest)
            .onChange(of: game.guideStorePanelRequest) { _, _ in applyGuidePanelRequest() }
        }
    }

    /// ガイドの誘導ボタンから開かれたときに、対象タブへ切り替えます。
    private func applyGuidePanelRequest() {
        guard let request = game.guideStorePanelRequest else { return }
        switch request {
        case .store: panel = .store
        case .team: panel = .team
        case .market: panel = .market
        case .finance: panel = .finance
        }
        game.guideStorePanelRequest = nil
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

    private var capacity: Int { game.weeklySalesCapacity(storeID: store.id) }
    private var remaining: Int { game.remainingWeeklySalesOpportunities(storeID: store.id) }
    private var inventoryRate: Double {
        Double(store.inventoryCount) / Double(max(1, store.type.capacity))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "今週の営業")
            HStack(spacing: 8) {
                StoreStatusMetric(
                    icon: "clock.badge.checkmark",
                    title: "営業枠",
                    value: "\(remaining)/\(capacity)",
                    detail: "残り",
                    tint: remaining > 0 ? GameTheme.teal : GameTheme.orange
                )
                StoreStatusMetric(
                    icon: "car.2.fill",
                    title: "在庫",
                    value: "\(store.inventoryCount)/\(store.type.capacity)",
                    detail: inventoryRate >= 0.9 ? "満車間近" : inventoryRate < 0.25 ? "仕入不足" : "適正",
                    tint: inventoryRate >= 0.9 || inventoryRate < 0.25 ? GameTheme.orange : GameTheme.teal
                )
                StoreStatusMetric(
                    icon: "yensign.circle.fill",
                    title: "直近売上",
                    value: store.lastRevenue.currency,
                    detail: "前週実績",
                    tint: store.lastRevenue > 0 ? GameTheme.teal : GameTheme.navy
                )
                StoreStatusMetric(
                    icon: "figure.walk",
                    title: "客足",
                    value: "\(store.weeklyVisitorCount)人",
                    detail: store.trafficLevel.name,
                    tint: GameTheme.navy
                )
            }
        }
        .gameCard()
    }
}

private struct StoreStatusMetric: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
    private var isAutomated: Bool {
        game.stores.first(where: { $0.id == storeID })?.autoProcurement == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "今週の買取客")
                if !cases.isEmpty { Text("\(cases.count)件").font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 5).background(GameTheme.orange).clipShape(Capsule()) }
            }
            if cases.isEmpty {
                Label("現在、未処理の買取案件はありません", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(GameTheme.teal).padding(.vertical, 12)
            } else {
                ForEach(cases) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        let grossProfit = game.purchaseExpectedGrossProfit(for: item)
                        let saleRange = game.marketForecastRange(value: item.expectedSaleAfterAppraisal, storeID: storeID)
                        let assessment = game.purchaseAssessment(for: item)
                        let saleForecastText = "\(saleRange.lowerBound.currency)〜\(saleRange.upperBound.currency)"
                        let exteriorText = assessmentRangeText(assessment.condition.exterior)
                        let interiorText = assessmentRangeText(assessment.condition.interior)
                        let mechanicalText = assessment.condition.mechanical.map(assessmentRangeText) ?? "不明"
                        let repairText = "\(assessment.repairCostRange.lowerBound.currency)〜\(assessment.repairCostRange.upperBound.currency)"
                        Text("お客様の車両情報")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        HStack {
                            CharacterAvatarView(
                                role: item.characterAvatarRole,
                                seed: item.characterAvatarSeed,
                                size: 46
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Text(item.vehicleName).font(.subheadline.bold())
                                    if item.origin == .specialtyReferral {
                                        CapsuleLabel(text: "指名買取", color: .purple, icon: "scope")
                                    }
                                }
                                Text("\(item.category.name)・\(String(item.modelYear))年式・走行 \(item.mileage.formatted())km")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        if item.lotCount > 1 {
                            Label("法人放出 \(item.lotCount)台一括・表示価格と整備費は1台あたり", systemImage: "building.2.fill")
                                .font(.caption2.bold()).foregroundStyle(GameTheme.orange)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), alignment: .leading, spacing: 8) {
                            PurchaseMetric(title: "希望額", value: item.askingPrice.currency)
                            PurchaseMetric(title: "外装", value: exteriorText)
                            PurchaseMetric(title: "内装", value: interiorText)
                            PurchaseMetric(title: "機関", value: mechanicalText)
                        }
                        Divider()
                        Text("店舗の見積もり")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), alignment: .leading, spacing: 8) {
                            PurchaseMetric(title: "推定販売価格", value: saleForecastText)
                            PurchaseMetric(
                                title: item.suggestedProjectKind == nil ? "推定粗利" : "改造後の推定粗利",
                                value: grossProfit.currency,
                                tint: grossProfit >= 0 ? GameTheme.teal : GameTheme.danger
                            )
                            PurchaseMetric(title: "査定見積り", value: item.appraisedPrice.currency)
                            PurchaseMetric(title: "推定修繕費", value: repairText)
                        }
                        if let project = item.suggestedProjectKind {
                            HStack {
                                Label("推奨：\(project.name)", systemImage: project.icon)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.purple)
                                Spacer()
                                Text("現状販売粗利 \(item.asIsExpectedGrossProfit.currency)")
                                    .font(.caption2.bold().monospacedDigit())
                                    .foregroundStyle(item.asIsExpectedGrossProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                            }
                            Text("取得後、現金と工房枠があれば推奨改造へ自動投入します。")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let detectedFault = assessment.detectedFault {
                            Label(
                                detectedFault.name,
                                systemImage: detectedFault == .none ? "checkmark.seal.fill" : "wrench.adjustable.fill"
                            )
                            .font(.caption2.bold())
                            .foregroundStyle(detectedFault == .none ? GameTheme.teal : GameTheme.orange)
                        } else if !game.hasServiceTechnician(storeID: storeID) {
                            Label("整備担当不在のため不明", systemImage: "person.crop.circle.badge.questionmark")
                                .font(.caption2.bold())
                                .foregroundStyle(GameTheme.orange)
                        }
                        if let rival = item.competitorOffer {
                            Text("競合提示目安：\(game.competitorName(for: rival.competitorID)) \(rival.price.currency)/台")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if let advice = game.procurementAppraisalAdvice(for: item.id) {
                            let shouldDecline = game.storePurchaseDecision(for: item) == .decline
                            Label(advice, systemImage: shouldDecline ? "hand.raised.fill" : "checkmark.shield.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(shouldDecline ? GameTheme.danger : GameTheme.teal)
                        }
                        if let issue = item.revealedIssue {
                            Label(issue.warningText, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(GameTheme.danger)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(GameTheme.danger.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        if item.negotiations > 0 {
                            Label("交渉 \(item.negotiations)回・次に断られると売主が帰る可能性があります", systemImage: "exclamationmark.bubble.fill")
                                .font(.caption2)
                                .foregroundStyle(GameTheme.orange)
                        }
                        HStack(spacing: 6) {
                            Menu {
                                let recommended = game.storePurchaseDecision(for: item).recommendedOfferPercent
                                let offerPercents = Array(Set([100, 94, 88, 80] + (recommended.map { [$0] } ?? []))).sorted(by: >)
                                ForEach(offerPercents, id: \.self) { percent in
                                    purchaseOfferButton(
                                        item,
                                        percent: percent,
                                        title: percent == recommended && percent != 100
                                            ? "査定担当の推奨額"
                                            : percent == 100 ? "希望額で提示" : "\(100 - percent)%値下げを交渉"
                                    )
                                }
                            } label: {
                                Label("価格を提示", systemImage: "bubble.left.and.bubble.right.fill")
                                    .font(.caption2.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(GameTheme.orange)
                            .disabled(!game.canNegotiatePurchaseCase(item.id))
                            Button(role: .destructive) { game.declinePurchaseCase(item.id) } label: { Image(systemName: "xmark").font(.caption.bold()).padding(8) }.buttonStyle(.bordered)
                        }
                        if !isAutomated && !game.canNegotiatePurchaseCase(item.id) {
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
                        ? "\(item.lotCount)台を合計\(price.currency)で買取成立しました。現状のまま在庫へ追加しました。"
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
    let title: String
    let value: String
    var tint: Color = GameTheme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(2)
            Text(value)
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ManualSalesPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    @State private var message: String?
    @State private var selectedLead: BuyerLead?

    private var leads: [BuyerLead] { game.buyerLeads(for: store.id) }
    private var capacity: Int { game.weeklySalesCapacity(storeID: store.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "今週の販売客")
                Spacer()
                Text("営業枠 \(store.manualNegotiationsThisWeek)/\(capacity)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(GameTheme.teal)
            }
            if leads.isEmpty {
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
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 11) {
                            CharacterAvatarView(
                                role: lead.characterAvatarRole,
                                seed: lead.characterAvatarSeed,
                                size: 48
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lead.preference.customerDescription).font(.subheadline.bold())
                                Text("用途 \(lead.purpose.name)・予算 \(lead.budget.currency)・\(customerFacingRequirementText(lead))")
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                if let rival = lead.competitorOffer {
                                    Text("比較候補：\(game.competitorName(for: rival.competitorID)) \(rival.price.currency)・状態目安\(Int(rival.quality * 100))")
                                        .font(.caption2).foregroundStyle(GameTheme.orange)
                                }
                                if let tradeIn = lead.tradeInVehicle {
                                    Text("下取り希望：\(tradeIn.vehicleName)・査定 \(tradeIn.appraisedValue.currency)")
                                        .font(.caption2.bold()).foregroundStyle(GameTheme.teal)
                                }
                            }
                            Spacer(minLength: 4)
                            }
                            Button {
                                selectedLead = lead
                            } label: {
                                Label("車を提案", systemImage: "bubble.left.and.bubble.right.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
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
                Text("商談すると成否に関係なく営業枠を1回使い、このお客様は帰ります。値引き・予算・希望条件・車両状態で成約率が変わります。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .gameCard()
        .overlay {
            if game.currentGuideLesson?.id == .sellCar {
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
        store.inventory.filter { game.inventoryMatchesBuyer($0, lead: lead, storeID: store.id) }
            .reduce(0) { $0 + $1.count }
    }

    private func noMatchingInventoryMessage(for lead: BuyerLead) -> String {
        switch lead.preference {
        case .category, .categoryOrigin: "希望車種・産地・年式・走行距離に合う在庫がありません"
        case .maker: "指定メーカーと条件に合う在庫がありません"
        case .exactModel: "指名車種と条件に合う在庫がありません"
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
                        HStack(spacing: 12) {
                            CharacterAvatarView(
                                role: lead.characterAvatarRole,
                                seed: lead.characterAvatarSeed,
                                size: 56
                            )
                            SectionTitle(
                                title: lead.preference.customerDescription,
                                subtitle: "\(lead.purpose.name)・提案する在庫車を選ぶ"
                            )
                        }
                        HStack {
                            MetricView(title: "希望条件", value: lead.preference.name, tint: GameTheme.teal)
                            MetricView(title: "予算", value: lead.budget.currency)
                            MetricView(title: "年式・仕様", value: customerFacingRequirementText(lead))
                        }
                    }
                    .gameCard()

                    if let tradeIn = lead.tradeInVehicle {
                        let assessment = game.tradeInAssessment(for: tradeIn, storeID: storeID)
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("下取り車 \(tradeIn.vehicleName)").font(.subheadline.bold())
                                    Text(
                                        "\(String(tradeIn.modelYear))年式・\(tradeIn.mileage.formatted())km・"
                                            + assessmentConditionText(assessment.condition)
                                    )
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("査定 \(tradeIn.appraisedValue.currency)")
                                    .font(.subheadline.bold().monospacedDigit()).foregroundStyle(GameTheme.teal)
                            }
                            HStack {
                                ProposalMetric(title: "推定修繕費", value: "\(assessment.repairCostRange.lowerBound.currency)〜\(assessment.repairCostRange.upperBound.currency)")
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
                                    Text("条件一致").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 5).background(GameTheme.teal).clipShape(Capsule())
                                } else {
                                    Text("代替提案").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 5).background(GameTheme.orange).clipShape(Capsule())
                                }
                            }

                            HStack {
                                ProposalMetric(title: "外装", value: "\(batch.condition.exterior)")
                                ProposalMetric(title: "内装", value: "\(batch.condition.interior)")
                                ProposalMetric(title: "機関", value: "\(batch.condition.mechanical)")
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
        game.inventoryMatchesBuyer(batch, lead: lead, storeID: storeID)
    }

    private func proposalTint(_ batch: InventoryBatch) -> Color {
        proposalFits(batch) ? GameTheme.teal : GameTheme.orange
    }

    private func tradeInSettlementLabel(_ preview: TradeInSalePreview?) -> String {
        guard let preview else { return "下取り条件を計算できません" }
        let grossText = preview.expectedTradeInGrossProfit.currency
        if preview.customerCashSettlement >= 0 {
            return "下取り\(preview.allowance.currency)・お客様差額\(preview.customerCashSettlement.currency)・下取粗利見込\(grossText)"
        }
        return "下取り\(preview.allowance.currency)・店舗支払\((-preview.customerCashSettlement).currency)・下取粗利見込\(grossText)"
    }
}

private struct ProposalMetric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StoreInventoryPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    @State private var showAll = false
    @State private var message: String?
    @State private var customizationBatch: InventoryBatch?

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
            HStack {
                SectionTitle(title: "店舗在庫一覧")
                Spacer()
                Text("\(store.inventoryCount)台")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(GameTheme.teal)
            }
            if sortedInventory.isEmpty {
                Label("販売できる在庫がありません", systemImage: "car.circle")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                ForEach(visibleInventory) { batch in
                    VStack(alignment: .leading, spacing: 9) {
                        let mechanicalDetail = batch.faultRevealed || game.hasServiceTechnician(storeID: store.id)
                            ? "\(batch.condition.mechanical)"
                            : "不明"
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: batch.fault == .none ? batch.category.icon : "exclamationmark.triangle.fill")
                                .foregroundStyle(batch.fault == .none ? GameTheme.teal : GameTheme.danger)
                                .frame(width: 34, height: 34)
                                .background((batch.fault == .none ? GameTheme.teal : GameTheme.danger).opacity(0.10))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(batch.vehicleName)（#\(batch.id.uuidString.prefix(4).uppercased())）")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(batch.fault == .none ? GameTheme.ink : GameTheme.danger)
                                HStack(spacing: 5) {
                                    Text("\(batch.category.name)・\(String(batch.modelYear))年式・\(batch.mileage.formatted())km")
                                        .foregroundStyle(.secondary)
                                    Text(game.inventoryAgeLabel(for: batch))
                                        .foregroundStyle(ageTint(for: batch))
                                }
                                .font(.caption2.bold().monospacedDigit())
                                Text("外装\(batch.condition.exterior)・内装\(batch.condition.interior)・機関\(mechanicalDetail)・\(batch.faultRevealed ? batch.fault.name : "故障判定中")")
                                    .font(.caption2.bold().monospacedDigit())
                                    .foregroundStyle(batch.fault == .none ? .secondary : GameTheme.danger)
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
                                    if batch.isReserved { Text("法人案件に予約中").foregroundStyle(GameTheme.orange) }
                                }
                                .font(.caption2.bold())
                                Text("仕入れ価格 \(batch.averageCost.currency)・販売目安 \((game.manualSaleQuote(storeID: store.id, inventoryID: batch.id)?.price ?? 0).currency)")
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        if let project = batch.workshopProject {
                            Label(project.outsourced ? "\(project.kind.name) あと\(project.remainingWeeks)週" : "\(project.kind.name) 残\(project.remainingWork)工数", systemImage: project.kind.icon)
                                .font(.caption2.bold()).foregroundStyle(.purple)
                        } else {
                            HStack(spacing: 8) {
                                if hasCustomizationOption(batch) {
                                    Button {
                                        customizationBatch = batch
                                    } label: {
                                        Label("カスタマイズ", systemImage: "paintbrush.pointed.fill")
                                    }
                                    .font(.caption2.bold())
                                    .buttonStyle(.borderedProminent)
                                    .tint(.purple)
                                }
                                if let preview = game.workshopProjectPreview(storeID: store.id, inventoryID: batch.id, kind: batch.fault == .none ? .basicService : .repair) {
                                    Button("\(preview.kind.name) \(preview.cost.currency)") {
                                        message = game.startWorkshopProject(storeID: store.id, inventoryID: batch.id, kind: preview.kind)
                                            ? "\(preview.kind.name)を商品化キューへ追加しました。"
                                            : "整備を実行できませんでした。"
                                    }
                                    .font(.caption2.bold()).buttonStyle(.bordered).tint(GameTheme.teal)
                                    .disabled(game.cash < preview.cost)
                                } else if !hasCustomizationOption(batch) {
                                    Text("整備上限").font(.caption2.bold()).foregroundStyle(GameTheme.teal)
                                }
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
        .sheet(item: $customizationBatch) { batch in
            InventoryCustomizationSheet(storeID: store.id, inventoryID: batch.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("在庫整備", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }

    private func hasCustomizationOption(_ batch: InventoryBatch) -> Bool {
        [.streetTuning, .driftTuning, .circuitTuning,
         .liftSeatConversion, .wheelchairConversion,
         .mobileSalesConversion, .kitchenCarConversion,
         .camperConversion, .refurbishment, .outdoorConversion, .workConversion].contains {
            game.workshopProjectPreview(storeID: store.id, inventoryID: batch.id, kind: $0) != nil
        }
    }

    private func ageTint(for batch: InventoryBatch) -> Color {
        let weeks = game.inventoryAgeWeeks(for: batch)
        return weeks <= 2 ? GameTheme.teal : weeks <= 12 ? GameTheme.navy : weeks <= 25 ? GameTheme.orange : GameTheme.danger
    }
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
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let plot: LandPlot
    @State private var showRename = false
    @State private var nameDraft = ""

    private var isFullyDelegated: Bool {
        store.hasManager
            && store.delegateStaff
            && store.delegatePricing
            && store.delegateMarketing
            && store.delegateProcurement
            && store.delegateService
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Button {
                        nameDraft = store.name
                        showRename = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(store.name)
                                .font(.title3.bold())
                                .multilineTextAlignment(.leading)
                            Image(systemName: "pencil").font(.caption.bold())
                        }
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("店名を変更")
                    Spacer()
                    if isFullyDelegated {
                        Label("店長に一任", systemImage: "checkmark.shield.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(GameTheme.mint)
                    }
                }
                Label(
                    game.regionalNicheLeaderLabel(for: store) ?? game.derivedBusinessName(for: store),
                    systemImage: game.regionalNicheLeaderLabel(for: store) == nil ? "car.2.fill" : "crown.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(GameTheme.mint)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(15).background(GameTheme.ink)
            ZStack(alignment: .top) {
                StoreScene(store: store)
                    .frame(height: 258)
                HStack(spacing: 9) {
                    if isFullyDelegated, let manager = store.manager {
                        CharacterAvatarView(
                            role: .manager,
                            seed: manager.characterAvatarSeed,
                            size: 36
                        )
                    }
                    Text(greeting).font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                }
                .padding(11).background(.black.opacity(0.66))
                StoreSceneStatusOverlay(store: store)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .shadow(color: GameTheme.ink.opacity(0.20), radius: 12, y: 5)
        .alert("店名を変更", isPresented: $showRename) {
            TextField("店名", text: $nameDraft)
            Button("キャンセル", role: .cancel) {}
            Button("変更") { renameStore() }
        } message: {
            Text("24文字以内で入力してください")
        }
    }

    private var greeting: String {
        if let remaining = store.openingMonthsRemaining { return "建設中です。あと\(remaining)週間で開店予定です" }
        if let remaining = store.renovationMonthsRemaining { return "営業を続けながら改装中。あと\(remaining)週間です" }
        if store.inventoryCount < 5 { return "在庫が少なく、販売機会を逃しています" }
        if store.lastProfit < 0 { return "今週は赤字です。価格と広告を見直しましょう" }
        if (store.averageReviewScore ?? 0) >= 80 { return "口コミが好調です。この流れを維持しましょう" }
        return "今週もお客様の動きを確認していきましょう"
    }

    private func renameStore() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var changed = store
        changed.name = String(trimmed.prefix(24))
        game.updateStore(changed)
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
                Label("\(store.buyerArrivalsThisWeek)", systemImage: "figure.walk")
                    .foregroundStyle(GameTheme.orange)
                    .accessibilityLabel("販売客 \(store.buyerArrivalsThisWeek)人")
                Label("\(store.sellerArrivalsThisWeek)", systemImage: "car.side.fill")
                    .foregroundStyle(GameTheme.mint)
                    .accessibilityLabel("買取車 \(store.sellerArrivalsThisWeek)台")
                Spacer()
                Label("\(store.weeklyVisitorCount)", systemImage: "calendar")
                    .foregroundStyle(.white)
                    .accessibilityLabel("今週 \(store.weeklyVisitorCount)件")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "お客様レビュー")
                Spacer()
                Text(store.reviewRatingText).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(GameTheme.orange)
            }
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: Double(star) <= (store.reviewRating ?? 0) ? "star.fill" : "star")
                        .foregroundStyle(store.reviewCount == 0 ? .secondary : GameTheme.orange)
                }
                Text(store.reviewCount == 0 ? "レビューはまだありません" : "\(store.reviewCount)件の来店客評価")
                    .font(.caption).foregroundStyle(.secondary).padding(.leading, 5)
            }
            HStack {
                ReviewMetric(name: "販売価格", value: store.reviewScore(for: .salesPrice))
                ReviewMetric(name: "車両・商品", value: store.reviewScore(for: .vehicle))
                ReviewMetric(name: "買取価格", value: store.reviewScore(for: .purchaseOffer))
                ReviewMetric(name: "接客", value: store.reviewScore(for: .service))
            }
            Label(store.reviewManagementAdvice, systemImage: "signpost.right.and.left.fill")
                .font(.caption.bold())
                .foregroundStyle(GameTheme.navy)
            if !store.customerReviews.isEmpty {
                Divider()
                ForEach(Array(store.customerReviews.prefix(3))) { review in
                    HStack(alignment: .top, spacing: 8) {
                        Text(review.channel.name)
                            .font(.caption2.bold())
                            .foregroundStyle(review.channel == .buyer ? .blue : GameTheme.teal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background((review.channel == .buyer ? Color.blue : GameTheme.teal).opacity(0.10))
                            .clipShape(Capsule())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(review.comment).font(.caption)
                            Text("評価 \(String(format: "%.1f", Double(review.overallScore) / 20))・\(review.createdTurn + 1)週目")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .gameCard()
    }
}

private struct ReviewMetric: View {
    let name: String
    let value: Int?
    var body: some View {
        VStack(spacing: 5) {
            Text(name).font(.caption2).foregroundStyle(.secondary)
            ZStack {
                Circle().stroke(GameTheme.navy.opacity(0.1), lineWidth: 5)
                Circle().trim(from: 0, to: min(1, Double(value ?? 0) / 100))
                    .stroke((value ?? 70) < 60 ? GameTheme.orange : GameTheme.teal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value.map(String.init) ?? "—").font(.caption.bold().monospacedDigit())
            }.frame(width: 45, height: 45)
        }.frame(maxWidth: .infinity)
    }
}

private struct ManagerPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let update: (Store) -> Void
    @State private var confirmFireManager = false
    @State private var showProcurementInstructionEditor = false
    @State private var showStorePurchasePolicyEditor = false

    private var candidate: StoreManager? { game.managerCandidate(for: store.id) }
    private var employeeCandidates: [StoreEmployee] { game.employeeCandidates(for: store.id) }
    private var employeeSalesCapacity: Int {
        store.employees
            .filter { $0.assignment == .sales }
            .reduce(0) {
                $0 + game.employeeWeeklyCaseCapacity(for: $1)
            }
    }
    private var employeeProcurementCapacity: Int {
        store.employees
            .filter { $0.assignment == .procurement }
            .reduce(0) { $0 + game.employeeWeeklyCaseCapacity(for: $1) }
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "社員に任せる業務")
                AutomationPolicyRow(
                    title: "販売",
                    icon: "person.line.dotted.person.fill",
                    isOn: binding(\.autoSales),
                    policyName: store.salesPolicy.name
                ) {
                    Picker("販売方針", selection: binding(\.salesPolicy)) {
                        ForEach(SalesAutomationPolicy.allCases) { Text($0.name).tag($0) }
                    }
                }
                AutomationPolicyRow(
                    title: "市場調査",
                    icon: "chart.line.uptrend.xyaxis",
                    isOn: binding(\.autoMarketing),
                    policyName: store.marketingPolicy.name
                ) {
                    Picker("集客方針", selection: binding(\.marketingPolicy)) {
                        ForEach(MarketingAutomationPolicy.allCases) { Text($0.name).tag($0) }
                    }
                }
                AutomationPolicyRow(
                    title: "整備",
                    icon: "wrench.and.screwdriver.fill",
                    isOn: binding(\.autoService),
                    policyName: store.servicePolicy.name
                ) {
                    Picker("整備方針", selection: binding(\.servicePolicy)) {
                        ForEach(ServiceAutomationPolicy.allCases) { Text($0.name).tag($0) }
                    }
                }
                HStack(spacing: 10) {
                    Label("仕入", systemImage: "car.badge.gearshape")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: binding(\.autoProcurement))
                        .labelsHidden()
                    .tint(GameTheme.teal)
                    Button("AA指示") {
                        showProcurementInstructionEditor = true
                    }
                        .font(.subheadline.bold())
                        .frame(width: 96, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
            .gameCard()

            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    SectionTitle(title: "店舗買取方針")
                    Spacer()
                    Button("方針を設定") { showStorePurchasePolicyEditor = true }
                        .font(.caption.bold())
                }
                let policy = store.storePurchasePolicy
                HStack {
                    MetricView(title: "週間予算", value: policy.weeklyBudget.currency)
                    MetricView(title: "最低粗利", value: "\(policy.minimumGrossProfit.currency)／台")
                    MetricView(title: "今週残り", value: policy.remainingBudget.currency)
                }
                Text(policy.categories.isEmpty
                    ? "対象車両なし"
                    : policy.modelIDs.isEmpty
                        ? "対象：\(policy.categories.sorted { $0.name < $1.name }.map(\.name).joined(separator: "、"))"
                        : "対象車種：\(policy.modelIDs.compactMap { VehicleCatalog.entry(id: $0)?.fullName }.sorted().joined(separator: "、"))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .gameCard()

            ProcurementInstructionPanel(
                store: store,
                showCreate: $showProcurementInstructionEditor
            )

            VStack(alignment: .leading, spacing: 13) {
                SectionTitle(title: "店員の情報")
                HStack {
                    MetricView(title: "在籍", value: "\(store.staff)名")
                    MetricView(title: "月額給与", value: store.employeeMonthlyPayroll.currency)
                    MetricView(title: "オーナー販売枠", value: "週\(game.weeklySalesCapacity(storeID: store.id))回")
                    MetricView(
                        title: "社員営業枠",
                        value: "週\(employeeSalesCapacity)回"
                    )
                    MetricView(
                        title: "オーナー仕入枠",
                        value: "週\(game.weeklyProcurementCapacity(storeID: store.id))回"
                    )
                    MetricView(
                        title: "社員仕入枠",
                        value: "週\(employeeProcurementCapacity)回"
                    )
                }
                Text("社員は担当を割り当てないと業務をしてくれません")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.employees.isEmpty {
                    Label("在籍店員はいません", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(store.employees) { employee in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                CharacterAvatarView(
                                    role: employee.characterAvatarRole,
                                    seed: employee.characterAvatarSeed,
                                    size: 46
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(employee.name).font(.subheadline.bold())
                                    Text("\(employee.rankName)・\(employee.compensationType.name)・月給\(employee.monthlySalary.currency)\(employee.commissionRate > 0 ? "＋成約粗利\(employee.commissionRate)%" : "")")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Menu {
                                    ForEach(EmployeeTrainingFocus.allCases) { focus in
                                        Button("\(focus.name)研修・\(game.employeeTrainingCost.currency)") {
                                            _ = game.trainEmployee(employee.id, at: store.id, focus: focus)
                                        }
                                        .disabled(employee.lastTrainingTurn == game.turn || ability(employee, focus: focus) >= 99 || game.cash < game.employeeTrainingCost)
                                    }
                                    Button("月給を2万円昇給") { _ = game.raiseEmployeeSalary(employee.id, at: store.id) }
                                        .disabled(employee.monthlySalary >= 130)
                                    Divider()
                                    Button("解雇", role: .destructive) { _ = game.fireEmployee(employee.id, from: store.id) }
                                } label: {
                                    Label("育成・待遇", systemImage: "ellipsis.circle")
                                        .font(.caption.bold())
                                }
                            }
                            Picker("担当", selection: Binding(
                                get: { employee.assignment },
                                set: { _ = game.assignEmployee(employee.id, at: store.id, to: $0) }
                            )) {
                                ForEach(EmployeeAssignment.allCases) { Label($0.name, systemImage: $0.icon).tag($0) }
                            }
                            .pickerStyle(.menu)
                            AbilityBar(name: "販売", value: employee.salesSkill, color: .blue)
                            AbilityBar(name: "仕入", value: employee.procurementSkill, color: .purple)
                            AbilityBar(name: "調査", value: employee.researchSkill, color: .indigo)
                            AbilityBar(name: "査定・整備", value: employee.serviceSkill, color: GameTheme.teal)
                            HStack {
                                Text(effectDescription(employee))
                                Spacer()
                                let risk = game.employeePoachingRisk(employee)
                                Text(risk > 0 ? "引抜リスク \(Int((risk * 100).rounded()))%/週" : "定着中")
                                    .foregroundStyle(risk >= 0.04 ? GameTheme.danger : .secondary)
                            }
                            .font(.caption2).monospacedDigit()
                            Label("前週：\(employee.lastWeekPerformance.summary)\(employee.lastWeekPerformance.commission > 0 ? "・歩合\(employee.lastWeekPerformance.commission.currency)" : "")", systemImage: "clock.arrow.circlepath")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(GameTheme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    }
                }
            }
            .gameCard()

            VStack(alignment: .leading, spacing: 11) {
                SectionTitle(title: "今週の店員候補", subtitle: "販売・仕入・調査・整備の専門家を毎週各1人以上紹介")
                if employeeCandidates.isEmpty {
                    Label("現在紹介できる候補者はいません", systemImage: "person.crop.circle.badge.clock")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(employeeCandidates) { employee in
                        HStack(spacing: 10) {
                            CharacterAvatarView(
                                role: employee.characterAvatarRole,
                                seed: employee.characterAvatarSeed,
                                size: 48
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(employee.name)・\(employee.specialtyName)・\(employee.rankName)").font(.subheadline.bold())
                                Text("販売\(employee.salesSkill) 仕入\(employee.procurementSkill) 調査\(employee.researchSkill) 査定・整備\(employee.serviceSkill)")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("\(employee.compensationType.name)・月給\(employee.monthlySalary.currency)\(employee.commissionRate > 0 ? "＋成約粗利\(employee.commissionRate)%" : "")")
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
                    SectionTitle(title: "店長候補")
                    Label("店長はあなたに代わって店舗運営の責任を負います。", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let candidate {
                        HStack(spacing: 16) {
                            CharacterAvatarView(
                                role: .manager,
                                seed: candidate.characterAvatarSeed,
                                size: 100
                            )
                            VStack(alignment: .leading, spacing: 8) {
                                Text(candidate.name).font(.title3.bold())
                                Text("総合能力 \(candidate.overallAbility)・給与 \(candidate.monthlySalary.currency)/月")
                                    .font(.caption.bold()).foregroundStyle(.secondary)
                                AbilityBar(name: "人員管理", value: candidate.staffingAbility, color: .green)
                                AbilityBar(name: "販売管理", value: candidate.salesAbility, color: .blue)
                                AbilityBar(name: "仕入管理", value: candidate.procurementAbility, color: .purple)
                                AbilityBar(name: "調査管理", value: candidate.researchAbility, color: GameTheme.orange)
                                AbilityBar(name: "査定／整備管理", value: candidate.serviceAbility, color: GameTheme.teal)
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
                    SectionTitle(title: "店長")
                    HStack(spacing: 16) {
                        CharacterAvatarView(
                            role: .manager,
                            seed: manager.characterAvatarSeed,
                            size: 104
                        )
                        VStack(alignment: .leading, spacing: 9) {
                            Text(manager.name).font(.title3.bold())
                            Text("総合能力 \(manager.overallAbility)・給与 \(manager.monthlySalary.currency)/月")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            AbilityBar(name: "人員管理", value: manager.staffingAbility, color: .green)
                            AbilityBar(name: "販売管理", value: manager.salesAbility, color: .blue)
                            AbilityBar(name: "仕入管理", value: manager.procurementAbility, color: .purple)
                            AbilityBar(name: "調査管理", value: manager.researchAbility, color: GameTheme.orange)
                            AbilityBar(name: "査定／整備管理", value: manager.serviceAbility, color: GameTheme.teal)
                        }
                    }
                    Divider()
                    Text("専門店運営の目標").font(.subheadline.bold())
                    Picker("専門店方針", selection: Binding(
                        get: { store.managerMandate.specialty },
                        set: { specialty in
                            var mandate = store.managerMandate
                            mandate.specialty = specialty
                            _ = game.setManagerMandate(mandate, for: store.id)
                        }
                    )) {
                        ForEach(MarketProductKind.allCases) { kind in
                            Text(kind.name).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    Stepper(
                        "4週粗利目標 \(store.managerMandate.fourWeekGrossProfitTarget.currency)",
                        value: Binding(
                            get: { store.managerMandate.fourWeekGrossProfitTarget },
                            set: { value in
                                var mandate = store.managerMandate
                                mandate.fourWeekGrossProfitTarget = value
                                _ = game.setManagerMandate(mandate, for: store.id)
                            }
                        ),
                        in: 0...5_000,
                        step: 100
                    )
                    Stepper(
                        "最低保有現金 \(store.managerMandate.minimumCashReserve.currency)",
                        value: Binding(
                            get: { store.managerMandate.minimumCashReserve },
                            set: { value in
                                var mandate = store.managerMandate
                                mandate.minimumCashReserve = value
                                _ = game.setManagerMandate(mandate, for: store.id)
                            }
                        ),
                        in: 0...10_000,
                        step: 100
                    )
                    Toggle("必要時の外注を許可", isOn: Binding(
                        get: { store.managerMandate.allowsOutsourcing },
                        set: { value in
                            var mandate = store.managerMandate
                            mandate.allowsOutsourcing = value
                            _ = game.setManagerMandate(mandate, for: store.id)
                        }
                    ))
                    ForEach(store.managerProposals.filter { $0.status == .pending }) { proposal in
                        VStack(alignment: .leading, spacing: 7) {
                            Label(proposal.title, systemImage: "lightbulb.fill")
                                .font(.subheadline.bold()).foregroundStyle(GameTheme.orange)
                            Text(proposal.rationale).font(.caption).foregroundStyle(.secondary)
                            Text("4週想定粗利 \(proposal.expectedFourWeekGrossProfit.currency)・必要投資 \(proposal.requiredInvestment.currency)")
                                .font(.caption2.bold())
                            HStack {
                                Button("採用") { _ = game.respondToManagerProposal(proposal.id, at: store.id, accept: true) }
                                    .buttonStyle(.borderedProminent).tint(GameTheme.teal)
                                Button("見送り") { _ = game.respondToManagerProposal(proposal.id, at: store.id, accept: false) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(10)
                        .background(GameTheme.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Button(role: .destructive) {
                        confirmFireManager = true
                    } label: {
                        Label("店長を解雇", systemImage: "person.crop.circle.badge.minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }.gameCard()
            }
        }
        .confirmationDialog("店長を解雇しますか？", isPresented: $confirmFireManager, titleVisibility: .visible) {
            Button("店長を解雇", role: .destructive) { _ = game.fireManager(for: store.id) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべての業務委任が解除され、次週からオーナーの手動運営に戻ります。")
        }
        .sheet(isPresented: $showStorePurchasePolicyEditor) {
            StorePurchasePolicyEditor(storeID: store.id)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Store, Value>) -> Binding<Value> {
        Binding(get: { store[keyPath: keyPath] }, set: { value in var changed = store; changed[keyPath: keyPath] = value; update(changed) })
    }

    private func ability(_ employee: StoreEmployee, focus: EmployeeTrainingFocus) -> Int {
        switch focus {
        case .sales: employee.salesSkill
        case .procurement: employee.procurementSkill
        case .research: employee.researchSkill
        case .service: employee.serviceSkill
        }
    }

    private func effectDescription(_ employee: StoreEmployee) -> String {
        switch employee.assignment {
        case .sales:
            let effect = Int((game.employeeSalesCloseAdjustment(employee) * 100).rounded())
            let price = Int((game.employeeSalesPriceRealization(employee) * 100).rounded())
            return "週\(game.employeeWeeklyCaseCapacity(for: employee))件・成約\(effect >= 0 ? "+" : "")\(effect)pt・売価\(price >= 0 ? "+" : "")\(price)%"
        case .procurement:
            let close = Int((game.employeeProcurementCloseAdjustment(employee) * 100).rounded())
            return "週\(game.employeeWeeklyCaseCapacity(for: employee))件・仕入成約\(close >= 0 ? "+" : "")\(close)pt"
        case .research:
            return "広告効率とトレンド先読み精度を改善"
        case .service:
            return "機関・故障を判定・修理原価を最大\(game.employeeServiceCostDiscount(for: store.id))%削減"
        case .unassigned:
            return "担当を設定してください"
        }
    }
}

private struct StorePurchasePolicyEditor: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let storeID: UUID
    @State private var policy: StorePurchasePolicy

    init(storeID: UUID) {
        self.storeID = storeID
        _policy = State(initialValue: .standard)
    }

    private var selectedModels: [VehicleCatalogEntry] {
        game.availableVehicleCatalog.filter { policy.modelIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("採算と予算") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("1週間の買取予算")
                            Spacer()
                            Text(policy.weeklyBudget.currency).bold().monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(policy.weeklyBudget) },
                                set: { policy.weeklyBudget = Int($0.rounded()) }
                            ),
                            in: 0...5_000,
                            step: 100
                        )
                        Text("0万円では査定助言だけを表示し、自動買取は行いません。")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Stepper(
                        "最低粗利 \(policy.minimumGrossProfit.currency)／台",
                        value: $policy.minimumGrossProfit,
                        in: 0...1_000,
                        step: 5
                    )
                }
                Section("対象カテゴリ") {
                    ForEach(VehicleCategory.allCases) { category in
                        Toggle(category.name, isOn: Binding(
                            get: { policy.categories.contains(category) },
                            set: { enabled in
                                if enabled {
                                    policy.categories.insert(category)
                                } else {
                                    policy.categories.remove(category)
                                    let removedIDs = game.availableVehicleCatalog
                                        .filter { $0.category == category }
                                        .map(\.id)
                                    policy.modelIDs.subtract(removedIDs)
                                }
                            }
                        ))
                    }
                }
                Section("対象車種（任意）") {
                    if !policy.modelIDs.isEmpty {
                        Button("車種指定を解除") { policy.modelIDs.removeAll() }
                        Text("選択中：\(selectedModels.map(\.fullName).sorted().joined(separator: "、"))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(VehicleCategory.allCases.filter { policy.categories.contains($0) }) { category in
                        DisclosureGroup(category.name) {
                            ForEach(game.availableVehicleCatalog.filter { $0.category == category }) { model in
                                Toggle(model.fullName, isOn: Binding(
                                    get: { policy.modelIDs.contains(model.id) },
                                    set: { enabled in
                                        if enabled { policy.modelIDs.insert(model.id) }
                                        else { policy.modelIDs.remove(model.id) }
                                    }
                                ))
                            }
                        }
                    }
                    Text("車種を選ばない場合は、選択したカテゴリの全車種が対象です。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("店舗買取方針")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let store = game.stores.first(where: { $0.id == storeID }) {
                    policy = store.storePurchasePolicy
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard var store = game.stores.first(where: { $0.id == storeID }) else { return }
                        policy.spentBudget = min(policy.spentBudget, policy.weeklyBudget)
                        store.storePurchasePolicy = policy
                        game.updateStore(store)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ProcurementInstructionPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    @Binding var showCreate: Bool
    @State private var editingInstruction: ProcurementInstruction?

    private var instructions: [ProcurementInstruction] {
        game.procurementInstructions(for: store.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "AA仕入れ指示")

            if store.autoProcurement && instructions.filter({ $0.status == .active }).isEmpty {
                Label("自動仕入れはONですが、有効なAA仕入れ指示がありません", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(GameTheme.orange)
            }

            if instructions.isEmpty {
                Text("まだ指示はありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(instructions.enumerated()), id: \.element.id) { position, instruction in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(instruction.targetName)
                                    .font(.subheadline.bold())
                                Text("最低粗利 \(instruction.minimumGrossProfit.currency)／台")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(instruction.status.name)
                                .font(.caption2.bold())
                                .foregroundStyle(instruction.status == .active ? GameTheme.teal : .secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background((instruction.status == .active ? GameTheme.teal : Color.gray).opacity(0.12))
                                .clipShape(Capsule())
                            Menu {
                                Button("編集") { editingInstruction = instruction }
                                if instruction.status != .completed {
                                    Button(instruction.status == .paused ? "再開" : "一時停止") {
                                        _ = game.setProcurementInstructionStatus(
                                            instruction.id,
                                            status: instruction.status == .paused ? .active : .paused
                                        )
                                    }
                                    Button("完了") {
                                        _ = game.setProcurementInstructionStatus(instruction.id, status: .completed)
                                    }
                                }
                                Button("削除", role: .destructive) {
                                    game.deleteProcurementInstruction(instruction.id)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 72), alignment: .leading)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ProposalMetric(title: "週間予算", value: instruction.totalBudget.currency)
                            ProposalMetric(title: "今週支出", value: instruction.spentBudget.currency)
                            ProposalMetric(title: "入札中", value: instruction.reservedBudget.currency)
                            ProposalMetric(title: "今週残り", value: instruction.remainingBudget.currency)
                            ProposalMetric(title: "取得", value: "\(instruction.acquiredCount)台")
                        }
                        ProgressView(
                            value: Double(instruction.spentBudget + instruction.reservedBudget),
                            total: Double(max(1, instruction.totalBudget))
                        )
                        .tint(GameTheme.teal)
                        HStack {
                            Text(instruction.lastResult)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button {
                                _ = game.moveProcurementInstruction(instruction.id, direction: -1)
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .disabled(position == 0)
                            Button {
                                _ = game.moveProcurementInstruction(instruction.id, direction: 1)
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .disabled(position == instructions.count - 1)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(10)
                    .background(GameTheme.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            }
            let procurementEmployees = store.employees.filter { $0.assignment == .procurement }
            if !procurementEmployees.isEmpty {
                Divider()
                Label(
                    "社員専用ネットAA：\(procurementEmployees.map(\.name).joined(separator: "、"))",
                    systemImage: "network.badge.shield.half.filled"
                )
                .font(.caption.bold())
                .foregroundStyle(GameTheme.teal)
                Text("出品一覧は非公開です。担当者の仕入力に応じて案件発見数・車両確認・落札判断が向上します。入札\(game.networkAuctionBidReservations.filter { $0.storeID == store.id }.count)件、直近成約\(game.networkAuctionBidResults.filter { $0.storeID == store.id && $0.status == .won }.prefix(5).count)件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .gameCard()
        .sheet(isPresented: $showCreate) {
            ProcurementInstructionEditor(storeID: store.id, instruction: nil)
        }
        .sheet(item: $editingInstruction) { instruction in
            ProcurementInstructionEditor(storeID: store.id, instruction: instruction)
        }
    }
}

private struct ProcurementInstructionEditor: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let storeID: UUID
    let instruction: ProcurementInstruction?
    @State private var totalBudget: Int
    @State private var minimumGrossProfit: Int
    @State private var categories: Set<VehicleCategory>
    @State private var modelIDs: Set<String>

    init(storeID: UUID, instruction: ProcurementInstruction?) {
        self.storeID = storeID
        self.instruction = instruction
        _totalBudget = State(initialValue: instruction?.totalBudget ?? 1_000)
        _minimumGrossProfit = State(initialValue: instruction?.minimumGrossProfit ?? 30)
        _categories = State(initialValue: instruction?.categories ?? Set(VehicleCategory.allCases))
        _modelIDs = State(initialValue: instruction?.modelIDs ?? [])
    }

    private var selectedModels: [VehicleCatalogEntry] {
        game.availableVehicleCatalog.filter { modelIDs.contains($0.id) }
    }

    private var minimumBudget: Int {
        let committed = (instruction?.spentBudget ?? 0) + (instruction?.reservedBudget ?? 0)
        return Int(ceil(Double(committed) / 100.0)) * 100
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("採算と予算") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("1週間の仕入予算")
                            Spacer()
                            Text(totalBudget.currency).bold().monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(totalBudget) },
                                set: { totalBudget = Int($0.rounded()) }
                            ),
                            in: Double(minimumBudget)...Double(max(5_000, minimumBudget)),
                            step: 100
                        )
                    }
                    Stepper("最低粗利 \(minimumGrossProfit.currency)／台", value: $minimumGrossProfit, in: 0...1_000, step: 5)
                    Text("週間予算は毎週更新され、車両価格・手数料・輸送費を含みます。入札は次の週間処理で一度だけ確定します。最低粗利は予測修理費も差し引いて判定します。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Section("対象カテゴリ") {
                    ForEach(VehicleCategory.allCases) { category in
                        Toggle(category.name, isOn: Binding(
                            get: { categories.contains(category) },
                            set: { enabled in
                                if enabled { categories.insert(category) }
                                else {
                                    categories.remove(category)
                                    modelIDs.subtract(game.availableVehicleCatalog.filter { $0.category == category }.map(\.id))
                                }
                            }
                        ))
                    }
                }
                Section("対象車種（任意）") {
                    if !modelIDs.isEmpty {
                        Button("車種指定を解除") { modelIDs.removeAll() }
                        Text("選択中：\(selectedModels.map(\.fullName).sorted().joined(separator: "、"))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(VehicleCategory.allCases.filter { categories.contains($0) }) { category in
                        DisclosureGroup(category.name) {
                            ForEach(game.availableVehicleCatalog.filter { $0.category == category }) { model in
                                Toggle(model.fullName, isOn: Binding(
                                    get: { modelIDs.contains(model.id) },
                                    set: { enabled in
                                        if enabled { modelIDs.insert(model.id) } else { modelIDs.remove(model.id) }
                                    }
                                ))
                            }
                        }
                    }
                    Text("車種を選ばない場合は、選択したカテゴリの全車種が対象です。通常AAと社員専用ネットAAの両方を探索します。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(instruction == nil ? "AA仕入れ指示を追加" : "AA仕入れ指示を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if var changed = instruction {
                            changed.totalBudget = totalBudget
                            changed.minimumGrossProfit = minimumGrossProfit
                            changed.categories = categories
                            changed.modelIDs = modelIDs
                            _ = game.updateProcurementInstruction(changed)
                        } else {
                            _ = game.createProcurementInstruction(
                                storeID: storeID,
                                totalBudget: totalBudget,
                                minimumGrossProfit: minimumGrossProfit,
                                categories: categories,
                                modelIDs: modelIDs
                            )
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AutomationPolicyRow<PolicyContent: View>: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let policyName: String
    let policyContent: PolicyContent

    init(title: String, icon: String, isOn: Binding<Bool>, policyName: String, @ViewBuilder policyContent: () -> PolicyContent) {
        self.title = title
        self.icon = icon
        _isOn = isOn
        self.policyName = policyName
        self.policyContent = policyContent()
    }

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(GameTheme.teal)
            policyContent
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(!isOn)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.vertical, 4)
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

private enum MarketSection: String, CaseIterable, Identifiable {
    case district = "地区"
    case procurement = "仕入れ"
    case vehicles = "車両"

    var id: String { rawValue }
}

private struct MarketPanel: View {
    let store: Store
    let plot: LandPlot
    let campaign: (Int, String) -> Void
    @State private var section: MarketSection = CommandLine.arguments.contains("-demo-catalog") ? .vehicles : .district

    var body: some View {
        VStack(spacing: 14) {
            Picker("市場表示", selection: $section) {
                ForEach(MarketSection.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            switch section {
            case .district:
                DistrictSpecialtyPanel(store: store, district: plot.district)
                DistrictMarketSharePanel(store: store, plot: plot)
                MarketConditionsPanel(store: store, plot: plot, campaign: campaign)
            case .procurement:
                ProcurementPanel(store: store, plot: plot)
            case .vehicles:
                VehicleCatalogPanel(store: store, district: plot.district)
            }
        }
    }
}

private struct DistrictSpecialtyPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let district: DistrictKind

    var body: some View {
        let reports = game.districtSpecialtyReports(
            storeID: store.id,
            district: district
        )
        let demandReports = reports.sorted {
            $0.fourWeekDemand.upperBound > $1.fourWeekDemand.upperBound
        }
        let nearbyReports = reports
            .filter { !$0.isAbsent }
            .sorted {
                if $0.competitorBranchCount != $1.competitorBranchCount {
                    return $0.competitorBranchCount < $1.competitorBranchCount
                }
                return $0.fourWeekDemand.upperBound > $1.fourWeekDemand.upperBound
            }

        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "この地区の需要")
            Text("各業態の需要")
                .font(.subheadline.bold())
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 145), spacing: 8)],
                spacing: 8
            ) {
                ForEach(demandReports) { report in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            report.productKind.name,
                            systemImage: specialtyIcon(report.productKind)
                        )
                        .font(.caption.bold())
                        Text(
                            "4週間 \(report.fourWeekDemand.lowerBound)〜\(report.fourWeekDemand.upperBound)人"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(GameTheme.navy.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Divider()
            Text("近隣の専門店")
                .font(.subheadline.bold())
            if nearbyReports.isEmpty {
                Text("なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nearbyReports) { report in
                    HStack(spacing: 10) {
                        Image(systemName: specialtyIcon(report.productKind))
                            .foregroundStyle(GameTheme.teal)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.productKind.name)
                                .font(.subheadline.bold())
                            Text(report.competitorNames.joined(separator: "・"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(report.competitorBranchCount)店")
                                .font(.subheadline.bold().monospacedDigit())
                            Text(
                                "在庫 \(report.competingInventory.lowerBound)〜\(report.competingInventory.upperBound)台"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .gameCard()
    }

    private func specialtyIcon(_ productKind: MarketProductKind) -> String {
        switch productKind {
        case .camper: "tent.fill"
        case .workCargo: "shippingbox.fill"
        case .outdoor: "mountain.2.fill"
        case .collector: "star.circle.fill"
        case .sportTuned: "flag.checkered"
        case .welfare: "figure.roll"
        case .mobileSales: "truck.box.fill"
        case .kitchenCar: "fork.knife"
        case .standard, .repaired, .refurbished: "wrench.and.screwdriver.fill"
        }
    }
}

private struct DistrictMarketSharePanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let plot: LandPlot

    private var shares: [ShareSlice] {
        var result = [
            ShareSlice(
                name: store.name,
                value: game.marketShare(for: store) * 100,
                color: GameTheme.teal
            )
        ]
        let otherOwnShare = game.stores
            .filter { $0.id != store.id && game.plot(id: $0.plotID)?.district == plot.district }
            .reduce(0.0) { $0 + game.marketShare(for: $1) }
        if otherOwnShare > 0.001 {
            result.append(
                ShareSlice(name: "自社の他店舗", value: otherOwnShare * 100, color: .blue)
            )
        }
        let rivalColors: [Color] = [GameTheme.orange, .purple, .pink, .indigo]
        for (index, competitor) in game.competitors.enumerated() {
            let share = game.competitorMarketShare(competitor, in: plot.district)
            if share > 0.001 {
                result.append(
                    ShareSlice(
                        name: competitor.name,
                        value: share * 100,
                        color: rivalColors[index % rivalColors.count]
                    )
                )
            }
        }
        return result
    }

    private var selectedStoreShare: Int {
        Int((game.marketShare(for: store) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "地区のマーケットシェア")
            HStack(spacing: 15) {
                ZStack {
                    Chart(shares) { slice in
                        SectorMark(
                            angle: .value("シェア", slice.value),
                            innerRadius: .ratio(0.62),
                            angularInset: 1.5
                        )
                        .foregroundStyle(slice.color)
                    }
                    VStack {
                        Text("この店舗").font(.caption2)
                        Text("\(selectedStoreShare)%")
                            .font(.title2.bold())
                            .foregroundStyle(GameTheme.teal)
                    }
                }
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(shares) { slice in
                        HStack {
                            Circle().fill(slice.color).frame(width: 8, height: 8)
                            Text(slice.name).font(.caption).lineLimit(1)
                            Spacer()
                            Text("\(Int(slice.value.rounded()))%")
                                .font(.caption.bold().monospacedDigit())
                        }
                    }
                }
            }
        }
        .gameCard()
    }
}

private struct MarketConditionsPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let plot: LandPlot
    let campaign: (Int, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let weeklyDemand = game.marketForecastRange(
                value: game.weeklyBuyerPool(in: plot.district),
                storeID: store.id
            )
            SectionTitle(title: "市況")
            HStack {
                ProposalMetric(
                    title: "地区の1週間の需要",
                    value: "\(weeklyDemand.lowerBound)〜\(weeklyDemand.upperBound)人"
                )
            }

            Divider()
            Text("販促").font(.subheadline.bold())
            HStack(spacing: 10) {
                CampaignCard(
                    title: "地域SNS広告",
                    detail: "+60万円/月",
                    icon: "wifi",
                    color: .blue
                ) {
                    campaign(60, "地域SNS広告を開始しました")
                }
                CampaignCard(
                    title: "ロードサイド看板",
                    detail: "+100万円/月",
                    icon: "signpost.right.fill",
                    color: GameTheme.orange
                ) {
                    campaign(100, "幹線道路に大型看板を設置しました")
                }
            }
            if let sale = store.inventorySaleCampaign {
                Label(
                    "\(sale.tier.name)在庫セール・残り\(sale.remainingWeeks)週"
                        + "・来客\(String(format: "%.1f", sale.tier.trafficMultiplier))倍"
                        + "・成約+\(Int(sale.tier.closeBonus * 100))pt",
                    systemImage: "tag.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(GameTheme.orange)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    Text("4週間の在庫セール").font(.caption.bold())
                    HStack(spacing: 7) {
                        ForEach(InventorySaleTier.allCases) { tier in
                            Button {
                                _ = game.startInventorySaleCampaign(
                                    storeID: store.id,
                                    tier: tier
                                )
                            } label: {
                                VStack(spacing: 2) {
                                    Text(tier.name).font(.caption2.bold())
                                    Text(
                                        "来客\(String(format: "%.1f", tier.trafficMultiplier))倍"
                                    )
                                    .font(.system(size: 9, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(GameTheme.orange)
                            .disabled(
                                !game.canStartInventorySaleCampaign(
                                    storeID: store.id,
                                    tier: tier
                                )
                            )
                        }
                    }
                    Text(
                        store.inventorySaleCooldownWeeks > 0
                            ? "再開催まで\(store.inventorySaleCooldownWeeks)週"
                            : "販売可能在庫が店舗容量の40%以上で開始できます"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .gameCard()
    }
}

private struct ProcurementPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let plot: LandPlot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "共有法人案件",
                subtitle: "法人放出は複数台一括。応募には法人窓口が必要です"
            )
            if !store.facilities.contains(.corporateDesk) {
                Label("応募には法人窓口が必要です", systemImage: "building.2.fill")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if game.corporateOpportunities.filter({ !$0.resolved }).isEmpty {
                Text("現在募集中の案件はありません").font(.caption2).foregroundStyle(.secondary)
            } else {
                ForEach(game.corporateOpportunities.filter { !$0.resolved }) { opportunity in
                    CorporateOpportunityRow(opportunity: opportunity, store: store)
                }
            }

        }
        .gameCard()
    }
}

private struct CorporateOpportunityRow: View {
    @EnvironmentObject private var game: GameEngine
    let opportunity: CorporateOpportunity
    let store: Store
    @State private var unitPrice: Int

    init(opportunity: CorporateOpportunity, store: Store) {
        self.opportunity = opportunity
        self.store = store
        _unitPrice = State(initialValue: opportunity.unitPrice)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(opportunity.kind.name, systemImage: opportunity.kind == .fleetDisposal ? "truck.box.fill" : "building.2.fill")
                    .font(.caption.bold())
                Spacer()
                Text("締切 次週").font(.caption2.bold()).foregroundStyle(GameTheme.orange)
            }
            Text("\(opportunity.vehicleName) \(opportunity.count)台・\(opportunity.purpose.name)用途・基準\(opportunity.unitPrice.currency)/台")
                .font(.caption2).foregroundStyle(.secondary)
            if let year = opportunity.modelYear, let mileage = opportunity.mileage {
                Text("\(year)年・\(mileage.formatted())km・状態\(Int((opportunity.quality * 100).rounded()))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Stepper(value: $unitPrice, in: max(10, opportunity.unitPrice * 60 / 100)...opportunity.unitPrice * 140 / 100, step: 5) {
                Text(opportunity.kind == .fleetDisposal ? "買取提示 \(unitPrice.currency)/台" : "販売提案 \(unitPrice.currency)/台")
                    .font(.caption.bold())
            }
            if let gross = game.corporateDisposalExpectedGrossProfit(
                for: opportunity,
                unitPrice: unitPrice,
                storeID: store.id
            ) {
                let retail = gross + unitPrice
                let margin = Int((Double(gross) / Double(max(1, retail)) * 100).rounded())
                Label(
                    "価格方針100での予測粗利 \(gross.currency)/台（\(margin)%）",
                    systemImage: gross >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(.caption2.bold())
                .foregroundStyle(gross >= 0 ? GameTheme.teal : GameTheme.danger)
            }
            Button(opportunity.playerStoreID == store.id ? "提案を更新" : "この店舗で応募") {
                _ = game.submitCorporateBid(opportunityID: opportunity.id, storeID: store.id, unitPrice: unitPrice)
            }
            .buttonStyle(.bordered).font(.caption.bold())
        }
        .padding(9)
        .background(GameTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct VehicleCatalogPanel: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    let district: DistrictKind
    @State private var selectedCategory: VehicleCategory?
    @State private var selectedOrigin: VehicleOrigin?
    @State private var selectedPowertrain: VehiclePowertrain?

    private var models: [VehicleCatalogEntry] {
        game.availableVehicleCatalog.filter {
            (selectedCategory == nil || $0.category == selectedCategory) &&
            (selectedOrigin == nil || $0.origin == selectedOrigin) &&
            (selectedPowertrain == nil || $0.powertrain == selectedPowertrain)
        }
    }

    private var displayedModels: [VehicleCatalogEntry] { Array(models.prefix(36)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "車両市場カタログ")
            HStack(spacing: 8) {
                Picker("カテゴリ", selection: $selectedCategory) {
                    Text("全カテゴリ").tag(Optional<VehicleCategory>.none)
                    ForEach(VehicleCategory.allCases) { category in
                        Label(category.name, systemImage: category.icon).tag(Optional(category))
                    }
                }
                .pickerStyle(.menu)
                Picker("産地", selection: $selectedOrigin) {
                    Text("全産地").tag(Optional<VehicleOrigin>.none)
                    ForEach(VehicleOrigin.allCases) { origin in
                        Label(origin.name, systemImage: origin.icon).tag(Optional(origin))
                    }
                }
                .pickerStyle(.menu)
                Picker("動力", selection: $selectedPowertrain) {
                    Text("全動力").tag(Optional<VehiclePowertrain>.none)
                    ForEach(VehiclePowertrain.allCases) { powertrain in
                        Label(powertrain.name, systemImage: powertrain.icon).tag(Optional(powertrain))
                    }
                }
                .pickerStyle(.menu)
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

private struct CatalogVehicleRow: View {
    @EnvironmentObject private var game: GameEngine
    let model: VehicleCatalogEntry
    let store: Store
    let district: DistrictKind

    private var marketIndex: Double { game.catalogMarketIndex(for: model, in: district) }
    private var trend: Int { game.catalogPriceTrendPercent(for: model, in: district) }
    private var hasResearcher: Bool { game.hasMarketResearcher(storeID: store.id) }
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
                    .accessibilityLabel(model.powertrain.name)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.maker)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(model.modelName)
                            .font(.subheadline.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text(model.origin.shortName)
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(model.origin == .imported ? .white : GameTheme.navy)
                            .padding(.horizontal, 5).padding(.vertical, 3)
                            .background(model.origin == .imported ? Color.purple : GameTheme.navy.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    Text(model.classicProductionYears.map { "\(model.category.name)・\($0.lowerBound)〜\($0.upperBound)年製" } ?? model.category.name)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if hasResearcher {
                    VStack(alignment: .trailing, spacing: 2) {
                    Label(status, systemImage: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.bold()).foregroundStyle(color)
                    Text("価格 \(trend >= 0 ? "+" : "")\(trend)%")
                        .font(.caption2.bold().monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 6) {
                if model.isRareClassic {
                    CapsuleLabel(text: "希少旧車", color: GameTheme.orange, icon: "star.circle.fill")
                } else if model.isPopularCustomBase {
                    CapsuleLabel(text: "カスタム人気", color: .purple, icon: "paintbrush.fill")
                }
                if !model.isRareClassic && game.turn - model.usedMarketTurn <= 3 {
                    CapsuleLabel(text: "中古流入", color: GameTheme.orange, icon: "arrow.triangle.2.circlepath")
                }
            }
            HStack {
                ProposalMetric(title: "新車販売価格", value: model.referenceRetailPrice.currency)
                if hasResearcher {
                    ProposalMetric(title: "仕入価格相場", value: game.catalogWholesalePrice(for: model, in: district).currency)
                    ProposalMetric(title: "販売価格相場", value: game.catalogRetailPrice(for: model, in: district).currency)
                }
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
    @State private var confirmHumanResourcesDelegation = false
    let store: Store
    let update: (Store) -> Void
    let openSettings: () -> Void
    let openTeam: () -> Void

    private var facilityStatus: (text: String, icon: String, color: Color)? {
        if let remaining = store.openingMonthsRemaining {
            return (
                "建設中・完成まで\(remaining)週間",
                "hammer.fill",
                GameTheme.orange
            )
        }
        if let remaining = store.renovationMonthsRemaining,
           let target = store.pendingType {
            return (
                "\(target.name)へ改装中・完成まで\(remaining)週間",
                "wrench.and.screwdriver.fill",
                GameTheme.orange
            )
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                MetricView(title: "売上高", value: store.lastRevenue.currency)
                MetricView(title: "営業利益", value: store.lastProfit.currency, tint: store.lastProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                MetricView(title: "在庫回転", value: store.lastSales > 0 ? "\(store.inventoryCount * 30 / store.lastSales)日" : "—")
            }.gameCard()
            if let forecast = game.fourWeekForecast(for: store.id) {
                VStack(alignment: .leading, spacing: 11) {
                    SectionTitle(title: "4週間の店舗予測")
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
                SectionTitle(title: "オーナーの経営方針")
                Text("価格水準  \(Int(store.priceIndex * 100))").font(.subheadline.bold())
                Slider(value: binding(\.priceIndex), in: 0.88...1.18, step: 0.01).tint(GameTheme.teal)
                HStack { Text("販売量重視").font(.caption2).foregroundStyle(.secondary); Spacer(); Text("粗利重視").font(.caption2).foregroundStyle(.secondary) }
                Divider()
                Text("広告予算  \(store.advertising.currency)/月").font(.subheadline.bold())
                Slider(value: Binding(get: { Double(store.advertising) }, set: { value in var changed = store; changed.advertising = Int(value); update(changed) }), in: 0...500, step: 20).tint(GameTheme.orange)
                Text("設定額だけが月次PLに計上されます。初期値は0で、集客を店長へ委任すると店長が予算を調整します。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .gameCard()

            VStack(alignment: .leading, spacing: 5) {
                SectionTitle(title: "店長への指示")
                if store.hasManager {
                    DelegationToggle(
                        title: "人事権（採用・配置・解雇）",
                        icon: "person.2.fill",
                        isOn: Binding(
                            get: { store.delegateStaff },
                            set: { enabled in
                                if enabled {
                                    confirmHumanResourcesDelegation = true
                                } else {
                                    var changed = store
                                    changed.delegateStaff = false
                                    update(changed)
                                }
                            }
                        )
                    )
                    Text("OFFの間、店長は採用・配置変更・解雇を一切行いません。ONにすると、余剰人員の解雇も自動判断に含まれます。")
                        .font(.caption2)
                        .foregroundStyle(store.delegateStaff ? GameTheme.orange : .secondary)
                    DelegationToggle(
                        title: "販売方針と価格設定",
                        icon: "tag.fill",
                        isOn: binding(\.delegatePricing)
                    )
                    DelegationToggle(
                        title: "集客方針と広告予算",
                        icon: "megaphone.fill",
                        isOn: binding(\.delegateMarketing)
                    )
                    DelegationToggle(
                        title: "仕入条件と仕入先",
                        icon: "car.badge.gearshape",
                        isOn: binding(\.delegateProcurement)
                    )
                    DelegationToggle(
                        title: "査定・整備方針と配分",
                        icon: "wrench.and.screwdriver.fill",
                        isOn: binding(\.delegateService)
                    )
                } else {
                    HStack {
                        Label("店長がいません", systemImage: "person.crop.circle.badge.questionmark")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("店員タブへ", action: openTeam)
                            .buttonStyle(.bordered)
                            .font(.caption.bold())
                    }
                    .padding(.vertical, 6)
                }
            }
            .gameCard()
            .confirmationDialog(
                "店長へ人事権を渡しますか？",
                isPresented: $confirmHumanResourcesDelegation,
                titleVisibility: .visible
            ) {
                Button("採用・配置・解雇を委任") {
                    var changed = store
                    changed.delegateStaff = true
                    update(changed)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("余剰人員と判断した店員の解雇も自動で行われます。OFFのままなら店長は人員を変更しません。")
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(title: "店舗・設備")
                    Spacer()
                    Button(action: openSettings) {
                        Label("詳細", systemImage: "wrench.and.screwdriver.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.navy)
                    .font(.caption.bold())
                }
                HStack {
                    MetricView(title: "店舗", value: store.type.name)
                    MetricView(title: "区画", value: "\(store.plotIDs.count)区画")
                    MetricView(title: "施設", value: "\(store.facilities.count)")
                }
                if let facilityStatus {
                    Label(facilityStatus.text, systemImage: facilityStatus.icon)
                        .font(.caption.bold())
                        .foregroundStyle(facilityStatus.color)
                }
                if store.facilities.isEmpty {
                    Text("設置施設なし")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(store.facilities.sorted(by: { $0.name < $1.name })) { facility in
                            Label(facility.name, systemImage: facility.icon)
                                .font(.caption.bold())
                                .foregroundStyle(GameTheme.teal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(GameTheme.teal.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }
            }
            .gameCard()
        }
    }

    private func binding<Value>(
        _ keyPath: WritableKeyPath<Store, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store[keyPath: keyPath] },
            set: { value in
                var changed = store
                changed[keyPath: keyPath] = value
                update(changed)
            }
        )
    }
}
