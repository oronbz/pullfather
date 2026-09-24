import SwiftUI

enum Palette {
    static let bone = Color(hex: 0xEDE3D1)
    static let commitRed = Color(hex: 0xB3202A)
    static let brass = Color(hex: 0xC9A45C)
    static let surface = Color(hex: 0x211B19, opacity: 0.94)
    static let windowSurface = Color(hex: 0x211B19)
    static let textPrimary = Color(hex: 0xF2E9DA)
    static let textSecondary = Color(hex: 0xB8AB98)
    static let textMuted = Color(hex: 0x9C9083)
    static let checksPassing = Color(hex: 0x4FA464)
    static let checksRunning = Color(hex: 0xD9A441)
    static let checksFailing = Color(hex: 0xD9534A)
    static let hairline = bone.opacity(0.1)
    static let rowHighlight = bone.opacity(0.06)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
