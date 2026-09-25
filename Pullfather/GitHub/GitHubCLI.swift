import Foundation

nonisolated enum GitHubCLI {
    private static let knownDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]

    @concurrent static func token() async -> String? {
        guard let executable = locate() else { return nil }
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["auth", "token"]
        process.environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("DYLD_") }
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    private static func locate() -> URL? {
        let path = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        return (knownDirectories + path)
            .lazy
            .map { URL(filePath: $0).appending(path: "gh") }
            .first { FileManager.default.isExecutableFile(atPath: $0.path(percentEncoded: false)) }
    }
}
