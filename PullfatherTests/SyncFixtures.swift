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
              "updatedAt": "2026-09-24T07:41:00Z",
              "isDraft": false,
              "reviewDecision": "REVIEW_REQUIRED",
              "repository": { "nameWithOwner": "corleone/olive-oil" },
              "author": { "login": "mike-corleone", "avatarUrl": "https://avatars.githubusercontent.com/u/1001?s=60&v=4" },
              "commits": { "nodes": [{ "commit": { "statusCheckRollup": { "state": "SUCCESS" } } }] },
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
              "updatedAt": "2026-09-24T04:41:00Z",
              "isDraft": false,
              "reviewDecision": null,
              "repository": { "nameWithOwner": "corleone/casino" },
              "author": { "login": "sonny", "avatarUrl": "https://avatars.githubusercontent.com/u/1002?s=60&v=4" },
              "commits": { "nodes": [{ "commit": { "statusCheckRollup": { "state": "PENDING" } } }] },
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
              "updatedAt": "2026-09-23T09:41:00Z",
              "isDraft": false,
              "reviewDecision": "REVIEW_REQUIRED",
              "repository": { "nameWithOwner": "corleone/casino" },
              "author": { "login": "luca-brasi", "avatarUrl": "https://avatars.githubusercontent.com/u/1003?s=60&v=4" },
              "commits": { "nodes": [{ "commit": { "statusCheckRollup": { "state": "FAILURE" } } }] },
              "timelineItems": { "nodes": [] }
            }
          ]
        },
        "family": {
          "nodes": [
            {
              "id": "PR_kwDOAAAAAc5ddddd",
              "number": 1079,
              "title": "Add offline banner",
              "url": "https://github.com/corleone/casino/pull/1079",
              "createdAt": "2026-09-14T09:41:00Z",
              "updatedAt": "2026-09-21T09:41:00Z",
              "isDraft": false,
              "reviewDecision": "APPROVED",
              "repository": { "nameWithOwner": "corleone/casino" },
              "author": { "login": "tomhagen" },
              "commits": { "nodes": [{ "commit": { "statusCheckRollup": { "state": "SUCCESS" } } }] }
            },
            {
              "id": "PR_kwDOAAAAAc5eeeee",
              "number": 1084,
              "title": "Refactor push routing",
              "url": "https://github.com/corleone/casino/pull/1084",
              "createdAt": "2026-09-18T09:41:00Z",
              "updatedAt": "2026-09-23T09:41:00Z",
              "isDraft": false,
              "reviewDecision": "CHANGES_REQUESTED",
              "repository": { "nameWithOwner": "corleone/casino" },
              "author": { "login": "tomhagen" },
              "commits": { "nodes": [{ "commit": { "statusCheckRollup": { "state": "FAILURE" } } }] }
            },
            {
              "id": "PR_kwDOAAAAAc5fffff",
              "number": 97,
              "title": "Sketch the olive oil import pipeline",
              "url": "https://github.com/corleone/olive-oil/pull/97",
              "createdAt": "2026-09-24T08:41:00Z",
              "updatedAt": "2026-09-24T09:11:00Z",
              "isDraft": true,
              "reviewDecision": null,
              "repository": { "nameWithOwner": "corleone/olive-oil" },
              "author": { "login": "tomhagen" },
              "commits": { "nodes": [{ "commit": { "statusCheckRollup": null } }] }
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
        var author: String? = "sonny"
        var createdAt: Date
        var updatedAt: Date?
        var isDraft = false
        var reviewDecision: String?
        var rollupState: String?
        var requests: [Request] = []
    }

    var viewer = "tomhagen"
    var business: [PullRequest] = []
    var family: [PullRequest] = []

    var data: Data {
        let response: [String: Any] = ["data": [
            "viewer": ["login": viewer],
            "business": ["nodes": Self.nodes(business)],
            "family": ["nodes": Self.nodes(family)],
        ]]
        return try! JSONSerialization.data(withJSONObject: response)
    }

    private static func nodes(_ pullRequests: [PullRequest]) -> [[String: Any]] {
        let formatter = ISO8601DateFormatter()
        return pullRequests.map { pullRequest -> [String: Any] in
            [
                "id": "PR_\(pullRequest.number)",
                "number": pullRequest.number,
                "title": pullRequest.title,
                "url": "https://github.com/\(pullRequest.repository)/pull/\(pullRequest.number)",
                "createdAt": formatter.string(from: pullRequest.createdAt),
                "updatedAt": formatter.string(from: pullRequest.updatedAt ?? pullRequest.createdAt),
                "isDraft": pullRequest.isDraft,
                "reviewDecision": pullRequest.reviewDecision ?? NSNull(),
                "repository": ["nameWithOwner": pullRequest.repository],
                "author": pullRequest.author.map { ["login": $0, "avatarUrl": "https://avatars.githubusercontent.com/\($0)?s=60"] } ?? NSNull(),
                "commits": ["nodes": [["commit": ["statusCheckRollup": pullRequest.rollupState.map { ["state": $0] } ?? NSNull()]]]],
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
    }
}
