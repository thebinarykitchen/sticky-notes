import NoteModel
import SwiftUI

/// Where the canvas is scrolled to, and how much of the board its content covers.
///
/// A board has no edges, but a scroll view's content does. Here it covers ``extent``: the notes,
/// ``margin`` round them, and whatever is on screen. Autoscroll grows it ahead of the scroll, and
/// at rest it fits again. Growing or shrinking at the left or top moves everything in the
/// content, so the scroll moves by as much in the same update and nothing moves on screen —
/// except a note being held, which is why ``HeldNote`` draws that one elsewhere.
///
/// Where it is scrolled to is kept as the content point at the top-left of what is visible —
/// below the bars and beside an iPad's sidebar, inside the content insets — which is what
/// `scrollTo(point:)` takes (measured on iOS 27). The raw offset isn't: insets can arrive late — a canvas just opened can report
/// none until its first scroll — and the raw offset moves when they do, while this stays put.
/// What changes every frame isn't observed.
///
/// The scroll view's `ScrollPosition` isn't kept here but in ``CanvasScrolling``'s state, which
/// scrolls to the points this hands back: the scroll view writes the position back as it goes,
/// and kept in an observed property, each write re-ran the modifier that bound it, which
/// scrolled again — a loop that never let the canvas rest (seen on iOS 27).
@Observable
final class CanvasScroll {
    /// How far the board reaches past its notes: as far as a scroll can go, a status-bar tap
    /// included.
    nonisolated static let margin: CGFloat = 600

    /// How long the notes wait for the scroll that opens the board before showing anyway.
    static let openingTimeout: Duration = .milliseconds(500)

    /// The part of the board the content covers, in board points. Zero until the canvas has a
    /// size.
    private(set) var extent = CGRect.zero
    /// Whether the scroll that opens the board has landed: board (0, 0) at the top-left of the
    /// canvas, or a note being revealed in the middle. The notes are hidden until then, rather
    /// than seen where the content starts.
    private(set) var isOpen = false

    /// Whether the scroll view is moving: under a finger, a fling, or an animation of its own.
    @ObservationIgnored var isScrolling = false
    /// The content point at the top-left of what is visible.
    @ObservationIgnored private var scrolledTo = CGPoint.zero
    @ObservationIgnored private var viewport = CGSize.zero
    @ObservationIgnored private var opening = Opening.unsized
    /// The content point the board opens at.
    @ObservationIgnored private var openingPoint = CGPoint.zero

    private enum Opening {
        case unsized
        /// The extent is set; waiting for the content to take its size.
        case sized
        /// Scrolling to the opening point.
        case scrolling
        case open
    }

    /// What is on screen, in board points.
    var visible: CGRect { visible(at: scrolledTo) }

    /// Where board (0, 0) is in the content.
    var contentOrigin: CGPoint { CGPoint(x: -extent.minX, y: -extent.minY) }

    func boardPoint(fromContent point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + extent.minX, y: point.y + extent.minY)
    }

    func canvasPoint(fromBoard point: CGPoint) -> CGPoint {
        let visible = visible
        return CGPoint(x: point.x - visible.minX, y: point.y - visible.minY)
    }

    // MARK: - Following the scroll view

    /// What the scroll view should do after ``observe(_:notes:target:isAutoscrolling:)``.
    struct Change: Equatable {
        /// The canvas changed size.
        var resized = false
        /// Scroll to this to open the board — a turn later: from inside the geometry callback,
        /// the scroll doesn't stick. Then ``finishOpening()`` after ``openingTimeout``, in case
        /// it never gets there.
        var opening: CGPoint?
    }

    /// Takes in the scroll view's latest geometry, opening the board once it can: with board
    /// (0, 0) at the top-left, or with `target` — a note to reveal, in board points — in the
    /// middle. The content covers either, so the opening scroll can always land.
    @discardableResult
    func observe(
        _ geometry: ScrollGeometry, notes: () -> CGRect?, target: () -> CGRect? = { nil },
        isAutoscrolling: Bool
    ) -> Change {
        var change = Change(resized: geometry.containerSize != viewport)
        viewport = geometry.containerSize
        // While autoscrolling, the point last scrolled to is ahead of the one reported.
        if !isAutoscrolling {
            scrolledTo = CGPoint(
                x: geometry.contentOffset.x + geometry.contentInsets.leading,
                y: geometry.contentOffset.y + geometry.contentInsets.top)
        }

        switch opening {
        case .unsized:
            guard viewport.width > 0, viewport.height > 0 else { break }
            let first = target().map(centred(on:)) ?? CGRect(origin: .zero, size: viewport)
            extent = Self.needed(notes: notes(), visible: first)
            openingPoint = CGPoint(x: first.minX - extent.minX, y: first.minY - extent.minY)
            if Self.isClose(scrolledTo, openingPoint) {
                opened()
            } else {
                opening = .sized
            }
        case .sized:
            guard abs(geometry.contentSize.width - extent.width) < 1,
                abs(geometry.contentSize.height - extent.height) < 1
            else { break }
            opening = .scrolling
            change.opening = openingPoint
        case .scrolling:
            if Self.isClose(scrolledTo, openingPoint) { opened() }
        case .open:
            break
        }
        return change
    }

    /// Shows the notes, wherever the opening scroll got to.
    func finishOpening() {
        guard case .scrolling = opening else { return }
        opened()
    }

    private func opened() {
        opening = .open
        isOpen = true
    }

    /// Where to scroll to bring `rect`, in board points, to the middle of the canvas — or as
    /// near as the content reaches, since growing it would shift it under the scroll. Nil until
    /// the board is open; opening takes its target through
    /// ``observe(_:notes:target:isAutoscrolling:)``.
    func reveal(_ rect: CGRect) -> CGPoint? {
        guard case .open = opening else { return nil }
        let visible = Self.clamp(centred(on: rect), in: extent)
        scrolledTo = CGPoint(x: visible.minX - extent.minX, y: visible.minY - extent.minY)
        return scrolledTo
    }

    /// What is on screen with `rect` in the middle of it.
    private func centred(on rect: CGRect) -> CGRect {
        CGRect(
            x: rect.midX - viewport.width / 2, y: rect.midY - viewport.height / 2,
            width: viewport.width, height: viewport.height)
    }

    /// Fits the extent to the notes and what is on screen. Only at rest: it would move the
    /// content under a scroll in flight. Returns where to scroll if the content shifted, which
    /// has to happen in the same update.
    func settle(notes: CGRect?) -> CGPoint? {
        guard case .open = opening, !isScrolling else { return nil }
        let fitted = Self.needed(notes: notes, visible: visible)
        guard !Self.isClose(extent, fitted) else { return nil }
        let shift = CGPoint(x: extent.minX - fitted.minX, y: extent.minY - fitted.minY)
        extent = fitted
        guard shift != .zero else { return nil }
        scrolledTo = CGPoint(x: scrolledTo.x + shift.x, y: scrolledTo.y + shift.y)
        return scrolledTo
    }

    /// One frame of autoscroll.
    struct Step: Equatable {
        /// Where to scroll, in the same update.
        var scrollTo: CGPoint
        /// How far the board moved under the canvas, in board points.
        var moved: CGSize
    }

    /// Scrolls `velocity × seconds` further, growing the extent ahead of the scroll.
    func autoscroll(_ velocity: CGVector, for seconds: Double, notes: CGRect?) -> Step? {
        guard case .open = opening, velocity != .zero else { return nil }
        let before = visible.origin
        var next = CGPoint(
            x: scrolledTo.x + velocity.dx * seconds, y: scrolledTo.y + velocity.dy * seconds)
        let ahead = Self.reaching(visible(at: next), toward: velocity, by: Self.margin)
        if let grown = Self.grow(
            extent, toCover: Self.needed(notes: notes, visible: ahead), by: Self.margin)
        {
            next.x += extent.minX - grown.minX
            next.y += extent.minY - grown.minY
            extent = grown
        }
        scrolledTo = next
        let after = visible.origin
        return Step(
            scrollTo: next, moved: CGSize(width: after.x - before.x, height: after.y - before.y))
    }

    // MARK: - Geometry

    private func visible(at point: CGPoint) -> CGRect {
        CGRect(
            x: point.x + extent.minX, y: point.y + extent.minY, width: viewport.width,
            height: viewport.height)
    }

    nonisolated static func isClose(_ a: CGPoint, _ b: CGPoint) -> Bool {
        abs(a.x - b.x) < 0.5 && abs(a.y - b.y) < 0.5
    }

    /// Within a point on every edge: a fit that close isn't worth moving the content for.
    nonisolated static func isClose(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1 && abs(a.maxX - b.maxX) < 1
            && abs(a.maxY - b.maxY) < 1
    }

    /// `rect`, moved the least distance that puts it inside `bounds`. Centred on an axis where
    /// `bounds` is no wider.
    nonisolated static func clamp(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        var rect = rect
        rect.origin.x = clamp(rect.minX, length: rect.width, from: bounds.minX, to: bounds.maxX)
        rect.origin.y = clamp(rect.minY, length: rect.height, from: bounds.minY, to: bounds.maxY)
        return rect
    }

    private nonisolated static func clamp(
        _ start: CGFloat, length: CGFloat, from low: CGFloat, to high: CGFloat
    ) -> CGFloat {
        guard high - low > length else { return (low + high - length) / 2 }
        return min(max(start, low), high - length)
    }

    /// What the content has to cover: `visible`, and the notes with ``margin`` round them.
    nonisolated static func needed(notes: CGRect?, visible: CGRect) -> CGRect {
        guard let notes else { return visible }
        return visible.union(notes.insetBy(dx: -margin, dy: -margin))
    }

    /// `rect`, reaching `distance` further on each side `velocity` heads toward.
    nonisolated static func reaching(
        _ rect: CGRect, toward velocity: CGVector, by distance: CGFloat
    ) -> CGRect {
        var rect = rect
        if velocity.dx < 0 { rect.origin.x -= distance }
        if velocity.dx != 0 { rect.size.width += distance }
        if velocity.dy < 0 { rect.origin.y -= distance }
        if velocity.dy != 0 { rect.size.height += distance }
        return rect
    }

    /// `extent`, grown past each edge `needed` crosses and `slack` further; nil if it already
    /// covers it. The slack keeps autoscroll from growing it every frame.
    nonisolated static func grow(_ extent: CGRect, toCover needed: CGRect, by slack: CGFloat)
        -> CGRect?
    {
        guard !extent.contains(needed) else { return nil }
        let minX = needed.minX < extent.minX ? needed.minX - slack : extent.minX
        let minY = needed.minY < extent.minY ? needed.minY - slack : extent.minY
        let maxX = needed.maxX > extent.maxX ? needed.maxX + slack : extent.maxX
        let maxY = needed.maxY > extent.maxY ? needed.maxY + slack : extent.maxY
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// Keeps a ``CanvasScroll`` in step with the scroll view it is applied to, and autoscrolls while
/// ``NoteDrag`` says to. A modifier of its own so that what it watches — every frame of a
/// scroll, the notes' bounds, the drag — re-runs this rather than the canvas.
struct CanvasScrolling: ViewModifier {
    let scroll: CanvasScroll
    let drag: NoteDrag
    let notes: [Note]
    /// The note to bring to the middle of the canvas: where the board opens, or, open already,
    /// where it scrolls to.
    let reveal: CanvasView.Reveal?

    @Environment(\.motion) private var motion
    @State private var position = ScrollPosition()

    private var notesBounds: CGRect? {
        notes.reduce(nil) { bounds, note in
            let frame = Self.frame(of: note)
            return bounds?.union(frame) ?? frame
        }
    }

    /// The frame of the note to reveal, if it is on this board.
    private var revealed: CGRect? {
        guard let reveal else { return nil }
        return notes.first { $0.id == reveal.noteID }.map(Self.frame(of:))
    }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { _, geometry in
                let change = scroll.observe(
                    geometry, notes: { notesBounds }, target: { revealed },
                    isAutoscrolling: drag.isAutoscrolling)
                if let origin = change.opening { open(at: origin) }
                if change.resized { settle() }
            }
            .onScrollPhaseChange { _, phase in
                scroll.isScrolling = phase != .idle
                settle()
            }
            .modifier(
                AutoscrollClock(isRunning: drag.isAutoscrolling) { seconds in
                    let velocity = Autoscroll.velocity(at: drag.location, in: drag.canvas)
                    guard let step = scroll.autoscroll(velocity, for: seconds, notes: notesBounds)
                    else { return }
                    position.scrollTo(point: step.scrollTo)
                    drag.scroll(by: step.moved)
                }
            )
            .onChange(of: notesBounds) { settle() }
            .onChange(of: drag.isActive) { settle() }
            .onChange(of: reveal) {
                guard let revealed, let point = scroll.reveal(revealed) else { return }
                withAnimation(motion.reveal) { position.scrollTo(point: point) }
            }
    }

    private static func frame(of note: Note) -> CGRect {
        CGRect(
            x: note.x - note.side / 2, y: note.y - note.side / 2, width: note.side,
            height: note.side)
    }

    /// A turn after the geometry callback that asks for it — not `.task(id:)`, which a canvas
    /// pushed onto a navigation stack never ran (seen on iOS 27).
    private func open(at origin: CGPoint) {
        Task {
            position.scrollTo(point: origin)
            try? await Task.sleep(for: CanvasScroll.openingTimeout)
            scroll.finishOpening()
        }
    }

    /// Never under a held note: the content shifting under it would move it.
    private func settle() {
        guard !drag.isActive, let point = scroll.settle(notes: notesBounds) else { return }
        position.scrollTo(point: point)
    }
}
