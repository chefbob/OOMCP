import XCTest
@testable import OOMCP

final class DocumentModelTests: XCTestCase {

    // MARK: - Document Tests

    func testDocumentInitialization() {
        let doc = Document(
            name: "Test.ooutline",
            path: "/path/to/Test.ooutline",
            isFrontmost: true,
            canUndo: true,
            canRedo: false,
            rowCount: 10
        )

        XCTAssertEqual(doc.name, "Test.ooutline")
        XCTAssertEqual(doc.path, "/path/to/Test.ooutline")
        XCTAssertTrue(doc.isFrontmost)
        XCTAssertTrue(doc.canUndo)
        XCTAssertFalse(doc.canRedo)
        XCTAssertEqual(doc.rowCount, 10)
    }

    func testDocumentDefaultValues() {
        let doc = Document(name: "Test.ooutline")

        XCTAssertNil(doc.path)
        XCTAssertTrue(doc.isFrontmost)
        XCTAssertFalse(doc.canUndo)
        XCTAssertFalse(doc.canRedo)
        XCTAssertEqual(doc.rowCount, 0)
    }

    func testDocumentCodable() throws {
        let doc = Document(
            name: "Test.ooutline",
            path: "/path/to/file",
            isFrontmost: true,
            canUndo: true,
            canRedo: false,
            rowCount: 5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(doc)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Document.self, from: data)

        XCTAssertEqual(doc, decoded)
    }

    // MARK: - Row Tests

    func testRowInitialization() {
        let row = Row(
            id: "row-123",
            topic: "Test Topic",
            note: "Test Note",
            level: 2,
            state: .checked,
            hasChildren: true,
            parentId: "parent-456",
            childIds: ["child-1", "child-2"]
        )

        XCTAssertEqual(row.id, "row-123")
        XCTAssertEqual(row.topic, "Test Topic")
        XCTAssertEqual(row.note, "Test Note")
        XCTAssertEqual(row.level, 2)
        XCTAssertEqual(row.state, .checked)
        XCTAssertTrue(row.hasChildren)
        XCTAssertEqual(row.parentId, "parent-456")
        XCTAssertEqual(row.childIds, ["child-1", "child-2"])
    }

    func testRowDefaultValues() {
        let row = Row(id: "row-123", topic: "Test")

        XCTAssertNil(row.note)
        XCTAssertEqual(row.level, 0)
        XCTAssertEqual(row.state, .none)
        XCTAssertFalse(row.hasChildren)
        XCTAssertNil(row.parentId)
        XCTAssertEqual(row.childIds, [])
    }

    func testRowCodable() throws {
        let row = Row(
            id: "row-123",
            topic: "Test",
            note: "Note",
            level: 1,
            state: .unchecked,
            hasChildren: false,
            parentId: nil,
            childIds: []
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(row)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Row.self, from: data)

        XCTAssertEqual(row, decoded)
    }

    // MARK: - RowState Tests

    func testRowStateValues() {
        XCTAssertEqual(RowState.unchecked.rawValue, "unchecked")
        XCTAssertEqual(RowState.checked.rawValue, "checked")
        XCTAssertEqual(RowState.mixed.rawValue, "mixed")
        XCTAssertEqual(RowState.none.rawValue, "none")
    }

    func testRowStateCodable() throws {
        let states: [RowState] = [.unchecked, .checked, .mixed, .none]

        for state in states {
            let encoder = JSONEncoder()
            let data = try encoder.encode(state)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(RowState.self, from: data)

            XCTAssertEqual(state, decoded)
        }
    }

    // MARK: - Column Tests

    func testColumnInitialization() {
        let column = Column(id: "col-1", name: "Status", type: .checkbox)

        XCTAssertEqual(column.id, "col-1")
        XCTAssertEqual(column.name, "Status")
        XCTAssertEqual(column.type, .checkbox)
    }

    func testColumnTypeCodable() throws {
        let types: [ColumnType] = [.text, .number, .checkbox, .date, .duration, .popup, .richText]

        for type in types {
            let encoder = JSONEncoder()
            let data = try encoder.encode(type)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ColumnType.self, from: data)

            XCTAssertEqual(type, decoded)
        }
    }

    // MARK: - RowLocation Tests

    func testRowLocationDefaults() {
        let location = RowLocation()

        XCTAssertNil(location.parentId)
        XCTAssertEqual(location.position, .last)
        XCTAssertNil(location.siblingId)
    }

    func testRowLocationWithSibling() {
        let location = RowLocation(
            parentId: "parent-1",
            position: .after,
            siblingId: "sibling-1"
        )

        XCTAssertEqual(location.parentId, "parent-1")
        XCTAssertEqual(location.position, .after)
        XCTAssertEqual(location.siblingId, "sibling-1")
    }

    // MARK: - SearchResult Tests

    func testSearchResultInitialization() {
        let row = Row(id: "row-1", topic: "Test Topic")
        let result = SearchResult(
            row: row,
            matchContext: "...Test Topic...",
            matchField: .topic
        )

        XCTAssertEqual(result.row.id, "row-1")
        XCTAssertEqual(result.matchContext, "...Test Topic...")
        XCTAssertEqual(result.matchField, .topic)
    }

    // MARK: - OperationResult Tests

    func testOperationResultSuccess() {
        let result = OperationResult(
            success: true,
            message: "Row added",
            affectedRowIds: ["row-1"],
            undoAvailable: true
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Row added")
        XCTAssertEqual(result.affectedRowIds, ["row-1"])
        XCTAssertTrue(result.undoAvailable)
    }

    func testOperationResultDefaults() {
        let result = OperationResult(success: true, message: "Done")

        XCTAssertNil(result.affectedRowIds)
        XCTAssertTrue(result.undoAvailable)
    }

    // MARK: - OutlineTree Tests

    func testOutlineTreeInitialization() {
        let doc = Document(name: "Test.ooutline")
        let rows = [Row(id: "1", topic: "Row 1"), Row(id: "2", topic: "Row 2")]
        let tree = OutlineTree(document: doc, rootRows: rows)

        XCTAssertEqual(tree.document.name, "Test.ooutline")
        XCTAssertEqual(tree.rootRows.count, 2)
    }

    // MARK: - SizeConstraints Tests

    func testSizeConstraints() {
        XCTAssertEqual(SizeConstraints.maxTopicLength, 65535)
        XCTAssertEqual(SizeConstraints.maxNoteLength, 1_000_000)
        XCTAssertEqual(SizeConstraints.maxSearchResults, 100)
        XCTAssertEqual(SizeConstraints.maxBatchOperation, 50)
    }
}
