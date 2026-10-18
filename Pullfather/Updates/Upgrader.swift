import Foundation
import Observation

/// Upgrades the app through its Homebrew cask: downloads while the app runs, then quits and leaves the upgrade and relaunch to Homebrew.
@Observable
final class Upgrader {
    private(set) var isUpgrading = false
    private(set) var failure: String?

    @ObservationIgnored private let homebrew: Homebrew
    @ObservationIgnored private let quit: () -> Void

    init(homebrew: Homebrew, quit: @escaping () -> Void) {
        self.homebrew = homebrew
        self.quit = quit
    }

    @discardableResult
    func upgrade() -> Task<Void, Never>? {
        guard !isUpgrading else { return nil }
        isUpgrading = true
        failure = nil
        return Task {
            do {
                try await homebrew.download()
                try homebrew.upgradeAfterQuit()
                quit()
            } catch {
                failure = "Couldn't update. \(Self.reason(for: error))"
                isUpgrading = false
            }
        }
    }

    func dismissFailure() {
        failure = nil
    }

    private static func reason(for error: any Error) -> String {
        switch error as? HomebrewFailure {
        case .notInstalled: "Homebrew isn't installed."
        case .failed(let reason): reason
        case nil: error.localizedDescription
        }
    }
}

#if DEBUG
extension Upgrader {
    static func preview() -> Upgrader {
        Upgrader(homebrew: Homebrew(download: {}, upgradeAfterQuit: {}), quit: {})
    }
}
#endif
