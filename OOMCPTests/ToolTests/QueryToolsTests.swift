import XCTest
@testable import OOMCP

final class QueryToolsTests: XCTestCase {

    // MARK: - ListDocuments Tests

    func testListDocumentsToolDefinition() {
        let handler = ListDocumentsHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "list_documents")
        XCTAssertTrue(tool.description.contains("List"))
        XCTAssertTrue(tool.description.contains("open documents"))
        XCTAssertNil(tool.inputSchema.required)
    }

    // MARK: - GetAllDocumentsContent Tests

    func testGetAllDocumentsContentToolDefinition() {
        let handler = GetAllDocumentsContentHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "get_all_documents_content")
        XCTAssertTrue(tool.description.contains("ALL open documents"))

        // Check parameters exist
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["includeNotes"])
        XCTAssertEqual(properties?["includeNotes"]?.type, "boolean")
    }

    // MARK: - GetCurrentDocument Tests

    func testGetCurrentDocumentToolDefinition() {
        let handler = GetCurrentDocumentHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "get_current_document")
        XCTAssertTrue(tool.description.contains("frontmost"))
        XCTAssertNil(tool.inputSchema.required)
    }

    // MARK: - GetOutlineStructure Tests

    func testGetOutlineStructureToolDefinition() {
        let handler = GetOutlineStructureHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "get_outline_structure")
        XCTAssertTrue(tool.description.contains("outline structure"))

        // Check parameters exist
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["documentName"])
        XCTAssertNotNil(properties?["maxDepth"])
        XCTAssertNotNil(properties?["includeNotes"])

        // Check parameter types
        XCTAssertEqual(properties?["documentName"]?.type, "string")
        XCTAssertEqual(properties?["maxDepth"]?.type, "integer")
        XCTAssertEqual(properties?["includeNotes"]?.type, "boolean")
    }

    // MARK: - GetRow Tests

    func testGetRowToolDefinition() {
        let handler = GetRowHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "get_row")
        XCTAssertTrue(tool.description.contains("specific row"))

        // Check required parameters
        XCTAssertTrue(tool.inputSchema.required?.contains("rowId") ?? false)

        // Check parameters
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["rowId"])
        XCTAssertNotNil(properties?["includeChildren"])
        XCTAssertEqual(properties?["rowId"]?.type, "string")
        XCTAssertEqual(properties?["includeChildren"]?.type, "boolean")
    }

    func testGetRowMissingRowIdThrows() async {
        let handler = GetRowHandler()

        do {
            _ = try await handler.execute(arguments: nil)
            XCTFail("Expected error for missing rowId")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602) // Invalid params
            // Detail is in data field, message is "Invalid params"
            XCTAssertEqual(error.message, "Invalid params")
            if let data = error.data?.stringValue {
                XCTAssertTrue(data.contains("rowId"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testGetRowMissingRowIdWithEmptyArgs() async {
        let handler = GetRowHandler()

        do {
            _ = try await handler.execute(arguments: [:])
            XCTFail("Expected error for missing rowId")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - GetRowChildren Tests

    func testGetRowChildrenToolDefinition() {
        let handler = GetRowChildrenHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "get_row_children")
        XCTAssertTrue(tool.description.contains("children"))

        // rowId is optional for this tool (omit for top-level)
        XCTAssertNil(tool.inputSchema.required)

        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["rowId"])
    }

    // MARK: - SearchOutline Tests

    func testSearchOutlineToolDefinition() {
        let handler = SearchOutlineHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "search_outline")
        XCTAssertTrue(tool.description.contains("Search"))

        // Check required parameters
        XCTAssertTrue(tool.inputSchema.required?.contains("query") ?? false)

        // Check all parameters
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["query"])
        XCTAssertNotNil(properties?["searchIn"])
        XCTAssertNotNil(properties?["caseSensitive"])
        XCTAssertNotNil(properties?["maxResults"])

        // Check enum values for searchIn
        XCTAssertEqual(properties?["searchIn"]?.enum, ["all", "topics", "notes"])

        // Check range for maxResults
        XCTAssertEqual(properties?["maxResults"]?.minimum, 1)
        XCTAssertEqual(properties?["maxResults"]?.maximum, 100)
    }

    func testSearchOutlineMissingQueryThrows() async {
        let handler = SearchOutlineHandler()

        do {
            _ = try await handler.execute(arguments: nil)
            XCTFail("Expected error for missing query")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
            XCTAssertEqual(error.message, "Invalid params")
            if let data = error.data?.stringValue {
                XCTAssertTrue(data.contains("query"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSearchOutlineWithEmptyArgsThrows() async {
        let handler = SearchOutlineHandler()

        do {
            _ = try await handler.execute(arguments: [:])
            XCTFail("Expected error for missing query")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - CheckConnection Tests

    func testCheckConnectionToolDefinition() {
        let handler = CheckConnectionHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "check_connection")
        XCTAssertTrue(tool.description.contains("OmniOutliner"))
        XCTAssertNil(tool.inputSchema.required)
        XCTAssertNil(tool.inputSchema.properties)
    }

    // MARK: - Tool Registration Tests

    @MainActor
    func testQueryToolsRegistration() {
        let registry = ToolRegistry.shared

        // Clear and re-register
        QueryTools.registerAll(in: registry)

        // Verify all query tools are registered
        XCTAssertTrue(registry.hasToolNamed("list_documents"))
        XCTAssertTrue(registry.hasToolNamed("get_all_documents_content"))
        XCTAssertTrue(registry.hasToolNamed("get_current_document"))
        XCTAssertTrue(registry.hasToolNamed("get_outline_structure"))
        XCTAssertTrue(registry.hasToolNamed("get_row"))
        XCTAssertTrue(registry.hasToolNamed("get_row_children"))
        XCTAssertTrue(registry.hasToolNamed("search_outline"))
        XCTAssertTrue(registry.hasToolNamed("check_connection"))
    }

    @MainActor
    func testToolDefinitionsMatchRegistry() {
        let registry = ToolRegistry.shared
        QueryTools.registerAll(in: registry)

        // Verify tool can be retrieved
        let tool = registry.tool(named: "search_outline")
        XCTAssertNotNil(tool)
        XCTAssertEqual(tool?.name, "search_outline")
    }
}
