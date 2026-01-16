import XCTest
@testable import OOMCP

final class ConnectionStatusTests: XCTestCase {

    // MARK: - ConnectionStatus Model Tests

    func testConnectionStatusInitialization() {
        let status = ConnectionStatus(
            connected: true,
            appRunning: true,
            documentOpen: true,
            documentName: "Test Document",
            message: "Connected successfully"
        )

        XCTAssertTrue(status.connected)
        XCTAssertTrue(status.appRunning)
        XCTAssertTrue(status.documentOpen)
        XCTAssertEqual(status.documentName, "Test Document")
        XCTAssertEqual(status.message, "Connected successfully")
        XCTAssertFalse(status.proRequired)
    }

    func testConnectionStatusWithProRequired() {
        let status = ConnectionStatus(
            connected: false,
            appRunning: true,
            documentOpen: false,
            documentName: nil,
            message: "OmniOutliner Pro required",
            proRequired: true
        )

        XCTAssertFalse(status.connected)
        XCTAssertTrue(status.appRunning)
        XCTAssertFalse(status.documentOpen)
        XCTAssertNil(status.documentName)
        XCTAssertTrue(status.proRequired)
    }

    func testConnectionStatusEquality() {
        let status1 = ConnectionStatus(
            connected: true,
            appRunning: true,
            documentOpen: true,
            documentName: "Doc",
            message: "OK"
        )

        let status2 = ConnectionStatus(
            connected: true,
            appRunning: true,
            documentOpen: true,
            documentName: "Doc",
            message: "OK"
        )

        let status3 = ConnectionStatus(
            connected: false,
            appRunning: true,
            documentOpen: true,
            documentName: "Doc",
            message: "OK"
        )

        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, status3)
    }

    func testConnectionStatusCodable() throws {
        let original = ConnectionStatus(
            connected: true,
            appRunning: true,
            documentOpen: true,
            documentName: "Test.ooutline",
            message: "All good"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ConnectionStatus.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testConnectionStatusCodableWithNilDocumentName() throws {
        let original = ConnectionStatus(
            connected: false,
            appRunning: false,
            documentOpen: false,
            documentName: nil,
            message: "OmniOutliner not running"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ConnectionStatus.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertNil(decoded.documentName)
    }

    // MARK: - CheckConnection Tool Tests

    func testCheckConnectionToolHasNoRequiredParams() {
        let handler = CheckConnectionHandler()
        let tool = handler.tool

        XCTAssertNil(tool.inputSchema.required)
        XCTAssertNil(tool.inputSchema.properties)
    }

    func testCheckConnectionToolDescription() {
        let handler = CheckConnectionHandler()
        let tool = handler.tool

        XCTAssertEqual(tool.name, "check_connection")
        XCTAssertTrue(tool.description.contains("OmniOutliner"))
        XCTAssertTrue(tool.description.contains("running") || tool.description.contains("accessible"))
    }

    // MARK: - Status Message Tests

    func testNotRunningMessage() {
        let status = ConnectionStatus(
            connected: false,
            appRunning: false,
            documentOpen: false,
            documentName: nil,
            message: "OmniOutliner is not running. Please launch OmniOutliner and open a document."
        )

        XCTAssertFalse(status.connected)
        XCTAssertFalse(status.appRunning)
        XCTAssertTrue(status.message.contains("not running"))
    }

    func testNoDocumentOpenMessage() {
        let status = ConnectionStatus(
            connected: false,
            appRunning: true,
            documentOpen: false,
            documentName: nil,
            message: "OmniOutliner is running but no document is open. Please open a document."
        )

        XCTAssertFalse(status.connected)
        XCTAssertTrue(status.appRunning)
        XCTAssertFalse(status.documentOpen)
        XCTAssertTrue(status.message.contains("no document"))
    }

    func testConnectedMessage() {
        let status = ConnectionStatus(
            connected: true,
            appRunning: true,
            documentOpen: true,
            documentName: "Project Plan",
            message: "Connected to OmniOutliner. Document 'Project Plan' is open."
        )

        XCTAssertTrue(status.connected)
        XCTAssertTrue(status.appRunning)
        XCTAssertTrue(status.documentOpen)
        XCTAssertEqual(status.documentName, "Project Plan")
        XCTAssertTrue(status.message.contains("Connected"))
    }

    // MARK: - ServerStatus Tests

    func testServerStatusIsError() {
        let running = ServerStatus.running
        let stopped = ServerStatus.stopped
        let starting = ServerStatus.starting
        let stopping = ServerStatus.stopping
        let error = ServerStatus.error("Something went wrong")

        XCTAssertFalse(running.isError)
        XCTAssertFalse(stopped.isError)
        XCTAssertFalse(starting.isError)
        XCTAssertFalse(stopping.isError)
        XCTAssertTrue(error.isError)
    }

    func testServerStatusErrorMessage() {
        let error = ServerStatus.error("Port already in use")

        if case .error(let message) = error {
            XCTAssertEqual(message, "Port already in use")
        } else {
            XCTFail("Expected error status")
        }
    }
}
