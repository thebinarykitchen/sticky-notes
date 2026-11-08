import AccessibilityIdentifiers
import UITestSupport
import XCTest

/// Validates the `Shot` list; duplicate numbers would silently overwrite each other.
@MainActor
final class ShotListTests: XCTestCase {
    func testTheListIsHonest() {
        XCTAssertEqual(Shot.listingProblems, [])
    }

    func testEveryLessonHasAShot() {
        XCTAssertEqual(
            Shot.lessons.count, A11y.Tour.lessonPages.count, "A lesson with no shot for its page")
        XCTAssertTrue(Shot.lessons.allSatisfy { !$0.isInTheListing })
    }
}
