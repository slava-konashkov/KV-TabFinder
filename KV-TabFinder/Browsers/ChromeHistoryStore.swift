import Foundation
import SQLite3

/// Reads each Chrome profile's `History` SQLite DB to learn which URLs
/// that profile has seen. We open it in `immutable` mode so Chrome's
/// own exclusive lock does not get in the way. Results are cached and
/// invalidated when the DB file's mtime changes.
///
/// This is the backbone of the "which profile owns this window?"
/// heuristic: for each AppleScript window, we match its tab URLs
/// against each profile's set and pick the profile with the most hits.
final class ChromeHistoryStore: @unchecked Sendable {
    static let shared = ChromeHistoryStore()

    private struct CachedSet {
        let urls: Set<String>
        let historyMtime: Date
    }

    private let lock = NSLock()
    private var cache: [String: CachedSet] = [:]

    private let chromeDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome")
    }()

    private init() {}

    /// URLs visited in this profile recently (top `limit` entries by
    /// `last_visit_time`). Cached until `History`'s mtime changes.
    func recentURLs(profileDir: String, limit: Int = 5000) -> Set<String> {
        let historyURL = chromeDir.appendingPathComponent("\(profileDir)/History")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: historyURL.path),
              let mtime = attrs[.modificationDate] as? Date else {
            return []
        }

        lock.lock()
        if let cached = cache[profileDir], cached.historyMtime == mtime {
            let urls = cached.urls
            lock.unlock()
            return urls
        }
        lock.unlock()

        let loaded = Self.loadURLs(from: historyURL, limit: limit)
        lock.lock()
        cache[profileDir] = CachedSet(urls: loaded, historyMtime: mtime)
        lock.unlock()

        Log.provider.info("ChromeHistory loaded profile=\(profileDir, privacy: .public) urls=\(loaded.count)")
        return loaded
    }

    private static func loadURLs(from dbPath: URL, limit: Int) -> Set<String> {
        // `immutable=1` lets us read even while Chrome holds an exclusive
        // lock. We miss uncheckpointed WAL changes — acceptable, since
        // recent entries that matter for the currently-open tabs are
        // already in the main DB by the time the panel shows.
        let uri = "file:\(dbPath.path)?immutable=1"
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(uri, &db, flags, nil) == SQLITE_OK else {
            Log.provider.error("sqlite3_open failed for \(dbPath.path, privacy: .public)")
            return []
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT url FROM urls ORDER BY last_visit_time DESC LIMIT ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Log.provider.error("sqlite3_prepare failed for \(dbPath.path, privacy: .public)")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var urls = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cstr = sqlite3_column_text(stmt, 0) {
                urls.insert(String(cString: cstr))
            }
        }
        return urls
    }
}
