import AppKit

@MainActor
final class MenuBarMenu {
    let menu: NSMenu
    var onSearch: (() -> Void)?
    var onPreferences: (() -> Void)?
    var onQuit: (() -> Void)?

    init() {
        menu = NSMenu()
        menu.delegate = nil

        let searchItem = NSMenuItem(title: "Search Tabs", action: #selector(handleSearch), keyEquivalent: "")
        searchItem.target = self
        menu.addItem(searchItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(handlePreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit KV-TabFinder", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func handleSearch()      { onSearch?() }
    @objc private func handlePreferences() { onPreferences?() }
    @objc private func handleQuit()        { onQuit?() }
}
