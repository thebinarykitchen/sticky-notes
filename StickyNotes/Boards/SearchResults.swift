import AccessibilityIdentifiers
import NoteModel
import SwiftData
import SwiftUI

/// The notes whose text holds `query`, listed in place of the boards while searching: under their
/// boards' names, boards in list order and notes as each board reads. Picking one opens its board
/// on it.
struct SearchResults: View {
    let query: String
    let boards: [Board]
    @Binding var reveal: CanvasView.Reveal?

    @Query private var found: [Note]

    init(query: String, boards: [Board], reveal: Binding<CanvasView.Reveal?>) {
        self.query = query
        self.boards = boards
        _reveal = reveal
        _found = Query(Note.search(query))
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.notes) { note in
                        Button {
                            reveal = CanvasView.Reveal(note)
                        } label: {
                            SearchResultRow(note: note)
                        }
                        // Plain on every platform: a Mac draws a list's buttons bordered.
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(A11y.Boards.searchResult)
                    }
                } header: {
                    section.board.title
                }
            }
        }
        .overlay {
            if found.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private struct BoardSection: Identifiable {
        let board: Board
        let notes: [Note]
        var id: UUID { board.id }
    }

    /// Each board something was found on, in list order.
    private var sections: [BoardSection] {
        let byBoard = Dictionary(grouping: found) { $0.board?.id }
        return boards.compactMap { board in
            byBoard[board.id].map { BoardSection(board: board, notes: $0) }
        }
    }
}

/// A note found: its words, beside a swatch of its color.
private struct SearchResultRow: View {
    let note: Note

    var body: some View {
        Label {
            // The reader's own words, never localized.
            Text(verbatim: note.text)
                .lineLimit(2)
        } icon: {
            RoundedRectangle(cornerRadius: 3)
                .fill(note.color.fill)
                .overlay {
                    RoundedRectangle(cornerRadius: 3).strokeBorder(.separator)
                }
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

#Preview {
    @Previewable @State var reveal: CanvasView.Reveal?
    let container = PreviewNotes.container(seeded: true)
    NavigationStack {
        SearchResults(query: "the", boards: PreviewNotes.boards(in: container), reveal: $reveal)
    }
    .previewNotes(container)
}
