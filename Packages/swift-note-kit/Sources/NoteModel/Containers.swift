import SwiftData

/// The only ways to open the store. Use these rather than building a `ModelContainer` directly.
///
/// Each names its `cloudKitDatabase` explicitly: the default, `.automatic`, syncs wherever
/// entitlements allow. Both take their models from ``CurrentSchema``.
extension ModelContainer {
    /// The persistent store, in the app's default location.
    public static func onDisk() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: CurrentSchema.self),
            migrationPlan: NoteMigrationPlan.self,
            configurations: ModelConfiguration(cloudKitDatabase: .none)
        )
    }

    /// A fresh in-memory store for previews and tests.
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
