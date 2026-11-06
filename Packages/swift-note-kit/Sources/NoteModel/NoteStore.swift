import CoreGraphics
import Foundation
import OSLog
import SwiftData

/// Every write to the notes goes through here, and every write saves before it returns:
/// autosave isn't guaranteed to run before the process exits, and a note that moved back on
/// relaunch reads as lost work. Text alone waits for a pause in typing, outside the note until
/// then; see ``setText(_:of:)``.
///
/// ## Undo is the store's own
///
/// Adding, moving, resizing, recoloring and deleting are undoable through ``undoManager`` — the
/// window's, handed over by the canvas — and each undo registers its redo. SwiftData's own undo is
/// never used: an undone delete comes back gone at the next save (seen in task-manager on iOS 27),
/// so `context.undoManager` stays nil and the store registers what reverses each write itself.
///
/// An undo finds its note by ``Note/id``, never by holding the model: a deleted note brought back
/// is a new instance, and a later undo has to reach that one.
///
/// Not undoable: text, which the text field undoes keystroke by keystroke while it's being
/// edited; the raise that comes with every ``drop(_:at:)``; and anything done to a board.
/// Deleting a board is confirmed first instead, and leaves any undo of a change to its notes
/// doing nothing.
@Observable
public final class NoteStore {
    /// What an undoable write did, so the app can name it in an Undo menu item.
    public enum Action: Sendable {
        case add, addSeveral, move, resize, recolor, delete
    }

    /// The note deleted last, while undoing that is still the next undo.
    public struct Deletion: Equatable, Sendable {
        public let noteID: UUID
        /// The board it was on, so only that board offers it back.
        public let boardID: UUID?
        /// Tells two deletions of the same note apart.
        let token = UUID()
    }

    public let context: ModelContext

    /// Where writes register their undo. Held weakly: it belongs to a window.
    @ObservationIgnored public weak var undoManager: UndoManager?

    /// The Undo menu's name for each action. Supplied by the app, which owns the strings.
    @ObservationIgnored public var actionName: (Action) -> String? = { _ in nil }

    /// How long typing has to pause before ``setText(_:of:)`` saves.
    @ObservationIgnored var textSaveDelay: Duration = .seconds(1)

    /// The save waiting for typing to pause. Any other save saves the text too, and cancels it.
    @ObservationIgnored private var textSave: Task<Void, Never>?

    /// What is being typed into a note, until typing pauses. Kept out of the note because any
    /// change to a note, saved or not, has every `@Query` over notes and boards fetch again and
    /// the canvas re-render — on each keystroke, at a cost growing with the notes on the board
    /// (measured on iOS 27). Written into the note before every save, and before anything that
    /// copies or deletes notes.
    @ObservationIgnored private var draft: (note: Note, text: String)?

    /// Set by ``delete(_:)`` and cleared by any other write, undo or redo — so while it is set,
    /// ``undo()`` brings this note back.
    public private(set) var lastDeletion: Deletion?

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Writes

    /// Adds an empty note to `board`, centred on `point` and moved as little as keeps it wholly
    /// within `visible` — what is on screen, in board points — on top of every other note there
    /// and in the color after the board's newest note's.
    @discardableResult
    public func add(at point: CGPoint, within visible: CGRect, on board: Board) -> Note {
        let top = topmost(on: board)
        let note = Note(
            center: NoteGeometry.clamp(point, side: NoteGeometry.defaultSide, in: visible),
            color: top?.color.next ?? .yellow,
            z: (top?.z ?? -1) + 1
        )
        context.insert(note)
        note.board = board
        save()
        let id = note.id
        register(.add, Reversal { $0.removing(id) })
        lastDeletion = nil
        return note
    }

    /// Adds a note saying each of `texts` to `board`, in ``NoteGeometry/rows(of:side:in:)`` in
    /// the middle of `visible`, in reading order: on top of every other note there, in colors
    /// that carry on from the board's newest note's. In one save, since each save re-renders
    /// every note on the board, and one undo takes them all back. Nothing, for no texts.
    @discardableResult
    public func add(_ texts: [String], within visible: CGRect, on board: Board) -> [Note] {
        guard !texts.isEmpty else { return [] }
        let top = topmost(on: board)
        let centers = NoteGeometry.rows(
            of: texts.count, side: NoteGeometry.defaultSide, in: visible)
        var color = top?.color.next ?? .yellow
        var notes: [Note] = []
        for (text, center) in zip(texts, centers) {
            let note = Note(
                center: center, color: color, z: (top?.z ?? -1) + 1 + notes.count, text: text)
            context.insert(note)
            note.board = board
            notes.append(note)
            color = color.next
        }
        save()
        let ids = notes.map(\.id)
        register(.addSeveral, .all(ids.map { id in Reversal { $0.removing(id) } }))
        lastDeletion = nil
        return notes
    }

    /// Moves `note` so its centre is `point`.
    public func move(_ note: Note, to point: CGPoint) {
        place(note, as: .move) {
            note.center = point
        }
    }

    /// Makes `note` `side` points square, held to the size limits. It grows about its centre.
    public func resize(_ note: Note, to side: Double) {
        place(note, as: .resize) {
            note.side = NoteGeometry.clampSide(side)
        }
    }

    /// Makes `note` `color`. No write, and nothing to undo, when it already is.
    public func recolor(_ note: Note, to color: NoteColor) {
        // Compared raw: a color this build doesn't know reads as yellow, but isn't.
        let before = note.colorRaw
        guard color.rawValue != before else { return }
        note.color = color
        save()
        let id = note.id
        register(.recolor, Reversal { $0.coloring(id, as: before) })
        lastDeletion = nil
    }

    /// Puts `note` down with its centre at `point`, above every other note on its board — the end
    /// of a drag, and of each of a note's Move actions. In one save, since each save re-renders
    /// every note on the board. Only the move is undoable.
    public func drop(_ note: Note, at point: CGPoint) {
        if let board = note.board, let top = topmost(on: board), top != note {
            note.z = top.z + 1
        }
        move(note, to: point)
        // The move saved the raise too, unless the note went down where it was picked up.
        save()
    }

    /// Takes `text` as `note`'s at once — ``text(of:)`` reads it back — but writes it into the
    /// note and saves it only once typing pauses for ``textSaveDelay``, or sooner, through
    /// ``saveText()`` or any other write. Each save re-renders every note on the board, too much
    /// to do on every keystroke.
    public func setText(_ text: String, of note: Note) {
        guard self.text(of: note) != text else { return }
        if let draft, draft.note !== note { writeDraft() }
        draft = (note, text)
        lastDeletion = nil
        textSave?.cancel()
        textSave = Task { [weak self, textSaveDelay] in
            try? await Task.sleep(for: textSaveDelay)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    /// `note`'s text, with whatever is being typed into it that typing hasn't paused on yet.
    public func text(of note: Note) -> String {
        if let draft, draft.note === note { return draft.text }
        return note.text
    }

    /// Saves text still waiting for a pause in typing — for when an edit ends, and when the app
    /// leaves the foreground, as a Mac app also does on its way to quitting.
    public func saveText() {
        save()
    }

    public func delete(_ note: Note) {
        // The values an undo brings back include what was being typed.
        writeDraft()
        let values = NoteValues(of: note)
        context.delete(note)
        save()
        register(.delete, Reversal { $0.inserting(values) })
        lastDeletion = Deletion(noteID: values.id, boardID: values.boardID)
    }

    // MARK: - Boards

    /// The oldest board, made if there are none. Any note without a board goes onto it.
    @discardableResult
    public func firstBoard(creatingOneNamed name: String) -> Board {
        var descriptor = FetchDescriptor<Board>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        let board: Board
        if let first = try? context.fetch(descriptor).first {
            board = first
        } else {
            board = Board(name: name)
            context.insert(board)
        }
        let strays =
            (try? context.fetch(
                FetchDescriptor<Note>(
                    predicate: #Predicate {
                        $0.board == nil
                    }))) ?? []
        for note in strays { note.board = board }
        save()
        return board
    }

    @discardableResult
    public func addBoard(named name: String) -> Board {
        let board = Board(name: name)
        context.insert(board)
        save()
        return board
    }

    public func rename(_ board: Board, to name: String) {
        guard board.name != name else { return }
        board.name = name
        save()
    }

    /// Deletes `board` and every note on it. Not undoable.
    public func delete(_ board: Board) {
        // Before the note being typed into goes with the board.
        writeDraft()
        if lastDeletion?.boardID == board.id { lastDeletion = nil }
        context.delete(board)
        save()
    }

    // MARK: - Undo

    public var canUndo: Bool { undoManager?.canUndo ?? false }

    public func undo() {
        undoManager?.undo()
    }

    /// Stops offering `deletion` back, if it is still the last one.
    public func forget(_ deletion: Deletion) {
        if lastDeletion == deletion { lastDeletion = nil }
    }

    /// Makes `change` to `note`'s placement and registers putting it back. No write, and nothing
    /// to undo, when nothing moved.
    private func place(_ note: Note, as action: Action, _ change: () -> Void) {
        let before = Placement(of: note)
        change()
        guard Placement(of: note) != before else { return }
        save()
        let id = note.id
        register(action, Reversal { $0.placing(id, at: before) })
        lastDeletion = nil
    }

    /// Registers `reversal` as the undo of what just happened. When it runs, what it returns is
    /// registered in turn — onto the redo stack, since the manager is undoing as it runs.
    private func register(_ action: Action, _ reversal: Reversal) {
        guard let manager = undoManager else { return }

        // A manager grouped by hand throws on a registration with no group open; give it one.
        let opensGroup = !manager.groupsByEvent && manager.groupingLevel == 0
        if opensGroup { manager.beginUndoGrouping() }
        defer { if opensGroup { manager.endUndoGrouping() } }

        manager.registerUndo(withTarget: self) { store in
            // A reversal may copy or delete the note being typed into.
            store.writeDraft()
            guard let inverse = reversal.apply(store) else { return }
            store.save()
            store.lastDeletion = nil
            store.register(action, inverse)
        }
        if let name = actionName(action) { manager.setActionName(name) }
    }

    private func removing(_ id: UUID) -> Reversal? {
        guard let note = note(withID: id) else { return nil }
        let values = NoteValues(of: note)
        context.delete(note)
        return Reversal { $0.inserting(values) }
    }

    /// Nil, and nothing inserted, when the note's board has since been deleted.
    private func inserting(_ values: NoteValues) -> Reversal? {
        guard let boardID = values.boardID, let board = board(withID: boardID) else { return nil }
        let note = values.makeNote()
        context.insert(note)
        note.board = board
        return Reversal { $0.removing(values.id) }
    }

    private func placing(_ id: UUID, at placement: Placement) -> Reversal? {
        guard let note = note(withID: id) else { return nil }
        let current = Placement(of: note)
        placement.apply(to: note)
        return Reversal { $0.placing(id, at: current) }
    }

    private func coloring(_ id: UUID, as colorRaw: String) -> Reversal? {
        guard let note = note(withID: id) else { return nil }
        let current = note.colorRaw
        note.colorRaw = colorRaw
        return Reversal { $0.coloring(id, as: current) }
    }

    // MARK: - Reads

    private func note(withID id: UUID) -> Note? {
        var descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func board(withID id: UUID) -> Board? {
        var descriptor = FetchDescriptor<Board>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func topmost(on board: Board) -> Note? {
        let boardID = board.id
        var descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.board?.id == boardID },
            sortBy: [SortDescriptor(\.z, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Puts what is being typed into its note.
    private func writeDraft() {
        guard let draft else { return }
        self.draft = nil
        if draft.note.text != draft.text { draft.note.text = draft.text }
    }

    private func save() {
        writeDraft()
        textSave?.cancel()
        textSave = nil
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Logger.store.error("Couldn't save the store: \(error)")
        }
    }
}

/// Undoes one change, and returns the change that redoes it — or nil when its note is gone.
struct Reversal {
    let apply: (NoteStore) -> Reversal?

    /// Undoes each of `reversals` as one change, and redoes them as one: notes added together
    /// go together. No redo when none of them had anything left to undo.
    static func all(_ reversals: [Reversal]) -> Reversal {
        Reversal { store in
            let inverses = reversals.compactMap { $0.apply(store) }
            return inverses.isEmpty ? nil : .all(inverses)
        }
    }
}

/// Where a note is and how big: what a move or resize changes, and all its undo puts back.
/// Text is left alone, so undoing a move never takes back what was typed since.
struct Placement: Equatable {
    let x: Double
    let y: Double
    let side: Double

    init(of note: Note) {
        x = note.x
        y = note.y
        side = note.side
    }

    func apply(to note: Note) {
        note.x = x
        note.y = y
        note.side = side
    }
}

/// Every stored property of a note, to bring a deleted one back as it was. Its board is held by
/// id, and put back by the store.
/// `NoteStoreUndoTests` fails until ``storedProperties`` matches the schema — a property added to
/// `Note` and left out here would come back reset to its default.
struct NoteValues {
    static let storedProperties: Set<String> = [
        "id", "text", "x", "y", "side", "colorRaw", "z", "createdAt", "board",
    ]

    let id: UUID
    let text: String
    let x: Double
    let y: Double
    let side: Double
    let colorRaw: String
    let z: Int
    let createdAt: Date
    let boardID: UUID?

    init(of note: Note) {
        id = note.id
        text = note.text
        x = note.x
        y = note.y
        side = note.side
        colorRaw = note.colorRaw
        z = note.z
        createdAt = note.createdAt
        boardID = note.board?.id
    }

    func makeNote() -> Note {
        let note = Note(center: CGPoint(x: x, y: y), color: .yellow, z: z, text: text)
        note.id = id
        note.side = side
        note.colorRaw = colorRaw
        note.createdAt = createdAt
        return note
    }
}

extension Logger {
    fileprivate static let store = Logger(
        subsystem: "com.thebinarykitchen.StickyNotes", category: "store")
}
