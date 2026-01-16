import XCTest
@testable import OOMCP

final class MCPProtocolTests: XCTestCase {

    // MARK: - JSONRPCRequest Tests

    func testJSONRPCRequestInitialization() {
        let request = JSONRPCRequest(
            method: "tools/list",
            params: ["key": AnyCodable("value")],
            id: .string("req-1")
        )

        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.method, "tools/list")
        XCTAssertEqual(request.params?["key"]?.stringValue, "value")
        XCTAssertEqual(request.id, .string("req-1"))
    }

    func testJSONRPCRequestDecoding() throws {
        let json = """
        {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "get_current_document"
            },
            "id": 1
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let request = try decoder.decode(JSONRPCRequest.self, from: data)

        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.method, "tools/call")
        XCTAssertEqual(request.params?["name"]?.stringValue, "get_current_document")
        XCTAssertEqual(request.id, .number(1))
    }

    func testJSONRPCRequestDecodingStringId() throws {
        let json = """
        {
            "jsonrpc": "2.0",
            "method": "ping",
            "id": "request-123"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let request = try decoder.decode(JSONRPCRequest.self, from: data)

        XCTAssertEqual(request.id, .string("request-123"))
    }

    func testJSONRPCRequestDecodingNullId() throws {
        // In JSON-RPC 2.0, an explicit null id is treated as a notification (no response expected)
        // Standard Codable treats null the same as absent, which is correct for our use case
        let json = """
        {
            "jsonrpc": "2.0",
            "method": "initialized",
            "id": null
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let request = try decoder.decode(JSONRPCRequest.self, from: data)

        // Null id is treated as absent (notification)
        XCTAssertNil(request.id)
    }

    func testJSONRPCRequestDecodingNoId() throws {
        let json = """
        {
            "jsonrpc": "2.0",
            "method": "initialized"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let request = try decoder.decode(JSONRPCRequest.self, from: data)

        XCTAssertNil(request.id)
    }

    // MARK: - JSONRPCResponse Tests

    func testJSONRPCResponseSuccess() throws {
        let response = JSONRPCResponse(
            result: ["status": "ok"],
            id: .number(1)
        )

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertNil(response.error)
        XCTAssertEqual(response.id, .number(1))

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"jsonrpc\":\"2.0\""))
    }

    func testJSONRPCResponseError() throws {
        let error = JSONRPCError.methodNotFound("unknown_method")
        let response = JSONRPCResponse(error: error, id: .string("req-1"))

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32601)
    }

    // MARK: - JSONRPCError Tests

    func testJSONRPCErrorCodes() {
        XCTAssertEqual(JSONRPCError.parseError().code, -32700)
        XCTAssertEqual(JSONRPCError.invalidRequest().code, -32600)
        XCTAssertEqual(JSONRPCError.methodNotFound("test").code, -32601)
        XCTAssertEqual(JSONRPCError.invalidParams().code, -32602)
        XCTAssertEqual(JSONRPCError.internalError().code, -32603)
        XCTAssertEqual(JSONRPCError.toolError("test").code, -32000)
    }

    func testJSONRPCErrorWithData() {
        let error = JSONRPCError.toolError("Test error", data: ["detail": "more info"])

        XCTAssertEqual(error.code, -32000)
        XCTAssertEqual(error.message, "Test error")
        XCTAssertNotNil(error.data)
    }

    // MARK: - JSONRPCId Tests

    func testJSONRPCIdEquality() {
        XCTAssertEqual(JSONRPCId.string("abc"), JSONRPCId.string("abc"))
        XCTAssertEqual(JSONRPCId.number(123), JSONRPCId.number(123))
        XCTAssertEqual(JSONRPCId.null, JSONRPCId.null)

        XCTAssertNotEqual(JSONRPCId.string("abc"), JSONRPCId.string("def"))
        XCTAssertNotEqual(JSONRPCId.number(1), JSONRPCId.number(2))
        XCTAssertNotEqual(JSONRPCId.string("1"), JSONRPCId.number(1))
    }

    // MARK: - MCPServerInfo Tests

    func testMCPServerInfo() {
        let info = MCPServerInfo.current

        XCTAssertEqual(info.name, "omnioutliner-mcp")
        XCTAssertEqual(info.version, "1.0.0")
    }

    // MARK: - MCPTool Tests

    func testMCPToolDefinition() {
        let tool = MCPTool(
            name: "test_tool",
            description: "A test tool",
            inputSchema: MCPInputSchema(
                properties: [
                    "param1": MCPProperty(type: "string", description: "A string parameter")
                ],
                required: ["param1"]
            )
        )

        XCTAssertEqual(tool.name, "test_tool")
        XCTAssertEqual(tool.description, "A test tool")
        XCTAssertEqual(tool.inputSchema.type, "object")
        XCTAssertNotNil(tool.inputSchema.properties?["param1"])
        XCTAssertEqual(tool.inputSchema.required, ["param1"])
    }

    // MARK: - MCPProperty Tests

    func testMCPPropertyWithEnum() {
        let prop = MCPProperty(
            type: "string",
            description: "A search scope",
            enum: ["all", "topics", "notes"],
            default: "all"
        )

        XCTAssertEqual(prop.type, "string")
        XCTAssertEqual(prop.enum, ["all", "topics", "notes"])
        XCTAssertEqual(prop.default?.stringValue, "all")
    }

    func testMCPPropertyWithRange() {
        let prop = MCPProperty(
            type: "integer",
            description: "Max results",
            default: 50,
            minimum: 1,
            maximum: 100
        )

        XCTAssertEqual(prop.type, "integer")
        XCTAssertEqual(prop.minimum, 1)
        XCTAssertEqual(prop.maximum, 100)
        XCTAssertEqual(prop.default?.intValue, 50)
    }

    // MARK: - MCPToolResult Tests

    func testMCPToolResultText() {
        let result = MCPToolResult.text("Hello, world!")

        XCTAssertEqual(result.content.count, 1)
        XCTAssertNil(result.isError)

        if case .text(let text) = result.content[0] {
            XCTAssertEqual(text, "Hello, world!")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testMCPToolResultError() {
        let result = MCPToolResult.error("Something went wrong")

        XCTAssertTrue(result.isError ?? false)

        if case .text(let text) = result.content[0] {
            XCTAssertEqual(text, "Something went wrong")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testMCPToolResultJSON() {
        let result = MCPToolResult.json(["key": "value", "number": 42])

        XCTAssertEqual(result.content.count, 1)

        if case .text(let text) = result.content[0] {
            XCTAssertTrue(text.contains("\"key\""))
            XCTAssertTrue(text.contains("\"value\""))
        } else {
            XCTFail("Expected text content")
        }
    }

    // MARK: - MCPContent Tests

    func testMCPContentTextCodable() throws {
        let content = MCPContent.text("Hello")

        let encoder = JSONEncoder()
        let data = try encoder.encode(content)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPContent.self, from: data)

        if case .text(let text) = decoded {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testMCPContentImageCodable() throws {
        let content = MCPContent.image(data: "base64data", mimeType: "image/png")

        let encoder = JSONEncoder()
        let data = try encoder.encode(content)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPContent.self, from: data)

        if case .image(let imageData, let mimeType) = decoded {
            XCTAssertEqual(imageData, "base64data")
            XCTAssertEqual(mimeType, "image/png")
        } else {
            XCTFail("Expected image content")
        }
    }

    // MARK: - AnyCodable Tests

    func testAnyCodableString() throws {
        let value = AnyCodable("hello")
        XCTAssertEqual(value.stringValue, "hello")
        XCTAssertNil(value.intValue)
    }

    func testAnyCodableInt() throws {
        let value = AnyCodable(42)
        XCTAssertEqual(value.intValue, 42)
        XCTAssertNil(value.stringValue)
    }

    func testAnyCodableBool() throws {
        let value = AnyCodable(true)
        XCTAssertEqual(value.boolValue, true)
    }

    func testAnyCodableArray() throws {
        let value = AnyCodable([1, 2, 3])
        XCTAssertEqual(value.arrayValue?.count, 3)
    }

    func testAnyCodableDictionary() throws {
        let value = AnyCodable(["key": "value"])
        XCTAssertEqual(value.dictionaryValue?["key"] as? String, "value")
    }

    func testAnyCodableRoundTrip() throws {
        let original: [String: Any] = [
            "string": "hello",
            "number": 42,
            "bool": true,
            "array": [1, 2, 3],
            "nested": ["key": "value"]
        ]

        let encoded = AnyCodable(original)
        let encoder = JSONEncoder()
        let data = try encoder.encode(encoded)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.dictionaryValue?["string"] as? String, "hello")
        XCTAssertEqual(decoded.dictionaryValue?["number"] as? Int, 42)
        XCTAssertEqual(decoded.dictionaryValue?["bool"] as? Bool, true)
    }
}
