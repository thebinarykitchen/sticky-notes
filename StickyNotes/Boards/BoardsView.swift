import NoteModel
import SwiftData
import SwiftUI

/// The list of boards beside the canvas of the one chosen. On iPhone the list collapses behind
/// the canvas, and a launch opens straight onto the canvas. A note picked from a search opens
/// its board on it.
struct BoardsView: View {
    @Query(sort: \Board.createdAt) private var boards: [Board]
    /// The chosen board's id, kept per window across launches. Empty while none is chosen.
    @SceneStorage("selectedBoard") private var selectedID = ""
    @State private var compactColumn = NavigationSplitViewColumn.detail
    /// The note picked from a search last, while its board is the one chosen.
    @State private var reveal: CanvasView.Reveal?
    /// This window's Pro sheet, which the list, the canvas and the menu bar put up.
    @State private var offer = ProOffer()

    private var chosen: Board? {
        boards.first { $0.id.uuidString == selectedID }
    }

    /// What the canvas shows: the first board while none is chosen, as on iPhone, where going
    /// back to the list clears the choice.
    private var board: Board? { chosen ?? boards.first }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            BoardList(boards: boards, selection: $selectedID.uuid, reveal: $reveal)
        } detail: {
            if let board {
                // A board of its own, so a drag or focus never carries over from the last one.
                CanvasView(board: board, reveal: reveal?.boardID == board.id ? reveal : nil)
                    .id(board.id)
            }
        }
        .sheet(item: $offer.shown) { reason in
            ProSheet(reason: reason)
        }
        .environment(\.proOffer, offer)
        .focusedSceneValue(offer)
        // Its board, on screen even on an iPhone, where the list would otherwise stay.
        .onChange(of: reveal) {
            guard let reveal else { return }
            selectedID = reveal.boardID.uuidString
            compactColumn = .detail
        }
        // Revealed on its own board only, and only until another is chosen: coming back, a board
        // opens as it always does.
        .onChange(of: selectedID) {
            if let reveal, reveal.boardID.uuidString != selectedID { self.reveal = nil }
        }
        // Choose the board the canvas shows: at launch, and when the chosen one is deleted. Not
        // when there was no choice, which on iPhone would push a canvas over the list.
        .onAppear {
            if chosen == nil { selectedID = boards.first?.id.uuidString ?? "" }
        }
        .onChange(of: boards.map(\.id)) {
            if !selectedID.isEmpty, chosen == nil {
                selectedID = boards.first?.id.uuidString ?? ""
            }
        }
    }
}

extension String {
    /// The string as a UUID, written back as its `uuidString`. A key path, so the list's selection
    /// binding compares equal from one body to the next and the list isn't re-rendered with it.
    fileprivate var uuid: UUID? {
        get { UUID(uuidString: self) }
        set { self = newValue?.uuidString ?? "" }
    }
}

#Preview {
    BoardsView()
        .previewNotes(seeded: true)
}
