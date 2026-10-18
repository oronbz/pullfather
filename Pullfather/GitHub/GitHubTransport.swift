import Foundation

nonisolated enum GitHubFailure: Error, Equatable, Sendable {
    case unauthorised
    case rateLimited(resetsAt: Date?)
    case offline
    case other(String)
}

nonisolated enum GraphQLVariable: Encodable, Equatable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral {
    case string(String)
    case int(Int)
    case bool(Bool)

    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .int(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }
}

nonisolated struct RESTRequest: Equatable, Sendable {
    let method: String
    let path: String
    var body: [String: [String]] = [:]

    static func removingRequestedReviewer(_ login: String, repository: String, number: Int) -> RESTRequest {
        RESTRequest(method: "DELETE", path: "repos/\(repository)/pulls/\(number)/requested_reviewers", body: ["reviewers": [login]])
    }

    static func listingReleases(of repository: String) -> RESTRequest {
        RESTRequest(method: "GET", path: "repos/\(repository)/releases")
    }
}

nonisolated struct GraphQLMutation: Equatable, Sendable {
    let text: String
    let variables: [String: GraphQLVariable]

    static func unsubscribing(from id: String) -> GraphQLMutation {
        GraphQLMutation(text: "mutation($id: ID!) { updateSubscription(input: {subscribableId: $id, state: UNSUBSCRIBED}) { subscribable { id } } }", variables: ["id": .string(id)])
    }

    static func approving(_ id: String) -> GraphQLMutation {
        GraphQLMutation(text: "mutation($id: ID!) { addPullRequestReview(input: {pullRequestId: $id, event: APPROVE}) { pullRequestReview { id } } }", variables: ["id": .string(id)])
    }
}

nonisolated protocol GitHubTransport: Sendable {
    func send(_ query: String, variables: [String: GraphQLVariable]) async throws(GitHubFailure) -> Data
    @discardableResult
    func send(_ request: RESTRequest) async throws(GitHubFailure) -> Data
}

extension GitHubTransport {
    @discardableResult
    func send(_ mutation: GraphQLMutation) async throws(GitHubFailure) -> Data {
        try await send(mutation.text, variables: mutation.variables)
    }
}
