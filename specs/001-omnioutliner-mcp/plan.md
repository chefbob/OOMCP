# Implementation Plan: OmniOutliner MCP Server

**Branch**: `001-omnioutliner-mcp` | **Date**: 2026-01-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-omnioutliner-mcp/spec.md`

## Summary

Build a **native macOS menu bar application** that provides MCP (Model Context Protocol) server functionality for OmniOutliner. The app runs an HTTP server that enables AI agents (primarily ChatGPT Desktop, also Claude Desktop) to query, modify, and synthesize content from OmniOutliner documents.

The implementation uses:
- **Swift/SwiftUI** for the native macOS app and menu bar UI
- **NSAppleScript** for direct JXA/Omni Automation execution
- **HTTP server** (Vapor or native URLSession) for MCP protocol

## Technical Context

**Language/Version**: Swift 5.9+ / SwiftUI
**Platform SDK**: macOS 14 SDK (supports macOS 13+, Ventura or later)
**Primary Frameworks**: SwiftUI, Foundation, OSAKit (NSAppleScript)
**HTTP Server**: Vapor 4.x or native URLSession-based server
**Storage**: N/A (reads/writes directly to OmniOutliner documents)
**Testing**: XCTest for unit tests, UI tests for menu bar interactions
**Target Platform**: macOS 12 (Monterey) or later
**Project Type**: Native macOS menu bar application
**Performance Goals**: Query response <2s, modification <2s (per SC-003)
**Constraints**: <50MB memory footprint, startup <1s, app size <10MB
**Requirements**: OmniOutliner 5 Pro (scripting/automation is a Pro-only feature)
**Scale/Scope**: Support outlines up to 5,000 rows (per SC-004)

## AI Client Compatibility

Both clients connect via HTTP to the local server:

| Client | Transport | Configuration | User Experience |
|--------|-----------|---------------|-----------------|
| ChatGPT Desktop | HTTP | Developer Mode connector | Install app → Configure once |
| Claude Desktop | HTTP | claude_desktop_config.json | Install app → Configure once |

**Note**: Claude Desktop can also use HTTP MCP servers. By standardizing on HTTP, we simplify to a single transport mode.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              OmniOutliner MCP (Native macOS App)            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  SwiftUI Menu Bar                     │  │
│  │                                                       │  │
│  │  ● Status indicator (green/yellow/red)               │  │
│  │  ● Server URL display                                │  │
│  │  ● Start/Stop toggle                                 │  │
│  │  ● "Setup ChatGPT" instructions button               │  │
│  │  ● "Setup Claude" instructions button                │  │
│  │  ● Preferences (port, auto-launch)                   │  │
│  │  ● Quit                                              │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    HTTP Server                        │  │
│  │                                                       │  │
│  │  - Vapor 4.x or URLSession-based                     │  │
│  │  - localhost:3000 (configurable)                     │  │
│  │  - MCP Streamable HTTP transport                     │  │
│  │  - JSON-RPC 2.0 message handling                     │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   MCP Tools Layer                     │  │
│  │                                                       │  │
│  │  Query Tools:                                        │  │
│  │  - get_current_document                              │  │
│  │  - get_outline_structure                             │  │
│  │  - get_row, get_row_children                         │  │
│  │  - search_outline                                    │  │
│  │                                                       │  │
│  │  Modify Tools:                                       │  │
│  │  - add_row, update_row, move_row                     │  │
│  │  - delete_row (with confirmation)                    │  │
│  │                                                       │  │
│  │  Synthesis Tools:                                    │  │
│  │  - get_section_content                               │  │
│  │  - insert_content                                    │  │
│  │                                                       │  │
│  │  Status Tools:                                       │  │
│  │  - check_connection                                  │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              OmniOutliner Integration                 │  │
│  │                                                       │  │
│  │  - NSAppleScript for JXA execution                   │  │
│  │  - Omni Automation script templates                  │  │
│  │  - JSON result parsing                               │  │
│  │  - Error handling & user-friendly messages           │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Single responsibility | PASS | One purpose: OmniOutliner ↔ AI agent bridge |
| Native experience | PASS | SwiftUI menu bar app, native macOS integration |
| Simple installation | PASS | Download DMG, drag to Applications |
| Testable | PASS | XCTest for logic, UI tests for menu bar |
| Error handling | PASS | User-friendly error messages per FR-010 |

No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/001-omnioutliner-mcp/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (MCP tool definitions)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (Xcode Project)

```text
OmniOutlinerMCP/
├── OmniOutlinerMCP.xcodeproj
├── OmniOutlinerMCP/
│   ├── App/
│   │   ├── OmniOutlinerMCPApp.swift      # @main entry point, MenuBarExtra
│   │   ├── AppState.swift                 # ObservableObject for app state
│   │   └── Preferences.swift              # UserDefaults wrapper
│   │
│   ├── Views/
│   │   ├── MenuBarView.swift              # Menu bar dropdown content
│   │   ├── StatusIndicator.swift          # Connection status view
│   │   ├── SetupInstructionsView.swift    # ChatGPT/Claude setup guides
│   │   └── PreferencesView.swift          # Settings window
│   │
│   ├── Server/
│   │   ├── MCPServer.swift                # HTTP server lifecycle
│   │   ├── MCPRouter.swift                # JSON-RPC request routing
│   │   ├── MCPProtocol.swift              # MCP message types (Codable)
│   │   └── JSONRPCHandler.swift           # JSON-RPC 2.0 implementation
│   │
│   ├── Tools/
│   │   ├── ToolRegistry.swift             # Tool registration & dispatch
│   │   ├── QueryTools.swift               # get_outline_structure, search, etc.
│   │   ├── ModifyTools.swift              # add_row, update_row, delete_row
│   │   └── SynthesisTools.swift           # get_section_content, insert_content
│   │
│   ├── OmniOutliner/
│   │   ├── OmniOutlinerBridge.swift       # NSAppleScript execution wrapper
│   │   ├── JXAScripts.swift               # Omni Automation script templates
│   │   ├── DocumentModel.swift            # Document/Row Swift types
│   │   └── OmniOutlinerError.swift        # Error types & user messages
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets                # App icon, menu bar icons
│   │   └── Localizable.strings            # User-facing strings
│   │
│   └── Info.plist                         # App configuration
│
├── OmniOutlinerMCPTests/
│   ├── ServerTests/                       # HTTP server tests
│   ├── ToolTests/                         # MCP tool logic tests
│   ├── OmniOutlinerTests/                 # JXA script tests (mocked)
│   └── IntegrationTests/                  # End-to-end with real OmniOutliner
│
└── OmniOutlinerMCPUITests/
    └── MenuBarTests.swift                 # UI automation tests
```

### Build Artifacts

```text
build/
├── OmniOutlinerMCP.app                    # Signed application bundle
├── OmniOutlinerMCP.dmg                    # Distributable disk image
└── OmniOutlinerMCP.zip                    # Notarized ZIP for direct download
```

## Key Implementation Details

### Menu Bar App Entry Point

```swift
@main
struct OmniOutlinerMCPApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.statusIcon)
        }

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}
```

### NSAppleScript for JXA Execution

```swift
class OmniOutlinerBridge {
    func execute(_ script: String) async throws -> [String: Any] {
        let appleScript = NSAppleScript(source: wrapAsJXA(script))
        var error: NSDictionary?

        guard let result = appleScript?.executeAndReturnError(&error) else {
            throw OmniOutlinerError.scriptFailed(error)
        }

        return try parseJSONResult(result)
    }

    private func wrapAsJXA(_ omniScript: String) -> String {
        // Wrap Omni Automation script for JXA execution
    }
}
```

### HTTP Server (Vapor Example)

```swift
class MCPServer {
    let app: Application
    let router: MCPRouter

    func start(port: Int) async throws {
        app.http.server.configuration.port = port
        app.post("mcp") { req async throws -> Response in
            let message = try req.content.decode(JSONRPCRequest.self)
            let result = try await self.router.handle(message)
            return try await result.encodeResponse(for: req)
        }
        try await app.startup()
    }
}
```

## User Experience Flow

### Installation (One-Time)

1. Download `OmniOutlinerMCP.dmg` from website
2. Drag app to Applications folder
3. Launch app (menu bar icon appears)
4. Grant Automation permission when prompted
5. Configure AI client (ChatGPT or Claude) - instructions in app

### Daily Usage

1. App auto-launches on login (if enabled)
2. Menu bar shows green indicator when ready
3. Open OmniOutliner document
4. Use ChatGPT/Claude to interact with outline
5. App runs silently in background

### Menu Bar States

| Icon | Color | Meaning |
|------|-------|---------|
| ● | Green | Server running, OmniOutliner connected |
| ● | Yellow | Server running, OmniOutliner not open |
| ● | Red | Server stopped |

## Distribution

### Code Signing & Notarization

- Sign with Developer ID Application certificate
- Notarize via Xcode or `notarytool`
- Staple notarization ticket to DMG

### Distribution Channels

1. **Direct Download** (Primary)
   - DMG on GitHub Releases or project website
   - User downloads, drags to Applications

2. **Homebrew Cask** (Future)
   - `brew install --cask omnioutliner-mcp`

3. **Mac App Store** (Future consideration)
   - Would require sandboxing adjustments

## Complexity Tracking

| Decision | Why Needed | Simpler Alternative Rejected Because |
|----------|------------|-------------------------------------|
| Vapor for HTTP | Full-featured HTTP server | URLSession server is more manual, less maintainable |
| NSAppleScript | Direct JXA execution | Shelling to osascript adds latency and complexity |
| Menu bar app | Always-running server for ChatGPT | CLI requires user to manually start each time |

## Dependencies

| Dependency | Purpose | Version |
|------------|---------|---------|
| Vapor | HTTP server framework | 4.x |
| SwiftUI | Menu bar UI | macOS 12+ |
| OSAKit | NSAppleScript | System framework |

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Automation permission denied | Clear first-run instructions, troubleshooting in app |
| OmniOutliner not installed | Graceful error with install link |
| Port 3000 in use | Configurable port in preferences |
| Large outline performance | Pagination, progress indication |

## Implementation Status

**Last Updated**: 2026-01-13

### Completed Phases

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Setup | COMPLETE | Xcode project, Vapor dependency, folder structure |
| Phase 2: Foundational | COMPLETE | Data models, MCP protocol, JSON-RPC, server lifecycle |
| Phase 3: US4 - Installation | COMPLETE | Menu bar app, AppState, preferences, views |
| Phase 4: US1 - Query | COMPLETE | All query tools implemented and registered |
| Phase 5: US2 - Modify | COMPLETE | All modify tools implemented and registered |
| Phase 6: US3 - Synthesis | COMPLETE | All synthesis tools implemented and registered |
| Phase 7: US5 - Status | COMPLETE | Connection polling, status indicator, notifications |
| Phase 8: Polish | IN PROGRESS | See remaining tasks below |

### Recent Bug Fixes

- **2026-01-13**: Fixed crash when OmniOutliner closes - `UNUserNotificationCenter` requires a proper app bundle; added guard for `Bundle.main.bundleIdentifier` to gracefully handle command-line execution (commit `8b25976`)

### Documentation Added

- **2026-01-13**: Added comprehensive README.md with installation, usage, tool reference, and troubleshooting (commit `8275b39`)

### Remaining Tasks (Phase 8: Polish)

| Task | Description | Status |
|------|-------------|--------|
| T030 | UI tests for menu bar interactions | Pending |
| T042 | Unit tests for QueryTools | Pending |
| T043 | Integration tests for Query | Pending |
| T054 | Unit tests for ModifyTools | Pending |
| T055 | Integration tests for Modify | Pending |
| T061 | Unit tests for SynthesisTools | Pending |
| T062 | Integration tests for Synthesis | Pending |
| T069 | Unit tests for connection status | Pending |
| T070 | Input validation hardening | Pending |
| T071 | Localhost-only server binding | Pending |
| T072 | Performance testing (5,000 rows) | Pending |
| T073 | Localized strings review | Pending |
| T074 | Code signing configuration | Pending |
| T075 | Notarization configuration | Pending |
| T076 | DMG installer creation | Pending |
| T077 | Clean install testing | Pending |
| T078 | Quickstart validation | Pending |
| T079 | Final security review | Pending |

### MVP Status

**MVP is COMPLETE** - The application can:
- Run as a menu bar app on macOS
- Start/stop HTTP server on configurable port
- Connect to OmniOutliner via JXA scripting
- Execute all 12 MCP tools (query, modify, synthesis)
- Display real-time connection status
- Handle OmniOutliner disconnection gracefully
