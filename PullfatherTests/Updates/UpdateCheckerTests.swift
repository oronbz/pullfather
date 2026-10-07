import Foundation
import Testing
@testable import Pullfather

final class UpdateCheckerTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "UpdateCheckerTests-\(UUID().uuidString)")
    lazy var tokenStore = TokenStore(directory: directory)
    let github = FakeGitHub(viewers: ["ghp_consigliere": "tomhagen"])
    var now = Date(timeIntervalSince1970: 1_790_000_000)
    let sleeper = ManualSleeper()
    var account: Account!
    let defaultsSuite = "UpdateCheckerTests-\(UUID().uuidString)"
    lazy var defaults = UserDefaults(suiteName: defaultsSuite)!

    deinit {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: defaultsSuite)
    }

    private func makeChecker(runningVersion: String = "0.3.0", signedIn: Bool = true) throws -> UpdateChecker {
        if signedIn {
            try tokenStore.save("ghp_consigliere")
        }
        account = Account(tokenStore: tokenStore, makeTransport: github.transport(token:))
        return UpdateChecker(account: account, runningVersion: runningVersion, defaults: defaults, now: { [unowned self] in now }, sleep: sleeper.sleep(for:))
    }

    private func publish(_ releases: ReleaseFixture...) {
        github.respondToReads(with: ReleaseFixture.data(releases))
    }

    @Test func aNewerPublishedReleaseIsOfferedAsAnUpdate() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker(runningVersion: "0.3.0")

        await checker.check().value

        #expect(checker.newerRelease == Release(version: "0.4.0", url: URL(string: "https://github.com/oronbz/pullfather/releases/tag/v0.4.0")!))
    }

    @Test(arguments: [
        ("0.9.0", "v0.10.0", "0.10.0"),
        ("0.3.0", "v1.0.0", "1.0.0"),
        ("0.3.9", "v0.4.0", "0.4.0"),
        ("0.3.0", "v0.3.0", nil),
        ("0.10.0", "v0.9.0", nil),
        ("1.0.0", "v0.99.99", nil),
    ])
    func versionsCompareAsSemver(running: String, published: String, offered: String?) async throws {
        publish(ReleaseFixture(tag: published))
        let checker = try makeChecker(runningVersion: running)

        await checker.check().value

        #expect(checker.newerRelease?.version == offered)
    }

    @Test func draftsAndPreReleasesAreIgnored() async throws {
        publish(
            ReleaseFixture(tag: "v0.6.0", draft: true),
            ReleaseFixture(tag: "v0.5.0", prerelease: true),
            ReleaseFixture(tag: "v0.4.0")
        )
        let checker = try makeChecker(runningVersion: "0.3.0")

        await checker.check().value

        #expect(checker.newerRelease?.version == "0.4.0")
    }

    @Test(arguments: [GitHubFailure.offline, .rateLimited(resetsAt: nil), .unauthorised, .other("Boom")])
    func aFailedCheckOffersNoUpdate(failure: GitHubFailure) async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        github.fail(with: failure)
        let checker = try makeChecker()

        await checker.check().value

        #expect(checker.newerRelease == nil)
    }

    @Test func signedOutThereIsNoCheck() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker(signedIn: false)

        await checker.check().value

        #expect(checker.newerRelease == nil)
        #expect(github.requestCount == 0)
    }

    @Test func signingOutHidesTheUpdate() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker()
        await checker.check().value

        account.signOut()

        #expect(checker.newerRelease == nil)
    }

    @Test func openingThePopoverDuringACheckJoinsIt() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        github.hold()
        let checker = try makeChecker()
        let launchCheck = checker.check()

        let popoverCheck = checker.checkIfStale()
        github.release()
        await launchCheck.value
        await popoverCheck?.value

        #expect(github.requestCount == 1)
        #expect(checker.newerRelease?.version == "0.4.0")
    }

    @Test func openingThePopoverWithinAnHourReusesTheLastCheck() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker()
        await checker.check().value

        now += 59 * 60
        await checker.checkIfStale()?.value

        #expect(github.requestCount == 1)
        #expect(checker.newerRelease?.version == "0.4.0")
    }

    @Test func openingThePopoverAfterAnHourChecksAgain() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker()
        await checker.check().value

        publish(ReleaseFixture(tag: "v0.5.0"))
        now += 61 * 60
        await checker.checkIfStale()?.value

        #expect(github.requestCount == 2)
        #expect(checker.newerRelease?.version == "0.5.0")
    }

    @Test func openingThePopoverChecksWhenThereWasNoCheckYet() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker()

        await checker.checkIfStale()?.value

        #expect(checker.newerRelease?.version == "0.4.0")
    }

    @Test func aFailedCheckIsRetriedTheNextTimeThePopoverOpens() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        github.fail(with: .offline)
        let checker = try makeChecker()
        await checker.check().value

        github.fail(with: nil)
        now += 60
        await checker.checkIfStale()?.value

        #expect(checker.newerRelease?.version == "0.4.0")
    }

    @Test func theScheduleChecksAtOnceAndThenOnceADay() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker()
        let schedule = Task { await checker.checkDaily() }
        defer { schedule.cancel() }

        await sleeper.waitUntilAsleep(times: 1)
        #expect(github.requestCount == 1)
        #expect(checker.newerRelease?.version == "0.4.0")

        publish(ReleaseFixture(tag: "v0.5.0"))
        sleeper.wake()
        await sleeper.waitUntilAsleep(times: 2)
        #expect(github.requestCount == 2)
        #expect(checker.newerRelease?.version == "0.5.0")
        #expect(sleeper.requests == [.seconds(86_400), .seconds(86_400)])
    }

    @Test func aNewerReleaseShowsTheBadge() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker()

        await checker.check().value

        #expect(checker.showsBadge)
    }

    @Test func noNewerReleaseMeansNoBadge() async throws {
        publish(ReleaseFixture(tag: "v0.3.0"))
        let checker = try makeChecker()

        await checker.check().value

        #expect(!checker.showsBadge)
    }

    @Test func dismissingTheBadgeKeepsTheUpdateInTheFooter() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker()
        await checker.check().value

        checker.dismissBadge()

        #expect(!checker.showsBadge)
        #expect(checker.newerRelease?.version == "0.4.0")
    }

    @Test func aDismissedVersionStaysDismissedAcrossLaunches() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        try await {
            let checker = try makeChecker()
            await checker.check().value
            checker.dismissBadge()
        }()

        let relaunched = try makeChecker()
        await relaunched.check().value

        #expect(!relaunched.showsBadge)
        #expect(relaunched.newerRelease?.version == "0.4.0")
    }

    @Test func aReleaseNewerThanTheDismissedOneShowsTheBadgeAgain() async throws {
        publish(ReleaseFixture(tag: "v0.4.0"))
        let checker = try makeChecker()
        await checker.check().value
        checker.dismissBadge()

        publish(ReleaseFixture(tag: "v0.4.1"))
        await checker.check().value

        #expect(checker.showsBadge)
    }

    @Test func onlyDraftsAndPreReleasesMeanNoUpdate() async throws {
        publish(ReleaseFixture(tag: "v0.5.0", draft: true), ReleaseFixture(tag: "v0.4.0-beta.1", prerelease: true))
        let checker = try makeChecker(runningVersion: "0.3.0")

        await checker.check().value

        #expect(checker.newerRelease == nil)
    }
}
