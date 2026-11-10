import SwiftUI

struct CityMapView: View {
    @EnvironmentObject private var game: GameEngine
    @Binding var isExpanded: Bool
    @State private var layer: MapLayer = CommandLine.arguments.contains("-demo-competition") ? .competition : (CommandLine.arguments.contains("-demo-vehicle-demand") ? .vehicleDemand : .normal)
    @State private var demandCategory: VehicleCategory = .kei
    @State private var selectedPlot: LandPlot?
    @State private var selectedFacility: MapFacility?
    @State private var focusRequest: MapFocusRequest?
    @State private var showSearch = false
    @State private var showNationalMap = false
    @State private var showCompanyDashboard = false
    @State private var showMarketNewspaper = false
    @State private var didOpenDemoFacility = false
    @State private var showGuideProfitLoss = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    GridCityMapSurface(
                        layer: layer,
                        demandCategory: demandCategory,
                        selectedPlot: $selectedPlot,
                        selectedFacility: $selectedFacility,
                        focusRequest: focusRequest,
                        isExpanded: isExpanded,
                        toggleExpanded: { isExpanded.toggle() }
                    )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 8) {
                            GuideToggleButton()
                            MapCityPlaque()
                            Spacer(minLength: 0)
                            Button { showSearch = true } label: {
                                GameIconTile(title: "マップ検索", icon: "magnifyingglass", size: 38, showsTitle: false)
                            }
                            .buttonStyle(.gamePress)
                            Menu {
                                ForEach(MapLayer.allCases) { item in
                                    if item == .vehicleDemand {
                                        Menu {
                                            ForEach(VehicleCategory.allCases) { category in
                                                Button {
                                                    demandCategory = category
                                                    withAnimation(.easeInOut(duration: 0.25)) { layer = .vehicleDemand }
                                                } label: { Label(category.name, systemImage: category.icon) }
                                            }
                                        } label: {
                                            Label(item.name, systemImage: item.icon)
                                        }
                                    } else {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.25)) { layer = item }
                                        } label: {
                                            Label(item.name, systemImage: item.icon)
                                        }
                                    }
                                }
                            } label: {
                                GameIconTile(
                                    title: layer.name,
                                    icon: "square.3.layers.3d.top.filled",
                                    tint: layer == .normal ? GameTheme.hudTop : GameTheme.orange,
                                    size: 38,
                                    showsTitle: false
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        if layer != .normal {
                            MapLayerBanner(layer: layer, demandCategory: demandCategory) {
                                withAnimation(.easeInOut(duration: 0.25)) { layer = .normal }
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 6)
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            AdvanceWeekButton()
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                        if !isExpanded {
                            MapDock(
                                openStore: { store in
                                    guard let plot = game.plot(id: store.plotID) else { return }
                                    focusRequest = MapFocusRequest(plotID: plot.id)
                                    selectedPlot = plot
                                },
                                openFacility: { selectedFacility = $0 },
                                openCompany: { showCompanyDashboard = true },
                                openNewspaper: { showMarketNewspaper = true },
                                openNational: { showNationalMap = true }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    GuideFloatingPanel(bounds: proxy.size, perform: handleGuideAction)
                }
            }
            .background(Color(red: 0.24, green: 0.62, blue: 0.80))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedPlot) { plot in
                PlotDetailView(plotID: plot.id).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedFacility) { facility in
                FacilityHubSheet(facility: facility) { plot in
                    focusRequest = MapFocusRequest(plotID: plot.id)
                    selectedPlot = plot
                }
                .presentationDetents([.height(270), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSearch) {
                MapSearchView { facility in selectedFacility = facility; showSearch = false } focusDistrict: { kind in
                    focusRequest = MapFocusRequest(district: kind); showSearch = false
                }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCompanyDashboard) {
                CompanyDashboardView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showMarketNewspaper) {
                MarketNewspaperView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showNationalMap) {
                NationalExpansionView()
            }
            .sheet(isPresented: $showGuideProfitLoss) {
                GuideProfitLossLessonView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear(perform: openDemoFacilityIfNeeded)
        }
    }

    /// ガイドカードの誘導ボタンから、該当画面へ移動します。
    private func handleGuideAction(_ action: GuideAction) {
        switch action {
        case .focusRecommendedPlot:
            guard let plot = game.recommendedFoundingPlot else { return }
            focusRequest = MapFocusRequest(plotID: plot.id)
        case .openChosenPlot:
            let target = game.tutorialPlotID.flatMap { game.plot(id: $0) } ?? game.recommendedFoundingPlot
            guard let target else { return }
            focusRequest = MapFocusRequest(plotID: target.id)
            selectedPlot = target
        case .openStore(let panel):
            guard let store = game.stores.first, let plot = game.plot(id: store.plotID) else { return }
            game.requestGuideStorePanel(panel)
            focusRequest = MapFocusRequest(plotID: plot.id)
            selectedPlot = plot
        case .openWeeklyReport:
            guard game.lastReport != nil else { return }
            game.presentLatestWeeklyReport()
        case .openProfitLossLesson:
            showGuideProfitLoss = true
        }
    }

    private func openDemoFacilityIfNeeded() {
        guard !didOpenDemoFacility else { return }
        let facility: MapFacility? = if CommandLine.arguments.contains("-demo-auction") {
            .auction
        } else if CommandLine.arguments.contains("-demo-workshop") {
            .workshop
        } else {
            nil
        }
        guard let facility else { return }
        selectedFacility = facility
        didOpenDemoFacility = true
    }

}

/// マップ左上の都市名プレート。自社と競合の店舗数を常に示します。
private struct MapCityPlaque: View {
    @EnvironmentObject private var game: GameEngine

    var body: some View {
        HStack(spacing: 8) {
            Text("翠浜市")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 3) {
                Image(systemName: "flag.fill").font(.system(size: 9, weight: .black))
                Text("\(game.stores.count)")
            }
            .foregroundStyle(GameTheme.mint)
            HStack(spacing: 3) {
                Image(systemName: "flag.fill").font(.system(size: 9, weight: .black))
                Text("\(game.competitors.reduce(0) { $0 + $1.plotIDs.count })")
            }
            .foregroundStyle(Color(red: 1, green: 0.70, blue: 0.42))
        }
        .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
        .shadow(color: .black.opacity(0.35), radius: 0, y: 1)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .gameHUDPlate(cornerRadius: 11)
        .padding(.bottom, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("翠浜市 自社\(game.stores.count)店舗 競合\(game.competitors.reduce(0) { $0 + $1.plotIDs.count })店舗")
    }
}

/// 分析レイヤーを表示している間だけ出る説明帯。
private struct MapLayerBanner: View {
    let layer: MapLayer
    let demandCategory: VehicleCategory
    let close: () -> Void

    private var detail: String {
        switch layer {
        case .demand: "地区ごとに固定された今週の購入需要です"
        case .vehicleDemand: "\(demandCategory.name)の需要が強い地域を表示"
        case .competition: "固定需要を自社と競合の商圏で奪い合います"
        default: "青＝低い　緑＝中間　橙＝高い"
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: layer.icon)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(GameTheme.gold)
            VStack(alignment: .leading, spacing: 1) {
                Text(layer.name)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("通常表示に戻す")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .gameHUDPlate(cornerRadius: 11)
        .padding(.bottom, 3)
    }
}

/// 画面下端のメインメニュー。街づくりゲームのドックにあたります。
private struct MapDock: View {
    @EnvironmentObject private var game: GameEngine
    let openStore: (Store) -> Void
    let openFacility: (MapFacility) -> Void
    let openCompany: () -> Void
    let openNewspaper: () -> Void
    let openNational: () -> Void

    private static let tileSize: CGFloat = 52

    var body: some View {
        HStack(spacing: 0) {
            slot {
                if game.stores.count == 1, let store = game.stores.first {
                    Button { openStore(store) } label: { storeTile }
                        .buttonStyle(.gamePress)
                } else {
                    Menu {
                        ForEach(game.stores) { store in
                            Button { openStore(store) } label: {
                                Label(store.name, systemImage: "storefront.fill")
                            }
                        }
                    } label: { storeTile }
                    .disabled(game.stores.isEmpty)
                    .saturation(game.stores.isEmpty ? 0.1 : 1)
                }
            }
            slot {
                Button { openFacility(.auction) } label: {
                    tile("仕入れ", MapFacility.auction.icon, Color(red: 0.48, green: 0.36, blue: 0.86))
                }
                .buttonStyle(.gamePress)
                .accessibilityLabel("オークション会場")
            }
            slot {
                Menu {
                    ForEach(MapFacility.allCases.filter { $0 != .auction }) { facility in
                        Button { openFacility(facility) } label: {
                            Label(facility.shortName, systemImage: facility.icon)
                        }
                    }
                } label: {
                    tile("施設", "building.columns.fill", Color(red: 0.20, green: 0.52, blue: 0.86))
                }
            }
            slot {
                Button(action: openCompany) {
                    tile("経営", "chart.bar.xaxis", GameTheme.orange)
                }
                .buttonStyle(.gamePress)
            }
            slot {
                Button(action: openNewspaper) {
                    tile("新聞", "newspaper.fill", Color(red: 0.55, green: 0.44, blue: 0.30))
                }
                .buttonStyle(.gamePress)
            }
            slot {
                Button(action: openNational) {
                    tile("全国", "globe.asia.australia.fill", Color(red: 0.26, green: 0.66, blue: 0.30))
                }
                .buttonStyle(.gamePress)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 9)
        .padding(.bottom, 4)
        .background(
            GameTheme.hudGradient
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        Rectangle().fill(GameTheme.hudEdge).frame(height: 2)
                        Rectangle().fill(GameTheme.gold).frame(height: 2)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var storeTile: some View {
        tile("店舗", "storefront.fill", GameTheme.teal, badge: game.stores.count > 1 ? "\(game.stores.count)" : nil)
    }

    private func tile(_ title: String, _ icon: String, _ tint: Color, badge: String? = nil) -> some View {
        GameIconTile(title: title, icon: icon, tint: tint, size: Self.tileSize, badge: badge)
    }

    private func slot<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().frame(maxWidth: .infinity)
    }
}

private struct MapSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let selectFacility: (MapFacility) -> Void
    let focusDistrict: (DistrictKind) -> Void
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List {
                Section("経営施設") {
                    ForEach(MapFacility.allCases.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { facility in
                        Button { selectFacility(facility) } label: { Label(facility.name, systemImage: facility.icon).foregroundStyle(GameTheme.ink) }
                    }
                }
                Section("地区") {
                    ForEach(DistrictKind.allCases.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { kind in
                        Button { focusDistrict(kind) } label: { Label(kind.name, systemImage: kind.symbol).foregroundStyle(GameTheme.ink) }
                    }
                }
            }.searchable(text: $query, prompt: "施設・地区を検索").navigationTitle("マップ検索").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }
}

struct NationalExpansionView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCityID = "suihama"
    @State private var sourceStoreID: UUID?
    @State private var shippingCategory: VehicleCategory = .kei
    @State private var shippingCount = 1
    @State private var message: String?

    private var selectedCity: NationalCity {
        game.nationalCities.first(where: { $0.id == selectedCityID }) ?? game.nationalCities[0]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    nationalSummary
                    nationalExpansionQuest
                    NationalNetworkMap(cities: game.nationalCities, operations: game.regionalOperations, selection: $selectedCityID)
                    cityDetail(selectedCity)
                    if selectedCity.id != "suihama", game.regionalOperation(for: selectedCity.id) != nil {
                        logisticsCard(selectedCity)
                    }
                    nationalCampaign
                }
                .padding(15)
            }
            .background(GameTheme.cream)
            .navigationTitle("全国事業マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("翠浜市へ戻る") { dismiss() } }
            }
            .onAppear { sourceStoreID = sourceStoreID ?? game.stores.first?.id }
            .alert("全国展開", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private var nationalSummary: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("翠浜モーターズ 全国戦略室").font(.headline)
                    Text("本拠地の経営を維持しながら、地域市場へ進出します").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "globe.asia.australia.fill").font(.title).foregroundStyle(GameTheme.teal)
            }
            HStack {
                MetricView(title: "進出都市", value: "\(1 + game.regionalOperations.count)都市", tint: GameTheme.teal)
                MetricView(title: "域外店舗", value: "\(game.regionalOperations.reduce(0) { $0 + $1.networkStores })店")
                MetricView(title: "全国認知", value: "\(Int(game.nationalBrandStrength * 100))")
            }
        }
        .gameCard()
    }

    private var nationalExpansionQuest: some View {
        let status = game.milestoneStatuses.first(where: { $0.id == .nationalExpansion })
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: game.canExpandNationally ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(game.canExpandNationally ? GameTheme.teal : GameTheme.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.canExpandNationally ? "全国展開クエスト達成" : "全国展開クエスト")
                        .font(.subheadline.bold())
                    Text("企業価値4.5億円へ成長すると地域本社を開設できます")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(status?.progressText ?? "")
                    .font(.caption.bold().monospacedDigit())
            }
            ProgressView(value: status?.progress ?? 0)
                .tint(game.canExpandNationally ? GameTheme.teal : GameTheme.orange)
        }
        .gameCard()
    }

    @ViewBuilder private func cityDetail(_ city: NationalCity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: city.name, subtitle: "\(city.region)・人口\(city.population.formatted())人")
            HStack {
                MetricView(title: "所得", value: String(format: "%.2f", city.incomeIndex))
                MetricView(title: "地価", value: String(format: "%.2f", city.landPriceIndex))
                MetricView(title: "競争", value: String(format: "%.2f", city.competitionIndex))
                MetricView(title: "成長", value: String(format: "%+.1f%%", (city.growthRate - 1) * 100), tint: .green)
            }
            Label("主力需要：\(city.marketLabel)", systemImage: "car.2.fill")
                .font(.subheadline.bold()).foregroundStyle(GameTheme.navy)

            if city.id == "suihama" {
                Label("現在の本拠地。区画単位の店舗経営は翠浜市マップで行います。", systemImage: "star.fill")
                    .font(.caption).foregroundStyle(GameTheme.teal)
            } else if let operation = game.regionalOperation(for: city.id) {
                Divider()
                HStack {
                    MetricView(title: "販売網", value: "\(operation.networkStores)店舗")
                    MetricView(title: "地域在庫", value: "\(operation.inventoryCount)台")
                    MetricView(title: "前月販売", value: "\(operation.lastSales)台")
                    MetricView(title: "前月利益", value: operation.lastProfit.currency, tint: operation.lastProfit >= 0 ? GameTheme.teal : GameTheme.danger)
                }
                HStack(spacing: 10) {
                    expansionButton(title: "FC出店", detail: game.franchiseCost(in: city.id).currency, icon: "person.2.badge.plus", color: GameTheme.teal) {
                        message = game.openFranchise(in: city.id) ? "\(city.name)にフランチャイズ店を開設しました" : "資金または出店上限を確認してください"
                    }
                    expansionButton(title: "地場店M&A", detail: game.acquisitionCost(in: city.id).currency, icon: "building.2.crop.circle", color: .purple) {
                        message = game.acquireLocalDealer(in: city.id) ? "\(city.name)の地場販売店を取得しました" : "資金または買収上限を確認してください"
                    }
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("地域広告 \(operation.advertisingBudget.currency)/月").font(.caption.bold())
                    Slider(value: Binding(
                        get: { Double(game.regionalOperation(for: city.id)?.advertisingBudget ?? 0) },
                        set: { game.updateRegionalAdvertising(cityID: city.id, budget: Int($0)) }
                    ), in: 0...600, step: 20).tint(GameTheme.orange)
                }
            } else {
                Divider()
                Button {
                    message = game.establishRegionalOffice(in: city.id)
                        ? "\(city.name)に地域本社を開設しました"
                        : (game.canExpandNationally ? "開設資金が不足しています" : "企業価値4.5億円以上で全国展開が解放されます")
                } label: {
                    HStack {
                        Image(systemName: "building.2.fill")
                        VStack(alignment: .leading) {
                            Text("地域本社を開設").font(.headline)
                            Text("初期投資 \(city.expansionCost.currency)・輸送\(city.shippingMonths)週間").font(.caption)
                        }
                        Spacer()
                        Image(systemName: game.canExpandNationally ? "chevron.right" : "lock.fill")
                    }
                    .padding(13).foregroundStyle(.white).background(GameTheme.navy).clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .gameCard()
    }

    private func logisticsCard(_ city: NationalCity) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionTitle(title: "都市間物流", subtitle: "翠浜市の在庫を\(city.name)へ輸送")
            Picker("発送元店舗", selection: $sourceStoreID) {
                ForEach(game.stores) { store in Text(store.name).tag(Optional(store.id)) }
            }
            .pickerStyle(.menu)
            Picker("車種", selection: $shippingCategory) {
                ForEach(VehicleCategory.allCases) { category in Text(category.name).tag(category) }
            }
            .pickerStyle(.menu)
            Stepper("輸送台数 \(shippingCount)台", value: $shippingCount, in: 1...5)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("所要 \(city.shippingMonths)週間").font(.subheadline.bold())
                    Text("輸送費 \(Int((Double(city.shippingCostPerVehicle * shippingCount) * game.economicCostMultipliers.logistics).rounded()).currency)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("輸送を手配") {
                    guard let sourceStoreID else { message = "発送元店舗を選択してください"; return }
                    message = game.shipInventoryToRegion(cityID: city.id, from: sourceStoreID, category: shippingCategory, count: shippingCount)
                        ? "\(shippingCategory.name)\(shippingCount)台を発送しました"
                        : "対象在庫または輸送費が不足しています"
                }
                .buttonStyle(.gamePrimary).tint(GameTheme.teal)
            }
            let shipments = game.intercityShipments.filter { $0.destinationCityID == city.id }
            ForEach(shipments) { shipment in
                HStack {
                    Image(systemName: "truck.box.fill").foregroundStyle(GameTheme.orange)
                    Text("\(shipment.category.name) \(shipment.count)台").font(.caption.bold())
                    Spacer()
                    Text("あと\(shipment.monthsRemaining)週間").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .gameCard()
    }

    private var nationalCampaign: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "全国ブランド", subtitle: "進出都市すべての集客力を底上げ")
            HStack {
                Label("現在の全国認知度 \(Int(game.nationalBrandStrength * 100))", systemImage: "megaphone.fill")
                    .font(.subheadline.bold())
                Spacer()
                Button("全国広告 1,200万円") {
                    message = game.runNationalCampaign() ? "全国広告を開始しました" : "進出都市または現金が不足しています"
                }
                .buttonStyle(.gameSecondary).tint(GameTheme.orange)
            }
        }
        .gameCard()
    }

    private func expansionButton(title: String, detail: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.bold())
                Text(detail).font(.caption2)
            }
            .foregroundStyle(color).frame(maxWidth: .infinity, minHeight: 76)
            .background(color.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}

private struct NationalNetworkMap: View {
    let cities: [NationalCity]
    let operations: [RegionalOperation]
    @Binding var selection: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: [Color(red: 0.76, green: 0.88, blue: 0.94), Color(red: 0.91, green: 0.93, blue: 0.82)], startPoint: .top, endPoint: .bottom)
                Canvas { context, _ in
                    guard let home = cities.first(where: { $0.id == "suihama" }) else { return }
                    let start = CGPoint(x: home.mapX * size.width, y: home.mapY * size.height)
                    for city in cities where city.id != home.id {
                        let end = CGPoint(x: city.mapX * size.width, y: city.mapY * size.height)
                        var route = Path(); route.move(to: start); route.addLine(to: end)
                        let active = operations.contains(where: { $0.cityID == city.id })
                        context.stroke(route, with: .color(active ? GameTheme.teal.opacity(0.72) : Color.white.opacity(0.60)), style: StrokeStyle(lineWidth: active ? 3 : 1.5, dash: active ? [] : [5, 5]))
                    }
                }
                ForEach(cities) { city in
                    let active = city.id == "suihama" || operations.contains(where: { $0.cityID == city.id })
                    Button { selection = city.id } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(active ? GameTheme.teal : Color.gray.opacity(0.72)).frame(width: selection == city.id ? 48 : 40, height: selection == city.id ? 48 : 40)
                                Circle().stroke(.white, lineWidth: 3).frame(width: selection == city.id ? 48 : 40, height: selection == city.id ? 48 : 40)
                                Image(systemName: city.id == "suihama" ? "star.fill" : (active ? "building.2.fill" : "mappin"))
                                    .foregroundStyle(.white)
                            }
                            Text(city.name).font(.caption2.bold()).foregroundStyle(GameTheme.navy)
                                .padding(.horizontal, 6).padding(.vertical, 3).background(.white.opacity(0.88)).clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .position(x: city.mapX * size.width, y: city.mapY * size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.9), lineWidth: 2))
        }
        .frame(height: 345)
        .shadow(color: GameTheme.navy.opacity(0.16), radius: 10, y: 5)
    }
}
