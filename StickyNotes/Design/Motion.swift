import LaunchArguments
import SwiftUI

/// The app's animations, each nil (or a fade) under Reduce Motion.
///
/// What a finger is holding is not animation: a dragged note tracks it undamped, under Reduce
/// Motion or not. Each animation is named for its purpose, so new ones must choose a category.
nonisolated struct Motion: Equatable {
    let isReduced: Bool

    init(reduced: Bool) {
        isReduced = reduced
    }

    /// A note being added or deleted, or resized or moved without a gesture.
    var edit: Animation? { isReduced ? nil : .snappy }

    /// A note lifting off the canvas as a drag starts, and settling as it ends.
    var lift: Animation? { isReduced ? nil : .snappy(duration: 0.15) }

    /// A note arriving or leaving; a fade under Reduce Motion.
    var arrival: AnyTransition {
        isReduced ? .opacity : .scale(scale: 0.6).combined(with: .opacity)
    }

    /// The canvas scrolling to a note picked from a search, on its board already.
    var reveal: Animation? { isReduced ? nil : .smooth }

    /// The undo banner arriving from the bottom edge; a fade under Reduce Motion.
    var banner: AnyTransition {
        isReduced ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    /// A note going to the middle of the canvas to be written on, and back to its place; the blur
    /// over the rest of the board coming and going.
    var writing: Animation? { isReduced ? nil : .snappy }

    /// A note being written on, coming to the middle of the canvas from its place `offset` away,
    /// at `scale` of the size it has there, and going back the same way; a fade under Reduce
    /// Motion.
    func toTheMiddle(from offset: CGSize, scale: CGFloat) -> AnyTransition {
        isReduced ? .opacity : AnyTransition(FromItsPlace(offset: offset, scale: scale))
    }

    /// The tour turning a page, and a page's words changing once its gesture is done: the words
    /// cross-fade while the controls stay put.
    var pageTurn: Animation? { isReduced ? nil : .smooth }

    /// A fingertip in the tour's demonstrations pressing and letting go.
    var press: Animation? { isReduced ? nil : .snappy(duration: 0.1) }

    /// Whether the tour's gestures play on a loop. Under Reduce Motion each is a still picture
    /// instead: the board at rest, with where the fingers go drawn on it.
    var demonstrates: Bool { !isReduced }

    /// Whether ``LaunchFlag/reduceMotion`` was passed. Read once, since launch arguments never
    /// change.
    static let isAskedForByLaunchArgument = LaunchFlag.reduceMotion.isPresent()
}

/// A view `offset` away at `scale` of its size: scaled first, so `offset` is where its centre
/// lands. Two transitions `combined(with:)` don't say which applies first.
struct FromItsPlace: Transition {
    let offset: CGSize
    let scale: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : scale)
            .offset(phase.isIdentity ? .zero : offset)
    }
}

extension EnvironmentValues {
    /// Derived from `accessibilityReduceMotion`, or forced on by the launch flag.
    nonisolated var motion: Motion {
        Motion(reduced: accessibilityReduceMotion || Motion.isAskedForByLaunchArgument)
    }
}
