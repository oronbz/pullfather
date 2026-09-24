import SwiftUI

struct SignInCard: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Sign in")
            Text("The Pullfather needs a GitHub token to see your pull requests. It stays in a file only you can read.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            TokenForm(account: account)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SignedInLine: View {
    let login: String?

    var body: some View {
        Text(Self.text(for: login))
            .font(.system(size: 13))
            .foregroundStyle(Palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    static func text(for login: String?) -> String {
        login.map { "Signed in as @\($0)" } ?? "Signed in"
    }
}

#Preview {
    SignInCard(account: .preview(signedIn: false))
        .frame(width: PanelPlacement.width)
        .background(Palette.surface)
        .environment(\.colorScheme, .dark)
}
