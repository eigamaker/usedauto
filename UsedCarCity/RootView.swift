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
            } else if (CommandLine.arguments.contains("-demo-store") || CommandLine.arguments.contains("-demo-team") || CommandLine.arguments.contains("-demo-proposal") || CommandLine.arguments.contains("-demo-catalog") || CommandLine.arguments.contains("-demo-tutorial-purchase")), let store = game.stores.first {
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
                    GameTheme.cream.ignoresSafeArea()
                    VStack(spacing: 0) {
                        if !isMapExpanded {
                            GameHeader()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        CityMapView(isExpanded: $isMapExpanded)
                    }
                }
                .sheet(isPresented: $game.showWeeklyReport) {
                    if let report = game.lastReport { MonthlyReportView(report: report) }
                }
                .sheet(isPresented: $game.showMonthlyReport) {
                    if let report = game.lastMonthlyReport { MonthlyPLDashboardView(report: report) }
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
    @AppStorage("settings.confirmWeeklyAdvance") private var confirmWeeklyAdvance = true
    @State private var confirmAdvance = false
    @State private var warnBeforeFirstStore = false
    @State private var showSettings = false

    /// ガイドが「1週間進める」を案内している最中だけ、日付ボタンを目立たせます。
    private var highlightsAdvance: Bool {
        game.currentGuideLesson?.id == .advanceWeek || game.tutorialStep == .runFirstMonth
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: advanceWeek) {
                Text("\(String(game.year))年\(game.month)月第\(game.weekOfMonth)週")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(GameTheme.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 11)
                    .frame(height: 40)
                    .background(GameTheme.mint)
                    .clipShape(Capsule())
                    .overlay {
                        if highlightsAdvance {
                            Capsule().stroke(.white, lineWidth: 3)
                        }
                    }
                    .shadow(color: highlightsAdvance ? GameTheme.mint.opacity(0.7) : .clear, radius: 9)
            }
            .buttonStyle(.plain)
            .accessibilityHint("タップすると1週間進みます")
            .layoutPriority(1)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("現金")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
                Text(game.cash.currency)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(game.cash < 0 ? Color.red.opacity(0.9) : .white)
            }
            Button { showSettings = true } label: {
                VStack(spacing: 2) {
                    Image(systemName: "gearshape.fill")
                        .font(.subheadline.bold())
                    Text("設定")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(width: 34, height: 40)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("ゲーム設定")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(GameTheme.navy)
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
        .sheet(isPresented: $showSettings) {
            GameSettingsView()
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
