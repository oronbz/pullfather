import Foundation
import Testing
@testable import Pullfather

final class PreferencesTests {
    private let defaultsSuite = "PreferencesTests-\(UUID().uuidString)"
    private lazy var defaults = UserDefaults(suiteName: defaultsSuite)!

    deinit {
        UserDefaults().removePersistentDomain(forName: defaultsSuite)
    }

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
}
