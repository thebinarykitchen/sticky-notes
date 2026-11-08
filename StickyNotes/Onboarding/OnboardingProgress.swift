import AppTour
import LaunchArguments

extension TourProgress {
    /// Bump only when existing readers should see the tour again.
    static let version = 1

    /// Whether the tour should be up. Named by the case the UI tests preset it through.
    static var app: TourProgress {
        TourProgress(key: LaunchDefault.onboardingFinished.rawValue, version: version)
    }
}
