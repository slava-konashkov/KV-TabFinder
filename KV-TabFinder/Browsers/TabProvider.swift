import Foundation

protocol TabProvider: Sendable {
    var browser: BrowserKind { get }
    var isRunning: Bool { get }
    func fetchTabs() async throws -> [Tab]
    func activate(_ tab: Tab) async throws
}

enum TabProviderError: Error, LocalizedError {
    case notAuthorized(bundleID: String)
    case scriptFailed(bundleID: String, message: String)
    case invalidResponse(bundleID: String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized(let b):
            return "KV-TabFinder is not allowed to control \(b). Enable it in System Settings → Privacy & Security → Automation."
        case .scriptFailed(let b, let m):
            return "Script failed for \(b): \(m)"
        case .invalidResponse(let b):
            return "Unexpected AppleScript response from \(b)"
        }
    }
}
