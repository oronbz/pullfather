import Foundation

/// Fetches reviews and comment threads for Family pull requests by ID, so the cost scales with how many there are rather than with the Sync's search limits.
/// GitHub prices a query by its connections' parents, not their sizes, so fetching 20 comments per thread costs the same as fetching 1.
nonisolated enum ReviewQuery {
    static let batchSize = 100

    static let text = """
        query Reviews($ids: [ID!]!) {
          nodes(ids: $ids) {
            ... on PullRequest {
              id
              latestOpinionatedReviews(first: 20) {
                nodes { state submittedAt }
              }
              dismissedReviews: reviews(states: [DISMISSED], last: 20) {
                nodes { submittedAt }
              }
              reviewThreads(last: 50) {
                nodes {
                  isResolved
                  comments(last: 20) {
                    nodes {
                      publishedAt
                      author { login }
                    }
                  }
                }
              }
            }
          }
        }
        """

    static func variables(ids: [String]) -> [String: GraphQLVariable] {
        ["ids": .strings(ids)]
    }

    static func decode(_ data: Data) throws -> [String: FetchedReviews] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let nodes = try decoder.decode(Response.self, from: data).data.nodes.compactMap(\.self)
        return Dictionary(nodes.map { ($0.id, $0.fetched) }) { _, latest in latest }
    }

    private struct Response: Decodable {
        struct Payload: Decodable {
            let nodes: [Node?]
        }

        let data: Payload
    }

    private struct Node: Decodable {
        struct Reviews: Decodable {
            struct Node: Decodable {
                let state: String?
                let submittedAt: Date?
            }

            let nodes: [Node]
        }

        struct Threads: Decodable {
            struct Node: Decodable {
                let isResolved: Bool
                let comments: Comments
            }

            struct Comments: Decodable {
                let nodes: [Comment]
            }

            struct Comment: Decodable {
                /// When its review was submitted; a comment drafted earlier is created, but not seen, before then.
                let publishedAt: Date?
                let author: Author?
            }

            struct Author: Decodable {
                let login: String
            }

            let nodes: [Node]
        }

        let id: String
        let latestOpinionatedReviews: Reviews
        let dismissedReviews: Reviews
        let reviewThreads: Threads

        var fetched: FetchedReviews {
            let decisions = latestOpinionatedReviews.nodes.compactMap { node -> ReviewActivity.Review? in
                guard let submittedAt = node.submittedAt, let outcome = node.state.flatMap(ReviewActivity.Outcome.init) else { return nil }
                return ReviewActivity.Review(outcome: outcome, submittedAt: submittedAt)
            }
            let dismissals = dismissedReviews.nodes.compactMap { node in
                node.submittedAt.map { ReviewActivity.Review(outcome: .dismissed, submittedAt: $0) }
            }
            return FetchedReviews(
                reviews: decisions + dismissals,
                threads: reviewThreads.nodes.map { thread in
                    FetchedReviews.Thread(
                        isResolved: thread.isResolved,
                        comments: thread.comments.nodes.compactMap { comment in
                            comment.publishedAt.map { FetchedReviews.Comment(author: comment.author?.login, publishedAt: $0) }
                        }
                    )
                }
            )
        }
    }
}
