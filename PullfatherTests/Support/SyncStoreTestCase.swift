import Foundation
@testable import Pullfather

/// Shared by the `SyncStore` suites: a signed-in account on a fake GitHub, and the Arrivals and Verdicts each Sync reports.
class SyncStoreTestCase {
    let directory = FileManager.default.temporaryDirectory.appending(path: "SyncStoreTests-\(UUID().uuidString)")
    lazy var tokenStore = TokenStore(directory: directory)
    let testDefaults = TestDefaults()
    lazy var preferences = Preferences(defaults: testDefaults.defaults)
    var now = SyncFixtures.recordedAt
    let sleeper = ManualSleeper()
    var arrivals: [[String]] = []
    var verdicts: [[String]] = []

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    func ago(minutes: Double = 0, hours: Double = 0, days: Double = 0) -> Date {
        now.addingTimeInterval(-(minutes * 60 + hours * 3600 + days * 86400))
    }

    func sync(_ response: Data) async throws -> SyncStore {
        let store = try makeStore(makeGitHub(response))
        await store.requestSync().value
        return store
    }

    func makeGitHub(_ response: Data, gated: Bool = false) -> FakeGitHub {
        FakeGitHub(viewers: ["ghp_consigliere": "tomhagen", "ghp_new_consigliere": "tomhagen"], response: response, gated: gated)
    }

    func makeStore(_ github: FakeGitHub) throws -> SyncStore {
        try tokenStore.save("ghp_consigliere")
        let account = Account(tokenStore: tokenStore, makeTransport: github.transport(token:))
        let store = SyncStore(account: account, preferences: preferences, now: { [unowned self] in now }, sleep: sleeper.sleep(for:))
        store.onArrivals = { [unowned self] in arrivals.append($0.map(\.id)) }
        store.onVerdicts = { [unowned self] in verdicts.append($0.map(\.id)) }
        return store
    }

    func reRequested(_ pullRequest: SyncFixture.PullRequest) -> SyncFixture.PullRequest {
        var pullRequest = pullRequest
        pullRequest.requests.append(.user("tomhagen", at: ago(minutes: 5)))
        return pullRequest
    }

    /// A Family pull request authored by `tomhagen`, the signed-in viewer.
    func family(_ number: Int, reviews: [SyncFixture.Review] = [], threads: [SyncFixture.Thread] = [], requests: [SyncFixture.Request] = []) -> SyncFixture.PullRequest {
        SyncFixture.PullRequest(number: number, author: "tomhagen", createdAt: ago(hours: 2), requests: requests, reviews: reviews, threads: threads)
    }

    func review(_ state: String, minutesAgo: Double = 60) -> SyncFixture.Review {
        SyncFixture.Review(state: state, at: ago(minutes: minutesAgo))
    }

    func thread(resolved: Bool = false, _ comments: (author: String, minutesAgo: Double)...) -> SyncFixture.Thread {
        SyncFixture.Thread(isResolved: resolved, comments: comments.map { SyncFixture.Comment(author: $0.author, at: ago(minutes: $0.minutesAgo)) })
    }
}
