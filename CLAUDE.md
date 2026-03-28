# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Building and running

```bash
# Debug build (fast, for development)
swift build

# Production app bundle (required for notifications)
bash build.sh

# Run the bundled app
open GrantBar.app

# Install to Applications
cp -r GrantBar.app /Applications/
```

The app requires a proper `.app` bundle (produced by `build.sh`) for `UNUserNotificationCenter` to work. Running the raw binary directly skips notification permission.

```bash
# Build a versioned DMG for distribution
bash package.sh              # version read from VERSION file
```

## Icon

`make_icon.swift` generates `AppIcon.iconset/` (all 10 required PNG sizes) from the `newspaper.fill` SF Symbol — white glyph on a black rounded-rect background. `build.sh` compiles and runs it via `swiftc -framework AppKit`, then calls `iconutil` to produce `AppIcon.icns`, which gets copied into the bundle's `Contents/Resources/`. The `.icns` and iconset directory are build artifacts and not committed to git.

The `pointSize` in the symbol configuration is set to `~75% of the drawn rect width` so AppKit rasterises the glyph natively at each size rather than stretching a small default render. To change the icon appearance, edit `make_icon.swift` and re-run `bash build.sh`.

## Architecture

A Swift Package Manager macOS menu bar app. No Xcode project file — `Package.swift` defines a single executable target at `Sources/GrantBar/`.

**Entry point**: `GrantBarApp.swift` uses SwiftUI's `@main App` protocol with `@NSApplicationDelegateAdaptor(AppDelegate.self)`. No `main.swift`. The `Settings { EmptyView() }` scene suppresses default window behavior.

**Actor model**: `FeedManager` is `@MainActor` so all `@Published` mutations are automatically on the main thread. `AppDelegate` is also `@MainActor` (required to access `FeedManager` without Tasks). Network fetches (`downloadFeed`) are `static` so they run off the main actor while the concurrent `withTaskGroup` collects `Sendable` `FetchResult` values back onto the main actor.

**Key files**:
- `AppDelegate.swift` — status bar item (`NSStatusItem`), `NSPopover` hosting `ContentView`, separate `NSWindow` for `ManageFeedsView`, `UNUserNotificationCenter` delegate
- `FeedManager.swift` — `@MainActor ObservableObject`; owns all feed state, UserDefaults persistence, refresh timer (30 min), notification dispatch
- `RSSParser.swift` — `XMLParserDelegate`-based RSS 2.0 / Atom parser; `@unchecked Sendable` because each instance is single-use per fetch
- `ContentView.swift` — popover UI (420×520); calls `onManageFeeds` closure to open the settings window
- `ManageFeedsView.swift` — add/remove/toggle feeds; hosted in a standalone `NSWindow`, not a sheet

**Persistence**: All state is in `UserDefaults`. Key `savedFeeds` stores `[Feed]` as JSON. Key `seenItemIds` stores `[String]` of item IDs used to detect new arrivals and suppress first-run notification spam.

**Notifications**: First fetch is always silent (populates `seenItemIds`). Subsequent fetches send a `UNUserNotificationRequest` for any item ID not already in `seenItemIds`. Single-item notifications include the item URL in `userInfo["url"]` so tapping opens the link directly.

## Default feeds (pre-loaded on first launch)

- NIH Funding Opportunities: `https://grants.nih.gov/grants/guide/newsfeed/fundingopps.xml`
- NSF Funding Announcements: `https://www.nsf.gov/rss/rss_www_funding_pgm_annc_inf.xml`
