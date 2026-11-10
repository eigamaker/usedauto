import SceneKit
import SwiftUI
import UIKit

/// 店舗詳細ページ上部のジオラマ。マップと同じ 3D アセットを近くから眺め、
/// 来店客と持ち込み車両の多さを人と車の動きで伝えます。
struct StoreDioramaView: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: Store

    /// シーンを作り直す必要がある状態だけを抜き出した署名。
    private var signature: String {
        "\(store.type.rawValue)|\(store.openingMonthsRemaining != nil)|\(store.trafficLevel.rawValue)|"
            + "\(min(5, store.buyerArrivalsThisWeek))|\(min(3, store.sellerArrivalsThisWeek))|\(reduceMotion)"
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.50, green: 0.74, blue: 0.30, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.rendersContinuously = true
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        view.accessibilityLabel = "店舗の外観"
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard context.coordinator.signature != signature else { return }
        context.coordinator.signature = signature
        view.scene = StoreDioramaBuilder(
            store: store,
            factory: context.coordinator.factory,
            animated: !reduceMotion
        ).build()
    }

    @MainActor
    final class Coordinator {
        var signature = ""
        let factory = CityBuildingFactory(cellSize: 20)
    }
}

@MainActor
private struct StoreDioramaBuilder {
    let store: Store
    let factory: CityBuildingFactory
    let animated: Bool

    private let scene = SCNScene()
    private let sidewalkWidth: Float = 7
    private let roadWidth: Float = 22

    private var footprint: GridSize { CityAssetCatalog.definition(for: store.type.cityAssetID).footprint }
    private var lotWidth: Float { Float(footprint.width) * 20 }
    private var lotDepth: Float { Float(footprint.depth) * 20 }
    /// 敷地の道路側の端（+z が正面）。
    private var frontEdge: Float { lotDepth / 2 }
    private var roadCenter: Float { frontEdge + sidewalkWidth + roadWidth / 2 }
    private var span: Float { max(lotWidth, 60) * 3.2 }

    func build() -> SCNScene {
        buildGround()
        buildStreet()
        buildStore()
        buildNeighbourhood()
        buildLighting()
        buildCamera()
        buildPassingTraffic()
        buildVisitors()
        buildArrivingCars()
        return scene
    }

    // MARK: - Static set

    private func plane(width: Float, depth: Float, y: Float, image: UIImage, tile: Float) -> SCNNode {
        let geometry = SCNPlane(width: CGFloat(width), height: CGFloat(depth))
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.mipFilter = .linear
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(width / tile, depth / tile, 1)
        material.lightingModel = .lambert
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        node.eulerAngles.x = -.pi / 2
        node.position.y = y
        node.castsShadow = false
        return node
    }

    private func slab(_ width: Float, _ height: Float, _ depth: Float, color: UIColor, at position: SCNVector3) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth), chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .lambert
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        node.position = position
        node.castsShadow = false
        return node
    }

    private func buildGround() {
        scene.rootNode.addChildNode(plane(width: span * 2, depth: span * 2, y: 0, image: CityGroundArt.grassTexture(), tile: 40))
    }

    private func buildStreet() {
        let paint = UIColor(red: 0.97, green: 0.96, blue: 0.90, alpha: 1)
        for side: Float in [-1, 1] {
            let z = roadCenter + side * (roadWidth / 2 + sidewalkWidth / 2)
            let sidewalk = plane(width: span * 2, depth: sidewalkWidth, y: 0.45, image: CityGroundArt.sidewalkTexture(), tile: 10)
            sidewalk.position.z = z
            scene.rootNode.addChildNode(sidewalk)
            // 縁石
            scene.rootNode.addChildNode(slab(
                span * 2, 0.7, 0.7,
                color: UIColor(red: 0.86, green: 0.84, blue: 0.76, alpha: 1),
                at: SCNVector3(0, 0.35, roadCenter + side * (roadWidth / 2 + 0.35))
            ))
            // 路側の白線
            scene.rootNode.addChildNode(slab(span * 2, 0.02, 0.45, color: paint, at: SCNVector3(0, 0.27, roadCenter + side * (roadWidth / 2 - 1.3))))
        }
        let road = plane(width: span * 2, depth: roadWidth, y: 0.25, image: CityGroundArt.asphaltTexture(brightness: 0.40), tile: 20)
        road.position.z = roadCenter
        scene.rootNode.addChildNode(road)
        var x = -span
        while x < span {
            scene.rootNode.addChildNode(slab(5, 0.02, 0.5, color: paint, at: SCNVector3(x, 0.27, roadCenter)))
            x += 10
        }
        // 車両入口：歩道を切り下げ、敷地へ続くスロープを舗装します。
        let drivewayX = lotWidth * 0.30
        scene.rootNode.addChildNode(slab(
            11, 0.06, sidewalkWidth + 0.8,
            color: UIColor(red: 0.42, green: 0.44, blue: 0.48, alpha: 1),
            at: SCNVector3(drivewayX, 0.47, frontEdge + sidewalkWidth / 2)
        ))
        // 街灯と街路樹
        for (index, offset) in [-1.25, -0.72, 0.72, 1.25].enumerated() {
            let x = lotWidth * Float(offset)
            if index.isMultiple(of: 2) {
                addLamp(at: SCNVector3(x, 0.45, frontEdge + sidewalkWidth - 1.6))
            } else {
                addTree(at: SCNVector3(x, 0.45, frontEdge + 2.6), scale: 1.25)
            }
        }
    }

    private func buildStore() {
        let asset = factory.makeAsset(id: store.type.cityAssetID, facing: .south, heightHint: store.type.cityAssetHeight)
        asset.position.y = 0.4
        if store.openingMonthsRemaining != nil {
            // 建設中は半透明の完成予想に、足場の柱とコーンを添えます。
            asset.opacity = 0.42
            let pole = UIColor(red: 0.95, green: 0.62, blue: 0.14, alpha: 1)
            for dx: Float in [-1, 1] {
                for dz: Float in [-1, 1] {
                    scene.rootNode.addChildNode(slab(
                        0.9, 26, 0.9, color: pole,
                        at: SCNVector3(dx * (lotWidth / 2 - 3), 13.4, dz * (lotDepth / 2 - 3))
                    ))
                }
            }
            for dz: Float in [-1, 1] {
                for level: Float in [9, 18, 26] {
                    scene.rootNode.addChildNode(slab(lotWidth - 6, 0.6, 0.6, color: pole, at: SCNVector3(0, level, dz * (lotDepth / 2 - 3))))
                }
            }
        }
        scene.rootNode.addChildNode(asset)
        // 敷地を囲む生垣（正面は開けておきます）。
        let hedge = UIColor(red: 0.22, green: 0.50, blue: 0.20, alpha: 1)
        scene.rootNode.addChildNode(slab(lotWidth + 4, 3.2, 2.4, color: hedge, at: SCNVector3(0, 1.6, -lotDepth / 2 - 1.6)))
        for dx: Float in [-1, 1] {
            scene.rootNode.addChildNode(slab(2.4, 3.2, lotDepth, color: hedge, at: SCNVector3(dx * (lotWidth / 2 + 1.6), 1.6, 0)))
        }
    }

    /// 奥と左右に近隣の建物と木を置き、街の一角であることを伝えます。
    private func buildNeighbourhood() {
        let neighbours: [(CityAssetID, Float, Float)] = [
            (.residentialCottage, -(lotWidth / 2 + 52), -6),
            (.commercialConvenience, lotWidth / 2 + 52, -6),
            (.residentialApartment, -42, -(lotDepth / 2 + 52)),
            (.residentialGable, 44, -(lotDepth / 2 + 52)),
            (.commercialRestaurant, -(lotWidth / 2 + 52), -(lotDepth / 2 + 96)),
            (.residentialTwin, lotWidth / 2 + 60, -(lotDepth / 2 + 96))
        ]
        for (id, x, z) in neighbours {
            let node = factory.makeAsset(id: id, facing: .south)
            node.position = SCNVector3(x, 0.4, z)
            scene.rootNode.addChildNode(node)
        }
        for (x, z, scale) in [
            (-(lotWidth / 2 + 8), -(lotDepth / 2 + 8), Float(1.7)), (lotWidth / 2 + 9, -(lotDepth / 2 + 7), 1.5),
            (-4, -(lotDepth / 2 + 9), 1.9), (lotWidth / 2 + 10, lotDepth / 2 - 6, 1.3),
            (-(lotWidth / 2 + 10), lotDepth / 2 - 8, 1.4)
        ] {
            addTree(at: SCNVector3(x, 0, z), scale: scale)
        }
        // 道路の向かい側
        for index in -3...3 {
            addTree(at: SCNVector3(Float(index) * 34 + 9, 0, roadCenter + roadWidth / 2 + sidewalkWidth + 9), scale: 1.5)
        }
    }

    private func addTree(at position: SCNVector3, scale: Float) {
        let tree = SCNNode()
        let trunk = SCNCylinder(radius: CGFloat(0.5 * scale), height: CGFloat(4 * scale))
        trunk.radialSegmentCount = 8
        trunk.firstMaterial = flat(UIColor(red: 0.42, green: 0.27, blue: 0.15, alpha: 1))
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position.y = 2 * scale
        tree.addChildNode(trunkNode)
        for (radius, y, color) in [
            (Float(3.4), Float(5.6), UIColor(red: 0.20, green: 0.50, blue: 0.20, alpha: 1)),
            (2.6, 8.2, UIColor(red: 0.34, green: 0.64, blue: 0.24, alpha: 1))
        ] {
            let crown = SCNSphere(radius: CGFloat(radius * scale))
            crown.segmentCount = 10
            crown.firstMaterial = flat(color)
            let node = SCNNode(geometry: crown)
            node.position = SCNVector3(radius == 2.6 ? 0.8 * scale : 0, y * scale, 0)
            tree.addChildNode(node)
        }
        tree.position = position
        scene.rootNode.addChildNode(tree)
    }

    private func addLamp(at position: SCNVector3) {
        let lamp = SCNNode()
        let iron = UIColor(red: 0.19, green: 0.28, blue: 0.31, alpha: 1)
        lamp.addChildNode(slab(0.5, 13, 0.5, color: iron, at: SCNVector3(0, 6.5, 0)))
        lamp.addChildNode(slab(0.6, 0.5, 3.4, color: iron, at: SCNVector3(0, 12.8, 1.5)))
        lamp.addChildNode(slab(1.2, 0.3, 1.6, color: UIColor(red: 1, green: 0.90, blue: 0.58, alpha: 1), at: SCNVector3(0, 12.45, 2.6)))
        lamp.position = position
        scene.rootNode.addChildNode(lamp)
    }

    private func flat(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .lambert
        return material
    }

    // MARK: - Light and camera

    private func buildLighting() {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 420
        ambient.color = UIColor(red: 0.76, green: 0.85, blue: 0.95, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1_050
        sun.color = UIColor(red: 1, green: 0.94, blue: 0.82, alpha: 1)
        sun.castsShadow = true
        sun.shadowMode = .forward
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.maximumShadowDistance = 1_200
        sun.shadowSampleCount = 8
        sun.shadowRadius = 3
        sun.shadowBias = 2
        sun.forcesBackFaceCasters = true
        sun.shadowColor = UIColor(red: 0.10, green: 0.16, blue: 0.30, alpha: 0.42)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.position = SCNVector3(-260, 330, 210)
        sunNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(sunNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 170
        fill.color = UIColor(red: 0.54, green: 0.73, blue: 1, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(240, 180, -260)
        fillNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(fillNode)
    }

    private func buildCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(max(lotWidth, lotDepth) * 0.50 + 19)
        camera.zNear = 1
        camera.zFar = 2_000
        camera.screenSpaceAmbientOcclusionIntensity = 0.6
        camera.screenSpaceAmbientOcclusionRadius = 4
        let node = SCNNode()
        node.camera = camera
        let azimuth: Float = 0.52
        let elevation: Float = 0.50
        let distance: Float = 600
        let target = SCNVector3(lotWidth * 0.04, 11, lotDepth * 0.16)
        node.position = SCNVector3(
            target.x + distance * sin(azimuth) * cos(elevation),
            target.y + distance * sin(elevation),
            target.z + distance * cos(azimuth) * cos(elevation)
        )
        node.look(at: target)
        scene.rootNode.addChildNode(node)
    }

    // MARK: - Life

    /// 表通りを行き交う車。通行量は客足に合わせて増えます。
    private func buildPassingTraffic() {
        let count = 2 + store.trafficLevel.rawValue
        for index in 0..<count {
            let eastbound = index.isMultiple(of: 2)
            let car = factory.makeStreetVehicle(variant: index * 3 + 1)
            // 左側通行：+x 方向は手前（-z）側の車線。
            let z = roadCenter + (eastbound ? -1 : 1) * roadWidth * 0.24
            let from = SCNVector3(eastbound ? -span : span, 0.25, z)
            let to = SCNVector3(eastbound ? span : -span, 0.25, z)
            car.eulerAngles.y = eastbound ? 0 : .pi
            let t = Float((index * 37) % 100) / 100
            car.position = SCNVector3(from.x + (to.x - from.x) * t, 0.25, z)
            scene.rootNode.addChildNode(car)
            guard animated else { continue }
            let lap = TimeInterval(span * 2 / (20 + Float(index % 3) * 4))
            car.runAction(.sequence([
                .move(to: to, duration: lap * TimeInterval(1 - t)),
                .repeatForever(.sequence([.move(to: from, duration: 0), .move(to: to, duration: lap)]))
            ]))
        }
    }

    private func makePerson(_ index: Int) -> SCNNode {
        let shirts: [UIColor] = [
            UIColor(red: 0.96, green: 0.48, blue: 0.14, alpha: 1), UIColor(red: 0.20, green: 0.52, blue: 0.86, alpha: 1),
            UIColor(red: 0.90, green: 0.26, blue: 0.30, alpha: 1), UIColor(red: 0.98, green: 0.80, blue: 0.22, alpha: 1),
            UIColor(red: 0.42, green: 0.74, blue: 0.36, alpha: 1)
        ]
        let person = SCNNode()
        let legs = SCNCapsule(capRadius: 0.75, height: 2.6)
        legs.firstMaterial = flat(UIColor(red: 0.16, green: 0.22, blue: 0.36, alpha: 1))
        let legsNode = SCNNode(geometry: legs)
        legsNode.position.y = 1.3
        person.addChildNode(legsNode)
        let body = SCNCapsule(capRadius: 1.0, height: 3.0)
        body.firstMaterial = flat(shirts[index % shirts.count])
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position.y = 3.5
        person.addChildNode(bodyNode)
        let head = SCNSphere(radius: 0.95)
        head.segmentCount = 10
        head.firstMaterial = flat(UIColor(red: 0.98, green: 0.82, blue: 0.68, alpha: 1))
        let headNode = SCNNode(geometry: head)
        headNode.position.y = 5.7
        person.addChildNode(headNode)
        if animated {
            bodyNode.runAction(.repeatForever(.sequence([
                .moveBy(x: 0, y: 0.35, z: 0, duration: 0.22), .moveBy(x: 0, y: -0.35, z: 0, duration: 0.22)
            ])))
            headNode.runAction(.repeatForever(.sequence([
                .moveBy(x: 0, y: 0.35, z: 0, duration: 0.22), .moveBy(x: 0, y: -0.35, z: 0, duration: 0.22)
            ])))
        }
        return person
    }

    /// 歩いて来店する販売客。歩道から敷地へ入っていきます。
    private func buildVisitors() {
        guard store.openingMonthsRemaining == nil else { return }
        let count = min(5, store.buyerArrivalsThisWeek)
        guard count > 0 else { return }
        let walkwayZ = frontEdge + sidewalkWidth / 2
        let entranceX = -lotWidth * 0.12
        for index in 0..<count {
            let person = makePerson(index)
            let fromRight = index.isMultiple(of: 2)
            let start = SCNVector3((fromRight ? 1 : -1) * (lotWidth * 0.9 + 20), 0.45, walkwayZ + (fromRight ? 1.2 : -1.2))
            let corner = SCNVector3(entranceX + Float(index % 3) * 2.4, 0.45, start.z)
            let door = SCNVector3(corner.x, 0.9, frontEdge - 9)
            person.position = start
            scene.rootNode.addChildNode(person)
            guard animated else {
                person.position = corner
                continue
            }
            let walk = TimeInterval(abs(corner.x - start.x) / 7)
            person.opacity = 0
            person.runAction(.sequence([
                .wait(duration: TimeInterval(index) * 2.3),
                .repeatForever(.sequence([
                    .move(to: start, duration: 0),
                    .fadeIn(duration: 0.3),
                    .move(to: corner, duration: walk),
                    .move(to: door, duration: 1.6),
                    .fadeOut(duration: 0.4),
                    .wait(duration: 2.5 + Double(5 - count))
                ]))
            ]))
        }
    }

    /// 買取の持ち込み車両。表通りから車両入口へ曲がって入ります。
    private func buildArrivingCars() {
        guard animated, store.openingMonthsRemaining == nil else { return }
        let count = min(3, store.sellerArrivalsThisWeek)
        guard count > 0 else { return }
        let drivewayX = lotWidth * 0.30
        let laneZ = roadCenter - roadWidth * 0.24
        for index in 0..<count {
            let car = factory.makeStreetVehicle(variant: index * 2)
            let start = SCNVector3(-span, 0.25, laneZ)
            let turn = SCNVector3(drivewayX - 6, 0.25, laneZ)
            let inside = SCNVector3(drivewayX, 0.5, frontEdge - 4)
            car.position = start
            car.opacity = 0
            scene.rootNode.addChildNode(car)
            car.runAction(.sequence([
                .wait(duration: 1.5 + TimeInterval(index) * 4.2),
                .repeatForever(.sequence([
                    .group([.move(to: start, duration: 0), .rotateTo(x: 0, y: 0, z: 0, duration: 0)]),
                    .fadeIn(duration: 0.2),
                    .move(to: turn, duration: TimeInterval((turn.x - start.x) / 22)),
                    .group([
                        .move(to: inside, duration: 1.5),
                        .rotateTo(x: 0, y: .pi / 2, z: 0, duration: 0.9, usesShortestUnitArc: true)
                    ]),
                    .fadeOut(duration: 0.5),
                    .wait(duration: 4 + Double(3 - count) * 2)
                ]))
            ]))
        }
    }
}
