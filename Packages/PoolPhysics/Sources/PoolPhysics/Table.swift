import Foundation

/// Kích thước bàn và bi theo SI. Gốc tọa độ ở một góc mặt chơi, trục x theo chiều dài,
/// y theo chiều rộng, z hướng lên. Mặt nỉ ở z = 0, tâm bi ở z = R.
public struct TableSpec: Codable, Equatable, Sendable {
    public var length: Double        // m, mặt chơi
    public var width: Double         // m, mặt chơi
    public var ballRadius: Double    // m
    public var ballMass: Double      // kg
    /// Chiều cao mũi băng so với mặt nỉ, tính theo đường kính bi (WPA: 62,5–64,5%).
    public var cushionHeightRatio: Double
    public var cornerPocketMouth: Double // m
    public var sidePocketMouth: Double   // m

    public init(length: Double, width: Double,
                ballRadius: Double = 0.028575, ballMass: Double = 0.17,
                cushionHeightRatio: Double = 0.635,
                cornerPocketMouth: Double = 0.1143, sidePocketMouth: Double = 0.127) {
        self.length = length
        self.width = width
        self.ballRadius = ballRadius
        self.ballMass = ballMass
        self.cushionHeightRatio = cushionHeightRatio
        self.cornerPocketMouth = cornerPocketMouth
        self.sidePocketMouth = sidePocketMouth
    }

    public static let nineFoot = TableSpec(length: 2.54, width: 1.27)
    public static let eightFoot = TableSpec(length: 2.34, width: 1.17)
    public static let sevenFoot = TableSpec(length: 1.98, width: 0.99)

    /// Chiều cao mũi băng tuyệt đối (m).
    public var cushionHeight: Double { cushionHeightRatio * 2 * ballRadius }

    // MARK: Đơn vị kim cương (dài 8, rộng 4)

    public var diamondSize: Double { length / 8 }

    /// Kim cương → mét (mặt phẳng bàn).
    public func meters(fromDiamonds d: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2(d.x * length / 8, d.y * width / 4)
    }

    /// Mét → kim cương.
    public func diamonds(fromMeters m: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2(m.x * 8 / length, m.y * 4 / width)
    }
}
