import NoteModel
import SwiftData
import SwiftUI

/// A throwaway store for `#Preview`s. Not `#if DEBUG`: Release builds compile previews too.
enum PreviewNotes {
    /// The sample boards and notes, or one empty board: the app always has a board.
    static func container(seeded: Bool = false) -> ModelContainer {
        let container = try! ModelContainer.inMemory()
        if seeded {
            SampleData.seed(in: container.mainContext)
        } else {
            container.mainContext.insert(Board(name: "Board"))
            try! container.mainContext.save()
        }
        return container
    }

    /// Every board in `container`, oldest first.
    static func boards(in container: ModelContainer) -> [Board] {
        let descriptor = FetchDescriptor<Board>(sortBy: [SortDescriptor(\.createdAt)])
        return try! container.mainContext.fetch(descriptor)
    }
}

extension View {
    /// The store and container a canvas needs, in memory.
    func previewNotes(seeded: Bool) -> some View {
        previewNotes(PreviewNotes.container(seeded: seeded))
    }

    /// The store over `container`, the container, and Pro as the defaults have it.
    func previewNotes(_ container: ModelContainer) -> some View {
        environment(NoteStore(context: container.mainContext))
            .environment(Pro())
            .modelContainer(container)
    }
}
