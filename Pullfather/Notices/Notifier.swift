import Foundation
import UserNotifications

struct NotificationPoster {
    var post: (Notice) -> Void

    static let live = NotificationPoster { notice in
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.body
        content.sound = .default
        if case .pullRequest(let url) = notice.opens {
            content.userInfo = [Notifier.urlKey: url.absoluteString]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    nonisolated fileprivate static let urlKey = "url"

    private let preferences: Preferences
    private let poster: NotificationPoster
    private let openPullRequest: (URL) -> Void
    private let openPopover: () -> Void

    init(preferences: Preferences, poster: NotificationPoster = .live, openPullRequest: @escaping (URL) -> Void, openPopover: @escaping () -> Void) {
        self.preferences = preferences
        self.poster = poster
        self.openPullRequest = openPullRequest
        self.openPopover = openPopover
        super.init()
    }

    func startHandlingClicks() {
        UNUserNotificationCenter.current().delegate = self
    }

    func notify(arrivals: [BusinessRow]) {
        guard preferences.notifiesArrivals, let notice = Notice(arrivals: arrivals) else { return }
        poster.post(notice)
    }

    func notify(verdicts: [FamilyRow]) {
        guard preferences.notifiesVerdicts, let notice = Notice(verdicts: verdicts) else { return }
        poster.post(notice)
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
