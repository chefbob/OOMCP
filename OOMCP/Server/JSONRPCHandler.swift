import Foundation

/// Handles JSON-RPC 2.0 message parsing and response formatting.
final class JSONRPCHandler: Sendable {

    // MARK: - Singleton

    static let shared = JSONRPCHandler()

    private init() {}

    // MARK: - Parsing

    /// Parse a JSON-RPC request from data.
    func parseRequest(from data: Data) throws -> JSONRPCRequest {
        let decoder = JSONDecoder()
        do {
            let request = try decoder.decode(JSONRPCRequest.self, from: data)

            // Validate JSON-RPC version
            guard request.jsonrpc == "2.0" else {
                throw JSONRPCError.invalidRequest("Invalid JSON-RPC version: \(request.jsonrpc)")
            }

            return request
        } catch let error as DecodingError {
            throw JSONRPCError.parseError(error.localizedDescription)
        }
    }

    /// Parse a JSON-RPC request from a string.
    func parseRequest(from string: String) throws -> JSONRPCRequest {
        guard let data = string.data(using: .utf8) else {
            throw JSONRPCError.parseError("Invalid UTF-8 string")
        }
        return try parseRequest(from: data)
    }

    // MARK: - Response Building

    /// Create a success response.
    func successResponse(result: Any?, id: JSONRPCId?) -> JSONRPCResponse {
        JSONRPCResponse(result: result, id: id)
    }

    /// Create an error response.
    func errorResponse(error: JSONRPCError, id: JSONRPCId?) -> JSONRPCResponse {
        JSONRPCResponse(error: error, id: id)
    }

    /// Create an error response from an OutlinerError.
    func errorResponse(from outlinerError: OutlinerError, id: JSONRPCId?) -> JSONRPCResponse {
        let rpcError = JSONRPCError.toolError(
            outlinerError.message,
            data: [
                "code": outlinerError.code.rawValue,
                "suggestion": outlinerError.suggestion as Any,
                "technicalDetail": outlinerError.technicalDetail as Any
            ]
        )
        return JSONRPCResponse(error: rpcError, id: id)
    }

    // MARK: - Encoding

    /// Encode a response to JSON data.
    func encodeResponse(_ response: JSONRPCResponse) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(response)
    }

    /// Encode a response to a JSON string.
    func encodeResponseString(_ response: JSONRPCResponse) throws -> String {
        let data = try encodeResponse(response)
        guard let string = String(data: data, encoding: .utf8) else {
            throw JSONRPCError.internalError("Failed to encode response as UTF-8")
        }
        return string
    }

    // MARK: - Parameter Extraction

    /// Extract a required string parameter.
    func requiredString(_ key: String, from params: [String: AnyCodable]?) throws -> String {
        guard let params = params else {
            throw JSONRPCError.invalidParams("Missing required parameters")
        }
        guard let value = params[key]?.stringValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: \(key)")
        }
        return value
    }

    /// Extract an optional string parameter.
    func optionalString(_ key: String, from params: [String: AnyCodable]?) -> String? {
        params?[key]?.stringValue
    }

    /// Extract a required integer parameter.
    func requiredInt(_ key: String, from params: [String: AnyCodable]?) throws -> Int {
        guard let params = params else {
            throw JSONRPCError.invalidParams("Missing required parameters")
        }
        guard let value = params[key]?.intValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: \(key)")
        }
        return value
    }

    /// Extract an optional integer parameter with default.
    func optionalInt(_ key: String, from params: [String: AnyCodable]?, default defaultValue: Int) -> Int {
        params?[key]?.intValue ?? defaultValue
    }

    /// Extract a required boolean parameter.
    func requiredBool(_ key: String, from params: [String: AnyCodable]?) throws -> Bool {
        guard let params = params else {
            throw JSONRPCError.invalidParams("Missing required parameters")
        }
        guard let value = params[key]?.boolValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: \(key)")
        }
        return value
    }

    /// Extract an optional boolean parameter with default.
    func optionalBool(_ key: String, from params: [String: AnyCodable]?, default defaultValue: Bool) -> Bool {
        params?[key]?.boolValue ?? defaultValue
    }

    /// Extract tool arguments from a tools/call request.
    func extractToolArguments(_ params: [String: AnyCodable]?) -> [String: AnyCodable]? {
        guard let params = params,
              let argumentsValue = params["arguments"] else {
            return nil
        }

        // Arguments might be already a dictionary
        if let dict = argumentsValue.dictionaryValue {
            return dict.mapValues { AnyCodable($0) }
        }

        return nil
    }
}

// MARK: - Batch Request Support

extension JSONRPCHandler {
    /// Check if the data contains a batch request (JSON array).
    func isBatchRequest(_ data: Data) -> Bool {
        guard let firstByte = data.first else { return false }
        // '[' character in ASCII/UTF-8
        return firstByte == 0x5B
    }

    /// Parse batch requests.
    func parseBatchRequests(from data: Data) throws -> [JSONRPCRequest] {
        let decoder = JSONDecoder()
        return try decoder.decode([JSONRPCRequest].self, from: data)
    }

    /// Encode batch responses.
    func encodeBatchResponses(_ responses: [JSONRPCResponse]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(responses)
    }
}
