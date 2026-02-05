import Foundation

/// Simple file-backed logger for on-device diagnostics.
///
/// Logs to an app-writable, stable location:
/// - Sandbox: `~/Library/Containers/<bundle-id>/Data/Library/Application Support/VibeCap/Logs/vibecap.log`
/// - Non-sandbox: `~/Library/Logs/VibeCap/vibecap.log`
enum AppLog {
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
    }

    private static let queue = DispatchQueue(label: "vibecap.applog", qos: .utility)
    private static let iso = ISO8601DateFormatter()
    private static let bootstrapLock = NSLock()
    private static var bootstrapped = false

    static func logURL() -> URL {
        // Prefer a sandbox-writable location first.
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport
                .appendingPathComponent("VibeCap", isDirectory: true)
                .appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent("vibecap.log", isDirectory: false)
        }

        // Fallback (non-sandbox / unusual environments).
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
            .appendingPathComponent("VibeCap", isDirectory: true)
            .appendingPathComponent("vibecap.log", isDirectory: false)
    }

    static func log(_ level: Level, _ category: String, _ message: String, file: StaticString = #fileID, line: UInt = #line) {
        bootstrap()

        let ts = iso.string(from: Date())
        let thread = Thread.isMainThread ? "main" : "bg"
        let loc = "\(file):\(line)"
        let line = "[\(ts)] [\(level.rawValue)] [\(category)] [\(thread)] \(message) (\(loc))\n"

        queue.async {
            do {
                let url = logURL()
                let dir = url.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                if FileManager.default.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    try handle.seekToEnd()
                    if let data = line.data(using: .utf8) {
                        try handle.write(contentsOf: data)
                    }
                    try handle.close()
                } else {
                    try line.data(using: .utf8)?.write(to: url, options: .atomic)
                }
            } catch {
                // Best-effort: never crash on logging.
                // But do print so failures are visible in Xcode console.
                print("[AppLog] write failed: \(error)")
            }
        }
    }

    static func bootstrap() {
        bootstrapLock.lock()
        defer { bootstrapLock.unlock() }
        guard !bootstrapped else { return }
        bootstrapped = true

        // Create file eagerly so "file not found" can't happen.
        do {
            let url = logURL()
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let header = "\n=== VibeCap log session start \(iso.string(from: Date())) ===\n"
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                if let data = header.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
                try handle.close()
            } else {
                try header.data(using: .utf8)?.write(to: url, options: .atomic)
            }

            // Always print resolved path once for debugging.
            print("[AppLog] log path: \(url.path)")
        } catch {
            print("[AppLog] bootstrap failed: \(error)")
        }
    }

    /// Returns the last `maxBytes` of the log file (best-effort).
    static func tail(maxBytes: Int = 32_000) -> String {
        bootstrap()
        let url = logURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }

            let end = try handle.seekToEnd()
            let size = Int(end)
            let startOffset = max(0, size - maxBytes)
            try handle.seek(toOffset: UInt64(startOffset))
            let data = try handle.readToEnd() ?? Data()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            // Best-effort
            return "[AppLog] tail failed: \(error)"
        }
    }

    /// Measures duration of a scope and logs it at end.
    static func span(_ category: String, _ name: String, meta: [String: CustomStringConvertible] = [:]) -> Span {
        Span(category: category, name: name, meta: meta)
    }

    struct Span {
        let category: String
        let name: String
        let meta: [String: CustomStringConvertible]
        private let start = DispatchTime.now()

        init(category: String, name: String, meta: [String: CustomStringConvertible]) {
            self.category = category
            self.name = name
            self.meta = meta
            if meta.isEmpty {
                AppLog.log(.debug, category, "BEGIN \(name)")
            } else {
                AppLog.log(.debug, category, "BEGIN \(name) meta=\(format(meta))")
            }
        }

        func end(_ level: Level = .info, extra: [String: CustomStringConvertible] = [:]) {
            let end = DispatchTime.now()
            let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
            let ms = Double(nanos) / 1_000_000.0

            var merged = meta
            extra.forEach { merged[$0.key] = $0.value }

            if merged.isEmpty {
                AppLog.log(level, category, "END \(name) duration_ms=\(String(format: "%.2f", ms))")
            } else {
                AppLog.log(level, category, "END \(name) duration_ms=\(String(format: "%.2f", ms)) meta=\(format(merged))")
            }
        }

        private func format(_ meta: [String: CustomStringConvertible]) -> String {
            meta
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
        }
    }
}

