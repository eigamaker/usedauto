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
                    let businessLabel = game.regionalNicheLeaderLabel(for: store) ?? game.derivedBusinessName(for: store)
                    Text(store.hasManager ? "\(businessLabel)・\(store.marketPolicy.targetPurpose.name)狙い・店長あり" : "\(businessLabel)・オーナー直営")
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
                Label("口コミ \(store.reviewRatingText)（\(store.reviewCount)件）", systemImage: "hand.thumbsup.fill")
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
                            SectionTitle(title: "オーナーの市場方針", subtitle: "保存した変更は次週の来店配分から反映されます")
                            if store.wrappedValue.pendingMarketPolicy != nil {
                                Label("次週反映予定の方針があります", systemImage: "clock.arrow.circlepath")
                                    .font(.caption).foregroundStyle(GameTheme.orange)
                            }
                            Text("価格水準  \(Int(store.wrappedValue.priceIndex * 100))").font(.subheadline.bold())
                            Slider(value: store.priceIndex, in: 0.88...1.18, step: 0.01).tint(GameTheme.teal)
                            HStack { Text("割安・販売量↑").font(.caption).foregroundStyle(.secondary); Spacer(); Text("高値・粗利↑").font(.caption).foregroundStyle(.secondary) }
                            Picker("狙う用途", selection: store.marketPolicy.targetPurpose) {
                                ForEach(CustomerPurpose.allCases) { Text($0.name).tag($0) }
                            }.pickerStyle(.menu)
                            Text("重点車種（最大3車種）").font(.caption.bold())
                            ForEach(VehicleCategory.allCases) { category in
                                Button {
                                    if store.wrappedValue.marketPolicy.priorityCategories.contains(category) {
                                        store.wrappedValue.marketPolicy.priorityCategories.remove(category)
                                    } else if store.wrappedValue.marketPolicy.priorityCategories.count < 3 {
                                        store.wrappedValue.marketPolicy.priorityCategories.insert(category)
                                    }
                                } label: {
                                    Label(category.name, systemImage: store.wrappedValue.marketPolicy.priorityCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                                }
                                .buttonStyle(.plain)
                            }
                            Text("受け入れる車両状態").font(.caption.bold())
                            ForEach(VehicleConditionBand.allCases) { condition in
                                Button {
                                    guard condition != .normal else { return }
                                    if store.wrappedValue.marketPolicy.acceptedConditions.contains(condition) {
                                        store.wrappedValue.marketPolicy.acceptedConditions.remove(condition)
                                    } else {
                                        store.wrappedValue.marketPolicy.acceptedConditions.insert(condition)
                                    }
                                } label: {
                                    Label(condition.name, systemImage: store.wrappedValue.marketPolicy.acceptedConditions.contains(condition) ? "checkmark.circle.fill" : "circle")
                                }
                                .buttonStyle(.plain)
                            }
                            if !store.wrappedValue.facilities.isEmpty {
                                Divider()
                                ForEach(store.wrappedValue.facilities.sorted(by: { $0.name < $1.name })) { facility in
                                    Label("\(facility.name)・月\(facility.monthlyCost.currency)", systemImage: facility.icon)
                                        .font(.caption.bold()).foregroundStyle(GameTheme.teal)
                                }
                            }
                            let installable = StoreFacility.allCases.filter {
                                !store.wrappedValue.facilities.contains($0) && $0.minimumGridCells <= store.wrappedValue.plotIDs.count
                            }
                            if !installable.isEmpty {
                                Divider()
                                Text("施設を追加（業態と独立）").font(.caption.bold())
                                ForEach(installable) { facility in
                                    HStack {
                                        Label("\(facility.name)・\(facility.installationCost.currency)", systemImage: facility.icon)
                                            .font(.caption)
                                        Spacer()
                                        Button("設置") {
                                            if game.installFacility(facility, at: storeID) {
                                                draft = game.stores.first(where: { $0.id == storeID })
                                            }
                                        }
                                        .buttonStyle(.bordered).font(.caption.bold())
                                        .disabled(game.cash < facility.installationCost)
                                    }
                                }
                            }
                            if store.wrappedValue.hasManager && (store.wrappedValue.delegatePricing || store.wrappedValue.delegateProcurement) {
                                Label("販売または仕入方針は店長へ管理委任中です。社員の自動実行とは独立しています。", systemImage: "person.crop.circle.badge.checkmark")
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
                            SectionTitle(title: "広告と整備能力", subtitle: "整備担当の工数と設備ベイは独立した制約です")
                            Text("広告予算  \(store.wrappedValue.advertising.currency)/月").font(.subheadline.bold())
                            Slider(value: Binding(get: { Double(store.wrappedValue.advertising) }, set: { store.wrappedValue.advertising = Int($0) }), in: 0...500, step: 20).tint(GameTheme.orange)
                            HStack {
                                MetricView(title: "週次工数", value: "\(store.wrappedValue.weeklyWorkshopLabor)")
                                MetricView(title: "ベイ", value: "\(store.wrappedValue.workshopBays)")
                                MetricView(title: "進行中", value: "\(store.wrappedValue.inventory.filter { $0.isInWorkshop }.count)台")
                            }
                        }
                        .gameCard()
                        VStack(alignment: .leading, spacing: 13) {
                            SectionTitle(title: "店員配置", subtitle: "個人ごとの能力と給与で運営")
                            HStack {
                                MetricView(title: "店員", value: "\(store.wrappedValue.staff)名")
                                MetricView(title: "月額給与", value: store.wrappedValue.employeeMonthlyPayroll.currency)
                                MetricView(title: "手動枠", value: "週7回")
                                MetricView(title: "固定客", value: "\(store.wrappedValue.loyalCustomers)組")
                            }
                            Text("採用・担当配置・4能力研修・自動化方針は店舗画面の「店員」で設定します。販売・仕入担当は1人週7件を自動処理します。")
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
