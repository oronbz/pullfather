import Foundation
import Testing
@testable import Pullfather

final class AccountTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "AccountTests-\(UUID().uuidString)")
    lazy var tokenStore = TokenStore(directory: directory)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeAccount(_ github: FakeGitHub) -> Account {
        Account(tokenStore: tokenStore, makeTransport: github.transport(token:))
    }

    @Test func aValidTokenSignsInAsTheViewer() async {
        let account = makeAccount(FakeGitHub(viewers: ["ghp_consigliere": "tomhagen"]))

        await account.signIn(token: "ghp_consigliere")

        #expect(account.state == .signedIn(login: "tomhagen"))
        #expect(account.signInError == nil)
        #expect(tokenStore.load() == "ghp_consigliere")
    }

    @Test func anUnauthorisedTokenShowsAnErrorAndSavesNothing() async {
        let account = makeAccount(FakeGitHub(failure: .unauthorised))

        await account.signIn(token: "ghp_revoked")

        #expect(account.state == .signedOut)
        #expect(account.signInError != nil)
        #expect(tokenStore.load() == nil)
    }

    @Test func aRejectedReplacementKeepsTheCurrentToken() async throws {
        try tokenStore.save("ghp_consigliere")
        let account = makeAccount(FakeGitHub(viewers: ["ghp_consigliere": "tomhagen"], failure: .unauthorised))

        await account.signIn(token: "ghp_revoked")

        #expect(account.signInError != nil)
        #expect(tokenStore.load() == "ghp_consigliere")
    }

    @Test func aSavedTokenIsSignedInOnLaunchAndLearnsItsLogin() async throws {
        try tokenStore.save("ghp_consigliere")
        let account = makeAccount(FakeGitHub(viewers: ["ghp_consigliere": "tomhagen"]))

        #expect(account.state == .signedIn(login: nil))

        await account.restore()

        #expect(account.state == .signedIn(login: "tomhagen"))
    }

    @Test func signingOutForgetsTheToken() async {
        let account = makeAccount(FakeGitHub(viewers: ["ghp_consigliere": "tomhagen"]))
        await account.signIn(token: "ghp_consigliere")

        account.signOut()

        #expect(account.state == .signedOut)
        #expect(tokenStore.load() == nil)
    }
}
