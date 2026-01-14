import Foundation

/// Routes MCP requests to appropriate handlers.
@MainActor
final class MCPRouter {

    // MARK: - Properties

    private let handler = JSONRPCHandler.shared
    private var toolRegistry: ToolRegistry?

    // MARK: - Singleton

    static let shared = MCPRouter()

    private init() {}

    // MARK: - Configuration

    /// Set the tool registry for handling tool calls.
    func setToolRegistry(_ registry: ToolRegistry) {
        self.toolRegistry = registry
    }

    // MARK: - Request Routing

    /// Handle an incoming JSON-RPC request and return a response.
    func handleRequest(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        let startTime = CFAbsoluteTimeGetCurrent()
        let idString: String
        if let id = request.id {
            switch id {
            case .string(let s): idString = s
            case .number(let n): idString = String(n)
            case .null: idString = "null"
            }
        } else {
            idString = "nil"
        }
        DebugLogger.logMCP("Request: \(request.method) (id: \(idString))")

        let response: JSONRPCResponse
        switch request.method {
        case "initialize":
            response = handleInitialize(request)

        case "initialized":
            // Notification, no response needed but we'll acknowledge
            response = handler.successResponse(result: nil, id: request.id)

        case "ping":
            response = handler.successResponse(result: ["status": "ok"], id: request.id)

        case "tools/list":
            response = handleToolsList(request)

        case "tools/call":
            response = await handleToolsCall(request)

        case "shutdown":
            response = handler.successResponse(result: nil, id: request.id)

        default:
            response = handler.errorResponse(
                error: .methodNotFound(request.method),
                id: request.id
            )
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        DebugLogger.logMCP("Response: \(request.method) completed in \(String(format: "%.1f", duration))ms")

        return response
    }

    /// Handle raw data request.
    func handleRequest(data: Data) async -> Data {
        do {
            // Check for batch request
            if handler.isBatchRequest(data) {
                let requests = try handler.parseBatchRequests(from: data)
                var responses: [JSONRPCResponse] = []

                for request in requests {
                    let response = await handleRequest(request)
                    // Only include responses for requests with IDs
                    if request.id != nil {
                        responses.append(response)
                    }
                }

                return try handler.encodeBatchResponses(responses)
            }

            // Single request
            let request = try handler.parseRequest(from: data)
            let response = await handleRequest(request)

            // Notifications (no id) don't get responses
            if request.id == nil {
                return Data()
            }

            return try handler.encodeResponse(response)
        } catch let error as JSONRPCError {
            let response = handler.errorResponse(error: error, id: nil)
            return (try? handler.encodeResponse(response)) ?? Data()
        } catch {
            let response = handler.errorResponse(
                error: .internalError(error.localizedDescription),
                id: nil
            )
            return (try? handler.encodeResponse(response)) ?? Data()
        }
    }

    // MARK: - Method Handlers

    private func handleInitialize(_ request: JSONRPCRequest) -> JSONRPCResponse {
        handler.successResponse(
            result: [
                "protocolVersion": MCPInitializeResult.current.protocolVersion,
                "capabilities": [
                    "tools": ["listChanged": false]
                ],
                "serverInfo": [
                    "name": MCPServerInfo.current.name,
                    "version": MCPServerInfo.current.version
                ]
            ],
            id: request.id
        )
    }

    private func handleToolsList(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let registry = toolRegistry else {
            return handler.errorResponse(
                error: .internalError("Tool registry not initialized"),
                id: request.id
            )
        }

        var toolsList: [[String: Any]] = []

        for tool in registry.allTools() {
            // Build properties dictionary
            var propertiesDict: [String: [String: Any]] = [:]

            if let properties = tool.inputSchema.properties {
                for (name, prop) in properties {
                    var propDict: [String: Any] = ["type": prop.type]
                    if let desc = prop.description {
                        propDict["description"] = desc
                    }
                    if let enumVals = prop.enum {
                        propDict["enum"] = enumVals
                    }
                    if let def = prop.default {
                        // Only include primitive default values
                        if let strVal = def.stringValue {
                            propDict["default"] = strVal
                        } else if let intVal = def.intValue {
                            propDict["default"] = intVal
                        } else if let boolVal = def.boolValue {
                            propDict["default"] = boolVal
                        }
                    }
                    if let min = prop.minimum {
                        propDict["minimum"] = min
                    }
                    if let max = prop.maximum {
                        propDict["maximum"] = max
                    }
                    propertiesDict[name] = propDict
                }
            }

            // Build inputSchema
            var inputSchema: [String: Any] = [
                "type": "object",
                "properties": propertiesDict
            ]

            if let required = tool.inputSchema.required, !required.isEmpty {
                inputSchema["required"] = required
            }

            let toolDict: [String: Any] = [
                "name": tool.name,
                "description": tool.description,
                "inputSchema": inputSchema
            ]

            toolsList.append(toolDict)
        }

        return handler.successResponse(result: ["tools": toolsList], id: request.id)
    }

    private func handleToolsCall(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        guard let registry = toolRegistry else {
            return handler.errorResponse(
                error: .internalError("Tool registry not initialized"),
                id: request.id
            )
        }

        // Extract tool name
        guard let toolName = request.params?["name"]?.stringValue else {
            return handler.errorResponse(
                error: .invalidParams("Missing tool name"),
                id: request.id
            )
        }

        // Extract arguments
        let arguments = handler.extractToolArguments(request.params)

        DebugLogger.logTool("Executing tool: \(toolName)")
        let toolStartTime = CFAbsoluteTimeGetCurrent()

        // Execute tool
        // Note: Tool execution errors are returned as successful responses with isError: true
        // JSON-RPC errors should only be used for protocol-level issues (not tool failures)
        do {
            let result = try await registry.executeTool(name: toolName, arguments: arguments)

            let toolDuration = (CFAbsoluteTimeGetCurrent() - toolStartTime) * 1000
            DebugLogger.logTool("Tool \(toolName) completed in \(String(format: "%.1f", toolDuration))ms")

            return handler.successResponse(
                result: [
                    "content": result.content.map { content -> [String: Any] in
                        switch content {
                        case .text(let text):
                            return ["type": "text", "text": text]
                        case .image(let data, let mimeType):
                            return ["type": "image", "data": data, "mimeType": mimeType]
                        }
                    },
                    "isError": result.isError ?? false
                ],
                id: request.id
            )
        } catch let error as OutlinerError {
            // Return tool error as successful response with isError: true (per MCP spec)
            let toolDuration = (CFAbsoluteTimeGetCurrent() - toolStartTime) * 1000
            DebugLogger.logTool("Tool \(toolName) failed after \(String(format: "%.1f", toolDuration))ms: \(error.message)", type: .error)

            let errorMessage = error.suggestion != nil
                ? "\(error.message) \(error.suggestion!)"
                : error.message

            return handler.successResponse(
                result: [
                    "content": [["type": "text", "text": errorMessage]],
                    "isError": true
                ],
                id: request.id
            )
        } catch let error as JSONRPCError {
            // Invalid params etc. are protocol errors, return as JSON-RPC error
            let toolDuration = (CFAbsoluteTimeGetCurrent() - toolStartTime) * 1000
            DebugLogger.logTool("Tool \(toolName) failed after \(String(format: "%.1f", toolDuration))ms: \(error.localizedDescription)", type: .error)
            return handler.errorResponse(error: error, id: request.id)
        } catch {
            // Unknown errors returned as tool errors with isError: true
            let toolDuration = (CFAbsoluteTimeGetCurrent() - toolStartTime) * 1000
            DebugLogger.logTool("Tool \(toolName) failed after \(String(format: "%.1f", toolDuration))ms: \(error.localizedDescription)", type: .error)

            return handler.successResponse(
                result: [
                    "content": [["type": "text", "text": error.localizedDescription]],
                    "isError": true
                ],
                id: request.id
            )
        }
    }
}
