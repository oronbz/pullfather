import Darwin
import Foundation

struct Homebrew {
    var download: () async throws -> Void
    var upgradeAfterQuit: () throws -> Void
}

nonisolated enum HomebrewFailure: Error, Equatable {
    case notInstalled
    case failed(String)
}

extension Homebrew {
    static var live: Homebrew {
        Homebrew(download: { try await HomebrewCLI.download() }, upgradeAfterQuit: { try HomebrewCLI.upgradeAfterQuit() })
    }
}

private nonisolated enum HomebrewCLI {
    // The full name lets brew load the cask even when it can't find the user's tap trust list, as when XDG_CONFIG_HOME is only set in their shell.
    private static let cask = "oronbz/tap/pullfather"
    private static let knownDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]
    private static let log = URL.libraryDirectory.appending(path: "Logs/Pullfather/upgrade.log")

    @concurrent static func download() async throws {
        let brew = try locate()
        try run(brew, ["update"])
        try run(brew, ["fetch", "--cask", cask])
    }

    static func upgradeAfterQuit() throws {
        let brew = try locate()
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Upgrading only once this process has exited means brew never has to quit the app, which would need Automation access.
        let script = #"while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; "$2" upgrade --cask "$3" >>"$4" 2>&1; open "$5""#
        try spawnDetached("/bin/sh", ["-c", script, "sh", String(getpid()), brew.path(percentEncoded: false), cask, log.path(percentEncoded: false), Bundle.main.bundleURL.path(percentEncoded: false)])
    }

    private static var environment: [String: String] {
        var environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("DYLD_") }
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        return environment
    }

    private static func locate() throws -> URL {
        let path = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        let brew = (knownDirectories + path)
            .lazy
            .map { URL(filePath: $0).appending(path: "brew") }
            .first { FileManager.default.isExecutableFile(atPath: $0.path(percentEncoded: false)) }
        guard let brew else { throw HomebrewFailure.notInstalled }
        return brew
    }

    private static func run(_ brew: URL, _ arguments: [String]) throws {
        let process = Process()
        let errors = Pipe()
        process.executableURL = brew
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        let data = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw HomebrewFailure.failed(reason(in: String(decoding: data, as: UTF8.self)))
        }
    }

    private static func reason(in errors: String) -> String {
        let lines = errors.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let error = lines.last(where: { $0.hasPrefix("Error: ") }) {
            return String(error.dropFirst("Error: ".count))
        }
        return lines.last ?? "Homebrew failed."
    }

    /// Starts the process in its own session, so it outlives the app instead of going down with its process group.
    private static func spawnDetached(_ path: String, _ arguments: [String]) throws {
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT))

        var files: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&files)
        defer { posix_spawn_file_actions_destroy(&files) }
        for descriptor: Int32 in 0...2 {
            posix_spawn_file_actions_addopen(&files, descriptor, "/dev/null", descriptor == 0 ? O_RDONLY : O_WRONLY, 0)
        }

        let argv = ([path] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { (argv + envp).forEach { free($0) } }

        var pid = pid_t()
        let status = posix_spawn(&pid, path, &files, &attributes, argv, envp)
        guard status == 0 else { throw POSIXError(POSIXErrorCode(rawValue: status) ?? .EIO) }
    }
}
