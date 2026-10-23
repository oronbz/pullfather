import Foundation
import Testing
@testable import Pullfather

final class ReviewerActionTests: SyncStoreTestCase {
    private func requested(_ number: Int, _ pending: [SyncFixture.Reviewer]) -> SyncFixture.PullRequest {
        SyncFixture.PullRequest(number: number, createdAt: ago(hours: Double(number)), requests: [.user("tomhagen", at: ago(hours: Double(number)))], pending: pending)
    }

    @Test func removingMeFromReviewersDropsMyNamedRequestAndTheRow() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        await store.removeMeFromReviewers("PR_1")?.value

        #expect(github.writes == [.removingRequestedReviewer("tomhagen", repository: "corleone/olive-oil", number: 1)])
        #expect(github.mutations == [.unsubscribing(from: "PR_1")])
        #expect(store.business?.map(\.id) == ["PR_2"])
        #expect(store.countText == "1")
    }

    @Test func aFailedUnsubscribeKeepsTheRemovalAndSaysSo() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        github.failMutations(with: .offline)

        await store.removeMeFromReviewers("PR_1")?.value

        #expect(store.business?.map(\.id) == ["PR_2"])
        #expect(store.actionFailure == "Removed you from #1, but couldn't mute its notifications. Can't reach GitHub.")
    }

    @Test func theRowLeavesBusinessBeforeGitHubAnswers() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        github.hold()

        let removal = store.removeMeFromReviewers("PR_1")

        #expect(store.business?.map(\.id) == ["PR_2"])
        #expect(store.countText == "1")
        github.release()
        await removal?.value
        #expect(store.business?.map(\.id) == ["PR_2"])
    }

    @Test(arguments: [
        (GitHubFailure.offline, "Couldn't remove you from #1. Can't reach GitHub."),
        (.rateLimited(resetsAt: nil), "Couldn't remove you from #1. GitHub is rate limiting this token."),
        (.unauthorised, "Couldn't remove you from #1. GitHub didn't accept your token."),
        (.other("You don't have access to change its reviewers."), "Couldn't remove you from #1. You don't have access to change its reviewers."),
    ])
    func aRejectedRemovalBringsTheRowBackAndSaysWhy(failure: GitHubFailure, message: String) async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        github.failWrites(with: failure)

        await store.removeMeFromReviewers("PR_1")?.value

        #expect(store.business?.map(\.id) == ["PR_1", "PR_2"])
        #expect(store.countText == "2")
        #expect(store.actionFailure == message)
        #expect(github.mutations.isEmpty)
    }

    @Test func aTeamOnlyRequestCannotBeRemoved() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("fredo"), .team("consiglieri")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        #expect(store.business?.first?.isRequestedByName == false)
        #expect(store.removeMeFromReviewers("PR_1") == nil)
        #expect(github.writes.isEmpty)
        #expect(store.business?.map(\.id) == ["PR_1"])
    }

    @Test func removingMyNamedRequestKeepsARowStillRequestedThroughATeam() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.team("consiglieri"), .user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        github.hold()

        let removal = store.removeMeFromReviewers("PR_1")

        #expect(store.business?.map(\.id) == ["PR_1"])
        github.release()
        await removal?.value
        #expect(github.writes == [.removingRequestedReviewer("tomhagen", repository: "corleone/olive-oil", number: 1)])
        #expect(github.mutations == [.unsubscribing(from: "PR_1")])
        #expect(store.business?.map(\.id) == ["PR_1"])
        #expect(store.business?.first?.isRequestedByName == false)
        #expect(store.removeMeFromReviewers("PR_1") == nil)
    }

    @Test func removingTheSelectedRowSelectsTheNextOne() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        store.select(.business("PR_1"))

        store.removeMeFromReviewers("PR_1")
        #expect(store.selection == .business("PR_2"))

        await store.removeMeFromReviewers("PR_2")?.value
        #expect(store.selection == nil)
    }

    @Test func removingTheLastSelectedRowSelectsTheOneBefore() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        store.select(.business("PR_2"))

        store.removeMeFromReviewers("PR_2")

        #expect(store.selection == .business("PR_1"))
    }

    @Test func approvingSubmitsAnApprovalAndDropsTheRow() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        store.approvalCandidate = "PR_1"

        await store.approve("PR_1")?.value

        #expect(github.mutations == [.approving("PR_1")])
        #expect(github.writes.isEmpty)
        #expect(store.business?.map(\.id) == ["PR_2"])
        #expect(store.countText == "1")
        #expect(store.approvalCandidate == nil)
    }

    @Test func approvingATeamRequestDropsTheRowToo() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("fredo"), .team("consiglieri")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        github.hold()

        let approval = store.approve("PR_1")

        #expect(store.business?.isEmpty == true)
        github.release()
        await approval?.value
        #expect(github.mutations == [.approving("PR_1")])
        #expect(store.business?.isEmpty == true)
    }

    @Test(arguments: [
        (GitHubFailure.offline, "Couldn't approve #1. Can't reach GitHub."),
        (.other("Can not approve your own pull request"), "Couldn't approve #1. Can not approve your own pull request"),
    ])
    func aRejectedApprovalBringsTheRowBackAndSaysWhy(failure: GitHubFailure, message: String) async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        github.failMutations(with: failure)

        await store.approve("PR_1")?.value

        #expect(store.business?.map(\.id) == ["PR_1", "PR_2"])
        #expect(store.actionFailure == message)
    }

    @Test func approvingTheSelectedRowSelectsTheNextOne() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        store.select(.business("PR_1"))

        store.approve("PR_1")

        #expect(store.selection == .business("PR_2"))
    }

    @Test func aPullRequestBeingApprovedCannotBeApprovedOrRemovedAgain() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        github.hold()

        let approval = store.approve("PR_1")

        #expect(store.approve("PR_1") == nil)
        #expect(store.removeMeFromReviewers("PR_1") == nil)
        github.release()
        await approval?.value
        #expect(github.mutations == [.approving("PR_1")])
    }

    @Test func aSyncThatStillFindsTheApprovedPullRequestDoesNotBringItBack() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        await store.approve("PR_1")?.value

        github.respond(with: SyncFixture(business: [requested(1, [.team("consiglieri")]), requested(2, [.user("tomhagen")])]).data)
        await store.requestSync().value

        #expect(store.business?.map(\.id) == ["PR_2"])
    }

    @Test func aSyncThatStillFindsTheRemovedPullRequestDoesNotBringItBack() async throws {
        let github = makeGitHub(SyncFixture(business: [requested(1, [.user("tomhagen")]), requested(2, [.user("tomhagen")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        await store.removeMeFromReviewers("PR_1")?.value

        github.respond(with: SyncFixture(business: [requested(1, [.user("fredo")]), requested(2, [.user("tomhagen")])]).data)
        await store.requestSync().value

        #expect(store.business?.map(\.id) == ["PR_2"])
        #expect(arrivals.isEmpty)

        github.respond(with: SyncFixture(business: [reRequested(requested(1, [.user("tomhagen")])), requested(2, [.user("tomhagen")])]).data)
        await store.requestSync().value

        #expect(store.business?.map(\.id) == ["PR_1", "PR_2"])
        #expect(arrivals == [["PR_1"]])
    }
}
