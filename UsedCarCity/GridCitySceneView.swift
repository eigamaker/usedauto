import SceneKit
import SwiftUI
import UIKit

struct GridCityMapSurface: View {
    @EnvironmentObject private var game: GameEngine
    let layer: MapLayer
    let demandCategory: VehicleCategory
    @Binding var selectedPlot: LandPlot?
    @Binding var selectedFacility: MapFacility?
    let focusRequest: MapFocusRequest?
    let isExpanded: Bool
    let toggleExpanded: () -> Void

    @State private var zoomStep = GridCameraZoom.demoInitialStep()
    @State private var cameraCommand = GridCameraCommand.none
    @State private var showsGrid = CommandLine.arguments.contains("-debug-grid")

    private let map = CityMapDefinition.suihama

    var body: some View {
        ZStack {
            GridSceneRepresentable(
                map: map,
                game: game,
                layer: layer,
                demandCategory: demandCategory,
                selectedPlotID: selectedPlot?.id,
                focusPlotID: effectiveFocusPlotID,
                focusRequestID: effectiveFocusRequestID,
                zoomStep: zoomStep,
                cameraCommand: cameraCommand,
                showsGrid: showsGrid,
                onZoomStepChanged: { zoomStep = $0 },
                onSelectPlot: select,
                onSelectFacility: { selectedFacility = $0 }
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Label("翠浜市 2.5Dビュー · \(GridCameraZoom.percentage(for: zoomStep))%", systemImage: "building.2.crop.circle")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(GameTheme.navy.opacity(0.86))
                        .clipShape(Capsule())
                    Spacer()
                    VStack(spacing: 7) {
                        GridCameraButton(icon: "plus.magnifyingglass", label: "一段階拡大") {
                            zoomStep = GridCameraZoom.clamped(zoomStep + 1)
                        }
                        GridCameraButton(icon: "minus.magnifyingglass", label: "一段階縮小") {
                            zoomStep = GridCameraZoom.clamped(zoomStep - 1)
                        }
                        GridCameraButton(icon: "scope", label: "街の中心に戻す") {
                            zoomStep = 0
                            cameraCommand = .reset()
                        }
                        GridCameraButton(
                            icon: showsGrid ? "square.grid.3x3.fill" : "square.grid.3x3",
                            label: showsGrid ? "グリッドを隠す" : "グリッドを表示"
                        ) {
                            showsGrid.toggle()
                        }
                        GridCameraButton(
                            icon: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                            label: isExpanded ? "通常表示に戻す" : "マップを全面表示"
                        ) {
                            withAnimation(.easeInOut(duration: 0.22)) { toggleExpanded() }
                        }
                    }
                }
                Spacer()
            }
            .padding(.top, 106)
            .padding(.horizontal, 10)
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("斜め上から見下ろす翠浜市の2.5Dシティマップ")
    }

    private var focusPlotID: Int? {
        guard let target = focusRequest?.target else { return nil }
        switch target {
        case .plot(let plotID):
            return map.parcel(legacyPlotID: plotID) == nil ? nil : plotID
        case .district(let district):
            guard let districtCenter = map.worldCenter(of: district) else { return nil }
            return map.parcels
                .filter { $0.district == district && $0.legacyPlotID != nil }
                .min { lhs, rhs in
                    let lhsCenter = map.metrics.worldBounds(of: lhs.rect, mapSize: map.size).center
                    let rhsCenter = map.metrics.worldBounds(of: rhs.rect, mapSize: map.size).center
                    return squaredDistance(lhsCenter, districtCenter)
                        < squaredDistance(rhsCenter, districtCenter)
                }?
                .legacyPlotID
        }
    }

    private var effectiveFocusPlotID: Int? {
        focusPlotID ?? GridCameraZoom.demoFocusPlotID()
    }

    private var effectiveFocusRequestID: UUID? {
        guard effectiveFocusPlotID != nil else { return nil }
        return focusRequest?.id ?? GridCameraZoom.demoFocusRequestID
    }

    private func squaredDistance(_ lhs: GridWorldPoint, _ rhs: GridWorldPoint) -> Float {
        let dx = lhs.x - rhs.x
        let dy = lhs.z - rhs.z
        return dx * dx + dy * dy
    }

    private func select(plotID: Int) {
        guard let plot = game.plot(id: plotID) else { return }
        if case .available = plot.occupant,
           game.tutorialStep == .chooseLocation || game.tutorialStep == .buildStore {
            game.selectFoundingPlot(plot.id)
        }
        selectedPlot = plot
    }
}

private struct GridCameraButton: View {
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

enum GridCameraZoom {
    static let scaleFactors = GridOrthographicCameraSpec.foundation.zoomScaleFactors.map(CGFloat.init)
    static let demoFocusRequestID = UUID()

    static func clamped(_ step: Int) -> Int {
        min(scaleFactors.count - 1, max(0, step))
    }

    static func percentage(for step: Int) -> Int {
        guard let baseline = scaleFactors.first else { return 100 }
        return Int((baseline / scaleFactors[clamped(step)] * 100).rounded())
    }

    static func nearestStep(to factor: CGFloat) -> Int {
        scaleFactors.indices.min {
            abs(scaleFactors[$0] - factor) < abs(scaleFactors[$1] - factor)
        } ?? 0
    }

    static func demoInitialStep(arguments: [String] = CommandLine.arguments) -> Int {
        if let argument = arguments.first(where: { $0.hasPrefix("-demo-map-zoom-step=") }),
           let value = Int(argument.split(separator: "=").last ?? "") {
            return clamped(value)
        }
        return arguments.contains("-demo-map-zoom") ? 2 : 0
    }

    static func demoFocusPlotID(arguments: [String] = CommandLine.arguments) -> Int? {
        guard let argument = arguments.first(where: { $0.hasPrefix("-demo-map-focus-plot=") }) else {
            return nil
        }
        return Int(argument.split(separator: "=").last ?? "")
    }
}

private struct GridCameraCommand: Equatable {
    enum Action: Equatable { case none, reset }

    let id: UUID
    let action: Action

    static let none = GridCameraCommand(id: UUID(), action: .none)
    static func reset() -> GridCameraCommand { .init(id: UUID(), action: .reset) }
}

private struct GridSceneRepresentable: UIViewRepresentable {
    let map: GridCityMap
    let game: GameEngine
    let layer: MapLayer
    let demandCategory: VehicleCategory
    let selectedPlotID: Int?
    let focusPlotID: Int?
    let focusRequestID: UUID?
    let zoomStep: Int
    let cameraCommand: GridCameraCommand
    let showsGrid: Bool
    let onZoomStepChanged: (Int) -> Void
    let onSelectPlot: (Int) -> Void
    let onSelectFacility: (MapFacility) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onZoomStepChanged: onZoomStepChanged,
            onSelectPlot: onSelectPlot,
            onSelectFacility: onSelectFacility
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView(frame: .zero, options: nil)
        let controller = GridCitySceneController(map: map, sceneView: sceneView)
        context.coordinator.controller = controller
        context.coordinator.installGestures(on: sceneView)
        controller.updateRuntime(
            game: game,
            layer: layer,
            demandCategory: demandCategory,
            selectedPlotID: selectedPlotID
        )
        if let demoFocusPlotID = GridCameraZoom.demoFocusPlotID() {
            controller.focus(onLegacyPlotID: demoFocusPlotID, animated: false)
        }
        controller.setGridVisible(showsGrid)
        return sceneView
    }

    func updateUIView(_ sceneView: SCNView, context: Context) {
        context.coordinator.onZoomStepChanged = onZoomStepChanged
        context.coordinator.onSelectPlot = onSelectPlot
        context.coordinator.onSelectFacility = onSelectFacility
        guard let controller = context.coordinator.controller else { return }
        controller.updateLayout(viewSize: sceneView.bounds.size)
        controller.setZoomStep(zoomStep, animated: true)
        controller.setGridVisible(showsGrid)
        controller.updateRuntime(
            game: game,
            layer: layer,
            demandCategory: demandCategory,
            selectedPlotID: selectedPlotID
        )
        if context.coordinator.lastCameraCommandID != cameraCommand.id {
            context.coordinator.lastCameraCommandID = cameraCommand.id
            if cameraCommand.action == .reset { controller.resetCamera(animated: true) }
        }
        if context.coordinator.lastFocusRequestID != focusRequestID {
            context.coordinator.lastFocusRequestID = focusRequestID
            if let focusPlotID {
                let focusedZoomStep = max(zoomStep, 2)
                controller.focus(onLegacyPlotID: focusPlotID, animated: true)
                if focusedZoomStep != zoomStep { onZoomStepChanged(focusedZoomStep) }
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var controller: GridCitySceneController?
        var onZoomStepChanged: (Int) -> Void
        var onSelectPlot: (Int) -> Void
        var onSelectFacility: (MapFacility) -> Void
        var lastCameraCommandID: UUID?
        var lastFocusRequestID: UUID?
        private var pinchStartFactor: CGFloat = 1

        init(
            onZoomStepChanged: @escaping (Int) -> Void,
            onSelectPlot: @escaping (Int) -> Void,
            onSelectFacility: @escaping (MapFacility) -> Void
        ) {
            self.onZoomStepChanged = onZoomStepChanged
            self.onSelectPlot = onSelectPlot
            self.onSelectFacility = onSelectFacility
        }

        func installGestures(on view: SCNView) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pan.minimumNumberOfTouches = 1
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            pinch.delegate = self
            tap.require(toFail: pan)
            view.addGestureRecognizer(tap)
            view.addGestureRecognizer(pan)
            view.addGestureRecognizer(pinch)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let view = gesture.view as? SCNView,
                  let selection = controller?.selection(at: gesture.location(in: view)) else { return }
            switch selection {
            case .plot(let plotID): onSelectPlot(plotID)
            case .facility(let facility): onSelectFacility(facility)
            }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            switch gesture.state {
            case .began:
                controller?.beginPan()
            case .changed:
                controller?.pan(by: gesture.translation(in: view), viewSize: view.bounds.size)
            case .ended, .cancelled, .failed:
                controller?.endPan()
            default:
                break
            }
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                pinchStartFactor = controller?.zoomFactor ?? 1
            case .changed:
                controller?.setContinuousZoomFactor(pinchStartFactor / gesture.scale)
            case .ended, .cancelled, .failed:
                let step = GridCameraZoom.nearestStep(to: controller?.zoomFactor ?? 1)
                controller?.setZoomStep(step, animated: true)
                onZoomStepChanged(step)
            default:
                break
            }
        }
    }
}

@MainActor
private enum GridSceneSelection {
    case plot(Int)
    case facility(MapFacility)
}

@MainActor
private final class GridCitySceneController {
    private let map: GridCityMap
    private weak var sceneView: SCNView?
    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let gridNode = SCNNode()
    private var parcelNodes: [String: SCNNode] = [:]
    private var staticObjectNodes: [String: SCNNode] = [:]
    private var vacantMarkerNodes: [String: SCNNode] = [:]
    private var runtimeStoreNodes: [UUID: SCNNode] = [:]
    private var runtimeStoreSignatures: [UUID: String] = [:]
    private var interactionPlotIDs: [ObjectIdentifier: Int] = [:]
    private var interactionFacilities: [ObjectIdentifier: MapFacility] = [:]
    private var facilityNodes: [MapFacility: SCNNode] = [:]
    private var assetLODNodes: [ObjectIdentifier: (near: SCNNode, props: SCNNode)] = [:]
    private var appliedAssetLODVisibility: CityAssetLODVisibility?

    private var focusPoint = SCNVector3Zero
    private var panStartFocus = SCNVector3Zero
    private var baseOrthographicScale: CGFloat = 1
    private var currentZoomStep = 0
    private var currentZoomFactor: CGFloat = 1
    private var lastViewSize = CGSize.zero
    private lazy var assetFactory = CityBuildingFactory(cellSize: map.metrics.cellSize)

    var zoomFactor: CGFloat { currentZoomFactor }

    init(
        map: GridCityMap,
        sceneView: SCNView
    ) {
        self.map = map
        self.sceneView = sceneView
        configureView(sceneView)
        buildScene()
        updateLayout(viewSize: sceneView.bounds.size)
        applyCamera(animated: false)
    }

    func updateLayout(viewSize: CGSize) {
        guard viewSize.width > 0, viewSize.height > 0, viewSize != lastViewSize else { return }
        lastViewSize = viewSize
        let contentBounds = map.cameraContentBounds
        let projectedWidth = CGFloat(contentBounds.width + contentBounds.depth) / sqrt(2)
        let projectedHeight = CGFloat(contentBounds.width + contentBounds.depth) * 0.58 / sqrt(2)
        let aspect = max(0.25, viewSize.width / viewSize.height)
        // Keep the whole city readable while using most of a phone's narrow
        // viewport. The fixed camera may reveal a small margin for panning.
        baseOrthographicScale = max(projectedHeight * 1.08, projectedWidth / aspect * 0.58)
        cameraNode.camera?.orthographicScale = baseOrthographicScale * currentZoomFactor
        applyCamera(animated: false)
    }

    func setZoomStep(_ step: Int, animated: Bool) {
        let clamped = GridCameraZoom.clamped(step)
        guard clamped != currentZoomStep || abs(currentZoomFactor - GridCameraZoom.scaleFactors[clamped]) > 0.001 else { return }
        currentZoomStep = clamped
        currentZoomFactor = GridCameraZoom.scaleFactors[clamped]
        updateFacilityVisibility()
        updateAssetLODVisibility()
        applyCamera(animated: animated)
    }

    func setContinuousZoomFactor(_ factor: CGFloat) {
        currentZoomFactor = min(
            GridCameraZoom.scaleFactors.first ?? 1,
            max(GridCameraZoom.scaleFactors.last ?? 0.0314286, factor)
        )
        updateFacilityVisibility()
        updateAssetLODVisibility()
        applyCamera(animated: false)
    }

    func resetCamera(animated: Bool) {
        let cityCenter = map.cameraContentBounds.center
        focusPoint = SCNVector3(cityCenter.x, 0, cityCenter.z)
        currentZoomStep = 0
        currentZoomFactor = GridCameraZoom.scaleFactors[0]
        updateFacilityVisibility()
        updateAssetLODVisibility()
        applyCamera(animated: animated)
    }

    func focus(onLegacyPlotID plotID: Int, animated: Bool) {
        guard let parcel = map.parcel(legacyPlotID: plotID) else { return }
        let center = map.metrics.worldBounds(of: parcel.rect, mapSize: map.size).center
        focusPoint = SCNVector3(center.x, 0, center.z)
        if currentZoomStep < 2 {
            currentZoomStep = 2
            currentZoomFactor = GridCameraZoom.scaleFactors[2]
        }
        updateFacilityVisibility()
        updateAssetLODVisibility()
        applyCamera(animated: animated)
    }

    func beginPan() {
        panStartFocus = focusPoint
    }

    func pan(by translation: CGPoint, viewSize: CGSize) {
        guard viewSize.height > 0 else { return }
        let worldPerPoint = Float(baseOrthographicScale * currentZoomFactor / viewSize.height)
        let inverseRootTwo = Float(1 / sqrt(2.0))
        let horizontal = Float(translation.x) * worldPerPoint
        let vertical = Float(translation.y) * worldPerPoint * 1.35
        focusPoint = SCNVector3(
            panStartFocus.x - horizontal * inverseRootTwo - vertical * inverseRootTwo,
            0,
            panStartFocus.z + horizontal * inverseRootTwo - vertical * inverseRootTwo
        )
        applyCamera(animated: false)
    }

    func endPan() {
        clampFocus()
        applyCamera(animated: false)
    }

    func setGridVisible(_ isVisible: Bool) {
        gridNode.isHidden = !isVisible
        sceneView?.setNeedsDisplay()
    }

    func selection(at point: CGPoint) -> GridSceneSelection? {
        let hits = sceneView?.hitTest(point, options: [
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue,
            SCNHitTestOption.ignoreHiddenNodes: true
        ]) ?? []
        for hit in hits {
            var node: SCNNode? = hit.node
            while let current = node {
                if let facility = interactionFacilities[ObjectIdentifier(current)] {
                    return .facility(facility)
                }
                if let plotID = interactionPlotIDs[ObjectIdentifier(current)] {
                    return .plot(plotID)
                }
                node = current.parent
            }
        }
        return nil
    }

    func updateRuntime(
        game: GameEngine,
        layer: MapLayer,
        demandCategory: VehicleCategory,
        selectedPlotID: Int?
    ) {
        let maximumPrice = max(1, game.plots.map(\.price).max() ?? 1)
        for parcel in map.parcels {
            guard let node = parcelNodes[parcel.id],
                  let material = node.geometry?.firstMaterial else { continue }
            let plot = parcel.legacyPlotID.flatMap(game.plot(id:))
            material.diffuse.contents = parcelColor(
                parcel: parcel,
                plot: plot,
                game: game,
                layer: layer,
                demandCategory: demandCategory,
                maximumPrice: maximumPrice,
                isSelected: parcel.legacyPlotID == selectedPlotID
            )
            material.emission.contents = emissionColor(
                plot: plot,
                game: game,
                isSelected: parcel.legacyPlotID == selectedPlotID
            )

            if let marker = vacantMarkerNodes[parcel.id] {
                marker.isHidden = plot?.currentUse.isVacant != true
            }
        }

        for object in map.objects {
            guard let node = staticObjectNodes[object.id],
                  let parcel = map.parcel(id: object.parcelID),
                  let plotID = parcel.legacyPlotID,
                  let plot = game.plot(id: plotID) else {
                staticObjectNodes[object.id]?.isHidden = false
                continue
            }
            switch plot.currentUse {
            case .ambientBuilding(let assetID):
                node.isHidden = object.kind != .building || object.assetID != assetID
            case .surfaceParking:
                node.isHidden = object.kind != .parking
            case .vacant, .construction, .playerFacility, .displayParking:
                node.isHidden = true
            }
        }
        updateStoreNodes(
            stores: game.stores,
            plotByID: Dictionary(uniqueKeysWithValues: game.plots.map { ($0.id, $0) })
        )
        sceneView?.setNeedsDisplay()
    }

    private func configureView(_ view: SCNView) {
        view.scene = scene
        view.backgroundColor = UIColor(red: 0.76, green: 0.89, blue: 0.94, alpha: 1)
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 30
        view.rendersContinuously = false
        view.isJitteringEnabled = false
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.accessibilityLabel = "翠浜市グリッドマップ"
    }

    private func buildScene() {
        buildTerrainGround()
        buildParcelNodes()
        buildRoadNetwork()
        buildBridgeFurniture()
        buildStaticObjectNodes()
        buildVacantMarkers()
        buildGreenery()
        buildFacilityMarkers()
        buildGridNode()
        buildLighting()
        buildCamera()
        updateAssetLODVisibility()
    }

    // MARK: - Terrain

    private enum GroundKind: Hashable, CaseIterable {
        case grass
        case park
        case beach
        case plaza
        case water

        var surfaceHeight: Float {
            switch self {
            case .grass: GridSceneElevation.groundSurface + 0.30
            case .park: GridSceneElevation.groundSurface + 0.31
            case .beach: GridSceneElevation.groundSurface + 0.26
            case .plaza: GridSceneElevation.groundSurface + 0.34
            case .water: GridSceneElevation.groundSurface + 0.08
            }
        }
    }

    private func groundKind(at coordinate: GridCoordinate) -> GroundKind {
        switch map.terrain[coordinate] {
        case .water: .water
        case .beach: .beach
        case .park: .park
        case .plaza: .plaza
        case nil: .grass
        }
    }

    /// The whole ground plane is merged into one static geometry per surface
    /// kind: run-length strips over the map cells plus an apron that extends
    /// every edge cell outward, so the city never reads as a floating slab.
    private func buildTerrainGround() {
        let bounds = map.metrics.worldBounds(of: map.size)
        let cell = map.metrics.cellSize
        let apron = cell * 44
        var strips: [GroundKind: [(GridWorldPoint, GridLocalSurfaceRect)]] = [:]

        func appendStrip(kind: GroundKind, minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
            strips[kind, default: []].append((
                GridWorldPoint(x: (minX + maxX) / 2, z: (minZ + maxZ) / 2),
                GridLocalSurfaceRect(centerX: 0, centerZ: 0, width: maxX - minX, depth: maxZ - minZ)
            ))
        }

        for row in 0..<map.size.rows {
            var runStart = 0
            var runKind = groundKind(at: GridCoordinate(column: 0, row: row))
            func flush(_ endColumn: Int) {
                let minX = bounds.minX + Float(runStart) * cell
                let maxX = bounds.minX + Float(endColumn) * cell
                let minZ = bounds.minZ + Float(row) * cell
                appendStrip(kind: runKind, minX: minX, maxX: maxX, minZ: minZ, maxZ: minZ + cell)
            }
            for column in 1..<map.size.columns {
                let kind = groundKind(at: GridCoordinate(column: column, row: row))
                if kind != runKind {
                    flush(column)
                    runStart = column
                    runKind = kind
                }
            }
            flush(map.size.columns)

            // West/east aprons continue the row's edge cells outward.
            let minZ = bounds.minZ + Float(row) * cell
            let westKind = groundKind(at: GridCoordinate(column: 0, row: row))
            appendStrip(kind: westKind, minX: bounds.minX - apron, maxX: bounds.minX, minZ: minZ, maxZ: minZ + cell)
            let eastKind = groundKind(at: GridCoordinate(column: map.size.columns - 1, row: row))
            appendStrip(kind: eastKind, minX: bounds.maxX, maxX: bounds.maxX + apron, minZ: minZ, maxZ: minZ + cell)
        }
        for column in 0..<map.size.columns {
            let minX = bounds.minX + Float(column) * cell
            let northKind = groundKind(at: GridCoordinate(column: column, row: 0))
            appendStrip(kind: northKind, minX: minX, maxX: minX + cell, minZ: bounds.minZ - apron, maxZ: bounds.minZ)
            let southKind = groundKind(at: GridCoordinate(column: column, row: map.size.rows - 1))
            appendStrip(kind: southKind, minX: minX, maxX: minX + cell, minZ: bounds.maxZ, maxZ: bounds.maxZ + apron)
        }
        // Corner aprons continue the corner cells.
        appendStrip(kind: groundKind(at: GridCoordinate(column: 0, row: 0)),
                    minX: bounds.minX - apron, maxX: bounds.minX,
                    minZ: bounds.minZ - apron, maxZ: bounds.minZ)
        appendStrip(kind: groundKind(at: GridCoordinate(column: map.size.columns - 1, row: 0)),
                    minX: bounds.maxX, maxX: bounds.maxX + apron,
                    minZ: bounds.minZ - apron, maxZ: bounds.minZ)
        appendStrip(kind: groundKind(at: GridCoordinate(column: 0, row: map.size.rows - 1)),
                    minX: bounds.minX - apron, maxX: bounds.minX,
                    minZ: bounds.maxZ, maxZ: bounds.maxZ + apron)
        appendStrip(kind: groundKind(at: GridCoordinate(column: map.size.columns - 1, row: map.size.rows - 1)),
                    minX: bounds.maxX, maxX: bounds.maxX + apron,
                    minZ: bounds.maxZ, maxZ: bounds.maxZ + apron)

        for kind in GroundKind.allCases {
            guard let rects = strips[kind], !rects.isEmpty else { continue }
            let geometry = makeHorizontalGeometry(
                rectangles: rects,
                height: kind.surfaceHeight,
                material: groundMaterial(for: kind),
                uvScale: 1 / cell
            )
            let node = SCNNode(geometry: geometry)
            node.name = "ground-\(kind)"
            node.castsShadow = false
            scene.rootNode.addChildNode(node)
        }

        buildShoreline()
    }

    /// Foam band along every water edge that touches land.
    private func buildShoreline() {
        let foamWidth = map.metrics.cellSize * 0.14
        var rects: [(GridWorldPoint, GridLocalSurfaceRect)] = []
        for row in 0..<map.size.rows {
            for column in 0..<map.size.columns {
                let coordinate = GridCoordinate(column: column, row: row)
                guard groundKind(at: coordinate) == .water else { continue }
                let center = map.metrics.worldCenter(of: coordinate, mapSize: map.size)
                let half = map.metrics.cellSize / 2
                for direction in CardinalDirection.allCases {
                    let neighbor = coordinate.neighbor(in: direction)
                    guard map.size.contains(neighbor), groundKind(at: neighbor) != .water else { continue }
                    switch direction {
                    case .north:
                        rects.append((center, .init(centerX: 0, centerZ: -half + foamWidth / 2, width: map.metrics.cellSize, depth: foamWidth)))
                    case .south:
                        rects.append((center, .init(centerX: 0, centerZ: half - foamWidth / 2, width: map.metrics.cellSize, depth: foamWidth)))
                    case .east:
                        rects.append((center, .init(centerX: half - foamWidth / 2, centerZ: 0, width: foamWidth, depth: map.metrics.cellSize)))
                    case .west:
                        rects.append((center, .init(centerX: -half + foamWidth / 2, centerZ: 0, width: foamWidth, depth: map.metrics.cellSize)))
                    }
                }
            }
        }
        guard !rects.isEmpty else { return }
        let material = flatMaterial(named: "shore-foam", color: UIColor(white: 1, alpha: 0.62))
        let geometry = makeHorizontalGeometry(
            rectangles: rects,
            height: GroundKind.water.surfaceHeight + 0.02,
            material: material,
            uvScale: 0
        )
        let node = SCNNode(geometry: geometry)
        node.name = "shoreline-foam"
        node.castsShadow = false
        scene.rootNode.addChildNode(node)
    }

    // MARK: - Parcels

    private func buildParcelNodes() {
        for parcel in map.parcels {
            let bounds = map.metrics.worldBounds(of: parcel.rect, mapSize: map.size)
            let geometry = SCNBox(
                width: CGFloat(bounds.width),
                height: 0.40,
                length: CGFloat(bounds.depth),
                chamferRadius: 0.5
            )
            geometry.firstMaterial = material(color: baseDistrictColor(parcel.district))
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(bounds.center.x, 0.20, bounds.center.z)
            node.name = "parcel:\(parcel.id)"
            node.castsShadow = false
            setInteractionMetadata(on: node, parcel: parcel)
            parcelNodes[parcel.id] = node
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Roads

    private func buildRoadNetwork() {
        // Sidewalk pads first, pavement above, decals on top.
        scene.rootNode.addChildNode(makeSidewalkNode())
        for roadClass in GridRoadClass.allCases {
            scene.rootNode.addChildNode(makePavementNode(for: roadClass))
        }
        scene.rootNode.addChildNode(makeLaneMarkingNode())
        scene.rootNode.addChildNode(makeCrosswalkNode())
    }

    private func makeSidewalkNode() -> SCNNode {
        var rectangles: [(GridWorldPoint, GridLocalSurfaceRect)] = []
        for road in map.roads.values.sorted(by: { $0.coordinate < $1.coordinate })
        where road.roadClass != .expressway {
            let center = map.metrics.worldCenter(of: road.coordinate, mapSize: map.size)
            for piece in GridRoadSurfaceLayout.pieces(
                for: road,
                in: map.roads,
                cellSize: map.metrics.cellSize,
                isSidewalk: true
            ) {
                rectangles.append((center, piece))
            }
        }
        let geometry = makeHorizontalGeometry(
            rectangles: rectangles,
            height: GridSceneElevation.sidewalkSurface,
            material: texturedMaterial(named: "sidewalk", image: CityGroundArt.sidewalkTexture(), lighting: .lambert),
            uvScale: 1 / map.metrics.cellSize
        )
        let node = SCNNode(geometry: geometry)
        node.name = "road-sidewalks"
        node.castsShadow = false
        return node
    }

    private func makePavementNode(for roadClass: GridRoadClass) -> SCNNode {
        var rectangles: [(GridWorldPoint, GridLocalSurfaceRect)] = []
        for road in map.roads.values.sorted(by: { $0.coordinate < $1.coordinate })
        where road.roadClass == roadClass {
            let center = map.metrics.worldCenter(of: road.coordinate, mapSize: map.size)
            for piece in GridRoadSurfaceLayout.pieces(
                for: road,
                in: map.roads,
                cellSize: map.metrics.cellSize,
                isSidewalk: false
            ) {
                rectangles.append((center, piece))
            }
        }
        let image: UIImage = switch roadClass {
        case .local: CityGroundArt.asphaltTexture(brightness: 0.36)
        case .arterial: CityGroundArt.asphaltTexture(brightness: 0.30)
        case .expressway: CityGroundArt.asphaltTexture(brightness: 0.25)
        }
        let geometry = makeHorizontalGeometry(
            rectangles: rectangles,
            height: GridSceneElevation.pavementSurface,
            material: texturedMaterial(named: "pavement-\(roadClass.rawValue)", image: image, lighting: .lambert),
            uvScale: 1 / map.metrics.cellSize
        )
        let node = SCNNode(geometry: geometry)
        node.name = "road-pavement-\(roadClass.rawValue)"
        node.castsShadow = false
        return node
    }

    private func makeLaneMarkingNode() -> SCNNode {
        var rectangles: [(GridWorldPoint, GridLocalSurfaceRect)] = []
        let cell = map.metrics.cellSize
        for road in map.roads.values {
            let center = map.metrics.worldCenter(of: road.coordinate, mapSize: map.size)
            switch road.roadClass {
            case .arterial:
                // Solid center line along straight axes.
                if road.connections.contains(.north) || road.connections.contains(.south) {
                    let hasHorizontal = road.connections.contains(.east) || road.connections.contains(.west)
                    if !hasHorizontal {
                        rectangles.append((center, .init(centerX: 0, centerZ: 0, width: 0.40, depth: cell)))
                    }
                }
                if road.connections.contains(.east) || road.connections.contains(.west) {
                    let hasVertical = road.connections.contains(.north) || road.connections.contains(.south)
                    if !hasVertical {
                        rectangles.append((center, .init(centerX: 0, centerZ: 0, width: cell, depth: 0.40)))
                    }
                }
            case .expressway:
                // Dashed center plus shoulder lines along the corridor.
                if road.connections.contains(.east) || road.connections.contains(.west) {
                    for offset in [-0.30 as Float, 0.10] {
                        rectangles.append((center, .init(centerX: cell * offset, centerZ: 0, width: cell * 0.24, depth: 0.34)))
                    }
                    let shoulder = road.roadClass.pavementWidth(cellSize: cell) / 2 - 0.55
                    rectangles.append((center, .init(centerX: 0, centerZ: -shoulder, width: cell, depth: 0.30)))
                    rectangles.append((center, .init(centerX: 0, centerZ: shoulder, width: cell, depth: 0.30)))
                }
            case .local:
                break
            }
        }
        let geometry = makeHorizontalGeometry(
            rectangles: rectangles,
            height: GridSceneElevation.pavementSurface + 0.015,
            material: flatMaterial(named: "lane-paint", color: UIColor(red: 0.93, green: 0.90, blue: 0.80, alpha: 0.9)),
            uvScale: 0
        )
        let node = SCNNode(geometry: geometry)
        node.name = "lane-markings"
        node.castsShadow = false
        return node
    }

    /// Zebra crossings where a local street meets an arterial.
    private func makeCrosswalkNode() -> SCNNode {
        var rectangles: [(GridWorldPoint, GridLocalSurfaceRect)] = []
        let cell = map.metrics.cellSize
        let stripeCount = 5
        for road in map.roads.values where road.roadClass == .arterial {
            let center = map.metrics.worldCenter(of: road.coordinate, mapSize: map.size)
            for direction in road.connections.directions {
                guard let neighbor = map.roads[road.coordinate.neighbor(in: direction)],
                      neighbor.roadClass == .local else { continue }
                let span = GridRoadClass.local.pavementWidth(cellSize: cell)
                let stripeLength = span * 0.86
                let stripeWidth: Float = 0.62
                let inset = cell / 2 - 1.9
                for index in 0..<stripeCount {
                    let t = Float(index) / Float(stripeCount - 1) - 0.5
                    let lateral = t * stripeLength
                    switch direction {
                    case .north:
                        rectangles.append((center, .init(centerX: lateral, centerZ: -inset, width: stripeWidth, depth: 2.4)))
                    case .south:
                        rectangles.append((center, .init(centerX: lateral, centerZ: inset, width: stripeWidth, depth: 2.4)))
                    case .east:
                        rectangles.append((center, .init(centerX: inset, centerZ: lateral, width: 2.4, depth: stripeWidth)))
                    case .west:
                        rectangles.append((center, .init(centerX: -inset, centerZ: lateral, width: 2.4, depth: stripeWidth)))
                    }
                }
            }
        }
        let geometry = makeHorizontalGeometry(
            rectangles: rectangles,
            height: GridSceneElevation.pavementSurface + 0.018,
            material: flatMaterial(named: "crosswalk-paint", color: UIColor(white: 0.96, alpha: 0.88)),
            uvScale: 0
        )
        let node = SCNNode(geometry: geometry)
        node.name = "crosswalks"
        node.castsShadow = false
        return node
    }

    /// Rails and causeway bases for every road segment that crosses water.
    private func buildBridgeFurniture() {
        let cell = map.metrics.cellSize
        let container = SCNNode()
        container.name = "bridge-furniture"
        let railMaterial = material(color: UIColor(red: 0.88, green: 0.89, blue: 0.90, alpha: 1))
        let baseMaterial = material(color: UIColor(red: 0.47, green: 0.50, blue: 0.53, alpha: 1))

        for road in map.roads.values where map.terrain[road.coordinate] == .water {
            let center = map.metrics.worldCenter(of: road.coordinate, mapSize: map.size)
            let pavementWidth = road.roadClass.pavementWidth(cellSize: cell)
            let isEastWest = road.connections.contains(.east) || road.connections.contains(.west)

            // Causeway base fills the water gap below the deck.
            let base = SCNBox(
                width: CGFloat(isEastWest ? cell : pavementWidth + 1.6),
                height: CGFloat(GridSceneElevation.pavementSurface - 0.02),
                length: CGFloat(isEastWest ? pavementWidth + 1.6 : cell),
                chamferRadius: 0
            )
            base.firstMaterial = baseMaterial
            let baseNode = SCNNode(geometry: base)
            baseNode.position = SCNVector3(center.x, GridSceneElevation.pavementSurface / 2 - 0.01, center.z)
            container.addChildNode(baseNode)

            let railHeight: Float = 1.5
            let railThickness: Float = 0.5
            let offset = pavementWidth / 2 + railThickness / 2 + 0.15
            let rail = SCNBox(
                width: CGFloat(isEastWest ? cell : railThickness),
                height: CGFloat(railHeight),
                length: CGFloat(isEastWest ? railThickness : cell),
                chamferRadius: 0.1
            )
            rail.firstMaterial = railMaterial
            for side in [-offset, offset] {
                let railNode = SCNNode(geometry: rail)
                railNode.position = SCNVector3(
                    center.x + (isEastWest ? 0 : side),
                    GridSceneElevation.pavementSurface + railHeight / 2,
                    center.z + (isEastWest ? side : 0)
                )
                container.addChildNode(railNode)
            }
        }
        scene.rootNode.addChildNode(container.flattenedClone())
    }

    // MARK: - Greenery

    /// Deterministic street and park trees, flattened into a handful of draw
    /// calls.
    private func buildGreenery() {
        let container = SCNNode()
        container.name = "city-greenery"
        let cell = map.metrics.cellSize

        func seededUnit(_ column: Int, _ row: Int, _ salt: Int) -> Float {
            var value = UInt64(bitPattern: Int64(column * 73_856_093 ^ row * 19_349_663 ^ salt * 83_492_791))
            value = (value ^ (value >> 33)) &* 0xFF51_AFD7_ED55_8CCD
            value = (value ^ (value >> 33)) &* 0xC4CE_B9FE_1A85_EC53
            return Float((value ^ (value >> 33)) % 1_000) / 1_000
        }

        for row in 0..<map.size.rows {
            for column in 0..<map.size.columns {
                let coordinate = GridCoordinate(column: column, row: row)
                let center = map.metrics.worldCenter(of: coordinate, mapSize: map.size)
                switch map.terrain[coordinate] {
                case .park:
                    let roll = seededUnit(column, row, 1)
                    guard roll > 0.16 else { continue }
                    let count = roll > 0.60 ? 2 : 1
                    for index in 0..<count {
                        let dx = (seededUnit(column, row, 2 + index) - 0.5) * cell * 0.66
                        let dz = (seededUnit(column, row, 4 + index) - 0.5) * cell * 0.66
                        let scale = 1.7 + seededUnit(column, row, 6 + index) * 1.1
                        let tree = makeTreeNode(
                            broadleaf: seededUnit(column, row, 8 + index) > 0.30,
                            scale: scale
                        )
                        tree.position = SCNVector3(center.x + dx, GroundKind.park.surfaceHeight, center.z + dz)
                        container.addChildNode(tree)
                    }
                case nil:
                    // Street trees line green verges next to arterials.
                    guard (column + row).isMultiple(of: 2) else { continue }
                    let touchesArterial = CardinalDirection.allCases.contains { direction in
                        map.roads[coordinate.neighbor(in: direction)]?.roadClass == .arterial
                    }
                    let isOpenGrass = map.parcel(at: coordinate) == nil
                    guard touchesArterial, isOpenGrass, seededUnit(column, row, 11) > 0.28 else { continue }
                    let tree = makeTreeNode(
                        broadleaf: true,
                        scale: 1.5 + seededUnit(column, row, 12) * 0.6
                    )
                    tree.position = SCNVector3(center.x, GroundKind.grass.surfaceHeight, center.z)
                    container.addChildNode(tree)
                default:
                    break
                }
            }
        }

        // A loose forest ring on the apron frames the city and hides the
        // hard map boundary. Only land-edge cells grow trees.
        let bounds = map.metrics.worldBounds(of: map.size)
        for ring in 1...22 {
            let step = ring < 5 ? 2 : (ring < 12 ? 3 : 4)
            for column in Swift.stride(from: -ring, through: map.size.columns - 1 + ring, by: step) {
                for row in [-ring, map.size.rows - 1 + ring] {
                    let clampedColumn = min(max(column, 0), map.size.columns - 1)
                    let clampedRow = min(max(row, 0), map.size.rows - 1)
                    guard groundKind(at: GridCoordinate(column: clampedColumn, row: clampedRow)) != .water,
                          seededUnit(column, row, 21) > (ring < 5 ? 0.26 : 0.42) else { continue }
                    let x = bounds.minX + (Float(column) + 0.5) * cell
                        + (seededUnit(column, row, 22) - 0.5) * cell * 1.6
                    let z = bounds.minZ + (Float(row) + 0.5) * cell
                        + (seededUnit(column, row, 23) - 0.5) * cell * 1.6
                    let tree = makeTreeNode(
                        broadleaf: seededUnit(column, row, 24) > 0.42,
                        scale: 1.8 + seededUnit(column, row, 25) * 1.3
                    )
                    tree.position = SCNVector3(x, GroundKind.grass.surfaceHeight, z)
                    container.addChildNode(tree)
                }
            }
            for row in Swift.stride(from: -ring, through: map.size.rows - 1 + ring, by: step) {
                for column in [-ring, map.size.columns - 1 + ring] {
                    let clampedColumn = min(max(column, 0), map.size.columns - 1)
                    let clampedRow = min(max(row, 0), map.size.rows - 1)
                    guard groundKind(at: GridCoordinate(column: clampedColumn, row: clampedRow)) != .water,
                          seededUnit(column, row, 26) > (ring < 5 ? 0.26 : 0.42) else { continue }
                    let x = bounds.minX + (Float(column) + 0.5) * cell
                        + (seededUnit(column, row, 27) - 0.5) * cell * 1.6
                    let z = bounds.minZ + (Float(row) + 0.5) * cell
                        + (seededUnit(column, row, 28) - 0.5) * cell * 1.6
                    let tree = makeTreeNode(
                        broadleaf: seededUnit(column, row, 29) > 0.42,
                        scale: 1.8 + seededUnit(column, row, 30) * 1.3
                    )
                    tree.position = SCNVector3(x, GroundKind.grass.surfaceHeight, z)
                    container.addChildNode(tree)
                }
            }
        }
        // flattenedClone() proved unreliable for these subtrees (it returned
        // empty geometry), so trees share cached geometries and are added
        // directly; the scene renders on demand, not continuously.
        container.castsShadow = true
        scene.rootNode.addChildNode(container)
    }

    private var treeGeometryCache: [String: SCNGeometry] = [:]

    private func treeGeometry(_ key: String, build: () -> SCNGeometry) -> SCNGeometry {
        if let cached = treeGeometryCache[key] { return cached }
        let geometry = build()
        treeGeometryCache[key] = geometry
        return geometry
    }

    private func makeTreeNode(broadleaf: Bool, scale rawScale: Float) -> SCNNode {
        // Quantized scale keeps the shared-geometry cache tiny while still
        // varying silhouettes across the map.
        let scale = (rawScale * 4).rounded() / 4
        let tree = SCNNode()

        let blobGeometry = treeGeometry("blob-\(scale)") {
            let plane = SCNPlane(width: CGFloat(6.4 * scale), height: CGFloat(6.4 * scale))
            let material = SCNMaterial()
            material.diffuse.contents = CityGroundArt.blobShadowTexture()
            material.lightingModel = .constant
            material.blendMode = .alpha
            material.writesToDepthBuffer = false
            plane.firstMaterial = material
            return plane
        }
        let blob = SCNNode(geometry: blobGeometry)
        blob.eulerAngles.x = -.pi / 2
        blob.position = SCNVector3(0.9 * scale, 0.16, 0.9 * scale)
        tree.addChildNode(blob)

        let trunkGeometry = treeGeometry("trunk-\(scale)") {
            let trunk = SCNCylinder(radius: CGFloat(0.55 * scale), height: CGFloat(2.6 * scale))
            trunk.radialSegmentCount = 6
            trunk.firstMaterial = self.material(color: UIColor(red: 0.42, green: 0.31, blue: 0.22, alpha: 1))
            return trunk
        }
        let trunkNode = SCNNode(geometry: trunkGeometry)
        trunkNode.position.y = 1.3 * scale
        tree.addChildNode(trunkNode)

        if broadleaf {
            let lowerGeometry = treeGeometry("canopyA-\(scale)") {
                let sphere = SCNSphere(radius: CGFloat(2.9 * scale))
                sphere.segmentCount = 10
                sphere.firstMaterial = self.material(color: UIColor(red: 0.24, green: 0.45, blue: 0.22, alpha: 1))
                return sphere
            }
            let lowerNode = SCNNode(geometry: lowerGeometry)
            lowerNode.position.y = 4.3 * scale
            tree.addChildNode(lowerNode)
            let topGeometry = treeGeometry("canopyB-\(scale)") {
                let sphere = SCNSphere(radius: CGFloat(2.0 * scale))
                sphere.segmentCount = 8
                sphere.firstMaterial = self.material(color: UIColor(red: 0.32, green: 0.55, blue: 0.27, alpha: 1))
                return sphere
            }
            let topNode = SCNNode(geometry: topGeometry)
            topNode.position = SCNVector3(0.7 * scale, 6.0 * scale, -0.5 * scale)
            tree.addChildNode(topNode)
        } else {
            let lowerGeometry = treeGeometry("coneA-\(scale)") {
                let cone = SCNCone(
                    topRadius: CGFloat(0.3 * scale),
                    bottomRadius: CGFloat(2.3 * scale),
                    height: CGFloat(3.4 * scale)
                )
                cone.radialSegmentCount = 7
                cone.firstMaterial = self.material(color: UIColor(red: 0.16, green: 0.38, blue: 0.24, alpha: 1))
                return cone
            }
            let lowerNode = SCNNode(geometry: lowerGeometry)
            lowerNode.position.y = 3.6 * scale
            tree.addChildNode(lowerNode)
            let upperGeometry = treeGeometry("coneB-\(scale)") {
                let cone = SCNCone(
                    topRadius: 0.05,
                    bottomRadius: CGFloat(1.6 * scale),
                    height: CGFloat(2.6 * scale)
                )
                cone.radialSegmentCount = 7
                cone.firstMaterial = self.material(color: UIColor(red: 0.16, green: 0.38, blue: 0.24, alpha: 1))
                return cone
            }
            let upperNode = SCNNode(geometry: upperGeometry)
            upperNode.position.y = 5.6 * scale
            tree.addChildNode(upperNode)
        }
        return tree
    }


    private func makeHorizontalGeometry(
        rectangles: [(GridWorldPoint, GridLocalSurfaceRect)],
        height: Float,
        material: SCNMaterial,
        uvScale: Float
    ) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [UInt32] = []
        vertices.reserveCapacity(rectangles.count * 4)
        normals.reserveCapacity(rectangles.count * 4)
        uvs.reserveCapacity(rectangles.count * 4)
        indices.reserveCapacity(rectangles.count * 6)

        for (worldCenter, rect) in rectangles {
            let minX = worldCenter.x + rect.minX
            let maxX = worldCenter.x + rect.maxX
            let minZ = worldCenter.z + rect.minZ
            let maxZ = worldCenter.z + rect.maxZ
            let start = UInt32(vertices.count)
            vertices.append(contentsOf: [
                SCNVector3(minX, height, minZ),
                SCNVector3(maxX, height, minZ),
                SCNVector3(maxX, height, maxZ),
                SCNVector3(minX, height, maxZ)
            ])
            normals.append(contentsOf: Array(repeating: SCNVector3(0, 1, 0), count: 4))
            let scale = CGFloat(uvScale)
            uvs.append(contentsOf: [
                CGPoint(x: CGFloat(minX) * scale, y: CGFloat(minZ) * scale),
                CGPoint(x: CGFloat(maxX) * scale, y: CGFloat(minZ) * scale),
                CGPoint(x: CGFloat(maxX) * scale, y: CGFloat(maxZ) * scale),
                CGPoint(x: CGFloat(minX) * scale, y: CGFloat(maxZ) * scale)
            ])
            indices.append(contentsOf: [start, start + 2, start + 1, start, start + 3, start + 2])
        }
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.firstMaterial = material
        return geometry
    }

    private func buildStaticObjectNodes() {
        for object in map.objects {
            guard let parcel = map.parcel(id: object.parcelID) else { continue }
            let node = makeObjectNode(object, parcel: parcel)
            staticObjectNodes[object.id] = node
            scene.rootNode.addChildNode(node)
        }
    }

    private func makeObjectNode(_ object: GridPlacedObject, parcel: GridParcel) -> SCNNode {
        let objectBounds = map.metrics.worldBounds(of: object.rect, mapSize: map.size)
        let parcelBounds = map.metrics.worldBounds(of: parcel.rect, mapSize: map.size)
        let container = SCNNode()
        container.position = SCNVector3(
            parcelBounds.center.x,
            GridSceneElevation.assetBase,
            parcelBounds.center.z
        )
        container.name = "object:\(object.id)"
        // Selection remains attached to the exact parcel geometry. A sprite is
        // a rectangular card with transparent pixels, so attaching interaction
        // metadata to it would make taps outside the lot appear selectable.

        let definition = CityAssetCatalog.definition(for: object.assetID)
        if object.kind == .building {
            container.addChildNode(assetFactory.makeLotInfill(
                category: definition.category,
                facing: object.facing,
                width: parcelBounds.width,
                depth: parcelBounds.depth
            ))
        }

        let assetNode = assetFactory.makeAsset(
            id: object.assetID,
            facing: object.facing,
            heightHint: object.kind == .parking ? nil : object.height
        )
        // An integer grid rect cannot center an odd-difference footprint
        // exactly. When the object is the parcel's centered placement, close
        // the remaining half cell visually; authored off-center rects keep
        // their exact grid position.
        let centeredPlacement = GridPlacementRules.centeredRect(
            for: object.assetID,
            facing: object.facing,
            in: parcel
        )
        assetNode.position = object.rect == centeredPlacement
            ? SCNVector3Zero
            : SCNVector3(
                objectBounds.center.x - parcelBounds.center.x,
                0,
                objectBounds.center.z - parcelBounds.center.z
            )
        container.addChildNode(assetNode)
        registerAssetLODNodes(for: container)
        return container
    }

    private func buildVacantMarkers() {
        // Every gameplay parcel receives a hidden reusable marker. Runtime
        // state decides which marker is visible, so demolishing a building can
        // reveal true vacant ground without rebuilding the SceneKit scene.
        for parcel in map.parcels where parcel.legacyPlotID != nil {
            let bounds = map.metrics.worldBounds(of: parcel.rect, mapSize: map.size)
            let node = SCNNode()
            node.position = SCNVector3(
                bounds.center.x,
                GridSceneElevation.parcelSurface,
                bounds.center.z
            )
            node.name = "vacant:\(parcel.id)"
            setInteractionMetadata(on: node, parcel: parcel)

            // A prepared construction pad: graded earth, corner posts, a low
            // rope fence and a for-sale board facing the camera.
            let padHeight: Float = 0.20
            let pad = SCNBox(
                width: CGFloat(bounds.width - 6),
                height: CGFloat(padHeight),
                length: CGFloat(bounds.depth - 6),
                chamferRadius: 0.8
            )
            pad.firstMaterial = texturedMaterial(
                named: "vacant-pad",
                image: CityGroundArt.gravelTexture(),
                lighting: .lambert
            )
            let padNode = SCNNode(geometry: pad)
            padNode.position.y = padHeight / 2
            node.addChildNode(padNode)

            let postInsetX = bounds.width / 2 - 4.5
            let postInsetZ = bounds.depth / 2 - 4.5
            let postMaterial = material(color: UIColor(white: 0.94, alpha: 1))
            for (x, z) in [(-postInsetX, -postInsetZ), (postInsetX, -postInsetZ),
                           (-postInsetX, postInsetZ), (postInsetX, postInsetZ)] {
                let post = SCNBox(width: 0.9, height: 3.0, length: 0.9, chamferRadius: 0.16)
                post.firstMaterial = postMaterial
                let postNode = SCNNode(geometry: post)
                postNode.position = SCNVector3(x, padHeight + 1.5, z)
                node.addChildNode(postNode)
            }
            let ropeMaterial = material(color: UIColor(red: 0.93, green: 0.60, blue: 0.20, alpha: 1))
            for (width, depth, x, z) in [
                (postInsetX * 2, Float(0.3), Float(0), -postInsetZ),
                (postInsetX * 2, 0.3, 0, postInsetZ),
                (0.3, postInsetZ * 2, -postInsetX, 0),
                (0.3, postInsetZ * 2, postInsetX, 0)
            ] {
                let rope = SCNBox(width: CGFloat(width), height: 0.3, length: CGFloat(depth), chamferRadius: 0.1)
                rope.firstMaterial = ropeMaterial
                let ropeNode = SCNNode(geometry: rope)
                ropeNode.position = SCNVector3(x, padHeight + 2.6, z)
                node.addChildNode(ropeNode)
            }

            let sign = SCNBox(width: 8.4, height: 5.2, length: 0.5, chamferRadius: 0.2)
            let signMaterial = SCNMaterial()
            signMaterial.diffuse.contents = CityGroundArt.forSaleSignTexture()
            signMaterial.lightingModel = .lambert
            let signEdge = material(color: UIColor(white: 0.93, alpha: 1))
            sign.materials = [signMaterial, signEdge, signMaterial, signEdge, signEdge, signEdge]
            let signNode = SCNNode(geometry: sign)
            signNode.position = SCNVector3(0, padHeight + 3.4, bounds.depth / 2 - 7)
            signNode.eulerAngles.y = -.pi / 4
            node.addChildNode(signNode)

            vacantMarkerNodes[parcel.id] = node
            node.isHidden = true
            scene.rootNode.addChildNode(node)
        }
    }

    private func buildFacilityMarkers() {
        for facility in MapFacility.allCases {
            let coordinate = facilityGridCoordinate(facility)
            let center = map.metrics.worldCenter(of: coordinate, mapSize: map.size)
            let root = SCNNode()
            root.position = SCNVector3(center.x, GridSceneElevation.pavementSurface, center.z)
            root.name = "facility:\(facility.rawValue)"
            interactionFacilities[ObjectIdentifier(root)] = facility

            let plinthGeometry = SCNCylinder(radius: 3.4, height: 0.8)
            plinthGeometry.radialSegmentCount = 14
            plinthGeometry.firstMaterial = material(color: UIColor(white: 0.90, alpha: 1))
            let plinth = SCNNode(geometry: plinthGeometry)
            plinth.position.y = 0.4
            root.addChildNode(plinth)

            let poleGeometry = SCNCylinder(radius: 0.7, height: 12)
            poleGeometry.radialSegmentCount = 8
            poleGeometry.firstMaterial = material(color: UIColor(white: 0.96, alpha: 1))
            let pole = SCNNode(geometry: poleGeometry)
            pole.position.y = 6.4
            root.addChildNode(pole)

            let badgeGeometry = SCNBox(width: 7.6, height: 7.6, length: 7.6, chamferRadius: 1.8)
            let badgeMaterial = material(color: facilityColor(facility))
            badgeMaterial.emission.contents = facilityColor(facility).withAlphaComponent(0.22)
            badgeGeometry.firstMaterial = badgeMaterial
            let badge = SCNNode(geometry: badgeGeometry)
            badge.position.y = 14.5
            root.addChildNode(badge)

            facilityNodes[facility] = root
            scene.rootNode.addChildNode(root)
        }
        updateFacilityVisibility()
    }

    private func buildGridNode() {
        let bounds = map.metrics.worldBounds(of: map.size)
        var vertices: [SCNVector3] = []
        for column in 0...map.size.columns {
            let x = bounds.minX + Float(column) * map.metrics.cellSize
            vertices.append(SCNVector3(x, GridSceneElevation.debugOverlay, bounds.minZ))
            vertices.append(SCNVector3(x, GridSceneElevation.debugOverlay, bounds.maxZ))
        }
        for row in 0...map.size.rows {
            let z = bounds.minZ + Float(row) * map.metrics.cellSize
            vertices.append(SCNVector3(bounds.minX, GridSceneElevation.debugOverlay, z))
            vertices.append(SCNVector3(bounds.maxX, GridSceneElevation.debugOverlay, z))
        }
        let indices = Array(UInt32(0)..<UInt32(vertices.count))
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .line)]
        )
        let gridMaterial = material(color: UIColor(white: 0.08, alpha: 0.30))
        gridMaterial.lightingModel = .constant
        geometry.firstMaterial = gridMaterial
        gridNode.geometry = geometry
        gridNode.name = "debug-grid"
        gridNode.renderingOrder = 20
        gridNode.isHidden = true
        scene.rootNode.addChildNode(gridNode)
    }

    private func buildLighting() {
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        // A restrained cool ambient fill; the warm key light carries the
        // modelling and the soft shadow pass gives the town its depth.
        ambientLight.intensity = 420
        ambientLight.color = UIColor(red: 0.80, green: 0.87, blue: 0.94, alpha: 1)
        let ambient = SCNNode()
        ambient.light = ambientLight
        scene.rootNode.addChildNode(ambient)

        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 1_250
        directionalLight.color = UIColor(red: 1, green: 0.95, blue: 0.83, alpha: 1)
        // Shadow maps under a fixed orthographic camera produced acne on
        // faceted roofs while ground shadows stayed invisible, so depth-map
        // shadows stay off. Grounding comes from baked blob shadows that
        // every building and tree carries, which is also much cheaper.
        directionalLight.castsShadow = false
        let directional = SCNNode()
        directional.light = directionalLight
        let mapCenter = map.metrics.worldBounds(of: map.size).center
        directional.position = SCNVector3(mapCenter.x + 850, 1_150, mapCenter.z + 1_250)
        directional.look(at: SCNVector3(mapCenter.x, 0, mapCenter.z))
        scene.rootNode.addChildNode(directional)
    }

    private func buildCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = baseOrthographicScale
        camera.zNear = 1
        camera.zFar = 5_000
        camera.wantsHDR = false
        camera.wantsExposureAdaptation = false
        cameraNode.camera = camera
        cameraNode.name = "fixed-orthographic-camera"
        scene.rootNode.addChildNode(cameraNode)
        sceneView?.pointOfView = cameraNode
    }

    private func updateStoreNodes(stores: [Store], plotByID: [Int: LandPlot]) {
        let activeIDs = Set(stores.map(\.id))
        for id in Array(runtimeStoreNodes.keys) where !activeIDs.contains(id) {
            if let node = runtimeStoreNodes[id] {
                interactionPlotIDs[ObjectIdentifier(node)] = nil
                unregisterAssetLODNodes(for: node)
                node.removeFromParentNode()
            }
            runtimeStoreNodes[id] = nil
            runtimeStoreSignatures[id] = nil
        }
        for store in stores {
            let parcelSignature = store.plotIDs.sorted().map { plotID in
                "\(plotID):\(plotByID[plotID].map(parcelUseSignature) ?? "missing")"
            }.joined(separator: ",")
            let signature = "\(store.type.rawValue)-\(store.pendingType?.rawValue ?? "none")-\(parcelSignature)"
            if runtimeStoreSignatures[store.id] == signature { continue }
            if let oldNode = runtimeStoreNodes[store.id] {
                interactionPlotIDs[ObjectIdentifier(oldNode)] = nil
                unregisterAssetLODNodes(for: oldNode)
                oldNode.removeFromParentNode()
            }
            let node = makeStoreNode(store: store, plotByID: plotByID)
            runtimeStoreNodes[store.id] = node
            runtimeStoreSignatures[store.id] = signature
            scene.rootNode.addChildNode(node)
            registerAssetLODNodes(for: node)
        }
    }

    private func makeStoreNode(store: Store, plotByID: [Int: LandPlot]) -> SCNNode {
        let root = SCNNode()
        root.name = "player-store:\(store.id.uuidString)"
        for placement in GridStorePlacementAdapter.visualPlacements(for: store, map: map) {
            guard let parcel = map.parcel(id: placement.parcelID) else { continue }
            let parcelBounds = map.metrics.worldBounds(of: parcel.rect, mapSize: map.size)
            let infill = assetFactory.makeLotInfill(
                category: .playerFacility,
                facing: placement.facing,
                width: parcelBounds.width,
                depth: parcelBounds.depth
            )
            infill.position = SCNVector3(
                parcelBounds.center.x,
                GridSceneElevation.assetBase,
                parcelBounds.center.z
            )
            infill.name = "player-store-lot-infill:\(store.id.uuidString):\(placement.plotID)"
            setInteractionMetadata(on: infill, parcel: parcel)
            root.addChildNode(infill)

            let node: SCNNode
            // Store placements are always the parcel's centered rect, and an
            // integer rect cannot center an odd-difference footprint exactly,
            // so the grid-native building sits on the true parcel center.
            if placement.role == .primaryBuilding,
               plotByID[placement.plotID]?.currentUse.isUnderConstruction == true {
                node = makeConstructionSiteNode(
                    width: parcelBounds.width,
                    depth: parcelBounds.depth
                )
            } else {
                node = assetFactory.makeAsset(
                    id: placement.assetID,
                    facing: placement.facing,
                    heightHint: placement.height
                )
            }
            setInteractionMetadata(on: node, parcel: parcel)
            node.position = SCNVector3(
                parcelBounds.center.x,
                GridSceneElevation.assetBase,
                parcelBounds.center.z
            )
            node.name = placement.role == .primaryBuilding
                ? "player-store-building:\(store.id.uuidString)"
                : "player-store-parking:\(store.id.uuidString):\(placement.plotID)"
            root.addChildNode(node)
        }
        return root
    }

    private func parcelUseSignature(_ plot: LandPlot) -> String {
        switch plot.currentUse {
        case .ambientBuilding(let assetID):
            return "ambient:\(assetID.rawValue)"
        case .surfaceParking:
            return "surface-parking"
        case .vacant:
            return "vacant"
        case .construction(let storeID, let assetID):
            return "construction:\(storeID.uuidString):\(assetID.rawValue)"
        case .playerFacility(let storeID, let assetID):
            return "facility:\(storeID.uuidString):\(assetID.rawValue)"
        case .displayParking(let storeID):
            return "display-parking:\(storeID.uuidString)"
        }
    }

    /// A grid-contained construction placeholder. Its foundation and frame
    /// are sized from the authoritative parcel bounds, so it cannot introduce
    /// the baked rotation or lot-edge mismatch of the legacy sprite cards.
    private func makeConstructionSiteNode(width: Float, depth: Float) -> SCNNode {
        let root = SCNNode()
        root.name = "construction-site"

        let usableWidth = max(12, width - 14)
        let usableDepth = max(12, depth - 14)
        let foundationHeight: Float = 0.7
        let frameHeight = min(12, max(7, min(usableWidth, usableDepth) * 0.18))
        let concrete = material(color: UIColor(red: 0.62, green: 0.64, blue: 0.64, alpha: 1))
        let steel = material(color: UIColor(red: 0.93, green: 0.48, blue: 0.12, alpha: 1))
        let timber = material(color: UIColor(red: 0.55, green: 0.34, blue: 0.17, alpha: 1))

        let foundation = SCNBox(
            width: CGFloat(usableWidth),
            height: CGFloat(foundationHeight),
            length: CGFloat(usableDepth),
            chamferRadius: 0.5
        )
        foundation.firstMaterial = concrete
        let foundationNode = SCNNode(geometry: foundation)
        foundationNode.position.y = foundationHeight / 2
        root.addChildNode(foundationNode)

        let columnInsetX = max(3, usableWidth / 2 - 3)
        let columnInsetZ = max(3, usableDepth / 2 - 3)
        for (x, z) in [
            (-columnInsetX, -columnInsetZ), (columnInsetX, -columnInsetZ),
            (-columnInsetX, columnInsetZ), (columnInsetX, columnInsetZ)
        ] {
            let column = SCNBox(width: 1.2, height: CGFloat(frameHeight), length: 1.2, chamferRadius: 0.15)
            column.firstMaterial = steel
            let columnNode = SCNNode(geometry: column)
            columnNode.position = SCNVector3(x, foundationHeight + frameHeight / 2, z)
            root.addChildNode(columnNode)
        }

        for z in [-columnInsetZ, columnInsetZ] {
            let beam = SCNBox(width: CGFloat(usableWidth - 4), height: 1.0, length: 1.0, chamferRadius: 0.12)
            beam.firstMaterial = steel
            let beamNode = SCNNode(geometry: beam)
            beamNode.position = SCNVector3(0, foundationHeight + frameHeight, z)
            root.addChildNode(beamNode)
        }
        for x in [-columnInsetX, columnInsetX] {
            let beam = SCNBox(width: 1.0, height: 1.0, length: CGFloat(usableDepth - 4), chamferRadius: 0.12)
            beam.firstMaterial = steel
            let beamNode = SCNNode(geometry: beam)
            beamNode.position = SCNVector3(x, foundationHeight + frameHeight, 0)
            root.addChildNode(beamNode)
        }

        let materials = SCNBox(width: 8, height: 1.8, length: 4, chamferRadius: 0.25)
        materials.firstMaterial = timber
        let materialsNode = SCNNode(geometry: materials)
        materialsNode.position = SCNVector3(0, foundationHeight + 0.9, usableDepth * 0.27)
        root.addChildNode(materialsNode)
        return root
    }

    private func updateFacilityVisibility() {
        let showsSecondaryFacilities = currentZoomFactor <= (GridCameraZoom.scaleFactors.first ?? 0.22) + 0.02
        for (facility, node) in facilityNodes {
            node.isHidden = !facility.isPrimary && !showsSecondaryFacilities
        }
    }

    private func updateAssetLODVisibility() {
        let visibility = CityAssetLODPolicy.visibility(zoomFactor: currentZoomFactor)
        guard visibility != appliedAssetLODVisibility else { return }
        appliedAssetLODVisibility = visibility
        for nodes in assetLODNodes.values {
            nodes.near.isHidden = !visibility.showsNearDetails
            nodes.props.isHidden = !visibility.showsProps
        }
    }

    private func registerAssetLODNodes(for root: SCNNode) {
        let visibility = CityAssetLODPolicy.visibility(zoomFactor: currentZoomFactor)
        var candidates = [root]
        root.enumerateChildNodes { node, _ in candidates.append(node) }
        for candidate in candidates {
            guard let near = candidate.childNode(
                withName: CityBuildingFactory.nearDetailNodeName,
                recursively: false
            ), let props = candidate.childNode(
                withName: CityBuildingFactory.propDetailNodeName,
                recursively: false
            ) else { continue }
            near.isHidden = !visibility.showsNearDetails
            props.isHidden = !visibility.showsProps
            assetLODNodes[ObjectIdentifier(candidate)] = (near, props)
        }
    }

    private func unregisterAssetLODNodes(for root: SCNNode) {
        assetLODNodes[ObjectIdentifier(root)] = nil
        root.enumerateChildNodes { node, _ in
            self.assetLODNodes[ObjectIdentifier(node)] = nil
        }
    }

    private func facilityGridCoordinate(_ facility: MapFacility) -> GridCoordinate {
        // Facility markers are named anchors in the authored map definition,
        // not renderer-owned coordinates or occupied parcels.
        map.coordinate(for: facility.gridAnchorID)
            ?? GridCoordinate(column: map.size.columns / 2, row: map.size.rows / 2)
    }

    private func facilityColor(_ facility: MapFacility) -> UIColor {
        switch facility {
        case .auction: UIColor(red: 0.34, green: 0.27, blue: 0.72, alpha: 1)
        case .bank: UIColor(red: 0.18, green: 0.45, blue: 0.76, alpha: 1)
        case .realEstate: UIColor(red: 0.24, green: 0.62, blue: 0.34, alpha: 1)
        case .workshop: UIColor(red: 0.43, green: 0.46, blue: 0.48, alpha: 1)
        case .advertising: UIColor(red: 0.91, green: 0.45, blue: 0.16, alpha: 1)
        case .recruiting: UIColor(red: 0.58, green: 0.30, blue: 0.67, alpha: 1)
        case .cityHall: UIColor(red: 0.53, green: 0.36, blue: 0.24, alpha: 1)
        }
    }

    private func applyCamera(animated: Bool) {
        clampFocus()
        let cameraOffset = GridOrthographicCameraSpec.foundation.cameraOffset(
            groundDistance: 900 * sqrt(2)
        )
        let changes = {
            self.cameraNode.camera?.orthographicScale = self.baseOrthographicScale * self.currentZoomFactor
            self.cameraNode.position = SCNVector3(
                self.focusPoint.x + cameraOffset.x,
                cameraOffset.y,
                self.focusPoint.z + cameraOffset.z
            )
            self.cameraNode.look(at: SCNVector3(self.focusPoint.x, 0, self.focusPoint.z))
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.22 : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        changes()
        SCNTransaction.commit()
        sceneView?.setNeedsDisplay()
    }

    private func clampFocus() {
        let bounds = map.cameraContentBounds
        let clamped = GridCameraFocusPolicy.clampedFocus(
            GridWorldPoint(x: focusPoint.x, z: focusPoint.z),
            in: bounds,
            zoomFactor: Float(currentZoomFactor)
        )
        focusPoint.x = clamped.x
        focusPoint.z = clamped.z
        focusPoint.y = 0
    }

    private func setInteractionMetadata(on node: SCNNode, parcel: GridParcel) {
        if let plotID = parcel.legacyPlotID {
            interactionPlotIDs[ObjectIdentifier(node)] = plotID
        }
    }

    private var materialCache: [String: SCNMaterial] = [:]

    private func material(color: UIColor) -> SCNMaterial {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let key = String(format: "color-%.3f-%.3f-%.3f-%.3f", red, green, blue, alpha)
        if let cached = materialCache[key] { return cached }
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.lightingModel = .lambert
        result.isDoubleSided = true
        materialCache[key] = result
        return result
    }

    private func flatMaterial(named name: String, color: UIColor) -> SCNMaterial {
        if let cached = materialCache[name] { return cached }
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.lightingModel = .constant
        materialCache[name] = result
        return result
    }

    private func texturedMaterial(
        named name: String,
        image: UIImage,
        lighting: SCNMaterial.LightingModel
    ) -> SCNMaterial {
        if let cached = materialCache[name] { return cached }
        let result = SCNMaterial()
        result.diffuse.contents = image
        result.diffuse.wrapS = .repeat
        result.diffuse.wrapT = .repeat
        result.diffuse.mipFilter = .linear
        result.lightingModel = lighting
        materialCache[name] = result
        return result
    }

    private func groundMaterial(for kind: GroundKind) -> SCNMaterial {
        switch kind {
        case .grass:
            return texturedMaterial(named: "ground-grass", image: CityGroundArt.grassTexture(), lighting: .lambert)
        case .park:
            return texturedMaterial(named: "ground-park", image: CityGroundArt.parkTexture(), lighting: .lambert)
        case .beach:
            return texturedMaterial(named: "ground-beach", image: CityGroundArt.sandTexture(), lighting: .lambert)
        case .plaza:
            return texturedMaterial(named: "ground-plaza", image: CityGroundArt.plazaTexture(), lighting: .lambert)
        case .water:
            return texturedMaterial(named: "ground-water", image: CityGroundArt.waterTexture(), lighting: .lambert)
        }
    }

    private func baseDistrictColor(_ district: DistrictKind) -> UIColor {
        // Lot aprons stay close to one warm neutral so the buildings, not the
        // ground checkerboard, carry the color of every district.
        switch district {
        case .downtown: UIColor(red: 0.71, green: 0.69, blue: 0.66, alpha: 1)
        case .station: UIColor(red: 0.72, green: 0.71, blue: 0.65, alpha: 1)
        case .emerging: UIColor(red: 0.70, green: 0.72, blue: 0.62, alpha: 1)
        case .suburb: UIColor(red: 0.71, green: 0.72, blue: 0.63, alpha: 1)
        case .industrial: UIColor(red: 0.68, green: 0.68, blue: 0.66, alpha: 1)
        case .highway: UIColor(red: 0.71, green: 0.70, blue: 0.63, alpha: 1)
        }
    }

    private func buildingColor(_ style: GridBuildingStyle) -> UIColor {
        switch style {
        case .generalResidential: UIColor(red: 0.81, green: 0.69, blue: 0.55, alpha: 1)
        case .luxuryResidential: UIColor(red: 0.83, green: 0.82, blue: 0.72, alpha: 1)
        case .commercial: UIColor(red: 0.55, green: 0.68, blue: 0.75, alpha: 1)
        case .industrial: UIColor(red: 0.54, green: 0.56, blue: 0.58, alpha: 1)
        case .downtown: UIColor(red: 0.63, green: 0.60, blue: 0.70, alpha: 1)
        case .roadside: UIColor(red: 0.72, green: 0.58, blue: 0.42, alpha: 1)
        case .parking: UIColor(red: 0.31, green: 0.34, blue: 0.35, alpha: 1)
        }
    }

    private func parcelColor(
        parcel: GridParcel,
        plot: LandPlot?,
        game: GameEngine,
        layer: MapLayer,
        demandCategory: VehicleCategory,
        maximumPrice: Int,
        isSelected: Bool
    ) -> UIColor {
        if isSelected { return UIColor(red: 0.92, green: 0.80, blue: 0.28, alpha: 1) }
        if let plot {
            switch plot.occupant {
            case .player:
                return UIColor(red: 0.15, green: 0.76, blue: 0.70, alpha: 1)
            case .competitor:
                return UIColor(red: 0.91, green: 0.46, blue: 0.22, alpha: 1)
            case .available, .unavailable:
                break
            }
        }
        guard let plot, layer != .normal else { return baseDistrictColor(parcel.district) }
        let value: Double
        switch layer {
        case .normal:
            value = 0.5
        case .demand:
            value = game.demandScore(for: plot) / 1.5
        case .vehicleDemand:
            value = game.vehicleDemand(demandCategory, in: plot.district) / 1.6
        case .price:
            value = Double(plot.price) / Double(maximumPrice)
        case .traffic:
            value = plot.traffic / 1.25
        case .competition:
            value = game.district(for: plot).competition / 1.5
        case .growth:
            value = (game.district(for: plot).growthRate - 0.96) / 0.12
        case .profit:
            value = game.profitabilityScore(for: plot) / 4.0
        }
        return UIColor.heatMap(min(1, max(0, value)))
    }

    private func emissionColor(plot: LandPlot?, game: GameEngine, isSelected: Bool) -> UIColor {
        if isSelected { return UIColor(red: 0.20, green: 0.15, blue: 0.02, alpha: 1) }
        guard let plot,
              game.isTutorialActive,
              game.isFoundingCandidate(plot) else { return .black }
        return UIColor(red: 0.13, green: 0.17, blue: 0.02, alpha: 1)
    }
}

private extension UIColor {
    static func heatMap(_ value: Double) -> UIColor {
        let low = UIColor(red: 0.25, green: 0.55, blue: 0.72, alpha: 1)
        let middle = UIColor(red: 0.44, green: 0.70, blue: 0.45, alpha: 1)
        let high = UIColor(red: 0.91, green: 0.52, blue: 0.22, alpha: 1)
        if value < 0.5 { return interpolate(from: low, to: middle, amount: value * 2) }
        return interpolate(from: middle, to: high, amount: (value - 0.5) * 2)
    }

    static func interpolate(from: UIColor, to: UIColor, amount: Double) -> UIColor {
        var fromRed: CGFloat = 0
        var fromGreen: CGFloat = 0
        var fromBlue: CGFloat = 0
        var fromAlpha: CGFloat = 0
        var toRed: CGFloat = 0
        var toGreen: CGFloat = 0
        var toBlue: CGFloat = 0
        var toAlpha: CGFloat = 0
        from.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
        to.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
        let factor = CGFloat(min(1, max(0, amount)))
        return UIColor(
            red: fromRed + (toRed - fromRed) * factor,
            green: fromGreen + (toGreen - fromGreen) * factor,
            blue: fromBlue + (toBlue - fromBlue) * factor,
            alpha: fromAlpha + (toAlpha - fromAlpha) * factor
        )
    }
}
