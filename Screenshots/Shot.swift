import UITestSupport

/// An App Store screenshot. The raw value is its listing position and file-name prefix. Up to
/// ``lastInTheListing`` they are the listing; higher numbers are alternates.
enum Shot: Int, CaseIterable, ListingShot {
    case theBoard = 1
    case writingOnANote
    case makingNotes
    case notesMade
    case aNotesColors
    case everyBoard
    case search

    case tourWelcome
    case doubleTapToAdd
    case tapToWrite
    case dragToMove
    case pinchToResize
    case holdForMenu
    case dragToBin
    case pinchToCrumple
    case unlockingPro

    /// The last shot the listing itself uses. Everything past it is an alternate.
    static let lastInTheListing = Shot.search

    /// The tour's lesson pages, in `A11y.Tour.lessonPages` order.
    static let lessons: [Shot] = [
        .doubleTapToAdd, .tapToWrite, .dragToMove, .pinchToResize, .holdForMenu, .dragToBin,
        .pinchToCrumple,
    ]

    /// Written out rather than derived from the case name, so renames don't change file names.
    var slug: String {
        switch self {
        case .theBoard: "the-board"
        case .writingOnANote: "writing-on-a-note"
        case .makingNotes: "making-notes"
        case .notesMade: "notes-made"
        case .aNotesColors: "a-notes-colors"
        case .everyBoard: "every-board"
        case .search: "search"
        case .tourWelcome: "tour-welcome"
        case .doubleTapToAdd: "double-tap-to-add"
        case .tapToWrite: "tap-to-write"
        case .dragToMove: "drag-to-move"
        case .pinchToResize: "pinch-to-resize"
        case .holdForMenu: "hold-for-menu"
        case .dragToBin: "drag-to-bin"
        case .pinchToCrumple: "pinch-to-crumple"
        case .unlockingPro: "unlocking-pro"
        }
    }
}
