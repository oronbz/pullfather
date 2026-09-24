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

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var inFlight: Task<Void, Never>?

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

    init(account: Account, preferences: Preferences, now: @escaping () -> Date = Date.init) {
        self.account = account
        self.preferences = preferences
        self.now = now
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
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        guard let data = try? await account.makeTransport(token).send(SyncQuery.text, variables: SyncQuery.variables),
              let result = try? SyncQuery.decode(data),
              account.token == token
        else { return }
        let now = now()
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
                    waitingTime: RelativeTime.format(waitingSince, relativeTo: now)
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
                    reviewState: pullRequest.reviewState
                )
            }
    }
}

#if DEBUG
extension BusinessRow {
    static let previews = [
        BusinessRow(id: "3", number: 412, title: "Fix race in token refresh", url: URL(string: "https://github.com/corleone/olive-oil/pull/412")!,
                    repository: "corleone/olive-oil", author: "mike-corleone", waitingSince: .now, waitingTime: "2h"),
        BusinessRow(id: "2", number: 1088, title: "Migrate settings screen to SwiftUI", url: URL(string: "https://github.com/corleone/casino/pull/1088")!,
                    repository: "corleone/casino", author: "sonny", waitingSince: .now, waitingTime: "5h"),
        BusinessRow(id: "1", number: 1091, title: "Bump fastlane to latest", url: URL(string: "https://github.com/corleone/casino/pull/1091")!,
                    repository: "corleone/casino", author: "luca-brasi", waitingSince: .now, waitingTime: "1d"),
    ]
}

extension FamilyRow {
    static let previews = [
        FamilyRow(id: "6", number: 97, title: "Sketch the olive oil import pipeline", url: URL(string: "https://github.com/corleone/olive-oil/pull/97")!,
                  repository: "corleone/olive-oil", lastActivity: "30m", isDraft: true, reviewState: nil),
        FamilyRow(id: "5", number: 1084, title: "Refactor push routing", url: URL(string: "https://github.com/corleone/casino/pull/1084")!,
                  repository: "corleone/casino", lastActivity: "1d", isDraft: false, reviewState: .changesRequested),
        FamilyRow(id: "4", number: 1079, title: "Add offline banner", url: URL(string: "https://github.com/corleone/casino/pull/1079")!,
                  repository: "corleone/casino", lastActivity: "3d", isDraft: false, reviewState: .approved),
        FamilyRow(id: "7", number: 1102, title: "Tidy up the casino ledger", url: URL(string: "https://github.com/corleone/casino/pull/1102")!,
                  repository: "corleone/casino", lastActivity: "1w", isDraft: false, reviewState: nil),
    ]
}

extension SyncStore {
    static func preview(business: [BusinessRow]?, family: [FamilyRow]?) -> SyncStore {
        let store = SyncStore(account: .preview(signedIn: true), preferences: .preview)
        store.oldestFirst = business?.reversed()
        store.family = family
        return store
    }
}
#endif
