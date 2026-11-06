import AccessibilityIdentifiers
import XCTest

/// Making notes with Apple Intelligence, through the stand-in that makes a note of each line or
/// comma-separated item: the model's own notes vary, and it runs only where the host Mac has
/// it. `NoteWriterModelTests` checks what the model writes.
final class MakeNotesTests: AppTestCase {
    private var makeNotesButton: XCUIElement { app.buttons[A11y.Canvas.makeNotesButton] }
    private var field: XCUIElement { app.find(A11y.MakeNotes.text) }

    /// Opens the sheet; the field takes the keyboard as it opens.
    private func openTheSheet() {
        makeNotesButton.awaiting("Make Notes").tap()
        field.awaiting("the field notes are made from")
    }

    /// Without the model the toolbar is what it always was.
    func testWithoutAppleIntelligenceNothingIsOffered() {
        launch()
        let add = app.buttons[A11y.Canvas.addButton].awaiting("the add button")
        XCTAssertFalse(makeNotesButton.exists)

        add.tap()
        app.notes.firstMatch.awaiting("the new note")
    }

    /// Together in the middle of the canvas, in reading order: two to a row on an iPhone.
    func testAListBecomesANoteForEachItem() {
        launch(intelligence: .fake)
        openTheSheet()
        app.typeText("Milk, Eggs, Bread")
        app.buttons[A11y.MakeNotes.addButton].tap()

        field.awaitingDisappearance("the sheet")
        let milk = app.note(saying: "Milk").awaiting("the first note")
        let eggs = app.note(saying: "Eggs").awaiting("the second note")
        let bread = app.note(saying: "Bread").awaiting("the third note")
        XCTAssertEqual(app.notes.count, 3)

        XCTAssertEqual(milk.frame.midY, eggs.frame.midY, accuracy: 1)
        XCTAssertLessThan(milk.frame.maxX, eggs.frame.minX)
        XCTAssertEqual(bread.frame.midX, milk.frame.midX, accuracy: 1)
        XCTAssertLessThan(milk.frame.maxY, bread.frame.minY)
        let canvas = app.surface.frame
        XCTAssertEqual((milk.frame.minX + eggs.frame.maxX) / 2, canvas.midX, accuracy: 1)
        XCTAssertEqual((milk.frame.minY + bread.frame.maxY) / 2, canvas.midY, accuracy: 1)
    }

    /// The system's own Cancel, found by its label.
    func testCancelAddsNothing() {
        launch(intelligence: .fake)
        openTheSheet()
        app.typeText("Milk, Eggs")
        app.buttons["Cancel"].tap()

        field.awaitingDisappearance("the sheet")
        app.find(A11y.Canvas.emptyState).awaiting("the empty canvas")
        XCTAssertEqual(app.notes.count, 0)
    }

    /// The canvas with Make Notes, and the sheet empty and written in: Add Notes disabled, then
    /// enabled.
    func testMakeNotesPassesTheAccessibilityAudit() throws {
        launch(intelligence: .fake)
        makeNotesButton.awaiting("Make Notes")
        try app.performAccessibilityAudit()

        openTheSheet()
        try app.performAccessibilityAudit()

        // The audit takes the keyboard away.
        field.tap()
        app.typeText("Milk")
        try app.performAccessibilityAudit()
    }
}
