import Foundation

/// Protocol for MCP tool handlers.
protocol MCPToolHandler: Sendable {
    /// The tool definition for MCP tools/list.
    var tool: MCPTool { get }

    /// Execute the tool with the given arguments.
    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult
}

/// Registry for all MCP tools.
@MainActor
final class ToolRegistry {

    // MARK: - Properties

    private var handlers: [String: any MCPToolHandler] = [:]

    // MARK: - Singleton

    static let shared = ToolRegistry()

    private init() {}

    // MARK: - Registration

    /// Register a tool handler.
    func register(_ handler: any MCPToolHandler) {
        handlers[handler.tool.name] = handler
    }

    /// Register multiple tool handlers.
    func register(_ handlers: [any MCPToolHandler]) {
        for handler in handlers {
            register(handler)
        }
    }

    /// Unregister a tool by name.
    func unregister(_ name: String) {
        handlers.removeValue(forKey: name)
    }

    // MARK: - Tool Access

    /// Get all registered tools.
    func allTools() -> [MCPTool] {
        handlers.values.map { $0.tool }
    }

    /// Get a tool by name.
    func tool(named name: String) -> MCPTool? {
        handlers[name]?.tool
    }

    /// Check if a tool is registered.
    func hasToolNamed(_ name: String) -> Bool {
        handlers[name] != nil
    }

    // MARK: - Execution

    /// Execute a tool by name with arguments.
    func executeTool(name: String, arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        guard let handler = handlers[name] else {
            throw JSONRPCError.methodNotFound(name)
        }

        // Validate and sanitize arguments
        let sanitizedArgs = try validateArguments(arguments, for: handler.tool)

        return try await handler.execute(arguments: sanitizedArgs)
    }

    // MARK: - Input Validation

    /// Validate and sanitize tool arguments against the schema.
    private func validateArguments(_ arguments: [String: AnyCodable]?, for tool: MCPTool) throws -> [String: AnyCodable]? {
        // Check required parameters
        if let required = tool.inputSchema.required {
            for param in required {
                if arguments?[param] == nil {
                    throw JSONRPCError.invalidParams("Missing required parameter: \(param)")
                }
            }
        }

        // Validate parameter types and sanitize
        guard let args = arguments, let properties = tool.inputSchema.properties else {
            return arguments
        }

        var sanitized: [String: AnyCodable] = [:]

        for (key, value) in args {
            // Skip unknown parameters
            guard let prop = properties[key] else {
                continue
            }

            // Type validation
            let isValid: Bool
            switch prop.type {
            case "string":
                isValid = value.stringValue != nil
                // Sanitize string inputs
                if let str = value.stringValue {
                    let sanitizedStr = sanitizeString(str)
                    sanitized[key] = AnyCodable(sanitizedStr)
                }
            case "integer", "number":
                isValid = value.intValue != nil || value.doubleValue != nil
                sanitized[key] = value
            case "boolean":
                isValid = value.boolValue != nil
                sanitized[key] = value
            case "array":
                isValid = value.arrayValue != nil
                sanitized[key] = value
            case "object":
                isValid = value.dictionaryValue != nil
                sanitized[key] = value
            default:
                isValid = true
                sanitized[key] = value
            }

            if !isValid {
                throw JSONRPCError.invalidParams("Invalid type for parameter '\(key)': expected \(prop.type)")
            }

            // Enum validation
            if let enumValues = prop.enum, let strValue = value.stringValue {
                if !enumValues.contains(strValue) {
                    throw JSONRPCError.invalidParams("Invalid value for '\(key)': must be one of \(enumValues.joined(separator: ", "))")
                }
            }

            // Range validation for integers
            if let intValue = value.intValue {
                if let min = prop.minimum, intValue < min {
                    throw JSONRPCError.invalidParams("Value for '\(key)' must be >= \(min)")
                }
                if let max = prop.maximum, intValue > max {
                    throw JSONRPCError.invalidParams("Value for '\(key)' must be <= \(max)")
                }
            }
        }

        return sanitized.isEmpty ? arguments : sanitized
    }

    /// Sanitize a string input to prevent injection attacks.
    private func sanitizeString(_ input: String) -> String {
        // Remove null bytes
        var sanitized = input.replacingOccurrences(of: "\0", with: "")

        // Limit length to prevent DoS
        if sanitized.count > SizeConstraints.maxTopicLength {
            sanitized = String(sanitized.prefix(SizeConstraints.maxTopicLength))
        }

        return sanitized
    }

    // MARK: - Default Tool Registration

    /// Register all default tools.
    func registerDefaultTools() {
        // Query tools will be registered from QueryTools.swift
        // Modify tools will be registered from ModifyTools.swift
        // Synthesis tools will be registered from SynthesisTools.swift

        // Note: Call this after all tool handlers are imported
    }
}

// MARK: - Convenience Tool Builder

/// Builder for creating MCPTool definitions.
struct ToolBuilder {
    let name: String
    let description: String
    var properties: [String: MCPProperty] = [:]
    var required: [String] = []

    init(name: String, description: String) {
        self.name = name
        self.description = description
    }

    mutating func addParameter(
        _ name: String,
        type: String,
        description: String,
        required: Bool = false,
        enumValues: [String]? = nil,
        defaultValue: Any? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil
    ) {
        properties[name] = MCPProperty(
            type: type,
            description: description,
            enum: enumValues,
            default: defaultValue,
            minimum: minimum,
            maximum: maximum
        )

        if required {
            self.required.append(name)
        }
    }

    func build() -> MCPTool {
        MCPTool(
            name: name,
            description: description,
            inputSchema: MCPInputSchema(
                properties: properties.isEmpty ? nil : properties,
                required: required.isEmpty ? nil : required
            )
        )
    }
}
