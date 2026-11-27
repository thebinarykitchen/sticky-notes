import Testing

@testable import LaunchArguments

/// How a flag or preset is found is `swift-launch-options`' to test; what's left here is that this
/// app's cases are spelled so a launch can carry them. Duplicate raw values don't compile.
struct LaunchArgumentsTests {
    @Test func flagsAreSpelledAsOptions() {
        #expect(LaunchFlag.spellingProblems == [])
    }

    @Test func defaultsCanBePreset() {
        #expect(LaunchDefault.spellingProblems == [])
    }

    /// The app's keys are `"pro.used." + ProFeature.rawValue`; `ProTests` checks the suffix.
    @Test func proCountsShareOnePrefix() {
        #expect(LaunchDefault.proUsedMakeNotes.rawValue.hasPrefix("pro.used."))
        #expect(!LaunchDefault.proUnlocked.rawValue.hasPrefix("pro.used."))
    }
}
