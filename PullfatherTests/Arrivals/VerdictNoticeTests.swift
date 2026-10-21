import Foundation
import Testing
@testable import Pullfather

struct VerdictNoticeTests {
    private func verdict(_ number: Int, title: String, reviewState: ReviewState) -> FamilyRow {
        FamilyRow(
            id: "PR_\(number)", number: number, title: title, url: URL(string: "https://github.com/corleone/casino/pull/\(number)")!,
            repository: "corleone/casino", branch: "offline-banner", lastActivity: "now", lineChanges: LineChanges(additions: 2, deletions: 4), isDraft: false, reviewState: reviewState, checks: nil
        )
    }

    @Test func oneApprovalNamesThePullRequestAndOpensIt() throws {
        let notice = try #require(VerdictNotice(verdicts: [verdict(1079, title: "Add offline banner", reviewState: .approved)]))

        #expect(notice.title == "Your offer was accepted")
        #expect(notice.body == "corleone/casino #1079 · Add offline banner")
        #expect(notice.opens == .pullRequest(URL(string: "https://github.com/corleone/casino/pull/1079")!))
    }

    @Test func oneRequestForChangesNamesThePullRequestAndOpensIt() throws {
        let notice = try #require(VerdictNotice(verdicts: [verdict(1084, title: "Refactor push routing", reviewState: .changesRequested)]))

        #expect(notice.title == "They want to renegotiate")
        #expect(notice.body == "corleone/casino #1084 · Refactor push routing")
        #expect(notice.opens == .pullRequest(URL(string: "https://github.com/corleone/casino/pull/1084")!))
    }

    @Test func severalVerdictsCollapseIntoOneNoticeThatOpensThePopover() throws {
        let notice = try #require(VerdictNotice(verdicts: [
            verdict(1, title: "One", reviewState: .approved),
            verdict(2, title: "Two", reviewState: .changesRequested),
        ]))

        #expect(notice.title == "2 verdicts are in")
        #expect(notice.body == "")
        #expect(notice.opens == .popover)
    }

    @Test func noVerdictsMeansNoNotice() {
        #expect(VerdictNotice(verdicts: []) == nil)
    }
}
