import SwiftUI

struct PanelHeader: View {
    let isSyncing: Bool
    let statusLine: String?
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 1) {
                    Text("The Pullfather")
                        .font(Font(Typography.title))
                        .foregroundStyle(Palette.textPrimary)
                    Text("It's not personal. It's just business logic.")
                        .font(Font(Typography.tagline))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .symbolEffect(.rotate, options: .repeat(.continuous), isActive: isSyncing)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.textSecondary)
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh")
            }
            if let statusLine {
                Text(statusLine)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
                    .padding(.leading, 54)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}
