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
                    }
                }
                .padding(14)
            }
            .background(GameTheme.cream)
            .navigationTitle("在庫管理")
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
    @EnvironmentObject private var game: GameEngine
    let store: Store
    var body: some View {
        HStack {
            MetricView(title: "展示在庫", value: "\(store.inventoryCount)台", detail: "上限 \(store.type.capacity)台")
            MetricView(title: "空きスペース", value: "\(max(0, store.type.capacity - store.inventoryCount))台")
            MetricView(title: "平均在庫", value: String(format: "%.1f週", game.averageInventoryWeeks(storeID: store.id)))
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
                HStack(spacing: 5) {
                    Text(batch.vehicleName).font(.subheadline.bold())
                    if batch.isRareClassic { Text("希少旧車").font(.caption2.bold()).foregroundStyle(GameTheme.orange) }
                    if batch.productState != .stock { Text(batch.productState.name).font(.caption2.bold()).foregroundStyle(.purple) }
                    if let issue = batch.disclosedIssue { Text("告知：\(issue.name)").font(.caption2.bold()).foregroundStyle(GameTheme.danger) }
                }
                Text("\(batch.category.name)・\(String(batch.modelYear))年式・\(batch.mileage.formatted())km・品質 \(Int((batch.quality * 100).rounded()))/100").font(.caption).foregroundStyle(.secondary)
                if let project = batch.workshopProject {
                    Text("\(project.kind.name)・あと\(project.remainingWeeks)週・簿価 \(batch.averageCost.currency)・#\(batch.id.uuidString.prefix(4).uppercased())").font(.caption2).foregroundStyle(.purple)
                } else {
                    Text("仕入れ値 \(batch.averageCost.currency)・販売目安 \((game.manualSaleQuote(storeID: store.id, inventoryID: batch.id)?.price ?? 0).currency)・#\(batch.id.uuidString.prefix(4).uppercased())").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("1台").font(.headline.monospacedDigit())
                Text(game.inventoryAgeLabel(for: batch))
                    .font(.caption2.bold())
                    .foregroundStyle(ageTint)
            }
            if game.stores.count > 1 {
                Menu {
                    ForEach(game.stores.filter { $0.id != store.id }) { destination in
                        Button(destination.name) {
                            _ = game.transferInventory(inventoryID: batch.id, from: store.id, to: destination.id)
                        }
                        .disabled(destination.inventoryCount >= destination.type.capacity || batch.isInWorkshop)
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .foregroundStyle(GameTheme.teal)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var ageTint: Color {
        let weeks = game.inventoryAgeWeeks(for: batch)
        return weeks <= 2 ? GameTheme.teal : weeks <= 12 ? GameTheme.navy : weeks <= 25 ? GameTheme.orange : GameTheme.danger
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
                    Text(store.hasManager ? "\(store.concept.name)・\(store.focus.name)狙い・店長あり" : "\(store.concept.name)・オーナー直営")
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
                Label("店員 \(store.staff)", systemImage: "person.2.fill")
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
                        VStack(alignment: .leading, spacing: 13) {
                            SectionTitle(title: "オーナーの販売方針", subtitle: "店長がいなくても直接設定できます")
                            Text("価格水準  \(Int(store.wrappedValue.priceIndex * 100))").font(.subheadline.bold())
                            Slider(value: store.priceIndex, in: 0.88...1.18, step: 0.01).tint(GameTheme.teal)
                            HStack { Text("割安・販売量↑").font(.caption).foregroundStyle(.secondary); Spacer(); Text("高値・粗利↑").font(.caption).foregroundStyle(.secondary) }
                            Picker("狙う客層", selection: store.focus) { ForEach(CustomerFocus.allCases) { Text($0.name).tag($0) } }.pickerStyle(.menu)
                            Picker("店舗コンセプト", selection: store.concept) { ForEach(StoreConcept.allCases) { Text($0.name).tag($0) } }.pickerStyle(.menu)
                            Text(store.wrappedValue.concept.summary).font(.caption).foregroundStyle(.secondary)
                            if store.wrappedValue.hasManager && (store.wrappedValue.delegatePricing || store.wrappedValue.delegateProcurement) {
                                Label("販売価格または仕入れは店長へ委任中です。週間処理で実行されます。", systemImage: "person.crop.circle.badge.checkmark")
                                    .font(.caption).foregroundStyle(GameTheme.teal)
                            }
                        }
                        .gameCard()
                        if game.stores.count > 1 {
                            Button(role: .destructive) { confirmClose = true } label: {
                                Label("この店舗を撤退・売却する", systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        VStack(alignment: .leading, spacing: 13) {
                            SectionTitle(title: "広告と整備", subtitle: "オーナーが直接決める投資配分")
                            Text("広告予算  \(store.wrappedValue.advertising.currency)/月").font(.subheadline.bold())
                            Slider(value: Binding(get: { Double(store.wrappedValue.advertising) }, set: { store.wrappedValue.advertising = Int($0) }), in: 0...500, step: 20).tint(GameTheme.orange)
                            Text("整備スペース配分  \(Int(store.wrappedValue.serviceAllocation * 100))%").font(.subheadline.bold())
                            Slider(value: store.serviceAllocation, in: 0.2...0.65, step: 0.05).tint(GameTheme.teal)
                        }
                        .gameCard()
                        VStack(alignment: .leading, spacing: 13) {
                            SectionTitle(title: "店員配置", subtitle: "個人ごとの能力と給与で運営")
                            HStack {
                                MetricView(title: "店員", value: "\(store.wrappedValue.staff)名")
                                MetricView(title: "月額給与", value: store.wrappedValue.employeeMonthlyPayroll.currency)
                                MetricView(title: "営業枠", value: "週\((store.wrappedValue.staff + 1) * 7)回")
                            }
                            Text("採用・解雇・研修・昇給は店舗画面の「店員」で行います。店員は自分では判断せず、オーナーの操作または店長への委任が必要です。")
                                .font(.caption).foregroundStyle(.secondary)
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
            .navigationTitle("店舗・運営方針")
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
                Text("所有地は時価、設備は簿価の30%、在庫は原価の80%で売却します。店舗と設備は撤去され、使用していた区画は更地になります。この操作は取り消せません。")
            }
            .alert("店舗改装", isPresented: Binding(get: { renovationMessage != nil }, set: { if !$0 { renovationMessage = nil } })) {
                Button("OK") { renovationMessage = nil }
            } message: { Text(renovationMessage ?? "") }
        }
    }
}
