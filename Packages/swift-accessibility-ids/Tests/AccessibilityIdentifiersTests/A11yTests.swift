import Testing

@testable import AccessibilityIdentifiers

struct A11yTests {
    private static let tour =
        [
            A11y.Tour.view, A11y.Tour.instruction, A11y.Tour.practiceBoard,
            A11y.Tour.advanceButton, A11y.Tour.skipButton, A11y.Tour.page(A11y.Tour.welcomePage),
        ] + A11y.Tour.lessonPages.map(A11y.Tour.page)

    private static let pro =
        [
            A11y.Pro.sheet, A11y.Pro.buyButton, A11y.Pro.retryButton, A11y.Pro.restoreButton,
            A11y.Pro.message, A11y.Pro.listRow, A11y.Pro.reason(A11y.Pro.listReason),
        ] + A11y.Pro.features.map(A11y.Pro.reason)

    @Test func identifiersAreDistinct() {
        let all =
            [
                A11y.Boards.addButton, A11y.Boards.searchResult, A11y.Boards.tourButton,
                A11y.Canvas.surface, A11y.Canvas.addButton, A11y.Canvas.makeNotesButton,
                A11y.Canvas.emptyState, A11y.Canvas.tourButton, A11y.Canvas.undoBanner,
                A11y.Canvas.undoButton, A11y.Canvas.blur, A11y.MakeNotes.text,
                A11y.MakeNotes.addButton, A11y.Note.card, A11y.Note.text,
            ] + Self.tour + Self.pro
        #expect(Set(all).count == all.count)
    }

    /// The string mirrors the Swift path, lowercase prefix first.
    @Test func identifiersCarryTheirFeaturePrefix() {
        for id in [
            A11y.Canvas.surface, A11y.Canvas.addButton, A11y.Canvas.makeNotesButton,
            A11y.Canvas.emptyState, A11y.Canvas.tourButton, A11y.Canvas.undoBanner,
            A11y.Canvas.undoButton, A11y.Canvas.blur,
        ] {
            #expect(id.hasPrefix("canvas."))
        }
        for id in [A11y.Boards.addButton, A11y.Boards.searchResult, A11y.Boards.tourButton] {
            #expect(id.hasPrefix("boards."))
        }
        for id in [A11y.MakeNotes.text, A11y.MakeNotes.addButton] {
            #expect(id.hasPrefix("makeNotes."))
        }
        for id in [A11y.Note.card, A11y.Note.text] {
            #expect(id.hasPrefix("note."))
        }
        for id in Self.tour {
            #expect(id.hasPrefix("tour."))
        }
        for id in Self.pro {
            #expect(id.hasPrefix("pro."))
        }
    }

    /// A page name is a key for ``A11y/Tour/page(_:)``, not an identifier of its own.
    @Test func everyPageHasItsOwnName() {
        let names = [A11y.Tour.welcomePage] + A11y.Tour.lessonPages
        #expect(Set(names).count == names.count)
        #expect(A11y.Tour.page("dragToBin") == "tour.page.dragToBin")
    }

    /// A reason is a key for ``A11y/Pro/reason(_:)``, and the sheet opened from the list must
    /// not read as a feature that ran out.
    @Test func everyProReasonHasItsOwnName() {
        let names = A11y.Pro.features + [A11y.Pro.listReason]
        #expect(Set(names).count == names.count)
        #expect(A11y.Pro.reason("boards") == "pro.reason.boards")
    }
}
