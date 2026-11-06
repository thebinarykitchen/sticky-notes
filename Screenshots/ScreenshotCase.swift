import AccessibilityIdentifiers
import LaunchArguments
import XCTest

/// Base class for the listing: launch configuration and settling before capture.
///
/// Explicitly `@MainActor`, with async `setUp`/`tearDown` — see `AppTestCase` in
/// `StickyNotesUITests`.
@MainActor
class ScreenshotCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        Multitasking.useFullScreenApps()
    }

    override func tearDown() async throws {
        app = nil
    }

    /// Launches the app a shot is taken of. Each test calls it first, rather than `setUp`, since
    /// the shots want different launches and an alternate that skips wants none.
    ///
    /// - Parameters:
    ///   - makeNotes: The stand-in for the on-device model, for the shots of Make Notes — see
    ///     the README. Off everywhere else, so the toolbar doesn't depend on the machine.
    ///   - tour: Due only for the lesson pages.
    ///   - pro: Bought except for the Pro sheet shot, so nothing is shown behind a paywall.
    func launch(makeNotes: Bool = false, tour: Bool = false, pro: Bool = true) {
        app = .forScreenshots(makeNotes: makeNotes, tour: tour, pro: pro)
        app.launch()
    }

    /// Launches onto the board the app opens on, and waits for its notes.
    func launchOntoTheBoard(makeNotes: Bool = false) {
        launch(makeNotes: makeNotes)
        app.note(saying: Seed.onTheBoard).awaiting("the board")
    }

    /// Waits for system animations (sheets, menus, the keyboard) that `--reduce-motion` doesn't
    /// affect. Two seconds covers a sheet presentation.
    func settle(_ duration: TimeInterval = 2) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settling")], timeout: duration)
    }

    /// Skips an alternate unless the run asked for them — see ``Shot/alternatesWanted``. Called
    /// before ``launch(makeNotes:tour:pro:)``, so a listing run spends nothing on it.
    func skipUnlessWanted(_ shot: Shot) throws {
        guard !shot.isInTheListing else { return }
        try XCTSkipUnless(
            Shot.alternatesWanted,
            "\(shot.fileName) is an alternate; set TEST_RUNNER_SCREENSHOT_ALTERNATES=1 to take it")
    }

    /// Waits for `element`, lets the screen settle, and takes `shot`.
    func capture(_ shot: Shot, once element: XCUIElement, _ what: String) {
        element.awaiting(what)
        settle()
        capture(shot)
    }
}

extension XCUIApplication {
    /// The app configured for screenshots: seeded, ephemeral, reduced motion.
    static func forScreenshots(makeNotes: Bool, tour: Bool, pro: Bool) -> XCUIApplication {
        let app = XCUIApplication()

        // `--reduce-motion`: static frames, the tour's demonstrations included.
        var flags: [LaunchFlag] = [.ephemeralStore, .seedListing, .reduceMotion]
        flags.append(makeNotes ? .fakeAppleIntelligence : .noAppleIntelligence)
        // `--no-storekit` keeps the preset unlock, which asking the store would take back. The
        // Pro shot is the one launched locked and the one that has to show a real price, so it
        // is served instead by the scheme's `StoreKit.storekit`.
        if pro { flags.append(.noStoreKit) }
        app.launchArguments = flags.map(\.rawValue)
        // The tour version the app is on: `OnboardingProgress.version`.
        app.launchArguments += LaunchDefault.onboardingFinished.arguments(tour ? "0" : "1")
        app.launchArguments += LaunchDefault.proUnlocked.arguments(pro ? "1" : "0")
        app.launchArguments += LaunchDefault.proUsedMakeNotes.arguments("0")

        return app
    }
}
