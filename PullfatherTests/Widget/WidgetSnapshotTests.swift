import Foundation
import Testing
@testable import Pullfather

final class WidgetSnapshotTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "WidgetSnapshotTests-\(UUID().uuidString)")
    lazy var file = WidgetSnapshotFile(directory: directory)
    let tokenDirectory = FileManager.default.temporaryDirectory.appending(path: "WidgetSnapshotTests-token-\(UUID().uuidString)")
    let defaultsSuite = "WidgetSnapshotTests-\(UUID().uuidString)"
    var github = FakeGitHub()

    deinit {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.removeItem(at: tokenDirectory)
        UserDefaults().removePersistentDomain(forName: defaultsSuite)
    }

    private let row = WidgetRow(
        id: "PR_412",
        reference: "corleone/olive-oil #412",
        title: "Fix race in token refresh",
        url: URL(string: "https://github.com/corleone/olive-oil/pull/412")!,
        elapsed: "2h",
        checks: .passing
    )

    @Test func aWrittenSnapshotReadsBack() throws {
        let snapshot = WidgetSnapshot(business: 3, family: 4, businessRows: [row], familyRows: [row], syncedAt: SyncFixtures.recordedAt, needsSignIn: false)

        try file.write(snapshot)

        #expect(file.read() == snapshot)
    }

    @Test func nothingIsReadBeforeTheFirstWrite() {
        #expect(file.read() == nil)
    }

    @Test func aNewSnapshotReplacesTheOldOne() throws {
        try file.write(WidgetSnapshot(business: 3, family: 4, businessRows: [row], familyRows: [row], syncedAt: SyncFixtures.recordedAt, needsSignIn: false))
        let later = WidgetSnapshot(business: 0, family: 1, businessRows: [], familyRows: [row], syncedAt: SyncFixtures.recordedAt.addingTimeInterval(60), needsSignIn: false)

        try file.write(later)

        #expect(file.read() == later)
    }

    @Test func theWidgetDirectoryDoesNotHoldTheTokenFile() {
        let widget = WidgetSnapshotFile.standard.directory.path(percentEncoded: false)
        let tokenFile = TokenStore.standard.directory.appending(path: "token").path(percentEncoded: false)

        #expect(!tokenFile.hasPrefix(widget + "/"))
        #expect(widget.hasPrefix(TokenStore.standard.directory.path(percentEncoded: false) + "/"))
    }

    @Test func theSandboxExceptionCoversExactlyTheWidgetDirectory() throws {
        let entitlements = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "PullfatherWidget/PullfatherWidget.entitlements")
        let plist = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: entitlements), format: nil) as? [String: Any])
        let exceptions = try #require(plist["com.apple.security.temporary-exception.files.home-relative-path.read-only"] as? [String])
        let home = FileManager.default.homeDirectoryForCurrentUser

        let covered = exceptions.map { home.appending(path: String($0.drop { $0 == "/" })).standardizedFileURL.path(percentEncoded: false) }

        #expect(covered.map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 } == [WidgetSnapshotFile.standard.directory.path(percentEncoded: false)])
        #expect(plist["com.apple.security.app-sandbox"] as? Bool == true)
    }

    private func sync(_ fixture: SyncFixture) async throws -> SyncStore {
        github = FakeGitHub(viewers: ["ghp_consigliere": "tomhagen"], response: fixture.data, gated: false)
        let tokenStore = TokenStore(directory: tokenDirectory)
        try tokenStore.save("ghp_consigliere")
        let account = Account(tokenStore: tokenStore, makeTransport: github.transport(token:))
        let store = SyncStore(account: account, preferences: Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!), now: { SyncFixtures.recordedAt }, sleep: ManualSleeper().sleep(for:))
        await store.requestSync().value
        return store
    }

    private func requested(_ number: Int, hoursAgo: Double, rollupState: String? = nil) -> SyncFixture.PullRequest {
        let at = SyncFixtures.recordedAt.addingTimeInterval(-hoursAgo * 3600)
        return SyncFixture.PullRequest(number: number, createdAt: at, rollupState: rollupState, requests: [.user("tomhagen", at: at)], pending: [.user("tomhagen")])
    }

    @Test func aSyncedStoreDescribesItselfToTheWidget() async throws {
        let store = try await sync(SyncFixture(
            business: [requested(412, hoursAgo: 2, rollupState: "SUCCESS"), requested(1088, hoursAgo: 5, rollupState: "FAILURE")],
            authored: [SyncFixture.PullRequest(number: 97, repository: "corleone/casino", createdAt: SyncFixtures.recordedAt.addingTimeInterval(-1800), rollupState: "PENDING")]
        ))

        let snapshot = try #require(store.widgetSnapshot)

        #expect(snapshot.business == 2)
        #expect(snapshot.family == 1)
        #expect(snapshot.syncedAt == SyncFixtures.recordedAt)
        #expect(!snapshot.needsSignIn)
        #expect(snapshot.businessRows.map { [$0.reference, $0.elapsed] } == store.business?.map { [$0.reference, $0.waitingTime] })
        #expect(snapshot.businessRows.map(\.checks) == store.business?.map { $0.checks == .passing ? .passing : .failing })
        #expect(snapshot.businessRows.first?.url == store.business?.first?.url)
        #expect(snapshot.familyRows.map { [$0.reference, $0.elapsed, $0.title] } == [["corleone/casino #97", "30m", "Fix race in token refresh"]])
        #expect(snapshot.familyRows.first?.checks == .running)
    }

    @Test func nothingStaleIsShownOnceTheTokenIsRejected() async throws {
        let store = try await sync(SyncFixture(
            business: [requested(412, hoursAgo: 2)],
            authored: [SyncFixture.PullRequest(number: 97, createdAt: SyncFixtures.recordedAt.addingTimeInterval(-1800))]
        ))
        #expect(store.widgetSnapshot?.businessRows.count == 1)
        #expect(store.widgetSnapshot?.familyRows.count == 1)

        github.fail(with: .unauthorised)
        await store.requestSync().value

        #expect(store.widgetSnapshot == WidgetSnapshot(
            business: nil,
            family: nil,
            businessRows: [],
            familyRows: [],
            syncedAt: SyncFixtures.recordedAt,
            needsSignIn: true
        ))
    }

    @Test func rowsAreCappedPerSectionButCountsAreNot() async throws {
        let at = SyncFixtures.recordedAt
        let store = try await sync(SyncFixture(
            business: (1...7).map { requested($0, hoursAgo: Double($0)) },
            authored: (101...106).map { SyncFixture.PullRequest(number: $0, createdAt: at.addingTimeInterval(-Double($0))) }
        ))

        let snapshot = try #require(store.widgetSnapshot)

        #expect(snapshot.business == 7)
        #expect(snapshot.family == 6)
        #expect(snapshot.businessRows.count == WidgetSnapshot.businessRowLimit)
        #expect(snapshot.familyRows.count == WidgetSnapshot.familyRowLimit)
        #expect(snapshot.businessRows.map(\.id) == store.business?.prefix(WidgetSnapshot.businessRowLimit).map(\.id))
        #expect(snapshot.familyRows.map(\.id) == store.family?.prefix(WidgetSnapshot.familyRowLimit).map(\.id))
    }

    @Test func aSignedOutStoreAsksToSignIn() {
        let account = Account(tokenStore: TokenStore(directory: tokenDirectory), makeTransport: { URLSessionTransport(token: $0) })
        let store = SyncStore(account: account, preferences: Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!))

        #expect(store.widgetSnapshot == WidgetSnapshot(business: nil, family: nil, businessRows: [], familyRows: [], syncedAt: nil, needsSignIn: true))
    }

    @Test func signingOutClearsTheAccountsPullRequests() async throws {
        let store = try await sync(SyncFixture(business: [requested(412, hoursAgo: 2)]))
        #expect(store.widgetSnapshot?.businessRows.count == 1)

        store.account.signOut()
        await store.requestSync().value

        #expect(store.widgetSnapshot == WidgetSnapshot(business: nil, family: nil, businessRows: [], familyRows: [], syncedAt: nil, needsSignIn: true))
    }

    @Test func aStoreThatHasNotSyncedYetHasNothingNewToSay() throws {
        let tokenStore = TokenStore(directory: tokenDirectory)
        try tokenStore.save("ghp_consigliere")
        let account = Account(tokenStore: tokenStore, makeTransport: { URLSessionTransport(token: $0) })
        let store = SyncStore(account: account, preferences: Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!))

        #expect(store.widgetSnapshot == nil)
    }

    @Test func aFailedSyncKeepsTheLastGoodSnapshotInPlace() async throws {
        let store = try await sync(SyncFixture(business: [requested(412, hoursAgo: 2)]))
        let before = store.widgetSnapshot

        github.fail(with: .offline)
        await store.requestSync().value

        #expect(store.widgetSnapshot == before)
    }

    @Test func checksFollowTheCheckPreferencesPerSection() async throws {
        let at = SyncFixtures.recordedAt.addingTimeInterval(-1800)
        let store = try await sync(SyncFixture(
            business: [requested(412, hoursAgo: 2, rollupState: "SUCCESS")],
            authored: [SyncFixture.PullRequest(number: 97, createdAt: at, rollupState: "FAILURE")]
        ))
        #expect(store.widgetSnapshot?.businessRows.first?.checks == .passing)
        #expect(store.widgetSnapshot?.familyRows.first?.checks == .failing)

        store.preferences.showsBusinessChecks = false
        #expect(store.widgetSnapshot?.businessRows.first?.checks == nil)
        #expect(store.widgetSnapshot?.familyRows.first?.checks == .failing)

        store.preferences.showsBusinessChecks = true
        store.preferences.showsFamilyChecks = false
        #expect(store.widgetSnapshot?.businessRows.first?.checks == .passing)
        #expect(store.widgetSnapshot?.familyRows.first?.checks == nil)
    }

    // MARK: Publishing

    private func makePublisher(file: WidgetSnapshotFile, reloads: Reloads) throws -> WidgetPublisher {
        let account = Account(tokenStore: TokenStore(directory: tokenDirectory), makeTransport: { URLSessionTransport(token: $0) })
        let store = SyncStore(account: account, preferences: Preferences(defaults: UserDefaults(suiteName: defaultsSuite)!))
        return WidgetPublisher(store: store, file: file, reload: { reloads.count += 1 })
    }

    private final class Reloads {
        var count = 0
    }

    private let sampleSnapshot = WidgetSnapshot(business: 1, family: 0, businessRows: [], familyRows: [], syncedAt: SyncFixtures.recordedAt, needsSignIn: false)

    @Test func publishingNothingLeavesTheLastGoodSnapshotAlone() throws {
        let reloads = Reloads()
        try file.write(sampleSnapshot)
        let publisher = try makePublisher(file: file, reloads: reloads)

        publisher.publish(nil)

        #expect(file.read() == sampleSnapshot)
        #expect(reloads.count == 0)
    }

    @Test func anUnchangedSnapshotIsNotPublishedAgain() throws {
        let reloads = Reloads()
        let publisher = try makePublisher(file: file, reloads: reloads)

        publisher.publish(sampleSnapshot)
        publisher.publish(sampleSnapshot)

        #expect(file.read() == sampleSnapshot)
        #expect(reloads.count == 1)
    }

    @Test func aFailedWriteIsRetriedWithTheSameSnapshot() throws {
        let reloads = Reloads()
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: directory)
        let publisher = try makePublisher(file: file, reloads: reloads)

        publisher.publish(sampleSnapshot)
        #expect(reloads.count == 0)

        try FileManager.default.removeItem(at: directory)
        publisher.publish(sampleSnapshot)

        #expect(file.read() == sampleSnapshot)
        #expect(reloads.count == 1)
    }

    @Test(.timeLimit(.minutes(1))) func startPublishesEachDistinctSnapshotAndReloadsTheWidget() async throws {
        let store = try await sync(SyncFixture(
            business: [requested(412, hoursAgo: 2, rollupState: "SUCCESS")],
            authored: [SyncFixture.PullRequest(number: 97, createdAt: SyncFixtures.recordedAt.addingTimeInterval(-1800))]
        ))
        let (reloads, signal) = AsyncStream.makeStream(of: Void.self)
        var nextReload = reloads.makeAsyncIterator()
        let publisher = WidgetPublisher(store: store, file: file, reload: { signal.yield() })

        publisher.start()
        await nextReload.next()
        #expect(file.read() == store.widgetSnapshot)
        #expect(file.read()?.businessRows.first?.checks == .passing)

        store.preferences.showsBusinessChecks = false
        await nextReload.next()
        #expect(file.read()?.businessRows.first?.checks == nil)

        github.fail(with: .unauthorised)
        await store.requestSync().value
        await nextReload.next()
        #expect(file.read() == WidgetSnapshot(business: nil, family: nil, businessRows: [], familyRows: [], syncedAt: SyncFixtures.recordedAt, needsSignIn: true))
    }

    // MARK: Reloading and staleness

    private func snapshot(syncedAt: Date, business: Int = 1, staleAfter: TimeInterval = 30 * 60) -> WidgetSnapshot {
        WidgetSnapshot(business: business, family: 0, businessRows: [], familyRows: [], syncedAt: syncedAt, needsSignIn: false, staleAfter: staleAfter)
    }

    @Test func aSyncThatChangesNothingVisibleIsWrittenButDoesNotReloadTheWidget() throws {
        let reloads = Reloads()
        let publisher = try makePublisher(file: file, reloads: reloads)
        let first = snapshot(syncedAt: SyncFixtures.recordedAt)
        let nextMinute = snapshot(syncedAt: SyncFixtures.recordedAt.addingTimeInterval(60))

        publisher.publish(first)
        publisher.publish(nextMinute)

        #expect(file.read() == nextMinute)
        #expect(reloads.count == 1)
    }

    @Test func aSlowHeartbeatStillReloadsTheWidgetBeforeItGoesStale() throws {
        let reloads = Reloads()
        let publisher = try makePublisher(file: file, reloads: reloads)
        let staleAfter: TimeInterval = 30 * 60

        publisher.publish(snapshot(syncedAt: SyncFixtures.recordedAt))
        publisher.publish(snapshot(syncedAt: SyncFixtures.recordedAt.addingTimeInterval(staleAfter / 3 - 1)))
        #expect(reloads.count == 1)

        publisher.publish(snapshot(syncedAt: SyncFixtures.recordedAt.addingTimeInterval(staleAfter / 3)))
        #expect(reloads.count == 2)
    }

    @Test func aVisibleChangeReloadsTheWidgetRightAway() throws {
        let reloads = Reloads()
        let publisher = try makePublisher(file: file, reloads: reloads)

        publisher.publish(snapshot(syncedAt: SyncFixtures.recordedAt, business: 1))
        publisher.publish(snapshot(syncedAt: SyncFixtures.recordedAt.addingTimeInterval(60), business: 2))

        #expect(reloads.count == 2)
    }

    @Test func aSnapshotIsStaleOnceItsStaleWindowHasPassed() {
        let snapshot = snapshot(syncedAt: SyncFixtures.recordedAt, staleAfter: 30 * 60)

        #expect(!snapshot.isStale(at: SyncFixtures.recordedAt.addingTimeInterval(30 * 60 - 1)))
        #expect(snapshot.isStale(at: SyncFixtures.recordedAt.addingTimeInterval(30 * 60)))
        #expect(snapshot.staleDate == SyncFixtures.recordedAt.addingTimeInterval(30 * 60))
        #expect(!WidgetSnapshot(business: nil, family: nil, businessRows: [], familyRows: [], syncedAt: nil, needsSignIn: true).isStale(at: .distantFuture))
    }

    @Test func theStaleWindowFollowsTheRefreshInterval() async throws {
        let store = try await sync(SyncFixture(business: [requested(412, hoursAgo: 2)]))
        #expect(store.widgetSnapshot?.staleAfter == TimeInterval(30 * 60))

        store.preferences.refreshInterval = .sixtyMinutes

        #expect(store.widgetSnapshot?.staleAfter == TimeInterval(2 * 60 * 60))
    }

    @Test(.timeLimit(.minutes(1))) func thePublisherDoesNotKeepItselfAlive() async throws {
        let store = try await sync(SyncFixture(business: [requested(412, hoursAgo: 2)]))
        let (reloads, signal) = AsyncStream.makeStream(of: Void.self)
        var nextReload = reloads.makeAsyncIterator()
        var publisher: WidgetPublisher? = WidgetPublisher(store: store, file: file, reload: { signal.yield() })
        weak let weakPublisher = publisher

        publisher?.start()
        publisher?.start()
        await nextReload.next()
        publisher = nil

        #expect(weakPublisher == nil)
    }
}
