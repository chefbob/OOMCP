# Data Model: OmniOutliner MCP Server

**Date**: 2026-01-13
**Branch**: `001-omnioutliner-mcp`

## Overview

This document defines the data structures used by the MCP server to represent OmniOutliner documents, rows, and operations. These models bridge between OmniOutliner's native object model (accessed via Omni Automation) and the MCP tool interfaces.

---

## Core Entities

### Document

Represents an OmniOutliner document currently open in the application.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Document filename (e.g., "Project Plan.ooutline") |
| path | string | No | Full filesystem path if saved; null for unsaved documents |
| isFrontmost | boolean | Yes | Whether this is the currently active document |
| canUndo | boolean | Yes | Whether undo is available |
| canRedo | boolean | Yes | Whether redo is available |
| rowCount | number | Yes | Total number of rows in the document |

**Validation Rules**:
- `name` must be non-empty string
- `rowCount` must be >= 0

**Note**: Due to OmniOutliner API limitations, only the frontmost document can be queried. The `isFrontmost` field will always be `true` for returned documents.

---

### Row

Represents a single item (row) in an OmniOutliner document.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | Yes | Unique identifier within the document |
| topic | string | Yes | Main text content of the row |
| note | string | No | Optional note attached to the row |
| level | number | Yes | Nesting depth (0 = top-level) |
| state | RowState | Yes | Checkbox state |
| hasChildren | boolean | Yes | Whether this row has child rows |
| parentId | string | No | ID of parent row; null for top-level rows |
| childIds | string[] | Yes | IDs of direct child rows (in order) |

**Validation Rules**:
- `id` must be non-empty string
- `topic` can be empty string (blank rows allowed)
- `level` must be >= 0
- `childIds` array can be empty

---

### RowState (Enum)

Represents the checkbox state of a row.

| Value | Description |
|-------|-------------|
| unchecked | Checkbox is empty |
| checked | Checkbox is filled |
| mixed | Checkbox is partially filled (some children checked) |
| none | No checkbox displayed |

---

### Column

Represents a column in the outline (beyond the default Topic column).

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | Yes | Unique column identifier |
| name | string | Yes | Column header name |
| type | ColumnType | Yes | Data type of the column |

---

### ColumnType (Enum)

| Value | Description |
|-------|-------------|
| text | Plain text |
| number | Numeric value |
| checkbox | Boolean checkbox |
| date | Date/time value |
| duration | Time duration |
| popup | Dropdown menu selection |
| rich_text | Formatted text |

---

## Operation Models

### RowLocation

Specifies where to place a new or moved row.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| parentId | string | No | ID of parent row; null for top-level |
| position | InsertPosition | Yes | Where to insert relative to siblings |
| siblingId | string | No | Reference sibling for before/after positioning |

---

### InsertPosition (Enum)

| Value | Description |
|-------|-------------|
| first | First child of parent |
| last | Last child of parent |
| before | Before the specified sibling |
| after | After the specified sibling |

---

### SearchResult

Represents a row that matched a search query.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| row | Row | Yes | The matching row |
| matchContext | string | Yes | Text excerpt showing match in context |
| matchField | MatchField | Yes | Which field contained the match |

---

### MatchField (Enum)

| Value | Description |
|-------|-------------|
| topic | Match found in row topic text |
| note | Match found in row note |
| column | Match found in a column value |

---

### OperationResult

Standard response for modification operations.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| success | boolean | Yes | Whether operation completed successfully |
| message | string | Yes | Human-readable result description |
| affectedRowIds | string[] | No | IDs of rows that were modified |
| undoAvailable | boolean | Yes | Whether the change can be undone via Cmd+Z |

---

## Hierarchy Representation

### OutlineTree

Represents the full hierarchical structure of a document.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| document | Document | Yes | Document metadata |
| rootRows | Row[] | Yes | Top-level rows with nested children |

**Structure Notes**:
- Each Row in `rootRows` contains its `childIds` references
- Full tree can be reconstructed by following `childIds` arrays
- For large documents (>1000 rows), tree may be returned in segments

---

### FlattenedOutline

Alternative representation for simpler processing.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| document | Document | Yes | Document metadata |
| rows | Row[] | Yes | All rows in depth-first order |

**Structure Notes**:
- Rows ordered by visual appearance (top to bottom)
- `level` field indicates nesting depth
- `parentId` allows tree reconstruction

---

## Error Types

### OutlinerError

Standardized error response for all operations.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| code | ErrorCode | Yes | Machine-readable error code |
| message | string | Yes | User-friendly error description |
| suggestion | string | No | Recommended action to resolve |
| technicalDetail | string | No | Additional detail for debugging |

---

### ErrorCode (Enum)

| Code | Description |
|------|-------------|
| app_not_running | OmniOutliner is not running |
| no_document | No document is currently open |
| row_not_found | Referenced row ID does not exist |
| invalid_location | Cannot place row at specified location |
| permission_denied | macOS denied automation permission |
| document_locked | Document is read-only or locked |
| operation_failed | Generic operation failure |

---

## State Transitions

### Row Lifecycle

```
[Created] → [Exists] → [Deleted]
              ↓↑
         [Modified]
```

- Rows are created via `add_row` tool
- Rows can be modified (topic, note, state, column values) while existing
- Rows can be moved within the hierarchy while existing
- Deleted rows cannot be recovered via MCP (only via OmniOutliner's undo)

### Document Access State

```
[Unavailable] ←→ [Available]
      ↓              ↓
  (App closed)   (Frontmost)
  (No document)
```

- Document is "Available" only when OmniOutliner is running AND a document is open AND it is the frontmost window
- All other states return appropriate errors

---

## Size Constraints

| Constraint | Limit | Rationale |
|------------|-------|-----------|
| Max rows per query | 5,000 | Per SC-004 performance requirement |
| Max topic length | 65,535 chars | OmniOutliner limit |
| Max note length | 1,000,000 chars | Practical limit for automation |
| Max search results | 100 | Prevent overwhelming responses |
| Max batch operation | 50 rows | Performance and safety |
