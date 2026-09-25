import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", initial: .init(.p, modifiers: [.control, .shift, .command]))
}
