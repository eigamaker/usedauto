import SwiftUI

enum MapFacility: String, CaseIterable, Identifiable {
    case auction, bank, realEstate, workshop, advertising, recruiting, cityHall
    var id: String { rawValue }

    var name: String {
        switch self {
        case .auction: "翠浜オートオークション"
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

    var gridAnchorID: GridMapAnchorID {
        switch self {
        case .auction: .auction
        case .bank: .bank
        case .realEstate: .realEstate
        case .workshop: .workshop
        case .advertising: .advertising
        case .recruiting: .recruiting
        case .cityHall: .cityHall
        }
    }

    var isPrimary: Bool { self == .auction }

    @MainActor func status(game: GameEngine) -> String {
        switch self {
        case .auction: "出品\(game.auctionListings.count)台・入札\(game.bidReservations.count)件・結果\(game.auctionBidResults.filter { $0.resolvedTurn == game.turn }.count)件"
        case .bank: "借入 \(game.debt.currency)"
        case .realEstate: "売地 \(game.plots.filter { if case .available = $0.occupant { true } else { false } }.count)件"
        case .workshop: "整備提携受付中"
        case .advertising: "今週の広告枠あり"
        case .recruiting: "候補者12名"
        case .cityHall: "補助金1件"
        }
    }
}

enum MapFocusTarget: Equatable {
    case plot(Int)
    case district(DistrictKind)
}

struct MapFocusRequest: Equatable {
    let id = UUID()
    let target: MapFocusTarget

    init(plotID: Int) {
        target = .plot(plotID)
    }

    init(district: DistrictKind) {
        target = .district(district)
    }
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
                    if facility != .auction {
                        FacilityHeader(facility: facility)
                    }
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
            .navigationTitle(facility == .auction ? "オークション" : facility.shortName)
            .navigationBarTitleDisplayMode(.inline)
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
            MonthlyReportHistoryCard()
            BrandDashboardCard()
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

private struct MonthlyReportHistoryCard: View {
    @EnvironmentObject private var game: GameEngine
    @State private var selectedReport: MonthlyPLReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "月次PL", subtitle: "毎月の最終週終了時に4週間を集計")
            if game.monthlyReports.isEmpty {
                Label("最初の月末に月次経営レポートが作成されます", systemImage: "calendar.badge.clock")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(game.monthlyReports.prefix(3)) { report in
                    Button {
                        selectedReport = report
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(report.year)年\(report.month)月").font(.subheadline.bold())
                                Text("売上 \(report.revenue.currency)・\(report.sales)台")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(report.operatingProfit.currency)
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(report.operatingProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .gameCard()
        .sheet(item: $selectedReport) { report in
            MonthlyPLDashboardView(report: report)
        }
    }
}

private struct BrandDashboardCard: View {
    @EnvironmentObject private var game: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "ブランド・知名度",
                subtitle: "広告、口コミ、専門実績で上昇。ブーム時は既に認知された専門店へ来店が集中"
            )
            ForEach(game.stores) { store in
                let recognition = game.storeRecognitionScore(for: store)
                let profiles = game.specialtyBrandProfiles(for: store)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.name).font(.subheadline.bold())
                            Text(game.derivedBusinessName(for: store)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        CapsuleLabel(
                            text: "店舗知名度 \(recognition)",
                            color: recognition >= 60 ? GameTheme.teal : GameTheme.orange,
                            icon: "star.circle.fill"
                        )
                    }
                    ProgressView(value: Double(recognition), total: 100)
                        .tint(recognition >= 60 ? GameTheme.teal : GameTheme.orange)
                    ForEach(profiles.prefix(3)) { profile in
                        HStack {
                            Label(profile.productKind.name, systemImage: brandIcon(profile.productKind))
                                .font(.caption.bold())
                            Spacer()
                            if store.certifiedSpecialties.contains(profile.productKind) {
                                CapsuleLabel(
                                    text: "認定Lv.\(game.specialtyCertificationTier(for: store, productKind: profile.productKind))",
                                    color: profile.productKind == .collector ? GameTheme.orange : .purple,
                                    icon: "checkmark.seal.fill"
                                )
                            }
                            Text("\(profile.tierName) \(profile.recognition)/100")
                                .font(.caption2.bold().monospacedDigit())
                                .foregroundStyle(profile.recognition >= 40 ? GameTheme.teal : .secondary)
                            if profile.firstMoverBonusPercent > 0 {
                                CapsuleLabel(
                                    text: "先行者 +\(profile.firstMoverBonusPercent)%",
                                    color: .purple,
                                    icon: "bolt.fill"
                                )
                            }
                        }
                    }
                }
                .padding(10)
                .background(GameTheme.navy.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            Text("スポーツ／クラシックは、設備・担当者・技術・実績・知名度の条件を満たすと認定専門店になります。認定後は地区外からの来店、買取、持ち込み改造が段階的に増えます。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .gameCard()
    }

    private func brandIcon(_ productKind: MarketProductKind) -> String {
        switch productKind {
        case .camper: "tent.fill"
        case .outdoor: "mountain.2.fill"
        case .collector: "clock.arrow.circlepath"
        case .workCargo: "shippingbox.fill"
        case .sportTuned: "flag.checkered"
        case .welfare: "figure.roll"
        case .mobileSales: "truck.box.fill"
        case .kitchenCar: "fork.knife"
        case .refurbished, .repaired: "wrench.and.screwdriver.fill"
        case .standard: "car.side.fill"
        }
    }
}

private struct StoreNetworkContent: View {
    @EnvironmentObject private var game: GameEngine
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "店舗ネットワーク", subtitle: "在庫の融通と各店舗の社員運用状況を確認")
            ForEach(game.stores) { store in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(store.name).font(.subheadline.bold())
                            Text("在庫\(store.inventoryCount)/\(store.type.capacity)台・入庫予定\(game.incomingCount(for: store.id))台").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        let employeeOperated = [
                            store.salesControlMode,
                            store.researchControlMode,
                            store.procurementControlMode,
                            store.serviceControlMode
                        ].filter { $0 == .employee }.count
                        CapsuleLabel(
                            text: employeeOperated == 0 ? "オーナー運用" : "社員運用 \(employeeOperated)/4",
                            color: employeeOperated == 4 ? GameTheme.teal : GameTheme.navy,
                            icon: employeeOperated == 0 ? "person.fill" : "person.3.fill"
                        )
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
    @State private var selectedStoreID: UUID?
    @State private var message: String?
    @State private var category: VehicleCategory?
    @State private var origin: VehicleOrigin?
    @State private var modelID: String?
    @State private var unbidOnly = false
    @State private var sort: AuctionListingSort = .reservePrice

    private enum AuctionListingSort: String, CaseIterable, Identifiable {
        case reservePrice, expectedProfit, winChance, newest
        var id: String { rawValue }
        var name: String {
            switch self {
            case .reservePrice: "開始価格"
            case .expectedProfit: "予測粗利"
            case .winChance: "落札見込"
            case .newest: "新着"
            }
        }
        var icon: String {
            switch self {
            case .reservePrice: "yensign.circle"
            case .expectedProfit: "chart.line.uptrend.xyaxis"
            case .winChance: "percent"
            case .newest: "clock.badge"
            }
        }
    }

    private var selectedStore: Store? {
        game.stores.first(where: { $0.id == selectedStoreID }) ?? game.stores.first
    }
    private var listings: [AuctionListing] {
        let storeID = selectedStore?.id
        return game.auctionListings.filter { listing in
            let model = VehicleCatalog.entry(id: listing.modelID)
            return (category == nil || listing.category == category)
                && (origin == nil || model?.origin == origin)
                && (modelID == nil || listing.modelID == modelID)
                && (!unbidOnly || !game.bidReservations.contains { $0.listingID == listing.id })
        }.sorted { left, right in
            switch sort {
            case .reservePrice:
                return left.reservePrice < right.reservePrice
            case .expectedProfit:
                guard let storeID else { return left.reservePrice < right.reservePrice }
                let leftProfit = game.auctionExpectedGrossProfit(for: left, storeID: storeID, maxPrice: left.marketPrice) ?? Int.min
                let rightProfit = game.auctionExpectedGrossProfit(for: right, storeID: storeID, maxPrice: right.marketPrice) ?? Int.min
                return leftProfit > rightProfit
            case .winChance:
                return game.auctionBidWinChance(for: left, maxPrice: left.marketPrice)
                    > game.auctionBidWinChance(for: right, maxPrice: right.marketPrice)
            case .newest:
                return left.createdTurn > right.createdTurn
            }
        }
    }
    private var bidResults: [AuctionBidResult] {
        game.auctionBidResults.filter { result in
            selectedStore == nil || result.storeID == selectedStore?.id
        }
    }
    private var availableModels: [VehicleCatalogEntry] {
        let ids = Set(game.auctionListings.filter {
            (category == nil || $0.category == category)
                && (origin == nil || VehicleCatalog.entry(id: $0.modelID)?.origin == origin)
        }.map(\.modelID))
        return ids.compactMap(VehicleCatalog.entry(id:)).sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        VStack(spacing: 14) {
            if game.stores.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("入庫店舗", selection: Binding(get: { selectedStore?.id }, set: { selectedStoreID = $0 })) {
                        ForEach(game.stores) { store in Text(store.name).tag(Optional(store.id)) }
                    }
                }
                .gameCard()
            }
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    SectionTitle(title: "出品車両")
                    Spacer()
                    Text("\(listings.count)台・入札\(game.bidReservations.count)件")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.indigo)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                    Menu {
                        Button { category = nil } label: { Label("全カテゴリ", systemImage: "square.grid.2x2") }
                        ForEach(VehicleCategory.allCases) { item in
                            Button { category = item } label: { Label(item.name, systemImage: item.icon) }
                        }
                    } label: {
                        auctionFilterLabel(category?.name ?? "カテゴリ", icon: category?.icon ?? "square.grid.2x2", active: category != nil)
                    }
                    Menu {
                        Button { origin = nil } label: { Label("国内外すべて", systemImage: "globe.asia.australia.fill") }
                        ForEach(VehicleOrigin.allCases, id: \.self) { item in
                            Button { origin = item } label: { Label(item.name, systemImage: item.icon) }
                        }
                    } label: {
                        auctionFilterLabel(origin?.name ?? "生産国", icon: origin?.icon ?? "globe.asia.australia.fill", active: origin != nil)
                    }
                    Menu {
                        Button { modelID = nil } label: { Label("全車種", systemImage: "car.side.fill") }
                        ForEach(availableModels, id: \.id) { model in
                            Button { modelID = model.id } label: { Label(model.fullName, systemImage: model.category.icon) }
                        }
                    } label: {
                        let model = modelID.flatMap(VehicleCatalog.entry(id:))
                        auctionFilterLabel(model?.modelName ?? "車種", icon: model?.category.icon ?? "car.side.fill", active: model != nil)
                    }
                    Menu {
                        ForEach(AuctionListingSort.allCases) { item in
                            Button { sort = item } label: { Label(item.name, systemImage: item.icon) }
                        }
                    } label: {
                        auctionFilterLabel(sort.name, icon: sort.icon, active: sort != .reservePrice)
                    }
                    Toggle(isOn: $unbidOnly) {
                        auctionFilterLabel("未入札", icon: unbidOnly ? "checkmark.circle.fill" : "circle", active: unbidOnly)
                    }
                    .toggleStyle(.button)
                }
                if let store = selectedStore {
                    LazyVStack(spacing: 0) {
                        ForEach(listings) { listing in
                            AuctionBidRow(listing: listing, storeID: store.id) { message = $0 }
                            if listing.id != listings.last?.id { Divider() }
                        }
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
                    SectionTitle(title: "自社在庫を出品")
                    ForEach(store.inventory.filter { $0.count > 0 && !$0.isInWorkshop }) { batch in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(batch.vehicleName).font(.subheadline.bold())
                                Text("\(batch.category.name)・簿価\(batch.averageCost.currency)・\(batch.condition.displayText)・#\(batch.id.uuidString.prefix(4).uppercased())").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("1台出品") {
                                message = game.consignInventory(storeID: store.id, inventoryID: batch.id) ? "翠浜AAへ1台出品しました" : "出品できませんでした"
                            }.buttonStyle(.bordered).tint(.indigo)
                        }
                    }
                }.gameCard()
            }
            if !game.inboundShipments.isEmpty || !game.auctionConsignments.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    SectionTitle(title: "進行中", subtitle: "入庫と出品成約は週間処理で進みます")
                    ForEach(game.inboundShipments) { shipment in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "truck.box.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(shipment.source.name)・\(shipment.vehicleName) \(shipment.count)台")
                                    .font(.subheadline.bold())
                                Text("あと\(shipment.monthsRemaining)週間・\(shipment.dispositionPlan.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu {
                                Button("通常販売") {
                                    _ = game.setInboundDisposition(shipment.id, plan: .retail)
                                }
                                Menu("カスタム予定") {
                                    ForEach(WorkshopProjectKind.allCases.filter { $0.usesCustomizationBay }) { kind in
                                        Button(kind.name) {
                                            _ = game.setInboundDisposition(
                                                shipment.id,
                                                plan: .customization(kind: kind, grade: .middle)
                                            )
                                        }
                                    }
                                }
                            } label: {
                                Label("用途", systemImage: "slider.horizontal.3")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 3)
                    }
                    ForEach(game.auctionConsignments) { order in
                        FacilityRow("出品中・\(order.vehicleName) \(order.count)台", "成約まで\(order.monthsRemaining)週間", tint: .indigo)
                    }
                }.gameCard()
            }
        }
        .onAppear { if selectedStoreID == nil { selectedStoreID = game.stores.first?.id } }
        .alert("仕入れ・出品", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }

    private func auctionFilterLabel(_ text: String, icon: String, active: Bool) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(active ? Color.white : GameTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .frame(minHeight: 34)
            .background(active ? Color.indigo : GameTheme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
    private var automaticInstruction: ProcurementInstruction? {
        reservation?.instructionID.flatMap { id in game.procurementInstructions.first { $0.id == id } }
    }
    private var retailReferencePrice: Int? {
        guard let store = game.stores.first(where: { $0.id == storeID }),
              let plot = game.plot(id: store.plotID) else { return nil }
        return game.vehicleRetailValue(
            modelID: listing.modelID,
            category: listing.category,
            modelYear: listing.modelYear,
            mileage: listing.mileage,
            quality: listing.quality,
            in: plot.district
        )
    }
    private var bidStep: Int { game.auctionBidStep(for: listing) }
    private var bidUpperBound: Int {
        max(listing.reservePrice + bidStep, listing.marketPrice * 8 / 5, (retailReferencePrice ?? 0) * 11 / 10)
    }
    private var expectedGrossProfit: Int? {
        game.auctionExpectedGrossProfit(
            for: listing,
            storeID: storeID,
            maxPrice: maxPrice
        )
    }
    private var restorationCost: Int {
        game.restorationQuote(
            category: listing.category,
            fault: listing.fault,
            condition: listing.condition,
            storeID: storeID
        ).finalCost
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 9) {
                Image(systemName: listing.category.icon).foregroundStyle(.indigo).frame(width: 30, height: 30).background(Color.indigo.opacity(0.1)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.vehicleName)
                        .font(.subheadline.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5) {
                        if VehicleCatalog.entry(id: listing.modelID)?.isRareClassic == true {
                            Text("希少旧車").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(GameTheme.orange).clipShape(Capsule())
                        }
                        if let model = VehicleCatalog.entry(id: listing.modelID), model.origin == .imported {
                            Text("需要 \(Int((model.customerDemandIndex * 100).rounded()))")
                                .font(.caption2.bold())
                                .foregroundStyle(.indigo)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.indigo.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(listing.category.name)・\(String(listing.modelYear))年・\(listing.mileage.formatted())km・\(listing.condition.displayText)・\(listing.fault.name)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), alignment: .leading)], alignment: .leading, spacing: 4) {
                auctionPriceMetric("開始", listing.reservePrice.currency, tint: GameTheme.ink)
                auctionPriceMetric("落札相場", listing.marketPrice.currency, tint: GameTheme.ink.opacity(0.65))
                if let retailReferencePrice {
                    auctionPriceMetric("店頭参考", retailReferencePrice.currency, tint: GameTheme.teal)
                }
                auctionPriceMetric("諸費用", "+\((listing.lane.fee + listing.lane.shippingCost).currency)", tint: GameTheme.orange)
                auctionPriceMetric("修繕費", restorationCost.currency, tint: GameTheme.orange)
            }
            if let automaticInstruction {
                Label(
                    "自動入札：\(automaticInstruction.targetName)・上限\(reservation?.maxPrice.currency ?? "—")",
                    systemImage: "gearshape.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(GameTheme.teal)
            } else {
                if let expectedGrossProfit {
                    Label(
                        "入札上限価格で落札した場合の推定粗利 \(expectedGrossProfit.currency)",
                        systemImage: expectedGrossProfit >= 0
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(expectedGrossProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                }
                VStack(spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            bidLimitControl
                            winChanceLabel
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            bidLimitControl
                            winChanceLabel
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            bidActionButton
                            if reserved { cancelBidButton }
                        }
                        VStack(spacing: 6) {
                            bidActionButton
                            if reserved { cancelBidButton }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .onAppear {
            if let reservation { maxPrice = reservation.maxPrice }
        }
    }

    private var bidLimitControl: some View {
        Stepper(
            "上限 \(maxPrice.currency)",
            value: $maxPrice,
            in: listing.reservePrice...bidUpperBound,
            step: bidStep
        )
        .font(.caption.bold())
    }

    private var winChanceLabel: some View {
        Text("見込 \(Int(game.auctionBidWinChance(for: listing, maxPrice: maxPrice) * 100))%")
            .font(.caption2.bold().monospacedDigit())
            .foregroundStyle(listing.lane.tint)
            .lineLimit(1)
    }

    private var bidActionButton: some View {
        let workEffort = game.transactionWorkEffort(for: listing.category)
        return Button(reserved ? "入札額を変更" : "この上限で入札（\(workEffort)工数）") {
            result(
                game.reserveBid(listingID: listing.id, storeID: storeID, maxPrice: maxPrice)
                    ? "上限\(maxPrice.currency)で入札しました。結果は次の週間処理で確定します"
                    : "入庫枠を確保できません"
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(listing.lane.tint)
        .frame(maxWidth: .infinity)
        .disabled(!reserved && game.ownerRemainingWorkEffort < workEffort)
    }

    private var cancelBidButton: some View {
        Button("取消") {
            game.cancelBid(listingID: listing.id)
            result("入札を取り消しました")
        }
        .buttonStyle(.bordered)
        .tint(.gray)
    }

    private func auctionPriceMetric(_ title: String, _ value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(title).foregroundStyle(.secondary)
            Text(value).foregroundStyle(tint).bold().monospacedDigit()
        }
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private struct AuctionBidResultRow: View {
    @EnvironmentObject private var game: GameEngine
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
                if let winner = game.auctionWinnerName(for: result) {
                    Text("落札者 \(winner)").font(.caption2.bold()).foregroundStyle(GameTheme.orange)
                }
            }
        }
    }
}

private struct BankContent: View {
    @EnvironmentObject private var game: GameEngine
    var body: some View {
        VStack(spacing: 14) {
            HStack { MetricView(title: "信用評価", value: game.creditRating, tint: game.creditRating == "C" ? GameTheme.orange : GameTheme.teal); MetricView(title: "融資上限", value: game.borrowingLimit.currency); MetricView(title: "借入残高", value: game.debt.currency) }.gameCard()
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "融資・返済", subtitle: "所有地は担保に反映。赤字や資金危機は信用枠を縮小")
                ProgressView(value: Double(game.debt), total: Double(max(1, game.borrowingLimit))).tint(.blue)
                HStack { Button("1,000万円借入") { game.borrow(1_000) }.buttonStyle(.borderedProminent).tint(.blue).disabled(game.debt + 1_000 > game.borrowingLimit); Button("1,000万円返済") { game.repay(1_000) }.buttonStyle(.bordered).disabled(game.cash < 1_000 || game.debt == 0) }
                Label("借入利息は週間処理で計上されます。元本は任意返済です。", systemImage: "calendar.badge.clock").font(.caption).foregroundStyle(.secondary)
                if let warning = game.financialDistressMessage {
                    Label(warning, systemImage: "exclamationmark.triangle.fill").font(.caption.bold()).foregroundStyle(GameTheme.danger)
                }
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
            SectionTitle(title: "整備・商品化キュー", subtitle: "整備担当と対応設備の空きベイがあれば内製し、それ以外は外注します")
            ForEach(game.stores) { store in
                VStack(alignment: .leading, spacing: 6) {
                    let customerOrders = game.customizationOrders(for: store.id)
                    let activeCustomerOrders = customerOrders.filter { $0.status == .active }.count
                    let inHouseProjects = store.inventory.filter { $0.workshopProject?.outsourced == false }.count
                        + activeCustomerOrders
                    HStack {
                        Text(store.name).font(.subheadline.bold())
                        Spacer()
                        Text("週\(store.weeklyWorkshopLabor)工数・稼働\(inHouseProjects)／整備\(store.serviceBays)・カスタム\(store.customizationBays)ベイ").font(.caption.bold())
                    }
                    ForEach(customerOrders) { order in
                        let orderProductKind = MarketProductKind.resolve(
                            productState: order.kind.productState ?? .stock,
                            isRareClassic: VehicleCatalog.entry(id: order.modelID)?.isRareClassic == true
                        )
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label("持ち込み：\(order.vehicleName)", systemImage: order.kind.icon)
                                    .font(.caption.bold())
                                Spacer()
                                CapsuleLabel(
                                    text: order.status == .active ? "作業中" : "受注待ち",
                                    color: order.status == .active ? .purple : GameTheme.orange,
                                    icon: order.status == .active ? "wrench.and.screwdriver.fill" : "person.crop.circle.badge.plus"
                                )
                            }
                            Text("\(order.kind.name)・\(order.grade.name(for: orderProductKind))・売上\(order.quotedRevenue.currency)・材料\(order.materialCost.currency)・粗利\(order.expectedGrossProfit.currency)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if order.status == .active {
                                HStack {
                                    ProgressView(
                                        value: Double(order.requiredWork - order.remainingWork),
                                        total: Double(order.requiredWork)
                                    )
                                    .tint(.purple)
                                    Text("残り\(order.remainingWork)工数").font(.caption2.bold())
                                    Button("優先") {
                                        game.setCustomizationOrderPriority(order.id, priority: min(3, order.priority + 1))
                                    }
                                    .font(.caption2.bold())
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                HStack {
                                    Button("受注する") {
                                        message = game.acceptCustomizationOrder(order.id)
                                            ? "\(order.kind.name) \(order.grade.name(for: orderProductKind))を受注し、材料を手配しました。"
                                            : "材料費、担当者、対応ベイの空きを確認してください。"
                                    }
                                    .font(.caption2.bold())
                                    .buttonStyle(.borderedProminent)
                                    .tint(.purple)
                                    Button("見送る", role: .destructive) {
                                        game.declineCustomizationOrder(order.id)
                                    }
                                    .font(.caption2.bold())
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.purple.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
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
                                        if let grade = batch.productGrade {
                                            CapsuleLabel(text: grade.name(for: game.marketProductKind(for: batch)), color: GameTheme.orange, icon: "star.fill")
                                        }
                                        if let issue = batch.disclosedIssue {
                                            CapsuleLabel(text: "告知：\(issue.name)", color: GameTheme.danger, icon: "exclamationmark.triangle.fill")
                                        }
                                    }
                                    Text("\(String(batch.modelYear))年式・\(batch.mileage.formatted())km・\(batch.condition.displayText)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            if let project = batch.workshopProject {
                                HStack {
                                    let projectProductKind = MarketProductKind.resolve(
                                        productState: project.kind.productState ?? batch.productState,
                                        isRareClassic: batch.isRareClassic
                                    )
                                    Label(
                                        project.targetGrade.map { "\(project.kind.name)・\($0.name(for: projectProductKind))" } ?? project.kind.name,
                                        systemImage: project.kind.icon
                                    ).font(.caption2.bold()).foregroundStyle(.purple)
                                    if project.outsourced {
                                        ProgressView(value: Double(max(0, project.totalWeeks - project.remainingWeeks)), total: Double(project.totalWeeks)).tint(.purple)
                                        Text("外注・あと\(project.remainingWeeks)週").font(.caption2.bold().monospacedDigit())
                                    } else {
                                        ProgressView(value: Double(project.requiredWork - project.remainingWork), total: Double(project.requiredWork)).tint(.purple)
                                        Text("残り\(project.remainingWork)工数").font(.caption2.bold().monospacedDigit())
                                    }
                                }
                            } else {
                                let previews = WorkshopProjectKind.allCases.flatMap { kind in
                                    let productKind = MarketProductKind.resolve(
                                        productState: kind.productState ?? batch.productState,
                                        isRareClassic: batch.isRareClassic
                                    )
                                    let isGradeProject = productKind.supportsGrades
                                        && ![WorkshopProjectKind.basicService, .repair].contains(kind)
                                        && (kind != .refurbishment || batch.isRareClassic)
                                    let grades: [SpecialtyProductGrade?] = isGradeProject
                                        ? SpecialtyProductGrade.allCases.map(Optional.some)
                                        : [nil]
                                    return grades.compactMap { grade in
                                        game.workshopProjectPreview(
                                            storeID: store.id,
                                            inventoryID: batch.id,
                                            kind: kind,
                                            grade: grade,
                                            fulfillment: .automatic
                                        )
                                        }
                                }
                                if previews.isEmpty {
                                    Text("現金、車種条件、または車両状態を確認してください").font(.caption2).foregroundStyle(.secondary)
                                } else {
                                    Menu {
                                        ForEach(Array(previews.enumerated()), id: \.offset) { _, preview in
                                            Button(
                                                "\(preview.kind.name)"
                                                    + (preview.grade.map {
                                                        "・\($0.name(for: MarketProductKind.resolve(productState: preview.kind.productState ?? batch.productState, isRareClassic: batch.isRareClassic)))"
                                                    } ?? "")
                                                    + "・\(preview.fulfillmentMode.name)"
                                                    + "｜必要コスト\(preview.cost.currency)・納期\(preview.estimatedWeeks)週"
                                                    + "・想定販売価格\(preview.projectedSalePrice.currency)"
                                            ) {
                                                message = game.startWorkshopProject(
                                                    storeID: store.id,
                                                    inventoryID: batch.id,
                                                    kind: preview.kind,
                                                    grade: preview.grade,
                                                    fulfillment: preview.fulfillmentMode
                                                )
                                                    ? "\(preview.kind.name)\(preview.grade.map { "・\($0.name(for: MarketProductKind.resolve(productState: preview.kind.productState ?? batch.productState, isRareClassic: batch.isRareClassic)))" } ?? "")を\(preview.fulfillmentMode.name)で開始しました。販売目安は\(preview.projectedSalePrice.currency)です。"
                                                    : "現金、ベイ、担当者を確認してください。"
                                            }.disabled(game.cash < preview.cost)
                                        }
                                    } label: { Label("カスタマイズを選ぶ", systemImage: "paintbrush.pointed.fill") }
                                    .font(.caption2.bold()).buttonStyle(.borderedProminent).tint(.purple)
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
            SectionTitle(title: "店員採用", subtitle: "販売・仕入・調査・整備の4能力と個別給与を比較")
            ForEach(game.stores) { store in
                let candidate = game.employeeCandidates(for: store.id).first
                HStack(spacing: 10) {
                    if let candidate {
                        CharacterAvatarView(
                            role: candidate.characterAvatarRole,
                            seed: candidate.characterAvatarSeed,
                            size: 44
                        )
                    }
                    VStack(alignment: .leading) {
                        Text(store.name).font(.subheadline.bold())
                        Text("店員 \(store.staff)名・給与 \(store.employeeMonthlyPayroll.currency)/月")
                            .font(.caption).foregroundStyle(.secondary)
                        if let candidate {
                            Text("候補 \(candidate.name)｜販売\(candidate.salesSkill)・仕入\(candidate.procurementSkill)・\(candidate.monthlySalary.currency)/月")
                                .font(.caption2).foregroundStyle(GameTheme.teal)
                        }
                    }
                    Spacer()
                    if let candidate {
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
            Text("ガソリン価格・日経平均・中古車需要は毎週緩やかに変化します。戦争や原油供給、金融市場のイベント時は大きく動きます。").font(.caption).foregroundStyle(.secondary)
        }.gameCard()
    }
}

private struct FacilityRow: View {
    let title: String; let value: String; var tint: Color = GameTheme.ink
    init(_ title: String, _ value: String, tint: Color = GameTheme.ink) { self.title = title; self.value = value; self.tint = tint }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(value).font(.subheadline.bold().monospacedDigit()).foregroundStyle(tint).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline)
                Text(value).font(.subheadline.bold().monospacedDigit()).foregroundStyle(tint)
            }
        }
        .padding(.vertical, 3)
    }
}
