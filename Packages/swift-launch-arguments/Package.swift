// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-launch-arguments",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "LaunchArguments", targets: ["LaunchArguments"])
    ],
    targets: [
        .target(name: "LaunchArguments"),
        .testTarget(name: "LaunchArgumentsTests", dependencies: ["LaunchArguments"]),
    ]
)
