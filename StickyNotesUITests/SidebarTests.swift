import XCTest

/// On an iPad in landscape the list of boards stands beside the canvas, and the board runs under
/// it as it runs under the toolbar: the sidebar is a leading inset of the canvas. What the canvas
/// places by its frame belongs beside the sidebar, not under it. Skipped where nothing stands
/// beside the canvas, as on an iPhone.
final class SidebarTests: AppTestCase {
    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
        try await super.tearDown()
    }

    /// Board (0, 0) is the top-left of the part the sidebar leaves uncovered.
    func testABoardOpensBesideTheSidebar() throws {
        try launchBesideTheSidebar(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")
        let canvas = app.surface.frame
        // Where `SampleData` puts it.
        XCTAssertEqual(note.frame.midX - canvas.minX, 100, accuracy: 1)
        XCTAssertEqual(note.frame.midY - canvas.minY, 180, accuracy: 1)
    }

    /// A new note is kept wholly in view, so one added at the sidebar's edge lands beside it.
    func testADoubleTapAtTheSidebarsEdgeAddsANoteBesideIt() throws {
        try launchBesideTheSidebar()
        // Read before tapping: the keyboard shortens the canvas as the new note takes focus.
        let canvas = app.surface.frame

        app.surface.point(0, 0.5).withOffset(CGVector(dx: 10, dy: 0)).doubleTap()
        app.typeText("At the sidebar's edge")
        // Written on in the middle until that ends.
        app.stopWriting()

        let note = app.note(saying: "At the sidebar's edge").awaiting("the new note")
        XCTAssertEqual(note.frame.minX, canvas.minX, accuracy: 1, "the note at \(note.frame)")
    }

    /// Landscape, where an iPad's list of boards stands beside the canvas.
    private func launchBesideTheSidebar(seeded: Bool = false) throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch(seeded: seeded)
        try XCTSkipUnless(app.addBoardButton.isHittable, "Nothing stands beside the canvas")
    }
}
