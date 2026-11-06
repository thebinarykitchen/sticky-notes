import AccessibilityIdentifiers
import XCTest

/// The canvas scrolls over a board with no edges. On the sample "Home" board, whose notes lie
/// between 100 and 620 points down it, a scroll goes `margin` further and no more.
final class ScrollTests: AppTestCase {
    /// Mirrored from `CanvasScroll.margin`, which this bundle can't import.
    private let margin: CGFloat = 600

    private var dentist: XCUIElement { app.note(saying: "Call the dentist before Friday") }

    /// Drags the empty canvas up and to the left, below the lowest seeded note, and lets go
    /// still, so it doesn't fling. Returns how far the finger went.
    @discardableResult
    private func scrollTheCanvas() -> CGVector {
        let start = app.surface.point(0.85, 0.95)
        let end = app.surface.point(0.35, 0.6)
        start.press(
            forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        return CGVector(
            dx: end.screenPoint.x - start.screenPoint.x, dy: end.screenPoint.y - start.screenPoint.y
        )
    }

    /// Board (0, 0) is the canvas's top-left, as it always was: notes open where they were left.
    func testABoardOpensWithItsNotesWhereTheyWere() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        let canvas = app.surface.frame
        // Where `SampleData` puts it.
        XCTAssertEqual(note.frame.midX - canvas.minX, 100, accuracy: 1)
        XCTAssertEqual(note.frame.midY - canvas.minY, 180, accuracy: 1)
    }

    func testDraggingTheEmptyCanvasScrollsIt() {
        launch(seeded: true)
        let note = dentist.awaiting("a seeded note")
        let before = note.frame

        let moved = scrollTheCanvas()

        // A scroll view takes the first few points of a drag to tell it is one.
        XCTAssertEqual(note.frame.midX - before.midX, moved.dx, accuracy: 15)
        XCTAssertEqual(note.frame.midY - before.midY, moved.dy, accuracy: 15)
    }

    /// The note moves; the canvas doesn't.
    func testDraggingANoteDoesntScrollTheCanvas() {
        launch(seeded: true)
        let dragged = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        let other = dentist.awaiting("another note")
        let before = other.frame
        let target = app.surface.point(0.6, 0.75)
        let letGo = target.screenPoint

        dragged.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.1)

        XCTAssertEqual(other.frame.midX, before.midX, accuracy: 1, "the canvas scrolled")
        XCTAssertEqual(other.frame.midY, before.midY, accuracy: 1, "the canvas scrolled")
        XCTAssertEqual(
            dragged.frame.midX, letGo.x, accuracy: 2, "the note isn't where it was let go")
        XCTAssertEqual(
            dragged.frame.midY, letGo.y, accuracy: 2, "the note isn't where it was let go")
    }

    /// Held at the right edge, a note scrolls the canvas under it, stays under the finger, and
    /// lands where it is let go: further over the board than the canvas reached.
    func testHoldingANoteAtAnEdgeScrollsTheCanvasUnderIt() {
        launch(seeded: true)
        let held = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        let other = dentist.awaiting("another note")
        let before = other.frame
        let edge = app.surface.point(0, 0.5)
            .withOffset(CGVector(dx: app.surface.frame.width - 8, dy: 0))
        let letGo = edge.screenPoint

        held.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: edge, withVelocity: .slow, thenHoldForDuration: 1)

        XCTAssertEqual(held.frame.midX, letGo.x, accuracy: 3, "the note isn't under the finger")
        XCTAssertEqual(held.frame.midY, letGo.y, accuracy: 3, "the note isn't under the finger")
        XCTAssertLessThan(other.frame.midX, before.midX - 300, "the canvas didn't scroll")
        XCTAssertEqual(other.frame.midY, before.midY, accuracy: 1, "the canvas scrolled up or down")
    }

    /// Toward the left, the board grows ahead of the scroll, moving everything in the content;
    /// the held note must not move with it.
    func testHoldingANoteAtTheLeftEdgeScrollsTheOtherWay() {
        launch(seeded: true)
        let held = dentist.awaiting("a seeded note")
        let other = app.note(saying: "Buy oat milk").awaiting("another note")
        let before = other.frame
        let edge = app.surface.point(0, 0.5).withOffset(CGVector(dx: 8, dy: 0))
        let letGo = edge.screenPoint

        held.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: edge, withVelocity: .slow, thenHoldForDuration: 1)

        XCTAssertEqual(held.frame.midX, letGo.x, accuracy: 3, "the note isn't under the finger")
        XCTAssertEqual(held.frame.midY, letGo.y, accuracy: 3, "the note isn't under the finger")
        XCTAssertGreaterThan(other.frame.midX, before.midX + 300, "the canvas didn't scroll")
        XCTAssertEqual(other.frame.midY, before.midY, accuracy: 1, "the canvas scrolled up or down")
    }

    func testAfterAScrollTheToolbarButtonAddsInTheMiddleOfTheCanvas() {
        launch(seeded: true)
        dentist.awaiting("a seeded note")
        scrollTheCanvas()
        // Read before adding: the keyboard shortens the canvas as the new note takes focus.
        let canvas = app.surface.frame

        app.buttons[A11y.Canvas.addButton].tap()
        app.typeText("Added after a scroll")
        // Written on in the middle of what the keyboard leaves until that ends.
        app.stopWriting()

        let note = app.note(saying: "Added after a scroll").awaiting("the new note")
        XCTAssertEqual(note.frame.midX, canvas.midX, accuracy: 1, "the note at \(note.frame)")
        XCTAssertEqual(note.frame.midY, canvas.midY, accuracy: 1, "the note at \(note.frame)")
    }

    func testAfterAScrollADoubleTapAddsANoteThere() {
        launch(seeded: true)
        dentist.awaiting("a seeded note")
        scrollTheCanvas()
        let tap = app.surface.point(0.5, 0.35)
        // Read before tapping, as above.
        let tapped = tap.screenPoint

        tap.doubleTap()
        app.typeText("Tapped after a scroll")
        app.stopWriting()

        let note = app.note(saying: "Tapped after a scroll").awaiting("the new note")
        XCTAssertEqual(note.frame.midX, tapped.x, accuracy: 1, "the note at \(note.frame)")
        XCTAssertEqual(note.frame.midY, tapped.y, accuracy: 1, "the note at \(note.frame)")
    }

    /// A status-bar tap scrolls to the top of the board: up to the notes' margin, not off into
    /// an endless board.
    func testTheStatusBarScrollsNoFurtherThanTheMargin() {
        launch(seeded: true)
        let note = dentist.awaiting("a seeded note")
        let before = note.frame

        // The clock's end of the status bar; its middle is the Dynamic Island.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 20)).tap()
        // The scroll to the top animates.
        Thread.sleep(forTimeInterval: 1.5)

        let moved = note.frame.midY - before.midY
        XCTAssertGreaterThan(moved, 0, "the tap didn't scroll")
        XCTAssertLessThanOrEqual(moved, margin, "the canvas went past the notes' margin")
    }
}
