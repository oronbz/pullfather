import Foundation
import Testing
@testable import Pullfather

struct NoticeTests {
    @Test func oneArrivalNamesItsAuthorAndTitleAndOpensThePullRequest() throws {
        let notice = try #require(Notice(arrivals: [BusinessRow.fixture(1088, author: "sonny", title: "Migrate settings screen to SwiftUI")]))

        #expect(notice.title == "sonny asks a favor")
        #expect(notice.body == "Migrate settings screen to SwiftUI")
        #expect(notice.opens == .pullRequest(URL(string: "https://github.com/corleone/casino/pull/1088")!))
    }

    @Test func severalArrivalsCollapseIntoOneNoticeThatOpensThePopover() throws {
        let notice = try #require(Notice(arrivals: [
            BusinessRow.fixture(1, author: "sonny", title: "One"),
            BusinessRow.fixture(2, author: "fredo", title: "Two"),
            BusinessRow.fixture(3, author: "luca-brasi", title: "Three"),
        ]))

        #expect(notice.title == "3 new favors asked")
        #expect(notice.body == "")
        #expect(notice.opens == .popover)
    }

    @Test func noArrivalsMeansNoNotice() {
        #expect(Notice(arrivals: []) == nil)
    }

    @Test func oneApprovalNamesThePullRequestAndOpensIt() throws {
        let notice = try #require(Notice(verdicts: [FamilyRow.fixture(1079, title: "Add offline banner", reviewState: .approved)]))

        #expect(notice.title == "Your offer was accepted")
        #expect(notice.body == "corleone/casino #1079 · Add offline banner")
        #expect(notice.opens == .pullRequest(URL(string: "https://github.com/corleone/casino/pull/1079")!))
    }

    @Test func oneRequestForChangesNamesThePullRequestAndOpensIt() throws {
        let notice = try #require(Notice(verdicts: [FamilyRow.fixture(1084, title: "Refactor push routing", reviewState: .changesRequested)]))

        #expect(notice.title == "They want to renegotiate")
        #expect(notice.body == "corleone/casino #1084 · Refactor push routing")
        #expect(notice.opens == .pullRequest(URL(string: "https://github.com/corleone/casino/pull/1084")!))
    }

    @Test func severalVerdictsCollapseIntoOneNoticeThatOpensThePopover() throws {
        let notice = try #require(Notice(verdicts: [
            FamilyRow.fixture(1, title: "One", reviewState: .approved),
            FamilyRow.fixture(2, title: "Two", reviewState: .changesRequested),
        ]))

        #expect(notice.title == "2 verdicts are in")
        #expect(notice.body == "")
        #expect(notice.opens == .popover)
    }

    @Test func noVerdictsMeansNoNotice() {
        #expect(Notice(verdicts: []) == nil)
    }
}
