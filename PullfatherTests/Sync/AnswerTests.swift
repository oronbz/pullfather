import Foundation
import Testing
@testable import Pullfather

final class AnswerTests: SyncStoreTestCase {
    /// A Favor authored by `sonny`, asking `tomhagen`, the signed-in viewer, by name.
    private func favor(reviews: [SyncFixture.Review] = [], threads: [SyncFixture.Thread] = [], pending: [SyncFixture.Reviewer] = [.user("tomhagen")]) -> SyncFixture.PullRequest {
        SyncFixture.PullRequest(number: 1, author: "sonny", createdAt: ago(hours: 2), pending: pending, reviews: reviews, threads: threads)
    }

    private func answer(of pullRequest: SyncFixture.PullRequest) async throws -> Answer? {
        let store = try await sync(SyncFixture(business: [pullRequest]).data)
        return try #require(store.business?.first).answer
    }

    @Test func anotherReviewersApprovalAnswersApproved() async throws {
        #expect(try await answer(of: favor(reviews: [review("APPROVED", by: "tessio")])) == Answer(opinion: .approved, reviewers: ["tessio"]))
    }

    @Test func anotherReviewersRequestForChangesAnswersChangesRequested() async throws {
        #expect(try await answer(of: favor(reviews: [review("CHANGES_REQUESTED", by: "tessio")])) == Answer(opinion: .changesRequested, reviewers: ["tessio"]))
    }

    @Test func anotherReviewersUnresolvedCommentAnswersCommented() async throws {
        #expect(try await answer(of: favor(threads: [thread(("tessio", 30))])) == Answer(opinion: .commented, reviewers: ["tessio"]))
    }

    @Test func aRequestForChangesOutranksAnApprovalAndNamesOnlyItsReviewer() async throws {
        let pullRequest = favor(reviews: [review("CHANGES_REQUESTED", minutesAgo: 60, by: "tessio"), review("APPROVED", minutesAgo: 10, by: "clemenza")])

        #expect(try await answer(of: pullRequest) == Answer(opinion: .changesRequested, reviewers: ["tessio"]))
    }

    @Test func anUnresolvedCommentOutranksAnApproval() async throws {
        let pullRequest = favor(reviews: [review("APPROVED", minutesAgo: 10, by: "clemenza")], threads: [thread(("tessio", 30))])

        #expect(try await answer(of: pullRequest) == Answer(opinion: .commented, reviewers: ["tessio"]))
    }

    @Test func aRequestForChangesOutranksAnUnresolvedComment() async throws {
        let pullRequest = favor(reviews: [review("CHANGES_REQUESTED", by: "tessio")], threads: [thread(("clemenza", 10))])

        #expect(try await answer(of: pullRequest) == Answer(opinion: .changesRequested, reviewers: ["tessio"]))
    }

    @Test func reviewersAreNamedMostRecentFirstEachOnce() async throws {
        let pullRequest = favor(threads: [thread(("tessio", 50), ("clemenza", 10)), thread(("tessio", 5))])

        #expect(try await answer(of: pullRequest)?.reviewers == ["tessio", "clemenza"])
    }

    @Test func noReviewsAnswerNothing() async throws {
        #expect(try await answer(of: favor()) == nil)
    }

    @Test func myOwnReviewAndCommentsAnswerNothing() async throws {
        #expect(try await answer(of: favor(reviews: [review("APPROVED", by: "tomhagen")], threads: [thread(("tomhagen", 30))])) == nil)
    }

    @Test func theAuthorsRepliesAnswerNothing() async throws {
        #expect(try await answer(of: favor(threads: [thread(("sonny", 30))])) == nil)
    }

    @Test func aBotsApprovalAndCommentsAnswerNothing() async throws {
        let comment = SyncFixture.Comment(author: "copilot-pull-request-reviewer", at: ago(minutes: 30), isBot: true)
        let pullRequest = favor(reviews: [review("APPROVED", by: "dependabot", isBot: true)], threads: [SyncFixture.Thread(comments: [comment])])

        #expect(try await answer(of: pullRequest) == nil)
    }

    @Test func aDismissedApprovalAnswersNothing() async throws {
        #expect(try await answer(of: favor(reviews: [review("DISMISSED", by: "tessio")])) == nil)
    }

    @Test func aSummaryOnlyCommentReviewAnswersNothing() async throws {
        #expect(try await answer(of: favor(reviews: [review("COMMENTED", by: "tessio")])) == nil)
    }

    @Test func resolvedCommentsAnswerNothing() async throws {
        #expect(try await answer(of: favor(threads: [thread(resolved: true, ("tessio", 30))])) == nil)
    }

    @Test func aFavorAskedThroughATeamShowsItsAnswer() async throws {
        let pullRequest = favor(reviews: [review("APPROVED", by: "tessio")], pending: [.team("capos")])

        #expect(try await answer(of: pullRequest)?.opinion == .approved)
    }

    @Test func whereReviewsAreRequiredAnApprovalShortOfTheRequirementStillAnswersApproved() async throws {
        var pullRequest = favor(reviews: [review("APPROVED", by: "tessio")])
        pullRequest.reviewDecision = "REVIEW_REQUIRED"

        #expect(try await answer(of: pullRequest)?.opinion == .approved)
    }

    @Test(arguments: [
        (["tessio"], "by tessio"),
        (["tessio", "hagen"], "by tessio, hagen"),
        (["tessio", "hagen", "clemenza", "fredo"], "by tessio, hagen +2"),
    ])
    func theLineNamesTwoReviewersAndCountsTheRest(reviewers: [String], attribution: String) {
        #expect(Answer(opinion: .approved, reviewers: reviewers).attribution == attribution)
    }

    @Test func theLineUsesFamilysWords() {
        #expect(Answer.Opinion.approved.title == "Approved")
        #expect(Answer.Opinion.commented.title == "Commented")
        #expect(Answer.Opinion.changesRequested.title == "Changes requested")
    }
}
