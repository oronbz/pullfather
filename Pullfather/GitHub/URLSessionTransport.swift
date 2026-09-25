import Foundation

nonisolated struct URLSessionTransport: GitHubTransport {
    static let endpoint = URL(string: "https://api.github.com/graphql")!

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .dnsLookupFailed, .timedOut, .internationalRoamingOff, .dataNotAllowed,
    ]

    let token: String
    var session: URLSession = .shared

    func send(_ query: String, variables: [String: GraphQLVariable]) async throws(GitHubFailure) -> Data {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Pullfather", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONEncoder().encode(Body(query: query, variables: variables))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw .offline
        } catch {
            throw .other(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw .other("GitHub sent an unexpected response.") }
        let errors = GraphQLErrors(data)
        switch http.statusCode {
        case 200..<300 where errors.isRateLimited:
            throw .rateLimited(resetsAt: Self.resetDate(http))
        case 200..<300 where !errors.hasData:
            throw .other(errors.firstMessage ?? "GitHub sent an unexpected response.")
        case 200..<300:
            return data
        case 401:
            throw .unauthorised
        case 403 where Self.isRateLimited(http), 429:
            throw .rateLimited(resetsAt: Self.resetDate(http))
        default:
            throw .other(errors.firstMessage ?? "GitHub returned HTTP \(http.statusCode).")
        }
    }

    private static func isRateLimited(_ response: HTTPURLResponse) -> Bool {
        response.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0"
            || response.value(forHTTPHeaderField: "retry-after") != nil
    }

    private static func resetDate(_ response: HTTPURLResponse) -> Date? {
        if let reset = response.value(forHTTPHeaderField: "x-ratelimit-reset").flatMap(TimeInterval.init) {
            return Date(timeIntervalSince1970: reset)
        }
        if let retryAfter = response.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init) {
            return Date(timeIntervalSinceNow: retryAfter)
        }
        return nil
    }

    private struct Body: Encodable {
        let query: String
        let variables: [String: GraphQLVariable]
    }
}

private nonisolated struct GraphQLErrors {
    let hasData: Bool
    let isRateLimited: Bool
    let firstMessage: String?

    init(_ body: Data) {
        let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let errors = object?["errors"] as? [[String: Any]] ?? []
        hasData = object?["data"].map { !($0 is NSNull) } ?? false
        isRateLimited = errors.contains { $0["type"] as? String == "RATE_LIMITED" }
        firstMessage = errors.first?["message"] as? String
    }
}
