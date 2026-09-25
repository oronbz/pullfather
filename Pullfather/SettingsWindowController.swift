import AppKit
import KeyboardShortcuts
import SwiftUI

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let account: Account
    private let preferences: Preferences
    private let launchAtLogin: LaunchAtLogin
    private let activation: ActivationHandoff

    init(account: Account, preferences: Preferences, launchAtLogin: LaunchAtLogin, activation: ActivationHandoff) {
        self.account = account
        self.preferences = preferences
        self.launchAtLogin = launchAtLogin
        self.activation = activation
    }

    private lazy var window: NSWindow = {
        let controller = NSHostingController(rootView: SettingsView(account: account, preferences: preferences, launchAtLogin: launchAtLogin))
        controller.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: controller)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(Palette.windowSurface)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }()

    func show() {
        launchAtLogin.refresh()
        activation.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        activation.handBack(leaving: window)
    }
}

struct SettingsView: View {
    let account: Account
    let preferences: Preferences
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(Font(Typography.title))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 10)
            AccountPane(account: account)
            BusinessPane(preferences: preferences)
            NotificationsPane(preferences: preferences)
            SyncPane(preferences: preferences)
            MenuBarPane(preferences: preferences)
            GeneralPane(launchAtLogin: launchAtLogin)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .frame(width: 480, alignment: .topLeading)
        .background(Palette.windowSurface)
        .environment(\.colorScheme, .dark)
    }
}

private struct AccountPane: View {
    let account: Account
    @State private var isChangingToken = false

    var body: some View {
        NoirSection(title: "Account") {
            switch account.state {
            case .signedOut:
                TokenForm(account: account)
                    .padding(10)
                    .background(Palette.rowHighlight, in: .rect(cornerRadius: Noir.rowRadius))
            case .signedIn(let login):
                NoirRow {
                    Text(SignedInLine.text(for: login))
                    Spacer()
                    Button(isChangingToken ? "Cancel" : "Change Token…") { isChangingToken.toggle() }
                        .buttonStyle(.noir)
                    Button("Sign Out") {
                        isChangingToken = false
                        account.signOut()
                    }
                    .buttonStyle(.noir)
                }
                if isChangingToken {
                    TokenForm(account: account) { isChangingToken = false }
                        .padding(10)
                        .background(Palette.rowHighlight, in: .rect(cornerRadius: Noir.rowRadius))
                }
            }
        }
    }
}

private struct BusinessPane: View {
    @Bindable var preferences: Preferences

    var body: some View {
        NoirSection(title: "Business") {
            NoirRow {
                Text("Show first")
                Spacer()
                Picker("Show first", selection: $preferences.businessOrder) {
                    Text("Newest").tag(BusinessOrder.newestFirst)
                    Text("Longest waiting").tag(BusinessOrder.oldestFirst)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .tint(Palette.commitRed)
                .fixedSize()
            }
        }
    }
}

private struct NotificationsPane: View {
    @Bindable var preferences: Preferences

    var body: some View {
        NoirSection(title: "Notifications") {
            NoirRow {
                Text("Notify when a favor is asked")
                Spacer()
                Toggle("Notify when a favor is asked", isOn: $preferences.notifiesArrivals)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Palette.commitRed)
            }
        }
    }
}

private struct SyncPane: View {
    @Bindable var preferences: Preferences

    var body: some View {
        NoirSection(title: "Sync") {
            NoirRow {
                Text("Refresh interval")
                Spacer()
                Picker("Refresh interval", selection: $preferences.refreshInterval) {
                    ForEach(RefreshInterval.allCases, id: \.self) { interval in
                        Text("\(interval.rawValue) min").tag(interval)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .tint(Palette.commitRed)
                .fixedSize()
            }
        }
    }
}

private struct MenuBarPane: View {
    @Bindable var preferences: Preferences

    var body: some View {
        NoirSection(title: "Menu Bar") {
            NoirRow {
                Text("Counter")
                Spacer()
                Picker("Counter", selection: $preferences.countMode) {
                    Text("Business").tag(CountMode.business)
                    Text("Family").tag(CountMode.family)
                    Text("No counter").tag(CountMode.off)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .tint(Palette.commitRed)
                .fixedSize()
            }
        }
    }
}

private struct GeneralPane: View {
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        NoirSection(title: "General") {
            NoirRow {
                Text("Launch at Login")
                Spacer()
                Toggle("Launch at Login", isOn: Binding(get: { launchAtLogin.isEnabled }, set: launchAtLogin.setEnabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Palette.commitRed)
            }
            NoirRow {
                Text("Global hotkey")
                Spacer()
                KeyboardShortcuts.Recorder(for: .togglePanel)
                    .controlSize(.small)
                    .fixedSize()
            }
            if launchAtLogin.needsApproval {
                NoirRow {
                    Text("Approve The Pullfather in Login Items to finish.")
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Button("Open Login Items") { launchAtLogin.openSystemSettings() }
                        .buttonStyle(.noir)
                }
            }
            if let error = launchAtLogin.error {
                Text(error)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.checksFailing)
                    .padding(.horizontal, 10)
            }
        }
    }
}

#Preview("Signed out") {
    SettingsView(account: .preview(signedIn: false), preferences: .preview, launchAtLogin: LaunchAtLogin())
        .frame(minHeight: 370, maxHeight: .infinity, alignment: .top)
        .background(Palette.windowSurface)
}

#Preview("Signed in") {
    SettingsView(account: .preview(signedIn: true), preferences: .preview, launchAtLogin: LaunchAtLogin())
        .fixedSize()
}
