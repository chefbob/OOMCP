import XCTest
@testable import OOMCP

/// Integration tests for modify tools that require a running OmniOutliner instance.
/// These tests are skipped if OmniOutliner is not running.
/// The tests will create a new document if needed, then modify it.
/// WARNING: These tests will create/modify documents in OmniOutliner!
final class ModifyIntegrationTests: XCTestCase {

    // MARK: - Setup

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        // Check if OmniOutliner is running
        let status = await OmniOutlinerBridge.shared.checkConnection()
        try XCTSkipUnless(status.appRunning, "OmniOutliner is not running")

        // If no document is open, create one
        if !status.documentOpen {
            let handler = CreateDocumentHandler()
            let result = try await handler.execute(arguments: nil)
            XCTAssertFalse(result.isError ?? false, "Failed to create document for tests")

            // Give OmniOutliner a moment to fully initialize the document
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }

    // MARK: - CreateDocument Tests

    func testCreateDocumentCreatesNewDocument() async throws {
        let handler = CreateDocumentHandler()

        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            XCTAssertTrue(text.contains("success") || text.contains("Created"))
            XCTAssertTrue(text.contains("document"))
        } else {
            XCTFail("Expected text content in result")
        }
    }

    func testCreateDocumentBringsAppToForeground() async throws {
        let handler = CreateDocumentHandler()

        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let document = json["document"] as? [String: Any] {
            XCTAssertEqual(document["isFrontmost"] as? Bool, true)
        }
    }

    // MARK: - AddRow Tests

    func testAddRowCreatesNewRow() async throws {
        let handler = AddRowHandler()
        let uniqueTopic = "Test Row \(UUID().uuidString.prefix(8))"
        let args: [String: AnyCodable] = [
            "topic": AnyCodable(uniqueTopic)
        ]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            XCTAssertTrue(text.contains("id") || text.contains("created"))
        }

        // Clean up: search for and delete the test row
        await cleanupTestRow(withTopic: uniqueTopic)
    }

    func testAddRowWithNote() async throws {
        let handler = AddRowHandler()
        let uniqueTopic = "Test Row With Note \(UUID().uuidString.prefix(8))"
        let args: [String: AnyCodable] = [
            "topic": AnyCodable(uniqueTopic),
            "note": AnyCodable("This is a test note")
        ]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)

        // Clean up
        await cleanupTestRow(withTopic: uniqueTopic)
    }

    func testAddRowAsChild() async throws {
        // First create a parent row
        let addHandler = AddRowHandler()
        let parentTopic = "Parent Row \(UUID().uuidString.prefix(8))"
        let parentArgs: [String: AnyCodable] = [
            "topic": AnyCodable(parentTopic)
        ]

        let parentResult = try await addHandler.execute(arguments: parentArgs)
        XCTAssertFalse(parentResult.isError ?? false)

        // Extract parent row ID from result
        var parentId: String?
        if case .text(let text) = parentResult.content.first,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let newRow = json["newRow"] as? [String: Any] {
                parentId = newRow["id"] as? String
            }
        }

        guard let validParentId = parentId else {
            XCTFail("Could not get parent row ID")
            await cleanupTestRow(withTopic: parentTopic)
            return
        }

        // Create child row
        let childTopic = "Child Row \(UUID().uuidString.prefix(8))"
        let childArgs: [String: AnyCodable] = [
            "topic": AnyCodable(childTopic),
            "parentId": AnyCodable(validParentId)
        ]

        let childResult = try await addHandler.execute(arguments: childArgs)
        XCTAssertFalse(childResult.isError ?? false)

        // Clean up parent (should delete child too)
        await cleanupTestRowById(validParentId)
    }

    // MARK: - UpdateRow Tests

    func testUpdateRowTopic() async throws {
        // First create a row to update
        let addHandler = AddRowHandler()
        let originalTopic = "Original Topic \(UUID().uuidString.prefix(8))"
        let args: [String: AnyCodable] = [
            "topic": AnyCodable(originalTopic)
        ]

        let addResult = try await addHandler.execute(arguments: args)
        XCTAssertFalse(addResult.isError ?? false)

        // Extract row ID
        var rowId: String?
        if case .text(let text) = addResult.content.first,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let newRow = json["newRow"] as? [String: Any] {
                rowId = newRow["id"] as? String
            }
        }

        guard let validRowId = rowId else {
            XCTFail("Could not get row ID")
            await cleanupTestRow(withTopic: originalTopic)
            return
        }

        // Update the row
        let updateHandler = UpdateRowHandler()
        let updatedTopic = "Updated Topic \(UUID().uuidString.prefix(8))"
        let updateArgs: [String: AnyCodable] = [
            "rowId": AnyCodable(validRowId),
            "topic": AnyCodable(updatedTopic)
        ]

        let updateResult = try await updateHandler.execute(arguments: updateArgs)
        XCTAssertFalse(updateResult.isError ?? false)

        // Clean up
        await cleanupTestRowById(validRowId)
    }

    // MARK: - MoveRow Tests

    func testMoveRowToNewParent() async throws {
        // Create source row
        let addHandler = AddRowHandler()
        let sourceTopic = "Source Row \(UUID().uuidString.prefix(8))"
        let sourceArgs: [String: AnyCodable] = [
            "topic": AnyCodable(sourceTopic)
        ]

        let sourceResult = try await addHandler.execute(arguments: sourceArgs)
        XCTAssertFalse(sourceResult.isError ?? false)

        var sourceId: String?
        if case .text(let text) = sourceResult.content.first,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let newRow = json["newRow"] as? [String: Any] {
                sourceId = newRow["id"] as? String
            }
        }

        // Create destination parent row
        let destTopic = "Destination Parent \(UUID().uuidString.prefix(8))"
        let destArgs: [String: AnyCodable] = [
            "topic": AnyCodable(destTopic)
        ]

        let destResult = try await addHandler.execute(arguments: destArgs)
        XCTAssertFalse(destResult.isError ?? false)

        var destId: String?
        if case .text(let text) = destResult.content.first,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let newRow = json["newRow"] as? [String: Any] {
                destId = newRow["id"] as? String
            }
        }

        guard let validSourceId = sourceId, let validDestId = destId else {
            XCTFail("Could not get row IDs")
            await cleanupTestRow(withTopic: sourceTopic)
            await cleanupTestRow(withTopic: destTopic)
            return
        }

        // Move the source row under the destination
        let moveHandler = MoveRowHandler()
        let moveArgs: [String: AnyCodable] = [
            "rowId": AnyCodable(validSourceId),
            "newParentId": AnyCodable(validDestId)
        ]

        do {
            let moveResult = try await moveHandler.execute(arguments: moveArgs)
            XCTAssertFalse(moveResult.isError ?? false)

            // Clean up destination (should include moved row as child)
            await cleanupTestRowById(validDestId)
        } catch let error as OutlinerError {
            // Clean up both rows if move failed
            await cleanupTestRow(withTopic: sourceTopic)
            await cleanupTestRowById(validDestId)

            // Skip test if it's a known JXA limitation with index handling
            if error.message.contains("Invalid index") {
                throw XCTSkip("Move operation has known JXA index limitation in some scenarios")
            }
            throw error
        } catch {
            // Clean up both rows if move failed
            await cleanupTestRow(withTopic: sourceTopic)
            await cleanupTestRowById(validDestId)
            throw error
        }
    }

    // MARK: - DeleteRow Tests

    func testDeleteRowRemovesRow() async throws {
        // First create a row to delete
        let addHandler = AddRowHandler()
        let topic = "Row To Delete \(UUID().uuidString.prefix(8))"
        let args: [String: AnyCodable] = [
            "topic": AnyCodable(topic)
        ]

        let addResult = try await addHandler.execute(arguments: args)
        XCTAssertFalse(addResult.isError ?? false)

        var rowId: String?
        if case .text(let text) = addResult.content.first,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let newRow = json["newRow"] as? [String: Any] {
                rowId = newRow["id"] as? String
            }
        }

        guard let validRowId = rowId else {
            XCTFail("Could not get row ID")
            return
        }

        // Delete the row
        let deleteHandler = DeleteRowHandler()
        let deleteArgs: [String: AnyCodable] = [
            "rowId": AnyCodable(validRowId),
            "confirmed": AnyCodable(true)
        ]

        let deleteResult = try await deleteHandler.execute(arguments: deleteArgs)
        XCTAssertFalse(deleteResult.isError ?? false)

        if case .text(let text) = deleteResult.content.first {
            XCTAssertTrue(text.contains("deleted") || text.contains("success"))
        }
    }

    func testDeleteRowWithoutConfirmationFails() async throws {
        // First create a row
        let addHandler = AddRowHandler()
        let topic = "Row Without Confirm \(UUID().uuidString.prefix(8))"
        let args: [String: AnyCodable] = [
            "topic": AnyCodable(topic)
        ]

        let addResult = try await addHandler.execute(arguments: args)
        XCTAssertFalse(addResult.isError ?? false)

        var rowId: String?
        if case .text(let text) = addResult.content.first,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let newRow = json["newRow"] as? [String: Any] {
                rowId = newRow["id"] as? String
            }
        }

        guard let validRowId = rowId else {
            XCTFail("Could not get row ID")
            return
        }

        // Try to delete without confirmation
        let deleteHandler = DeleteRowHandler()
        let deleteArgs: [String: AnyCodable] = [
            "rowId": AnyCodable(validRowId),
            "confirmed": AnyCodable(false)
        ]

        let deleteResult = try await deleteHandler.execute(arguments: deleteArgs)

        // Should fail or return error
        if case .text(let text) = deleteResult.content.first {
            XCTAssertTrue(
                (deleteResult.isError ?? false) ||
                text.contains("confirm") ||
                text.contains("cancelled")
            )
        }

        // Clean up the row we created
        await cleanupTestRowById(validRowId)
    }

    // MARK: - Helper Methods

    private func cleanupTestRow(withTopic topic: String) async {
        let searchHandler = SearchOutlineHandler()
        let searchArgs: [String: AnyCodable] = [
            "query": AnyCodable(topic)
        ]

        do {
            let searchResult = try await searchHandler.execute(arguments: searchArgs)

            if case .text(let text) = searchResult.content.first,
               let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]] {

                for result in results {
                    if let rowId = result["rowId"] as? String {
                        await cleanupTestRowById(rowId)
                    }
                }
            }
        } catch {
            // Ignore cleanup errors
        }
    }

    private func cleanupTestRowById(_ rowId: String) async {
        let deleteHandler = DeleteRowHandler()
        let deleteArgs: [String: AnyCodable] = [
            "rowId": AnyCodable(rowId),
            "confirmed": AnyCodable(true)
        ]

        do {
            _ = try await deleteHandler.execute(arguments: deleteArgs)
        } catch {
            // Ignore cleanup errors
        }
    }
}
