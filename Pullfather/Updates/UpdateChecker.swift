import Foundation
import Observation

nonisolated struct Version: Comparable, CustomStringConvertible {
    private let components: [Int]

    init?(_ text: String) {
        let numbers = text.trimmingPrefix("v").split(separator: ".", omittingEmptySubsequences: false)
        let components = numbers.compactMap { $0.allSatisfy(\.isNumber) ? Int($0) : nil }
        guard (1...3).contains(numbers.count), components.count == numbers.count else { return nil }
        self.components = components + Array(repeating: 0, count: 3 - components.count)
    }

    var description: String {
        components.map(String.init).joined(separator: ".")
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

struct Release: Equatable {
    let version: String
    let url: URL
}

@Observable
final class UpdateChecker {
    static let upgradeCommand = "brew update && brew upgrade --cask pullfather"
    private static let repository = "oronbz/pullfather"
    private static let staleAfter: TimeInterval = 60 * 60
    private static let dailyInterval = Duration.seconds(24 * 60 * 60)

    private var latestNewerRelease: Release?

    var newerRelease: Release? {
        account.token == nil ? nil : latestNewerRelease
    }

    @ObservationIgnored private let account: Account
    @ObservationIgnored private let runningVersion: String
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    @ObservationIgnored private var lastCheckedAt: Date?
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    init(
        account: Account,
        runningVersion: String,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.account = account
        self.runningVersion = runningVersion
        self.now = now
        self.sleep = sleep
    }

    func checkDaily() async {
        repeat {
            await check().value
        } while (try? await sleep(Self.dailyInterval)) != nil
    }

    @discardableResult
    func checkIfStale() -> Task<Void, Never>? {
        if let lastCheckedAt, now().timeIntervalSince(lastCheckedAt) < Self.staleAfter {
            return nil
        }
        return check()
    }

    @discardableResult
    func check() -> Task<Void, Never> {
        if let inFlight {
            return inFlight
        }
        let task = Task {
            await checkLatestRelease()
            inFlight = nil
        }
        inFlight = task
        return task
    }

    private func checkLatestRelease() async {
        guard let token = account.token, let running = Version(runningVersion),
              let data = try? await account.makeTransport(token).send(.listingReleases(of: Self.repository)),
              let releases = try? JSONDecoder().decode([PublishedRelease].self, from: data)
        else { return }
        lastCheckedAt = now()
        let latest = releases
            .filter { !$0.draft && !$0.prerelease }
            .compactMap { release in Version(release.tagName).map { (version: $0, url: release.htmlURL) } }
            .max { $0.version < $1.version }
        latestNewerRelease = latest.flatMap { $0.version > running ? Release(version: $0.version.description, url: $0.url) : nil }
    }
}

#if DEBUG
extension UpdateChecker {
    static func preview(newerRelease: Release? = nil) -> UpdateChecker {
        let checker = UpdateChecker(account: .preview(signedIn: true), runningVersion: "0.3.0")
        checker.latestNewerRelease = newerRelease
        return checker
    }
}
#endif

private nonisolated struct PublishedRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft
        case prerelease
    }
}
