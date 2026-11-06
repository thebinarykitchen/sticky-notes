import AccessibilityIdentifiers
import XCTest

/// Validates the `Shot` list; duplicate numbers would silently overwrite each other.
@MainActor
final class ShotListTests: XCTestCase {
    func testEveryShotHasItsOwnPlaceInTheListing() {
        let names = Set(Shot.allCases.map(\.fileName))
        XCTAssertEqual(names.count, Shot.allCases.count, "Two shots share a file name")

        let numbers = Shot.allCases.map(\.rawValue).sorted()
        XCTAssertEqual(numbers, Array(1...Shot.allCases.count), "The numbering has a gap in it")
    }

    func testTheListingFitsInWhatTheStoreTakes() {
        let listing = Shot.allCases.filter(\.isInTheListing)
        XCTAssertLessThanOrEqual(listing.count, 10, "More listing shots than the store takes")
        XCTAssertEqual(
            listing.map(\.rawValue), Array(1...listing.count),
            "The listing has to be the first run of them, or the numbers stop meaning the order")
    }

    func testEveryLessonHasAShot() {
        XCTAssertEqual(
            Shot.lessons.count, A11y.Tour.lessonPages.count, "A lesson with no shot for its page")
        XCTAssertTrue(Shot.lessons.allSatisfy { !$0.isInTheListing })
    }
}
