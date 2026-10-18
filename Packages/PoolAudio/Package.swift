// swift-tools-version:6.0
import PackageDescription

// Zoker Acoustic Physics — lõi âm thanh thuần Swift (không AVFoundation) để test được bằng `swift test`.
// Phần phát bằng AVAudioEngine nằm trong App/.
let package = Package(
    name: "PoolAudio",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PoolAudio", targets: ["PoolAudio"]),
        .executable(name: "audiodump", targets: ["audiodump"])
    ],
    dependencies: [
        .package(path: "../PoolPhysics")
    ],
    targets: [
        .target(name: "PoolAudio", dependencies: [.product(name: "PoolPhysics", package: "PoolPhysics")]),
        // Xuất WAV để nghe thử (chỉ dùng trong CI / máy phát triển, không nằm trong app).
        .executableTarget(name: "audiodump", dependencies: ["PoolAudio", .product(name: "PoolPhysics", package: "PoolPhysics")]),
        .testTarget(name: "PoolAudioTests", dependencies: ["PoolAudio", .product(name: "PoolPhysics", package: "PoolPhysics")])
    ]
)
