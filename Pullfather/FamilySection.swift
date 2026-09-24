import SwiftUI

struct FamilySection: View {
    let rows: [FamilyRow]?
    let open: (URL) -> Void

    var body: some View {
        PanelSection(
            title: "Family",
            caption: "Your pull requests",
            emptyText: "No family business today.",
            rows: rows
        ) { row in
            PanelRow(help: row.title, action: { open(row.url) }) {
                RowText(title: row.title, metadata: row.metadata)
                Spacer(minLength: 8)
                if row.isDraft {
                    ReviewBadge(title: "Draft", color: Palette.textMuted)
                } else if let reviewState = row.reviewState {
                    ReviewBadge(reviewState: reviewState)
                }
                if let checks = row.checks {
                    ChecksIcon(checks: checks)
                }
            }
        }
    }
}

private struct ReviewBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: .capsule)
            .fixedSize()
    }

}

extension ReviewBadge {
    init(reviewState: ReviewState) {
        switch reviewState {
        case .approved: self.init(title: "Approved", color: Palette.checksPassing)
        case .changesRequested: self.init(title: "Changes requested", color: Palette.amber)
        }
    }
}

#if DEBUG
#Preview("Family") {
    FamilySection(rows: FamilyRow.previews, open: { _ in })
        .padding(6)
        .frame(width: PanelPlacement.width)
        .background(Palette.surface)
        .environment(\.colorScheme, .dark)
}

#Preview("Empty") {
    FamilySection(rows: [], open: { _ in })
        .padding(6)
        .frame(width: PanelPlacement.width)
        .background(Palette.surface)
        .environment(\.colorScheme, .dark)
}
#endif
