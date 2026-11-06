import AccessibilityIdentifiers
import NoteModel
import SwiftUI

/// The Pro sheet a window is showing, and why. One per window, so the sheet comes up over the
/// window that asked; the list, the canvas, its notes and the menu bar all ask through it.
@Observable
final class ProOffer {
    /// Why the sheet is up. Nil while it isn't.
    var shown: Reason?

    /// A feature that ran out, or nothing when Pro was asked for from the list or the menu bar.
    ///
    /// The sheet is presented by this `item`: presented by a flag, with the reason in a second
    /// piece of state, it would be built from the body that ran before both were written.
    struct Reason: Identifiable {
        let feature: ProFeature?
        /// A color picked for a note, shown on the sheet and given to the note if Pro is bought
        /// there. Nothing is written before then.
        var trying: Trial?

        var id: String { feature?.rawValue ?? A11y.Pro.listReason }
    }

    struct Trial {
        let note: Note
        let color: NoteColor
    }

    /// Puts the sheet up for `feature`, or for Pro as a whole.
    func show(_ feature: ProFeature?) {
        shown = Reason(feature: feature)
    }

    /// Puts the sheet up for a color only Pro has, picked for `note`.
    func show(_ color: NoteColor, on note: Note) {
        shown = Reason(feature: .colors, trying: Trial(note: note, color: color))
    }
}

extension EnvironmentValues {
    /// The window's ``ProOffer``. Nil where nothing may be sold, like the tour's practice board,
    /// whose notes are nobody's and take every color.
    @Entry var proOffer: ProOffer? = nil
}

/// "Sticky Notes Pro…" after About in the app menu, on a Mac and in an iPad's menu bar. Puts the
/// sheet up in the window in front; gone once Pro is bought.
struct ProCommands: Commands {
    let pro: Pro

    @FocusedValue(ProOffer.self) private var offer

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            if !pro.isUnlocked {
                Button {
                    offer?.show(nil)
                } label: {
                    Text(
                        "Sticky Notes Pro…",
                        comment: "The app menu item that opens the Pro sheet.")
                }
                .disabled(offer == nil)
            }
        }
    }
}
