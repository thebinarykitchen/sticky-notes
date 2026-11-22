import AccessibilityIdentifiers
import UITestSupport
import XCTest

/// The hint at the foot of a board for a gesture the tour was skipped past.
final class LessonHintTests: AppTestCase {
    /// Nothing known, and a board with notes on it: the first lesson is hinted, with a way to
    /// put it away.
    func testAGestureNotYetDoneIsHinted() {
        app = .underTest(seeded: true, hints: true)
        app.launch()
        app.surface.awaiting("the canvas")

        app.find(A11y.Canvas.lessonHint).awaiting("the hint")
        XCTAssertTrue(app.buttons[A11y.Canvas.lessonHintDismiss].exists, "a hint with no way off")
    }

    /// Every lesson known, as every other test launches: no hint over the notes.
    func testEveryGestureKnownHintsNothing() {
        launch(seeded: true)
        app.notes.firstMatch.awaiting("the seeded notes")
        XCTAssertFalse(app.find(A11y.Canvas.lessonHint).exists, "a hint for a known gesture")
    }
}
