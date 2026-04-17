import AppKit
import SwiftUI

@MainActor
final class SearchPanelController {
    let panel: SearchPanel
    let viewModel: SearchViewModel
    private let aggregator: TabAggregator
    private var hideObserver: NSObjectProtocol?

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
        Log.panel.notice("show")
        viewModel.query = ""
        viewModel.load(result: TabFetchResult(tabs: [], failures: []))
        centerPanel()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Task { [aggregator, viewModel] in
            let result = await aggregator.fetchAll()
            await MainActor.run {
                viewModel.load(result: result)
                Log.panel.info("UI updated tabs=\(result.tabs.count) failures=\(result.failures.count)")
            }
        }
    }

    func hide() {
        Log.panel.info("hide")
        panel.orderOut(nil)
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
