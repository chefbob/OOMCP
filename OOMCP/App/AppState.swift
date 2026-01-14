import Foundation
import SwiftUI
import Combine

/// Observable state for the OmniOutliner MCP application.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Published Properties

    /// Current server status
    @Published private(set) var serverStatus: ServerStatus = .stopped

    /// Connection status to OmniOutliner
    @Published private(set) var connectionStatus: ConnectionStatus?

    /// Last error message
    @Published var lastError: String?

    /// Whether the server is currently starting/stopping
    @Published private(set) var isTransitioning = false

    // MARK: - Properties

    private let server = MCPServer.shared
    private var connectionCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// Icon name for the menu bar based on current status
    var statusIcon: String {
        switch serverStatus {
        case .running:
            if connectionStatus?.connected == true {
                return "circle.fill" // Green
            } else {
                return "circle.fill" // Yellow (different color in view)
            }
        case .stopped:
            return "circle.fill" // Red
        case .starting, .stopping:
            return "circle.dotted"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }

    /// Color for the status indicator
    var statusColor: Color {
        switch serverStatus {
        case .running:
            if connectionStatus?.connected == true {
                return .green
            } else if connectionStatus?.proRequired == true {
                return .red
            } else {
                return .yellow
            }
        case .stopped:
            return .red
        case .starting, .stopping:
            return .orange
        case .error:
            return .red
        }
    }

    /// Human-readable status message
    var statusMessage: String {
        switch serverStatus {
        case .running:
            if let conn = connectionStatus {
                if conn.connected {
                    return "Connected to \(conn.documentName ?? "OmniOutliner")"
                } else if conn.proRequired {
                    return "OmniOutliner Pro required"
                } else if conn.appRunning {
                    return "Waiting for document"
                } else {
                    return "OmniOutliner not running"
                }
            }
            return "Server running"
        case .stopped:
            return "Server stopped"
        case .starting:
            return "Starting server..."
        case .stopping:
            return "Stopping server..."
        case .error(let message):
            return message
        }
    }

    /// Detailed status message for Pro requirement
    var proRequirementMessage: String? {
        if connectionStatus?.proRequired == true {
            return "Scripting is a Pro-only feature. Please upgrade to OmniOutliner Pro, or subscribe to OmniOutliner or Omni Pro."
        }
        return nil
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Observe server state changes
        server.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                if isRunning {
                    self?.serverStatus = .running
                    self?.startConnectionPolling()
                } else {
                    self?.serverStatus = .stopped
                    self?.stopConnectionPolling()
                    self?.connectionStatus = nil
                }
            }
            .store(in: &cancellables)

        server.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.lastError = error
                    self?.serverStatus = .error(error)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Server Control

    /// Start the MCP server
    func startServer() async {
        guard !isTransitioning else { return }

        isTransitioning = true
        serverStatus = .starting
        lastError = nil

        do {
            let port = Preferences.shared.serverPort
            try await server.start(port: port)
            serverStatus = .running
        } catch {
            lastError = error.localizedDescription
            serverStatus = .error(error.localizedDescription)
        }

        isTransitioning = false
    }

    /// Stop the MCP server
    func stopServer() async {
        guard !isTransitioning else { return }

        isTransitioning = true
        serverStatus = .stopping

        await server.stop()
        serverStatus = .stopped

        isTransitioning = false
    }

    /// Toggle server state
    func toggleServer() async {
        if serverStatus == .running {
            await stopServer()
        } else if serverStatus == .stopped || serverStatus.isError {
            await startServer()
        }
    }

    /// Restart the server with a new port
    func restartServer(port: Int) async {
        guard !isTransitioning else { return }

        isTransitioning = true
        serverStatus = .stopping

        do {
            try await server.restart(port: port)
            serverStatus = .running
        } catch {
            lastError = error.localizedDescription
            serverStatus = .error(error.localizedDescription)
        }

        isTransitioning = false
    }

    // MARK: - Connection Polling

    private func startConnectionPolling() {
        // Check connection immediately
        Task {
            await checkConnection()
        }

        // Poll every 5 seconds
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkConnection()
            }
        }
    }

    private func stopConnectionPolling() {
        connectionCheckTimer?.invalidate()
        connectionCheckTimer = nil
    }

    /// Check connection to OmniOutliner
    func checkConnection() async {
        let bridge = OmniOutlinerBridge.shared
        let status = await bridge.checkConnection()

        // Notify if connection was lost
        if let previousStatus = connectionStatus,
           previousStatus.connected && !status.connected {
            notifyConnectionLost()
        }

        connectionStatus = status
    }

    private func notifyConnectionLost() {
        // UNUserNotificationCenter requires a proper app bundle to work.
        // When running from SPM build directory or command line, skip notifications.
        guard Bundle.main.bundleIdentifier != nil else {
            print("Connection lost: \(connectionStatus?.message ?? "OmniOutliner disconnected")")
            return
        }

        // Post a user notification about lost connection
        let content = UNMutableNotificationContent()
        content.title = "OmniOutliner Disconnected"
        content.body = connectionStatus?.message ?? "Connection to OmniOutliner was lost."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "connection-lost", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cleanup

    func cleanup() {
        stopConnectionPolling()
        Task {
            await stopServer()
        }
    }
}

// MARK: - Server Status Enum

enum ServerStatus: Equatable {
    case stopped
    case starting
    case running
    case stopping
    case error(String)

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    static func == (lhs: ServerStatus, rhs: ServerStatus) -> Bool {
        switch (lhs, rhs) {
        case (.stopped, .stopped),
             (.starting, .starting),
             (.running, .running),
             (.stopping, .stopping):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - UserNotifications Import

import UserNotifications
