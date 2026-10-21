import Foundation
import Testing
@testable import Pullfather

final class NotifierTests {
    let defaultsSuite = "NotifierTests-\(UUID().uuidString)"
    lazy var preferences = Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!)
    var posted: [Notice] = []

    deinit {
        UserDefaults().removePersistentDomain(forName: defaultsSuite)
    }

    private func makeNotifier() -> Notifier {
        Notifier(
            preferences: preferences,
            poster: NotificationPoster { [unowned self] in posted.append($0) },
            openPullRequest: { _ in },
            openPopover: {}
        )
    }

    private let verdict = FamilyRow(
        id: "PR_1079", number: 1079, title: "Add offline banner", url: URL(string: "https://github.com/corleone/casino/pull/1079")!,
        repository: "corleone/casino", branch: "offline-banner", lastActivity: "now", lineChanges: LineChanges(additions: 2, deletions: 4), isDraft: false, reviewState: .approved, checks: nil
    )

    private let arrival = BusinessRow(
        id: "PR_1088", number: 1088, title: "Migrate settings screen to SwiftUI", url: URL(string: "https://github.com/corleone/casino/pull/1088")!,
        repository: "corleone/casino", branch: "swiftui-settings", author: "sonny", avatarURL: nil, waitingSince: .now, waitingTime: "now", lineChanges: LineChanges(additions: 2, deletions: 4), checks: nil, isRequestedByName: true, isRequestedThroughTeam: false
    )

    @Test func aVerdictIsPostedWhileVerdictNotificationsAreOn() {
        makeNotifier().notify(verdicts: [verdict])

        #expect(posted.map(\.title) == ["Your offer was accepted"])
    }

    @Test func switchingVerdictNotificationsOffSilencesVerdictsButNotArrivals() {
        preferences.notifiesVerdicts = false
        let notifier = makeNotifier()

        notifier.notify(verdicts: [verdict])
        notifier.notify(arrivals: [arrival])

        #expect(posted.map(\.title) == ["sonny asks a favor"])
    }

    @Test func switchingArrivalNotificationsOffSilencesArrivalsButNotVerdicts() {
        preferences.notifiesArrivals = false
        let notifier = makeNotifier()

        notifier.notify(arrivals: [arrival])
        notifier.notify(verdicts: [verdict])

        #expect(posted.map(\.title) == ["Your offer was accepted"])
    }
}
