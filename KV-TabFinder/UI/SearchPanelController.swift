import AppKit
import SwiftUI

@MainActor
final class SearchPanelController {
    let panel: SearchPanel
    let viewModel: SearchViewModel
    private let aggregator: TabAggregator
    private var hideObserver: NSObjectProtocol?

    /// Last successful fetch. Shown instantly on the next `show()` so
    /// the UI never waits on AppleScript before appearing.
    private var cache: TabFetchResult?
    /// Guard against running more than one background refresh at a time.
    private var refreshInFlight = false

    init(aggregator: TabAggregator) {
        self.panel = SearchPanel()
        self.viewModel = SearchViewModel()
        self.aggregator = aggregator

        let view = SearchView(
            viewModel: viewModel,
            onActivate: { [weak self] tab in
                self?.activate(tab)
            },
            onCancel: { [weak self] in
                self?.hide()
            }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hosting

        // Wire panel-level key interception to the view model. sendEvent
        // in SearchPanel calls these before the responder chain runs,
        // so arrow-key scrolling in the SwiftUI ScrollView can never win.
        panel.onMoveUp   = { [weak self] in self?.viewModel.moveUp() }
        panel.onMoveDown = { [weak self] in self?.viewModel.moveDown() }
        panel.onSubmit   = { [weak self] in
            guard let tab = self?.viewModel.selected()?.tab else { return }
            self?.activate(tab)
        }
        panel.onEscape   = { [weak self] in self?.hide() }

        // Hide when user clicks elsewhere.
        hideObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    deinit {
        if let obs = hideObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        Log.panel.notice("show cached=\(self.cache?.tabs.count ?? 0)")
        viewModel.query = ""
        // Paint immediately with whatever we already have.
        viewModel.load(result: cache ?? TabFetchResult(tabs: [], failures: []))
        centerPanel()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        startRefresh()
    }

    func hide() {
        Log.panel.info("hide")
        panel.orderOut(nil)
    }

    /// Fire-and-forget fetch that updates the cache and the view model
    /// once it finishes. Call this on app launch to warm the cache, and
    /// again whenever the panel is shown to refresh stale data.
    func startRefresh() {
        guard !refreshInFlight else {
            Log.panel.debug("refresh skipped (already in flight)")
            return
        }
        refreshInFlight = true

        Task { [weak self] in
            guard let self else { return }
            let result = await self.aggregator.fetchAll()
            await MainActor.run {
                self.cache = result
                self.refreshInFlight = false
                // Only push to UI if panel is visible; otherwise cache
                // is used on next show().
                if self.panel.isVisible {
                    self.viewModel.load(result: result)
                }
                Log.panel.info("refresh done tabs=\(result.tabs.count) failures=\(result.failures.count)")
            }
        }
    }

    private func activate(_ tab: Tab) {
        Log.panel.notice("activate \(tab.browser.rawValue, privacy: .public) window=\(tab.windowIndex) tab=\(tab.tabIndex) title=\(tab.title, privacy: .public)")
        hide()
        Task.detached {
            do {
                let provider: TabProvider = tab.browser == .safari
                    ? SafariTabProvider()
                    : ChromiumTabProvider(browser: tab.browser)
                try await provider.activate(tab)
                Log.panel.info("activate ok \(tab.browser.rawValue, privacy: .public)")
            } catch {
                Log.panel.error("activate FAIL \(tab.browser.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)")
                await MainActor.run {
                    AutomationPermission.showErrorAlert(for: error, browser: tab.browser)
                }
            }
        }
    }

    private func centerPanel() {
        let screen = NSScreen.screenContainingMouse() ?? NSScreen.main ?? NSScreen.screens.first!
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2 + frame.height * 0.1 // a bit above center
        )
        panel.setFrameOrigin(origin)
    }
}

private extension NSScreen {
    static func screenContainingMouse() -> NSScreen? {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(loc, $0.frame, false) }
    }
}
