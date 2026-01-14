# OmniOutlinerMCP Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-01-13

## Active Technologies
- Swift 5.9+ / SwiftUI (001-omnioutliner-mcp)
- Vapor 4.x HTTP server
- NSAppleScript for Omni Automation (JXA) execution
- N/A for storage (reads/writes directly to OmniOutliner documents)

## Project Structure

```text
OmniOutlinerMCP/
├── OmniOutlinerMCP.xcodeproj
├── OmniOutlinerMCP/
│   ├── App/                    # Entry point, AppState, Preferences
│   ├── Views/                  # SwiftUI menu bar and settings views
│   ├── Server/                 # HTTP server, MCP protocol, JSON-RPC
│   ├── Tools/                  # MCP tool implementations
│   ├── OmniOutliner/           # NSAppleScript bridge, JXA scripts
│   └── Resources/              # Assets, localization
├── OmniOutlinerMCPTests/       # Unit and integration tests
└── OmniOutlinerMCPUITests/     # UI automation tests
```

## Commands

```bash
# Build (via Xcode or command line)
xcodebuild -scheme OmniOutlinerMCP -configuration Debug build

# Test
xcodebuild -scheme OmniOutlinerMCP test

# Archive for distribution
xcodebuild -scheme OmniOutlinerMCP -configuration Release archive
```

## Code Style

Swift: Follow Swift API Design Guidelines and SwiftLint defaults

## Constitution Principles

1. **User Experience First** - Prioritize non-technical users in all decisions
2. **Native macOS** - Use Swift/SwiftUI and native frameworks
3. **Simplicity (YAGNI)** - Only implement what's specified
4. **User-Friendly Errors** - Plain language, actionable error messages
5. **Test Coverage** - 80% coverage target for business logic
6. **Security Best Practices** - Validate inputs, prevent injection, localhost-only server
7. **Latest Stable Versions** - Keep dependencies updated, pin versions explicitly

See `.specify/memory/constitution.md` for full governance details.

## Recent Changes
- 001-omnioutliner-mcp: Native Swift/SwiftUI menu bar application
- Constitution ratified with 5 core principles

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
