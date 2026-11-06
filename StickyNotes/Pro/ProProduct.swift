import Foundation
import LaunchArguments
import OSLog
import StoreKit

/// The Pro in-app purchase, and all StoreKit calls.
enum ProProduct {
    /// The non-consumable's product ID, also in `StoreKit.storekit`.
    static let id = "com.thebinarykitchen.StickyNotes.IAP.Pro"

    /// False when ``LaunchFlag/noStoreKit`` is passed. Debug only: on macOS anyone can pass launch
    /// arguments, and skipping StoreKit would leave a preset unlock in place.
    static var isOfferedToApp: Bool {
        #if DEBUG
            !LaunchFlag.noStoreKit.isPresent()
        #else
            true
        #endif
    }

    /// What a purchase or a restore came to, for the sheet to put into words.
    nonisolated enum Outcome {
        /// Bought, or the restore reached the App Store.
        case done
        /// Waiting for approval, such as Ask to Buy. An approval arrives through
        /// `Transaction.updates`.
        case pending
        /// The reader backed out. Nothing is said.
        case cancelled
        /// Anything else, an unverified purchase included.
        case failed
    }

    /// Whether a verified, unrevoked entitlement exists for the product.
    static func isOwned() async -> Bool {
        guard isOfferedToApp else { return false }
        for await entitlement in Transaction.currentEntitlements(for: id) {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.revocationDate == nil { return true }
        }
        return false
    }

    /// The product, or nil if it can't be loaded.
    static func load() async -> Product? {
        guard isOfferedToApp else { return nil }
        do {
            return try await Product.products(for: [id]).first
        } catch {
            Logger.pro.error("Couldn't load \(id, privacy: .public): \(error)")
            return nil
        }
    }

    /// `AppStore.sync()`, for Restore Purchases. May prompt the user to sign in.
    ///
    /// Under ``LaunchFlag/noStoreKit`` it answers `.done` without asking, as a store with nothing
    /// to restore would.
    static func sync() async -> Outcome {
        guard isOfferedToApp else { return .done }
        do {
            try await AppStore.sync()
            return .done
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            Logger.pro.error("Restore failed: \(error)")
            return .failed
        }
    }

    /// Buys the product through `purchasing` and says what that came to. A pending purchase
    /// completes later via ``Pro/watchTheStore()``.
    ///
    /// `purchasing` is the sheet's `PurchaseAction` (see ``Pro/buy(with:)``), or a test answering
    /// for the App Store.
    static func purchase(
        _ product: Product,
        by purchasing: (Product) async throws -> Product.PurchaseResult
    ) async -> Outcome {
        do {
            switch try await purchasing(product) {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    Logger.pro.error("Purchase came back unverified")
                    return .failed
                }
                await transaction.finish()
                return .done
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            Logger.pro.error("Purchase failed: \(error)")
            return .failed
        }
    }
}

extension Logger {
    static let pro = Logger(subsystem: "com.thebinarykitchen.StickyNotes", category: "pro")
}
