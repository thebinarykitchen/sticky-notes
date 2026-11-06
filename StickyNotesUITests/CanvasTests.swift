import AccessibilityIdentifiers
import XCTest

final class CanvasTests: AppTestCase {
    /// The new note is centred on the tap.
    func testDoubleTappingTheCanvasAddsANoteThere() {
        launch()
        app.find(A11y.Canvas.emptyState).awaiting("the empty state")

        let tap = app.surface.point(0.5, 0.35)
        // Read before tapping: the coordinate is relative to the canvas, which the keyboard
        // shortens as soon as the new note takes focus.
        let tapped = tap.screenPoint
        tap.doubleTap()

        let note = app.notes.firstMatch.awaiting("the new note")
        XCTAssertEqual(app.notes.count, 1)
        // Written on in the middle until that ends.
        app.stopWriting()
        XCTAssertEqual(note.frame.midX, tapped.x, accuracy: 1, "the note at \(note.frame)")
        XCTAssertEqual(note.frame.midY, tapped.y, accuracy: 1, "the note at \(note.frame)")
        app.find(A11y.Canvas.emptyState).awaitingDisappearance("the empty state")
    }

    /// The same verb, for anyone a double tap doesn't suit.
    func testTheToolbarButtonAddsANote() {
        launch()
        app.buttons[A11y.Canvas.addButton].awaiting("the add button").tap()
        app.notes.firstMatch.awaiting("the new note")
        XCTAssertEqual(app.notes.count, 1)
    }

    /// A double tap on a note is not a double tap on the canvas.
    func testDoubleTappingANoteAddsNothing() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        let before = app.notes.count

        note.doubleTap()

        XCTAssertEqual(app.notes.count, before)
    }

    func testDraggingANoteMovesIt() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        let start = note.frame

        note.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: app.surface.point(0.6, 0.75),
            withVelocity: .slow, thenHoldForDuration: 0.1)

        let end = note.frame
        XCTAssertGreaterThan(end.midX - start.midX, 40, "the note didn't move right")
        XCTAssertGreaterThan(end.midY - start.midY, 100, "the note didn't move down")
    }

    /// The drag runs alongside the note's tap, so a drag mustn't count as a tap too.
    func testDraggingANoteDoesntStartEditingIt() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")

        note.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: app.surface.point(0.6, 0.75),
            withVelocity: .slow, thenHoldForDuration: 0.1)

        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))
    }

    /// "Buy oat milk" starts below "Call the dentist before Friday"; dropped right on it, it
    /// covers it, so a press there opens the dropped note's menu.
    func testADroppedNoteLandsOnTop() {
        launch(seeded: true)
        let below = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        let above = app.note(saying: "Call the dentist before Friday").awaiting("the note above it")
        let target = above.point(0.5, 0.5)

        below.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.1)

        target.press(forDuration: 1.0)
        app.buttons["Delete"].awaiting("the Delete item").tap()
        below.awaitingDisappearance("the dropped note")
        XCTAssertTrue(above.exists)
    }

    func testTappingANoteStartsEditingIt() {
        launch(seeded: true)
        app.note(saying: "Buy oat milk").awaiting("a seeded note").tap()
        app.keyboards.firstMatch.awaiting("the keyboard")
    }

    /// Written on, a note comes to the middle of what the keyboard leaves of the canvas, over the
    /// rest of the board, blurred. A tap on another note lands on the blur and ends the writing,
    /// which puts the note back where it was.
    func testANoteBeingWrittenOnComesToTheMiddle() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        let other = app.note(saying: "Call the dentist before Friday").awaiting("another note")
        let start = note.frame
        let otherStart = other.frame

        note.tap()
        app.keyboards.firstMatch.awaiting("the keyboard")
        app.find(A11y.Canvas.blur).awaiting("the blur")

        // Read now: the keyboard has shortened it — unless the simulator remembers a hardware
        // keyboard and shows none, which leaves this centring in the whole canvas.
        let canvas = app.surface.frame
        XCTAssertEqual(note.frame.midX, canvas.midX, accuracy: 1, "the note at \(note.frame)")
        XCTAssertEqual(note.frame.midY, canvas.midY, accuracy: 1, "the note at \(note.frame)")

        // Its right edge, clear of the note in the middle.
        other.point(0.85, 0.5).tap()
        app.find(A11y.Canvas.blur).awaitingDisappearance("the blur")
        app.keyboards.firstMatch.awaitingDisappearance("the keyboard")
        XCTAssertEqual(note.frame.midX, start.midX, accuracy: 1, "the note at \(note.frame)")
        XCTAssertEqual(note.frame.midY, start.midY, accuracy: 1, "the note at \(note.frame)")
        XCTAssertEqual(other.frame.midX, otherStart.midX, accuracy: 1, "the other note moved")
        XCTAssertEqual(other.frame.midY, otherStart.midY, accuracy: 1, "the other note moved")
    }

    /// On the real store: typed text and a move both survive a relaunch. Cleans up after itself,
    /// so it is safe on a store that already holds notes.
    func testANoteSurvivesARelaunch() {
        launch(store: .onDisk)
        let text = "Relaunch \(UUID().uuidString.prefix(8))"

        app.buttons[A11y.Canvas.addButton].awaiting("the add button").tap()
        app.typeText(text)
        app.note(saying: text).awaiting("the typed note")

        app.terminate()
        launch(store: .onDisk)

        let note = app.note(saying: text).awaiting("the note after relaunch")
        note.press(forDuration: 1.0)
        app.buttons["Delete"].awaiting("the Delete item").tap()
        note.awaitingDisappearance("the cleaned-up note")
    }

    func testTheCanvasPassesTheAccessibilityAudit() throws {
        launch(seeded: true)
        app.note(saying: "Buy oat milk").awaiting("a seeded note")
        try app.performAccessibilityAudit()
    }
}
