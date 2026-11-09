import Foundation
import Testing
@testable import Pullfather

@Suite(.serialized)
final class URLSessionTransportTests {
    private let transport: URLSessionTransport

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        transport = URLSessionTransport(token: "ghp_consigliere", session: URLSession(configuration: configuration))
    }

    @Test func aMutationRefusedForAMissingScopeNamesTheScope() async throws {
        StubProtocol.body = Data("""
            {"errors":[{"type":"INSUFFICIENT_SCOPES","locations":[{"line":1,"column":38}],"message":"Your token has not been granted the required scopes to execute this query. The 'updateSubscription' field requires one of the following scopes: ['notifications'], but your token has only been granted the: ['admin:public_key', 'gist', 'read:org', 'repo'] scopes. Please modify your token's scopes at: https://github.com/settings/tokens."}]}
            """.utf8)

        await #expect(throws: GitHubFailure.missingScope("notifications")) {
            try await transport.send(.unsubscribing(from: "PR_1"))
        }
    }

    @Test func anotherRejectedMutationKeepsGitHubsMessage() async throws {
        StubProtocol.body = Data("""
            {"data":{"addPullRequestReview":null},"errors":[{"type":"FORBIDDEN","message":"Can not approve your own pull request"}]}
            """.utf8)

        await #expect(throws: GitHubFailure.other("Can not approve your own pull request")) {
            try await transport.send(.approving("PR_1"))
        }
    }
}

private nonisolated final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
