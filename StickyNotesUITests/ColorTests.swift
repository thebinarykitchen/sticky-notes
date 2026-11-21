import UITestSupport
import XCTest

final class ColorTests: AppTestCase {
    /// Menu items drop their identifiers, so the colors are matched by label. Picking one leaves
    /// the menu open, so it is closed and opened again to see the color kept.
    func testTheMenuChangesANotesColor() {
        launch(seeded: true)
        let note = app.note(saying: "Buy oat milk").awaiting("a seeded note")

        XCTAssertTrue(note.openMenu(showing: app.buttons["Yellow"], "the colors").isSelected)
        app.buttons["Pink"].tap()

        app.surface.point(0.5, 0.05).tap()
        app.buttons["Delete"].awaitingDisappearance("the menu")

        XCTAssertTrue(note.openMenu(showing: app.buttons["Pink"], "the colors again").isSelected)
        XCTAssertFalse(app.buttons["Yellow"].isSelected)
    }
}
