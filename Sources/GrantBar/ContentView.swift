import SwiftUI

struct ContentView: View {
    @EnvironmentObject var feedManager: FeedManager
    let onManageFeeds: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            itemList
            Divider()
            footer
        }
        .frame(width: 420, height: 520)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 8) {
            Text("GrantBar")
                .font(.headline)
            if feedManager.isRefreshing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            }
            Spacer()
            if let date = feedManager.lastRefreshed {
                Text(date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await feedManager.fetchAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .disabled(feedManager.isRefreshing)
            .help("Refresh now")

            Button {
                onManageFeeds()
            } label: {
                Image(systemName: "gear")
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .help("Manage feeds")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var itemList: some View {
        Group {
            if feedManager.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(feedManager.items.prefix(60)) { item in
                            ItemRow(item: item)
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if feedManager.isRefreshing {
                ProgressView("Loading feeds...")
            } else if feedManager.feeds.isEmpty {
                Text("No feeds configured.")
                    .foregroundStyle(.secondary)
                Button("Add a feed") { onManageFeeds() }
                    .buttonStyle(.link)
            } else {
                Text("No items found.")
                    .foregroundStyle(.secondary)
                Button("Refresh") {
                    Task { await feedManager.fetchAll() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Item Row

struct ItemRow: View {
    let item: FeedItem
    @State private var isHovered = false

    var body: some View {
        Button {
            if let url = URL(string: item.link) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)

                HStack {
                    Text(item.feedTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let date = item.pubDate {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.accentColor.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
