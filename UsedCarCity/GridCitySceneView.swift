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
                    Label("正投影 · 45°固定 · \(GridCameraZoom.percentage(for: zoomStep))%", systemImage: "cube.transparent")
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
        .accessibilityLabel("正投影で斜め上から見た翠浜市のグリッド3Dマップ")
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
        Int((1 / scaleFactors[clamped(step)] * 100).rounded())
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

enum CityBuildingRenderMode: Equatable, Sendable {
    case gridNative3D
    case legacyIso25DSprites

    static let legacySpriteArgument = "-legacy-iso25d-sprites"

    static func selected(arguments: [String] = CommandLine.arguments) -> CityBuildingRenderMode {
        arguments.contains(legacySpriteArgument) ? .legacyIso25DSprites : .gridNative3D
    }
}

/// Builds camera-facing legacy cards from the same world-space grid rectangles
/// used by placement and collision. New city rendering defaults to grid-native
/// 3D geometry because the old artwork includes a baked lot plate whose angle
/// cannot be corrected by scale and anchor calibration alone. This factory is
/// retained behind `-legacy-iso25d-sprites` for visual comparisons only.
@MainActor
final class Iso25DCitySpriteFactory {
    static let spriteNodeName = "iso25d-sprite"

    private var materials: [String: SCNMaterial] = [:]

    func makeSprite(
        assetID: CityAssetID,
        facing: CardinalDirection,
        worldWidth: Float,
        worldDepth: Float,
        renderingOrder: Int
    ) -> SCNNode? {
        guard worldWidth > 0,
              worldDepth > 0,
              let definition = Iso25DCityAssetCatalog.definition(for: assetID, facing: facing),
              UIImage(named: definition.imageName) != nil else { return nil }

        let projectedFootprintWidth = (worldWidth + worldDepth) / sqrt(2)
        let planeWidth = projectedFootprintWidth / definition.projectedFootprintWidthFraction
        let planeHeight = planeWidth / definition.aspectRatio
        let plane = SCNPlane(width: CGFloat(planeWidth), height: CGFloat(planeHeight))
        plane.widthSegmentCount = 1
        plane.heightSegmentCount = 1
        plane.firstMaterial = material(for: definition.imageName)

        let node = SCNNode(geometry: plane)
        node.name = Self.spriteNodeName
        node.pivot = SCNMatrix4MakeTranslation(
            (definition.groundAnchorX - 0.5) * planeWidth,
            (0.5 - definition.groundAnchorY) * planeHeight,
            0
        )
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]
        node.renderingOrder = renderingOrder
        node.castsShadow = false
        return node
    }

    func cachedMaterial(for imageName: String) -> SCNMaterial? {
        materials[imageName]
    }

    private func material(for imageName: String) -> SCNMaterial {
        if let cached = materials[imageName] { return cached }
        let result = SCNMaterial()
        result.name = "iso25d-material:\(imageName)"
        result.diffuse.contents = UIImage(named: imageName)
        result.diffuse.magnificationFilter = .linear
        result.diffuse.minificationFilter = .linear
        result.diffuse.mipFilter = .linear
        result.lightingModel = .constant
        result.blendMode = .alpha
        result.transparencyMode = .dualLayer
        result.writesToDepthBuffer = false
        result.readsFromDepthBuffer = false
        result.isDoubleSided = true
        result.fresnelExponent = 0
        materials[imageName] = result
        return result
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
    private let buildingRenderMode: CityBuildingRenderMode
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
    private lazy var assetFactory = LowPolyCityAssetFactory(cellSize: map.metrics.cellSize)
    private lazy var spriteFactory = Iso25DCitySpriteFactory()

    var zoomFactor: CGFloat { currentZoomFactor }

    init(
        map: GridCityMap,
        sceneView: SCNView,
        buildingRenderMode: CityBuildingRenderMode = .selected()
    ) {
        self.map = map
        self.buildingRenderMode = buildingRenderMode
        self.sceneView = sceneView
        configureView(sceneView)
        buildScene()
        updateLayout(viewSize: sceneView.bounds.size)
        applyCamera(animated: false)
    }

    func updateLayout(viewSize: CGSize) {
        guard viewSize.width > 0, viewSize.height > 0, viewSize != lastViewSize else { return }
        lastViewSize = viewSize
        let mapBounds = map.metrics.worldBounds(of: map.size)
        let projectedWidth = CGFloat(mapBounds.width + mapBounds.depth) / sqrt(2)
        let projectedHeight = CGFloat(mapBounds.width + mapBounds.depth) * 0.58 / sqrt(2)
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
            max(GridCameraZoom.scaleFactors.last ?? 0.22, factor)
        )
        updateFacilityVisibility()
        updateAssetLODVisibility()
        applyCamera(animated: false)
    }

    func resetCamera(animated: Bool) {
        focusPoint = SCNVector3Zero
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
        view.backgroundColor = UIColor(red: 0.70, green: 0.88, blue: 0.93, alpha: 1)
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 30
        view.rendersContinuously = false
        view.isJitteringEnabled = false
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.accessibilityLabel = "翠浜市グリッドマップ"
    }

    private func buildScene() {
        scene.rootNode.addChildNode(makeGroundNode())
        buildParcelNodes()
        scene.rootNode.addChildNode(makeRoadNode(isSidewalk: true))
        scene.rootNode.addChildNode(makeRoadNode(isSidewalk: false))
        scene.rootNode.addChildNode(makeRoadMarkingNode())
        buildStaticObjectNodes()
        buildVacantMarkers()
        buildFacilityMarkers()
        buildGridNode()
        buildLighting()
        buildCamera()
        updateAssetLODVisibility()
    }

    private func makeGroundNode() -> SCNNode {
        let bounds = map.metrics.worldBounds(of: map.size)
        let geometry = SCNBox(
            width: CGFloat(bounds.width),
            height: 2,
            length: CGFloat(bounds.depth),
            chamferRadius: 0
        )
        geometry.firstMaterial = material(color: UIColor(red: 0.31, green: 0.58, blue: 0.34, alpha: 1))
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(bounds.center.x, -1, bounds.center.z)
        node.name = "map-ground"
        return node
    }

    private func buildParcelNodes() {
        for parcel in map.parcels {
            let bounds = map.metrics.worldBounds(of: parcel.rect, mapSize: map.size)
            let geometry = SCNBox(
                width: CGFloat(bounds.width),
                height: 0.40,
                length: CGFloat(bounds.depth),
                chamferRadius: 1.1
            )
            geometry.firstMaterial = material(color: baseDistrictColor(parcel.district))
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(bounds.center.x, 0.20, bounds.center.z)
            node.name = "parcel:\(parcel.id)"
            setInteractionMetadata(on: node, parcel: parcel)
            parcelNodes[parcel.id] = node
            scene.rootNode.addChildNode(node)
        }
    }

    private func makeRoadNode(isSidewalk: Bool) -> SCNNode {
        var rectangles: [(GridWorldPoint, GridLocalSurfaceRect)] = []
        for road in map.roads.values.sorted(by: { $0.coordinate < $1.coordinate }) {
            let center = map.metrics.worldCenter(of: road.coordinate, mapSize: map.size)
            for piece in GridRoadSurfaceLayout.pieces(
                for: road,
                in: map.roads,
                cellSize: map.metrics.cellSize,
                isSidewalk: isSidewalk
            ) {
                rectangles.append((center, piece))
            }
        }
        let color = isSidewalk
            ? UIColor(red: 0.76, green: 0.73, blue: 0.64, alpha: 1)
            : UIColor(red: 0.26, green: 0.30, blue: 0.32, alpha: 1)
        let geometry = makeHorizontalGeometry(
            rectangles: rectangles,
            height: isSidewalk ? GridSceneElevation.sidewalkSurface : GridSceneElevation.pavementSurface,
            color: color
        )
        let node = SCNNode(geometry: geometry)
        node.name = isSidewalk ? "road-sidewalks" : "road-pavement"
        return node
    }

    private func makeRoadMarkingNode() -> SCNNode {
        var rectangles: [(GridWorldPoint, GridLocalSurfaceRect)] = []
        let arterialCellsByRow = Dictionary(grouping: map.roads.values.filter {
            $0.roadClass == .arterial
        }, by: { $0.coordinate.row })
        let horizontalBandRows = Set(arterialCellsByRow.compactMap { row, cells in
            cells.count > map.size.columns / 2 ? row : nil
        })
        for road in map.roads.values where road.roadClass == .arterial {
            let center = map.metrics.worldCenter(of: road.coordinate, mapSize: map.size)
            let isHorizontalBand = horizontalBandRows.contains(road.coordinate.row)
            if !isHorizontalBand,
               (road.connections.contains(.north) || road.connections.contains(.south)) {
                rectangles.append((
                    center,
                    GridLocalSurfaceRect(
                        centerX: 0,
                        centerZ: 0,
                        width: 0.42,
                        depth: map.metrics.cellSize * 0.48
                    )
                ))
            }
            if isHorizontalBand,
               (road.connections.contains(.east) || road.connections.contains(.west)) {
                rectangles.append((
                    center,
                    GridLocalSurfaceRect(
                        centerX: 0,
                        centerZ: 0,
                        width: map.metrics.cellSize * 0.48,
                        depth: 0.42
                    )
                ))
            }
        }
        let geometry = makeHorizontalGeometry(
            rectangles: rectangles,
            height: GridSceneElevation.pavementSurface + 0.015,
            color: UIColor(red: 0.91, green: 0.77, blue: 0.38, alpha: 0.92)
        )
        let node = SCNNode(geometry: geometry)
        node.name = "arterial-lane-markings"
        return node
    }

    private func makeHorizontalGeometry(
        rectangles: [(GridWorldPoint, GridLocalSurfaceRect)],
        height: Float,
        color: UIColor
    ) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt32] = []
        vertices.reserveCapacity(rectangles.count * 4)
        normals.reserveCapacity(rectangles.count * 4)
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
            indices.append(contentsOf: [start, start + 2, start + 1, start, start + 3, start + 2])
        }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.firstMaterial = material(color: color)
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
        // Legacy cards include their own photographed/generated ground plate.
        // They are available only for before/after comparison; the default 3D
        // path below composes an engine-owned lot surface and building geometry.
        if buildingRenderMode == .legacyIso25DSprites,
           object.kind == .building,
           let spriteNode = spriteFactory.makeSprite(
            assetID: object.assetID,
            facing: object.facing,
            worldWidth: parcelBounds.width,
            worldDepth: parcelBounds.depth,
            renderingOrder: spriteRenderingOrder(worldCenter: parcelBounds.center)
           ) {
            container.addChildNode(spriteNode)
            return container
        }

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

            // A purchasable parcel is an intentionally prepared construction
            // pad, not a bright lawn.  Its muted earth base keeps it readable
            // without competing with the town's completed buildings.
            let padHeight: Float = 0.22
            let pad = SCNBox(
                width: CGFloat(bounds.width - 5),
                height: CGFloat(padHeight),
                length: CGFloat(bounds.depth - 5),
                chamferRadius: 1.2
            )
            pad.firstMaterial = material(color: UIColor(red: 0.72, green: 0.63, blue: 0.45, alpha: 1))
            let padNode = SCNNode(geometry: pad)
            padNode.position.y = padHeight / 2
            node.addChildNode(padNode)

            let foundation = SCNBox(width: 22, height: 0.10, length: 22, chamferRadius: 0.8)
            foundation.firstMaterial = material(color: UIColor(red: 0.87, green: 0.82, blue: 0.66, alpha: 1))
            let foundationNode = SCNNode(geometry: foundation)
            foundationNode.position.y = padHeight + 0.05
            node.addChildNode(foundationNode)

            for (x, z) in [(-29 as Float, -29 as Float), (29, -29), (-29, 29), (29, 29)] {
                let stake = SCNBox(width: 1.4, height: 2.8, length: 1.4, chamferRadius: 0.2)
                stake.firstMaterial = material(color: UIColor(red: 0.94, green: 0.46, blue: 0.16, alpha: 1))
                let stakeNode = SCNNode(geometry: stake)
                stakeNode.position = SCNVector3(x, padHeight + 1.4, z)
                node.addChildNode(stakeNode)
            }
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

            let poleGeometry = SCNCylinder(radius: 1.1, height: 13)
            poleGeometry.radialSegmentCount = 8
            poleGeometry.firstMaterial = material(color: UIColor(white: 0.92, alpha: 1))
            let pole = SCNNode(geometry: poleGeometry)
            pole.position.y = 6.5
            root.addChildNode(pole)

            let badgeGeometry = SCNBox(width: 8, height: 8, length: 8, chamferRadius: 1.2)
            let badgeMaterial = material(color: facilityColor(facility))
            badgeMaterial.emission.contents = facilityColor(facility).withAlphaComponent(0.15)
            badgeGeometry.firstMaterial = badgeMaterial
            let badge = SCNNode(geometry: badgeGeometry)
            badge.position.y = 15
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
        // A restrained ambient fill keeps the town clean on mobile while
        // leaving enough directional contrast for roof pitches, canopies and
        // loading bays to read as shapes instead of coloured boxes.
        ambientLight.intensity = 300
        ambientLight.color = UIColor(red: 0.78, green: 0.85, blue: 0.91, alpha: 1)
        let ambient = SCNNode()
        ambient.light = ambientLight
        scene.rootNode.addChildNode(ambient)

        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 1_400
        directionalLight.color = UIColor(red: 1, green: 0.93, blue: 0.78, alpha: 1)
        directionalLight.castsShadow = false
        let directional = SCNNode()
        directional.light = directionalLight
        directional.eulerAngles = SCNVector3(-1.05, -0.75, 0)
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
            // so both the grid-native building and the legacy comparison card
            // sit on the true parcel center.
            if placement.role == .primaryBuilding,
               plotByID[placement.plotID]?.currentUse.isUnderConstruction == true {
                node = makeConstructionSiteNode(
                    width: parcelBounds.width,
                    depth: parcelBounds.depth
                )
            } else if buildingRenderMode == .legacyIso25DSprites,
               placement.role == .primaryBuilding,
               let sprite = spriteFactory.makeSprite(
                assetID: placement.assetID,
                facing: placement.facing,
                worldWidth: parcelBounds.width,
                worldDepth: parcelBounds.depth,
                renderingOrder: spriteRenderingOrder(worldCenter: parcelBounds.center)
               ) {
                node = sprite
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

    private func spriteRenderingOrder(worldCenter: GridWorldPoint) -> Int {
        // The fixed camera sits on +X/+Z. Draw farther cards first, then nearer
        // cards, while keeping the value stable at every pan and zoom level.
        10_000 + Int(((worldCenter.x + worldCenter.z) / map.metrics.cellSize * 8).rounded())
    }

    private func updateFacilityVisibility() {
        let showsSecondaryFacilities = currentZoomFactor <= GridCameraZoom.scaleFactors[2] + 0.02
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
                withName: LowPolyCityAssetFactory.nearDetailNodeName,
                recursively: false
            ), let props = candidate.childNode(
                withName: LowPolyCityAssetFactory.propDetailNodeName,
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
        let bounds = map.metrics.worldBounds(of: map.size)
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

    private func material(color: UIColor) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.lightingModel = .lambert
        result.isDoubleSided = true
        return result
    }

    private func baseDistrictColor(_ district: DistrictKind) -> UIColor {
        switch district {
        case .downtown: UIColor(red: 0.70, green: 0.67, blue: 0.64, alpha: 1)
        case .station: UIColor(red: 0.61, green: 0.72, blue: 0.55, alpha: 1)
        case .emerging: UIColor(red: 0.47, green: 0.76, blue: 0.43, alpha: 1)
        case .suburb: UIColor(red: 0.53, green: 0.78, blue: 0.46, alpha: 1)
        case .industrial: UIColor(red: 0.61, green: 0.64, blue: 0.60, alpha: 1)
        case .highway: UIColor(red: 0.67, green: 0.66, blue: 0.46, alpha: 1)
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
