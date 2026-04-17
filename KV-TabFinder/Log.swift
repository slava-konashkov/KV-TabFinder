import Foundation
import os

enum Log {
    static let subsystem = "com.konashkov.KV-TabFinder"

    static let app         = Logger(subsystem: subsystem, category: "app")
    static let hotkey      = Logger(subsystem: subsystem, category: "hotkey")
    static let panel       = Logger(subsystem: subsystem, category: "panel")
    static let aggregator  = Logger(subsystem: subsystem, category: "aggregator")
    static let provider    = Logger(subsystem: subsystem, category: "provider")
    static let applescript = Logger(subsystem: subsystem, category: "applescript")
}
