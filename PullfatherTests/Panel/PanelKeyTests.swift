import AppKit
import Testing
@testable import Pullfather

struct PanelKeyTests {
    @Test(arguments: [
        (125, "\u{F701}", .move(.down)),
        (126, "\u{F700}", .move(.up)),
        (38, "j", .move(.down)),
        (40, "k", .move(.up)),
        (36, "\r", .open),
        (76, "\u{3}", .open),
    ] as [(UInt16, String, PanelCommand)])
    func navigationKeysMoveAndOpen(keyCode: UInt16, characters: String, expected: PanelCommand) {
        #expect(PanelKey.command(keyCode: keyCode, characters: characters, modifiers: []) == expected)
    }

    @Test func capsLockDoesNotStopLetterNavigation() {
        #expect(PanelKey.command(keyCode: 38, characters: "J", modifiers: .capsLock) == .move(.down))
        #expect(PanelKey.command(keyCode: 40, characters: "K", modifiers: .capsLock) == .move(.up))
    }

    @Test func arrowKeysCarryTheirFunctionFlags() {
        #expect(PanelKey.command(keyCode: 125, characters: "\u{F701}", modifiers: [.function, .numericPad]) == .move(.down))
    }

    @Test(arguments: [
        (38, "j", NSEvent.ModifierFlags.command),
        (40, "k", .control),
        (125, "\u{F701}", .option),
        (36, "\r", .command),
        (38, "J", .shift),
    ] as [(UInt16, String, NSEvent.ModifierFlags)])
    func modifiedKeysAreLeftAlone(keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags) {
        #expect(PanelKey.command(keyCode: keyCode, characters: characters, modifiers: modifiers) == nil)
    }

    @Test func otherKeysAreLeftAlone() {
        #expect(PanelKey.command(keyCode: 0, characters: "a", modifiers: []) == nil)
    }
}
