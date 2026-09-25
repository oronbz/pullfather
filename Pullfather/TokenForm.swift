import SwiftUI

struct TokenForm: View {
    static let classicTokenURL = URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=Pullfather")!
    static let fineGrainedTokenURL = URL(string: "https://github.com/settings/personal-access-tokens/new")!

    let account: Account
    let onSignedIn: () -> Void

    @State private var token = ""
    @State private var cliToken: String?
    @FocusState private var isFocused: Bool

    init(account: Account, cliToken: String? = nil, onSignedIn: @escaping () -> Void = {}) {
        self.account = account
        self.onSignedIn = onSignedIn
        _cliToken = State(initialValue: cliToken)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cliToken {
                Button {
                    importFromCLI(cliToken)
                } label: {
                    Label("Import from gh", systemImage: "terminal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NoirButtonStyle(prominent: true, height: 30))
                Text("Uses the token the GitHub CLI is already signed in with.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textMuted)
                OrDivider()
            }

            SecureField("Paste a GitHub token", text: $token)
                .noirField()
                .focused($isFocused)
                .onSubmit {
                    if let cliToken, token.isEmpty {
                        importFromCLI(cliToken)
                    } else {
                        submit(token)
                    }
                }
                .onChange(of: token) { account.dismissSignInError() }

            if TokenStore.isFineGrained(token.trimmingCharacters(in: .whitespacesAndNewlines)) {
                Notice(symbol: "exclamationmark.triangle.fill", color: Palette.amber,
                       text: "Fine-grained tokens cover only one owner. Pull requests from other owners won't show up.")
            }
            if let error = account.signInError {
                Notice(symbol: "xmark.octagon.fill", color: Palette.checksFailing, text: error)
            }

            HStack(spacing: 4) {
                Text("Create a token:")
                Link("Classic (recommended)", destination: Self.classicTokenURL)
                    .foregroundStyle(Palette.brass)
                Text("·")
                Link("Fine-grained", destination: Self.fineGrainedTokenURL)
                    .foregroundStyle(Palette.brass)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.textMuted)

            HStack(spacing: 8) {
                if account.isValidating {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer(minLength: 0)
                Button("Sign In") { submit(token) }
                    .buttonStyle(NoirButtonStyle(prominent: cliToken == nil))
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .disabled(account.isValidating)
        .onAppear { isFocused = true }
        .onDisappear { account.dismissSignInError() }
        .task {
            if cliToken == nil {
                cliToken = await GitHubCLI.token()
            }
        }
    }

    private func importFromCLI(_ cliToken: String) {
        token = cliToken
        submit(cliToken)
    }

    private func submit(_ candidate: String) {
        Task {
            if await account.signIn(token: candidate) {
                token = ""
                onSignedIn()
            }
        }
    }
}

private struct OrDivider: View {
    var body: some View {
        HStack(spacing: 8) {
            line
            Text("or paste a token")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textMuted)
            line
        }
        .padding(.vertical, 2)
    }

    private var line: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
    }
}

private struct Notice: View {
    let symbol: String
    let color: Color
    let text: String

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
        }
        .font(.system(size: 11.5))
    }
}

#if DEBUG
#Preview("With gh") {
    BothAppearances {
        TokenForm(account: .preview(signedIn: false), cliToken: "gho_preview")
            .padding(16)
            .frame(width: PanelPlacement.width)
            .background(Palette.surface)
    }
}
#endif
