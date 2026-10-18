import Foundation

/// Bài tập (docs/04-drills.md). Tọa độ theo đơn vị kim cương (dài 8, rộng 4).
/// Khóa JSON giữ tiếng Việt không dấu cho dễ soạn tay.
public struct Drill: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var ten: String
    public var ban: String                 // "9ft" | "8ft" | "7ft"
    public var bi: [DrillBall]
    public var danhDau: [Marker]
    public var huongDan: Guide
    public var dieuKienDat: [String]
    public var soLan: Int
    public var lechNgauNhien: Double

    enum CodingKeys: String, CodingKey {
        case id, ten, ban, bi
        case danhDau = "danh_dau"
        case huongDan = "huong_dan"
        case dieuKienDat = "dieu_kien_dat"
        case soLan = "so_lan"
        case lechNgauNhien = "lech_ngau_nhien"
    }
}

public struct DrillBall: Codable, Equatable, Sendable {
    public var so: Int   // 0 = bi cái
    public var x: Double
    public var y: Double
}

public struct Marker: Codable, Equatable, Sendable {
    public var loai: String          // "vi_tri_bi" | "vung_dich" | "diem_bang"
    public var so: Int?
    public var x: Double?
    public var y: Double?
    public var banKinh: Double?
    public var canh: String?         // "dai_tren" | "dai_duoi" | "ngan_trai" | "ngan_phai"
    public var kimCuong: Double?

    enum CodingKeys: String, CodingKey {
        case loai, so, x, y, canh
        case banKinh = "ban_kinh"
        case kimCuong = "kim_cuong"
    }
}

public struct Guide: Codable, Equatable, Sendable {
    public var luc: Int              // thang 1–7
    public var diemCham: TipPoint
    public var congThuc: String?
    public var ghiChu: String?

    enum CodingKeys: String, CodingKey {
        case luc
        case diemCham = "diem_cham"
        case congThuc = "cong_thuc"
        case ghiChu = "ghi_chu"
    }
}

public struct TipPoint: Codable, Equatable, Sendable {
    public var doc: Double    // −1…1, + là xoáy trên
    public var ngang: Double  // −1…1, + là bên phải
}

/// Thang lực 1–7 → tốc độ cơ (m/s). Hiệu chỉnh được.
public enum SpeedScale {
    public static let cueSpeeds: [Double] = [0.8, 1.3, 2.0, 3.0, 4.3, 6.0, 8.0]
    public static func cueSpeed(level: Int) -> Double {
        cueSpeeds[min(max(level, 1), 7) - 1]
    }
}

public enum DrillLoader {
    public static func load(_ data: Data) throws -> Drill {
        try JSONDecoder().decode(Drill.self, from: data)
    }
    public static func export(_ d: Drill) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(d)
    }
}
