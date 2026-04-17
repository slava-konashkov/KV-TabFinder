import Foundation

/// Resolves Chrome profile → account email for each AppleScript window.
///
/// Chrome's AppleScript doesn't expose profile info, so we do it by
/// content: we match each window's tab URLs against each profile's
/// `History` SQLite (via ChromeHistoryStore). The profile whose history
/// contains the most of a window's tab URLs wins that window.
///
/// Fallback: when URL matching is inconclusive (e.g. all tabs are
/// `chrome://newtab/`) we fall back to Chrome's
/// `Local State.profile.last_active_profiles` heuristic, mapping
/// frontmost windows to the most-recently-active profiles.
///
/// Debug-only: this uses filesystem access which won't work under the
/// App Sandbox used in Release.
enum ChromeProfileRegistry {

    /// Input: one entry per Chrome window, 1-based index plus the URLs
    /// of every tab in that window.
    struct WindowURLs {
        let windowIndex: Int
        let urls: [String]
    }

    /// Output: window index → human-readable account label (email or name).
    static func windowProfileMap(windows: [WindowURLs]) -> [Int: String] {
        guard !windows.isEmpty, let state = loadLocalState() else { return [:] }
        let profileDirs = Array(state.infoCache.keys)
        guard !profileDirs.isEmpty else { return [:] }

        // Preload URL sets for each profile once.
        var profileURLs: [String: Set<String>] = [:]
        for dir in profileDirs {
            profileURLs[dir] = ChromeHistoryStore.shared.recentURLs(profileDir: dir)
        }

        var out: [Int: String] = [:]
        for w in windows {
            let matchable = w.urls.filter { Self.isMatchableURL($0) }
            if !matchable.isEmpty {
                // Score each profile by how many of this window's
                // URLs appear in its history.
                var best: (dir: String, score: Int)? = nil
                for (dir, set) in profileURLs {
                    let score = matchable.reduce(0) { $0 + (set.contains($1) ? 1 : 0) }
                    if score > 0, score > (best?.score ?? 0) {
                        best = (dir, score)
                    }
                }
                if let best, let display = accountDisplayString(for: best.dir, localState: state) {
                    out[w.windowIndex] = display
                    continue
                }
            }
            // Fallback: use last_active_profiles ordering.
            if let dir = fallbackProfileDir(for: w.windowIndex, state: state),
               let display = accountDisplayString(for: dir, localState: state) {
                out[w.windowIndex] = display
            }
        }
        return out
    }

    // MARK: - Heuristics

    private static func isMatchableURL(_ url: String) -> Bool {
        // URLs that never hit the urls table or are shared across all
        // profiles.
        if url.isEmpty { return false }
        if url.hasPrefix("chrome://") { return false }
        if url.hasPrefix("chrome-extension://") { return false }
        if url == "about:blank" { return false }
        return true
    }

    /// Map window index to last_active_profiles[i-1] when URL matching
    /// fails. Imperfect but better than nothing.
    private static func fallbackProfileDir(for windowIndex: Int, state: LocalState) -> String? {
        let i = windowIndex - 1
        guard state.lastActiveProfiles.indices.contains(i) else {
            return state.lastActiveProfiles.first
        }
        return state.lastActiveProfiles[i]
    }

    // MARK: - Local State parsing

    struct LocalState {
        let lastActiveProfiles: [String]
        let infoCache: [String: ProfileInfo]
    }

    struct ProfileInfo {
        let name: String?
        let userName: String?  // email
        let gaiaName: String?
    }

    private static let chromeDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Application Support/Google/Chrome")
    }()

    private static func loadLocalState() -> LocalState? {
        let url = chromeDir.appendingPathComponent("Local State")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any] else {
            return nil
        }

        let lastActive = (profile["last_active_profiles"] as? [String]) ?? []

        var cache: [String: ProfileInfo] = [:]
        if let raw = profile["info_cache"] as? [String: [String: Any]] {
            for (dir, info) in raw {
                cache[dir] = ProfileInfo(
                    name: info["name"] as? String,
                    userName: info["user_name"] as? String,
                    gaiaName: info["gaia_name"] as? String
                )
            }
        }

        return LocalState(lastActiveProfiles: lastActive, infoCache: cache)
    }

    private static func accountDisplayString(for profileDir: String, localState: LocalState) -> String? {
        if let info = localState.infoCache[profileDir] {
            if let email = info.userName, !email.isEmpty { return email }
            if let name  = info.name, !name.isEmpty     { return name }
            if let gaia  = info.gaiaName, !gaia.isEmpty { return gaia }
        }

        let prefsURL = chromeDir.appendingPathComponent(profileDir).appendingPathComponent("Preferences")
        guard let data = try? Data(contentsOf: prefsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let accounts = json["account_info"] as? [[String: Any]], let first = accounts.first {
            if let email = first["email"] as? String, !email.isEmpty { return email }
            if let name  = first["full_name"] as? String, !name.isEmpty { return name }
        }
        if let prof = json["profile"] as? [String: Any], let name = prof["name"] as? String, !name.isEmpty {
            return name
        }
        return nil
    }
}
