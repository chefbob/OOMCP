import XCTest
@testable import OmniOutlinerMCP

/// Performance tests for verifying response times with large outlines.
/// Per SC-004: Response time under 2 seconds for outlines up to 5,000 rows.
///
/// These tests require OmniOutliner to be running with a large document.
/// Tests are skipped if OmniOutliner is not available or document is too small.
final class PerformanceTests: XCTestCase {

    // MARK: - Configuration

    /// Minimum number of rows required for performance testing
    private let minimumRowsForTest = 100

    /// Target response time in seconds (SC-004 requirement)
    private let targetResponseTime: TimeInterval = 2.0

    /// Large document threshold for comprehensive testing
    private let largeDocumentThreshold = 5000

    // MARK: - Setup

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        // Check if OmniOutliner is running
        let status = await OmniOutlinerBridge.shared.checkConnection()
        try XCTSkipUnless(status.appRunning, "OmniOutliner is not running")
        try XCTSkipUnless(status.documentOpen, "No document is open in OmniOutliner")
    }

    // MARK: - Get Outline Structure Performance

    func testGetOutlineStructurePerformance() async throws {
        let handler = GetOutlineStructureHandler()

        // Measure response time
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await handler.execute(arguments: nil)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(result.isError ?? false, "get_outline_structure should succeed")

        // Log performance metrics
        print("get_outline_structure completed in \(String(format: "%.3f", elapsed))s")

        // Verify response time meets target
        XCTAssertLessThan(elapsed, targetResponseTime,
            "get_outline_structure should complete within \(targetResponseTime)s, took \(elapsed)s")
    }

    func testGetOutlineStructureWithDepthLimitPerformance() async throws {
        let handler = GetOutlineStructureHandler()
        let args: [String: AnyCodable] = ["maxDepth": AnyCodable(2)]

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await handler.execute(arguments: args)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(result.isError ?? false)
        print("get_outline_structure (maxDepth=2) completed in \(String(format: "%.3f", elapsed))s")

        XCTAssertLessThan(elapsed, targetResponseTime)
    }

    // MARK: - Search Performance

    func testSearchOutlinePerformance() async throws {
        let handler = SearchOutlineHandler()
        let args: [String: AnyCodable] = [
            "query": AnyCodable("the"),  // Common word likely to have many matches
            "maxResults": AnyCodable(100)
        ]

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await handler.execute(arguments: args)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(result.isError ?? false, "search_outline should succeed")
        print("search_outline completed in \(String(format: "%.3f", elapsed))s")

        XCTAssertLessThan(elapsed, targetResponseTime,
            "search_outline should complete within \(targetResponseTime)s")
    }

    // MARK: - Get All Documents Content Performance

    func testGetAllDocumentsContentPerformance() async throws {
        let handler = GetAllDocumentsContentHandler()

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await handler.execute(arguments: nil)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(result.isError ?? false, "get_all_documents_content should succeed")
        print("get_all_documents_content completed in \(String(format: "%.3f", elapsed))s")

        // Allow slightly longer for multi-document operations
        XCTAssertLessThan(elapsed, targetResponseTime * 2,
            "get_all_documents_content should complete within \(targetResponseTime * 2)s")
    }

    // MARK: - List Documents Performance

    func testListDocumentsPerformance() async throws {
        let handler = ListDocumentsHandler()

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await handler.execute(arguments: nil)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(result.isError ?? false, "list_documents should succeed")
        print("list_documents completed in \(String(format: "%.3f", elapsed))s")

        // List documents should be very fast
        XCTAssertLessThan(elapsed, 1.0,
            "list_documents should complete within 1s")
    }

    // MARK: - Check Connection Performance

    func testCheckConnectionPerformance() async throws {
        let handler = CheckConnectionHandler()

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await handler.execute(arguments: nil)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(result.isError ?? false, "check_connection should succeed")
        print("check_connection completed in \(String(format: "%.3f", elapsed))s")

        // Connection check should be very fast
        XCTAssertLessThan(elapsed, 0.5,
            "check_connection should complete within 0.5s")
    }

    // MARK: - Get Section Content Performance

    func testGetSectionContentPerformance() async throws {
        let handler = GetSectionContentHandler()

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await handler.execute(arguments: nil)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(result.isError ?? false, "get_section_content should succeed")
        print("get_section_content completed in \(String(format: "%.3f", elapsed))s")

        XCTAssertLessThan(elapsed, targetResponseTime)
    }

    // MARK: - Repeated Operations Performance

    func testRepeatedQueryPerformance() async throws {
        let handler = GetCurrentDocumentHandler()
        let iterations = 10

        var totalTime: TimeInterval = 0

        for i in 1...iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            let result = try await handler.execute(arguments: nil)
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            totalTime += elapsed

            XCTAssertFalse(result.isError ?? false, "Iteration \(i) should succeed")
        }

        let averageTime = totalTime / Double(iterations)
        print("get_current_document average over \(iterations) iterations: \(String(format: "%.3f", averageTime))s")

        // Average should be well under target
        XCTAssertLessThan(averageTime, targetResponseTime / 2,
            "Average response time should be under \(targetResponseTime / 2)s")
    }

    // MARK: - Large Document Metrics (Informational)

    /// This test reports metrics for the current document size.
    /// It does not fail but provides useful performance data.
    func testDocumentSizeMetrics() async throws {
        // Get document info
        let docHandler = GetCurrentDocumentHandler()
        let docResult = try await docHandler.execute(arguments: nil)

        guard case .text(let docText) = docResult.content.first,
              let docData = docText.data(using: .utf8),
              let docJson = try? JSONSerialization.jsonObject(with: docData) as? [String: Any],
              let document = docJson["document"] as? [String: Any],
              let rowCount = document["rowCount"] as? Int else {
            XCTFail("Could not parse document info")
            return
        }

        print("=== Performance Test Document Metrics ===")
        print("Document name: \(document["name"] ?? "Unknown")")
        print("Row count: \(rowCount)")

        // Measure full outline retrieval
        let outlineHandler = GetOutlineStructureHandler()
        let startTime = CFAbsoluteTimeGetCurrent()
        let outlineResult = try await outlineHandler.execute(arguments: nil)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(outlineResult.isError ?? false)

        let rowsPerSecond = rowCount > 0 ? Double(rowCount) / elapsed : 0
        print("Time to retrieve full outline: \(String(format: "%.3f", elapsed))s")
        print("Rows per second: \(String(format: "%.0f", rowsPerSecond))")

        if rowCount >= largeDocumentThreshold {
            print("✅ Document meets large document threshold (\(largeDocumentThreshold) rows)")
            XCTAssertLessThan(elapsed, targetResponseTime,
                "Large document (\(rowCount) rows) should complete within \(targetResponseTime)s")
        } else {
            print("ℹ️ Document has \(rowCount) rows (threshold: \(largeDocumentThreshold) for full performance validation)")
        }

        print("==========================================")
    }
}
