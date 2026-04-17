import SwiftUI

@main
struct KVTabFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // SwiftUI's `App` type demands at least one Scene. We use an
        // empty `Settings` as a placeholder — the real Settings window
        // is managed imperatively by AppDelegate because
        // `showSettingsWindow:` does not work for LSUIElement apps.
        Settings { EmptyView() }
    }
}
