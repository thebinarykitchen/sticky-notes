import AccessibilityIdentifiers
import XCTest

/// The sheet that shows every note on a board, and going to one from it. On the sample "Home"
/// board.
final class OverviewTests: AppTestCase {
    private var overviewNotes: XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: A11y.Overview.note)
    }

    private func overviewNote(saying text: String) -> XCUIElement {
        overviewNotes.matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    private func openOverview() {
        app.buttons[A11y.Canvas.overviewButton].awaiting("Show All Notes").tap()
        overviewNotes.firstMatch.awaiting("the overview")
    }

    /// Drags the empty canvas up and to the left, as `ScrollTests` does.
    private func scrollTheCanvas() {
        app.surface.point(0.85, 0.95).press(
            forDuration: 0.1, thenDragTo: app.surface.point(0.35, 0.6), withVelocity: .slow,
            thenHoldForDuration: 0.2)
    }

    func testItShowsEveryNoteOnTheBoardAndNoOther() {
        launch(seeded: true)
        app.note(saying: "Buy oat milk").awaiting("a seeded note")
        let onTheBoard = app.notes.count

        openOverview()

        XCTAssertEqual(overviewNotes.count, onTheBoard)
        overviewNote(saying: "Buy oat milk").awaiting("a note on this board")
        XCTAssertFalse(overviewNote(saying: "Book the team offsite").exists, "a note from Work")
    }

    /// Scrolled away so it is off to one side, then picked: it comes to the middle.
    func testPickingANoteBringsItToTheMiddleOfTheCanvas() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        scrollTheCanvas()
        let canvas = app.surface.frame

        openOverview()
        // Not `tap()` on the element: it takes no touches itself, and the map under it does.
        overviewNote(saying: "Buy oat milk").point(0.5, 0.5).tap()
        overviewNotes.firstMatch.awaitingDisappearance("the overview")

        XCTAssertEqual(note.frame.midX, canvas.midX, accuracy: 1, "the note at \(note.frame)")
        XCTAssertEqual(note.frame.midY, canvas.midY, accuracy: 1, "the note at \(note.frame)")
    }

    func testClosingItLeavesTheCanvasWhereItWas() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        scrollTheCanvas()
        let before = note.frame

        openOverview()
        // The system's own Cancel, found by its label.
        app.navigationBars.buttons["Cancel"].tap()
        overviewNotes.firstMatch.awaitingDisappearance("the overview")

        XCTAssertEqual(note.frame.midX, before.midX, accuracy: 1, "the canvas moved")
        XCTAssertEqual(note.frame.midY, before.midY, accuracy: 1, "the canvas moved")
    }

    func testAnEmptyBoardHasNothingToShow() {
        launch()
        app.find(A11y.Canvas.emptyState).awaiting("the empty board")
        XCTAssertFalse(app.buttons[A11y.Canvas.overviewButton].isEnabled)
    }

    /// Opening it while a note is written on ends the writing, as a tap on the blur does.
    func testOpeningItEndsTheWriting() {
        launch(seeded: true)
        app.note(saying: "Buy oat milk").awaiting("a seeded note").tap()
        app.find(A11y.Canvas.blur).awaiting("the blur")

        openOverview()

        XCTAssertFalse(app.find(A11y.Canvas.blur).exists, "still writing behind the sheet")
    }

    func testItPassesTheAccessibilityAudit() throws {
        launch(seeded: true)
        openOverview()
        try app.performAccessibilityAudit()
    }

    // MARK: - Where a board was left

    func testABoardReopensWhereItWasLeft() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        scrollTheCanvas()
        let left = note.frame

        app.openBoard("Work")
        app.openBoard("Home")

        let back = app.note(saying: "Buy oat milk").awaiting("the note, back on its board")
        XCTAssertEqual(back.frame.midX, left.midX, accuracy: 1, "at \(back.frame), left \(left)")
        XCTAssertEqual(back.frame.midY, left.midY, accuracy: 1, "at \(back.frame), left \(left)")
    }

    /// Where one board was left isn't where another opens.
    func testEachBoardHasAPlaceOfItsOwn() {
        launch(seeded: true)
        app.note(saying: "Buy oat milk").awaiting("a seeded note")
        scrollTheCanvas()

        app.openBoard("Work")

        let note = app.note(saying: "Book the team offsite").awaiting("Work's note")
        // Where `SampleData` puts it, from a board opened at (0, 0).
        XCTAssertEqual(note.frame.midX - app.surface.frame.minX, 140, accuracy: 1)
        XCTAssertEqual(note.frame.midY - app.surface.frame.minY, 220, accuracy: 1)
    }

    /// A note picked in the overview is where the board is left.
    func testAPickInTheOverviewIsRemembered() {
        launch(seeded: true)
        let note = app.note(saying: "Ideas for the weekend:\nhike, bake bread")
            .awaiting("a seeded note")
        openOverview()
        overviewNote(saying: "Ideas for the weekend:\nhike, bake bread").point(0.5, 0.5).tap()
        overviewNotes.firstMatch.awaitingDisappearance("the overview")
        let left = note.frame

        app.openBoard("Work")
        app.openBoard("Home")

        let back = app.note(saying: "Ideas for the weekend:\nhike, bake bread")
            .awaiting("the note, back on its board")
        XCTAssertEqual(back.frame.midX, left.midX, accuracy: 1)
        XCTAssertEqual(back.frame.midY, left.midY, accuracy: 1)
    }

    /// On the real store, whose board keeps its id across launches. The system keeps what a scene
    /// stored once the app has gone to the background. Cleans up after itself.
    func testABoardReopensWhereItWasLeftAfterARelaunch() {
        launch(store: .onDisk)
        let text = "Place \(UUID().uuidString.prefix(8))"
        app.buttons[A11y.Canvas.addButton].awaiting("the add button").tap()
        app.typeText(text)
        app.stopWriting()
        let note = app.note(saying: text).awaiting("the note")
        scrollTheCanvas()
        let left = note.frame

        XCUIDevice.shared.press(.home)
        // Under a test runner it never reaches suspended. A moment for the scene to store its state.
        let backgrounded = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in self.app.state != .runningForeground }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [backgrounded], timeout: 15), .completed)
        Thread.sleep(forTimeInterval: 2)
        app.terminate()
        launch(store: .onDisk)

        let back = app.note(saying: text).awaiting("the note after a relaunch")
        let frame = back.frame
        let menu = back.point(0.5, 0.5)
        menu.press(forDuration: 1.0)
        app.buttons["Delete"].awaiting("the Delete item").tap()
        back.awaitingDisappearance("the cleaned-up note")

        XCTAssertEqual(frame.midX, left.midX, accuracy: 1, "at \(frame), left \(left)")
        XCTAssertEqual(frame.midY, left.midY, accuracy: 1, "at \(frame), left \(left)")
    }
}
