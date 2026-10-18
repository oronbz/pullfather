import Foundation
import Testing
@testable import Pullfather

final class UpgraderTests {
    var steps: [String] = []
    var downloadFailure: (any Error)?
    var handOffFailure: (any Error)?
    let sleeper = ManualSleeper()

    private func makeUpgrader(holdingDownload: Bool = false) -> Upgrader {
        Upgrader(
            homebrew: Homebrew(
                download: { [unowned self] in
                    steps.append("download")
                    if holdingDownload {
                        try await sleeper.sleep(for: .zero)
                    }
                    if let downloadFailure { throw downloadFailure }
                },
                upgradeAfterQuit: { [unowned self] in
                    steps.append("upgrade after quit")
                    if let handOffFailure { throw handOffFailure }
                }
            ),
            quit: { [unowned self] in steps.append("quit") }
        )
    }

    @Test func upgradingDownloadsThenHandsOffAndQuits() async {
        let upgrader = makeUpgrader()

        await upgrader.upgrade()?.value

        #expect(steps == ["download", "upgrade after quit", "quit"])
        #expect(upgrader.failure == nil)
    }

    @Test func aFailedDownloadKeepsTheAppRunningAndSaysWhy() async {
        downloadFailure = HomebrewFailure.failed("Download failed on Cask 'pullfather'")
        let upgrader = makeUpgrader()

        await upgrader.upgrade()?.value

        #expect(steps == ["download"])
        #expect(upgrader.failure == "Couldn't update. Download failed on Cask 'pullfather'")
        #expect(!upgrader.isUpgrading)
    }

    @Test func missingHomebrewIsNamed() async {
        downloadFailure = HomebrewFailure.notInstalled
        let upgrader = makeUpgrader()

        await upgrader.upgrade()?.value

        #expect(upgrader.failure == "Couldn't update. Homebrew isn't installed.")
    }

    @Test func aFailedHandOffKeepsTheAppRunning() async {
        handOffFailure = POSIXError(.EAGAIN)
        let upgrader = makeUpgrader()

        await upgrader.upgrade()?.value

        #expect(steps == ["download", "upgrade after quit"])
        #expect(upgrader.failure != nil)
        #expect(!upgrader.isUpgrading)
    }

    @Test func clickingAgainWhileUpgradingIsIgnored() async {
        let upgrader = makeUpgrader(holdingDownload: true)
        let first = upgrader.upgrade()
        await sleeper.waitUntilAsleep(times: 1)

        #expect(upgrader.isUpgrading)
        #expect(upgrader.upgrade() == nil)

        sleeper.wake()
        await first?.value
        #expect(steps == ["download", "upgrade after quit", "quit"])
    }

    @Test func retryingAfterAFailureClearsIt() async {
        downloadFailure = HomebrewFailure.failed("Boom")
        let upgrader = makeUpgrader()
        await upgrader.upgrade()?.value

        downloadFailure = nil
        await upgrader.upgrade()?.value

        #expect(upgrader.failure == nil)
        #expect(steps.last == "quit")
    }
}
