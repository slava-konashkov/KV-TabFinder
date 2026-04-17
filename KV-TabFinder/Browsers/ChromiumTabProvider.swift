import Foundation

/// Works for Chrome, Chromium, Arc, Brave, Edge, Vivaldi, Opera —
/// they all share the Chromium AppleScript vocabulary.
struct ChromiumTabProvider: TabProvider {
    let browser: BrowserKind
    private let runner: AppleScriptRunner

    init(browser: BrowserKind, runner: AppleScriptRunner = .shared) {
        precondition(browser.isChromiumFamily, "Use SafariTabProvider for Safari")
        self.browser = browser
        self.runner = runner
    }

    var isRunning: Bool { browser.isRunning }

    func fetchTabs() async throws -> [Tab] {
        // Bulk query. `title of every tab of win` is the only form
        // Chrome's AppleScript engine accepts for accessing a property
        // across a collection of tabs — the shorter `title of tbs`
        // (where `tbs` is a list of tab refs) errors with -1728.
        // Returns list<{titles_list, urls_list}>, one entry per window.
        let source = """
        tell application id "\(browser.bundleID)"
            set output to {}
            repeat with w from 1 to count of windows
                set win to window w
                if (count of tabs of win) is 0 then
                    set end of output to {{}, {}}
                else
                    set end of output to {title of every tab of win, URL of every tab of win}
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
            set active tab index of window \(tab.windowIndex) to \(tab.tabIndex)
            set index of window \(tab.windowIndex) to 1
        end tell
        """
        _ = try await runner.run(source: source, bundleID: browser.bundleID)
    }

    private func parse(descriptor: NSAppleEventDescriptor) throws -> [Tab] {
        var rows: [(w: Int, t: Int, title: String, url: String)] = []
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
                rows.append((w, t, title, url))
            }
        }

        let profileMap: [Int: String] = browser == .chrome
            ? ChromeProfileRegistry.windowProfileMap(windowCount: windowCount)
            : [:]

        return rows.map { r in
            Tab(
                browser: browser,
                windowIndex: r.w,
                tabIndex: r.t,
                title: r.title,
                url: r.url,
                accountHint: profileMap[r.w]
            )
        }
    }
}
