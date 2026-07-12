import SwiftUI

struct CityMapView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var layer: MapLayer = CommandLine.arguments.contains("-demo-competition") ? .competition : (CommandLine.arguments.contains("-demo-vehicle-demand") ? .vehicleDemand : .normal)
    @State private var demandCategory: VehicleCategory = .kei
    @State private var selectedPlot: LandPlot?
    @State private var selectedFacility: MapFacility?
    @State private var focusRequest: MapFocusRequest?
    @State private var showSearch = false
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    IsometricCitySurface(layer: layer, demandCategory: demandCategory, selectedPlot: $selectedPlot, selectedFacility: $selectedFacility, focusRequest: focusRequest)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    VStack(spacing: 0) {
                        MapStatusStrip(layer: layer, demandCategory: demandCategory)
                            .padding(.horizontal, 10)
                            .padding(.top, 8)
                        Spacer()
                        MapBottomHUD(layer: layer, demandCategory: demandCategory)
                            .padding(12)
                    }
                    .allowsHitTesting(false)
                    VStack {
                        Spacer()
                        MapHomeControls(
                            notifications: game.purchaseCases.count + min(3, game.cityEvents.filter { $0.turn >= max(0, game.turn - 1) }.count),
                            showNotifications: { showNotifications = true },
                            showSearch: { showSearch = true }
                        )
                        .padding(.horizontal, 14).padding(.bottom, 82)
                    }
                }
            }
            .background(Color(red: 0.71, green: 0.83, blue: 0.91))
            .navigationTitle("翠浜市 事業マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                        Label(layer.name, systemImage: "square.3.layers.3d.top.filled")
                            .font(.caption.bold())
                    }
                }
            }
            .sheet(item: $selectedPlot) { plot in
                PlotDetailView(plotID: plot.id).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedFacility) { facility in
                FacilityHubSheet(facility: facility) { plot in
                    focusRequest = MapFocusRequest(worldPoint: CityMapLayout.position(for: plot.id))
                    selectedPlot = plot
                }
                .presentationDetents([.height(270), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSearch) {
                MapSearchView { facility in selectedFacility = facility; showSearch = false } focusDistrict: { kind in
                    focusRequest = MapFocusRequest(worldPoint: CityMapLayout.trafficBadgePosition(for: kind)); showSearch = false
                }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationCenterView(open: { facility in selectedFacility = facility; showNotifications = false }, openStore: { store in
                    if let plot = game.plot(id: store.plotID) {
                        focusRequest = MapFocusRequest(worldPoint: CityMapLayout.position(for: plot.id)); selectedPlot = plot
                    }
                    showNotifications = false
                }, openEvent: { event in
                    if let plotID = event.plotID, let plot = game.plot(id: plotID) {
                        focusRequest = MapFocusRequest(worldPoint: CityMapLayout.position(for: plot.id)); selectedPlot = plot
                    } else if let district = event.district {
                        focusRequest = MapFocusRequest(worldPoint: CityMapLayout.trafficBadgePosition(for: district))
                    }
                    showNotifications = false
                })
                    .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
        }
    }
}

private struct MapBottomHUD: View {
    @EnvironmentObject private var game: GameEngine
    let layer: MapLayer
    let demandCategory: VehicleCategory

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Label("翠浜市", systemImage: "building.2.fill")
                    .font(.subheadline.bold())
                Text(layer == .demand ? "青い光が今月の主な客足です" : layer == .vehicleDemand ? "\(demandCategory.name)の需要が強い地域を表示" : layer == .competition ? "円は店舗の商圏、重なりは顧客競争です" : "ドラッグで移動・ピンチで拡大")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("自社 \(game.stores.count)店舗").font(.caption.bold())
                Text("競合 \(game.competitors.reduce(0) { $0 + $1.plotIDs.count })店舗").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }
}

private struct MapStatusStrip: View {
    @EnvironmentObject private var game: GameEngine
    let layer: MapLayer
    let demandCategory: VehicleCategory

    var body: some View {
        HStack(spacing: 8) {
            CapsuleLabel(text: "経営ホーム", color: GameTheme.teal, icon: "building.2.fill")
            if layer == .normal, let event = game.cityEvents.first {
                CapsuleLabel(text: event.title, color: event.isPositive ? GameTheme.teal : GameTheme.orange, icon: event.kind.icon)
            } else if layer == .vehicleDemand {
                CapsuleLabel(text: "\(demandCategory.name)需要", color: .blue, icon: demandCategory.icon)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .overlay(alignment: .trailing) {
            if layer == .demand {
                Label("人の流れ表示中", systemImage: "figure.walk.motion")
                    .font(.caption2.bold()).foregroundStyle(.blue).padding(.trailing, 12)
            }
        }
    }
}

private struct MapHomeControls: View {
    let notifications: Int
    let showNotifications: () -> Void
    let showSearch: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Button(action: showNotifications) {
                Label("通知 \(notifications)", systemImage: "exclamationmark.bubble.fill")
                    .font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 13).padding(.vertical, 11).background(notifications > 0 ? GameTheme.orange : GameTheme.navy).clipShape(Capsule())
            }
            Spacer()
            Button(action: showSearch) {
                Image(systemName: "magnifyingglass").font(.headline.bold()).foregroundStyle(.white).frame(width: 44, height: 44).background(GameTheme.navy.opacity(0.9)).clipShape(Circle())
            }
        }.shadow(color: .black.opacity(0.22), radius: 7, y: 3)
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

private struct NotificationCenterView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let open: (MapFacility) -> Void
    let openStore: (Store) -> Void
    let openEvent: (CityEvent) -> Void
    var body: some View {
        NavigationStack {
            List {
                if !game.purchaseCases.isEmpty {
                    Button { if let store = game.stores.first(where: { $0.id == game.purchaseCases.first?.storeID }) { openStore(store) } } label: { NotificationRow(icon: "wrench.and.screwdriver.fill", title: "買取案件 \(game.purchaseCases.count)件", detail: "自社店舗で査定判断を待っています", color: GameTheme.orange) }
                }
                if game.totalInventory < game.stores.count * 8 {
                    Button { open(.auction) } label: { NotificationRow(icon: "car.2.fill", title: "在庫不足の可能性", detail: "オークションで不足車種を補充できます", color: .indigo) }
                }
                Button { open(.bank) } label: { NotificationRow(icon: "calendar.badge.clock", title: "借入返済日", detail: "月末処理で利息を支払います", color: .blue) }
                if !game.cityEvents.isEmpty {
                    Section("街の変化") {
                        ForEach(game.cityEvents.prefix(8)) { event in
                            Button { openEvent(event) } label: {
                                NotificationRow(icon: event.kind.icon, title: event.title, detail: event.detail, color: event.isPositive ? GameTheme.teal : GameTheme.orange)
                            }
                        }
                    }
                }
                ForEach(game.reports.first?.notes ?? [], id: \.self) { note in NotificationRow(icon: "bell.fill", title: note, detail: "直近の月次レポート", color: GameTheme.teal) }
            }.navigationTitle("未処理案件・通知").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }
}

private struct NotificationRow: View {
    let icon: String; let title: String; let detail: String; let color: Color
    var body: some View { HStack(spacing: 11) { Image(systemName: icon).foregroundStyle(.white).frame(width: 38, height: 38).background(color).clipShape(Circle()); VStack(alignment: .leading) { Text(title).font(.subheadline.bold()); Text(detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }.foregroundStyle(GameTheme.ink).padding(.vertical, 3) }
}

private struct CityMapSurface: View {
    @EnvironmentObject private var game: GameEngine
    let layer: MapLayer
    @Binding var selectedPlot: LandPlot?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                CityBaseMap(layer: layer)
                CustomerFlowOverlay(emphasized: layer == .demand)
                ForEach(CityMapLayout.landmarks) { landmark in
                    LandmarkBadge(landmark: landmark)
                        .position(x: size.width * landmark.x, y: size.height * landmark.y)
                }
                ForEach(game.plots) { plot in
                    let point = CityMapLayout.position(for: plot.id)
                    PlotMapMarker(plot: plot, layer: layer) {
                        selectedPlot = plot
                    }
                    .position(x: size.width * point.x, y: size.height * point.y)
                }
                if layer == .demand {
                    ForEach(DistrictKind.allCases) { kind in
                        let point = CityMapLayout.trafficBadgePosition(for: kind)
                        TrafficBadge(kind: kind)
                            .position(x: size.width * point.x, y: size.height * point.y)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.9), lineWidth: 3))
            .shadow(color: GameTheme.ink.opacity(0.15), radius: 14, y: 7)
        }
        .frame(height: 680)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("翠浜市の俯瞰事業マップ")
    }
}

private struct CityBaseMap: View {
    @EnvironmentObject private var game: GameEngine
    let layer: MapLayer

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.80, green: 0.87, blue: 0.73), Color(red: 0.70, green: 0.82, blue: 0.67)]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            ))

            drawZones(context: &context, size: size)
            drawLocalRoads(context: &context, size: size)
            drawBuildings(context: &context, size: size)
            drawHighway(context: &context, size: size)
            drawWater(context: &context, size: size)
        }
    }

    private func drawZones(context: inout GraphicsContext, size: CGSize) {
        let zones: [(DistrictKind, [CGPoint])] = [
            (.downtown, [.init(x: 0.02, y: 0.02), .init(x: 0.41, y: 0.02), .init(x: 0.43, y: 0.31), .init(x: 0.03, y: 0.33)]),
            (.station, [.init(x: 0.43, y: 0.02), .init(x: 0.75, y: 0.02), .init(x: 0.74, y: 0.34), .init(x: 0.43, y: 0.31)]),
            (.emerging, [.init(x: 0.76, y: 0.02), .init(x: 0.99, y: 0.03), .init(x: 0.98, y: 0.40), .init(x: 0.76, y: 0.38)]),
            (.suburb, [.init(x: 0.02, y: 0.34), .init(x: 0.48, y: 0.33), .init(x: 0.48, y: 0.64), .init(x: 0.02, y: 0.65)]),
            (.industrial, [.init(x: 0.50, y: 0.38), .init(x: 0.98, y: 0.42), .init(x: 0.98, y: 0.68), .init(x: 0.50, y: 0.66)]),
            (.highway, [.init(x: 0.02, y: 0.69), .init(x: 0.98, y: 0.69), .init(x: 0.98, y: 0.97), .init(x: 0.02, y: 0.97)])
        ]
        for (kind, points) in zones {
            var path = Path()
            path.move(to: scaled(points[0], size))
            for point in points.dropFirst() { path.addLine(to: scaled(point, size)) }
            path.closeSubpath()
            let district = game.districts.first(where: { $0.kind == kind })
            context.fill(path, with: .color(zoneColor(kind: kind, district: district).opacity(layer == .normal ? 0.30 : 0.44)))
        }
    }

    private func drawLocalRoads(context: inout GraphicsContext, size: CGSize) {
        let roads: [[CGPoint]] = [
            [.init(x: 0, y: 0.34), .init(x: 1, y: 0.38)],
            [.init(x: 0.43, y: 0), .init(x: 0.48, y: 0.68)],
            [.init(x: 0.75, y: 0), .init(x: 0.73, y: 0.68)],
            [.init(x: 0.02, y: 0.17), .init(x: 0.75, y: 0.18)],
            [.init(x: 0.02, y: 0.49), .init(x: 0.98, y: 0.51)],
            [.init(x: 0.18, y: 0.02), .init(x: 0.19, y: 0.66)],
            [.init(x: 0.89, y: 0.03), .init(x: 0.87, y: 0.68)]
        ]
        for points in roads {
            var path = Path()
            path.move(to: scaled(points[0], size))
            path.addLine(to: scaled(points[1], size))
            context.stroke(path, with: .color(Color.white.opacity(0.95)), style: StrokeStyle(lineWidth: 13, lineCap: .round))
            context.stroke(path, with: .color(GameTheme.road.opacity(0.78)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            context.stroke(path, with: .color(Color.white.opacity(0.44)), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))
        }
    }

    private func drawHighway(context: inout GraphicsContext, size: CGSize) {
        for y in [0.695, 0.735] {
            var path = Path()
            path.move(to: scaled(.init(x: -0.02, y: y), size))
            path.addCurve(to: scaled(.init(x: 1.02, y: y + 0.015), size), control1: scaled(.init(x: 0.30, y: y - 0.025), size), control2: scaled(.init(x: 0.67, y: y + 0.035), size))
            context.stroke(path, with: .color(Color.white), style: StrokeStyle(lineWidth: 16))
            context.stroke(path, with: .color(Color(red: 0.24, green: 0.27, blue: 0.28)), style: StrokeStyle(lineWidth: 12))
            context.stroke(path, with: .color(Color.yellow.opacity(0.72)), style: StrokeStyle(lineWidth: 1.5, dash: [9, 8]))
        }
        var ramp = Path()
        ramp.move(to: scaled(.init(x: 0.53, y: 0.71), size))
        ramp.addCurve(to: scaled(.init(x: 0.64, y: 0.58), size), control1: scaled(.init(x: 0.60, y: 0.70), size), control2: scaled(.init(x: 0.64, y: 0.65), size))
        context.stroke(ramp, with: .color(.white), style: StrokeStyle(lineWidth: 12))
        context.stroke(ramp, with: .color(GameTheme.road), style: StrokeStyle(lineWidth: 8))

        context.draw(Text("翠浜高速  E8").font(.caption2.bold()).foregroundStyle(.white), at: scaled(.init(x: 0.48, y: 0.715), size))
        context.draw(Text("みなとIC").font(.caption2.bold()).foregroundStyle(GameTheme.ink), at: scaled(.init(x: 0.64, y: 0.625), size))
    }

    private func drawBuildings(context: inout GraphicsContext, size: CGSize) {
        let boutiques = [
            CGRect(x: 0.04, y: 0.05, width: 0.10, height: 0.055), CGRect(x: 0.23, y: 0.05, width: 0.13, height: 0.055),
            CGRect(x: 0.04, y: 0.20, width: 0.10, height: 0.065), CGRect(x: 0.25, y: 0.20, width: 0.12, height: 0.06)
        ]
        for rect in boutiques { building(rect, color: Color(red: 0.52, green: 0.45, blue: 0.64), context: &context, size: size, radius: 3) }

        let towers = [CGRect(x: 0.48, y: 0.045, width: 0.08, height: 0.07), CGRect(x: 0.63, y: 0.05, width: 0.08, height: 0.07), CGRect(x: 0.50, y: 0.21, width: 0.07, height: 0.07), CGRect(x: 0.64, y: 0.21, width: 0.07, height: 0.07)]
        for rect in towers { building(rect, color: Color(red: 0.32, green: 0.48, blue: 0.61), context: &context, size: size, radius: 2) }

        let houses = [
            CGRect(x: 0.04, y: 0.38, width: 0.07, height: 0.04), CGRect(x: 0.25, y: 0.36, width: 0.07, height: 0.045), CGRect(x: 0.38, y: 0.43, width: 0.065, height: 0.04),
            CGRect(x: 0.04, y: 0.56, width: 0.07, height: 0.04), CGRect(x: 0.27, y: 0.55, width: 0.07, height: 0.04),
            CGRect(x: 0.79, y: 0.055, width: 0.065, height: 0.038), CGRect(x: 0.91, y: 0.08, width: 0.06, height: 0.04), CGRect(x: 0.78, y: 0.31, width: 0.06, height: 0.04), CGRect(x: 0.90, y: 0.34, width: 0.06, height: 0.04)
        ]
        for rect in houses { building(rect, color: Color(red: 0.91, green: 0.70, blue: 0.47), context: &context, size: size, radius: 3) }

        let factories = [CGRect(x: 0.53, y: 0.41, width: 0.13, height: 0.07), CGRect(x: 0.76, y: 0.42, width: 0.16, height: 0.075), CGRect(x: 0.52, y: 0.55, width: 0.14, height: 0.07), CGRect(x: 0.79, y: 0.56, width: 0.14, height: 0.065)]
        for rect in factories {
            building(rect, color: Color(red: 0.47, green: 0.52, blue: 0.54), context: &context, size: size, radius: 1)
            let chimney = CGRect(x: rect.maxX - 0.018, y: rect.minY - 0.022, width: 0.012, height: 0.028)
            building(chimney, color: .gray, context: &context, size: size, radius: 0)
        }

        let roadside = [CGRect(x: 0.05, y: 0.81, width: 0.13, height: 0.07), CGRect(x: 0.29, y: 0.80, width: 0.14, height: 0.075), CGRect(x: 0.57, y: 0.84, width: 0.13, height: 0.07), CGRect(x: 0.80, y: 0.82, width: 0.14, height: 0.075)]
        for rect in roadside { building(rect, color: Color(red: 0.77, green: 0.56, blue: 0.30), context: &context, size: size, radius: 3) }
    }

    private func drawWater(context: inout GraphicsContext, size: CGSize) {
        var water = Path()
        water.move(to: scaled(.init(x: 0.97, y: 0.40), size))
        water.addLine(to: scaled(.init(x: 1, y: 0.40), size))
        water.addLine(to: scaled(.init(x: 1, y: 1), size))
        water.addLine(to: scaled(.init(x: 0.96, y: 1), size))
        water.addCurve(to: scaled(.init(x: 0.97, y: 0.40), size), control1: scaled(.init(x: 0.94, y: 0.80), size), control2: scaled(.init(x: 0.99, y: 0.60), size))
        context.fill(water, with: .color(Color.blue.opacity(0.30)))
    }

    private func zoneColor(kind: DistrictKind, district: District?) -> Color {
        switch layer {
        case .normal: return kind.color
        case .demand: return Color.blue.opacity(0.45 + min(0.35, (district?.trafficIndex ?? 1) / 5))
        case .vehicleDemand: return Color.cyan.opacity(0.68)
        case .price: return Color.purple.opacity(min(0.85, 0.25 + (district?.incomeIndex ?? 1) / 2.2))
        case .traffic: return Color.cyan.opacity(min(0.85, 0.2 + (district?.trafficIndex ?? 1) / 2))
        case .competition: return Color.orange.opacity(min(0.85, 0.18 + (district?.competition ?? 1) / 2))
        case .growth: return Color.green.opacity(min(0.85, 0.2 + ((district?.growthRate ?? 1) - 0.97) * 8))
        case .profit: return GameTheme.teal.opacity(0.55)
        }
    }

    private func building(_ rect: CGRect, color: Color, context: inout GraphicsContext, size: CGSize, radius: CGFloat) {
        let scaledRect = CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
        let shadowRect = scaledRect.offsetBy(dx: 2, dy: 3)
        context.fill(Path(roundedRect: shadowRect, cornerRadius: radius), with: .color(GameTheme.ink.opacity(0.16)))
        context.fill(Path(roundedRect: scaledRect, cornerRadius: radius), with: .color(color))
        let roof = CGRect(x: scaledRect.minX + 3, y: scaledRect.minY + 3, width: max(1, scaledRect.width - 6), height: 2)
        context.fill(Path(roof), with: .color(.white.opacity(0.45)))
    }

    private func scaled(_ point: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}

private struct CustomerFlowOverlay: View {
    let emphasized: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            Canvas { context, size in
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
                let routes: [(CGPoint, CGPoint, Double)] = [
                    (.init(x: 0.16, y: 0.48), .init(x: 0.55, y: 0.20), 1.0),
                    (.init(x: 0.88, y: 0.27), .init(x: 0.30, y: 0.20), 0.82),
                    (.init(x: 0.17, y: 0.76), .init(x: 0.69, y: 0.52), 1.15),
                    (.init(x: 0.58, y: 0.18), .init(x: 0.25, y: 0.52), 0.72)
                ]
                for (startN, endN, intensity) in routes {
                    let start = CGPoint(x: startN.x * size.width, y: startN.y * size.height)
                    let end = CGPoint(x: endN.x * size.width, y: endN.y * size.height)
                    var path = Path()
                    path.move(to: start)
                    path.addCurve(to: end, control1: CGPoint(x: start.x, y: end.y), control2: CGPoint(x: end.x, y: start.y))
                    context.stroke(path, with: .color(Color.blue.opacity(emphasized ? 0.55 : 0.14)), style: StrokeStyle(lineWidth: emphasized ? 2.5 * CGFloat(intensity) : 1, dash: [5, 5]))
                    let count = emphasized ? 4 : 2
                    for index in 0..<count {
                        let t = (phase + Double(index) / Double(count)).truncatingRemainder(dividingBy: 1)
                        let point = cubicPoint(from: start, to: end, t: CGFloat(t))
                        let dot = CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)
                        context.fill(Path(ellipseIn: dot), with: .color(Color.white.opacity(emphasized ? 0.95 : 0.5)))
                        context.stroke(Path(ellipseIn: dot), with: .color(Color.blue.opacity(0.8)), lineWidth: 1)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func cubicPoint(from start: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let c1 = CGPoint(x: start.x, y: end.y)
        let c2 = CGPoint(x: end.x, y: start.y)
        let u = 1 - t
        return CGPoint(
            x: u * u * u * start.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * end.x,
            y: u * u * u * start.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * end.y
        )
    }
}

private struct PlotMapMarker: View {
    @EnvironmentObject private var game: GameEngine
    let plot: LandPlot
    let layer: MapLayer
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                ZStack {
                    Circle().fill(markerColor).frame(width: markerSize, height: markerSize)
                    Circle().stroke(.white, lineWidth: 2).frame(width: markerSize, height: markerSize)
                    Image(systemName: markerIcon).font(.system(size: markerSize * 0.42, weight: .black)).foregroundStyle(.white)
                }
                if case .player = plot.occupant {
                    Text(layer == .demand ? "客足 \(game.estimatedVisitors(for: plot))人" : (game.store(at: plot.id)?.concept.name ?? "自店舗"))
                        .font(.system(size: 7, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2).background(GameTheme.teal).clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .shadow(color: GameTheme.ink.opacity(0.25), radius: 3, y: 2)
        .accessibilityLabel(accessibilityText)
    }

    private var markerSize: CGFloat {
        switch plot.occupant { case .player: 30; case .competitor: 27; default: 22 }
    }
    private var markerIcon: String {
        switch plot.occupant { case .player: "star.fill"; case .competitor: "flag.fill"; case .unavailable: "xmark"; case .available: plot.isForLease ? "key.fill" : "yensign" }
    }
    private var markerColor: Color {
        switch plot.occupant {
        case .player: GameTheme.teal
        case .competitor: GameTheme.orange
        case .unavailable: .gray
        case .available:
            switch layer {
            case .price: plot.price > 9_000 ? .purple : .indigo
            case .profit: game.profitabilityScore(for: plot) > 1.2 ? GameTheme.teal : GameTheme.navy
            default: GameTheme.navy.opacity(0.78)
            }
        }
    }
    private var accessibilityText: String {
        switch plot.occupant {
        case .player: "自店舗"
        case .competitor(let name): "競合店 \(name)"
        case .available: "出店候補地"
        case .unavailable: "利用不可"
        }
    }
}

private struct LandmarkBadge: View {
    let landmark: MapLandmark
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: landmark.icon)
            VStack(alignment: .leading, spacing: 0) {
                Text(landmark.title).font(.system(size: 9, weight: .black))
                if let subtitle = landmark.subtitle { Text(subtitle).font(.system(size: 6, weight: .bold)) }
            }
        }
        .foregroundStyle(landmark.tint)
        .padding(.horizontal, 5).padding(.vertical, 3)
        .background(.ultraThinMaterial.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .allowsHitTesting(false)
    }
}

private struct TrafficBadge: View {
    @EnvironmentObject private var game: GameEngine
    let kind: DistrictKind
    var body: some View {
        if let district = game.districts.first(where: { $0.kind == kind }) {
            Label("\(Int(district.trafficIndex * 70))人", systemImage: "figure.walk")
                .font(.system(size: 7, weight: .black))
                .foregroundStyle(.blue)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(.white.opacity(0.9)).clipShape(Capsule())
                .allowsHitTesting(false)
        }
    }
}

private struct CustomerTrafficCard: View {
    @EnvironmentObject private var game: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "客足と立地の読み方", subtitle: "人は生活動線と道路を通って複数の店を比較します")
            ForEach(game.districts.sorted { $0.trafficIndex > $1.trafficIndex }.prefix(4)) { district in
                HStack(spacing: 10) {
                    Image(systemName: district.kind.symbol).foregroundStyle(district.kind.color).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(district.kind.name).font(.subheadline.bold())
                        Text(trafficReason(district.kind)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("客足 \(Int(district.trafficIndex * 70))").font(.caption.bold().monospacedDigit())
                        Text(game.recommendedConcept(for: district.kind).name).font(.caption2).foregroundStyle(GameTheme.teal)
                    }
                }
            }
        }
        .gameCard()
    }

    private func trafficReason(_ kind: DistrictKind) -> String {
        switch kind {
        case .downtown: "買物客は多いが、賃料と競争も最大"
        case .suburb: "生活道路を使う家族と日常需要が安定"
        case .station: "通勤・若年客が多く、展示面積は小さい"
        case .industrial: "一般客は少ないが改造・法人目的が強い"
        case .emerging: "人口増加で週末の家族来店が伸びる"
        case .highway: "通過交通が多く、看板と出入りやすさが重要"
        }
    }
}

private struct CityPulseCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionTitle(title: "今月の街の動き", subtitle: "出店判断に影響する変化")
            HStack(spacing: 12) {
                Image(systemName: "house.lodge.fill").foregroundStyle(.green).frame(width: 34, height: 34).background(Color.green.opacity(0.12)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("新興住宅地の入居が増加中").font(.subheadline.bold())
                    Text("SUV・ミニバン需要と週末客足に追い風").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("+6.5%").font(.subheadline.bold().monospacedDigit()).foregroundStyle(.green)
            }
        }
        .gameCard()
    }
}

struct MapLandmark: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let x: CGFloat
    let y: CGFloat
    let tint: Color
}

enum CityMapLayout {
    static let plotPositions: [CGPoint] = [
        .init(x: 0.10, y: 0.13), .init(x: 0.21, y: 0.11), .init(x: 0.34, y: 0.14), .init(x: 0.11, y: 0.27), .init(x: 0.23, y: 0.25), .init(x: 0.36, y: 0.27),
        .init(x: 0.48, y: 0.12), .init(x: 0.60, y: 0.13), .init(x: 0.70, y: 0.11), .init(x: 0.49, y: 0.27), .init(x: 0.61, y: 0.26), .init(x: 0.71, y: 0.28),
        .init(x: 0.80, y: 0.12), .init(x: 0.92, y: 0.16), .init(x: 0.81, y: 0.27), .init(x: 0.92, y: 0.29), .init(x: 0.81, y: 0.38), .init(x: 0.93, y: 0.39),
        .init(x: 0.08, y: 0.41), .init(x: 0.20, y: 0.39), .init(x: 0.34, y: 0.41), .init(x: 0.08, y: 0.55), .init(x: 0.21, y: 0.53), .init(x: 0.38, y: 0.57),
        .init(x: 0.58, y: 0.44), .init(x: 0.72, y: 0.45), .init(x: 0.88, y: 0.48), .init(x: 0.59, y: 0.59), .init(x: 0.75, y: 0.60), .init(x: 0.90, y: 0.62),
        .init(x: 0.09, y: 0.79), .init(x: 0.23, y: 0.78), .init(x: 0.39, y: 0.81), .init(x: 0.58, y: 0.80), .init(x: 0.75, y: 0.79), .init(x: 0.90, y: 0.81)
    ]

    static let landmarks: [MapLandmark] = [
        MapLandmark(id: "boutique", title: "ブティック通り", subtitle: "高所得・高級車", icon: "bag.fill", x: 0.19, y: 0.035, tint: .purple),
        MapLandmark(id: "station", title: "翠浜駅", subtitle: "通勤・若年層", icon: "tram.fill", x: 0.59, y: 0.035, tint: .blue),
        MapLandmark(id: "newtown", title: "ひかりニュータウン", subtitle: "人口増加", icon: "house.and.flag.fill", x: 0.87, y: 0.035, tint: .green),
        MapLandmark(id: "residential", title: "さくら住宅街", subtitle: "軽・ファミリー", icon: "house.fill", x: 0.21, y: 0.345, tint: GameTheme.teal),
        MapLandmark(id: "factory", title: "臨海工業団地", subtitle: "改造・商用車", icon: "gearshape.2.fill", x: 0.73, y: 0.395, tint: .gray),
        MapLandmark(id: "roadside", title: "国道8号ロードサイド", subtitle: "通過交通", icon: "road.lanes", x: 0.29, y: 0.91, tint: GameTheme.orange)
    ]

    static func position(for plotID: Int) -> CGPoint {
        plotPositions.indices.contains(plotID) ? plotPositions[plotID] : .init(x: 0.5, y: 0.5)
    }

    static func trafficBadgePosition(for kind: DistrictKind) -> CGPoint {
        switch kind {
        case .downtown: .init(x: 0.38, y: 0.06)
        case .station: .init(x: 0.69, y: 0.06)
        case .emerging: .init(x: 0.94, y: 0.06)
        case .suburb: .init(x: 0.42, y: 0.37)
        case .industrial: .init(x: 0.91, y: 0.42)
        case .highway: .init(x: 0.76, y: 0.91)
        }
    }
}
