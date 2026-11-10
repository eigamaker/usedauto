import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var confirmNewGame = false
    @State private var showGuideIntro = false

    var body: some View {
        ZStack {
            TitleBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()
                VStack(spacing: 6) {
                    Text("中古車店経営シミュレーション")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(GameTheme.hudEdge)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(GameTheme.gold))
                        .overlay(Capsule().strokeBorder(GameTheme.hudEdge, lineWidth: 1.5))
                    ZStack {
                        // 厚みのあるロゴ：影→縁→本体の順に重ねます。
                        Text("CAR CITY")
                            .foregroundStyle(GameTheme.hudEdge)
                            .offset(y: 7)
                        Text("CAR CITY")
                            .foregroundStyle(GameTheme.goldDark)
                            .offset(y: 4)
                        Text("CAR CITY")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(red: 1, green: 0.93, blue: 0.55), GameTheme.gold],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .tracking(1)
                    .shadow(color: GameTheme.hudEdge.opacity(0.5), radius: 0, x: 0, y: 2)
                    Text("カーシティ経営")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .tracking(6)
                        .foregroundStyle(.white)
                        .shadow(color: GameTheme.hudEdge, radius: 0, y: 2)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        if game.hasSaveData { confirmNewGame = true }
                        else { showGuideIntro = true }
                    } label: {
                        TitleActionLabel(title: "はじめから", icon: "flag.checkered", prominent: true)
                    }
                    .buttonStyle(.gamePress)

                    Button { game.loadGame() } label: {
                        TitleActionLabel(title: "つづきから", icon: "play.fill", prominent: false)
                    }
                    .buttonStyle(.gamePress)
                    .disabled(!game.hasSaveData)
                    .saturation(game.hasSaveData ? 1 : 0.1)

                    Text(game.saveSummary ?? "セーブデータはありません")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: GameTheme.hudEdge, radius: 0, y: 1)
                }
                .frame(maxWidth: 330)

                HStack(spacing: 10) {
                    GuideAvatarView(expression: .smile, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("案内役　\(GuideCharacter.nao.name)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(GameTheme.ink)
                        Text("土地選び・仕入れ・販売・委任・PLの読み方まで案内します")
                            .font(.caption2)
                            .foregroundStyle(GameTheme.ink.opacity(0.7))
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: 430)
                .background(GamePanelBackground(cornerRadius: 14))
                .padding(.bottom, 12)
            }
            .padding(24)
        }
        .confirmationDialog("新しいゲームを始めますか？", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("セーブデータを上書きして開始", role: .destructive) { showGuideIntro = true }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在のセーブデータは削除されます。")
        }
        .fullScreenCover(isPresented: $showGuideIntro) {
            GuideIntroView { mode in
                game.startNewGame()
                game.beginGuide(mode: mode)
            }
        }
    }
}

private struct TitleActionLabel: View {
    let title: String
    let icon: String
    let prominent: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let top = prominent ? GameTheme.go : GameTheme.hudTop
        let lip = prominent ? GameTheme.goDark : GameTheme.hudEdge
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 22, weight: .black, design: .rounded))
        .foregroundStyle(.white)
        .shadow(color: lip, radius: 0, y: 2)
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background {
            ZStack {
                shape.fill(lip).offset(y: 6)
                shape.stroke(GameTheme.hudEdge, lineWidth: 2).offset(y: 6)
                shape.fill(top)
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(0.45), .white.opacity(0.02), .black.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                shape.strokeBorder(GameTheme.hudEdge, lineWidth: 2)
                shape.strokeBorder(.white.opacity(0.35), lineWidth: 1).padding(2)
            }
        }
        .padding(.bottom, 6)
    }
}

/// タイトル画面の背景。青空・雲・街のシルエット・道路を手描きします。
private struct TitleBackdrop: View {
    var body: some View {
        Canvas { context, size in
            let sky = Gradient(colors: [
                Color(red: 0.20, green: 0.56, blue: 0.92),
                Color(red: 0.55, green: 0.82, blue: 0.98),
                Color(red: 0.86, green: 0.95, blue: 0.98)
            ])
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.72))
            )
            // 雲
            for (x, y, scale) in [(0.16, 0.13, 1.0), (0.74, 0.09, 0.8), (0.52, 0.22, 1.25), (0.05, 0.30, 0.7)] {
                var cloud = Path()
                let cx = size.width * x, cy = size.height * y, unit = 26.0 * scale
                cloud.addEllipse(in: CGRect(x: cx, y: cy, width: unit * 2.2, height: unit))
                cloud.addEllipse(in: CGRect(x: cx + unit * 0.5, y: cy - unit * 0.45, width: unit * 1.3, height: unit * 1.1))
                cloud.addEllipse(in: CGRect(x: cx + unit * 1.3, y: cy - unit * 0.15, width: unit * 1.6, height: unit * 0.95))
                context.fill(cloud, with: .color(.white.opacity(0.9)))
            }
            let horizon = size.height * 0.66
            // 遠景のビル群
            let far = Color(red: 0.52, green: 0.72, blue: 0.90)
            var x = -10.0
            var index = 0
            while x < size.width {
                let width = 30.0 + Double((index * 37) % 26)
                let height = 70.0 + Double((index * 53) % 120)
                context.fill(Path(CGRect(x: x, y: horizon - height, width: width, height: height)), with: .color(far))
                x += width + 5
                index += 1
            }
            // 近景のビル群（窓つき）
            x = -18
            index = 0
            let palette = [
                Color(red: 0.17, green: 0.42, blue: 0.70), Color(red: 0.93, green: 0.55, blue: 0.24),
                Color(red: 0.20, green: 0.60, blue: 0.56), Color(red: 0.80, green: 0.36, blue: 0.30),
                Color(red: 0.95, green: 0.86, blue: 0.62)
            ]
            while x < size.width {
                let width = 44.0 + Double((index * 29) % 30)
                let height = 46.0 + Double((index * 71) % 96)
                let rect = CGRect(x: x, y: horizon - height, width: width, height: height)
                context.fill(Path(rect), with: .color(palette[index % palette.count]))
                context.fill(Path(CGRect(x: x, y: rect.minY, width: width, height: 6)), with: .color(.black.opacity(0.22)))
                context.fill(Path(CGRect(x: rect.maxX - 9, y: rect.minY, width: 9, height: height)), with: .color(.black.opacity(0.14)))
                var wy = rect.minY + 14
                while wy < horizon - 12 {
                    var wx = x + 7
                    while wx < rect.maxX - 16 {
                        context.fill(Path(CGRect(x: wx, y: wy, width: 7, height: 8)), with: .color(.white.opacity(0.62)))
                        wx += 13
                    }
                    wy += 16
                }
                x += width + 3
                index += 1
            }
            // 草地と道路
            context.fill(
                Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.50, green: 0.76, blue: 0.30), Color(red: 0.34, green: 0.62, blue: 0.24)]),
                    startPoint: CGPoint(x: 0, y: horizon),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            let road = CGRect(x: 0, y: horizon + 26, width: size.width, height: 58)
            context.fill(Path(road.insetBy(dx: 0, dy: -5)), with: .color(Color(red: 0.80, green: 0.78, blue: 0.70)))
            context.fill(Path(road), with: .color(Color(red: 0.36, green: 0.39, blue: 0.44)))
            var dash = 8.0
            while dash < size.width {
                context.fill(Path(CGRect(x: dash, y: road.midY - 2, width: 26, height: 4)), with: .color(.white.opacity(0.9)))
                dash += 52
            }
            // 走る車
            for (cx, lane, color) in [
                (0.18, 0.28, Color(red: 0.90, green: 0.26, blue: 0.20)),
                (0.62, 0.72, Color(red: 0.16, green: 0.46, blue: 0.86)),
                (0.86, 0.28, Color(red: 1.0, green: 0.78, blue: 0.20))
            ] {
                let bx = size.width * cx, by = road.minY + road.height * lane - 12
                context.fill(Path(ellipseIn: CGRect(x: bx - 2, y: by + 16, width: 50, height: 7)), with: .color(.black.opacity(0.25)))
                context.fill(Path(roundedRect: CGRect(x: bx, y: by + 6, width: 46, height: 13), cornerRadius: 5), with: .color(color))
                context.fill(Path(roundedRect: CGRect(x: bx + 9, y: by - 3, width: 25, height: 12), cornerRadius: 5), with: .color(color))
                context.fill(Path(roundedRect: CGRect(x: bx + 12, y: by - 1, width: 19, height: 8), cornerRadius: 3), with: .color(Color(red: 0.75, green: 0.92, blue: 1.0)))
                for wheel in [8.0, 32.0] {
                    context.fill(Path(ellipseIn: CGRect(x: bx + wheel, y: by + 14, width: 9, height: 9)), with: .color(GameTheme.hudEdge))
                }
            }
        }
    }
}
