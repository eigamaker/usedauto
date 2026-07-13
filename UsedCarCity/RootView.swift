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
            } else if CommandLine.arguments.contains("-demo-store"), let store = game.stores.first {
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
            }
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
