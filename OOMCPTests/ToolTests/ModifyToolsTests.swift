import XCTest
@testable import OmniOutlinerMCP

final class ModifyToolsTests: XCTestCase {

    // MARK: - CreateDocument Tests

    func testCreateDocumentToolDefinition() {
        let handler = CreateDocumentHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "create_document")
        XCTAssertTrue(tool.description.contains("Create"))
        XCTAssertTrue(tool.description.contains("new"))

        // No required parameters
        XCTAssertTrue(tool.inputSchema.required?.isEmpty ?? true)

        // No parameters at all
        XCTAssertTrue(tool.inputSchema.properties?.isEmpty ?? true)
    }

    func testCreateDocumentDescriptionGuidesUserConfirmation() {
        let handler = CreateDocumentHandler()
        let tool = handler.tool

        // Verify the description includes guidance about checking existing documents
        XCTAssertTrue(tool.description.contains("get_current_document"))
        XCTAssertTrue(tool.description.contains("confirm"))
    }

    // MARK: - AddRow Tests

    func testAddRowToolDefinition() {
        let handler = AddRowHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "add_row")
        XCTAssertTrue(tool.description.contains("Add"))

        // Check required parameters
        XCTAssertTrue(tool.inputSchema.required?.contains("topic") ?? false)

        // Check all parameters
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["topic"])
        XCTAssertNotNil(properties?["note"])
        XCTAssertNotNil(properties?["parentId"])
        XCTAssertNotNil(properties?["position"])
        XCTAssertNotNil(properties?["siblingId"])
        XCTAssertNotNil(properties?["relativePosition"])

        // Check enum values
        XCTAssertEqual(properties?["position"]?.enum, ["first", "last"])
        XCTAssertEqual(properties?["relativePosition"]?.enum, ["before", "after"])
    }

    func testAddRowMissingTopicThrows() async {
        let handler = AddRowHandler()

        do {
            _ = try await handler.execute(arguments: nil)
            XCTFail("Expected error for missing topic")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
            XCTAssertEqual(error.message, "Invalid params")
            if let data = error.data?.stringValue {
                XCTAssertTrue(data.contains("topic"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAddRowMissingTopicWithEmptyArgs() async {
        let handler = AddRowHandler()

        do {
            _ = try await handler.execute(arguments: [:])
            XCTFail("Expected error for missing topic")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - UpdateRow Tests

    func testUpdateRowToolDefinition() {
        let handler = UpdateRowHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "update_row")
        XCTAssertTrue(tool.description.contains("Update"))

        // Check required parameters
        XCTAssertTrue(tool.inputSchema.required?.contains("rowId") ?? false)

        // Check parameters
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["rowId"])
        XCTAssertNotNil(properties?["topic"])
        XCTAssertNotNil(properties?["note"])
        XCTAssertNotNil(properties?["state"])

        // Check state enum values
        XCTAssertEqual(properties?["state"]?.enum, ["checked", "unchecked", "none"])
    }

    func testUpdateRowMissingRowIdThrows() async {
        let handler = UpdateRowHandler()

        do {
            _ = try await handler.execute(arguments: nil)
            XCTFail("Expected error for missing rowId")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
            XCTAssertEqual(error.message, "Invalid params")
            if let data = error.data?.stringValue {
                XCTAssertTrue(data.contains("rowId"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUpdateRowWithOnlyRowIdIsValid() async {
        // Update row should accept just rowId (though it won't change anything)
        let handler = UpdateRowHandler()
        let args: [String: AnyCodable] = ["rowId": AnyCodable("test-id")]

        // This will fail at execution (OmniOutliner not running) but should pass validation
        do {
            _ = try await handler.execute(arguments: args)
            // If OmniOutliner is running, this might succeed
        } catch let error as JSONRPCError {
            // Should not be invalid params error
            XCTAssertNotEqual(error.code, -32602)
        } catch {
            // Other errors are acceptable (e.g., OmniOutliner not running)
        }
    }

    // MARK: - MoveRow Tests

    func testMoveRowToolDefinition() {
        let handler = MoveRowHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "move_row")
        XCTAssertTrue(tool.description.contains("Move"))

        // Check required parameters
        XCTAssertTrue(tool.inputSchema.required?.contains("rowId") ?? false)

        // Check parameters
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["rowId"])
        XCTAssertNotNil(properties?["newParentId"])
        XCTAssertNotNil(properties?["position"])
        XCTAssertNotNil(properties?["siblingId"])
        XCTAssertNotNil(properties?["relativePosition"])

        // Check enum values
        XCTAssertEqual(properties?["position"]?.enum, ["first", "last"])
    }

    func testMoveRowMissingRowIdThrows() async {
        let handler = MoveRowHandler()

        do {
            _ = try await handler.execute(arguments: nil)
            XCTFail("Expected error for missing rowId")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
            XCTAssertEqual(error.message, "Invalid params")
            if let data = error.data?.stringValue {
                XCTAssertTrue(data.contains("rowId"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - DeleteRow Tests

    func testDeleteRowToolDefinition() {
        let handler = DeleteRowHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "delete_row")
        XCTAssertTrue(tool.description.contains("Delete"))
        XCTAssertTrue(tool.description.contains("destructive"))

        // Check required parameters - both rowId and confirmed are required
        XCTAssertTrue(tool.inputSchema.required?.contains("rowId") ?? false)
        XCTAssertTrue(tool.inputSchema.required?.contains("confirmed") ?? false)

        // Check parameters
        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties?["rowId"])
        XCTAssertNotNil(properties?["confirmed"])
        XCTAssertEqual(properties?["confirmed"]?.type, "boolean")
    }

    func testDeleteRowMissingRowIdThrows() async {
        let handler = DeleteRowHandler()
        let args: [String: AnyCodable] = ["confirmed": AnyCodable(true)]

        do {
            _ = try await handler.execute(arguments: args)
            XCTFail("Expected error for missing rowId")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
            XCTAssertEqual(error.message, "Invalid params")
            if let data = error.data?.stringValue {
                XCTAssertTrue(data.contains("rowId"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDeleteRowMissingConfirmedThrows() async {
        let handler = DeleteRowHandler()
        let args: [String: AnyCodable] = ["rowId": AnyCodable("test-id")]

        do {
            _ = try await handler.execute(arguments: args)
            XCTFail("Expected error for missing confirmed")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
            XCTAssertEqual(error.message, "Invalid params")
            if let data = error.data?.stringValue {
                XCTAssertTrue(data.contains("confirmed"))
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDeleteRowMissingBothParamsThrows() async {
        let handler = DeleteRowHandler()

        do {
            _ = try await handler.execute(arguments: nil)
            XCTFail("Expected error for missing parameters")
        } catch let error as JSONRPCError {
            XCTAssertEqual(error.code, -32602)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Tool Registration Tests

    @MainActor
    func testModifyToolsRegistration() {
        let registry = ToolRegistry.shared

        // Register modify tools
        ModifyTools.registerAll(in: registry)

        // Verify all modify tools are registered
        XCTAssertTrue(registry.hasToolNamed("create_document"))
        XCTAssertTrue(registry.hasToolNamed("add_row"))
        XCTAssertTrue(registry.hasToolNamed("update_row"))
        XCTAssertTrue(registry.hasToolNamed("move_row"))
        XCTAssertTrue(registry.hasToolNamed("delete_row"))
    }

    @MainActor
    func testToolCount() {
        let registry = ToolRegistry.shared
        ModifyTools.registerAll(in: registry)

        // Get all tools and check modify tools are included
        let allTools = registry.allTools()
        let modifyToolNames = ["create_document", "add_row", "update_row", "move_row", "delete_row"]

        for name in modifyToolNames {
            XCTAssertTrue(allTools.contains { $0.name == name }, "Missing tool: \(name)")
        }
    }
}
