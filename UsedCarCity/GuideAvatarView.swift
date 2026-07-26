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
    HStack(spacing: 12) {
        GuideAvatarView(expression: .neutral, size: 64)
        GuideAvatarView(expression: .smile, size: 64)
        GuideAvatarView(expression: .point, size: 64)
        GuideAvatarView(expression: .think, size: 64)
        GuideAvatarView(expression: .cheer, size: 64)
        GuideAvatarView(expression: .alert, size: 64)
    }
    .padding()
}
