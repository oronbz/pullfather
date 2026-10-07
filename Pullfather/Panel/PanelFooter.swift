import SwiftUI

struct PanelFooter: View {
    let actions: PanelActions
    var failure: String?
    var newerRelease: Release?

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
            if let newerRelease {
                UpdateRow(release: newerRelease, actions: actions)
            }
            FooterRow(title: "Open GitHub", key: "o", action: actions.openGitHub)
            FooterRow(title: "Settings…", key: ",", action: actions.openSettings)
            FooterRow(title: "Quit The Pullfather", key: "q", action: actions.quit)
        }
        .padding(6)
    }
}

private struct UpdateRow: View {
    let release: Release
    let actions: PanelActions
    @State private var isConfirmingCopy = false

    var body: some View {
        FooterRow(title: isConfirmingCopy ? "Copied, paste in Terminal" : "Update to \(release.version)", key: "u") {
            actions.copyUpgradeCommand()
            isConfirmingCopy = true
        }
        .contextMenu {
            Button("View release notes") { actions.openReleaseNotes(release.url) }
        }
        .task(id: isConfirmingCopy) {
            guard isConfirmingCopy else { return }
            try? await Task.sleep(for: .seconds(2))
            isConfirmingCopy = false
        }
    }
}

private struct FooterRow: View {
    let title: String
    var key: Character?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if let key {
                    Text("⌘\(String(key).uppercased())")
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .contentShape(.rect)
            .background(isHovered ? Palette.rowHighlight : .clear, in: .rect(cornerRadius: Noir.rowRadius))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(key.map { KeyboardShortcut(KeyEquivalent($0), modifiers: .command) })
        .onHover { isHovered = $0 }
    }
}
