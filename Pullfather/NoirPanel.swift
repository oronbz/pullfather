import AppKit

final class NoirPanel: NSPanel {
    var onCancel: (() -> Void)?
    var onCommand: ((PanelCommand) -> Bool)?

    init(contentView: NSView) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        self.contentView = contentView
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, !(firstResponder is NSText),
           let command = PanelKey.command(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers, modifiers: event.modifierFlags),
           onCommand?(command) == true {
            return
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
