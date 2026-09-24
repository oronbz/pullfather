import AppKit
import SwiftUI

struct PanelActions {
    var openGitHub: () -> Void
    var openSettings: () -> Void
    var quit: () -> Void
}

final class PanelController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var hostingView: NSHostingView<PanelView>!
    private var panel: NoirPanel!

    init(account: Account, actions: PanelActions) {
        super.init()
        hostingView = NSHostingView(rootView: PanelView(
            account: account,
            actions: PanelActions(
                openGitHub: { [weak self] in actions.openGitHub(); self?.close() },
                openSettings: { [weak self] in actions.openSettings(); self?.close() },
                quit: actions.quit
            ),
            onHeightChange: { [weak self] _ in self?.contentHeightChanged() }
        ))
        panel = NoirPanel(contentView: hostingView)
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.close() }

        if let button = statusItem.button {
            button.image = NSImage(resource: .menuBarIcon)
            button.image?.accessibilityDescription = "The Pullfather"
            button.target = self
            button.action = #selector(toggle)
        }
    }

    @objc private func toggle() {
        panel.isVisible ? close() : open()
    }

    private func open() {
        guard layout() else { return }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        statusItem.button?.highlight(true)
    }

    @discardableResult
    private func layout() -> Bool {
        guard let button = statusItem.button, let buttonWindow = button.window, let screen = buttonWindow.screen else { return false }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let frame = PanelPlacement.frame(below: anchor, contentHeight: hostingView.fittingSize.height, within: screen.visibleFrame)
        panel.setFrame(frame, display: true)
        return true
    }

    private func contentHeightChanged() {
        guard panel.isVisible else { return }
        layout()
        panel.invalidateShadow()
    }

    private func close() {
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
    }

    func windowDidResignKey(_ notification: Notification) {
        if let event = NSApp.currentEvent, event.type == .leftMouseDown, event.window === statusItem.button?.window {
            return
        }
        close()
    }
}
