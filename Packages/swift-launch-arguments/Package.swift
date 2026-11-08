// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-launch-arguments",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "LaunchArguments", targets: ["LaunchArguments"])
    ],
    dependencies: [
        .package(path: "../../../launchpad/Packages/swift-launch-options")
    ],
    targets: [
        .target(
            name: "LaunchArguments",
            dependencies: [.product(name: "LaunchOptions", package: "swift-launch-options")]
        ),
        .testTarget(name: "LaunchArgumentsTests", dependencies: ["LaunchArguments"]),
    ]
)
