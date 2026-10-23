import Foundation

/// A `UserDefaults` suite of its own that is erased when the test releases it.
final class TestDefaults {
    private let suite = "PullfatherTests-\(UUID().uuidString)"
    lazy var defaults = UserDefaults(suiteName: suite)!

    deinit {
        UserDefaults().removePersistentDomain(forName: suite)
    }
}
