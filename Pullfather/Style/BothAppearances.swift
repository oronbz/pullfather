#if DEBUG
import SwiftUI

struct BothAppearances<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                content
                    .environment(\.colorScheme, scheme)
            }
        }
        .padding(16)
    }
}
#endif
