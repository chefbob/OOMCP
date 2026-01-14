# OmniOutliner MCP

A Model Context Protocol (MCP) server that enables AI assistants to read and modify OmniOutliner documents.

## Overview

OmniOutliner MCP runs as a macOS menu bar application, providing a localhost HTTP server that exposes OmniOutliner's scripting capabilities through the MCP protocol. This allows AI tools like Claude to interact with your outlines - reading content, searching, adding items, and reorganizing structure.

## Requirements

- macOS 13.0 or later
- OmniOutliner Pro (scripting requires the Pro version)
- Swift 5.9+ (for building from source)

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/yourusername/OmniOutlinerMCP.git
cd OmniOutlinerMCP

# Build
swift build -c release

# Run
.build/release/OmniOutlinerMCP
```

### Xcode

Open the project in Xcode and build/run the `OmniOutlinerMCP` scheme.

## Usage

1. Launch OmniOutliner MCP from Applications or build output
2. The app appears in your menu bar with a status indicator:
   - **Green**: Connected to OmniOutliner with a document open
   - **Yellow**: OmniOutliner running but no document open, or app not running
   - **Red**: Server stopped or error
3. Configure your MCP client to connect to `http://127.0.0.1:3000`

### Claude Desktop Configuration

Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "omnioutliner": {
      "url": "http://127.0.0.1:3000"
    }
  }
}
```

## Available Tools

Most tools accept an optional `documentName` parameter to target a specific open document. If omitted, the frontmost document is used.

### Query Tools

| Tool | Description |
|------|-------------|
| `list_documents` | List all open OmniOutliner documents with names, paths, and row counts |
| `get_all_documents_content` | Get the full outline structure of all open documents in one call |
| `get_current_document` | Get metadata about the frontmost OmniOutliner document |
| `get_outline_structure` | Get the full outline hierarchy with text, notes, and structure |
| `get_row` | Get details of a specific row by ID |
| `get_row_children` | Get immediate children of a row |
| `search_outline` | Search for rows matching text in topics or notes |
| `check_connection` | Check if OmniOutliner is running and accessible |

### Modification Tools

| Tool | Description |
|------|-------------|
| `create_document` | Create a new, empty OmniOutliner document |
| `add_row` | Add a new row with text at a specified location |
| `update_row` | Update topic, note, or checkbox state of a row |
| `move_row` | Move a row (and children) to a new location |
| `delete_row` | Delete a row and all its children (requires confirmation) |

### Synthesis Tools

| Tool | Description |
|------|-------------|
| `get_section_content` | Get formatted content of a section for summarization |
| `insert_content` | Insert single or hierarchical content at a location |

## Configuration

Access preferences from the menu bar icon:

- **Server Port**: Default 3000, configurable if needed
- **Auto-start**: Launch server automatically when app starts

## Security

- Server binds to localhost only (127.0.0.1)
- No remote connections accepted
- All changes are undoable in OmniOutliner (Cmd+Z)
- Destructive operations require explicit confirmation

## Architecture

```
OmniOutlinerMCP/
├── App/           # Entry point, AppState, Preferences
├── Views/         # SwiftUI menu bar and settings
├── Server/        # Vapor HTTP server, MCP protocol, JSON-RPC
├── Tools/         # MCP tool implementations
├── OmniOutliner/  # JXA script bridge to OmniOutliner
└── Resources/     # Assets
```

The server uses:
- **Vapor 4.x** for HTTP handling
- **JSON-RPC 2.0** for MCP protocol communication
- **JXA (JavaScript for Automation)** via NSAppleScript to control OmniOutliner

## Development

```bash
# Build debug
swift build

# Run tests
swift test

# Build release
swift build -c release
```

## Troubleshooting

**"OmniOutliner Pro required" error**
- Scripting is a Pro-only feature. Upgrade to OmniOutliner Pro or subscribe to OmniOutliner/Omni Pro.

**Server won't start**
- Check if port 3000 is in use. Change the port in preferences.
- Ensure no other instance is running.

**Can't connect to OmniOutliner**
- Make sure OmniOutliner is running with a document open.
- Grant automation permissions in System Settings > Privacy & Security > Automation.

## License

MIT License - See LICENSE file for details.
