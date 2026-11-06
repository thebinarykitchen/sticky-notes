import NoteModel
import SwiftUI

/// A gesture the tour teaches: its words, the notes its practice board starts with, and what its
/// demonstration does to them. Cases are in teaching order.
nonisolated enum Lesson: String, CaseIterable, Identifiable, Sendable {
    case doubleTapToAdd
    case tapToWrite
    case dragToMove
    case pinchToResize
    case holdForMenu
    case dragToBin
    case pinchToCrumple

    var id: Self { self }

    // MARK: - Words

    var title: LocalizedStringResource { title(for: .current) }
    var instruction: LocalizedStringResource { instruction(for: .current) }
    var afterword: LocalizedStringResource { afterword(for: .current) }

    func title(for pointing: Pointing) -> LocalizedStringResource {
        switch (self, pointing) {
        case (.doubleTapToAdd, .touch):
            LocalizedStringResource(
                "Double-Tap to Add", comment: "Title of the tour page on adding a note.")
        case (.doubleTapToAdd, .pointer):
            LocalizedStringResource(
                "Double-Click to Add", comment: "Title of the tour page on adding a note, on a Mac."
            )
        case (.tapToWrite, .touch):
            LocalizedStringResource(
                "Tap to Write", comment: "Title of the tour page on writing on a note.")
        case (.tapToWrite, .pointer):
            LocalizedStringResource(
                "Click to Write", comment: "Title of the tour page on writing on a note, on a Mac.")
        case (.dragToMove, _):
            LocalizedStringResource(
                "Drag to Move", comment: "Title of the tour page on moving a note.")
        case (.pinchToResize, _):
            LocalizedStringResource(
                "Pinch to Resize", comment: "Title of the tour page on resizing a note.")
        case (.holdForMenu, .touch):
            LocalizedStringResource(
                "Touch and Hold for the Menu",
                comment: "Title of the tour page on a note's menu, which changes its color.")
        case (.holdForMenu, .pointer):
            LocalizedStringResource(
                "Control-Click for the Menu",
                comment:
                    "Title of the tour page on a note's menu, which changes its color, on a Mac.")
        case (.dragToBin, _):
            LocalizedStringResource(
                "Drag to the Bin",
                comment: "Title of the tour page on deleting a note by dragging it onto the bin.")
        case (.pinchToCrumple, _):
            LocalizedStringResource(
                "Pinch to Crumple",
                comment: "Title of the tour page on deleting a note by pinching it very small.")
        }
    }

    /// How to do the gesture, shown until it has been done.
    func instruction(for pointing: Pointing) -> LocalizedStringResource {
        switch (self, pointing) {
        case (.doubleTapToAdd, .touch):
            LocalizedStringResource(
                "Double-tap an empty spot on the board, and a note appears there.",
                comment: "How to add a note, on the tour.")
        case (.doubleTapToAdd, .pointer):
            LocalizedStringResource(
                "Double-click an empty spot on the board, and a note appears there.",
                comment: "How to add a note, on the tour, on a Mac.")
        case (.tapToWrite, .touch):
            LocalizedStringResource(
                "Tap a note to write on it.", comment: "How to write on a note, on the tour.")
        case (.tapToWrite, .pointer):
            LocalizedStringResource(
                "Click a note to write on it.",
                comment: "How to write on a note, on the tour, on a Mac.")
        case (.dragToMove, _):
            LocalizedStringResource(
                "Drag a note to move it somewhere else on the board.",
                comment: "How to move a note, on the tour.")
        case (.pinchToResize, .touch):
            LocalizedStringResource(
                """
                Pinch a note with two fingers. Spread them to make it bigger, or bring them \
                together to make it smaller.
                """,
                comment: "How to resize a note, on the tour.")
        case (.pinchToResize, .pointer):
            LocalizedStringResource(
                """
                Pinch a note on the trackpad. Spread your fingers to make it bigger, or bring them \
                together to make it smaller.
                """,
                comment: "How to resize a note, on the tour, on a Mac.")
        case (.holdForMenu, .touch):
            LocalizedStringResource(
                "Touch and hold a note, then pick a color for it.",
                comment: "How to open a note's menu and change its color, on the tour.")
        case (.holdForMenu, .pointer):
            LocalizedStringResource(
                "Control-click a note, then pick a color for it.",
                comment: "How to open a note's menu and change its color, on the tour, on a Mac.")
        case (.dragToBin, _):
            LocalizedStringResource(
                """
                Drag a note onto the bin that appears at the bottom, and let go once the bin turns \
                red.
                """,
                comment: "How to delete a note by dragging it onto the bin, on the tour.")
        case (.pinchToCrumple, .touch):
            LocalizedStringResource(
                "Pinch a note smaller, and keep going until it crumples. Then let go.",
                comment: "How to delete a note by pinching it, on the tour.")
        case (.pinchToCrumple, .pointer):
            LocalizedStringResource(
                """
                On the trackpad, pinch a note smaller and keep going until it crumples. Then let \
                go.
                """,
                comment: "How to delete a note by pinching it, on the tour, on a Mac.")
        }
    }

    /// What else there is to know about the gesture on a real board, shown once it has been done.
    func afterword(for pointing: Pointing) -> LocalizedStringResource {
        switch (self, pointing) {
        case (.doubleTapToAdd, .touch):
            LocalizedStringResource(
                """
                On your own boards, a new note opens for writing straight away. The + button adds \
                one in the middle of the screen, too.
                """,
                comment: "On the tour, once a note has been added.")
        case (.doubleTapToAdd, .pointer):
            LocalizedStringResource(
                """
                On your own boards, a new note opens for writing straight away. The + button adds \
                one in the middle of the window, too.
                """,
                comment: "On the tour, once a note has been added, on a Mac.")
        case (.tapToWrite, .touch):
            LocalizedStringResource(
                """
                The note comes to the middle while you write, and goes back when you tap anywhere \
                around it.
                """,
                comment: "On the tour, once a note has been opened for writing.")
        case (.tapToWrite, .pointer):
            LocalizedStringResource(
                """
                The note comes to the middle while you write, and goes back when you click \
                anywhere around it.
                """,
                comment: "On the tour, once a note has been opened for writing, on a Mac.")
        case (.dragToMove, .touch):
            LocalizedStringResource(
                """
                Boards have no edges: hold a note near the edge of the screen, and the board \
                scrolls along with it.
                """,
                comment: "On the tour, once a note has been moved.")
        case (.dragToMove, .pointer):
            LocalizedStringResource(
                """
                Boards have no edges: hold a note near the edge of the window, and the board \
                scrolls along with it.
                """,
                comment: "On the tour, once a note has been moved, on a Mac.")
        case (.pinchToResize, .touch):
            LocalizedStringResource(
                """
                The words reflow to fit. Make Bigger and Make Smaller in the note's menu do the \
                same, a step at a time.
                """,
                comment: "On the tour, once a note has been resized.")
        case (.pinchToResize, .pointer):
            LocalizedStringResource(
                """
                The words reflow to fit. With a mouse, Make Bigger and Make Smaller are in the \
                note's menu.
                """,
                comment: "On the tour, once a note has been resized, on a Mac.")
        case (.holdForMenu, _):
            LocalizedStringResource(
                """
                The menu also makes a note bigger or smaller, or deletes it. New notes take the \
                color after the last one.
                """,
                comment: "On the tour, once a note's color has been changed.")
        case (.dragToBin, _), (.pinchToCrumple, _):
            LocalizedStringResource(
                "Every delete offers Undo for a few seconds, so nothing goes by accident.",
                comment: "On the tour, once a note has been deleted.")
        }
    }

    // MARK: - The practice board

    /// A note a lesson's board starts with.
    nonisolated struct PracticeNote: Sendable {
        let text: LocalizedStringResource
        let color: NoteColor
        /// From the middle of the board, on a board of ``Lesson/roomy`` size.
        let offset: CGSize
        let side: Double
    }

    /// The board the layouts are written for. On a smaller one they draw in toward the middle.
    static let roomy = CGSize(width: 340, height: 440)

    /// How much a layout draws in on a board of `size`: not at all on a roomy one.
    static func fit(in size: CGSize) -> CGFloat {
        min(1, size.width / roomy.width, size.height / roomy.height)
    }

    /// `offset` from the middle of a board of `size`, drawn in as ``fit(in:)`` says.
    static func place(_ offset: CGSize, in size: CGSize) -> CGPoint {
        let fit = fit(in: size)
        return CGPoint(
            x: size.width / 2 + offset.width * fit, y: size.height / 2 + offset.height * fit)
    }

    /// The notes on the board, in the order they are stacked: the last on top. Clear of each
    /// other, clear of the bin, and clear of where the demonstration takes its note.
    var practice: [PracticeNote] {
        switch self {
        case .doubleTapToAdd:
            [
                PracticeNote(
                    text: LocalizedStringResource(
                        "Plan the picnic", comment: "A note on the tour's practice board."),
                    color: .yellow, offset: CGSize(width: 75, height: -110), side: 110),
                PracticeNote(
                    text: LocalizedStringResource(
                        "Pack a blanket", comment: "A note on the tour's practice board."),
                    color: .pink, offset: CGSize(width: 95, height: 20), side: 110),
            ]
        case .tapToWrite:
            [
                PracticeNote(
                    text: LocalizedStringResource(
                        "Groceries",
                        comment:
                            "A note on the tour's practice board; the tour writes a list under it."
                    ),
                    color: .yellow, offset: CGSize(width: -75, height: -60), side: 130),
                PracticeNote(
                    text: LocalizedStringResource(
                        "Call Grandma", comment: "A note on the tour's practice board."),
                    color: .green, offset: CGSize(width: 95, height: -40), side: 110),
            ]
        case .dragToMove:
            [
                PracticeNote(
                    text: LocalizedStringResource(
                        "Book the vet", comment: "A note on the tour's practice board."),
                    color: .blue, offset: CGSize(width: -80, height: -100), side: 120),
                PracticeNote(
                    text: LocalizedStringResource(
                        "Water the plants", comment: "A note on the tour's practice board."),
                    color: .green, offset: CGSize(width: 85, height: -30), side: 120),
            ]
        case .pinchToResize:
            [
                PracticeNote(
                    text: LocalizedStringResource(
                        "Ideas for the party", comment: "A note on the tour's practice board."),
                    color: .pink, offset: CGSize(width: -30, height: -80), side: 130),
                PracticeNote(
                    text: LocalizedStringResource(
                        "Ask Sam", comment: "A note on the tour's practice board."),
                    color: .blue, offset: CGSize(width: 120, height: 60), side: 100),
            ]
        case .holdForMenu:
            [
                PracticeNote(
                    text: LocalizedStringResource(
                        "Dentist on Tuesday", comment: "A note on the tour's practice board."),
                    color: .yellow, offset: CGSize(width: -60, height: -120), side: 120),
                PracticeNote(
                    text: LocalizedStringResource(
                        "Gym bag", comment: "A note on the tour's practice board."),
                    color: .green, offset: CGSize(width: 110, height: -40), side: 100),
            ]
        case .dragToBin:
            [
                PracticeNote(
                    text: LocalizedStringResource(
                        "Old shopping list", comment: "A note on the tour's practice board."),
                    color: .green, offset: CGSize(width: -75, height: -110), side: 120),
                PracticeNote(
                    text: LocalizedStringResource(
                        "Keep this one", comment: "A note on the tour's practice board."),
                    color: .yellow, offset: CGSize(width: 85, height: -40), side: 120),
            ]
        case .pinchToCrumple:
            [
                PracticeNote(
                    text: LocalizedStringResource(
                        "Done already", comment: "A note on the tour's practice board."),
                    color: .blue, offset: CGSize(width: -20, height: -70), side: 130),
                PracticeNote(
                    text: LocalizedStringResource(
                        "Still to do", comment: "A note on the tour's practice board."),
                    color: .pink, offset: CGSize(width: 110, height: -10), side: 100),
            ]
        }
    }

    /// Which of ``practice`` the demonstration acts on. Nil for the double tap, which acts on the
    /// note it adds.
    var demonstrated: Int? {
        self == .doubleTapToAdd ? nil : 0
    }

    // MARK: - What the demonstration does

    /// Where the double tap lands, from the middle of the board: on nothing.
    static let spot = CGSize(width: -80, height: -40)

    /// What the note the double tap adds says, on the practice board and in its demonstration:
    /// there is no keyboard to write it with.
    static let added = LocalizedStringResource(
        "Bring lemonade", comment: "The note the tour's practice board adds on a double tap.")

    /// What the demonstration writes on its note, under what the note already says.
    static let written = LocalizedStringResource(
        "Apples, bread and milk",
        comment: "Written on the tour's practice note \"Groceries\", as the tour shows writing.")

    /// How far the demonstration drags its note to move it, on a roomy board: down, away from the
    /// other note, and short of the bin.
    static let travel = CGSize(width: 20, height: 160)

    /// The color the demonstration picks from the menu. Not the note's own.
    static let picked = NoteColor.pink

    /// How much the demonstration pinches its note: to resize it, out; to crumple it, in, until a
    /// note of its size crumples.
    static let spread = 1.45
    static let squeeze = 0.38
}
