import Foundation

struct Tab: Identifiable, Hashable, Sendable {
    let id: UUID
    let browser: BrowserKind
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
    /// Optional account/profile label (e.g. Chrome profile email). `nil`
    /// if the browser doesn't expose it.
    let accountHint: String?

    init(
        browser: BrowserKind,
        windowIndex: Int,
        tabIndex: Int,
        title: String,
        url: String,
        accountHint: String? = nil
    ) {
        self.id = UUID()
        self.browser = browser
        self.windowIndex = windowIndex
        self.tabIndex = tabIndex
        self.title = title
        self.url = url
        self.accountHint = accountHint
    }
}
