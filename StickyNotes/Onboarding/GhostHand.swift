import SwiftUI

/// Fingertips, and the ways they go, traced over a practice board for one frame of a
/// ``Demonstration``. Gray with a white rim, so they show on the board in light and dark and on
/// a note's paper alike.
struct GhostHand: View {
    let demonstration: Demonstration
    /// The still Reduce Motion shows, rather than a frame of the loop: arrowheads give the way
    /// each finger goes.
    let isStill: Bool

    @Environment(\.motion) private var motion

    /// Not scaled with text size.
    private static let fingertip: CGFloat = 40

    var body: some View {
        ZStack {
            ForEach(Array(demonstration.tracks.enumerated()), id: \.offset) { _, track in
                path(track)
                if isStill { head(track) }
            }
            ForEach(Array(demonstration.fingers.enumerated()), id: \.offset) { _, finger in
                ring(finger)
            }
        }
        .allowsHitTesting(false)
        // The instruction says it all for assistive technologies.
        .accessibilityHidden(true)
    }

    private func ring(_ finger: Demonstration.Finger) -> some View {
        Circle()
            .fill(.gray.opacity(finger.isDown ? 0.45 : 0.3))
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
            .overlay {
                if let hold = finger.hold {
                    Circle()
                        .trim(from: 0, to: hold)
                        .stroke(.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(-6)
                }
            }
            .overlay {
                // A second ring round the first: tap twice.
                if isStill && demonstration.taps > 1 {
                    Circle()
                        .strokeBorder(.gray.opacity(0.6), lineWidth: 1.5)
                        .padding(-8)
                }
            }
            .frame(width: Self.fingertip, height: Self.fingertip)
            .scaleEffect(finger.isDown ? 0.85 : 1)
            .animation(motion.press, value: finger.isDown)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .opacity(finger.presence)
            .position(finger.at)
    }

    /// Dotted, under Reduce Motion too.
    private func path(_ track: Demonstration.Track) -> some View {
        Path {
            $0.move(to: track.from)
            $0.addLine(to: track.to)
        }
        .stroke(
            .gray.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))
    }

    private func head(_ track: Demonstration.Track) -> some View {
        Image(systemName: "arrowtriangle.right.fill")
            .font(.system(size: 10))
            .foregroundStyle(.gray)
            .rotationEffect(.radians(atan2(track.to.y - track.from.y, track.to.x - track.from.x)))
            .position(track.to)
    }
}

#Preview("Each gesture, at a point in its loop") {
    @Previewable @State var phase = 0.3
    let board = CGSize(width: 340, height: 300)

    ScrollView {
        VStack(spacing: 12) {
            ForEach(Lesson.allCases) { lesson in
                let rest = Demonstration.Rest(
                    lesson.practice[lesson.demonstrated ?? 0], on: board)
                GhostHand(
                    demonstration: Demonstration(
                        lesson: lesson, phase: phase, board: board, rest: rest),
                    isStill: false
                )
                .frame(width: board.width, height: board.height)
                .background(.background.secondary)
                .overlay(alignment: .bottomLeading) {
                    Text(lesson.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
        }
    }
    .safeAreaInset(edge: .bottom) {
        Slider(value: $phase)
            .padding()
            .background(.bar)
    }
}
