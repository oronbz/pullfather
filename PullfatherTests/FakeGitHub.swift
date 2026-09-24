import Foundation
@testable import Pullfather

nonisolated struct FakeGitHub: Sendable {
    var viewers: [String: String] = [:]
    var failure: GitHubFailure = .unauthorised

    func transport(token: String) -> any GitHubTransport {
        Transport(login: viewers[token], failure: failure)
    }

    private struct Transport: GitHubTransport {
        let login: String?
        let failure: GitHubFailure

        func send(_ query: String, variables: [String: GraphQLVariable]) async throws(GitHubFailure) -> Data {
            guard let login else { throw failure }
            return Data(#"{"data":{"viewer":{"login":"\#(login)"}}}"#.utf8)
        }
    }
}
