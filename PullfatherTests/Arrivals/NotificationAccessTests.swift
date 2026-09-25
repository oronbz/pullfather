import Foundation
import Testing
import UserNotifications
@testable import Pullfather

struct NotificationAccessTests {
    private final class FakeCenter {
        var status: UNAuthorizationStatus
        var statusAfterRequest: UNAuthorizationStatus?

        init(status: UNAuthorizationStatus, statusAfterRequest: UNAuthorizationStatus? = nil) {
            self.status = status
            self.statusAfterRequest = statusAfterRequest
        }

        var authorizer: NotificationAuthorizer {
            NotificationAuthorizer(
                status: { self.status },
                request: { self.status = self.statusAfterRequest ?? self.status }
            )
        }
    }

    private let defaults = UserDefaults(suiteName: "NotificationAccessTests-\(UUID().uuidString)")!

    private func access(_ center: FakeCenter, preferences: Preferences? = nil) -> NotificationAccess {
        NotificationAccess(preferences: preferences ?? Preferences(defaults: defaults), authorizer: center.authorizer, defaults: defaults)
    }

    @Test func deniedNotificationsShowTheHintEverywhere() async {
        let access = access(FakeCenter(status: .denied))

        await access.refresh()

        #expect(access.showsHint)
        #expect(access.showsPopoverHint)
    }

    @Test func allowedNotificationsShowNoHint() async {
        let access = access(FakeCenter(status: .notDetermined, statusAfterRequest: .authorized))

        await access.request()

        #expect(!access.showsHint)
    }

    @Test func undecidedNotificationsShowNoHintBeforeAskingMacOS() async {
        let access = access(FakeCenter(status: .notDetermined))

        await access.refresh()

        #expect(!access.showsHint)
    }

    @Test func aRequestMacOSRefusesToPromptForShowsTheHint() async {
        let access = access(FakeCenter(status: .notDetermined))

        await access.request()

        #expect(access.showsHint)
    }

    @Test func turningNotificationsOnInSystemSettingsHidesTheHintOnTheNextRefresh() async {
        let center = FakeCenter(status: .denied)
        let access = access(center)
        await access.refresh()

        center.status = .authorized
        await access.refresh()

        #expect(!access.showsHint)
    }

    @Test func dismissingHidesThePopoverHintForGoodButKeepsTheSettingsHint() async {
        let center = FakeCenter(status: .denied)
        let first = access(center)
        await first.refresh()

        first.dismissHint()
        let relaunched = access(center)
        await relaunched.refresh()

        #expect(!first.showsPopoverHint)
        #expect(!relaunched.showsPopoverHint)
        #expect(relaunched.showsHint)
    }

    @Test func noHintWhenArrivalNotificationsAreSwitchedOffInSettings() async {
        let preferences = Preferences(defaults: defaults)
        preferences.notifiesArrivals = false
        let access = access(FakeCenter(status: .denied), preferences: preferences)

        await access.refresh()

        #expect(!access.showsHint)
        #expect(!access.showsPopoverHint)
    }
}
