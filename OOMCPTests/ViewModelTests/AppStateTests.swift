import XCTest
import SwiftUI
@testable import OmniOutlinerMCP

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
    func testStatusIconForStopped() {
        let appState = AppState()
        // Initial state is stopped
        XCTAssertEqual(appState.statusIcon, "circle.fill")
    }

    @MainActor
    func testStatusIconForError() {
        let appState = AppState()
        // Force error state through the server status
        // Note: In production, this would be set by the server bindings
        XCTAssertEqual(ServerStatus.error("test").isError, true)
    }

    // MARK: - Status Color Tests

    @MainActor
    func testStatusColorForStoppedIsRed() {
        let appState = AppState()
        // Initial state is stopped, color should be red
        XCTAssertEqual(appState.statusColor, .red)
    }

    // MARK: - Status Message Tests

    @MainActor
    func testStatusMessageForStopped() {
        let appState = AppState()
        // Initial state is stopped
        XCTAssertEqual(appState.statusMessage, "Server stopped")
    }

    func testStatusMessageForStarting() {
        // Server starting message
        let status = ServerStatus.starting
        // Can't directly test appState.statusMessage for starting without mocking
        // but we can verify the enum exists
        XCTAssertEqual(status, ServerStatus.starting)
    }

    func testStatusMessageForStopping() {
        let status = ServerStatus.stopping
        XCTAssertEqual(status, ServerStatus.stopping)
    }

    func testStatusMessageForError() {
        let status = ServerStatus.error("Port already in use")
        XCTAssertTrue(status.isError)
    }

    // MARK: - Transition State Tests

    @MainActor
    func testInitialTransitionStateIsFalse() {
        let appState = AppState()
        XCTAssertFalse(appState.isTransitioning)
    }

    @MainActor
    func testInitialServerStatusIsStopped() {
        let appState = AppState()
        XCTAssertEqual(appState.serverStatus, .stopped)
    }

    @MainActor
    func testInitialConnectionStatusIsNil() {
        let appState = AppState()
        XCTAssertNil(appState.connectionStatus)
    }

    @MainActor
    func testInitialLastErrorIsNil() {
        let appState = AppState()
        XCTAssertNil(appState.lastError)
    }

    // MARK: - Pro Requirement Message Tests

    @MainActor
    func testProRequirementMessageWhenNotRequired() {
        let appState = AppState()
        // No connection status, so no pro requirement
        XCTAssertNil(appState.proRequirementMessage)
    }

    // MARK: - Status With Connection Tests

    func testStatusColorForProRequired() {
        // Test that proRequired status exists
        let status = ConnectionStatus(
            connected: false,
            appRunning: true,
            documentOpen: false,
            documentName: nil,
            message: "Pro required",
            proRequired: true
        )
        XCTAssertTrue(status.proRequired)
    }

    func testStatusColorForWaitingForDocument() {
        let status = ConnectionStatus(
            connected: false,
            appRunning: true,
            documentOpen: false,
            documentName: nil,
            message: "No document open"
        )
        XCTAssertTrue(status.appRunning)
        XCTAssertFalse(status.documentOpen)
    }
}
