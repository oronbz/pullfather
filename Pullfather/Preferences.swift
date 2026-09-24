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

@Observable
final class Preferences {
    private static let businessOrderKey = "businessOrder"
    private static let countModeKey = "countMode"

    @ObservationIgnored private let defaults: UserDefaults

    var businessOrder: BusinessOrder {
        didSet { defaults.set(businessOrder.rawValue, forKey: Self.businessOrderKey) }
    }

    var countMode: CountMode {
        didSet { defaults.set(countMode.rawValue, forKey: Self.countModeKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        businessOrder = defaults.string(forKey: Self.businessOrderKey).flatMap(BusinessOrder.init) ?? .newestFirst
        countMode = defaults.string(forKey: Self.countModeKey).flatMap(CountMode.init) ?? .business
    }
}

#if DEBUG
extension Preferences {
    static var preview: Preferences {
        Preferences(defaults: UserDefaults(suiteName: "PullfatherPreview-\(UUID().uuidString)")!)
    }
}
#endif
