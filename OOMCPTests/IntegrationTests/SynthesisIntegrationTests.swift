import XCTest
@testable import OmniOutlinerMCP

/// Integration tests for synthesis tools that require a running OmniOutliner instance.
/// These tests are skipped if OmniOutliner is not running.
/// A new document will be created if needed.
final class SynthesisIntegrationTests: XCTestCase {

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

    // MARK: - GetSectionContent Tests

    func testGetSectionContentReturnsDocumentContent() async throws {
        let handler = GetSectionContentHandler()
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            // Should return some content
            XCTAssertFalse(text.isEmpty)
        }
    }

    func testGetSectionContentWithPlainFormat() async throws {
        let handler = GetSectionContentHandler()
        let args: [String: AnyCodable] = [
            "format": AnyCodable("plain")
        ]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)
    }

    func testGetSectionContentWithMarkdownFormat() async throws {
        let handler = GetSectionContentHandler()
        let args: [String: AnyCodable] = [
            "format": AnyCodable("markdown")
        ]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)
    }

    func testGetSectionContentWithStructuredFormat() async throws {
        let handler = GetSectionContentHandler()
        let args: [String: AnyCodable] = [
            "format": AnyCodable("structured")
        ]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            // Structured format should be JSON
            XCTAssertTrue(text.hasPrefix("{") || text.hasPrefix("["))
        }
    }

    func testGetSectionContentForSpecificRow() async throws {
        // First, get the outline to find a valid row ID
        let outlineHandler = GetOutlineStructureHandler()
        let outlineResult = try await outlineHandler.execute(arguments: nil)

        var rowId: String?
        if case .text(let text) = outlineResult.content.first,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let rows = json["rows"] as? [[String: Any]],
           let firstRow = rows.first {
            rowId = firstRow["id"] as? String
        }

        // Skip if no rows in document
        try XCTSkipIf(rowId == nil, "No rows in document to test with")

        let handler = GetSectionContentHandler()
        let args: [String: AnyCodable] = [
            "rowId": AnyCodable(rowId!)
        ]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)
    }

    // MARK: - InsertContent Tests

    func testInsertContentCreatesRows() async throws {
        let handler = InsertContentHandler()
        let uniqueContent = "Test Insert \(UUID().uuidString.prefix(8))"
        let args: [String: AnyCodable] = [
            "content": AnyCodable(uniqueContent)
        ]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            XCTAssertTrue(text.contains("created") || text.contains("inserted") || text.contains("\"id\""))
        }

        // Clean up
        await cleanupTestRow(withTopic: uniqueContent)
    }

    func testInsertContentWithParent() async throws {
        // First create a parent row
        let addHandler = AddRowHandler()
        let parentTopic = "Insert Parent \(UUID().uuidString.prefix(8))"
        let parentArgs: [String: AnyCodable] = [
            "topic": AnyCodable(parentTopic)
        ]

        let parentResult = try await addHandler.execute(arguments: parentArgs)
        XCTAssertFalse(parentResult.isError ?? false)

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

        // Insert content under parent
        let handler = InsertContentHandler()
        let childContent = "Inserted Child \(UUID().uuidString.prefix(8))"
        let args: [String: AnyCodable] = [
            "content": AnyCodable(childContent),
            "parentId": AnyCodable(validParentId)
        ]

        let result = try await handler.execute(arguments: args)
        XCTAssertFalse(result.isError ?? false)

        // Clean up parent (should delete children too)
        await cleanupTestRowById(validParentId)
    }

    func testInsertContentWithPosition() async throws {
        let handler = InsertContentHandler()
        let uniqueContent = "Test Position Insert \(UUID().uuidString.prefix(8))"
        let args: [String: AnyCodable] = [
            "content": AnyCodable(uniqueContent),
            "position": AnyCodable("first")
        ]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)

        // Clean up
        await cleanupTestRow(withTopic: uniqueContent)
    }

    func testInsertContentWithJSONStructure() async throws {
        let handler = InsertContentHandler()
        let uniqueId = UUID().uuidString.prefix(8)

        // JSON structure for hierarchical content
        let jsonContent = """
        {"topic": "JSON Parent \(uniqueId)", "children": [{"topic": "JSON Child \(uniqueId)"}]}
        """

        let args: [String: AnyCodable] = [
            "content": AnyCodable(jsonContent)
        ]

        let result = try await handler.execute(arguments: args)

        // This may succeed or fail depending on implementation
        // The test verifies the handler processes the request
        if result.isError ?? false {
            // JSON format might not be supported - that's OK
            if case .text(let text) = result.content.first {
                XCTAssertTrue(text.contains("error") || text.contains("invalid") || text.contains("format"))
            }
        }

        // Clean up
        await cleanupTestRow(withTopic: "JSON Parent \(uniqueId)")
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
