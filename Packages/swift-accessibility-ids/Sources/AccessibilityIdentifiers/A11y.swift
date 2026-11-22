/// Accessibility identifiers shared by the app, which attaches them, and the UI tests, which
/// query them, so a rename is a compile error.
///
/// ## Naming convention
/// A lowercase feature prefix and a camelCase leaf, mirroring the Swift path:
/// `A11y.Canvas.addButton` is `"canvas.addButton"`.
///
/// Identify elements whose label varies or is app copy. Standard chrome with a fixed label is
/// found by label.
public enum A11y {

    /// The list of boards: the sidebar on iPad and Mac, the first screen back on iPhone.
    public enum Boards {
        /// The toolbar `+` that starts a new board.
        public static let addButton = "boards.addButton"
        /// A note found by searching, listed in place of the boards. Every result carries this
        /// one identifier; they are told apart by their text.
        public static let searchResult = "boards.searchResult"
        /// The toolbar button that puts the tour back up.
        public static let tourButton = "boards.tourButton"
        /// A board's name in the list. Every row carries this one identifier; they are told
        /// apart by their label, the board's name, which an iPad's open board shows as its title too.
        public static let row = "boards.row"
    }

    /// The bottom of the list of boards: what App Review looks for.
    public enum About {
        /// The app's version and build.
        public static let versionRow = "about.versionRow"
        /// Opens the support page.
        public static let supportLink = "about.supportLink"
        /// Opens the privacy policy.
        public static let privacyLink = "about.privacyLink"
    }

    /// The board the notes sit on.
    public enum Canvas {
        /// The canvas as it is on screen, below the bars: what positions on it are measured by.
        public static let surface = "canvas.surface"
        /// The toolbar `+`, the non-gesture way to add a note.
        public static let addButton = "canvas.addButton"
        /// The toolbar's Make Notes, there only where the on-device model can run.
        public static let makeNotesButton = "canvas.makeNotesButton"
        /// The toolbar's Show All Notes, which opens the overview.
        public static let overviewButton = "canvas.overviewButton"
        /// "Double-tap anywhere to add a note", shown while there are none.
        public static let emptyState = "canvas.emptyState"
        /// "Show Me How", under the empty state: puts the tour back up.
        public static let tourButton = "canvas.tourButton"
        /// "Note deleted", shown for a few seconds after a delete.
        public static let undoBanner = "canvas.undoBanner"
        /// The banner's Undo, which brings the note back.
        public static let undoButton = "canvas.undoButton"
        /// A gesture the reader hasn't done yet — the tour skipped, or pressed through — named at
        /// the foot of a board with notes enough to do it on.
        public static let lessonHint = "canvas.lessonHint"
        /// The hint's close button: the gesture counts as known.
        public static let lessonHintDismiss = "canvas.lessonHintDismiss"
        /// The blur over the board while a note is written on in the middle of it. A tap on it
        /// ends the writing.
        public static let blur = "canvas.blur"
    }

    /// The sheet that shows every note on a board at once.
    public enum Overview {
        /// A note in it. Every one carries this one identifier; they are told apart by their
        /// label, which is their text.
        public static let note = "overview.note"
    }

    /// The sheet Make Notes opens, which makes notes of what is written in it.
    public enum MakeNotes {
        /// What the notes are made from.
        public static let text = "makeNotes.text"
        /// Add Notes, which makes them.
        public static let addButton = "makeNotes.addButton"
    }

    /// A sticky note.
    public enum Note {
        /// Every note carries this one identifier. Notes are told apart by their text, or by
        /// position — never by z-order, which a drag changes.
        public static let card = "note.card"
        /// The note's text field.
        public static let text = "note.text"
    }

    /// The tour: a welcome page and a page per gesture, each with a board to practise on.
    public enum Tour {
        /// The tour, on whichever page.
        public static let view = "tour.view"
        public static let pagePrefix = "tour.page."
        /// A page, keyed by `Lesson.rawValue` or ``welcomePage``.
        public static func page(_ name: String) -> String { pagePrefix + name }
        public static let welcomePage = "welcome"
        /// `Lesson.allCases` raw values in order, for the UI tests. `OnboardingTests` checks they
        /// match.
        public static let lessonPages = [
            "doubleTapToAdd", "pinchToResize", "dragToBin", "pinchToCrumple",
        ]

        /// The line under the title: how to do the gesture, and once it is done, what else to
        /// know about it.
        public static let instruction = "tour.instruction"
        /// The board a lesson page practises on. Its notes carry ``Note/card``, as any note does.
        public static let practiceBoard = "tour.practiceBoard"
        /// Start, Next or Get Started, by page; never disabled.
        public static let advanceButton = "tour.advanceButton"
        /// Skip, on every page.
        public static let skipButton = "tour.skipButton"
    }

    /// The Pro sheet and the ways to it.
    public enum Pro {
        /// The sheet. Apply `.accessibilityElement(children: .contain)` before this identifier,
        /// or the container hides its children.
        public static let sheet = "pro.sheet"
        /// The purchase button. Its label includes the localized price.
        public static let buyButton = "pro.buyButton"
        /// Retries loading the product, shown in place of ``buyButton``.
        public static let retryButton = "pro.retryButton"
        /// "Restore Purchases". Its label is replaced by a spinner while restoring.
        public static let restoreButton = "pro.restoreButton"
        /// What the last purchase or restore came to, shown under ``restoreButton``.
        public static let message = "pro.message"
        /// The row under the boards showing Pro's price or that it is unlocked.
        public static let listRow = "pro.listRow"

        public static let reasonPrefix = "pro.reason."
        /// Why the sheet is up, keyed by `ProFeature.rawValue` or ``listReason``.
        public static func reason(_ feature: String) -> String { reasonPrefix + feature }
        /// `ProFeature` raw values, for the UI tests. `ProTests` checks they match.
        public static let features = ["makeNotes", "boards", "colors"]
        /// The reason when nothing ran out: the sheet was opened from the list of boards or the
        /// menu bar.
        public static let listReason = "boardList"
    }
}
