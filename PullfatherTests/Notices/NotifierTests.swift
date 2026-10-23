import Foundation
import Testing
@testable import Pullfather

final class NotifierTests {
    let testDefaults = TestDefaults()
    lazy var preferences = Preferences(defaults: testDefaults.defaults)
    var posted: [Notice] = []

    private func makeNotifier() -> Notifier {
        Notifier(
            preferences: preferences,
            poster: NotificationPoster { [unowned self] in posted.append($0) },
            openPullRequest: { _ in },
            openPopover: {}
        )
    }

    private let verdict = FamilyRow.fixture(1079)
    private let arrival = BusinessRow.fixture(1088)

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
