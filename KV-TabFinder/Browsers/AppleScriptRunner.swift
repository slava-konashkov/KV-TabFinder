import Foundation

/// Runs AppleScript snippets. Caches compiled scripts by source-hash for reuse.
/// NSAppleScript is not thread-safe; we serialise all runs on a private queue.
final class AppleScriptRunner: @unchecked Sendable {
    static let shared = AppleScriptRunner()

    private let queue = DispatchQueue(label: "com.konashkov.KV-TabFinder.applescript")
    private var cache: [Int: NSAppleScript] = [:]

    private init() {}

    /// Execute source and return the result descriptor, or throw.
    /// `bundleID` is only used to build useful error messages.
    func run(source: String, bundleID: String) async throws -> NSAppleEventDescriptor {
        let startedAt = Date()
        Log.applescript.info("▶ run start bundleID=\(bundleID, privacy: .public) source=\(source, privacy: .public)")
        do {
            let result: NSAppleEventDescriptor = try await withCheckedThrowingContinuation { cont in
                queue.async { [self] in
                    do {
                        let script = try compiled(source: source, bundleID: bundleID)
                        var err: NSDictionary?
                        let descriptor = script.executeAndReturnError(&err)
                        if let err { throw Self.mapError(err, bundleID: bundleID) }
                        cont.resume(returning: descriptor)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
            let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
            Log.applescript.info("✔ run ok bundleID=\(bundleID, privacy: .public) items=\(result.numberOfItems) \(ms)ms")
            return result
        } catch {
            let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
            Log.applescript.error("✘ run FAIL bundleID=\(bundleID, privacy: .public) \(ms)ms error=\(String(describing: error), privacy: .public)")
            throw error
        }
    }

    private func compiled(source: String, bundleID: String) throws -> NSAppleScript {
        let key = source.hashValue
        if let cached = cache[key] { return cached }
        guard let script = NSAppleScript(source: source) else {
            Log.applescript.fault("could not instantiate NSAppleScript for \(bundleID, privacy: .public)")
            throw TabProviderError.scriptFailed(bundleID: bundleID, message: "could not instantiate NSAppleScript")
        }
        var err: NSDictionary?
        if !script.compileAndReturnError(&err), let err {
            throw Self.mapError(err, bundleID: bundleID)
        }
        cache[key] = script
        Log.applescript.debug("compiled+cached script for \(bundleID, privacy: .public)")
        return script
    }

    private static func mapError(_ err: NSDictionary, bundleID: String) -> TabProviderError {
        let code = (err[NSAppleScript.errorNumber] as? Int) ?? 0
        let message = (err[NSAppleScript.errorMessage] as? String) ?? "unknown"
        let briefMessage = (err[NSAppleScript.errorBriefMessage] as? String) ?? ""
        let appName = (err[NSAppleScript.errorAppName] as? String) ?? ""

        Log.applescript.error(
            "AppleScript error bundleID=\(bundleID, privacy: .public) code=\(code) message=\(message, privacy: .public) brief=\(briefMessage, privacy: .public) app=\(appName, privacy: .public)"
        )

        // Codes treated as automation-permission denial:
        //  -1743  errAEEventNotPermitted (user denied in TCC)
        //   1002  Not authorized to send Apple events (sandbox / missing entitlement)
        //  -1744  User cancelled
        //  -10004 errAEPrivilegeError
        if code == -1743 || code == -1744 || code == 1002 || code == -10004 {
            return .notAuthorized(bundleID: bundleID)
        }
        return .scriptFailed(bundleID: bundleID, message: "\(message) (\(code))")
    }
}
