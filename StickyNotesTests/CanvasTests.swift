import CoreGraphics
import NoteModel
import Observation
import SwiftData
import SwiftUI
import Testing
import os

@testable import StickyNotes

struct DragToMoveTests {
    @Test func aNoteLandsWhereTheFingerTookIt() {
        let landed = DragToMove.drop(
            from: CGPoint(x: 100, y: 200), by: CGSize(width: 30, height: -50))
        #expect(landed == CGPoint(x: 130, y: 150))
    }

    /// A board has no edges: nothing pulls a note back.
    @Test func aDropPastTheScreenStaysThere() {
        let landed = DragToMove.drop(from: .zero, by: CGSize(width: -500, height: -500))
        #expect(landed == CGPoint(x: -500, y: -500))
    }

    /// The board autoscroll moved under the finger counts as much as the finger's own travel.
    @Test func aDropCountsTheBoardThatScrolledUnderTheFinger() {
        let drag = NoteDrag()
        drag.scroll(by: CGSize(width: 900, height: 0))
        drag.scroll(by: CGSize(width: 100, height: -20))
        let travel = drag.travel(CGSize(width: 40, height: 10))
        #expect(travel == CGSize(width: 1_040, height: -10))
    }
}

struct NoteDragTests {
    let canvas = CGSize(width: 400, height: 800)

    /// The canvas's body re-runs on any change to the drag, so a finger moving short of the bin
    /// mustn't make one; only reaching the bin does.
    @Test func onlyReachingTheBinChangesAnything() {
        let drag = NoteDrag()
        drag.track(CGPoint(x: 100, y: 100), in: canvas)
        let changed = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = (drag.isActive, drag.isOverTrash)
        } onChange: {
            changed.withLock { $0 = true }
        }

        drag.track(CGPoint(x: 300, y: 400), in: canvas)
        #expect(!changed.withLock { $0 })

        drag.track(TrashZone.center(in: canvas), in: canvas)
        #expect(changed.withLock { $0 })
        #expect(drag.isOverTrash)
    }

    @Test func endingClearsBoth() {
        let drag = NoteDrag()
        drag.track(TrashZone.center(in: canvas), in: canvas)
        drag.end()
        #expect(!drag.isActive)
        #expect(!drag.isOverTrash)
    }

    @Test func endingLetsGoOfTheNoteAndForgetsTheTravel() {
        let drag = NoteDrag()
        drag.lift(Note(center: .zero, color: .yellow, z: 0), at: CGPoint(x: 100, y: 100))
        drag.track(CGPoint(x: 150, y: 300), translation: CGSize(width: 50, height: 200), in: canvas)
        drag.scroll(by: CGSize(width: 300, height: 0))
        drag.end()
        #expect(drag.held == nil)
        #expect(drag.translation == .zero)
        #expect(drag.travel(.zero) == .zero)
    }

    @Test func aFingerInAnEdgeBandAutoscrolls() {
        let drag = NoteDrag()
        drag.track(CGPoint(x: 200, y: 400), in: canvas)
        #expect(!drag.isAutoscrolling)
        drag.track(CGPoint(x: canvas.width - 10, y: 400), in: canvas)
        #expect(drag.isAutoscrolling)
    }

    /// A note picked up near an edge doesn't set the canvas off until the finger has been away
    /// from the edges and comes back.
    @Test func aBandCountsOnlyOnceTheFingerHasBeenOutsideIt() {
        let drag = NoteDrag()
        drag.track(CGPoint(x: canvas.width - 10, y: 400), in: canvas)
        #expect(!drag.isAutoscrolling)
        drag.track(CGPoint(x: 200, y: 400), in: canvas)
        drag.track(CGPoint(x: canvas.width - 10, y: 400), in: canvas)
        #expect(drag.isAutoscrolling)
    }

    /// The bin sits in the bottom band; aiming at it mustn't scroll the canvas away.
    @Test func overTheBinNothingScrolls() {
        let drag = NoteDrag()
        drag.track(CGPoint(x: 200, y: 400), in: canvas)
        let bin = TrashZone.center(in: canvas)
        let inTheBand = CGPoint(x: bin.x, y: canvas.height - Autoscroll.band / 2)
        #expect(TrashZone.contains(inTheBand, in: canvas))
        drag.track(inTheBand, in: canvas)
        #expect(!drag.isAutoscrolling)
    }

    /// Only a pinch on the held note reaches its stand-in.
    @Test func onlyTheHeldNotesPinchCounts() {
        let drag = NoteDrag()
        let held = Note(center: .zero, color: .yellow, z: 0)
        drag.lift(held, at: .zero)
        drag.pinch(Note(center: .zero, color: .pink, z: 1), by: 2)
        #expect(drag.magnification == 1)
        drag.pinch(held, by: 0.1)
        #expect(drag.magnification == 0.1)
        #expect(drag.isCrumpled)
    }
}

struct AutoscrollTests {
    let canvas = CGSize(width: 400, height: 800)

    @Test func theMiddleDoesntScroll() {
        #expect(Autoscroll.velocity(at: CGPoint(x: 200, y: 400), in: canvas) == .zero)
    }

    @Test func eachEdgeScrollsTowardItself() {
        let inset: CGFloat = 10
        #expect(Autoscroll.velocity(at: CGPoint(x: inset, y: 400), in: canvas).dx < 0)
        #expect(
            Autoscroll.velocity(at: CGPoint(x: canvas.width - inset, y: 400), in: canvas).dx > 0)
        #expect(Autoscroll.velocity(at: CGPoint(x: 200, y: inset), in: canvas).dy < 0)
        #expect(
            Autoscroll.velocity(at: CGPoint(x: 200, y: canvas.height - inset), in: canvas).dy > 0)
    }

    @Test func deeperIntoTheBandIsFaster() {
        let shallow = Autoscroll.velocity(at: CGPoint(x: canvas.width - 50, y: 400), in: canvas)
        let deep = Autoscroll.velocity(at: CGPoint(x: canvas.width - 5, y: 400), in: canvas)
        #expect(0 < shallow.dx && shallow.dx < deep.dx)
    }

    /// A Mac's pointer can leave the window mid-drag.
    @Test func pastTheEdgeIsFullSpeed() {
        let past = Autoscroll.velocity(at: CGPoint(x: canvas.width + 200, y: -300), in: canvas)
        #expect(past == CGVector(dx: Autoscroll.maxSpeed, dy: -Autoscroll.maxSpeed))
    }

    @Test func aCanvasTooNarrowForTwoBandsDoesntScrollAcross() {
        let narrow = CGSize(width: Autoscroll.band * 2, height: 800)
        #expect(Autoscroll.velocity(at: CGPoint(x: 5, y: 400), in: narrow).dx == 0)
    }
}

/// On an iPhone 17's canvas, below the navigation bar: what a scroll view there reports.
struct CanvasScrollTests {
    let insets = EdgeInsets(top: 116, leading: 0, bottom: 34, trailing: 0)
    let viewport = CGSize(width: 402, height: 724)
    /// Where the seeded board's notes are.
    let notes = CGRect(x: 20, y: 100, width: 320, height: 520)

    /// What a scroll view reports with `point` at the visible top-left: its raw offset is that
    /// less the insets.
    private func geometry(
        _ scroll: CanvasScroll, at point: CGPoint, insets: EdgeInsets? = nil,
        viewport: CGSize? = nil
    ) -> ScrollGeometry {
        let insets = insets ?? self.insets
        return ScrollGeometry(
            contentOffset: CGPoint(x: point.x - insets.leading, y: point.y - insets.top),
            contentSize: scroll.extent.size, contentInsets: insets,
            containerSize: viewport ?? self.viewport)
    }

    /// `scroll` as a scroll view opens it: sized, scrolled to board (0, 0), landed.
    private func opened(insets: EdgeInsets? = nil, viewport: CGSize? = nil) -> CanvasScroll {
        let scroll = CanvasScroll()
        scroll.observe(
            geometry(scroll, at: .zero, insets: insets, viewport: viewport), notes: { notes },
            isAutoscrolling: false)
        scroll.observe(
            geometry(scroll, at: .zero, insets: insets, viewport: viewport), notes: { notes },
            isAutoscrolling: false)
        let landed = geometry(scroll, at: scroll.contentOrigin, insets: insets, viewport: viewport)
        scroll.observe(landed, notes: { notes }, isAutoscrolling: false)
        return scroll
    }

    @Test func theContentCoversTheNotesWithAMarginAndWhatIsOnScreen() {
        let screen = CGRect(origin: .zero, size: viewport)
        let needed = CanvasScroll.needed(notes: notes, visible: screen)
        let margin = CanvasScroll.margin
        #expect(needed == screen.union(notes.insetBy(dx: -margin, dy: -margin)))
        #expect(CanvasScroll.needed(notes: nil, visible: screen) == screen)
    }

    @Test func growingGoesPastOnlyTheEdgesCrossed() {
        let extent = CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        let needed = CGRect(x: -100, y: 200, width: 500, height: 500)
        let grown = CanvasScroll.grow(extent, toCover: needed, by: 50)
        #expect(grown == CGRect(x: -150, y: 0, width: 1_150, height: 1_000))
        #expect(CanvasScroll.grow(extent, toCover: extent.insetBy(dx: 10, dy: 10), by: 50) == nil)
    }

    @Test func autoscrollReachesAheadOnlyWhichWayItGoes() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let up = CanvasScroll.reaching(rect, toward: CGVector(dx: 0, dy: -5), by: 50)
        #expect(up == CGRect(x: 0, y: -50, width: 100, height: 150))
        let right = CanvasScroll.reaching(rect, toward: CGVector(dx: 5, dy: 0), by: 50)
        #expect(right == CGRect(x: 0, y: 0, width: 150, height: 100))
    }

    /// Board (0, 0) at the canvas's top-left, so notes are where they were before boards
    /// scrolled. The scroll asks for the content point to show there.
    @Test func aBoardOpensWithItsOriginAtTheTopLeft() {
        let scroll = CanvasScroll()
        let sized = scroll.observe(
            geometry(scroll, at: .zero), notes: { notes }, isAutoscrolling: false)
        #expect(sized.opening == nil)
        let laidOut = scroll.observe(
            geometry(scroll, at: .zero), notes: { notes }, isAutoscrolling: false)
        #expect(laidOut.opening == scroll.contentOrigin)
        #expect(!scroll.isOpen)

        let landed = geometry(scroll, at: scroll.contentOrigin)
        scroll.observe(landed, notes: { notes }, isAutoscrolling: false)
        #expect(scroll.isOpen)
        #expect(scroll.visible.origin == .zero)
    }

    /// A note picked from a search: the board opens with it in the middle, not at (0, 0).
    @Test func aBoardCanOpenWithANoteInTheMiddle() throws {
        let scroll = CanvasScroll()
        let note = CGRect(x: 170, y: 460, width: 160, height: 160)
        scroll.observe(
            geometry(scroll, at: .zero), notes: { notes }, target: { note },
            isAutoscrolling: false)
        let laidOut = scroll.observe(
            geometry(scroll, at: .zero), notes: { notes }, target: { note },
            isAutoscrolling: false)
        let opening = try #require(laidOut.opening)

        scroll.observe(geometry(scroll, at: opening), notes: { notes }, isAutoscrolling: false)
        #expect(scroll.isOpen)
        #expect(scroll.visible.midX == note.midX && scroll.visible.midY == note.midY)
    }

    /// On an iPad the canvas runs under the sidebar as it does under the navigation bar: the
    /// sidebar is a leading inset, and what's visible is what it leaves uncovered (measured on
    /// iOS 27, an 11-inch iPad in landscape).
    @Test func besideASidebarWhatIsVisibleIsWhatItLeavesUncovered() throws {
        let sidebar = EdgeInsets(top: 86, leading: 320, bottom: 20, trailing: 0)
        let uncovered = CGSize(width: 860, height: 714)
        let scroll = opened(insets: sidebar, viewport: uncovered)
        #expect(scroll.visible == CGRect(origin: .zero, size: uncovered))

        let note = CGRect(x: 170, y: 460, width: 160, height: 160)
        let point = try #require(scroll.reveal(note))

        #expect(scroll.visible.midX == note.midX && scroll.visible.midY == note.midY)
        #expect(scroll.visible.origin == scroll.boardPoint(fromContent: point))
    }

    @Test func anOpenBoardScrollsANoteToTheMiddle() throws {
        let scroll = opened()
        let note = CGRect(x: 170, y: 460, width: 160, height: 160)

        let point = try #require(scroll.reveal(note))

        #expect(scroll.visible.midX == note.midX && scroll.visible.midY == note.midY)
        #expect(scroll.visible.origin == scroll.boardPoint(fromContent: point))
    }

    /// Opening takes its target from the geometry; a reveal before then has nowhere to go.
    @Test func aRevealWaitsForTheBoardToOpen() {
        let scroll = CanvasScroll()
        #expect(scroll.reveal(CGRect(x: 0, y: 0, width: 160, height: 160)) == nil)
    }

    /// Where the content ends before the middle does, the scroll stops there.
    @Test func clampingMovesARectTheLeastThatFits() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        let inside = CGRect(x: 100, y: 100, width: 400, height: 400)
        #expect(CanvasScroll.clamp(inside, in: bounds) == inside)
        let over = CGRect(x: -50, y: 900, width: 400, height: 400)
        #expect(
            CanvasScroll.clamp(over, in: bounds) == CGRect(x: 0, y: 600, width: 400, height: 400))
        let wider = CGRect(x: 0, y: 0, width: 1_200, height: 400)
        #expect(CanvasScroll.clamp(wider, in: bounds).minX == -100)
    }

    /// Nothing to scroll to: an empty board is what's on screen, already in place.
    @Test func anEmptyBoardOpensAtOnce() {
        let scroll = CanvasScroll()
        scroll.observe(geometry(scroll, at: .zero), notes: { nil }, isAutoscrolling: false)
        #expect(scroll.isOpen)
        #expect(scroll.extent == CGRect(origin: .zero, size: viewport))
    }

    /// A canvas can report no insets until its first scroll. When they come, the raw offset
    /// moves by as much and nothing on screen does — nor may the next scroll.
    @Test func insetsArrivingLateMoveNothing() {
        let scroll = CanvasScroll()
        let none = EdgeInsets()
        for _ in 0..<2 {
            scroll.observe(
                geometry(scroll, at: .zero, insets: none), notes: { notes },
                isAutoscrolling: false)
        }
        scroll.observe(
            geometry(scroll, at: scroll.contentOrigin, insets: none), notes: { notes },
            isAutoscrolling: false)
        #expect(scroll.isOpen)

        scroll.observe(
            geometry(scroll, at: scroll.contentOrigin), notes: { notes }, isAutoscrolling: false)
        #expect(scroll.visible.origin == .zero)

        let step = scroll.autoscroll(CGVector(dx: 60, dy: 0), for: 1, notes: notes)
        #expect(step?.scrollTo.y == scroll.contentOrigin.y)
    }

    /// Scrolling left past the board's edge grows it, which moves the content; the scroll
    /// moves by as much, so the board moves under the finger only as fast as autoscroll goes.
    @Test func autoscrollGrowsTheBoardAheadOfItself() {
        let scroll = opened()
        let extent = scroll.extent

        let step = scroll.autoscroll(CGVector(dx: -300, dy: 0), for: 1, notes: notes)

        #expect(step?.moved == CGSize(width: -300, height: 0))
        #expect(scroll.visible.origin == CGPoint(x: -300, y: 0))
        #expect(scroll.extent.minX < extent.minX)
        #expect(scroll.extent.maxX == extent.maxX)
        #expect(scroll.extent.minY == extent.minY && scroll.extent.maxY == extent.maxY)
        #expect(step?.scrollTo == CGPoint(x: -300 - scroll.extent.minX, y: -extent.minY))
    }

    /// At rest the board fits again, shrinking back to the notes and the screen.
    @Test func atRestTheBoardFitsAgain() {
        let scroll = opened()
        _ = scroll.autoscroll(CGVector(dx: -1_200, dy: 0), for: 2, notes: notes)
        let away = scroll.visible

        let scrollTo = scroll.settle(notes: notes)

        #expect(scroll.extent == CanvasScroll.needed(notes: notes, visible: away))
        #expect(scroll.visible == away)
        #expect(scrollTo == CGPoint(x: away.minX - scroll.extent.minX, y: -scroll.extent.minY))
    }

    @Test func nothingFitsWhileTheScrollMoves() {
        let scroll = opened()
        _ = scroll.autoscroll(CGVector(dx: -1_200, dy: 0), for: 2, notes: notes)
        let extent = scroll.extent

        scroll.isScrolling = true

        #expect(scroll.settle(notes: notes) == nil)
        #expect(scroll.extent == extent)
    }
}

struct MotionTests {
    @Test func reduceMotionRemovesEveryAnimation() {
        let motion = Motion(reduced: true)
        #expect(motion.edit == nil)
        #expect(motion.lift == nil)
        #expect(motion.reveal == nil)
        #expect(motion.writing == nil)
    }

    @Test func fullMotionAnimates() {
        let motion = Motion(reduced: false)
        #expect(motion.edit != nil)
        #expect(motion.lift != nil)
        #expect(motion.reveal != nil)
        #expect(motion.writing != nil)
    }
}

struct EditedNoteTests {
    @Test func withRoomANoteIsWrittenOnAtItsOwnSize() {
        let canvas = CGSize(width: 402, height: 390)
        #expect(EditedNote.side(NoteGeometry.defaultSide, in: canvas) == NoteGeometry.defaultSide)
        #expect(EditedNote.side(NoteGeometry.maxSide, in: canvas) == NoteGeometry.maxSide)
    }

    @Test func aNoteTooBigForWhatTheKeyboardLeavesFitsIt() {
        let canvas = CGSize(width: 874, height: 180)
        #expect(EditedNote.side(NoteGeometry.maxSide, in: canvas) == 180 - 2 * EditedNote.margin)
    }

    @Test func aNoteIsNeverDrawnSmallerThanOneCanBeMade() {
        let canvas = CGSize(width: 874, height: 90)
        #expect(EditedNote.side(NoteGeometry.maxSide, in: canvas) == NoteGeometry.minSide)
    }
}

struct NoteStyleTests {
    /// Two colors drawn the same would make the rotation invisible.
    @Test func everyColorIsDrawnDifferently() {
        let fills = NoteColor.allCases.map(\.fill)
        for (i, fill) in fills.enumerated() {
            for other in fills[(i + 1)...] {
                #expect(fill != other)
            }
        }
    }
}

struct TrashZoneTests {
    let canvas = CGSize(width: 400, height: 800)

    @Test func theBinSitsAtTheBottomMiddle() {
        let center = TrashZone.center(in: canvas)
        #expect(center.x == 200)
        #expect(center.y == 800 - TrashZone.bottomInset - TrashZone.diameter / 2)
    }

    @Test func aFingerNearTheBinCounts() {
        let center = TrashZone.center(in: canvas)
        let edge = TrashZone.diameter / 2 + TrashZone.reach
        #expect(TrashZone.contains(center, in: canvas))
        #expect(TrashZone.contains(CGPoint(x: center.x + edge - 1, y: center.y), in: canvas))
        #expect(!TrashZone.contains(CGPoint(x: center.x + edge + 1, y: center.y), in: canvas))
    }

    /// The middle of the canvas, where most notes are put down, is nowhere near it.
    @Test func theMiddleIsNotTheBin() {
        #expect(!TrashZone.contains(CGPoint(x: 200, y: 400), in: canvas))
    }
}

struct NoteTextTests {
    /// The text field's binding writes through the store, like any other write: it clears the
    /// offer to undo a delete, and reads back what was typed, leaving the note itself and saving
    /// to a pause in typing.
    @Test func typingGoesThroughTheStore() throws {
        let container = try ModelContainer.inMemory()
        let store = NoteStore(context: container.mainContext)
        let board = store.addBoard(named: "Board")
        let visible = CGRect(x: 0, y: 0, width: 400, height: 800)
        let note = store.add(at: CGPoint(x: 200, y: 300), within: visible, on: board)
        store.delete(store.add(at: CGPoint(x: 100, y: 100), within: visible, on: board))

        store[textOf: note] = "Milk"
        #expect(store[textOf: note] == "Milk")
        #expect(note.text.isEmpty)
        #expect(store.lastDeletion == nil)
        #expect(!container.mainContext.hasChanges)
    }
}
