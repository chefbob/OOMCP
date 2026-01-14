# Quick Start Guide: OmniOutliner MCP

Connect your AI assistant (ChatGPT or Claude) to your OmniOutliner documents.

---

## What This Does

OmniOutliner MCP lets you:
- **Ask questions** about your outlines ("What's in my project plan?")
- **Make changes** through conversation ("Add a task called 'Review budget'")
- **Get summaries** and insights ("Summarize the key points")
- **Generate content** based on your outline data

---

## Requirements

- **macOS 13 (Ventura) or later**
- **OmniOutliner 5 Pro or later** (Pro version required for scripting/automation)
- **ChatGPT Desktop** or **Claude Desktop**

> **Note:** The standard version of OmniOutliner does not support scripting. You need OmniOutliner Pro, an OmniOutliner subscription with Pro features, or an Omni Pro subscription.

---

## Installation

### Step 1: Install the App

1. Download `OmniOutlinerMCP.dmg` from [releases page]
2. Open the DMG file
3. Drag **OmniOutliner MCP** to your **Applications** folder
4. Launch the app from Applications

A small icon will appear in your menu bar (top-right of your screen).

### Step 2: Grant Permission

The first time you use the app, macOS will ask for permission:

1. A dialog appears: "OmniOutliner MCP wants to control OmniOutliner"
2. Click **OK**

This only happens once.

### Step 3: Configure Your AI Assistant

#### For ChatGPT Desktop (Requires Tunnel)

> **Note:** ChatGPT Desktop cannot connect to localhost directly. You need a public HTTPS URL via a tunnel service like ngrok or Cloudflare Tunnel.

1. Install [ngrok](https://ngrok.com/) or a similar tunnel service
2. Start the tunnel: `ngrok http 3000`
3. Copy the HTTPS URL provided by ngrok (e.g., `https://abc123.ngrok.io`)
4. Open ChatGPT Desktop
5. Go to **Settings** → **Connectors** → **Advanced**
6. Enable **Developer Mode**
7. Go to **Settings** → **Connectors** → **Create**
8. Enter:
   - **Name**: OmniOutliner
   - **Server URL**: Your ngrok HTTPS URL
9. Click **Save**

#### For Claude Desktop

> **Note:** Claude Desktop requires stdio transport for local servers. We use `mcp-remote` as a proxy to bridge our HTTP server.

1. Install the mcp-remote proxy: `npm install -g mcp-remote`
2. Open `~/Library/Application Support/Claude/claude_desktop_config.json`
3. Add the server configuration:
   ```json
   {
     "mcpServers": {
       "omnioutliner": {
         "command": "npx",
         "args": ["mcp-remote", "http://localhost:3000/mcp"]
       }
     }
   }
   ```
4. Save the file and restart Claude Desktop
5. Go to **Settings** → **Developer** and ensure the server is enabled

---

## Using OmniOutliner MCP

### Daily Workflow

1. The app runs automatically in your menu bar
2. Open a document in OmniOutliner
3. Switch to ChatGPT or Claude
4. Start asking questions or making requests

### Example Conversations

**Ask questions:**
> "What's in my current outline?"
> "Show me everything under the Tasks section"
> "Find all items mentioning 'budget'"

**Make changes:**
> "Add a new task called 'Review Q3 report'"
> "Move 'Meeting notes' under 'Archive'"
> "Mark 'Project Alpha' as complete"

**Get summaries:**
> "Summarize this document"
> "What are the main themes?"
> "Draft an executive summary"

---

## Menu Bar Status

The menu bar icon shows the current status:

| Color | Meaning |
|-------|---------|
| 🟢 Green | Ready - Server running, OmniOutliner connected |
| 🟡 Yellow | Waiting - Server running, open a document in OmniOutliner |
| 🔴 Red | Stopped - Click to start the server |

---

## Important Notes

### Document Access

The app supports **multiple open documents**. By default, tools operate on the frontmost document. You can also:
- Ask "What documents are open?" to list all available documents
- Specify a document by name: "Show me the outline in 'Project Plan'"
- Get content from all documents at once for comparison

### Undoing Changes

All changes can be undone:
1. Switch to OmniOutliner
2. Press **Cmd+Z**

### Deleting Items

When you ask to delete something:
1. The AI shows what will be deleted
2. You must confirm before it happens
3. You can always undo afterward

---

## Settings

Click the menu bar icon and select **Preferences** to:

- **Start at Login**: Launch automatically when you log in (recommended)
- **Port**: Change the server port if 3000 is in use (default: 3000)

---

## Troubleshooting

### "OmniOutliner is not running"

Open OmniOutliner and open a document.

### "No document is open"

Open or create a document in OmniOutliner.

### "Permission denied"

1. Open **System Settings** → **Privacy & Security** → **Automation**
2. Find **OmniOutliner MCP** in the list
3. Enable the checkbox for **OmniOutliner**

### ChatGPT can't connect

1. Make sure the menu bar icon is green or yellow (not red)
2. Verify ngrok (or your tunnel) is running: `ngrok http 3000`
3. Check that Developer Mode is enabled in ChatGPT
4. Verify the server URL matches your ngrok HTTPS URL (not localhost)

### App won't launch

1. Open **System Settings** → **Privacy & Security**
2. Look for a message about OmniOutliner MCP being blocked
3. Click **Open Anyway**

---

## Getting Help

- **Documentation**: [Link to full docs]
- **Report Issues**: [GitHub Issues]
- **OmniOutliner Help**: [Omni Group Support]

---

## Uninstalling

1. Quit the app (click menu bar icon → **Quit**)
2. Drag **OmniOutliner MCP** from Applications to Trash
3. Remove the ChatGPT/Claude connector configuration if desired
