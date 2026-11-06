import AccessibilityIdentifiers
import NoteModel
import SwiftData
import SwiftUI

/// The note being written on, drawn by the canvas above the scroll view in the middle of what is
/// on screen — above the keyboard, which shortens the canvas — while the note itself waits hidden
/// in its place and the rest of the board is blurred behind it. When the writing ends, it goes
/// back.
///
/// Above the scroll view for the reason ``HeldNote`` is: the keyboard coming and going resizes
/// the canvas, and the content can shift under a note drawn inside it. Its text field is the only
/// one any note has — the rest are drawn as text, by ``NoteView/words(_:)`` — and it carries the
/// note's identifiers: to VoiceOver and the UI tests, it is the note.
struct EditedNote: View {
    /// How far it keeps from the canvas's edges, the keyboard's among them.
    nonisolated static let margin: Double = 16

    let note: Note
    var focus: FocusState<UUID?>.Binding
    /// The canvas's size, less the keyboard while that is up.
    let canvas: CGSize

    @Environment(NoteStore.self) private var store
    @Environment(\.motion) private var motion

    /// A key path rather than closures, so the binding compares equal from one body to the next
    /// and SwiftUI leaves the text field alone instead of rewriting and re-measuring it.
    private var text: Binding<String> {
        @Bindable var store = store
        return $store[textOf: note]
    }

    var body: some View {
        TextField(
            text: text,
            prompt: Text("Write something…", comment: "Placeholder on an empty note.")
                .foregroundStyle(NoteStyle.placeholder),
            axis: .vertical
        ) {
            Text("Note text", comment: "VoiceOver label for a note's text field.")
        }
        .textFieldStyle(.plain)
        .foregroundStyle(NoteStyle.ink)
        .focused(focus, equals: note.id)
        .accessibilityIdentifier(A11y.Note.text)
        .notePaper(side: Self.side(note.side, in: canvas), color: note.color)
        .shadow(color: .black.opacity(0.25), radius: NoteStyle.liftedShadow, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(note.color.accessibilityName))
        .accessibilityIdentifier(A11y.Note.card)
        // Placed, not aligned: on its way back nothing changes it any more, and the canvas's
        // top-left stays put as the keyboard goes, so the offset it leaves by ends on its place.
        .position(x: canvas.width / 2, y: canvas.height / 2)
        // Up as the keyboard comes.
        .animation(motion.writing, value: canvas)
    }

    /// The side it is drawn at: its own, or less where that wouldn't fit the canvas — but never
    /// less than a note can be made.
    nonisolated static func side(_ side: Double, in canvas: CGSize) -> Double {
        let room = Double(min(canvas.width, canvas.height)) - 2 * margin
        return max(min(side, room), NoteGeometry.minSide)
    }
}

#Preview {
    @Previewable @FocusState var focus: UUID?
    let container = PreviewNotes.container()
    let note = Note(center: .zero, color: .blue, z: 0, text: "Ideas for the weekend")
    container.mainContext.insert(note)
    return EditedNote(note: note, focus: $focus, canvas: CGSize(width: 320, height: 400))
        .frame(width: 320, height: 400)
        .previewNotes(container)
}
