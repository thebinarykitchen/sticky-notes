import LaunchArguments
import OSLog
import PurchaseKit

/// The Pro in-app purchase.
enum ProProduct {
    /// The non-consumable's product ID, also in `StoreKit.storekit`.
    static let id = "com.thebinarykitchen.Stickies.IAP.Pro"

    /// False when ``LaunchFlag/noStoreKit`` is passed. Debug only: on macOS anyone can pass launch
    /// arguments, and skipping StoreKit would leave a preset unlock in place.
    static var isOfferedToApp: Bool {
        #if DEBUG
            !LaunchFlag.noStoreKit.isPresent()
        #else
            true
        #endif
    }

    static let store = OneTimeProduct(id: id, isStoreEnabled: isOfferedToApp, logger: .pro)
}

extension Logger {
    fileprivate static let pro = Logger(
        subsystem: "com.thebinarykitchen.Stickies", category: "pro")
}
