import AccessibilityIdentifiers
import XCTest

/// The note's side limits, mirrored from `NoteGeometry`, which this bundle can't import. Change
/// one there and the test here fails loudly rather than quietly proving nothing.
private enum Side {
    static let start: CGFloat = 160
    static let min: CGFloat = 100
    static let max: CGFloat = 320
    static let step: CGFloat = 40
}

/// On a note of its own: a pinch-in starts its fingers at the note's edges, and a seeded
/// neighbour overlapping one edge would take that finger.
final class ResizeTests: AppTestCase {
    private var note: XCUIElement { app.notes.firstMatch }

    override func setUp() async throws {
        try await super.setUp()
        launch()
        app.buttons[A11y.Canvas.addButton].awaiting("the add button").tap()
        note.awaiting("the new note")
        // A new note is written on in the middle, over a blur that takes every touch.
        app.stopWriting()
        XCTAssertEqual(note.frame.width, Side.start, accuracy: 1)
    }

    func testPinchingOutMakesANoteBiggerUpToTheLimit() {
        note.pinch(withScale: 1.4, velocity: 1)
        XCTAssertGreaterThan(note.frame.width, Side.start + 20, "the note didn't grow")

        note.pinch(withScale: 6, velocity: 3)
        XCTAssertEqual(note.frame.width, Side.max, accuracy: 1)
        XCTAssertEqual(note.frame.height, Side.max, accuracy: 1, "a note stays square")
    }

    /// To a side between the crumple and the minimum: held at the minimum, not deleted.
    func testPinchingInMakesANoteSmallerDownToTheLimit() {
        note.pinch(withScale: 0.55, velocity: -1)
        XCTAssertEqual(note.frame.width, Side.min, accuracy: 1)
    }

    /// The same verb, for anyone a pinch doesn't suit. Menu items drop their identifiers, so
    /// they're matched by label.
    func testTheMenuResizesANoteOneStepAtATime() {
        note.press(forDuration: 1.0)
        app.buttons["Make Bigger"].awaiting("Make Bigger").tap()
        XCTAssertEqual(note.frame.width, Side.start + Side.step, accuracy: 1)

        note.press(forDuration: 1.0)
        app.buttons["Make Smaller"].awaiting("Make Smaller").tap()
        XCTAssertEqual(note.frame.width, Side.start, accuracy: 1)
    }
}
