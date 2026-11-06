import NoteModel
import SwiftUI

/// A drag in progress. Whether one is, whether the finger is over the bin and whether the canvas
/// is autoscrolling change only as they flip, never as the finger moves: the canvas's body re-runs
/// on every change it reads. What does change with the finger, only ``HeldNote`` reads.
@Observable
final class NoteDrag {
    private(set) var isActive = false
    private(set) var isOverTrash = false
    /// Whether the canvas scrolls under the finger: it is in an edge band, off the bin. The bands
    /// count only once the finger has been outside them, so a note picked up near an edge doesn't
    /// set the canvas off.
    private(set) var isAutoscrolling = false
    /// The note being held, which ``HeldNote`` draws above the scroll view.
    private(set) var held: Note?
    /// Whether a pinch has crumpled the held note.
    private(set) var isCrumpled = false
    /// Where the held note's centre was as it lifted, in canvas coordinates.
    private(set) var liftCenter: CGPoint = .zero
    /// The finger's travel since the lift, and the side a pinch asks for over the note's own.
    private(set) var translation: CGSize = .zero
    private(set) var magnification: Double = 1

    /// The finger and the canvas, for autoscroll to read each frame.
    @ObservationIgnored private(set) var location: CGPoint = .zero
    @ObservationIgnored private(set) var canvas: CGSize = .zero
    /// How far autoscroll has moved the board under the finger, in board points.
    @ObservationIgnored private(set) var scrolled: CGSize = .zero
    @ObservationIgnored private var hasLeftTheBands = false

    func lift(_ note: Note, at center: CGPoint) {
        held = note
        liftCenter = center
    }

    /// The finger dragging a note is at `location`, in canvas coordinates, `translation` from
    /// where it went down. Called on every move; assigning a value a property already holds
    /// notifies no one.
    func track(_ location: CGPoint, translation: CGSize = .zero, in canvas: CGSize) {
        isActive = true
        isOverTrash = TrashZone.contains(location, in: canvas)
        self.location = location
        self.canvas = canvas
        self.translation = translation
        let isInABand = Autoscroll.velocity(at: location, in: canvas) != .zero
        if !isInABand { hasLeftTheBands = true }
        isAutoscrolling = isInABand && hasLeftTheBands && !isOverTrash
    }

    /// A pinch on `note` asks for `magnification` times its side. Only the held note's counts:
    /// any other draws its own pinch.
    func pinch(_ note: Note, by magnification: Double) {
        guard note == held else { return }
        self.magnification = magnification
        isCrumpled = NoteGeometry.crumples(note.side * magnification)
    }

    func scroll(by distance: CGSize) {
        scrolled.width += distance.width
        scrolled.height += distance.height
    }

    /// How far the finger has taken the note over the board: its own travel on screen, and the
    /// board's under it.
    func travel(_ translation: CGSize) -> CGSize {
        CGSize(
            width: translation.width + scrolled.width, height: translation.height + scrolled.height)
    }

    func end() {
        isActive = false
        isOverTrash = false
        isAutoscrolling = false
        held = nil
        isCrumpled = false
        translation = .zero
        magnification = 1
        scrolled = .zero
        hasLeftTheBands = false
    }
}

/// Drags a note over the board: it follows the finger undamped — toward an edge of the canvas,
/// the board scrolls under it — and is written to the store only where it lands: raised and
/// moved, or, dropped on the ``TrashZone``, deleted. Nothing is saved while it is held: every
/// save re-renders every note on the board.
///
/// While held, the note stays where it was in the content, hidden, and ``HeldNote`` draws it
/// above the scroll view instead. The gesture stays with this one.
struct DragToMove: ViewModifier {
    let note: Note
    let canvas: CanvasBounds
    let onTrash: () -> Void

    @Environment(NoteStore.self) private var store
    @Environment(NoteDrag.self) private var drag
    @Environment(CanvasScroll.self) private var scroll
    @Environment(\.motion) private var motion
    @GestureState private var isHeld = false
    /// Dropped on the bin, it stays hidden while it goes: the stand-in goes from the bin.
    @State private var isBinned = false

    func body(content: Content) -> some View {
        content
            // Lifted while hidden, so that on the drop it settles from where the stand-in was.
            .scaleEffect(isHeld ? NoteStyle.liftedScale : 1)
            .shadow(
                color: .black.opacity(isHeld ? 0.25 : 0.18),
                radius: isHeld ? NoteStyle.liftedShadow : NoteStyle.shadow,
                y: isHeld ? 8 : 2
            )
            .animation(motion.lift, value: isHeld)
            .opacity(isHeld || isBinned ? 0 : 1)
            // Simultaneous, not `.gesture`: a child's gestures take precedence over this one, and
            // the pinch inside can't fail until the finger lifts, so the note would only follow
            // the finger once the drag was over.
            .simultaneousGesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named(CanvasView.space))
                    .updating($isHeld) { _, isHeld, _ in isHeld = true }
                    .onChanged { value in
                        if drag.held == nil {
                            drag.lift(note, at: scroll.canvasPoint(fromBoard: note.center))
                        }
                        drag.track(value.location, translation: value.translation, in: canvas.size)
                    }
                    .onEnded { value in
                        let travel = drag.travel(value.translation)
                        drag.end()
                        if TrashZone.contains(value.location, in: canvas.size) {
                            isBinned = true
                            onTrash()
                        } else {
                            store.drop(note, at: Self.drop(from: note.center, by: travel))
                        }
                    }
            )
            // A cancelled drag never reaches `onEnded`; its gesture state still resets.
            .onChange(of: isHeld) { _, isHeld in
                if !isHeld { drag.end() }
            }
    }

    /// Where a note picked up at `center` lands after the finger takes it `travel` over the
    /// board.
    nonisolated static func drop(from center: CGPoint, by travel: CGSize) -> CGPoint {
        CGPoint(x: center.x + travel.width, y: center.y + travel.height)
    }
}

extension View {
    func dragToMove(
        _ note: Note, in canvas: CanvasBounds, onTrash: @escaping () -> Void
    ) -> some View {
        modifier(DragToMove(note: note, canvas: canvas, onTrash: onTrash))
    }
}
