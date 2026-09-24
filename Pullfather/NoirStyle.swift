import SwiftUI

enum Noir {
    static let rowRadius: CGFloat = 7
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Palette.brass)
    }
}

struct NoirSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: title)
                .padding(.horizontal, 10)
            VStack(spacing: 2) {
                content
            }
        }
    }
}

struct NoirRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .font(.system(size: 13))
        .foregroundStyle(Palette.textPrimary)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        .background(Palette.rowHighlight, in: .rect(cornerRadius: Noir.rowRadius))
    }
}

struct NoirButtonStyle: ButtonStyle {
    var prominent = false
    var height: CGFloat = 26
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: prominent ? .semibold : .regular))
            .foregroundStyle(prominent ? Palette.bone : Palette.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(background(pressed: configuration.isPressed), in: .rect(cornerRadius: Noir.rowRadius))
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(.rect)
    }

    private func background(pressed: Bool) -> Color {
        let base = prominent ? Palette.commitRed : Palette.bone.opacity(0.1)
        return pressed ? base.opacity(0.7) : base
    }
}

extension ButtonStyle where Self == NoirButtonStyle {
    static var noir: NoirButtonStyle { NoirButtonStyle() }
    static var noirProminent: NoirButtonStyle { NoirButtonStyle(prominent: true) }
}

extension View {
    func noirField() -> some View {
        textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Palette.rowHighlight, in: .rect(cornerRadius: Noir.rowRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Noir.rowRadius)
                    .strokeBorder(Palette.hairline)
            }
    }
}
