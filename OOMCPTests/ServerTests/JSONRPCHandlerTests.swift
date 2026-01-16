import XCTest
@testable import OOMCP

final class JSONRPCHandlerTests: XCTestCase {

    let handler = JSONRPCHandler.shared

    // MARK: - Request Parsing Tests

    func testParseValidRequest() throws {
        let json = """
        {
            "jsonrpc": "2.0",
            "method": "initialize",
            "id": 1
        }
        """

        let request = try handler.parseRequest(from: json)

        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.method, "initialize")
        XCTAssertEqual(request.id, .number(1))
    }

    func testParseRequestWithParams() throws {
        let json = """
        {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "search_outline",
                "arguments": {
                    "query": "test",
                    "maxResults": 10
                }
            },
            "id": "req-123"
        }
        """

        let request = try handler.parseRequest(from: json)

        XCTAssertEqual(request.method, "tools/call")
        XCTAssertEqual(request.params?["name"]?.stringValue, "search_outline")
        XCTAssertEqual(request.id, .string("req-123"))
    }

    func testParseInvalidJSON() {
        let json = "{ invalid json }"

        XCTAssertThrowsError(try handler.parseRequest(from: json)) { error in
            XCTAssertTrue(error is JSONRPCError)
        }
    }

    func testParseInvalidVersion() {
        let json = """
        {
            "jsonrpc": "1.0",
            "method": "test",
            "id": 1
        }
        """

        XCTAssertThrowsError(try handler.parseRequest(from: json)) { error in
            if let rpcError = error as? JSONRPCError {
                XCTAssertEqual(rpcError.code, -32600) // Invalid Request
            }
        }
    }

    // MARK: - Response Building Tests

    func testSuccessResponse() throws {
        let response = handler.successResponse(
            result: ["status": "ok"],
            id: .number(1)
        )

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertNil(response.error)
        XCTAssertEqual(response.id, .number(1))

        let data = try handler.encodeResponse(response)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"status\""))
        XCTAssertTrue(json.contains("\"ok\""))
    }

    func testErrorResponse() throws {
        let error = JSONRPCError.methodNotFound("unknown")
        let response = handler.errorResponse(error: error, id: .string("test"))

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32601)

        let data = try handler.encodeResponse(response)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("-32601"))
        XCTAssertTrue(json.contains("unknown"))
    }

    func testOutlinerErrorResponse() throws {
        let outlinerError = OutlinerError.appNotRunning
        let response = handler.errorResponse(from: outlinerError, id: .number(1))

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32000)
        XCTAssertTrue(response.error?.message.contains("not running") ?? false)
    }

    // MARK: - Parameter Extraction Tests

    func testRequiredStringParameter() throws {
        let params: [String: AnyCodable] = [
            "name": AnyCodable("test_value")
        ]

        let value = try handler.requiredString("name", from: params)
        XCTAssertEqual(value, "test_value")
    }

    func testRequiredStringParameterMissing() {
        let params: [String: AnyCodable] = [:]

        XCTAssertThrowsError(try handler.requiredString("name", from: params)) { error in
            if let rpcError = error as? JSONRPCError {
                XCTAssertEqual(rpcError.code, -32602) // Invalid params
            }
        }
    }

    func testRequiredStringParameterNilParams() {
        XCTAssertThrowsError(try handler.requiredString("name", from: nil)) { error in
            if let rpcError = error as? JSONRPCError {
                XCTAssertEqual(rpcError.code, -32602)
            }
        }
    }

    func testOptionalStringParameter() {
        let params: [String: AnyCodable] = [
            "query": AnyCodable("search term")
        ]

        XCTAssertEqual(handler.optionalString("query", from: params), "search term")
        XCTAssertNil(handler.optionalString("missing", from: params))
        XCTAssertNil(handler.optionalString("query", from: nil))
    }

    func testRequiredIntParameter() throws {
        let params: [String: AnyCodable] = [
            "count": AnyCodable(42)
        ]

        let value = try handler.requiredInt("count", from: params)
        XCTAssertEqual(value, 42)
    }

    func testOptionalIntParameter() {
        let params: [String: AnyCodable] = [
            "limit": AnyCodable(100)
        ]

        XCTAssertEqual(handler.optionalInt("limit", from: params, default: 50), 100)
        XCTAssertEqual(handler.optionalInt("missing", from: params, default: 50), 50)
    }

    func testRequiredBoolParameter() throws {
        let params: [String: AnyCodable] = [
            "confirmed": AnyCodable(true)
        ]

        let value = try handler.requiredBool("confirmed", from: params)
        XCTAssertTrue(value)
    }

    func testOptionalBoolParameter() {
        let params: [String: AnyCodable] = [
            "includeNotes": AnyCodable(false)
        ]

        XCTAssertEqual(handler.optionalBool("includeNotes", from: params, default: true), false)
        XCTAssertEqual(handler.optionalBool("missing", from: params, default: true), true)
    }

    // MARK: - Tool Arguments Extraction Tests

    func testExtractToolArguments() {
        let params: [String: AnyCodable] = [
            "name": AnyCodable("search_outline"),
            "arguments": AnyCodable([
                "query": "test",
                "maxResults": 25
            ])
        ]

        let arguments = handler.extractToolArguments(params)

        XCTAssertNotNil(arguments)
        XCTAssertEqual(arguments?["query"]?.stringValue, "test")
        XCTAssertEqual(arguments?["maxResults"]?.intValue, 25)
    }

    func testExtractToolArgumentsNil() {
        let params: [String: AnyCodable] = [
            "name": AnyCodable("ping")
        ]

        let arguments = handler.extractToolArguments(params)
        XCTAssertNil(arguments)
    }

    // MARK: - Batch Request Tests

    func testIsBatchRequest() {
        let batchJSON = "[{\"jsonrpc\":\"2.0\",\"method\":\"ping\",\"id\":1}]"
        let singleJSON = "{\"jsonrpc\":\"2.0\",\"method\":\"ping\",\"id\":1}"

        XCTAssertTrue(handler.isBatchRequest(batchJSON.data(using: .utf8)!))
        XCTAssertFalse(handler.isBatchRequest(singleJSON.data(using: .utf8)!))
    }

    func testParseBatchRequests() throws {
        let json = """
        [
            {"jsonrpc": "2.0", "method": "ping", "id": 1},
            {"jsonrpc": "2.0", "method": "initialize", "id": 2}
        ]
        """

        let requests = try handler.parseBatchRequests(from: json.data(using: .utf8)!)

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].method, "ping")
        XCTAssertEqual(requests[1].method, "initialize")
    }

    func testEncodeBatchResponses() throws {
        let responses = [
            JSONRPCResponse(result: "ok", id: .number(1)),
            JSONRPCResponse(result: "ok", id: .number(2))
        ]

        let data = try handler.encodeBatchResponses(responses)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.hasPrefix("["))
        XCTAssertTrue(json.hasSuffix("]"))
    }

    // MARK: - Response Encoding Tests

    func testEncodeResponseString() throws {
        let response = handler.successResponse(result: "test", id: .number(1))
        let jsonString = try handler.encodeResponseString(response)

        XCTAssertTrue(jsonString.contains("\"jsonrpc\""))
        XCTAssertTrue(jsonString.contains("\"2.0\""))
        XCTAssertTrue(jsonString.contains("\"result\""))
    }
}
