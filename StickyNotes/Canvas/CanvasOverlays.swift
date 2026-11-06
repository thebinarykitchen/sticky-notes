import AccessibilityIdentifiers
import NoteModel
import SwiftUI

/// What a board draws above its notes, and the state that brings it: the note a finger is holding
/// and the bin it can go into, the offer to undo a delete, and the note being written on, in the
/// middle, with the rest of the board blurred behind it. ``CanvasView`` applies it, and so does the
/// tour's practice board, so practising a gesture is the gesture.
///
/// Brings `drag` and `scroll` into the environment, for the notes' gestures to read.
struct CanvasOverlays: ViewModifier {
    let board: Board
    let notes: [Note]
    let drag: NoteDrag
    let scroll: CanvasScroll
    /// The canvas's size.
    let size: CGSize
    /// The note being written on, which ``EditedNote`` draws in the middle. Set ahead of the focus,
    /// which only goes to a text field that is already there: the middle note's is there once
    /// this is set.
    @Binding var editing: UUID?

    @Environment(NoteStore.self) private var store
    @Environment(\.motion) private var motion
    @FocusState private var focus: UUID?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let held = drag.held {
                    HeldNote(note: held)
                        // Gone at once when put down, as the note comes back in its place; into the
                        // bin, or crumpled, it goes as a delete does.
                        .transition(
                            drag.isOverTrash || drag.isCrumpled ? motion.arrival : .identity)
                }
            }
            // An overlay, so it stays above the note being dragged.
            .overlay {
                if drag.isActive {
                    TrashZone(isHot: drag.isOverTrash, canvas: size)
                        .transition(.opacity)
                }
            }
            .animation(motion.lift, value: drag.isActive)
            .overlay(alignment: .bottom) {
                if let deletion = store.lastDeletion, deletion.boardID == board.id, store.canUndo {
                    UndoBanner { store.undo() }
                        .padding(.bottom, 24)
                        .transition(motion.banner)
                        .task(id: deletion) {
                            try? await Task.sleep(for: CanvasView.undoOffer)
                            store.forget(deletion)
                        }
                }
            }
            .animation(motion.edit, value: store.lastDeletion)
            // Above everything else: the rest of the board, blurred, and the note being written on.
            .overlay {
                if edited != nil {
                    blur.transition(.opacity)
                }
            }
            .overlay {
                if let edited {
                    let place = scroll.canvasPoint(fromBoard: edited.center)
                    EditedNote(note: edited, focus: $focus, canvas: size)
                        // From its place on the board, at its own size, and back.
                        .transition(
                            motion.toTheMiddle(
                                from: CGSize(
                                    width: place.x - size.width / 2,
                                    height: place.y - size.height / 2),
                                scale: edited.side / EditedNote.side(edited.side, in: size)))
                }
            }
            // On the note found, so it animates whichever comes last as a note is added: its id
            // here, or the note itself in `notes`.
            .animation(motion.writing, value: edited?.id)
            .sensoryFeedback(.impact, trigger: store.lastDeletion) { _, deletion in
                deletion != nil
            }
            .environment(drag)
            .environment(scroll)
            // Its text field is there now, in the middle.
            .onChange(of: editing) { focus = editing }
            // Typing saves once it pauses; ending the edit, or moving to another note, saves it
            // now. However the keyboard went — the blur tapped, its own key — the writing ends with
            // it.
            .onChange(of: focus) {
                store.saveText()
                if focus == nil { editing = nil }
            }
            // A held note crumpled away takes its gesture with it, so nothing else ends the drag.
            .onChange(of: notes) {
                if let held = drag.held, !notes.contains(held) { drag.end() }
            }
    }

    /// The note being written on, which ``EditedNote`` draws in the middle of the canvas.
    private var edited: Note? {
        guard let editing else { return nil }
        return notes.first { $0.id == editing }
    }

    /// The rest of the board while a note is written on, out of focus — under the bars and the
    /// keyboard too. A tap on it, anywhere, ends the writing.
    private var blur: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
            .onTapGesture { editing = nil }
            .accessibilityElement()
            .accessibilityLabel(
                Text(
                    "Done",
                    comment: "Ends writing on a note: what VoiceOver calls the blur over the board."
                )
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { editing = nil }
            .accessibilityIdentifier(A11y.Canvas.blur)
    }
}
