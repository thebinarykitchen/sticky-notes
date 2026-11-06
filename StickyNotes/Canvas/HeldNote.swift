import NoteModel
import SwiftData
import SwiftUI

/// The note a finger is holding, drawn by the canvas above the scroll view while the note itself
/// waits hidden in the content — see ``DragToMove``.
///
/// Above the scroll view nothing the content does reaches it: not the board scrolling under the
/// finger, nor the content shifting as the board grows at the left or top. Inside the content it
/// flashed on such a shift: SwiftUI lays the shift out a pass before the scroll offset that
/// matches it, and a held note — alone — was drawn in between, gone or a whole shift away, for a
/// frame or more (seen on iOS 27).
struct HeldNote: View {
    let note: Note

    @Environment(NoteStore.self) private var store
    @Environment(NoteDrag.self) private var drag
    @State private var isRaised = false

    var body: some View {
        let asked = note.side * drag.magnification
        // Through the store, which holds what is typed until typing pauses.
        NoteView.words(store.text(of: note))
            .notePaper(side: NoteGeometry.clampSide(asked), color: note.color)
            .modifier(PinchLook(asked: asked))
            .modifier(HeldLook(isRaised: isRaised, isOverTrash: drag.isOverTrash))
            // What a finger holds is not animated.
            .position(
                x: drag.liftCenter.x + drag.translation.width,
                y: drag.liftCenter.y + drag.translation.height
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { isRaised = true }
    }
}

/// How a held note looks: raised off the board, and over the bin, smaller and faded on its way in.
/// The tour's demonstrations draw the note they hold with it too.
struct HeldLook: ViewModifier {
    let isRaised: Bool
    let isOverTrash: Bool

    @Environment(\.motion) private var motion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isOverTrash ? 0.6 : isRaised ? NoteStyle.liftedScale : 1)
            .opacity(isOverTrash ? 0.6 : 1)
            .shadow(
                color: .black.opacity(isRaised ? 0.25 : 0.18),
                radius: isRaised ? NoteStyle.liftedShadow : NoteStyle.shadow,
                y: isRaised ? 8 : 2
            )
            .animation(motion.lift, value: isRaised)
            .animation(motion.lift, value: isOverTrash)
    }
}

#Preview {
    let container = PreviewNotes.container()
    let note = Note(center: .zero, color: .pink, z: 0, text: "Call the dentist before Friday")
    container.mainContext.insert(note)
    let drag = NoteDrag()
    drag.lift(note, at: CGPoint(x: 140, y: 140))
    return HeldNote(note: note)
        .frame(width: 280, height: 280)
        .environment(drag)
        .previewNotes(container)
}
