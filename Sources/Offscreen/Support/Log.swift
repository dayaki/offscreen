import os

enum Log {
    static let app = Logger(subsystem: "com.dayo.offscreen", category: "app")
    static let engine = Logger(subsystem: "com.dayo.offscreen", category: "engine")
    static let monitors = Logger(subsystem: "com.dayo.offscreen", category: "monitors")
    static let windows = Logger(subsystem: "com.dayo.offscreen", category: "windows")
    static let stats = Logger(subsystem: "com.dayo.offscreen", category: "stats")
}
