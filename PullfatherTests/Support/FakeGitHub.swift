import Foundation
import Synchronization
@testable import Pullfather

nonisolated final class FakeGitHub: Sendable {
    private struct State {
        var requestCount = 0
        var isGateOpen: Bool
        var scriptedFailure: GitHubFailure?
        var response: Data?
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

    func fail(with failure: GitHubFailure?) {
        state.withLock { $0.scriptedFailure = failure }
    }

    func respond(with response: Data) {
        state.withLock { $0.response = response }
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

    fileprivate func send(token: String) async throws(GitHubFailure) -> Data {
        guard let login = viewers[token] else { throw failure }
        await passGate()
        let (scriptedFailure, response) = state.withLock { ($0.scriptedFailure, $0.response) }
        if let scriptedFailure {
            throw scriptedFailure
        }
        return response ?? Data(#"{"data":{"viewer":{"login":"\#(login)"}}}"#.utf8)
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
            try await github.send(token: token)
        }
    }
}
