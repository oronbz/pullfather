import Foundation
import Testing
@testable import Pullfather

final class SyncStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "SyncStoreTests-\(UUID().uuidString)")
    lazy var tokenStore = TokenStore(directory: directory)
    let defaultsSuite = "SyncStoreTests-\(UUID().uuidString)"
    lazy var preferences = Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!)
    var now = SyncFixtures.recordedAt

    deinit {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: defaultsSuite)
    }

    private func ago(minutes: Double = 0, hours: Double = 0, days: Double = 0) -> Date {
        now.addingTimeInterval(-(minutes * 60 + hours * 3600 + days * 86400))
    }

    private func sync(_ response: Data) async throws -> SyncStore {
        let store = try makeStore(makeGitHub(response))
        await store.requestSync().value
        return store
    }

    private func makeGitHub(_ response: Data, gated: Bool = false) -> FakeGitHub {
        FakeGitHub(viewers: ["ghp_consigliere": "tomhagen"], response: response, gated: gated)
    }

    private func waitingTime(_ pullRequest: SyncFixture.PullRequest) async throws -> String? {
        try await sync(SyncFixture(business: [pullRequest]).data).business?.first?.waitingTime
    }

    private func makeStore(_ github: FakeGitHub) throws -> SyncStore {
        try tokenStore.save("ghp_consigliere")
        let account = Account(tokenStore: tokenStore, makeTransport: github.transport(token:))
        return SyncStore(account: account, preferences: preferences, now: { [unowned self] in now })
    }

    @Test func businessShowsTheNewestReviewRequestFirstByDefault() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.business?.map(\.metadata) == [
            "corleone/olive-oil #412 · 2h",
            "corleone/casino #1088 · 5h",
            "corleone/casino #1091 · 1d",
        ])
        let row = try #require(store.business?.first)
        #expect(row.title == "Fix race in token refresh")
        #expect(row.author == "mike-corleone")
        #expect(row.url == URL(string: "https://github.com/corleone/olive-oil/pull/412"))
    }

    @Test func businessCanShowTheLongestWaitingFirst() async throws {
        preferences.businessOrder = .oldestFirst

        let store = try await sync(SyncFixtures.recorded)

        #expect(store.business?.map(\.number) == [1091, 1088, 412])
    }

    @Test func switchingTheOrderReordersBusinessWithoutASync() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        await store.requestSync().value

        preferences.businessOrder = .oldestFirst

        #expect(store.business?.map(\.number) == [1091, 1088, 412])
        #expect(github.requestCount == 1)
    }

    @Test func theBusinessOrderIsRememberedAcrossLaunches() {
        preferences.businessOrder = .oldestFirst

        #expect(Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!).businessOrder == .oldestFirst)
    }

    @Test func aRequestByNameOutranksAMoreRecentTeamRequest() async throws {
        let waitingTime = try await waitingTime(.init(number: 1, createdAt: ago(days: 3), requests: [
            .user("tomhagen", at: ago(hours: 5)),
            .team("consiglieri", at: ago(hours: 1)),
        ]))

        #expect(waitingTime == "5h")
    }

    @Test func aTeamRequestCountsWhenThereIsNoneByName() async throws {
        let waitingTime = try await waitingTime(.init(number: 1, createdAt: ago(days: 3), requests: [
            .user("fredo", at: ago(hours: 1)),
            .team("consiglieri", at: ago(hours: 5)),
        ]))

        #expect(waitingTime == "5h")
    }

    @Test func aReRequestRestartsTheWaitingTime() async throws {
        let waitingTime = try await waitingTime(.init(number: 1, createdAt: ago(days: 10), requests: [
            .user("tomhagen", at: ago(days: 9)),
            .user("tomhagen", at: ago(minutes: 20)),
        ]))

        #expect(waitingTime == "20m")
    }

    @Test func withoutARequestEventTheWaitingTimeStartsAtCreation() async throws {
        let waitingTime = try await waitingTime(.init(number: 1, createdAt: ago(days: 15), requests: [
            .user("fredo", at: ago(hours: 1)),
        ]))

        #expect(waitingTime == "2w")
    }

    @Test(arguments: [
        (59, "now"),
        (60, "1m"),
        (59 * 60 + 59, "59m"),
        (3600, "1h"),
        (23 * 3600 + 59 * 60, "23h"),
        (86400, "1d"),
        (6 * 86400 + 23 * 3600, "6d"),
        (7 * 86400, "1w"),
        (29 * 86400, "4w"),
        (30 * 86400, "1mo"),
        (125 * 86400, "4mo"),
    ] as [(Double, String)])
    func waitingTimeIsCompact(seconds: Double, expected: String) async throws {
        let waitingTime = try await waitingTime(.init(number: 1, createdAt: now.addingTimeInterval(-seconds)))

        #expect(waitingTime == expected)
    }

    @Test func theCountIsTheSizeOfBusiness() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.countText == "3")
    }

    @Test func theCountIsHiddenWhenBusinessIsEmpty() async throws {
        let store = try await sync(SyncFixture(business: []).data)

        #expect(store.business == [])
        #expect(store.countText == nil)
    }

    @Test func familyShowsMyPullRequestsWithTheMostRecentActivityFirst() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.family?.map(\.metadata) == [
            "corleone/olive-oil #97 · 30m",
            "corleone/casino #1084 · 1d",
            "corleone/casino #1079 · 3d",
        ])
        let row = try #require(store.family?.first)
        #expect(row.title == "Sketch the olive oil import pipeline")
        #expect(row.url == URL(string: "https://github.com/corleone/olive-oil/pull/97"))
    }

    @Test func familyIncludesDraftsWhileBusinessExcludesThem() async throws {
        let draft = SyncFixture.PullRequest(number: 7, createdAt: ago(hours: 1), isDraft: true)
        let ready = SyncFixture.PullRequest(number: 8, createdAt: ago(hours: 2))

        let store = try await sync(SyncFixture(business: [draft, ready], family: [draft, ready]).data)

        #expect(store.business?.map(\.number) == [8])
        #expect(store.family?.map(\.number) == [7, 8])
    }

    @Test(arguments: [
        ("APPROVED", .approved),
        ("CHANGES_REQUESTED", .changesRequested),
        ("REVIEW_REQUIRED", nil),
        (nil, nil),
    ] as [(String?, ReviewState?)])
    func familyRowsShowTheirReviewState(reviewDecision: String?, expected: ReviewState?) async throws {
        let pullRequest = SyncFixture.PullRequest(number: 1, createdAt: ago(days: 1), reviewDecision: reviewDecision)

        let store = try await sync(SyncFixture(family: [pullRequest]).data)

        #expect(store.family?.first?.reviewState == expected)
    }

    @Test(arguments: [
        ("SUCCESS", .passing),
        ("PENDING", .running),
        ("EXPECTED", .running),
        ("FAILURE", .failing),
        ("ERROR", .failing),
    ] as [(String, Checks)])
    func rowsShowTheirChecks(rollupState: String, expected: Checks) async throws {
        let pullRequest = SyncFixture.PullRequest(number: 1, createdAt: ago(hours: 1), rollupState: rollupState)

        let store = try await sync(SyncFixture(business: [pullRequest], family: [pullRequest]).data)

        #expect(store.business?.first?.checks == expected)
        #expect(store.family?.first?.checks == expected)
    }

    @Test func businessAndFamilyRowsShowTheChecksOfTheirLatestCommit() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.business?.map(\.checks) == [.passing, .running, .failing])
        #expect(store.family?.map(\.checks) == [nil, .failing, .passing])
    }

    @Test func aPullRequestWithoutChecksShowsNone() async throws {
        let pullRequest = SyncFixture.PullRequest(number: 1, createdAt: ago(hours: 1), rollupState: nil)

        let store = try await sync(SyncFixture(business: [pullRequest], family: [pullRequest]).data)

        #expect(store.business?.first?.checks == nil)
        #expect(store.family?.first?.checks == nil)
    }

    @Test func familyRowsFlagDrafts() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.family?.map(\.isDraft) == [true, false, false])
    }

    @Test(arguments: [
        (.business, "1"),
        (.family, "2"),
        (.off, nil),
    ] as [(CountMode, String?)])
    func theCountFollowsTheCountMode(mode: CountMode, expected: String?) async throws {
        let store = try await sync(SyncFixture(
            business: [.init(number: 1, createdAt: ago(hours: 1))],
            family: [.init(number: 2, createdAt: ago(hours: 1)), .init(number: 3, createdAt: ago(hours: 2), isDraft: true)]
        ).data)

        preferences.countMode = mode

        #expect(store.countText == expected)
    }

    @Test func theFamilyCountIsHiddenWhenFamilyIsEmpty() async throws {
        preferences.countMode = .family

        let store = try await sync(SyncFixture(business: [.init(number: 1, createdAt: ago(hours: 1))]).data)

        #expect(store.family == [])
        #expect(store.countText == nil)
    }

    @Test func theCountModeIsRememberedAcrossLaunches() {
        preferences.countMode = .off

        #expect(Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!).countMode == .off)
    }

    @Test func overlappingSyncRequestsShareOneSync() async throws {
        let github = makeGitHub(SyncFixtures.recorded, gated: true)
        let store = try makeStore(github)

        let first = store.requestSync()
        while github.requestCount == 0 {
            await Task.yield()
        }
        #expect(store.isSyncing)
        let second = store.requestSync()
        github.release()
        await first.value
        await second.value

        #expect(github.requestCount == 1)
        #expect(store.business?.count == 3)
        #expect(!store.isSyncing)
    }
}
