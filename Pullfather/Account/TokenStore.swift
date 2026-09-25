import Foundation

nonisolated struct TokenStore: Sendable {
    static let standard = TokenStore(directory: .applicationSupportDirectory.appending(path: "Pullfather"))

    let directory: URL

    private var fileURL: URL { directory.appending(path: "token") }

    func load() -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    func save(_ token: String) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path(percentEncoded: false))

        let staging = directory.appending(path: ".token-\(UUID().uuidString)").path(percentEncoded: false)
        let descriptor = open(staging, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        do {
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            try handle.write(contentsOf: Data(token.utf8))
            try handle.close()
            guard rename(staging, fileURL.path(percentEncoded: false)) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        } catch {
            unlink(staging)
            throw error
        }
    }

    func remove() throws {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
        }
    }

    static func isFineGrained(_ token: String) -> Bool {
        token.hasPrefix("github_pat_")
    }
}
