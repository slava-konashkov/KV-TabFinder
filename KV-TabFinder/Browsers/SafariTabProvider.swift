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
        let source = """
        tell application id "\(browser.bundleID)"
            set out to {}
            set wcount to count of windows
            repeat with w from 1 to wcount
                set win to window w
                set tcount to count of tabs of win
                repeat with t from 1 to tcount
                    set theTab to tab t of win
                    set end of out to {w, t, name of theTab, URL of theTab}
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
            set current tab of window \(tab.windowIndex) to tab \(tab.tabIndex) of window \(tab.windowIndex)
            set index of window \(tab.windowIndex) to 1
        end tell
        """
        _ = try await runner.run(source: source, bundleID: browser.bundleID)
    }

    private func parse(descriptor: NSAppleEventDescriptor) throws -> [Tab] {
        var tabs: [Tab] = []
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
            tabs.append(Tab(browser: browser,
                            windowIndex: Int(w),
                            tabIndex: Int(t),
                            title: title,
                            url: url))
        }
        return tabs
    }
}
