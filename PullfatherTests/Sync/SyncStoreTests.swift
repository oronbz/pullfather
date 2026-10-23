import Foundation
import Testing
@testable import Pullfather

final class SyncStoreTests: SyncStoreTestCase {
    private func waitingTime(_ pullRequest: SyncFixture.PullRequest) async throws -> String? {
        try await sync(SyncFixture(business: [pullRequest]).data).business?.first?.waitingTime
    }

    @Test func businessShowsTheNewestReviewRequestFirstByDefault() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.business?.map { [$0.reference, $0.waitingTime] } == [
            ["corleone/olive-oil #412", "2h"],
            ["corleone/casino #1088", "5h"],
            ["corleone/casino #1091", "1d"],
        ])
        let row = try #require(store.business?.first)
        #expect(row.title == "Fix race in token refresh")
        #expect(row.author == "mike-corleone")
        #expect(row.url == URL(string: "https://github.com/corleone/olive-oil/pull/412"))
    }

    @Test func rowsShowTheLinesAddedAndRemoved() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.business?.map(\.lineChanges) == [
            LineChanges(additions: 48, deletions: 12),
            LineChanges(additions: 1240, deletions: 310),
            LineChanges(additions: 2, deletions: 2),
        ])
        #expect(store.family?.map(\.lineChanges) == [
            LineChanges(additions: 530, deletions: 0),
            LineChanges(additions: 214, deletions: 377),
            LineChanges(additions: 86, deletions: 9),
        ])
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

        #expect(store.family?.map { [$0.reference, $0.lastActivity] } == [
            ["corleone/olive-oil #97", "30m"],
            ["corleone/casino #1084", "1d"],
            ["corleone/casino #1079", "3d"],
        ])
        let row = try #require(store.family?.first)
        #expect(row.title == "Sketch the olive oil import pipeline")
        #expect(row.url == URL(string: "https://github.com/corleone/olive-oil/pull/97"))
    }

    @Test func familyIncludesDraftsWhileBusinessExcludesThem() async throws {
        let draft = SyncFixture.PullRequest(number: 7, createdAt: ago(hours: 1), isDraft: true)
        let ready = SyncFixture.PullRequest(number: 8, createdAt: ago(hours: 2))

        let store = try await sync(SyncFixture(business: [draft, ready], authored: [draft, ready]).data)

        #expect(store.business?.map(\.number) == [8])
        #expect(store.family?.map(\.number) == [7, 8])
    }

    @Test func syncAsksGitHubForPullRequestsIAuthoredAndPullRequestsAssignedToMe() async throws {
        let github = makeGitHub(SyncFixture().data)
        let store = try makeStore(github)

        await store.requestSync().value

        let searches = Array(github.lastVariables.values)
        #expect(searches.contains("is:open is:pr archived:false author:@me"))
        #expect(searches.contains("is:open is:pr archived:false assignee:@me"))
    }

    @Test func familyIncludesPullRequestsAssignedToMe() async throws {
        let assigned = SyncFixture.PullRequest(number: 5, author: "sonny", createdAt: ago(hours: 1))

        let store = try await sync(SyncFixture(assigned: [assigned]).data)

        #expect(store.family?.map(\.number) == [5])
    }

    @Test func aPullRequestIAuthoredAndAmAssignedToIsInFamilyOnce() async throws {
        let authoredAndAssigned = SyncFixture.PullRequest(number: 5, author: "tomhagen", createdAt: ago(hours: 1))

        let store = try await sync(SyncFixture(authored: [authoredAndAssigned], assigned: [authoredAndAssigned]).data)

        #expect(store.family?.map(\.number) == [5])
    }

    @Test func assignedPullRequestsJoinFamilyByMostRecentActivityDraftsIncluded() async throws {
        let older = SyncFixture.PullRequest(number: 1, author: "tomhagen", createdAt: ago(days: 2), updatedAt: ago(hours: 3))
        let assignedDraft = SyncFixture.PullRequest(number: 2, author: "sonny", createdAt: ago(days: 1), updatedAt: ago(hours: 1), isDraft: true)
        let newer = SyncFixture.PullRequest(number: 3, author: "tomhagen", createdAt: ago(days: 1), updatedAt: ago(hours: 2))

        let store = try await sync(SyncFixture(business: [assignedDraft], authored: [older, newer], assigned: [assignedDraft]).data)

        #expect(store.business == [])
        #expect(store.family?.map(\.number) == [2, 3, 1])
        #expect(store.family?.map(\.isDraft) == [true, false, false])
    }

    @Test func theFamilyCountIncludesAssignedPullRequestsOnce() async throws {
        preferences.countMode = .family

        let store = try await sync(SyncFixture(
            authored: [.init(number: 1, createdAt: ago(hours: 1)), .init(number: 2, createdAt: ago(hours: 2))],
            assigned: [.init(number: 2, createdAt: ago(hours: 2)), .init(number: 3, createdAt: ago(hours: 3))]
        ).data)

        #expect(store.countText == "3")
    }

    @Test func anAssignedPullRequestAskingForMyReviewIsInBusinessAndFamily() async throws {
        let pullRequest = SyncFixture.PullRequest(number: 4, createdAt: ago(hours: 1), requests: [.user("tomhagen", at: ago(hours: 1))])

        let store = try await sync(SyncFixture(business: [pullRequest], assigned: [pullRequest]).data)

        #expect(store.business?.map(\.number) == [4])
        #expect(store.family?.map(\.number) == [4])
    }

    @Test(arguments: [
        ("APPROVED", .approved),
        ("CHANGES_REQUESTED", .changesRequested),
        ("REVIEW_REQUIRED", nil),
        (nil, nil),
    ] as [(String?, ReviewState?)])
    func familyRowsShowTheirReviewState(reviewDecision: String?, expected: ReviewState?) async throws {
        let pullRequest = SyncFixture.PullRequest(number: 1, createdAt: ago(days: 1), reviewDecision: reviewDecision)

        let store = try await sync(SyncFixture(authored: [pullRequest]).data)

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

        let store = try await sync(SyncFixture(business: [pullRequest], authored: [pullRequest]).data)

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

        let store = try await sync(SyncFixture(business: [pullRequest], authored: [pullRequest]).data)

        #expect(store.business?.first?.checks == nil)
        #expect(store.family?.first?.checks == nil)
    }

    @Test func rowsKnowTheirBranchName() async throws {
        let store = try await sync(SyncFixtures.recorded)

        #expect(store.business?.map(\.branch) == ["fix/token-refresh-race", "swiftui-settings", "bump-fastlane"])
        #expect(store.family?.map(\.branch) == ["olive-oil-import", "push-routing", "offline-banner"])
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
            authored: [.init(number: 2, createdAt: ago(hours: 1)), .init(number: 3, createdAt: ago(hours: 2), isDraft: true)]
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
}
