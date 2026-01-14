import Foundation

/// Bridge to OmniOutliner via NSAppleScript for JXA execution.
/// Provides async methods to execute Omni Automation scripts and parse results.
@MainActor
final class OmniOutlinerBridge: Sendable {

    // MARK: - Singleton

    static let shared = OmniOutlinerBridge()

    private init() {}

    // MARK: - Script Execution

    /// Execute a JXA script and return the JSON result.
    /// - Parameter script: Complete JXA script with run() function that returns JSON.stringify(...)
    /// - Returns: Parsed JSON result as a dictionary
    /// - Throws: OutlinerError if execution fails
    func execute(_ script: String) async throws -> [String: Any] {
        let resultString = try executeJXA(script)
        return try parseJSONResult(resultString)
    }

    /// Execute a JXA script and return raw string result.
    /// - Parameter script: The Omni Automation JavaScript code to execute
    /// - Returns: Raw string result from the script
    /// - Throws: OutlinerError if execution fails
    func executeRaw(_ script: String) async throws -> String {
        let wrappedScript = wrapAsJXA(script)
        return try executeJXA(wrappedScript)
    }

    /// Execute a complete JXA script directly (no wrapping).
    /// - Parameter script: Complete JXA script with run() function
    /// - Returns: Raw string result from the script
    /// - Throws: OutlinerError if execution fails
    func executeJXADirect(_ script: String) async throws -> String {
        return try executeJXA(script)
    }

    // MARK: - Private Methods

    /// Wrap Omni Automation script for JXA execution via NSAppleScript.
    private func wrapAsJXA(_ omniScript: String) -> String {
        // Escape the script for embedding in JXA
        let escapedScript = omniScript
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        return """
        ObjC.import('Foundation');

        function run() {
            const app = Application('OmniOutliner');

            // Check if app is running
            if (!app.running()) {
                return JSON.stringify({
                    error: {
                        code: 'app_not_running',
                        message: 'OmniOutliner is not running.'
                    }
                });
            }

            try {
                // Execute Omni Automation script via URL
                const script = "\(escapedScript)";
                const encodedScript = encodeURIComponent(script);
                const url = 'omnioutliner:///omnijs-run?script=' + encodedScript;

                // Use openLocation to run the script
                const currentApp = Application.currentApplication();
                currentApp.includeStandardAdditions = true;

                // For simple queries, we can use direct evaluation
                app.includeStandardAdditions = true;

                // Execute and return result
                const result = eval(script);
                return JSON.stringify({ result: result });

            } catch (e) {
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: e.message || 'Script execution failed',
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    /// Execute JXA script and parse JSON result.
    private func executeAppleScript(_ source: String) throws -> [String: Any] {
        let stringResult = try executeJXA(source)
        return try parseJSONResult(stringResult)
    }

    /// Execute JXA script using osascript command.
    /// Note: For sandboxed apps, ensure proper entitlements are configured.
    private func executeJXA(_ source: String) throws -> String {
        let startTime = CFAbsoluteTimeGetCurrent()
        DebugLogger.logScript("Executing osascript (\(source.count) chars)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", source]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            DebugLogger.logScript("osascript failed to launch after \(String(format: "%.1f", duration))ms: \(error)", type: .error)
            throw OutlinerError.operationFailed(detail: "Failed to run osascript: \(error.localizedDescription)")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        DebugLogger.logScript("osascript completed in \(String(format: "%.1f", duration))ms (output: \(output.count) chars)")

        if process.terminationStatus != 0 {
            DebugLogger.logScript("osascript error (exit \(process.terminationStatus)): \(errorOutput)", type: .error)

            // Check for specific error types
            if errorOutput.contains("Pro feature") || errorOutput.contains("-1743") {
                if errorOutput.contains("Pro feature") {
                    throw OutlinerError.proRequired
                } else {
                    throw OutlinerError.permissionDenied
                }
            }

            if errorOutput.contains("not allowed") || errorOutput.contains("(-1743)") {
                throw OutlinerError.permissionDenied
            }

            throw OutlinerError.operationFailed(detail: "osascript error: \(errorOutput)")
        }

        return output
    }

    /// Parse JSON string result into dictionary.
    private func parseJSONResult(_ jsonString: String) throws -> [String: Any] {
        guard let data = jsonString.data(using: .utf8) else {
            throw OutlinerError.operationFailed(detail: "Could not encode result as UTF-8")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OutlinerError.operationFailed(detail: "Result is not a JSON object")
        }

        // Check for error in response
        if let errorDict = json["error"] as? [String: Any] {
            let code = ErrorCode(rawValue: errorDict["code"] as? String ?? "operation_failed") ?? .operationFailed
            let message = errorDict["message"] as? String ?? "Unknown error"
            let suggestion = errorDict["suggestion"] as? String
            let technicalDetail = errorDict["technicalDetail"] as? String

            throw OutlinerError(code: code, message: message, suggestion: suggestion, technicalDetail: technicalDetail)
        }

        // Return the result portion or the full response
        if let result = json["result"] {
            if let resultDict = result as? [String: Any] {
                return resultDict
            } else {
                return ["value": result]
            }
        }

        return json
    }

    // MARK: - Connection Check

    /// Check if OmniOutliner is running and accessible.
    func checkConnection() async -> ConnectionStatus {
        let checkScript = """
        ObjC.import('Foundation');

        function run() {
            const app = Application('OmniOutliner');

            if (!app.running()) {
                return JSON.stringify({
                    connected: false,
                    appRunning: false,
                    documentOpen: false,
                    documentName: null,
                    message: 'OmniOutliner is not running. Please launch OmniOutliner and open a document.'
                });
            }

            try {
                const docs = app.documents();
                if (docs.length === 0) {
                    return JSON.stringify({
                        connected: false,
                        appRunning: true,
                        documentOpen: false,
                        documentName: null,
                        message: 'OmniOutliner is running but no document is open. Please open a document.'
                    });
                }

                const doc = docs[0];
                const docName = doc.name();

                return JSON.stringify({
                    connected: true,
                    appRunning: true,
                    documentOpen: true,
                    documentName: docName,
                    message: 'Connected to OmniOutliner. Document \\'' + docName + '\\' is open.'
                });
            } catch (e) {
                return JSON.stringify({
                    connected: false,
                    appRunning: true,
                    documentOpen: false,
                    documentName: null,
                    message: 'Error checking OmniOutliner status: ' + e.message
                });
            }
        }

        run();
        """

        do {
            let resultString = try await executeJXADirect(checkScript)

            guard let data = resultString.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ConnectionStatus(connected: false, appRunning: false, documentOpen: false,
                                        documentName: nil, message: "Failed to parse connection status")
            }

            return ConnectionStatus(
                connected: json["connected"] as? Bool ?? false,
                appRunning: json["appRunning"] as? Bool ?? false,
                documentOpen: json["documentOpen"] as? Bool ?? false,
                documentName: json["documentName"] as? String,
                message: json["message"] as? String ?? "Unknown status"
            )
        } catch let error as OutlinerError {
            if error.code == .proRequired {
                return ConnectionStatus(
                    connected: false,
                    appRunning: true,
                    documentOpen: false,
                    documentName: nil,
                    message: "OmniOutliner Pro is required. Scripting is a Pro-only feature. Please upgrade to OmniOutliner Pro.",
                    proRequired: true
                )
            }
            return ConnectionStatus(
                connected: false,
                appRunning: false,
                documentOpen: false,
                documentName: nil,
                message: error.message
            )
        } catch {
            return ConnectionStatus(
                connected: false,
                appRunning: false,
                documentOpen: false,
                documentName: nil,
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Connection Status

/// Status of the connection to OmniOutliner.
struct ConnectionStatus: Codable, Equatable, Sendable {
    let connected: Bool
    let appRunning: Bool
    let documentOpen: Bool
    let documentName: String?
    let message: String
    let proRequired: Bool

    init(connected: Bool, appRunning: Bool, documentOpen: Bool, documentName: String?, message: String, proRequired: Bool = false) {
        self.connected = connected
        self.appRunning = appRunning
        self.documentOpen = documentOpen
        self.documentName = documentName
        self.message = message
        self.proRequired = proRequired
    }
}
