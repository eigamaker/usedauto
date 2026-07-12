import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var selected: StartupPlan = .family

    var body: some View {
        ZStack {
            LinearGradient(colors: [GameTheme.navy, GameTheme.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle().fill(GameTheme.teal.opacity(0.18)).frame(width: 340).blur(radius: 2).offset(x: 170, y: -310)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "car.side.fill")
                                .font(.title2)
                                .foregroundStyle(GameTheme.mint)
                            Text("CAR CITY").font(.caption.bold()).tracking(3).foregroundStyle(GameTheme.mint)
                        }
                        Text("この街で、\n選ばれる店をつくる。")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("立地、客層、在庫、資金。すべての判断が街と数字を変える中古車経営シミュレーション。")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.72)).lineSpacing(4)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("創業プランを選択").font(.headline).foregroundStyle(.white)
                        ForEach(StartupPlan.allCases) { plan in
                            PlanCard(plan: plan, selected: selected == plan) { selected = plan }
                        }
                    }
                    Button { game.start(plan: selected) } label: {
                        HStack {
                            Text("\(selected.name)で創業")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(GameTheme.ink)
                        .padding(17)
                        .background(GameTheme.mint)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Text("1ターン＝1か月 / 10年間で企業価値を高めよう")
                        .font(.caption).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity)
                }
                .padding(22)
                .padding(.top, 24)
            }
        }
    }
}

private struct PlanCard: View {
    let plan: StartupPlan
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: plan.icon)
                    .font(.title2)
                    .frame(width: 46, height: 46)
                    .foregroundStyle(selected ? GameTheme.ink : .white)
                    .background(selected ? GameTheme.mint : .white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name).font(.headline).foregroundStyle(.white)
                    Text(plan.tagline).font(.caption).foregroundStyle(.white.opacity(0.66))
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? GameTheme.mint : .white.opacity(0.35))
            }
            .padding(14)
            .background(.white.opacity(selected ? 0.13 : 0.06))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(selected ? GameTheme.mint : .white.opacity(0.08), lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
    }
}

