import os

/// Central logger instances. Filter in Console.app by subsystem `com.mblieden.peekr`.
///
/// Categories:
///   - Ping      — HTTP/TCP connectivity checks
///   - Refresh   — Background and manual refresh cycles
///   - Store     — ServiceStore persistence operations
///   - Notify    — Push notification delivery
enum AppLogger {
    static let ping    = Logger(subsystem: "com.mblieden.peekr", category: "Ping")
    static let refresh = Logger(subsystem: "com.mblieden.peekr", category: "Refresh")
    static let store   = Logger(subsystem: "com.mblieden.peekr", category: "Store")
    static let notify  = Logger(subsystem: "com.mblieden.peekr", category: "Notify")
}
