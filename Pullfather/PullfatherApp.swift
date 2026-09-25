import AppKit

@main
enum PullfatherApp {
    static func main() {
        let app = NSApplication.shared
        Typography.registerBundledFonts()
        let environment = ProcessInfo.processInfo.environment
        guard environment["XCTestConfigurationFilePath"] == nil, environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            app.run()
            return
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
