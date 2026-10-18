import Foundation
import SwiftUI
import UIKit

/// Cài đặt người dùng (lưu bằng UserDefaults, giống localStorage của bản web).
struct Settings: Codable, Equatable {
    var cloth = "blue"          // blue | green | teal | red | grey
    var guide = 1               // 0 tắt · 1 cơ bản · 2 đầy đủ (dự đoán vật lý)
    var view3D = true
    var leftHand = false        // tay đẩy lực
    var swipePower = true       // vuốt đẩy theo tốc độ tay | thanh lực + nút Đánh
    var sens = 1.0              // 0.6 · 1 · 1.4
    var squirt = true
    var autoUnlock = true
    var labels = true
    var sound = true
    var haptics = true
    var telemetry = false       // bảng thông số bi cái (tốc độ, xoáy, trượt/lăn)

    static let clothColors: [(id: String, name: String, hex: UInt32)] = [
        ("blue", "Xanh giải đấu", 0x1f5d9e), ("green", "Xanh lá", 0x1d6e45), ("teal", "Xanh ngọc", 0x156b70),
        ("red", "Đỏ rượu", 0x8e2430), ("grey", "Xám", 0x5d6670),
    ]
    var clothHex: UInt32 { Settings.clothColors.first { $0.id == cloth }?.hex ?? 0x1f5d9e }

    init() {}
    // giải mã khoan dung: thiếu khoá (bản cũ) thì lấy mặc định
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        cloth = (try? c.decode(String.self, forKey: .cloth)) ?? d.cloth
        guide = (try? c.decode(Int.self, forKey: .guide)) ?? d.guide
        view3D = (try? c.decode(Bool.self, forKey: .view3D)) ?? d.view3D
        leftHand = (try? c.decode(Bool.self, forKey: .leftHand)) ?? d.leftHand
        swipePower = (try? c.decode(Bool.self, forKey: .swipePower)) ?? d.swipePower
        sens = (try? c.decode(Double.self, forKey: .sens)) ?? d.sens
        squirt = (try? c.decode(Bool.self, forKey: .squirt)) ?? d.squirt
        autoUnlock = (try? c.decode(Bool.self, forKey: .autoUnlock)) ?? d.autoUnlock
        labels = (try? c.decode(Bool.self, forKey: .labels)) ?? d.labels
        sound = (try? c.decode(Bool.self, forKey: .sound)) ?? d.sound
        haptics = (try? c.decode(Bool.self, forKey: .haptics)) ?? d.haptics
        telemetry = (try? c.decode(Bool.self, forKey: .telemetry)) ?? d.telemetry
    }
}

struct DrillStat: Codable { var att = 0, ok = 0, streak = 0, best = 0 }

enum Store {
    private static let d = UserDefaults.standard
    static func load<T: Decodable>(_ key: String, _ def: T) -> T {
        guard let data = d.data(forKey: key), let v = try? JSONDecoder().decode(T.self, from: data) else { return def }
        return v
    }
    static func save<T: Encodable>(_ key: String, _ v: T) {
        if let data = try? JSONEncoder().encode(v) { d.set(data, forKey: key) }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }
}

/// Màu bi chuẩn (giống bản web).
enum BallColors {
    static let solid: [Int: UInt32] = [1: 0xf2b705, 2: 0x1747a6, 3: 0xd42a20, 4: 0x53308a, 5: 0xf26a1b, 6: 0x13804a, 7: 0x8a1f22, 8: 0x141414]
    static let ivory: UInt32 = 0xf7f3ea
    static func hex(_ id: Int) -> UInt32 { id == 0 ? ivory : solid[id > 8 ? id - 8 : id]! }
}

/// Định dạng số kiểu Việt Nam (dấu phẩy thập phân).
func vn(_ v: Double, _ digits: Int = 1) -> String {
    String(format: "%.\(digits)f", v).replacingOccurrences(of: ".", with: ",")
}
