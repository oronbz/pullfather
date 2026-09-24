import Foundation

nonisolated enum SyncFixtures {
    static let recordedAt = ISO8601DateFormatter().date(from: "2026-09-24T09:41:00Z")!

    static let recorded = Data(#"""
    {
      "data": {
        "viewer": { "login": "tomhagen" },
        "business": {
          "nodes": [
            {
              "id": "PR_kwDOAAAAAc5aaaaa",
              "number": 412,
              "title": "Fix race in token refresh",
              "url": "https://github.com/corleone/olive-oil/pull/412",
              "createdAt": "2026-09-21T09:41:00Z",
              "repository": { "nameWithOwner": "corleone/olive-oil" },
              "author": { "login": "mike-corleone" },
              "timelineItems": {
                "nodes": [
                  {
                    "createdAt": "2026-09-21T09:41:01Z",
                    "requestedReviewer": { "__typename": "User", "login": "fredo" }
                  },
                  {
                    "createdAt": "2026-09-24T07:41:00Z",
                    "requestedReviewer": { "__typename": "User", "login": "tomhagen" }
                  }
                ]
              }
            },
            {
              "id": "PR_kwDOAAAAAc5bbbbb",
              "number": 1088,
              "title": "Migrate settings screen to SwiftUI",
              "url": "https://github.com/corleone/casino/pull/1088",
              "createdAt": "2026-09-19T09:41:00Z",
              "repository": { "nameWithOwner": "corleone/casino" },
              "author": { "login": "sonny" },
              "timelineItems": {
                "nodes": [
                  {
                    "createdAt": "2026-09-24T04:41:00Z",
                    "requestedReviewer": { "__typename": "Team", "slug": "consiglieri" }
                  }
                ]
              }
            },
            {
              "id": "PR_kwDOAAAAAc5ccccc",
              "number": 1091,
              "title": "Bump fastlane to latest",
              "url": "https://github.com/corleone/casino/pull/1091",
              "createdAt": "2026-09-23T09:41:00Z",
              "repository": { "nameWithOwner": "corleone/casino" },
              "author": { "login": "luca-brasi" },
              "timelineItems": { "nodes": [] }
            }
          ]
        }
      }
    }
    """#.utf8)
}

nonisolated struct SyncFixture {
    enum Request {
        case user(String, at: Date)
        case team(String, at: Date)
    }

    struct PullRequest {
        var number: Int
        var title = "Fix race in token refresh"
        var repository = "corleone/olive-oil"
        var author = "sonny"
        var createdAt: Date
        var requests: [Request] = []
    }

    var viewer = "tomhagen"
    var business: [PullRequest] = []

    var data: Data {
        let formatter = ISO8601DateFormatter()
        let nodes = business.map { pullRequest -> [String: Any] in
            [
                "id": "PR_\(pullRequest.number)",
                "number": pullRequest.number,
                "title": pullRequest.title,
                "url": "https://github.com/\(pullRequest.repository)/pull/\(pullRequest.number)",
                "createdAt": formatter.string(from: pullRequest.createdAt),
                "repository": ["nameWithOwner": pullRequest.repository],
                "author": ["login": pullRequest.author],
                "timelineItems": ["nodes": pullRequest.requests.map { request -> [String: Any] in
                    switch request {
                    case .user(let login, let date):
                        ["createdAt": formatter.string(from: date), "requestedReviewer": ["__typename": "User", "login": login]]
                    case .team(let slug, let date):
                        ["createdAt": formatter.string(from: date), "requestedReviewer": ["__typename": "Team", "slug": slug]]
                    }
                }],
            ]
        }
        let response: [String: Any] = ["data": ["viewer": ["login": viewer], "business": ["nodes": nodes]]]
        return try! JSONSerialization.data(withJSONObject: response)
    }
}
