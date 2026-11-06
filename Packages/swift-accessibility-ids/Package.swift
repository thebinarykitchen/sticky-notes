// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-accessibility-ids",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "AccessibilityIdentifiers", targets: ["AccessibilityIdentifiers"])
    ],
    targets: [
        .target(name: "AccessibilityIdentifiers"),
        .testTarget(
            name: "AccessibilityIdentifiersTests",
            dependencies: ["AccessibilityIdentifiers"]
        ),
    ]
)
