import AppKit
import Synchronization
import Testing
@testable import Pullfather

struct AvatarCacheTests {
    let avatar = URL(string: "https://avatars.githubusercontent.com/u/1001?s=60&v=4")!
    let server = FakeAvatarServer()

    @Test func anAvatarDownloadsOnceAndThenComesFromMemory() async {
        let cache = AvatarCache(download: server.download)

        await cache.load(avatar).value
        await cache.load(avatar).value

        #expect(cache.image(for: avatar)?.size == NSSize(width: 60, height: 60))
        #expect(server.requests == [avatar])
    }

    @Test func rowsAskingForTheSameAvatarAtOnceShareOneDownload() async {
        let cache = AvatarCache(download: server.download)

        let first = cache.load(avatar)
        let second = cache.load(avatar)
        await first.value
        await second.value

        #expect(cache.image(for: avatar) != nil)
        #expect(server.requests == [avatar])
    }

    @Test(arguments: [FakeAvatarServer.Response.failure, .garbage])
    func anAvatarThatFailsToLoadHasNoImageAndIsTriedAgainNextTime(response: FakeAvatarServer.Response) async {
        server.respond(with: [response, .image])
        let cache = AvatarCache(download: server.download)

        await cache.load(avatar).value
        #expect(cache.image(for: avatar) == nil)

        await cache.load(avatar).value
        #expect(cache.image(for: avatar) != nil)
        #expect(server.requests == [avatar, avatar])
    }
}

nonisolated final class FakeAvatarServer: Sendable {
    enum Response: Sendable {
        case image
        case garbage
        case failure
    }

    private let log = Mutex<[URL]>([])
    private let responses = Mutex<[Response]>([])

    var requests: [URL] {
        log.withLock { $0 }
    }

    func respond(with responses: [Response]) {
        self.responses.withLock { $0 = responses }
    }

    func download(_ url: URL) async throws -> Data {
        log.withLock { $0.append(url) }
        let response = responses.withLock { $0.isEmpty ? .image : $0.removeFirst() }
        switch response {
        case .image: return Self.png
        case .garbage: return Data("<html>404</html>".utf8)
        case .failure: throw URLError(.notConnectedToInternet)
        }
    }

    static let png: Data = {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 60, pixelsHigh: 60, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        return bitmap.representation(using: .png, properties: [:])!
    }()
}
