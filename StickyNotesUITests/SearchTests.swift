import AccessibilityIdentifiers
import XCTest

/// Searching the sample boards from the list of boards: "Home", which a launch opens, and
/// "Work".
final class SearchTests: AppTestCase {
    private var results: XCUIElementQuery {
        app.buttons.matching(identifier: A11y.Boards.searchResult)
    }

    /// The search field is UIKit's, found by type.
    private func search(_ text: String) {
        app.showBoards()
        let field = app.searchFields.firstMatch.awaiting("the search field")
        field.tap()
        field.typeText(text)
    }

    /// Case aside, and on every board: "Call the dentist before Friday" and "Ideas for the
    /// weekend" on Home, "Book the team offsite" on Work.
    func testSearchFindsNotesOnEveryBoard() {
        launch(seeded: true)
        search("THE")
        results.firstMatch.awaiting("the notes found")
        XCTAssertEqual(results.count, 3)
    }

    /// From Home, a note on Work: Work opens with the note in the middle of the canvas.
    func testPickingANoteOpensItsBoardWithTheNoteInTheMiddle() {
        launch(seeded: true)
        search("offsite")
        results.firstMatch.awaiting("the note found").tap()

        let note = app.note(saying: "Book the team offsite").awaiting("the note on its board")
        app.navigationBars["Work"].awaiting("the board it is on")
        let canvas = app.surface.frame
        XCTAssertEqual(note.frame.midX, canvas.midX, accuracy: 1, "the note at \(note.frame)")
        XCTAssertEqual(note.frame.midY, canvas.midY, accuracy: 1, "the note at \(note.frame)")
    }
}
