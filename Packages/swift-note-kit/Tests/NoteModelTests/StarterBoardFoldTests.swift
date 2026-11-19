import CoreGraphics
import Foundation
import SwiftData
import Testing

@testable import NoteModel

/// Two devices each make a starter board on their first launch; once they sync, both boards are
/// in each store. These stand in for that by inserting the boards a sync would bring.
struct StarterBoardFoldTests {
    let container: ModelContainer
    let store: NoteStore
    let undo = UndoManager()
    let visible = CGRect(x: 0, y: 0, width: 400, height: 800)

    static let older = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let newer = Date(timeIntervalSinceReferenceDate: 800_000_100)
    static let lowID = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    static let highID = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

    init() throws {
        container = try .inMemory()
        store = NoteStore(context: container.mainContext)
        undo.groupsByEvent = false
        store.undoManager = undo
    }

    /// A starter board as another device would have made it.
    @discardableResult
    private func starter(
        _ name: String, id: UUID = UUID(), createdAt: Date, in context: ModelContext? = nil
    ) throws -> Board {
        let context = context ?? container.mainContext
        let board = Board(name: name, isStarter: true)
        board.id = id
        board.createdAt = createdAt
        context.insert(board)
        try context.save()
        return board
    }

    /// What is saved, read through a context of its own.
    private func savedBoards() throws -> [Board] {
        try ModelContext(container).fetch(
            FetchDescriptor<Board>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    @Test func theFirstLaunchBoardIsTheStarterAndNoOtherIs() {
        let first = store.firstBoard(creatingOneNamed: "My Board")
        let later = store.addBoard(named: "Later")
        #expect(first.isStarter)
        #expect(!later.isStarter)
    }

    @Test func theOldestStarterTakesTheOthersNotesAboveItsOwn() throws {
        let kept = try starter("Kitchen", createdAt: Self.older)
        let folded = try starter("My Board", createdAt: Self.newer)
        let own = store.add(at: CGPoint(x: 100, y: 100), within: visible, on: kept)
        let low = store.add(at: CGPoint(x: 200, y: 200), within: visible, on: folded)
        let high = store.add(at: CGPoint(x: 300, y: 300), within: visible, on: folded)
        #expect([own.z, low.z, high.z] == [Int]([0, 0, 1]))

        #expect(store.foldStarterBoards() == 1)

        let boards = try savedBoards()
        #expect(boards.map(\.id) == [kept.id])
        #expect(boards.first?.name == "Kitchen", "the survivor keeps its own name")
        let notes = (boards.first?.notes ?? []).sorted { $0.z < $1.z }
        #expect(notes.map(\.id) == [own.id, low.id, high.id])
        #expect(notes.map(\.z) == [Int]([0, 1, 2]))
    }

    /// Both devices fold, so both must keep the same board: otherwise each deletes the one the
    /// other kept, and the two deletes sync into no board at all.
    @Test func everyStoreKeepsTheSameBoardWhateverOrderItFoundThemIn() throws {
        let other = try ModelContainer.inMemory()
        let otherStore = NoteStore(context: other.mainContext)

        try starter("Mine", id: Self.highID, createdAt: Self.older)
        try starter("Theirs", id: Self.lowID, createdAt: Self.older)
        try starter("Theirs", id: Self.lowID, createdAt: Self.older, in: other.mainContext)
        try starter("Mine", id: Self.highID, createdAt: Self.older, in: other.mainContext)

        store.foldStarterBoards()
        otherStore.foldStarterBoards()

        #expect(try savedBoards().map(\.id) == [Self.lowID], "a tie goes to the lowest id")
        let otherBoards = try ModelContext(other).fetch(FetchDescriptor<Board>())
        #expect(otherBoards.map(\.id) == [Self.lowID])
    }

    @Test func boardsTheReaderMadeAreNeverFolded() throws {
        let starter = try starter("My Board", createdAt: Self.newer)
        let made = store.addBoard(named: "My Board")
        store.add(at: CGPoint(x: 200, y: 200), within: visible, on: made)

        #expect(store.foldStarterBoards() == 0)
        #expect(Set(try savedBoards().map(\.id)) == Set([starter.id, made.id]))
        #expect(made.notes?.count == 1)
    }

    @Test func anUndoneDeleteFromAFoldedBoardComesBackOnTheSurvivor() throws {
        let kept = try starter("Kept", createdAt: Self.older)
        let folded = try starter("Folded", createdAt: Self.newer)
        let note = store.add(at: CGPoint(x: 200, y: 200), within: visible, on: folded)
        let id = note.id
        store.delete(note)
        #expect(store.lastDeletion?.boardID == folded.id)

        store.foldStarterBoards()
        #expect(store.lastDeletion?.boardID == kept.id, "the survivor offers it back now")

        undo.undo()
        let back = try ModelContext(container).fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.id == id }))
        #expect(back.first?.board?.id == kept.id)
    }
}
