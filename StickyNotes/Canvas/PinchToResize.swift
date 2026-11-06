import NoteModel
import SwiftUI

/// Pinches a note bigger or smaller. While the fingers move, the note's frame itself changes —
/// so its text reflows rather than scaling up like a zoomed picture — held to the size limits;
/// the store is written once, when the pinch ends.
///
/// Pinched below the minimum, the note gives under the fingers instead of stopping dead, and
/// past ``NoteGeometry/crumpleSide`` it crumples: see ``PinchLook``. Letting go there deletes it;
/// easing back out first leaves it at the minimum.
///
/// A view rather than a modifier because the note has to be laid out at the live size, which
/// only this view knows: `content` is handed the side to draw at. A held note is drawn by its
/// stand-in, ``HeldNote``, which this tells the size too.
struct PinchToResize<Content: View>: View {
    let note: Note
    let onCrumple: () -> Void
    @ViewBuilder let content: (_ side: Double) -> Content

    @Environment(NoteStore.self) private var store
    @Environment(NoteDrag.self) private var drag
    @GestureState private var magnification: Double = 1

    /// The side the fingers are asking for, before any limit.
    private var asked: Double { note.side * magnification }

    var body: some View {
        content(NoteGeometry.clampSide(asked))
            .modifier(PinchLook(asked: asked))
            // Arms rather than commits: the note is still there to play it.
            .sensoryFeedback(.impact(weight: .light), trigger: NoteGeometry.crumples(asked)) {
                _, isCrumpled in isCrumpled
            }
            // Simultaneous, so a pinch that also travels moves the note as it resizes it.
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($magnification) { value, magnification, _ in
                        magnification = value.magnification
                    }
                    .onChanged { value in drag.pinch(note, by: value.magnification) }
                    .onEnded { value in
                        drag.pinch(note, by: 1)
                        let asked = note.side * value.magnification
                        if NoteGeometry.crumples(asked) {
                            onCrumple()
                        } else {
                            store.resize(note, to: asked)
                        }
                    }
            )
    }
}

/// How a note looks while a pinch asks for `asked` points: giving below the minimum, and past
/// ``NoteGeometry/crumpleSide`` crumpled — tilted, faded, with a bin on it.
struct PinchLook: ViewModifier {
    let asked: Double

    @Environment(\.motion) private var motion

    private var isCrumpled: Bool { NoteGeometry.crumples(asked) }

    /// How far the note visibly gives below the minimum. Bottoms out a little past the crumple,
    /// so a note never vanishes under the fingers.
    private var give: Double {
        guard asked < NoteGeometry.minSide else { return 1 }
        return max(asked, NoteGeometry.crumpleSide * 0.75) / NoteGeometry.minSide
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isCrumpled {
                    Image(systemName: "trash")
                        .font(.largeTitle)
                        .foregroundStyle(NoteStyle.ink.opacity(0.6))
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect(give)
            .rotationEffect(.degrees(isCrumpled ? -8 : 0))
            .opacity(isCrumpled ? 0.6 : 1)
            .animation(motion.lift, value: isCrumpled)
    }
}
