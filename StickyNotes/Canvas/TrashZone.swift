import SwiftUI

/// The target a note is dragged onto to delete it. Drawn only while a note is being dragged,
/// near the bottom of the canvas; it reaches a little past what it draws, so a drop doesn't
/// have to be exact. What decides a delete is the finger, not the note: a big note's edge
/// brushing the bin shouldn't throw it away.
struct TrashZone: View {
    let isHot: Bool
    let canvas: CGSize
    /// Off for the tour's demonstration, whose bin turns hot on every loop.
    var playsFeedback = true

    @Environment(\.motion) private var motion

    nonisolated static let diameter: CGFloat = 64
    /// From the bottom of the canvas to the bottom of the bin.
    nonisolated static let bottomInset: CGFloat = 40
    /// How far past the drawn circle a finger still counts as over it.
    nonisolated static let reach: CGFloat = 28

    nonisolated static func center(in canvas: CGSize) -> CGPoint {
        CGPoint(x: canvas.width / 2, y: canvas.height - bottomInset - diameter / 2)
    }

    /// Whether a finger at `point`, in canvas coordinates, is over the bin.
    nonisolated static func contains(_ point: CGPoint, in canvas: CGSize) -> Bool {
        let center = center(in: canvas)
        return hypot(point.x - center.x, point.y - center.y) <= diameter / 2 + reach
    }

    var body: some View {
        Image(systemName: isHot ? "trash.fill" : "trash")
            .font(.title2)
            .foregroundStyle(isHot ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: Self.diameter, height: Self.diameter)
            .background(
                isHot ? AnyShapeStyle(.red) : AnyShapeStyle(.regularMaterial), in: .circle
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            .scaleEffect(isHot ? 1.2 : 1)
            .animation(motion.lift, value: isHot)
            // Arms rather than commits, and the bin outlives the drop, so the tap lands.
            .sensoryFeedback(.selection, trigger: isHot) { _, _ in playsFeedback }
            // A drag target only; VoiceOver deletes through the note's own action.
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .position(Self.center(in: canvas))
    }
}

#Preview {
    HStack {
        TrashZone(isHot: false, canvas: CGSize(width: 120, height: 160))
        TrashZone(isHot: true, canvas: CGSize(width: 120, height: 160))
    }
    .frame(width: 240, height: 160)
}
