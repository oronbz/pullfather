import AppKit
import SwiftUI

final class SettingsWindowController {
    private let account: Account
    private let launchAtLogin: LaunchAtLogin

    init(account: Account, launchAtLogin: LaunchAtLogin) {
        self.account = account
        self.launchAtLogin = launchAtLogin
    }

    private lazy var window: NSWindow = {
        let controller = NSHostingController(rootView: SettingsView(account: account, launchAtLogin: launchAtLogin))
        controller.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: controller)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(Palette.windowSurface)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }()

    func show() {
        launchAtLogin.refresh()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let account: Account
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(Font(Typography.title))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 10)
            AccountPane(account: account)
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
    SettingsView(account: .preview(signedIn: false), launchAtLogin: LaunchAtLogin())
        .frame(minHeight: 370, maxHeight: .infinity, alignment: .top)
        .background(Palette.windowSurface)
}

#Preview("Signed in") {
    SettingsView(account: .preview(signedIn: true), launchAtLogin: LaunchAtLogin())
        .fixedSize()
}
