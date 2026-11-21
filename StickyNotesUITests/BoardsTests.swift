import AccessibilityIdentifiers
import UITestSupport
import XCTest

/// Uses the sample boards: "Home", with "Buy oat milk" and three other notes, then "Work", with
/// "Book the team offsite".
final class BoardsTests: AppTestCase {
    func testALaunchOpensOntoTheFirstBoard() {
        launch(seeded: true)
        app.note(saying: "Buy oat milk").awaiting("a Home note")
        XCTAssertFalse(app.note(saying: "Book the team offsite").exists)
    }

    func testEachBoardShowsOnlyItsOwnNotes() {
        launch(seeded: true)
        app.note(saying: "Buy oat milk").awaiting("a Home note")

        app.openBoard("Work")
        app.note(saying: "Book the team offsite").awaiting("the Work note")
        XCTAssertEqual(app.notes.count, 1)

        app.openBoard("Home")
        app.note(saying: "Buy oat milk").awaiting("a Home note, back again")
        XCTAssertEqual(app.notes.count, 4)
    }

    func testANewBoardOpensEmptyAndKeepsItsOwnNotes() {
        launch(seeded: true)
        app.showBoards()
        app.addBoardButton.tap()

        let field = app.alerts.textFields.firstMatch.awaiting("the name field")
        field.typeText("Groceries")
        app.alerts.buttons["Create"].tap()

        app.find(A11y.Canvas.emptyState).awaiting("the new board's empty canvas")
        app.buttons[A11y.Canvas.addButton].tap()
        app.notes.firstMatch.awaiting("the new note")
        XCTAssertEqual(app.notes.count, 1)

        app.openBoard("Home")
        app.note(saying: "Buy oat milk").awaiting("a Home note")
        XCTAssertEqual(app.notes.count, 4)
    }

    func testDeletingABoardAsksFirstAndTheLastOneCantBeDeleted() {
        launch(seeded: true)
        app.showBoards()

        app.boardRow("Work").awaiting("the Work board").openMenu(showing: app.buttons["Delete"], "the Delete item").tap()
        app.buttons["Delete Board"].awaiting("the confirmation").tap()
        app.boardRow("Work").awaitingDisappearance("the deleted board")

        XCTAssertFalse(app.boardRow("Home").openMenu(showing: app.buttons["Delete"], "the Delete item").isEnabled)
    }
}
