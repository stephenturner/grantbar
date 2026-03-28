import SwiftUI

@main
struct GrantBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — menu bar only. Settings scene suppresses the default "New Window" behavior.
        Settings { EmptyView() }
    }
}
