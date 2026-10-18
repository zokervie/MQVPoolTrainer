// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PoolPhysics",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PoolPhysics", targets: ["PoolPhysics"])
    ],
    targets: [
        .target(name: "PoolPhysics"),
        .testTarget(name: "PoolPhysicsTests", dependencies: ["PoolPhysics"])
    ]
)
