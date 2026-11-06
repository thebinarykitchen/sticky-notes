import CoreGraphics

/// How big a note may be, and where a new one may go. In the model rather than the app so the
/// store clamps every write with the same rules the view draws by. A board has no edges, so a
/// note may sit anywhere; only a new one is kept wholly in view, and notes that arrive together
/// start there.
nonisolated public enum NoteGeometry {
    // Sides are `Double`, as `Note.side` stores them, so nothing compares a `CGFloat` to one:
    // `#expect` reports an implicitly converted `Double == CGFloat` as false even when equal.

    /// A new note's width and height, in points. Notes are square.
    public static let defaultSide: Double = 160
    /// The smallest and largest a note can be made.
    public static let minSide: Double = 100
    public static let maxSide: Double = 320
    /// How much one "Make Bigger" or "Make Smaller" changes a note's side.
    public static let step: Double = 40
    /// A pinch that would take a note below this side crumples it, and letting go deletes it.
    /// Between this and ``minSide`` the note holds at the minimum.
    public static let crumpleSide: Double = 60
    /// The space between notes that arrive together, and between their block and the screen's
    /// edges.
    public static let gap: Double = 16

    /// Whether a pinch that has taken a note to `side`, unclamped, has crumpled it.
    public static func crumples(_ side: Double) -> Bool {
        side < crumpleSide
    }

    /// `side`, held between ``minSide`` and ``maxSide``.
    public static func clampSide(_ side: Double) -> Double {
        min(max(side, minSide), maxSide)
    }

    /// `point`, moved the least distance that keeps a whole note of `side` inside `bounds`.
    /// Centred on an axis where `bounds` is narrower than the note.
    public static func clamp(_ point: CGPoint, side: Double, in bounds: CGRect) -> CGPoint {
        CGPoint(
            x: clamp(point.x, side: side, from: bounds.minX, to: bounds.maxX),
            y: clamp(point.y, side: side, from: bounds.minY, to: bounds.maxY)
        )
    }

    private static func clamp(
        _ value: CGFloat, side: CGFloat, from low: CGFloat, to high: CGFloat
    ) -> CGFloat {
        let half = side / 2
        guard high - low > side else { return (low + high) / 2 }
        return min(max(value, low + half), high - half)
    }

    /// The centres of `count` notes of `side` that arrive together, in reading order: left to
    /// right, then down. They make a block as near square as fits across `bounds` with a
    /// ``gap`` at each side, centred in `bounds`, or a gap below its top where the block is too
    /// tall for that. Across bounds narrower than a note, one centred column, as
    /// ``clamp(_:side:in:)`` centres a note.
    public static func rows(of count: Int, side: Double, in bounds: CGRect) -> [CGPoint] {
        guard count > 0 else { return [] }
        let pitch = side + gap
        let fit = Int(((bounds.width - gap) / pitch).rounded(.down))
        let columns = max(1, min(fit, Int(Double(count).squareRoot().rounded(.up))))
        let rows = (count + columns - 1) / columns
        let left = bounds.midX - (Double(columns) * pitch - gap) / 2
        let top = max(bounds.midY - (Double(rows) * pitch - gap) / 2, bounds.minY + gap)
        return (0..<count).map { index in
            CGPoint(
                x: left + side / 2 + Double(index % columns) * pitch,
                y: top + side / 2 + Double(index / columns) * pitch)
        }
    }
}
