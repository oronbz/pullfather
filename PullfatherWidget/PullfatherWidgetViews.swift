import SwiftUI
import WidgetKit

struct PullfatherWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: SnapshotEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium: MediumLayout(snapshot: entry.snapshot)
            case .systemLarge: LargeLayout(snapshot: entry.snapshot)
            default: SmallLayout(snapshot: entry.snapshot)
            }
        }
        .opacity(entry.isStale ? 0.45 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private enum PullSection {
    case business
    case family

    var title: String {
        switch self {
        case .business: "Business"
        case .family: "Family"
        }
    }

    func count(in snapshot: WidgetSnapshot?) -> Int? {
        switch self {
        case .business: snapshot?.business
        case .family: snapshot?.family
        }
    }

    func rows(in snapshot: WidgetSnapshot?) -> [WidgetRow] {
        switch self {
        case .business: snapshot?.businessRows ?? []
        case .family: snapshot?.familyRows ?? []
        }
    }

    func countText(in snapshot: WidgetSnapshot?) -> String {
        count(in: snapshot).map(String.init) ?? "–"
    }

    func emptyText(in snapshot: WidgetSnapshot?) -> String? {
        guard snapshot?.needsSignIn != true else { return nil }
        guard count(in: snapshot) != nil else { return "Waiting for the first Sync." }
        return switch self {
        case .business: "Nothing waiting on you."
        case .family: "Nothing of yours is open."
        }
    }
}

private let mediumRowLimit = 3

private struct SmallLayout: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(section: .business)
            Text(PullSection.business.countText(in: snapshot))
                .font(.system(size: 52, weight: .semibold, design: .serif))
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            Text("\(PullSection.family.title) \(PullSection.family.countText(in: snapshot))")
                .font(.system(.footnote, design: .serif))
            SignInNotice(snapshot: snapshot)
        }
    }
}

private struct MediumLayout: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(section: .business)
                Text(PullSection.business.countText(in: snapshot))
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                Text("\(PullSection.family.title) \(PullSection.family.countText(in: snapshot))")
                    .font(.system(.footnote, design: .serif))
                SignInNotice(snapshot: snapshot)
            }
            .frame(width: 92, alignment: .leading)
            Divider()
            RowList(section: .business, snapshot: snapshot, limit: mediumRowLimit)
        }
    }
}

private struct LargeLayout: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(section: .business, snapshot: snapshot)
            RowList(section: .business, snapshot: snapshot, limit: WidgetSnapshot.businessRowLimit)
            SectionHeader(section: .family, snapshot: snapshot)
            RowList(section: .family, snapshot: snapshot, limit: WidgetSnapshot.familyRowLimit)
            Spacer(minLength: 0)
            SignInNotice(snapshot: snapshot)
        }
    }
}

private struct SectionLabel: View {
    let section: PullSection

    var body: some View {
        Text(section.title)
            .font(.system(.caption, design: .serif).weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

private struct SectionHeader: View {
    let section: PullSection
    let snapshot: WidgetSnapshot?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(section: section)
            Spacer()
            Text(section.countText(in: snapshot))
                .font(.system(.callout, design: .serif).weight(.semibold))
        }
    }
}

private struct RowList: View {
    let section: PullSection
    let snapshot: WidgetSnapshot?
    let limit: Int

    var body: some View {
        let rows = Array(section.rows(in: snapshot).prefix(limit))
        VStack(alignment: .leading, spacing: 6) {
            if rows.isEmpty, let emptyText = section.emptyText(in: snapshot) {
                Text(emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                RowView(row: row)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct RowView: View {
    let row: WidgetRow

    var body: some View {
        Link(destination: row.url) {
            HStack(spacing: 6) {
                ChecksDot(checks: row.checks)
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(row.reference)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(row.elapsed)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ChecksDot: View {
    let checks: WidgetRow.Checks?

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .accessibilityLabel(label)
    }

    private var color: Color {
        switch checks {
        case .passing: .green
        case .running: .orange
        case .failing: .red
        case nil: .clear
        }
    }

    private var label: String {
        switch checks {
        case .passing: "Checks passing"
        case .running: "Checks running"
        case .failing: "Checks failing"
        case nil: "No checks"
        }
    }
}

private struct SignInNotice: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        if snapshot?.needsSignIn == true {
            Text("Sign in again")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
