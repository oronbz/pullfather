import AppKit
import Network

final class SyncTriggers {
    private let store: SyncStore
    private var observations: [Task<Void, Never>] = []
    private var schedule: Task<Void, Never>?
    private var wakeObserver: (any NSObjectProtocol)?

    init(store: SyncStore) {
        self.store = store
    }

    func start() {
        observations = [
            Task { [weak self, store] in
                for await _ in Observations({ (store.account.token, store.preferences.refreshInterval) }) {
                    self?.restartSchedule()
                }
            },
            Task { [weak self] in
                var wasSatisfied = true
                for await path in NWPathMonitor() {
                    let isSatisfied = path.status == .satisfied
                    if isSatisfied, !wasSatisfied {
                        self?.restartSchedule()
                    }
                    wasSatisfied = isSatisfied
                }
            },
        ]
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartSchedule() }
        }
    }

    private func restartSchedule() {
        schedule?.cancel()
        schedule = Task { [store] in await store.syncOnSchedule() }
    }
}
