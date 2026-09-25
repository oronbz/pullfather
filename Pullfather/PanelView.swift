import SwiftUI

struct PanelView: View {
    let store: SyncStore
    let avatars: AvatarCache
    let actions: PanelActions
    var onHeightChange: (CGFloat) -> Void = { _ in }
    private let cornerRadius: CGFloat = 12
    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var isSigningInAgain = false
    @State private var pointedRow: PanelRowID?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 15)) { _ in
                    PanelHeader(isSyncing: store.isSyncing, statusLine: store.statusLine, refresh: { store.requestSync() })
                }
                Hairline()
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { headerHeight = $0 }
            switch store.account.state {
            case .signedOut:
                SignInCard(account: store.account)
            case .signedIn where store.needsSignInAgain && isSigningInAgain:
                SignInCard(
                    account: store.account,
                    message: "GitHub no longer accepts your token. Paste a new one to get back to business.",
                    onSignedIn: { isSigningInAgain = false }
                )
            case .signedIn where store.needsSignInAgain:
                SignInAgainRow { isSigningInAgain = true }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
            case .signedIn:
                ScrollViewReader { scroller in
                    ScrollView {
                        VStack(spacing: 16) {
                            BusinessSection(rows: store.business, syncedAt: store.lastSyncedAt, avatars: avatars, selection: selection, actions: actions)
                            FamilySection(rows: store.family, selection: selection, actions: actions)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 10)
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
                    }
                    .frame(height: min(contentHeight, PanelPlacement.maxHeight - headerHeight - footerHeight))
                    .onChange(of: store.selection) {
                        if let selection = store.selection, selection != pointedRow {
                            scroller.scrollTo(selection)
                        }
                    }
                }
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
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { onHeightChange($0) }
        .onChange(of: store.needsSignInAgain) { isSigningInAgain = false }
    }

    private var selection: Binding<PanelRowID?> {
        Binding(get: { store.selection }, set: { row in
            pointedRow = row
            store.select(row)
        })
    }
}

private struct SignInAgainRow: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        PanelRow(help: "Sign in again", isHighlighted: isHovered, onHover: { isHovered = $0 }, action: action) {
            Image(systemName: "key.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.amber)
                .frame(width: 30, height: 30)
            RowText(title: "Sign in again", metadata: "GitHub no longer accepts your token.")
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
        }
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
    BothAppearances {
        PanelView(
            store: SyncStore(account: .preview(signedIn: false), preferences: .preview),
            avatars: .preview,
            actions: .preview
        )
    }
}

#Preview("Business and Family") {
    BothAppearances {
        PanelView(
            store: .preview(business: BusinessRow.previews, family: FamilyRow.previews),
            avatars: .preview,
            actions: .preview
        )
    }
}

#Preview("Stale") {
    BothAppearances {
        PanelView(
            store: .preview(business: BusinessRow.previews, family: FamilyRow.previews, failure: .offline),
            avatars: .preview,
            actions: .preview
        )
    }
}

#Preview("Sign in again") {
    BothAppearances {
        PanelView(
            store: .preview(business: BusinessRow.previews, family: FamilyRow.previews, failure: .unauthorised),
            avatars: .preview,
            actions: .preview
        )
    }
}

#Preview("Empty") {
    BothAppearances {
        PanelView(
            store: .preview(business: [], family: []),
            avatars: .preview,
            actions: .preview
        )
    }
}
#endif
