import Foundation
import UserNotifications

@MainActor
final class FeedManager: ObservableObject {
    static let shared = FeedManager()

    @Published var feeds: [Feed] = []
    @Published var items: [FeedItem] = []
    @Published var isRefreshing = false
    @Published var lastRefreshed: Date?

    private var seenItemIds: Set<String> = []

    private enum Keys {
        static let feeds = "savedFeeds"
        static let seenIds = "seenItemIds"
    }

    private init() {
        loadFeeds()
        loadSeenIds()
    }

    // MARK: - Persistence

    private func loadFeeds() {
        if let data = UserDefaults.standard.data(forKey: Keys.feeds),
           let decoded = try? JSONDecoder().decode([Feed].self, from: data)
        {
            feeds = decoded
            return
        }
        // Default feeds on first launch
        feeds = [
            Feed(
                title: "NIH Funding Opportunities",
                url: "https://grants.nih.gov/grants/guide/newsfeed/fundingopps.xml"
            ),
            Feed(
                title: "NSF Funding Announcements",
                url: "https://www.nsf.gov/rss/rss_www_funding_pgm_annc_inf.xml"
            )
        ]
        saveFeeds()
    }

    func saveFeeds() {
        if let data = try? JSONEncoder().encode(feeds) {
            UserDefaults.standard.set(data, forKey: Keys.feeds)
        }
    }

    private func loadSeenIds() {
        let stored = UserDefaults.standard.stringArray(forKey: Keys.seenIds) ?? []
        seenItemIds = Set(stored)
    }

    private func saveSeenIds() {
        UserDefaults.standard.set(Array(seenItemIds), forKey: Keys.seenIds)
    }

    // MARK: - Feed Management

    func addFeed(url: String, title: String = "") {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let feed = Feed(title: title.isEmpty ? trimmed : title, url: trimmed)
        feeds.append(feed)
        saveFeeds()
        Task {
            guard let result = await Self.downloadFeed(feed) else { return }
            self.applyFetchResult(result)
            self.saveSeenIds()
        }
    }

    func removeFeed(_ feed: Feed) {
        feeds.removeAll { $0.id == feed.id }
        items.removeAll { $0.feedId == feed.id }
        saveFeeds()
    }

    func toggleEnabled(_ feed: Feed) {
        guard let idx = feeds.firstIndex(where: { $0.id == feed.id }) else { return }
        feeds[idx].isEnabled.toggle()
        saveFeeds()
    }

    // MARK: - Refreshing

    func startRefreshTimer() {
        Task { await fetchAll() }
        // Fire every 30 minutes
        Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.fetchAll() }
        }
    }

    func fetchAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshed = Date()
        }

        // Capture feed list before going async
        let enabledFeeds = feeds.filter { $0.isEnabled }

        // Fetch all feeds concurrently; each returns its results as Sendable value types
        await withTaskGroup(of: FetchResult?.self) { group in
            for feed in enabledFeeds {
                group.addTask {
                    await Self.downloadFeed(feed)
                }
            }
            for await result in group {
                guard let result else { continue }
                self.applyFetchResult(result)
            }
        }

        saveSeenIds()
    }

    // MARK: - Private fetch logic

    // Static + nonisolated so it runs off the main actor for real concurrency
    private static func downloadFeed(_ feed: Feed) async -> FetchResult? {
        guard let url = URL(string: feed.url) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parsed = RSSParser().parse(data: data)
            let dateParser = RSSDateParser()
            let feedItems = parsed.items.map { item -> FeedItem in
                let rawId = item.guid.isEmpty ? item.link : item.guid
                let id = rawId.isEmpty ? "\(feed.id):\(item.title)" : rawId
                return FeedItem(
                    id: id,
                    title: item.title,
                    link: item.link,
                    summary: item.description,
                    pubDate: dateParser.parse(item.pubDate),
                    feedTitle: feed.title,
                    feedId: feed.id
                )
            }
            return FetchResult(feed: feed, parsedTitle: parsed.title, items: feedItems)
        } catch {
            return nil
        }
    }

    private func applyFetchResult(_ result: FetchResult) {
        let feed = result.feed

        // Auto-update feed title if it was just the URL
        if !result.parsedTitle.isEmpty,
           let idx = feeds.firstIndex(where: { $0.id == feed.id }),
           feeds[idx].title == feeds[idx].url
        {
            feeds[idx].title = result.parsedTitle
            saveFeeds()
        }

        let isFirstRun = seenItemIds.isEmpty
        let newItems = result.items.filter { !seenItemIds.contains($0.id) }

        if !isFirstRun && !newItems.isEmpty {
            Task { await self.sendNotification(newItems: newItems, feedTitle: feed.title) }
        }

        for item in result.items {
            seenItemIds.insert(item.id)
        }

        items.removeAll { $0.feedId == feed.id }
        items.append(contentsOf: result.items)
        items.sort { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
    }

    // MARK: - Notifications

    private func sendNotification(newItems: [FeedItem], feedTitle: String) async {
        let content = UNMutableNotificationContent()
        content.title = feedTitle
        if newItems.count == 1 {
            content.body = newItems[0].title
            content.userInfo = ["url": newItems[0].link]
        } else {
            content.body = "\(newItems.count) new announcements"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Supporting types

private struct FetchResult: Sendable {
    let feed: Feed
    let parsedTitle: String
    let items: [FeedItem]
}
