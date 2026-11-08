import NoteModel
import PurchaseKit
import SwiftUI

/// What Pro allows, and what is left free. Whether it is bought is ``purchase``'s to know, and what
/// has been spent is ``allowance``'s.
@MainActor
@Observable
final class Pro {
    let purchase = OneTimePurchase(ProProduct.store, cacheKey: ProPreference.unlockedKey)
    let allowance: MonthlyAllowance<ProFeature>

    /// - Parameter period: The current ``MonthStamp``. Injected for tests.
    init(period: @escaping @MainActor () -> Int = { MonthStamp.current }) {
        allowance = MonthlyAllowance(
            features: ProFeature.monthly, keyPrefix: ProPreference.allowancePrefix, period: period)
    }

    var isUnlocked: Bool { purchase.isUnlocked }

    /// The localized price from StoreKit.
    var price: String? { purchase.price }

    /// Whether the feature may be used again. Check immediately before doing the work. Boards
    /// and colors are allowed outright only with Pro: ask ``allowsAnotherBoard(having:)``, and
    /// `allows(_:)` with a color, for what is free of them.
    func allows(_ feature: ProFeature) -> Bool {
        switch feature {
        case .makeNotes: isUnlocked || ProFeature.allowsMakeNotes(used: allowance.used(feature))
        case .boards, .colors: isUnlocked
        }
    }

    /// Whether a board may be added beside the `count` there are. Nothing is spent: a board
    /// deleted frees its place, and boards beyond the free ones are never taken back.
    func allowsAnotherBoard(having count: Int) -> Bool {
        isUnlocked || ProFeature.allowsAnotherBoard(having: count)
    }

    /// Whether a note may be made `color`. A note already that color keeps it either way.
    func allows(_ color: NoteColor) -> Bool {
        isUnlocked || NoteColor.handedOut.contains(color)
    }

    /// Whether the allowance is used up. Check after ``spend(_:)`` to show the Pro sheet on the
    /// use that exhausts it.
    func hasRunOut(of feature: ProFeature) -> Bool { !allows(feature) }

    /// Counts one use of a monthly feature. Does nothing once unlocked, or for a feature that
    /// isn't spent.
    func spend(_ feature: ProFeature) {
        guard !isUnlocked else { return }
        allowance.spend(feature)
    }
}
