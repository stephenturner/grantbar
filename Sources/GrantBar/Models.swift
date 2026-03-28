import Foundation

struct Feed: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var url: String
    var isEnabled: Bool

    init(id: UUID = UUID(), title: String, url: String, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.url = url
        self.isEnabled = isEnabled
    }
}

struct FeedItem: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var link: String
    var summary: String
    var pubDate: Date?
    var feedTitle: String
    var feedId: UUID

    static func == (lhs: FeedItem, rhs: FeedItem) -> Bool {
        lhs.id == rhs.id
    }
}
