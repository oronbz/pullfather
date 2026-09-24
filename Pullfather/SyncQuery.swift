import Foundation

nonisolated struct ReviewRequest: Equatable, Sendable {
    enum Reviewer: Equatable, Sendable {
        case user(String)
        case team
        case other
    }

    let reviewer: Reviewer
    let requestedAt: Date
}

nonisolated enum ReviewState: String, Equatable, Sendable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
}

nonisolated enum Checks: Equatable, Sendable {
    case passing
    case running
    case failing

    init?(rollupState: String) {
        switch rollupState {
        case "SUCCESS": self = .passing
        case "PENDING", "EXPECTED": self = .running
        case "FAILURE", "ERROR": self = .failing
        default: return nil
        }
    }
}

nonisolated struct PullRequest: Equatable, Sendable {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let repository: String
    let author: String
    let createdAt: Date
    let updatedAt: Date
    let isDraft: Bool
    let reviewState: ReviewState?
    let checks: Checks?
    let reviewRequests: [ReviewRequest]

    func waitingSince(viewer: String) -> Date {
        latestRequest(to: .user(viewer)) ?? latestRequest(to: .team) ?? createdAt
    }

    private func latestRequest(to reviewer: ReviewRequest.Reviewer) -> Date? {
        reviewRequests.filter { $0.reviewer == reviewer }.map(\.requestedAt).max()
    }
}

nonisolated struct SyncResult: Equatable, Sendable {
    let viewer: String
    let business: [PullRequest]
    let family: [PullRequest]
}

nonisolated enum SyncQuery {
    static let text = """
        query Sync($business: String!, $family: String!) {
          viewer { login }
          business: search(query: $business, type: ISSUE, first: 100) {
            nodes {
              ...PullRequestFields
              ... on PullRequest {
                timelineItems(itemTypes: [REVIEW_REQUESTED_EVENT], last: 20) {
                  nodes {
                    ... on ReviewRequestedEvent {
                      createdAt
                      requestedReviewer {
                        __typename
                        ... on User { login }
                      }
                    }
                  }
                }
              }
            }
          }
          family: search(query: $family, type: ISSUE, first: 100) {
            nodes {
              ...PullRequestFields
            }
          }
        }

        fragment PullRequestFields on PullRequest {
          id
          number
          title
          url
          createdAt
          updatedAt
          isDraft
          reviewDecision
          repository { nameWithOwner }
          author { login }
          commits(last: 1) {
            nodes {
              commit {
                statusCheckRollup { state }
              }
            }
          }
        }
        """

    static let variables: [String: GraphQLVariable] = [
        "business": "is:open is:pr archived:false -is:draft review-requested:@me",
        "family": "is:open is:pr archived:false author:@me",
    ]

    static func decode(_ data: Data) throws -> SyncResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Response.self, from: data).data
        return SyncResult(
            viewer: payload.viewer.login,
            business: payload.business.nodes.compactMap(\.pullRequest),
            family: payload.family.nodes.compactMap(\.pullRequest)
        )
    }

    private struct Response: Decodable {
        struct Payload: Decodable {
            let viewer: Viewer
            let business: Search
            let family: Search
        }

        struct Viewer: Decodable {
            let login: String
        }

        struct Search: Decodable {
            let nodes: [Node]
        }

        let data: Payload
    }

    private struct Node: Decodable {
        let pullRequest: PullRequest?

        init(from decoder: any Decoder) throws {
            pullRequest = try? PullRequestNode(from: decoder).pullRequest
        }
    }

    private struct PullRequestNode: Decodable {
        struct Repository: Decodable {
            let nameWithOwner: String
        }

        struct Author: Decodable {
            let login: String
        }

        struct Commits: Decodable {
            struct Node: Decodable {
                let commit: Commit
            }

            struct Commit: Decodable {
                let statusCheckRollup: StatusCheckRollup?
            }

            struct StatusCheckRollup: Decodable {
                let state: String
            }

            let nodes: [Node]

            var checks: Checks? {
                nodes.last?.commit.statusCheckRollup.flatMap { Checks(rollupState: $0.state) }
            }
        }

        struct Timeline: Decodable {
            let nodes: [ReviewRequestedEvent]
        }

        struct ReviewRequestedEvent: Decodable {
            let createdAt: Date
            let requestedReviewer: RequestedReviewer?
        }

        struct RequestedReviewer: Decodable {
            let __typename: String
            let login: String?

            var reviewer: ReviewRequest.Reviewer {
                switch (__typename, login) {
                case ("User", let login?): .user(login)
                case ("Team", _): .team
                default: .other
                }
            }
        }

        let id: String
        let number: Int
        let title: String
        let url: URL
        let createdAt: Date
        let updatedAt: Date
        let isDraft: Bool
        let reviewDecision: String?
        let repository: Repository
        let author: Author?
        let commits: Commits
        let timelineItems: Timeline?

        var pullRequest: PullRequest {
            PullRequest(
                id: id,
                number: number,
                title: title,
                url: url,
                repository: repository.nameWithOwner,
                author: author?.login ?? "ghost",
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDraft: isDraft,
                reviewState: reviewDecision.flatMap(ReviewState.init),
                checks: commits.checks,
                reviewRequests: (timelineItems?.nodes ?? []).map {
                    ReviewRequest(reviewer: $0.requestedReviewer?.reviewer ?? .other, requestedAt: $0.createdAt)
                }
            )
        }
    }
}
