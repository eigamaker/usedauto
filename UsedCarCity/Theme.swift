import SwiftUI
import UIKit

/// ゲーム全体の配色。HUD は濃紺＋金の縁取り、メニューは羊皮紙色のパネルで統一します。
enum GameTheme {
    static let ink = Color(red: 0.09, green: 0.13, blue: 0.21)
    static let navy = Color(red: 0.10, green: 0.21, blue: 0.36)
    static let teal = Color(red: 0.06, green: 0.58, blue: 0.50)
    static let mint = Color(red: 0.66, green: 0.92, blue: 0.78)
    static let cream = Color(red: 0.95, green: 0.90, blue: 0.77)
    static let sand = Color(red: 0.89, green: 0.80, blue: 0.60)
    static let orange = Color(red: 0.96, green: 0.48, blue: 0.14)
    static let danger = Color(red: 0.82, green: 0.20, blue: 0.20)
    static let road = Color(red: 0.30, green: 0.35, blue: 0.38)

    // パネル
    static let panel = Color(red: 1.00, green: 0.975, blue: 0.90)
    static let panelLip = Color(red: 0.66, green: 0.55, blue: 0.36)
    static let panelEdge = Color(red: 0.47, green: 0.37, blue: 0.22)

    // HUD
    static let hudTop = Color(red: 0.16, green: 0.33, blue: 0.54)
    static let hudBottom = Color(red: 0.07, green: 0.16, blue: 0.30)
    static let hudEdge = Color(red: 0.03, green: 0.08, blue: 0.16)
    static let gold = Color(red: 1.00, green: 0.82, blue: 0.27)
    static let goldDark = Color(red: 0.80, green: 0.52, blue: 0.08)
    static let go = Color(red: 0.36, green: 0.76, blue: 0.22)
    static let goDark = Color(red: 0.16, green: 0.48, blue: 0.12)

    static var hudGradient: LinearGradient {
        LinearGradient(colors: [hudTop, hudBottom], startPoint: .top, endPoint: .bottom)
    }

    /// ナビゲーションバーやセグメントなど、UIKit 由来の部品をゲームの配色に合わせます。
    @MainActor
    static func installAppearance() {
        let rounded: (CGFloat, UIFont.Weight) -> UIFont = { size, weight in
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        }
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(hudBottom)
        bar.shadowColor = UIColor(goldDark)
        bar.titleTextAttributes = [.foregroundColor: UIColor.white, .font: rounded(18, .heavy)]
        bar.largeTitleTextAttributes = [.foregroundColor: UIColor.white, .font: rounded(30, .heavy)]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
        UINavigationBar.appearance().tintColor = UIColor(gold)

        let segment = UISegmentedControl.appearance()
        segment.selectedSegmentTintColor = UIColor(navy)
        segment.backgroundColor = UIColor(panelLip).withAlphaComponent(0.45)
        segment.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: rounded(13, .bold)], for: .selected)
        segment.setTitleTextAttributes([.foregroundColor: UIColor(ink), .font: rounded(13, .semibold)], for: .normal)
    }
}

// MARK: - パネル

/// 下端に厚みのある、ボードゲームの駒のようなパネル形状。
struct GamePanelBackground: View {
    var cornerRadius: CGFloat = 16
    var fill: Color = GameTheme.panel
    var lip: Color = GameTheme.panelLip
    var edge: Color = GameTheme.panelEdge
    var lipHeight: CGFloat = 4

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(lip).offset(y: lipHeight)
            shape.fill(fill)
            shape.fill(
                LinearGradient(
                    colors: [.white.opacity(0.55), .white.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            shape.strokeBorder(edge, lineWidth: 1.5)
        }
    }
}

extension View {
    func gameCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(GamePanelBackground())
            .padding(.bottom, 4)
    }

    /// シート最上部などに置く、濃紺の見出し帯。
    func gameHUDPlate(cornerRadius: CGFloat = 12) -> some View {
        self.background(
            GamePanelBackground(
                cornerRadius: cornerRadius,
                fill: GameTheme.hudTop,
                lip: GameTheme.hudEdge,
                edge: GameTheme.hudEdge,
                lipHeight: 3
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(GameTheme.hudGradient)
                    .padding(1.5)
            )
        )
    }
}

// MARK: - ボタン

/// 押すと沈む、厚みのあるゲームボタン。色は `.tint(_:)` で指定します。
struct GameButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        GameButtonBody(kind: kind, configuration: configuration)
    }
}

private struct GameButtonBody: View {
    let kind: GameButtonStyle.Kind
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        let small = controlSize == .small || controlSize == .mini
        let large = controlSize == .large
        let radius: CGFloat = small ? 9 : 12
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let pressed = configuration.isPressed
        let lip: CGFloat = pressed ? 1 : (small ? 2.5 : 3.5)
        let destructive = configuration.role == .destructive
        let primary = kind == .primary
        let base: AnyShapeStyle = destructive ? AnyShapeStyle(GameTheme.danger) : AnyShapeStyle(.tint)

        configuration.label
            .fontWeight(.heavy)
            .multilineTextAlignment(.center)
            .foregroundStyle(primary ? AnyShapeStyle(Color.white) : base)
            .shadow(color: primary ? .black.opacity(0.28) : .clear, radius: 0, y: 1)
            .padding(.horizontal, small ? 10 : (large ? 18 : 14))
            .padding(.vertical, small ? 6 : (large ? 13 : 9))
            .background {
                ZStack {
                    // 厚み
                    shape.fill(primary ? base : AnyShapeStyle(GameTheme.panelLip))
                        .overlay(shape.fill(Color.black.opacity(primary ? 0.38 : 0.08)))
                        .offset(y: lip)
                    // 天面
                    shape.fill(primary ? base : AnyShapeStyle(GameTheme.panel))
                    if primary {
                        shape.fill(
                            LinearGradient(
                                colors: [.white.opacity(0.34), .white.opacity(0.04), .black.opacity(0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        shape.strokeBorder(Color.black.opacity(0.30), lineWidth: 1.2)
                    } else {
                        shape.strokeBorder(base, lineWidth: 1.6)
                    }
                }
            }
            .offset(y: pressed ? 2.5 : 0)
            .padding(.bottom, small ? 2.5 : 3.5)
            .saturation(isEnabled ? 1 : 0.05)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension ButtonStyle where Self == GameButtonStyle {
    static var gamePrimary: GameButtonStyle { GameButtonStyle(kind: .primary) }
    static var gameSecondary: GameButtonStyle { GameButtonStyle(kind: .secondary) }
}

/// アイコン＋短いラベルの正方形タイル。HUD とドックで共通に使います。
struct GameIconTile: View {
    let title: String
    let icon: String
    var tint: Color = GameTheme.hudTop
    var size: CGFloat = 46
    var showsTitle = true
    var badge: String? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: size * (showsTitle ? 0.36 : 0.44), weight: .heavy))
                .frame(height: size * (showsTitle ? 0.44 : 0.6))
            if showsTitle {
                Text(title)
                    .font(.system(size: max(8.5, size * 0.19), weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 0, y: 1)
        .frame(width: size, height: size)
        .background {
            ZStack {
                shape.fill(GameTheme.hudEdge).offset(y: 3.5)
                shape.fill(tint)
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(0.36), .white.opacity(0.02), .black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                shape.strokeBorder(GameTheme.hudEdge, lineWidth: 1.5)
                shape.strokeBorder(.white.opacity(0.22), lineWidth: 1).padding(1.5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(GameTheme.danger)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    .offset(x: 5, y: -5)
            }
        }
        .padding(.bottom, 3.5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// タイルやプレートを押したときに沈ませるだけのボタンスタイル。
struct GamePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2.5 : 0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GamePressStyle {
    static var gamePress: GamePressStyle { GamePressStyle() }
}

/// HUD 上の資源表示（アイコン入りの凹んだ枠）。
struct HUDResourceChip<Icon: View>: View {
    let title: String
    let value: String
    var valueColor: Color = .white
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(spacing: 7) {
            icon()
            VStack(alignment: .leading, spacing: -1) {
                Text(title)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameTheme.gold.opacity(0.9))
                Text(value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .frame(height: 40)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.34))
                .overlay(Capsule().strokeBorder(GameTheme.hudEdge, lineWidth: 1.5))
                .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1).padding(1.5))
        )
    }
}

/// 金色のコイン。現金表示に使います。
struct GameCoinIcon: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle().fill(GameTheme.goldDark).offset(y: 2)
            Circle().fill(
                LinearGradient(
                    colors: [Color(red: 1, green: 0.93, blue: 0.55), GameTheme.gold],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Circle().strokeBorder(GameTheme.goldDark, lineWidth: 1.5)
            Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1).padding(3)
            Text("¥")
                .font(.system(size: size * 0.56, weight: .black, design: .rounded))
                .foregroundStyle(GameTheme.goldDark)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 共通部品

struct CapsuleLabel: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon) }
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .font(.caption.weight(.heavy))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.22), radius: 0, y: 1)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color)
                .overlay(
                    Capsule().fill(
                        LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
                    )
                )
                .overlay(Capsule().strokeBorder(.black.opacity(0.22), lineWidth: 1))
        )
    }
}

struct MetricView: View {
    let title: String
    let value: String
    var detail: String? = nil
    var tint: Color = GameTheme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GameTheme.panelEdge)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.headline.weight(.heavy).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(GameTheme.orange)
                .frame(width: 5, height: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(GameTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
