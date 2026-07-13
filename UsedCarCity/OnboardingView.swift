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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最初の経営体験").font(.headline).foregroundStyle(.white)
                        HStack(alignment: .top, spacing: 8) {
                            TutorialFlowItem(number: 1, icon: "mappin.and.ellipse", title: "立地")
                            TutorialFlowArrow()
                            TutorialFlowItem(number: 2, icon: "hammer.fill", title: "出店")
                            TutorialFlowArrow()
                            TutorialFlowItem(number: 3, icon: "car.2.fill", title: "仕入")
                            TutorialFlowArrow()
                            TutorialFlowItem(number: 4, icon: "chart.bar.fill", title: "販売")
                        }
                        Text("次の画面では完成済みの店は用意されていません。街を見て、最初の店舗を置く土地から自分で選びます。")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                            .lineSpacing(3)
                    }
                    .padding(15)
                    .background(.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    Button { game.start(plan: selected) } label: {
                        HStack {
                            Text("マップで創業地を選ぶ")
                            Spacer()
                            Image(systemName: "map.fill")
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

private struct TutorialFlowItem: View {
    let number: Int
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .frame(width: 36, height: 36)
                    .foregroundStyle(GameTheme.mint)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
                Text("\(number)")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(GameTheme.ink)
                    .frame(width: 15, height: 15)
                    .background(GameTheme.mint)
                    .clipShape(Circle())
            }
            Text(title).font(.caption2.bold()).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TutorialFlowArrow: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.bold())
            .foregroundStyle(.white.opacity(0.35))
            .padding(.top, 13)
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
