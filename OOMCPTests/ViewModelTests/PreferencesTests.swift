import XCTest
@testable import OOMCP

/// Tests for Preferences view model that drives the preferences UI.
@MainActor
final class PreferencesTests: XCTestCase {

    // MARK: - Port Validation Tests

    func testValidPortRange() {
        // Valid ports: 1024-65535
        XCTAssertTrue(Preferences.isValidPort(1024))
        XCTAssertTrue(Preferences.isValidPort(3000))
        XCTAssertTrue(Preferences.isValidPort(8080))
        XCTAssertTrue(Preferences.isValidPort(65535))
    }

    func testInvalidPortTooLow() {
        XCTAssertFalse(Preferences.isValidPort(0))
        XCTAssertFalse(Preferences.isValidPort(80))
        XCTAssertFalse(Preferences.isValidPort(443))
        XCTAssertFalse(Preferences.isValidPort(1023))
    }

    func testInvalidPortTooHigh() {
        XCTAssertFalse(Preferences.isValidPort(65536))
        XCTAssertFalse(Preferences.isValidPort(70000))
        XCTAssertFalse(Preferences.isValidPort(Int.max))
    }

    func testPortValidationErrorForLowPort() {
        let error = Preferences.portValidationError(80)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("1024"))
    }

    func testPortValidationErrorForHighPort() {
        let error = Preferences.portValidationError(70000)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("65535"))
    }

    func testPortValidationErrorForValidPort() {
        XCTAssertNil(Preferences.portValidationError(3000))
        XCTAssertNil(Preferences.portValidationError(8080))
    }

    // MARK: - Server URL Tests

    func testServerURLFormat() {
        let preferences = Preferences.shared
        let url = preferences.serverURL
        XCTAssertTrue(url.hasPrefix("http://localhost:"))
        XCTAssertTrue(url.contains(String(preferences.serverPort)))
    }

    func testMCPEndpointFormat() {
        let preferences = Preferences.shared
        let endpoint = preferences.mcpEndpoint
        XCTAssertTrue(endpoint.hasPrefix("http://localhost:"))
        XCTAssertTrue(endpoint.hasSuffix("/mcp"))
    }

    // MARK: - Claude Config Tests

    func testClaudeConfigContainsMCPServers() {
        let preferences = Preferences.shared
        let config = preferences.claudeConfigJSON
        XCTAssertTrue(config.contains("mcpServers"))
    }

    func testClaudeConfigContainsOmniOutliner() {
        let preferences = Preferences.shared
        let config = preferences.claudeConfigJSON
        XCTAssertTrue(config.contains("omnioutliner"))
    }

    func testClaudeConfigContainsMCPRemote() {
        let preferences = Preferences.shared
        let config = preferences.claudeConfigJSON
        XCTAssertTrue(config.contains("mcp-remote"))
    }

    func testClaudeConfigContainsCurrentPort() {
        let preferences = Preferences.shared
        let config = preferences.claudeConfigJSON
        XCTAssertTrue(config.contains(String(preferences.serverPort)))
    }

    func testClaudeConfigIsValidJSON() {
        let preferences = Preferences.shared
        let config = preferences.claudeConfigJSON

        guard let data = config.data(using: .utf8) else {
            XCTFail("Could not convert config to data")
            return
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data)
            XCTAssertTrue(json is [String: Any])
        } catch {
            XCTFail("Invalid JSON: \(error)")
        }
    }

    // MARK: - Default Values Tests

    func testDefaultPortIsValid() {
        // After reset, port should be valid
        let preferences = Preferences.shared
        XCTAssertTrue(Preferences.isValidPort(preferences.serverPort))
    }

    // MARK: - Edge Cases

    func testPortBoundaries() {
        // Boundary testing
        XCTAssertFalse(Preferences.isValidPort(1023))  // Just below valid
        XCTAssertTrue(Preferences.isValidPort(1024))   // Minimum valid
        XCTAssertTrue(Preferences.isValidPort(65535))  // Maximum valid
        XCTAssertFalse(Preferences.isValidPort(65536)) // Just above valid
    }

    func testNegativePort() {
        XCTAssertFalse(Preferences.isValidPort(-1))
        XCTAssertFalse(Preferences.isValidPort(-3000))
    }
}
