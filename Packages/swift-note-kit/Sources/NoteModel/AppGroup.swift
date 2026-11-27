import Foundation
import OSLog

/// The app group the app and any extension share: the store, and the defaults both read. Named
/// once because a mistyped identifier silently opens a different, empty container.
nonisolated public enum AppGroup {
    public static let identifier = "group.com.thebinarykitchen.Stickies"
}

extension UserDefaults {
    /// Defaults shared with an extension, for what it needs that only the app can work out.
    /// Nothing reads them yet. Falls back to `standard`, logging a critical error, when the app
    /// group is unavailable.
    ///
    /// Made each time rather than kept: `UserDefaults` isn't `Sendable`, and making one is cheap.
    nonisolated public static var shared: UserDefaults {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else {
            Logger.appGroup.critical(
                "No defaults for \(AppGroup.identifier, privacy: .public), using standard")
            return .standard
        }
        return defaults
    }
}

extension Logger {
    nonisolated fileprivate static let appGroup = Logger(
        subsystem: "com.thebinarykitchen.Stickies", category: "app-group")
}
