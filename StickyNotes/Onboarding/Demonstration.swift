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
        /// How far a touch and hold has got, 0...1; nil for any other touch.
        var hold: Double?
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
        /// Lifted off the board: held by a drag, or by its menu.
        var isRaised = false
        var isOverTrash = false
        /// In the middle, being written on, with the rest of the board blurred.
        var isWriting = false
        /// Deleted — or, for the double tap, not added yet.
        var isGone = false
    }

    // MARK: - The loop

    /// One loop, in seconds.
    static func loop(of lesson: Lesson) -> Double {
        switch lesson {
        case .doubleTapToAdd: 3.6
        case .tapToWrite: 5.8
        case .dragToMove: 4.2
        case .pinchToResize: 4.0
        case .holdForMenu: 5.4
        case .dragToBin, .pinchToCrumple: 4.8
        }
    }

    /// When what the gesture does lands — the note added, opened for writing, put down, resized,
    /// recolored or deleted — as the finger lets go.
    static func landing(of lesson: Lesson) -> Double {
        switch lesson {
        case .doubleTapToAdd: 0.8
        case .tapToWrite: 0.6
        case .pinchToResize: 1.9
        case .dragToMove, .dragToBin, .pinchToCrumple: 2.0
        case .holdForMenu: 2.1
        }
    }

    /// When the board goes back as the reader found it.
    static func rewind(of lesson: Lesson) -> Double {
        switch lesson {
        case .doubleTapToAdd: 2.8
        case .tapToWrite: 5.1
        case .dragToMove: 3.4
        case .pinchToResize: 3.2
        case .holdForMenu: 4.6
        case .dragToBin, .pinchToCrumple: 3.9
        }
    }

    /// When the finger first presses.
    static func press(of lesson: Lesson) -> Double {
        switch lesson {
        case .doubleTapToAdd, .tapToWrite: 0.45
        case .dragToMove, .dragToBin: 0.3
        case .pinchToResize, .pinchToCrumple, .holdForMenu: 0.35
        }
    }

    /// How long a finger takes to come or go.
    static let fade = 0.25

    /// How long the rewind's animation takes to put the note back, before the board has it again.
    static let settle = 0.6

    /// How long the demonstration goes on drawing its note once the board has it back, so the
    /// board's own is there before this one goes.
    private static let overlap = 0.1

    /// The writing, after the tap that starts it: when the words start and stop coming, and when
    /// a tap on the blur ends it.
    private static let typing = 1.0...3.0
    private static let writingEnds = 3.85

    /// The menu, after the hold that opens it: when it is up, and when the color picked from it
    /// lands; a tap outside it puts it away.
    private static let menuOpens = 1.0
    private static let menuCloses = 3.25

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

    /// Where the drag puts its note down.
    var destination: CGPoint {
        let fit = Lesson.fit(in: board)
        return CGPoint(
            x: rest.center.x + Lesson.travel.width * fit,
            y: rest.center.y + Lesson.travel.height * fit)
    }

    /// Where a tap ends the writing: on the blur, in a corner the middle note never reaches.
    var corner: CGPoint { CGPoint(x: 44, y: 44) }

    /// Where a tap puts the menu away: on the board, clear of the menu and the notes.
    var outside: CGPoint { CGPoint(x: board.width - 44, y: 44) }

    var menu: Menu { Menu(for: rest, on: board) }

    /// The stand-in for the note's menu, under the note — or over it, where there's no room below.
    nonisolated struct Menu: Equatable {
        static let width: CGFloat = 200
        static let rowHeight: CGFloat = 36
        static let paletteHeight: CGFloat = 44
        static let gap: CGFloat = 12
        /// Make Bigger and Make Smaller, the colors, then Delete, as the menu has them.
        static var height: CGFloat { 3 * rowHeight + paletteHeight }

        let frame: CGRect

        init(for note: Rest, on board: CGSize) {
            let below = note.center.y + note.side / 2 + Self.gap
            let above = note.center.y - note.side / 2 - Self.gap - Self.height
            frame = CGRect(
                x: min(max(note.center.x - Self.width / 2, 8), board.width - Self.width - 8),
                y: below + Self.height <= board.height - 8 ? below : above,
                width: Self.width, height: Self.height)
        }

        /// The middle of the swatch for `color`: the colors share the row equally. The four every
        /// note is handed, not all eight, which wouldn't fit a swatch apiece in the picture.
        func swatch(_ color: NoteColor) -> CGPoint {
            let colors = NoteColor.handedOut
            let slot = frame.width / CGFloat(colors.count)
            let index = CGFloat(colors.firstIndex(of: color) ?? 0)
            return CGPoint(
                x: frame.minX + slot * (index + 0.5),
                y: frame.minY + 2 * Self.rowHeight + Self.paletteHeight / 2)
        }
    }

    // MARK: - The hand

    var fingers: [Finger] {
        switch lesson {
        case .doubleTapToAdd:
            [
                finger(
                    at: spot, presence: arriving(0) * leaving(Self.landing(of: lesson)),
                    isDown: pressed(Self.press(of: lesson)..<0.55) || pressed(0.7..<0.8))
            ]
        case .tapToWrite:
            // The same finger taps the note, then the blur.
            if isStill || t < 2 {
                [
                    finger(
                        at: rest.center, presence: arriving(0) * leaving(Self.landing(of: lesson)),
                        isDown: pressed(Self.press(of: lesson)..<Self.landing(of: lesson)))
                ]
            } else {
                [
                    finger(
                        at: corner, presence: arriving(3.3) * leaving(Self.writingEnds),
                        isDown: pressed(3.7..<Self.writingEnds))
                ]
            }
        case .dragToMove:
            [dragging(to: destination)]
        case .dragToBin:
            [dragging(to: TrashZone.center(in: board))]
        case .pinchToResize, .pinchToCrumple:
            pinching
        case .holdForMenu:
            [holding]
        }
    }

    /// How many taps the still marks: two for the double tap, which ``GhostHand`` rings twice.
    var taps: Int { lesson == .doubleTapToAdd ? 2 : 1 }

    var tracks: [Track] {
        switch lesson {
        case .doubleTapToAdd, .tapToWrite, .holdForMenu: []
        case .dragToMove: [Track(from: rest.center, to: destination)]
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

    /// Down on the note until the menu opens; across to the color, and a tap on it; then a tap
    /// outside, which puts the menu away.
    private var holding: Finger {
        let swatch = menu.swatch(Lesson.picked)
        let hold = Self.press(of: lesson)..<1.05
        if isStill {
            return Finger(at: rest.center, isDown: true, presence: 1, hold: 1)
        }
        if t >= 2.5 {
            return finger(
                at: outside, presence: arriving(2.7) * leaving(Self.menuCloses),
                isDown: pressed(3.1..<Self.menuCloses))
        }
        return Finger(
            at: Self.mix(rest.center, swatch, Self.ramp(t, from: 1.2, to: 1.8)),
            isDown: pressed(hold) || pressed(1.95..<Self.landing(of: lesson)),
            presence: arriving(0) * leaving(Self.landing(of: lesson)),
            hold: hold.contains(t)
                ? min(1, (t - hold.lowerBound) / (Self.menuOpens - hold.lowerBound)) : nil)
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
        case .tapToWrite:
            look.isWriting = t >= landing && t < Self.writingEnds
            if t >= Self.typing.lowerBound && t < rewind { look.text = rest.text + "\n" + typed }
        case .dragToMove:
            look.isRaised = t >= 0.4 && t < landing
            if t < rewind { look.center = fingers[0].at }
        case .pinchToResize:
            if t < rewind {
                look.asked = Self.mix(rest.side, rest.side * Lesson.spread, pinchProgress)
            }
        case .holdForMenu:
            look.isRaised = t >= 0.9 && t < Self.menuCloses
            if t >= landing && t < rewind { look.color = Lesson.picked }
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

    var showsMenu: Bool {
        lesson == .holdForMenu && !isStill && t >= Self.menuOpens && t < Self.menuCloses
    }

    var offersUndo: Bool {
        (lesson == .dragToBin || lesson == .pinchToCrumple) && !isStill
            && t >= Self.landing(of: lesson) && t < Self.rewind(of: lesson)
    }

    /// What has been written on the note by now.
    private var typed: String {
        let written = String(localized: Lesson.written)
        let typing = Self.typing
        let share = min(
            max((t - typing.lowerBound) / (typing.upperBound - typing.lowerBound), 0), 1)
        return String(written.prefix(Int((Double(written.count) * share).rounded(.down))))
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
