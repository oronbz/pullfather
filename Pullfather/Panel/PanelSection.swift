import SwiftUI

struct PanelSection<Row: Identifiable, RowView: View>: View {
    let title: String
    let caption: String?
    let emptyText: String
    let rows: [Row]?
    @ViewBuilder let row: (Row) -> RowView

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(title: title)
                Spacer()
                if let caption {
                    Text(caption)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .padding(.horizontal, 10)
            if let rows {
                if rows.isEmpty {
                    Text(emptyText)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 2) {
                        ForEach(rows, content: row)
                    }
                }
            }
        }
    }
}

struct PanelRow<Content: View>: View {
    let help: String
    let isHighlighted: Bool
    let onHover: (Bool) -> Void
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                content
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(.rect)
            .background(isHighlighted ? Palette.rowHighlight : .clear, in: .rect(cornerRadius: Noir.rowRadius))
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .help(help)
    }
}

struct PullRequestRow<Content: View>: View {
    let id: PanelRowID
    let pullRequest: any ListedPullRequest
    @Binding var selection: PanelRowID?
    let actions: PanelActions
    @ViewBuilder let content: Content

    var body: some View {
        PanelRow(help: pullRequest.title, isHighlighted: selection == id, onHover: pointerMoved, action: { actions.openPullRequest(pullRequest.url) }) {
            content
        }
        .id(id)
        .contextMenu {
            Button("Copy link") { actions.copyLink(pullRequest.url) }
            Button("Open repository") { actions.openRepository(pullRequest.repositoryURL) }
        }
    }

    private func pointerMoved(isInside: Bool) {
        let pointerEvents: [NSEvent.EventType] = [.mouseMoved, .mouseEntered, .mouseExited, .scrollWheel]
        guard let type = NSApp.currentEvent?.type, pointerEvents.contains(type) else { return }
        if isInside {
            selection = id
        } else if selection == id {
            selection = nil
        }
    }
}

struct RowText: View {
    let title: String
    let metadata: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textPrimary)
            Text(metadata)
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textSecondary)
        }
        .lineLimit(1)
    }
}
