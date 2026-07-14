import SwiftUI

enum MapFacility: String, CaseIterable, Identifiable {
    case headquarters, auction, bank, realEstate, workshop, advertising, recruiting, cityHall
    var id: String { rawValue }

    var name: String {
        switch self {
        case .headquarters: "本社"
        case .auction: "東部オートオークション"
        case .bank: "翠浜銀行"
        case .realEstate: "まち不動産"
        case .workshop: "臨海整備センター"
        case .advertising: "翠浜広告社"
        case .recruiting: "キャリアモーター"
        case .cityHall: "翠浜市役所"
        }
    }

    var shortName: String {
        switch self {
        case .headquarters: "本社"; case .auction: "AA会場"; case .bank: "銀行"; case .realEstate: "不動産"
        case .workshop: "整備"; case .advertising: "広告"; case .recruiting: "人材"; case .cityHall: "行政"
        }
    }

    var icon: String {
        switch self {
        case .headquarters: "building.2.fill"
        case .auction: "car.2.fill"
        case .bank: "building.columns.fill"
        case .realEstate: "house.fill"
        case .workshop: "wrench.and.screwdriver.fill"
        case .advertising: "megaphone.fill"
        case .recruiting: "person.3.fill"
        case .cityHall: "building.fill"
        }
    }

    var color: Color {
        switch self {
        case .headquarters: GameTheme.teal
        case .auction: .indigo
        case .bank: .blue
        case .realEstate: .green
        case .workshop: .gray
        case .advertising: GameTheme.orange
        case .recruiting: .purple
        case .cityHall: .brown
        }
    }

    var worldPoint: CGPoint {
        switch self {
        case .headquarters: CityMapLayout.gridPoint(column: 7, row: 11)
        case .auction: CityMapLayout.gridPoint(column: 3, row: 11)
        case .bank: CityMapLayout.gridPoint(column: 1, row: 1)
        case .realEstate: CityMapLayout.gridPoint(column: 6, row: 3)
        case .workshop: CityMapLayout.gridPoint(column: 7, row: 6)
        case .advertising: CityMapLayout.gridPoint(column: 3, row: 1)
        case .recruiting: CityMapLayout.gridPoint(column: 6, row: 1)
        case .cityHall: CityMapLayout.gridPoint(column: 10, row: 6)
        }
    }

    var isPrimary: Bool { [.headquarters, .auction, .bank, .realEstate, .workshop].contains(self) }

    @MainActor func status(game: GameEngine) -> String {
        switch self {
        case .headquarters: "企業価値 \(game.companyValue.currency)"
        case .auction: "3会場・出品\(game.auctionListings.count)台・予約\(game.bidReservations.count)件"
        case .bank: "借入 \(game.debt.currency)"
        case .realEstate: "売地 \(game.plots.filter { if case .available = $0.occupant { true } else { false } }.count)件"
        case .workshop: "整備提携受付中"
        case .advertising: "今週の広告枠あり"
        case .recruiting: "候補者12名"
        case .cityHall: "補助金1件"
        }
    }
}

struct MapFocusRequest: Equatable {
    let id = UUID()
    let worldPoint: CGPoint
}

struct FacilityHubSheet: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let facility: MapFacility
    let focusPlot: (LandPlot) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    FacilityHeader(facility: facility)
                    switch facility {
                    case .headquarters: HeadquartersContent()
                    case .auction: AuctionContent()
                    case .bank: BankContent()
                    case .realEstate: RealEstateContent { plot in dismiss(); focusPlot(plot) }
                    case .workshop: WorkshopContent()
                    case .advertising: AdvertisingContent()
                    case .recruiting: RecruitingContent()
                    case .cityHall: CityHallContent()
                    }
                }.padding(15)
            }
            .background(GameTheme.cream)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }
}

private struct FacilityHeader: View {
    @EnvironmentObject private var game: GameEngine
    let facility: MapFacility
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: facility.icon).font(.title2).foregroundStyle(.white).frame(width: 52, height: 52).background(facility.color).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(facility.name).font(.title3.bold())
                Text(facility.status(game: game)).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }.gameCard()
    }
}

private struct HeadquartersContent: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(spacing: 14) {
            HStack { MetricView(title: "企業価値", value: game.companyValue.currency, tint: GameTheme.teal); MetricView(title: "店舗", value: "\(game.stores.count)店"); MetricView(title: "在庫", value: "\(game.totalInventory)台") }.gameCard()
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "全社ダッシュボード", subtitle: "会社全体のPL・BS・資金繰り")
                FacilityRow("売上高", game.finance.revenue.currency)
                FacilityRow("営業利益", game.finance.operatingProfit.currency, tint: game.finance.operatingProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                FacilityRow("現金", game.cash.currency)
                FacilityRow("土地・建物", (game.finance.landAssets + game.finance.buildingAssets).currency)
                FacilityRow("借入金", game.debt.currency)
            }.gameCard()
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "店舗比較")
                ForEach(game.stores) { store in FacilityRow(store.name, "\(store.lastSales)台・利益 \(store.lastProfit.currency)", tint: store.lastProfit >= 0 ? GameTheme.teal : GameTheme.danger) }
            }.gameCard()
            StoreNetworkContent()
        }
    }
}

private struct StoreNetworkContent: View {
    @EnvironmentObject private var game: GameEngine
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "店舗ネットワーク", subtitle: "在庫を融通し、店長への委任状況を管理")
            ForEach(game.stores) { store in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(store.name).font(.subheadline.bold())
                            Text("在庫\(store.inventoryCount)/\(store.type.capacity)台・入庫予定\(game.incomingCount(for: store.id))台").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        let delegated = [store.delegateStaff, store.delegatePricing, store.delegateMarketing, store.delegateService].filter { $0 }.count
                        CapsuleLabel(text: delegated == 0 ? "直営" : "\(delegated)/4委任", color: delegated == 4 ? GameTheme.teal : GameTheme.navy, icon: delegated == 0 ? "person.fill" : "person.badge.key.fill")
                    }
                    if game.stores.count > 1 {
                        ForEach(store.inventory.filter { $0.count > 0 }) { batch in
                            HStack {
                                Label("\(batch.category.name) \(batch.count)台", systemImage: batch.category.icon).font(.caption)
                                Spacer()
                                Menu("1台移動") {
                                    ForEach(game.stores.filter { $0.id != store.id }) { destination in
                                        Button(destination.name) {
                                            message = game.transferInventory(category: batch.category, from: store.id, to: destination.id) ? "\(destination.name)へ1台移動しました" : "移動先の展示枠が不足しています"
                                        }
                                    }
                                }.font(.caption.bold())
                            }
                        }
                    }
                }
                .padding(10).background(GameTheme.navy.opacity(0.045)).clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
        .gameCard()
        .alert("店舗間物流", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
}

private struct AuctionContent: View {
    @EnvironmentObject private var game: GameEngine
    @State private var venue: AuctionVenue = .east
    @State private var selectedStoreID: UUID?
    @State private var message: String?

    private var selectedStore: Store? {
        game.stores.first(where: { $0.id == selectedStoreID }) ?? game.stores.first
    }
    private var listings: [AuctionListing] {
        game.auctionListings.filter { $0.venue == venue }.sorted { $0.reservePrice < $1.reservePrice }
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 11) {
                SectionTitle(title: "仕入先を選ぶ", subtitle: "会場ごとに得意車種・費用・納期が異なります")
                Picker("会場", selection: $venue) {
                    ForEach(AuctionVenue.allCases) { item in Text(item.name.replacingOccurrences(of: "オートオークション", with: "AA")).tag(item) }
                }.pickerStyle(.segmented)
                if game.stores.count > 1 {
                    Picker("入庫店舗", selection: Binding(get: { selectedStore?.id }, set: { selectedStoreID = $0 })) {
                        ForEach(game.stores) { store in Text(store.name).tag(Optional(store.id)) }
                    }
                }
            }.gameCard()
            HStack {
                MetricView(title: "得意車種", value: venue.specialty)
                MetricView(title: "手数料", value: venue.fee.currency)
                MetricView(title: "陸送", value: venue.shippingCost.currency)
                MetricView(title: "入庫", value: "\(venue.shippingMonths)週間後", tint: venue.tint)
            }.gameCard()
            VStack(alignment: .leading, spacing: 11) {
                SectionTitle(title: "出品車両・上限入札", subtitle: "次の週間処理で競合と入札し、上限内なら落札")
                if let store = selectedStore {
                    ForEach(listings.prefix(7)) { listing in
                        AuctionBidRow(listing: listing, storeID: store.id) { message = $0 }
                        if listing.id != listings.prefix(7).last?.id { Divider() }
                    }
                }
            }.gameCard()
            if let store = selectedStore {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "他の仕入れ経路", subtitle: "価格・数量・納期の違いを使い分けます")
                    ForEach(Array(game.recommendedCategories(for: game.plot(id: store.plotID)?.district ?? .suburb).prefix(3))) { category in
                        HStack {
                            Label(category.name, systemImage: category.icon).font(.subheadline.bold())
                            Spacer()
                            Button("業販3台・1週間") {
                                message = game.orderDealerTrade(category: category, count: 3, storeID: store.id) ? "業販で\(category.name)3台を発注しました。到着後は個別在庫になります" : "資金または入庫枠が不足しています"
                            }.buttonStyle(.bordered).tint(.teal)
                            Button("法人5台・2週間") {
                                message = game.orderFleetPurchase(category: category, count: 5, storeID: store.id) ? "法人一括で\(category.name)5台を発注しました。到着後は個別在庫になります" : "資金または入庫枠が不足しています"
                            }.buttonStyle(.bordered).tint(.orange)
                        }
                    }
                }.gameCard()
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "自社在庫を出品", subtitle: "\(venue.name)の買い手へ販売")
                    ForEach(store.inventory.filter { $0.count > 0 }) { batch in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(batch.vehicleName).font(.subheadline.bold())
                                Text("\(batch.category.name)・簿価\(batch.averageCost.currency)・品質\(Int(batch.quality * 100))・#\(batch.id.uuidString.prefix(4).uppercased())").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("1台出品") {
                                message = game.consignInventory(storeID: store.id, inventoryID: batch.id, venue: venue) ? "\(venue.name)へ1台出品しました" : "出品できませんでした"
                            }.buttonStyle(.bordered).tint(venue.tint)
                        }
                    }
                }.gameCard()
            }
            if !game.inboundShipments.isEmpty || !game.auctionConsignments.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    SectionTitle(title: "進行中", subtitle: "入庫と出品成約は週間処理で進みます")
                    ForEach(game.inboundShipments) { shipment in
                        FacilityRow("\(shipment.source.name)・\(shipment.category.name) \(shipment.count)台", "あと\(shipment.monthsRemaining)週間", tint: .blue)
                    }
                    ForEach(game.auctionConsignments) { order in
                        FacilityRow("出品中・\(order.category.name) \(order.count)台", "成約まで\(order.monthsRemaining)週間", tint: venue.tint)
                    }
                }.gameCard()
            }
        }
        .onAppear { if selectedStoreID == nil { selectedStoreID = game.stores.first?.id } }
        .alert("仕入れ・出品", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
}

private struct AuctionBidRow: View {
    @EnvironmentObject private var game: GameEngine
    let listing: AuctionListing
    let storeID: UUID
    let result: (String) -> Void
    @State private var maxPrice: Int

    init(listing: AuctionListing, storeID: UUID, result: @escaping (String) -> Void) {
        self.listing = listing
        self.storeID = storeID
        self.result = result
        _maxPrice = State(initialValue: max(listing.reservePrice, listing.marketPrice))
    }

    private var reserved: Bool { game.bidReservations.contains { $0.listingID == listing.id } }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 9) {
                Image(systemName: listing.category.icon).foregroundStyle(listing.venue.tint).frame(width: 30, height: 30).background(listing.venue.tint.opacity(0.1)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(listing.category.name)・\(String(listing.modelYear))年").font(.subheadline.bold())
                    Text("\(listing.mileage.formatted())km・評価\(Int(listing.quality * 100))・\(listing.seller)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("開始 \(listing.reservePrice.currency)").font(.caption.bold())
                    Text("相場 \(listing.marketPrice.currency)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack {
                Stepper("上限 \(maxPrice.currency)", value: $maxPrice, in: listing.reservePrice...max(listing.reservePrice + 10, listing.marketPrice * 13 / 10), step: 5)
                    .font(.caption.bold())
                Button(reserved ? "取消" : "予約") {
                    if reserved {
                        game.cancelBid(listingID: listing.id)
                        result("入札予約を取り消しました")
                    } else {
                        result(game.reserveBid(listingID: listing.id, storeID: storeID, maxPrice: maxPrice) ? "上限\(maxPrice.currency)で入札予約しました" : "入庫枠を確保できません")
                    }
                }.buttonStyle(.borderedProminent).tint(reserved ? .gray : listing.venue.tint)
            }
        }.padding(.vertical, 3)
    }
}

private struct BankContent: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(spacing: 14) {
            HStack { MetricView(title: "信用評価", value: game.debt < game.borrowingLimit / 2 ? "A" : "B", tint: GameTheme.teal); MetricView(title: "融資上限", value: game.borrowingLimit.currency); MetricView(title: "借入残高", value: game.debt.currency) }.gameCard()
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "融資・返済", subtitle: "所有地は担保として融資枠へ反映")
                ProgressView(value: Double(game.debt), total: Double(max(1, game.borrowingLimit))).tint(.blue)
                HStack { Button("1,000万円借入") { game.borrow(1_000) }.buttonStyle(.borderedProminent).tint(.blue).disabled(game.debt + 1_000 > game.borrowingLimit); Button("1,000万円返済") { game.repay(1_000) }.buttonStyle(.bordered).disabled(game.cash < 1_000 || game.debt == 0) }
                Label("次回返済は月末処理時です", systemImage: "calendar.badge.clock").font(.caption).foregroundStyle(.secondary)
            }.gameCard()
        }
    }
}

private struct RealEstateContent: View {
    @EnvironmentObject private var game: GameEngine
    let focus: (LandPlot) -> Void
    var available: [LandPlot] { game.plots.filter { plot in if case .available = plot.occupant { plot.development == nil } else { false } }.sorted { game.profitabilityScore(for: $0) > game.profitabilityScore(for: $1) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "おすすめ物件", subtitle: "収益性予測の高い順")
            ForEach(available.prefix(10)) { plot in
                HStack {
                    Image(systemName: plot.district.symbol).foregroundStyle(plot.district.color).frame(width: 32)
                    VStack(alignment: .leading) { Text("\(plot.district.name) \(plot.localNumber)番区画").font(.subheadline.bold()); Text("購入 \(plot.price.currency)・賃料 \(plot.monthlyRent.currency)/月").font(.caption).foregroundStyle(.secondary) }
                    Spacer(); Button("地図で見る") { focus(plot) }.font(.caption.bold()).buttonStyle(.bordered).tint(GameTheme.teal)
                }.padding(.vertical, 4)
            }
        }.gameCard()
    }
}

private struct WorkshopContent: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "整備・部品・業務提携", subtitle: "店舗別の整備配分を調整")
            ForEach(game.stores) { store in
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(store.name).font(.subheadline.bold()); Spacer(); Text("整備 \(Int(store.serviceAllocation * 100))%").font(.caption.bold()) }
                    Slider(value: Binding(get: { game.stores.first(where: { $0.id == store.id })?.serviceAllocation ?? store.serviceAllocation }, set: { value in var changed = store; changed.serviceAllocation = value; game.updateStore(changed) }), in: 0.2...0.65, step: 0.05).tint(GameTheme.teal)
                }.padding(.vertical, 5)
            }
        }.gameCard()
    }
}

private struct AdvertisingContent: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "地域広告・ブランド広告", subtitle: "店舗ごとの月額予算")
            ForEach(game.stores) { store in
                HStack { VStack(alignment: .leading) { Text(store.name).font(.subheadline.bold()); Text("現在 \(store.advertising.currency)/月").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("+40万円") { var changed = store; changed.advertising = min(500, changed.advertising + 40); game.updateStore(changed) }.buttonStyle(.bordered).tint(GameTheme.orange) }
            }
            Divider(); Label("市場調査レベル 2：競合推定精度 68%", systemImage: "binoculars.fill").font(.caption).foregroundStyle(.secondary)
        }.gameCard()
    }
}

private struct RecruitingContent: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "採用候補者", subtitle: "営業・整備・店長候補 12名")
            ForEach(game.stores) { store in
                HStack { VStack(alignment: .leading) { Text(store.name).font(.subheadline.bold()); Text("現在 \(store.staff)名・人件費 \((store.staff * 34).currency)/月").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("1名採用") { var changed = store; changed.staff = min(15, changed.staff + 1); game.updateStore(changed) }.buttonStyle(.borderedProminent).tint(.purple).disabled(store.staff >= 15) }
            }
        }.gameCard()
    }
}

private struct CityHallContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "税金・補助金・許認可")
            Label("中古車品質認証：有効", systemImage: "checkmark.seal.fill").foregroundStyle(GameTheme.teal)
            Label("整備設備導入補助金：申請可能", systemImage: "yensign.circle.fill").foregroundStyle(.blue)
            Label("次回法人税納付：12週間後", systemImage: "calendar").foregroundStyle(.secondary)
            Text("EV設備と環境規制は事業規模の拡大後に解放されます。").font(.caption).foregroundStyle(.secondary)
        }.gameCard()
    }
}

private struct FacilityRow: View {
    let title: String; let value: String; var tint: Color = GameTheme.ink
    init(_ title: String, _ value: String, tint: Color = GameTheme.ink) { self.title = title; self.value = value; self.tint = tint }
    var body: some View { HStack { Text(title).font(.subheadline); Spacer(); Text(value).font(.subheadline.bold().monospacedDigit()).foregroundStyle(tint) }.padding(.vertical, 3) }
}
