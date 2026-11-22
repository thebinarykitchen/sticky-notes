import AccessibilityIdentifiers
import LaunchArguments
import UITestSupport
import XCTest

/// Which store a launch runs on.
enum StoreKind {
    case ephemeral
    /// The persistent store, for testing persistence across launches. Never synced: it adds
    /// `LaunchFlag.noSync`.
    case onDisk
}

/// Whether a launch makes notes with Apple Intelligence: whether the on-device model runs in
/// the Simulator depends on the Mac hosting it, and what it writes varies.
enum IntelligenceKind {
    /// Not at all, whatever the Mac: the toolbar every other test expects.
    case off
    /// Through a stand-in that makes a note of each line or comma-separated item written (Debug
    /// builds only).
    case fake
}

/// What a launch reads as Pro's state. Every case but ``whateverStuck`` adds
/// `LaunchFlag.noStoreKit`, so a simulator asked what it owns, which answers nothing, doesn't
/// overwrite the preset.
enum ProState: Equatable {
    /// Bought.
    case unlocked
    /// Not bought, with this month's Make Notes untouched: what every other test expects.
    case locked
    /// Not bought, with this month's Make Notes all spent.
    case makeNotesSpent
    /// Not bought, with one Make Notes left this month, so the next run spends the last.
    case oneMakeNotesLeft
    /// No preset and StoreKit asked: for testing what the store says.
    case whateverStuck

    /// The app's `ProFeature.freeMakeNotes`, which this bundle can't import. Changed there and
    /// not here, `ProTests.testTheLastFreeRunOffersProAsItsNotesLand` fails.
    static let freeMakeNotes = 10
}

/// What a launch reads as the tour's stored answer — see `LaunchDefault`.
enum TourState {
    /// Finished or skipped already: the canvas every other test expects.
    case answered
    /// Never answered, as on a fresh install: the tour is up at launch.
    case due
    /// Nothing preset, so what the app last wrote is read: for testing that an answer sticks.
    case whateverStuck
}

@MainActor
extension XCUIApplication {
    /// The app configured for a UI test via launch arguments. Reduce Motion is always on, so
    /// nothing is left animating for a test to wait out — the tour's demonstrations included,
    /// which would otherwise loop for as long as their page is up.
    ///
    /// - Parameters:
    ///   - seeded: Whether to seed sample notes (Debug builds only).
    ///   - store: Ephemeral unless testing persistence.
    ///   - intelligence: Off unless testing making notes.
    ///   - tour: Answered unless testing the tour.
    ///   - hints: Off unless testing them: every lesson known, so no board has a hint over its
    ///     notes.
    ///   - pro: Locked with nothing spent unless testing Pro.
    static func underTest(
        seeded: Bool = false, store: StoreKind = .ephemeral, intelligence: IntelligenceKind = .off,
        tour: TourState = .answered, hints: Bool = false, pro: ProState = .locked
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var flags: [LaunchFlag] = [.reduceMotion]
        switch store {
        case .ephemeral: flags.append(.ephemeralStore)
        case .onDisk: flags.append(.noSync)
        }
        if seeded { flags.append(.seedStore) }
        switch intelligence {
        case .off: flags.append(.noAppleIntelligence)
        case .fake: flags.append(.fakeAppleIntelligence)
        }
        if pro != .whateverStuck { flags.append(.noStoreKit) }
        app.launchArguments = flags.map(\.rawValue)
        switch tour {
        // The tour version the app is on: `TourProgress.version`.
        case .answered: app.launchArguments += LaunchDefault.onboardingFinished.arguments("1")
        case .due: app.launchArguments += LaunchDefault.onboardingFinished.arguments("0")
        case .whateverStuck: break
        }
        app.launchArguments += LaunchDefault.onboardingKnown.arguments(
            hints ? "" : A11y.Tour.lessonPages.joined(separator: ","))
        // Every key preset: `UserDefaults` outlives the run, unlike the ephemeral store.
        let unlocked = LaunchDefault.proUnlocked
        let used = LaunchDefault.proUsedMakeNotes
        switch pro {
        case .unlocked: app.launchArguments += unlocked.arguments("1") + used.arguments("0")
        case .locked: app.launchArguments += unlocked.arguments("0") + used.arguments("0")
        case .makeNotesSpent:
            app.launchArguments += unlocked.arguments("0") + used.arguments("9999")
        case .oneMakeNotesLeft:
            app.launchArguments +=
                unlocked.arguments("0") + used.arguments("\(ProState.freeMakeNotes - 1)")
        case .whateverStuck: break
        }
        return app
    }

    /// The canvas as it is on screen. The board behind it scrolls.
    var surface: XCUIElement { find(A11y.Canvas.surface) }

    /// Every note on the canvas — see ``A11y/Note/card``.
    var notes: XCUIElementQuery {
        descendants(matching: .any).matching(identifier: A11y.Note.card)
    }

    /// The banner's Undo, shown for a few seconds after a delete.
    var undoButton: XCUIElement { buttons[A11y.Canvas.undoButton] }

    /// The note whose text is exactly `text`.
    func note(saying text: String) -> XCUIElement {
        notes.containing(NSPredicate(format: "value == %@", text)).firstMatch
    }
}

@MainActor
extension XCUIElement {
    /// The point at a fraction of this element.
    func point(_ dx: CGFloat, _ dy: CGFloat) -> XCUICoordinate {
        coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy))
    }
}

@MainActor
extension XCUIApplication {
    /// The board list's `+`, which is only on screen while the list is.
    var addBoardButton: XCUIElement { buttons[A11y.Boards.addButton] }

    /// Goes back from the canvas to the list of boards, on an iPhone; on an iPad the list is
    /// already beside it. The back button is UIKit's, labeled with the list's title.
    func showBoards() {
        if !addBoardButton.isHittable {
            navigationBars.buttons["Boards"].awaiting("the back button").tap()
        }
        addBoardButton.awaiting("the list of boards")
    }

    /// The row of the board named `name` in the list of boards, and not the open board's title,
    /// which on an iPad reads the same.
    func boardRow(_ name: String) -> XCUIElement {
        staticTexts.matching(identifier: A11y.Boards.row)
            .matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    /// Opens the board named `name` from the list of boards.
    func openBoard(_ name: String) {
        showBoards()
        boardRow(name).awaiting("the board \(name)").tap()
        surface.awaiting("the canvas of \(name)")
    }
}

/// The bin's place, mirrored from `TrashZone`, which this bundle can't import: its centre is this
/// far above the bottom of the canvas, in the middle.
enum Trash {
    static let centerAboveBottom: CGFloat = 40 + 64 / 2
}

@MainActor
extension XCUIApplication {
    /// The point over the bin, which is only drawn while a note is dragged.
    var trash: XCUICoordinate {
        let frame = surface.frame
        return surface.point(0, 0).withOffset(
            CGVector(dx: frame.width / 2, dy: frame.height - Trash.centerAboveBottom))
    }

    /// Ends the writing on a note, which puts it back in its place: a tap on the blur over the
    /// board, in a corner the note in the middle never reaches.
    func stopWriting() {
        surface.point(0, 0).withOffset(CGVector(dx: 8, dy: 8)).tap()
        find(A11y.Canvas.blur).awaitingDisappearance("the blur")
    }
}

/// Base class: launches this suite's app, on top of holding it and stopping at the first failure.
class AppTestCase: UITestCase {
    /// Launches and waits for the canvas.
    func launch(
        seeded: Bool = false, store: StoreKind = .ephemeral, intelligence: IntelligenceKind = .off,
        pro: ProState = .locked
    ) {
        app = .underTest(seeded: seeded, store: store, intelligence: intelligence, pro: pro)
        app.launch()
        app.surface.awaiting("the canvas")
    }
}
