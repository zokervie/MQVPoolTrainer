import RealityKit
import UIKit
import simd
import PoolPhysics

/// Hình khối và vật liệu "bàn thật" (docs/03-camera-graphics.md): mũi băng vát theo đúng chiều cao mũi băng
/// của mô hình vật lý, miệng lỗ có viền da, nỉ và gỗ có vân. Chỉ là hình ảnh — không ảnh hưởng vật lý.
/// Mọi điểm dựng trong hệ tọa độ vật lý (x dài, y rộng, z lên) rồi đổi qua `map` (RenderMapping).
@MainActor
enum TableDecor {
    typealias Map = (SIMD3<Double>) -> SIMD3<Float>

    // MARK: Lưới tự dựng

    /// Đùn một tiết diện (u: khoảng cách vào trong bàn tính từ đường băng, v: độ cao) dọc một đoạn thẳng.
    static func extrude(profile: [SIMD2<Double>], from a: SIMD2<Double>, to b: SIMD2<Double>,
                        inward n: SIMD2<Double>, map: Map) -> MeshResource? {
        func point(_ base: SIMD2<Double>, _ q: SIMD2<Double>) -> SIMD3<Float> {
            let p = base + n * q.x
            return map(SIMD3(p.x, p.y, q.y))
        }
        var pos: [SIMD3<Float>] = [], nor: [SIMD3<Float>] = [], idx: [UInt32] = []
        let centroid2 = profile.reduce(SIMD2<Double>.zero, +) / Double(profile.count)
        let mid = (a + b) / 2
        let center = point(mid, centroid2)
        func addTri(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>, _ p2: SIMD3<Float>) {
            var nn = simd_normalize(simd_cross(p1 - p0, p2 - p0))
            let fc = (p0 + p1 + p2) / 3
            var q1 = p1, q2 = p2
            if simd_dot(nn, fc - center) < 0 { nn = -nn; swap(&q1, &q2) }   // pháp tuyến hướng ra ngoài
            let base = UInt32(pos.count)
            pos += [p0, q1, q2]; nor += [nn, nn, nn]; idx += [base, base + 1, base + 2]
        }
        let m = profile.count
        for k in 0..<m {
            let p = profile[k], q = profile[(k + 1) % m]
            let a0 = point(a, p), a1 = point(a, q), b0 = point(b, p), b1 = point(b, q)
            addTri(a0, a1, b1); addTri(a0, b1, b0)
        }
        // Hai đầu: quạt từ trọng tâm tiết diện.
        for base in [a, b] {
            let c = point(base, centroid2)
            for k in 0..<m { addTri(c, point(base, profile[k]), point(base, profile[(k + 1) % m])) }
        }
        var d = MeshDescriptor(name: "extrusion")
        d.positions = MeshBuffers.Positions(pos)
        d.normals = MeshBuffers.Normals(nor)
        d.primitives = .triangles(idx)
        return try? MeshResource.generate(from: [d])
    }

    /// Vành khuyên (một cung) nằm ngang tại độ cao z, tâm c — dùng cho viền da miệng lỗ.
    static func ring(center c: SIMD2<Double>, inner r1: Double, outer r2: Double, z: Double,
                     from a0: Double, to a1: Double, segments: Int = 40, map: Map) -> MeshResource? {
        var pos: [SIMD3<Float>] = [], nor: [SIMD3<Float>] = [], idx: [UInt32] = []
        let up = simd_normalize(map(SIMD3(c.x, c.y, z + 1)) - map(SIMD3(c.x, c.y, z)))
        for s in 0...segments {
            let t = a0 + (a1 - a0) * Double(s) / Double(segments)
            let dir = SIMD2(cos(t), sin(t))
            for r in [r1, r2] {
                let p = c + dir * r
                pos.append(map(SIMD3(p.x, p.y, z))); nor.append(up)
            }
            if s > 0 {
                let k = UInt32(2 * s)
                idx += [k - 2, k - 1, k + 1, k - 2, k + 1, k]
            }
        }
        var d = MeshDescriptor(name: "ring")
        d.positions = MeshBuffers.Positions(pos)
        d.normals = MeshBuffers.Normals(nor)
        d.primitives = .triangles(idx)
        return try? MeshResource.generate(from: [d])
    }

    // MARK: Vân tự sinh (xác định — cùng ảnh mỗi lần chạy)

    /// Ảnh xám 256×256: nhiễu sợi nhỏ + thớ dệt chéo rất nhẹ (nỉ) hoặc vân dọc (gỗ). Màu do `tint` của vật liệu.
    static func texture(kind: String) -> TextureResource? {
        let n = 256
        var rng = SplitMix64(seed: kind == "felt" ? 0xF31 : 0x900D)
        var px = [UInt8](repeating: 0, count: n * n * 4)
        var grain = [Double](repeating: 0, count: n)
        for x in 0..<n { grain[x] = rng.unit() }
        for y in 0..<n {
            for x in 0..<n {
                var v: Double
                if kind == "felt" {
                    let weave = 0.025 * sin(Double(x + y) * 0.9) * sin(Double(x - y) * 0.9)
                    v = 0.93 + 0.07 * (rng.unit() - 0.5) * 2 * 0.6 + weave
                } else {
                    // Vân gỗ: sọc dọc lượn sóng + nhiễu.
                    let wave = sin(Double(x) * 0.18 + 3 * sin(Double(y) * 0.025) + grain[x] * 0.8)
                    v = 0.82 + 0.12 * wave + 0.05 * (rng.unit() - 0.5)
                }
                let b = UInt8(max(0, min(255, v * 255)))
                let i = (y * n + x) * 4
                px[i] = b; px[i + 1] = b; px[i + 2] = b; px[i + 3] = 255
            }
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let image: CGImage? = px.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        guard let img = image else { return nil }
        return try? TextureResource.generate(from: img, options: .init(semantic: .color))
    }

    static func felt(_ color: UIColor, tiles: SIMD2<Float>, texture: TextureResource?) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        if let texture { m.baseColor = .init(tint: color, texture: .init(texture)) } else { m.baseColor = .init(tint: color) }
        m.roughness = 0.92
        m.metallic = 0.0
        m.textureCoordinateTransform = .init(offset: .zero, scale: tiles, rotation: 0)
        m.faceCulling = .none
        return m
    }

    static func wood(texture: TextureResource?) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        let c = UIColor(red: 0.36, green: 0.18, blue: 0.08, alpha: 1)
        if let texture { m.baseColor = .init(tint: c, texture: .init(texture)) } else { m.baseColor = .init(tint: c) }
        m.roughness = 0.35
        m.metallic = 0.0
        m.clearcoat = 0.7
        m.clearcoatRoughness = 0.15
        m.textureCoordinateTransform = .init(offset: .zero, scale: [1, 6], rotation: 0)
        m.faceCulling = .none
        return m
    }

    static func leather() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: 0.10, green: 0.06, blue: 0.04, alpha: 1))
        m.roughness = 0.5
        m.clearcoat = 0.3
        m.faceCulling = .none
        return m
    }
}
