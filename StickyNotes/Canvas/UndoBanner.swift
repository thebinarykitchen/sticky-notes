import AccessibilityIdentifiers
import NoteModel
import SwiftUI

/// "Note deleted · Undo", for a few seconds after a delete. Shake, three-finger swipe and ⌘Z undo
/// it too; this is the way that doesn't need knowing about any of them.
struct UndoBanner: View {
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text("Note deleted", comment: "Shown briefly after a note is deleted.")
            Button(action: undo) {
                Text("Undo", comment: "Brings back the note just deleted.")
                    .bold()
            }
            .accessibilityIdentifier(A11y.Canvas.undoButton)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11y.Canvas.undoBanner)
    }
}

extension NoteStore.Action {
    /// What Undo and Redo call this action: "Undo Delete Note".
    var undoName: String {
        switch self {
        case .add:
            String(
                localized: "Add Note",
                comment: "Adds a note: the toolbar button, and what Undo and Redo call it.")
        case .addSeveral:
            String(
                localized: "Add Notes",
                comment:
                    "Makes and adds the notes: the button that does, and what Undo and Redo call it."
            )
        case .move:
            String(localized: "Move Note", comment: "What Undo and Redo call moving a note.")
        case .resize:
            String(localized: "Resize Note", comment: "What Undo and Redo call resizing a note.")
        case .recolor:
            String(
                localized: "Change Color",
                comment: "What Undo and Redo call changing a note's color.")
        case .delete:
            String(localized: "Delete Note", comment: "What Undo and Redo call deleting a note.")
        }
    }
}

#Preview {
    UndoBanner {}
        .padding()
}
