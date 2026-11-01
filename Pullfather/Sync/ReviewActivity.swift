import Foundation

nonisolated enum ReviewState: Equatable, Sendable {
    case approved
    case changesRequested
    case commented
    case reRequested
}

/// Reviews and comment threads on a pull request as `ReviewQuery` fetched them, the author's own comments included.
nonisolated struct FetchedReviews: Equatable, Sendable {
    struct Comment: Equatable, Sendable {
        let author: String?
        let publishedAt: Date
    }

    struct Thread: Equatable, Sendable {
        let isResolved: Bool
        let comments: [Comment]
    }

    var reviews: [ReviewActivity.Review] = []
    var threads: [Thread] = []
}

/// What reviewers have said on a pull request and when its author last asked them back, which together give its Review State.
nonisolated struct ReviewActivity: Equatable, Sendable {
    enum Decision: String, Sendable {
        case approved = "APPROVED"
        case changesRequested = "CHANGES_REQUESTED"
        case reviewRequired = "REVIEW_REQUIRED"
    }

    enum Outcome: String, Sendable {
        case approved = "APPROVED"
        case changesRequested = "CHANGES_REQUESTED"
        case dismissed = "DISMISSED"
    }

    struct Review: Equatable, Sendable {
        let outcome: Outcome
        let submittedAt: Date
    }

    struct Thread: Equatable, Sendable {
        let isResolved: Bool
        /// When anyone but the author commented on it.
        let feedback: [Date]
    }

    /// GitHub's own decision, present only where the base branch requires reviews.
    let decision: Decision?
    let reviews: [Review]
    let threads: [Thread]
    /// When anyone asked a person or team for review, first requests included.
    let requests: [Date]

    init(_ pullRequest: PullRequest, _ fetched: FetchedReviews) {
        decision = pullRequest.reviewDecision
        reviews = fetched.reviews
        threads = fetched.threads.map { thread in
            Thread(isResolved: thread.isResolved, feedback: thread.comments.filter { $0.author != pullRequest.author }.map(\.publishedAt))
        }
        requests = pullRequest.reviewRequests.filter { $0.reviewer != .other }.map(\.requestedAt)
    }

    var state: ReviewState? {
        guard let latestFeedback = (reviews.map(\.submittedAt) + threads.flatMap(\.feedback)).max() else {
            return nil
        }
        if let latestRequest = requests.max(), latestRequest > latestFeedback {
            return .reRequested
        }
        if isChangesRequested {
            return .changesRequested
        }
        if threads.contains(where: { !$0.isResolved && !$0.feedback.isEmpty }) {
            return .commented
        }
        if isApproved {
            return .approved
        }
        return nil
    }

    private var isChangesRequested: Bool {
        decision.map { $0 == .changesRequested } ?? reviews.contains { $0.outcome == .changesRequested }
    }

    private var isApproved: Bool {
        decision.map { $0 == .approved } ?? reviews.contains { $0.outcome == .approved }
    }
}
