import SwiftUI

/// 案内役「浜岡ナオ」の似顔絵。画像アセットを持たず、表情だけを差し替えられるよう
/// SwiftUI のシェイプで組み立てています。
struct GuideAvatarView: View {
    var expression: GuideExpression = .smile
    var size: CGFloat = 44
    /// 背景の丸を描くかどうか。ふきだしの中など、地の色に馴染ませたいときは false。
    var showsBackground = true

    private var skin: Color { Color(red: 0.99, green: 0.85, blue: 0.75) }
    private var skinShade: Color { Color(red: 0.93, green: 0.75, blue: 0.65) }
    private var hair: Color { Color(red: 0.17, green: 0.14, blue: 0.16) }
    private var line: Color { Color(red: 0.14, green: 0.12, blue: 0.14) }

    var body: some View {
        ZStack {
            if showsBackground {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [GameTheme.mint, GameTheme.teal],
                            center: .topLeading,
                            startRadius: size * 0.06,
                            endRadius: size * 1.05
                        )
                    )
            }
            body(size: size)
            head(size: size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if showsBackground {
                Circle().stroke(.white.opacity(0.85), lineWidth: max(1, size * 0.035))
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 体（スーツ）

    private func body(size s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.24, style: .continuous)
                .fill(GameTheme.navy)
                .frame(width: s * 0.86, height: s * 0.42)
                .offset(y: s * 0.38)
            Capsule()
                .fill(skinShade)
                .frame(width: s * 0.15, height: s * 0.14)
                .offset(y: s * 0.20)
            collar(size: s, mirrored: false)
            collar(size: s, mirrored: true)
            Triangle()
                .fill(GameTheme.orange)
                .frame(width: s * 0.11, height: s * 0.17)
                .offset(y: s * 0.32)
        }
    }

    private func collar(size s: CGFloat, mirrored: Bool) -> some View {
        RoundedRectangle(cornerRadius: s * 0.03, style: .continuous)
            .fill(.white)
            .frame(width: s * 0.13, height: s * 0.20)
            .rotationEffect(.degrees(mirrored ? -20 : 20))
            .offset(x: (mirrored ? 1 : -1) * s * 0.10, y: s * 0.29)
    }

    // MARK: - 顔

    private func head(size s: CGFloat) -> some View {
        ZStack {
            // 後ろ髪
            Ellipse()
                .fill(hair)
                .frame(width: s * 0.50, height: s * 0.52)
                .offset(y: -s * 0.09)
            // 耳
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(skinShade)
                    .frame(width: s * 0.07, height: s * 0.10)
                    .offset(x: side * s * 0.22, y: -s * 0.02)
            }
            // 顔
            Ellipse()
                .fill(skin)
                .frame(width: s * 0.42, height: s * 0.48)
                .offset(y: -s * 0.04)
            // 前髪
            Ellipse()
                .fill(hair)
                .frame(width: s * 0.44, height: s * 0.24)
                .offset(y: -s * 0.20)
            Capsule()
                .fill(hair)
                .frame(width: s * 0.26, height: s * 0.11)
                .rotationEffect(.degrees(-14))
                .offset(x: s * 0.06, y: -s * 0.15)
            brows(size: s)
            eyes(size: s)
            mouth(size: s)
            if expression == .cheer {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Ellipse()
                        .fill(GameTheme.orange.opacity(0.30))
                        .frame(width: s * 0.09, height: s * 0.05)
                        .offset(x: side * s * 0.15, y: s * 0.02)
                }
            }
        }
    }

    private func brows(size s: CGFloat) -> some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            Capsule()
                .fill(hair)
                .frame(width: s * 0.10, height: s * 0.025)
                .rotationEffect(.degrees(browAngle(side: side)))
                .offset(x: side * s * 0.10, y: -s * 0.11 - browLift(side: side) * s)
        }
    }

    private func browAngle(side: Double) -> Double {
        switch expression {
        case .alert: side * -10
        case .think: side > 0 ? -14 : 4
        case .point: side > 0 ? -12 : 0
        default: side * -4
        }
    }

    private func browLift(side: Double) -> CGFloat {
        switch expression {
        case .alert: 0.02
        case .point where side > 0: 0.018
        case .think where side > 0: 0.015
        default: 0
        }
    }

    @ViewBuilder private func eyes(size s: CGFloat) -> some View {
        let eyeY = -s * 0.04
        switch expression {
        case .cheer, .smile:
            ForEach([-1.0, 1.0], id: \.self) { side in
                ArcStroke(bulge: -1)
                    .stroke(line, style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round))
                    .frame(width: s * 0.09, height: s * 0.05)
                    .offset(x: side * s * 0.10, y: eyeY)
            }
        case .alert:
            ForEach([-1.0, 1.0], id: \.self) { side in
                Circle()
                    .fill(line)
                    .frame(width: s * 0.065, height: s * 0.065)
                    .offset(x: side * s * 0.10, y: eyeY)
            }
        case .think:
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(line)
                    .frame(width: s * 0.055, height: side > 0 ? s * 0.028 : s * 0.062)
                    .offset(x: side * s * 0.10, y: eyeY)
            }
        case .neutral, .point:
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(line)
                    .frame(width: s * 0.052, height: s * 0.068)
                    .offset(x: side * s * 0.10, y: eyeY)
            }
        }
    }

    @ViewBuilder private func mouth(size s: CGFloat) -> some View {
        let mouthY = s * 0.075
        switch expression {
        case .cheer:
            ArcStroke(bulge: 1)
                .stroke(line, style: StrokeStyle(lineWidth: s * 0.032, lineCap: .round))
                .frame(width: s * 0.15, height: s * 0.075)
                .offset(y: mouthY)
        case .smile, .point:
            ArcStroke(bulge: 1)
                .stroke(line, style: StrokeStyle(lineWidth: s * 0.028, lineCap: .round))
                .frame(width: s * 0.11, height: s * 0.05)
                .offset(y: mouthY)
        case .alert:
            Ellipse()
                .fill(line)
                .frame(width: s * 0.075, height: s * 0.065)
                .offset(y: mouthY)
        case .think:
            Capsule()
                .fill(line)
                .frame(width: s * 0.06, height: s * 0.024)
                .offset(x: s * 0.045, y: mouthY)
        case .neutral:
            Capsule()
                .fill(line)
                .frame(width: s * 0.09, height: s * 0.024)
                .offset(y: mouthY)
        }
    }
}

/// 顧客・店員・店長に使う、ゲーム内共通の人物アバター。
/// モデルには画像情報を保存せず、人物のIDや名前から同じ見た目を再現します。
struct CharacterAvatarView: View {
    let role: CharacterAvatarRole
    let seed: Int
    var size: CGFloat = 46

    private var variant: Int { positiveSeed % 4 }
    private var positiveSeed: Int { seed == .min ? 0 : abs(seed) }
    private var skin: Color { Self.skinColors[positiveSeed % Self.skinColors.count] }
    private var skinShade: Color { Self.skinShadeColors[positiveSeed % Self.skinShadeColors.count] }
    private var hair: Color { Self.hairColors[(positiveSeed / 3) % Self.hairColors.count] }
    private var line: Color { Color(red: 0.15, green: 0.13, blue: 0.14) }

    private static let skinColors: [Color] = [
        Color(red: 1.00, green: 0.86, blue: 0.75),
        Color(red: 0.96, green: 0.78, blue: 0.65),
        Color(red: 0.88, green: 0.68, blue: 0.54),
        Color(red: 0.73, green: 0.52, blue: 0.39)
    ]
    private static let skinShadeColors: [Color] = [
        Color(red: 0.93, green: 0.75, blue: 0.64),
        Color(red: 0.88, green: 0.66, blue: 0.54),
        Color(red: 0.78, green: 0.56, blue: 0.43),
        Color(red: 0.61, green: 0.41, blue: 0.30)
    ]
    private static let hairColors: [Color] = [
        Color(red: 0.13, green: 0.11, blue: 0.12),
        Color(red: 0.25, green: 0.16, blue: 0.11),
        Color(red: 0.40, green: 0.27, blue: 0.17),
        Color(red: 0.18, green: 0.20, blue: 0.24)
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: role.backgroundColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            torso
            head
            roleBadge
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: max(1, size * 0.035)))
        .shadow(color: role.accent.opacity(0.16), radius: size * 0.07, y: size * 0.025)
        .accessibilityHidden(true)
    }

    private var torso: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.20, style: .continuous)
                .fill(role.clothingColor)
                .frame(width: size * 0.82, height: size * 0.39)
                .offset(y: size * 0.39)
            Capsule()
                .fill(skinShade)
                .frame(width: size * 0.14, height: size * 0.13)
                .offset(y: size * 0.20)
            if role.wearsCollar {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    RoundedRectangle(cornerRadius: size * 0.025)
                        .fill(.white.opacity(0.94))
                        .frame(width: size * 0.12, height: size * 0.17)
                        .rotationEffect(.degrees(side * 19))
                        .offset(x: side * size * 0.085, y: size * 0.30)
                }
            }
            if role.wearsTie {
                Triangle()
                    .fill(role.accent)
                    .frame(width: size * 0.10, height: size * 0.16)
                    .offset(y: size * 0.33)
            }
            if role == .craftsmanCustomer || role == .staffService {
                HStack(spacing: size * 0.25) {
                    Capsule().fill(.white.opacity(0.58)).frame(width: size * 0.055, height: size * 0.20)
                    Capsule().fill(.white.opacity(0.58)).frame(width: size * 0.055, height: size * 0.20)
                }
                .offset(y: size * 0.34)
            }
        }
    }

    private var head: some View {
        ZStack {
            backHair
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(skinShade)
                    .frame(width: size * 0.07, height: size * 0.10)
                    .offset(x: side * size * 0.21, y: -size * 0.01)
            }
            Ellipse()
                .fill(skin)
                .frame(width: size * 0.41, height: size * 0.47)
                .offset(y: -size * 0.035)
            frontHair
            if role.wearsCap { cap }
            brows
            eyes
            smile
            if role.wearsGlasses { glasses }
            if variant == 3 {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Ellipse()
                        .fill(Color.pink.opacity(0.20))
                        .frame(width: size * 0.075, height: size * 0.035)
                        .offset(x: side * size * 0.145, y: size * 0.035)
                }
            }
        }
    }

    @ViewBuilder private var backHair: some View {
        switch variant {
        case 1:
            Ellipse()
                .fill(hair)
                .frame(width: size * 0.49, height: size * 0.55)
                .offset(y: -size * 0.055)
        case 3:
            RoundedRectangle(cornerRadius: size * 0.19)
                .fill(hair)
                .frame(width: size * 0.50, height: size * 0.54)
                .offset(y: -size * 0.005)
        default:
            Ellipse()
                .fill(hair)
                .frame(width: size * 0.46, height: size * 0.43)
                .offset(y: -size * 0.10)
        }
    }

    @ViewBuilder private var frontHair: some View {
        if !role.wearsCap {
            switch variant {
            case 0:
                Ellipse()
                    .fill(hair)
                    .frame(width: size * 0.42, height: size * 0.20)
                    .offset(y: -size * 0.20)
            case 1:
                Capsule()
                    .fill(hair)
                    .frame(width: size * 0.35, height: size * 0.14)
                    .rotationEffect(.degrees(-12))
                    .offset(x: size * 0.035, y: -size * 0.18)
            case 2:
                HStack(spacing: -size * 0.025) {
                    ForEach(0..<4, id: \.self) { index in
                        Ellipse()
                            .fill(hair)
                            .frame(width: size * 0.13, height: size * 0.17)
                            .offset(y: index.isMultiple(of: 2) ? 0 : size * 0.015)
                    }
                }
                .offset(y: -size * 0.19)
            default:
                RoundedRectangle(cornerRadius: size * 0.07)
                    .fill(hair)
                    .frame(width: size * 0.42, height: size * 0.17)
                    .offset(y: -size * 0.19)
            }
        }
    }

    private var cap: some View {
        ZStack {
            Ellipse()
                .fill(role.accent)
                .frame(width: size * 0.45, height: size * 0.20)
                .offset(y: -size * 0.22)
            Capsule()
                .fill(role.accent.opacity(0.86))
                .frame(width: size * 0.27, height: size * 0.055)
                .offset(x: size * 0.12, y: -size * 0.17)
        }
    }

    private var brows: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            Capsule()
                .fill(hair)
                .frame(width: size * 0.09, height: size * 0.022)
                .rotationEffect(.degrees(side * -4))
                .offset(x: side * size * 0.10, y: -size * 0.10)
        }
    }

    private var eyes: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            ArcStroke(bulge: -1)
                .stroke(line, style: StrokeStyle(lineWidth: size * 0.027, lineCap: .round))
                .frame(width: size * 0.08, height: size * 0.045)
                .offset(x: side * size * 0.10, y: -size * 0.035)
        }
    }

    private var smile: some View {
        ArcStroke(bulge: 1)
            .stroke(line, style: StrokeStyle(lineWidth: size * 0.027, lineCap: .round))
            .frame(width: size * 0.105, height: size * 0.05)
            .offset(y: size * 0.075)
    }

    private var glasses: some View {
        HStack(spacing: size * 0.025) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: size * 0.025)
                    .stroke(line.opacity(0.78), lineWidth: max(1, size * 0.018))
                    .frame(width: size * 0.14, height: size * 0.09)
            }
        }
        .offset(y: -size * 0.025)
    }

    private var roleBadge: some View {
        ZStack {
            Circle().fill(.white)
            Circle().fill(role.accent.opacity(0.14)).padding(size * 0.025)
            Image(systemName: role.badgeIcon)
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundStyle(role.accent)
        }
        .frame(width: size * 0.30, height: size * 0.30)
        .offset(x: size * 0.31, y: size * 0.31)
    }
}

enum CharacterAvatarRole: Equatable {
    case valueCustomer
    case familyCustomer
    case affluentCustomer
    case craftsmanCustomer
    case outdoorCustomer
    case camperCustomer
    case corporateCustomer
    case seller
    case staffGeneral
    case staffSales
    case staffProcurement
    case staffResearch
    case staffService
    case manager

    var backgroundColors: [Color] {
        switch self {
        case .familyCustomer: [Color(red: 1.0, green: 0.84, blue: 0.72), Color(red: 0.96, green: 0.60, blue: 0.48)]
        case .affluentCustomer: [Color(red: 0.91, green: 0.82, blue: 0.55), Color(red: 0.56, green: 0.39, blue: 0.19)]
        case .craftsmanCustomer: [Color(red: 0.98, green: 0.76, blue: 0.42), Color(red: 0.83, green: 0.38, blue: 0.20)]
        case .outdoorCustomer, .camperCustomer: [Color(red: 0.68, green: 0.86, blue: 0.64), Color(red: 0.22, green: 0.55, blue: 0.42)]
        case .corporateCustomer, .manager: [Color(red: 0.52, green: 0.75, blue: 0.88), GameTheme.navy]
        case .seller: [Color(red: 0.91, green: 0.82, blue: 0.72), Color(red: 0.66, green: 0.52, blue: 0.43)]
        case .valueCustomer: [Color(red: 0.76, green: 0.90, blue: 0.93), GameTheme.teal]
        case .staffGeneral, .staffSales, .staffProcurement, .staffResearch, .staffService:
            [Color(red: 0.78, green: 0.84, blue: 0.94), Color(red: 0.36, green: 0.48, blue: 0.67)]
        }
    }

    var clothingColor: Color {
        switch self {
        case .familyCustomer: Color(red: 0.86, green: 0.35, blue: 0.31)
        case .affluentCustomer, .corporateCustomer, .manager: GameTheme.navy
        case .craftsmanCustomer, .staffService: Color(red: 0.92, green: 0.48, blue: 0.17)
        case .outdoorCustomer: Color(red: 0.24, green: 0.51, blue: 0.30)
        case .camperCustomer: Color(red: 0.17, green: 0.45, blue: 0.57)
        case .seller: Color(red: 0.57, green: 0.43, blue: 0.34)
        case .valueCustomer: GameTheme.teal
        case .staffSales: Color.blue
        case .staffProcurement: Color.purple
        case .staffResearch: Color.indigo
        case .staffGeneral: Color(red: 0.35, green: 0.43, blue: 0.58)
        }
    }

    var accent: Color {
        switch self {
        case .familyCustomer: Color.pink
        case .affluentCustomer: Color(red: 0.82, green: 0.61, blue: 0.18)
        case .craftsmanCustomer, .staffService: GameTheme.orange
        case .outdoorCustomer: Color.green
        case .camperCustomer: Color.cyan
        case .corporateCustomer, .manager: GameTheme.mint
        case .seller: Color.brown
        case .valueCustomer: GameTheme.teal
        case .staffSales: Color.blue
        case .staffProcurement: Color.purple
        case .staffResearch: Color.indigo
        case .staffGeneral: Color.gray
        }
    }

    var badgeIcon: String {
        switch self {
        case .familyCustomer: "figure.2.and.child.holdinghands"
        case .affluentCustomer: "sparkles"
        case .craftsmanCustomer: "wrench.and.screwdriver.fill"
        case .outdoorCustomer: "leaf.fill"
        case .camperCustomer: "mountain.2.fill"
        case .corporateCustomer: "building.2.fill"
        case .seller: "car.side.fill"
        case .valueCustomer: "tag.fill"
        case .staffGeneral: "person.fill"
        case .staffSales: "bubble.left.and.bubble.right.fill"
        case .staffProcurement: "car.badge.gearshape"
        case .staffResearch: "chart.line.uptrend.xyaxis"
        case .staffService: "wrench.adjustable.fill"
        case .manager: "star.fill"
        }
    }

    var wearsCap: Bool {
        self == .craftsmanCustomer || self == .outdoorCustomer || self == .staffService
    }
    var wearsGlasses: Bool {
        self == .affluentCustomer || self == .corporateCustomer || self == .staffResearch
    }
    var wearsTie: Bool {
        self == .affluentCustomer || self == .corporateCustomer || self == .manager
    }
    var wearsCollar: Bool {
        wearsTie || self == .staffSales || self == .staffProcurement || self == .staffResearch
    }
}

extension BuyerLead {
    var characterAvatarRole: CharacterAvatarRole {
        switch purpose {
        case .family: .familyCustomer
        case .outdoor: .outdoorCustomer
        case .camper: .camperCustomer
        case .work: .craftsmanCustomer
        case .corporate: .corporateCustomer
        case .performance: .affluentCustomer
        case .welfare: .familyCustomer
        case .mobileBusiness: .craftsmanCustomer
        case .general:
            budget >= 500 || minimumQuality >= 0.88 ? .affluentCustomer : .valueCustomer
        }
    }

    var characterAvatarSeed: Int { id.characterAvatarSeed }
}

extension PurchaseCase {
    var characterAvatarRole: CharacterAvatarRole {
        if lotCount > 1 { return .corporateCustomer }
        if VehicleCatalog.entry(id: modelID)?.origin == .imported { return .affluentCustomer }
        switch category {
        case .pickup: return .craftsmanCustomer
        case .sports: return .affluentCustomer
        case .suv: return .outdoorCustomer
        default: return .seller
        }
    }

    var characterAvatarSeed: Int { id.characterAvatarSeed }
}

extension StoreEmployee {
    var characterAvatarRole: CharacterAvatarRole {
        switch assignment {
        case .sales: return .staffSales
        case .procurement: return .staffProcurement
        case .research: return .staffResearch
        case .service: return .staffService
        case .unassigned:
            let abilities: [(CharacterAvatarRole, Int)] = [
                (.staffSales, salesSkill),
                (.staffProcurement, procurementSkill),
                (.staffResearch, researchSkill),
                (.staffService, serviceSkill)
            ]
            return abilities.max(by: { $0.1 < $1.1 })?.0 ?? .staffGeneral
        }
    }

    var characterAvatarSeed: Int { id.characterAvatarSeed }
}

extension StoreManager {
    var characterAvatarSeed: Int { name.characterAvatarSeed }
}

private extension UUID {
    var characterAvatarSeed: Int {
        uuidString.unicodeScalars.reduce(17) { ($0 &* 31) &+ Int($1.value) }
    }
}

private extension String {
    var characterAvatarSeed: Int {
        unicodeScalars.reduce(17) { ($0 &* 31) &+ Int($1.value) }
    }
}

/// 正の `bulge` で下向き（笑顔）、負で上向き（笑い目）に膨らむ弧。
private struct ArcStroke: Shape {
    var bulge: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.midY + bulge * rect.height * 1.6)
        )
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            GuideAvatarView(expression: .neutral, size: 64)
            GuideAvatarView(expression: .smile, size: 64)
            GuideAvatarView(expression: .point, size: 64)
            GuideAvatarView(expression: .think, size: 64)
            GuideAvatarView(expression: .cheer, size: 64)
            GuideAvatarView(expression: .alert, size: 64)
        }
        HStack(spacing: 12) {
            CharacterAvatarView(role: .familyCustomer, seed: 1, size: 64)
            CharacterAvatarView(role: .affluentCustomer, seed: 2, size: 64)
            CharacterAvatarView(role: .craftsmanCustomer, seed: 3, size: 64)
            CharacterAvatarView(role: .outdoorCustomer, seed: 4, size: 64)
            CharacterAvatarView(role: .staffSales, seed: 5, size: 64)
            CharacterAvatarView(role: .manager, seed: 6, size: 64)
        }
    }
    .padding()
}
