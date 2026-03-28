import SwiftUI

struct ManageFeedsView: View {
    @EnvironmentObject var feedManager: FeedManager
    @State private var newURL = ""
    @State private var newTitle = ""
    @State private var urlError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Manage Feeds")
                .font(.headline)
                .padding()

            Divider()

            if feedManager.feeds.isEmpty {
                Text("No feeds added yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List {
                    ForEach(feedManager.feeds) { feed in
                        FeedRow(feed: feed)
                    }
                    .onDelete { indices in
                        for idx in indices {
                            feedManager.removeFeed(feedManager.feeds[idx])
                        }
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 120)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Add Feed")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Feed URL (required)", text: $newURL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addFeed() }

                TextField("Display name (optional)", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addFeed() }

                if let error = urlError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button("Add Feed") { addFeed() }
                        .disabled(newURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 460, height: 380)
    }

    private func addFeed() {
        var urlString = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return }

        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        guard URL(string: urlString) != nil else {
            urlError = "That doesn't look like a valid URL."
            return
        }

        feedManager.addFeed(url: urlString, title: newTitle.trimmingCharacters(in: .whitespacesAndNewlines))
        newURL = ""
        newTitle = ""
        urlError = nil
    }
}

private struct FeedRow: View {
    @EnvironmentObject var feedManager: FeedManager
    let feed: Feed

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { feed.isEnabled },
                set: { _ in feedManager.toggleEnabled(feed) }
            ))
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .font(.system(size: 13))
                Text(feed.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 2)
    }
}
