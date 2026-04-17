import XCTest
@testable import KVTabFinder

final class TabAggregatorTests: XCTestCase {
    func testAggregatesFromAllRunningProviders() async {
        let p1 = FakeProvider(
            browser: .safari,
            running: true,
            outcome: .success([.fixture(title: "Safari A"), .fixture(title: "Safari B")])
        )
        let p2 = FakeProvider(
            browser: .chrome,
            running: true,
            outcome: .success([.fixture(title: "Chrome A")])
        )
        let aggregator = TabAggregator(providers: [p1, p2])

        let result = await aggregator.fetchAll()

        XCTAssertEqual(result.tabs.count, 3)
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testSkipsProvidersThatAreNotRunning() async {
        let running = FakeProvider(
            browser: .safari,
            running: true,
            outcome: .success([.fixture(title: "A")])
        )
        let notRunning = FakeProvider(
            browser: .chrome,
            running: false,
            outcome: .success([.fixture(title: "B")])
        )
        let aggregator = TabAggregator(providers: [running, notRunning])

        let result = await aggregator.fetchAll()

        XCTAssertEqual(result.tabs.count, 1)
        XCTAssertEqual(result.tabs.first?.title, "A")
    }

    func testErrorInOneProviderDoesNotDropOthers() async {
        let good = FakeProvider(
            browser: .safari,
            running: true,
            outcome: .success([.fixture(title: "Good")])
        )
        let bad = FakeProvider(
            browser: .chrome,
            running: true,
            outcome: .failure(.notAuthorized(bundleID: "com.google.Chrome"))
        )
        let aggregator = TabAggregator(providers: [good, bad])

        let result = await aggregator.fetchAll()

        XCTAssertEqual(result.tabs.count, 1)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures.first?.browser, .chrome)
    }
}

// MARK: - Fakes

private struct FakeProvider: TabProvider {
    let browser: BrowserKind
    let running: Bool
    let outcome: Outcome

    enum Outcome: Sendable {
        case success([Tab])
        case failure(TabProviderError)
    }

    var isRunning: Bool { running }

    func fetchTabs() async throws -> [Tab] {
        switch outcome {
        case .success(let tabs): return tabs
        case .failure(let err):  throw err
        }
    }

    func activate(_ tab: Tab) async throws {}
}

private extension Tab {
    static func fixture(title: String) -> Tab {
        Tab(browser: .safari, windowIndex: 1, tabIndex: 1, title: title, url: "https://example.com")
    }
}
