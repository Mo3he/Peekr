import os

/// Central logger instances. Filter in Console.app by subsystem `net.mohome.peekr`.
///
/// Categories:
///   - Ping      — HTTP/TCP connectivity checks
///   - Refresh   — Background and manual refresh cycles
///   - Store     — ServiceStore persistence operations
///   - Notify    — Push notification delivery
enum AppLogger {
    static let ping    = Logger(subsystem: "net.mohome.peekr", category: "Ping")
    static let refresh = Logger(subsystem: "net.mohome.peekr", category: "Refresh")
    static let store   = Logger(subsystem: "net.mohome.peekr", category: "Store")
    static let notify  = Logger(subsystem: "net.mohome.peekr", category: "Notify")
}
