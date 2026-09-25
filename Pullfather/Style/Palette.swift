import AppKit
import SwiftUI

enum Palette {
    static let bone = Color(hex: 0xEDE3D1)
    static let commitRed = Color(hex: 0xB3202A)
    static let brass = Color(dark: 0xC9A45C, light: 0x7A5A1C)
    static let surface = Color(dark: 0x211B19, light: 0xF4EDE1, opacity: 0.94)
    static let windowBackground = NSColor(dark: 0x211B19, light: 0xF4EDE1)
    static let windowSurface = Color(nsColor: windowBackground)
    static let textPrimary = Color(dark: 0xF2E9DA, light: 0x211B19)
    static let textSecondary = Color(dark: 0xB8AB98, light: 0x574B41)
    static let textMuted = Color(dark: 0x9C9083, light: 0x6E6257)
    static let checksPassing = Color(hex: 0x4FA464)
    static let approved = Color(dark: 0x4FA464, light: 0x2B7040)
    static let amber = Color(dark: 0xD9A441, light: 0x825708)
    static let checksRunning = Color(hex: 0x4F8FD9)
    static let checksFailing = Color(hex: 0xD9534A)
    static let ink = Color(dark: 0xEDE3D1, light: 0x211B19)
    static let hairline = ink.opacity(0.1)
    static let rowHighlight = ink.opacity(0.06)
}

extension Theme {
    var appearance: NSAppearance? {
        switch self {
        case .noir: NSAppearance(named: .darkAqua)
        case .bone: NSAppearance(named: .aqua)
        case .system: nil
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(nsColor: NSColor(hex: hex, opacity: opacity))
    }

    init(dark: UInt32, light: UInt32, opacity: Double = 1) {
        self.init(nsColor: NSColor(dark: dark, light: light, opacity: opacity))
    }
}

extension NSColor {
    convenience init(hex: UInt32, opacity: Double = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }

    convenience init(dark: UInt32, light: UInt32, opacity: Double = 1) {
        self.init(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, opacity: opacity)
        }
    }
}
