import Foundation

/// JXA script templates for Omni Automation.
/// These scripts are executed via NSAppleScript to interact with OmniOutliner.
enum JXAScripts {

    // MARK: - Document Scripts

    /// Get information about the current (frontmost) document.
    static let getCurrentDocument = """
    function run() {
        const app = Application('OmniOutliner');
        if (!app.running()) {
            return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
        }

        const docs = app.documents();
        if (docs.length === 0) {
            return JSON.stringify({ error: { code: 'no_document', message: 'No document is open in OmniOutliner.' } });
        }

        const doc = docs[0];
        const rows = doc.rows();

        return JSON.stringify({
            document: {
                name: doc.name(),
                isFrontmost: true,
                rowCount: rows.length
            }
        });
    }
    """

    /// Create a new OmniOutliner document and bring it to the foreground.
    static let createDocument = """
    function run() {
        const app = Application('OmniOutliner');

        // Launch OmniOutliner if not running
        if (!app.running()) {
            app.launch();
            // Give it a moment to start
            delay(0.5);
        }

        // Bring OmniOutliner to the foreground
        app.activate();

        try {
            // Create a new document using native JXA
            const newDoc = app.make({ new: 'document' });

            // Get document info
            const docName = newDoc.name();

            return JSON.stringify({
                success: true,
                message: "Created new document '" + docName + "'. The document is unsaved - use File > Save in OmniOutliner to save it.",
                document: {
                    name: docName,
                    rowCount: 0,
                    isFrontmost: true
                }
            });
        } catch (e) {
            return JSON.stringify({
                error: {
                    code: 'operation_failed',
                    message: 'Failed to create document: ' + e.message,
                    technicalDetail: e.toString()
                }
            });
        }
    }
    """

    /// List all open documents in OmniOutliner.
    static let listDocuments = """
    function run() {
        const app = Application('OmniOutliner');
        if (!app.running()) {
            return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
        }

        const docs = app.documents();
        if (docs.length === 0) {
            return JSON.stringify({
                documents: [],
                message: 'No documents are open in OmniOutliner.'
            });
        }

        const result = [];
        for (let i = 0; i < docs.length; i++) {
            const doc = docs[i];
            let filePath = null;
            try {
                const f = doc.file();
                if (f) filePath = f.toString();
            } catch(e) {}

            result.push({
                name: doc.name(),
                index: i,
                filePath: filePath,
                rowCount: doc.rows().length,
                modified: doc.modified(),
                isFrontmost: i === 0
            });
        }

        return JSON.stringify({
            documents: result,
            totalOpen: result.length
        });
    }
    """

    /// Get the content of all open documents.
    /// For large documents (500+ rows), automatically limits to top-level for performance.
    static func getAllDocumentsContent(includeNotes: Bool = true) -> String {
        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            const docs = app.documents();
            if (docs.length === 0) {
                return JSON.stringify({
                    documents: [],
                    message: 'No documents are open in OmniOutliner.'
                });
            }

            const includeNotes = \(includeNotes);
            const LARGE_DOC_THRESHOLD = 500;
            const result = [];

            for (let d = 0; d < docs.length; d++) {
                const doc = docs[d];
                let filePath = null;
                try {
                    const f = doc.file();
                    if (f) filePath = f.toString();
                } catch(e) {}

                const totalRowCount = doc.rows().length;
                const useFastMode = totalRowCount >= LARGE_DOC_THRESHOLD;
                const rows = [];

                if (useFastMode) {
                    // FAST MODE: Use whose() filter for large documents
                    const topRows = doc.rows.whose({level: 1})();
                    for (let i = 0; i < topRows.length; i++) {
                        const row = topRows[i];
                        const rowData = {
                            id: row.id(),
                            topic: row.topic(),
                            level: 1,
                            state: row.state() || 'none'
                        };

                        if (includeNotes) {
                            rowData.note = row.note() || null;
                        }

                        rows.push(rowData);
                    }
                } else {
                    // FULL MODE: Iterate all rows for small documents
                    const allRows = doc.rows();
                    for (let i = 0; i < allRows.length; i++) {
                        const row = allRows[i];
                        const rowData = {
                            id: row.id(),
                            topic: row.topic(),
                            level: row.level(),
                            state: row.state() || 'none'
                        };

                        if (includeNotes) {
                            rowData.note = row.note() || null;
                        }

                        rows.push(rowData);
                    }
                }

                result.push({
                    name: doc.name(),
                    index: d,
                    filePath: filePath,
                    isFrontmost: d === 0,
                    modified: doc.modified(),
                    totalRowCount: totalRowCount,
                    rowsReturned: rows.length,
                    autoLimited: useFastMode,
                    rows: rows
                });
            }

            return JSON.stringify({
                documents: result,
                totalDocuments: result.length
            });
        }
        """
    }

    // MARK: - Document Lookup Helper
    // This JavaScript snippet is embedded in scripts that need to find a document by name.
    // It defines a findDocument function that returns { doc, index } or throws an error.
    static let documentLookupHelper = """
        function findDocument(app, documentName) {
            const docs = app.documents();
            if (docs.length === 0) {
                throw { code: 'no_document', message: 'No document is open in OmniOutliner.' };
            }

            if (documentName === null) {
                return { doc: docs[0], index: 0 };
            }

            for (let i = 0; i < docs.length; i++) {
                if (docs[i].name() === documentName) {
                    return { doc: docs[i], index: i };
                }
            }

            const available = docs.map(d => d.name()).join(', ');
            throw { code: 'document_not_found', message: "Document '" + documentName + "' not found. Open documents: " + available };
        }
    """

    /// Get the full outline structure of the current document.
    /// Parameters: maxDepth (optional), includeNotes (default: true)
    /// For large documents (500+ rows), automatically limits to top-level for performance.
    static func getOutlineStructure(maxDepth: Int? = nil, includeNotes: Bool = true, documentName: String? = nil) -> String {
        let maxDepthParam = maxDepth.map { String($0) } ?? "null"
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc, index } = findDocument(app, documentName);
                const totalRowCount = doc.rows().length;
                const requestedMaxDepth = \(maxDepthParam);
                const includeNotes = \(includeNotes);

                // Smart auto-limiting for large documents
                const LARGE_DOC_THRESHOLD = 500;
                const useFastMode = requestedMaxDepth === null && totalRowCount >= LARGE_DOC_THRESHOLD;

                if (useFastMode) {
                    // FAST MODE: Use whose() filter for large documents
                    // This filters on OmniOutliner's side, avoiding 7000+ IPC calls
                    const topRows = doc.rows.whose({level: 1})();
                    const result = [];

                    for (let i = 0; i < topRows.length; i++) {
                        const row = topRows[i];
                        const rowData = {
                            id: row.id(),
                            topic: row.topic(),
                            level: 1,
                            state: row.state() || 'none'
                        };

                        if (includeNotes) {
                            rowData.note = row.note() || null;
                        }

                        result.push(rowData);
                    }

                    return JSON.stringify({
                        document: {
                            name: doc.name(),
                            totalRowCount: totalRowCount,
                            rowsReturned: result.length,
                            isFrontmost: index === 0,
                            autoLimited: true,
                            effectiveMaxDepth: 1,
                            message: 'Large document (' + totalRowCount + ' rows). Showing top-level only for performance. Use get_section_content(rowId) to explore sections, which returns totalRowsInSection.'
                        },
                        rows: result
                    });
                }

                // FULL MODE: Iterate all rows with descendantCount (for small docs or explicit maxDepth)
                const allRows = doc.rows();
                const result = [];
                const stack = []; // indices into result, representing open ancestors

                for (let i = 0; i < totalRowCount; i++) {
                    const row = allRows[i];
                    const level = row.level();

                    // Pop items from stack that are no longer ancestors (same or lower level)
                    while (stack.length > 0 && result[stack[stack.length - 1]].level >= level) {
                        stack.pop();
                    }

                    if (requestedMaxDepth !== null && level > requestedMaxDepth) {
                        // This row is not included, but is a descendant of everything on the stack
                        for (let s = 0; s < stack.length; s++) {
                            result[stack[s]].descendantCount++;
                        }
                        continue;
                    }

                    // This row is included and is a descendant of everything on the stack
                    for (let s = 0; s < stack.length; s++) {
                        result[stack[s]].descendantCount++;
                    }

                    const rowData = {
                        id: row.id(),
                        topic: row.topic(),
                        level: level,
                        state: row.state() || 'none',
                        descendantCount: 0
                    };

                    if (includeNotes) {
                        rowData.note = row.note() || null;
                    }

                    result.push(rowData);
                    stack.push(result.length - 1);
                }

                return JSON.stringify({
                    document: {
                        name: doc.name(),
                        totalRowCount: totalRowCount,
                        rowsReturned: result.length,
                        isFrontmost: index === 0
                    },
                    rows: result
                });
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to get outline: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    /// Get details for a specific row by ID.
    static func getRow(rowId: String, includeChildren: Bool = false, documentName: String? = nil) -> String {
        let escapedId = rowId.replacingOccurrences(of: "'", with: "\\'")
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc } = findDocument(app, documentName);
                const allRows = doc.rows();
                const targetId = '\(escapedId)';

                let targetRow = null;
                let targetIndex = -1;
                for (let i = 0; i < allRows.length; i++) {
                    if (allRows[i].id() === targetId) {
                        targetRow = allRows[i];
                        targetIndex = i;
                        break;
                    }
                }

                if (!targetRow) {
                    return JSON.stringify({ error: { code: 'row_not_found', message: 'Row not found: ' + targetId } });
                }

                const rowData = {
                    id: targetRow.id(),
                    topic: targetRow.topic(),
                    note: targetRow.note() || null,
                    level: targetRow.level(),
                    state: targetRow.state() || 'none'
                };

                const result = { row: rowData, documentName: doc.name() };

                if (\(includeChildren)) {
                    const targetLevel = targetRow.level();
                    const children = [];
                    for (let i = targetIndex + 1; i < allRows.length; i++) {
                        const childRow = allRows[i];
                        const childLevel = childRow.level();
                        if (childLevel <= targetLevel) break;
                        if (childLevel === targetLevel + 1) {
                            children.push({
                                id: childRow.id(),
                                topic: childRow.topic(),
                                note: childRow.note() || null,
                                level: childLevel,
                                state: childRow.state() || 'none'
                            });
                        }
                    }
                    result.children = children;
                }

                return JSON.stringify(result);
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to get row: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    /// Get children of a specific row (or top-level rows if rowId is nil).
    static func getRowChildren(rowId: String? = nil, documentName: String? = nil) -> String {
        let parentIdParam = rowId.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"

        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc } = findDocument(app, documentName);
                const allRows = doc.rows();
                const parentId = \(parentIdParam);

                const children = [];

                if (parentId === null) {
                    for (let i = 0; i < allRows.length; i++) {
                        const row = allRows[i];
                        if (row.level() === 1) {
                            children.push({
                                id: row.id(),
                                topic: row.topic(),
                                note: row.note() || null,
                                level: row.level(),
                                state: row.state() || 'none'
                            });
                        }
                    }
                } else {
                    let parentIndex = -1;
                    let parentLevel = -1;
                    for (let i = 0; i < allRows.length; i++) {
                        if (allRows[i].id() === parentId) {
                            parentIndex = i;
                            parentLevel = allRows[i].level();
                            break;
                        }
                    }

                    if (parentIndex === -1) {
                        return JSON.stringify({ error: { code: 'row_not_found', message: 'Parent row not found: ' + parentId } });
                    }

                    for (let i = parentIndex + 1; i < allRows.length; i++) {
                        const row = allRows[i];
                        const level = row.level();
                        if (level <= parentLevel) break;
                        if (level === parentLevel + 1) {
                            children.push({
                                id: row.id(),
                                topic: row.topic(),
                                note: row.note() || null,
                                level: level,
                                state: row.state() || 'none'
                            });
                        }
                    }
                }

                return JSON.stringify({
                    parentId: parentId,
                    documentName: doc.name(),
                    children: children
                });
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to get row children: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    /// Search for rows containing specific text.
    static func searchOutline(query: String, searchIn: String = "all",
                             caseSensitive: Bool = false, maxResults: Int = 50,
                             documentName: String? = nil) -> String {
        let escapedQuery = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc } = findDocument(app, documentName);
                const allRows = doc.rows();
                const query = '\(escapedQuery)';
                const searchIn = '\(searchIn)';
                const caseSensitive = \(caseSensitive);
                const maxResults = Math.min(\(maxResults), 100);

                const normalizedQuery = caseSensitive ? query : query.toLowerCase();
                const results = [];

                for (let i = 0; i < allRows.length && results.length < maxResults; i++) {
                    const row = allRows[i];
                    const topic = row.topic() || '';
                    const note = row.note() || '';
                    const normalizedTopic = caseSensitive ? topic : topic.toLowerCase();
                    const normalizedNote = caseSensitive ? note : note.toLowerCase();

                    const rowData = {
                        id: row.id(),
                        topic: topic,
                        note: note || null,
                        level: row.level(),
                        state: row.state() || 'none'
                    };

                    if ((searchIn === 'all' || searchIn === 'topics') && normalizedTopic.includes(normalizedQuery)) {
                        const idx = normalizedTopic.indexOf(normalizedQuery);
                        const start = Math.max(0, idx - 20);
                        const end = Math.min(topic.length, idx + query.length + 20);
                        results.push({
                            row: rowData,
                            matchContext: topic.substring(start, end),
                            matchField: 'topic'
                        });
                    } else if ((searchIn === 'all' || searchIn === 'notes') && normalizedNote.includes(normalizedQuery)) {
                        const idx = normalizedNote.indexOf(normalizedQuery);
                        const start = Math.max(0, idx - 20);
                        const end = Math.min(note.length, idx + query.length + 20);
                        results.push({
                            row: rowData,
                            matchContext: note.substring(start, end),
                            matchField: 'note'
                        });
                    }
                }

                return JSON.stringify({
                    documentName: doc.name(),
                    results: results,
                    totalMatches: results.length,
                    truncated: results.length >= maxResults
                });
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to search outline: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    // MARK: - Modification Scripts

    /// Add a new row to the outline.
    static func addRow(topic: String, note: String? = nil, parentId: String? = nil,
                      position: String = "last", siblingId: String? = nil,
                      relativePosition: String? = nil, documentName: String? = nil) -> String {
        let escapedTopic = topic
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let escapedNote = note?
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let noteParam = escapedNote.map { "'\($0)'" } ?? "null"
        let parentParam = parentId.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"

        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc } = findDocument(app, documentName);
                const topic = '\(escapedTopic)';
                const note = \(noteParam);
                const parentId = \(parentParam);
                const position = '\(position)';

                // Find parent row if specified
                let targetRows = doc.rows;
                let parentLevel = 0;

                if (parentId) {
                    const allRows = doc.rows();
                    let parentRow = null;
                    for (let i = 0; i < allRows.length; i++) {
                        if (allRows[i].id() === parentId) {
                            parentRow = allRows[i];
                            parentLevel = allRows[i].level();
                            break;
                        }
                    }
                    if (!parentRow) {
                        return JSON.stringify({ error: { code: 'row_not_found', message: 'Parent row not found: ' + parentId } });
                    }
                    targetRows = parentRow.rows;
                }

                // Create the new row
                const props = { topic: topic };
                if (note) {
                    props.note = note;
                }

                const newRow = app.Row(props);

                // Add to target (position first/last handled by unshift/push)
                if (position === 'first') {
                    targetRows.unshift(newRow);
                } else {
                    targetRows.push(newRow);
                }

                return JSON.stringify({
                    success: true,
                    documentName: doc.name(),
                    message: "Added row '" + topic + "'" + (parentId ? " under parent" : "") + " in '" + doc.name() + "'",
                    newRow: {
                        id: newRow.id(),
                        topic: newRow.topic(),
                        note: newRow.note() || null,
                        level: parentLevel + 1,
                        state: newRow.state() || 'none',
                        hasChildren: false,
                        parentId: parentId,
                        childIds: []
                    },
                    undoAvailable: true
                });
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to add row: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    /// Update an existing row.
    static func updateRow(rowId: String, topic: String? = nil,
                         note: String? = nil, state: String? = nil,
                         documentName: String? = nil) -> String {
        let escapedId = rowId.replacingOccurrences(of: "'", with: "\\'")
        let topicParam = topic.map { "'\($0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n"))'" } ?? "null"
        let noteParam = note.map { "'\($0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n"))'" } ?? "undefined"
        let stateParam = state.map { "'\($0)'" } ?? "null"
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"

        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc } = findDocument(app, documentName);
                const rowId = '\(escapedId)';
                const allRows = doc.rows();

                // Find the row
                let row = null;
                for (let i = 0; i < allRows.length; i++) {
                    if (allRows[i].id() === rowId) {
                        row = allRows[i];
                        break;
                    }
                }

                if (!row) {
                    return JSON.stringify({ error: { code: 'row_not_found', message: 'Row not found: ' + rowId } });
                }

                const changes = [];
                const newTopic = \(topicParam);
                const newNote = \(noteParam);
                const newState = \(stateParam);

                if (newTopic !== null) {
                    row.topic = newTopic;
                    changes.push('topic');
                }
                if (newNote !== undefined) {
                    row.note = newNote === '' ? null : newNote;
                    changes.push('note');
                }
                if (newState !== null) {
                    row.state = newState;
                    changes.push('state');
                }

                // Get child IDs
                const childRows = row.rows();
                const childIds = [];
                for (let i = 0; i < childRows.length; i++) {
                    childIds.push(childRows[i].id());
                }

                return JSON.stringify({
                    success: true,
                    documentName: doc.name(),
                    message: 'Updated row in ' + doc.name() + ': changed ' + changes.join(', '),
                    updatedRow: {
                        id: row.id(),
                        topic: row.topic(),
                        note: row.note() || null,
                        level: row.level(),
                        state: row.state() || 'none',
                        hasChildren: childRows.length > 0,
                        childIds: childIds
                    },
                    undoAvailable: true
                });
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to update row: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    /// Move a row to a new location.
    /// Note: JXA does not support direct row movement in OmniOutliner.
    /// This implementation uses copy-and-delete which changes the row ID.
    static func moveRow(rowId: String, newParentId: String? = nil,
                       position: String = "last", siblingId: String? = nil,
                       relativePosition: String? = nil, documentName: String? = nil) -> String {
        let escapedId = rowId.replacingOccurrences(of: "'", with: "\\'")
        let parentParam = newParentId.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"

        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc } = findDocument(app, documentName);
                const rowId = '\(escapedId)';
                const newParentId = \(parentParam);
                const position = '\(position)';
                const allRows = doc.rows();

                // Find the row to move
                let sourceRow = null;
                let sourceIndex = -1;
                for (let i = 0; i < allRows.length; i++) {
                    if (allRows[i].id() === rowId) {
                        sourceRow = allRows[i];
                        sourceIndex = i;
                        break;
                    }
                }

                if (!sourceRow) {
                    return JSON.stringify({ error: { code: 'row_not_found', message: 'Row not found: ' + rowId } });
                }

                // Prevent moving a row under itself or its descendants
                if (newParentId) {
                    const sourceLevel = sourceRow.level();
                    for (let i = sourceIndex; i < allRows.length; i++) {
                        const checkRow = allRows[i];
                        if (i > sourceIndex && checkRow.level() <= sourceLevel) break;
                        if (checkRow.id() === newParentId) {
                            return JSON.stringify({ error: { code: 'invalid_operation', message: 'Cannot move a row under itself or its descendants.' } });
                        }
                    }
                }

                // Gather source row data including all descendants
                function gatherRowData(row, rowIndex, allRows) {
                    const data = {
                        topic: row.topic(),
                        note: row.note() || null,
                        state: row.state() || 'none',
                        children: []
                    };

                    const rowLevel = row.level();
                    for (let i = rowIndex + 1; i < allRows.length; i++) {
                        const childRow = allRows[i];
                        const childLevel = childRow.level();
                        if (childLevel <= rowLevel) break;
                        if (childLevel === rowLevel + 1) {
                            data.children.push(gatherRowData(childRow, i, allRows));
                        }
                    }
                    return data;
                }

                const sourceData = gatherRowData(sourceRow, sourceIndex, allRows);
                const originalTopic = sourceData.topic;

                // Find target parent row if specified
                let targetRows = doc.rows;
                let newLevel = 1;

                if (newParentId) {
                    let parentRow = null;
                    for (let i = 0; i < allRows.length; i++) {
                        if (allRows[i].id() === newParentId) {
                            parentRow = allRows[i];
                            break;
                        }
                    }
                    if (!parentRow) {
                        return JSON.stringify({ error: { code: 'row_not_found', message: 'New parent row not found: ' + newParentId } });
                    }
                    targetRows = parentRow.rows;
                    newLevel = parentRow.level() + 1;
                }

                // Recursively create rows at destination
                function createRowWithChildren(data, targetCollection, insertFirst) {
                    const props = { topic: data.topic };
                    if (data.note) props.note = data.note;

                    const newRow = app.Row(props);

                    if (insertFirst) {
                        targetCollection.unshift(newRow);
                    } else {
                        targetCollection.push(newRow);
                    }

                    // Set state after insertion
                    if (data.state && data.state !== 'none') {
                        newRow.state = data.state;
                    }

                    // Recursively create children (always append children in order)
                    for (const childData of data.children) {
                        createRowWithChildren(childData, newRow.rows, false);
                    }

                    return newRow;
                }

                // Create the new row structure at destination
                const newRow = createRowWithChildren(sourceData, targetRows, position === 'first');

                // Delete the original row (this also deletes all its children)
                app.delete(sourceRow);

                // Get info about the new row
                const newChildRows = newRow.rows();
                const childIds = [];
                for (let i = 0; i < newChildRows.length; i++) {
                    childIds.push(newChildRows[i].id());
                }

                return JSON.stringify({
                    success: true,
                    documentName: doc.name(),
                    message: "Moved '" + originalTopic + "'" + (newParentId ? " under new parent" : " to top level") + " in '" + doc.name() + "'. Note: Row ID has changed.",
                    movedRow: {
                        id: newRow.id(),
                        topic: newRow.topic(),
                        note: newRow.note() || null,
                        level: newRow.level(),
                        state: newRow.state() || 'none',
                        hasChildren: newChildRows.length > 0,
                        parentId: newParentId,
                        childIds: childIds
                    },
                    previousRowId: rowId,
                    undoAvailable: true
                });
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to move row: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    /// Delete a row (with confirmation check).
    static func deleteRow(rowId: String, confirmed: Bool, documentName: String? = nil) -> String {
        let escapedId = rowId.replacingOccurrences(of: "'", with: "\\'")
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"

        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc } = findDocument(app, documentName);
                const rowId = '\(escapedId)';
                const confirmed = \(confirmed);
                const allRows = doc.rows();

                // Find the row
                let row = null;
                let rowIndex = -1;
                for (let i = 0; i < allRows.length; i++) {
                    if (allRows[i].id() === rowId) {
                        row = allRows[i];
                        rowIndex = i;
                        break;
                    }
                }

                if (!row) {
                    return JSON.stringify({ error: { code: 'row_not_found', message: 'Row not found: ' + rowId } });
                }

                const topic = row.topic();
                const rowLevel = row.level();

                // Count descendants (rows with higher level following this row until we hit same or lower level)
                const affectedRows = [{ id: row.id(), topic: topic }];
                for (let i = rowIndex + 1; i < allRows.length; i++) {
                    const childRow = allRows[i];
                    const childLevel = childRow.level();
                    if (childLevel <= rowLevel) break;
                    affectedRows.push({ id: childRow.id(), topic: childRow.topic() });
                }
                const childCount = affectedRows.length - 1;

                if (!confirmed) {
                    // Return preview without deleting
                    return JSON.stringify({
                        success: false,
                        documentName: doc.name(),
                        requiresConfirmation: true,
                        message: "This will delete '" + topic + "' and " + childCount + " child rows from '" + doc.name() + "'. Set confirmed=true to proceed.",
                        affectedRows: affectedRows
                    });
                }

                // Perform deletion
                app.delete(row);

                return JSON.stringify({
                    success: true,
                    documentName: doc.name(),
                    message: "Deleted '" + topic + "' and " + childCount + " child rows from '" + doc.name() + "'. Use Cmd+Z in OmniOutliner to undo.",
                    deletedCount: childCount + 1,
                    undoAvailable: true
                });
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to delete row: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    // MARK: - Synthesis Scripts

    /// Get section content in various formats with pagination support.
    static func getSectionContent(rowId: String? = nil, format: String = "structured", documentName: String? = nil, offset: Int = 0, limit: Int = 500) -> String {
        let rowParam = rowId.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"

        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc } = findDocument(app, documentName);
                const rowId = \(rowParam);
                const format = '\(format)';
                const offset = \(offset);
                const limit = \(limit);
                const allRows = doc.rows();
                const totalRowCount = allRows.length;

                let sectionTitle = doc.name();
                let sectionId = null;
                let startIndex = 0;
                let baseLevel = 0;

                if (rowId) {
                    // Find the section row
                    let sectionRow = null;
                    for (let i = 0; i < allRows.length; i++) {
                        if (allRows[i].id() === rowId) {
                            sectionRow = allRows[i];
                            startIndex = i;
                            break;
                        }
                    }
                    if (!sectionRow) {
                        return JSON.stringify({ error: { code: 'row_not_found', message: 'Section not found: ' + rowId } });
                    }
                    sectionTitle = sectionRow.topic();
                    sectionId = sectionRow.id();
                    baseLevel = sectionRow.level();
                    startIndex++; // Start from children
                }

                // Pagination-optimized row collection
                // - Rows before offset: only check level (1 IPC) for section boundary
                // - Rows in window: full property access (5 IPC)
                // - Rows after window: only check level (1 IPC) for counting
                const rows = [];
                let rowsInSection = 0;
                let prevLevel = baseLevel;

                for (let i = startIndex; i < allRows.length; i++) {
                    const row = allRows[i];
                    const level = row.level();

                    // Stop if we've exited the section (for rowId mode)
                    if (rowId && level <= baseLevel) break;

                    // Count this row in the section
                    rowsInSection++;

                    // Skip rows before offset (minimal IPC - already got level)
                    if (rowsInSection <= offset) {
                        continue;
                    }

                    // Stop collecting after limit, but continue counting
                    if (rows.length >= limit) {
                        continue;
                    }

                    // Collect this row (full property access)
                    const adjustedLevel = rowId ? level - baseLevel : level;

                    // Mark previous row as having children if current is deeper
                    if (rows.length > 0 && adjustedLevel > prevLevel) {
                        for (let k = rows.length - 1; k >= 0; k--) {
                            if (rows[k].level === adjustedLevel - 1) {
                                rows[k].hasChildren = true;
                                break;
                            }
                        }
                    }

                    rows.push({
                        id: row.id(),
                        topic: row.topic(),
                        note: row.note() || null,
                        level: adjustedLevel,
                        state: row.state() || 'none',
                        hasChildren: false
                    });

                    prevLevel = adjustedLevel;
                }

                const pagination = {
                    offset: offset,
                    limit: limit,
                    rowsReturned: rows.length,
                    totalRowsInSection: rowsInSection,
                    hasMore: (offset + rows.length) < rowsInSection
                };

                const section = {
                    title: sectionTitle,
                    id: sectionId,
                    documentName: doc.name(),
                    totalRowsInDocument: totalRowCount
                };

                if (format === 'markdown') {
                    let md = '# ' + sectionTitle + '\\n\\n';
                    for (const row of rows) {
                        const indent = '  '.repeat(Math.max(0, row.level - 1));
                        md += indent + '- ' + row.topic + '\\n';
                        if (row.note) {
                            md += indent + '  > ' + row.note + '\\n';
                        }
                    }
                    if (pagination.hasMore) {
                        md += '\\n... (page ' + Math.floor(offset / limit + 1) + ', showing rows ' + (offset + 1) + '-' + (offset + rows.length) + ' of ' + rowsInSection + ')\\n';
                    }
                    return JSON.stringify({
                        section: section,
                        pagination: pagination,
                        markdown: md
                    });
                } else if (format === 'plain') {
                    let text = sectionTitle + '\\n';
                    for (const row of rows) {
                        const indent = '  '.repeat(row.level);
                        text += indent + row.topic + '\\n';
                        if (row.note) {
                            text += indent + '  [Note: ' + row.note + ']\\n';
                        }
                    }
                    if (pagination.hasMore) {
                        text += '\\n... (page ' + Math.floor(offset / limit + 1) + ', showing rows ' + (offset + 1) + '-' + (offset + rows.length) + ' of ' + rowsInSection + ')\\n';
                    }
                    return JSON.stringify({
                        section: section,
                        pagination: pagination,
                        text: text
                    });
                } else {
                    return JSON.stringify({
                        section: section,
                        pagination: pagination,
                        rows: rows
                    });
                }
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to get section content: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    /// Insert content into the outline.
    static func insertContent(content: String, parentId: String? = nil, position: String = "last", documentName: String? = nil) -> String {
        let escapedContent = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let parentParam = parentId.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        let documentNameParam = documentName.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"

        return """
        function run() {
            const app = Application('OmniOutliner');
            if (!app.running()) {
                return JSON.stringify({ error: { code: 'app_not_running', message: 'OmniOutliner is not running.' } });
            }

            \(documentLookupHelper)

            try {
                const documentName = \(documentNameParam);
                const { doc } = findDocument(app, documentName);
                const contentStr = '\(escapedContent)';
                const parentId = \(parentParam);
                const position = '\(position)';
                const allRows = doc.rows();

                // Find parent row if specified
                let targetRows = doc.rows;
                if (parentId) {
                    let parentRow = null;
                    for (let i = 0; i < allRows.length; i++) {
                        if (allRows[i].id() === parentId) {
                            parentRow = allRows[i];
                            break;
                        }
                    }
                    if (!parentRow) {
                        return JSON.stringify({ error: { code: 'row_not_found', message: 'Parent row not found: ' + parentId } });
                    }
                    targetRows = parentRow.rows;
                }

                // Try to parse content as JSON array
                let content;
                try {
                    content = JSON.parse(contentStr);
                } catch (e) {
                    // Treat as single text item
                    content = [{ topic: contentStr }];
                }

                if (!Array.isArray(content)) {
                    content = [content];
                }

                // Create rows recursively
                function createRows(items, target, insertFirst) {
                    const created = [];
                    // If inserting first, reverse the array so they end up in correct order
                    const itemsToProcess = insertFirst ? items.slice().reverse() : items;
                    for (const itemData of itemsToProcess) {
                        const props = { topic: itemData.topic || '' };
                        if (itemData.note) {
                            props.note = itemData.note;
                        }

                        const newRow = app.Row(props);
                        if (insertFirst) {
                            target.unshift(newRow);
                        } else {
                            target.push(newRow);
                        }

                        created.push({
                            id: newRow.id(),
                            topic: newRow.topic(),
                            note: newRow.note() || null
                        });

                        // Create children if present (always append children)
                        if (itemData.children && itemData.children.length > 0) {
                            const childResults = createRows(itemData.children, newRow.rows, false);
                            created.push(...childResults);
                        }
                    }
                    // Restore original order for created array if we reversed
                    return insertFirst ? created.reverse() : created;
                }

                const insertedRows = createRows(content, targetRows, position === 'first');

                return JSON.stringify({
                    success: true,
                    documentName: doc.name(),
                    message: 'Inserted ' + insertedRows.length + ' rows' + (parentId ? ' under parent' : '') + ' in ' + doc.name(),
                    insertedRows: insertedRows,
                    undoAvailable: true
                });
            } catch (e) {
                if (e.code) {
                    return JSON.stringify({ error: e });
                }
                return JSON.stringify({
                    error: {
                        code: 'operation_failed',
                        message: 'Failed to insert content: ' + e.message,
                        technicalDetail: e.toString()
                    }
                });
            }
        }
        """
    }

    // MARK: - Status Script

    /// Check connection to OmniOutliner.
    static let checkConnection = """
    function run() {
        const app = Application('OmniOutliner');

        if (!app.running()) {
            return JSON.stringify({
                connected: false,
                appRunning: false,
                documentOpen: false,
                documentName: null,
                message: 'OmniOutliner is not running. Please launch OmniOutliner and open a document.'
            });
        }

        try {
            const docs = app.documents();
            if (docs.length === 0) {
                return JSON.stringify({
                    connected: false,
                    appRunning: true,
                    documentOpen: false,
                    documentName: null,
                    message: 'OmniOutliner is running but no document is open. Please open a document.'
                });
            }

            const doc = docs[0];
            const docName = doc.name();

            return JSON.stringify({
                connected: true,
                appRunning: true,
                documentOpen: true,
                documentName: docName,
                message: 'Connected to OmniOutliner. Document \\'' + docName + '\\' is open.'
            });
        } catch (e) {
            return JSON.stringify({
                connected: false,
                appRunning: true,
                documentOpen: false,
                documentName: null,
                message: 'Error checking OmniOutliner status: ' + e.message
            });
        }
    }
    """
}
