import AccessibilityIdentifiers
import NoteModel
import SwiftData
import SwiftUI

/// One sticky note, positioned on the canvas.
///
/// Its words never take touches: a touch lands on the note itself, so a drag anywhere on it
/// moves it, a pinch resizes it and a tap starts writing on it — in the middle of the canvas,
/// where ``EditedNote`` draws it while this one waits hidden. Dragged onto the bin or pinched until it crumples, it is deleted. Resizing and deleting are
/// also in its menu and its accessibility actions, and moving in its accessibility actions, for
/// anyone a gesture doesn't suit. Its color is changed in either.
struct NoteView: View {
    let note: Note
    let canvas: CanvasBounds
    /// The note being written on, in the middle of the canvas. A tap on this one makes it this.
    var editing: Binding<UUID?>
    /// The note VoiceOver is on, which the canvas moves to one a search reveals.
    var spoken: AccessibilityFocusState<UUID?>.Binding

    @Environment(NoteStore.self) private var store
    @Environment(Pro.self) private var pro
    /// Where a color only Pro has asks for it. Nil on the tour's practice board.
    @Environment(\.proOffer) private var offer
    @Environment(\.motion) private var motion
    @Environment(\.layoutDirection) private var layoutDirection

    private var isEditing: Bool { editing.wrappedValue == note.id }

    /// What the menu's colors choose between, written through ``choose(_:)``. Not a key path,
    /// since a color only Pro has may not be written at all.
    private var color: Binding<NoteColor> {
        Binding {
            note.color
        } set: {
            choose($0)
        }
    }

    var body: some View {
        PinchToResize(note: note, onCrumple: delete) { side in
            card(side: side)
        }
        .contextMenu {
            Button(action: grow) {
                Label {
                    Text("Make Bigger", comment: "Makes a note one step larger.")
                } icon: {
                    Image(systemName: "plus.magnifyingglass")
                }
            }
            .disabled(!canGrow)
            Button(action: shrink) {
                Label {
                    Text("Make Smaller", comment: "Makes a note one step smaller.")
                } icon: {
                    Image(systemName: "minus.magnifyingglass")
                }
            }
            .disabled(!canShrink)
            Picker(selection: color) {
                ForEach(NoteColor.allCases, id: \.self) { option in
                    Label {
                        Text(option.name)
                    } icon: {
                        // A square, like the note: on a light menu the system frames a pale
                        // swatch, and the frame is square whatever the symbol.
                        Image(systemName: "square.fill")
                    }
                    .tint(option.fill)
                }
            } label: {
                Text("Color", comment: "Labels the colors in a note's menu.")
            }
            .pickerStyle(.palette)
            Button(role: .destructive, action: delete) {
                Label {
                    Text("Delete", comment: "Removes a note.")
                } icon: {
                    Image(systemName: "trash")
                }
            }
        }
        .dragToMove(note, in: canvas, onTrash: delete)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(note.color.accessibilityName))
        .accessibilityIdentifier(A11y.Note.card)
        .accessibilityAction(named: Text("Make Bigger", comment: "Makes a note one step larger.")) {
            if canGrow { grow() }
        }
        .accessibilityAction(
            named: Text("Make Smaller", comment: "Makes a note one step smaller.")
        ) {
            if canShrink { shrink() }
        }
        .accessibilityAction(named: Text("Move Up", comment: "Moves a note up by its height.")) {
            move(x: 0, y: -1)
        }
        .accessibilityAction(named: Text("Move Down", comment: "Moves a note down by its height."))
        {
            move(x: 0, y: 1)
        }
        .accessibilityAction(named: Text("Move Left", comment: "Moves a note left by its width.")) {
            move(x: -1, y: 0)
        }
        .accessibilityAction(
            named: Text("Move Right", comment: "Moves a note right by its width.")
        ) {
            move(x: 1, y: 0)
        }
        .accessibilityActions {
            ForEach(otherColors, id: \.self) { other in
                Button(other.accessibilityActionName) { choose(other) }
            }
        }
        .accessibilityAction(named: Text("Delete", comment: "Removes a note.")) { delete() }
        // Written on in the middle of the canvas, where `EditedNote` is the note — to VoiceOver
        // too.
        .opacity(isEditing ? 0 : 1)
        .accessibilityHidden(isEditing)
        // Not `position`, which makes the view as big as the canvas: the note would arrive and
        // leave scaling about the canvas's centre, sliding in and out rather than growing in place.
        .layoutValue(key: NoteCenter.self, value: note.center)
    }

    private func card(side: Double) -> some View {
        // Through the store, which holds what is typed until typing pauses.
        Self.words(store.text(of: note))
            // The words, since VoiceOver lands inside the card rather than on it.
            .accessibilityFocused(spoken, equals: note.id)
            // Activated, it is written on, as a tap does.
            .accessibilityAction { editing.wrappedValue = note.id }
            .allowsHitTesting(false)
            .accessibilityIdentifier(A11y.Note.text)
            .notePaper(side: side, color: note.color)
            .contentShape(.rect)
            .onTapGesture { editing.wrappedValue = note.id }
    }

    /// The words on a note at rest, and on the stand-in of a held note: text, not a text field.
    /// Only the note being written on has one, ``EditedNote``'s; a field on every note took
    /// three-fifths of a 300-note board's launch and two-fifths of its memory (measured on
    /// iOS 27). To VoiceOver and the UI tests it reads as that field does: "Note text", the words
    /// its value. Where they don't fit, at the largest text sizes, they end in an ellipsis.
    static func words(_ text: String) -> some View {
        (text.isEmpty
            ? Text("Write something…", comment: "Placeholder on an empty note.")
            : Text(verbatim: text))
            .foregroundStyle(text.isEmpty ? NoteStyle.placeholder : NoteStyle.ink)
            // The words written on it change as the note goes back from the middle, inside that
            // animation; animated, the text was redrawn on every frame of it.
            .contentTransition(.identity)
            .accessibilityLabel(
                Text("Note text", comment: "VoiceOver label for a note's text field.")
            )
            .accessibilityValue(text)
    }

    private var canGrow: Bool { note.side < NoteGeometry.maxSide }
    private var canShrink: Bool { note.side > NoteGeometry.minSide }

    /// The colors its accessibility actions offer: every one it isn't.
    private var otherColors: [NoteColor] { NoteColor.allCases.filter { $0 != note.color } }

    /// A whole side at a time, so a note moved beside another of its size lands edge to edge. Put
    /// down as a drag leaves it: on top, and undoable. Left and right are as seen: a right-to-left
    /// layout mirrors the board.
    private func move(x: Double, y: Double) {
        let x = layoutDirection == .rightToLeft ? -x : x
        let to = CGPoint(x: note.x + x * note.side, y: note.y + y * note.side)
        withAnimation(motion.edit) { store.drop(note, at: to) }
    }

    private func grow() {
        withAnimation(motion.edit) {
            store.resize(note, to: note.side + NoteGeometry.step)
        }
    }

    private func shrink() {
        withAnimation(motion.edit) {
            store.resize(note, to: note.side - NoteGeometry.step)
        }
    }

    /// Makes the note `color`, or, for a color only Pro has while Pro is locked, offers Pro with
    /// the color shown on this note — the gate is here rather than in the store, which knows
    /// nothing about Pro.
    private func choose(_ color: NoteColor) {
        if let offer, !pro.allows(color) {
            offer.show(color, on: note)
        } else {
            store.recolor(note, to: color)
        }
    }

    private func delete() {
        if isEditing { editing.wrappedValue = nil }
        withAnimation(motion.edit) { store.delete(note) }
    }
}

extension NoteStore {
    /// `note`'s text as typed, written through ``NoteStore/setText(_:of:)``: what its text field
    /// binds to.
    subscript(textOf note: Note) -> String {
        get { text(of: note) }
        set { setText(newValue, of: note) }
    }
}

extension View {
    /// The paper under a note's words: `side` points square, in `color`.
    func notePaper(side: Double, color: NoteColor) -> some View {
        padding(NoteStyle.padding)
            .frame(width: side, height: side, alignment: .topLeading)
            .background(color.fill, in: .rect(cornerRadius: NoteStyle.cornerRadius))
    }
}

#Preview {
    @Previewable @State var editing: UUID?
    @Previewable @AccessibilityFocusState var spoken: UUID?
    let container = PreviewNotes.container()
    let note = Note(center: CGPoint(x: 120, y: 120), color: .yellow, z: 0, text: "Buy oat milk")
    container.mainContext.insert(note)
    let canvas = CanvasBounds(size: CGSize(width: 240, height: 240))
    return NoteView(note: note, canvas: canvas, editing: $editing, spoken: $spoken)
        .frame(width: 240, height: 240)
        .environment(NoteStore(context: container.mainContext))
        .environment(Pro())
        .environment(NoteDrag())
        .environment(CanvasScroll())
        .modelContainer(container)
}
