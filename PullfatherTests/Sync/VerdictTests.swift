import Foundation
import Testing
@testable import Pullfather

final class VerdictTests: SyncStoreTestCase {
    @Test func aFamilyPullRequestGettingApprovedIsAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: nil)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func changesRequestedAfterAnApprovalIsAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: "CHANGES_REQUESTED")]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func losingTheReviewStateIsNotAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: nil)]).data)
        await store.requestSync().value

        #expect(verdicts.isEmpty)
    }

    @Test func anUnchangedReviewStateIsNotAVerdictAgain() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: nil)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data)
        await store.requestSync().value
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func aDraftGettingReviewedIsAVerdict() async throws {
        var draft = family(1, reviewDecision: nil)
        draft.isDraft = true
        let github = makeGitHub(SyncFixture(authored: [draft]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        draft.reviewDecision = "CHANGES_REQUESTED"
        github.respond(with: SyncFixture(authored: [draft]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func aPullRequestNewToFamilyBringsNoVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: nil)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: nil)], assigned: [family(2, reviewDecision: "APPROVED")]).data)
        await store.requestSync().value

        #expect(store.family?.count == 2)
        #expect(verdicts.isEmpty)
    }

    @Test func theFirstSyncAfterLaunchHasNoVerdicts() async throws {
        let store = try makeStore(makeGitHub(SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data))

        await store.requestSync().value

        #expect(store.family?.count == 1)
        #expect(verdicts.isEmpty)
    }

    @Test func verdictsFromOneSyncArriveTogether() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: nil)], assigned: [family(2, reviewDecision: nil)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: "APPROVED")], assigned: [family(2, reviewDecision: "CHANGES_REQUESTED")]).data)
        await store.requestSync().value

        #expect(verdicts.map(Set.init) == [["PR_1", "PR_2"]])
    }

    @Test func aPullRequestApprovedWhileMissingFromASyncIsAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: nil)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: []).data)
        await store.requestSync().value
        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func anApprovedPullRequestBackAfterASyncWithoutItIsNotAVerdictAgain() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: []).data)
        await store.requestSync().value
        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data)
        await store.requestSync().value

        #expect(verdicts.isEmpty)
    }

    @Test func anApprovalAfterLosingTheReviewStateIsAVerdict() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: nil)]).data)
        await store.requestSync().value
        github.respond(with: SyncFixture(authored: [family(1, reviewDecision: "APPROVED")]).data)
        await store.requestSync().value

        #expect(verdicts == [["PR_1"]])
    }

    @Test func switchingToAnotherAccountDoesNotReplayItsVerdicts() async throws {
        let github = makeGitHub(SyncFixture(authored: [family(1, reviewDecision: nil)]).data)
        let store = try makeStore(github)
        await store.requestSync().value

        github.respond(with: SyncFixture(viewer: "fredo", authored: [family(1, reviewDecision: "APPROVED")]).data)
        await store.requestSync().value

        #expect(verdicts.isEmpty)
    }
}
