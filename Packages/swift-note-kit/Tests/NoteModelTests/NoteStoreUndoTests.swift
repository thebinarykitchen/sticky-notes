import CoreGraphics
import Foundation
import SwiftData
import Testing

@testable import NoteModel

/// Each check reads the store through a context of its own: the models alone can say an undo
/// worked when the store never heard of it, which is how SwiftData's own undo fails.
struct NoteStoreUndoTests {
    let container: ModelContainer
    let store: NoteStore
    let undo = UndoManager()
    let visible = CGRect(x: 0, y: 0, width: 400, height: 800)
    let board: Board

    init() throws {
        container = try .inMemory()
        store = NoteStore(context: container.mainContext)
        board = store.addBoard(named: "Board")
        // Grouped by hand, so a test needn't spin a run loop; the store opens a group per write.
        undo.groupsByEvent = false
        store.undoManager = undo
    }

    /// What is saved, keyed by id.
    private func stored() throws -> [UUID: NoteValues] {
        let notes = try ModelContext(container).fetch(FetchDescriptor<Note>())
        return Dictionary(uniqueKeysWithValues: notes.map { ($0.id, NoteValues(of: $0)) })
    }

    @Test func undoingAnAddRemovesTheNoteAndRedoBringsItBackWithItsText() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let id = note.id
        store.setText("Milk", of: note)

        undo.undo()
        #expect(try stored().isEmpty)

        undo.redo()
        #expect(try stored()[id]?.text == "Milk")
    }

    @Test func oneUndoTakesBackNotesAddedTogetherAndRedoBringsThemBackWithTheirText() throws {
        let kept = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let ids = store.add(["Milk", "Eggs", "Bread"], within: visible, on: board).map(\.id)

        undo.undo()
        #expect(try Set(stored().keys) == [kept.id])

        undo.redo()
        let stored = try stored()
        #expect(ids.map { stored[$0]?.text } == ["Milk", "Eggs", "Bread"])
    }

    @Test func addingNoTextsLeavesNothingToUndo() {
        store.add([], within: visible, on: board)
        #expect(!undo.canUndo)
    }

    @Test func undoingADeleteBringsTheNoteBackAsItWas() throws {
        let note = store.add(at: CGPoint(x: 120, y: 300), within: visible, on: board)
        store.setText("Call the dentist", of: note)
        store.resize(note, to: 240)
        let before = try #require(try stored()[note.id])

        store.delete(note)
        #expect(try stored().isEmpty)

        undo.undo()
        let after = try #require(try stored()[before.id])
        #expect(after.text == before.text)
        #expect(after.x == before.x && after.y == before.y)
        #expect(after.side == before.side)
        #expect(after.colorRaw == before.colorRaw)
        #expect(after.z == before.z)
        #expect(after.createdAt == before.createdAt)
        #expect(after.boardID == board.id)

        undo.redo()
        #expect(try stored().isEmpty)
    }

    /// Deleted before typing paused, a note still comes back with every word typed into it.
    @Test func undoingADeleteBringsBackTextStillWaitingToSave() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let id = note.id
        store.setText("Milk", of: note)

        store.delete(note)
        undo.undo()
        #expect(try stored()[id]?.text == "Milk")
    }

    /// A redo after undoing the delete deletes the note brought back, not the one first deleted.
    @Test func undoAndRedoGoOnReachingTheNoteBroughtBack() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let id = note.id
        store.delete(note)

        undo.undo()
        undo.redo()
        undo.undo()
        #expect(try stored()[id] != nil)
        undo.undo()
        #expect(try stored().isEmpty)
    }

    @Test func undoingAMovePutsTheNoteBackButKeepsItsText() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.move(note, to: CGPoint(x: 250, y: 600))
        store.setText("Typed after the move", of: note)

        undo.undo()
        let values = try #require(try stored()[note.id])
        #expect(values.x == 200 && values.y == 300)
        #expect(values.text == "Typed after the move")

        undo.redo()
        #expect(try stored()[note.id]?.y == 600)
    }

    @Test func undoingAResizePutsTheSizeBack() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.resize(note, to: NoteGeometry.maxSide)

        undo.undo()
        #expect(try stored()[note.id]?.side == NoteGeometry.defaultSide)

        undo.redo()
        #expect(try stored()[note.id]?.side == NoteGeometry.maxSide)
    }

    @Test func undoingARecolorPutsTheColorBackButKeepsItsText() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.recolor(note, to: .green)
        store.setText("Typed after the recolor", of: note)

        undo.undo()
        let values = try #require(try stored()[note.id])
        #expect(values.colorRaw == NoteColor.yellow.rawValue)
        #expect(values.text == "Typed after the recolor")

        undo.redo()
        #expect(try stored()[note.id]?.colorRaw == NoteColor.green.rawValue)
    }

    /// A drop where it was picked up, a resize held at a limit it was already at, or the color it
    /// already is.
    @Test func aWriteThatChangesNothingLeavesNothingToUndo() {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        undo.removeAllActions()

        store.move(note, to: CGPoint(x: 200, y: 300))
        store.resize(note, to: NoteGeometry.defaultSide)
        store.recolor(note, to: note.color)
        #expect(!undo.canUndo)
    }

    @Test func lastDeletionIsOnlyTheNextUndo() {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let other = store.add(at: CGPoint(x: 200, y: 600), within: visible, on: board)

        store.delete(note)
        #expect(store.lastDeletion?.noteID == note.id)

        store.move(other, to: CGPoint(x: 100, y: 600))
        #expect(store.lastDeletion == nil)

        store.delete(other)
        undo.undo()
        #expect(store.lastDeletion == nil)
    }

    /// The next undo would take back the recolor, not bring the note back.
    @Test func aRecolorStopsOfferingTheDeleteBack() {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        let other = store.add(at: CGPoint(x: 200, y: 600), within: visible, on: board)

        store.delete(note)
        store.recolor(other, to: .green)
        #expect(store.lastDeletion == nil)
    }

    @Test func eachActionIsNamed() {
        store.actionName = { "\($0)" }
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        #expect(undo.undoActionName == "add")
        store.add(["Milk", "Eggs"], within: visible, on: board)
        #expect(undo.undoActionName == "addSeveral")
        store.recolor(note, to: .blue)
        #expect(undo.undoActionName == "recolor")
        store.delete(note)
        #expect(undo.undoActionName == "delete")
        undo.undo()
        #expect(undo.redoActionName == "delete")
    }

    @Test func withoutAManagerWritesStillSave() throws {
        store.undoManager = nil
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.delete(note)
        #expect(try stored().isEmpty)
    }

    /// A note whose board has gone has nowhere to come back to.
    @Test func undoingADeleteAfterItsBoardIsDeletedBringsNothingBack() throws {
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.delete(note)
        store.delete(board)

        undo.undo()
        #expect(try stored().isEmpty)
    }

    @Test func deletingTheBoardStopsOfferingItsNoteBack() {
        let other = store.addBoard(named: "Other")
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.delete(note)
        #expect(store.lastDeletion?.boardID == board.id)

        store.delete(other)
        #expect(store.lastDeletion != nil)
        store.delete(board)
        #expect(store.lastDeletion == nil)
    }

    /// A stored property `NoteValues` doesn't carry comes back from an undone delete as its
    /// default.
    @Test func noteValuesCarryEveryStoredProperty() throws {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let entity = try #require(schema.entities.first { $0.name == "Note" })
        let stored = entity.attributes.map(\.name) + entity.relationships.map(\.name)
        #expect(Set(stored) == NoteValues.storedProperties)
    }
}
