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

nonisolated protocol GitHubTransport: Sendable {
    func send(_ query: String, variables: [String: GraphQLVariable]) async throws(GitHubFailure) -> Data
}
