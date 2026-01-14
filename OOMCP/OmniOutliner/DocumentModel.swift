import Foundation

// MARK: - Document

/// Represents an OmniOutliner document currently open in the application.
struct Document: Codable, Equatable, Sendable {
    /// Document filename (e.g., "Project Plan.ooutline")
    let name: String

    /// Full filesystem path if saved; nil for unsaved documents
    let path: String?

    /// Whether this is the currently active document
    let isFrontmost: Bool

    /// Whether undo is available
    let canUndo: Bool

    /// Whether redo is available
    let canRedo: Bool

    /// Total number of rows in the document
    let rowCount: Int

    init(name: String, path: String? = nil, isFrontmost: Bool = true,
         canUndo: Bool = false, canRedo: Bool = false, rowCount: Int = 0) {
        self.name = name
        self.path = path
        self.isFrontmost = isFrontmost
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.rowCount = rowCount
    }
}

// MARK: - Row State

/// Represents the checkbox state of a row.
enum RowState: String, Codable, Equatable, Sendable {
    case unchecked = "unchecked"
    case checked = "checked"
    case mixed = "mixed"
    case none = "none"
}

// MARK: - Row

/// Represents a single item (row) in an OmniOutliner document.
struct Row: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier within the document
    let id: String

    /// Main text content of the row
    let topic: String

    /// Optional note attached to the row
    let note: String?

    /// Nesting depth (0 = top-level)
    let level: Int

    /// Checkbox state
    let state: RowState

    /// Whether this row has child rows
    let hasChildren: Bool

    /// ID of parent row; nil for top-level rows
    let parentId: String?

    /// IDs of direct child rows (in order)
    let childIds: [String]

    init(id: String, topic: String, note: String? = nil, level: Int = 0,
         state: RowState = .none, hasChildren: Bool = false,
         parentId: String? = nil, childIds: [String] = []) {
        self.id = id
        self.topic = topic
        self.note = note
        self.level = level
        self.state = state
        self.hasChildren = hasChildren
        self.parentId = parentId
        self.childIds = childIds
    }
}

// MARK: - Column Type

/// Data type of a column in the outline.
enum ColumnType: String, Codable, Equatable, Sendable {
    case text = "text"
    case number = "number"
    case checkbox = "checkbox"
    case date = "date"
    case duration = "duration"
    case popup = "popup"
    case richText = "rich_text"
}

// MARK: - Column

/// Represents a column in the outline (beyond the default Topic column).
struct Column: Codable, Equatable, Sendable, Identifiable {
    /// Unique column identifier
    let id: String

    /// Column header name
    let name: String

    /// Data type of the column
    let type: ColumnType

    init(id: String, name: String, type: ColumnType) {
        self.id = id
        self.name = name
        self.type = type
    }
}

// MARK: - Insert Position

/// Specifies where to place a new or moved row.
enum InsertPosition: String, Codable, Equatable, Sendable {
    case first = "first"
    case last = "last"
    case before = "before"
    case after = "after"
}

// MARK: - Row Location

/// Specifies where to place a new or moved row.
struct RowLocation: Codable, Equatable, Sendable {
    /// ID of parent row; nil for top-level
    let parentId: String?

    /// Where to insert relative to siblings
    let position: InsertPosition

    /// Reference sibling for before/after positioning
    let siblingId: String?

    init(parentId: String? = nil, position: InsertPosition = .last, siblingId: String? = nil) {
        self.parentId = parentId
        self.position = position
        self.siblingId = siblingId
    }
}

// MARK: - Match Field

/// Which field contained a search match.
enum MatchField: String, Codable, Equatable, Sendable {
    case topic = "topic"
    case note = "note"
    case column = "column"
}

// MARK: - Search Result

/// Represents a row that matched a search query.
struct SearchResult: Codable, Equatable, Sendable {
    /// The matching row
    let row: Row

    /// Text excerpt showing match in context
    let matchContext: String

    /// Which field contained the match
    let matchField: MatchField

    init(row: Row, matchContext: String, matchField: MatchField) {
        self.row = row
        self.matchContext = matchContext
        self.matchField = matchField
    }
}

// MARK: - Operation Result

/// Standard response for modification operations.
struct OperationResult: Codable, Equatable, Sendable {
    /// Whether operation completed successfully
    let success: Bool

    /// Human-readable result description
    let message: String

    /// IDs of rows that were modified
    let affectedRowIds: [String]?

    /// Whether the change can be undone via Cmd+Z
    let undoAvailable: Bool

    init(success: Bool, message: String, affectedRowIds: [String]? = nil, undoAvailable: Bool = true) {
        self.success = success
        self.message = message
        self.affectedRowIds = affectedRowIds
        self.undoAvailable = undoAvailable
    }
}

// MARK: - Outline Tree

/// Represents the full hierarchical structure of a document.
struct OutlineTree: Codable, Equatable, Sendable {
    /// Document metadata
    let document: Document

    /// Top-level rows with nested children
    let rootRows: [Row]

    init(document: Document, rootRows: [Row]) {
        self.document = document
        self.rootRows = rootRows
    }
}

// MARK: - Flattened Outline

/// Alternative representation for simpler processing.
struct FlattenedOutline: Codable, Equatable, Sendable {
    /// Document metadata
    let document: Document

    /// All rows in depth-first order
    let rows: [Row]

    init(document: Document, rows: [Row]) {
        self.document = document
        self.rows = rows
    }
}

// MARK: - Size Constraints

/// Constants for size limits.
enum SizeConstraints {
    /// Maximum topic length (OmniOutliner limit)
    static let maxTopicLength = 65535

    /// Maximum note length (practical limit)
    static let maxNoteLength = 1_000_000

    /// Maximum search results
    static let maxSearchResults = 100

    /// Maximum batch operation size
    static let maxBatchOperation = 50
}
