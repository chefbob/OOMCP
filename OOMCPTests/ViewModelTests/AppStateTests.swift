import XCTest
import SwiftUI
@testable import OOMCP

/// Tests for AppState view model that drives the menu bar UI.
/// These tests verify the state management logic for menu bar interactions.
final class AppStateTests: XCTestCase {

    // MARK: - Server Status Tests

    func testServerStatusStoppedInitialState() {
        // ServerStatus should have a stopped case
        let status = ServerStatus.stopped
        XCTAssertFalse(status.isError)
    }

    func testServerStatusRunningState() {
        let status = ServerStatus.running
        XCTAssertFalse(status.isError)
    }

    func testServerStatusStartingState() {
        let status = ServerStatus.starting
        XCTAssertFalse(status.isError)
    }

    func testServerStatusStoppingState() {
        let status = ServerStatus.stopping
        XCTAssertFalse(status.isError)
    }

    func testServerStatusErrorState() {
        let status = ServerStatus.error("Test error")
        XCTAssertTrue(status.isError)
    }

    func testServerStatusEquality() {
        XCTAssertEqual(ServerStatus.stopped, ServerStatus.stopped)
        XCTAssertEqual(ServerStatus.running, ServerStatus.running)
        XCTAssertEqual(ServerStatus.starting, ServerStatus.starting)
        XCTAssertEqual(ServerStatus.stopping, ServerStatus.stopping)
        XCTAssertEqual(ServerStatus.error("test"), ServerStatus.error("test"))

        XCTAssertNotEqual(ServerStatus.stopped, ServerStatus.running)
        XCTAssertNotEqual(ServerStatus.error("a"), ServerStatus.error("b"))
    }

    // MARK: - Status Icon Tests

    @MainActor
    func testStatusIconValues() {
        // Test that statusIcon returns valid SF Symbol names for the shared instance
        let icon = AppState.shared.statusIcon
        XCTAssertFalse(icon.isEmpty, "Status icon should not be empty")
        // Valid icons are: circle.fill, circle.dotted, exclamationmark.circle.fill
        let validIcons = ["circle.fill", "circle.dotted", "exclamationmark.circle.fill"]
        XCTAssertTrue(validIcons.contains(icon), "Status icon '\(icon)' should be a valid SF Symbol")
    }

    func testStatusIconExpectedValues() {
        // Document the expected icon names for each status
        // These are SF Symbol names used in the menu bar
        let expectedCircleFill = "circle.fill"       // Used for stopped, running states
        let expectedDotted = "circle.dotted"         // Used for transitional states
        let expectedError = "exclamationmark.circle.fill"  // Used for error state

        // Verify these are valid SF Symbol name patterns
        XCTAssertFalse(expectedCircleFill.isEmpty)
        XCTAssertFalse(expectedDotted.isEmpty)
        XCTAssertFalse(expectedError.isEmpty)
    }

    // MARK: - Status Color Tests

    @MainActor
    func testStatusColorIsValid() {
        // Test that statusColor returns a valid Color for the shared instance
        let color = AppState.shared.statusColor
        // Color should be one of: .red, .green, .yellow, .orange
        // We can't easily compare Colors, so just verify it doesn't crash
        XCTAssertNotNil(color)
    }

    // MARK: - Status Message Tests

    @MainActor
    func testStatusMessageIsNotEmpty() {
        // Test that statusMessage returns a non-empty string
        let message = AppState.shared.statusMessage
        XCTAssertFalse(message.isEmpty, "Status message should not be empty")
    }

    func testServerStatusErrorPreservesMessage() {
        let errorMessage = "Port already in use"
        let status = ServerStatus.error(errorMessage)

        XCTAssertTrue(status.isError)

        // Verify the error message is preserved in the enum
        if case .error(let message) = status {
            XCTAssertEqual(message, errorMessage)
        } else {
            XCTFail("Expected error status with message")
        }
    }

    func testServerStatusErrorMessagesAreDistinct() {
        let error1 = ServerStatus.error("Error A")
        let error2 = ServerStatus.error("Error B")
        let error1Copy = ServerStatus.error("Error A")

        XCTAssertNotEqual(error1, error2, "Different error messages should not be equal")
        XCTAssertEqual(error1, error1Copy, "Same error messages should be equal")
    }

    func testAllServerStatusIsErrorValues() {
        // Verify isError returns correct value for all status types
        XCTAssertFalse(ServerStatus.stopped.isError)
        XCTAssertFalse(ServerStatus.starting.isError)
        XCTAssertFalse(ServerStatus.running.isError)
        XCTAssertFalse(ServerStatus.stopping.isError)
        XCTAssertTrue(ServerStatus.error("any message").isError)
    }

    // MARK: - Shared Instance State Tests

    @MainActor
    func testSharedInstanceIsTransitioningAccessible() {
        // Verify isTransitioning property is accessible on shared instance
        let isTransitioning = AppState.shared.isTransitioning
        // Value depends on current state, just verify access works
        XCTAssertNotNil(isTransitioning as Bool?)
    }

    @MainActor
    func testSharedInstanceServerStatusAccessible() {
        // Verify serverStatus property is accessible on shared instance
        let status = AppState.shared.serverStatus
        // Value depends on current state (likely .running since app auto-starts server)
        XCTAssertNotNil(status as ServerStatus?)
    }

    @MainActor
    func testSharedInstanceConnectionStatusAccessible() {
        // Verify connectionStatus property is accessible on shared instance
        // May be nil or have a value depending on OmniOutliner state
        _ = AppState.shared.connectionStatus
        // No assertion - just verify access doesn't crash
    }

    @MainActor
    func testSharedInstanceLastErrorAccessible() {
        // Verify lastError property is accessible on shared instance
        _ = AppState.shared.lastError
        // No assertion - just verify access doesn't crash
    }

    // MARK: - Pro Requirement Message Tests

    @MainActor
    func testProRequirementMessageAccessible() {
        // Verify proRequirementMessage computed property works
        let message = AppState.shared.proRequirementMessage
        // Should be nil unless proRequired is true in connectionStatus
        if AppState.shared.connectionStatus?.proRequired != true {
            XCTAssertNil(message)
        }
    }

    // MARK: - Status With Connection Tests

    func testConnectionStatusProRequired() {
        let status = ConnectionStatus(
            connected: false,
            appRunning: true,
            documentOpen: false,
            documentName: nil,
            message: "Pro required",
            proRequired: true
        )

        XCTAssertTrue(status.proRequired)
        XCTAssertFalse(status.connected, "Pro required should not be connected")
        XCTAssertTrue(status.appRunning, "App should be running when pro is required")
    }

    func testConnectionStatusWaitingForDocument() {
        let status = ConnectionStatus(
            connected: false,
            appRunning: true,
            documentOpen: false,
            documentName: nil,
            message: "No document open"
        )

        XCTAssertFalse(status.connected)
        XCTAssertTrue(status.appRunning)
        XCTAssertFalse(status.documentOpen)
        XCTAssertNil(status.documentName)
    }

    func testConnectionStatusFullyConnected() {
        let status = ConnectionStatus(
            connected: true,
            appRunning: true,
            documentOpen: true,
            documentName: "MyOutline.ooutline",
            message: "Connected"
        )

        XCTAssertTrue(status.connected)
        XCTAssertTrue(status.appRunning)
        XCTAssertTrue(status.documentOpen)
        XCTAssertEqual(status.documentName, "MyOutline.ooutline")
        XCTAssertFalse(status.proRequired)
    }

    func testConnectionStatusAppNotRunning() {
        let status = ConnectionStatus(
            connected: false,
            appRunning: false,
            documentOpen: false,
            documentName: nil,
            message: "OmniOutliner not running"
        )

        XCTAssertFalse(status.connected)
        XCTAssertFalse(status.appRunning)
        XCTAssertFalse(status.documentOpen)
        XCTAssertEqual(status.message, "OmniOutliner not running")
    }

    func testConnectionStatusDefaultProRequired() {
        // Test that proRequired defaults to false when not specified
        let status = ConnectionStatus(
            connected: true,
            appRunning: true,
            documentOpen: true,
            documentName: "Test.ooutline",
            message: "Connected"
        )

        XCTAssertFalse(status.proRequired, "proRequired should default to false")
    }
}
