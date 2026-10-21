import Foundation

nonisolated struct WidgetRow: Codable, Equatable, Identifiable, Sendable {
    enum Checks: String, Codable, Sendable {
        case passing
        case running
        case failing
    }

    var id: String
    var reference: String
    var title: String
    var url: URL
    /// Waiting Time for a Business row, Last Activity for a Family row.
    var elapsed: String
    var checks: Checks?
}

nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    static let kind = "PullfatherWidget"
    static let minimumStaleAfter: TimeInterval = 30 * 60
    static let businessRowLimit = 4
    static let familyRowLimit = 3

    var business: Int?
    var family: Int?
    var businessRows: [WidgetRow]
    var familyRows: [WidgetRow]
    var syncedAt: Date?
    var needsSignIn: Bool
    var staleAfter: TimeInterval = WidgetSnapshot.minimumStaleAfter

    var staleDate: Date? {
        syncedAt?.addingTimeInterval(staleAfter)
    }

    func isStale(at date: Date) -> Bool {
        staleDate.map { date >= $0 } ?? false
    }
}

nonisolated struct WidgetSnapshotFile: Sendable {
    static let standard = WidgetSnapshotFile(directory: homeDirectory.appending(path: "Library/Application Support/Pullfather/Widget"))

    let directory: URL

    private var fileURL: URL { directory.appending(path: "snapshot.json") }

    func write(_ snapshot: WidgetSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    func read() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// A sandboxed process reports its container as the home directory, so ask the user database instead.
    private static var homeDirectory: URL {
        guard let entry = getpwuid(getuid()), let path = entry.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(filePath: String(cString: path), directoryHint: .isDirectory)
    }
}
