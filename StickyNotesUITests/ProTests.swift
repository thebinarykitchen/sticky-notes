import AccessibilityIdentifiers
import XCTest

/// What is free, what asks for Pro, and the sheet that asks. Every launch passes
/// `--no-storekit`, so the price never loads and the sheet offers Try Again; buying itself is
/// `PurchaseTests`', against `SKTestSession`.
///
/// Uses the sample boards: "Home", with the yellow "Buy oat milk", then "Work".
final class ProTests: AppTestCase {
    private var sheet: XCUIElement { app.find(A11y.Pro.sheet) }

    private func awaitSheet(for reason: String) {
        sheet.awaiting("the Pro sheet")
        app.find(A11y.Pro.reason(reason)).awaiting("the reason \(reason)")
    }

    /// The system's Cancel, found by its label, in the navigation bar: outside the container
    /// ``A11y/Pro/sheet`` names.
    private func closeSheet() {
        app.navigationBars.buttons["Cancel"].tap()
        sheet.awaitingDisappearance("the Pro sheet")
    }

    /// Adds a board named `name` through the name prompt, and waits for its empty canvas.
    private func addBoard(_ name: String) {
        app.addBoardButton.tap()
        let field = app.alerts.textFields.firstMatch.awaiting("the name field")
        field.typeText(name)
        app.alerts.buttons["Create"].tap()
        app.find(A11y.Canvas.emptyState).awaiting("the new board \(name)")
    }

    // MARK: - Boards

    /// The samples are two boards; the third is free, and the fourth asks. New Board is never
    /// drawn dead.
    func testAFourthBoardOffersPro() {
        launch(seeded: true)
        app.showBoards()
        addBoard("Groceries")

        app.showBoards()
        XCTAssertTrue(app.addBoardButton.isEnabled)
        app.addBoardButton.tap()
        awaitSheet(for: "boards")
        XCTAssertFalse(app.alerts.firstMatch.exists, "the name prompt came up behind the sheet")

        closeSheet()
        XCTAssertFalse(app.staticTexts["Untitled Board"].exists)
    }

    func testWithProBoardsAreUnlimited() {
        launch(seeded: true, pro: .unlocked)
        app.showBoards()
        addBoard("Groceries")
        app.showBoards()
        addBoard("Garden")
        XCTAssertFalse(sheet.exists)
    }

    /// A board deleted frees its place.
    func testDeletingABoardFreesItsPlace() {
        launch(seeded: true)
        app.showBoards()
        addBoard("Groceries")

        // In the list's rows: on an iPad the open board's title says "Groceries" too.
        app.showBoards()
        let row = app.cells.staticTexts["Groceries"]
        row.awaiting("the third board").press(forDuration: 1.0)
        app.buttons["Delete"].awaiting("the Delete item").tap()
        app.buttons["Delete Board"].awaiting("the confirmation").tap()
        row.awaitingDisappearance("the deleted board")

        addBoard("Garden")
        XCTAssertFalse(sheet.exists)
    }

    // MARK: - Colors

    /// The color only Pro has is shown on the sheet, not written: the note is still yellow.
    func testAProColorOffersProAndLeavesTheNoteAsItWas() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")

        note.press(forDuration: 1.0)
        app.buttons["Purple"].awaiting("the colors").tap()
        awaitSheet(for: "colors")
        closeSheet()

        XCTAssertEqual(app.note(saying: "Buy oat milk").label, "Yellow note")
    }

    func testAFreeColorIsJustChosen() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")

        note.press(forDuration: 1.0)
        app.buttons["Green"].awaiting("the colors").tap()
        app.surface.point(0.5, 0.05).tap()
        app.buttons["Delete"].awaitingDisappearance("the menu")

        XCTAssertFalse(sheet.exists)
        XCTAssertEqual(app.note(saying: "Buy oat milk").label, "Green note")
    }

    func testWithProEveryColorIsChosen() {
        launch(seeded: true, pro: .unlocked)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")

        note.press(forDuration: 1.0)
        app.buttons["Purple"].awaiting("the colors").tap()
        app.surface.point(0.5, 0.05).tap()
        app.buttons["Delete"].awaitingDisappearance("the menu")

        XCTAssertFalse(sheet.exists)
        XCTAssertEqual(app.note(saying: "Buy oat milk").label, "Purple note")
    }

    // MARK: - Make Notes

    /// Spent, Make Notes is still drawn, and offers Pro rather than its sheet.
    func testSpentMakeNotesOffersPro() {
        launch(intelligence: .fake, pro: .makeNotesSpent)
        app.buttons[A11y.Canvas.makeNotesButton].awaiting("Make Notes").tap()
        awaitSheet(for: "makeNotes")
        XCTAssertFalse(app.find(A11y.MakeNotes.text).exists)
    }

    /// The last free run makes its notes, and offers Pro as they land.
    func testTheLastFreeRunOffersProAsItsNotesLand() {
        launch(intelligence: .fake, pro: .oneMakeNotesLeft)
        app.buttons[A11y.Canvas.makeNotesButton].awaiting("Make Notes").tap()
        app.find(A11y.MakeNotes.text).awaiting("the field notes are made from")
        app.typeText("Milk, Eggs")
        app.buttons[A11y.MakeNotes.addButton].tap()

        awaitSheet(for: "makeNotes")
        closeSheet()
        app.note(saying: "Milk").awaiting("the first note")
        app.note(saying: "Eggs").awaiting("the second note")
    }

    // MARK: - The sheet

    /// Under `--no-storekit` a restore finds nothing, as a store with nothing to restore would.
    func testTheListOffersProAndRestoreSaysWhatItFound() {
        launch()
        app.showBoards()
        app.buttons[A11y.Pro.listRow].awaiting("Pro's row").tap()
        awaitSheet(for: A11y.Pro.listReason)

        XCTAssertTrue(app.buttons[A11y.Pro.retryButton].exists, "no price, and no way to retry")
        app.buttons[A11y.Pro.restoreButton].tap()
        app.find(A11y.Pro.message).awaiting("what the restore found")
    }

    func testWithProTheListSaysSo() {
        launch(pro: .unlocked)
        app.showBoards()
        let row = app.find(A11y.Pro.listRow).awaiting("Pro's row")
        XCTAssertTrue(row.label.contains("Unlocked"), "the row says \(row.label)")
        row.tap()
        XCTAssertFalse(sheet.waitForExistence(timeout: 1))
    }

    func testTheSheetPassesTheAccessibilityAudit() throws {
        launch(seeded: true)
        app.showBoards()
        addBoard("Groceries")
        app.showBoards()
        app.addBoardButton.tap()
        awaitSheet(for: "boards")
        // On an iPad the sheet leaves the board in view behind its dimming, hidden from
        // accessibility while the sheet is up: the audit reads that text and finds no element
        // for it ("Potentially inaccessible text", with none). Seen on iOS 27; the same sheet
        // passes on an iPhone, where it covers everything.
        try app.performAccessibilityAudit { issue in
            issue.auditType == .elementDetection && issue.element == nil
        }
    }
}
