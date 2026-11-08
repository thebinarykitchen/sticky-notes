// swift-tools-version: 6.4

import PackageDescription

// Matches the app target's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so unannotated types
// here have the same isolation as the code that calls them.
let isolation: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "swift-note-kit",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "NoteModel", targets: ["NoteModel"])
    ],
    dependencies: [
        .package(path: "../../../launchpad/Packages/swift-schema-testing")
    ],
    targets: [
        .target(name: "NoteModel", swiftSettings: isolation),
        .testTarget(
            name: "NoteModelTests",
            dependencies: [
                "NoteModel",
                .product(name: "SchemaTesting", package: "swift-schema-testing"),
            ],
            // Read from the source tree by `SchemaFixtures`, not bundled.
            exclude: ["Fixtures"],
            swiftSettings: isolation
        ),
    ]
)
