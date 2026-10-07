import Foundation

nonisolated struct ReleaseFixture: Encodable {
    let tag: String
    var draft = false
    var prerelease = false

    static func data(_ releases: [ReleaseFixture]) -> Data {
        try! JSONEncoder().encode(releases)
    }

    enum CodingKeys: String, CodingKey {
        case tag = "tag_name"
        case url = "html_url"
        case draft
        case prerelease
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tag, forKey: .tag)
        try container.encode("https://github.com/oronbz/pullfather/releases/tag/\(tag)", forKey: .url)
        try container.encode(draft, forKey: .draft)
        try container.encode(prerelease, forKey: .prerelease)
    }
}
