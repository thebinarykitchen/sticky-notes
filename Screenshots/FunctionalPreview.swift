import AccessibilityIdentifiers
import LaunchArguments
import XCTest

/// The functional preview: every screen and notable state the app can be walked to, filed as
/// attachments for launchpad's `app-preview` to tile into an HTML contact sheet.
///
/// ```sh
/// swift run --package-path ../launchpad/Packages/swift-app-store app-preview
/// swift run --package-path ../launchpad/Packages/swift-app-store app-preview \
///   --appearance light --appearance dark      # each device twice, a tab per pass
/// ```
///
/// Like the listing next door, nothing here asserts anything about the app —
/// `StickyNotesUITests` is where behavior is checked. What separates the two is the subject:
/// ``Listing`` is the pictures that sell the app, every one with Pro bought. These are every
/// state someone reviewing the app has to look at: the listing's screens again, since
/// `app-preview` leaves `Listing` out, and mostly the ones a listing would never show — the
/// first launch, the prompts, the walls, the largest type size.
///
/// ## Rules
///
/// - **Numbered from 100,** a block of ten per section, so the sheet keeps the order the app is
///   met in whatever order XCTest ran. Past 99, a tile's name never reads as one of the
///   listing's own files (``Shot``). `app-preview` renumbers them 01…N afterwards.
/// - **Each test picks its own launch,** since half of what is worth a picture is a state the
///   standard one can't reach.
/// - **A class is small on purpose.** `continueAfterFailure` is off, so a class that walks into
///   something missing loses the rest of its own tiles and none of anybody else's.
/// - **Anything that depends on the device skips rather than fails** — the list of boards beside
///   the canvas, say, which only a wide screen has.

// MARK: - Capture

/// Hands out sequentially numbered names, so a tile's place in the sheet doesn't depend on the
/// order XCTest ran the methods in. Each method seeds its own base; the gaps between bases keep
/// the sections in the intended order.
@MainActor
final class PreviewShots {
    private unowned let testCase: XCTestCase
    private var next: Int

    init(in testCase: XCTestCase, from start: Int) {
        self.testCase = testCase
        self.next = start
    }

    /// Files the screen under the next number, suffixed with `name`. See `capture(named:)`.
    func capture(_ name: String) {
        testCase.capture(named: String(format: "%02d-%@", next, name))
        next += 1
    }
}

// MARK: - The base

/// What a preview launch reads as Pro's state.
enum ProLaunch {
    /// Bought, with `--no-storekit` so the preset holds.
    case unlocked
    /// Not bought, nothing spent, with `--no-storekit`: the sheet offers Try Again for the price.
    case locked
    /// Not bought, asking StoreKit, for the sheet with a real price. `app-preview` runs from an
    /// `.xctestrun`, which never carries the scheme's StoreKit configuration, so there it may
    /// get no price either; a plain `xcodebuild test` gets `StoreKit.storekit`'s.
    case lockedAskingTheStore
    /// Not bought, with this month's Make Notes spent.
    case makeNotesSpent
}

/// Holds the app and the numbering, and launches nothing: each test chooses its own state.
@MainActor
class FunctionalPreviewCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        Multitasking.useFullScreenApps()
    }

    override func tearDown() async throws {
        app = nil
    }

    /// Waits out the animations `--reduce-motion` doesn't cover — sheets, the keyboard, a menu
    /// opening. Two seconds covers a sheet presentation.
    func settle(_ duration: TimeInterval = 2) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settling")], timeout: duration)
    }

    /// Launches, and waits for the canvas: on the listing's boards, unless `seeded` is off.
    func launch(
        seeded: Bool = true, makeNotes: Bool = false, tour: Bool = false,
        pro: ProLaunch = .unlocked, contentSize: String? = nil
    ) {
        app = .forFunctionalPreview(
            seeded: seeded, makeNotes: makeNotes, tour: tour, pro: pro, contentSize: contentSize)
        app.launch()
        if !tour {
            app.surface.awaiting("the canvas")
            if seeded { app.note(saying: Seed.onTheBoard).awaiting("the board") }
        }
    }
}

extension XCUIApplication {
    /// The app configured for one preview capture: ephemeral, reduced motion.
    ///
    /// - Parameters:
    ///   - seeded: The listing's boards. Off for the states only an empty store shows.
    ///   - makeNotes: The stand-in for the on-device model. Off, Make Notes isn't drawn.
    ///   - tour: Whether the tour is due, as on a first install.
    ///   - contentSize: A `UIContentSizeCategory` name, for the Dynamic Type pass.
    static func forFunctionalPreview(
        seeded: Bool, makeNotes: Bool, tour: Bool, pro: ProLaunch, contentSize: String?
    ) -> XCUIApplication {
        let app = XCUIApplication()

        var flags: [LaunchFlag] = [.ephemeralStore, .reduceMotion]
        if seeded { flags.append(.seedListing) }
        flags.append(makeNotes ? .fakeAppleIntelligence : .noAppleIntelligence)
        if pro != .lockedAskingTheStore { flags.append(.noStoreKit) }
        app.launchArguments = flags.map(\.rawValue)

        app.launchArguments += LaunchDefault.onboardingFinished.arguments(tour ? "0" : "1")
        app.launchArguments += LaunchDefault.proUnlocked.arguments(pro == .unlocked ? "1" : "0")
        // Exceeds any allowance, so the wall doesn't depend on what the limit currently is.
        app.launchArguments += LaunchDefault.proUsedMakeNotes.arguments(
            pro == .makeNotesSpent ? "9999" : "0")
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }

        return app
    }
}

// MARK: - The first launch

/// What a fresh install opens on, and the tour in front of it.
final class PreviewFirstRun: FunctionalPreviewCase {
    func testTheEmptyFirstBoard() {
        launch(seeded: false)
        app.find(A11y.Canvas.emptyState).awaiting("the empty board a first launch opens on")
        settle()

        PreviewShots(in: self, from: 100).capture("EmptyBoard")
    }

    func testTheTourFromEndToEnd() {
        launch(seeded: false, tour: true)

        let shots = PreviewShots(in: self, from: 110)
        app.find(A11y.Tour.page(A11y.Tour.welcomePage)).awaiting("the welcome page")
        settle()
        shots.capture("TourWelcome")

        for page in A11y.Tour.lessonPages {
            app.buttons[A11y.Tour.advanceButton].awaiting("the way on").tap()
            app.find(A11y.Tour.page(page)).awaiting("the \(page) page")
            app.find(A11y.Tour.practiceBoard).awaiting("the \(page) page's board")
            settle()
            shots.capture(Self.tile(for: page))
        }

        app.buttons[A11y.Tour.advanceButton].awaiting("the way out").tap()
        app.find(A11y.Canvas.emptyState).awaiting("the board the tour was about")
        settle()
        shots.capture("AfterTheTour")
    }

    /// A lesson page's tile: `doubleTapToAdd` is `TourDoubleTapToAdd`.
    private static func tile(for page: String) -> String {
        "Tour" + page.prefix(1).uppercased() + page.dropFirst()
    }
}

// MARK: - The board

/// A board, a note added without the gesture, a note's menu, and the offer after a delete.
final class PreviewTheBoard: FunctionalPreviewCase {
    func testTheBoardAndANewNote() {
        launch()

        let shots = PreviewShots(in: self, from: 120)
        settle()
        shots.capture("TheBoard")

        // A new note is written on in the middle, as one a double tap adds is.
        app.buttons[A11y.Canvas.addButton].awaiting("the add button").tap()
        app.find(A11y.Canvas.blur).awaiting("the new note, written on")
        app.dismissTheKeyboardTip()
        settle()
        shots.capture("ANewNote")
    }

    func testANotesMenuAndTheOfferToUndo() {
        launch()

        let shots = PreviewShots(in: self, from: 122)
        app.showMenu(of: Seed.forTheMenu)
        settle()
        shots.capture("TheNotesMenu")

        app.buttons["Delete"].tap()
        app.find(A11y.Canvas.undoBanner).awaiting("the offer to undo")
        shots.capture("TheOfferToUndo")
    }

    /// The largest a note can be made, through its menu: the non-gesture way to resize.
    func testTheLargestNote() {
        launch()

        // From `NoteGeometry.defaultSide` to `maxSide`, a `step` at a time: 160 to 320 by 40.
        for _ in 0..<4 {
            app.showMenu(of: Seed.forTheMenu)
            app.buttons["Make Bigger"].tap()
            // Whether the menu stays up after a pick is the system's; close it if it did.
            if app.buttons["Delete"].waitForExistence(timeout: 1) {
                app.closeMenu(of: Seed.forTheMenu)
            }
        }
        app.note(saying: Seed.forTheMenu).awaiting("the note, at its largest")
        settle()

        PreviewShots(in: self, from: 124).capture("TheLargestNote")
    }
}

// MARK: - Boards

/// The list of boards, and the prompts it puts up: naming, renaming, deleting.
final class PreviewBoards: FunctionalPreviewCase {
    func testTheListAndItsPrompts() {
        launch()

        let shots = PreviewShots(in: self, from: 130)
        app.showBoards()
        settle()
        shots.capture("TheBoards")

        app.addBoardButton.tap()
        app.alerts.textFields.firstMatch.awaiting("the name field")
        app.dismissTheKeyboardTip()
        settle()
        shots.capture("NamingANewBoard")
        app.alerts.buttons["Cancel"].tap()
        app.alerts.firstMatch.awaitingDisappearance("the prompt")

        app.staticTexts[Seed.anotherBoard].awaiting("a board's row").press(forDuration: 1.0)
        app.buttons["Rename"].awaiting("the board's menu")
        settle()
        shots.capture("ABoardsMenu")

        app.buttons["Rename"].tap()
        app.alerts.textFields.firstMatch.awaiting("the name, to change")
        settle()
        shots.capture("RenamingABoard")
        app.alerts.buttons["Cancel"].tap()
        app.alerts.firstMatch.awaitingDisappearance("the prompt")

        app.staticTexts[Seed.anotherBoard].press(forDuration: 1.0)
        app.buttons["Delete"].awaiting("the board's menu").tap()
        app.buttons["Delete Board"].awaiting("the confirmation")
        settle()
        shots.capture("DeletingABoard")
    }

    /// Wide, the list stands beside the canvas: an iPad in landscape, and a 13-inch one in
    /// portrait too. Skips where nothing stands beside it.
    func testTheListBesideTheCanvas() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        launch()
        try XCTSkipUnless(app.addBoardButton.isHittable, "Nothing stands beside the canvas")
        settle()

        PreviewShots(in: self, from: 136).capture("BesideTheCanvasInLandscape")
    }
}

// MARK: - Search

/// Search over every board, nothing found, and a note picked from the results.
final class PreviewSearch: FunctionalPreviewCase {
    func testSearchingAndPicking() {
        launch()

        let shots = PreviewShots(in: self, from: 140)
        let field = app.search(for: Seed.searchTerm)
        let results = app.buttons.matching(identifier: A11y.Boards.searchResult)
        results.firstMatch.awaiting("the notes found")
        settle()
        shots.capture("SearchResults")

        field.typeText("zzzz")
        results.firstMatch.awaitingDisappearance("the notes found")
        settle()
        shots.capture("SearchFoundNothing")

        field.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: "zzzz".count))
        let hit = results.containing(NSPredicate(format: "label CONTAINS %@", Seed.searchHit))
            .firstMatch
        hit.awaiting("a note on another board").tap()
        app.note(saying: Seed.searchHit).awaiting("the note, in the middle of its board")
        settle()
        shots.capture("ANoteFound")
    }
}

// MARK: - Make Notes

/// Making notes, through the stand-in for the on-device model: the sheet empty, written in,
/// and the notes it made.
final class PreviewMakeNotes: FunctionalPreviewCase {
    func testTheSheetAndTheNotesItMakes() {
        launch(makeNotes: true)
        app.openBoard(Seed.emptyBoard)

        let shots = PreviewShots(in: self, from: 150)
        app.buttons[A11y.Canvas.makeNotesButton].awaiting("Make Notes").tap()
        app.find(A11y.MakeNotes.text).awaiting("the field notes are made from")
        app.dismissTheKeyboardTip()
        settle()
        shots.capture("MakeNotesEmpty")

        app.typeText(Seed.madeFrom)
        settle()
        shots.capture("MakeNotesWritten")

        app.buttons[A11y.MakeNotes.addButton].tap()
        app.find(A11y.MakeNotes.text).awaitingDisappearance("the sheet")
        app.note(saying: Seed.firstMade).awaiting("the notes made")
        settle()
        shots.capture("NotesMade")
    }
}

// MARK: - Pro

/// What Pro looks like from both sides of the wall.
final class PreviewPro: FunctionalPreviewCase {
    func testTheSheetAndRestoring() throws {
        launch(pro: .lockedAskingTheStore)

        let shots = PreviewShots(in: self, from: 170)
        app.showBoards()
        app.buttons[A11y.Pro.listRow].awaiting("Pro's row").tap()
        app.find(A11y.Pro.sheet).awaiting("the Pro sheet")
        // The price, or Try Again where StoreKit serves nothing.
        _ = app.buttons[A11y.Pro.buyButton].waitForExistence(timeout: 10)
        settle()
        shots.capture("TheProSheet")

        // Where StoreKit serves nothing, a restore is a real App Store sync that never answers.
        try XCTSkipIf(
            app.buttons[A11y.Pro.retryButton].exists,
            "StoreKit isn't serving products here, so a restore never answers")
        app.buttons[A11y.Pro.restoreButton].tap()
        // A sync with whichever store the run has, which may ask to sign in and never answer.
        try XCTSkipUnless(
            app.find(A11y.Pro.message).waitForExistence(timeout: 30),
            "The restore never answered here")
        settle()
        shots.capture("RestoringAPurchase")
    }

    /// The listing's four boards are one more than free: the list's `+` asks for Pro.
    func testTheWallInFrontOfAnotherBoard() {
        launch(pro: .locked)
        app.showBoards()
        app.addBoardButton.tap()
        app.find(A11y.Pro.reason("boards")).awaiting("the sheet, for boards")
        settle()

        PreviewShots(in: self, from: 172).capture("TheWallForBoards")
    }

    func testTheWallInFrontOfAProColor() {
        launch(pro: .locked)
        app.showMenu(of: Seed.forTheMenu)
        app.buttons["Purple"].awaiting("a color only Pro has").tap()
        app.find(A11y.Pro.reason("colors")).awaiting("the sheet, for colors")
        settle()

        PreviewShots(in: self, from: 173).capture("TheWallForColors")
    }

    func testTheWallInFrontOfSpentMakeNotes() {
        launch(makeNotes: true, pro: .makeNotesSpent)
        app.buttons[A11y.Canvas.makeNotesButton].awaiting("Make Notes").tap()
        app.find(A11y.Pro.reason("makeNotes")).awaiting("the sheet, for Make Notes")
        settle()

        PreviewShots(in: self, from: 174).capture("TheWallForMakeNotes")
    }
}

// MARK: - The largest type

/// What the largest Dynamic Type size does to a note, the list, and a note being written on.
final class PreviewLargestType: FunctionalPreviewCase {
    private static let largest = "UICTContentSizeCategoryAccessibilityXXXL"

    func testTheBoardAndTheListAtTheLargestSize() {
        launch(contentSize: Self.largest)

        let shots = PreviewShots(in: self, from: 180)
        settle()
        shots.capture("LargestTypeBoard")

        app.note(saying: Seed.toWriteOn).tap()
        app.find(A11y.Canvas.blur).awaiting("the note, written on")
        app.dismissTheKeyboardTip()
        settle()
        shots.capture("LargestTypeWriting")
        app.stopWriting()

        app.showBoards()
        settle()
        shots.capture("LargestTypeBoards")
    }
}
