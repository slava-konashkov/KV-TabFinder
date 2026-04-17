import Foundation

struct TabFetchFailure: Sendable {
    let browser: BrowserKind
    let error: TabProviderError
}

struct TabFetchResult: Sendable {
    let tabs: [Tab]
    let failures: [TabFetchFailure]
}

actor TabAggregator {
    private let providers: [TabProvider]

    init(providers: [TabProvider]) {
        self.providers = providers
    }

    static func defaultProviders() -> [TabProvider] {
        var list: [TabProvider] = [SafariTabProvider()]
        for kind in BrowserKind.allCases where kind.isChromiumFamily {
            list.append(ChromiumTabProvider(browser: kind))
        }
        return list
    }

    func fetchAll(timeoutSeconds: Double = 2.0) async -> TabFetchResult {
        let runningList = providers.filter { $0.isRunning }
        let allList = providers.map { "\($0.browser.rawValue):\($0.isRunning ? "running" : "stopped")" }.joined(separator: ",")
        Log.aggregator.info("fetchAll providers=[\(allList, privacy: .public)] running=\(runningList.count)")

        if runningList.isEmpty {
            Log.aggregator.notice("no running browsers detected — returning empty result")
            return TabFetchResult(tabs: [], failures: [])
        }

        return await withTaskGroup(of: ProviderOutcome.self) { group in
            for p in runningList {
                group.addTask {
                    await Self.fetchWithTimeout(provider: p, seconds: timeoutSeconds)
                }
            }
            var tabs: [Tab] = []
            var failures: [TabFetchFailure] = []
            for await outcome in group {
                switch outcome {
                case .success(let batch):
                    tabs.append(contentsOf: batch)
                case .failure(let f):
                    Log.aggregator.error("provider \(f.browser.rawValue, privacy: .public) failed: \(String(describing: f.error), privacy: .public)")
                    failures.append(f)
                }
            }
            Log.aggregator.info("fetchAll result tabs=\(tabs.count) failures=\(failures.count)")
            return TabFetchResult(tabs: tabs, failures: failures)
        }
    }

    private enum ProviderOutcome: Sendable {
        case success([Tab])
        case failure(TabFetchFailure)
    }

    private static func fetchWithTimeout(provider: TabProvider, seconds: Double) async -> ProviderOutcome {
        let startedAt = Date()
        Log.provider.info("fetch start \(provider.browser.rawValue, privacy: .public)")
        do {
            let tabs = try await withThrowingTaskGroup(of: [Tab].self) { group in
                group.addTask { try await provider.fetchTabs() }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    throw CancellationError()
                }
                let result = try await group.next() ?? []
                group.cancelAll()
                return result
            }
            let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
            Log.provider.info("fetch ok \(provider.browser.rawValue, privacy: .public) tabs=\(tabs.count) \(ms)ms")
            return .success(tabs)
        } catch let e as TabProviderError {
            let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
            Log.provider.error("fetch fail \(provider.browser.rawValue, privacy: .public) \(ms)ms error=\(String(describing: e), privacy: .public)")
            return .failure(TabFetchFailure(browser: provider.browser, error: e))
        } catch {
            let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
            Log.provider.error("fetch fail \(provider.browser.rawValue, privacy: .public) \(ms)ms generic=\(String(describing: error), privacy: .public)")
            return .failure(TabFetchFailure(
                browser: provider.browser,
                error: .scriptFailed(bundleID: provider.browser.bundleID, message: "\(error)")
            ))
        }
    }
}
