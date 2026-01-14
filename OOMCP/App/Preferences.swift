import Foundation
import Combine
import ServiceManagement
#if canImport(AppKit)
import AppKit
#endif

/// User preferences for the OmniOutliner MCP application.
@MainActor
final class Preferences: ObservableObject {

    // MARK: - Singleton

    static let shared = Preferences()

    // MARK: - Keys

    private enum Keys {
        static let serverPort = "serverPort"
        static let launchAtLogin = "launchAtLogin"
        static let debugLogging = "debugLogging"
    }

    // MARK: - Defaults

    private enum Defaults {
        static let serverPort = 3000
        static let launchAtLogin = false
        static let debugLogging = false
    }

    // MARK: - Published Properties

    /// Server port number (default: 3000)
    @Published var serverPort: Int {
        didSet {
            UserDefaults.standard.set(serverPort, forKey: Keys.serverPort)
        }
    }

    /// Whether to launch at login
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    /// Whether to enable debug logging to Console
    @Published var debugLogging: Bool {
        didSet {
            UserDefaults.standard.set(debugLogging, forKey: Keys.debugLogging)
        }
    }

    // MARK: - Initialization

    private init() {
        // Load saved preferences or use defaults
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Keys.serverPort) != nil {
            self.serverPort = defaults.integer(forKey: Keys.serverPort)
        } else {
            self.serverPort = Defaults.serverPort
        }

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.debugLogging = defaults.bool(forKey: Keys.debugLogging)
    }

    // MARK: - Reset

    /// Reset all preferences to defaults
    func resetToDefaults() {
        serverPort = Defaults.serverPort
        launchAtLogin = Defaults.launchAtLogin
        debugLogging = Defaults.debugLogging
    }

    // MARK: - Launch at Login

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }

    /// Check current launch at login status from system
    var isRegisteredForLaunchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Validation

    /// Validate port number
    static func isValidPort(_ port: Int) -> Bool {
        port >= 1024 && port <= 65535
    }

    /// Get error message for invalid port
    static func portValidationError(_ port: Int) -> String? {
        if port < 1024 {
            return "Port must be 1024 or higher"
        }
        if port > 65535 {
            return "Port must be 65535 or lower"
        }
        return nil
    }
}

// MARK: - Server URL Helpers

extension Preferences {
    /// Get the server URL for current port
    var serverURL: String {
        "http://localhost:\(serverPort)"
    }

    /// Get the MCP endpoint URL
    var mcpEndpoint: String {
        "http://localhost:\(serverPort)/mcp"
    }

    /// Get Claude Desktop configuration JSON (using mcp-remote proxy)
    var claudeConfigJSON: String {
        """
        {
          "mcpServers": {
            "omnioutliner": {
              "command": "npx",
              "args": ["mcp-remote", "\(mcpEndpoint)"]
            }
          }
        }
        """
    }
}
