import Foundation
import NoteModel
import SchemaTesting
import SwiftData
import Testing

/// Guards the store on people's devices: the plan is complete, shipped versions haven't been
/// edited, and a store written by each one still opens with its boards and notes.
///
/// `Fixtures` holds one store and one shape per version. To record the current version:
///
///     RECORD_SCHEMA_FIXTURES=1 swift test --package-path Packages/swift-note-kit \
///       --filter SchemaMigrationTests
///
/// Recording never overwrites a file. Commit what it writes.
@Suite("Schema migration")
struct SchemaMigrationTests {
    let audit = MigrationAudit(plan: NoteMigrationPlan.self, current: CurrentSchema.self)
    let fixtures = SchemaFixtures(plan: NoteMigrationPlan.self, current: CurrentSchema.self)

    @Test("The plan's versions and stages are complete and in order")
    func planIsComplete() {
        #expect(audit.planProblems() == [])
    }

    @Test("The containers open with the plan and the current schema")
    func containersCarryThePlan() throws {
        #expect(audit.containerProblems(try .inMemory()) == [])
    }

    /// The models are written to stay CloudKit-safe, so turning sync on needs no migration.
    /// Evolution isn't checked: while the store doesn't sync, a version may still drop a field.
    @Test("Every model could be mirrored to CloudKit")
    func modelsCouldSync() {
        #expect(audit.syncShapeProblems() == [])
    }

    @Test("Every @Model is listed by a version in the plan")
    func everyModelIsListed() {
        let kit = URL(filePath: #filePath)
            .deletingLastPathComponent()  // NoteModelTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()
        let app =
            kit
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()
            .appending(path: "StickyNotes")
        #expect(
            audit.unlistedModelProblems(inSourcesUnder: [kit.appending(path: "Sources"), app]) == []
        )
    }

    @Test("A store from every version opens under the current schema with its notes intact")
    func recordedStoresMigrate() throws {
        try fixtures.recordIfRequested(Fixture.write)
        #expect(fixtures.problems() == [])
        try fixtures.eachRecordedStore(Fixture.check)
    }
}

/// Written with the models directly, so a change to `NoteStore`'s rules can't change what a
/// version wrote. Dates are fixed so the expectations don't depend on when the tests run.
private enum Fixture {
    static let boardCreated = Date(timeIntervalSinceReferenceDate: 700_000_000)
    static let noteCreated = Date(timeIntervalSinceReferenceDate: 750_000_000)
    static let boardID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let emptyBoardID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let noteID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    static func write(in context: ModelContext) {
        let board = Board(name: "Kitchen wall")
        board.id = boardID
        board.createdAt = boardCreated
        context.insert(board)

        // Everything a note can carry.
        let note = Note(
            center: CGPoint(x: 120.5, y: -40), color: .teal, z: 7, text: "Call the plumber")
        note.id = noteID
        note.side = 220
        note.createdAt = noteCreated
        note.board = board
        context.insert(note)

        // A color this build doesn't know, which has to be kept as it was written.
        let future = Note(center: .zero, color: .yellow, z: 1)
        future.colorRaw = "mauve"
        future.board = board
        context.insert(future)

        // An empty name and no notes: the to-many that comes back empty rather than absent.
        let empty = Board(name: "")
        empty.id = emptyBoardID
        empty.createdAt = boardCreated
        context.insert(empty)
    }

    static func check(_ version: Schema.Version, _ context: ModelContext) throws {
        let boards = try context.fetch(FetchDescriptor<Board>())
        let notes = try context.fetch(FetchDescriptor<Note>())
        #expect(boards.count == 2, "\(version): boards")
        #expect(notes.count == 2, "\(version): notes")

        let board = try #require(boards.first { $0.id == boardID }, "\(version): the full board")
        #expect(board.name == "Kitchen wall", "\(version): a board's name")
        #expect(board.createdAt == boardCreated, "\(version): when a board was made")
        #expect(board.notes?.count == 2, "\(version): a board's notes")

        let note = try #require(notes.first { $0.id == noteID }, "\(version): the full note")
        #expect(note.text == "Call the plumber", "\(version): a note's words")
        #expect(note.center == CGPoint(x: 120.5, y: -40), "\(version): where it sits")
        #expect(note.color == .teal, "\(version): its color")
        #expect(note.side == 220, "\(version): its size")
        #expect(note.z == 7, "\(version): its stacking order")
        #expect(note.createdAt == noteCreated, "\(version): when it was made")
        #expect(note.board?.id == boardID, "\(version): the board it's on")

        let future = try #require(notes.first { $0.id != noteID }, "\(version): the other note")
        #expect(future.colorRaw == "mauve", "\(version): an unknown color, kept")
        #expect(future.text.isEmpty, "\(version): a note with no words")

        let empty = try #require(
            boards.first { $0.id == emptyBoardID }, "\(version): the empty board")
        #expect(empty.name.isEmpty, "\(version): a board with no name")
        #expect(empty.notes?.isEmpty == true, "\(version): a board with no notes")
    }
}
