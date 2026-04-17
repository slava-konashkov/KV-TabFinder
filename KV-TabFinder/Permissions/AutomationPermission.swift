import AppKit

enum AutomationPermission {

    @MainActor
    static func showErrorAlert(for error: Error, browser: BrowserKind) {
        let alert = NSAlert()
        if let e = error as? TabProviderError, case .notAuthorized = e {
            alert.messageText = "\(browser.displayName) is not authorized"
            alert.informativeText = """
            KV-TabFinder needs permission to control \(browser.displayName).

            Open System Settings → Privacy & Security → Automation and enable \
            \(browser.displayName) under KV-TabFinder.
            """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                openAutomationSettings()
            }
        } else {
            alert.messageText = "Could not switch to tab"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @MainActor
    static func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
}
