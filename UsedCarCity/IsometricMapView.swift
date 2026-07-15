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
    @State private var cameraScale: CGFloat = CommandLine.arguments.contains("-demo-map-zoom") ? 4.2 : 1.8
    @State private var lastScale: CGFloat = CommandLine.arguments.contains("-demo-map-zoom") ? 4.2 : 1.8
    @State private var cameraOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectionBlockedUntil = Date.distantPast

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ZStack {
                    IsometricCityCanvas(
                        layer: layer,
                        demandCategory: demandCategory,
                        cameraScale: cameraScale,
                        cameraOffset: cameraOffset
                    )
                    if layer == .demand {
                        IsometricCustomerFlow(emphasized: true, cameraScale: cameraScale, cameraOffset: cameraOffset)
                    }
                    if layer == .competition {
                        IsometricCatchmentOverlay(cameraScale: cameraScale, cameraOffset: cameraOffset)
                    }
                    if cameraScale >= 1.18 {
                        ForEach(CityMapLayout.landmarks) { landmark in
                            let point = IsoProjection.project(
                                .init(x: landmark.x, y: landmark.y),
                                in: size,
                                cameraScale: cameraScale,
                                cameraOffset: cameraOffset
                            )
                            IsoLandmarkLabel(landmark: landmark, compact: cameraScale < 2.40)
                                .position(point)
                                .offset(x: landmarkOffset(landmark.id).x, y: landmarkOffset(landmark.id).y)
                        }
                    }
                    ForEach(game.plots) { plot in
                        let world = CityMapLayout.position(for: plot.id)
                        let point = IsoProjection.project(world, in: size, cameraScale: cameraScale, cameraOffset: cameraOffset)
                        if let project = plot.development, cameraScale >= 2.25 {
                            DevelopmentMapMarker(project: project) { select(plot) }
                                .position(x: point.x, y: point.y - 18)
                        } else if shouldShowPlot(plot) && isInteractionAnchor(plot) {
                            IsometricPlotHitTarget(plot: plot, layer: layer, showMarker: shouldShowPlotMarker(plot)) {
                                select(plot)
                            }
                            .position(x: point.x, y: point.y - markerLift(for: plot))
                        }
                    }
                    ForEach(MapFacility.allCases) { facility in
                        if facility.isPrimary || cameraScale >= 2.40 {
                            let point = IsoProjection.project(facility.worldPoint, in: size, cameraScale: cameraScale, cameraOffset: cameraOffset)
                            FacilityMapMarker(facility: facility, compact: cameraScale < 1.25 || !facility.isPrimary) { select(facility) }
                                .position(x: point.x, y: point.y - (facility.isPrimary ? 31 : 26))
                        }
                    }
                    if layer == .demand {
                        ForEach(DistrictKind.allCases) { kind in
                            let world = CityMapLayout.trafficBadgePosition(for: kind)
                            let point = IsoProjection.project(world, in: size, cameraScale: cameraScale, cameraOffset: cameraOffset)
                            IsoTrafficBadge(kind: kind)
                                .position(x: point.x, y: point.y - 28)
                        }
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.80), value: game.stores.map(\.id))
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
                            CameraButton(icon: "scope", label: "街の中心に戻す") { resetCamera() }
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
            cameraScale = 1.8
            lastScale = 1.8
            cameraOffset = .zero
            lastOffset = .zero
        }
    }

    private func shouldShowPlot(_ plot: LandPlot) -> Bool {
        switch plot.occupant {
        case .player, .competitor, .available: return true
        case .unavailable: return false
        }
    }

    private func shouldShowPlotMarker(_ plot: LandPlot) -> Bool {
        if case .player = plot.occupant { return true }
        if case .available = plot.occupant,
           game.isTutorialActive, game.isFoundingCandidate(plot) {
            return true
        }
        if case .competitor = plot.occupant { return cameraScale >= 2.30 }
        return false
    }

    private func isInteractionAnchor(_ plot: LandPlot) -> Bool {
        if case .player = plot.occupant {
            return game.store(at: plot.id)?.plotID == plot.id
        }
        return true
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
        let baseLift: CGFloat
        switch plot.occupant {
        case .player:
            if let store = game.store(at: plot.id), !store.isOperational || store.isRenovating { baseLift = 54 }
            else { baseLift = 30 }
        case .competitor: baseLift = 25
        default: baseLift = 7
        }
        return baseLift
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
    let type: StoreType
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
                if owner == .player {
                    Ellipse()
                        .stroke(GameTheme.teal.opacity(0.95), lineWidth: 3)
                        .frame(width: width * 1.27, height: width * 0.39)
                        .shadow(color: GameTheme.teal.opacity(0.75), radius: 8)
                        .offset(y: width * 0.01)
                }
                Ellipse()
                    .fill(ownerColor.opacity(owner == .player ? 0.24 : 0.18))
                    .frame(width: width * 1.14, height: width * 0.34)
                    .overlay {
                        Ellipse().stroke(ownerColor.opacity(0.82), lineWidth: owner == .player ? 2 : 1.4)
                    }
                    .offset(y: -width * 0.02)
                Image(type.mapAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 1.22)
                    .scaleEffect(tierScale, anchor: .bottom)
                    .saturation(owner == .player ? 1 : 0.68)
                    .colorMultiply(owner == .player ? .white : Color(red: 1.0, green: 0.90, blue: 0.80))
                    .opacity(imageOpacity)
                    .offset(y: -width * 0.08)
                    .transition(.scale(scale: 0.45, anchor: .bottom).combined(with: .opacity))
                if phase != .operating {
                    ConstructionScaffold(width: width, phase: phase)
                        .offset(y: -width * 0.05)
                }
                Label(owner == .player ? "自社・中古車" : "競合", systemImage: owner == .player ? "car.2.fill" : "flag.fill")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, owner == .player ? 3 : 2)
                    .background(ownerColor)
                    .clipShape(Capsule())
                    .scaleEffect(interfaceScale)
                    .overlay {
                        if owner == .player {
                            Capsule().stroke(.white.opacity(0.92), lineWidth: 1.5)
                        }
                    }
                    .shadow(color: ownerColor.opacity(0.8), radius: owner == .player ? 5 : 2)
                    .offset(x: owner == .player ? -width * 0.25 : -width * 0.36, y: -width * 0.60)
                if tier > 1, owner == .player {
                    Text("Lv.\(tier)")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(GameTheme.teal)
                        .clipShape(Capsule())
                        .scaleEffect(interfaceScale)
                        .offset(x: width * 0.36, y: -width * 0.54)
                }
            }
            .frame(width: width * 1.34, height: width * 0.92, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.24), radius: 4, y: 3)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: type)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: tier)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: phase)
        .accessibilityLabel(accessibilityName)
        .accessibilityHint("タップして店舗または土地の情報を表示")
    }

    private var tierScale: CGFloat {
        1 + CGFloat(max(0, tier - 1)) * 0.045
    }

    private var imageOpacity: Double {
        switch phase {
        case .operating: 1
        case .constructing: 0.18
        case .renovating: 0.58
        }
    }

    private var ownerColor: Color {
        owner == .player ? GameTheme.teal : GameTheme.orange
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
            VStack(spacing: 1) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(red: 0.76, green: 0.77, blue: 0.72))
                        .frame(width: compact ? 42 : 54, height: compact ? 23 : 29)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.94), lineWidth: 1.5)
                        }
                    RoundedRectangle(cornerRadius: compact ? 4 : 5)
                        .fill(facility.color)
                        .frame(width: compact ? 27 : 35, height: compact ? 27 : 35)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(.white.opacity(0.82))
                                .frame(height: compact ? 4 : 5)
                        }
                        .overlay {
                            Image(systemName: facility.icon)
                                .font(.system(size: compact ? 11 : 15, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .offset(y: compact ? -7 : -9)
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(GameTheme.danger)
                            .clipShape(Circle())
                            .offset(x: compact ? 16 : 20, y: compact ? -26 : -34)
                    }
                }
                Text(facility.shortName)
                    .font(.system(size: compact ? 6 : 7, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(facility.color)
                    .clipShape(Capsule())
            }
            .frame(minWidth: compact ? 44 : 56, minHeight: compact ? 50 : 62)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        .accessibilityLabel("\(facility.name)、\(facility.status(game: game))")
    }
    private var badge: Int {
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
    /// Keep the two ground axes on one fixed projection. Deriving one axis from
    /// width and the other from height made the city stretch on tall devices.
    private static let verticalRatio: CGFloat = 0.68

    static func project(
        _ world: CGPoint,
        in size: CGSize,
        cameraScale: CGFloat = 1,
        cameraOffset: CGSize = .zero
    ) -> CGPoint {
        let horizontalReach = min(size.width * 0.47, size.height * 0.46)
        let verticalReach = horizontalReach * verticalRatio
        let origin = CGPoint(
            x: size.width * 0.50,
            y: max(size.height * 0.23, 86)
        )
        let xAxis = CGVector(dx: horizontalReach, dy: verticalReach)
        let yAxis = CGVector(dx: -horizontalReach, dy: verticalReach)
        let base = CGPoint(
            x: origin.x + world.x * xAxis.dx + world.y * yAxis.dx,
            y: origin.y + world.x * xAxis.dy + world.y * yAxis.dy
        )
        let viewportCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        return CGPoint(
            x: viewportCenter.x + (base.x - viewportCenter.x) * cameraScale + cameraOffset.width,
            y: viewportCenter.y + (base.y - viewportCenter.y) * cameraScale + cameraOffset.height
        )
    }

    static func heightScale(in size: CGSize, cameraScale: CGFloat = 1) -> CGFloat {
        let horizontalReach = min(size.width * 0.47, size.height * 0.46)
        return min(1.22, max(0.78, horizontalReach / 185)) * cameraScale
    }
}

private struct IsometricCityCanvas: View {
    @EnvironmentObject private var game: GameEngine
    let layer: MapLayer
    let demandCategory: VehicleCategory
    let cameraScale: CGFloat
    let cameraOffset: CGSize

    var body: some View {
        Canvas { context, size in
            drawBackdrop(context: &context, size: size)
            drawTerrain(context: &context, size: size)
            drawZones(context: &context, size: size)
            drawWaterAndParks(context: &context, size: size)
            if layer != .normal { drawGrid(context: &context, size: size) }
            drawStreets(context: &context, size: size)
            drawRailAndStationPlaza(context: &context, size: size)
            drawHighway(context: &context, size: size)
            drawLots(context: &context, size: size)
            drawStreetLife(context: &context, size: size)
            drawFacilityLots(context: &context, size: size)
            drawTrees(context: &context, size: size)
            drawParcelBuildings(context: &context, size: size)
        }
    }

    private func drawBackdrop(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(red: 0.71, green: 0.83, blue: 0.91), Color(red: 0.91, green: 0.90, blue: 0.78)]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)
        ))
        context.fill(
            Path(CGRect(x: 0, y: size.height * 0.94, width: size.width, height: size.height * 0.06)),
            with: .color(Color.blue.opacity(0.28))
        )
    }

    private func drawTerrain(context: inout GraphicsContext, size: CGSize) {
        let a = iso(.init(x: 0, y: 0), size)
        let b = iso(.init(x: 1, y: 0), size)
        let c = iso(.init(x: 1, y: 1), size)
        let d = iso(.init(x: 0, y: 1), size)
        let depth: CGFloat = 18 * cameraScale
        let rightSide = polygon([b, c, CGPoint(x: c.x, y: c.y + depth), CGPoint(x: b.x, y: b.y + depth)])
        let leftSide = polygon([d, c, CGPoint(x: c.x, y: c.y + depth), CGPoint(x: d.x, y: d.y + depth)])
        context.fill(rightSide, with: .color(Color(red: 0.38, green: 0.48, blue: 0.29)))
        context.fill(leftSide, with: .color(Color(red: 0.31, green: 0.42, blue: 0.25)))
        context.fill(polygon([a, b, c, d]), with: .color(Color(red: 0.67, green: 0.78, blue: 0.56)))
        context.stroke(polygon([a, b, c, d]), with: .color(.white.opacity(0.8)), lineWidth: 2)
    }

    private func drawZones(context: inout GraphicsContext, size: CGSize) {
        for kind in DistrictKind.allCases {
            let rect = CityMapLayout.districtRect(for: kind)
            let district = game.districts.first(where: { $0.kind == kind })
            let path = worldRect(rect, size)
            context.fill(path, with: .color(zoneColor(kind, district: district).opacity(layer == .normal ? 0.08 : 0.48)))
            if layer != .normal {
                context.stroke(path, with: .color(kind.color.opacity(0.90)), style: StrokeStyle(lineWidth: 2.0))
            }
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        for row in 0..<CityMapLayout.rowCount {
            for column in 0..<CityMapLayout.columnCount {
                let cell = worldRect(CityMapLayout.gridCellRect(column: column, row: row), size)
                if (row + column).isMultiple(of: 2) {
                    context.fill(cell, with: .color(Color.white.opacity(0.025)))
                }
                context.stroke(cell, with: .color(GameTheme.navy.opacity(0.13)), lineWidth: 0.65)
            }
        }
    }

    private func drawWaterAndParks(context: inout GraphicsContext, size: CGSize) {
        let water = CityMapLayout.blueprint.water
        let river = worldRect(water.rect, size)
        context.fill(river, with: .linearGradient(
            Gradient(colors: [.cyan.opacity(0.72), .blue.opacity(0.50)]),
            startPoint: iso(.init(x: water.rect.minX, y: water.rect.minY), size),
            endPoint: iso(.init(x: water.rect.maxX, y: water.rect.maxY), size)
        ))
        context.stroke(river, with: .color(.white.opacity(0.48)), lineWidth: 2)
        for y in stride(from: water.rippleStart, through: water.rippleEnd, by: 0.09) {
            let ripple = worldRect(CGRect(x: water.rect.minX + water.rect.width * 0.22, y: y, width: water.rect.width * 0.47, height: 0.003), size)
            context.stroke(ripple, with: .color(.white.opacity(0.45)), lineWidth: 0.8)
        }

        let parkPlacement = CityMapLayout.blueprint.park
        let parkRect = parkPlacement.rect
        let park = worldRect(parkRect, size)
        context.fill(park, with: .color(Color(red: 0.45, green: 0.68, blue: 0.35)))
        context.stroke(park, with: .color(Color.white.opacity(0.72)), lineWidth: 1.5)
        let parkPathA = worldRect(CGRect(x: parkRect.minX + 0.012, y: parkRect.midY - 0.005, width: parkRect.width - 0.024, height: 0.010), size)
        let parkPathB = worldRect(CGRect(x: parkRect.midX - 0.005, y: parkRect.minY + 0.012, width: 0.010, height: parkRect.height - 0.024), size)
        context.fill(parkPathA, with: .color(Color(red: 0.88, green: 0.80, blue: 0.62)))
        context.fill(parkPathB, with: .color(Color(red: 0.88, green: 0.80, blue: 0.62)))
        context.draw(Text(parkPlacement.name).font(.system(size: 7, weight: .bold)).foregroundStyle(Color.white.opacity(0.95)), at: iso(.init(x: parkRect.midX, y: parkRect.midY), size))
    }

    private func drawStreets(context: inout GraphicsContext, size: CGSize) {
        for road in CityMapLayout.blueprint.majorRoads {
            drawRoad(axis: road.axis, position: road.position, range: road.range, width: road.width, major: road.isMajor, context: &context, size: size)
        }

        for origin in CityMapLayout.districtGridOrigins {
            let first = CityMapLayout.gridPoint(column: origin.column, row: origin.row)
            let last = CityMapLayout.gridPoint(
                column: origin.column + CityMapLayout.districtColumnCount - 1,
                row: origin.row + CityMapLayout.districtRowCount - 1
            )
            let xRange = max(0.01, first.x - 0.025)...min(0.98, last.x + 0.025)
            let yRange = max(0.01, first.y - 0.025)...min(0.94, last.y + 0.025)
            for row in 0..<(CityMapLayout.districtRowCount - 1) {
                let upper = CityMapLayout.gridPoint(column: origin.column, row: origin.row + row).y
                let lower = CityMapLayout.gridPoint(column: origin.column, row: origin.row + row + 1).y
                drawRoad(axis: .horizontal, position: (upper + lower) / 2, range: xRange, width: 0.007, major: false, context: &context, size: size)
            }
            for column in 0..<(CityMapLayout.districtColumnCount - 1) {
                let left = CityMapLayout.gridPoint(column: origin.column + column, row: origin.row).x
                let right = CityMapLayout.gridPoint(column: origin.column + column + 1, row: origin.row).x
                drawRoad(axis: .vertical, position: (left + right) / 2, range: yRange, width: 0.007, major: false, context: &context, size: size)
            }
        }
    }

    private func drawRoad(axis: GridRoadAxis, position: CGFloat, range: ClosedRange<CGFloat>, width: CGFloat, major: Bool, context: inout GraphicsContext, size: CGSize) {
        let sidewalkWidth = width + (major ? 0.012 : 0.006)
        let sidewalkRect: CGRect
        let roadRect: CGRect
        let start: CGPoint
        let end: CGPoint
        switch axis {
        case .horizontal:
            sidewalkRect = CGRect(x: range.lowerBound, y: position - sidewalkWidth / 2, width: range.upperBound - range.lowerBound, height: sidewalkWidth)
            roadRect = CGRect(x: range.lowerBound, y: position - width / 2, width: range.upperBound - range.lowerBound, height: width)
            start = .init(x: range.lowerBound, y: position)
            end = .init(x: range.upperBound, y: position)
        case .vertical:
            sidewalkRect = CGRect(x: position - sidewalkWidth / 2, y: range.lowerBound, width: sidewalkWidth, height: range.upperBound - range.lowerBound)
            roadRect = CGRect(x: position - width / 2, y: range.lowerBound, width: width, height: range.upperBound - range.lowerBound)
            start = .init(x: position, y: range.lowerBound)
            end = .init(x: position, y: range.upperBound)
        }
        context.fill(worldRect(sidewalkRect, size), with: .color(Color(red: 0.82, green: 0.82, blue: 0.78)))
        context.stroke(worldRect(sidewalkRect, size), with: .color(GameTheme.ink.opacity(0.18)), lineWidth: 0.7)
        context.fill(worldRect(roadRect, size), with: .color(major ? Color(red: 0.23, green: 0.26, blue: 0.28) : Color(red: 0.30, green: 0.32, blue: 0.33)))
        if major {
            var centerLine = Path(); centerLine.move(to: iso(start, size)); centerLine.addLine(to: iso(end, size))
            context.stroke(centerLine, with: .color(Color.white.opacity(0.68)), style: StrokeStyle(lineWidth: 0.9, dash: [6, 5]))
        }
    }

    private func drawRailAndStationPlaza(context: inout GraphicsContext, size: CGSize) {
        let placement = CityMapLayout.blueprint.rail
        let station = CityMapLayout.districtRect(for: placement.district)
        let plazaRect = CGRect(x: station.minX, y: station.maxY + 0.008, width: station.width, height: placement.platformDepth)
        let plaza = worldRect(plazaRect, size)
        context.fill(plaza, with: .color(Color(red: 0.72, green: 0.76, blue: 0.76)))
        context.stroke(plaza, with: .color(.white.opacity(0.75)), lineWidth: 1)

        let railY = plazaRect.midY
        let railStart = CGPoint(x: station.minX - placement.extensionLength, y: railY)
        let railEnd = CGPoint(x: station.maxX + placement.extensionLength, y: railY)
        for offset in [-0.005, 0.005] as [CGFloat] {
            var rail = Path(); rail.move(to: iso(.init(x: railStart.x, y: railStart.y + offset), size)); rail.addLine(to: iso(.init(x: railEnd.x, y: railEnd.y + offset), size))
            context.stroke(rail, with: .color(Color(red: 0.27, green: 0.29, blue: 0.30)), lineWidth: 1.6 * cameraScale)
        }
        for x in stride(from: railStart.x + 0.01, through: railEnd.x - 0.01, by: 0.018) {
            var sleeper = Path(); sleeper.move(to: iso(.init(x: x, y: railY - 0.009), size)); sleeper.addLine(to: iso(.init(x: x, y: railY + 0.009), size))
            context.stroke(sleeper, with: .color(Color.brown.opacity(0.72)), lineWidth: max(1, cameraScale))
        }
    }

    private func drawLots(context: inout GraphicsContext, size: CGSize) {
        for plot in game.plots {
            let lotRect = CityMapLayout.lotRect(for: plot)
            let path = worldRect(lotRect, size)
            let fill: Color
            let border: Color
            switch plot.occupant {
            case .player:
                fill = Color(red: 0.34, green: 0.38, blue: 0.38)
                border = GameTheme.teal
            case .competitor:
                fill = Color(red: 0.35, green: 0.37, blue: 0.37)
                border = GameTheme.orange
            case .available:
                switch plot.structure {
                case .home, .villa:
                    fill = Color(red: 0.56, green: 0.72, blue: 0.43)
                case .factory, .warehouse:
                    fill = Color(red: 0.58, green: 0.60, blue: 0.58)
                case .roadside:
                    fill = Color(red: 0.39, green: 0.41, blue: 0.40)
                case .vacant:
                    fill = Color(red: 0.54, green: 0.68, blue: 0.41)
                default:
                    fill = Color(red: 0.72, green: 0.73, blue: 0.68)
                }
                border = layer == .normal ? GameTheme.ink.opacity(0.22) : plot.district.color.opacity(0.85)
            case .unavailable:
                fill = Color.gray.opacity(0.38)
                border = Color.gray.opacity(0.58)
            }
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(.white.opacity(0.52)), lineWidth: 0.8)
            let emphasizedBorder: Bool
            switch plot.occupant {
            case .player, .competitor: emphasizedBorder = true
            case .available, .unavailable: emphasizedBorder = false
            }
            context.stroke(path, with: .color(border), lineWidth: emphasizedBorder ? 2.0 : 0.7)

            if plot.structure == .vacant {
                drawVacantLotTexture(in: lotRect, context: &context, size: size, color: border)
            } else if plot.structure == .home || plot.structure == .villa {
                let drive = CGRect(x: lotRect.maxX - lotRect.width * 0.24, y: lotRect.minY, width: lotRect.width * 0.18, height: lotRect.height * 0.50)
                context.fill(worldRect(drive, size), with: .color(Color(red: 0.72, green: 0.70, blue: 0.64)))
            } else if plot.structure == .commercial || plot.structure == .office || plot.structure == .apartment {
                let paving = CGRect(x: lotRect.minX + 0.003, y: lotRect.maxY - lotRect.height * 0.18, width: lotRect.width - 0.006, height: lotRect.height * 0.12)
                context.fill(worldRect(paving, size), with: .color(Color.white.opacity(0.26)))
            }
        }
    }

    private func drawVacantLotTexture(in rect: CGRect, context: inout GraphicsContext, size: CGSize, color: Color) {
        let insetX = rect.width * 0.16
        let insetY = rect.height * 0.18
        let inner = CGRect(x: rect.minX + insetX, y: rect.minY + insetY, width: rect.width - insetX * 2, height: rect.height - insetY * 2)
        context.stroke(worldRect(inner, size), with: .color(color.opacity(0.34)), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
    }

    private func drawParcelBuildings(context: inout GraphicsContext, size: CGSize) {
        let backgroundPlots = game.plots.filter {
            if case .player = $0.occupant { return false }
            return true
        }.sorted {
            let lhs = CityMapLayout.position(for: $0.id)
            let rhs = CityMapLayout.position(for: $1.id)
            return lhs.x + lhs.y < rhs.x + rhs.y
        }

        for plot in backgroundPlots {
            let rect = CityMapLayout.lotRect(for: plot).insetBy(dx: 0.007, dy: 0.006)
            switch plot.occupant {
            case .competitor:
                drawDealership(in: rect, color: GameTheme.orange, label: "競合", type: competitorType(for: plot.id), context: &context, size: size)
            case .available, .unavailable:
                if let building = MapAssetLibrary.parcelBuilding(for: plot, in: rect) {
                    drawPrism(building, context: &context, size: size)
                }
            case .player:
                break
            }
        }

        for store in game.stores.sorted(by: {
            let lhs = CityMapLayout.position(for: $0.plotID)
            let rhs = CityMapLayout.position(for: $1.plotID)
            return lhs.x + lhs.y < rhs.x + rhs.y
        }) {
            let footprint = CityMapLayout.combinedLotRect(for: store.plotIDs).insetBy(dx: 0.004, dy: 0.004)
            let color = store.isOperational ? GameTheme.teal : GameTheme.orange
            drawDealership(in: footprint, color: color, label: store.isOperational ? "自社" : "工事中", type: store.pendingType ?? store.type, context: &context, size: size)
        }
    }

    private func drawDealership(in lot: CGRect, color: Color, label: String, type: StoreType, context: inout GraphicsContext, size: CGSize) {
        let base = worldRect(lot, size)
        context.fill(base, with: .color(Color(red: 0.34, green: 0.37, blue: 0.38)))
        context.stroke(base, with: .color(color.opacity(0.95)), lineWidth: 2.2)

        let building = MapAssetLibrary.dealership(in: lot, type: type, color: color)
        drawPrism(building, context: &context, size: size)

        let carCount = min(6, max(2, type.requiredGridCells * 2))
        for index in 0..<carCount {
            let column = index % 3
            let row = index / 3
            let point = CGPoint(
                x: lot.minX + lot.width * (0.64 + CGFloat(column) * 0.105),
                y: lot.minY + lot.height * (0.28 + CGFloat(row) * 0.25)
            )
            let stripe = CGRect(x: point.x - 0.008, y: point.y - 0.006, width: 0.016, height: 0.012)
            context.stroke(worldRect(stripe, size), with: .color(.white.opacity(0.34)), lineWidth: 0.55)
            drawCar(at: point, color: index.isMultiple(of: 2) ? .white : color, context: &context, size: size)
        }

        let signPoint = iso(CGPoint(x: building.rect.midX, y: building.rect.midY), size)
        context.draw(Text(label).font(.system(size: 7, weight: .black)).foregroundStyle(.white), at: CGPoint(x: signPoint.x, y: signPoint.y - building.height * 0.48 * cameraScale))
    }

    private func drawCar(at point: CGPoint, color: Color, context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(x: point.x - 0.006, y: point.y - 0.004, width: 0.012, height: 0.008)
        let path = worldRect(rect, size)
        context.fill(worldRect(rect.offsetBy(dx: 0.002, dy: 0.002), size), with: .color(.black.opacity(0.22)))
        context.fill(path, with: .color(color.opacity(0.96)))
        context.stroke(path, with: .color(GameTheme.ink.opacity(0.55)), lineWidth: 0.5)
        let glass = CGRect(x: point.x - 0.0025, y: point.y - 0.002, width: 0.005, height: 0.004)
        context.fill(worldRect(glass, size), with: .color(Color.cyan.opacity(0.72)))
    }

    private func drawStreetLife(context: inout GraphicsContext, size: CGSize) {
        let traffic: [(CGPoint, Color)] = [
            (.init(x: 0.10, y: 0.243), .white), (.init(x: 0.24, y: 0.257), .red),
            (.init(x: 0.48, y: 0.243), .yellow), (.init(x: 0.76, y: 0.257), .white),
            (.init(x: 0.12, y: 0.583), .blue), (.init(x: 0.42, y: 0.597), .white),
            (.init(x: 0.78, y: 0.583), .red), (.init(x: 0.278, y: 0.36), .yellow),
            (.init(x: 0.622, y: 0.47), .white), (.init(x: 0.868, y: 0.68), .blue)
        ]
        for (point, color) in traffic {
            drawCar(at: point, color: color, context: &context, size: size)
        }

        for center in [CGPoint(x: 0.285, y: 0.250), CGPoint(x: 0.615, y: 0.250), CGPoint(x: 0.285, y: 0.590), CGPoint(x: 0.615, y: 0.590)] {
            for index in -2...2 {
                let stripe = CGRect(x: center.x - 0.018 + CGFloat(index) * 0.007, y: center.y - 0.012, width: 0.0035, height: 0.024)
                context.fill(worldRect(stripe, size), with: .color(.white.opacity(0.72)))
            }
        }

        let lampPoints: [CGPoint] = [
            .init(x: 0.06, y: 0.230), .init(x: 0.20, y: 0.230), .init(x: 0.43, y: 0.230), .init(x: 0.72, y: 0.230),
            .init(x: 0.08, y: 0.570), .init(x: 0.27, y: 0.570), .init(x: 0.55, y: 0.570), .init(x: 0.84, y: 0.570)
        ]
        for world in lampPoints {
            let base = iso(world, size)
            let assetScale = IsoProjection.heightScale(in: size, cameraScale: cameraScale)
            let top = CGPoint(x: base.x, y: base.y - 10 * assetScale)
            var pole = Path(); pole.move(to: base); pole.addLine(to: top)
            context.stroke(pole, with: .color(Color(red: 0.25, green: 0.28, blue: 0.29)), lineWidth: 1.5 * cameraScale)
            context.fill(Path(ellipseIn: CGRect(x: top.x - 2.5 * assetScale, y: top.y - 2.5 * assetScale, width: 5 * assetScale, height: 5 * assetScale)), with: .color(Color.yellow.opacity(0.90)))
        }
    }

    private func competitorType(for plotID: Int) -> StoreType {
        switch plotID % 3 {
        case 0: .small
        case 1: .standard
        default: .roadside
        }
    }

    private func drawFacilityLots(context: inout GraphicsContext, size: CGSize) {
        for facility in MapFacility.allCases {
            let point = facility.worldPoint
            let rect = CGRect(x: point.x - 0.021, y: point.y - 0.0185, width: 0.042, height: 0.037)
            let path = worldRect(rect, size)
            context.fill(path, with: .color(Color(red: 0.70, green: 0.71, blue: 0.68)))
            context.stroke(path, with: .color(facility.color.opacity(0.82)), lineWidth: 1.2)

            let buildingRect = rect.insetBy(dx: 0.005, dy: 0.004)
            let building = MapAssetLibrary.facility(facility, in: buildingRect)
            drawPrism(building, context: &context, size: size)
        }
    }

    private func drawGridCoordinates(context: inout GraphicsContext, size: CGSize) {
        for column in 0..<CityMapLayout.columnCount {
            let letter = String(UnicodeScalar(65 + column)!)
            let point = iso(.init(x: CityMapLayout.gridPoint(column: column, row: 0).x, y: 0.012), size)
            context.draw(Text(letter).font(.system(size: 6, weight: .black)).foregroundStyle(GameTheme.navy.opacity(0.70)), at: point)
        }
        for row in 0..<CityMapLayout.rowCount {
            let point = iso(.init(x: 0.012, y: CityMapLayout.gridPoint(column: 0, row: row).y), size)
            context.draw(Text("\(row + 1)").font(.system(size: 6, weight: .black)).foregroundStyle(GameTheme.navy.opacity(0.70)), at: point)
        }
    }

    private func drawTrees(context: inout GraphicsContext, size: CGSize) {
        for tree in CityMapLayout.blueprint.trees {
            let p = iso(tree.point, size)
            let scale = IsoProjection.heightScale(in: size, cameraScale: cameraScale)
            context.fill(Path(ellipseIn: CGRect(x: p.x - 7 * scale, y: p.y - 2 * scale, width: 14 * scale, height: 5 * scale)), with: .color(.black.opacity(0.18)))
            var trunk = Path(); trunk.move(to: p); trunk.addLine(to: CGPoint(x: p.x, y: p.y - 12 * scale))
            context.stroke(trunk, with: .color(.brown.opacity(0.92)), lineWidth: 2.4 * scale)
            let crown = CGRect(x: p.x - 6.5 * scale, y: p.y - 23 * scale, width: 13 * scale, height: 13 * scale)
            context.fill(Path(ellipseIn: crown), with: .color(tree.variant.isMultiple(of: 2) ? Color(red: 0.22, green: 0.55, blue: 0.27) : Color(red: 0.30, green: 0.63, blue: 0.31)))
            context.fill(Path(ellipseIn: crown.offsetBy(dx: -4 * scale, dy: 4 * scale)), with: .color(Color.green.opacity(0.88)))
            context.fill(Path(ellipseIn: crown.offsetBy(dx: 3 * scale, dy: 3 * scale)), with: .color(Color(red: 0.18, green: 0.48, blue: 0.24).opacity(0.92)))
        }
    }

    private func drawHighway(context: inout GraphicsContext, size: CGSize) {
        let highway = CityMapLayout.blueprint.highway
        for y in highway.laneYPositions {
            let start = iso(.init(x: -0.04, y: y), size)
            let end = iso(.init(x: 1.04, y: y), size)
            var shadow = Path(); shadow.move(to: CGPoint(x: start.x, y: start.y + 10 * cameraScale)); shadow.addLine(to: CGPoint(x: end.x, y: end.y + 10 * cameraScale))
            context.stroke(shadow, with: .color(GameTheme.ink.opacity(0.32)), style: StrokeStyle(lineWidth: 11 * cameraScale, lineCap: .square))
            var path = Path(); path.move(to: CGPoint(x: start.x, y: start.y - 4 * cameraScale)); path.addLine(to: CGPoint(x: end.x, y: end.y - 4 * cameraScale))
            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 12 * cameraScale, lineCap: .square))
            context.stroke(path, with: .color(Color(red: 0.20, green: 0.23, blue: 0.24)), style: StrokeStyle(lineWidth: 9 * cameraScale, lineCap: .square))
            context.stroke(path, with: .color(Color.yellow.opacity(0.78)), style: StrokeStyle(lineWidth: 1.5 * cameraScale, dash: [8 * cameraScale, 7 * cameraScale]))
        }
        let rampStart = iso(highway.rampStart, size)
        let rampEnd = iso(highway.rampEnd, size)
        var ramp = Path(); ramp.move(to: CGPoint(x: rampStart.x, y: rampStart.y - 4 * cameraScale)); ramp.addCurve(to: rampEnd, control1: CGPoint(x: rampStart.x + 25 * cameraScale, y: rampStart.y - 25 * cameraScale), control2: CGPoint(x: rampEnd.x + 22 * cameraScale, y: rampEnd.y + 18 * cameraScale))
        context.stroke(ramp, with: .color(.white), style: StrokeStyle(lineWidth: 9 * cameraScale, lineCap: .round))
        context.stroke(ramp, with: .color(GameTheme.road), style: StrokeStyle(lineWidth: 6 * cameraScale, lineCap: .round))
        let label = iso(highway.labelPoint, size)
        context.draw(Text("翠浜高速 E8").font(.caption2.bold()).foregroundStyle(.white), at: CGPoint(x: label.x, y: label.y - 7 * cameraScale))
    }

    private func drawPrism(_ building: IsoBuildingAsset, context: inout GraphicsContext, size: CGSize) {
        let scale = IsoProjection.heightScale(in: size, cameraScale: cameraScale)
        let visualHeight = building.height * scale * 0.72
        let r = building.rect
        let base = [
            iso(.init(x: r.minX, y: r.minY), size), iso(.init(x: r.maxX, y: r.minY), size),
            iso(.init(x: r.maxX, y: r.maxY), size), iso(.init(x: r.minX, y: r.maxY), size)
        ]
        let top = base.map { CGPoint(x: $0.x, y: $0.y - visualHeight) }
        let right = polygon([base[1], base[2], top[2], top[1]])
        let front = polygon([base[2], base[3], top[3], top[2]])
        let roof = polygon(top)

        let shadowOffset = CGSize(width: 7 * scale, height: 6 * scale)
        let shadow = polygon(base.map { CGPoint(x: $0.x + shadowOffset.width, y: $0.y + shadowOffset.height) })
        context.fill(shadow, with: .color(.black.opacity(0.20)))

        // Solid faces with one consistent light source make the blocks read as
        // actual volume instead of translucent diamonds.
        context.fill(right, with: .color(building.color))
        context.fill(right, with: .color(.black.opacity(0.28)))
        context.fill(front, with: .color(building.color))
        context.fill(front, with: .color(.black.opacity(0.12)))
        context.stroke(right, with: .color(GameTheme.ink.opacity(0.42)), lineWidth: 0.8)
        context.stroke(front, with: .color(GameTheme.ink.opacity(0.38)), lineWidth: 0.8)

        if building.roof == .house {
            drawHouseRoof(top: top, color: building.color, scale: scale, context: &context)
        } else {
            context.fill(roof, with: .color(building.color))
            context.fill(roof, with: .color(.white.opacity(0.20)))
            context.stroke(roof, with: .color(GameTheme.ink.opacity(0.42)), lineWidth: 0.9)
            let fascia = polygon([
                top[3], top[2], CGPoint(x: top[2].x, y: top[2].y + 3 * scale), CGPoint(x: top[3].x, y: top[3].y + 3 * scale)
            ])
            context.fill(fascia, with: .color(.black.opacity(0.18)))
        }

        switch building.detail {
        case .windows, .station:
            let columns = building.detail == .station ? 5 : 3
            let rows = max(2, min(5, Int(visualHeight / 10)))
            drawWindowGrid(topLeft: top[3], topRight: top[2], bottomLeft: base[3], bottomRight: base[2], columns: columns, rows: rows, brightness: 0.88, context: &context)
            drawWindowGrid(topLeft: top[1], topRight: top[2], bottomLeft: base[1], bottomRight: base[2], columns: max(2, columns - 1), rows: rows, brightness: 0.64, context: &context)
            if visualHeight > 35 {
                drawBalconyLines(topLeft: top[3], topRight: top[2], bottomLeft: base[3], bottomRight: base[2], rows: rows, context: &context)
            }
        case .retail, .roadside, .dealership:
            drawStorefront(topLeft: top[3], topRight: top[2], bottomLeft: base[3], bottomRight: base[2], accent: building.color, context: &context)
            drawWindowGrid(topLeft: top[1], topRight: top[2], bottomLeft: base[1], bottomRight: base[2], columns: 2, rows: 2, brightness: 0.58, context: &context)
        case .home:
            drawWindowGrid(topLeft: top[3], topRight: top[2], bottomLeft: base[3], bottomRight: base[2], columns: 2, rows: 1, brightness: 0.90, context: &context)
            drawDoor(topLeft: top[3], topRight: top[2], bottomLeft: base[3], bottomRight: base[2], context: &context)
        case .factory:
            drawFactoryFacade(top: top, base: base, scale: scale, context: &context)
        }

        if building.roof == .house {
            let chimneyBase = lerp(top[0], top[1], 0.72)
            let chimneyTop = CGPoint(x: chimneyBase.x, y: chimneyBase.y - 8 * scale)
            var chimney = Path(); chimney.move(to: chimneyBase); chimney.addLine(to: chimneyTop)
            context.stroke(chimney, with: .color(Color(red: 0.36, green: 0.25, blue: 0.20)), lineWidth: 3.2 * scale)
        }
        if building.roof == .sawtooth {
            drawSawtoothRoof(top: top, scale: scale, context: &context)
        }
    }

    private func drawHouseRoof(top: [CGPoint], color: Color, scale: CGFloat, context: inout GraphicsContext) {
        let rise = 9 * scale
        let ridgeLeft = CGPoint(x: (top[0].x + top[3].x) / 2, y: (top[0].y + top[3].y) / 2 - rise)
        let ridgeRight = CGPoint(x: (top[1].x + top[2].x) / 2, y: (top[1].y + top[2].y) / 2 - rise)
        let rightGable = polygon([top[1], top[2], ridgeRight])
        context.fill(rightGable, with: .color(color))
        context.fill(rightGable, with: .color(.black.opacity(0.20)))

        let backPlane = polygon([top[0], top[1], ridgeRight, ridgeLeft])
        let frontPlane = polygon([ridgeLeft, ridgeRight, top[2], top[3]])
        context.fill(backPlane, with: .color(Color(red: 0.55, green: 0.16, blue: 0.13)))
        context.fill(frontPlane, with: .color(Color(red: 0.75, green: 0.25, blue: 0.18)))
        context.stroke(backPlane, with: .color(GameTheme.ink.opacity(0.48)), lineWidth: 0.8)
        context.stroke(frontPlane, with: .color(GameTheme.ink.opacity(0.48)), lineWidth: 0.8)
        var ridge = Path(); ridge.move(to: ridgeLeft); ridge.addLine(to: ridgeRight)
        context.stroke(ridge, with: .color(.white.opacity(0.42)), lineWidth: 1)
    }

    private func drawWindowGrid(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, columns: Int, rows: Int, brightness: Double, context: inout GraphicsContext) {
        for row in 0..<rows {
            let rowHeight = 0.60 / CGFloat(rows)
            let v0 = 0.17 + CGFloat(row) * rowHeight
            let v1 = min(0.82, v0 + rowHeight * 0.58)
            for column in 0..<columns {
                let columnWidth = 0.84 / CGFloat(columns)
                let u0 = 0.08 + CGFloat(column) * columnWidth + columnWidth * 0.15
                let u1 = 0.08 + CGFloat(column + 1) * columnWidth - columnWidth * 0.15
                let window = faceQuad(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u0: u0, u1: u1, v0: v0, v1: v1)
                context.fill(window, with: .color(Color(red: 0.32, green: 0.71, blue: 0.82).opacity(brightness)))
                context.stroke(window, with: .color(.white.opacity(0.36)), lineWidth: 0.45)
            }
        }
    }

    private func drawBalconyLines(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, rows: Int, context: inout GraphicsContext) {
        for row in 0..<rows {
            let v = 0.17 + CGFloat(row + 1) * (0.60 / CGFloat(rows))
            let start = facePoint(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u: 0.04, v: v)
            let end = facePoint(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u: 0.96, v: v)
            var rail = Path(); rail.move(to: start); rail.addLine(to: end)
            context.stroke(rail, with: .color(GameTheme.ink.opacity(0.34)), lineWidth: 0.55)
        }
    }

    private func drawStorefront(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, accent: Color, context: inout GraphicsContext) {
        let glass = faceQuad(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u0: 0.07, u1: 0.93, v0: 0.48, v1: 0.91)
        context.fill(glass, with: .color(Color(red: 0.25, green: 0.62, blue: 0.72).opacity(0.88)))
        context.stroke(glass, with: .color(.white.opacity(0.68)), lineWidth: 0.8)
        let awning = faceQuad(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u0: 0.03, u1: 0.97, v0: 0.39, v1: 0.48)
        context.fill(awning, with: .color(accent))
        context.fill(awning, with: .color(.white.opacity(0.18)))
        drawDoor(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, context: &context)
    }

    private func drawDoor(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, context: inout GraphicsContext) {
        let door = faceQuad(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u0: 0.43, u1: 0.57, v0: 0.62, v1: 0.96)
        context.fill(door, with: .color(Color(red: 0.18, green: 0.28, blue: 0.30).opacity(0.92)))
        context.stroke(door, with: .color(.white.opacity(0.55)), lineWidth: 0.55)
    }

    private func drawFactoryFacade(top: [CGPoint], base: [CGPoint], scale: CGFloat, context: inout GraphicsContext) {
        let shutter = faceQuad(topLeft: top[3], topRight: top[2], bottomLeft: base[3], bottomRight: base[2], u0: 0.18, u1: 0.58, v0: 0.48, v1: 0.96)
        context.fill(shutter, with: .color(Color(red: 0.70, green: 0.73, blue: 0.72)))
        context.stroke(shutter, with: .color(GameTheme.ink.opacity(0.42)), lineWidth: 0.7)
        for index in 1..<4 {
            let v = 0.48 + CGFloat(index) * 0.12
            let start = facePoint(topLeft: top[3], topRight: top[2], bottomLeft: base[3], bottomRight: base[2], u: 0.18, v: v)
            let end = facePoint(topLeft: top[3], topRight: top[2], bottomLeft: base[3], bottomRight: base[2], u: 0.58, v: v)
            var seam = Path(); seam.move(to: start); seam.addLine(to: end)
            context.stroke(seam, with: .color(GameTheme.ink.opacity(0.25)), lineWidth: 0.45)
        }
        let chimneyBase = lerp(top[0], top[1], 0.76)
        let chimneyTop = CGPoint(x: chimneyBase.x, y: chimneyBase.y - 18 * scale)
        var chimney = Path(); chimney.move(to: chimneyBase); chimney.addLine(to: chimneyTop)
        context.stroke(chimney, with: .color(Color(red: 0.35, green: 0.38, blue: 0.39)), lineWidth: 5 * scale)
        context.stroke(chimney, with: .color(.white.opacity(0.24)), lineWidth: 1)
        context.fill(Path(ellipseIn: CGRect(x: chimneyTop.x - 3 * scale, y: chimneyTop.y - 2 * scale, width: 6 * scale, height: 4 * scale)), with: .color(.white.opacity(0.65)))
    }

    private func drawSawtoothRoof(top: [CGPoint], scale: CGFloat, context: inout GraphicsContext) {
        for index in 0..<3 {
            let u0 = CGFloat(index) / 3
            let u1 = CGFloat(index + 1) / 3
            let front0 = lerp(top[3], top[2], u0)
            let front1 = lerp(top[3], top[2], u1)
            let back0 = lerp(top[0], top[1], u0)
            let back1 = lerp(top[0], top[1], u1)
            let ridgeFront = CGPoint(x: front1.x, y: front1.y - 5 * scale)
            let ridgeBack = CGPoint(x: back1.x, y: back1.y - 5 * scale)
            let slope = polygon([back0, front0, ridgeFront, ridgeBack])
            context.fill(slope, with: .color(index.isMultiple(of: 2) ? Color.white.opacity(0.24) : Color.black.opacity(0.10)))
            var ridge = Path(); ridge.move(to: ridgeBack); ridge.addLine(to: ridgeFront)
            context.stroke(ridge, with: .color(.white.opacity(0.70)), lineWidth: 1)
        }
    }

    private func faceQuad(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, u0: CGFloat, u1: CGFloat, v0: CGFloat, v1: CGFloat) -> Path {
        polygon([
            facePoint(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u: u0, v: v0),
            facePoint(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u: u1, v: v0),
            facePoint(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u: u1, v: v1),
            facePoint(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, u: u0, v: v1)
        ])
    }

    private func facePoint(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, u: CGFloat, v: CGFloat) -> CGPoint {
        lerp(lerp(topLeft, topRight, u), lerp(bottomLeft, bottomRight, u), v)
    }

    private func lerp(_ start: CGPoint, _ end: CGPoint, _ amount: CGFloat) -> CGPoint {
        CGPoint(x: start.x + (end.x - start.x) * amount, y: start.y + (end.y - start.y) * amount)
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

    private func iso(_ point: CGPoint, _ size: CGSize) -> CGPoint {
        IsoProjection.project(point, in: size, cameraScale: cameraScale, cameraOffset: cameraOffset)
    }

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
    let cameraScale: CGFloat
    let cameraOffset: CGSize

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
                    let start = IsoProjection.project(startW, in: size, cameraScale: cameraScale, cameraOffset: cameraOffset)
                    let end = IsoProjection.project(endW, in: size, cameraScale: cameraScale, cameraOffset: cameraOffset)
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
    let cameraScale: CGFloat
    let cameraOffset: CGSize

    var body: some View {
        Canvas { context, size in
            for competitor in game.competitors {
                for plotID in competitor.plotIDs {
                    guard let plot = game.plot(id: plotID) else { continue }
                    let center = IsoProjection.project(CityMapLayout.position(for: plot.id), in: size, cameraScale: cameraScale, cameraOffset: cameraOffset)
                    let area = CGRect(x: center.x - 34 * cameraScale, y: center.y - 19 * cameraScale, width: 68 * cameraScale, height: 38 * cameraScale)
                    context.fill(Path(ellipseIn: area), with: .color(GameTheme.orange.opacity(0.10)))
                    context.stroke(Path(ellipseIn: area), with: .color(GameTheme.orange.opacity(0.58)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            for store in game.stores {
                guard let plot = game.plot(id: store.plotID) else { continue }
                let center = IsoProjection.project(CityMapLayout.position(for: plot.id), in: size, cameraScale: cameraScale, cameraOffset: cameraOffset)
                let strength = game.catchmentStrength(for: store)
                let width = 78 * strength * cameraScale
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
    let showMarker: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear
                if showMarker {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle().fill(markerColor).frame(width: markerSize, height: markerSize)
                            Circle().stroke(.white, lineWidth: 2).frame(width: markerSize, height: markerSize)
                            Image(systemName: markerIcon).font(.system(size: markerSize * 0.40, weight: .black)).foregroundStyle(.white)
                        }
                        if case .available = plot.occupant,
                           game.isTutorialActive, game.isFoundingCandidate(plot) {
                            Text(game.recommendedFoundingPlot?.id == plot.id ? "おすすめ" : "候補")
                                .font(.system(size: 7, weight: .black)).foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(game.recommendedFoundingPlot?.id == plot.id ? GameTheme.orange : GameTheme.teal)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .frame(width: hitTargetSize, height: hitTargetSize)
            .contentShape(Rectangle())
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
        case .available: 34
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
                if !compact {
                    if let subtitle = landmark.subtitle { Text(subtitle).font(.system(size: 6, weight: .bold)) }
                    Text(marketSummary)
                        .font(.system(size: 6, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            LandValueMeter(level: landValueLevel, tint: landmark.tint)
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
        case "newtown": "高級住宅"
        case "residential": "一般住宅"
        case "factory": "工業・物流"
        case "roadside": "ロードサイド・IC"
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

    private var landValueLevel: Int {
        let prices = game.plots.filter { $0.district == districtKind }.map(\.price)
        let average = prices.isEmpty ? 0 : prices.reduce(0, +) / prices.count
        if average >= 8_500 { return 3 }
        if average >= 5_000 { return 2 }
        return 1
    }
}

private struct LandValueMeter: View {
    let level: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("地価")
                .font(.system(size: 5, weight: .black))
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(1...3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(tint.opacity(index <= level ? 0.95 : 0.18))
                        .frame(width: 3, height: CGFloat(3 + index * 2))
                }
            }
        }
        .padding(.leading, 2)
        .accessibilityLabel("地価レベル\(level)")
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
