import SwiftUI

struct PanelFooter: View {
    let actions: PanelActions
    var failure: String?

    var body: some View {
        VStack(spacing: 0) {
            if let failure {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.amber)
                    Text(failure)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 11.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            FooterRow(title: "Open GitHub", key: "o", action: actions.openGitHub)
            FooterRow(title: "Settings…", key: ",", action: actions.openSettings)
            FooterRow(title: "Quit The Pullfather", key: "q", action: actions.quit)
        }
        .padding(6)
    }
}

private struct FooterRow: View {
    let title: String
    let key: Character
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("⌘\(String(key).uppercased())")
                    .foregroundStyle(Palette.textMuted)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .contentShape(.rect)
            .background(isHovered ? Palette.rowHighlight : .clear, in: .rect(cornerRadius: Noir.rowRadius))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(key), modifiers: .command)
        .onHover { isHovered = $0 }
    }
}
