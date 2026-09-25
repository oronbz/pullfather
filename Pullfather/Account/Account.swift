import Foundation
import Observation

@Observable
final class Account {
    enum State: Equatable {
        case signedOut
        case signedIn(login: String?)
    }

    typealias MakeTransport = @Sendable (String) -> any GitHubTransport

    private(set) var state: State
    private(set) var token: String?
    private(set) var isValidating = false
    private(set) var signInError: String?

    @ObservationIgnored private let tokenStore: TokenStore
    @ObservationIgnored let makeTransport: MakeTransport

    init(tokenStore: TokenStore, makeTransport: @escaping MakeTransport) {
        self.tokenStore = tokenStore
        self.makeTransport = makeTransport
        let token = tokenStore.load()
        self.token = token
        state = token == nil ? .signedOut : .signedIn(login: nil)
    }

    @discardableResult
    func signIn(token: String) async -> Bool {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !isValidating else { return false }
        guard !TokenStore.isFineGrained(token) else {
            signInError = "Fine-grained tokens aren't supported. Use a classic token with repo scope."
            return false
        }
        isValidating = true
        defer { isValidating = false }
        signInError = nil
        do {
            let login = try await viewerLogin(token: token)
            try tokenStore.save(token)
            self.token = token
            state = .signedIn(login: login)
            return true
        } catch let failure as GitHubFailure {
            signInError = Self.message(for: failure)
        } catch {
            signInError = "Couldn't save the token: \(error.localizedDescription)"
        }
        return false
    }

    func restore() async {
        guard let token, let login = try? await viewerLogin(token: token) else { return }
        if state == .signedIn(login: nil) {
            state = .signedIn(login: login)
        }
    }

    func dismissSignInError() {
        signInError = nil
    }

    func signOut() {
        do {
            try tokenStore.remove()
            token = nil
            signInError = nil
            state = .signedOut
        } catch {
            signInError = "Couldn't remove the token: \(error.localizedDescription)"
        }
    }

    private func viewerLogin(token: String) async throws(GitHubFailure) -> String {
        let data = try await makeTransport(token).send("query { viewer { login } }", variables: [:])
        guard let response = try? JSONDecoder().decode(ViewerResponse.self, from: data) else {
            throw .other("GitHub sent an unexpected response.")
        }
        return response.data.viewer.login
    }

    private static func message(for failure: GitHubFailure) -> String {
        switch failure {
        case .unauthorised: "GitHub didn't accept that token."
        case .rateLimited: "GitHub is rate limiting this token. Try again later."
        case .offline: "Can't reach GitHub. Check your connection."
        case .other(let reason): reason
        }
    }
}

#if DEBUG
extension Account {
    static func preview(signedIn: Bool) -> Account {
        let tokenStore = TokenStore(directory: .temporaryDirectory.appending(path: "PullfatherPreview-\(UUID().uuidString)"))
        if signedIn {
            try? tokenStore.save("ghp_preview")
        }
        return Account(tokenStore: tokenStore, makeTransport: { URLSessionTransport(token: $0) })
    }
}
#endif

private nonisolated struct ViewerResponse: Decodable {
    struct Payload: Decodable {
        struct Viewer: Decodable {
            let login: String
        }

        let viewer: Viewer
    }

    let data: Payload
}
