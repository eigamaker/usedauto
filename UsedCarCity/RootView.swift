import SwiftUI

struct RootView: View {
    @EnvironmentObject private var game: GameEngine
    @AppStorage("settings.showTutorialHints") private var showTutorialHints = true
    @State private var isMapExpanded = false

    var body: some View {
        Group {
            if CommandLine.arguments.contains("-demo-national") {
                NationalExpansionView()
            } else if CommandLine.arguments.contains("-demo-auction") {
                FacilityHubSheet(facility: .auction) { _ in }
            } else if CommandLine.arguments.contains("-demo-hq") {
                CompanyDashboardView()
            } else if (CommandLine.arguments.contains("-demo-store") || CommandLine.arguments.contains("-demo-proposal") || CommandLine.arguments.contains("-demo-catalog") || CommandLine.arguments.contains("-demo-tutorial-purchase")), let store = game.stores.first {
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
                .sheet(isPresented: $game.showMonthlyReport) {
                    if let report = game.lastReport { MonthlyReportView(report: report) }
                }
                .sheet(isPresented: $game.gameOver) {
                    GameEndView()
                }
                .overlay(alignment: .top) {
                    if showTutorialHints, let message = game.tutorialMessage {
                        TutorialBanner(message: message) { game.tutorialMessage = nil }
                            .padding(.horizontal, 12)
                            .padding(.top, 78)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
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
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(String(game.year))年 \(game.month)月 第\(game.weekOfMonth)週")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                Text("\(game.turn + 1) / \(game.maxTurns)週")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("現金")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
                Text(game.cash.currency)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(game.cash < 0 ? Color.red.opacity(0.9) : .white)
            }
            Button {
                if confirmWeeklyAdvance { confirmAdvance = true }
                else { game.advanceWeek() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("1週間進める")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .font(.subheadline.bold())
                .foregroundStyle(GameTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(GameTheme.mint)
                .clipShape(Capsule())
                .overlay {
                    if game.tutorialStep == .runFirstMonth {
                        Capsule().stroke(.white, lineWidth: 3)
                    }
                }
                .shadow(color: game.tutorialStep == .runFirstMonth ? GameTheme.mint.opacity(0.7) : .clear, radius: 9)
            }
            .disabled(game.isTutorialActive && game.tutorialStep != .runFirstMonth)
            .opacity(game.isTutorialActive && game.tutorialStep != .runFirstMonth ? 0.48 : 1)
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
        .sheet(isPresented: $showSettings) {
            GameSettingsView()
        }
    }
}

struct TutorialCoachCard: View {
    let step: TutorialStep
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: step.icon)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(GameTheme.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(step == .reviewFirstResult ? "FINAL STEP" : "STEP \(step.number) / 5")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(GameTheme.orange)
                    Text(step.title).font(.subheadline.bold()).foregroundStyle(GameTheme.ink)
                }
                Spacer()
                Text("\(Int(step.progress * 100))%")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: step.progress).tint(GameTheme.orange)
            Text(step.instruction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "scope")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(GameTheme.teal)
            }
        }
        .gameCard(padding: 13)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(GameTheme.orange.opacity(0.55), lineWidth: 1.5)
        }
        .shadow(color: GameTheme.ink.opacity(0.13), radius: 9, y: 4)
    }
}

private struct GameSettingsView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings.confirmWeeklyAdvance") private var confirmWeeklyAdvance = true
    @AppStorage("settings.autoShowWeeklyReport") private var autoShowWeeklyReport = true
    @AppStorage("settings.showTutorialHints") private var showTutorialHints = true
    @State private var confirmRestart = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ゲーム進行") {
                    Toggle("週を進める前に確認", isOn: $confirmWeeklyAdvance)
                    Toggle("週間レポートを自動表示", isOn: $autoShowWeeklyReport)
                    Toggle("チュートリアル案内を表示", isOn: $showTutorialHints)
                }

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
                    dismiss()
                    game.startNewGame()
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

private struct TutorialBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lightbulb.max.fill")
                .foregroundStyle(GameTheme.orange)
            Text(message).font(.subheadline.weight(.medium))
            Spacer(minLength: 6)
            Button(action: dismiss) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
        }
        .gameCard(padding: 13)
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
