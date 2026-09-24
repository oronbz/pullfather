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

nonisolated struct PullRequest: Equatable, Sendable {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let repository: String
    let author: String
    let createdAt: Date
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
}

nonisolated enum SyncQuery {
    static let text = """
        query Sync($business: String!) {
          viewer { login }
          business: search(query: $business, type: ISSUE, first: 100) {
            nodes {
              ... on PullRequest {
                id
                number
                title
                url
                createdAt
                repository { nameWithOwner }
                author { login }
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
        }
        """

    static let variables: [String: GraphQLVariable] = [
        "business": "is:open is:pr archived:false -is:draft review-requested:@me",
    ]

    static func decode(_ data: Data) throws -> SyncResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Response.self, from: data).data
        return SyncResult(
            viewer: payload.viewer.login,
            business: payload.business.nodes.compactMap(\.pullRequest)
        )
    }

    private struct Response: Decodable {
        struct Payload: Decodable {
            let viewer: Viewer
            let business: Search
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
        let repository: Repository
        let author: Author?
        let timelineItems: Timeline

        var pullRequest: PullRequest {
            PullRequest(
                id: id,
                number: number,
                title: title,
                url: url,
                repository: repository.nameWithOwner,
                author: author?.login ?? "ghost",
                createdAt: createdAt,
                reviewRequests: timelineItems.nodes.map {
                    ReviewRequest(reviewer: $0.requestedReviewer?.reviewer ?? .other, requestedAt: $0.createdAt)
                }
            )
        }
    }
}
