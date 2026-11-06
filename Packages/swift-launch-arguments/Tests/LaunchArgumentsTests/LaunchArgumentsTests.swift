import Testing

@testable import LaunchArguments

struct LaunchFlagTests {
    @Test func flagIsFoundWhereItWasPassed() {
        let arguments = ["/path/to/App", "--ephemeral-store", "--seed-store"]
        #expect(LaunchFlag.ephemeralStore.isPresent(in: arguments))
        #expect(LaunchFlag.seedStore.isPresent(in: arguments))
        #expect(!LaunchFlag.reduceMotion.isPresent(in: arguments))
    }

    @Test func nothingIsPresentInAnEmptyRun() {
        for flag in LaunchFlag.allCases {
            #expect(!flag.isPresent(in: ["/path/to/App"]))
        }
    }

    @Test func flagsAreDistinct() {
        let spellings = Set(LaunchFlag.allCases.map(\.rawValue))
        #expect(spellings.count == LaunchFlag.allCases.count)
        for flag in LaunchFlag.allCases {
            #expect(flag.rawValue.hasPrefix("--"))
        }
    }
}

struct LaunchDefaultTests {
    @Test func argumentsPresetTheKey() {
        #expect(LaunchDefault.onboardingFinished.arguments("1") == ["-onboarding.finished", "1"])
        #expect(LaunchDefault.proUnlocked.arguments("1") == ["-pro.unlocked", "1"])
    }

    /// The dash is the argument's, added by `arguments(_:)`; the key is what `UserDefaults` reads.
    @Test func keysAreDistinctAndBare() {
        let keys = Set(LaunchDefault.allCases.map(\.rawValue))
        #expect(keys.count == LaunchDefault.allCases.count)
        for key in LaunchDefault.allCases {
            #expect(!key.rawValue.hasPrefix("-"))
        }
    }

    /// A preset can't be mistaken for a flag, whatever its value.
    @Test func noPresetReadsAsAFlag() {
        let arguments = LaunchDefault.allCases.flatMap { $0.arguments("1") }
        for flag in LaunchFlag.allCases {
            #expect(!flag.isPresent(in: arguments))
        }
    }

    /// The app's keys are `"pro.used." + ProFeature.rawValue`; `ProTests` checks the suffix.
    @Test func proCountsShareOnePrefix() {
        #expect(LaunchDefault.proUsedMakeNotes.rawValue.hasPrefix("pro.used."))
        #expect(!LaunchDefault.proUnlocked.rawValue.hasPrefix("pro.used."))
    }
}
