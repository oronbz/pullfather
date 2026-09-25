import Foundation
import Observation

enum BusinessOrder: String, CaseIterable {
    case newestFirst
    case oldestFirst
}

enum CountMode: String, CaseIterable {
    case business
    case family
    case off
}

enum Theme: String, CaseIterable {
    case noir
    case bone
    case system
}

enum RefreshInterval: Int, CaseIterable {
    case oneMinute = 1
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case sixtyMinutes = 60

    var duration: Duration {
        .seconds(rawValue * 60)
    }

    var staleAfter: TimeInterval {
        TimeInterval(rawValue * 60 * 2)
    }
}

@Observable
final class Preferences {
    private static let businessOrderKey = "businessOrder"
    private static let countModeKey = "countMode"
    private static let refreshIntervalKey = "refreshIntervalMinutes"
    private static let notifiesArrivalsKey = "notifiesArrivals"
    private static let themeKey = "theme"

    @ObservationIgnored private let defaults: UserDefaults

    var businessOrder: BusinessOrder {
        didSet { defaults.set(businessOrder.rawValue, forKey: Self.businessOrderKey) }
    }

    var countMode: CountMode {
        didSet { defaults.set(countMode.rawValue, forKey: Self.countModeKey) }
    }

    var refreshInterval: RefreshInterval {
        didSet { defaults.set(refreshInterval.rawValue, forKey: Self.refreshIntervalKey) }
    }

    var notifiesArrivals: Bool {
        didSet { defaults.set(notifiesArrivals, forKey: Self.notifiesArrivalsKey) }
    }

    var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: Self.themeKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        businessOrder = defaults.string(forKey: Self.businessOrderKey).flatMap(BusinessOrder.init) ?? .newestFirst
        countMode = defaults.string(forKey: Self.countModeKey).flatMap(CountMode.init) ?? .business
        refreshInterval = RefreshInterval(rawValue: defaults.integer(forKey: Self.refreshIntervalKey)) ?? .oneMinute
        notifiesArrivals = defaults.object(forKey: Self.notifiesArrivalsKey) as? Bool ?? true
        theme = defaults.string(forKey: Self.themeKey).flatMap(Theme.init) ?? .noir
    }
}

#if DEBUG
extension Preferences {
    static var preview: Preferences {
        Preferences(defaults: UserDefaults(suiteName: "PullfatherPreview-\(UUID().uuidString)")!)
    }
}
#endif
