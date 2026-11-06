import AccessibilityIdentifiers
import XCTest

/// The App Store listing: ``Shot``'s seven, and its alternates when a run asks for them.
///
/// The one class the `screenshots` section of `launchpad.json` names, so `screenshots run` takes
/// these and nothing else and `app-preview` leaves them out. The shots want four different
/// launches — the standard one, Make Notes on, the tour due, Pro locked — so each test launches
/// its own, after ``skipUnlessWanted(_:)`` where it is an alternate.
final class Listing: ScreenshotCase {
    // MARK: - The listing

    /// The primary listing image: a board full of notes, every color on it.
    func testTheBoard() {
        launchOntoTheBoard()
        settle()
        capture(.theBoard)
    }

    /// A note tapped comes to the middle, above the keyboard, with the board blurred behind it.
    func testWritingOnANote() {
        launchOntoTheBoard()
        app.note(saying: Seed.toWriteOn).awaiting("the note to write on").tap()
        app.find(A11y.Canvas.blur).awaiting("the blur behind the note")
        app.dismissTheKeyboardTip()
        settle()
        capture(.writingOnANote)
    }

    /// Make Notes' sheet with a list written in it, over the empty board it will fill.
    func testMakingNotes() {
        launch(makeNotes: true)
        app.openBoard(Seed.emptyBoard)
        app.writeInMakeNotes(Seed.madeFrom)
        settle()
        capture(.makingNotes)
    }

    /// The notes the list became, together in the middle of the board.
    func testNotesMade() {
        launch(makeNotes: true)
        app.openBoard(Seed.emptyBoard)
        app.writeInMakeNotes(Seed.madeFrom)
        app.buttons[A11y.MakeNotes.addButton].tap()
        app.find(A11y.MakeNotes.text).awaitingDisappearance("the sheet")
        capture(.notesMade, once: app.note(saying: Seed.firstMade), "the notes made")
    }

    /// A note's menu: every color, with Pro, and the non-gesture ways to resize and delete.
    func testANotesColors() {
        launchOntoTheBoard()
        app.showMenu(of: Seed.forTheMenu)
        settle()
        capture(.aNotesColors)
    }

    /// The list of boards: back from the canvas on an iPhone. Where it already stands beside the
    /// canvas, as on a 13-inch iPad even in portrait, another board is opened from it instead,
    /// or this would be shot 01 again.
    func testEveryBoard() {
        launchOntoTheBoard()
        if app.addBoardButton.isHittable {
            app.openBoard(Seed.anotherBoard)
            app.note(saying: Seed.onAnotherBoard).awaiting("the other board's notes")
        } else {
            app.showBoards()
        }
        settle()
        capture(.everyBoard)
    }

    /// One search over every board, each note found under the board it is on.
    func testSearch() {
        launchOntoTheBoard()
        app.search(for: Seed.searchTerm)
        let hit = app.buttons.matching(identifier: A11y.Boards.searchResult)
            .containing(NSPredicate(format: "label CONTAINS %@", Seed.searchHit)).firstMatch
        capture(.search, once: hit, "a note found on another board")
    }

    // MARK: - Alternates

    /// The tour's pages. Not in the listing, where a tour page reads as a tutorial and is mostly
    /// a practice board. Under `--reduce-motion` each demonstration is a still.
    func testTheTour() throws {
        try skipUnlessWanted(.tourWelcome)
        launch(tour: true)
        capture(
            .tourWelcome, once: app.find(A11y.Tour.page(A11y.Tour.welcomePage)),
            "the welcome page")

        for (page, shot) in zip(A11y.Tour.lessonPages, Shot.lessons) {
            app.buttons[A11y.Tour.advanceButton].awaiting("the way on").tap()
            app.find(A11y.Tour.page(page)).awaiting("the \(page) page")
            capture(shot, once: app.find(A11y.Tour.practiceBoard), "the \(page) page's board")
        }
    }

    /// The Pro sheet, for the in-app purchase's review screenshot. The only shot launched
    /// without Pro, and without `--no-storekit`, so the price is the scheme's `StoreKit.storekit`.
    func testUnlockingPro() throws {
        try skipUnlessWanted(.unlockingPro)
        launch(pro: false)
        app.note(saying: Seed.onTheBoard).awaiting("the board")
        app.showBoards()
        app.buttons[A11y.Pro.listRow].awaiting("Pro's row").tap()
        app.find(A11y.Pro.sheet).awaiting("the Pro sheet")

        XCTAssertTrue(
            app.buttons[A11y.Pro.buyButton].waitForExistence(timeout: 10),
            "No price: StoreKit served no product, and the sheet offers Try Again")
        settle()
        capture(.unlockingPro)
    }
}
