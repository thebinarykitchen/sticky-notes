import AccessibilityIdentifiers
import XCTest

/// Navigation helpers for screenshots. A thin copy of `StickyNotesUITests/App.swift`, since two
/// test bundles link no code in common.
@MainActor
extension XCUIApplication {
    /// Any element with `identifier`. The canvas and the notes aren't buttons.
    func find(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The canvas as it is on screen. The board behind it scrolls.
    var surface: XCUIElement { find(A11y.Canvas.surface) }

    /// Every note on screen, the tour's practice boards' included.
    var notes: XCUIElementQuery {
        descendants(matching: .any).matching(identifier: A11y.Note.card)
    }

    /// The note whose text is exactly `text`.
    func note(saying text: String) -> XCUIElement {
        notes.containing(NSPredicate(format: "value == %@", text)).firstMatch
    }

    /// The board list's `+`, which is only on screen while the list is.
    var addBoardButton: XCUIElement { buttons[A11y.Boards.addButton] }

    /// Brings the list of boards up: back from the canvas on an iPhone, the sidebar's toggle on
    /// an iPad in portrait, and nothing where the list already stands beside the canvas. Both
    /// buttons are UIKit's: the back button is labeled with the list's title.
    func showBoards() {
        if !addBoardButton.isHittable {
            let back = navigationBars.buttons["Boards"]
            if back.exists {
                back.tap()
            } else {
                buttons[Level.sidebarToggle].awaiting("the button that puts the list up").tap()
            }
        }
        addBoardButton.awaiting("the list of boards")
    }

    /// Opens the board named `name` from the list of boards.
    func openBoard(_ name: String) {
        showBoards()
        staticTexts[name].awaiting("the board \(name)").tap()
        navigationBars[name].awaiting("the canvas of \(name)")
    }

    /// The list's search field, focused and written in. It is UIKit's, found by type.
    @discardableResult
    func search(for text: String) -> XCUIElement {
        showBoards()
        let field = searchFields.firstMatch.awaiting("the search field")
        field.tap()
        dismissTheKeyboardTip()
        field.typeText(text)
        return field
    }

    /// Puts away the tip a simulator's first keyboard comes with ("slide to type"), which takes
    /// the typing until it goes and would be in the picture. iOS's own, so found by its label.
    /// Once per device; afterwards there is nothing to wait for but a second.
    func dismissTheKeyboardTip() {
        let tip = buttons["Continue"]
        if tip.waitForExistence(timeout: 1) { tip.tap() }
    }

    /// Holds a note until its menu is up.
    func showMenu(of text: String) {
        note(saying: text).awaiting("the note \(text)").press(forDuration: 1.0)
        // Menu items drop their identifiers; matched by label.
        buttons["Delete"].awaiting("the note's menu")
    }

    /// Closes a note's menu with a tap on the backdrop, at a corner of the canvas clear of the
    /// menu and of the note. Where the system puts the menu depends on the note's size and
    /// place: over a large note it goes to the top, where a fixed tap would land on Make Bigger.
    func closeMenu(of text: String) {
        let menu = buttons["Make Bigger"].frame.union(buttons["Delete"].frame)
        let clear = [menu, note(saying: text).frame].map { $0.insetBy(dx: -16, dy: -16) }
        let canvas = surface.frame.insetBy(dx: 12, dy: 12)
        let corners = [
            CGPoint(x: canvas.minX, y: canvas.minY), CGPoint(x: canvas.maxX, y: canvas.minY),
            CGPoint(x: canvas.minX, y: canvas.maxY), CGPoint(x: canvas.maxX, y: canvas.maxY),
        ]
        let corner = corners.first { point in !clear.contains { $0.contains(point) } }
        let point = corner ?? corners[0]
        coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        buttons["Delete"].awaitingDisappearance("the menu")
    }

    /// Opens Make Notes, writes `text` in its sheet, and waits for the sheet to say it can add.
    func writeInMakeNotes(_ text: String) {
        buttons[A11y.Canvas.makeNotesButton].awaiting("Make Notes").tap()
        // The field takes the keyboard as the sheet opens.
        find(A11y.MakeNotes.text).awaiting("the field notes are made from")
        dismissTheKeyboardTip()
        typeText(text)
        let add = buttons[A11y.MakeNotes.addButton]
        // Checked first: the expectation doesn't evaluate until its first one-second poll.
        guard !add.isEnabled else { return }
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"), object: add)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 5), .completed, "Add Notes")
    }

    /// The point over the bin, which is only drawn while a note is dragged: its centre is
    /// `TrashZone`'s 40 + 64 / 2 points above the bottom of the canvas, in the middle.
    var trash: XCUICoordinate {
        let frame = surface.frame
        return surface.point(0, 0).withOffset(CGVector(dx: frame.width / 2, dy: frame.height - 72))
    }

    /// Ends the writing on a note, which puts it back in its place: a tap on the blur over the
    /// board, in a corner the note in the middle never reaches.
    func stopWriting() {
        surface.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 8, dy: 8)).tap()
        find(A11y.Canvas.blur).awaitingDisappearance("the blur")
    }
}

@MainActor
extension XCUIElement {
    /// Waits for this element, and fails where it never turns up.
    ///
    /// `exists` first: `waitForExistence` doesn't check until its first one-second poll, even
    /// for an element already on screen.
    @discardableResult
    func awaiting(
        _ what: String,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(
            exists || waitForExistence(timeout: timeout), "Never saw \(what)", file: file,
            line: line)
        return self
    }

    /// Waits for this element to go, and fails where it stays. `exists` first, for the same
    /// one-second poll as ``awaiting(_:timeout:file:line:)``.
    func awaitingDisappearance(
        _ what: String,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            !exists || waitForNonExistence(timeout: timeout), "\(what) never went away",
            file: file, line: line)
    }

    /// The point at a fraction of this element.
    func point(_ dx: CGFloat, _ dy: CGFloat) -> XCUICoordinate {
        coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy))
    }
}

/// Puts an iPad in Full Screen Apps before anything is photographed.
///
/// An iPad simulator can be left in Windowed Apps, and there a synthesized pinch-in is taken by
/// the system rather than the app: it shrinks the app into a window, and the window keeps its
/// place across the next launches. Settings is the one place the mode can be set from; the
/// pane's rows carry stable identifiers. Seen in `task-manager`, whose shots pinch as the tour's
/// pages here do.
///
/// Once per test process — the choice outlives the app, and each clone runs its own process.
@MainActor
enum Multitasking {
    private static var isFullScreen = false

    static func useFullScreenApps() {
        guard UIDevice.current.userInterfaceIdiom == .pad, !isFullScreen else { return }

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        settings.buttons["com.apple.settings.multitaskingAndGestures"]
            .awaiting("Multitasking & Gestures in Settings")
            .tap()
        let fullScreen = settings.buttons[
            "com.apple.settings.multitaskingAndGestures.fullScreenApps"
        ]
        .awaiting("the Full Screen Apps option")
        if !fullScreen.isSelected { fullScreen.tap() }
        settings.terminate()

        isFullScreen = true
    }
}

/// What the shots look for on `SampleData.seedListing`'s boards. Must match it.
enum Seed {
    /// On "Home", which a launch opens: what says the board is up.
    static let onTheBoard = "Pick up the dry cleaning"
    /// On "Home", near the middle of a phone's canvas.
    static let toWriteOn = "Book the dentist before Friday"
    /// On "Home", top left, clear of the toolbar for its menu.
    static let forTheMenu = "Call Mum\nSunday, 6pm"
    /// Full like "Home", for the iPad's list of boards to stand beside.
    static let anotherBoard = "Lisbon"
    static let onAnotherBoard = "Tram 28 before 9"
    /// A board point on "Home" no note covers, for a double tap to add one.
    static let freeSpot = CGVector(dx: 228, dy: 468)
    /// Empty, for Make Notes to fill.
    static let emptyBoard = "Groceries"
    /// What Make Notes is given: a list, which the model makes a note of per item, as the
    /// stand-in does.
    static let madeFrom = "Milk, Eggs, Sourdough, Apples, Coffee beans, Basil"
    static let firstMade = "Milk"
    /// On three boards.
    static let searchTerm = "book"
    static let searchHit = "Book the team offsite"
}

/// UI names the app doesn't choose.
enum Level {
    /// UIKit's sidebar toggle identifier (note UIKit's `SideBar` spelling).
    static let sidebarToggle = "ToggleSideBar"
}
