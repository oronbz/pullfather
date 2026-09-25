import AppKit
import SwiftUI

struct PanelActions {
    var openPullRequest: (URL) -> Void
    var copyLink: (URL) -> Void
    var openRepository: (URL) -> Void
    var openGitHub: () -> Void
    var openSettings: () -> Void
    var quit: () -> Void
}

final class PanelController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var hostingView: NSHostingView<PanelView>!
    private var panel: NoirPanel!
    private var actions: PanelActions!
    private let store: SyncStore
    private var countUpdates: Task<Void, Never>?
    private let activation: ActivationHandoff

    init(store: SyncStore, avatars: AvatarCache, activation: ActivationHandoff, actions: PanelActions) {
        self.store = store
        self.activation = activation
        super.init()
        self.actions = PanelActions(
            openPullRequest: { [weak self] url in actions.openPullRequest(url); self?.close() },
            copyLink: { [weak self] url in actions.copyLink(url); self?.dismiss() },
            openRepository: { [weak self] url in actions.openRepository(url); self?.close() },
            openGitHub: { [weak self] in actions.openGitHub(); self?.close() },
            openSettings: { [weak self] in actions.openSettings(); self?.close() },
            quit: actions.quit
        )
        hostingView = NSHostingView(rootView: PanelView(
            store: store,
            avatars: avatars,
            actions: self.actions,
            onHeightChange: { [weak self] _ in self?.contentHeightChanged() }
        ))
        panel = NoirPanel(contentView: hostingView)
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.dismiss() }
        panel.onCommand = { [weak self] command in self?.perform(command) ?? false }

        if let button = statusItem.button {
            button.image = NSImage(resource: .menuBarIcon)
            button.image?.accessibilityDescription = "The Pullfather"
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(toggle)
        }
        countUpdates = Task { [weak self] in
            for await count in Observations({ store.countText }) {
                self?.statusItem.button?.title = count ?? ""
            }
        }
    }

    @objc func toggle() {
        panel.isVisible ? dismiss() : open()
    }

    private func open() {
        guard layout() else { return }
        store.select(nil)
        store.requestSync()
        activation.activate()
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

    private func perform(_ command: PanelCommand) -> Bool {
        switch command {
        case .move(let move):
            store.moveSelection(move)
            return store.selection != nil
        case .open:
            guard let url = store.selectedURL else { return false }
            actions.openPullRequest(url)
            return true
        }
    }

    private func close() {
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
    }

    private func dismiss() {
        close()
        activation.handBack(leaving: panel)
    }

    func windowDidResignKey(_ notification: Notification) {
        if let event = NSApp.currentEvent, event.type == .leftMouseDown, event.window === statusItem.button?.window {
            return
        }
        guard panel.isVisible else { return }
        dismiss()
    }
}

#if DEBUG
extension PanelActions {
    static let preview = PanelActions(openPullRequest: { _ in }, copyLink: { _ in }, openRepository: { _ in }, openGitHub: {}, openSettings: {}, quit: {})
}
#endif
