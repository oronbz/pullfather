import SwiftUI

struct PanelHeader: View {
    var body: some View {
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
            Button {} label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.textSecondary)
            .help("Refresh")
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}
