import Foundation

/// Synthesis tools for AI content operations.
enum SynthesisTools {

    /// Register all synthesis tools with the registry.
    @MainActor
    static func registerAll(in registry: ToolRegistry) {
        registry.register([
            GetSectionContentHandler(),
            InsertContentHandler()
        ])
    }
}

// MARK: - Get Section Content

struct GetSectionContentHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "get_section_content",
            description: "Get the text content of a section with pagination. Use get_outline_structure with maxDepth=1 first to see section overview with descendantCount, then use rowId to fetch specific sections. Response includes pagination metadata showing hasMore and totalRowsInSection."
        )

        builder.addParameter(
            "rowId",
            type: "string",
            description: "Root row ID for the section. Omit for entire document. Use get_outline_structure to find section IDs."
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document to read. Omit to use the frontmost document."
        )

        builder.addParameter(
            "format",
            type: "string",
            description: "How to format the content output.",
            enumValues: ["plain", "markdown", "structured"],
            defaultValue: "structured"
        )

        builder.addParameter(
            "offset",
            type: "integer",
            description: "Number of rows to skip (for pagination). Default 0.",
            defaultValue: 0,
            minimum: 0
        )

        builder.addParameter(
            "limit",
            type: "integer",
            description: "Maximum number of rows to return per page. Default 500.",
            defaultValue: 500,
            minimum: 1,
            maximum: 2000
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        let rowId = arguments?["rowId"]?.stringValue
        let documentName = arguments?["documentName"]?.stringValue
        let format = arguments?["format"]?.stringValue ?? "structured"
        let offset = arguments?["offset"]?.intValue ?? 0
        let limit = arguments?["limit"]?.intValue ?? 500

        let script = JXAScripts.getSectionContent(rowId: rowId, format: format, documentName: documentName, offset: offset, limit: limit)
        let result = try await OmniOutlinerBridge.shared.execute(script)

        return MCPToolResult.json(result)
    }
}

// MARK: - Insert Content

struct InsertContentHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "insert_content",
            description: "Insert synthesized or generated content at a specified location. Supports both single rows and hierarchical content."
        )

        builder.addParameter(
            "content",
            type: "string",
            description: "Content to insert - either a string or JSON array of row objects with 'topic', 'note', and optional 'children' fields.",
            required: true
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document to insert into. Omit to use the frontmost document."
        )

        builder.addParameter(
            "parentId",
            type: "string",
            description: "Parent row ID. Omit for top-level placement."
        )

        builder.addParameter(
            "position",
            type: "string",
            description: "Where to place among siblings.",
            enumValues: ["first", "last"],
            defaultValue: "last"
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        guard let content = arguments?["content"]?.stringValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: content")
        }

        let documentName = arguments?["documentName"]?.stringValue
        let parentId = arguments?["parentId"]?.stringValue
        let position = arguments?["position"]?.stringValue ?? "last"

        let script = JXAScripts.insertContent(
            content: content,
            parentId: parentId,
            position: position,
            documentName: documentName
        )

        let result = try await OmniOutlinerBridge.shared.execute(script)

        // Add undo hint
        var modifiedResult = result
        if var message = modifiedResult["message"] as? String {
            message += " Use Cmd+Z in OmniOutliner to undo."
            modifiedResult["message"] = message
        }

        return MCPToolResult.json(modifiedResult)
    }
}
