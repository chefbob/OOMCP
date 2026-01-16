import SwiftUI

/// Main menu bar dropdown content.
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var preferences: Preferences
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status
            headerSection

            Divider()
                .padding(.vertical, 8)

            // Server control
            serverControlSection

            Divider()
                .padding(.vertical, 8)

            // Setup guides
            setupSection

            Divider()
                .padding(.vertical, 8)

            // Footer
            footerSection
        }
        .padding(12)
        .frame(width: 280)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("OmniOutliner MCP")
                    .font(.headline)

                Spacer()
            }

            StatusIndicator()
        }
    }

    private var serverControlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Server URL (copyable)
            if appState.serverStatus == .running {
                HStack {
                    Text("Server URL:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(preferences.serverURL)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)

                    Button {
                        copyToClipboard(preferences.serverURL)
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy URL to clipboard")
                }
            }

            // Start/Stop button
            Button {
                Task {
                    await appState.toggleServer()
                }
            } label: {
                HStack {
                    Image(systemName: appState.serverStatus == .running ? "stop.fill" : "play.fill")
                    Text(appState.serverStatus == .running ? "Stop Server" : "Start Server")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(appState.isTransitioning)
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Setup")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                SetupWindowController.shared.showWindow()
            } label: {
                HStack {
                    Image(systemName: "brain")
                    Text("Setup Claude")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                openPreferences()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Preferences...")
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            Divider()
                .padding(.vertical, 4)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private func openPreferences() {
        PreferencesWindowController.shared.showWindow()
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
        .environmentObject(Preferences.shared)
}
