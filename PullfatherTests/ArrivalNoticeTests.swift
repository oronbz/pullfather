import Foundation
import Testing
@testable import Pullfather

struct ArrivalNoticeTests {
    private func arrival(_ number: Int, author: String, title: String) -> BusinessRow {
        BusinessRow(
            id: "PR_\(number)", number: number, title: title, url: URL(string: "https://github.com/corleone/casino/pull/\(number)")!,
            repository: "corleone/casino", author: author, avatarURL: nil, waitingSince: .now, waitingTime: "now", checks: nil
        )
    }

    @Test func oneArrivalNamesItsAuthorAndTitleAndOpensThePullRequest() throws {
        let notice = try #require(ArrivalNotice(arrivals: [arrival(1088, author: "sonny", title: "Migrate settings screen to SwiftUI")]))

        #expect(notice.title == "sonny asks a favor")
        #expect(notice.body == "Migrate settings screen to SwiftUI")
        #expect(notice.opens == .pullRequest(URL(string: "https://github.com/corleone/casino/pull/1088")!))
    }

    @Test func severalArrivalsCollapseIntoOneNoticeThatOpensThePopover() throws {
        let notice = try #require(ArrivalNotice(arrivals: [
            arrival(1, author: "sonny", title: "One"),
            arrival(2, author: "fredo", title: "Two"),
            arrival(3, author: "luca-brasi", title: "Three"),
        ]))

        #expect(notice.title == "3 new favors asked")
        #expect(notice.body == "")
        #expect(notice.opens == .popover)
    }

    @Test func noArrivalsMeansNoNotice() {
        #expect(ArrivalNotice(arrivals: []) == nil)
    }
}
