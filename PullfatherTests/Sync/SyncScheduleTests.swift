import Foundation
import Testing
@testable import Pullfather

final class SyncScheduleTests: SyncStoreTestCase {
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
}
