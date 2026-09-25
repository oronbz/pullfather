import AppKit
import Observation

@Observable
final class AvatarCache {
    typealias Download = @Sendable (URL) async throws -> Data

    private var images: [URL: NSImage] = [:]
    @ObservationIgnored private var inFlight: [URL: Task<Void, Never>] = [:]
    @ObservationIgnored private let download: Download

    init(download: @escaping Download = AvatarCache.fromGitHub) {
        self.download = download
    }

    func image(for url: URL) -> NSImage? {
        images[url]
    }

    @discardableResult
    func load(_ url: URL) -> Task<Void, Never> {
        if let inFlight = inFlight[url] {
            return inFlight
        }
        guard images[url] == nil else { return Task {} }
        let task = Task {
            if let data = try? await download(url) {
                images[url] = NSImage(data: data)
            }
            inFlight[url] = nil
        }
        inFlight[url] = task
        return task
    }
}

extension AvatarCache {
    nonisolated static let fromGitHub: Download = { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}

#if DEBUG
extension AvatarCache {
    static let preview = AvatarCache(download: { _ in
        let image = NSImage(size: NSSize(width: 60, height: 60), flipped: false) { rect in
            NSColor(red: 0.55, green: 0.42, blue: 0.3, alpha: 1).setFill()
            rect.fill()
            NSColor(white: 0.93, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 18, y: 30, width: 24, height: 24)).fill()
            NSBezierPath(ovalIn: NSRect(x: 6, y: -12, width: 48, height: 38)).fill()
            return true
        }
        return image.tiffRepresentation!
    })
}
#endif
