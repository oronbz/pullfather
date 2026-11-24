import Foundation

nonisolated enum ReviewState: Equatable, Sendable {
    case approved
    case changesRequested
    case commented
    case reRequested
}

/// Reviews and comment threads on a pull request as `ReviewQuery` fetched them, the viewer's own comments included.
nonisolated struct FetchedReviews: Equatable, Sendable {
    struct Author: Equatable, Sendable {
        let login: String
        let isBot: Bool
    }

    struct Comment: Equatable, Sendable {
        let author: Author?
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
        /// Missing on a dismissed review, which no rule attributes to anyone.
        let author: FetchedReviews.Author?
    }

    /// A comment on a review thread by anyone but the viewer, dated when its review was submitted.
    struct Comment: Equatable, Sendable {
        let at: Date
        let isFromBot: Bool
    }

    struct Thread: Equatable, Sendable {
        let isResolved: Bool
        let feedback: [Comment]
    }

    /// GitHub's own decision, present only where the base branch requires reviews.
    let decision: Decision?
    let reviews: [Review]
    let threads: [Thread]
    /// When anyone asked a person or team for review, first requests included.
    let requests: [Date]

    init(_ pullRequest: PullRequest, _ fetched: FetchedReviews, viewer: String) {
        decision = pullRequest.reviewDecision
        reviews = fetched.reviews
        threads = fetched.threads.map { thread in
            Thread(
                isResolved: thread.isResolved,
                feedback: thread.comments.filter { $0.author?.login != viewer }.map { Comment(at: $0.publishedAt, isFromBot: $0.author?.isBot ?? false) }
            )
        }
        requests = pullRequest.reviewRequests.filter { $0.reviewer != .other }.map(\.requestedAt)
    }

    var state: ReviewState? {
        guard !reviews.isEmpty || threads.contains(where: { !$0.feedback.isEmpty }) else {
            return nil
        }
        if isReRequested {
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

    /// Only a person's Feedback can be asked back for: a request that follows nothing but a bot's is a person's first.
    private var isReRequested: Bool {
        let peopleFeedback = reviews.filter { $0.author?.isBot != true }.map(\.submittedAt)
            + threads.flatMap(\.feedback).filter { !$0.isFromBot }.map(\.at)
        guard let latestRequest = requests.max(), let firstFeedback = peopleFeedback.min(), latestRequest > firstFeedback else {
            return false
        }
        // A comment already resolved is dealt with, so only standing Feedback can take the pull request back from the reviewers.
        let standingFeedback = reviews.map(\.submittedAt) + threads.filter { !$0.isResolved }.flatMap(\.feedback).map(\.at)
        return standingFeedback.allSatisfy { $0 < latestRequest }
    }

    private var isChangesRequested: Bool {
        decision.map { $0 == .changesRequested } ?? reviews.contains { $0.outcome == .changesRequested }
    }

    private var isApproved: Bool {
        decision.map { $0 == .approved } ?? reviews.contains { $0.outcome == .approved }
    }
}
