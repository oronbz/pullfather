import Foundation
@testable import Pullfather

extension BusinessRow {
    static func fixture(_ number: Int, author: String = "sonny", title: String = "Migrate settings screen to SwiftUI") -> BusinessRow {
        BusinessRow(
            id: "PR_\(number)", number: number, title: title, url: URL(string: "https://github.com/corleone/casino/pull/\(number)")!,
            repository: "corleone/casino", branch: "swiftui-settings", author: author, avatarURL: nil, waitingSince: .now, waitingTime: "now",
            lineChanges: LineChanges(additions: 2, deletions: 4), checks: nil, isRequestedByName: true, isRequestedThroughTeam: false
        )
    }
}

extension FamilyRow {
    static func fixture(_ number: Int, title: String = "Add offline banner", reviewState: ReviewState? = .approved) -> FamilyRow {
        FamilyRow(
            id: "PR_\(number)", number: number, title: title, url: URL(string: "https://github.com/corleone/casino/pull/\(number)")!,
            repository: "corleone/casino", branch: "offline-banner", lastActivity: "now",
            lineChanges: LineChanges(additions: 2, deletions: 4), isDraft: false, reviewState: reviewState, checks: nil
        )
    }
}
