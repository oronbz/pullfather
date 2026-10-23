import Foundation
import Testing
@testable import Pullfather

final class ArrivalTests: SyncStoreTestCase {
    private var first: SyncFixture.PullRequest { SyncFixture.PullRequest(number: 1, createdAt: ago(hours: 1)) }
    private var second: SyncFixture.PullRequest { SyncFixture.PullRequest(number: 2, createdAt: ago(hours: 2)) }

    @Test func pullRequestsNewToBusinessArrive() async throws {
        let github = makeGitHub(SyncFixture(business: [first]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(business: [first, second]).data)
        await store.requestSync().value

        #expect(arrivals == [["PR_2"]])
    }

    @Test func theFirstSyncAfterLaunchHasNoArrivals() async throws {
        let store = try makeStore(makeGitHub(SyncFixtures.recorded))

        await store.requestSync().value

        #expect(store.business?.count == 3)
        #expect(arrivals.isEmpty)
    }

    @Test func aFailedFirstSyncLeavesTheNextGoodOneWithoutArrivals() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        github.fail(with: .offline)
        await store.requestSync().value

        github.fail(with: nil)
        await store.requestSync().value

        #expect(arrivals.isEmpty)
    }

    @Test func beingAssignedIsNotAnArrival() async throws {
        let github = makeGitHub(SyncFixture(business: [first]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(business: [first], assigned: [second]).data)
        await store.requestSync().value

        #expect(store.family?.map(\.number) == [2])
        #expect(arrivals.isEmpty)
    }

    @Test func pullRequestsLeavingBusinessDoNotArrive() async throws {
        let github = makeGitHub(SyncFixture(business: [first, second]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(business: [second]).data)
        await store.requestSync().value

        #expect(arrivals.isEmpty)
    }

    @Test func switchingToAnotherAccountDoesNotReplayItsBusiness() async throws {
        let github = makeGitHub(SyncFixture(business: [first]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(viewer: "fredo", business: [first, second]).data)
        await store.requestSync().value

        #expect(store.business?.count == 2)
        #expect(arrivals.isEmpty)
    }

    @Test func signingInAgainDoesNotReplayBusiness() async throws {
        let github = makeGitHub(SyncFixture(business: []).data)
        let store = try makeStore(github)
        await store.requestSync().value

        store.account.signOut()
        await store.requestSync().value
        github.respond(with: SyncFixtures.recorded)
        await store.account.signIn(token: "ghp_consigliere")
        await store.requestSync().value

        #expect(store.business?.count == 3)
        #expect(arrivals.isEmpty)
    }

    @Test func aPullRequestBackAfterASyncWithoutItDoesNotArriveAgain() async throws {
        let github = makeGitHub(SyncFixture(business: [first]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(business: []).data)
        await store.requestSync().value
        github.respond(with: SyncFixture(business: [first]).data)
        await store.requestSync().value

        #expect(store.business?.map(\.id) == ["PR_1"])
        #expect(arrivals.isEmpty)
    }

    @Test func aReRequestAfterLeavingBusinessArrives() async throws {
        let pullRequest = SyncFixture.PullRequest(number: 1, createdAt: ago(days: 1), requests: [.user("tomhagen", at: ago(hours: 3))])
        let github = makeGitHub(SyncFixture(business: [pullRequest]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(business: []).data)
        await store.requestSync().value
        github.respond(with: SyncFixture(business: [reRequested(pullRequest)]).data)
        await store.requestSync().value

        #expect(arrivals == [["PR_1"]])
    }

    @Test func aRequestByNameAfterATeamRequestArrives() async throws {
        let pullRequest = SyncFixture.PullRequest(number: 1, createdAt: ago(days: 1), requests: [.team("consiglieri", at: ago(hours: 3))])
        let github = makeGitHub(SyncFixture(business: [pullRequest]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(business: [reRequested(pullRequest)]).data)
        await store.requestSync().value

        #expect(arrivals == [["PR_1"]])
    }

    @Test func aDraftMarkedReadyArrivesForARequestMadeWhileItWasADraft() async throws {
        var draft = SyncFixture.PullRequest(number: 1, createdAt: ago(days: 1), isDraft: true, requests: [.user("tomhagen", at: ago(hours: 3))])
        let github = makeGitHub(SyncFixture(business: [draft]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        draft.isDraft = false
        github.respond(with: SyncFixture(business: [draft]).data)
        await store.requestSync().value

        #expect(arrivals == [["PR_1"]])
    }

    @Test func switchingToAnotherAccountForgetsTheReviewRequestsTheFirstKnew() async throws {
        let github = makeGitHub(SyncFixture(business: [first]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(viewer: "fredo", business: []).data)
        await store.requestSync().value
        github.respond(with: SyncFixture(viewer: "fredo", business: [first]).data)
        await store.requestSync().value

        #expect(arrivals == [["PR_1"]])
    }
}
