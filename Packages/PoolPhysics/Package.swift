// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PoolPhysics",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PoolPhysics", targets: ["PoolPhysics"]),
        .executable(name: "poolsim", targets: ["poolsim"])
    ],
    targets: [
        .target(name: "PoolPhysics"),
        // Công cụ dòng lệnh cho đối chứng pooltool (Tools/validation). Không nằm trong app.
        .executableTarget(name: "poolsim", dependencies: ["PoolPhysics"]),
        .testTarget(name: "PoolPhysicsTests", dependencies: ["PoolPhysics"])
    ]
)
