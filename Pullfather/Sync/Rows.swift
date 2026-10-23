import Foundation

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

    func isVerdict(since previous: ReviewState?) -> Bool {
        reviewState != nil && reviewState != previous
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
#endif
