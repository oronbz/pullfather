import AppKit
import SwiftUI

struct PanelActions {
    var openPullRequest: (URL) -> Void
    var copyLink: (URL) -> Void
    var openRepository: (URL) -> Void
    var openGitHub: () -> Void
    var openSettings: () -> Void
    var openNotificationSettings: () -> Void
    var quit: () -> Void
}

final class PanelController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var hostingView: NSHostingView<PanelView>!
    private var panel: NoirPanel!
    private var actions: PanelActions!
    private let store: SyncStore
    private let notifications: NotificationAccess
    private var countUpdates: Task<Void, Never>?
    private let activation: ActivationHandoff
    private var isOpen = false

    init(store: SyncStore, avatars: AvatarCache, notifications: NotificationAccess, activation: ActivationHandoff, actions: PanelActions) {
        self.store = store
        self.notifications = notifications
        self.activation = activation
        super.init()
        self.actions = PanelActions(
            openPullRequest: { [weak self] url in actions.openPullRequest(url); self?.close() },
            copyLink: { [weak self] url in actions.copyLink(url); self?.dismiss() },
            openRepository: { [weak self] url in actions.openRepository(url); self?.close() },
            openGitHub: { [weak self] in actions.openGitHub(); self?.close() },
            openSettings: { [weak self] in actions.openSettings(); self?.close() },
            openNotificationSettings: { [weak self] in actions.openNotificationSettings(); self?.close() },
            quit: actions.quit
        )
        hostingView = NSHostingView(rootView: PanelView(
            store: store,
            avatars: avatars,
            notifications: notifications,
            actions: self.actions,
            onHeightChange: { [weak self] height in self?.contentHeightChanged(to: height) }
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
        isOpen ? dismiss() : open()
    }

    func show() {
        guard !isOpen else { return }
        open()
    }

    private func open() {
        guard layout() else { return }
        store.select(nil)
        store.requestSync()
        Task { [notifications] in await notifications.refresh() }
        activation.activate()
        isOpen = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 1
        }
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        statusItem.button?.highlight(true)
    }

    @discardableResult
    private func layout(contentHeight: CGFloat? = nil) -> Bool {
        guard let anchor = statusItemFrame, let screen = statusItem.button?.window?.screen else { return false }
        let height = contentHeight ?? hostingView.fittingSize.height
        let frame = PanelPlacement.frame(below: anchor, contentHeight: height, within: screen.visibleFrame)
        panel.setFrame(frame, display: true)
        return true
    }

    private func contentHeightChanged(to height: CGFloat) {
        guard isOpen else { return }
        layout(contentHeight: height)
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
        isOpen = false
        statusItem.button?.highlight(false)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isOpen else { return }
                self.panel.orderOut(nil)
            }
        }
    }

    private func dismiss() {
        close()
        activation.handBack(leaving: panel)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard isOpen, !isPressingStatusItem else { return }
        dismiss()
    }

    private var isPressingStatusItem: Bool {
        guard NSEvent.pressedMouseButtons & 1 != 0, let anchor = statusItemFrame else { return false }
        return anchor.contains(NSEvent.mouseLocation)
    }

    private var statusItemFrame: NSRect? {
        guard let button = statusItem.button, let buttonWindow = button.window else { return nil }
        return buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
    }
}

#if DEBUG
extension PanelActions {
    static let preview = PanelActions(openPullRequest: { _ in }, copyLink: { _ in }, openRepository: { _ in }, openGitHub: {}, openSettings: {}, openNotificationSettings: {}, quit: {})
}
#endif
