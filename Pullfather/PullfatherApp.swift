import AppKit

@main
enum PullfatherApp {
    static func main() {
        let app = NSApplication.shared
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
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
