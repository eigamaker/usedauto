import SwiftUI

enum GameTheme {
    static let ink = Color(red: 0.06, green: 0.12, blue: 0.19)
    static let navy = Color(red: 0.08, green: 0.18, blue: 0.28)
    static let teal = Color(red: 0.08, green: 0.55, blue: 0.49)
    static let mint = Color(red: 0.68, green: 0.90, blue: 0.81)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.91)
    static let sand = Color(red: 0.91, green: 0.85, blue: 0.70)
    static let orange = Color(red: 0.94, green: 0.47, blue: 0.19)
    static let danger = Color(red: 0.78, green: 0.20, blue: 0.22)
    static let road = Color(red: 0.30, green: 0.35, blue: 0.38)
}

extension View {
    func gameCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: GameTheme.ink.opacity(0.08), radius: 14, y: 5)
    }
}

struct CapsuleLabel: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct MetricView: View {
    let title: String
    let value: String
    var detail: String? = nil
    var tint: Color = GameTheme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(tint)
            if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.bold()).foregroundStyle(GameTheme.ink)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

