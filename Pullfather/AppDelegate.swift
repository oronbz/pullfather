import AppKit
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let account = Account(tokenStore: .standard, makeTransport: { URLSessionTransport(token: $0) })
    private let preferences = Preferences()
    private lazy var store = SyncStore(account: account, preferences: preferences)
    private let avatars = AvatarCache()
    private let launchAtLogin = LaunchAtLogin()
    private let activation = ActivationHandoff()
    private lazy var settingsWindow = SettingsWindowController(account: account, preferences: preferences, launchAtLogin: launchAtLogin, activation: activation)
    private var panelController: PanelController?
    private lazy var syncTriggers = SyncTriggers(store: store)
    private lazy var notifier = ArrivalNotifier(
        preferences: preferences,
        openPullRequest: { NSWorkspace.shared.open($0) },
        openPopover: { [weak self] in self?.panelController?.show() }
    )
    private var permissionRequests: Task<Void, Never>?
    private var themeUpdates: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        quitOtherInstances()
        NSApp.appearance = preferences.theme.appearance
        themeUpdates = Task { [preferences] in
            for await theme in Observations({ preferences.theme }) {
                NSApp.appearance = theme.appearance
            }
        }
        NSApp.mainMenu = makeMainMenu()
        Task { await account.restore() }
        store.onArrivals = notifier.notify
        permissionRequests = Task { [account, notifier] in
            for await state in Observations({ account.state }) {
                if case .signedIn(login: .some) = state {
                    notifier.requestPermission()
                }
            }
        }
        syncTriggers.start()
        panelController = PanelController(store: store, avatars: avatars, activation: activation, actions: PanelActions(
            openPullRequest: { NSWorkspace.shared.open($0) },
            copyLink: { url in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            },
            openRepository: { NSWorkspace.shared.open($0) },
            openGitHub: { NSWorkspace.shared.open(URL(string: "https://github.com/pulls/review-requested")!) },
            openSettings: { [settingsWindow] in settingsWindow.show() },
            quit: { NSApp.terminate(nil) }
        ))
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.panelController?.toggle()
        }
    }

    private func quitOtherInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0 != .current }
            .forEach { $0.terminate() }
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit The Pullfather", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let mainMenu = NSMenu()
        for submenu in [appMenu, editMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        return mainMenu
    }
}
