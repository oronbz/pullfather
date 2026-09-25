import Foundation
import UserNotifications

final class ArrivalNotifier: NSObject, UNUserNotificationCenterDelegate {
    nonisolated private static let urlKey = "url"

    private let center = UNUserNotificationCenter.current()
    private let preferences: Preferences
    private let openPullRequest: (URL) -> Void
    private let openPopover: () -> Void

    init(preferences: Preferences, openPullRequest: @escaping (URL) -> Void, openPopover: @escaping () -> Void) {
        self.preferences = preferences
        self.openPullRequest = openPullRequest
        self.openPopover = openPopover
        super.init()
        center.delegate = self
    }

    func requestPermission() {
        Task { [center] in
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func notify(_ arrivals: [BusinessRow]) {
        guard preferences.notifiesArrivals, let notice = ArrivalNotice(arrivals: arrivals) else { return }
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.body
        content.sound = .default
        if case .pullRequest(let url) = notice.opens {
            content.userInfo = [Self.urlKey: url.absoluteString]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        Task { [center] in
            try? await center.add(request)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let url = (response.notification.request.content.userInfo[Self.urlKey] as? String).flatMap(URL.init(string:))
        await MainActor.run {
            if let url {
                openPullRequest(url)
            } else {
                openPopover()
            }
        }
    }
}
