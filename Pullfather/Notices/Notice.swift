import Foundation

struct Notice: Equatable {
    enum Destination: Equatable {
        case pullRequest(URL)
        case popover
    }

    let title: String
    let body: String
    let opens: Destination

    private init(title: String, body: String, opens: Destination) {
        self.title = title
        self.body = body
        self.opens = opens
    }

    private init(summary: String) {
        self.init(title: summary, body: "", opens: .popover)
    }

    init?(arrivals: [BusinessRow]) {
        switch arrivals.count {
        case 0:
            return nil
        case 1:
            self.init(title: "\(arrivals[0].author) asks a favor", body: arrivals[0].title, opens: .pullRequest(arrivals[0].url))
        default:
            self.init(summary: "\(arrivals.count) new favors asked")
        }
    }

    init?(verdicts: [FamilyRow]) {
        switch verdicts.count {
        case 0:
            return nil
        case 1:
            let verdict = verdicts[0]
            let title = verdict.reviewState == .changesRequested ? "They want to renegotiate" : "Your offer was accepted"
            self.init(title: title, body: "\(verdict.reference) · \(verdict.title)", opens: .pullRequest(verdict.url))
        default:
            self.init(summary: "\(verdicts.count) verdicts are in")
        }
    }
}
