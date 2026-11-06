import Foundation

/// What Pro covers, with what each is worth free and its Pro sheet copy.
nonisolated enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    /// Make Notes, ``NoteWriter``. Free uses refill every calendar month.
    case makeNotes
    /// More boards than ``freeBoards``. Counted as they stand, never spent: deleting one frees
    /// its place.
    case boards
    /// The colors a note is never handed, beyond `NoteColor.handedOut`. Pro only.
    case colors

    var id: String { rawValue }

    /// The features whose free uses are spent and come back on the 1st.
    static let monthly: [ProFeature] = [.makeNotes]

    /// Make Notes runs free per calendar month. Keep ``explanation`` in step.
    static let freeMakeNotes = 10

    /// Boards free at once. Keep ``explanation`` in step.
    static let freeBoards = 3

    /// The sheet's headline, a whole line per case for translation. Says what Pro adds, so
    /// ``explanation`` doesn't have to.
    var headline: LocalizedStringResource {
        switch self {
        case .makeNotes:
            LocalizedStringResource(
                "Unlimited Make Notes with Pro",
                comment: "The Pro sheet's title once this month's free Make Notes are used.")
        case .boards:
            LocalizedStringResource(
                "Unlimited Boards with Pro",
                comment:
                    "The Pro sheet's title when New Board is tapped with every free board used.")
        case .colors:
            LocalizedStringResource(
                "More Colors with Pro",
                comment: "The Pro sheet's title when a color only Pro has is picked for a note.")
        }
    }

    /// What is used, and what comes back. Keep the numbers in step with ``freeMakeNotes`` and
    /// ``freeBoards``; `ProTests` checks them.
    var explanation: LocalizedStringResource {
        switch self {
        case .makeNotes:
            LocalizedStringResource(
                "You've made notes ten times this month. You'll get ten more next month.",
                comment: "Under the Pro sheet's title once this month's free Make Notes are used.")
        case .boards:
            LocalizedStringResource(
                "Three boards are free. Pro lets you make as many as you like.",
                comment: "Under the Pro sheet's title when every free board is used.")
        case .colors:
            LocalizedStringResource(
                "Yellow, pink, blue and green are always free. Pro adds four more.",
                comment: "Under the Pro sheet's title when a color only Pro has is picked.")
        }
    }

    /// The symbol on the feature's card in the Pro sheet.
    var symbol: String {
        switch self {
        // The toolbar's own, which Make Notes is found by.
        case .makeNotes: "sparkles"
        case .boards: "square.stack"
        case .colors: "paintpalette"
        }
    }

    /// What is free, under the feature's card on the sheet. The counts come from the constants
    /// rather than being spelled out, so the two can't drift.
    var allowance: LocalizedStringResource {
        switch self {
        case .makeNotes:
            LocalizedStringResource(
                "\(Self.freeMakeNotes) free every month",
                comment: "Under Make Notes on the Pro sheet. The number is the free uses.")
        case .boards:
            LocalizedStringResource(
                "\(Self.freeBoards) boards free",
                comment: "Under the boards offer on the Pro sheet. The number is the free boards.")
        case .colors:
            LocalizedStringResource(
                "Four colors are always free",
                comment: "Under the colors offer on the Pro sheet.")
        }
    }

    /// Replaces ``allowance`` on the card for the feature that brought the sheet up — the one
    /// thing on the sheet the reader has just met.
    var exhausted: LocalizedStringResource {
        switch self {
        case .makeNotes:
            LocalizedStringResource(
                "None left until the 1st",
                comment: "Under Make Notes on the Pro sheet once this month's free uses are gone.")
        case .boards:
            LocalizedStringResource(
                "Every free board is in use",
                comment: "Under the boards offer on the Pro sheet when every free board is used.")
        case .colors:
            LocalizedStringResource(
                "Only with Pro",
                comment: "Under the colors offer on the Pro sheet when one of them was picked.")
        }
    }

    /// A short phrase for the sheet's list of what Pro adds.
    var offer: LocalizedStringResource {
        switch self {
        case .makeNotes:
            LocalizedStringResource(
                "Make notes from lists and topics",
                comment: "What Pro adds, on the Pro sheet: Make Notes without a monthly limit.")
        case .boards:
            LocalizedStringResource(
                "Make as many boards as you like",
                comment: "What Pro adds, on the Pro sheet: boards without a limit.")
        case .colors:
            LocalizedStringResource(
                "Orange, purple, teal and gray notes",
                comment: "What Pro adds, on the Pro sheet: the four colors only Pro has.")
        }
    }

    /// Whether another use is allowed after `used` this month. Pure, for testing.
    static func allowsMakeNotes(used: Int) -> Bool {
        used < freeMakeNotes
    }

    /// Whether another board is allowed beside `count`. Pure, for testing.
    static func allowsAnotherBoard(having count: Int) -> Bool {
        count < freeBoards
    }
}
