import Foundation
import Testing
@testable import Pullfather

final class SelectionTests: SyncStoreTestCase {
    private func pullRequestURL(_ path: String) -> URL? {
        URL(string: "https://github.com/corleone/\(path)")
    }

    @Test func movingDownFromNoSelectionSelectsTheFirstBusinessRow() async throws {
        let store = try await sync(SyncFixtures.recorded)

        store.moveSelection(.down)

        #expect(store.selectedURL == pullRequestURL("olive-oil/pull/412"))
    }

    @Test func movingUpFromNoSelectionSelectsTheLastFamilyRow() async throws {
        let store = try await sync(SyncFixtures.recorded)

        store.moveSelection(.up)

        #expect(store.selectedURL == pullRequestURL("casino/pull/1079"))
    }

    @Test func theSelectionCrossesFromBusinessIntoFamilyAndBack() async throws {
        let store = try await sync(SyncFixtures.recorded)

        for _ in 0..<4 {
            store.moveSelection(.down)
        }
        #expect(store.selectedURL == pullRequestURL("olive-oil/pull/97"))

        store.moveSelection(.up)
        #expect(store.selectedURL == pullRequestURL("casino/pull/1091"))
    }

    @Test func theSelectionStopsAtTheEnds() async throws {
        let store = try await sync(SyncFixtures.recorded)

        store.moveSelection(.down)
        store.moveSelection(.up)
        #expect(store.selectedURL == pullRequestURL("olive-oil/pull/412"))

        for _ in 0..<10 {
            store.moveSelection(.down)
        }
        #expect(store.selectedURL == pullRequestURL("casino/pull/1079"))
    }

    @Test func theSelectionFollowsTheBusinessOrder() async throws {
        preferences.businessOrder = .oldestFirst
        let store = try await sync(SyncFixtures.recorded)

        store.moveSelection(.down)

        #expect(store.selectedURL == pullRequestURL("casino/pull/1091"))
    }

    @Test func movingWithNoRowsSelectsNothing() async throws {
        let store = try await sync(SyncFixture().data)

        store.moveSelection(.down)

        #expect(store.selection == nil)
        #expect(store.selectedURL == nil)
    }

    @Test func aSelectedRowThatLeavesOnSyncIsNoLongerSelected() async throws {
        let first = SyncFixture.PullRequest(number: 1, createdAt: ago(hours: 1))
        let second = SyncFixture.PullRequest(number: 2, createdAt: ago(hours: 2))
        let github = makeGitHub(SyncFixture(business: [first, second]).data)
        let store = try makeStore(github)
        await store.requestSync().value
        store.moveSelection(.down)
        #expect(store.selection == .business("PR_1"))

        github.respond(with: SyncFixture(business: [second]).data)
        await store.requestSync().value

        #expect(store.selection == nil)
        store.moveSelection(.down)
        #expect(store.selection == .business("PR_2"))
    }

    @Test func aPullRequestInBothSectionsIsSelectedOncePerSection() async throws {
        let shared = SyncFixture.PullRequest(number: 5, createdAt: ago(hours: 1))
        let store = try await sync(SyncFixture(business: [shared], authored: [shared]).data)

        store.moveSelection(.down)
        store.moveSelection(.down)

        #expect(store.selection == .family("PR_5"))
    }

    @Test func pointingAtARowSelectsIt() async throws {
        let store = try await sync(SyncFixtures.recorded)
        let row = try #require(store.family?.first)

        store.select(.family(row.id))
        store.moveSelection(.down)

        #expect(store.selectedURL == pullRequestURL("casino/pull/1084"))
    }

    @Test func rowsLinkToTheirRepository() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.business?.first?.repositoryURL == URL(string: "https://github.com/corleone/olive-oil"))
        #expect(store.family?.last?.repositoryURL == URL(string: "https://github.com/corleone/casino"))
    }

    @Test func rowsHiddenBehindSignInAgainCannotBeSelected() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        await store.requestSync().value
        store.moveSelection(.down)

        github.fail(with: .unauthorised)
        await store.requestSync().value

        #expect(store.selection == nil)
        store.moveSelection(.down)
        #expect(store.selectedURL == nil)
    }
}
