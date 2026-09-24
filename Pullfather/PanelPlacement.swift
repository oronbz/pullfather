import CoreGraphics

enum PanelPlacement {
    static let width: CGFloat = 384
    static let gap: CGFloat = 6
    static let screenMargin: CGFloat = 8

    static func frame(below anchor: CGRect, contentHeight: CGFloat, within visibleFrame: CGRect) -> CGRect {
        let minX = visibleFrame.minX + screenMargin
        let maxX = visibleFrame.maxX - screenMargin - width
        return CGRect(
            x: max(minX, min(anchor.midX - width / 2, maxX)),
            y: anchor.minY - gap - contentHeight,
            width: width,
            height: contentHeight
        )
    }
}
