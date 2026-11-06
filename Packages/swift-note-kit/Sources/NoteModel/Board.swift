import Foundation
import SwiftData

/// A canvas of its own: every note is on exactly one board.
///
/// Every stored property has a declaration-site default, like ``Note``'s, and the relationship is
/// optional, as CloudKit would require of it.
@Model
public final class Board {
    public var id: UUID = UUID()
    /// What the reader called it; their words, never localized. May be empty.
    public var name: String = ""
    /// Boards are listed oldest first.
    public var createdAt: Date = Date.now

    /// Deleting a board deletes its notes. Unordered: fetch notes by board and sort by `z`.
    @Relationship(deleteRule: .cascade, inverse: \Note.board)
    public var notes: [Note]? = []

    public init(name: String) {
        self.name = name
    }
}
