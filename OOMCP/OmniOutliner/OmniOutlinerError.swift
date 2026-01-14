import Foundation

// MARK: - Error Code

/// Machine-readable error codes for OmniOutliner operations.
enum ErrorCode: String, Codable, Equatable, Sendable {
    case appNotRunning = "app_not_running"
    case noDocument = "no_document"
    case rowNotFound = "row_not_found"
    case invalidLocation = "invalid_location"
    case permissionDenied = "permission_denied"
    case proRequired = "pro_required"
    case documentLocked = "document_locked"
    case operationFailed = "operation_failed"
    case serverStartFailed = "server_start_failed"
    case invalidInput = "invalid_input"
}

// MARK: - Outliner Error

/// Standardized error response for all OmniOutliner operations.
struct OutlinerError: Error, Codable, Equatable, Sendable {
    /// Machine-readable error code
    let code: ErrorCode

    /// User-friendly error description
    let message: String

    /// Recommended action to resolve
    let suggestion: String?

    /// Additional detail for debugging
    let technicalDetail: String?

    init(code: ErrorCode, message: String, suggestion: String? = nil, technicalDetail: String? = nil) {
        self.code = code
        self.message = message
        self.suggestion = suggestion
        self.technicalDetail = technicalDetail
    }

    // MARK: - Convenience Initializers

    /// OmniOutliner is not running
    static var appNotRunning: OutlinerError {
        OutlinerError(
            code: .appNotRunning,
            message: "OmniOutliner is not running.",
            suggestion: "Please open OmniOutliner to use this feature."
        )
    }

    /// No document is currently open
    static var noDocument: OutlinerError {
        OutlinerError(
            code: .noDocument,
            message: "No document is open in OmniOutliner.",
            suggestion: "Please open a document in OmniOutliner."
        )
    }

    /// Referenced row ID does not exist
    static func rowNotFound(rowId: String) -> OutlinerError {
        OutlinerError(
            code: .rowNotFound,
            message: "The row '\(rowId)' could not be found.",
            suggestion: "The row may have been deleted or moved. Try refreshing the outline."
        )
    }

    /// Cannot place row at specified location
    static func invalidLocation(detail: String? = nil) -> OutlinerError {
        OutlinerError(
            code: .invalidLocation,
            message: "Cannot place the row at the specified location.",
            suggestion: "Choose a different parent row or position.",
            technicalDetail: detail
        )
    }

    /// macOS denied automation permission
    static var permissionDenied: OutlinerError {
        OutlinerError(
            code: .permissionDenied,
            message: "OmniOutliner MCP needs permission to control OmniOutliner.",
            suggestion: "Go to System Settings > Privacy & Security > Automation and enable OmniOutliner for this app."
        )
    }

    /// OmniOutliner Pro is required for scripting
    static var proRequired: OutlinerError {
        OutlinerError(
            code: .proRequired,
            message: "OmniOutliner Pro is required.",
            suggestion: "Scripting is a Pro-only feature. Please upgrade to OmniOutliner Pro, or subscribe to OmniOutliner or Omni Pro."
        )
    }

    /// Document is read-only or locked
    static var documentLocked: OutlinerError {
        OutlinerError(
            code: .documentLocked,
            message: "The document is read-only or locked.",
            suggestion: "Unlock the document in OmniOutliner or open a different document."
        )
    }

    /// Generic operation failure
    static func operationFailed(detail: String? = nil) -> OutlinerError {
        OutlinerError(
            code: .operationFailed,
            message: "The operation could not be completed.",
            suggestion: "Please try again. If the problem persists, restart OmniOutliner.",
            technicalDetail: detail
        )
    }

    /// Server failed to start
    static func serverStartFailed(port: Int, detail: String? = nil) -> OutlinerError {
        OutlinerError(
            code: .serverStartFailed,
            message: "Could not start the MCP server on port \(port).",
            suggestion: "Another application may be using this port. Try changing the port in Preferences.",
            technicalDetail: detail
        )
    }

    /// Invalid input provided
    static func invalidInput(_ detail: String) -> OutlinerError {
        OutlinerError(
            code: .invalidInput,
            message: "Invalid input provided.",
            suggestion: "Please check your request and try again.",
            technicalDetail: detail
        )
    }
}

// MARK: - LocalizedError Conformance

extension OutlinerError: LocalizedError {
    var errorDescription: String? {
        message
    }

    var recoverySuggestion: String? {
        suggestion
    }
}

// MARK: - JSON Response

extension OutlinerError {
    /// Convert to a dictionary suitable for JSON response
    func toResponse() -> [String: Any] {
        var response: [String: Any] = [
            "code": code.rawValue,
            "message": message
        ]

        if let suggestion = suggestion {
            response["suggestion"] = suggestion
        }

        if let technicalDetail = technicalDetail {
            response["technicalDetail"] = technicalDetail
        }

        return response
    }
}
