import Foundation
import Testing
@testable import Pullfather

final class TokenStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "TokenStoreTests-\(UUID().uuidString)")
    lazy var store = TokenStore(directory: directory)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func aSavedTokenLoadsBackAfterRelaunch() throws {
        try store.save("ghp_consigliere")

        #expect(TokenStore(directory: directory).load() == "ghp_consigliere")
    }

    @Test func theTokenFileIsReadableOnlyByTheUser() throws {
        try store.save("ghp_consigliere")

        #expect(try permissions(of: tokenFile) == 0o600)
    }

    @Test func replacingTheTokenKeepsItUserOnly() throws {
        try store.save("ghp_consigliere")
        try store.save("ghp_underboss")

        #expect(store.load() == "ghp_underboss")
        #expect(try permissions(of: tokenFile) == 0o600)
    }

    @Test func removingTheTokenDeletesTheFile() throws {
        try store.save("ghp_consigliere")

        try store.remove()

        #expect(store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: tokenFile.path(percentEncoded: false)))
    }

    @Test func removingWhenSignedOutSucceeds() throws {
        try store.remove()

        #expect(store.load() == nil)
    }

    @Test func tokensStartingWithGithubPatAreFineGrained() {
        #expect(TokenStore.isFineGrained("github_pat_11ABCDEFG0123456789"))
        #expect(!TokenStore.isFineGrained("ghp_consigliere"))
    }

    private var tokenFile: URL { directory.appending(path: "token") }

    private func permissions(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        return try #require(attributes[.posixPermissions] as? Int)
    }
}
