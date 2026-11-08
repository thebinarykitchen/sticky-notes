/// Where Pro's state lives in `UserDefaults.standard`. These are customers' data: a changed key
/// makes a paid customer look locked until StoreKit answers, and refills every free allowance.
enum ProPreference {
    /// A cache of what the App Store says is owned, for launch, before it answers. Absent means
    /// locked.
    static let unlockedKey = "pro.unlocked"

    /// Starts the keys ``Pro/allowance`` counts under, as in `pro.used.makeNotes`. Has to match
    /// `LaunchDefault.proUsedMakeNotes`, or the UI tests' presets count for nothing.
    static let allowancePrefix = "pro"
}
