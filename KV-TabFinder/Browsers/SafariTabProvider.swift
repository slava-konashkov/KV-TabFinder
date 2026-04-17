import Foundation

/// Safari uses `name` instead of `title` on tabs, and activation goes through
/// `set current tab of window`.
struct SafariTabProvider: TabProvider {
    let browser: BrowserKind = .safari
    private let runner: AppleScriptRunner

    init(runner: AppleScriptRunner = .shared) {
        self.runner = runner
    }

    var isRunning: Bool { browser.isRunning }

    func fetchTabs() async throws -> [Tab] {
        // Bulk query. See ChromiumTabProvider for why we use the
        // `… of every tab of win` form instead of `… of tabs of win`.
        // Safari uses `name` on tabs (not `title`).
        let source = """
        tell application id "\(browser.bundleID)"
            set output to {}
            repeat with w from 1 to count of windows
                set win to window w
                if (count of tabs of win) is 0 then
                    set end of output to {{}, {}}
                else
                    set end of output to {name of every tab of win, URL of every tab of win}
                end if
            end repeat
            return output
        end tell
        """
        let descriptor = try await runner.run(source: source, bundleID: browser.bundleID)
        return try parse(descriptor: descriptor)
    }

    func activate(_ tab: Tab) async throws {
        let source = """
        tell application id "\(browser.bundleID)"
            activate
            set current tab of window \(tab.windowIndex) to tab \(tab.tabIndex) of window \(tab.windowIndex)
            set index of window \(tab.windowIndex) to 1
        end tell
        """
        _ = try await runner.run(source: source, bundleID: browser.bundleID)
    }

    private func parse(descriptor: NSAppleEventDescriptor) throws -> [Tab] {
        var tabs: [Tab] = []
        let windowCount = descriptor.numberOfItems
        guard windowCount > 0 else { return [] }
        for w in 1...windowCount {
            guard
                let entry = descriptor.atIndex(w),
                entry.numberOfItems >= 2,
                let titles = entry.atIndex(1),
                let urls = entry.atIndex(2)
            else { continue }
            let tabCount = min(titles.numberOfItems, urls.numberOfItems)
            guard tabCount > 0 else { continue }
            for t in 1...tabCount {
                let title = titles.atIndex(t)?.stringValue ?? ""
                let url = urls.atIndex(t)?.stringValue ?? ""
                tabs.append(Tab(
                    browser: browser,
                    windowIndex: w,
                    tabIndex: t,
                    title: title,
                    url: url
                ))
            }
        }
        return tabs
    }
}
