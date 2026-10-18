// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PoolInput",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PoolInput", targets: ["PoolInput"])
    ],
    targets: [
        .target(name: "PoolInput"),
        .testTarget(name: "PoolInputTests", dependencies: ["PoolInput"])
    ]
)
