import NoteModel
import SwiftUI

/// A lesson's gesture as a function of how far through its loop the demonstration is: where the
/// fingers are, and how the board looks under them — the values the real gesture puts on screen,
/// for ``DemonstrationLayer`` to draw with the pieces the canvas draws with. Pure.
///
/// A loop plays the gesture, holds what it left, puts the board back and rests, so both its ends
/// are the board as the reader finds it. Without a phase it is the still Reduce Motion shows: the
/// board at rest, each finger down where the gesture starts and the way it goes drawn out.
///
/// It takes its note off the board only while the note is away from rest — see ``isAway`` — so
/// whenever it is at rest, the note under the reader's finger is the board's own.
nonisolated struct Demonstration: Equatable {
    let lesson: Lesson
    /// How far through the loop, 0...1; nil for the still.
    let phase: Double?
    /// The practice board's size.
    let board: CGSize
    /// The note the gesture acts on, as it rests on the board. For the double tap, the note it
    /// adds, as it lands.
    let rest: Rest

    /// A note at rest.
    nonisolated struct Rest: Equatable {
        var center: CGPoint
        var side: Double
        var color: NoteColor
        var text: String
    }

    /// A fingertip over the board.
    nonisolated struct Finger: Equatable {
        var at: CGPoint
        var isDown: Bool
        /// 0...1: in before the gesture, and out once it has let go.
        var presence: Double
    }

    /// The way a finger goes, drawn as a dotted line.
    nonisolated struct Track: Equatable {
        var from: CGPoint
        var to: CGPoint
    }

    /// How the demonstrated note is drawn.
    nonisolated struct Look: Equatable {
        var center: CGPoint
        /// The side a pinch asks for; the note's own otherwise.
        var asked: Double
        var color: NoteColor
        var text: String
        /// Lifted off the board: held by a drag.
        var isRaised = false
        var isOverTrash = false
        /// Deleted — or, for the double tap, not added yet.
        var isGone = false
    }

    // MARK: - The loop

    /// One loop, in seconds.
    static func loop(of lesson: Lesson) -> Double {
        switch lesson {
        case .doubleTapToAdd: 3.6
        case .pinchToResize: 4.0
        case .dragToBin, .pinchToCrumple: 4.8
        }
    }

    /// When what the gesture does lands — the note added, resized or deleted — as the finger
    /// lets go.
    static func landing(of lesson: Lesson) -> Double {
        switch lesson {
        case .doubleTapToAdd: 0.8
        case .pinchToResize: 1.9
        case .dragToBin, .pinchToCrumple: 2.0
        }
    }

    /// When the board goes back as the reader found it.
    static func rewind(of lesson: Lesson) -> Double {
        switch lesson {
        case .doubleTapToAdd: 2.8
        case .pinchToResize: 3.2
        case .dragToBin, .pinchToCrumple: 3.9
        }
    }

    /// When the finger first presses.
    static func press(of lesson: Lesson) -> Double {
        switch lesson {
        case .doubleTapToAdd: 0.45
        case .dragToBin: 0.3
        case .pinchToResize, .pinchToCrumple: 0.35
        }
    }

    /// How long a finger takes to come or go.
    static let fade = 0.25

    /// How long the rewind's animation takes to put the note back, before the board has it again.
    static let settle = 0.6

    /// How long the demonstration goes on drawing its note once the board has it back, so the
    /// board's own is there before this one goes.
    private static let overlap = 0.1

    private var isStill: Bool { phase == nil }

    /// Seconds into the loop; none for the still.
    private var t: Double { (phase ?? 0) * Self.loop(of: lesson) }

    /// Whether the board has gone back, for the rewind to animate as one change.
    var isRewound: Bool { !isStill && t >= Self.rewind(of: lesson) }

    /// Whether the note is away from rest, and the demonstration draws it while the board's own
    /// hides: from the press until the rewind has settled. Never in the still, which leaves the
    /// note to the board.
    var isAway: Bool { isDrawn(until: Self.rewind(of: lesson) + Self.settle) }

    /// Whether the demonstration draws its note: while it is away, and a moment more.
    var drawsNote: Bool { isDrawn(until: Self.rewind(of: lesson) + Self.settle + Self.overlap) }

    private func isDrawn(until end: Double) -> Bool {
        !isStill && t >= Self.press(of: lesson) && t < end
    }

    // MARK: - Where things are

    /// Where the double tap lands.
    var spot: CGPoint { Lesson.place(Lesson.spot, in: board) }

    // MARK: - The hand

    var fingers: [Finger] {
        switch lesson {
        case .doubleTapToAdd:
            [
                finger(
                    at: spot, presence: arriving(0) * leaving(Self.landing(of: lesson)),
                    isDown: pressed(Self.press(of: lesson)..<0.55) || pressed(0.7..<0.8))
            ]
        case .dragToBin:
            [dragging(to: TrashZone.center(in: board))]
        case .pinchToResize, .pinchToCrumple:
            pinching
        }
    }

    /// How many taps the still marks: two for the double tap, which ``GhostHand`` rings twice.
    var taps: Int { lesson == .doubleTapToAdd ? 2 : 1 }

    var tracks: [Track] {
        switch lesson {
        case .doubleTapToAdd: []
        case .dragToBin: [Track(from: rest.center, to: TrashZone.center(in: board))]
        case .pinchToResize, .pinchToCrumple:
            [-1.0, 1.0].map { sign in
                Track(
                    from: pinchPoint(sign, reach: pinchReach.from),
                    to: pinchPoint(sign, reach: pinchReach.to))
            }
        }
    }

    private func dragging(to end: CGPoint) -> Finger {
        finger(
            at: Self.mix(rest.center, end, Self.ramp(t, from: 0.5, to: 1.9)),
            presence: arriving(0) * leaving(Self.landing(of: lesson)),
            isDown: pressed(Self.press(of: lesson)..<Self.landing(of: lesson)))
    }

    private var pinching: [Finger] {
        let reach = Self.mix(pinchReach.from, pinchReach.to, pinchProgress)
        return [-1.0, 1.0].map { sign in
            finger(
                at: pinchPoint(sign, reach: reach),
                presence: arriving(0) * leaving(Self.landing(of: lesson)),
                isDown: pressed(Self.press(of: lesson)..<Self.landing(of: lesson)))
        }
    }

    /// A finger as the still has it, down where the gesture starts, or as it is now.
    private func finger(at point: CGPoint, presence: Double, isDown: Bool) -> Finger {
        isStill
            ? Finger(at: point, isDown: true, presence: 1)
            : Finger(at: point, isDown: isDown, presence: presence)
    }

    /// The pinch's fingers sit on the note's diagonal, `reach` from its middle on each axis.
    private func pinchPoint(_ sign: Double, reach: Double) -> CGPoint {
        CGPoint(x: rest.center.x + sign * reach, y: rest.center.y + sign * reach)
    }

    /// From how far apart the fingers start to how far they end: spreading, they stay on the note
    /// as it grows; closing, they meet near its middle.
    private var pinchReach: (from: Double, to: Double) {
        lesson == .pinchToResize
            ? (0.18 * rest.side, 0.34 * NoteGeometry.clampSide(rest.side * Lesson.spread))
            : (0.3 * rest.side, 0.1 * rest.side)
    }

    private var pinchProgress: Double {
        lesson == .pinchToResize
            ? Self.ramp(t, from: 0.4, to: 1.8) : Self.ramp(t, from: 0.4, to: 1.9)
    }

    // MARK: - The board

    var look: Look {
        var look = Look(center: rest.center, asked: rest.side, color: rest.color, text: rest.text)
        if isStill {
            look.isGone = lesson == .doubleTapToAdd
            return look
        }
        let landing = Self.landing(of: lesson)
        let rewind = Self.rewind(of: lesson)
        switch lesson {
        case .doubleTapToAdd:
            look.isGone = t < landing || t >= rewind
        case .pinchToResize:
            if t < rewind {
                look.asked = Self.mix(rest.side, rest.side * Lesson.spread, pinchProgress)
            }
        case .dragToBin:
            look.isRaised = t >= 0.4 && t < landing
            if t < landing {
                look.center = fingers[0].at
                look.isOverTrash = showsBin && TrashZone.contains(fingers[0].at, in: board)
            }
            look.isGone = t >= landing && t < rewind
        case .pinchToCrumple:
            if t < landing {
                look.asked = Self.mix(rest.side, rest.side * Lesson.squeeze, pinchProgress)
            }
            look.isGone = t >= landing && t < rewind
        }
        return look
    }

    /// The bin shows while the note is dragged — and in the still, for the way there to point at.
    var showsBin: Bool {
        lesson == .dragToBin && (isStill || (t >= 0.45 && t < Self.landing(of: lesson)))
    }

    var offersUndo: Bool {
        (lesson == .dragToBin || lesson == .pinchToCrumple) && !isStill
            && t >= Self.landing(of: lesson) && t < Self.rewind(of: lesson)
    }

    // MARK: - Easing

    private func arriving(_ start: Double) -> Double {
        Self.ramp(t, from: start, to: start + Self.fade)
    }

    private func leaving(_ start: Double) -> Double {
        1 - Self.ramp(t, from: start, to: start + Self.fade)
    }

    private func pressed(_ span: Range<Double>) -> Bool { span.contains(t) }

    /// Smoothstep from `start` to `end`, flat outside them.
    private static func ramp(_ value: Double, from start: Double, to end: Double) -> Double {
        let x = min(max((value - start) / (end - start), 0), 1)
        return x * x * (3 - 2 * x)
    }

    private static func mix(_ a: Double, _ b: Double, _ share: Double) -> Double {
        a + (b - a) * share
    }

    private static func mix(_ a: CGPoint, _ b: CGPoint, _ share: Double) -> CGPoint {
        CGPoint(x: mix(a.x, b.x, share), y: mix(a.y, b.y, share))
    }
}

extension Demonstration.Rest {
    /// `note` where its lesson puts it on a board of `size`.
    init(_ note: Lesson.PracticeNote, on size: CGSize) {
        self.init(
            center: Lesson.place(note.offset, in: size), side: note.side, color: note.color,
            text: String(localized: note.text))
    }

    /// The note the double tap adds, as the store adds it: centred on the spot — moved as little
    /// as keeps it wholly on the board — in the color after the board's newest note's.
    static func added(at spot: CGPoint, on size: CGSize, after newest: NoteColor?) -> Self {
        Self(
            center: NoteGeometry.clamp(
                spot, side: NoteGeometry.defaultSide, in: CGRect(origin: .zero, size: size)),
            side: NoteGeometry.defaultSide, color: newest?.next ?? .yellow,
            text: String(localized: Lesson.added))
    }
}
