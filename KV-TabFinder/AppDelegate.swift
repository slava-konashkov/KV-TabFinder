import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    private let hotkey = GlobalHotkey()
    private let aggregator = TabAggregator(providers: TabAggregator.defaultProviders())
    private lazy var panelController = SearchPanelController(aggregator: aggregator)

    private var statusItem: NSStatusItem!
    private var menuBarMenu: MenuBarMenu!

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !enforceSingleInstance() else { return }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier ?? "?"
        let path = Bundle.main.bundlePath
        Log.app.notice("launch bundleID=\(bundleID, privacy: .public) path=\(path, privacy: .public)")
        setupMenuBar()
        registerHotkey(combo: settings.hotkey)
        // Warm the cache so the first hotkey press paints instantly.
        panelController.startRefresh()
    }

    /// Returns true if we terminated because another copy is already running.
    /// Must be called before any user-visible state is created.
    private func enforceSingleInstance() -> Bool {
        guard let myBundleID = Bundle.main.bundleIdentifier else { return false }
        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: myBundleID)
            .filter { $0.processIdentifier != myPID }

        guard let existing = others.first else { return false }

        Log.app.notice("another instance is already running (pid=\(existing.processIdentifier)) — quitting this copy")
        existing.activate(options: [.activateAllWindows])
        NSApp.terminate(nil)
        return true
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "KV-TabFinder")
            button.image?.isTemplate = true
        }

        let menu = MenuBarMenu()
        menu.onSearch = { [weak self] in self?.panelController.show() }
        menu.onPreferences = { [weak self] in self?.openSettings() }
        menu.onQuit = { NSApp.terminate(nil) }
        statusItem.menu = menu.menu
        menuBarMenu = menu
    }

    // MARK: - Hotkey

    func registerHotkey(combo: HotkeyCombo) {
        let ok = hotkey.register(combo: combo) { [weak self] in
            Log.hotkey.notice("hotkey pressed")
            self?.panelController.toggle()
        }
        if ok {
            Log.hotkey.notice("registered hotkey \(combo.displayString, privacy: .public)")
        } else {
            Log.hotkey.error("FAILED to register hotkey \(combo.displayString, privacy: .public) — likely taken by another app")
        }
    }

    // MARK: - Settings

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
