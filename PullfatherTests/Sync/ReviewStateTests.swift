import Foundation
import Testing
@testable import Pullfather

final class ReviewStateTests: SyncStoreTestCase {
    private func reviewState(of pullRequest: SyncFixture.PullRequest) async throws -> ReviewState? {
        let store = try await sync(SyncFixture(authored: [pullRequest]).data)
        return try #require(store.family?.first).reviewState
    }

    @Test func anApprovalShowsApprovedWhereReviewsAreNotRequired() async throws {
        #expect(try await reviewState(of: family(1, reviews: [review("APPROVED")])) == .approved)
    }

    @Test func aRequestForChangesShowsChangesRequested() async throws {
        #expect(try await reviewState(of: family(1, reviews: [review("APPROVED"), review("CHANGES_REQUESTED")])) == .changesRequested)
    }

    @Test func whereReviewsAreRequiredAnApprovalShortOfTheRequirementShowsNothing() async throws {
        var pullRequest = family(1, reviews: [review("APPROVED")])
        pullRequest.reviewDecision = "REVIEW_REQUIRED"

        #expect(try await reviewState(of: pullRequest) == nil)
    }

    @Test func noReviewsShowNothing() async throws {
        #expect(try await reviewState(of: family(1)) == nil)
    }

    @Test func anUnresolvedCommentFromAReviewerShowsCommented() async throws {
        #expect(try await reviewState(of: family(1, threads: [thread(("fredo", 30))])) == .commented)
    }

    @Test func copilotsUnresolvedCommentsCountLikeAReviewers() async throws {
        #expect(try await reviewState(of: family(1, threads: [thread(("copilot-pull-request-reviewer", 30))])) == .commented)
    }

    @Test func myOwnUnresolvedNotesShowNothing() async throws {
        #expect(try await reviewState(of: family(1, threads: [thread(("tomhagen", 30))])) == nil)
    }

    @Test func onAPullRequestAssignedToMeItsAuthorsCommentsShowCommented() async throws {
        let assigned = SyncFixture.PullRequest(number: 1, author: "sonny", createdAt: ago(hours: 2), threads: [thread(("sonny", 30))])

        let store = try await sync(SyncFixture(assigned: [assigned]).data)

        #expect(store.family?.first?.reviewState == .commented)
    }

    @Test func onAPullRequestAssignedToMeMyOwnCommentsShowNothing() async throws {
        let assigned = SyncFixture.PullRequest(number: 1, author: "sonny", createdAt: ago(hours: 2), threads: [thread(("tomhagen", 30))])

        let store = try await sync(SyncFixture(assigned: [assigned]).data)

        #expect(store.family?.first?.reviewState == nil)
    }

    @Test func resolvedCommentsShowNothing() async throws {
        #expect(try await reviewState(of: family(1, threads: [thread(resolved: true, ("fredo", 30))])) == nil)
    }

    @Test func anApprovalWithUnresolvedCommentsShowsCommented() async throws {
        #expect(try await reviewState(of: family(1, reviews: [review("APPROVED")], threads: [thread(("copilot-pull-request-reviewer", 30))])) == .commented)
    }

    @Test func anApprovalWhoseCommentsAreAllResolvedShowsApproved() async throws {
        #expect(try await reviewState(of: family(1, reviews: [review("APPROVED")], threads: [thread(resolved: true, ("copilot-pull-request-reviewer", 30))])) == .approved)
    }

    @Test func aRequestForChangesOutranksUnresolvedComments() async throws {
        #expect(try await reviewState(of: family(1, reviews: [review("CHANGES_REQUESTED")], threads: [thread(("fredo", 30))])) == .changesRequested)
    }

    @Test func reRequestingAfterCommentsShowsReRequested() async throws {
        let pullRequest = family(1, threads: [thread(("fredo", 30), ("tomhagen", 20))], requests: [.user("fredo", at: ago(minutes: 10))])

        #expect(try await reviewState(of: pullRequest) == .reRequested)
    }

    @Test func reRequestingAfterARequestForChangesShowsReRequested() async throws {
        let pullRequest = family(1, reviews: [review("CHANGES_REQUESTED", minutesAgo: 30)], requests: [.user("fredo", at: ago(minutes: 10))])

        #expect(try await reviewState(of: pullRequest) == .reRequested)
    }

    @Test func reRequestingATeamCountsToo() async throws {
        let pullRequest = family(1, threads: [thread(("fredo", 30))], requests: [.team("consiglieri", at: ago(minutes: 10))])

        #expect(try await reviewState(of: pullRequest) == .reRequested)
    }

    @Test func reRequestingAfterResolvingEveryCommentShowsReRequested() async throws {
        let pullRequest = family(1, threads: [thread(resolved: true, ("fredo", 30))], requests: [.user("fredo", at: ago(minutes: 10))])

        #expect(try await reviewState(of: pullRequest) == .reRequested)
    }

    @Test func commentsCountFromWhenTheirReviewWasSubmittedNotDrafted() async throws {
        var comment = thread(("fredo", 5))
        comment.comments[0].drafted = ago(minutes: 40)
        let pullRequest = family(1, threads: [comment], requests: [.user("fredo", at: ago(minutes: 10))])

        #expect(try await reviewState(of: pullRequest) == .commented)
    }

    @Test func aCommentAfterTheReRequestThatIsAlreadyResolvedKeepsReRequested() async throws {
        let pullRequest = family(
            1,
            threads: [thread(("fredo", 60), ("tomhagen", 40)), thread(resolved: true, ("copilot-pull-request-reviewer", 10))],
            requests: [.user("fredo", at: ago(minutes: 20))]
        )

        #expect(try await reviewState(of: pullRequest) == .reRequested)
    }

    @Test func aRequestBeforeAnyFeedbackShowsNothing() async throws {
        #expect(try await reviewState(of: family(1, requests: [.user("fredo", at: ago(minutes: 90))])) == nil)
    }

    @Test func copilotBeingRequestedAgainIsNotAReRequest() async throws {
        let pullRequest = family(1, threads: [thread(("fredo", 30))], requests: [.bot("copilot-pull-request-reviewer", at: ago(minutes: 10))])

        #expect(try await reviewState(of: pullRequest) == .commented)
    }

    @Test func aReplyAfterTheReRequestShowsCommentedAgain() async throws {
        let pullRequest = family(1, threads: [thread(("fredo", 30), ("tomhagen", 20), ("fredo", 5))], requests: [.user("fredo", at: ago(minutes: 10))])

        #expect(try await reviewState(of: pullRequest) == .commented)
    }

    @Test func anApprovalAfterTheReRequestShowsApproved() async throws {
        let pullRequest = family(
            1,
            reviews: [review("APPROVED", minutesAgo: 5)],
            threads: [thread(resolved: true, ("fredo", 30))],
            requests: [.user("fredo", at: ago(minutes: 10))]
        )

        #expect(try await reviewState(of: pullRequest) == .approved)
    }

    @Test func aDismissedApprovalShowsNothing() async throws {
        #expect(try await reviewState(of: family(1, reviews: [review("DISMISSED", minutesAgo: 30)])) == nil)
    }

    @Test func reRequestingAfterADismissedApprovalShowsReRequested() async throws {
        let pullRequest = family(1, reviews: [review("DISMISSED", minutesAgo: 30)], requests: [.user("fredo", at: ago(minutes: 10))])

        #expect(try await reviewState(of: pullRequest) == .reRequested)
    }

    @Test func reviewsAreFetchedForFamilyOnly() async throws {
        let business = SyncFixture.PullRequest(number: 1, createdAt: ago(hours: 1))
        let github = makeGitHub(SyncFixture(business: [business], authored: [family(2)], assigned: [family(3)]).data)

        await try makeStore(github).requestSync().value

        #expect(github.reviewBatches == [["PR_2", "PR_3"]])
    }

    @Test func withoutFamilyNoReviewsAreFetched() async throws {
        let github = makeGitHub(SyncFixture(business: [SyncFixture.PullRequest(number: 1, createdAt: ago(hours: 1))]).data)

        await try makeStore(github).requestSync().value

        #expect(github.reviewBatches.isEmpty)
    }

    @Test func reviewsAreFetchedAHundredPullRequestsAtATime() async throws {
        let github = makeGitHub(SyncFixture(authored: (1...150).map { family($0) }).data)

        await try makeStore(github).requestSync().value

        #expect(github.reviewBatches.map(\.count) == [100, 50])
    }

    @Test func failingToFetchReviewsFailsTheSyncAndKeepsTheLastGoodFamily() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviews: [review("APPROVED")]), family(2)]).data)
        github.failReviews(with: .offline)
        now = now.addingTimeInterval(4 * 60)
        await store.requestSync().value

        #expect(store.family?.map(\.number) == [1])
        #expect(store.family?.first?.reviewState == .approved)
        #expect(store.statusLine == "Offline · synced 4m ago")
    }
}
