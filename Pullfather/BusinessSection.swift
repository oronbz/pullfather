import SwiftUI

struct BusinessSection: View {
    let rows: [BusinessRow]?
    let syncedAt: Date?
    let avatars: AvatarCache
    @Binding var selection: PanelRowID?
    let actions: PanelActions

    var body: some View {
        PanelSection(
            title: "Business",
            caption: rows.flatMap { $0.isEmpty ? nil : "\($0.count) awaiting your review" },
            emptyText: "No favors asked. Enjoy the cannoli.",
            rows: rows
        ) { row in
            PullRequestRow(id: .business(row.id), pullRequest: row, selection: $selection, actions: actions) {
                AuthorAvatar(login: row.author, url: row.avatarURL, syncedAt: syncedAt, avatars: avatars)
                RowText(title: row.title, metadata: row.metadata)
                Spacer(minLength: 8)
                if let checks = row.checks {
                    ChecksIcon(checks: checks)
                }
            }
        }
    }
}

struct AuthorAvatar: View {
    let login: String
    let url: URL?
    let syncedAt: Date?
    let avatars: AvatarCache

    var body: some View {
        Group {
            if let image = url.flatMap(avatars.image(for:)) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: InitialsAvatar.size, height: InitialsAvatar.size)
                    .clipShape(.circle)
            } else {
                InitialsAvatar(login: login)
            }
        }
        .task(id: url) { load() }
        .onChange(of: syncedAt) { load() }
    }

    private func load() {
        if let url {
            avatars.load(url)
        }
    }
}

struct InitialsAvatar: View {
    static let size: CGFloat = 30

    private static let colors: [Color] = [
        Color(hex: 0x4A3B5E), Color(hex: 0x2F4A4A), Color(hex: 0x5C3A2C),
        Color(hex: 0x3B4A2F), Color(hex: 0x5A2F3A), Color(hex: 0x2F3B5A),
    ]

    let login: String

    var body: some View {
        Text(Self.initials(of: login))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Palette.bone)
            .frame(width: Self.size, height: Self.size)
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
    BusinessSection(rows: BusinessRow.previews, syncedAt: nil, avatars: .preview, selection: .constant(.business("2")), actions: .preview)
        .padding(6)
        .frame(width: PanelPlacement.width)
        .background(Palette.surface)
        .environment(\.colorScheme, .dark)
}

#Preview("Empty") {
    BusinessSection(rows: [], syncedAt: nil, avatars: .preview, selection: .constant(nil), actions: .preview)
        .padding(6)
        .frame(width: PanelPlacement.width)
        .background(Palette.surface)
        .environment(\.colorScheme, .dark)
}
#endif
