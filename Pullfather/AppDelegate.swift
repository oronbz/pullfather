import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsWindow = SettingsWindowController()
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Typography.registerBundledFonts()
        NSApp.mainMenu = makeMainMenu()
        panelController = PanelController(actions: PanelActions(
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

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let mainMenu = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        return mainMenu
    }
}
