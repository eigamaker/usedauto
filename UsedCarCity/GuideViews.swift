import SwiftUI

// MARK: - 表示設定（端末に保存する見た目の好み）

enum GuideDisplayDefaults {
    static let visibleKey = "guide.visible"
    static let opacityKey = "guide.opacity"
    static let minimizedKey = "guide.minimized"
    static let originXKey = "guide.originX"
    static let originYKey = "guide.originY"

    static let defaultOpacity = 0.93
    static let translucentOpacity = 0.5
    /// 位置未設定を表す番兵値。
    static let unsetOrigin = -1.0
    static let cardWidth = 344.0

    static func resetPosition() {
        UserDefaults.standard.set(unsetOrigin, forKey: originXKey)
        UserDefaults.standard.set(unsetOrigin, forKey: originYKey)
    }
}

/// ガイドカードが画面上で占める領域（ウインドウ座標）。
///
/// マップは SceneKit ビューに直接ジェスチャを付けているため、SwiftUI で上に重ねただけでは
/// カードを貫通してタップが届いてしまいます。カードの矩形をここへ記録し、マップ側で除外します。
enum GuideOverlayHitArea {
    nonisolated(unsafe) static var frame: CGRect = .zero

    static func contains(_ point: CGPoint) -> Bool {
        !frame.isEmpty && frame.contains(point)
    }
}

private struct GuideHitAreaReporter: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { GuideOverlayHitArea.frame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, frame in
                        GuideOverlayHitArea.frame = frame
                    }
                    .onDisappear { GuideOverlayHitArea.frame = .zero }
            }
        }
    }
}

private extension View {
    func reportsGuideHitArea() -> some View { modifier(GuideHitAreaReporter()) }
}

// MARK: - マップ上に浮かぶガイド

/// ドラッグで移動でき、透過・最小化・非表示を切り替えられる案内カード。
/// 地図の視認性を損なわないことを最優先にしています。
struct GuideFloatingPanel: View {
    @EnvironmentObject private var game: GameEngine
    let bounds: CGSize
    let perform: (GuideAction) -> Void

    @AppStorage(GuideDisplayDefaults.visibleKey) private var isVisible = true
    @AppStorage(GuideDisplayDefaults.opacityKey) private var opacity = GuideDisplayDefaults.defaultOpacity
    @AppStorage(GuideDisplayDefaults.minimizedKey) private var isMinimized = false
    @AppStorage(GuideDisplayDefaults.originXKey) private var originX = GuideDisplayDefaults.unsetOrigin
    @AppStorage(GuideDisplayDefaults.originYKey) private var originY = GuideDisplayDefaults.unsetOrigin
    @State private var dragOffset = CGSize.zero

    private var cardWidth: CGFloat {
        min(GuideDisplayDefaults.cardWidth, max(220, bounds.width - 24))
    }

    private var panelWidth: CGFloat { isMinimized ? 62 : cardWidth }

    private var origin: CGPoint {
        let defaultX = (bounds.width - panelWidth) / 2
        let defaultY: CGFloat = isMinimized ? bounds.height - 210 : 54
        let x = originX == GuideDisplayDefaults.unsetOrigin ? defaultX : CGFloat(originX)
        let y = originY == GuideDisplayDefaults.unsetOrigin ? defaultY : CGFloat(originY)
        return clamp(CGPoint(x: x, y: y))
    }

    var body: some View {
        if isVisible, let lesson = game.currentGuideLesson {
            // 地図のタップを妨げないよう、当たり判定はカード本体だけに限定します。
            ZStack(alignment: .topLeading) {
                panel(for: lesson)
                    .frame(width: panelWidth, alignment: .topLeading)
                    .reportsGuideHitArea()
                    .offset(x: origin.x + dragOffset.width, y: origin.y + dragOffset.height)
            }
            .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
            .animation(.easeInOut(duration: 0.2), value: isMinimized)
            .transition(.opacity)
        }
    }

    @ViewBuilder private func panel(for lesson: GuideLesson) -> some View {
        if isMinimized {
            minimizedBubble(for: lesson)
        } else {
            // 透過はカード全体の opacity ではなく、背景と文字の色だけで表現します。
            // 全体に opacity を掛けるとカード内のボタンがタップを受け取れなくなるためです。
            VStack(spacing: 0) {
                header(for: lesson)
                GuideMessageBody(lesson: lesson, contentOpacity: contentOpacity, perform: perform)
                    .padding(.horizontal, 13)
                    .padding(.bottom, 12)
            }
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(opacity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(GameTheme.teal.opacity(0.45 * opacity), lineWidth: 1.4)
            }
            .shadow(color: GameTheme.ink.opacity(0.24 * opacity), radius: 14, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    /// 背景を薄くしても読めるよう、文字は背景よりゆるやかに薄くします。
    private var contentOpacity: Double { min(1, 0.42 + 0.58 * opacity) }

    private func minimizedBubble(for lesson: GuideLesson) -> some View {
        Button {
            isMinimized = false
        } label: {
            GuideAvatarView(expression: lesson.expression, size: 58)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(GameTheme.orange)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .offset(x: 3, y: 3)
                }
                .shadow(color: GameTheme.ink.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ガイドを開く")
        .simultaneousGesture(dragGesture)
    }

    private func header(for lesson: GuideLesson) -> some View {
        HStack(spacing: 9) {
            GuideAvatarView(expression: lesson.expression, size: 38)
                .opacity(contentOpacity)
            VStack(alignment: .leading, spacing: 1) {
                Text(GuideCharacter.nao.name)
                    .font(.caption.bold())
                    .foregroundStyle(GameTheme.ink.opacity(contentOpacity))
                Text("\(lesson.chapter.shortTitle)・STEP \(game.guide.stepNumber)/\(game.guide.totalSteps)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(GameTheme.teal.opacity(contentOpacity))
            }
            Spacer(minLength: 4)
            headerButton(icon: opacity > 0.7 ? "circle.lefthalf.filled" : "circle.fill", label: "透過") {
                opacity = opacity > 0.7 ? GuideDisplayDefaults.translucentOpacity : GuideDisplayDefaults.defaultOpacity
            }
            headerButton(icon: "minus", label: "最小化") { isMinimized = true }
            headerButton(icon: "xmark", label: "ガイドを隠す") { isVisible = false }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(GameTheme.navy.opacity(0.10 * opacity))
        .overlay(alignment: .top) {
            Capsule()
                .fill(GameTheme.navy.opacity(0.22))
                .frame(width: 34, height: 4)
                .padding(.top, 3)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    private func headerButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(GameTheme.navy)
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.85))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in dragOffset = value.translation }
            .onEnded { value in
                let moved = CGPoint(
                    x: origin.x + value.translation.width,
                    y: origin.y + value.translation.height
                )
                let clamped = clamp(moved)
                originX = Double(clamped.x)
                originY = Double(clamped.y)
                dragOffset = .zero
            }
    }

    private func clamp(_ point: CGPoint) -> CGPoint {
        let maxX = max(8, bounds.width - panelWidth - 8)
        let maxY = max(8, bounds.height - (isMinimized ? 70 : 96))
        return CGPoint(
            x: min(max(8, point.x), maxX),
            y: min(max(8, point.y), maxY)
        )
    }
}

/// ガイドを非表示にしているときに再表示するためのボタン。
struct GuideToggleButton: View {
    @EnvironmentObject private var game: GameEngine
    @AppStorage(GuideDisplayDefaults.visibleKey) private var isVisible = true
    @AppStorage(GuideDisplayDefaults.minimizedKey) private var isMinimized = false

    var body: some View {
        Button {
            if isVisible {
                isVisible = false
            } else {
                isVisible = true
                isMinimized = false
            }
        } label: {
            GuideAvatarView(expression: .smile, size: 26)
                .frame(width: 38, height: 38)
                .background((isVisible ? GameTheme.teal : GameTheme.navy).opacity(0.88))
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    if !isVisible {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(GameTheme.orange)
                            .clipShape(Circle())
                            .offset(x: 2, y: 2)
                    }
                }
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(game.isGuideRunning ? 1 : 0.55)
        .accessibilityLabel(isVisible ? "ガイドを隠す" : "ガイドを表示")
    }
}

// MARK: - シート内に差し込む案内カード

/// 店舗画面や区画詳細など、シートの中に置く据え置き型の案内カード。
/// `showing` に現在のレッスンが含まれるときだけ表示します。
struct GuideInlineCard: View {
    @EnvironmentObject private var game: GameEngine
    let showing: [GuideLessonID]
    var perform: ((GuideAction) -> Void)? = nil

    var body: some View {
        if let lesson = game.currentGuideLesson, showing.contains(lesson.id) {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    GuideAvatarView(expression: lesson.expression, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(GuideCharacter.nao.shortName)
                            .font(.caption.bold())
                            .foregroundStyle(GameTheme.ink)
                        Text("\(lesson.chapter.shortTitle)・STEP \(game.guide.stepNumber)/\(game.guide.totalSteps)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(GameTheme.teal)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)
                GuideMessageBody(lesson: lesson, showsActionButton: perform != nil, perform: perform ?? { _ in })
            }
            .padding(13)
            .background(GameTheme.mint.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(GameTheme.teal.opacity(0.4), lineWidth: 1.2)
            }
        }
    }
}

// MARK: - 共通のふきだし本体

struct GuideMessageBody: View {
    @EnvironmentObject private var game: GameEngine
    let lesson: GuideLesson
    var showsActionButton = true
    /// 文字や飾りの濃さ。マップを透かしたいときに下げます（ボタンには掛けません）。
    var contentOpacity: Double = 1
    let perform: (GuideAction) -> Void

    private var page: Int { min(game.guide.speechPage, max(0, lesson.speech.count - 1)) }
    private var isLastPage: Bool { page >= lesson.speech.count - 1 }
    private var waitsForPlayerAction: Bool { isLastPage && lesson.goal != .acknowledge }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ProgressView(value: game.guide.progress)
                .tint(GameTheme.teal)
                .scaleEffect(x: 1, y: 0.7, anchor: .center)
                .opacity(contentOpacity)
            Text(lesson.title)
                .font(.subheadline.bold())
                .foregroundStyle(GameTheme.ink.opacity(contentOpacity))
            Text(lesson.speech[page])
                .font(.callout)
                .foregroundStyle(GameTheme.ink.opacity(0.86 * contentOpacity))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if lesson.speech.count > 1 {
                HStack(spacing: 5) {
                    ForEach(Array(lesson.speech.indices), id: \.self) { index in
                        Capsule()
                            .fill(index == page ? GameTheme.teal : GameTheme.navy.opacity(0.2))
                            .frame(width: index == page ? 14 : 6, height: 5)
                    }
                }
                .opacity(contentOpacity)
            }

            if let objective = lesson.objective, waitsForPlayerAction {
                Label(objective, systemImage: "target")
                    .font(.caption.bold())
                    .foregroundStyle(GameTheme.orange.opacity(contentOpacity))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let tip = lesson.tip, isLastPage {
                Label(tip, systemImage: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundStyle(GameTheme.ink.opacity(0.5 * contentOpacity))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let action = lesson.action, showsActionButton, isLastPage {
                Button { perform(action) } label: {
                    Label(action.title, systemImage: action.icon)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(GameTheme.teal)
            }

            HStack(spacing: 8) {
                if page > 0 {
                    Button("戻る") { game.rewindGuide() }
                        .font(.caption.bold())
                        .buttonStyle(.bordered)
                        .tint(GameTheme.navy)
                }
                if waitsForPlayerAction {
                    Text("この操作が終わると自動で次へ進みます")
                        .font(.caption2)
                        .foregroundStyle(GameTheme.ink.opacity(0.5 * contentOpacity))
                    Spacer(minLength: 0)
                    Button("スキップ") { game.skipCurrentGuideLesson() }
                        .font(.caption2.bold())
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else {
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { game.advanceGuide() }
                    } label: {
                        Label(isLastPage ? "わかりました" : "次へ", systemImage: "chevron.right")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.orange)
                }
            }
        }
    }
}

// MARK: - 開始時の確認

/// 新規ゲーム開始時に「案内は必要ですか」を確認する画面。
struct GuideIntroView: View {
    @Environment(\.dismiss) private var dismiss
    let start: (GuideMode) -> Void
    @State private var appeared = false
    @State private var selectedMode: GuideMode?

    var body: some View {
        ZStack {
            LinearGradient(colors: [GameTheme.navy, GameTheme.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 13) {
                        GuideAvatarView(expression: .smile, size: 108)
                            .scaleEffect(appeared ? 1 : 0.85)
                            .animation(.spring(response: 0.5, dampingFraction: 0.65), value: appeared)
                        VStack(spacing: 4) {
                            Text(GuideCharacter.nao.name)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(GuideCharacter.nao.role)
                                .font(.caption.bold())
                                .foregroundStyle(GameTheme.mint)
                        }
                    }
                    .padding(.top, 30)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("「はじめまして。中古車店の立ち上げを担当する、翠浜商工会の浜岡です。」")
                            .font(.callout.weight(.medium))
                        Text("「土地選び、出店、仕入れ、販売の商談、店員への委任、そしてPLの読み方まで。ご案内はいかがしましょう？」")
                            .font(.callout.weight(.medium))
                    }
                    .foregroundStyle(GameTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
                    .background(.white.opacity(0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(spacing: 11) {
                        ForEach(GuideMode.allCases) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedMode = mode
                                }
                            } label: {
                                GuideModeChoiceLabel(mode: mode, isSelected: selectedMode == mode)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        guard let selectedMode else { return }
                        start(selectedMode)
                        dismiss()
                    } label: {
                        Text("この内容でゲームを始める")
                            .font(.headline)
                            .foregroundStyle(GameTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(GameTheme.mint)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedMode == nil)
                    .opacity(selectedMode == nil ? 0.42 : 1)

                    Text("案内はいつでも設定から切り替えられます。表示位置の移動・透過・最小化もできます。")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 24)
                }
                .padding(20)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { appeared = true }
    }
}

private struct GuideModeChoiceLabel: View {
    let mode: GuideMode
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: mode.icon)
                .font(.headline)
                .foregroundStyle(isSelected ? GameTheme.ink : .white)
                .frame(width: 42, height: 42)
                .background(isSelected ? GameTheme.mint : Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(mode.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(mode.detail)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.bold())
                .foregroundStyle(isSelected ? GameTheme.mint : .white.opacity(0.35))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? GameTheme.teal.opacity(0.28) : Color.white.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? GameTheme.mint : Color.white.opacity(0.14), lineWidth: isSelected ? 2.4 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 設定

/// ゲーム設定シートに差し込むガイド設定。
struct GuideSettingsSection: View {
    @EnvironmentObject private var game: GameEngine
    @AppStorage(GuideDisplayDefaults.visibleKey) private var isVisible = true
    @AppStorage(GuideDisplayDefaults.opacityKey) private var opacity = GuideDisplayDefaults.defaultOpacity
    @AppStorage(GuideDisplayDefaults.minimizedKey) private var isMinimized = false

    var body: some View {
        Section {
            HStack(spacing: 11) {
                GuideAvatarView(expression: .smile, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(GuideCharacter.nao.name).font(.subheadline.bold())
                    Text(game.isGuideRunning
                         ? "案内中：\(game.currentGuideLesson?.title ?? "")"
                         : (game.guide.mode == .off ? "案内オフ" : "全レッスン修了"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Toggle("ガイドを表示", isOn: $isVisible)
            Toggle("最小化（アバターだけ表示）", isOn: $isMinimized)
                .disabled(!isVisible)

            VStack(alignment: .leading, spacing: 4) {
                Text("カードの濃さ  \(Int(opacity * 100))%")
                    .font(.caption.bold())
                Slider(value: $opacity, in: 0.25...1.0, step: 0.01)
                    .tint(GameTheme.teal)
                Text("地図が見づらいときは濃さを下げるとカードが透けます。カードはドラッグでも移動できます。")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Button {
                GuideDisplayDefaults.resetPosition()
            } label: {
                Label("表示位置を初期化", systemImage: "arrow.counterclockwise")
            }

            Picker("案内モード", selection: Binding(
                get: { game.guide.mode },
                set: { game.restartGuide(mode: $0) }
            )) {
                ForEach(GuideMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            if game.guide.mode != .off {
                Button {
                    game.restartGuide(mode: game.guide.mode)
                    isVisible = true
                    isMinimized = false
                } label: {
                    Label("チュートリアルを最初から", systemImage: "play.circle")
                }
                Menu {
                    ForEach(GuideChapter.allCases) { chapter in
                        Button(chapter.title) { game.replayGuideChapter(chapter) }
                    }
                } label: {
                    Label("章を選んで復習", systemImage: "book.fill")
                }
                if game.isGuideRunning {
                    Button(role: .destructive) { game.stopGuide() } label: {
                        Label("今回の案内を終了", systemImage: "stop.circle")
                    }
                }
            }
        } header: {
            Text("ガイド")
        } footer: {
            Text("\(GuideCharacter.nao.tagline)\nチュートリアルをやり直しても、すでに達成済みの内容は自動でスキップされます。")
        }
    }
}

// MARK: - PLの読み方

/// ガイドが実際の数字を使ってPLの読み方を解説するシート。
struct GuideProfitLossLessonView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss

    private var finance: FinanceSnapshot { game.finance }
    private var grossProfit: Int { finance.revenue - finance.costOfSales }
    private var grossMargin: Double {
        finance.revenue > 0 ? Double(grossProfit) / Double(finance.revenue) : 0
    }
    private var operatingExpenses: Int {
        finance.personnel + finance.rent + finance.advertising + finance.fixedCosts
            + finance.depreciation + finance.interest + finance.customerClaims
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    speechCard
                    structureCard
                    numbersCard
                    diagnosisCard
                    Button {
                        game.acknowledgeGuide(.readProfitLoss)
                        dismiss()
                    } label: {
                        Label("読み方を理解した", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.teal)
                }
                .padding(15)
            }
            .background(GameTheme.cream)
            .navigationTitle("PLの読み方")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
            }
        }
    }

    private var speechCard: some View {
        HStack(alignment: .top, spacing: 11) {
            GuideAvatarView(expression: .think, size: 46)
            VStack(alignment: .leading, spacing: 6) {
                Text("「PLは上から下へ、引き算で読みます。」")
                    .font(.subheadline.bold())
                Text("売上高から仕入れ原価を引いて粗利。粗利から会社を回す費用を引いて営業利益。どこで利益が消えたのかを、この順番で追いかけます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard()
    }

    private var structureCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionTitle(title: "PLの骨格", subtitle: "覚えるのはこの3段だけ")
            GuidePLStep(
                order: 1,
                title: "売上高 − 売上原価 ＝ 売上総利益（粗利）",
                detail: "売った台数 × 1台あたりの粗利。値引きしすぎ・仕入れが高すぎると、ここが薄くなります。",
                color: GameTheme.teal
            )
            GuidePLStep(
                order: 2,
                title: "粗利 − 販売管理費 ＝ 営業利益",
                detail: "人件費・賃料・広告費・店舗固定費・減価償却・支払利息。台数が増えてもここが重いと黒字になりません。",
                color: GameTheme.orange
            )
            GuidePLStep(
                order: 3,
                title: "営業利益 ≠ 現金",
                detail: "在庫の仕入れは費用ではなく資産の入れ替えです。黒字でも仕入れすぎれば現金は減ります。",
                color: GameTheme.navy
            )
        }
        .gameCard()
    }

    private var numbersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "いまの数字で読む", subtitle: "直近週の損益計算書")
            GuidePLRow(title: "売上高", value: finance.revenue, note: "販売した車両の合計金額")
            GuidePLRow(title: "売上原価", value: -finance.costOfSales, note: "売れた車の仕入れ値", negative: true)
            GuidePLRow(title: "売上総利益（粗利）", value: grossProfit, note: "粗利率 \(Int((grossMargin * 100).rounded()))%", total: true)
            GuidePLRow(title: "人件費", value: -finance.personnel, note: "店員・店長の給与と歩合", negative: true)
            GuidePLRow(title: "賃料", value: -finance.rent, note: "土地・建物の月額を週按分", negative: true)
            GuidePLRow(title: "広告費", value: -finance.advertising, note: "自店が選ばれる確率を上げる投資", negative: true)
            GuidePLRow(title: "店舗・設備固定費", value: -finance.fixedCosts, note: "設備の維持費", negative: true)
            GuidePLRow(title: "減価償却", value: -finance.depreciation, note: "建物・設備の価値の目減り", negative: true)
            GuidePLRow(title: "支払利息", value: -finance.interest, note: "借入金にかかる金利", negative: true)
            if finance.customerClaims > 0 {
                GuidePLRow(title: "販売後補償", value: -finance.customerClaims, note: "納車後の不具合対応", negative: true)
            }
            GuidePLRow(
                title: "営業利益",
                value: finance.operatingProfit,
                note: finance.operatingProfit >= 0 ? "本業で黒字です" : "本業で赤字です",
                total: true,
                negative: finance.operatingProfit < 0
            )
        }
        .gameCard()
    }

    private var diagnosisCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "ナオの見立て", subtitle: "いまの数字から言えること")
            ForEach(diagnoses, id: \.self) { line in
                Label(line, systemImage: "quote.bubble.fill")
                    .font(.caption)
                    .foregroundStyle(GameTheme.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .gameCard()
    }

    private var diagnoses: [String] {
        var lines: [String] = []
        if finance.revenue == 0 {
            lines.append("まだ売上が立っていません。1週間進めると、この表に数字が入ります。")
            return lines
        }
        if grossMargin < 0.10 {
            lines.append("粗利率が\(Int((grossMargin * 100).rounded()))%と薄いです。値引き幅を抑えるか、仕入れ値の低い経路を増やしてください。")
        } else if grossMargin > 0.20 {
            lines.append("粗利率\(Int((grossMargin * 100).rounded()))%は良好です。この水準を保ったまま台数を伸ばせるか試しましょう。")
        }
        if operatingExpenses > grossProfit {
            lines.append("販管費（\(operatingExpenses.currency)）が粗利（\(grossProfit.currency)）を上回っています。台数を増やすか、固定費を見直す局面です。")
        }
        if finance.personnel > 0, grossProfit > 0, Double(finance.personnel) / Double(grossProfit) > 0.5 {
            lines.append("人件費が粗利の半分を超えています。採用した店員に担当を割り当て、自動枠を使い切れているか確認してください。")
        }
        if finance.interest > 0 {
            lines.append("支払利息が\(finance.interest.currency)発生しています。現金に余裕が出たら繰り上げ返済も選択肢です。")
        }
        if lines.isEmpty {
            lines.append("大きな崩れはありません。粗利率と在庫回転を維持したまま、来店数を増やす投資を検討しましょう。")
        }
        return lines
    }
}

private struct GuidePLStep: View {
    let order: Int
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(order)")
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold()).foregroundStyle(GameTheme.ink)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GuidePLRow: View {
    let title: String
    let value: Int
    let note: String
    var total = false
    var negative = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(total ? .subheadline.bold() : .subheadline)
                Spacer()
                Text(value.currency)
                    .font((total ? Font.subheadline.bold() : Font.subheadline).monospacedDigit())
                    .foregroundStyle(negative && value != 0 ? GameTheme.danger : GameTheme.ink)
            }
            Text(note).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, total ? 6 : 2)
        .overlay(alignment: .top) { if total { Divider() } }
    }
}
