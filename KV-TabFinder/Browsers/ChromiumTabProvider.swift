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
        let source = """
        tell application id "\(browser.bundleID)"
            set out to {}
            set wcount to count of windows
            repeat with w from 1 to wcount
                set win to window w
                set tcount to count of tabs of win
                repeat with t from 1 to tcount
                    set theTab to tab t of win
                    set end of out to {w, t, title of theTab, URL of theTab}
                end repeat
            end repeat
            return out
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
        let count = descriptor.numberOfItems
        guard count > 0 else { return [] }
        for i in 1...count {
            guard
                let row = descriptor.atIndex(i),
                row.numberOfItems == 4,
                let w = row.atIndex(1)?.int32Value,
                let t = row.atIndex(2)?.int32Value
            else { continue }
            let title = row.atIndex(3)?.stringValue ?? ""
            let url = row.atIndex(4)?.stringValue ?? ""
            rows.append((Int(w), Int(t), title, url))
        }

        let windowCount = rows.map(\.w).max() ?? 0
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
