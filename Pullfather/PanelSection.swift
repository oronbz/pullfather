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
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                content
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(.rect)
            .background(isHovered ? Palette.rowHighlight : .clear, in: .rect(cornerRadius: Noir.rowRadius))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
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
