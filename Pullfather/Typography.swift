import AppKit
import CoreText

enum Typography {
    private static let bundledFonts = ["PlayfairDisplay", "PlayfairDisplay-Italic"]

    static func registerBundledFonts() {
        for name in bundledFonts {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static var title: NSFont { playfair("PlayfairDisplayRoman-Bold", size: 20) }
    static var tagline: NSFont { playfair("PlayfairDisplayItalic-Bold", size: 13) }

    private static func playfair(_ postScriptName: String, size: CGFloat) -> NSFont {
        NSFont(name: postScriptName, size: size) ?? .systemFont(ofSize: size, weight: .bold)
    }
}
