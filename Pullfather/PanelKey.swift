import AppKit

enum PanelCommand: Equatable {
    case move(SelectionMove)
    case open
}

enum PanelKey {
    private static let upArrow: UInt16 = 126
    private static let downArrow: UInt16 = 125
    private static let returnKey: UInt16 = 36
    private static let keypadEnter: UInt16 = 76

    static func command(keyCode: UInt16, characters: String?, modifiers: NSEvent.ModifierFlags) -> PanelCommand? {
        guard modifiers.isDisjoint(with: [.command, .control, .option, .shift]) else { return nil }
        switch (keyCode, characters?.lowercased()) {
        case (downArrow, _), (_, "j"): return .move(.down)
        case (upArrow, _), (_, "k"): return .move(.up)
        case (returnKey, _), (keypadEnter, _): return .open
        default: return nil
        }
    }
}
