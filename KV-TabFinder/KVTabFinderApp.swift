import SwiftUI

@main
struct KVTabFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        SettingsScene(
            store: delegate.settings,
            onHotkeyChange: { combo in
                delegate.registerHotkey(combo: combo)
            }
        )
    }
}
