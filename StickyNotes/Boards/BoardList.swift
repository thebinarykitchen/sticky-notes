import AccessibilityIdentifiers
import AppTour
import NoteModel
import PurchaseUI
import SwiftData
import SwiftUI

/// Every board, oldest first. The toolbar's `+` adds one, or offers Pro once every free board is
/// in use; a board's menu renames or deletes it. The last board can't be deleted, so there is
/// always a canvas to show. Searching lists the notes found in place of the boards. Pro and
/// Restore Purchases are under the boards, above About.
struct BoardList: View {
    let boards: [Board]
    @Binding var selection: UUID?
    /// Set to a note picked from a search, which opens its board on it.
    @Binding var reveal: CanvasView.Reveal?

    @Environment(NoteStore.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.motion) private var motion
    @Environment(\.proOffer) private var offer
    private var tour = TourProgress.app
    @State private var isAdding = false
    @State private var renaming: Board?
    @State private var deleting: Board?
    /// What the New Board or Rename prompt's field holds.
    @State private var name = ""
    /// What the search field holds.
    @State private var query = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What is searched for: empty while the list shows the boards.
    private var searched: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if searched.isEmpty {
                boardRows
            } else {
                SearchResults(query: searched, boards: boards, reveal: $reveal)
            }
        }
        .searchable(
            text: $query, placement: .sidebar,
            prompt: Text(
                "Search Notes",
                comment: "Placeholder in the field that searches every board's notes.")
        )
        .navigationTitle(Text("Boards", comment: "The title of the list of boards."))
        .toolbar {
            // Before New Board, which stays at the trailing edge. An icon: a text button in the
            // toolbar fails the accessibility audit.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    tour.markDue()
                } label: {
                    Label {
                        Text(
                            "Gestures",
                            comment:
                                "Puts the tour of the gestures back up, over the list of boards.")
                    } icon: {
                        Image(systemName: "hand.tap")
                    }
                }
                .accessibilityIdentifier(A11y.Boards.tourButton)
            }
            ToolbarItem(placement: .primaryAction) {
                // Drawn whether or not another board is free: past the free ones, it offers Pro.
                Button {
                    if pro.allowsAnotherBoard(having: boards.count) {
                        name = ""
                        isAdding = true
                    } else {
                        offer?.show(.boards)
                    }
                } label: {
                    Label {
                        Text(
                            "New Board",
                            comment:
                                "Adds a board: the toolbar button, and the title of the prompt naming it."
                        )
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .accessibilityIdentifier(A11y.Boards.addButton)
            }
        }
        .alert(
            Text(
                "New Board",
                comment: "Adds a board: the toolbar button, and the title of the prompt naming it."),
            isPresented: $isAdding
        ) {
            nameField
            Button(role: .cancel) {}
            Button {
                selection = store.addBoard(named: trimmedName).id
            } label: {
                Text("Create", comment: "Adds the board just named.")
            }
        }
        .alert(
            Text("Rename Board", comment: "The title of the prompt renaming a board."),
            isPresented: isPresent($renaming),
            presenting: renaming
        ) { board in
            nameField
            Button(role: .cancel) {}
            Button {
                store.rename(board, to: trimmedName)
            } label: {
                Text("Rename", comment: "Renames a board.")
            }
        }
        .confirmationDialog(
            Text("Delete Board?", comment: "Asks before deleting a board."),
            isPresented: isPresent($deleting),
            titleVisibility: .visible,
            presenting: deleting
        ) { board in
            Button(role: .destructive) {
                store.delete(board)
            } label: {
                Text("Delete Board", comment: "Deletes a board and its notes.")
            }
        } message: { board in
            Text(
                "\(board.title) and its notes will be deleted. This can't be undone.",
                comment: "Before deleting a board. The argument is the board's name."
            )
        }
    }

    private var boardRows: some View {
        List(selection: $selection) {
            ForEach(boards) { board in
                Label {
                    board.title
                        .accessibilityIdentifier(A11y.Boards.row)
                } icon: {
                    Image(systemName: "note.text")
                }
                .tag(board.id as UUID?)
                .contextMenu {
                    Button {
                        name = board.name
                        renaming = board
                    } label: {
                        Label {
                            Text("Rename", comment: "Renames a board.")
                        } icon: {
                            Image(systemName: "pencil")
                        }
                    }
                    Button(role: .destructive) {
                        deleting = board
                    } label: {
                        Label {
                            Text("Delete", comment: "Deletes a board, after asking.")
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                    .disabled(boards.count == 1)
                }
            }
            PurchaseSettingsSection(
                purchase: pro.purchase,
                appName: ProSheet.appName,
                identifiers: PurchaseSettingsIdentifiers(
                    proRow: A11y.Pro.listRow, restoreButton: A11y.Pro.listRestoreButton),
                // `Motion.edit` is nil under Reduce Motion and the `--reduce-motion` launch flag.
                reducesMotion: motion.edit == nil,
                showOffer: { offer?.show(nil) }
            )
            AboutSection()
        }
    }

    private var nameField: some View {
        TextField(text: $name, prompt: Text("Name", comment: "Placeholder for a board's name.")) {
            Text("Board name", comment: "VoiceOver label for a board's name field.")
        }
    }

    /// True while `item` is set; setting it false clears `item`.
    private func isPresent<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}

extension Board {
    /// The board's name, or "Untitled Board" while it has none. The name is the reader's own,
    /// and never localized.
    var title: Text {
        name.isEmpty
            ? Text("Untitled Board", comment: "What a board with no name is called.")
            : Text(verbatim: name)
    }
}

#Preview {
    @Previewable @State var selection: UUID?
    let container = PreviewNotes.container(seeded: true)
    NavigationStack {
        BoardList(
            boards: PreviewNotes.boards(in: container), selection: $selection,
            reveal: .constant(nil))
    }
    .previewNotes(container)
}
