import SwiftUI

enum MapFacility: String, CaseIterable, Identifiable {
    case auction, bank, realEstate, workshop, advertising, recruiting, cityHall
    var id: String { rawValue }

    var name: String {
        switch self {
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
        case .auction: "AA会場"; case .bank: "銀行"; case .realEstate: "不動産"
        case .workshop: "整備"; case .advertising: "広告"; case .recruiting: "人材"; case .cityHall: "行政"
        }
    }

    var icon: String {
        switch self {
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
        case .auction: CityMapLayout.gridPoint(column: 2, row: 17)
        case .bank: CityMapLayout.gridPoint(column: 0, row: 5)
        case .realEstate: CityMapLayout.gridPoint(column: 6, row: 6)
        case .workshop: CityMapLayout.gridPoint(column: 18, row: 11)
        case .advertising: CityMapLayout.gridPoint(column: 9, row: 6)
        case .recruiting: CityMapLayout.gridPoint(column: 14, row: 5)
        case .cityHall: CityMapLayout.gridPoint(column: 18, row: 5)
        }
    }

    var isPrimary: Bool { self == .auction }

    @MainActor func status(game: GameEngine) -> String {
        switch self {
        case .auction: "3会場・出品\(game.auctionListings.count)台・予約\(game.bidReservations.count)件・結果\(game.auctionBidResults.filter { $0.resolvedTurn == game.turn }.count)件"
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

struct CompanyDashboardView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    HStack(spacing: 13) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(GameTheme.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("経営ダッシュボード").font(.title3.bold())
                            Text("店舗を拠点に会社全体を管理").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .gameCard()
                    CompanyDashboardContent()
                }
                .padding(15)
            }
            .background(GameTheme.cream)
            .navigationTitle("経営")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
            }
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

private struct CompanyDashboardContent: View {
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
            SectionTitle(title: "店舗ネットワーク", subtitle: "在庫を融通し、店長への自動化委任を確認")
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
                        ForEach(store.inventory.filter { $0.count > 0 && !$0.isInWorkshop }) { batch in
                            HStack {
                                Label("\(batch.category.name) \(batch.count)台", systemImage: batch.category.icon).font(.caption)
                                Spacer()
                                Menu("1台移動") {
                                    ForEach(game.stores.filter { $0.id != store.id }) { destination in
                                        Button(destination.name) {
                                            message = game.transferInventory(inventoryID: batch.id, from: store.id, to: destination.id) ? "\(destination.name)へ1台移動しました" : "移動先の展示枠が不足しています"
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
    private var bidResults: [AuctionBidResult] {
        game.auctionBidResults.filter { result in
            result.venue == venue && (selectedStore == nil || result.storeID == selectedStore?.id)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 11) {
                SectionTitle(title: "オークション会場", subtitle: "出品機会は多い一方、競合入札で落札率は低め。会場費と輸送費も加算されます")
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
                SectionTitle(title: "出品車両・上限入札", subtitle: "今週は上限額を予約し、落札結果は翌週に確定します")
                if let store = selectedStore {
                    ForEach(listings.prefix(7)) { listing in
                        AuctionBidRow(listing: listing, storeID: store.id) { message = $0 }
                        if listing.id != listings.prefix(7).last?.id { Divider() }
                    }
                }
            }.gameCard()
            if !bidResults.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    SectionTitle(title: "入札結果", subtitle: "落札・不落札と確定価格を車種ごとに確認できます")
                    ForEach(Array(bidResults.prefix(8))) { result in
                        AuctionBidResultRow(result: result, currentTurn: game.turn)
                        if result.id != bidResults.prefix(8).last?.id { Divider() }
                    }
                }.gameCard()
            }
            if let store = selectedStore {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "自社在庫を出品", subtitle: "\(venue.name)の買い手へ販売")
                    ForEach(store.inventory.filter { $0.count > 0 && !$0.isInWorkshop }) { batch in
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
                        FacilityRow("\(shipment.source.name)・\(shipment.vehicleName) \(shipment.count)台", "あと\(shipment.monthsRemaining)週間", tint: .blue)
                    }
                    ForEach(game.auctionConsignments) { order in
                        FacilityRow("出品中・\(order.vehicleName) \(order.count)台", "成約まで\(order.monthsRemaining)週間", tint: venue.tint)
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

    private var reservation: BidReservation? { game.bidReservations.first { $0.listingID == listing.id } }
    private var reserved: Bool { reservation != nil }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 9) {
                Image(systemName: listing.category.icon).foregroundStyle(listing.venue.tint).frame(width: 30, height: 30).background(listing.venue.tint.opacity(0.1)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(listing.vehicleName).font(.subheadline.bold())
                        if VehicleCatalog.entry(id: listing.modelID)?.isRareClassic == true {
                            Text("希少旧車").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(GameTheme.orange).clipShape(Capsule())
                        }
                    }
                    Text("\(listing.category.name)・\(String(listing.modelYear))年・\(listing.mileage.formatted())km・評価\(Int(listing.quality * 100))・\(listing.seller)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("開始 \(listing.reservePrice.currency)").font(.caption.bold())
                    Text("相場 \(listing.marketPrice.currency)").font(.caption2).foregroundStyle(.secondary)
                    Text("諸費用 +\((listing.venue.fee + listing.venue.shippingCost).currency)").font(.caption2).foregroundStyle(GameTheme.orange)
                }
            }
            HStack {
                Stepper("上限 \(maxPrice.currency)", value: $maxPrice, in: listing.reservePrice...max(listing.reservePrice + 10, listing.marketPrice * 13 / 10), step: 5)
                    .font(.caption.bold())
                Text("落札見込 \(Int(game.auctionBidWinChance(for: listing, maxPrice: maxPrice) * 100))%")
                    .font(.caption2.bold().monospacedDigit()).foregroundStyle(listing.venue.tint)
                Button(reserved ? "更新" : "予約") {
                    result(game.reserveBid(listingID: listing.id, storeID: storeID, maxPrice: maxPrice) ? "上限\(maxPrice.currency)で入札を予約しました。結果は翌週に確定します" : "入庫枠を確保できません")
                }.buttonStyle(.borderedProminent).tint(listing.venue.tint)
                if reserved {
                    Button("取消") {
                        game.cancelBid(listingID: listing.id)
                        result("入札予約を取り消しました")
                    }.buttonStyle(.bordered).tint(.gray)
                }
            }
        }
        .padding(.vertical, 3)
        .onAppear {
            if let reservation { maxPrice = reservation.maxPrice }
        }
    }
}

private struct AuctionBidResultRow: View {
    let result: AuctionBidResult
    let currentTurn: Int

    private var tint: Color {
        switch result.status {
        case .won: .green
        case .exceededLimit: .secondary
        case .insufficientFunds: .orange
        }
    }

    private var icon: String {
        switch result.status {
        case .won: "checkmark.circle.fill"
        case .exceededLimit: "xmark.circle.fill"
        case .insufficientFunds: "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.vehicleName).font(.subheadline.bold())
                Text("\(result.category.name)・\(String(result.modelYear))年・上限\(result.maxPrice.currency)・\(result.resolvedTurn == currentTurn ? "今週判明" : "\(max(1, currentTurn - result.resolvedTurn))週間前")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(result.status.name).font(.caption.bold()).foregroundStyle(tint)
                Text("確定 \(result.hammerPrice.currency)").font(.caption2).foregroundStyle(.secondary)
            }
        }
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
    @State private var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "整備・商品化・カスタム", subtitle: "軽整備は即時。レストアとカスタム製作は高額で、完成まで数週間は販売できません")
            ForEach(game.stores) { store in
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(store.name).font(.subheadline.bold()); Spacer(); Text("整備 \(Int(store.serviceAllocation * 100))%").font(.caption.bold()) }
                    Slider(value: Binding(get: { game.stores.first(where: { $0.id == store.id })?.serviceAllocation ?? store.serviceAllocation }, set: { value in var changed = store; changed.serviceAllocation = value; game.updateStore(changed) }), in: 0.2...0.65, step: 0.05).tint(GameTheme.teal)
                    ForEach(store.inventory.filter { $0.count > 0 }.prefix(6)) { batch in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 5) {
                                        Text(batch.vehicleName).font(.caption.bold())
                                        if batch.isRareClassic {
                                            CapsuleLabel(text: "希少旧車", color: GameTheme.orange, icon: "clock.arrow.circlepath")
                                        } else if VehicleCatalog.entry(id: batch.modelID)?.isPopularCustomBase == true {
                                            CapsuleLabel(text: "カスタム人気", color: .purple, icon: "flame.fill")
                                        }
                                        if batch.productState != .stock {
                                            CapsuleLabel(text: batch.productState.name, color: .purple, icon: "paintbrush.fill")
                                        }
                                        if let issue = batch.disclosedIssue {
                                            CapsuleLabel(text: "告知：\(issue.name)", color: GameTheme.danger, icon: "exclamationmark.triangle.fill")
                                        }
                                    }
                                    Text("\(String(batch.modelYear))年式・\(batch.mileage.formatted())km・品質\(Int((batch.quality * 100).rounded()))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            if let project = batch.workshopProject {
                                HStack {
                                    Label(project.kind.name, systemImage: project.kind.icon).font(.caption2.bold()).foregroundStyle(.purple)
                                    ProgressView(value: Double(project.totalWeeks - project.remainingWeeks), total: Double(project.totalWeeks)).tint(.purple)
                                    Text("あと\(project.remainingWeeks)週").font(.caption2.bold().monospacedDigit())
                                }
                            } else {
                                HStack(spacing: 6) {
                                    if let preview = game.servicePreview(storeID: store.id, inventoryID: batch.id) {
                                        Button("軽整備 +\(preview.qualityGain)・\(preview.cost.currency)") {
                                            message = game.serviceInventory(storeID: store.id, inventoryID: batch.id)
                                                ? "\(batch.vehicleName)を整備し、品質が\(preview.resultingQuality)になりました。"
                                                : "現金が不足しています。"
                                        }
                                        .font(.caption2.bold()).buttonStyle(.bordered).tint(GameTheme.teal)
                                        .disabled(game.cash < preview.cost)
                                    }
                                    let restoration = game.workshopProjectPreview(storeID: store.id, inventoryID: batch.id, kind: .restoration)
                                    let customization = game.workshopProjectPreview(storeID: store.id, inventoryID: batch.id, kind: .customization)
                                    if restoration != nil || customization != nil {
                                        Menu {
                                            if let preview = restoration {
                                                Button("レストア：\(preview.cost.currency)・\(preview.weeks)週・品質+\(preview.qualityGain)") {
                                                    message = game.startWorkshopProject(storeID: store.id, inventoryID: batch.id, kind: .restoration)
                                                        ? "商品化・レストアを開始しました。完成後の販売目安は\(preview.projectedSalePrice.currency)です。"
                                                        : "現金が不足しています。"
                                                }.disabled(game.cash < preview.cost)
                                            }
                                            if let preview = customization {
                                                Button("カスタム：\(preview.cost.currency)・\(preview.weeks)週・品質+\(preview.qualityGain)") {
                                                    message = game.startWorkshopProject(storeID: store.id, inventoryID: batch.id, kind: .customization)
                                                        ? "カスタム製作を開始しました。完成後の販売目安は\(preview.projectedSalePrice.currency)です。"
                                                        : "現金が不足しています。"
                                                }.disabled(game.cash < preview.cost)
                                            }
                                        } label: {
                                            Label("商品化プロジェクト", systemImage: "hammer.fill")
                                        }
                                        .font(.caption2.bold()).buttonStyle(.borderedProminent).tint(.purple)
                                    } else if VehicleCatalog.entry(id: batch.modelID)?.isPopularCustomBase != true {
                                        Text("カスタム需要のない車種").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }.padding(.vertical, 5)
            }
        }
        .gameCard()
        .alert("整備・商品化", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
}

private struct AdvertisingContent: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "地域広告・ブランド広告", subtitle: "店舗ごとの月額予算")
            ForEach(game.stores) { store in
                HStack { VStack(alignment: .leading) { Text(store.name).font(.subheadline.bold()); Text("現在 \(store.advertising.currency)/月・オーナー指示").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("+40万円") { _ = game.increaseAdvertisingBudget(for: store.id, by: 40) }.buttonStyle(.bordered).tint(GameTheme.orange).disabled(store.advertising >= 500) }
            }
            Divider(); Label("市場調査レベル 2：競合推定精度 68%", systemImage: "binoculars.fill").font(.caption).foregroundStyle(.secondary)
        }.gameCard()
    }
}

private struct RecruitingContent: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "店員採用", subtitle: "営業・査定能力と個別給与を比較")
            ForEach(game.stores) { store in
                HStack {
                    VStack(alignment: .leading) {
                        Text(store.name).font(.subheadline.bold())
                        Text("店員 \(store.staff)名・給与 \(store.employeeMonthlyPayroll.currency)/月")
                            .font(.caption).foregroundStyle(.secondary)
                        if let candidate = game.employeeCandidates(for: store.id).first {
                            Text("候補 \(candidate.name)｜営業\(candidate.salesSkill)・査定\(candidate.appraisalSkill)・\(candidate.monthlySalary.currency)/月")
                                .font(.caption2).foregroundStyle(GameTheme.teal)
                        }
                    }
                    Spacer()
                    if let candidate = game.employeeCandidates(for: store.id).first {
                        Button("\(candidate.name)を採用") { _ = game.hireEmployee(candidate.id, for: store.id) }
                            .buttonStyle(.borderedProminent).tint(.purple)
                            .disabled(store.staff >= game.maxEmployeesPerStore)
                    }
                }
            }
            Text("解雇・研修・昇給は各店舗の「店員」画面で個人を選んで行います。")
                .font(.caption).foregroundStyle(.secondary)
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
            Text("燃料価格とEV普及率は毎年変化します。充電設備補助や環境規制は今後の市場イベントに影響します。").font(.caption).foregroundStyle(.secondary)
        }.gameCard()
    }
}

private struct FacilityRow: View {
    let title: String; let value: String; var tint: Color = GameTheme.ink
    init(_ title: String, _ value: String, tint: Color = GameTheme.ink) { self.title = title; self.value = value; self.tint = tint }
    var body: some View { HStack { Text(title).font(.subheadline); Spacer(); Text(value).font(.subheadline.bold().monospacedDigit()).foregroundStyle(tint) }.padding(.vertical, 3) }
}
