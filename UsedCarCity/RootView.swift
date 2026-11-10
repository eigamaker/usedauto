import SwiftUI

struct RootView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var isMapExpanded = false

    var body: some View {
        Group {
            if CommandLine.arguments.contains("-demo-competition") {
                CompetitionDemoView()
            } else if CommandLine.arguments.contains("-demo-ending") {
                GameEndView()
            } else if CommandLine.arguments.contains("-demo-goals") {
                ManagementView()
            } else if CommandLine.arguments.contains("-demo-national") {
                NationalExpansionView()
            } else if CommandLine.arguments.contains("-demo-hq") {
                CompanyDashboardView()
            } else if (CommandLine.arguments.contains("-demo-store") || CommandLine.arguments.contains("-demo-team") || CommandLine.arguments.contains("-demo-finance") || CommandLine.arguments.contains("-demo-proposal") || CommandLine.arguments.contains("-demo-catalog") || CommandLine.arguments.contains("-demo-tutorial-purchase")), let store = game.stores.first {
                NavigationStack {
                    ScrollView {
                        StoreCommandCenterView(storeID: store.id)
                            .padding(15)
                    }
                    .background(GameTheme.cream)
                    .navigationTitle("店舗経営")
                    .navigationBarTitleDisplayMode(.inline)
                }
            } else if game.hasStarted {
                ZStack(alignment: .top) {
                    GameTheme.hudBottom.ignoresSafeArea()
                    VStack(spacing: 0) {
                        if !isMapExpanded {
                            GameHeader()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        CityMapView(isExpanded: $isMapExpanded)
                    }
                }
                .sheet(
                    item: $game.weeklyPresentationStage,
                    onDismiss: game.advanceWeeklyPresentationSequence
                ) { stage in
                    switch stage {
                    case .weeklyReport:
                        if let report = game.lastReport {
                            MonthlyReportView(report: report)
                        }
                    case .monthlyPL:
                        if let report = game.lastMonthlyReport {
                            MonthlyPLDashboardView(report: report)
                        }
                    case .newspaper:
                        MarketNewspaperView()
                    }
                }
                .sheet(isPresented: $game.gameOver) {
                    GameEndView()
                }
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: game.hasStarted)
        .animation(.easeInOut(duration: 0.22), value: isMapExpanded)
        .onChange(of: game.hasStarted) { _, hasStarted in
            if !hasStarted { isMapExpanded = false }
        }
    }
}

private struct GameHeader: View {
    @EnvironmentObject private var game: GameEngine
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white)
                    VStack(spacing: 0) {
                        Rectangle().fill(GameTheme.danger).frame(height: 9)
                        Text("\(game.month)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(GameTheme.ink)
                            .frame(maxHeight: .infinity)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(GameTheme.hudEdge, lineWidth: 1.5)
                }
                .frame(width: 30, height: 32)
                VStack(alignment: .leading, spacing: -1) {
                    Text("\(String(game.year))年")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(GameTheme.gold.opacity(0.9))
                    Text("\(game.month)月 第\(game.weekOfMonth)週")
                        .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(game.year)年\(game.month)月第\(game.weekOfMonth)週")

            Spacer(minLength: 4)

            HUDResourceChip(
                title: "現金",
                value: game.cash.currency,
                valueColor: game.cash < 0 ? Color(red: 1, green: 0.55, blue: 0.5) : .white
            ) {
                GameCoinIcon(size: 30)
            }

            Button { showSettings = true } label: {
                GameIconTile(title: "ゲーム設定", icon: "gearshape.fill", size: 38, showsTitle: false)
            }
            .buttonStyle(.gamePress)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 9)
        .background(
            GameTheme.hudGradient
                .overlay(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Rectangle().fill(GameTheme.gold).frame(height: 2)
                        Rectangle().fill(GameTheme.hudEdge).frame(height: 2)
                    }
                }
                .ignoresSafeArea(edges: .top)
        )
        .sheet(isPresented: $showSettings) {
            GameSettingsView()
        }
    }
}

/// マップ右下に常駐する「1週間進める」ボタン。ターン制ゲームの主操作です。
struct AdvanceWeekButton: View {
    @EnvironmentObject private var game: GameEngine
    @AppStorage("settings.confirmWeeklyAdvance") private var confirmWeeklyAdvance = true
    @State private var confirmAdvance = false
    @State private var warnBeforeFirstStore = false
    @State private var pulse = false

    /// ガイドが「1週間進める」を案内している最中だけ、ボタンを目立たせます。
    private var highlightsAdvance: Bool {
        game.currentGuideLesson?.id == .advanceWeek || game.tutorialStep == .runFirstMonth
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button(action: advanceWeek) {
            HStack(spacing: 7) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 17, weight: .black))
                VStack(alignment: .leading, spacing: -1) {
                    Text("NEXT WEEK")
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("1週間進める")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .shadow(color: GameTheme.goDark, radius: 0, y: 1.5)
            .padding(.horizontal, 15)
            .frame(height: 50)
            .background {
                ZStack {
                    shape.fill(GameTheme.goDark).offset(y: 5)
                    shape.stroke(GameTheme.hudEdge, lineWidth: 1.5).offset(y: 5)
                    shape.fill(GameTheme.go)
                    shape.fill(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.02), .black.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    shape.strokeBorder(GameTheme.hudEdge, lineWidth: 1.5)
                    shape.strokeBorder(.white.opacity(0.35), lineWidth: 1).padding(1.5)
                }
            }
            .overlay {
                if highlightsAdvance {
                    shape.stroke(GameTheme.gold, lineWidth: 4)
                        .scaleEffect(pulse ? 1.10 : 1.0)
                        .opacity(pulse ? 0.25 : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { pulse = true }
                        .onDisappear { pulse = false }
                }
            }
            .padding(.bottom, 5)
        }
        .buttonStyle(.gamePress)
        .accessibilityLabel("1週間進める")
        .accessibilityHint("現在の方針で1週間進みます")
        .confirmationDialog("現在の方針で1週間進めますか？", isPresented: $confirmAdvance, titleVisibility: .visible) {
            Button("\(game.year)年\(game.month)月 第\(game.weekOfMonth)週を実行") { game.advanceWeek() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("仕入・価格・広告など、現在の設定を使って販売結果を計算します。")
        }
        .confirmationDialog("まだ店舗がありません", isPresented: $warnBeforeFirstStore, titleVisibility: .visible) {
            Button("それでも1週間進める") { game.advanceWeek() }
            Button("先に創業する", role: .cancel) {}
        } message: {
            Text("店舗がない状態で週を進めると、売上のないまま1週間が過ぎます。マップで区画を選んで創業できます。")
        }
    }

    private func advanceWeek() {
        if game.stores.isEmpty { warnBeforeFirstStore = true }
        else if confirmWeeklyAdvance { confirmAdvance = true }
        else { game.advanceWeek() }
    }
}

private struct GameSettingsView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings.confirmWeeklyAdvance") private var confirmWeeklyAdvance = true
    @AppStorage("settings.autoShowWeeklyReport") private var autoShowWeeklyReport = true
    @State private var confirmRestart = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ゲーム進行") {
                    Toggle("週を進める前に確認", isOn: $confirmWeeklyAdvance)
                    Toggle("週間レポートを自動表示", isOn: $autoShowWeeklyReport)
                }

                GuideSettingsSection()

                Section("現在のゲーム") {
                    LabeledContent("日時", value: "\(game.year)年\(game.month)月 第\(game.weekOfMonth)週")
                    LabeledContent("経過", value: "\(game.turn)週間")
                    LabeledContent("現金", value: game.cash.currency)
                    Button {
                        dismiss()
                        game.returnToTitle()
                    } label: {
                        Label("セーブしてタイトルへ戻る", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section {
                    Button(role: .destructive) { confirmRestart = true } label: {
                        Label("ゲームを最初からやり直す", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("セーブを削除してタイトルへ", systemImage: "trash")
                    }
                } header: {
                    Text("セーブデータ")
                } footer: {
                    Text("やり直すと現在の進行状況は上書きされます。")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .confirmationDialog("最初からやり直しますか？", isPresented: $confirmRestart, titleVisibility: .visible) {
                Button("新しいゲームを開始", role: .destructive) {
                    let mode = game.guide.mode
                    dismiss()
                    game.startNewGame()
                    game.beginGuide(mode: mode)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("現在のセーブデータは上書きされます。")
            }
            .confirmationDialog("セーブデータを削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除してタイトルへ", role: .destructive) {
                    dismiss()
                    game.resetGame()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}

extension Int {
    var currency: String {
        let sign = self < 0 ? "−" : ""
        let value = abs(self)
        if value >= 10_000 {
            let oku = Double(value) / 10_000
            return String(format: "%@%.2f億円", sign, oku)
        }
        return "\(sign)\(value.formatted())万円"
    }
}
