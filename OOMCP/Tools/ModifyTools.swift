import Foundation

/// Modification tools for changing OmniOutliner content.
enum ModifyTools {

    /// Register all modify tools with the registry.
    @MainActor
    static func registerAll(in registry: ToolRegistry) {
        registry.register([
            CreateDocumentHandler(),
            AddRowHandler(),
            UpdateRowHandler(),
            MoveRowHandler(),
            DeleteRowHandler()
        ])
    }
}

// MARK: - Create Document

struct CreateDocumentHandler: MCPToolHandler {
    let tool = MCPTool(
        name: "create_document",
        description: """
            Create a new, empty OmniOutliner document and bring it to the foreground. \
            The document will be untitled until the user saves it. \
            Use this when the user wants to start a new outline. \
            IMPORTANT: Before modifying an existing document, first use get_current_document to check \
            what document is open and confirm with the user whether they want to modify that document \
            or create a new one.
            """,
        inputSchema: MCPInputSchema()
    )

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        let result = try await OmniOutlinerBridge.shared.execute(JXAScripts.createDocument)
        return MCPToolResult.json(result)
    }
}

// MARK: - Add Row

struct AddRowHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "add_row",
            description: "Add a new row with specified text at a given location."
        )

        builder.addParameter(
            "topic",
            type: "string",
            description: "The text content for the new row.",
            required: true
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document to add the row to. Omit to use the frontmost document."
        )

        builder.addParameter(
            "note",
            type: "string",
            description: "Optional note content to attach to the row."
        )

        builder.addParameter(
            "parentId",
            type: "string",
            description: "ID of the parent row. Omit for top-level placement."
        )

        builder.addParameter(
            "position",
            type: "string",
            description: "Where to place among siblings.",
            enumValues: ["first", "last"],
            defaultValue: "last"
        )

        builder.addParameter(
            "siblingId",
            type: "string",
            description: "Reference sibling for relative positioning."
        )

        builder.addParameter(
            "relativePosition",
            type: "string",
            description: "Insert before or after the sibling.",
            enumValues: ["before", "after"]
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        guard let topic = arguments?["topic"]?.stringValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: topic")
        }

        let documentName = arguments?["documentName"]?.stringValue
        let note = arguments?["note"]?.stringValue
        let parentId = arguments?["parentId"]?.stringValue
        let position = arguments?["position"]?.stringValue ?? "last"
        let siblingId = arguments?["siblingId"]?.stringValue
        let relativePosition = arguments?["relativePosition"]?.stringValue

        let script = JXAScripts.addRow(
            topic: topic,
            note: note,
            parentId: parentId,
            position: position,
            siblingId: siblingId,
            relativePosition: relativePosition,
            documentName: documentName
        )

        let result = try await OmniOutlinerBridge.shared.execute(script)

        // Add undo hint to message
        var modifiedResult = result
        if var message = modifiedResult["message"] as? String {
            message += " Use Cmd+Z in OmniOutliner to undo."
            modifiedResult["message"] = message
        }

        return MCPToolResult.json(modifiedResult)
    }
}

// MARK: - Update Row

struct UpdateRowHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "update_row",
            description: "Update the topic text, note, or checkbox state of an existing row."
        )

        builder.addParameter(
            "rowId",
            type: "string",
            description: "The ID of the row to update.",
            required: true
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document containing the row. Omit to use the frontmost document."
        )

        builder.addParameter(
            "topic",
            type: "string",
            description: "New topic text. Omit to keep current value."
        )

        builder.addParameter(
            "note",
            type: "string",
            description: "New note text. Omit to keep current, use empty string to clear."
        )

        builder.addParameter(
            "state",
            type: "string",
            description: "New checkbox state.",
            enumValues: ["checked", "unchecked", "none"]
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        guard let rowId = arguments?["rowId"]?.stringValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: rowId")
        }

        let documentName = arguments?["documentName"]?.stringValue
        let topic = arguments?["topic"]?.stringValue
        let note = arguments?["note"]?.stringValue
        let state = arguments?["state"]?.stringValue

        let script = JXAScripts.updateRow(
            rowId: rowId,
            topic: topic,
            note: note,
            state: state,
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

// MARK: - Move Row

struct MoveRowHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "move_row",
            description: "Move an existing row to a different position in the outline. The row and all its children are moved together."
        )

        builder.addParameter(
            "rowId",
            type: "string",
            description: "The ID of the row to move.",
            required: true
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document containing the row. Omit to use the frontmost document."
        )

        builder.addParameter(
            "newParentId",
            type: "string",
            description: "New parent row ID. Omit for top-level placement."
        )

        builder.addParameter(
            "position",
            type: "string",
            description: "Where to place among siblings.",
            enumValues: ["first", "last"],
            defaultValue: "last"
        )

        builder.addParameter(
            "siblingId",
            type: "string",
            description: "Reference sibling for relative positioning."
        )

        builder.addParameter(
            "relativePosition",
            type: "string",
            description: "Insert before or after the sibling.",
            enumValues: ["before", "after"]
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        guard let rowId = arguments?["rowId"]?.stringValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: rowId")
        }

        let documentName = arguments?["documentName"]?.stringValue
        let newParentId = arguments?["newParentId"]?.stringValue
        let position = arguments?["position"]?.stringValue ?? "last"
        let siblingId = arguments?["siblingId"]?.stringValue
        let relativePosition = arguments?["relativePosition"]?.stringValue

        let script = JXAScripts.moveRow(
            rowId: rowId,
            newParentId: newParentId,
            position: position,
            siblingId: siblingId,
            relativePosition: relativePosition,
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

// MARK: - Delete Row

struct DeleteRowHandler: MCPToolHandler {
    var tool: MCPTool {
        var builder = ToolBuilder(
            name: "delete_row",
            description: "Delete a row and all its children. This is a destructive operation that requires confirmation before proceeding."
        )

        builder.addParameter(
            "rowId",
            type: "string",
            description: "The ID of the row to delete.",
            required: true
        )

        builder.addParameter(
            "documentName",
            type: "string",
            description: "Name of the document containing the row. Omit to use the frontmost document."
        )

        builder.addParameter(
            "confirmed",
            type: "boolean",
            description: "Set to true to confirm this destructive operation.",
            required: true
        )

        return builder.build()
    }

    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolResult {
        guard let rowId = arguments?["rowId"]?.stringValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: rowId")
        }

        guard let confirmed = arguments?["confirmed"]?.boolValue else {
            throw JSONRPCError.invalidParams("Missing required parameter: confirmed")
        }

        let documentName = arguments?["documentName"]?.stringValue
        let script = JXAScripts.deleteRow(rowId: rowId, confirmed: confirmed, documentName: documentName)
        let result = try await OmniOutlinerBridge.shared.execute(script)

        return MCPToolResult.json(result)
    }
}
