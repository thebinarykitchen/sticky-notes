import Foundation

/// Launch-argument flags shared by the UI tests, which set them, and the app, which reads them,
/// so a rename is a compile error.
///
/// Add a flag only for state a test can't reach through the UI.
public enum LaunchFlag: String, CaseIterable, Sendable {
    /// Uses an in-memory store, so tests don't inherit each other's notes.
    case ephemeralStore = "--ephemeral-store"

    /// Seeds the store with sample notes. Debug builds only.
    case seedStore = "--seed-store"

    /// Seeds the store with the boards the App Store listing photographs, in place of
    /// ``seedStore``'s. Debug builds only.
    case seedListing = "--seed-listing"

    /// Behaves as if Reduce Motion is on, so a test isn't waiting out an add or delete animation.
    case reduceMotion = "--reduce-motion"

    /// Offers no notes made with Apple Intelligence, even where the on-device model can run, so
    /// a test sees the same toolbar on any Mac.
    case noAppleIntelligence = "--no-apple-intelligence"

    /// Makes notes with a stand-in for the on-device model: one for each line or comma-separated
    /// item written. Debug builds only.
    case fakeAppleIntelligence = "--fake-apple-intelligence"

    /// Skips StoreKit and reads Pro state from defaults, so ``LaunchDefault/proUnlocked`` isn't
    /// overwritten by a store reporting nothing owned. Debug builds only.
    case noStoreKit = "--no-storekit"

    /// Whether this flag is in `arguments`, which defaults to the current process's.
    public func isPresent(in arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(rawValue)
    }
}

/// A `UserDefaults` key the app keeps and a test can preset for one launch.
///
/// `-key value` arguments go into the argument domain, which takes precedence over persisted
/// values. Writes still persist but aren't read back while the argument is there, so a test
/// checking that one sticks relaunches without it.
public enum LaunchDefault: String, CaseIterable, Sendable {
    /// The last tour version the reader finished or skipped; 0, the default, means never, and the
    /// tour is up at launch. The UI tests answer it, unless a test is about the tour.
    case onboardingFinished = "onboarding.finished"

    /// Whether Pro is unlocked. Only holds with ``LaunchFlag/noStoreKit``; otherwise StoreKit
    /// overwrites it.
    case proUnlocked = "pro.unlocked"

    /// Make Notes runs spent this month. Must match the app's `"pro.used." + ProFeature.rawValue`,
    /// which `ProTests` checks. Boards are counted, and colors have no free uses, so no keys.
    case proUsedMakeNotes = "pro.used.makeNotes"

    /// The two arguments that preset this key to `value`, ready to append to `launchArguments`.
    public func arguments(_ value: String) -> [String] { ["-" + rawValue, value] }
}
