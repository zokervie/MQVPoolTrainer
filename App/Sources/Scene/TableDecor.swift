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
        // Bóng vừa phải (bản trước clearcoat 0,7 tạo vệt chói trắng trên băng dưới).
        m.roughness = 0.45
        m.metallic = 0.0
        m.clearcoat = 0.35
        m.clearcoatRoughness = 0.3
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

// MARK: - Bóng mềm, môi trường phản chiếu, phòng, cơ (đợt đồ họa 2, tham khảo kỹ thuật BankLab)
@MainActor
extension TableDecor {
    /// Ảnh xám 8 bit kích thước n×n từ hàm giá trị (0…1) → TextureResource.
    static func grayTexture(_ n: Int, semantic: TextureResource.Semantic = .color,
                            rgb: ((Int, Int) -> (Double, Double, Double))) -> TextureResource? {
        var px = [UInt8](repeating: 255, count: n * n * 4)
        for y in 0..<n { for x in 0..<n {
            let (r, g, b) = rgb(x, y)
            let i = (y * n + x) * 4
            px[i] = UInt8(max(0, min(255, r * 255))); px[i + 1] = UInt8(max(0, min(255, g * 255)))
            px[i + 2] = UInt8(max(0, min(255, b * 255)))
        } }
        let image: CGImage? = px.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        guard let image else { return nil }
        return try? TextureResource.generate(from: image, options: .init(semantic: semantic))
    }

    /// Bóng mềm dưới bi: độ mờ giảm dần theo bán kính (trắng = đậm), dùng làm texture độ trong suốt.
    static func softShadowMaterial() -> UnlitMaterial {
        var m = UnlitMaterial(color: .black)
        if let tex = grayTexture(128, semantic: .raw, rgb: { x, y in
            let dx = (Double(x) + 0.5) / 64 - 1, dy = (Double(y) + 0.5) / 64 - 1
            let r = (dx * dx + dy * dy).squareRoot()
            let core = max(0, 1 - r)                    // tắt dần tới mép
            let v = 0.75 * pow(core, 1.8)
            return (v, v, v)
        }) {
            m.blending = .transparent(opacity: .init(scale: 1, texture: .init(tex)))
        } else {
            m.blending = .transparent(opacity: 0.3)
        }
        return m
    }

    /// Bản đồ pháp tuyến nỉ: thớ sợi rất nhỏ, để ánh đèn xiên làm mặt nỉ "có vải".
    static func feltNormal() -> TextureResource? {
        var rng = SplitMix64(seed: 0xC10F)
        var hgt = [Double](repeating: 0, count: 128 * 128)
        for i in hgt.indices { hgt[i] = rng.unit() }
        return grayTexture(128, semantic: .normal) { x, y in
            func h(_ a: Int, _ b: Int) -> Double {
                let row: Int = (b + 128) % 128, col: Int = (a + 128) % 128
                return hgt[row * 128 + col]
            }
            let nx: Double = (h(x - 1, y) - h(x + 1, y)) * 0.35
            let ny: Double = (h(x, y - 1) - h(x, y + 1)) * 0.35
            return (0.5 + nx * 0.5, 0.5 + ny * 0.5, 1.0)
        }
    }

    /// Ván gỗ (tường, sàn): sọc ván + vân. Màu nhân với `tint` của vật liệu.
    static func planks(seed: UInt64) -> TextureResource? {
        var rng = SplitMix64(seed: seed)
        var shade = [Double](repeating: 0, count: 8)
        for i in shade.indices { shade[i] = 0.75 + 0.25 * rng.unit() }
        return grayTexture(256) { x, y in
            let plank: Int = x / 32
            let seam: Double = x % 32 == 0 ? 0.45 : 1.0
            let wave: Double = 2 * sin(Double(x) * 0.31)
            let phase: Double = Double(y) * 0.06 + Double(plank) * 1.7 + wave
            let grain: Double = 0.88 + 0.1 * sin(phase)
            let v: Double = shade[plank % 8] * grain * seam
            return (v, v, v)
        }
    }

    /// Môi trường phản chiếu (ảnh 360° dựng bằng mã): phòng gỗ tối, hai bóng đèn trần sáng ngay trên bàn.
    /// Cho bi bóng loáng phản chiếu đèn và tường như ảnh tham khảo, thay vì phản chiếu khoảng đen.
    static func environmentImage() -> CGImage? {
        let w = 512, h = 256
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h { for x in 0..<w {
            let elev = 90 - Double(y) / Double(h) * 180          // +90 trần … −90 sàn
            let az = Double(x) / Double(w) * 360
            var c: (Double, Double, Double)
            if elev > 55 {
                c = (0.06, 0.05, 0.045)                             // trần tối
                // Hai bóng đèn dài phía trên bàn.
                if elev > 68, abs(az - 90) < 26 || abs(az - 270) < 26 { c = (1, 0.93, 0.78) }
            } else if elev > -8 {
                // Tường: ván gỗ ấm, sọc dọc.
                let stripe = Int(az / 6) % 2 == 0 ? 1.0 : 0.85
                c = (0.32 * stripe, 0.19 * stripe, 0.10 * stripe)
                if elev > 18, abs(az - 180) < 14 { c = (0.55, 0.5, 0.42) } // khung tranh sáng nhẹ
            } else {
                c = (0.13, 0.08, 0.045)                             // sàn gỗ
            }
            let i = (y * w + x) * 4
            px[i] = UInt8(c.0 * 255); px[i + 1] = UInt8(c.1 * 255); px[i + 2] = UInt8(c.2 * 255)
        } }
        let image: CGImage? = px.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        return image
    }

    /// Hình nón cụt dọc trục +z (z từ 0 tới `length`), bán kính r0 → r1. Dùng dựng cơ nhiều đoạn.
    static func frustum(r0: Float, r1: Float, length: Float, segments: Int = 24) -> MeshResource? {
        var pos: [SIMD3<Float>] = [], nor: [SIMD3<Float>] = [], idx: [UInt32] = []
        let slope = (r0 - r1) / length
        for s in 0...segments {
            let a = Float(s) / Float(segments) * 2 * .pi
            let c = cos(a), sn = sin(a)
            let n = simd_normalize(SIMD3(c, sn, slope))
            pos += [SIMD3(r0 * c, r0 * sn, 0), SIMD3(r1 * c, r1 * sn, length)]
            nor += [n, n]
            if s > 0 {
                let k = UInt32(2 * s)
                idx += [k - 2, k, k - 1, k - 1, k, k + 1]
            }
        }
        // Nắp hai đầu.
        for (z, r, dir) in [(Float(0), r0, Float(-1)), (length, r1, Float(1))] {
            let center = UInt32(pos.count)
            pos.append(SIMD3(0, 0, z)); nor.append(SIMD3(0, 0, dir))
            for s in 0...segments {
                let a = Float(s) / Float(segments) * 2 * .pi
                pos.append(SIMD3(r * cos(a), r * sin(a), z)); nor.append(SIMD3(0, 0, dir))
                if s > 0 { idx += dir > 0 ? [center, center + UInt32(s), center + UInt32(s) + 1]
                                          : [center, center + UInt32(s) + 1, center + UInt32(s)] }
            }
        }
        var d = MeshDescriptor(name: "frustum")
        d.positions = MeshBuffers.Positions(pos)
        d.normals = MeshBuffers.Normals(nor)
        d.primitives = .triangles(idx)
        return try? MeshResource.generate(from: [d])
    }

    static func pbr(_ color: UIColor, roughness: Float, metallic: Float = 0, clearcoat: Float = 0) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = .init(floatLiteral: metallic)
        m.clearcoat = .init(floatLiteral: clearcoat)
        m.faceCulling = .none
        return m
    }
}
