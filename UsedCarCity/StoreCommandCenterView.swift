import SwiftUI
import Charts

struct StoreCommandCenterView: View {
    @EnvironmentObject private var game: GameEngine
    let storeID: UUID
    @State private var panel: StorePanel = .store
    @State private var showSettings = false
    @State private var actionMessage: String?

    private var store: Store? { game.stores.first(where: { $0.id == storeID }) }
    private var plot: LandPlot? { store.flatMap { game.plot(id: $0.plotID) } }

    var body: some View {
        if let store, let plot {
            VStack(spacing: 14) {
                StoreSceneHeader(store: store, plot: plot, managerName: managerName)
                StorePanelPicker(selection: $panel)
                Group {
                    switch panel {
                    case .store:
                        VStack(spacing: 14) {
                            PurchaseCasesPanel(storeID: store.id)
                            StoreOverviewPanel(store: store, plot: plot)
                        }
                    case .team: ManagerPanel(store: store, managerName: managerName, update: update)
                    case .market: MarketPanel(store: store, plot: plot, campaign: runCampaign)
                    case .finance: StoreFinancePanel(store: store, update: update)
                    }
                }
                StoreActionDock(
                    settings: { showSettings = true },
                    advertise: { runCampaign(amount: 40, message: "地域広告を強化しました") },
                    purchase: purchaseRecommended
                )
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
        guard var current = store else { return }
        current.advertising = min(500, current.advertising + amount)
        game.updateStore(current)
        actionMessage = "\(message)。広告予算は月\(current.advertising.currency)です。"
    }

    private func purchaseRecommended() {
        guard let store, let plot, let category = game.recommendedCategories(for: plot.district).first else { return }
        if game.buyInventory(category: category, count: 3, storeID: store.id) {
            actionMessage = "\(category.name)を3台仕入れました。"
        } else {
            actionMessage = "現金または展示スペースが不足しています。"
        }
    }
}

private struct PurchaseCasesPanel: View {
    @EnvironmentObject private var game: GameEngine
    let storeID: UUID
    @State private var message: String?
    private var cases: [PurchaseCase] { game.purchaseCases.filter { $0.storeID == storeID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "本日の買取", subtitle: "顧客からの査定依頼")
                if !cases.isEmpty { Text("\(cases.count)件").font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 5).background(GameTheme.orange).clipShape(Capsule()) }
            }
            if cases.isEmpty {
                Label("現在、未処理の買取案件はありません", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(GameTheme.teal).padding(.vertical, 12)
            } else {
                ForEach(cases) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: item.category.icon).font(.title3).foregroundStyle(GameTheme.teal).frame(width: 40, height: 40).background(GameTheme.teal.opacity(0.1)).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) { Text("\(item.modelYear)年式 \(item.category.name)").font(.subheadline.bold()); Text("走行 \(item.mileage.formatted())km・状態 \(item.conditionScore)").font(.caption).foregroundStyle(.secondary) }
                            Spacer(); VStack(alignment: .trailing) { Text("希望 \(item.askingPrice.currency)").font(.caption.bold()); Text("粗利予測 \(item.expectedGrossProfit.currency)").font(.caption2).foregroundStyle(item.expectedGrossProfit >= 0 ? GameTheme.teal : GameTheme.danger) }
                        }
                        HStack { PurchaseMetric(title: "整備", value: item.repairCost.currency); PurchaseMetric(title: "販売予測", value: item.expectedSalePrice.currency); PurchaseMetric(title: "期間", value: "\(item.expectedDays)日"); PurchaseMetric(title: "査定精度", value: "\(item.appraisalAccuracy)%") }
                        HStack(spacing: 6) {
                            CaseActionButton("買取", color: GameTheme.teal) { message = game.acceptPurchaseCase(item.id) ? "提示額で買い取りました" : "現金または展示枠が不足しています" }
                            CaseActionButton("交渉", color: GameTheme.orange) { message = game.acceptPurchaseCase(item.id, negotiated: true) ? "希望額の88%で交渉成立しました" : "交渉不成立、または資金不足です" }
                            CaseActionButton("詳細検査", color: .blue) { game.inspectPurchaseCase(item.id); message = "査定士が詳細検査しました" }
                            Button(role: .destructive) { game.declinePurchaseCase(item.id) } label: { Image(systemName: "xmark").font(.caption.bold()).padding(8) }.buttonStyle(.bordered)
                        }
                    }
                    .padding(11).background(GameTheme.cream).clipShape(RoundedRectangle(cornerRadius: 13))
                }
            }
        }
        .gameCard()
        .alert("買取結果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
}

private struct PurchaseMetric: View {
    let title: String; let value: String
    var body: some View { VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 8)).foregroundStyle(.secondary); Text(value).font(.caption2.bold().monospacedDigit()) }.frame(maxWidth: .infinity, alignment: .leading) }
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
                    Text("\(plot.district.name)・\(plot.localNumber)番区画").font(.caption).foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                CapsuleLabel(text: store.concept.name, color: GameTheme.mint, icon: store.concept.icon)
            }
            .padding(15).background(GameTheme.ink)
            ZStack(alignment: .top) {
                StoreScene(store: store)
                    .frame(height: 238)
                HStack(spacing: 9) {
                    Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(GameTheme.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("店長 \(managerName)").font(.caption.bold()).foregroundStyle(.white.opacity(0.7))
                        Text(greeting).font(.subheadline.bold()).foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(11).background(.black.opacity(0.66))
            }
            HStack {
                MetricView(title: "客足", value: "\(max(0, store.lastSales * 8 + 42))人/月", tint: .white)
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
        if store.inventoryCount < 5 { return "在庫が少なく、販売機会を逃しています" }
        if store.lastProfit < 0 { return "今月は赤字です。価格と広告を見直しましょう" }
        if store.satisfaction >= 80 { return "口コミが好調です。この流れを維持しましょう" }
        return "今月もお客様の動きを確認していきましょう"
    }
}

private struct StoreScene: View {
    let store: Store

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Color(red: 0.62, green: 0.80, blue: 0.88), Color(red: 0.81, green: 0.87, blue: 0.74)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let road = Path(CGRect(x: 0, y: size.height * 0.72, width: size.width, height: size.height * 0.28))
            context.fill(road, with: .color(GameTheme.road))
            var line = Path(); line.move(to: CGPoint(x: 0, y: size.height * 0.86)); line.addLine(to: CGPoint(x: size.width, y: size.height * 0.86))
            context.stroke(line, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 2, dash: [12, 9]))

            let center = CGPoint(x: size.width * 0.50, y: size.height * 0.66)
            let roof = polygon([CGPoint(x: center.x, y: 28), CGPoint(x: size.width * 0.84, y: 78), CGPoint(x: center.x, y: 124), CGPoint(x: size.width * 0.16, y: 78)])
            let left = polygon([CGPoint(x: size.width * 0.16, y: 78), CGPoint(x: center.x, y: 124), center, CGPoint(x: size.width * 0.16, y: 161)])
            let right = polygon([CGPoint(x: center.x, y: 124), CGPoint(x: size.width * 0.84, y: 78), CGPoint(x: size.width * 0.84, y: 161), center])
            context.fill(left, with: .color(GameTheme.teal.opacity(0.72)))
            context.fill(right, with: .color(GameTheme.teal.opacity(0.52)))
            context.fill(roof, with: .color(GameTheme.navy))
            for index in 0..<4 {
                let x = size.width * (0.23 + CGFloat(index) * 0.12)
                let window = CGRect(x: x, y: 129 + CGFloat(index) * 3, width: 25, height: 30)
                context.fill(Path(roundedRect: window, cornerRadius: 2), with: .color(Color.cyan.opacity(0.65)))
            }
            context.draw(Text(store.name).font(.caption.bold()).foregroundStyle(.white), at: CGPoint(x: center.x, y: 87))
            for index in 0..<5 {
                let x = size.width * (0.15 + CGFloat(index) * 0.17)
                let person = CGRect(x: x, y: size.height * 0.76 + CGFloat(index % 2) * 8, width: 7, height: 13)
                context.fill(Path(roundedRect: person, cornerRadius: 3), with: .color(index.isMultiple(of: 2) ? GameTheme.orange : GameTheme.mint))
            }
        }
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        var path = Path(); guard let first = points.first else { return path }; path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }; path.closeSubpath(); return path
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
                SectionTitle(title: "今月の経営要因", subtitle: "販売台数が動いた理由")
                if store.causes.isEmpty {
                    Text("月を進めると分析結果が表示されます").font(.subheadline).foregroundStyle(.secondary)
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
    let store: Store
    let managerName: String
    let update: (Store) -> Void

    var body: some View {
        VStack(spacing: 14) {
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
    let store: Store
    let plot: LandPlot
    let campaign: (Int, String) -> Void

    private var shares: [ShareSlice] {
        let player = max(12, min(55, 16 + store.lastSales * 2))
        let remain = 100 - player
        let a = remain * 38 / 100, b = remain * 34 / 100
        return [
            ShareSlice(name: "自社", value: player, color: GameTheme.teal),
            ShareSlice(name: "バリューオート", value: a, color: GameTheme.orange),
            ShareSlice(name: "プレミア", value: b, color: .purple),
            ShareSlice(name: "その他", value: remain - a - b, color: .gray.opacity(0.55))
        ]
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "\(plot.district.name)の市場シェア", subtitle: "商圏内の推定販売シェア")
                HStack(spacing: 15) {
                    ZStack {
                        Chart(shares) { slice in
                            SectorMark(angle: .value("シェア", slice.value), innerRadius: .ratio(0.62), angularInset: 1.5)
                                .foregroundStyle(slice.color)
                        }
                        VStack { Text("自社").font(.caption2); Text("\(shares[0].value)%").font(.title2.bold()).foregroundStyle(GameTheme.teal) }
                    }.frame(width: 150, height: 150)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(shares) { slice in
                            HStack { Circle().fill(slice.color).frame(width: 8, height: 8); Text(slice.name).font(.caption); Spacer(); Text("\(slice.value)%").font(.caption.bold().monospacedDigit()) }
                        }
                    }
                }
            }.gameCard()
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "マーケティング施策", subtitle: "客足と認知度を高める")
                HStack(spacing: 10) {
                    CampaignCard(title: "地域SNS広告", detail: "+60万円/月", icon: "wifi", color: .blue) { campaign(60, "地域SNS広告を開始しました") }
                    CampaignCard(title: "ロードサイド看板", detail: "+100万円/月", icon: "signpost.right.fill", color: GameTheme.orange) { campaign(100, "幹線道路に大型看板を設置しました") }
                }
            }.gameCard()
        }
    }
}

private struct ShareSlice: Identifiable {
    let id = UUID()
    let name: String
    let value: Int
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
            VStack(alignment: .leading, spacing: 13) {
                SectionTitle(title: "経営レバー", subtitle: "次月の販売量と利益率を調整")
                Text("価格水準  \(Int(store.priceIndex * 100))").font(.subheadline.bold())
                Slider(value: binding(\.priceIndex), in: 0.88...1.18, step: 0.01).tint(GameTheme.teal)
                HStack { Text("販売量重視").font(.caption2).foregroundStyle(.secondary); Spacer(); Text("粗利重視").font(.caption2).foregroundStyle(.secondary) }
                Divider()
                Text("広告予算  \(store.advertising.currency)/月").font(.subheadline.bold())
                Slider(value: Binding(get: { Double(store.advertising) }, set: { value in var changed = store; changed.advertising = Int(value); update(changed) }), in: 0...500, step: 20).tint(GameTheme.orange)
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
    let purchase: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            DockButton(title: "詳細設定", icon: "slider.horizontal.3", color: GameTheme.navy, action: settings)
            DockButton(title: "宣伝", icon: "megaphone.fill", color: GameTheme.orange, action: advertise)
            DockButton(title: "仕入", icon: "car.2.fill", color: GameTheme.teal, action: purchase)
        }
        .padding(8).background(GameTheme.ink).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct DockButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 11).background(color.opacity(0.82)).clipShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
}
