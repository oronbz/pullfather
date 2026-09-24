import SwiftUI

struct PanelView: View {
    let store: SyncStore
    let actions: PanelActions
    var onHeightChange: (CGFloat) -> Void = { _ in }
    private let cornerRadius: CGFloat = 12
    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                PanelHeader(isSyncing: store.isSyncing, refresh: { store.requestSync() })
                Hairline()
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { headerHeight = $0 }
            switch store.account.state {
            case .signedOut:
                SignInCard(account: store.account)
            case .signedIn:
                ScrollView {
                    VStack(spacing: 16) {
                        BusinessSection(rows: store.business, open: actions.openPullRequest)
                        FamilySection(rows: store.family, open: actions.openPullRequest)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
                }
                .frame(height: min(contentHeight, PanelPlacement.maxHeight - headerHeight - footerHeight))
            }
            VStack(spacing: 0) {
                Hairline()
                PanelFooter(actions: actions)
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { footerHeight = $0 }
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

#if DEBUG
#Preview("Signed out") {
    PanelView(
        store: SyncStore(account: .preview(signedIn: false), preferences: .preview),
        actions: PanelActions(openPullRequest: { _ in }, openGitHub: {}, openSettings: {}, quit: {})
    )
}

#Preview("Business and Family") {
    PanelView(
        store: .preview(business: BusinessRow.previews, family: FamilyRow.previews),
        actions: PanelActions(openPullRequest: { _ in }, openGitHub: {}, openSettings: {}, quit: {})
    )
}

#Preview("Empty") {
    PanelView(
        store: .preview(business: [], family: []),
        actions: PanelActions(openPullRequest: { _ in }, openGitHub: {}, openSettings: {}, quit: {})
    )
}
#endif
