import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var selectedStoreID: UUID?

    private var selectedStore: Store? {
        let id = selectedStoreID ?? game.stores.first?.id
        return game.stores.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    storePicker
                    if let store = selectedStore {
                        InventorySummary(store: store)
                        VStack(alignment: .leading, spacing: 11) {
                            SectionTitle(title: "現在の在庫", subtitle: "地区需要と在庫構成を合わせましょう")
                            if store.inventory.isEmpty {
                                ContentUnavailableView("在庫がありません", systemImage: "car.side", description: Text("下の市場から仕入れてください"))
                            } else {
                                ForEach(store.inventory) { batch in InventoryRow(batch: batch, store: store) }
                            }
                        }
                        .gameCard()
                        PurchaseMarket(store: store)
                    }
                }
                .padding(14)
            }
            .background(GameTheme.cream)
            .navigationTitle("在庫・仕入")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if selectedStoreID == nil { selectedStoreID = game.stores.first?.id } }
        }
    }

    private var storePicker: some View {
        Picker("店舗", selection: Binding(get: { selectedStoreID ?? game.stores.first?.id }, set: { selectedStoreID = $0 })) {
            ForEach(game.stores) { store in Text(store.name).tag(Optional(store.id)) }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }
}

private struct InventorySummary: View {
    let store: Store
    var body: some View {
        HStack {
            MetricView(title: "展示在庫", value: "\(store.inventoryCount)台", detail: "上限 \(store.type.capacity)台")
            MetricView(title: "空きスペース", value: "\(max(0, store.type.capacity - store.inventoryCount))台")
            MetricView(title: "在庫回転", value: store.lastSales > 0 ? "\(max(1, store.inventoryCount * 30 / store.lastSales))日" : "—")
        }
        .gameCard()
    }
}

private struct InventoryRow: View {
    @EnvironmentObject private var game: GameEngine
    let batch: InventoryBatch
    let store: Store

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: batch.category.icon).foregroundStyle(GameTheme.teal).frame(width: 36, height: 36).background(GameTheme.teal.opacity(0.1)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(batch.vehicleName).font(.subheadline.bold())
                Text("\(batch.category.name)・品質 \(Int(batch.quality * 100))/100・仕入れ値 \(batch.averageCost.currency)・#\(batch.id.uuidString.prefix(4).uppercased())").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("1台").font(.headline.monospacedDigit())
            if game.stores.count > 1 {
                Menu {
                    ForEach(game.stores.filter { $0.id != store.id }) { destination in
                        Button(destination.name) {
                            _ = game.transferInventory(inventoryID: batch.id, from: store.id, to: destination.id)
                        }
                        .disabled(destination.inventoryCount >= destination.type.capacity)
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .foregroundStyle(GameTheme.teal)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct PurchaseMarket: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store
    @State private var purchased: VehicleCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "業者オークション", subtitle: "3台を個別の在庫車として仕入れ")
                Text("現金 \(game.cash.currency)").font(.caption.bold()).foregroundStyle(.secondary)
            }
            ForEach(VehicleCategory.allCases) { category in
                HStack(spacing: 11) {
                    Image(systemName: category.icon).frame(width: 28).foregroundStyle(GameTheme.navy)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name).font(.subheadline.bold())
                        Text("相場 \(category.purchaseCost.currency)/台").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("3台・\((category.purchaseCost * 3).currency)") {
                        if game.buyInventory(category: category, count: 3, storeID: store.id) { purchased = category }
                    }
                    .font(.caption.bold())
                    .buttonStyle(.bordered)
                    .tint(GameTheme.teal)
                    .disabled(game.cash < category.purchaseCost * 3 || store.inventoryCount + 3 > store.type.capacity)
                }
                .padding(.vertical, 3)
            }
        }
        .gameCard()
        .alert("仕入が完了しました", isPresented: Binding(get: { purchased != nil }, set: { if !$0 { purchased = nil } })) {
            Button("OK") { purchased = nil }
        } message: { Text("\(purchased?.name ?? "車両")3台を、販売・移動を1台ずつ行う個別在庫として登録しました。") }
    }
}

struct StoresView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var selectedStore: Store?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(game.stores) { store in
                        Button { selectedStore = store } label: { StoreOperatingCard(store: store) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
            .background(GameTheme.cream)
            .navigationTitle("店舗経営")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedStore) { store in StoreSettingsView(storeID: store.id) }
        }
    }
}

private struct StoreOperatingCard: View {
    @EnvironmentObject private var game: GameEngine
    let store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.name).font(.headline).foregroundStyle(GameTheme.ink)
                    Text(store.hasManager ? "\(store.concept.name)・\(store.focus.name)狙い" : "オーナー直営・方針設定なし")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            HStack {
                MetricView(title: "販売", value: "\(store.lastSales)台")
                MetricView(title: "売上", value: store.lastRevenue.currency)
                MetricView(title: "営業利益", value: store.lastProfit.currency, tint: store.lastProfit >= 0 ? GameTheme.teal : GameTheme.danger)
            }
            HStack(spacing: 10) {
                Label("在庫 \(store.inventoryCount)/\(store.type.capacity)", systemImage: "car.2.fill")
                Label("満足度 \(store.satisfaction)", systemImage: "hand.thumbsup.fill")
                Label("スタッフ \(store.staff)", systemImage: "person.2.fill")
            }
            .font(.caption.bold()).foregroundStyle(.secondary)
            if let strongest = store.causes.max(by: { abs($0.effect) < abs($1.effect) }) {
                HStack {
                    Image(systemName: strongest.effect >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    Text(strongest.title)
                    Spacer()
                    Text(String(format: "%+.1f台", strongest.effect)).monospacedDigit()
                }
                .font(.caption.bold())
                .foregroundStyle(strongest.effect >= 0 ? GameTheme.teal : GameTheme.orange)
                .padding(9).background((strongest.effect >= 0 ? GameTheme.teal : GameTheme.orange).opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .gameCard()
    }
}

struct StoreSettingsView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let storeID: UUID
    @State private var draft: Store?
    @State private var confirmClose = false
    @State private var renovationMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let store = Binding($draft) {
                    VStack(spacing: 16) {
                        if let remaining = store.wrappedValue.openingMonthsRemaining {
                            Label("新店舗を建設中・完成まで\(remaining)週間", systemImage: "hammer.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(GameTheme.navy)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(13)
                                .background(Color.yellow.opacity(0.34))
                                .clipShape(RoundedRectangle(cornerRadius: 13))
                        } else if let remaining = store.wrappedValue.renovationMonthsRemaining,
                                  let target = store.wrappedValue.pendingType {
                            Label("\(target.name)へ改装中・完成まで\(remaining)週間", systemImage: "wrench.and.screwdriver.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(GameTheme.navy)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(13)
                                .background(GameTheme.orange.opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 13))
                        }
                        if store.wrappedValue.hasManager {
                            VStack(alignment: .leading, spacing: 13) {
                                SectionTitle(title: "店長の販売方針", subtitle: "委任した業務の判断基準")
                                Text("価格水準  \(Int(store.wrappedValue.priceIndex * 100))").font(.subheadline.bold())
                                Slider(value: store.priceIndex, in: 0.88...1.18, step: 0.01).tint(GameTheme.teal)
                                HStack { Text("割安・販売量↑").font(.caption).foregroundStyle(.secondary); Spacer(); Text("高値・粗利↑").font(.caption).foregroundStyle(.secondary) }
                                Picker("狙う客層", selection: store.focus) { ForEach(CustomerFocus.allCases) { Text($0.name).tag($0) } }.pickerStyle(.menu)
                                Picker("店舗コンセプト", selection: store.concept) { ForEach(StoreConcept.allCases) { Text($0.name).tag($0) } }.pickerStyle(.menu)
                                Text(store.wrappedValue.concept.summary).font(.caption).foregroundStyle(.secondary)
                            }
                            .gameCard()
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle(title: "オーナー直営", subtitle: "仕入れと商談は1台ずつ自分で判断")
                                Label("店長を採用するまでは、販売方針や自動広告の設定はありません。", systemImage: "person.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .gameCard()
                        }
                        if game.stores.count > 1 {
                            Button(role: .destructive) { confirmClose = true } label: {
                                Label("この店舗を撤退・売却する", systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        if store.wrappedValue.hasManager {
                            VStack(alignment: .leading, spacing: 13) {
                                SectionTitle(title: "広告と整備", subtitle: "店長が継続管理する投資配分")
                                Text("広告予算  \(store.wrappedValue.advertising.currency)/月").font(.subheadline.bold())
                                Slider(value: Binding(get: { Double(store.wrappedValue.advertising) }, set: { store.wrappedValue.advertising = Int($0) }), in: 0...400, step: 20).tint(GameTheme.orange)
                                Text("整備スペース配分  \(Int(store.wrappedValue.serviceAllocation * 100))%").font(.subheadline.bold())
                                Slider(value: store.serviceAllocation, in: 0.2...0.65, step: 0.05).tint(GameTheme.teal)
                            }
                            .gameCard()
                        }
                        VStack(alignment: .leading, spacing: 13) {
                            SectionTitle(title: "人員配置", subtitle: "1名あたり人件費34万円/月")
                            Stepper("稼働人数  \(store.wrappedValue.staff)名", value: store.staff, in: 1...15)
                            Text("1人につき販売・店頭買取を合計7回/週まで対応できます。AA・業者仕入れは営業枠を使いません。過剰配置は人件費を増やします。").font(.caption).foregroundStyle(.secondary)
                        }
                        .gameCard()
                        let upgrades = store.wrappedValue.isOperational && !store.wrappedValue.isRenovating
                            ? StoreType.allCases.filter { $0 != store.wrappedValue.type && $0.buildCost > store.wrappedValue.type.buildCost && $0.capacity >= store.wrappedValue.inventoryCount }
                            : []
                        if !upgrades.isEmpty {
                            VStack(alignment: .leading, spacing: 11) {
                                SectionTitle(title: "店舗改装", subtitle: "営業を続けながら設備と展示能力を拡張")
                                ForEach(upgrades) { type in
                                    let cost = max(600, (type.buildCost - store.wrappedValue.type.buildCost) * 65 / 100)
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(type.name).font(.subheadline.bold())
                                            Text("展示\(type.capacity)台・工期\(type.renovationMonths(from: store.wrappedValue.type))週間・改装費\(cost.currency)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button("改装") {
                                            if game.renovateStore(storeID, to: type) {
                                                draft = game.stores.first(where: { $0.id == storeID })
                                                renovationMessage = "\(type.name)への改装を開始しました。マップ上で工事の進行を確認できます"
                                            } else {
                                                renovationMessage = "資金または展示枠の条件を満たしていません"
                                            }
                                        }.buttonStyle(.bordered).tint(GameTheme.teal)
                                    }
                                }
                            }.gameCard()
                        }
                    }
                    .padding(15)
                }
            }
            .background(GameTheme.cream)
            .navigationTitle(draft?.hasManager == true ? "店長の運営方針" : "店舗・設備")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("保存") { if let draft { game.updateStore(draft) }; dismiss() }.bold() }
            }
            .onAppear { draft = game.stores.first(where: { $0.id == storeID }) }
            .confirmationDialog("この店舗から撤退しますか？", isPresented: $confirmClose, titleVisibility: .visible) {
                Button("撤退・資産を売却", role: .destructive) {
                    game.closeStore(storeID)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("所有地は時価、設備は簿価の30%、在庫は原価の80%で売却します。この操作は取り消せません。")
            }
            .alert("店舗改装", isPresented: Binding(get: { renovationMessage != nil }, set: { if !$0 { renovationMessage = nil } })) {
                Button("OK") { renovationMessage = nil }
            } message: { Text(renovationMessage ?? "") }
        }
    }
}
