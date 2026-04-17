import AppKit

enum BrowserKind: String, CaseIterable, Sendable {
    case safari
    case chrome
    case chromium
    case arc
    case brave
    case edge
    case vivaldi
    case opera

    var bundleID: String {
        switch self {
        case .safari:   return "com.apple.Safari"
        case .chrome:   return "com.google.Chrome"
        case .chromium: return "org.chromium.Chromium"
        case .arc:      return "company.thebrowser.Browser"
        case .brave:    return "com.brave.Browser"
        case .edge:     return "com.microsoft.edgemac"
        case .vivaldi:  return "com.vivaldi.Vivaldi"
        case .opera:    return "com.operasoftware.Opera"
        }
    }

    var displayName: String {
        switch self {
        case .safari:   return "Safari"
        case .chrome:   return "Google Chrome"
        case .chromium: return "Chromium"
        case .arc:      return "Arc"
        case .brave:    return "Brave"
        case .edge:     return "Microsoft Edge"
        case .vivaldi:  return "Vivaldi"
        case .opera:    return "Opera"
        }
    }

    var isChromiumFamily: Bool {
        self != .safari
    }

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    var icon: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
