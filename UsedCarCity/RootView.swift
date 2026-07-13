import SwiftUI

struct RootView: View {
    @EnvironmentObject private var game: GameEngine

    var body: some View {
        Group {
            if CommandLine.arguments.contains("-demo-national") {
                NationalExpansionView()
            } else if CommandLine.arguments.contains("-demo-auction") {
                FacilityHubSheet(facility: .auction) { _ in }
            } else if CommandLine.arguments.contains("-demo-hq") {
                FacilityHubSheet(facility: .headquarters) { _ in }
            } else if (CommandLine.arguments.contains("-demo-store") || CommandLine.arguments.contains("-demo-tutorial-purchase")), let store = game.stores.first {
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
                        GameHeader()
                        CityMapView()
                    }
                }
                .sheet(isPresented: $game.showMonthlyReport) {
                    if let report = game.lastReport { MonthlyReportView(report: report) }
                }
                .sheet(isPresented: $game.gameOver) {
                    GameEndView()
                }
                .overlay(alignment: .top) {
                    if let message = game.tutorialMessage {
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
    }
}

private struct GameHeader: View {
    @EnvironmentObject private var game: GameEngine
    @State private var confirmAdvance = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(String(game.year))年 \(game.month)月")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                Text("\(game.turn + 1) / 120か月")
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
            Button { confirmAdvance = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("月を進める")
                }
                .font(.subheadline.bold())
                .foregroundStyle(GameTheme.ink)
                .padding(.horizontal, 13)
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
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(GameTheme.navy)
        .confirmationDialog("設定した方針で1か月進めますか？", isPresented: $confirmAdvance, titleVisibility: .visible) {
            Button("\(game.year)年\(game.month)月を実行") { game.advanceMonth() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("仕入・価格・広告など、現在の設定を使って販売結果を計算します。")
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
