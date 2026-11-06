import AccessibilityIdentifiers
import XCTest

/// The tour: up on a first launch, a page per gesture with a board to practise it on, and back
/// whenever it is asked for. Under Reduce Motion, as every UI test runs, each page's
/// demonstration is a still: a loop would never let the app go idle.
final class TourTests: AppTestCase {
    private var advance: XCUIElement { app.buttons[A11y.Tour.advanceButton] }
    private var skip: XCUIElement { app.buttons[A11y.Tour.skipButton] }
    private var instruction: XCUIElement { app.find(A11y.Tour.instruction) }
    private var practiceBoard: XCUIElement { app.find(A11y.Tour.practiceBoard) }

    /// The practice board's notes, which carry the identifier every note does.
    private var practiceNotes: XCUIElementQuery {
        practiceBoard.descendants(matching: .any).matching(identifier: A11y.Note.card)
    }

    private func launchTheTour() {
        app = .underTest(tour: .due)
        app.launch()
        app.find(A11y.Tour.page(A11y.Tour.welcomePage)).awaiting("the welcome page")
    }

    /// Presses on from the welcome page to `lesson`'s.
    private func pressOn(to lesson: String) {
        for page in A11y.Tour.lessonPages {
            advance.awaiting("the way on").tap()
            app.find(A11y.Tour.page(page)).awaiting("the \(page) page")
            if page == lesson { break }
        }
        practiceNotes.firstMatch.awaiting("a note to practise on")
    }

    /// Skips the tour, then relaunches with nothing preset, so what the app wrote is what is read
    /// — a preset hides the app's own writes.
    private func skipTheTourAndRelaunch() {
        launchTheTour()
        skip.awaiting("the way out").tap()
        app.surface.awaiting("the board")
        app.terminate()

        app = .underTest(tour: .whateverStuck)
        app.launch()
        app.surface.awaiting("the board, without the tour again")
    }

    /// Whether the page says its gesture was done: its instruction has a value once it is.
    private var isPractised: Bool { !((instruction.value as? String) ?? "").isEmpty }

    /// Waits for the page to say its gesture was done, and fails the test if it doesn't.
    private func awaitPractised(file: StaticString = #filePath, line: UInt = #line) {
        let said = expectation(
            for: NSPredicate(format: "value != nil AND value != ''"), evaluatedWith: instruction)
        XCTAssertEqual(
            XCTWaiter.wait(for: [said], timeout: 10), .completed,
            "The page never said its gesture was done", file: file, line: line)
    }

    /// Waits for `query` to hold `count` elements, and fails the test if it doesn't.
    private func awaitCount(
        _ query: XCUIElementQuery, _ count: Int, _ what: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let counted = expectation(
            for: NSPredicate(format: "count == %d", count), evaluatedWith: query)
        XCTAssertEqual(
            XCTWaiter.wait(for: [counted], timeout: 10), .completed,
            "\(what): \(query.count), not \(count)", file: file, line: line)
    }

    func testTheTourIsUpOnAFirstLaunch() {
        launchTheTour()
        XCTAssertTrue(app.find(A11y.Tour.view).exists)
    }

    /// Never shut: not everyone can do every gesture, and the pages don't ask for one.
    func testPressingOnWalksThroughEveryPageToTheBoard() {
        launchTheTour()

        for lesson in A11y.Tour.lessonPages {
            let advance = advance.awaiting("the way on")
            XCTAssertTrue(advance.isEnabled, "The way off a page must never be shut")
            advance.tap()
            app.find(A11y.Tour.page(lesson)).awaiting("the \(lesson) page")
            instruction.awaiting("what the \(lesson) page asks the reader to do")
            practiceNotes.firstMatch.awaiting("a note to practise on, on the \(lesson) page")
        }

        advance.awaiting("the way out").tap()
        app.surface.awaiting("the board the tour was about")
        XCTAssertFalse(app.find(A11y.Tour.view).exists)
    }

    func testSkippingTheTourKeepsItAway() {
        skipTheTourAndRelaunch()
        XCTAssertFalse(app.find(A11y.Tour.view).exists, "The tour came back after being skipped")
    }

    func testShowMeHowPutsTheTourBackUp() {
        skipTheTourAndRelaunch()

        app.buttons[A11y.Canvas.tourButton].awaiting("Show Me How, on the empty board").tap()
        app.find(A11y.Tour.view).awaiting("the tour, put back up")
        skip.awaiting("the way out").tap()
        app.find(A11y.Tour.view).awaitingDisappearance("the tour")
    }

    func testTheListOfBoardsPutsTheTourBackUp() {
        skipTheTourAndRelaunch()

        app.showBoards()
        app.buttons[A11y.Boards.tourButton].awaiting("the tour button").tap()
        app.find(A11y.Tour.view).awaiting("the tour, put back up from the list of boards")
        skip.awaiting("the way out").tap()
        app.find(A11y.Tour.view).awaitingDisappearance("the tour")
    }

    /// The practice board runs the canvas's own double tap, and the page knows it was done.
    func testDoubleTappingThePracticeBoardAddsANote() {
        launchTheTour()
        pressOn(to: "doubleTapToAdd")
        let before = practiceNotes.count
        XCTAssertFalse(isPractised, "Done before anything was done")

        // Low on the board, where the lesson leaves room.
        practiceBoard.point(0.3, 0.8).doubleTap()

        awaitCount(practiceNotes, before + 1, "the practice notes after a double tap")
        awaitPractised()
    }

    /// The practice board runs the canvas's own drag and bin, on notes of its own: the reader's
    /// board is as it was.
    func testDraggingAPracticeNoteOntoItsBinDeletesItAndUndoBringsItBack() {
        launchTheTour()
        pressOn(to: "dragToBin")
        let before = practiceNotes.count
        let note = practiceNotes.firstMatch

        // The bin is where the canvas puts it, at the bottom of the board.
        let frame = practiceBoard.frame
        let bin = practiceBoard.point(0, 0).withOffset(
            CGVector(dx: frame.width / 2, dy: frame.height - Trash.centerAboveBottom))
        note.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: bin, withVelocity: .slow, thenHoldForDuration: 0.3)

        awaitCount(practiceNotes, before - 1, "the practice notes after one went in the bin")
        awaitPractised()
        app.undoButton.awaiting("Undo").tap()
        awaitCount(practiceNotes, before, "the practice notes after Undo")

        advance.tap()
        advance.awaiting("the way out").tap()
        app.surface.awaiting("the board the tour was about")
        XCTAssertEqual(app.notes.count, 0, "Practice reached the reader's board")
    }

    /// The canvas's own tap: the note comes to the middle of the practice board with the rest of
    /// it blurred, and a tap on the blur sends it back.
    func testTappingAPracticeNoteOpensItForWriting() {
        launchTheTour()
        pressOn(to: "tapToWrite")

        practiceNotes.firstMatch.tap()
        app.find(A11y.Canvas.blur).awaiting("the blur over the practice board")
        awaitPractised()

        // A corner of the board, clear of the note in the middle.
        practiceBoard.point(0, 0).withOffset(CGVector(dx: 12, dy: 12)).tap()
        app.find(A11y.Canvas.blur).awaitingDisappearance("the blur")
    }

    /// The note's own menu. Its items are UIKit's, and drop their identifiers: matched by label.
    func testHoldingAPracticeNoteOpensItsMenu() {
        launchTheTour()
        pressOn(to: "holdForMenu")

        practiceNotes.firstMatch.press(forDuration: 1.0)
        app.buttons["Pink"].awaiting("the colors").tap()
        awaitPractised()
    }

    func testDraggingAPracticeNoteMovesIt() {
        launchTheTour()
        pressOn(to: "dragToMove")
        let note = practiceNotes.firstMatch
        let start = note.frame

        note.point(0.5, 0.5).press(
            forDuration: 0.2, thenDragTo: practiceBoard.point(0.3, 0.6), withVelocity: .slow,
            thenHoldForDuration: 0.1)

        awaitPractised()
        XCTAssertGreaterThan(abs(note.frame.midY - start.midY), 40, "the note didn't move")
    }

    func testPinchingAPracticeNoteResizesIt() {
        launchTheTour()
        pressOn(to: "pinchToResize")
        let note = practiceNotes.firstMatch
        let start = note.frame.width

        note.pinch(withScale: 1.4, velocity: 1)

        awaitPractised()
        XCTAssertGreaterThan(note.frame.width, start + 20, "the note didn't grow")
    }

    func testPinchingAPracticeNoteUntilItCrumplesDeletesIt() {
        launchTheTour()
        pressOn(to: "pinchToCrumple")
        let before = practiceNotes.count

        practiceNotes.firstMatch.pinch(withScale: 0.1, velocity: -3)

        awaitCount(practiceNotes, before - 1, "the practice notes after a crumple")
        awaitPractised()
    }

    /// Every page: each has words and a board of its own.
    func testTheTourPassesTheAccessibilityAudit() throws {
        launchTheTour()
        try app.performAccessibilityAudit()

        for lesson in A11y.Tour.lessonPages {
            advance.awaiting("the way on").tap()
            app.find(A11y.Tour.page(lesson)).awaiting("the \(lesson) page")
            practiceNotes.firstMatch.awaiting("a note to practise on")
            try app.performAccessibilityAudit()
        }
    }

    func testShowMeHowPassesTheAccessibilityAudit() throws {
        launch()
        app.buttons[A11y.Canvas.tourButton].awaiting("Show Me How, on the empty board")
        try app.performAccessibilityAudit()
    }
}
