import SwiftUI
import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    var isStale: Bool {
        snapshot?.isStale(at: date) ?? false
    }
}

struct SnapshotProvider: TimelineProvider {
    private static let refreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : SnapshotEntry(date: .now, snapshot: WidgetSnapshotFile.standard.read()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetSnapshotFile.standard.read()
        var entries = [SnapshotEntry(date: .now, snapshot: snapshot)]
        if let staleDate = snapshot?.staleDate, staleDate > .now {
            entries.append(SnapshotEntry(date: staleDate, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(Self.refreshInterval))))
    }
}

struct PullfatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.kind, provider: SnapshotProvider()) { entry in
            PullfatherWidgetView(entry: entry)
        }
        .configurationDisplayName("The Pullfather")
        .description("The business waiting on you, and your family.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct PullfatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        PullfatherWidget()
    }
}

extension WidgetSnapshot {
    static let sample = WidgetSnapshot(
        business: 3,
        family: 4,
        businessRows: [
            WidgetRow(id: "3", reference: "corleone/olive-oil #412", title: "Fix race in token refresh", url: URL(string: "https://github.com/corleone/olive-oil/pull/412")!, elapsed: "2h", checks: .passing),
            WidgetRow(id: "2", reference: "corleone/casino #1088", title: "Migrate settings screen to SwiftUI", url: URL(string: "https://github.com/corleone/casino/pull/1088")!, elapsed: "5h", checks: .running),
            WidgetRow(id: "1", reference: "corleone/casino #1091", title: "Bump fastlane to latest", url: URL(string: "https://github.com/corleone/casino/pull/1091")!, elapsed: "1d", checks: .failing),
        ],
        familyRows: [
            WidgetRow(id: "6", reference: "corleone/olive-oil #97", title: "Sketch the olive oil import pipeline", url: URL(string: "https://github.com/corleone/olive-oil/pull/97")!, elapsed: "30m", checks: nil),
            WidgetRow(id: "5", reference: "corleone/casino #1084", title: "Refactor push routing", url: URL(string: "https://github.com/corleone/casino/pull/1084")!, elapsed: "1d", checks: .failing),
            WidgetRow(id: "4", reference: "corleone/casino #1079", title: "Add offline banner", url: URL(string: "https://github.com/corleone/casino/pull/1079")!, elapsed: "3d", checks: .passing),
        ],
        syncedAt: .now.addingTimeInterval(-4 * 60),
        needsSignIn: false
    )
}

#Preview("Small", as: .systemSmall) {
    PullfatherWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
}

#Preview("Medium", as: .systemMedium) {
    PullfatherWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
}

#Preview("Large", as: .systemLarge) {
    PullfatherWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
}

#Preview("Medium, stale", as: .systemMedium) {
    PullfatherWidget()
} timeline: {
    SnapshotEntry(date: .now.addingTimeInterval(2 * 60 * 60), snapshot: .sample)
}
