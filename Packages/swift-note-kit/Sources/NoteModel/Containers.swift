import SwiftData

/// The iCloud container the store syncs through, as in the app's entitlements. Named once: a
/// second spelling is a second, empty database.
public enum ICloudContainer {
    public static let identifier = "iCloud.com.thebinarykitchen.Stickies"
}

/// The only ways to open the store. Use these rather than building a `ModelContainer` directly.
///
/// Each names its `cloudKitDatabase` explicitly: the default, `.automatic`, syncs wherever
/// entitlements allow. Both take their models from ``CurrentSchema``.
extension ModelContainer {
    /// The persistent store, in the app's default location.
    ///
    /// - Parameter syncing: Whether it mirrors to the private database in
    ///   ``ICloudContainer/identifier``. The app syncs; a persistence UI test opens it without, so
    ///   its notes neither reach the simulator's iCloud account nor meet that account's. Signed out
    ///   of iCloud, a syncing store is a store on this device that syncs once they sign in.
    public static func onDisk(syncing: Bool) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: CurrentSchema.self),
            migrationPlan: NoteMigrationPlan.self,
            configurations: ModelConfiguration(
                cloudKitDatabase: syncing ? .private(ICloudContainer.identifier) : .none)
        )
    }

    /// A fresh in-memory store for previews and tests. Never syncs.
    ///
    /// Uses the migration plan too, so tests catch a plan that disagrees with ``CurrentSchema``.
    public static func inMemory() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: CurrentSchema.self),
            migrationPlan: NoteMigrationPlan.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    }
}
