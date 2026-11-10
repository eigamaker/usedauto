import SwiftUI

struct BuildStoreView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    let plot: LandPlot
    @State private var mode: AcquisitionMode = .lease
    @State private var type: StoreType = .small
    @State private var facilities: Set<StoreFacility> = []
    @State private var loan = 0
    @State private var completed = false
    @State private var foundingBuildCompleted = false

    private var footprint: [LandPlot] { game.footprintPlots(startingAt: plot, type: type, mode: mode) }
    private var availableTypes: [StoreType] {
        [.small, .standard].filter {
            game.footprintPlots(startingAt: plot, type: $0, mode: mode).count == $0.requiredGridCells
        }
    }
    private var landCost: Int { landCost(for: mode) }
    /// 選択中かどうかに関わらず、その取得方法を選んだ場合の土地費用。
    private func landCost(for mode: AcquisitionMode) -> Int {
        game.landAcquisitionCost(
            for: game.footprintPlots(startingAt: plot, type: type, mode: mode),
            mode: mode
        )
    }
    private var shortfall: Int { max(0, total - game.cash - loan) }
    private var demolitionCost: Int { game.demolitionCost(for: footprint) }
    private var total: Int { game.totalBuildCost(for: footprint, type: type, mode: mode, facilities: facilities) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GuideInlineCard(showing: [.planStore])
                        acquisitionSection
                        storeTypeSection
                        facilitiesSection
                        financingSection
                    }
                    .padding(18)
                }
                VStack(spacing: 6) {
                    if shortfall > 0 {
                        Label("資金が \(shortfall.currency) 足りません。下の「新規調達」で借入を増やしてください", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(GameTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button {
                        completeBuild()
                    } label: {
                        Label("契約して出店（\(total.currency)）", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.gamePrimary)
                    .controlSize(.large)
                    .tint(GameTheme.go)
                    .disabled(shortfall > 0 || footprint.count != type.requiredGridCells)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(GameTheme.panel)
                .overlay(alignment: .top) { Rectangle().fill(GameTheme.panelEdge.opacity(0.5)).frame(height: 1.5) }
            }
            .background(GameTheme.cream)
            .navigationTitle("出店計画")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .alert(foundingBuildCompleted ? "創業店がオープンしました" : "新店舗の建設を開始しました", isPresented: $completed) {
                Button(foundingBuildCompleted ? "店舗を開く" : "閉じる") { dismiss() }
            } message: {
                if foundingBuildCompleted {
                    Text("既存建物を解体し、\(footprintDescription)に\(type.name)を開業しました。在庫はまだ0台です。")
                } else {
                    Text("\(footprintDescription)の既存建物を解体し、\(type.name)を着工しました。完成まで\(type.constructionMonths)週間です。")
                }
            }
            .onAppear {
                type = availableTypes.contains(.small) ? .small : (availableTypes.first ?? type)
                ensureCompatibleStoreType()
            }
            .onChange(of: mode) { _, _ in
                if !availableTypes.contains(type), let fallback = availableTypes.first {
                    type = fallback
                }
            }
            .onChange(of: type) { _, _ in
                facilities.removeAll()
            }
        }
    }

    private var acquisitionSection: some View {
        VStack(spacing: 12) {
            SectionTitle(title: "物件取得と解体")
            HStack(spacing: 10) {
                Image(systemName: plot.structure.icon).foregroundStyle(plot.district.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("現在：\(structureText)").font(.subheadline.bold())
                    Text("\(type.name)は\(footprintDescription)を使用します").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .gameCard()
            ChoiceCard(title: "借地", subtitle: "\(footprintDescription)分の保証金 \(landCost(for: .lease).currency)・建替え可能", icon: "key.fill", selected: mode == .lease) { mode = .lease }
            ChoiceCard(title: "購入", subtitle: "\(footprintDescription)合計 \(landCost(for: .purchase).currency)・土地を資産保有", icon: "building.columns.fill", selected: mode == .purchase) { mode = .purchase }
            Label("解体費 \(demolitionCost.currency) は初期投資に含まれます", systemImage: "hammer.fill")
                .font(.subheadline.bold()).foregroundStyle(GameTheme.orange)
            Text(mode == .purchase ? "多額の現金を使いますが、土地を資産として保有し融資枠を広げられます。" : "初期資金を守りながら出店でき、撤退もしやすい一方、毎月の賃料が利益を圧迫します。")
                .font(.subheadline).foregroundStyle(.secondary).gameCard()
        }
    }

    private var storeTypeSection: some View {
        VStack(spacing: 10) {
            SectionTitle(title: "店舗の広さ")
            ForEach(availableTypes) { item in
                ChoiceCard(
                    title: footprintDescription(for: item),
                    subtitle: "\(item.name)・展示\(item.capacity)台・工期\(item.constructionMonths)週間・建設 \(item.buildCost.currency)",
                    icon: item.icon,
                    gridCells: item.requiredGridCells,
                    selected: type == item
                ) {
                    type = item
                }
            }
        }
    }

    private var facilitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                title: "店舗施設",
                subtitle: type.requiredGridCells == 1
                    ? "1区画では整備工場を追加できます"
                    : "施設を1つ追加できます"
            )
            VStack(alignment: .leading, spacing: 10) {
                ForEach(compatibleFacilities) { facility in
                    Button {
                        facilities = facilities.contains(facility) ? [] : [facility]
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: facility.icon).foregroundStyle(GameTheme.teal).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(facility.name).font(.subheadline.bold())
                                Text("設置 \(facility.installationCost.currency)・月\(facility.monthlyCost.currency)　\(facility.summary)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: facilities.contains(facility) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(facilities.contains(facility) ? GameTheme.teal : .gray)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .gameCard()
        }
    }

    private var financingSection: some View {
        VStack(spacing: 14) {
            SectionTitle(title: "資金計画", subtitle: "足りない分は融資でまかなえます")
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MetricView(title: "初期投資額", value: total.currency)
                    MetricView(title: "手元の現金", value: game.cash.currency)
                    MetricView(
                        title: "契約後の現金",
                        value: (game.cash + loan - total).currency,
                        tint: shortfall > 0 ? GameTheme.danger : GameTheme.teal
                    )
                }
                Stepper(value: $loan, in: 0...max(0, game.borrowingLimit - game.debt), step: 1_000) {
                    MetricView(title: "新規調達", value: loan.currency, tint: GameTheme.teal)
                }
            }
            .gameCard()
        }
    }

    private func completeBuild() {
        let isFounding = game.stores.isEmpty
        if game.buildStore(on: plot, type: type, mode: mode, facilities: facilities, loanAmount: loan) {
            foundingBuildCompleted = isFounding
            completed = true
        }
    }

    private func ensureCompatibleStoreType() {
        if !availableTypes.contains(type), let fallback = availableTypes.first {
            type = fallback
        }
    }

    private var structureText: String {
        plot.structure == .vacant ? "なし" : plot.structure.name
    }

    private var footprintDescription: String {
        footprintDescription(for: type)
    }

    private func footprintDescription(for type: StoreType) -> String {
        type.requiredGridCells == 1 ? "1区画" : "\(type.requiredGridCells)区画連結"
    }

    private var compatibleFacilities: [StoreFacility] {
        StoreFacility.allCases.filter { $0.minimumGridCells <= type.requiredGridCells }
    }

}

private struct ChoiceCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var gridCells: Int? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if let gridCells {
                        IsometricFootprintIcon(cells: gridCells, selected: selected)
                    } else {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(selected ? .white : GameTheme.teal)
                    }
                }
                .frame(width: 48, height: 42)
                .background(selected ? GameTheme.teal : GameTheme.teal.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(GameTheme.ink); Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? GameTheme.teal : .gray.opacity(0.4))
            }
            .padding(13).background(.white).overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? GameTheme.teal : .clear, lineWidth: 2)).clipShape(RoundedRectangle(cornerRadius: 15)).shadow(color: .black.opacity(0.04), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct IsometricFootprintIcon: View {
    let cells: Int
    let selected: Bool

    var body: some View {
        ZStack {
            ForEach(0..<cells, id: \.self) { index in
                IsometricCellShape()
                    .fill(selected ? Color.white.opacity(0.96) : GameTheme.teal.opacity(0.88))
                    .overlay {
                        IsometricCellShape().stroke(selected ? GameTheme.teal.opacity(0.45) : Color.white.opacity(0.92), lineWidth: 1)
                    }
                    .frame(width: 22, height: 13)
                    .offset(
                        x: (CGFloat(index) - CGFloat(cells - 1) / 2) * 9,
                        y: (CGFloat(index) - CGFloat(cells - 1) / 2) * 5
                    )
            }
        }
        .accessibilityLabel("\(cells)区画を使用")
    }
}

private struct IsometricCellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
