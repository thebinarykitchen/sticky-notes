import SwiftUI

/// How fast a held note's finger scrolls the canvas, in points a second: nothing away from the
/// edges, and within `band` of one, faster the deeper it goes, up to `maxSpeed` at the edge —
/// and past it, where a Mac's pointer can go.
nonisolated enum Autoscroll {
    static let band: CGFloat = 60
    static let maxSpeed: CGFloat = 1_200

    static func velocity(at finger: CGPoint, in canvas: CGSize) -> CGVector {
        CGVector(
            dx: speed(at: finger.x, across: canvas.width),
            dy: speed(at: finger.y, across: canvas.height))
    }

    /// An axis too short for a band at each end doesn't scroll.
    private static func speed(at position: CGFloat, across length: CGFloat) -> CGFloat {
        guard length > 2 * band else { return 0 }
        if position < band { return -maxSpeed * ramp((band - position) / band) }
        if position > length - band { return maxSpeed * ramp((position - length + band) / band) }
        return 0
    }

    /// Gentle at the band's inner edge, so brushing it barely moves the canvas.
    private static func ramp(_ depth: CGFloat) -> CGFloat {
        let depth = min(max(depth, 0), 1)
        return depth * depth
    }
}

/// Runs `step` once a frame while `isRunning`, with the seconds since the frame before. A finger
/// held still sends no events, so autoscroll keeps its own time.
struct AutoscrollClock: ViewModifier {
    let isRunning: Bool
    let step: (_ seconds: Double) -> Void

    func body(content: Content) -> some View {
        content.background {
            TimelineView(.animation(paused: !isRunning)) { context in
                Color.clear.onChange(of: context.date) { last, now in
                    // Capped: the first frame after a pause measures from the last one before it.
                    step(min(now.timeIntervalSince(last), 1.0 / 30))
                }
            }
        }
    }
}
