import Foundation
import Observation
import OSLog
import WidgetKit

extension Checks {
    fileprivate var widgetChecks: WidgetRow.Checks {
        switch self {
        case .passing: .passing
        case .running: .running
        case .failing: .failing
        }
    }
}

extension SyncStore {
    /// What the widget should show, or nil while there is nothing new to say: a launch that has not synced yet
    /// must not overwrite the last good snapshot. Signed out is something to say, so it clears the last account's rows.
    var widgetSnapshot: WidgetSnapshot? {
        guard account.token != nil, !needsSignInAgain else {
            return WidgetSnapshot(business: nil, family: nil, businessRows: [], familyRows: [], syncedAt: lastSyncedAt, needsSignIn: true)
        }
        guard let lastSyncedAt else { return nil }
        let showsBusinessChecks = preferences.showsBusinessChecks
        let showsFamilyChecks = preferences.showsFamilyChecks
        return WidgetSnapshot(
            business: business?.count,
            family: family?.count,
            businessRows: (business ?? []).prefix(WidgetSnapshot.businessRowLimit).map {
                WidgetRow(id: $0.id, reference: $0.reference, title: $0.title, url: $0.url, elapsed: $0.waitingTime, checks: showsBusinessChecks ? $0.checks?.widgetChecks : nil)
            },
            familyRows: (family ?? []).prefix(WidgetSnapshot.familyRowLimit).map {
                WidgetRow(id: $0.id, reference: $0.reference, title: $0.title, url: $0.url, elapsed: $0.lastActivity, checks: showsFamilyChecks ? $0.checks?.widgetChecks : nil)
            },
            syncedAt: lastSyncedAt,
            needsSignIn: false,
            staleAfter: max(WidgetSnapshot.minimumStaleAfter, preferences.refreshInterval.staleAfter)
        )
    }
}

extension WidgetSnapshot {
    /// A Sync that changes nothing the widget shows only moves `syncedAt`, so it would reload the widget every minute for no visible change.
    /// A slow heartbeat still reloads it, so the stale flip scheduled from `syncedAt` never fires while Syncs keep succeeding.
    fileprivate func needsReload(after reloaded: WidgetSnapshot?) -> Bool {
        guard let reloaded else { return true }
        var visible = self
        visible.syncedAt = reloaded.syncedAt
        guard visible == reloaded else { return true }
        guard let syncedAt, let reloadedAt = reloaded.syncedAt else { return syncedAt != reloaded.syncedAt }
        return syncedAt.timeIntervalSince(reloadedAt) >= staleAfter / 3
    }
}

final class WidgetPublisher {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.oronbz.Pullfather", category: "Widget")

    private let store: SyncStore
    private let file: WidgetSnapshotFile
    private let reload: () -> Void
    private var published: WidgetSnapshot?
    private var reloaded: WidgetSnapshot?
    private var updates: Task<Void, Never>?

    init(
        store: SyncStore,
        file: WidgetSnapshotFile = .standard,
        reload: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.kind) }
    ) {
        self.store = store
        self.file = file
        self.reload = reload
    }

    deinit {
        updates?.cancel()
    }

    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self, store] in
            for await snapshot in Observations({ store.widgetSnapshot }) {
                guard let self else { return }
                publish(snapshot)
            }
        }
    }

    func publish(_ snapshot: WidgetSnapshot?) {
        guard let snapshot, snapshot != published else { return }
        do {
            try file.write(snapshot)
        } catch {
            Self.logger.error("Couldn't write the widget snapshot: \(error.localizedDescription, privacy: .public)")
            return
        }
        published = snapshot
        guard snapshot.needsReload(after: reloaded) else { return }
        reloaded = snapshot
        reload()
    }
}
