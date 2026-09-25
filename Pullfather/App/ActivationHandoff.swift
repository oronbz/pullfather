import AppKit

final class ActivationHandoff {
    private var previousApp: NSRunningApplication?

    func activate() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost != .current {
            previousApp = frontmost
        }
        NSApp.activate()
    }

    func handBack(leaving window: NSWindow) {
        let othersRemain = NSApp.windows.contains { $0 !== window && $0.isVisible && $0.canBecomeMain }
        guard NSApp.isActive, !othersRemain, let previousApp, !previousApp.isTerminated else { return }
        self.previousApp = nil
        NSApp.yieldActivation(to: previousApp)
        previousApp.activate()
    }
}
