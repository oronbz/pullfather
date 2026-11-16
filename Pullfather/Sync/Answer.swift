import Foundation

/// What other reviewers have already said on a Favor, and who said it.
nonisolated struct Answer: Equatable, Sendable {
    enum Opinion: Equatable, Sendable {
        case changesRequested
        case commented
        case approved

        var title: String {
            switch self {
            case .changesRequested: "Changes requested"
            case .commented: "Commented"
            case .approved: "Approved"
            }
        }
    }

    let opinion: Opinion
    /// Only those who gave `opinion`, most recent first.
    let reviewers: [String]

    var attribution: String {
        let named = reviewers.prefix(2).joined(separator: ", ")
        let others = reviewers.count - 2
        return others > 0 ? "by \(named) +\(others)" : "by \(named)"
    }
}

extension Answer {
    init?(_ pullRequest: PullRequest, _ fetched: FetchedReviews, viewer: String) {
        func reviewer(_ author: FetchedReviews.Author?) -> String? {
            guard let author, !author.isBot, author.login != viewer, author.login != pullRequest.author else { return nil }
            return author.login
        }
        func decisions(_ outcome: ReviewActivity.Outcome) -> [(String, Date)] {
            fetched.reviews.filter { $0.outcome == outcome }.compactMap { review in
                reviewer(review.author).map { ($0, review.submittedAt) }
            }
        }
        let comments: [(String, Date)] = fetched.threads.filter { !$0.isResolved }.flatMap(\.comments).compactMap { comment in
            reviewer(comment.author).map { ($0, comment.publishedAt) }
        }
        let said: [(opinion: Opinion, by: [(String, Date)])] = [
            (.changesRequested, decisions(.changesRequested)),
            (.commented, comments),
            (.approved, decisions(.approved)),
        ]
        guard let strictest = said.first(where: { !$0.by.isEmpty }) else { return nil }
        let latest = Dictionary(strictest.by) { max($0, $1) }
        self.init(
            opinion: strictest.opinion,
            reviewers: latest.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.map(\.key)
        )
    }
}
