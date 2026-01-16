import SwiftUI
import AppKit

@main
struct OmniOutlinerMCPApp: App {

    // MARK: - State

    @StateObject private var appState = AppState.shared
    @StateObject private var preferences = Preferences.shared

    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Body

    var body: some Scene {
        // Menu bar app
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(preferences)
        } label: {
            StatusMenuBarIcon(color: appState.statusColor)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            PreferencesView()
                .environmentObject(appState)
                .environmentObject(preferences)
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Returns true if running inside XCTest (unit tests)
    private var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (no dock icon by default)
        NSApp.setActivationPolicy(.accessory)

        // Skip auto-start when running tests to avoid polling timer blocking test completion
        guard !isRunningTests else {
            return
        }

        // Initialize tool registry with all tools
        Task { @MainActor in
            setupToolRegistry()

            // Auto-start server using the shared instance
            await AppState.shared.startServer()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        Task { @MainActor in
            await MCPServer.shared.stop()
        }
    }

    @MainActor
    private func setupToolRegistry() {
        let registry = ToolRegistry.shared
        let router = MCPRouter.shared

        // Register query tools
        QueryTools.registerAll(in: registry)

        // Register modify tools
        ModifyTools.registerAll(in: registry)

        // Register synthesis tools
        SynthesisTools.registerAll(in: registry)

        // Set registry on router
        router.setToolRegistry(registry)
    }
}

// MARK: - Status Menu Bar Icon

/// A menu bar icon that displays "OO" above "MCP" with a status color indicator.
struct StatusMenuBarIcon: View {
    let color: Color

    var body: some View {
        Image(nsImage: createStatusImage(color: NSColor(color)))
    }

    private func createStatusImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 36, height: 22)
        let image = NSImage(size: size, flipped: false) { rect in
            // Use menu bar appropriate colors
            let textColor = NSColor.black

            // Draw "OO" on top
            let ooAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: textColor
            ]
            let ooString = NSAttributedString(string: "OO", attributes: ooAttributes)
            let ooSize = ooString.size()
            let ooPoint = NSPoint(
                x: (rect.width - ooSize.width) / 2,
                y: rect.height - ooSize.height - 1
            )
            ooString.draw(at: ooPoint)

            // Draw "MCP" on bottom
            let mcpAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: textColor
            ]
            let mcpString = NSAttributedString(string: "MCP", attributes: mcpAttributes)
            let mcpSize = mcpString.size()
            let mcpPoint = NSPoint(
                x: (rect.width - mcpSize.width) / 2,
                y: 4
            )
            mcpString.draw(at: mcpPoint)

            // Draw status dot to the right
            let dotDiameter: CGFloat = 6
            let dotRect = NSRect(
                x: rect.width - dotDiameter - 2,
                y: (rect.height - dotDiameter) / 2,
                width: dotDiameter,
                height: dotDiameter
            )
            color.setFill()
            let dotPath = NSBezierPath(ovalIn: dotRect)
            dotPath.fill()

            return true
        }

        // Important: Set isTemplate to false to show colors
        image.isTemplate = false
        return image
    }
}
