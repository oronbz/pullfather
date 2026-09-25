import CoreGraphics
import Testing
@testable import Pullfather

struct PanelPlacementTests {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 944)

    @Test func hangsCentredBelowTheGlyph() {
        let glyph = CGRect(x: 1000, y: 945, width: 40, height: 37)

        let frame = PanelPlacement.frame(below: glyph, contentHeight: 300, within: screen)

        #expect(frame == CGRect(x: 828, y: 639, width: 384, height: 300))
    }

    @Test func staysOnScreenWhenTheGlyphIsNearTheRightEdge() {
        let glyph = CGRect(x: 1400, y: 945, width: 40, height: 37)

        let frame = PanelPlacement.frame(below: glyph, contentHeight: 300, within: screen)

        #expect(frame == CGRect(x: 1120, y: 639, width: 384, height: 300))
    }

    @Test func staysOnScreenWhenTheGlyphIsNearTheLeftEdgeOfASecondaryDisplay() {
        let secondary = CGRect(x: -1920, y: 0, width: 1920, height: 1055)
        let glyph = CGRect(x: -1900, y: 1056, width: 40, height: 24)

        let frame = PanelPlacement.frame(below: glyph, contentHeight: 300, within: secondary)

        #expect(frame == CGRect(x: -1912, y: 750, width: 384, height: 300))
    }
}
