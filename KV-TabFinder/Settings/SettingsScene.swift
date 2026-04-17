import SwiftUI

struct SettingsScene: Scene {
    @ObservedObject var store: SettingsStore
    let onHotkeyChange: (HotkeyCombo) -> Void

    var body: some Scene {
        Settings {
            SettingsView(store: store, onHotkeyChange: onHotkeyChange)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let onHotkeyChange: (HotkeyCombo) -> Void

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 280)
    }

    private var generalTab: some View {
        Form {
            Section {
                HStack {
                    Text("Shortcut:")
                        .frame(width: 120, alignment: .trailing)
                    HotkeyRecorder(combo: Binding(
                        get: { store.hotkey },
                        set: { newValue in
                            store.hotkey = newValue
                            onHotkeyChange(newValue)
                        }
                    ))
                    .frame(width: 200, height: 28)

                    Button("Reset") {
                        store.hotkey = .default
                        onHotkeyChange(.default)
                    }
                }
            } header: {
                Text("Global shortcut").font(.headline)
            } footer: {
                Text("Press this combination from anywhere to open tab search.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Launch at login", isOn: $store.launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
            Text("KV-TabFinder")
                .font(.title2).bold()
            Text("Search across all open browser tabs.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("© 2026 bsg.world")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
