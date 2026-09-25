import Foundation
import Testing
@testable import Pullfather

final class SyncStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "SyncStoreTests-\(UUID().uuidString)")
    lazy var tokenStore = TokenStore(directory: directory)
    let defaultsSuite = "SyncStoreTests-\(UUID().uuidString)"
    lazy var preferences = Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!)
    var now = SyncFixtures.recordedAt
    let sleeper = ManualSleeper()
    var arrivals: [[String]] = []

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
        FakeGitHub(viewers: ["ghp_consigliere": "tomhagen", "ghp_new_consigliere": "tomhagen"], response: response, gated: gated)
    }

    private func waitingTime(_ pullRequest: SyncFixture.PullRequest) async throws -> String? {
        try await sync(SyncFixture(business: [pullRequest]).data).business?.first?.waitingTime
    }

    private func makeStore(_ github: FakeGitHub) throws -> SyncStore {
        try tokenStore.save("ghp_consigliere")
        let account = Account(tokenStore: tokenStore, makeTransport: github.transport(token:))
        let store = SyncStore(account: account, preferences: preferences, now: { [unowned self] in now }, sleep: sleeper.sleep(for:))
        store.onArrivals = { [unowned self] in arrivals.append($0.map(\.id)) }
        return store
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

    @Test func businessRowsShowTheAuthorsAvatar() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.business?.map(\.avatarURL) == [
            URL(string: "https://avatars.githubusercontent.com/u/1001?s=60&v=4"),
            URL(string: "https://avatars.githubusercontent.com/u/1002?s=60&v=4"),
            URL(string: "https://avatars.githubusercontent.com/u/1003?s=60&v=4"),
        ])
    }

    @Test func aDeletedAuthorHasNoAvatar() async throws {
        let pullRequest = SyncFixture.PullRequest(number: 1, author: nil, createdAt: ago(hours: 1))

        let store = try await sync(SyncFixture(business: [pullRequest]).data)

        let row = try #require(store.business?.first)
        #expect(row.author == "ghost")
        #expect(row.avatarURL == nil)
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

    @Test func aFailedSyncKeepsTheLastGoodBusinessFamilyAndCount() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        await store.requestSync().value

        github.fail(with: .offline)
        now = now.addingTimeInterval(4 * 60)
        await store.requestSync().value

        #expect(store.business?.map(\.number) == [412, 1088, 1091])
        #expect(store.family?.map(\.number) == [97, 1084, 1079])
        #expect(store.countText == "3")
        #expect(store.isStale)
        #expect(store.statusLine == "Offline · synced 4m ago")
    }

    @Test(arguments: [
        (.oneMinute, 120, nil),
        (.oneMinute, 121, "Synced 2m ago"),
        (.fifteenMinutes, 1800, nil),
        (.fifteenMinutes, 1801, "Synced 30m ago"),
    ] as [(RefreshInterval, Double, String?)])
    func dataTurnsStaleAfterTwiceTheRefreshInterval(interval: RefreshInterval, elapsed: Double, expected: String?) async throws {
        preferences.refreshInterval = interval
        let store = try await sync(SyncFixtures.recorded)

        now = now.addingTimeInterval(elapsed)

        #expect(store.isStale == (expected != nil))
        #expect(store.statusLine == expected)
    }

    @Test func arrivalNotificationsAreOnByDefaultAndRememberedAcrossLaunches() {
        #expect(preferences.notifiesArrivals)

        preferences.notifiesArrivals = false

        #expect(!Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!).notifiesArrivals)
    }

    @Test func theRefreshIntervalIsOneMinuteByDefaultAndRememberedAcrossLaunches() {
        #expect(preferences.refreshInterval == .oneMinute)

        preferences.refreshInterval = .thirtyMinutes

        #expect(Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!).refreshInterval == .thirtyMinutes)
    }

    @Test func theThemeIsNoirByDefaultAndRememberedAcrossLaunches() {
        #expect(preferences.theme == .noir)

        preferences.theme = .system

        #expect(Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!).theme == .system)
    }

    private func statusLine(afterSyncFailingWith failure: GitHubFailure, minutesLater minutes: Double) async throws -> String? {
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        await store.requestSync().value
        github.fail(with: failure)
        now = now.addingTimeInterval(minutes * 60)
        await store.requestSync().value
        return store.statusLine
    }

    @Test func aRateLimitedSyncSaysWhenTheLimitResets() async throws {
        let resetsAt = now.addingTimeInterval(16 * 60)

        let statusLine = try await statusLine(afterSyncFailingWith: .rateLimited(resetsAt: resetsAt), minutesLater: 4)

        #expect(statusLine == "Rate limited · resets in 12m")
    }

    @Test func aRateLimitedSyncWithoutAResetTimeSaysWhenItLastSynced() async throws {
        let statusLine = try await statusLine(afterSyncFailingWith: .rateLimited(resetsAt: nil), minutesLater: 4)

        #expect(statusLine == "Rate limited · synced 4m ago")
    }

    @Test func aSyncThatFailsRightAfterAGoodOneSaysItSyncedJustNow() async throws {
        let statusLine = try await statusLine(afterSyncFailingWith: .offline, minutesLater: 0)

        #expect(statusLine == "Offline · synced just now")
    }

    @Test func anUnexpectedFailureSaysTheSyncFailed() async throws {
        let statusLine = try await statusLine(afterSyncFailingWith: .other("Something broke"), minutesLater: 4)

        #expect(statusLine == "Sync failed · synced 4m ago")
    }

    @Test func anUnauthorisedSyncAsksToSignInAgainInsteadOfShowingAStatus() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        await store.requestSync().value
        #expect(!store.needsSignInAgain)

        github.fail(with: .unauthorised)
        await store.requestSync().value

        #expect(store.needsSignInAgain)
        #expect(store.statusLine == nil)
        #expect(store.countText == "3")
    }

    @Test func aGoodSyncAfterSigningInAgainClearsTheRequest() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        github.fail(with: .unauthorised)
        await store.requestSync().value

        github.fail(with: nil)
        await store.requestSync().value

        #expect(!store.needsSignInAgain)
        #expect(store.business?.count == 3)
    }

    @Test func savingANewTokenStopsAskingToSignInAgainBeforeItsFirstSync() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        github.fail(with: .unauthorised)
        await store.requestSync().value

        github.fail(with: nil)
        await store.account.signIn(token: "ghp_new_consigliere")

        #expect(!store.needsSignInAgain)
        #expect(store.statusLine == nil)
    }

    private func startSchedule(_ store: SyncStore) -> Task<Void, Never> {
        Task { await store.syncOnSchedule() }
    }

    private func letScheduleRun(sleeps count: Int) async {
        for sleep in 1...count {
            await sleeper.waitUntilAsleep(times: sleep)
            if sleep < count {
                sleeper.wake()
            }
        }
    }

    @Test func theScheduleSyncsAtOnceAndThenEveryRefreshInterval() async throws {
        preferences.refreshInterval = .fiveMinutes
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        let schedule = startSchedule(store)
        defer { schedule.cancel() }

        await letScheduleRun(sleeps: 1)
        #expect(github.requestCount == 1)
        #expect(store.business?.count == 3)

        preferences.refreshInterval = .oneMinute
        sleeper.wake()
        await sleeper.waitUntilAsleep(times: 2)
        #expect(github.requestCount == 2)
        #expect(sleeper.requests == [.seconds(300), .seconds(60)])
    }

    @Test func failedSyncsRetrySoonAndBackOffUpToTheRefreshInterval() async throws {
        preferences.refreshInterval = .fiveMinutes
        let github = makeGitHub(SyncFixtures.recorded)
        github.fail(with: .offline)
        let store = try makeStore(github)
        let schedule = startSchedule(store)
        defer { schedule.cancel() }

        await letScheduleRun(sleeps: 7)

        #expect(sleeper.requests == [15, 30, 60, 120, 240, 300, 300].map(Duration.seconds))
        #expect(github.requestCount == 7)
    }

    @Test func aGoodSyncAfterFailuresReturnsToTheRefreshInterval() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        github.fail(with: .offline)
        let store = try makeStore(github)
        let schedule = startSchedule(store)
        defer { schedule.cancel() }
        await letScheduleRun(sleeps: 2)

        github.fail(with: nil)
        sleeper.wake()
        await sleeper.waitUntilAsleep(times: 3)
        github.fail(with: .offline)
        sleeper.wake()
        await sleeper.waitUntilAsleep(times: 4)

        #expect(sleeper.requests == [15, 30, 60, 15].map(Duration.seconds))
    }

    @Test func aRateLimitedSyncWaitsForTheLimitToResetBeforeTheNextScheduledSync() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        github.fail(with: .rateLimited(resetsAt: now.addingTimeInterval(12 * 60)))
        let store = try makeStore(github)
        let schedule = startSchedule(store)
        defer { schedule.cancel() }

        await letScheduleRun(sleeps: 1)

        #expect(sleeper.requests == [.seconds(720)])
    }

    @Test func aRateLimitedSyncWithoutAResetTimeBacksOff() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        github.fail(with: .rateLimited(resetsAt: nil))
        let store = try makeStore(github)
        let schedule = startSchedule(store)
        defer { schedule.cancel() }

        await letScheduleRun(sleeps: 2)

        #expect(sleeper.requests == [15, 30].map(Duration.seconds))
    }

    @Test func scheduledSyncsStopWhileAskingToSignInAgain() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        github.fail(with: .unauthorised)
        let store = try makeStore(github)
        let schedule = startSchedule(store)
        defer { schedule.cancel() }

        await letScheduleRun(sleeps: 3)

        #expect(github.requestCount == 1)
        #expect(sleeper.requests == [60, 60, 60].map(Duration.seconds))
    }

    @Test func cancellingTheScheduleStopsScheduledSyncs() async throws {
        let github = makeGitHub(SyncFixtures.recorded)
        let store = try makeStore(github)
        let schedule = startSchedule(store)
        await sleeper.waitUntilAsleep(times: 1)

        schedule.cancel()
        await schedule.value

        #expect(github.requestCount == 1)
        #expect(sleeper.requests.count == 1)
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

    @Test func aPullRequestInBothSectionsIsSelectedOncePerSection() async throws {
        let shared = SyncFixture.PullRequest(number: 5, createdAt: ago(hours: 1))
        let store = try await sync(SyncFixture(business: [shared], family: [shared]).data)

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
