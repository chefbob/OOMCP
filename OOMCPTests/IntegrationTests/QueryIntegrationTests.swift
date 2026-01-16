import XCTest
@testable import OOMCP

/// Integration tests for query tools that require a running OmniOutliner instance.
/// These tests are skipped if OmniOutliner is not running.
/// A new document will be created if needed.
final class QueryIntegrationTests: XCTestCase {

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

    // MARK: - ListDocuments Tests

    func testListDocumentsReturnsAtLeastOneDocument() async throws {
        let handler = ListDocumentsHandler()
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            XCTAssertTrue(text.contains("documents"))
            XCTAssertTrue(text.contains("totalOpen"))
            // Should have at least one document open (created in setUp if needed)
            XCTAssertFalse(text.contains("\"totalOpen\":0") || text.contains("\"totalOpen\": 0"))
        }
    }

    func testListDocumentsIncludesDocumentMetadata() async throws {
        let handler = ListDocumentsHandler()
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            // Each document should have these fields
            XCTAssertTrue(text.contains("name"))
            XCTAssertTrue(text.contains("index"))
            XCTAssertTrue(text.contains("rowCount"))
            XCTAssertTrue(text.contains("isFrontmost"))
        }
    }

    // MARK: - GetAllDocumentsContent Tests

    func testGetAllDocumentsContentReturnsContent() async throws {
        let handler = GetAllDocumentsContentHandler()
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            XCTAssertTrue(text.contains("documents"))
            // Should include document structure
            XCTAssertTrue(text.contains("name"))
            XCTAssertTrue(text.contains("rows"))
        }
    }

    func testGetAllDocumentsContentWithoutNotes() async throws {
        let handler = GetAllDocumentsContentHandler()
        let args: [String: AnyCodable] = ["includeNotes": AnyCodable(false)]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)
    }

    // MARK: - GetCurrentDocument Tests

    func testGetCurrentDocumentReturnsDocumentInfo() async throws {
        let handler = GetCurrentDocumentHandler()
        let result = try await handler.execute(arguments: nil)

        // Should return document info
        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            XCTAssertTrue(text.contains("document") || text.contains("name"))
        }
    }

    // MARK: - GetOutlineStructure Tests

    func testGetOutlineStructureReturnsRows() async throws {
        let handler = GetOutlineStructureHandler()
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            // Should contain rows array
            XCTAssertTrue(text.contains("rows") || text.contains("totalRows"))
        }
    }

    func testGetOutlineStructureWithMaxDepth() async throws {
        let handler = GetOutlineStructureHandler()
        let args: [String: AnyCodable] = ["maxDepth": AnyCodable(1)]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)
    }

    func testGetOutlineStructureWithoutNotes() async throws {
        let handler = GetOutlineStructureHandler()
        let args: [String: AnyCodable] = ["includeNotes": AnyCodable(false)]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)
    }

    // MARK: - GetRowChildren Tests

    func testGetTopLevelRows() async throws {
        let handler = GetRowChildrenHandler()

        // No rowId means get top-level rows
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            XCTAssertTrue(text.contains("children") || text.contains("rows"))
        }
    }

    // MARK: - SearchOutline Tests

    func testSearchOutlineWithNoMatches() async throws {
        let handler = SearchOutlineHandler()
        let args: [String: AnyCodable] = [
            "query": AnyCodable("xyzzy_unlikely_to_match_12345")
        ]

        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            // Should return empty results
            XCTAssertTrue(text.contains("results") || text.contains("matches"))
        }
    }

    // MARK: - CheckConnection Tests

    func testCheckConnectionReturnsConnected() async throws {
        let handler = CheckConnectionHandler()
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        if case .text(let text) = result.content.first {
            XCTAssertTrue(text.contains("connected"))
            XCTAssertTrue(text.contains("true"))
        }
    }
}
