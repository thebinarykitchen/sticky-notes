import AccessibilityIdentifiers
import XCTest

/// Run against a Release build by `preflight --stage runtime`, so nothing here leans on a Debug
/// launch flag: no seed, no stand-in model. Each method maps to a finding by name in
/// `launchpad.json`'s `preflight.tests.runtimeChecks`: rename one here and rename it there, or its
/// finding falls back to `runtime.<methodName>`.
final class PreflightTests: AppTestCase {
    private func launchAsShipped(
        store: StoreKind = .ephemeral, tour: TourState = .answered, contentSize: String? = nil
    ) {
        app = .underTest(store: store, tour: tour)
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
    }

    func testColdLaunchWithNoArgumentsComesUp() {
        app = XCUIApplication()
        app.launch()

        XCTAssertEqual(app.state, .runningForeground, "The app did not come up")
        let arrived =
            app.surface.waitForExistence(timeout: 20)
            || app.find(A11y.Tour.view).waitForExistence(timeout: 1)
        XCTAssertTrue(arrived, "Came up on nothing recognizable")
    }

    /// A first launch has the tour, and behind it a board with nothing on it.
    func testAFirstLaunchOpensOnTheTourAndAnEmptyBoard() {
        launchAsShipped(tour: .due)
        app.find(A11y.Tour.view).awaiting("the tour a first launch opens on")
        app.buttons[A11y.Tour.skipButton].awaiting("the way out of the tour").tap()

        app.surface.awaiting("the board")
        app.find(A11y.Canvas.emptyState).awaiting("the empty board's invitation")
        XCTAssertEqual(app.notes.count, 0, "a first launch starts with no notes")
    }

    /// On the real store. Cleans up after itself, so it is safe on a store that holds notes.
    func testWhatIsWrittenSurvivesARelaunch() {
        launchAsShipped(store: .onDisk)
        app.surface.awaiting("the board")
        let text = "Relaunch \(UUID().uuidString.prefix(8))"
        app.buttons[A11y.Canvas.addButton].awaiting("the add button").tap()
        app.typeText(text)
        app.note(saying: text).awaiting("the typed note")

        app.terminate()
        launchAsShipped(store: .onDisk)

        XCTAssertEqual(app.state, .runningForeground, "The store did not open on a relaunch")
        let note = app.note(saying: text).awaiting("the note after a relaunch")
        note.press(forDuration: 1.0)
        app.buttons["Delete"].awaiting("the Delete item").tap()
        note.awaitingDisappearance("the cleaned-up note")
    }

    func testTheListSaysTheVersionAndOffersSupportAndPrivacy() {
        launchAsShipped()
        app.surface.awaiting("the board")
        app.showBoards()

        let privacy = app.find(A11y.About.privacyLink)
        for _ in 0..<4 where !privacy.exists {
            app.collectionViews.firstMatch.swipeUp()
        }
        privacy.awaiting("the privacy policy")
        app.find(A11y.About.supportLink).awaiting("the way to reach a person")
        app.find(A11y.About.versionRow).awaiting("the version the reader is running")
    }

    /// Screens the other suites' audits can't reach in a Release build.
    func testEveryScreenPassesTheAccessibilityAudit() throws {
        // Clipping and Dynamic Type are `testNothingClipsAtTheLargestDynamicType`'s.
        let audited = XCUIAccessibilityAuditType.all.subtracting([.textClipped, .dynamicType])

        launchAsShipped()
        app.surface.awaiting("the board")
        try app.performAccessibilityAudit(for: audited)

        app.showBoards()
        try app.performAccessibilityAudit(for: audited)

        app.terminate()
        launchAsShipped(tour: .due)
        app.find(A11y.Tour.view).awaiting("the tour")
        try app.performAccessibilityAudit()
    }

    func testNothingClipsAtTheLargestDynamicType() throws {
        let largest = "UICTContentSizeCategoryAccessibilityXXXL"
        launchAsShipped(contentSize: largest)
        app.surface.awaiting("the board at the largest type size")
        try app.performAccessibilityAudit(for: [.textClipped, .dynamicType])

        app.showBoards()
        try app.performAccessibilityAudit(for: [.textClipped, .dynamicType]) { issue in
            // A row's `Label` wraps around its icon and is reported as clipped, but draws all of
            // its words at this size (seen on iOS 27, iPhone 17). Only these two rows: the board a
            // first launch makes, and Pro's.
            guard issue.auditType == .textClipped, let label = issue.element?.label else {
                return false
            }
            return label.hasPrefix("My Board") || label.hasPrefix("Sticky Notes Pro")
        }
    }

    /// The canvas's verbs are gestures, so this checks each has a control: `+` for the double tap,
    /// and the note's menu for a pinch or a drag onto the bin.
    func testEveryVerbIsReachableWithoutAGesture() {
        launchAsShipped()
        app.surface.awaiting("the board")
        XCTAssertEqual(app.notes.count, 0, "the board starts empty")

        app.buttons[A11y.Canvas.addButton].awaiting("the add button").tap()
        let text = "Verbs"
        app.typeText(text)
        let note = app.note(saying: text).awaiting("the note the button added")
        app.stopWriting()

        note.press(forDuration: 1.0)
        app.buttons["Delete"].awaiting("the Delete item").tap()
        note.awaitingDisappearance("the note the menu deleted")
    }
}
