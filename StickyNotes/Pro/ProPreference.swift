import Foundation

/// Persisted Pro state in `UserDefaults.standard`: the unlock cache, and the monthly features'
/// use counts with their month stamps. Only ``Pro`` writes here.
enum ProPreference {
    /// A cache of ``ProProduct/isOwned()`` for launch, before StoreKit responds. Absent means
    /// locked.
    static let unlockedKey = "pro.unlocked"

    /// Must match `LaunchDefault.proUsed…`; `ProTests` checks it.
    static func usedKey(_ feature: ProFeature) -> String { "pro.used." + feature.rawValue }

    /// The ``ProPeriod`` stamp for a feature's count. Per feature, since a shared stamp would
    /// misdate the other features' counts.
    static func periodKey(_ feature: ProFeature) -> String { "pro.period." + feature.rawValue }

    static var isUnlocked: Bool {
        get { UserDefaults.standard.bool(forKey: unlockedKey) }
        set { UserDefaults.standard.set(newValue, forKey: unlockedKey) }
    }

    /// Uses spent in the current month; a count from an earlier month reads as 0.
    static func used(_ feature: ProFeature) -> Int {
        ProPeriod.carried(
            UserDefaults.standard.integer(forKey: usedKey(feature)),
            stamped: period(feature),
            into: ProPeriod.current
        )
    }

    /// The count's month stamp, or nil if unstamped. Uses `object(forKey:)`, since
    /// `integer(forKey:)` returns 0 for a missing key.
    static func period(_ feature: ProFeature) -> Int? {
        UserDefaults.standard.object(forKey: periodKey(feature)) as? Int
    }

    static func setUsed(_ count: Int, for feature: ProFeature) {
        UserDefaults.standard.set(count, forKey: usedKey(feature))
        UserDefaults.standard.set(ProPeriod.current, forKey: periodKey(feature))
    }

    /// Stamps nonzero counts that have no month stamp with the current month, so they aren't
    /// reset. Covers counts from older builds and counts preset by UI tests.
    ///
    /// Call from ``Pro/init()`` before reading allowances.
    static func adoptUnstampedCounts() {
        for feature in ProFeature.monthly where period(feature) == nil {
            guard UserDefaults.standard.integer(forKey: usedKey(feature)) > 0 else { continue }
            UserDefaults.standard.set(ProPeriod.current, forKey: periodKey(feature))
        }
    }
}
