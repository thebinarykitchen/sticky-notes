import Foundation

/// Which window puts the tour up when ``OnboardingProgress`` says it is due. That is one setting
/// for the whole app, and every window observes it: without a single owner, each window on an
/// iPad or a Mac would open a tour of its own, and finishing one would leave the rest standing.
@Observable
final class TourStage {
    private(set) var presenter: UUID?

    /// Whether `window` may present: nobody else is, or it already is.
    func claim(for window: UUID) -> Bool {
        guard presenter == nil || presenter == window else { return false }
        presenter = window
        return true
    }

    /// Hands the tour back, when it is finished or the presenting window goes away.
    func release(from window: UUID) {
        if presenter == window { presenter = nil }
    }
}
