import AccessibilityIdentifiers
import XCTest

final class DeleteTests: AppTestCase {
    func testDraggingANoteOntoTheBinDeletesItAndUndoBringsItBack() {
        launch(seeded: true)
        let before = app.notes.count
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")

        note.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: app.trash, withVelocity: .slow,
            thenHoldForDuration: 0.3)

        note.awaitingDisappearance("the binned note")
        XCTAssertEqual(app.notes.count, before - 1)

        app.undoButton.awaiting("Undo").tap()
        app.note(saying: "Buy oat milk").awaiting("the note brought back")
        XCTAssertEqual(app.notes.count, before)
        app.undoButton.awaitingDisappearance("Undo, once used")
    }

    /// A drop short of the bin is a move.
    func testADropShortOfTheBinKeepsTheNote() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")

        note.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: app.surface.point(0.5, 0.5), withVelocity: .slow,
            thenHoldForDuration: 0.1)

        XCTAssertTrue(note.exists)
        XCTAssertFalse(app.undoButton.exists)
    }

    func testPinchingANoteUntilItCrumplesDeletesItAndUndoBringsItBack() {
        launch()
        app.buttons[A11y.Canvas.addButton].awaiting("the add button").tap()
        app.typeText("Crumple me")
        let note = app.note(saying: "Crumple me").awaiting("the new note")
        // Back in its place, out from under the blur, to be pinched.
        app.stopWriting()

        note.pinch(withScale: 0.1, velocity: -3)

        note.awaitingDisappearance("the crumpled note")
        app.undoButton.awaiting("Undo").tap()
        app.note(saying: "Crumple me").awaiting("the note brought back")
    }

    func testDeletingFromTheMenuOffersUndo() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")

        note.press(forDuration: 1.0)
        // Menu items drop their identifiers; matched by label.
        app.buttons["Delete"].awaiting("the Delete item").tap()
        note.awaitingDisappearance("the deleted note")

        app.undoButton.awaiting("Undo").tap()
        app.note(saying: "Buy oat milk").awaiting("the note brought back")
    }

    /// The offer goes by itself; the note stays deleted.
    func testTheUndoOfferGoesAway() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        note.press(forDuration: 1.0)
        app.buttons["Delete"].awaiting("the Delete item").tap()

        app.undoButton.awaiting("Undo")
        app.undoButton.awaitingDisappearance("Undo, after a while", timeout: 10)
        XCTAssertFalse(app.note(saying: "Buy oat milk").exists)
    }
}
