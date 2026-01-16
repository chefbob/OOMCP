import XCTest
@testable import OOMCP

/// Tests for large document auto-limiting behavior.
/// These tests verify that documents with 500+ rows automatically return
/// only top-level rows for performance, with appropriate metadata.
///
/// These tests require a document with 500+ rows to be open in OmniOutliner.
/// The tests will be skipped if no such document is available.
final class LargeDocumentTests: XCTestCase {

    // MARK: - Configuration

    /// Threshold at which auto-limiting kicks in (must match JXAScripts.swift)
    private let autoLimitThreshold = 500

    // MARK: - Setup

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        // Check if OmniOutliner is running with a document
        let status = await OmniOutlinerBridge.shared.checkConnection()
        try XCTSkipUnless(status.appRunning, "OmniOutliner is not running")
        try XCTSkipUnless(status.documentOpen, "No document is open in OmniOutliner")
    }

    /// Helper to check if the current document is large enough for testing
    @MainActor
    private func requireLargeDocument() async throws -> Int {
        let handler = GetCurrentDocumentHandler()
        let result = try await handler.execute(arguments: nil)

        guard case .text(let text) = result.content.first,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let document = json["document"] as? [String: Any],
              let rowCount = document["rowCount"] as? Int else {
            throw XCTSkip("Could not get document info")
        }

        guard rowCount >= autoLimitThreshold else {
            throw XCTSkip("Current document has only \(rowCount) rows, need \(autoLimitThreshold)+ for large document tests. Open a document with more rows to run these tests.")
        }

        return rowCount
    }

    // MARK: - Auto-Limit Tests for getAllDocumentsContent

    func testGetAllDocumentsContentAutoLimitsLargeDocument() async throws {
        // Ensure we have a large document
        let expectedRowCount = try await requireLargeDocument()

        let handler = GetAllDocumentsContentHandler()
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false, "get_all_documents_content should succeed")

        guard case .text(let text) = result.content.first,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            XCTFail("Could not parse response")
            return
        }

        // Find the large document (first one with 500+ rows)
        guard let doc = documents.first(where: { ($0["totalRowCount"] as? Int ?? 0) >= autoLimitThreshold }) else {
            XCTFail("No large document found in response")
            return
        }

        // Verify auto-limiting behavior
        let totalRowCount = doc["totalRowCount"] as? Int ?? 0
        let rowsReturned = doc["rowsReturned"] as? Int ?? 0
        let autoLimited = doc["autoLimited"] as? Bool ?? false
        let rows = doc["rows"] as? [[String: Any]] ?? []

        print("Document: \(doc["name"] ?? "Unknown")")
        print("  totalRowCount: \(totalRowCount)")
        print("  rowsReturned: \(rowsReturned)")
        print("  autoLimited: \(autoLimited)")

        // Assertions
        XCTAssertTrue(autoLimited, "Large document should have autoLimited=true")
        XCTAssertGreaterThanOrEqual(totalRowCount, autoLimitThreshold,
            "Document should have at least \(autoLimitThreshold) rows")
        XCTAssertLessThan(rowsReturned, totalRowCount,
            "rowsReturned (\(rowsReturned)) should be less than totalRowCount (\(totalRowCount)) when auto-limited")

        // Verify only top-level rows are returned
        for row in rows {
            let level = row["level"] as? Int ?? 0
            XCTAssertEqual(level, 1, "Auto-limited results should only contain top-level (level 1) rows")
        }
    }

    func testGetAllDocumentsContentIncludesMetadataFields() async throws {
        let handler = GetAllDocumentsContentHandler()
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false)

        guard case .text(let text) = result.content.first,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]],
              let firstDoc = documents.first else {
            XCTFail("Could not parse response")
            return
        }

        // Check that the first document has the required fields
        XCTAssertNotNil(firstDoc["totalRowCount"], "Document should include totalRowCount")
        XCTAssertNotNil(firstDoc["rowsReturned"], "Document should include rowsReturned")
        XCTAssertNotNil(firstDoc["autoLimited"], "Document should include autoLimited")
    }

    // MARK: - Auto-Limit Tests for getOutlineStructure

    func testGetOutlineStructureAutoLimitsLargeDocument() async throws {
        // Ensure we have a large document
        _ = try await requireLargeDocument()

        let handler = GetOutlineStructureHandler()
        let result = try await handler.execute(arguments: nil)

        XCTAssertFalse(result.isError ?? false, "get_outline_structure should succeed")

        guard case .text(let text) = result.content.first,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let document = json["document"] as? [String: Any] else {
            XCTFail("Could not parse response")
            return
        }

        let totalRowCount = document["totalRowCount"] as? Int ?? 0
        let rowsReturned = document["rowsReturned"] as? Int ?? 0
        let autoLimited = document["autoLimited"] as? Bool ?? false
        let effectiveMaxDepth = document["effectiveMaxDepth"] as? Int
        let rows = json["rows"] as? [[String: Any]] ?? []

        print("Document: \(document["name"] ?? "Unknown")")
        print("  totalRowCount: \(totalRowCount)")
        print("  rowsReturned: \(rowsReturned)")
        print("  autoLimited: \(autoLimited)")
        print("  effectiveMaxDepth: \(effectiveMaxDepth ?? -1)")

        // Assertions
        XCTAssertTrue(autoLimited, "Large document should have autoLimited=true")
        XCTAssertEqual(effectiveMaxDepth, 1, "Auto-limited should use effectiveMaxDepth=1")
        XCTAssertLessThan(rowsReturned, totalRowCount,
            "rowsReturned (\(rowsReturned)) should be less than totalRowCount (\(totalRowCount)) when auto-limited")

        // Verify only top-level rows are returned
        for row in rows {
            let level = row["level"] as? Int ?? 0
            XCTAssertEqual(level, 1, "Auto-limited results should only contain top-level (level 1) rows")
        }
    }

    func testGetOutlineStructureWithExplicitMaxDepthBypassesAutoLimit() async throws {
        // Ensure we have a large document
        _ = try await requireLargeDocument()

        let handler = GetOutlineStructureHandler()
        // Explicitly request maxDepth=2 to bypass auto-limiting
        let args: [String: AnyCodable] = ["maxDepth": AnyCodable(2)]
        let result = try await handler.execute(arguments: args)

        XCTAssertFalse(result.isError ?? false, "get_outline_structure should succeed")

        guard case .text(let text) = result.content.first,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let document = json["document"] as? [String: Any] else {
            XCTFail("Could not parse response")
            return
        }

        // When maxDepth is explicit, autoLimited should be false/nil
        let autoLimited = document["autoLimited"] as? Bool ?? false
        XCTAssertFalse(autoLimited, "Explicit maxDepth should bypass auto-limiting")

        // Should include level 2 rows
        let rows = json["rows"] as? [[String: Any]] ?? []
        let hasLevel2 = rows.contains { ($0["level"] as? Int ?? 0) == 2 }
        XCTAssertTrue(hasLevel2, "With maxDepth=2, should include level 2 rows")
    }

    // MARK: - Performance Tests

    func testAutoLimitedPerformanceIsFast() async throws {
        // Ensure we have a large document to test auto-limiting performance
        _ = try await requireLargeDocument()

        let handler = GetAllDocumentsContentHandler()

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await handler.execute(arguments: nil)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(result.isError ?? false)

        print("get_all_documents_content completed in \(String(format: "%.3f", elapsed))s")

        // Auto-limited queries should be very fast
        XCTAssertLessThan(elapsed, 2.0,
            "Auto-limited get_all_documents_content should complete within 2 seconds")
    }
}
