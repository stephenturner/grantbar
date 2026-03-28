import AppKit
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var manageFeedsWindow: NSWindow?

    // Accessed from @MainActor contexts; creation happens on main thread in applicationDidFinishLaunching
    let feedManager = FeedManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no dock icon
        NSApp.setActivationPolicy(.accessory)

        // Request notification permission
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        setupStatusItem()
        setupPopover()

        Task { @MainActor in
            feedManager.startRefreshTimer()
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "newspaper", accessibilityDescription: "GrantBar")
        button.action = #selector(togglePopover)
        button.target = self
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient

        let contentView = ContentView(onManageFeeds: { [weak self] in
            self?.openManageFeedsWindow()
        })
        .environmentObject(feedManager)

        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        // Refresh if stale (> 5 minutes since last fetch)
        let staleThreshold = Date().addingTimeInterval(-5 * 60)
        if feedManager.lastRefreshed == nil || feedManager.lastRefreshed! < staleThreshold {
            Task { @MainActor in await feedManager.fetchAll() }
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Manage Feeds Window

    func openManageFeedsWindow() {
        popover.performClose(nil)

        if manageFeedsWindow == nil {
            let view = ManageFeedsView().environmentObject(feedManager)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "Manage Feeds"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 460, height: 380))
            window.center()
            manageFeedsWindow = window

            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.manageFeedsWindow = nil
                }
            }
        }

        manageFeedsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // If the notification carries a specific item URL, open it directly
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString)
        {
            NSWorkspace.shared.open(url)
        } else {
            DispatchQueue.main.async { self.togglePopover() }
        }
        completionHandler()
    }

    // Show notifications even while the app is active (it's always "active" as a menu bar app)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
