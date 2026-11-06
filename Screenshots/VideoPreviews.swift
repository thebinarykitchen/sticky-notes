import AccessibilityIdentifiers
import LaunchArguments
import PreviewRecording
import XCTest

/// The App Store app preview journey.
///
/// Run by `video-preview` in [`launchpad`](../../launchpad), which records the simulator between
/// the start and stop markers this class writes through `PreviewRecorder`. Each mark keeps
/// footage until the next mark or for four seconds, whichever comes first.
///
/// ```sh
/// swift run --package-path ../launchpad/Packages/swift-app-store video-preview run
/// ```
///
/// `launchpad.json`'s `video-preview` section names this class as the bundle to run.
///
/// ## Beats
///
/// | Beat | What is on screen |
/// | --- | --- |
/// | `writing-one-down` | A double tap on the board: the note comes to the middle and is written on. |
/// | `into-the-bin` | The note dragged across the board onto the bin, and Undo bringing it back. |
/// | `making-it-bigger` | The note pinched apart. |
/// | `its-color` | Its menu held open, and a color picked. |
/// | `making-notes` | Another board, and a list written into Make Notes. |
/// | `notes-made` | The list arriving as a note per item — the poster frame (`posterBeat`). |
///
/// It drags once. A second drag in one launch never moved a note on iOS 27 — any note, under
/// Reduce Motion; on this journey, with motion on too — so the move and the bin are one beat.
///
/// One journey for both sizes: the list of boards is beside the canvas on a 13-inch iPad and
/// behind it on a phone, and `openBoard(_:)` takes either way to the next board.
///
/// ## Requirements
///
/// - Motion enabled (unlike ``ScreenshotCase``).
/// - A Debug build, for `--seed-listing` and the Make Notes stand-in.
@MainActor
final class VideoPreviews: XCTestCase {
    private var app: XCUIApplication!
    private var recorder: PreviewRecorder!

    /// What the journey writes on the note it adds.
    private static let written = "Buy stamps"

    override func setUp() async throws {
        continueAfterFailure = false
        Multitasking.useFullScreenApps()
        recorder = PreviewRecorder()
        app = .forPreview()
        app.launch()
    }

    override func tearDown() async throws {
        app = nil
        recorder = nil
    }

    func testThePreview() {
        app.note(saying: Seed.onTheBoard).awaiting("the board", timeout: 30)
        // Before recording: the tip would take the typing on camera.
        warmTheKeyboard()

        recorder.start()
        holdForTheRecorder()

        // 1 — A double tap on a free spot of the board (board points, which open at the
        // canvas's top-left — see `SampleData.seedListing`), and the note it adds written on.
        mark("writing-one-down")
        app.surface.point(0, 0).withOffset(Seed.freeSpot).doubleTap()
        app.find(A11y.Canvas.blur).awaiting("the new note, written on")
        hold(0.6)
        app.typeText(Self.written)
        hold(1.0)
        app.stopWriting()
        let note = app.note(saying: Self.written).awaiting("the note written")
        hold(0.6)

        // 2 — Across the board onto the bin, and back. What a finger holds tracks it undamped,
        // so slowly for the camera.
        mark("into-the-bin")
        note.point(0.5, 0.5).press(
            forDuration: 0.3, thenDragTo: app.trash, withVelocity: .slow,
            thenHoldForDuration: 0.6)
        // The offer is up for `CanvasView.undoOffer`, five seconds, and is itself the sign the
        // note went: waiting for the note to go first lost it on a slow simulator.
        let undo = app.buttons[A11y.Canvas.undoButton].awaiting("Undo")
        hold(0.8)
        undo.tap()
        // A note brought back is a new instance, found again by its text.
        app.note(saying: Self.written).awaiting("the note brought back")
        hold(1.0)

        // 3 — Pinched apart.
        mark("making-it-bigger")
        note.pinch(withScale: 1.6, velocity: 1)
        hold(1.5)

        // 4 — Its menu, and a color only Pro has.
        // Marked once the menu is up: opening it takes most of a beat, and the beat is the pick
        // and the note in its new color, which a cut at four seconds from the press missed.
        note.press(forDuration: 1.0)
        let purple = app.buttons["Purple"].awaiting("the colors")
        mark("its-color")
        hold(0.5)
        purple.tap()
        hold(0.8)
        app.closeMenu(of: Self.written)
        hold(1.5)

        // 5 — Another board, and a list for Make Notes. Marked once the sheet is up: getting
        // there is the list of boards, which the next stills show.
        app.openBoard(Seed.emptyBoard)
        app.buttons[A11y.Canvas.makeNotesButton].awaiting("Make Notes").tap()
        app.find(A11y.MakeNotes.text).awaiting("the field notes are made from")
        hold(0.6)
        mark("making-notes")
        app.typeText(Seed.madeFrom)
        hold(0.8)

        // 6 — The list, a note per item. Held past a whole beat, so all four seconds are in the
        // file: it is the poster frame.
        mark("notes-made")
        app.buttons[A11y.MakeNotes.addButton].tap()
        app.note(saying: Seed.firstMade).awaiting("the notes made")
        hold(6.0)

        recorder.stop()
    }

    // MARK: - Before recording

    /// Brings the keyboard up once and puts it away again, so a fresh simulator's tip is gone
    /// before the camera rolls.
    private func warmTheKeyboard() {
        app.note(saying: Seed.toWriteOn).tap()
        app.find(A11y.Canvas.blur).awaiting("a note, written on")
        app.dismissTheKeyboardTip()
        app.stopWriting()
    }

    // MARK: - Recording

    private func mark(_ label: String) {
        recorder.mark(label)
    }

    /// `simctl` begins capturing up to several seconds after it is started, and a beat marked
    /// before the video's first frame keeps none of its own start.
    private func holdForTheRecorder() {
        hold(4.0)
    }

    /// Holds the current screen for the recording.
    private func hold(_ seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "holding")], timeout: seconds)
    }
}

extension XCUIApplication {
    /// The app configured for recording: the listing's boards, ephemeral, Pro unlocked (with
    /// `--no-storekit`), the Make Notes stand-in, and motion on.
    static func forPreview() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            LaunchFlag.ephemeralStore, .seedListing, .fakeAppleIntelligence, .noStoreKit,
        ].map(\.rawValue)
        app.launchArguments += LaunchDefault.onboardingFinished.arguments("1")
        app.launchArguments += LaunchDefault.proUnlocked.arguments("1")
        app.launchArguments += LaunchDefault.proUsedMakeNotes.arguments("0")
        return app
    }
}
