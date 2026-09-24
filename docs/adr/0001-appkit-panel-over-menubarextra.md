# AppKit status item and panel instead of MenuBarExtra

The popover is an `NSStatusItem` that toggles a borderless `NSPanel` hosting SwiftUI content, not a SwiftUI `MenuBarExtra`. `MenuBarExtra` cannot be opened programmatically, so a global hotkey could not summon it, and it gives no reliable keyboard focus for arrow-key row navigation; both are core to the keyboard-first experience. The panel is arrowless to match the design and dismisses on Esc or outside click.
