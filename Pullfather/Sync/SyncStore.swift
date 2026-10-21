import Foundation
import Observation

protocol ListedPullRequest {
    var title: String { get }
    var url: URL { get }
    var repository: String { get }
    var branch: String { get }
}

extension ListedPullRequest {
    var repositoryURL: URL {
        URL(string: "https://github.com")!.appending(path: repository)
    }
}

struct BusinessRow: Identifiable, Equatable, ListedPullRequest {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let repository: String
    let branch: String
    let author: String
    let avatarURL: URL?
    let waitingSince: Date
    let waitingTime: String
    let lineChanges: LineChanges
    let checks: Checks?
    var isRequestedByName: Bool
    let isRequestedThroughTeam: Bool

    var reference: String {
        "\(repository) #\(number)"
    }
}

struct FamilyRow: Identifiable, Equatable, ListedPullRequest {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let repository: String
    let branch: String
    let lastActivity: String
    let lineChanges: LineChanges
    let isDraft: Bool
    let reviewState: ReviewState?
    let checks: Checks?

    var reference: String {
        "\(repository) #\(number)"
    }

    func isVerdict(since previous: FamilyRow) -> Bool {
        reviewState != nil && reviewState != previous.reviewState
    }
}

enum PanelRowID: Hashable {
    case business(String)
    case family(String)
}

enum SelectionMove {
    case up
    case down
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
    private var requestedSelection: PanelRowID?
    private var removingIDs: Set<String> = []
    private var approvingIDs: Set<String> = []
    private(set) var actionFailure: String?
    var approvalCandidate: String?

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    @ObservationIgnored private var consecutiveFailures = 0
    @ObservationIgnored private var syncedViewer: String?
    @ObservationIgnored private var removedIDs: Set<String> = []
    @ObservationIgnored var onArrivals: ([BusinessRow]) -> Void = { _ in }
    @ObservationIgnored var onVerdicts: ([FamilyRow]) -> Void = { _ in }

    private static let firstRetry = Duration.seconds(15)

    private var businessOldestFirst: [BusinessRow]? {
        oldestFirst?.filter { !approvingIDs.contains($0.id) && (!removingIDs.contains($0.id) || $0.isRequestedThroughTeam) }
    }

    var business: [BusinessRow]? {
        switch preferences.businessOrder {
        case .oldestFirst: businessOldestFirst
        case .newestFirst: businessOldestFirst?.reversed()
        }
    }

    private var rows: [(id: PanelRowID, url: URL)] {
        guard !needsSignInAgain else { return [] }
        return (business ?? []).map { (.business($0.id), $0.url) } + (family ?? []).map { (.family($0.id), $0.url) }
    }

    var selection: PanelRowID? {
        rows.contains { $0.id == requestedSelection } ? requestedSelection : nil
    }

    var selectedURL: URL? {
        rows.first { $0.id == selection }?.url
    }

    func select(_ row: PanelRowID?) {
        requestedSelection = row
    }

    func moveSelection(_ move: SelectionMove) {
        let ids = rows.map(\.id)
        guard let last = ids.indices.last else { return }
        let index = switch (ids.firstIndex { $0 == selection }, move) {
        case (nil, .down): 0
        case (nil, .up): last
        case (let index?, .down): min(index + 1, last)
        case (let index?, .up): max(index - 1, 0)
        }
        requestedSelection = ids[index]
    }

    @discardableResult
    func removeMeFromReviewers(_ id: String) -> Task<Void, Never>? {
        guard let token = account.token, let viewer = syncedViewer,
              let row = oldestFirst?.first(where: { $0.id == id }), row.isRequestedByName, !removingIDs.contains(id), !approvingIDs.contains(id)
        else { return nil }
        let request = RESTRequest.removingRequestedReviewer(viewer, repository: row.repository, number: row.number)
        if !row.isRequestedThroughTeam {
            selectNeighbour(of: .business(id))
        }
        removingIDs.insert(id)
        actionFailure = nil
        let transport = account.makeTransport(token)
        return Task {
            defer { removingIDs.remove(id) }
            do throws(GitHubFailure) {
                try await transport.send(request)
            } catch {
                actionFailure = "Couldn't remove you from #\(row.number). \(Self.reason(for: error))"
                return
            }
            oldestFirst = oldestFirst?.compactMap { row in
                guard row.id == id else { return row }
                guard row.isRequestedThroughTeam else {
                    removedIDs.insert(id)
                    return nil
                }
                var stillRequested = row
                stillRequested.isRequestedByName = false
                return stillRequested
            }
            do throws(GitHubFailure) {
                try await transport.send(.unsubscribing(from: id))
            } catch {
                actionFailure = "Removed you from #\(row.number), but couldn't mute its notifications. \(Self.reason(for: error))"
            }
        }
    }

    @discardableResult
    func approve(_ id: String) -> Task<Void, Never>? {
        guard let token = account.token,
              let row = oldestFirst?.first(where: { $0.id == id }), !approvingIDs.contains(id), !removingIDs.contains(id)
        else { return nil }
        approvalCandidate = nil
        selectNeighbour(of: .business(id))
        approvingIDs.insert(id)
        actionFailure = nil
        let transport = account.makeTransport(token)
        return Task {
            defer { approvingIDs.remove(id) }
            do throws(GitHubFailure) {
                try await transport.send(.approving(id))
            } catch {
                actionFailure = "Couldn't approve #\(row.number). \(Self.reason(for: error))"
                return
            }
            removedIDs.insert(id)
            oldestFirst = oldestFirst?.filter { $0.id != id }
        }
    }

    func dismissActionFailure() {
        actionFailure = nil
    }

    private func selectNeighbour(of row: PanelRowID) {
        let ids = rows.map(\.id)
        guard selection == row, let index = ids.firstIndex(of: row) else { return }
        requestedSelection = ids.indices.contains(index + 1) ? ids[index + 1] : ids.indices.contains(index - 1) ? ids[index - 1] : nil
    }

    private static func reason(for failure: GitHubFailure) -> String {
        switch failure {
        case .offline: "Can't reach GitHub."
        case .rateLimited: "GitHub is rate limiting this token."
        case .unauthorised: "GitHub didn't accept your token."
        case .other(let reason): reason
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
            syncedViewer = nil
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
        let sameViewer = syncedViewer == result.viewer
        let previousIDs = sameViewer ? businessOldestFirst.map { Set($0.map(\.id)) } : nil
        let previousFamily = sameViewer ? family.map { Dictionary($0.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) } : nil
        if syncedViewer != result.viewer {
            removedIDs = []
        }
        syncedViewer = result.viewer
        let stillIndexed = Set(result.business.filter { removedIDs.contains($0.id) && !$0.pendingReviewers.contains(.user(result.viewer)) }.map(\.id))
        removedIDs = stillIndexed
        oldestFirst = result.business
            .filter { !$0.isDraft && !stillIndexed.contains($0.id) }
            .map { pullRequest in
                let waitingSince = pullRequest.waitingSince(viewer: result.viewer)
                return BusinessRow(
                    id: pullRequest.id,
                    number: pullRequest.number,
                    title: pullRequest.title,
                    url: pullRequest.url,
                    repository: pullRequest.repository,
                    branch: pullRequest.branch,
                    author: pullRequest.author,
                    avatarURL: pullRequest.authorAvatarURL,
                    waitingSince: waitingSince,
                    waitingTime: RelativeTime.format(waitingSince, relativeTo: now),
                    lineChanges: pullRequest.lineChanges,
                    checks: pullRequest.checks,
                    isRequestedByName: pullRequest.pendingReviewers.contains(.user(result.viewer)),
                    isRequestedThroughTeam: pullRequest.pendingReviewers.contains(.team)
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
                    branch: pullRequest.branch,
                    lastActivity: RelativeTime.format(pullRequest.updatedAt, relativeTo: now),
                    lineChanges: pullRequest.lineChanges,
                    isDraft: pullRequest.isDraft,
                    reviewState: pullRequest.reviewState,
                    checks: pullRequest.checks
                )
            }
        if let previousIDs, let arrivals = businessOldestFirst?.filter({ !previousIDs.contains($0.id) }), !arrivals.isEmpty {
            onArrivals(arrivals)
        }
        if let previousFamily, let verdicts = family?.filter({ previousFamily[$0.id].map($0.isVerdict(since:)) ?? false }), !verdicts.isEmpty {
            onVerdicts(verdicts)
        }
    }
}

#if DEBUG
extension BusinessRow {
    static let previews = [
        BusinessRow(id: "3", number: 412, title: "Fix race in token refresh", url: URL(string: "https://github.com/corleone/olive-oil/pull/412")!,
                    repository: "corleone/olive-oil", branch: "feature/GETT-171154-rider-in-app-voice-contact-with-the-driver", author: "mike-corleone", avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1001?s=60&v=4"), waitingSince: .now, waitingTime: "2h", lineChanges: LineChanges(additions: 48, deletions: 12), checks: .passing, isRequestedByName: true, isRequestedThroughTeam: false),
        BusinessRow(id: "2", number: 1088, title: "Migrate settings screen to SwiftUI", url: URL(string: "https://github.com/corleone/casino/pull/1088")!,
                    repository: "corleone/casino", branch: "swiftui-settings", author: "sonny", avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1002?s=60&v=4"), waitingSince: .now, waitingTime: "5h", lineChanges: LineChanges(additions: 1240, deletions: 310), checks: .running, isRequestedByName: false, isRequestedThroughTeam: true),
        BusinessRow(id: "1", number: 1091, title: "Bump fastlane to latest", url: URL(string: "https://github.com/corleone/casino/pull/1091")!,
                    repository: "corleone/casino", branch: "bump-fastlane", author: "luca-brasi", avatarURL: nil, waitingSince: .now, waitingTime: "1d", lineChanges: LineChanges(additions: 2, deletions: 2), checks: .failing, isRequestedByName: true, isRequestedThroughTeam: false),
    ]
}

extension FamilyRow {
    static let previews = [
        FamilyRow(id: "6", number: 97, title: "Sketch the olive oil import pipeline", url: URL(string: "https://github.com/corleone/olive-oil/pull/97")!,
                  repository: "corleone/olive-oil", branch: "olive-oil-import", lastActivity: "30m", lineChanges: LineChanges(additions: 530, deletions: 0), isDraft: true, reviewState: nil, checks: nil),
        FamilyRow(id: "5", number: 1084, title: "Refactor push routing", url: URL(string: "https://github.com/corleone/casino/pull/1084")!,
                  repository: "corleone/casino", branch: "push-routing", lastActivity: "1d", lineChanges: LineChanges(additions: 214, deletions: 377), isDraft: false, reviewState: .changesRequested, checks: .failing),
        FamilyRow(id: "4", number: 1079, title: "Add offline banner", url: URL(string: "https://github.com/corleone/casino/pull/1079")!,
                  repository: "corleone/casino", branch: "offline-banner", lastActivity: "3d", lineChanges: LineChanges(additions: 86, deletions: 9), isDraft: false, reviewState: .approved, checks: .passing),
        FamilyRow(id: "7", number: 1102, title: "Tidy up the casino ledger", url: URL(string: "https://github.com/corleone/casino/pull/1102")!,
                  repository: "corleone/casino", branch: "casino-ledger", lastActivity: "1w", lineChanges: LineChanges(additions: 31, deletions: 58), isDraft: false, reviewState: nil, checks: .running),
    ]
}

extension SyncStore {
    static func preview(business: [BusinessRow]?, family: [FamilyRow]?, failure: GitHubFailure? = nil, actionFailure: String? = nil) -> SyncStore {
        let store = SyncStore(account: .preview(signedIn: true), preferences: .preview)
        store.oldestFirst = business?.reversed()
        store.family = family
        store.lastSyncedAt = .now.addingTimeInterval(-4 * 60)
        store.failure = failure.map { ($0, "ghp_preview") }
        store.actionFailure = actionFailure
        return store
    }
}
#endif
