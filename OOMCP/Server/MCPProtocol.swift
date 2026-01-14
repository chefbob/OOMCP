import Foundation

// MARK: - JSON-RPC 2.0 Types

/// JSON-RPC 2.0 request object.
struct JSONRPCRequest: Codable, Sendable {
    let jsonrpc: String
    let method: String
    let params: [String: AnyCodable]?
    let id: JSONRPCId?

    init(method: String, params: [String: AnyCodable]? = nil, id: JSONRPCId? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
        self.id = id
    }
}

/// JSON-RPC 2.0 response object.
struct JSONRPCResponse: Codable, Sendable {
    let jsonrpc: String
    let result: AnyCodable?
    let error: JSONRPCError?
    let id: JSONRPCId?

    init(result: Any?, id: JSONRPCId?) {
        self.jsonrpc = "2.0"
        self.result = result.map { AnyCodable($0) }
        self.error = nil
        self.id = id
    }

    init(error: JSONRPCError, id: JSONRPCId?) {
        self.jsonrpc = "2.0"
        self.result = nil
        self.error = error
        self.id = id
    }
}

/// JSON-RPC 2.0 error object.
struct JSONRPCError: Codable, Sendable, Error, LocalizedError {
    let code: Int
    let message: String
    let data: AnyCodable?

    init(code: Int, message: String, data: Any? = nil) {
        self.code = code
        self.message = message
        self.data = data.map { AnyCodable($0) }
    }

    var errorDescription: String? { message }

    // Standard JSON-RPC error codes
    static func parseError(_ detail: String? = nil) -> JSONRPCError {
        JSONRPCError(code: -32700, message: "Parse error", data: detail)
    }

    static func invalidRequest(_ detail: String? = nil) -> JSONRPCError {
        JSONRPCError(code: -32600, message: "Invalid Request", data: detail)
    }

    static func methodNotFound(_ method: String) -> JSONRPCError {
        JSONRPCError(code: -32601, message: "Method not found: \(method)")
    }

    static func invalidParams(_ detail: String? = nil) -> JSONRPCError {
        JSONRPCError(code: -32602, message: "Invalid params", data: detail)
    }

    static func internalError(_ detail: String? = nil) -> JSONRPCError {
        JSONRPCError(code: -32603, message: "Internal error", data: detail)
    }

    // MCP-specific error codes (-32000 to -32099)
    static func toolError(_ message: String, data: Any? = nil) -> JSONRPCError {
        JSONRPCError(code: -32000, message: message, data: data)
    }
}

/// JSON-RPC ID can be string, number, or null.
enum JSONRPCId: Codable, Sendable, Equatable {
    case string(String)
    case number(Int)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Int.self) {
            self = .number(number)
        } else {
            throw DecodingError.typeMismatch(
                JSONRPCId.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid JSON-RPC ID type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - MCP Protocol Types

/// MCP server information.
struct MCPServerInfo: Codable, Sendable {
    let name: String
    let version: String

    static let current = MCPServerInfo(name: "omnioutliner-mcp", version: "1.0.0")
}

/// MCP capabilities advertised by the server.
struct MCPCapabilities: Codable, Sendable {
    let tools: ToolsCapability?

    struct ToolsCapability: Codable, Sendable {
        let listChanged: Bool?
    }

    static let `default` = MCPCapabilities(tools: ToolsCapability(listChanged: false))
}

/// MCP initialize response.
struct MCPInitializeResult: Codable, Sendable {
    let protocolVersion: String
    let capabilities: MCPCapabilities
    let serverInfo: MCPServerInfo

    static let current = MCPInitializeResult(
        protocolVersion: "2024-11-05",
        capabilities: .default,
        serverInfo: .current
    )
}

/// MCP tool definition.
struct MCPTool: Codable, Sendable {
    let name: String
    let description: String
    let inputSchema: MCPInputSchema
}

/// MCP tool input schema (JSON Schema subset).
struct MCPInputSchema: Codable, Sendable {
    let type: String
    let properties: [String: MCPProperty]?
    let required: [String]?

    init(properties: [String: MCPProperty]? = nil, required: [String]? = nil) {
        self.type = "object"
        self.properties = properties
        self.required = required
    }
}

/// MCP property definition.
struct MCPProperty: Codable, Sendable {
    let type: String
    let description: String?
    let `enum`: [String]?
    let `default`: AnyCodable?
    let minimum: Int?
    let maximum: Int?

    init(type: String, description: String? = nil, enum enumValues: [String]? = nil,
         default defaultValue: Any? = nil, minimum: Int? = nil, maximum: Int? = nil) {
        self.type = type
        self.description = description
        self.enum = enumValues
        self.default = defaultValue.map { AnyCodable($0) }
        self.minimum = minimum
        self.maximum = maximum
    }
}

/// MCP tool call result.
struct MCPToolResult: Codable, Sendable {
    let content: [MCPContent]
    let isError: Bool?

    init(content: [MCPContent], isError: Bool? = nil) {
        self.content = content
        self.isError = isError
    }

    static func text(_ text: String) -> MCPToolResult {
        MCPToolResult(content: [.text(text)])
    }

    static func json(_ value: Any) -> MCPToolResult {
        if let data = try? JSONSerialization.data(withJSONObject: value, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return MCPToolResult(content: [.text(string)])
        }
        return MCPToolResult(content: [.text("Unable to serialize result")])
    }

    static func error(_ message: String) -> MCPToolResult {
        MCPToolResult(content: [.text(message)], isError: true)
    }
}

/// MCP content item.
enum MCPContent: Codable, Sendable {
    case text(String)
    case image(data: String, mimeType: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, data, mimeType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            self = .image(data: data, mimeType: mimeType)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown content type: \(type)")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let data, let mimeType):
            try container.encode("image", forKey: .type)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
        }
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic JSON values.
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unable to encode value of type \(type(of: value))")
            throw EncodingError.invalidValue(value, context)
        }
    }

    // Convenience accessors
    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }
    var doubleValue: Double? { value as? Double }
    var boolValue: Bool? { value as? Bool }
    var arrayValue: [Any]? { value as? [Any] }
    var dictionaryValue: [String: Any]? { value as? [String: Any] }
}
