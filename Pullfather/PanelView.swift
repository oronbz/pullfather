import SwiftUI

struct PanelView: View {
    let account: Account
    let actions: PanelActions
    var onHeightChange: (CGFloat) -> Void = { _ in }
    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader()
            Hairline()
            switch account.state {
            case .signedOut:
                SignInCard(account: account)
            case .signedIn(let login):
                SignedInLine(login: login)
            }
            Hairline()
            PanelFooter(actions: actions)
        }
        .frame(width: PanelPlacement.width)
        .background(Palette.surface, in: .rect(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Palette.hairline)
        }
        .environment(\.colorScheme, .dark)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { onHeightChange($0) }
    }
}

private struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

#Preview {
    PanelView(
        account: .preview(signedIn: false),
        actions: PanelActions(openGitHub: {}, openSettings: {}, quit: {})
    )
}
