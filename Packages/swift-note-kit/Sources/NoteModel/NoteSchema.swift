import SwiftData

/// Schema version 1.0.0. Once a later version exists, this must describe what 1.0.0 stores hold
/// on disk, not the current model types.
public enum NoteSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    /// The live types, valid only while this is the newest version — see ``NoteMigrationPlan``.
    public static var models: [any PersistentModel.Type] { [Board.self, Note.self] }
}

/// The schema every container opens with. A test checks it is the last entry in
/// ``NoteMigrationPlan/schemas``.
public typealias CurrentSchema = NoteSchemaV1

/// Migrations between schema versions. No stages yet: 1.0.0 is the only version.
///
/// ## Cutting a version
///
/// 1. Copy *all* of the outgoing version's models into its namespace and point its `models` at
///    the copies. Freezing only some leaves frozen relationships pointing at live models, which
///    crashes on launch.
/// 2. Add `NoteSchemaVN` listing the live types, point ``CurrentSchema`` at it, and add a
///    `.lightweight` stage from N-1 to N. The store syncs, so a version only *adds*: models, and
///    optional or defaulted properties. CloudKit never drops or retypes a field, and a custom
///    stage would run on every device and sync its output into the others'.
/// 3. Append it to ``schemas``, ascending.
/// 4. Record version N's shape and a store written by it, then commit the new files under
///    `Tests/NoteModelTests/Fixtures`. Add what's new to `Fixture` in `SchemaMigrationTests`.
///
///    ```sh
///    RECORD_SCHEMA_FIXTURES=1 swift test --package-path Packages/swift-note-kit \
///      --filter SchemaMigrationTests
///    ```
///
///    A version can only be recorded while it is the current one, and recording never overwrites
///    a file.
///
/// 5. Run a Debug build signed into iCloud so the new fields reach the development schema, then
///    deploy the CloudKit schema to production before the build ships. TestFlight talks to
///    production too, and an undeployed field there is sync failing without an error.
///
/// Until 1.0 ships, version 1.0.0 may still change, by deleting its two fixtures and recording
/// them again. After that, a fixture is never regenerated: it is what that version wrote.
public enum NoteMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [NoteSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
