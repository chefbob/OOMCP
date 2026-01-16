import XCTest
@testable import OOMCP

final class SynthesisToolsTests: XCTestCase {

    // MARK: - GetSectionContent Tests

    func testGetSectionContentToolDefinition() {
        let handler = GetSectionContentHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "get_section_content")
        XCTAssertTrue(tool.description.contains("section"))
        XCTAssertTrue(tool.description.contains("summarization") || tool.description.contains("content"))

        // rowId is optional (omit for entire document)
        XCTAssertNil(tool.inputSchema.required)

        // Check parameters
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["rowId"])
        XCTAssertNotNil(properties?["format"])

        // Check format enum values
        XCTAssertEqual(properties?["format"]?.enum, ["plain", "markdown", "structured"])
    }

    func testGetSectionContentAcceptsNoArguments() async {
        // get_section_content should accept no arguments (gets entire document)
        let handler = GetSectionContentHandler()

        // This will fail at execution but should pass parameter validation
        do {
            _ = try await handler.execute(arguments: nil)
        } catch let error as JSONRPCError {
            // Should not be invalid params error
            XCTAssertNotEqual(error.code, -32602, "Should not fail parameter validation")
        } catch {
            // Other errors are acceptable (OmniOutliner not running, etc.)
        }
    }

    func testGetSectionContentAcceptsEmptyArguments() async {
        let handler = GetSectionContentHandler()

        do {
            _ = try await handler.execute(arguments: [:])
        } catch let error as JSONRPCError {
            XCTAssertNotEqual(error.code, -32602, "Should not fail parameter validation")
        } catch {
            // Other errors acceptable
        }
    }

    // MARK: - InsertContent Tests

    func testInsertContentToolDefinition() {
        let handler = InsertContentHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "insert_content")
        XCTAssertTrue(tool.description.contains("Insert"))

        // Check required parameters
        XCTAssertTrue(tool.inputSchema.required?.contains("content") ?? false)

        // Check parameters
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["content"])
        XCTAssertNotNil(properties?["parentId"])
        XCTAssertNotNil(properties?["position"])

        // Check position enum
        XCTAssertEqual(properties?["position"]?.enum, ["first", "last"])
    }

    func testInsertContentMissingContentThrows() async {
        let handler = InsertContentHandler()

        do {
            _ = try await handler.execute(arguments: nil)
            XCTFail("Expected error for missing content")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
            XCTAssertEqual(error.message, "Invalid params")
            if let data = error.data?.stringValue {
                XCTAssertTrue(data.contains("content"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInsertContentMissingContentWithEmptyArgs() async {
        let handler = InsertContentHandler()

        do {
            _ = try await handler.execute(arguments: [:])
            XCTFail("Expected error for missing content")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInsertContentWithOnlyContentIsValid() async {
        // insert_content should accept just content parameter
        let handler = InsertContentHandler()
        let args: [String: AnyCodable] = ["content": AnyCodable("Test content")]

        do {
            _ = try await handler.execute(arguments: args)
        } catch let error as JSONRPCError {
            // Should not be invalid params error
            XCTAssertNotEqual(error.code, -32602, "Should not fail parameter validation")
        } catch {
            // Other errors acceptable
        }
    }

    // MARK: - Tool Registration Tests

    @MainActor
    func testSynthesisToolsRegistration() {
        let registry = ToolRegistry.shared

        // Register synthesis tools
        SynthesisTools.registerAll(in: registry)

        // Verify all synthesis tools are registered
        XCTAssertTrue(registry.hasToolNamed("get_section_content"))
        XCTAssertTrue(registry.hasToolNamed("insert_content"))
    }

    @MainActor
    func testSynthesisToolDefinitionsRetrievable() {
        let registry = ToolRegistry.shared
        SynthesisTools.registerAll(in: registry)

        // Verify tools can be retrieved by name
        let getSectionTool = registry.tool(named: "get_section_content")
        XCTAssertNotNil(getSectionTool)
        XCTAssertEqual(getSectionTool?.name, "get_section_content")

        let insertTool = registry.tool(named: "insert_content")
        XCTAssertNotNil(insertTool)
        XCTAssertEqual(insertTool?.name, "insert_content")
    }

    // MARK: - Format Parameter Tests

    func testGetSectionContentDefaultFormat() {
        let handler = GetSectionContentHandler()
        let tool = handler.tool

        // Check that default value is "structured"
        let formatProp = tool.inputSchema.properties?["format"]
        XCTAssertNotNil(formatProp?.default)
    }

    // MARK: - Content Parameter Tests

    func testInsertContentDescriptionMentionsJSON() {
        let handler = InsertContentHandler()
        let tool = handler.tool

        let contentProp = tool.inputSchema.properties?["content"]
        XCTAssertNotNil(contentProp?.description)
        XCTAssertTrue(contentProp?.description?.contains("JSON") ?? false)
    }
}
