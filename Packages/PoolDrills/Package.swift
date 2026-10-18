// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PoolDrills",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PoolDrills", targets: ["PoolDrills"])
    ],
    targets: [
        .target(name: "PoolDrills"),
        .testTarget(name: "PoolDrillsTests", dependencies: ["PoolDrills"],
                    resources: [.copy("Fixtures")])
    ]
)
