import AccessibilityIdentifiers
import NoteModel
import SwiftData
import SwiftUI

/// One board's notes, on a canvas that scrolls: the board has no edges. A double tap on an empty
/// spot adds a note there; the toolbar's `+` adds one in the middle of what's on screen, for
/// anyone a double tap doesn't suit. Where the on-device model can run, the toolbar's Make Notes
/// adds several there at once, made from what is written in its sheet. While a note is dragged,
/// its stand-in and the bin that deletes it are drawn here; after a delete on this board, so is
/// the offer to undo it. A note picked from a search is brought to the middle, and VoiceOver to
/// it. A note being written on is drawn in the middle too, above the keyboard, with the rest of
/// the board blurred behind it.
struct CanvasView: View {
    static let space = "canvas"

    /// How long "Note deleted · Undo" stays up.
    static let undoOffer: Duration = .seconds(5)

    /// A note to bring to the middle of the canvas: one picked from a search. Each pick is a new
    /// one, so picking the same note again scrolls to it again.
    struct Reveal: Equatable {
        let noteID: UUID
        let boardID: UUID
        private let pick = UUID()

        /// Nil for a note on no board, which the store never leaves.
        init?(_ note: Note) {
            guard let boardID = note.board?.id else { return nil }
            self.noteID = note.id
            self.boardID = boardID
        }
    }

    @Environment(NoteStore.self) private var store
    @Environment(\.motion) private var motion
    @Environment(\.undoManager) private var undoManager
    @Environment(\.noteWriter) private var writer
    @Environment(Pro.self) private var pro
    @Environment(\.proOffer) private var offer
    let board: Board
    let reveal: Reveal?
    @Query private var notes: [Note]
    @State private var size: CGSize = .zero
    @State private var bounds = CanvasBounds()
    @State private var scroll = CanvasScroll()
    @State private var drag = NoteDrag()
    @State private var isMakingNotes = false
    /// The notes Make Notes made, until its sheet has gone.
    @State private var made: [String] = []
    /// The note being written on — see ``CanvasOverlays``.
    @State private var editing: UUID?
    /// The note VoiceOver is on: moved to a revealed one.
    @AccessibilityFocusState private var spoken: UUID?
    private var tour = OnboardingProgress()

    init(board: Board, reveal: Reveal? = nil) {
        self.board = board
        self.reveal = reveal
        let id = board.id
        _notes = Query(filter: #Predicate { $0.board?.id == id }, sort: \.z)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack {
                surface
                NotePlacement(origin: scroll.contentOrigin) {
                    ForEach(notes) { note in
                        NoteView(note: note, canvas: bounds, editing: $editing, spoken: $spoken)
                            .transition(motion.arrival)
                    }
                }
            }
            .frame(width: scroll.extent.width, height: scroll.extent.height)
            // Until board (0, 0) reaches the top-left, the notes would show where the content
            // starts.
            .opacity(scroll.isOpen ? 1 : 0)
        }
        .scrollIndicators(.hidden)
        // While a note is written on in the middle, its place stays where it goes back to. The
        // blur takes touches, but not a Mac's scroll wheel or a tap on the status bar.
        .scrollDisabled(editing != nil)
        .modifier(CanvasScrolling(scroll: scroll, drag: drag, notes: notes, reveal: reveal))
        // Once it is on screen: as the board opens on it, or when picked with the board open.
        .onChange(of: scroll.isOpen) { speakRevealed() }
        .onChange(of: reveal) { speakRevealed() }
        // What VoiceOver and the UI tests know as the canvas: what's on screen, clear of the bars
        // and an iPad's sidebar. The scroll view's own frame runs under them, and its content is
        // the size of the board.
        .background {
            Rectangle()
                .fill(.clear)
                .accessibilityElement()
                .accessibilityLabel(Text("Canvas", comment: "VoiceOver label for the board."))
                .accessibilityIdentifier(A11y.Canvas.surface)
        }
        .overlay {
            if notes.isEmpty { emptyState }
        }
        .modifier(
            CanvasOverlays(
                board: board, notes: notes, drag: drag, scroll: scroll, size: size,
                editing: $editing)
        )
        // The store registers its undo with this window's manager — see `NoteStore`.
        .onChange(of: undoManager, initial: true) { store.undoManager = undoManager }
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            self.size = size
            bounds.size = size
        }
        .background(.background.secondary)
        .navigationTitle(board.title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            // Before `+`, which stays at the trailing edge.
            if writer.isAvailable {
                ToolbarItem(placement: .primaryAction) {
                    // Drawn whether or not this month's free runs are left: spent, it offers Pro.
                    Button {
                        if pro.allows(.makeNotes) {
                            isMakingNotes = true
                        } else {
                            offer?.show(.makeNotes)
                        }
                    } label: {
                        Label {
                            Text(
                                "Make Notes",
                                comment: "Opens the sheet that makes notes, and its title.")
                        } icon: {
                            // Not `apple.intelligence`, which only Apple Intelligence itself may
                            // show.
                            Image(systemName: "sparkles")
                        }
                    }
                    .accessibilityIdentifier(A11y.Canvas.makeNotesButton)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let visible = scroll.visible
                    add(at: CGPoint(x: visible.midX, y: visible.midY))
                } label: {
                    Label {
                        Text(
                            "Add Note",
                            comment:
                                "Adds a note: the toolbar button, and what Undo and Redo call it."
                        )
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .accessibilityIdentifier(A11y.Canvas.addButton)
            }
        }
        // Added once the sheet has gone, so they are seen arriving.
        .sheet(isPresented: $isMakingNotes, onDismiss: addMade) {
            MakeNotesSheet { made = $0 }
        }
    }

    /// The empty board behind the notes, as far as the content reaches: what a double tap lands
    /// on. A note sits on top of it, so a double tap on a note never adds one.
    private var surface: some View {
        Rectangle()
            .fill(.clear)
            .contentShape(.rect)
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { add(at: scroll.boardPoint(fromContent: $0.location)) }
            )
            .accessibilityHidden(true)
    }

    /// What an empty board says, and the way back to the tour. The words let touches through, so
    /// a double tap on them adds a note as anywhere else does.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Double-tap anywhere to add a note", comment: "Shown on an empty canvas.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .allowsHitTesting(false)
                .accessibilityIdentifier(A11y.Canvas.emptyState)
            // Plain and primary: the accent on the board's gray is short of contrast for text
            // this size.
            Button {
                tour.markDue()
            } label: {
                HStack(spacing: 6) {
                    Text(
                        "Show Me How",
                        comment: "Under the empty canvas: puts the tour of the gestures back up.")
                    Image(systemName: "chevron.forward")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .font(.headline)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11y.Canvas.tourButton)
        }
        .padding()
    }

    private func add(at point: CGPoint) {
        let note = withAnimation(motion.edit) {
            store.add(at: point, within: scroll.visible, on: board)
        }
        editing = note.id
    }

    /// What Make Notes made, together in the middle of what's on screen. VoiceOver goes to the
    /// first, since they are written already.
    ///
    /// A run is spent once its notes arrive, so one cancelled or failed costs nothing; the run
    /// that spends the last free one offers Pro as its notes land.
    private func addMade() {
        guard !made.isEmpty else { return }
        let notes = withAnimation(motion.edit) {
            store.add(made, within: scroll.visible, on: board)
        }
        made = []
        spoken = notes.first?.id
        pro.spend(.makeNotes)
        if pro.hasRunOut(of: .makeNotes) { offer?.show(.makeNotes) }
    }

    private func speakRevealed() {
        if scroll.isOpen, let reveal { spoken = reveal.noteID }
    }
}

/// Lays each note out at its own size, centred on its ``NoteCenter``. A note's frame is the note
/// rather than the whole canvas, so its arrival and departure scale it about its own centre.
nonisolated struct NotePlacement: Layout {
    /// Where board (0, 0) is in the layout.
    var origin: CGPoint = .zero

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        for subview in subviews {
            let center = subview[NoteCenter.self]
            subview.place(
                at: CGPoint(
                    x: bounds.minX + origin.x + center.x, y: bounds.minY + origin.y + center.y),
                anchor: .center, proposal: .unspecified)
        }
    }
}

/// Where ``NotePlacement`` centres a note, in board coordinates.
nonisolated struct NoteCenter: LayoutValueKey {
    static let defaultValue = CGPoint.zero
}

/// The canvas's size, for a note's gestures and menu to read when they act. A reference, and not
/// observed, so a resize — the keyboard, a rotation, every frame of a window drag — changes no
/// note's inputs and re-renders no note.
final class CanvasBounds {
    var size: CGSize

    init(size: CGSize = .zero) {
        self.size = size
    }
}

#Preview("Notes") {
    let container = PreviewNotes.container(seeded: true)
    NavigationStack { CanvasView(board: PreviewNotes.boards(in: container)[0]) }
        .previewNotes(container)
}

#Preview("Empty") {
    let container = PreviewNotes.container()
    NavigationStack { CanvasView(board: PreviewNotes.boards(in: container)[0]) }
        .previewNotes(container)
}
