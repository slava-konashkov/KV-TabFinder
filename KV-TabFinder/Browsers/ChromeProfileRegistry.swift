import Foundation

/// Resolves Chrome profile → account email by reading Chrome's on-disk
/// `Local State` + per-profile `Preferences` files. AppleScript does not
/// expose the profile of a window, so we fall back to a heuristic:
/// Chrome writes the list of currently active profile directories into
/// `Local State.profile.last_active_profiles`, ordered from most- to
/// least-recently-active. We map AppleScript's `window N` (which is
/// ordered frontmost → back) 1:1 to that list.
///
/// Caveats:
/// - If a profile has multiple windows open the count won't match and
///   the resolver returns nil (caller falls back to plain "Chrome").
/// - Only works in the non-sandboxed Debug build. Release/App Store
///   build would need a user-granted security-scoped bookmark to read
///   `~/Library/Application Support/Google/Chrome`.
enum ChromeProfileRegistry {

    /// Produces an `[Int: String]` mapping of window index (1-based, as
    /// used in AppleScript) to an email/display string for the profile
    /// of that window.
    ///
    /// The underlying signal — `last_active_profiles` in Chrome's Local
    /// State — lists UNIQUE profiles only. If one profile has multiple
    /// windows open, the list is shorter than `windowCount`. We degrade
    /// gracefully: map the profiles we know to the first N windows, and
    /// leave the remaining windows without a badge (rather than wiping
    /// every Chrome row as if we had no data).
    static func windowProfileMap(windowCount: Int) -> [Int: String] {
        guard windowCount > 0 else { return [:] }
        guard let state = loadLocalState() else { return [:] }
        let activeDirs = state.lastActiveProfiles
        guard !activeDirs.isEmpty else { return [:] }

        var out: [Int: String] = [:]
        let upper = min(activeDirs.count, windowCount)
        for i in 0..<upper {
            if let display = accountDisplayString(for: activeDirs[i], localState: state) {
                out[i + 1] = display
            }
        }
        return out
    }

    // MARK: - Local State parsing

    private struct LocalState {
        let lastActiveProfiles: [String]
        /// Profile directory name → info from `profile.info_cache`.
        let infoCache: [String: ProfileInfo]
    }

    private struct ProfileInfo {
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

    /// Prefer email (`user_name`). Fall back to `name`, then `gaia_name`.
    private static func accountDisplayString(for profileDir: String, localState: LocalState) -> String? {
        // First try: consult info_cache from Local State.
        if let info = localState.infoCache[profileDir] {
            if let email = info.userName, !email.isEmpty { return email }
            if let name  = info.name, !name.isEmpty     { return name }
            if let gaia  = info.gaiaName, !gaia.isEmpty { return gaia }
        }

        // Fallback: read the profile's own Preferences file.
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
