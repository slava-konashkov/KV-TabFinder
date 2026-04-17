import Foundation
import SwiftUI
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let hotkey = "hotkey.combo.v1"
    }

    private let defaults: UserDefaults

    @Published var hotkey: HotkeyCombo {
        didSet { persistHotkey() }
    }

    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Keys.hotkey),
           let stored = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            self.hotkey = stored
        } else {
            self.hotkey = .default
        }

        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            self.launchAtLogin = false
        }
    }

    private func persistHotkey() {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: Keys.hotkey)
        }
    }

    private func applyLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // swallow — the most common failure is "already in this state"
        }
    }
}
