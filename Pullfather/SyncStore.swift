import Foundation
import Observation

struct BusinessRow: Identifiable, Equatable {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let repository: String
    let author: String
    let waitingSince: Date
    let waitingTime: String
    let checks: Checks?

    var metadata: String {
        "\(repository) #\(number) · \(waitingTime)"
    }
}

struct FamilyRow: Identifiable, Equatable {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let repository: String
    let lastActivity: String
    let isDraft: Bool
    let reviewState: ReviewState?
    let checks: Checks?

    var metadata: String {
        "\(repository) #\(number) · \(lastActivity)"
    }
}

@Observable
final class SyncStore {
    let account: Account
    let preferences: Preferences
    private(set) var isSyncing = false
    private var oldestFirst: [BusinessRow]?
    private(set) var family: [FamilyRow]?
    private(set) var lastSyncedAt: Date?
    private var failure: (reason: GitHubFailure, token: String)?

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    @ObservationIgnored private var consecutiveFailures = 0

    private static let firstRetry = Duration.seconds(15)

    var business: [BusinessRow]? {
        switch preferences.businessOrder {
        case .oldestFirst: oldestFirst
        case .newestFirst: oldestFirst?.reversed()
        }
    }

    var countText: String? {
        let count = switch preferences.countMode {
        case .business: business?.count
        case .family: family?.count
        case .off: nil as Int?
        }
        guard let count, count > 0 else { return nil }
        return "\(count)"
    }

    var lastFailure: GitHubFailure? {
        guard let failure, failure.token == account.token else { return nil }
        return failure.reason
    }

    var isStale: Bool {
        guard lastFailure == nil else { return true }
        guard let lastSyncedAt else { return false }
        return now().timeIntervalSince(lastSyncedAt) > preferences.refreshInterval.staleAfter
    }

    var needsSignInAgain: Bool {
        lastFailure == .unauthorised
    }

    var statusLine: String? {
        guard isStale, !needsSignInAgain else { return nil }
        let now = now()
        let reason: String? = switch lastFailure {
        case nil: nil
        case .offline: "Offline"
        case .rateLimited: "Rate limited"
        case .unauthorised, .other: "Sync failed"
        }
        let detail: String? = switch lastFailure {
        case .rateLimited(let resetsAt?) where resetsAt.timeIntervalSince(now) >= 60:
            "resets in \(RelativeTime.format(now, relativeTo: resetsAt))"
        default:
            lastSyncedAt.map { lastSyncedAt in
                let age = RelativeTime.format(lastSyncedAt, relativeTo: now)
                return age == "now" ? "synced just now" : "synced \(age) ago"
            }
        }
        let line = [reason, detail].compactMap(\.self).joined(separator: " · ")
        return line.prefix(1).uppercased() + line.dropFirst()
    }

    init(
        account: Account,
        preferences: Preferences,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.account = account
        self.preferences = preferences
        self.now = now
        self.sleep = sleep
    }

    func syncOnSchedule() async {
        repeat {
            if !needsSignInAgain {
                await requestSync().value
            }
        } while (try? await sleep(delayBeforeScheduledSync)) != nil
    }

    private var delayBeforeScheduledSync: Duration {
        let interval = preferences.refreshInterval.duration
        let now = now()
        switch lastFailure {
        case nil, .unauthorised:
            return interval
        case .rateLimited(let resetsAt?) where resetsAt > now:
            return max(.seconds(resetsAt.timeIntervalSince(now).rounded(.up)), Self.firstRetry)
        case .rateLimited, .offline, .other:
            return min(Self.firstRetry * (1 << min(max(consecutiveFailures - 1, 0), 10)), interval)
        }
    }

    @discardableResult
    func requestSync() -> Task<Void, Never> {
        if let inFlight {
            return inFlight
        }
        let task = Task {
            var token: String?
            repeat {
                token = account.token
                await sync(token: token)
            } while account.token != token
            inFlight = nil
        }
        inFlight = task
        return task
    }

    private func sync(token: String?) async {
        guard let token else {
            oldestFirst = nil
            family = nil
            lastSyncedAt = nil
            failure = nil
            consecutiveFailures = 0
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        let result: SyncResult
        do throws(GitHubFailure) {
            let data = try await account.makeTransport(token).send(SyncQuery.text, variables: SyncQuery.variables)
            guard let decoded = try? SyncQuery.decode(data) else { throw .other("GitHub sent an unexpected response.") }
            result = decoded
        } catch {
            failure = (error, token)
            consecutiveFailures += 1
            return
        }
        guard account.token == token else { return }
        let now = now()
        lastSyncedAt = now
        failure = nil
        consecutiveFailures = 0
        oldestFirst = result.business
            .filter { !$0.isDraft }
            .map { pullRequest in
                let waitingSince = pullRequest.waitingSince(viewer: result.viewer)
                return BusinessRow(
                    id: pullRequest.id,
                    number: pullRequest.number,
                    title: pullRequest.title,
                    url: pullRequest.url,
                    repository: pullRequest.repository,
                    author: pullRequest.author,
                    waitingSince: waitingSince,
                    waitingTime: RelativeTime.format(waitingSince, relativeTo: now),
                    checks: pullRequest.checks
                )
            }
            .sorted { ($0.waitingSince, $0.number) < ($1.waitingSince, $1.number) }
        family = result.family
            .sorted { ($0.updatedAt, $0.number) > ($1.updatedAt, $1.number) }
            .map { pullRequest in
                FamilyRow(
                    id: pullRequest.id,
                    number: pullRequest.number,
                    title: pullRequest.title,
                    url: pullRequest.url,
                    repository: pullRequest.repository,
                    lastActivity: RelativeTime.format(pullRequest.updatedAt, relativeTo: now),
                    isDraft: pullRequest.isDraft,
                    reviewState: pullRequest.reviewState,
                    checks: pullRequest.checks
                )
            }
    }
}

#if DEBUG
extension BusinessRow {
    static let previews = [
        BusinessRow(id: "3", number: 412, title: "Fix race in token refresh", url: URL(string: "https://github.com/corleone/olive-oil/pull/412")!,
                    repository: "corleone/olive-oil", author: "mike-corleone", waitingSince: .now, waitingTime: "2h", checks: .passing),
        BusinessRow(id: "2", number: 1088, title: "Migrate settings screen to SwiftUI", url: URL(string: "https://github.com/corleone/casino/pull/1088")!,
                    repository: "corleone/casino", author: "sonny", waitingSince: .now, waitingTime: "5h", checks: .running),
        BusinessRow(id: "1", number: 1091, title: "Bump fastlane to latest", url: URL(string: "https://github.com/corleone/casino/pull/1091")!,
                    repository: "corleone/casino", author: "luca-brasi", waitingSince: .now, waitingTime: "1d", checks: .failing),
    ]
}

extension FamilyRow {
    static let previews = [
        FamilyRow(id: "6", number: 97, title: "Sketch the olive oil import pipeline", url: URL(string: "https://github.com/corleone/olive-oil/pull/97")!,
                  repository: "corleone/olive-oil", lastActivity: "30m", isDraft: true, reviewState: nil, checks: nil),
        FamilyRow(id: "5", number: 1084, title: "Refactor push routing", url: URL(string: "https://github.com/corleone/casino/pull/1084")!,
                  repository: "corleone/casino", lastActivity: "1d", isDraft: false, reviewState: .changesRequested, checks: .failing),
        FamilyRow(id: "4", number: 1079, title: "Add offline banner", url: URL(string: "https://github.com/corleone/casino/pull/1079")!,
                  repository: "corleone/casino", lastActivity: "3d", isDraft: false, reviewState: .approved, checks: .passing),
        FamilyRow(id: "7", number: 1102, title: "Tidy up the casino ledger", url: URL(string: "https://github.com/corleone/casino/pull/1102")!,
                  repository: "corleone/casino", lastActivity: "1w", isDraft: false, reviewState: nil, checks: .running),
    ]
}

extension SyncStore {
    static func preview(business: [BusinessRow]?, family: [FamilyRow]?, failure: GitHubFailure? = nil) -> SyncStore {
        let store = SyncStore(account: .preview(signedIn: true), preferences: .preview)
        store.oldestFirst = business?.reversed()
        store.family = family
        store.lastSyncedAt = .now.addingTimeInterval(-4 * 60)
        store.failure = failure.map { ($0, "ghp_preview") }
        return store
    }
}
#endif
