import CoreGraphics
import Foundation
import SwiftData
import Testing

@testable import NoteModel

struct BoardStoreTests {
    let container: ModelContainer
    let store: NoteStore
    let visible = CGRect(x: 0, y: 0, width: 400, height: 800)

    init() throws {
        container = try .inMemory()
        store = NoteStore(context: container.mainContext)
    }

    private func notes(on board: Board) throws -> [Note] {
        let id = board.id
        return try container.mainContext.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.board?.id == id }))
    }

    private func boards() throws -> [Board] {
        try container.mainContext.fetch(FetchDescriptor<Board>())
    }

    @Test func aNoteGoesOnTheBoardItWasAddedTo() throws {
        let home = store.addBoard(named: "Home")
        let work = store.addBoard(named: "Work")
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: work)
        #expect(note.board == work)
        #expect(try notes(on: home).isEmpty)
        #expect(try notes(on: work).map(\.id) == [note.id])
    }

    /// Each board starts its own stack and its own color rotation.
    @Test func boardsDontStackOrColorEachOther() {
        let home = store.addBoard(named: "Home")
        let work = store.addBoard(named: "Work")
        store.add(at: CGPoint(x: 200, y: 300), within: visible, on: home)
        store.add(at: CGPoint(x: 200, y: 300), within: visible, on: home)

        let first = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: work)
        #expect(first.color == .yellow)
        #expect(first.z == 0)
    }

    @Test func aDropOnlyLooksAtItsOwnBoard() {
        let home = store.addBoard(named: "Home")
        let work = store.addBoard(named: "Work")
        let alone = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: home)
        store.add(at: CGPoint(x: 200, y: 300), within: visible, on: work)
        store.add(at: CGPoint(x: 200, y: 300), within: visible, on: work)

        store.drop(alone, at: alone.center)
        #expect(alone.z == 0)
    }

    @Test func deletingABoardDeletesItsNotesAndNoOthers() throws {
        let home = store.addBoard(named: "Home")
        let work = store.addBoard(named: "Work")
        let kept = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: home)
        store.add(at: CGPoint(x: 200, y: 300), within: visible, on: work)

        store.delete(work)

        #expect(try boards().map(\.id) == [home.id])
        let all = try container.mainContext.fetch(FetchDescriptor<Note>())
        #expect(all.map(\.id) == [kept.id])
    }

    /// Typing on a board as it is deleted goes with the board, and leaves nothing to save.
    @Test func deletingABoardWhileTypingOnItLeavesNothingBehind() throws {
        let home = store.addBoard(named: "Home")
        let work = store.addBoard(named: "Work")
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: work)
        store.setText("Milk", of: note)

        store.delete(work)
        store.saveText()

        #expect(try boards().map(\.id) == [home.id])
        #expect(try container.mainContext.fetch(FetchDescriptor<Note>()).isEmpty)
        #expect(!container.mainContext.hasChanges)
    }

    @Test func renameSaves() throws {
        let board = store.addBoard(named: "Home")
        store.rename(board, to: "Kitchen")
        #expect(!container.mainContext.hasChanges)
        #expect(
            try ModelContext(container).fetch(FetchDescriptor<Board>()).first?.name == "Kitchen")
    }

    @Test func firstBoardIsMadeOnlyWhenThereAreNone() throws {
        let made = store.firstBoard(creatingOneNamed: "My Board")
        #expect(made.name == "My Board")

        store.addBoard(named: "Later")
        #expect(store.firstBoard(creatingOneNamed: "Another") == made)
        #expect(try boards().count == 2)
    }

    /// A note from a store made before boards would otherwise be on no canvas at all.
    @Test func firstBoardTakesInNotesWithoutOne() throws {
        let stray = Note(center: CGPoint(x: 200, y: 300), color: .blue, z: 0)
        container.mainContext.insert(stray)
        try container.mainContext.save()

        let board = store.firstBoard(creatingOneNamed: "My Board")
        #expect(stray.board == board)
        #expect(!container.mainContext.hasChanges)
    }
}
