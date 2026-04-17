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

        let searchItem = NSMenuItem(title: "Search Tabs",
                                    action: #selector(handleSearch),
                                    keyEquivalent: "")
        searchItem.target = self
        searchItem.image = Self.symbol("magnifyingglass")
        menu.addItem(searchItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Settings…",
                                   action: #selector(handlePreferences),
                                   keyEquivalent: ",")
        prefsItem.target = self
        prefsItem.image = Self.symbol("gearshape")
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit KV-TabFinder",
                                  action: #selector(handleQuit),
                                  keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = Self.symbol("xmark.circle")
        menu.addItem(quitItem)
    }

    @objc private func handleSearch()      { onSearch?() }
    @objc private func handlePreferences() { onPreferences?() }
    @objc private func handleQuit()        { onQuit?() }

    /// Small SF Symbol image sized to match standard NSMenuItem icons.
    private static func symbol(_ name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }
}
