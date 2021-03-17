// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ThorchainFramework",
    platforms: [
        .macOS(.v10_14), .iOS(.v9), .tvOS(.v12), .watchOS(.v5)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ThorchainFramework",
            targets: ["ThorchainFramework"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.2.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ThorchainFramework",
            dependencies: ["BigInt"]),
        .testTarget(
            name: "ThorchainFrameworkTests",
            dependencies: ["ThorchainFramework"]),
    ]
)
