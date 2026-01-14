# Research: OmniOutliner MCP Server

**Date**: 2026-01-13
**Branch**: `001-omnioutliner-mcp`

## Executive Summary

This document consolidates research findings for building an MCP server that connects AI agents to OmniOutliner on macOS. Key areas investigated: technology selection (Swift vs Node.js vs Go), MCP protocol implementation, OmniOutliner's automation API, ChatGPT Desktop compatibility, and distribution strategy.

**Key Decisions**:
- **Native Swift/SwiftUI menu bar app** - Best UX for non-technical macOS users
- **HTTP-only transport** - Works for both ChatGPT (primary) and Claude Desktop
- **NSAppleScript** - Direct JXA execution without shell overhead
- **DMG distribution** - Simple drag-to-install experience

---

## 1. Technology Selection

### Decision: Native Swift/SwiftUI Menu Bar App

**Rationale**: For a heavily ChatGPT user base of non-technical macOS users, a native menu bar app provides the best experience. The app auto-starts, runs silently in the background, and requires no terminal usage.

**Alternatives Considered**:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Node.js + Electron | Official MCP SDK | 150MB+ app size, not native feel | Rejected |
| Node.js + Tauri | Smaller than Electron | Still requires Node.js knowledge, Rust complexity | Rejected |
| Go | Single binary, small size | Not truly native, CGO for menu bar | Rejected |
| **Swift/SwiftUI** | Native macOS, smallest size, best UX | No official MCP SDK | **Selected** |

### Why Swift Wins for This Use Case

1. **Target audience is non-technical** - Native apps have fewer "weird" issues
2. **macOS is the only platform** - No cross-platform benefit from Node.js/Go
3. **Menu bar is primary UI** - SwiftUI MenuBarExtra is purpose-built
4. **ChatGPT is primary client** - Needs HTTP server always running; menu bar app solves this
5. **Distribution matters** - Xcode makes code signing and notarization trivial
6. **JXA is core functionality** - NSAppleScript is cleaner than shelling out

### MCP Protocol Implementation in Swift

MCP is JSON-RPC 2.0 over HTTP. Implementation requires:

1. **HTTP Server**: Vapor 4.x (lightweight, Swift-native)
2. **JSON-RPC Handler**: ~200 lines using Codable
3. **Tool Registry**: Enum-based dispatch to tool handlers
4. **Response Formatting**: Codable structs matching MCP spec

No official Swift MCP SDK exists, but the protocol is straightforward to implement directly.

---

## 2. OmniOutliner Automation API

### Decision: Use Omni Automation URLs via JXA

**Rationale**: Omni Automation is the modern approach for OmniOutliner scripting, providing full access to the object model. The URL protocol (`omnijs-run`) allows execution from external scripts.

**Alternatives Considered**:
- Direct AppleScript - Rejected: Less complete API, harder to maintain
- Native AppleScript bridge in Node.js - Rejected: Omni Automation URL protocol is preferred by Omni Group

### Critical Constraint: Single Document Access

**Finding**: OmniOutliner's automation only allows access to the **frontmost document**. There is no API to list or query all open documents.

**Impact on Design**:
- FR-002 (list all open documents) must be adjusted: can only report the current/frontmost document
- Users must manually bring documents to front for multi-document queries
- Cross-document synthesis (User Story 3, scenarios 6-7) will require user to switch documents

**Mitigation**: Document this limitation clearly in user-facing messages. The server will report only the frontmost document and prompt users to switch documents when needed.

### OmniOutliner Object Model

**Document** (top-level container):
- Properties: `name`, `fileType`, `canUndo`, `canRedo`
- Access: Only frontmost document via `document` reference
- Methods: `save()`, `close()`, `undo()`, `redo()`

**Outline** (row organization):
- Contains `columns` array and `rootItem` (invisible parent of all rows)
- Methods: `moveItems()`, `itemWithIdentifier()`, `addColumn()`
- Default columns: Status (checkbox), Topic (main text), Notes

**Item/Row** (individual entries):
- Properties: `topic` (text), `note`, `level` (depth), `state` (checkbox), `identifier`
- Hierarchy: `parent`, `children`, `descendants`, `ancestors`, `leaves`
- Methods: `addChild()`, `remove()`, `valueForColumn()`, `setValueForColumn()`

**TreeNode** (UI representation):
- Properties: `isExpanded`, `isSelected`
- Methods: `expand()`, `collapse()`
- Access via: `editor.nodeForObject(item)`

### JXA Execution Pattern

**From Node.js**:
1. Construct Omni Automation script as JavaScript string
2. URL-encode the script using `encodeURIComponent()`
3. Execute via `osascript -l JavaScript` with `openLocation()` call
4. Parse JSON result returned via stdout

**Result Communication Limitation**:
The omnijs-run protocol has limited result passing. Complex data must be returned via:
- JSON stringification within the script
- Temporary file creation (for large outputs)
- Pasteboard/clipboard interchange

**Recommendation**: Use JSON-encoded script results for all operations. Keep result payloads under 64KB to avoid osascript buffer issues.

---

## 3. Distribution Strategy

### Decision: npm Package with Desktop Extension (.mcpb)

**Rationale**: Desktop Extensions provide one-click installation for non-technical users. The .mcpb format bundles the server with built-in Node.js runtime, eliminating the need for users to install Node.js separately.

**Alternatives Considered**:
- pkg standalone executable - Rejected: Larger file size (~22MB), source code extractable
- npx-only - Rejected: Requires Node.js pre-installation
- Homebrew formula - Rejected: Still requires terminal usage

### Distribution Channels (in priority order)

1. **Desktop Extension (.mcpb)** - Primary
   - One-click installation
   - Built-in Node.js runtime
   - Secure credential storage via Keychain
   - Automatic updates

2. **npx command** - Fallback
   - `npx omnioutliner-mcp`
   - Requires Node.js installation
   - For users comfortable with terminal

3. **Manual configuration** - Advanced
   - Edit `~/Library/Application Support/Claude/claude_desktop_config.json`
   - For developers and power users

### Claude Desktop Configuration Format

```json
{
  "mcpServers": {
    "omnioutliner": {
      "command": "npx",
      "args": ["-y", "omnioutliner-mcp"]
    }
  }
}
```

### macOS Automation Permissions

**First-Run Behavior**:
When the server first attempts to control OmniOutliner, macOS will prompt the user to grant Automation permission. This is unavoidable but one-time.

**User Guidance Needed**:
- Explain why permission is needed ("to read and modify your outlines")
- Provide troubleshooting if permission denied
- Document how to re-grant in System Preferences > Privacy & Security > Automation

**Permission Scope**:
Permission is granted to the process (Node.js or Claude Desktop), not the MCP server specifically. Once granted, all future runs work without prompts.

---

## 4. ChatGPT Desktop Compatibility

### Critical Finding: Transport Incompatibility

**ChatGPT Desktop does NOT support stdio transport**. Unlike Claude Desktop which runs local MCP servers as child processes, ChatGPT Desktop only connects to MCP servers via HTTP endpoints.

| Aspect | Claude Desktop | ChatGPT Desktop |
|--------|----------------|-----------------|
| Transport | stdio (stdin/stdout) | HTTP only |
| Configuration | Local JSON file | Cloud UI (Developer Mode) |
| Server Lifecycle | Managed by Claude | User must run manually |
| Local File Support | Native | Requires localhost server |

### Decision: Dual Transport Architecture

**Rationale**: To support both clients, the MCP server must implement two transport layers:
1. **stdio** for Claude Desktop (default mode)
2. **HTTP (Streamable HTTP)** for ChatGPT Desktop

The tool implementations remain shared; only the transport layer differs.

**Alternatives Considered**:
- HTTP-only - Rejected: Claude Desktop's stdio is simpler and auto-managed
- mcp.run integration - Rejected: Adds external dependency, less control
- Separate codebases - Rejected: Duplicates effort, harder to maintain

### ChatGPT Desktop Configuration

**Prerequisites**:
- ChatGPT Desktop with Developer Mode (Business/Enterprise/Education, or Pro/Plus)
- Server running on localhost

**Setup Steps**:
1. Run server: `npx omnioutliner-mcp --http`
2. In ChatGPT: Settings → Connectors → Advanced → Enable Developer Mode
3. Settings → Connectors → Create
4. Configure connector:
   - Name: "OmniOutliner"
   - Server URL: `http://localhost:3000`
   - Authentication: None (local server)

### HTTP Transport Implementation

**Protocol**: MCP Streamable HTTP transport
- Endpoint: `http://localhost:3000/mcp` (or configurable port)
- Methods: POST for tool calls, GET for server info
- Format: JSON-RPC 2.0 over HTTP
- CORS: Enabled for local development

**Server Requirements**:
- Express.js for HTTP server
- Stateless request handling
- JSON-RPC message parsing
- Same tool handlers as stdio mode

### User Experience Implications

**For ChatGPT Users** (more complex than Claude):
1. Must start server manually before using tools
2. Server must remain running during conversation
3. Configuration done via UI (not file)
4. No one-click installation option

**Mitigations**:
- Clear quickstart guide with copy-paste commands
- Server startup message confirms readiness
- Background run option: `nohup npx omnioutliner-mcp --http &`
- Future: macOS launch agent for auto-start

---

## 5. Technical Decisions Summary

| Area | Decision | Rationale |
|------|----------|-----------|
| Language | Swift 5.9+ / SwiftUI | Native macOS, smallest footprint, best UX |
| App Type | Menu bar application | Always-running server, no terminal needed |
| HTTP Server | Vapor 4.x | Swift-native, lightweight, well-maintained |
| MCP Protocol | Custom implementation | JSON-RPC 2.0 is simple; no Swift SDK needed |
| Transport | HTTP only | Works for both ChatGPT and Claude |
| OmniOutliner API | Omni Automation | Full object model access |
| JXA Execution | NSAppleScript | Direct execution, no shell overhead |
| Distribution | DMG installer | Drag-to-install, native macOS experience |
| Code Signing | Developer ID + Notarization | Required for Gatekeeper, handled by Xcode |

---

## 6. Open Items for Implementation

1. **Document the single-document limitation** in user-facing help text
2. **Test NSAppleScript result size limits** during implementation
3. **Implement MCP JSON-RPC protocol** in Swift using Codable
4. **Design error messages** for common failures (OmniOutliner not running, permission denied, no document open)
5. **Validate NSAppleScript performance** with 5,000-row outlines
6. **Set up Vapor HTTP server** with MCP endpoint routing
7. **Test ChatGPT Developer Mode** connector configuration
8. **Implement auto-launch on login** via Login Items or LaunchAgent
9. **Design menu bar UI** with status indicators and setup instructions
10. **Set up Xcode project** with proper entitlements for automation
11. **Configure code signing** with Developer ID certificate
12. **Create DMG installer** with background image and Applications alias

---

## Sources

### MCP SDK
- [GitHub - modelcontextprotocol/typescript-sdk](https://github.com/modelcontextprotocol/typescript-sdk)
- [Build an MCP server - Model Context Protocol](https://modelcontextprotocol.io/docs/develop/build-server)
- [Tools - Model Context Protocol Specification](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)

### OmniOutliner Automation
- [Using Omni Automation with JXA and AppleScript](https://omni-automation.com/jxa-applescript.html)
- [OmniOutliner: Items API](https://omni-automation.com/omnioutliner/item.html)
- [OmniOutliner: Document API](https://omni-automation.com/omnioutliner/document.html)
- [OmniOutliner: Outline API](https://omni-automation.com/omnioutliner/outline.html)

### Distribution (Claude Desktop)
- [One-click MCP server installation for Claude Desktop](https://www.anthropic.com/engineering/desktop-extensions)
- [Connect to local MCP servers - Model Context Protocol](https://modelcontextprotocol.io/docs/develop/connect-local-servers)
- [Getting Started with Local MCP Servers on Claude Desktop](https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop)

### ChatGPT Desktop
- [Developer mode and MCP apps in ChatGPT - OpenAI Help Center](https://help.openai.com/en/articles/12584461-developer-mode-apps-and-full-mcp-connectors-in-chatgpt-beta)
- [Build your MCP server - OpenAI Apps SDK](https://developers.openai.com/apps-sdk/build/mcp-server/)
- [Connect from ChatGPT - OpenAI Developer](https://developers.openai.com/apps-sdk/deploy/connect-chatgpt/)
- [ChatGPT MCP Clients - mcp.run](https://docs.mcp.run/mcp-clients/chatgpt-desktop/)

### Swift/SwiftUI Development
- [MenuBarExtra - Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/menubarextra)
- [NSAppleScript - Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsapplescript)
- [Vapor Documentation](https://docs.vapor.codes/)
- [Notarizing macOS Software - Apple Developer](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
