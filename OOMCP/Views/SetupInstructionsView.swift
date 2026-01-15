import SwiftUI
import AppKit

// MARK: - Setup Window Controller

/// Controller for managing setup instruction windows.
class SetupWindowController {
    static let shared = SetupWindowController()

    private var claudeWindow: NSWindow?

    private init() {}

    func showWindow() {
        if let existing = claudeWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = createWindow()
        claudeWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() -> NSWindow {
        let contentView = SetupInstructionsView()
            .environmentObject(Preferences.shared)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Setup Claude Desktop"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false

        return window
    }
}

/// Setup instructions for Claude Desktop.
struct SetupInstructionsView: View {
    @EnvironmentObject var preferences: Preferences

    private let steps: [SetupStep] = [
        SetupStep(title: "Install mcp-remote",
                 description: "This proxy bridges HTTP servers to Claude's stdio transport:",
                 code: "npm install -g mcp-remote"),
        SetupStep(title: "Open Configuration File",
                 description: "Open ~/Library/Application Support/Claude/claude_desktop_config.json"),
        SetupStep(title: "Add Server Configuration",
                 description: "Add or update the mcpServers section:",
                 code: """
                 {
                   "mcpServers": {
                     "omnioutliner": {
                       "command": "npx",
                       "args": ["mcp-remote", "{URL}/mcp"]
                     }
                   }
                 }
                 """),
        SetupStep(title: "Save and Restart",
                 description: "Save the file and restart Claude Desktop"),
        SetupStep(title: "Enable in Developer Settings",
                 description: "Go to Settings → Developer and ensure the server is enabled")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain")
                    .font(.title)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text("Setup Claude Desktop")
                        .font(.title2.bold())
                    Text("Connect your AI assistant to OmniOutliner")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Instructions
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        StepView(number: index + 1, step: step, serverURL: preferences.serverURL)
                    }
                }
            }

            Divider()

            // Footer with copy button
            HStack {
                Button {
                    copyConfigToClipboard()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Copy Configuration")
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") {
                    closeWindow()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500, height: 450)
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }

    private func copyConfigToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preferences.claudeConfigJSON, forType: .string)
    }
}

// MARK: - Step View

struct StepView: View {
    let number: Int
    let step: SetupStep
    let serverURL: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            Circle()
                .fill(Color.accentColor)
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)

                if let description = step.description {
                    Text(description.replacingOccurrences(of: "{URL}", with: serverURL))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let code = step.code {
                    CodeBlock(code: code.replacingOccurrences(of: "{URL}", with: serverURL))
                }
            }
        }
    }
}

// MARK: - Code Block

struct CodeBlock: View {
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Setup Step

struct SetupStep {
    let title: String
    var description: String? = nil
    var code: String? = nil
}

// MARK: - Preview

#Preview("Claude Setup") {
    SetupInstructionsView()
        .environmentObject(Preferences.shared)
}
