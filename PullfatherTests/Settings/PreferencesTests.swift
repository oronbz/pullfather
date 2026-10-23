import Foundation
import Testing
@testable import Pullfather

final class PreferencesTests {
    private let testDefaults = TestDefaults()
    private var defaults: UserDefaults { testDefaults.defaults }
    private lazy var preferences = Preferences(defaults: defaults)

    @Test func checksShowInBothSectionsByDefault() {
        let preferences = Preferences(defaults: defaults)

        #expect(preferences.showsBusinessChecks)
        #expect(preferences.showsFamilyChecks)
    }

    @Test func hiddenChecksAreRememberedAcrossLaunches() {
        let preferences = Preferences(defaults: defaults)
        preferences.showsBusinessChecks = false

        let relaunched = Preferences(defaults: defaults)

        #expect(!relaunched.showsBusinessChecks)
        #expect(relaunched.showsFamilyChecks)
    }

    @Test func eachSectionRemembersItsOwnChecksSetting() {
        let preferences = Preferences(defaults: defaults)
        preferences.showsFamilyChecks = false

        let relaunched = Preferences(defaults: defaults)

        #expect(relaunched.showsBusinessChecks)
        #expect(!relaunched.showsFamilyChecks)
    }

    @Test func theBusinessOrderIsRememberedAcrossLaunches() {
        preferences.businessOrder = .oldestFirst

        #expect(Preferences(defaults: defaults).businessOrder == .oldestFirst)
    }

    @Test func theCountModeIsRememberedAcrossLaunches() {
        preferences.countMode = .off

        #expect(Preferences(defaults: defaults).countMode == .off)
    }

    @Test func arrivalNotificationsAreOnByDefaultAndRememberedAcrossLaunches() {
        #expect(preferences.notifiesArrivals)

        preferences.notifiesArrivals = false

        #expect(!Preferences(defaults: defaults).notifiesArrivals)
    }

    @Test func verdictNotificationsAreOnByDefaultAndRememberedAcrossLaunches() {
        #expect(preferences.notifiesVerdicts)

        preferences.notifiesVerdicts = false

        #expect(!Preferences(defaults: defaults).notifiesVerdicts)
    }

    @Test func theRefreshIntervalIsOneMinuteByDefaultAndRememberedAcrossLaunches() {
        #expect(preferences.refreshInterval == .oneMinute)

        preferences.refreshInterval = .thirtyMinutes

        #expect(Preferences(defaults: defaults).refreshInterval == .thirtyMinutes)
    }

    @Test func theThemeIsNoirByDefaultAndRememberedAcrossLaunches() {
        #expect(preferences.theme == .noir)

        preferences.theme = .system

        #expect(Preferences(defaults: defaults).theme == .system)
    }
}
