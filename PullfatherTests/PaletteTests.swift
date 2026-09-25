import AppKit
import SwiftUI
import Testing
@testable import Pullfather

@MainActor
struct PaletteTests {
    @Test func darkModeKeepsTheDesignTokens() {
        #expect(hex(Palette.surface, in: .dark) == "211B19F0")
        #expect(hex(Palette.windowSurface, in: .dark) == "211B19FF")
        #expect(hex(Palette.textPrimary, in: .dark) == "F2E9DAFF")
        #expect(hex(Palette.textSecondary, in: .dark) == "B8AB98FF")
        #expect(hex(Palette.textMuted, in: .dark) == "9C9083FF")
        #expect(hex(Palette.brass, in: .dark) == "C9A45CFF")
        #expect(hex(Palette.amber, in: .dark) == "D9A441FF")
        #expect(hex(Palette.approved, in: .dark) == "4FA464FF")
        #expect(hex(Palette.hairline, in: .dark) == "EDE3D11A")
        #expect(hex(Palette.rowHighlight, in: .dark) == "EDE3D10F")
    }

    @Test func lightModeSitsOnWarmBone() {
        #expect(hex(Palette.windowSurface, in: .light) == "F4EDE1FF")
        #expect(hex(Palette.surface, in: .light) == "F4EDE1F0")
    }

    @Test func lightTextIsNearBlackBrown() throws {
        let text = try #require(components(Palette.textPrimary, in: .light))

        #expect(text.red > text.green && text.green >= text.blue)
        #expect(text.red < 0.2)
    }

    @Test func lightBrassIsADarkerBrass() throws {
        let dark = try #require(components(Palette.brass, in: .dark))
        let light = try #require(components(Palette.brass, in: .light))

        #expect(light.red < dark.red && light.green < dark.green && light.blue < dark.blue)
        #expect(light.red > light.green && light.green > light.blue)
    }

    @Test func oxbloodBoneAndChecksStayTheSameInBothModes() {
        for color in [Palette.commitRed, Palette.bone, Palette.checksPassing, Palette.checksRunning, Palette.checksFailing] {
            #expect(hex(color, in: .light) == hex(color, in: .dark))
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func textReadsOnTheSurface(in scheme: ColorScheme) {
        let surface = Palette.windowSurface
        #expect(contrast(Palette.textPrimary, surface, in: scheme) >= 12)
        #expect(contrast(Palette.textSecondary, surface, in: scheme) >= 6.5)
        for color in [Palette.textMuted, Palette.brass, Palette.amber, Palette.approved] {
            #expect(contrast(color, surface, in: scheme) >= 4.5)
        }
    }

    @Test func settingsWindowBackgroundFollowsTheAppearance() {
        #expect(hex(Palette.windowBackground, in: .darkAqua) == "211B19FF")
        #expect(hex(Palette.windowBackground, in: .aqua) == "F4EDE1FF")
        #expect(hex(Palette.windowBackground, in: .accessibilityHighContrastDarkAqua) == "211B19FF")
    }

    private func environment(_ scheme: ColorScheme) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return environment
    }

    private func components(_ color: Color, in scheme: ColorScheme) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        let resolved = color.resolve(in: environment(scheme))
        guard let srgb = resolved.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let values = srgb.components, values.count == 4 else { return nil }
        return (values[0], values[1], values[2], values[3])
    }

    private func hex(_ color: Color, in scheme: ColorScheme) -> String? {
        components(color, in: scheme).map { hexString(red: $0.red, green: $0.green, blue: $0.blue, alpha: $0.alpha) }
    }

    private func hex(_ color: NSColor, in appearance: NSAppearance.Name) -> String? {
        var result: String?
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            if let srgb = color.usingColorSpace(.sRGB) {
                result = hexString(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent, alpha: srgb.alphaComponent)
            }
        }
        return result
    }

    private func hexString(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> String {
        [red, green, blue, alpha].map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    private func contrast(_ foreground: Color, _ background: Color, in scheme: ColorScheme) -> Double {
        let environment = environment(scheme)
        let luminances = [foreground, background].map { color in
            let linear = color.resolve(in: environment)
            return 0.2126 * Double(linear.linearRed) + 0.7152 * Double(linear.linearGreen) + 0.0722 * Double(linear.linearBlue)
        }
        return (luminances.max()! + 0.05) / (luminances.min()! + 0.05)
    }
}

@MainActor
struct ThemeTests {
    @Test(arguments: [
        (Theme.noir, NSAppearance.Name?.some(.darkAqua)),
        (.bone, .aqua),
        (.system, nil),
    ])
    func eachThemePinsItsAppearance(theme: Theme, expected: NSAppearance.Name?) {
        #expect(theme.appearance?.name == expected)
    }
}
