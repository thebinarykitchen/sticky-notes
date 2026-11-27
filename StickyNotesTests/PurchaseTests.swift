import NoteModel
import PurchaseTesting
import Testing

@testable import StickyNotes

/// The purchase itself, against `StoreKit.storekit` — the same configuration the app ships
/// against, bundled into this target so the product id can't drift from the one being sold.
///
/// The UI suite launches with `--no-storekit`, because presetting `pro.unlocked` only holds while
/// nothing is asking the App Store. That flag turns all of this off, so what a real transaction
/// does to ``Pro`` is only ever exercised here.
///
/// The scenarios are `PurchaseTesting`'s, run on ``Pro``'s own purchase; what Pro lifts is this
/// app's. `.serialized`: `SKTestSession` is process-wide, and so is `UserDefaults.standard`.
///
/// **These no-op where the harness isn't serving.** `SKTestSession` sometimes comes up with no
/// products at all, and `release` gates an upload on this suite, so each check returns instead.
/// A run that prints the skip note has proved nothing: re-run it on a fresh simulator.
@MainActor
@Suite("Buying Pro", .serialized)
struct PurchaseTests {
    let checks = OneTimePurchaseChecks(
        product: ProProduct.store, cacheKey: ProPreference.unlockedKey,
        clearing: ProFeature.storedKeys
    ) { Pro().purchase }

    @Test(arguments: OneTimePurchaseChecks.Scenario.allCases)
    func thePurchase(_ scenario: OneTimePurchaseChecks.Scenario) async throws {
        try await checks.run(scenario)
    }

    @Test("Buying it unlocks every Pro feature, and stops counting uses")
    func buyingUnlocksEveryFeature() async throws {
        try await checks.withStore { session in
            let pro = Pro()
            try await checks.buy(in: session)
            await pro.purchase.refresh()

            #expect(pro.isUnlocked)
            #expect(pro.allows(.makeNotes))
            #expect(pro.allowsAnotherBoard(having: 100))
            #expect(pro.allows(NoteColor.purple))
            pro.spend(.makeNotes)
            #expect(pro.allowance.used(.makeNotes) == 0, "an owner's uses are counted anyway")
        }
    }
}
