import LaunchArguments
import SwiftUI

/// Whether the tour should be up, stored as the last tour version finished or skipped, so a
/// revised tour can be shown again by bumping ``version``.
struct OnboardingProgress: DynamicProperty {
    /// Named by the case the UI tests preset it through.
    @AppStorage(LaunchDefault.onboardingFinished.rawValue) private var finished = 0

    /// Bump only when existing readers should see the tour again.
    static let version = 1

    var isDue: Bool { Self.isDue(answered: finished) }

    /// Pure, for testing without `UserDefaults`.
    ///
    /// - Parameter answered: The last tour version finished or skipped, 0 for never.
    static func isDue(answered: Int) -> Bool { answered < version }

    /// On finishing or skipping.
    func markSeen() { finished = Self.version }

    /// Puts the tour back up: from an empty board, the list of boards or the Help menu.
    func markDue() { finished = 0 }
}
