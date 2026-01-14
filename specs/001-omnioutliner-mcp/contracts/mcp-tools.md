# MCP Tool Contracts: OmniOutliner Server

**Date**: 2026-01-13
**Branch**: `001-omnioutliner-mcp`

This document defines all MCP tools exposed by the OmniOutliner server. Tools follow the Model Context Protocol specification and use JSON Schema for parameter definitions.

---

## Query Tools (Read Operations)

### get_current_document

Returns information about the currently active OmniOutliner document.

**Description**: Get the name and metadata of the frontmost OmniOutliner document.

**Parameters**: None

**Returns**:
```json
{
  "document": {
    "name": "string",
    "path": "string | null",
    "isFrontmost": true,
    "canUndo": "boolean",
    "canRedo": "boolean",
    "rowCount": "number"
  }
}
```

**Errors**:
- `app_not_running`: OmniOutliner is not running
- `no_document`: No document is currently open

---

### get_outline_structure

Returns the hierarchical structure of the current document.

**Description**: Get the full outline structure including all rows, their text, notes, and hierarchy.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| maxDepth | number | No | Maximum nesting depth to return (default: unlimited) |
| includeNotes | boolean | No | Include note content in response (default: true) |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "maxDepth": {
      "type": "integer",
      "minimum": 0,
      "description": "Maximum nesting depth to return. 0 = top-level only."
    },
    "includeNotes": {
      "type": "boolean",
      "default": true,
      "description": "Whether to include note content for each row."
    }
  }
}
```

**Returns**:
```json
{
  "document": { "name": "string", "rowCount": "number" },
  "rows": [
    {
      "id": "string",
      "topic": "string",
      "note": "string | null",
      "level": "number",
      "state": "unchecked | checked | mixed | none",
      "hasChildren": "boolean",
      "parentId": "string | null",
      "childIds": ["string"]
    }
  ]
}
```

**Errors**:
- `app_not_running`: OmniOutliner is not running
- `no_document`: No document is currently open

---

### get_row

Returns details for a specific row by ID.

**Description**: Get the full details of a specific row including its text, note, state, and position in the hierarchy.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| rowId | string | Yes | The unique identifier of the row |
| includeChildren | boolean | No | Include immediate children (default: false) |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "rowId": {
      "type": "string",
      "description": "The unique identifier of the row to retrieve."
    },
    "includeChildren": {
      "type": "boolean",
      "default": false,
      "description": "Whether to include immediate child rows in the response."
    }
  },
  "required": ["rowId"]
}
```

**Returns**:
```json
{
  "row": {
    "id": "string",
    "topic": "string",
    "note": "string | null",
    "level": "number",
    "state": "string",
    "hasChildren": "boolean",
    "parentId": "string | null",
    "childIds": ["string"]
  },
  "children": [{ "...row objects..." }]
}
```

**Errors**:
- `row_not_found`: The specified row ID does not exist

---

### search_outline

Searches for rows containing specific text.

**Description**: Search the current document for rows matching the given text. Searches topic text and notes.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| query | string | Yes | Text to search for |
| searchIn | string | No | Where to search: "all", "topics", "notes" (default: "all") |
| caseSensitive | boolean | No | Case-sensitive search (default: false) |
| maxResults | number | No | Maximum results to return (default: 50, max: 100) |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "minLength": 1,
      "description": "The text to search for in the outline."
    },
    "searchIn": {
      "type": "string",
      "enum": ["all", "topics", "notes"],
      "default": "all",
      "description": "Which fields to search in."
    },
    "caseSensitive": {
      "type": "boolean",
      "default": false,
      "description": "Whether the search should be case-sensitive."
    },
    "maxResults": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100,
      "default": 50,
      "description": "Maximum number of results to return."
    }
  },
  "required": ["query"]
}
```

**Returns**:
```json
{
  "results": [
    {
      "row": { "...row object..." },
      "matchContext": "string",
      "matchField": "topic | note"
    }
  ],
  "totalMatches": "number",
  "truncated": "boolean"
}
```

---

### get_row_children

Returns all children of a specific row.

**Description**: Get all immediate children of a row, useful for exploring outline hierarchy.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| rowId | string | No | Parent row ID; omit for top-level rows |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "rowId": {
      "type": "string",
      "description": "The parent row ID. Omit to get top-level rows."
    }
  }
}
```

**Returns**:
```json
{
  "parentId": "string | null",
  "children": [{ "...row objects..." }]
}
```

---

## Modification Tools (Write Operations)

### add_row

Creates a new row in the outline.

**Description**: Add a new row with specified text at a given location. For destructive operations on existing content, confirmation is NOT required. This tool creates new content only.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| topic | string | Yes | The text content for the new row |
| note | string | No | Optional note to attach to the row |
| parentId | string | No | Parent row ID; omit for top-level |
| position | string | No | Where to insert: "first", "last" (default: "last") |
| siblingId | string | No | Insert relative to this sibling |
| relativePosition | string | No | "before" or "after" the sibling |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "topic": {
      "type": "string",
      "description": "The text content for the new row."
    },
    "note": {
      "type": "string",
      "description": "Optional note content to attach to the row."
    },
    "parentId": {
      "type": "string",
      "description": "ID of the parent row. Omit for top-level placement."
    },
    "position": {
      "type": "string",
      "enum": ["first", "last"],
      "default": "last",
      "description": "Where to place among siblings."
    },
    "siblingId": {
      "type": "string",
      "description": "Reference sibling for relative positioning."
    },
    "relativePosition": {
      "type": "string",
      "enum": ["before", "after"],
      "description": "Insert before or after the sibling."
    }
  },
  "required": ["topic"]
}
```

**Returns**:
```json
{
  "success": true,
  "message": "Added row 'Task title' under 'Project Tasks'",
  "newRow": { "...row object..." },
  "undoAvailable": true
}
```

---

### update_row

Modifies an existing row's content.

**Description**: Update the topic text, note, or checkbox state of an existing row.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| rowId | string | Yes | The row to update |
| topic | string | No | New topic text (omit to keep current) |
| note | string | No | New note text (omit to keep current, empty string to clear) |
| state | string | No | New checkbox state: "checked", "unchecked", "none" |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "rowId": {
      "type": "string",
      "description": "The ID of the row to update."
    },
    "topic": {
      "type": "string",
      "description": "New topic text. Omit to keep current value."
    },
    "note": {
      "type": "string",
      "description": "New note text. Omit to keep current, use empty string to clear."
    },
    "state": {
      "type": "string",
      "enum": ["checked", "unchecked", "none"],
      "description": "New checkbox state."
    }
  },
  "required": ["rowId"]
}
```

**Returns**:
```json
{
  "success": true,
  "message": "Updated row: changed topic and added note",
  "updatedRow": { "...row object..." },
  "undoAvailable": true
}
```

---

### move_row

Moves a row to a new location in the hierarchy.

**Description**: Move an existing row to a different position in the outline. The row and all its children are moved together.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| rowId | string | Yes | The row to move |
| newParentId | string | No | New parent row ID; omit for top-level |
| position | string | No | Where to place: "first", "last" (default: "last") |
| siblingId | string | No | Reference sibling for relative positioning |
| relativePosition | string | No | "before" or "after" the sibling |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "rowId": {
      "type": "string",
      "description": "The ID of the row to move."
    },
    "newParentId": {
      "type": "string",
      "description": "New parent row ID. Omit for top-level placement."
    },
    "position": {
      "type": "string",
      "enum": ["first", "last"],
      "default": "last"
    },
    "siblingId": {
      "type": "string",
      "description": "Reference sibling for relative positioning."
    },
    "relativePosition": {
      "type": "string",
      "enum": ["before", "after"]
    }
  },
  "required": ["rowId"]
}
```

**Returns**:
```json
{
  "success": true,
  "message": "Moved 'Task A' under 'Completed Tasks'",
  "movedRow": { "...row object..." },
  "undoAvailable": true
}
```

---

### delete_row

Deletes a row from the outline. **REQUIRES CONFIRMATION**.

**Description**: Delete a row and all its children. This is a destructive operation that requires confirmation before proceeding.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| rowId | string | Yes | The row to delete |
| confirmed | boolean | Yes | Must be true to proceed with deletion |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "rowId": {
      "type": "string",
      "description": "The ID of the row to delete."
    },
    "confirmed": {
      "type": "boolean",
      "description": "Set to true to confirm this destructive operation."
    }
  },
  "required": ["rowId", "confirmed"]
}
```

**Behavior**:
- If `confirmed` is false or missing, returns preview of what will be deleted
- If `confirmed` is true, performs deletion

**Returns (unconfirmed)**:
```json
{
  "success": false,
  "requiresConfirmation": true,
  "message": "This will delete 'Project Alpha' and 5 child rows. Set confirmed=true to proceed.",
  "affectedRows": [{ "...row summaries..." }]
}
```

**Returns (confirmed)**:
```json
{
  "success": true,
  "message": "Deleted 'Project Alpha' and 5 child rows. Use Cmd+Z in OmniOutliner to undo.",
  "deletedCount": 6,
  "undoAvailable": true
}
```

---

## Synthesis Support Tools

### get_section_content

Returns all content under a specific section for AI synthesis.

**Description**: Get the complete text content of a section and all its descendants, formatted for summarization or content generation.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| rowId | string | No | Section root row ID; omit for entire document |
| format | string | No | Output format: "plain", "markdown", "structured" (default: "structured") |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "rowId": {
      "type": "string",
      "description": "Root row ID for the section. Omit for entire document."
    },
    "format": {
      "type": "string",
      "enum": ["plain", "markdown", "structured"],
      "default": "structured",
      "description": "How to format the content output."
    }
  }
}
```

**Returns (structured)**:
```json
{
  "section": {
    "title": "string",
    "id": "string"
  },
  "content": {
    "rows": [{ "...row objects with descendants..." }],
    "totalRows": "number"
  }
}
```

**Returns (markdown)**:
```json
{
  "section": { "title": "string", "id": "string" },
  "markdown": "# Section Title\n\n- Item 1\n  - Sub-item\n- Item 2\n\n> Note: attached note content"
}
```

**Returns (plain)**:
```json
{
  "section": { "title": "string", "id": "string" },
  "text": "Section Title\n  Item 1\n    Sub-item\n  Item 2"
}
```

---

### insert_content

Inserts AI-generated content into the outline.

**Description**: Insert synthesized or generated content at a specified location. Supports both single rows and hierarchical content.

**Parameters**:
| Name | Type | Required | Description |
|------|------|----------|-------------|
| content | string or array | Yes | Content to insert (text or array of row objects) |
| parentId | string | No | Parent row ID; omit for top-level |
| position | string | No | Where to insert: "first", "last" (default: "last") |

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "content": {
      "oneOf": [
        { "type": "string", "description": "Single text item to insert" },
        {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "topic": { "type": "string" },
              "note": { "type": "string" },
              "children": { "type": "array" }
            },
            "required": ["topic"]
          },
          "description": "Hierarchical content to insert"
        }
      ],
      "description": "Content to insert - either a string or array of row objects."
    },
    "parentId": {
      "type": "string",
      "description": "Parent row ID. Omit for top-level placement."
    },
    "position": {
      "type": "string",
      "enum": ["first", "last"],
      "default": "last"
    }
  },
  "required": ["content"]
}
```

**Returns**:
```json
{
  "success": true,
  "message": "Inserted 3 rows under 'Meeting Notes'",
  "insertedRows": [{ "...row objects..." }],
  "undoAvailable": true
}
```

---

## Status Tool

### check_connection

Verifies connectivity to OmniOutliner.

**Description**: Check if OmniOutliner is running and accessible, and whether a document is open.

**Parameters**: None

**Returns**:
```json
{
  "connected": "boolean",
  "appRunning": "boolean",
  "documentOpen": "boolean",
  "documentName": "string | null",
  "message": "string"
}
```

**Example Messages**:
- "Connected to OmniOutliner. Document 'Project Plan.ooutline' is open."
- "OmniOutliner is running but no document is open. Please open a document."
- "OmniOutliner is not running. Please launch OmniOutliner and open a document."

---

## Tool Summary

| Tool | Category | Description |
|------|----------|-------------|
| get_current_document | Query | Get current document info |
| get_outline_structure | Query | Get full outline hierarchy |
| get_row | Query | Get specific row details |
| search_outline | Query | Search for text in outline |
| get_row_children | Query | List children of a row |
| add_row | Modify | Create new row |
| update_row | Modify | Edit existing row |
| move_row | Modify | Relocate row in hierarchy |
| delete_row | Modify | Remove row (requires confirmation) |
| get_section_content | Synthesis | Get content for AI processing |
| insert_content | Synthesis | Add AI-generated content |
| check_connection | Status | Verify OmniOutliner connectivity |
