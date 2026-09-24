import Foundation
import Observation
import ServiceManagement

@Observable
final class LaunchAtLogin {
    private static let defaultAppliedKey = "launchAtLoginDefaultApplied"

    private(set) var isEnabled = false
    private(set) var needsApproval = false
    private(set) var error: String?

    init() {
        #if !DEBUG
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.defaultAppliedKey) {
            do {
                try SMAppService.mainApp.register()
                defaults.set(true, forKey: Self.defaultAppliedKey)
            } catch {
                self.error = error.localizedDescription
            }
        }
        #endif
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
    }
}
