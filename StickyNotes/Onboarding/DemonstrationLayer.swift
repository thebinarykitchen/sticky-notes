import NoteModel
import SwiftUI

/// A practice board's demonstration, drawn over the board with the canvas's own pieces: its note
/// on paper as the canvas draws one — held, pinched, crumpled or written on — with the bin, the
/// menu and the offer to undo as they come, and the hand doing it. Loops for as long as it is
/// there; under Reduce Motion it holds still.
///
/// While the demonstration has its note away from rest, the practice board hides its own; the
/// rest of the board shows through.
struct DemonstrationLayer: View {
    let lesson: Lesson
    let rest: Demonstration.Rest
    /// The practice board's size.
    let board: CGSize
    /// Called as the demonstration takes its note away from rest, and gives it back — see
    /// ``Demonstration/isAway``.
    var onAway: (Bool) -> Void = { _ in }

    @Environment(\.motion) private var motion
    /// When the loop began.
    @State private var start = Date.now

    var body: some View {
        Group {
            if motion.demonstrates {
                // A frame at a time, and not animated: what a finger holds follows it undamped.
                TimelineView(.animation) { context in
                    let demonstration = demonstration(at: context.date)
                    DemonstrationFrame(demonstration: demonstration, isStill: false)
                        .onChange(of: demonstration.isAway) { _, isAway in onAway(isAway) }
                }
            } else {
                DemonstrationFrame(
                    demonstration: Demonstration(
                        lesson: lesson, phase: nil, board: board, rest: rest),
                    isStill: true)
            }
        }
        .allowsHitTesting(false)
        // The instruction says it all for assistive technologies; the real note stays theirs.
        .accessibilityHidden(true)
    }

    private func demonstration(at date: Date) -> Demonstration {
        let loop = Demonstration.loop(of: lesson)
        let elapsed = max(date.timeIntervalSince(start), 0)
        return Demonstration(
            lesson: lesson, phase: elapsed.truncatingRemainder(dividingBy: loop) / loop,
            board: board, rest: rest)
    }
}

/// One frame of a ``Demonstration``. Its beats — the note lifting, landing, going, coming back —
/// animate as the canvas animates them; between beats, each frame is drawn as it is.
private struct DemonstrationFrame: View {
    let demonstration: Demonstration
    let isStill: Bool

    @Environment(\.motion) private var motion

    private var board: CGSize { demonstration.board }

    var body: some View {
        let look = demonstration.look
        ZStack {
            ZStack {
                note(look)
                // Above the note, as the canvas draws it above a held one.
                if demonstration.showsBin {
                    TrashZone(isHot: look.isOverTrash, canvas: board, playsFeedback: false)
                        .transition(.opacity)
                }
                banner
            }
            .animation(motion.lift, value: demonstration.showsBin)
            .animation(motion.edit, value: demonstration.offersUndo)
            .animation(motion.edit, value: look.isGone)
            // The board going back as one change, the way an undo puts it back.
            .animation(motion.edit, value: demonstration.isRewound)
            // Out of the beats' animations: between loops it goes back to where it starts
            // unseen, and animated, it was seen on its way.
            GhostHand(demonstration: demonstration, isStill: isStill)
        }
        .frame(width: board.width, height: board.height)
    }

    /// The note on the board, as the canvas draws one — or as it draws a held one.
    private func note(_ look: Demonstration.Look) -> some View {
        // Wrapped, so it arrives and leaves about its own centre rather than the board's.
        ZStack {
            if demonstration.drawsNote && !look.isGone {
                NoteView.words(look.text)
                    .notePaper(side: NoteGeometry.clampSide(look.asked), color: look.color)
                    .modifier(PinchLook(asked: look.asked))
                    .modifier(HeldLook(isRaised: look.isRaised, isOverTrash: look.isOverTrash))
                    .transition(motion.arrival)
            }
        }
        .position(look.center)
    }

    /// "Note deleted · Undo", where the canvas puts it. Only a picture: nothing here takes a tap.
    private var banner: some View {
        ZStack(alignment: .bottom) {
            if demonstration.offersUndo {
                UndoBanner {}
                    .padding(.bottom, 24)
                    .transition(motion.banner)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

#Preview("Each lesson") {
    @Previewable @State var lesson = Lesson.dragToBin
    let board = CGSize(width: 340, height: 440)

    VStack {
        Picker(selection: $lesson) {
            ForEach(Lesson.allCases) { Text($0.title).tag($0) }
        } label: {
            Text(verbatim: "Lesson")
        }
        DemonstrationLayer(
            lesson: lesson,
            rest: lesson.demonstrated.map { Demonstration.Rest(lesson.practice[$0], on: board) }
                ?? .added(at: Lesson.place(Lesson.spot, in: board), on: board, after: .pink),
            board: board
        )
        .id(lesson)
        .frame(width: board.width, height: board.height)
        .background(.background.secondary)
    }
}
