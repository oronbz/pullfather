import SwiftUI

struct BusinessSection: View {
    let rows: [BusinessRow]?
    let open: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(title: "Business")
                Spacer()
                if let rows, !rows.isEmpty {
                    Text("\(rows.count) awaiting your review")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .padding(.horizontal, 10)
            if let rows {
                if rows.isEmpty {
                    Text("No favors asked. Enjoy the cannoli.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 2) {
                        ForEach(rows) { row in
                            BusinessRowView(row: row) { open(row.url) }
                        }
                    }
                }
            }
        }
    }
}

private struct BusinessRowView: View {
    let row: BusinessRow
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                InitialsAvatar(login: row.author)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textPrimary)
                    Text(row.metadata)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textSecondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(.rect)
            .background(isHovered ? Palette.rowHighlight : .clear, in: .rect(cornerRadius: Noir.rowRadius))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(row.title)
    }
}

struct InitialsAvatar: View {
    private static let colors: [Color] = [
        Color(hex: 0x4A3B5E), Color(hex: 0x2F4A4A), Color(hex: 0x5C3A2C),
        Color(hex: 0x3B4A2F), Color(hex: 0x5A2F3A), Color(hex: 0x2F3B5A),
    ]

    let login: String

    var body: some View {
        Text(Self.initials(of: login))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette.bone)
            .frame(width: 30, height: 30)
            .background(Self.color(for: login), in: .circle)
    }

    static func initials(of login: String) -> String {
        let parts = login.split(whereSeparator: { "-_.".contains($0) })
        let letters = parts.count > 1 ? parts.prefix(2).compactMap(\.first) : Array(login.prefix(2))
        return String(letters).uppercased()
    }

    private static func color(for login: String) -> Color {
        let hash = login.utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
        return colors[Int(hash % UInt32(colors.count))]
    }
}

#if DEBUG
#Preview("Business") {
    BusinessSection(rows: BusinessRow.previews, open: { _ in })
        .padding(6)
        .frame(width: PanelPlacement.width)
        .background(Palette.surface)
        .environment(\.colorScheme, .dark)
}

#Preview("Empty") {
    BusinessSection(rows: [], open: { _ in })
        .padding(6)
        .frame(width: PanelPlacement.width)
        .background(Palette.surface)
        .environment(\.colorScheme, .dark)
}
#endif
