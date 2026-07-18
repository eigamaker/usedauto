import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var confirmNewGame = false
    @State private var showPlans = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [GameTheme.navy, GameTheme.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle()
                .fill(GameTheme.teal.opacity(0.16))
                .frame(width: 380, height: 380)
                .blur(radius: 8)
                .offset(x: 170, y: -300)

            VStack(spacing: 30) {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(GameTheme.mint)
                    Text("CAR CITY")
                        .font(.system(size: 39, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)
                    Text("中古車店を、自分の判断で育てる。")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                VStack(spacing: 12) {
                    Button {
                        if game.hasSaveData { confirmNewGame = true }
                        else { showPlans = true }
                    } label: {
                        TitleActionLabel(title: "新しいゲーム", icon: "plus", prominent: true)
                    }

                    Button { game.loadGame() } label: {
                        TitleActionLabel(title: "続きから", icon: "arrow.clockwise", prominent: false)
                    }
                    .disabled(!game.hasSaveData)
                    .opacity(game.hasSaveData ? 1 : 0.42)

                    if let summary = game.saveSummary {
                        Text(summary)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.58))
                    } else {
                        Text("セーブデータはありません")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                .frame(maxWidth: 430)

                VStack(spacing: 7) {
                    Text("安く仕入れ、値引きを判断し、1台ずつ商談")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                    Text("店員は対応枠を増やし、店長は委任業務を自動化します")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                    Text("1ターン＝1週間")
                        .font(.caption2.bold())
                        .foregroundStyle(GameTheme.mint.opacity(0.86))
                        .padding(.top, 3)
                }
                Spacer()
            }
            .padding(24)
        }
        .confirmationDialog("新しいゲームを始めますか？", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("セーブデータを上書きして開始", role: .destructive) { showPlans = true }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在のセーブデータは削除されます。")
        }
        .sheet(isPresented: $showPlans) {
            StartupPlanSelectionView { plan in
                showPlans = false
                game.start(plan: plan)
            }
        }
    }
}

private struct StartupPlanSelectionView: View {
    let choose: (StartupPlan) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("最初の勝ち筋を選ぶ")
                        .font(.title2.bold())
                    Text("おすすめ立地・客層・店舗コンセプトが変わります。開始後も方針転換できます。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(StartupPlan.allCases) { plan in
                        Button { choose(plan) } label: {
                            HStack(spacing: 13) {
                                Image(systemName: plan.icon)
                                    .font(.title2)
                                    .foregroundStyle(GameTheme.teal)
                                    .frame(width: 46, height: 46)
                                    .background(GameTheme.teal.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plan.name).font(.headline).foregroundStyle(GameTheme.ink)
                                    Text(plan.tagline).font(.caption).foregroundStyle(.secondary)
                                    Text("\(plan.recommendedDistrict.name)・\(plan.recommendedStoreType.name)・\(plan.recommendedConcept.name)")
                                        .font(.caption2.bold()).foregroundStyle(GameTheme.teal)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .padding(13)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .background(GameTheme.cream)
            .navigationTitle("創業プラン")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TitleActionLabel: View {
    let title: String
    let icon: String
    let prominent: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
        }
        .font(.headline)
        .foregroundStyle(prominent ? GameTheme.ink : .white)
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(prominent ? GameTheme.mint : Color.white.opacity(0.09))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(prominent ? 0 : 0.14)))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
