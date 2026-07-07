// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MeowVault",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MeowVault", targets: ["MeowVault"]),
        .library(name: "MeowVaultCore", targets: ["MeowVaultCore"])
    ],
    targets: [
        .target(
            name: "MeowVaultCore"
        ),
        .executableTarget(
            name: "MeowVault",
            dependencies: ["MeowVaultCore"]
        ),
        .testTarget(
            name: "MeowVaultCoreTests",
            dependencies: ["MeowVaultCore"]
        ),
    ]
)
