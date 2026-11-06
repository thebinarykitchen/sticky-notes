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
/// 2. Add `NoteSchemaVN` listing the live types, point ``CurrentSchema`` at it, and add a stage
///    from N-1 to N. `.lightweight` covers adding a model; adding or removing an optional or
///    defaulted property; renames via `@Attribute(originalName:)`; and index changes.
/// 3. Append it to ``schemas``, ascending.
///
/// Until 1.0 ships, version 1.0.0 may still change in place.
public enum NoteMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [NoteSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
