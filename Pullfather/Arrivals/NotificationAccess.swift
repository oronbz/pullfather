import AppKit
import Observation
import UserNotifications

struct NotificationAuthorizer {
    var status: () async -> UNAuthorizationStatus
    var request: () async -> Void

    static let live = NotificationAuthorizer(
        status: { await UNUserNotificationCenter.current().notificationSettings().authorizationStatus },
        request: { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
    )
}

@Observable
final class NotificationAccess {
    private static let hintDismissedKey = "notificationsHintDismissed"

    private(set) var isOff = false
    private(set) var isHintDismissed: Bool

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let authorizer: NotificationAuthorizer
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var hasRequested = false

    init(preferences: Preferences, authorizer: NotificationAuthorizer = .live, defaults: UserDefaults = .standard) {
        self.preferences = preferences
        self.authorizer = authorizer
        self.defaults = defaults
        isHintDismissed = defaults.bool(forKey: Self.hintDismissedKey)
    }

    var showsHint: Bool {
        preferences.notifiesArrivals && isOff
    }

    var showsPopoverHint: Bool {
        showsHint && !isHintDismissed
    }

    func request() async {
        await authorizer.request()
        hasRequested = true
        await refresh()
    }

    func refresh() async {
        let status = await authorizer.status()
        isOff = status == .denied || (hasRequested && status == .notDetermined)
    }

    func dismissHint() {
        isHintDismissed = true
        defaults.set(true, forKey: Self.hintDismissedKey)
    }

    func openSystemSettings() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)")!)
    }
}

#if DEBUG
extension NotificationAccess {
    static func preview(isOff: Bool) -> NotificationAccess {
        let access = NotificationAccess(
            preferences: .preview,
            authorizer: NotificationAuthorizer(status: { isOff ? .denied : .authorized }, request: {}),
            defaults: UserDefaults(suiteName: "PullfatherPreview-\(UUID().uuidString)")!
        )
        access.isOff = isOff
        return access
    }
}
#endif
