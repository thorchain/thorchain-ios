// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ThorchainFramework",
    platforms: [
        .macOS(.v10_14), .iOS(.v9), .tvOS(.v12), .watchOS(.v5)
    ],
    products: [
        .library(
            name: "ThorchainFramework",
            targets: ["ThorchainFramework"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.2.1")
    ],
    targets: [
        .target(
            name: "ThorchainFramework",
            dependencies: ["BigInt"]),
        .testTarget(
            name: "ThorchainFrameworkTests",
            dependencies: ["ThorchainFramework"]),
    ]
)
