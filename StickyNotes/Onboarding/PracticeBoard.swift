import AccessibilityIdentifiers
import NoteModel
import SwiftData
import SwiftUI

/// A small board to practise a lesson's gesture on: the canvas's own notes, gestures and overlays
/// over a ``Practice`` store, so what the reader does here is the gesture itself. A
/// ``Demonstration`` loops on it until the reader first touches it; from then on it is theirs.
///
/// Every gesture works on every page — it is a board — but only the page's own teaches it.
struct PracticeBoard: View {
    let lesson: Lesson
    /// Called once, the first time the lesson's gesture is done here.
    var onLearned: () -> Void

    /// Made on appearing rather than as this view's initial value, which would open a store each
    /// time the page is drawn.
    @State private var practice: Practice?

    var body: some View {
        Group {
            if let practice {
                PracticeSurface(lesson: lesson, board: practice.board, onLearned: onLearned)
                    .modelContainer(practice.container)
                    .environment(practice.store)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if practice == nil { practice = Practice() }
        }
    }
}

/// The throwaway store a practice board works on: in memory, with a board of its own and an undo
/// manager of its own, so nothing practised reaches the reader's notes or their window's Undo.
private final class Practice {
    let container: ModelContainer
    let store: NoteStore
    let board = Board(name: "")
    /// Held here: the store holds its undo manager weakly.
    private let undoManager = UndoManager()

    init() {
        do {
            container = try .inMemory()
        } catch {
            // The schema the app opens its own store with: if this fails, so did the launch.
            fatalError("Could not create the tour's practice store: \(error)")
        }
        store = NoteStore(context: container.mainContext)
        container.mainContext.insert(board)
        store.undoManager = undoManager
    }
}

/// The practice board itself, under its store's container, for its notes' query.
private struct PracticeSurface: View {
    let lesson: Lesson
    let board: Board
    var onLearned: () -> Void

    @Environment(NoteStore.self) private var store
    @Environment(\.motion) private var motion
    @Query private var notes: [Note]
    @State private var size: CGSize = .zero
    @State private var bounds = CanvasBounds()
    /// Never scrolled: board points are this board's own.
    @State private var scroll = CanvasScroll()
    @State private var drag = NoteDrag()
    @State private var editing: UUID?
    @AccessibilityFocusState private var spoken: UUID?
    /// The notes wait for a size to be laid out on.
    @State private var isSeeded = false
    /// The note the demonstration acts on, which it draws while it has it away from rest.
    @State private var demonstrated: UUID?
    /// Whether the demonstration has its note away from rest, with the board's own hidden.
    @State private var isAway = false
    /// Until the reader first touches the board.
    @State private var isDemonstrating = true
    @State private var isLearned = false

    init(lesson: Lesson, board: Board, onLearned: @escaping () -> Void) {
        self.lesson = lesson
        self.board = board
        self.onLearned = onLearned
        let id = board.id
        _notes = Query(filter: #Predicate { $0.board?.id == id }, sort: \.z)
    }

    var body: some View {
        ZStack {
            surface
            NotePlacement {
                ForEach(notes) { note in
                    NoteView(note: note, canvas: bounds, editing: $editing, spoken: $spoken)
                        // Still there for VoiceOver, whose way to practise it is its actions.
                        .opacity(isDemonstrating && isAway && note.id == demonstrated ? 0 : 1)
                        .transition(motion.arrival)
                }
            }
        }
        .modifier(
            CanvasOverlays(
                board: board, notes: notes, drag: drag, scroll: scroll, size: size,
                editing: $editing)
        )
        .overlay {
            if isDemonstrating, let rest {
                DemonstrationLayer(lesson: lesson, rest: rest, board: size) { isAway = $0 }
            }
        }
        // Any touch on the board ends the demonstration; whatever gesture it starts goes on.
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in takeOver() })
        .coordinateSpace(.named(CanvasView.space))
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            self.size = size
            bounds.size = size
            seed()
        }
        .background(.background.secondary)
        .accessibilityElement(children: .contain)
        // The double tap's way for anyone it doesn't suit, as the toolbar's + is on a real board.
        .accessibilityAction(
            named: Text(
                "Add Note",
                comment: "Adds a note: the toolbar button, and what Undo and Redo call it.")
        ) {
            add(at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        .accessibilityIdentifier(A11y.Tour.practiceBoard)
        .onChange(of: editing) {
            if editing != nil { did(.tapToWrite) }
        }
        .onChange(of: arrangement) { before, after in compare(before, after) }
        .onChange(of: store.lastDeletion) {
            guard store.lastDeletion != nil else { return }
            did(.dragToBin)
            did(.pinchToCrumple)
        }
        .onChange(of: drag.isActive) {
            if drag.isActive { takeOver() }
        }
    }

    /// The empty board behind the notes: what a double tap lands on.
    private var surface: some View {
        Rectangle()
            .fill(.clear)
            .contentShape(.rect)
            .gesture(SpatialTapGesture(count: 2).onEnded { add(at: $0.location) })
            .accessibilityHidden(true)
    }

    /// The note the demonstration acts on, as it rests. For the double tap, the note it adds,
    /// where the store would put it.
    private var rest: Demonstration.Rest? {
        guard isSeeded else { return nil }
        if lesson == .doubleTapToAdd {
            return .added(
                at: Lesson.place(Lesson.spot, in: size), on: size,
                after: notes.max { $0.z < $1.z }?.color)
        }
        guard let note = notes.first(where: { $0.id == demonstrated }) else { return nil }
        return Demonstration.Rest(
            center: note.center, side: note.side, color: note.color, text: store.text(of: note))
    }

    // MARK: - What the reader does

    /// Each note's place, size and color, to tell what a change did to which.
    private var arrangement: [UUID: Arrangement] {
        Dictionary(notes.map { ($0.id, Arrangement($0)) }) { first, _ in first }
    }

    private struct Arrangement: Equatable {
        let center: CGPoint
        let side: Double
        let color: String

        init(_ note: Note) {
            center = note.center
            side = note.side
            color = note.colorRaw
        }
    }

    /// What changed between the notes as they were and as they are. A note that is new, or new
    /// again after an undo, is neither moved nor resized nor recolored.
    private func compare(_ before: [UUID: Arrangement], _ after: [UUID: Arrangement]) {
        for (id, now) in after {
            guard let was = before[id] else { continue }
            if now.center != was.center { did(.dragToMove) }
            if now.side != was.side { did(.pinchToResize) }
            if now.color != was.color { did(.holdForMenu) }
        }
    }

    /// The reader did `gesture` here; the page's lesson is learned if it was the page's own.
    private func did(_ gesture: Lesson) {
        takeOver()
        guard gesture == lesson, !isLearned else { return }
        isLearned = true
        onLearned()
    }

    /// Ends the demonstration for good. If it had its note away, the board's own comes back at
    /// rest: a hidden note takes no touches, so the first touch on one only gets it back.
    private func takeOver() {
        if isDemonstrating { isDemonstrating = false }
    }

    /// Adds a note as the canvas does, where it is asked for, but not opened for writing: there
    /// is no keyboard on the tour. On the double tap's page it says something, so the page has
    /// something to show for it.
    private func add(at point: CGPoint) {
        let note = withAnimation(motion.edit) {
            store.add(at: point, within: CGRect(origin: .zero, size: size), on: board)
        }
        if lesson == .doubleTapToAdd {
            store.setText(String(localized: Lesson.added), of: note)
            store.saveText()
        }
        did(.doubleTapToAdd)
    }

    /// Puts the lesson's notes on the board, once it has a size to lay them out on — as sample
    /// notes are put on a board, past the store.
    private func seed() {
        guard !isSeeded, size.width > 0, size.height > 0 else { return }
        isSeeded = true
        let context = store.context
        for (index, practice) in lesson.practice.enumerated() {
            let note = Note(
                center: Lesson.place(practice.offset, in: size), color: practice.color, z: index,
                text: String(localized: practice.text))
            note.side = practice.side
            context.insert(note)
            note.board = board
            if index == lesson.demonstrated { demonstrated = note.id }
        }
        try? context.save()
    }
}

#Preview("Each lesson's board") {
    @Previewable @State var lesson = Lesson.doubleTapToAdd

    VStack {
        Picker(selection: $lesson) {
            ForEach(Lesson.allCases) { Text($0.title).tag($0) }
        } label: {
            Text(verbatim: "Lesson")
        }
        PracticeBoard(lesson: lesson) {}
            .id(lesson)
            .clipShape(.rect(cornerRadius: 16))
            .padding()
    }
}
