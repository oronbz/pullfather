import Testing
@testable import Pullfather

struct LineChangesTests {
    @Test func showsSmallCountsInFull() {
        let changes = LineChanges(additions: 2, deletions: 999)

        #expect(changes.addedText == "+2")
        #expect(changes.removedText == "−999")
    }

    @Test func showsZeroes() {
        let changes = LineChanges(additions: 0, deletions: 0)

        #expect(changes.addedText == "+0")
        #expect(changes.removedText == "−0")
    }

    @Test(arguments: [
        (1000, "+1k"),
        (1240, "+1.2k"),
        (9960, "+9.9k"),
        (12_345, "+12k"),
        (250_000, "+250k"),
    ])
    func abbreviatesThousands(additions: Int, text: String) {
        #expect(LineChanges(additions: additions, deletions: 0).addedText == text)
    }
}
