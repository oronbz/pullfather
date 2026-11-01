import Foundation
import Synchronization
@testable import Pullfather

nonisolated final class FakeGitHub: Sendable {
    private struct State {
        var requestCount = 0
        var isGateOpen: Bool
        var scriptedFailure: GitHubFailure?
        var response: Data?
        var readResponse: Data?
        var lastVariables: [String: GraphQLVariable] = [:]
        var reviewBatches: [[String]] = []
        var reviewFailure: GitHubFailure?
        var writes: [RESTRequest] = []
        var writeFailure: GitHubFailure?
        var mutations: [GraphQLMutation] = []
        var mutationFailure: GitHubFailure?
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    private let viewers: [String: String]
    private let failure: GitHubFailure
    private let state: Mutex<State>

    init(viewers: [String: String] = [:], failure: GitHubFailure = .unauthorised, response: Data? = nil, gated: Bool = false) {
        self.viewers = viewers
        self.failure = failure
        state = Mutex(State(isGateOpen: !gated, response: response))
    }

    var requestCount: Int {
        state.withLock { $0.requestCount }
    }

    var lastVariables: [String: GraphQLVariable] {
        state.withLock { $0.lastVariables }
    }

    /// The pull request IDs each `ReviewQuery` asked for, in order.
    var reviewBatches: [[String]] {
        state.withLock { $0.reviewBatches }
    }

    func failReviews(with failure: GitHubFailure?) {
        state.withLock { $0.reviewFailure = failure }
    }

    var writes: [RESTRequest] {
        state.withLock { $0.writes }
    }

    func failWrites(with failure: GitHubFailure?) {
        state.withLock { $0.writeFailure = failure }
    }

    var mutations: [GraphQLMutation] {
        state.withLock { $0.mutations }
    }

    func failMutations(with failure: GitHubFailure?) {
        state.withLock { $0.mutationFailure = failure }
    }

    func hold() {
        state.withLock { $0.isGateOpen = false }
    }

    func fail(with failure: GitHubFailure?) {
        state.withLock { $0.scriptedFailure = failure }
    }

    func respond(with response: Data) {
        state.withLock { $0.response = response }
    }

    func respondToReads(with response: Data) {
        state.withLock { $0.readResponse = response }
    }

    func release() {
        let waiters = state.withLock { state in
            state.isGateOpen = true
            defer { state.waiters = [] }
            return state.waiters
        }
        for waiter in waiters {
            waiter.resume()
        }
    }

    func transport(token: String) -> any GitHubTransport {
        Transport(github: self, token: token)
    }

    fileprivate func send(token: String, query: String, variables: [String: GraphQLVariable]) async throws(GitHubFailure) -> Data {
        guard !query.hasPrefix("mutation") else {
            guard viewers[token] != nil else { throw failure }
            state.withLock { $0.mutations.append(GraphQLMutation(text: query, variables: variables)) }
            await passGate()
            if let mutationFailure = state.withLock({ $0.mutationFailure }) {
                throw mutationFailure
            }
            return Data(#"{"data":{}}"#.utf8)
        }
        if query == ReviewQuery.text {
            return try reviews(token: token, variables: variables)
        }
        state.withLock { $0.lastVariables = variables }
        guard let login = viewers[token] else { throw failure }
        await passGate()
        let (scriptedFailure, response) = state.withLock { ($0.scriptedFailure, $0.response) }
        if let scriptedFailure {
            throw scriptedFailure
        }
        return response ?? Data(#"{"data":{"viewer":{"login":"\#(login)"}}}"#.utf8)
    }

    /// Answers from the `reviews` map in the last Sync response, without counting as a request or waiting at the gate, so a Sync still reads as one request.
    private func reviews(token: String, variables: [String: GraphQLVariable]) throws(GitHubFailure) -> Data {
        guard viewers[token] != nil else { throw failure }
        guard case .strings(let ids) = variables["ids"] else { throw .other("ReviewQuery sent no IDs.") }
        let (scriptedFailure, reviewFailure, response) = state.withLock { state in
            state.reviewBatches.append(ids)
            return (state.scriptedFailure, state.reviewFailure, state.response)
        }
        if let failure = scriptedFailure ?? reviewFailure {
            throw failure
        }
        let payload = response.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["data"] as? [String: Any]
        let reviews = payload?["reviews"] as? [String: Any] ?? [:]
        let nodes = ids.map { reviews[$0] ?? NSNull() }
        return try! JSONSerialization.data(withJSONObject: ["data": ["nodes": nodes]])
    }

    fileprivate func send(token: String, request: RESTRequest) async throws(GitHubFailure) -> Data {
        guard viewers[token] != nil else { throw failure }
        guard request.method != "GET" else {
            await passGate()
            let (scriptedFailure, readResponse) = state.withLock { ($0.scriptedFailure, $0.readResponse) }
            if let scriptedFailure {
                throw scriptedFailure
            }
            return readResponse ?? Data("[]".utf8)
        }
        state.withLock { $0.writes.append(request) }
        await passGate()
        if let writeFailure = state.withLock({ $0.writeFailure }) {
            throw writeFailure
        }
        return Data()
    }

    private func passGate() async {
        await withCheckedContinuation { continuation in
            let isOpen = state.withLock { state in
                state.requestCount += 1
                if !state.isGateOpen {
                    state.waiters.append(continuation)
                }
                return state.isGateOpen
            }
            if isOpen {
                continuation.resume()
            }
        }
    }

    private struct Transport: GitHubTransport {
        let github: FakeGitHub
        let token: String

        func send(_ query: String, variables: [String: GraphQLVariable]) async throws(GitHubFailure) -> Data {
            try await github.send(token: token, query: query, variables: variables)
        }

        func send(_ request: RESTRequest) async throws(GitHubFailure) -> Data {
            try await github.send(token: token, request: request)
        }
    }
}
