import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", initial: .init(.p, modifiers: [.option, .command]))
}
