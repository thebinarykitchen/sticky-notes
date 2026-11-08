import Foundation
import NoteModel
import PurchaseKit
import PurchaseTesting
import StoreKit
import StoreKitTest
import Testing

@testable import StickyNotes

/// The purchase itself, against `StoreKit.storekit` — the same configuration the app ships
/// against, bundled into this target so the product id can't drift from the one being sold.
///
/// The UI suite launches with `--no-storekit`, because presetting `pro.unlocked` only holds while
/// nothing is asking the App Store. That flag turns all of this off, so what a real transaction
/// does to ``Pro`` is only ever exercised here.
///
/// `.serialized`: `SKTestSession` is process-wide, and so is `UserDefaults.standard`.
///
/// **These no-op where the harness isn't serving.** `SKTestSession` sometimes comes up with no
/// products at all — seen in `task-manager` on a simulator whose automation stack had already
/// been wedged by a killed run — and that is a fact about the device, not about the app. The
/// release script to come gates an upload on this suite, as `task-manager`'s does, so a
/// simulator that won't play must not stop a release; ``withStore(_:)`` checks and returns
/// instead. A run that prints the skip note has proved nothing: re-run it on a fresh simulator
/// before trusting it.
@MainActor
@Suite("Buying Pro", .serialized)
struct PurchaseTests {
    /// Runs `body` against a clean store and no Pro state in defaults, putting back what was
    /// there.
    ///
    /// The session is held across the whole body: it stops intercepting StoreKit the moment it
    /// is released, and a `let` the compiler can see the end of is released before the
    /// assertions run — which reads as "the product wouldn't load" rather than as a lifetime bug.
    private func withStore(_ body: @MainActor (SKTestSession) async throws -> Void) async throws {
        try await withStoreSession(
            configurationNamed: "StoreKit", product: ProProduct.store,
            clearing: ProFeature.storedKeys, body)
    }

    private func untilOwned() async throws {
        try await PurchaseTesting.untilOwned(ProProduct.store)
    }

    @Test("The product being sold is the one the app asks for")
    func theProductLoads() async throws {
        try await withStore { _ in
            let product = try #require(await ProProduct.store.load(), "no product for \(ProProduct.id)")

            #expect(product.id == ProProduct.id)
            #expect(product.type == .nonConsumable)
            #expect(!product.displayPrice.isEmpty, "the sheet has a price-shaped hole in it")
        }
    }

    @Test("Nothing is owned before anything is bought")
    func nothingIsOwnedAtFirst() async throws {
        try await withStore { _ in
            #expect(await ProProduct.store.isOwned() == false)
        }
    }

    @Test("Buying it unlocks Pro and stops counting free uses")
    func buyingUnlocks() async throws {
        try await withStore { session in
            let pro = Pro()
            await pro.purchase.refresh()
            #expect(!pro.isUnlocked)

            _ = try await session.buyProduct(identifier: ProProduct.id)
            try await untilOwned()
            await pro.purchase.refresh()

            #expect(pro.isUnlocked)
            #expect(pro.allows(.makeNotes))
            #expect(pro.allowsAnotherBoard(having: 100))
            #expect(pro.allows(NoteColor.purple))
            pro.spend(.makeNotes)
            #expect(pro.allowance.used(.makeNotes) == 0, "an owner's uses are counted anyway")
        }
    }

    @Test("What was bought is still owned next launch")
    func ownershipSurvivesALaunch() async throws {
        try await withStore { session in
            _ = try await session.buyProduct(identifier: ProProduct.id)
            try await untilOwned()

            // A second `Pro` is the next launch: it starts from the cached value and asks again.
            let pro = Pro()
            await pro.purchase.refresh()

            #expect(pro.isUnlocked)
        }
    }

    /// `currentEntitlements` is read from on-device signed data, so an empty result means not
    /// owned — and `refresh` locks on it as well as unlocking. Without that, editing the
    /// preference by hand would buy Pro for free.
    @Test("A hand-edited default doesn't unlock Pro")
    func aForgedDefaultIsLockedBack() async throws {
        try await withStore { _ in
            UserDefaults.standard.set(true, forKey: ProPreference.unlockedKey)
            let pro = Pro()
            #expect(pro.isUnlocked, "the cached value is trusted until StoreKit answers")

            await pro.purchase.refresh()

            #expect(!pro.isUnlocked, "an unowned app stayed unlocked on a forged default")
            #expect(
                !UserDefaults.standard.bool(forKey: ProPreference.unlockedKey),
                "and the lock wasn't written back")
        }
    }

    // A refund is not asserted here: `SKTestSession.refundTransaction` does not reach
    // `Transaction.currentEntitlements` in the XcodeTest environment, so the test would be
    // asserting the harness rather than the app. The branch it would cover — `refresh` locking
    // when nothing is owned — is `aForgedDefaultIsLockedBack` above.

    // The purchases below answer for the App Store through `OneTimePurchase.buy(_:)`. The sheet's own path,
    // `buy(with:)`, takes a `PurchaseAction`, which needs a window to present in.

    @Test("A purchase that went through unlocks Pro")
    func aCompletedPurchaseUnlocks() async throws {
        try await withStore { session in
            let pro = Pro()
            await pro.purchase.refresh()

            let outcome = await pro.purchase.buy { _ in
                .success(.verified(try await session.buyProduct(identifier: ProProduct.id)))
            }

            #expect(outcome == .done)
            #expect(pro.isUnlocked)
        }
    }

    @Test("A purchase the store won't take leaves Pro locked")
    func aFailedPurchaseUnlocksNothing() async throws {
        try await withStore { _ in
            let pro = Pro()
            await pro.purchase.refresh()

            let outcome = await pro.purchase.buy { _ in
                throw StoreKitError.networkError(URLError(.notConnectedToInternet))
            }

            #expect(outcome == .failed)
            #expect(!pro.isUnlocked)
            #expect(await ProProduct.store.isOwned() == false)
        }
    }

    /// Ask to Buy: the purchase arrives later through `Transaction.updates`, if it is approved.
    @Test("A purchase waiting for approval leaves Pro locked")
    func aPendingPurchaseUnlocksNothing() async throws {
        try await withStore { _ in
            let pro = Pro()
            await pro.purchase.refresh()

            let outcome = await pro.purchase.buy { _ in .pending }

            #expect(outcome == .pending)
            #expect(!pro.isUnlocked)
        }
    }

    @Test("Backing out of a purchase, either way StoreKit reports it, unlocks nothing")
    func aCancelledPurchaseUnlocksNothing() async throws {
        try await withStore { _ in
            let pro = Pro()
            await pro.purchase.refresh()

            let answered = await pro.purchase.buy { _ in .userCancelled }
            let thrown = await pro.purchase.buy { _ in throw StoreKitError.userCancelled }

            #expect(answered == .cancelled)
            #expect(thrown == .cancelled)
            #expect(!pro.isUnlocked)
        }
    }

    /// Verification is what stands between a forged transaction and a free Pro.
    @Test("An unverified purchase doesn't unlock Pro")
    func anUnverifiedPurchaseUnlocksNothing() async throws {
        try await withStore { session in
            let pro = Pro()
            await pro.purchase.refresh()

            let outcome = await pro.purchase.buy { _ in
                let transaction = try await session.buyProduct(identifier: ProProduct.id)
                return .success(.unverified(transaction, .invalidSignature))
            }

            #expect(outcome == .failed)
            #expect(!pro.isUnlocked)
        }
    }

    /// Restore syncs with the App Store and then re-reads entitlements; with nothing owed it is
    /// the refresh that matters, and it must not unlock on a sync that found nothing.
    @Test("Restoring with nothing owed leaves Pro locked")
    func restoringNothingOwed() async throws {
        try await withStore { _ in
            let pro = Pro()

            let outcome = await pro.purchase.restore()

            #expect(outcome == .done)
            #expect(!pro.isUnlocked)
        }
    }

    @Test("Restoring after a purchase gives it back")
    func restoringAPurchase() async throws {
        try await withStore { session in
            _ = try await session.buyProduct(identifier: ProProduct.id)
            try await untilOwned()

            let pro = Pro()
            let outcome = await pro.purchase.restore()

            #expect(outcome == .done)
            #expect(pro.isUnlocked)
        }
    }

    /// Before this, the sheet said "No purchases to restore" about a restore that never reached
    /// the App Store.
    @Test("A restore that couldn't reach the App Store says so")
    func aFailedRestoreSaysSo() async throws {
        try await withStore { session in
            try await session.setSimulatedError(
                .generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
            let pro = Pro()

            let outcome = await pro.purchase.restore()

            #expect(outcome == .failed)
            #expect(!pro.isUnlocked)
            try await session.setSimulatedError(nil, forAPI: .appStoreSync)
        }
    }

    @Test("A restore whose sign-in was cancelled says nothing")
    func aCancelledRestoreSaysNothing() async throws {
        try await withStore { session in
            try await session.setSimulatedError(.generic(.userCancelled), forAPI: .appStoreSync)
            let pro = Pro()

            let outcome = await pro.purchase.restore()

            #expect(outcome == .cancelled)
            try await session.setSimulatedError(nil, forAPI: .appStoreSync)
        }
    }

    /// The listener is owned by ``Pro`` rather than a window, so closing the window that started
    /// it doesn't stop it, and a later call only refreshes.
    @Test("Watching the store picks up what is already owned, twice over")
    func watchingTheStore() async throws {
        try await withStore { session in
            _ = try await session.buyProduct(identifier: ProProduct.id)
            try await untilOwned()

            let pro = Pro()
            await pro.purchase.watchTheStore()
            #expect(pro.isUnlocked)

            await pro.purchase.watchTheStore()
            #expect(pro.isUnlocked, "the second call took the unlock back")
        }
    }
}
