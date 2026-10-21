import Foundation

struct VerdictNotice: Equatable {
    let title: String
    let body: String
    let opens: ArrivalNotice.Destination

    init?(verdicts: [FamilyRow]) {
        switch verdicts.count {
        case 0:
            return nil
        case 1:
            title = verdicts[0].reviewState == .changesRequested ? "They want to renegotiate" : "Your offer was accepted"
            body = "\(verdicts[0].reference) · \(verdicts[0].title)"
            opens = .pullRequest(verdicts[0].url)
        default:
            title = "\(verdicts.count) verdicts are in"
            body = ""
            opens = .popover
        }
    }
}
