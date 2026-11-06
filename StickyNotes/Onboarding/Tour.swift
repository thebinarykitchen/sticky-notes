import AccessibilityIdentifiers
import SwiftUI

/// A tour page: the welcome page, then one per lesson.
nonisolated enum TourPage: Hashable, Identifiable, Sendable {
    case welcome
    case lesson(Lesson)

    var id: Self { self }

    /// Every page, in order.
    static let all: [TourPage] = [.welcome] + Lesson.allCases.map(TourPage.lesson)

    var position: Int { Self.all.firstIndex(of: self) ?? 0 }

    /// The key for ``A11y/Tour/page(_:)``.
    var name: String {
        switch self {
        case .welcome: A11y.Tour.welcomePage
        case .lesson(let lesson): lesson.rawValue
        }
    }

    var next: TourPage? {
        let after = position + 1
        return Self.all.indices.contains(after) ? Self.all[after] : nil
    }

    var lesson: Lesson? {
        if case .lesson(let lesson) = self { return lesson }
        return nil
    }

    /// The advance button's title: Get Started on the last page. Whether the page's gesture has
    /// been done shows in the button's tint.
    var advanceTitle: LocalizedStringResource {
        switch self {
        case .welcome:
            LocalizedStringResource("Start", comment: "Starts the tour, on its welcome page.")
        case .lesson:
            next == nil
                ? LocalizedStringResource(
                    "Get Started", comment: "Ends the tour, on its last page.")
                : LocalizedStringResource("Next", comment: "Goes on to the tour's next page.")
        }
    }
}

/// The welcome page's words.
nonisolated enum TourCopy {
    /// Names the count, so it changes with the lessons. A whole string rather than a number put
    /// into one, for translation.
    static let welcomeTitle = LocalizedStringResource(
        "Seven Gestures",
        comment:
            "The title of the tour's welcome page: the tour has a page for each of seven gestures."
    )

    static var welcomeBody: LocalizedStringResource { welcomeBody(for: .current) }

    static func welcomeBody(for pointing: Pointing) -> LocalizedStringResource {
        switch pointing {
        case .touch:
            LocalizedStringResource(
                """
                Each board is a canvas with no edges, and you work on its notes with your \
                fingers. Nothing on screen points out how, so this quick tour shows you each \
                gesture.
                """,
                comment: "The tour's welcome page, its first paragraph.")
        case .pointer:
            LocalizedStringResource(
                """
                Each board is a canvas with no edges, and you work on its notes with the pointer \
                and the trackpad. Nothing on screen points out how, so this quick tour shows you \
                each one. With a mouse, Control-click a note for its menu.
                """,
                comment: "The tour's welcome page, its first paragraph, on a Mac.")
        }
    }

    /// A paragraph of its own: measured as one string, the blank line between the two had the
    /// accessibility audit find the words clipped.
    static let welcomePractice = LocalizedStringResource(
        "Every page has a board to practice on. Its notes aren't yours, so try anything.",
        comment: "The tour's welcome page, its second paragraph.")
}
