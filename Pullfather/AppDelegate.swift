import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let account = Account(tokenStore: .standard, makeTransport: { URLSessionTransport(token: $0) })
    private let launchAtLogin = LaunchAtLogin()
    private lazy var settingsWindow = SettingsWindowController(account: account, launchAtLogin: launchAtLogin)
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Typography.registerBundledFonts()
        NSApp.mainMenu = makeMainMenu()
        Task { await account.restore() }
        panelController = PanelController(account: account, actions: PanelActions(
            openGitHub: { NSWorkspace.shared.open(URL(string: "https://github.com/pulls/review-requested")!) },
            openSettings: { [settingsWindow] in settingsWindow.show() },
            quit: { NSApp.terminate(nil) }
        ))
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
