import SwiftUI

struct PanelView: View {
    let actions: PanelActions
    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader()
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 1)
                .padding(.horizontal, 16)
            PanelFooter(actions: actions)
        }
        .frame(width: PanelPlacement.width)
        .background(Palette.surface, in: .rect(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Palette.hairline)
        }
    }
}

#Preview {
    PanelView(actions: PanelActions(openGitHub: {}, openSettings: {}, quit: {}))
}
