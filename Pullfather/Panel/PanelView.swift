import SwiftUI

struct PanelView: View {
    let store: SyncStore
    let updates: UpdateChecker
    let upgrader: Upgrader
    let avatars: AvatarCache
    let notifications: NotificationAccess
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
                            if updates.showsBadge, let release = updates.newerRelease {
                                UpdateAvailableRow(release: release, upgrader: upgrader, actions: actions, dismiss: updates.dismissBadge)
                            }
                            if notifications.showsPopoverHint {
                                NotificationsOffRow(open: actions.openNotificationSettings, dismiss: notifications.dismissHint)
                            }
                            BusinessSection(rows: store.business, showsChecks: store.preferences.showsBusinessChecks, syncedAt: store.lastSyncedAt, avatars: avatars, selection: selection, approvalCandidate: approvalCandidate, actions: actions)
                            FamilySection(rows: store.family, showsChecks: store.preferences.showsFamilyChecks, selection: selection, actions: actions)
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
                PanelFooter(actions: actions, failure: store.actionFailure ?? upgrader.failure, newerRelease: updates.newerRelease, upgrader: upgrader)
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

    private var approvalCandidate: Binding<String?> {
        Binding(get: { store.approvalCandidate }, set: { store.approvalCandidate = $0 })
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

private struct NotificationsOffRow: View {
    let open: () -> Void
    let dismiss: () -> Void
    @State private var isHovered = false

    var body: some View {
        PanelRow(help: "Open Notifications in System Settings", isHighlighted: isHovered, onHover: { isHovered = $0 }, action: open) {
            Image(systemName: "bell.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.amber)
                .frame(width: 30, height: 30)
            RowText(title: "Notifications are off", metadata: "Turn them on in System Settings.")
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
            Color.clear
                .frame(width: 16, height: 16)
        }
        .overlay(alignment: .trailing) {
            DismissButton(action: dismiss)
        }
    }
}

private struct UpdateAvailableRow: View {
    let release: Release
    let upgrader: Upgrader
    let actions: PanelActions
    let dismiss: () -> Void
    @State private var isHovered = false

    var body: some View {
        PanelRow(help: "Upgrade with Homebrew and relaunch", isHighlighted: isHovered, onHover: { isHovered = $0 }, action: { upgrader.upgrade() }) {
            Image(systemName: "arrow.up.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.brass)
                .frame(width: 30, height: 30)
            RowText(
                title: "Update to \(release.version)",
                metadata: upgrader.isUpgrading ? "Updating, back in a moment." : "Upgrade with Homebrew and relaunch."
            )
            Spacer(minLength: 8)
            if upgrader.isUpgrading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textMuted)
            }
            Color.clear
                .frame(width: 16, height: 16)
        }
        .contextMenu {
            UpdateMenu(release: release, actions: actions)
        }
        .overlay(alignment: .trailing) {
            DismissButton(action: dismiss)
        }
    }
}

private struct DismissButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
                .frame(width: 16, height: 16)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Dismiss")
        .padding(.trailing, 10)
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
            updates: .preview(),
            upgrader: .preview(),
            avatars: .preview,
            notifications: .preview(isOff: false),
            actions: .preview
        )
    }
}

#Preview("Business and Family") {
    BothAppearances {
        PanelView(
            store: .preview(business: BusinessRow.previews, family: FamilyRow.previews),
            updates: .preview(),
            upgrader: .preview(),
            avatars: .preview,
            notifications: .preview(isOff: false),
            actions: .preview
        )
    }
}

#Preview("Notifications off") {
    BothAppearances {
        PanelView(
            store: .preview(business: BusinessRow.previews, family: FamilyRow.previews),
            updates: .preview(),
            upgrader: .preview(),
            avatars: .preview,
            notifications: .preview(isOff: true),
            actions: .preview
        )
    }
}

#Preview("Stale") {
    BothAppearances {
        PanelView(
            store: .preview(business: BusinessRow.previews, family: FamilyRow.previews, failure: .offline),
            updates: .preview(),
            upgrader: .preview(),
            avatars: .preview,
            notifications: .preview(isOff: false),
            actions: .preview
        )
    }
}

#Preview("Removal failed") {
    BothAppearances {
        PanelView(
            store: .preview(business: BusinessRow.previews, family: FamilyRow.previews, actionFailure: "Couldn't remove you from #412. Can't reach GitHub."),
            updates: .preview(),
            upgrader: .preview(),
            avatars: .preview,
            notifications: .preview(isOff: false),
            actions: .preview
        )
    }
}

#Preview("Sign in again") {
    BothAppearances {
        PanelView(
            store: .preview(business: BusinessRow.previews, family: FamilyRow.previews, failure: .unauthorised),
            updates: .preview(),
            upgrader: .preview(),
            avatars: .preview,
            notifications: .preview(isOff: false),
            actions: .preview
        )
    }
}

#Preview("Update available") {
    BothAppearances {
        PanelView(
            store: .preview(business: BusinessRow.previews, family: FamilyRow.previews),
            updates: .preview(newerRelease: Release(version: "0.4.0", url: URL(string: "https://github.com/oronbz/pullfather/releases/tag/v0.4.0")!)),
            upgrader: .preview(),
            avatars: .preview,
            notifications: .preview(isOff: false),
            actions: .preview
        )
    }
}

#Preview("Empty") {
    BothAppearances {
        PanelView(
            store: .preview(business: [], family: []),
            updates: .preview(),
            upgrader: .preview(),
            avatars: .preview,
            notifications: .preview(isOff: false),
            actions: .preview
        )
    }
}
#endif
