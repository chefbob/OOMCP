import Foundation

/// Query tools for reading OmniOutliner content.
enum QueryTools {

    /// Register all query tools with the registry.
    @MainActor
    static func registerAll(in registry: ToolRegistry) {
        registry.register([
            ListDocumentsHandler(),
            GetAllDocumentsContentHandler(),
            GetCurrentDocumentHandler(),
            GetOutlineStructureHandler(),
            GetRowHandler(),
            GetRowChildrenHandler(),
            SearchOutlineHandler(),
            CheckConnectionHandler()
        ])
    }
}

// MARK: - List Documents

struct ListDocumentsHandler: MCPToolHandler {
    let tool = MCPTool(
        name: "list_documents",
        description: """
            List all open documents in OmniOutliner. Returns document names, file paths, \
            row counts, and modification status. Use this to see what documents are available \
            before reading or modifying them.
            """,
        inputSchema: MCPInputSchema()
    )

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        let result = try await OmniOutlinerBridge.shared.execute(JXAScripts.listDocuments)
        return MCPToolResult.json(result)
    }
}

// MARK: - Get All Documents Content

struct GetAllDocumentsContentHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "get_all_documents_content",
            description: """
                Get the content of ALL open documents in one call. Returns the full outline \
                structure for each document. Use this when you need to understand the content \
                of multiple documents before deciding how to modify them or create new documents.
                """
        )

        builder.addParameter(
            "includeNotes",
            type: "boolean",
            description: "Whether to include note content for each row.",
            defaultValue: true
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        let includeNotes = arguments?["includeNotes"]?.boolValue ?? true
        let script = JXAScripts.getAllDocumentsContent(includeNotes: includeNotes)
        let result = try await OmniOutlinerBridge.shared.execute(script)
        return MCPToolResult.json(result)
    }
}

// MARK: - Get Current Document

struct GetCurrentDocumentHandler: MCPToolHandler {
    let tool = MCPTool(
        name: "get_current_document",
        description: "Get the name and metadata of the frontmost OmniOutliner document.",
        inputSchema: MCPInputSchema()
    )

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        let result = try await OmniOutlinerBridge.shared.execute(JXAScripts.getCurrentDocument)

        if let document = result["document"] {
            return MCPToolResult.json(["document": document])
        }

        return MCPToolResult.json(result)
    }
}

// MARK: - Get Outline Structure

struct GetOutlineStructureHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "get_outline_structure",
            description: "Get the full outline structure including all rows, their text, notes, and hierarchy."
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document to read. Omit to use the frontmost document."
        )

        builder.addParameter(
            "maxDepth",
            type: "integer",
            description: "Maximum nesting depth to return. 0 = top-level only.",
            minimum: 0
        )

        builder.addParameter(
            "includeNotes",
            type: "boolean",
            description: "Whether to include note content for each row.",
            defaultValue: true
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        let documentName = arguments?["documentName"]?.stringValue
        let maxDepth = arguments?["maxDepth"]?.intValue
        let includeNotes = arguments?["includeNotes"]?.boolValue ?? true

        let script = JXAScripts.getOutlineStructure(
            maxDepth: maxDepth,
            includeNotes: includeNotes,
            documentName: documentName
        )
        let result = try await OmniOutlinerBridge.shared.execute(script)

        return MCPToolResult.json(result)
    }
}

// MARK: - Get Row

struct GetRowHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "get_row",
            description: "Get the full details of a specific row including its text, note, state, and position in the hierarchy."
        )

        builder.addParameter(
            "rowId",
            type: "string",
            description: "The unique identifier of the row to retrieve.",
            required: true
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document containing the row. Omit to use the frontmost document."
        )

        builder.addParameter(
            "includeChildren",
            type: "boolean",
            description: "Whether to include immediate child rows in the response.",
            defaultValue: false
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        guard let rowId = arguments?["rowId"]?.stringValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: rowId")
        }

        let documentName = arguments?["documentName"]?.stringValue
        let includeChildren = arguments?["includeChildren"]?.boolValue ?? false

        let script = JXAScripts.getRow(
            rowId: rowId,
            includeChildren: includeChildren,
            documentName: documentName
        )
        let result = try await OmniOutlinerBridge.shared.execute(script)

        return MCPToolResult.json(result)
    }
}

// MARK: - Get Row Children

struct GetRowChildrenHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "get_row_children",
            description: "Get all immediate children of a row, useful for exploring outline hierarchy."
        )

        builder.addParameter(
            "rowId",
            type: "string",
            description: "The parent row ID. Omit to get top-level rows."
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document to read. Omit to use the frontmost document."
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        let rowId = arguments?["rowId"]?.stringValue
        let documentName = arguments?["documentName"]?.stringValue

        let script = JXAScripts.getRowChildren(rowId: rowId, documentName: documentName)
        let result = try await OmniOutlinerBridge.shared.execute(script)

        return MCPToolResult.json(result)
    }
}

// MARK: - Search Outline

struct SearchOutlineHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "search_outline",
            description: "Search a document for rows matching the given text. Searches topic text and notes."
        )

        builder.addParameter(
            "query",
            type: "string",
            description: "The text to search for in the outline.",
            required: true
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document to search. Omit to search the frontmost document."
        )

        builder.addParameter(
            "searchIn",
            type: "string",
            description: "Which fields to search in.",
            enumValues: ["all", "topics", "notes"],
            defaultValue: "all"
        )

        builder.addParameter(
            "caseSensitive",
            type: "boolean",
            description: "Whether the search should be case-sensitive.",
            defaultValue: false
        )

        builder.addParameter(
            "maxResults",
            type: "integer",
            description: "Maximum number of results to return.",
            defaultValue: 50,
            minimum: 1,
            maximum: 100
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        guard let query = arguments?["query"]?.stringValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: query")
        }

        let documentName = arguments?["documentName"]?.stringValue
        let searchIn = arguments?["searchIn"]?.stringValue ?? "all"
        let caseSensitive = arguments?["caseSensitive"]?.boolValue ?? false
        let maxResults = arguments?["maxResults"]?.intValue ?? 50

        let script = JXAScripts.searchOutline(
            query: query,
            searchIn: searchIn,
            caseSensitive: caseSensitive,
            maxResults: maxResults,
            documentName: documentName
        )

        let result = try await OmniOutlinerBridge.shared.execute(script)
        return MCPToolResult.json(result)
    }
}

// MARK: - Check Connection

struct CheckConnectionHandler: MCPToolHandler {
    let tool = MCPTool(
        name: "check_connection",
        description: "Check if OmniOutliner is running and accessible, and whether a document is open.",
        inputSchema: MCPInputSchema()
    )

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        let status = await OmniOutlinerBridge.shared.checkConnection()

        return MCPToolResult.json([
            "connected": status.connected,
            "appRunning": status.appRunning,
            "documentOpen": status.documentOpen,
            "documentName": status.documentName as Any,
            "message": status.message
        ])
    }
}
