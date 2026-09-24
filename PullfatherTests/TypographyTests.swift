import AppKit
import Testing
@testable import Pullfather

struct TypographyTests {
    init() {
        Typography.registerBundledFonts()
    }

    @Test func titleIsPlayfairDisplayBoldAt20pt() {
        let font = Typography.title

        #expect(font.familyName == "Playfair Display")
        #expect(font.fontDescriptor.symbolicTraits.contains(.bold))
        #expect(!font.fontDescriptor.symbolicTraits.contains(.italic))
        #expect(font.pointSize == 20)
    }

    @Test func taglineIsPlayfairDisplayBoldItalicAt13pt() {
        let font = Typography.tagline

        #expect(font.familyName == "Playfair Display")
        #expect(font.fontDescriptor.symbolicTraits.contains(.bold))
        #expect(font.fontDescriptor.symbolicTraits.contains(.italic))
        #expect(font.pointSize == 13)
    }

    @Test func registeringTwiceKeepsTheFontsAvailable() {
        Typography.registerBundledFonts()

        #expect(Typography.title.familyName == "Playfair Display")
    }
}
