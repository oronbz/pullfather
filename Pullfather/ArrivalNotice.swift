import Foundation

struct ArrivalNotice: Equatable {
    enum Destination: Equatable {
        case pullRequest(URL)
        case popover
    }

    let title: String
    let body: String
    let opens: Destination

    init?(arrivals: [BusinessRow]) {
        switch arrivals.count {
        case 0:
            return nil
        case 1:
            title = "\(arrivals[0].author) asks a favor"
            body = arrivals[0].title
            opens = .pullRequest(arrivals[0].url)
        default:
            title = "\(arrivals.count) new favors asked"
            body = ""
            opens = .popover
        }
    }
}
