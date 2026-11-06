import NoteModel
import StoreKit
import SwiftUI

/// Observable Pro state: whether it is unlocked, and what is left free.
///
/// Mirrors StoreKit and ``ProPreference`` so views update. ``isUnlocked`` starts from the cached
/// value, so a paid user doesn't see a locked UI while StoreKit responds.
@MainActor
@Observable
final class Pro {
    /// Persisted to ``ProPreference`` on change.
    private(set) var isUnlocked: Bool = ProPreference.isUnlocked {
        didSet { ProPreference.isUnlocked = isUnlocked }
    }

    /// Nil until loaded, or when StoreKit is unavailable.
    private(set) var product: Product?

    /// Uses spent per monthly feature and the ``ProPeriod`` they were counted in, mirrored from
    /// ``ProPreference`` so views update. Read through ``usedThisMonth(_:)``: an app left open past
    /// the 1st is still holding last month's counts.
    private var used: [ProFeature: (count: Int, period: Int)]

    /// The current ``ProPeriod`` stamp. Injected for tests.
    private let period: () -> Int

    /// The `Transaction.updates` listener. See ``watchTheStore()``.
    private var watcher: Task<Void, Never>?

    init(period: @escaping () -> Int = { ProPeriod.current }) {
        self.period = period
        ProPreference.adoptUnstampedCounts()
        let now = period()
        used = Dictionary(
            uniqueKeysWithValues: ProFeature.monthly.map { ($0, (ProPreference.used($0), now)) }
        )
    }

    /// The localized price from StoreKit.
    var price: String? { product?.displayPrice }

    /// Whether the feature may be used again. Check immediately before doing the work. Boards
    /// and colors are allowed outright only with Pro: ask ``allowsAnotherBoard(having:)``, and
    /// `allows(_:)` with a color, for what is free of them.
    func allows(_ feature: ProFeature) -> Bool {
        switch feature {
        case .makeNotes: isUnlocked || ProFeature.allowsMakeNotes(used: usedThisMonth(feature))
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
        guard !isUnlocked, ProFeature.monthly.contains(feature) else { return }
        let count = usedThisMonth(feature) + 1
        used[feature] = (count, period())
        ProPreference.setUsed(count, for: feature)
    }

    /// Re-reads ``used`` from ``ProPreference``, so a count spent in another window or process
    /// is picked up. Called on activation.
    func rollOver() {
        let now = period()
        for feature in ProFeature.monthly {
            used[feature] = (ProPreference.used(feature), now)
        }
    }

    /// The feature's count, or 0 once the month it was counted in has passed.
    private func usedThisMonth(_ feature: ProFeature) -> Int {
        guard let tally = used[feature] else { return 0 }
        return ProPeriod.carried(tally.count, stamped: tally.period, into: period())
    }

    /// Buys Pro through the sheet's `@Environment(\.purchase)`. That action knows the sheet's
    /// window, so the payment sheet opens over the one that asked; `product.purchase()` would
    /// leave the system to guess among an iPad's or a Mac's windows.
    func buy(with purchase: PurchaseAction) async -> ProProduct.Outcome {
        await buy { try await purchase($0) }
    }

    /// ``buy(with:)`` with the App Store's answer handed in, for tests.
    func buy(
        _ purchasing: (Product) async throws -> Product.PurchaseResult
    ) async -> ProProduct.Outcome {
        guard let product else { return .failed }
        let outcome = await ProProduct.purchase(product, by: purchasing)
        if outcome == .done { isUnlocked = true }
        return outcome
    }

    /// Loads the product and sets ``isUnlocked`` from current entitlements, locking as well as
    /// unlocking, so a hand-edited default can't unlock Pro.
    ///
    /// `currentEntitlements` is read from on-device signed data, so an empty result means not
    /// owned. When StoreKit is disabled for tests, the cached value is left alone.
    func refresh() async {
        if product == nil { product = await ProProduct.load() }
        guard ProProduct.isOfferedToApp else { return }
        isUnlocked = await ProProduct.isOwned()
    }

    /// Syncs with the App Store, then refreshes whatever the sync came to.
    func restore() async -> ProProduct.Outcome {
        let outcome = await ProProduct.sync()
        await refresh()
        return outcome
    }

    /// Refreshes, and on first call starts listening to `Transaction.updates` for purchases made
    /// elsewhere (Ask to Buy approvals, other devices).
    ///
    /// The listener is owned here rather than by a window, so closing the window that started it
    /// doesn't stop it. Later calls only refresh.
    func watchTheStore() async {
        await refresh()

        guard watcher == nil, ProProduct.isOfferedToApp else { return }
        watcher = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
    }
}

extension View {
    /// Rolls over allowances and refreshes ``Pro`` whenever the window becomes active. Apply to
    /// every scene.
    ///
    /// Takes `pro` explicitly: a modifier is outside `.environment(_:)` calls chained before it,
    /// so reading it from the environment would crash.
    func watchesTheStore(_ pro: Pro) -> some View {
        modifier(WatchesTheStore(pro: pro))
    }
}

private struct WatchesTheStore: ViewModifier {
    let pro: Pro

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.task(id: scenePhase) {
            guard scenePhase == .active else { return }
            pro.rollOver()
            await pro.watchTheStore()
        }
    }
}
