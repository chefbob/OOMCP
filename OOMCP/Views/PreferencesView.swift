import SwiftUI
import AppKit

// MARK: - Preferences Window Controller

/// Controller for managing the preferences window.
@MainActor
class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    private init() {}

    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = PreferencesView()
            .environmentObject(Preferences.shared)
            .environmentObject(AppState.shared)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "OmniOutliner MCP Preferences"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Preferences window view.
struct PreferencesView: View {
    @EnvironmentObject var preferences: Preferences
    @EnvironmentObject var appState: AppState

    @State private var portText: String = ""
    @State private var portError: String?
    @State private var showingResetConfirmation = false
    @State private var showingRestartAlert = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            serverTab
                .tabItem {
                    Label("Server", systemImage: "server.rack")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .padding(20)
        .frame(width: 450, height: 300)
        .onAppear {
            portText = String(preferences.serverPort)
        }
        .alert(isPresented: $showingRestartAlert) {
            restartAlert
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Start at Login", isOn: $preferences.launchAtLogin)
                    .help("Automatically launch OmniOutliner MCP when you log in")
            }

            Section {
                HStack {
                    Button("Reset to Defaults") {
                        showingResetConfirmation = true
                    }

                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset to Defaults?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                preferences.resetToDefaults()
                portText = String(preferences.serverPort)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all preferences to their default values.")
        }
    }

    // MARK: - Server Tab

    private var serverTab: some View {
        Form {
            Section {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("Port", text: $portText)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: portText) { newValue in
                            validatePort(newValue)
                        }

                    if let port = Int(portText), port != preferences.serverPort {
                        Button("Apply") {
                            applyPortChange(port)
                        }
                        .disabled(portError != nil)
                    }
                }

                if let error = portError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Text("Default port is 3000. Change only if another app is using that port.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    CompactStatusIndicator()
                }

                HStack {
                    Text("Server URL")
                    Spacer()
                    Text(preferences.serverURL)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section {
                Toggle("Debug Logging", isOn: $preferences.debugLogging)
                    .help("Log MCP requests and script execution times to Console")

                Text("When enabled, logs requests, tool calls, and timing info to Console.app. Filter by 'com.omnioutliner.mcp' to see logs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("OmniOutliner MCP")
                .font(.title.bold())

            Text("Version 0.4.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Connect your AI assistant to OmniOutliner")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            HStack(spacing: 16) {
                Link("Documentation", destination: URL(string: "https://github.com/example/omnioutliner-mcp")!)

                Link("Report Issue", destination: URL(string: "https://github.com/example/omnioutliner-mcp/issues")!)
            }
            .font(.caption)
        }
        .padding()
    }

    // MARK: - Helpers

    private func validatePort(_ value: String) {
        guard let port = Int(value) else {
            portError = "Enter a valid number"
            return
        }

        portError = Preferences.portValidationError(port)
    }

    private func applyPortChange(_ port: Int) {
        preferences.serverPort = port
        showingRestartAlert = true
    }
}

// MARK: - Restart Alert Extension

extension PreferencesView {
    var restartAlert: Alert {
        Alert(
            title: Text("Restart Required"),
            message: Text("The port change will take effect after restarting the app."),
            primaryButton: .default(Text("Quit Now")) {
                NSApp.terminate(nil)
            },
            secondaryButton: .cancel(Text("Later"))
        )
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
        .environmentObject(Preferences.shared)
        .environmentObject(AppState())
}
