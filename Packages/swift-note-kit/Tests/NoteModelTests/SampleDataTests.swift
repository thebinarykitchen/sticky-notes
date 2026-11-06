import Foundation
import SwiftData
import Testing

@testable import NoteModel

/// What the App Store screenshots (`Screenshots/` in the app's repository) take for granted of
/// the boards they photograph.
struct SampleDataTests {
    /// Held, or the context goes with it.
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try .inMemory()
        SampleData.seedListing(in: container.mainContext)
    }

    private func board(_ name: String) throws -> Board {
        try #require(try context.fetch(FetchDescriptor<Board>()).first { $0.name == name })
    }

    /// A launch opens the first, and Make Notes fills the empty one.
    @Test func theListingsBoardsComeInOrder() throws {
        let boards = try context.fetch(
            FetchDescriptor<Board>(sortBy: [SortDescriptor(\.createdAt)]))
        #expect(boards.map(\.name) == ["Home", "Work", "Lisbon", "Groceries"])
        #expect(try board("Groceries").notes?.isEmpty == true)
    }

    @Test func everyColorIsOnTheFirstBoard() throws {
        let colors = Set(try board("Home").notes?.map(\.color) ?? [])
        #expect(colors == Set(NoteColor.allCases))
    }

    @Test func everyNoteIsASizeTheAppAllows() throws {
        for note in try context.fetch(FetchDescriptor<Note>()) {
            #expect(note.side == NoteGeometry.clampSide(note.side), "\(note.text)")
        }
    }

    @Test func aSecondSeedAddsNothing() throws {
        let count = try context.fetchCount(FetchDescriptor<Note>())
        SampleData.seedListingIfEmpty(in: context)
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == count)
    }
}
