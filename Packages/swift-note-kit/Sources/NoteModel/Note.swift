import Foundation
import SwiftData

/// A sticky note on the canvas.
///
/// Every stored property has a declaration-site default, so a later lightweight migration — or
/// CloudKit, should the store ever sync — can add rows without an initializer's help.
@Model
public final class Note {
    public var id: UUID = UUID()
    public var text: String = ""
    /// The centre, in board points. A board has no edges; it opens with (0, 0) at the top-left
    /// of the canvas.
    public var x: Double = 0
    public var y: Double = 0
    /// ``NoteColor`` raw value. Stored as a string so it stays queryable and a renamed case
    /// can't silently renumber.
    public var colorRaw: String = NoteColor.yellow.rawValue
    /// Width and height, in points; always within ``NoteGeometry/minSide`` and
    /// ``NoteGeometry/maxSide``.
    public var side: Double = NoteGeometry.defaultSide
    /// Stacking order: higher draws on top.
    public var z: Int = 0
    public var createdAt: Date = Date.now
    /// The board it's on. Optional, as CloudKit would require; the store never leaves a note
    /// without one.
    public var board: Board?

    public init(center: CGPoint, color: NoteColor, z: Int, text: String = "") {
        self.x = center.x
        self.y = center.y
        self.colorRaw = color.rawValue
        self.z = z
        self.text = text
    }

    public var center: CGPoint {
        get { CGPoint(x: x, y: y) }
        set {
            x = newValue.x
            y = newValue.y
        }
    }

    /// Falls back to yellow for a raw value this build doesn't know.
    public var color: NoteColor {
        get { NoteColor(rawValue: colorRaw) ?? .yellow }
        set { colorRaw = newValue.rawValue }
    }

    /// Notes on any board whose text holds `query`, ignoring case and accents as the reader's
    /// language does: top to bottom, then left to right, each with its board fetched alongside.
    public static func search(_ query: String) -> FetchDescriptor<Note> {
        var descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.text.localizedStandardContains(query) },
            sortBy: [SortDescriptor(\.y), SortDescriptor(\.x)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.board]
        return descriptor
    }
}

/// The colors a note comes in. A new note gets one of ``handedOut``; the rest are only ever
/// chosen.
public enum NoteColor: String, CaseIterable, Codable, Sendable {
    case yellow
    case pink
    case blue
    case green
    case orange
    case purple
    case teal
    case gray

    /// The colors new notes are given, in this order.
    nonisolated public static let handedOut: [NoteColor] = [.yellow, .pink, .blue, .green]

    /// The color the note after this one is given: the next of ``handedOut``, wrapping around,
    /// or the first after a color that isn't handed out.
    public var next: NoteColor {
        let all = Self.handedOut
        guard let index = all.firstIndex(of: self) else { return all[0] }
        return all[(index + 1) % all.count]
    }
}
