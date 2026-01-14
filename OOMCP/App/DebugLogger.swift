import Foundation
import os.log

/// Debug logging utility that respects the debug logging preference.
/// Logs to Console.app with the subsystem "com.omnioutliner.mcp".
enum DebugLogger {

    // MARK: - Properties

    private static let subsystem = "com.omnioutliner.mcp"
    private static let mcpLogger = Logger(subsystem: subsystem, category: "MCP")
    private static let scriptLogger = Logger(subsystem: subsystem, category: "Script")
    private static let toolLogger = Logger(subsystem: subsystem, category: "Tool")

    // MARK: - Logging Methods

    /// Log an MCP request/response event.
    static func logMCP(_ message: String, type: LogType = .info) {
        guard Preferences.shared.debugLogging else { return }
        log(mcpLogger, message, type: type)
    }

    /// Log a script execution event.
    static func logScript(_ message: String, type: LogType = .info) {
        guard Preferences.shared.debugLogging else { return }
        log(scriptLogger, message, type: type)
    }

    /// Log a tool execution event.
    static func logTool(_ message: String, type: LogType = .info) {
        guard Preferences.shared.debugLogging else { return }
        log(toolLogger, message, type: type)
    }

    // MARK: - Timing Helpers

    /// Measure and log the duration of an async operation.
    static func measureMCP<T>(_ label: String, operation: () async throws -> T) async rethrows -> T {
        guard Preferences.shared.debugLogging else {
            return try await operation()
        }

        let start = CFAbsoluteTimeGetCurrent()
        logMCP("[\(label)] Starting...")

        do {
            let result = try await operation()
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            logMCP("[\(label)] Completed in \(String(format: "%.1f", duration))ms")
            return result
        } catch {
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            logMCP("[\(label)] Failed after \(String(format: "%.1f", duration))ms: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    /// Measure and log the duration of a synchronous operation.
    static func measureScript<T>(_ label: String, operation: () throws -> T) rethrows -> T {
        guard Preferences.shared.debugLogging else {
            return try operation()
        }

        let start = CFAbsoluteTimeGetCurrent()
        logScript("[\(label)] Starting...")

        do {
            let result = try operation()
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            logScript("[\(label)] Completed in \(String(format: "%.1f", duration))ms")
            return result
        } catch {
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            logScript("[\(label)] Failed after \(String(format: "%.1f", duration))ms: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - Private

    private static func log(_ logger: Logger, _ message: String, type: LogType) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formattedMessage = "[\(timestamp)] \(message)"

        switch type {
        case .info:
            logger.info("\(formattedMessage)")
        case .debug:
            logger.debug("\(formattedMessage)")
        case .warning:
            logger.warning("\(formattedMessage)")
        case .error:
            logger.error("\(formattedMessage)")
        }

        // Also print to console for immediate visibility
        print("[DEBUG] \(message)")
    }

    // MARK: - Log Type

    enum LogType {
        case info
        case debug
        case warning
        case error
    }
}
