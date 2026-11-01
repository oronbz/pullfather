import Foundation
import Testing
@testable import Pullfather

final class VerdictTests: SyncStoreTestCase {
    @Test func aFamilyPullRequestGettingApprovedIsAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func changesRequestedAfterAnApprovalIsAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviews: [review("CHANGES_REQUESTED")])]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func losingTheReviewStateIsNotAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1)]).data)
        await store.requestSync().value

        #expect(verdicts.isEmpty)
    }

    @Test func anUnchangedReviewStateIsNotAVerdictAgain() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        await store.requestSync().value
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func aDraftGettingReviewedIsAVerdict() async throws {
        var draft = family(1)
        draft.isDraft = true
        let github = makeGitHub(SyncFixture(authored: [draft]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        draft.reviews = [review("CHANGES_REQUESTED")]
        github.respond(with: SyncFixture(authored: [draft]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func aPullRequestNewToFamilyBringsNoVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1)], assigned: [family(2, reviews: [review("APPROVED")])]).data)
        await store.requestSync().value

        #expect(store.family?.count == 2)
        #expect(verdicts.isEmpty)
    }

    @Test func theFirstSyncAfterLaunchHasNoVerdicts() async throws {
        let store = try makeStore(makeGitHub(SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data))

        await store.requestSync().value

        #expect(store.family?.count == 1)
        #expect(verdicts.isEmpty)
    }

    @Test func verdictsFromOneSyncArriveTogether() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1)], assigned: [family(2)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviews: [review("APPROVED")])], assigned: [family(2, reviews: [review("CHANGES_REQUESTED")])]).data)
        await store.requestSync().value

        #expect(verdicts.map(Set.init) == [["PR_1", "PR_2"]])
    }

    @Test func aPullRequestApprovedWhileMissingFromASyncIsAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: []).data)
        await store.requestSync().value
        github.respond(with: SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func anApprovedPullRequestBackAfterASyncWithoutItIsNotAVerdictAgain() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: []).data)
        await store.requestSync().value
        github.respond(with: SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        await store.requestSync().value

        #expect(verdicts.isEmpty)
    }

    @Test func anApprovalAfterLosingTheReviewStateIsAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1)]).data)
        await store.requestSync().value
        github.respond(with: SyncFixture(authored: [family(1, reviews: [review("APPROVED")])]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func switchingToAnotherAccountDoesNotReplayItsVerdicts() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(viewer: "fredo", authored: [family(1, reviews: [review("APPROVED")])]).data)
        await store.requestSync().value

        #expect(verdicts.isEmpty)
    }

    @Test func unresolvedCommentsArrivingAreAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, threads: [thread(("fredo", 5))])]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func reRequestingIsNotAVerdict() async throws {
        let commented = family(1, threads: [thread(("fredo", 30))])
        let github = makeGitHub(SyncFixture(authored: [commented]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        var reRequested = commented
        reRequested.requests = [.user("fredo", at: ago(minutes: 10))]
        github.respond(with: SyncFixture(authored: [reRequested]).data)
        await store.requestSync().value

        #expect(store.family?.first?.reviewState == .reRequested)
        #expect(verdicts.isEmpty)
    }

    @Test func moreCommentsAfterAReRequestAreAVerdict() async throws {
        let reRequested = family(1, threads: [thread(("fredo", 30))], requests: [.user("fredo", at: ago(minutes: 10))])
        let github = makeGitHub(SyncFixture(authored: [reRequested]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        var commentedAgain = reRequested
        commentedAgain.threads.append(thread(("fredo", 5)))
        github.respond(with: SyncFixture(authored: [commentedAgain]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }
}
