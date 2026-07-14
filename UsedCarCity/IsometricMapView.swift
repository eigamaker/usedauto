import SwiftUI

struct IsometricCitySurface: View {
    @EnvironmentObject private var game: GameEngine
    let layer: MapLayer
    let demandCategory: VehicleCategory
    @Binding var selectedPlot: LandPlot?
    @Binding var selectedFacility: MapFacility?
    let focusRequest: MapFocusRequest?
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    @State private var cameraScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var cameraOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectionBlockedUntil = Date.distantPast

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ZStack {
                    Image("CityMapBackgroundV2")
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                    IsometricCityCanvas(layer: layer, demandCategory: demandCategory)
                    if layer == .demand { IsometricCustomerFlow(emphasized: true) }
                    if layer == .competition { IsometricCatchmentOverlay() }
                    ForEach(game.plots) { plot in
                        if case .competitor(let name) = plot.occupant {
                            let type = competitorStoreType(for: plot.id)
                            let point = IsoProjection.project(CityMapLayout.position(for: plot.id), in: size)
                            DynamicStoreBuilding(
                                assetName: type.mapAssetName,
                                width: type.mapAssetWidth * 0.72,
                                tier: 1,
                                owner: .competitor,
                                phase: .operating,
                                interfaceScale: interfaceScale,
                                accessibilityName: "競合店舗 \(name)"
                            ) { select(plot) }
                            .position(x: point.x, y: point.y - 18)
                        }
                    }
                    ForEach(game.stores) { store in
                        if let plot = game.plot(id: store.plotID) {
                            let point = IsoProjection.project(CityMapLayout.position(for: plot.id), in: size)
                            DynamicStoreBuilding(
                                assetName: store.type.mapAssetName,
                                width: store.type.mapAssetWidth,
                                tier: store.visualTier,
                                owner: .player,
                                phase: buildingPhase(for: store),
                                interfaceScale: interfaceScale,
                                accessibilityName: "\(store.name)、\(store.type.name)"
                            ) { select(plot) }
                            .position(x: point.x, y: point.y - 22)
                        }
                    }
                    ForEach(CityMapLayout.landmarks) { landmark in
                        let point = IsoProjection.project(.init(x: landmark.x, y: landmark.y), in: size)
                        IsoLandmarkLabel(landmark: landmark, compact: cameraScale < 1.32)
                            .scaleEffect(interfaceScale)
                            .position(point)
                            .offset(x: landmarkOffset(landmark.id).x, y: landmarkOffset(landmark.id).y)
                    }
                    ForEach(game.plots) { plot in
                        let world = CityMapLayout.position(for: plot.id)
                        let point = IsoProjection.project(world, in: size)
                        if let project = plot.development {
                            DevelopmentMapMarker(project: project) { select(plot) }
                                .scaleEffect(interfaceScale)
                                .position(x: point.x, y: point.y - 18)
                        } else if shouldShowPlot(plot) {
                            IsometricPlotHitTarget(plot: plot, layer: layer) {
                                select(plot)
                            }
                            .scaleEffect(interfaceScale)
                            .position(x: point.x, y: point.y - markerLift(for: plot))
                        }
                    }
                    ForEach(MapFacility.allCases) { facility in
                        if facility.isPrimary || cameraScale >= 1.38 {
                            let point = IsoProjection.project(facility.worldPoint, in: size)
                            FacilityMapMarker(facility: facility, compact: !facility.isPrimary) { select(facility) }
                                .scaleEffect(interfaceScale)
                                .position(x: point.x, y: point.y - 30)
                        }
                    }
                    if layer == .demand {
                        ForEach(DistrictKind.allCases) { kind in
                            let world = CityMapLayout.trafficBadgePosition(for: kind)
                            let point = IsoProjection.project(world, in: size)
                            IsoTrafficBadge(kind: kind)
                                .scaleEffect(interfaceScale)
                                .position(x: point.x, y: point.y - 28)
                        }
                    }
                }
                .scaleEffect(cameraScale)
                .offset(cameraOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            if dragDistance(value.translation) >= 12 { blockSelection() }
                            cameraOffset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                        }
                        .onEnded { value in
                            if dragDistance(value.translation) >= 12 { blockSelection() }
                            cameraOffset = constrained(cameraOffset, size: size)
                            lastOffset = cameraOffset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            blockSelection()
                            cameraScale = min(maxCameraScale, max(minCameraScale, lastScale * value))
                            cameraOffset = constrained(cameraOffset, size: size)
                        }
                        .onEnded { _ in
                            blockSelection()
                            lastScale = cameraScale
                            cameraOffset = constrained(cameraOffset, size: size)
                            lastOffset = cameraOffset
                        }
                )
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 7) {
                            CameraButton(icon: "plus.magnifyingglass", label: "拡大") { zoom(by: 1.45, size: size) }
                            CameraButton(icon: "minus.magnifyingglass", label: "縮小") { zoom(by: 1 / 1.45, size: size) }
                            CameraButton(icon: "scope", label: "都市全景に戻す") { resetCamera() }
                            CameraButton(
                                icon: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                                label: isExpanded ? "通常表示に戻す" : "マップを全面表示"
                            ) {
                                withAnimation(.easeInOut(duration: 0.22)) { toggleExpanded() }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.top, 108).padding(.trailing, 10)
                VStack {
                    HStack {
                        Label(cameraScale < 1.25 ? "都市全景" : "地区表示 \(Int(cameraScale * 100))%", systemImage: "map.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(GameTheme.navy.opacity(0.86))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 106).padding(.horizontal, 10).padding(.bottom, 10)
                .allowsHitTesting(false)
            }
            .clipped()
            .onChange(of: focusRequest) { _, request in
                guard let request else { return }
                focus(on: request.worldPoint, size: size)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("斜め上から見た翠浜市の3D事業マップ")
    }

    private func focus(on worldPoint: CGPoint, size: CGSize) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            cameraScale = max(cameraScale, 1.8)
            lastScale = cameraScale
            let point = IsoProjection.project(worldPoint, in: size)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let desired = CGSize(width: -(point.x - center.x) * cameraScale, height: -(point.y - center.y) * cameraScale)
            cameraOffset = constrained(desired, size: size)
            lastOffset = cameraOffset
        }
    }

    private func constrained(_ offset: CGSize, size: CGSize) -> CGSize {
        let maxX = max(0, size.width * (cameraScale - 1) * 0.52 + 45)
        let maxY = max(0, size.height * (cameraScale - 1) * 0.50 + 55)
        return CGSize(width: min(maxX, max(-maxX, offset.width)), height: min(maxY, max(-maxY, offset.height)))
    }

    private func zoom(by factor: CGFloat, size: CGSize) {
        withAnimation(.easeInOut(duration: 0.18)) {
            cameraScale = min(maxCameraScale, max(minCameraScale, cameraScale * factor))
            lastScale = cameraScale
            cameraOffset = constrained(cameraOffset, size: size)
            lastOffset = cameraOffset
        }
    }

    private func resetCamera() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            cameraScale = 1.0
            lastScale = 1.0
            cameraOffset = .zero
            lastOffset = .zero
        }
    }

    private func shouldShowPlot(_ plot: LandPlot) -> Bool {
        switch plot.occupant {
        case .player, .competitor: return true
        case .available:
            if game.tutorialStep == .chooseLocation || game.tutorialStep == .buildStore {
                return game.isFoundingCandidate(plot) || cameraScale >= 1.42
            }
            return cameraScale >= 1.42
        case .unavailable: return cameraScale >= 1.65
        }
    }

    private func select(_ plot: LandPlot) {
        guard Date() >= selectionBlockedUntil else { return }
        if case .available = plot.occupant,
           game.tutorialStep == .chooseLocation || game.tutorialStep == .buildStore {
            game.selectFoundingPlot(plot.id)
        }
        selectedPlot = plot
    }

    private func select(_ facility: MapFacility) {
        guard Date() >= selectionBlockedUntil else { return }
        selectedFacility = facility
    }

    private func blockSelection() {
        selectionBlockedUntil = Date().addingTimeInterval(0.22)
    }

    private func dragDistance(_ translation: CGSize) -> CGFloat {
        abs(translation.width) + abs(translation.height)
    }

    private func markerLift(for plot: LandPlot) -> CGFloat {
        switch plot.occupant {
        case .player:
            if let store = game.store(at: plot.id), !store.isOperational || store.isRenovating { return 54 }
            return 30
        case .competitor: return 25
        default: return 7
        }
    }

    private var interfaceScale: CGFloat {
        max(0.30, 1 / cameraScale)
    }

    private var minCameraScale: CGFloat { 0.72 }
    private var maxCameraScale: CGFloat { 6.0 }

    private func competitorStoreType(for plotID: Int) -> StoreType {
        switch plotID % 3 {
        case 0: .small
        case 1: .standard
        default: .roadside
        }
    }

    private func buildingPhase(for store: Store) -> DynamicBuildingPhase {
        if let remaining = store.openingMonthsRemaining {
            return .constructing(monthsRemaining: remaining)
        }
        if let remaining = store.renovationMonthsRemaining {
            return .renovating(monthsRemaining: remaining)
        }
        return .operating
    }

    private func landmarkOffset(_ id: String) -> CGPoint {
        switch id {
        case "boutique": .init(x: 0, y: -20)
        case "station": .init(x: -35, y: -12)
        case "newtown": .init(x: -18, y: 30)
        case "residential": .init(x: -46, y: -18)
        case "factory": .init(x: -25, y: -18)
        case "roadside": .init(x: 42, y: 14)
        default: .zero
        }
    }
}

private enum DynamicBuildingOwner {
    case player
    case competitor
}

private enum DynamicBuildingPhase: Equatable {
    case operating
    case constructing(monthsRemaining: Int)
    case renovating(monthsRemaining: Int)
}

private struct DynamicStoreBuilding: View {
    let assetName: String
    let width: CGFloat
    let tier: Int
    let owner: DynamicBuildingOwner
    let phase: DynamicBuildingPhase
    let interfaceScale: CGFloat
    let accessibilityName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(owner == .player ? GameTheme.teal.opacity(0.30) : GameTheme.orange.opacity(0.36))
                    .frame(width: width * 0.76, height: width * 0.24)
                    .overlay {
                        Ellipse()
                            .stroke(owner == .player ? Color.white.opacity(0.9) : GameTheme.orange,
                                    lineWidth: owner == .player ? 1.5 : 2)
                    }
                    .offset(y: 2)
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * tierScale)
                    .saturation(owner == .player ? 1 : 0.58)
                    .contrast(owner == .player ? 1 : 0.92)
                    .opacity(phase == .operating ? 1 : 0.58)
                    .id(assetName)
                    .transition(.scale(scale: 0.75).combined(with: .opacity))
                if phase != .operating {
                    ConstructionScaffold(width: width, phase: phase)
                }
                if tier > 1, owner == .player {
                    Text("Lv.\(tier)")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(GameTheme.teal)
                        .clipShape(Capsule())
                        .scaleEffect(interfaceScale)
                        .offset(x: width * 0.31, y: -width * 0.43)
                }
            }
            .frame(width: width * 1.18, height: width * 0.82, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.24), radius: 4, y: 3)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: assetName)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: tier)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: phase)
        .accessibilityLabel(accessibilityName)
        .accessibilityHint("タップして店舗または土地の情報を表示")
    }

    private var tierScale: CGFloat {
        1 + CGFloat(max(0, tier - 1)) * 0.045
    }
}

private struct ConstructionScaffold: View {
    let width: CGFloat
    let phase: DynamicBuildingPhase

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.24))
                .frame(width: width * 0.72, height: width * 0.40)
            HStack(spacing: width * 0.12) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle().fill(Color.white.opacity(0.82)).frame(width: 1.5, height: width * 0.42)
                }
            }
            VStack(spacing: width * 0.11) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(scaffoldColor.opacity(0.92)).frame(width: width * 0.76, height: 2)
                }
            }
        }
        .offset(y: -width * 0.05)
        .allowsHitTesting(false)
    }

    private var scaffoldColor: Color {
        switch phase {
        case .constructing: GameTheme.orange
        case .renovating: Color.yellow
        case .operating: GameTheme.teal
        }
    }
}

private struct FacilityMapMarker: View {
    @EnvironmentObject private var game: GameEngine
    let facility: MapFacility
    let compact: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: compact ? 7 : 10).fill(facility.color).frame(width: compact ? 27 : 38, height: compact ? 27 : 38)
                    RoundedRectangle(cornerRadius: compact ? 7 : 10).stroke(.white, lineWidth: 2).frame(width: compact ? 27 : 38, height: compact ? 27 : 38)
                    Image(systemName: facility.icon).font(compact ? .caption2.bold() : .subheadline.bold()).foregroundStyle(.white)
                    if badge > 0 { Text("\(badge)").font(.system(size: 8, weight: .black)).foregroundStyle(.white).frame(width: 16, height: 16).background(GameTheme.danger).clipShape(Circle()).offset(x: 17, y: -17) }
                }
                Text(facility.shortName).font(.system(size: compact ? 6 : 7, weight: .black)).foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 2).background(facility.color).clipShape(Capsule())
            }.frame(minWidth: 48, minHeight: 52)
        }.buttonStyle(.plain).shadow(color: .black.opacity(0.28), radius: 4, y: 3).accessibilityLabel("\(facility.name)、\(facility.status(game: game))")
    }
    private var badge: Int {
        if facility == .headquarters { return game.purchaseCases.count }
        if facility == .auction { return game.bidReservations.isEmpty ? (game.totalInventory < game.stores.count * 8 ? 1 : 0) : game.bidReservations.count }
        return 0
    }
}

private struct CameraButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(GameTheme.navy.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .accessibilityLabel(label)
    }
}

enum IsoProjection {
    static func normalized(_ world: CGPoint) -> CGPoint {
        CGPoint(
            x: 0.03 + world.x * 0.94,
            y: 0.08 + world.y * 0.84
        )
    }

    static func project(_ world: CGPoint, in size: CGSize) -> CGPoint {
        let point = normalized(world)
        return CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}

private struct IsoBuilding {
    let rect: CGRect
    let height: CGFloat
    let color: Color
    let roof: Roof
    let detail: Detail

    enum Roof { case flat, house, sawtooth }
    enum Detail { case retail, windows, factory, home, station, roadside }
}

private struct IsometricCityCanvas: View {
    @EnvironmentObject private var game: GameEngine
    let layer: MapLayer
    let demandCategory: VehicleCategory

    var body: some View {
        Canvas { context, size in
            drawZones(context: &context, size: size)
        }
    }

    private func drawBackdrop(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(red: 0.71, green: 0.83, blue: 0.91), Color(red: 0.91, green: 0.90, blue: 0.78)]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)
        ))
        let hillColors = [Color(red: 0.40, green: 0.61, blue: 0.43), Color(red: 0.34, green: 0.54, blue: 0.39), Color(red: 0.47, green: 0.66, blue: 0.45)]
        for index in 0..<5 {
            let x = CGFloat(index) * size.width * 0.23 - 30
            var hill = Path()
            hill.move(to: CGPoint(x: x, y: size.height * 0.16))
            hill.addLine(to: CGPoint(x: x + size.width * 0.16, y: size.height * (0.035 + CGFloat(index % 2) * 0.02)))
            hill.addLine(to: CGPoint(x: x + size.width * 0.32, y: size.height * 0.16))
            hill.closeSubpath()
            context.fill(hill, with: .color(hillColors[index % hillColors.count].opacity(0.8)))
        }
    }

    private func drawTerrain(context: inout GraphicsContext, size: CGSize) {
        let a = iso(.init(x: 0, y: 0), size)
        let b = iso(.init(x: 1, y: 0), size)
        let c = iso(.init(x: 1, y: 1), size)
        let d = iso(.init(x: 0, y: 1), size)
        let depth: CGFloat = 18
        let rightSide = polygon([b, c, CGPoint(x: c.x, y: c.y + depth), CGPoint(x: b.x, y: b.y + depth)])
        let leftSide = polygon([d, c, CGPoint(x: c.x, y: c.y + depth), CGPoint(x: d.x, y: d.y + depth)])
        context.fill(rightSide, with: .color(Color(red: 0.38, green: 0.48, blue: 0.29)))
        context.fill(leftSide, with: .color(Color(red: 0.31, green: 0.42, blue: 0.25)))
        context.fill(polygon([a, b, c, d]), with: .color(Color(red: 0.67, green: 0.78, blue: 0.56)))
        context.stroke(polygon([a, b, c, d]), with: .color(.white.opacity(0.8)), lineWidth: 2)
    }

    private func drawZones(context: inout GraphicsContext, size: CGSize) {
        let zones: [(DistrictKind, CGRect)] = [
            (.downtown, CGRect(x: 0.01, y: 0.01, width: 0.40, height: 0.31)),
            (.station, CGRect(x: 0.42, y: 0.01, width: 0.32, height: 0.32)),
            (.emerging, CGRect(x: 0.75, y: 0.01, width: 0.24, height: 0.38)),
            (.suburb, CGRect(x: 0.01, y: 0.34, width: 0.47, height: 0.31)),
            (.industrial, CGRect(x: 0.50, y: 0.39, width: 0.49, height: 0.28)),
            (.highway, CGRect(x: 0.01, y: 0.69, width: 0.98, height: 0.30))
        ]
        for (kind, rect) in zones {
            let district = game.districts.first(where: { $0.kind == kind })
            let path = worldRect(rect, size)
            context.fill(path, with: .color(zoneColor(kind, district: district).opacity(layer == .normal ? 0.13 : 0.52)))
            context.stroke(path, with: .color(kind.color.opacity(layer == .normal ? 0.52 : 0.78)), style: StrokeStyle(lineWidth: layer == .normal ? 1.2 : 2, dash: [5, 3]))
        }
    }

    private func drawWaterAndParks(context: inout GraphicsContext, size: CGSize) {
        let river = worldRect(CGRect(x: 0.94, y: 0.20, width: 0.055, height: 0.78), size)
        context.fill(river, with: .linearGradient(Gradient(colors: [.cyan.opacity(0.68), .blue.opacity(0.46)]), startPoint: iso(.init(x: 0.94, y: 0.2), size), endPoint: iso(.init(x: 1, y: 0.98), size)))
        context.stroke(river, with: .color(.white.opacity(0.48)), lineWidth: 2)
        let park = worldRect(CGRect(x: 0.77, y: 0.24, width: 0.18, height: 0.13), size)
        context.fill(park, with: .color(Color.green.opacity(0.42)))
        context.draw(Text("中央公園").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.green.opacity(0.9)), at: iso(.init(x: 0.85, y: 0.31), size))
    }

    private func drawStreets(context: inout GraphicsContext, size: CGSize) {
        let roads: [(CGPoint, CGPoint, CGFloat)] = [
            (.init(x: 0, y: 0.33), .init(x: 1, y: 0.33), 10),
            (.init(x: 0, y: 0.50), .init(x: 1, y: 0.50), 9),
            (.init(x: 0, y: 0.66), .init(x: 1, y: 0.66), 10),
            (.init(x: 0.42, y: 0), .init(x: 0.42, y: 0.68), 10),
            (.init(x: 0.74, y: 0), .init(x: 0.74, y: 0.68), 10),
            (.init(x: 0.18, y: 0), .init(x: 0.18, y: 0.68), 8),
            (.init(x: 0.90, y: 0), .init(x: 0.90, y: 0.68), 8)
        ]
        for (startW, endW, width) in roads {
            let start = iso(startW, size), end = iso(endW, size)
            var path = Path(); path.move(to: start); path.addLine(to: end)
            context.stroke(path, with: .color(.white.opacity(0.94)), style: StrokeStyle(lineWidth: width + 4, lineCap: .square))
            context.stroke(path, with: .color(GameTheme.road.opacity(0.82)), style: StrokeStyle(lineWidth: width, lineCap: .square))
            context.stroke(path, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))
        }
    }

    private func drawLots(context: inout GraphicsContext, size: CGSize) {
        for plot in game.plots {
            guard case .available = plot.occupant else { continue }
            let point = CityMapLayout.position(for: plot.id)
            let rect = CGRect(x: point.x - 0.027, y: point.y - 0.027, width: 0.054, height: 0.054)
            let path = worldRect(rect, size)
            context.fill(path, with: .color(plot.isForLease ? Color.white.opacity(0.82) : GameTheme.sand.opacity(0.86)))
            context.stroke(path, with: .color(GameTheme.navy.opacity(0.65)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
        }
    }

    private func drawTrees(context: inout GraphicsContext, size: CGSize) {
        let trees: [CGPoint] = [
            .init(x: 0.79, y: 0.25), .init(x: 0.84, y: 0.24), .init(x: 0.89, y: 0.28), .init(x: 0.80, y: 0.34), .init(x: 0.91, y: 0.35),
            .init(x: 0.04, y: 0.38), .init(x: 0.29, y: 0.45), .init(x: 0.43, y: 0.59), .init(x: 0.12, y: 0.61),
            .init(x: 0.03, y: 0.87), .init(x: 0.48, y: 0.91), .init(x: 0.93, y: 0.89)
        ]
        for (index, world) in trees.enumerated() {
            let p = iso(world, size)
            var trunk = Path(); trunk.move(to: p); trunk.addLine(to: CGPoint(x: p.x, y: p.y - 13))
            context.stroke(trunk, with: .color(.brown.opacity(0.75)), lineWidth: 3)
            let crown = CGRect(x: p.x - 6, y: p.y - 22, width: 12, height: 12)
            context.fill(Path(ellipseIn: crown), with: .color(index.isMultiple(of: 2) ? Color.green.opacity(0.92) : Color(red: 0.23, green: 0.56, blue: 0.29)))
            context.fill(Path(ellipseIn: crown.offsetBy(dx: -4, dy: 4)), with: .color(Color.green.opacity(0.78)))
        }
    }

    private func drawContextBuildings(context: inout GraphicsContext, size: CGSize) {
        var buildings: [IsoBuilding] = [
            IsoBuilding(rect: .init(x: 0.03, y: 0.04, width: 0.11, height: 0.065), height: 34, color: .purple, roof: .flat, detail: .retail),
            IsoBuilding(rect: .init(x: 0.23, y: 0.04, width: 0.13, height: 0.065), height: 45, color: Color(red: 0.50, green: 0.38, blue: 0.66), roof: .flat, detail: .windows),
            IsoBuilding(rect: .init(x: 0.04, y: 0.20, width: 0.10, height: 0.065), height: 28, color: Color(red: 0.65, green: 0.44, blue: 0.69), roof: .flat, detail: .retail),
            IsoBuilding(rect: .init(x: 0.25, y: 0.20, width: 0.12, height: 0.06), height: 38, color: Color(red: 0.45, green: 0.34, blue: 0.61), roof: .flat, detail: .windows),
            IsoBuilding(rect: .init(x: 0.47, y: 0.035, width: 0.10, height: 0.085), height: 60, color: .blue, roof: .flat, detail: .station),
            IsoBuilding(rect: .init(x: 0.62, y: 0.05, width: 0.08, height: 0.07), height: 48, color: Color(red: 0.29, green: 0.51, blue: 0.70), roof: .flat, detail: .windows),
            IsoBuilding(rect: .init(x: 0.50, y: 0.21, width: 0.07, height: 0.065), height: 36, color: Color(red: 0.35, green: 0.57, blue: 0.73), roof: .flat, detail: .windows),
            IsoBuilding(rect: .init(x: 0.64, y: 0.21, width: 0.07, height: 0.065), height: 31, color: Color(red: 0.33, green: 0.54, blue: 0.68), roof: .flat, detail: .windows),
            IsoBuilding(rect: .init(x: 0.04, y: 0.38, width: 0.07, height: 0.045), height: 18, color: .orange, roof: .house, detail: .home),
            IsoBuilding(rect: .init(x: 0.25, y: 0.36, width: 0.07, height: 0.045), height: 17, color: Color(red: 0.89, green: 0.64, blue: 0.36), roof: .house, detail: .home),
            IsoBuilding(rect: .init(x: 0.38, y: 0.43, width: 0.065, height: 0.04), height: 16, color: Color(red: 0.82, green: 0.57, blue: 0.33), roof: .house, detail: .home),
            IsoBuilding(rect: .init(x: 0.05, y: 0.56, width: 0.07, height: 0.04), height: 18, color: Color(red: 0.93, green: 0.72, blue: 0.45), roof: .house, detail: .home),
            IsoBuilding(rect: .init(x: 0.27, y: 0.55, width: 0.07, height: 0.04), height: 17, color: .orange, roof: .house, detail: .home),
            IsoBuilding(rect: .init(x: 0.79, y: 0.055, width: 0.065, height: 0.04), height: 19, color: Color(red: 0.92, green: 0.72, blue: 0.43), roof: .house, detail: .home),
            IsoBuilding(rect: .init(x: 0.91, y: 0.08, width: 0.06, height: 0.04), height: 17, color: .orange, roof: .house, detail: .home),
            IsoBuilding(rect: .init(x: 0.80, y: 0.30, width: 0.06, height: 0.04), height: 18, color: Color(red: 0.86, green: 0.62, blue: 0.35), roof: .house, detail: .home),
            IsoBuilding(rect: .init(x: 0.52, y: 0.41, width: 0.13, height: 0.07), height: 24, color: .gray, roof: .sawtooth, detail: .factory),
            IsoBuilding(rect: .init(x: 0.77, y: 0.42, width: 0.15, height: 0.075), height: 27, color: Color(red: 0.40, green: 0.46, blue: 0.49), roof: .sawtooth, detail: .factory),
            IsoBuilding(rect: .init(x: 0.53, y: 0.55, width: 0.13, height: 0.065), height: 22, color: Color(red: 0.48, green: 0.51, blue: 0.52), roof: .sawtooth, detail: .factory),
            IsoBuilding(rect: .init(x: 0.79, y: 0.56, width: 0.14, height: 0.06), height: 25, color: .gray, roof: .sawtooth, detail: .factory),
            IsoBuilding(rect: .init(x: 0.05, y: 0.83, width: 0.13, height: 0.07), height: 22, color: Color(red: 0.76, green: 0.53, blue: 0.28), roof: .flat, detail: .roadside),
            IsoBuilding(rect: .init(x: 0.30, y: 0.81, width: 0.14, height: 0.075), height: 20, color: Color(red: 0.88, green: 0.48, blue: 0.22), roof: .flat, detail: .roadside),
            IsoBuilding(rect: .init(x: 0.58, y: 0.84, width: 0.13, height: 0.07), height: 23, color: Color(red: 0.72, green: 0.49, blue: 0.25), roof: .flat, detail: .roadside),
            IsoBuilding(rect: .init(x: 0.81, y: 0.82, width: 0.13, height: 0.07), height: 21, color: .orange, roof: .flat, detail: .roadside)
        ]
        buildings.sort { ($0.rect.midX + $0.rect.midY) < ($1.rect.midX + $1.rect.midY) }
        for building in buildings { drawPrism(building, context: &context, size: size) }
    }

    private func drawHighway(context: inout GraphicsContext, size: CGSize) {
        let pairs: [(CGFloat, Color)] = [(0.715, .yellow), (0.755, .yellow)]
        for (y, stripe) in pairs {
            let start = iso(.init(x: -0.04, y: y), size)
            let end = iso(.init(x: 1.04, y: y), size)
            var shadow = Path(); shadow.move(to: CGPoint(x: start.x, y: start.y + 10)); shadow.addLine(to: CGPoint(x: end.x, y: end.y + 10))
            context.stroke(shadow, with: .color(GameTheme.ink.opacity(0.32)), style: StrokeStyle(lineWidth: 17, lineCap: .square))
            var path = Path(); path.move(to: CGPoint(x: start.x, y: start.y - 4)); path.addLine(to: CGPoint(x: end.x, y: end.y - 4))
            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 18, lineCap: .square))
            context.stroke(path, with: .color(Color(red: 0.20, green: 0.23, blue: 0.24)), style: StrokeStyle(lineWidth: 14, lineCap: .square))
            context.stroke(path, with: .color(stripe.opacity(0.78)), style: StrokeStyle(lineWidth: 1.5, dash: [8, 7]))
        }
        let rampStart = iso(.init(x: 0.59, y: 0.74), size)
        let rampEnd = iso(.init(x: 0.64, y: 0.60), size)
        var ramp = Path(); ramp.move(to: CGPoint(x: rampStart.x, y: rampStart.y - 4)); ramp.addCurve(to: rampEnd, control1: CGPoint(x: rampStart.x + 25, y: rampStart.y - 25), control2: CGPoint(x: rampEnd.x + 22, y: rampEnd.y + 18))
        context.stroke(ramp, with: .color(.white), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        context.stroke(ramp, with: .color(GameTheme.road), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        context.draw(Text("翠浜高速 E8").font(.caption2.bold()).foregroundStyle(.white), at: CGPoint(x: iso(.init(x: 0.54, y: 0.74), size).x, y: iso(.init(x: 0.54, y: 0.74), size).y - 7))
    }

    private func drawPrism(_ building: IsoBuilding, context: inout GraphicsContext, size: CGSize) {
        let visualHeight = building.height * 0.82
        let r = building.rect
        let base = [
            iso(.init(x: r.minX, y: r.minY), size), iso(.init(x: r.maxX, y: r.minY), size),
            iso(.init(x: r.maxX, y: r.maxY), size), iso(.init(x: r.minX, y: r.maxY), size)
        ]
        let top = base.map { CGPoint(x: $0.x, y: $0.y - visualHeight) }
        let right = polygon([base[1], base[2], top[2], top[1]])
        let front = polygon([base[2], base[3], top[3], top[2]])
        let roof = polygon(top)
        context.fill(right, with: .color(building.color.opacity(0.58)))
        context.fill(front, with: .color(building.color.opacity(0.78)))
        context.fill(roof, with: .color(building.color.opacity(0.98)))
        context.stroke(roof, with: .color(.white.opacity(0.38)), lineWidth: 0.8)

        if building.detail == .windows || building.detail == .station || building.detail == .retail {
            let count = building.detail == .station ? 4 : 3
            for index in 0..<count {
                let t = CGFloat(index + 1) / CGFloat(count + 1)
                let x = top[3].x + (top[2].x - top[3].x) * t
                let y = top[3].y + (top[2].y - top[3].y) * t + visualHeight * 0.52
                let window = CGRect(x: x - 2, y: y - 3, width: 5, height: 6)
                context.fill(Path(roundedRect: window, cornerRadius: 1), with: .color(Color.cyan.opacity(0.72)))
            }
        }
        if building.detail == .factory {
            let chimneyBase = top[1]
            let chimneyTop = CGPoint(x: chimneyBase.x, y: chimneyBase.y - 17)
            var chimney = Path(); chimney.move(to: chimneyBase); chimney.addLine(to: chimneyTop)
            context.stroke(chimney, with: .color(Color.gray), lineWidth: 5)
            context.fill(Path(ellipseIn: CGRect(x: chimneyTop.x - 3, y: chimneyTop.y - 2, width: 6, height: 4)), with: .color(.white.opacity(0.7)))
        }
        if building.roof == .house {
            let ridge = CGPoint(x: (top[0].x + top[2].x) / 2, y: min(top[0].y, top[1].y) - 9)
            let roofLeft = polygon([top[0], top[3], top[2], ridge])
            let roofRight = polygon([top[0], top[1], top[2], ridge])
            context.fill(roofLeft, with: .color(Color(red: 0.62, green: 0.20, blue: 0.15)))
            context.fill(roofRight, with: .color(Color(red: 0.78, green: 0.28, blue: 0.18)))
        }
        if building.roof == .sawtooth {
            var teeth = Path()
            for index in 0..<3 {
                let t0 = CGFloat(index) / 3, t1 = CGFloat(index + 1) / 3
                let p0 = CGPoint(x: top[3].x + (top[2].x - top[3].x) * t0, y: top[3].y + (top[2].y - top[3].y) * t0)
                let p1 = CGPoint(x: top[3].x + (top[2].x - top[3].x) * t1, y: top[3].y + (top[2].y - top[3].y) * t1)
                teeth.move(to: p0); teeth.addLine(to: CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2 - 6)); teeth.addLine(to: p1)
            }
            context.stroke(teeth, with: .color(.white.opacity(0.7)), lineWidth: 1.5)
        }
    }

    private func zoneColor(_ kind: DistrictKind, district: District?) -> Color {
        switch layer {
        case .normal: return kind.color
        case .demand: return Color.blue.opacity(0.55 + min(0.25, (district?.trafficIndex ?? 1) / 6))
        case .vehicleDemand:
            let score = game.vehicleDemand(demandCategory, in: kind)
            return Color(hue: 0.56 - min(0.18, max(0, score - 0.7) * 0.15), saturation: 0.78, brightness: min(0.98, 0.48 + score * 0.28)).opacity(0.82)
        case .price: return Color.purple.opacity(min(0.85, 0.3 + (district?.incomeIndex ?? 1) / 2.4))
        case .traffic: return Color.cyan.opacity(min(0.85, 0.25 + (district?.trafficIndex ?? 1) / 2.2))
        case .competition: return Color.orange.opacity(min(0.85, 0.2 + (district?.competition ?? 1) / 2))
        case .growth: return Color.green.opacity(min(0.85, 0.25 + ((district?.growthRate ?? 1) - 0.97) * 8))
        case .profit: return GameTheme.teal.opacity(0.62)
        }
    }

    private func iso(_ point: CGPoint, _ size: CGSize) -> CGPoint { IsoProjection.project(point, in: size) }

    private func worldRect(_ rect: CGRect, _ size: CGSize) -> Path {
        polygon([
            iso(.init(x: rect.minX, y: rect.minY), size), iso(.init(x: rect.maxX, y: rect.minY), size),
            iso(.init(x: rect.maxX, y: rect.maxY), size), iso(.init(x: rect.minX, y: rect.maxY), size)
        ])
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

private struct IsometricCustomerFlow: View {
    let emphasized: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 18)) { timeline in
            Canvas { context, size in
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
                let routes: [(CGPoint, CGPoint)] = [
                    (.init(x: 0.17, y: 0.48), .init(x: 0.56, y: 0.20)),
                    (.init(x: 0.87, y: 0.27), .init(x: 0.29, y: 0.19)),
                    (.init(x: 0.18, y: 0.78), .init(x: 0.70, y: 0.52)),
                    (.init(x: 0.60, y: 0.18), .init(x: 0.25, y: 0.53))
                ]
                for (startW, endW) in routes {
                    let start = IsoProjection.project(startW, in: size)
                    let end = IsoProjection.project(endW, in: size)
                    var path = Path(); path.move(to: start); path.addLine(to: end)
                    context.stroke(path, with: .color(Color.cyan.opacity(emphasized ? 0.72 : 0.18)), style: StrokeStyle(lineWidth: emphasized ? 2.5 : 1, dash: [5, 5]))
                    let count = emphasized ? 5 : 2
                    for index in 0..<count {
                        let t = CGFloat((phase + Double(index) / Double(count)).truncatingRemainder(dividingBy: 1))
                        let p = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
                        let dot = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.95)))
                        context.stroke(Path(ellipseIn: dot), with: .color(.cyan), lineWidth: 1.5)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct IsometricCatchmentOverlay: View {
    @EnvironmentObject private var game: GameEngine

    var body: some View {
        Canvas { context, size in
            for competitor in game.competitors {
                for plotID in competitor.plotIDs {
                    guard let plot = game.plot(id: plotID) else { continue }
                    let center = IsoProjection.project(CityMapLayout.position(for: plot.id), in: size)
                    let area = CGRect(x: center.x - 34, y: center.y - 19, width: 68, height: 38)
                    context.fill(Path(ellipseIn: area), with: .color(GameTheme.orange.opacity(0.10)))
                    context.stroke(Path(ellipseIn: area), with: .color(GameTheme.orange.opacity(0.58)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            for store in game.stores {
                guard let plot = game.plot(id: store.plotID) else { continue }
                let center = IsoProjection.project(CityMapLayout.position(for: plot.id), in: size)
                let strength = game.catchmentStrength(for: store)
                let width = 78 * strength
                let area = CGRect(x: center.x - width / 2, y: center.y - width * 0.28, width: width, height: width * 0.56)
                context.fill(Path(ellipseIn: area), with: .color(GameTheme.teal.opacity(0.14)))
                context.stroke(Path(ellipseIn: area), with: .color(GameTheme.teal.opacity(0.85)), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct DevelopmentMapMarker: View {
    let project: DevelopmentProject
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color.yellow).frame(width: 34, height: 34)
                    RoundedRectangle(cornerRadius: 9).stroke(.white, lineWidth: 2).frame(width: 34, height: 34)
                    Image(systemName: "hammer.fill").font(.subheadline.bold()).foregroundStyle(GameTheme.navy)
                }
                Text("開発 \(project.monthsRemaining)週間")
                    .font(.system(size: 7, weight: .black)).foregroundStyle(GameTheme.navy)
                    .padding(.horizontal, 5).padding(.vertical, 2).background(Color.yellow).clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.28), radius: 4, y: 3)
        .accessibilityLabel("\(project.title)、完成まで\(project.monthsRemaining)週間")
    }
}

private struct IsometricPlotHitTarget: View {
    @EnvironmentObject private var game: GameEngine
    let plot: LandPlot
    let layer: MapLayer
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    Circle().fill(markerColor).frame(width: markerSize, height: markerSize)
                    Circle().stroke(.white, lineWidth: 2).frame(width: markerSize, height: markerSize)
                    Image(systemName: markerIcon).font(.system(size: markerSize * 0.40, weight: .black)).foregroundStyle(.white)
                }
                if case .player = plot.occupant {
                    Text(playerLabel)
                        .font(.system(size: 7, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(GameTheme.teal).clipShape(Capsule())
                } else if case .available = plot.occupant,
                          game.isTutorialActive, game.isFoundingCandidate(plot) {
                    Text(game.recommendedFoundingPlot?.id == plot.id ? "おすすめ" : "候補")
                        .font(.system(size: 7, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(game.recommendedFoundingPlot?.id == plot.id ? GameTheme.orange : GameTheme.teal)
                        .clipShape(Capsule())
                }
            }
            .frame(width: hitTargetSize, height: hitTargetSize)
        }
        .buttonStyle(.plain)
        .shadow(color: GameTheme.ink.opacity(0.34), radius: 4, y: 3)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("タップして土地または店舗の詳細とアクションを表示")
    }

    private var markerSize: CGFloat {
        switch plot.occupant {
        case .player: 27
        case .competitor: 23
        case .available where game.isTutorialActive && game.isFoundingCandidate(plot): 25
        default: 14
        }
    }
    private var hitTargetSize: CGFloat {
        switch plot.occupant {
        case .player: 38
        case .competitor: 34
        case .available where game.isTutorialActive && game.isFoundingCandidate(plot): 36
        case .available: 26
        case .unavailable: 22
        }
    }
    private var markerIcon: String {
        switch plot.occupant {
        case .player:
            if game.store(at: plot.id)?.openingMonthsRemaining != nil { return "hammer.fill" }
            if game.store(at: plot.id)?.renovationMonthsRemaining != nil { return "wrench.and.screwdriver.fill" }
            return "storefront.fill"
        case .competitor: return "flag.fill"
        case .unavailable: return "xmark"
        case .available:
            if game.isTutorialActive && game.isFoundingCandidate(plot) { return "mappin.and.ellipse" }
            return plot.isForLease ? "key.fill" : "yensign"
        }
    }
    private var markerColor: Color {
        switch plot.occupant {
        case .player:
            if let store = game.store(at: plot.id), !store.isOperational || store.isRenovating { return GameTheme.orange }
            return GameTheme.teal
        case .competitor: return GameTheme.orange
        case .unavailable: return .gray
        case .available:
            if game.isTutorialActive && game.isFoundingCandidate(plot) {
                return game.recommendedFoundingPlot?.id == plot.id ? GameTheme.orange : GameTheme.teal
            }
            return layer == .profit && game.profitabilityScore(for: plot) > 1.2 ? GameTheme.teal : GameTheme.navy.opacity(0.82)
        }
    }
    private var accessibilityText: String {
        switch plot.occupant {
        case .player: "自店舗 \(game.store(at: plot.id)?.name ?? "")"
        case .competitor(let name): "競合店舗 \(name)"
        case .available: "\(plot.district.name)の出店候補地"
        case .unavailable: "利用できない土地"
        }
    }

    private var playerLabel: String {
        guard let store = game.store(at: plot.id) else { return "自店舗" }
        if let remaining = store.openingMonthsRemaining { return "建設中 あと\(remaining)週間" }
        if let remaining = store.renovationMonthsRemaining { return "改装中 あと\(remaining)週間" }
        return layer == .demand ? "客足 \(game.estimatedVisitors(for: plot))人" : store.concept.name
    }
}

private struct IsoLandmarkLabel: View {
    @EnvironmentObject private var game: GameEngine
    let landmark: MapLandmark
    let compact: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: landmark.icon)
            VStack(alignment: .leading, spacing: 0) {
                Text(shortTitle).font(.system(size: compact ? 8 : 9, weight: .black))
                if !compact, let subtitle = landmark.subtitle { Text(subtitle).font(.system(size: 6, weight: .bold)) }
                Text(marketSummary)
                    .font(.system(size: compact ? 5.5 : 6, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(landmark.tint)
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(.ultraThinMaterial.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        .allowsHitTesting(false)
    }

    private var shortTitle: String {
        switch landmark.id {
        case "boutique": "高級商業"
        case "station": "駅・オフィス"
        case "newtown": "新興住宅"
        case "residential": "住宅街"
        case "factory": "工業・物流"
        case "roadside": "幹線道路"
        default: landmark.title
        }
    }

    private var districtKind: DistrictKind {
        switch landmark.id {
        case "boutique": .downtown
        case "station": .station
        case "newtown": .emerging
        case "residential": .suburb
        case "factory": .industrial
        default: .highway
        }
    }

    private var marketSummary: String {
        let rivals = game.competitors.reduce(0) { count, competitor in
            count + competitor.plotIDs.filter { game.plot(id: $0)?.district == districtKind }.count
        }
        return "\(districtKind.shortName) 需要\(game.weeklyBuyerPool(in: districtKind))台/週・競合\(rivals)店"
    }
}

private struct IsoTrafficBadge: View {
    @EnvironmentObject private var game: GameEngine
    let kind: DistrictKind

    var body: some View {
        if game.districts.contains(where: { $0.kind == kind }) {
            Label("購入需要 \(game.weeklyBuyerPool(in: kind))台/週", systemImage: "person.2.fill")
                .font(.system(size: 7, weight: .black)).foregroundStyle(.blue)
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(.white.opacity(0.92)).clipShape(Capsule())
                .shadow(radius: 2, y: 1)
                .allowsHitTesting(false)
        }
    }
}
