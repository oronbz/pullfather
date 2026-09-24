import Foundation
import Observation

enum BusinessOrder: String, CaseIterable {
    case newestFirst
    case oldestFirst
}

@Observable
final class Preferences {
    private static let businessOrderKey = "businessOrder"

    @ObservationIgnored private let defaults: UserDefaults

    var businessOrder: BusinessOrder {
        didSet { defaults.set(businessOrder.rawValue, forKey: Self.businessOrderKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        businessOrder = defaults.string(forKey: Self.businessOrderKey).flatMap(BusinessOrder.init) ?? .newestFirst
    }
}

#if DEBUG
extension Preferences {
    static var preview: Preferences {
        Preferences(defaults: UserDefaults(suiteName: "PullfatherPreview-\(UUID().uuidString)")!)
    }
}
#endif
