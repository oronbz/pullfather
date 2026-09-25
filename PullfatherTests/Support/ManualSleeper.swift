import Foundation

final class ManualSleeper {
    private(set) var requests: [Duration] = []
    private var pending: CheckedContinuation<Void, any Error>?

    func sleep(for duration: Duration) async throws {
        requests.append(duration)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { pending = $0 }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
    }

    func waitUntilAsleep(times count: Int) async {
        while requests.count < count || pending == nil {
            await Task.yield()
        }
    }

    func wake() {
        pending?.resume()
        pending = nil
    }

    private func cancel() {
        pending?.resume(throwing: CancellationError())
        pending = nil
    }
}
