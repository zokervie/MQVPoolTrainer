import Foundation

/// Hồ sơ bàn: kích thước, hình học lỗ, băng, nỉ. Mọi kích thước tính bằng mét, góc bằng độ.
/// Thông số hình học (kích thước, miệng lỗ) lấy từ trang của hãng / WPA khi có công bố – xem `sources`.
/// Hệ số vật lý của nỉ và băng (ma sát, hồi phục) là ƯỚC LƯỢNG theo loại nỉ/cao su, chỉnh lại trong màn "Bàn tùy chỉnh".
struct TableSpec: Codable, Equatable, Identifiable {
    var id: String
    var brand: String
    var model: String
    var note: String = ""

    // mặt chơi (mũi băng → mũi băng)
    var length: Double
    var width: Double

    // lỗ
    var cornerMouth: Double            // miệng lỗ góc (giữa 2 mũi băng)
    var sideMouth: Double
    var cornerAngle: Double = 142      // góc cắt miệng lỗ (WPA 142° ±1)
    var sideAngle: Double = 104        // WPA 104° ±1
    var cornerShelf: Double = 0.0254   // độ sâu kệ lỗ góc (WPA 1–2¼″)
    var sideShelf: Double = 0.009525   // WPA 0–⅜″

    // băng
    var cushionHeight: Double = 0.0365 // chiều cao mũi băng (WPA 62,5–64,5% đường kính bi)
    var cushionName: String = "K66"
    var eCushion: Double = 0.86        // hồi phục băng ở tốc độ thấp
    var muCushion: Double = 0.2

    // nỉ
    var clothName: String = "Nỉ thi đấu"
    var muSlide: Double = 0.2
    var muRoll: Double = 0.011
    var spinDecel: Double = 10

    // hiển thị
    var clothColor: String = "blue"    // id trong Settings.clothColors
    var railHex: UInt32 = 0x4a2b17     // màu khung
    var railWood: Bool = true          // vân gỗ hay sơn/laminate trơn
    var sources: [String] = []

    var sizeName: String {
        let inch = length / 0.0254
        if inch > 96 { return "9 ft" } else if inch > 85 { return "8 ft" } else { return "7 ft" }
    }
    var cushionRatio: Double { cushionHeight / (2 * R) }
}

/// Hệ số nỉ/băng ước lượng (Dr. Dave Alciatore: μ trượt 0,15–0,4, cản lăn 0,005–0,015; nỉ len chải kỹ chạy nhanh hơn nỉ thường).
enum ClothModel {
    static let simonis860 = (name: "Simonis 860 Tournament", muSlide: 0.2, muRoll: 0.010, spin: 10.0)
    static let simonis760 = (name: "Simonis 760 (nhanh)", muSlide: 0.19, muRoll: 0.009, spin: 9.5)
    static let arcadia = (name: "Predator Arcadia Reserve", muSlide: 0.19, muRoll: 0.0095, spin: 9.5)
    static let woolen = (name: "Nỉ len thường (chậm)", muSlide: 0.25, muRoll: 0.014, spin: 11.0)
}

private func inch(_ v: Double) -> Double { v * 0.0254 }

private func make(_ id: String, _ brand: String, _ model: String, size: (Double, Double), corner: Double, side: Double,
                  cushion: (String, Double), cloth: (name: String, muSlide: Double, muRoll: Double, spin: Double),
                  shelf: (Double, Double) = (inch(1.5), inch(0.1875)), clothColor: String = "blue",
                  rail: UInt32 = 0x1a1a1c, wood: Bool = false, note: String = "", sources: [String]) -> TableSpec {
    var t = TableSpec(id: id, brand: brand, model: model, note: note, length: size.0, width: size.1, cornerMouth: corner, sideMouth: side)
    t.cornerShelf = shelf.0; t.sideShelf = shelf.1
    t.cushionHeight = 0.635 * 2 * R
    t.cushionName = cushion.0; t.eCushion = cushion.1
    t.clothName = cloth.name; t.muSlide = cloth.muSlide; t.muRoll = cloth.muRoll; t.spinDecel = cloth.spin
    t.clothColor = clothColor; t.railHex = rail; t.railWood = wood; t.sources = sources
    return t
}

extension TableSpec {
    private static let size9 = (inch(100), inch(50)), size8 = (inch(90), inch(45)), size7 = (inch(80), inch(40))
    private static let wpaSrc = "https://www.poolroom.com/tournament-table-equipment-specifications/"

    /// Bàn gốc của ứng dụng (khớp bản web, dùng cho kiểm thử đối chiếu).
    static let standard = TableSpec(id: "std", brand: "MQV", model: "Bàn chuẩn 9 ft (mặc định)",
                                    note: "Hình học gốc của bản web: miệng lỗ hơi rộng (≈4,65″ / 5,2″), dễ vào hơn bàn thi đấu.",
                                    length: 2.54, width: 1.27, cornerMouth: 0.118, sideMouth: 0.132,
                                    clothColor: "blue", sources: [])

    static let presets: [TableSpec] = [
        standard,
        make("wpa9", "WPA", "Tiêu chuẩn thi đấu 9 ft", size: size9, corner: inch(4.5), side: inch(5),
             cushion: ("Cao su K66 (ước lượng)", 0.86), cloth: ClothModel.simonis860, clothColor: "tournament", rail: 0x4a2b17, wood: true,
             note: "Mức nhỏ nhất của WPA: lỗ góc 4,5″, lỗ giữa 5″; góc cắt 142°/104°; mũi băng 63,5% đường kính bi.",
             sources: [wpaSrc]),
        make("predator-apex9", "Predator", "Apex 9ft Professional", size: size9, corner: 0.108, side: 0.125,
             cushion: ("K55 Pro Speed (hard-bonded)", 0.88), cloth: ClothModel.arcadia, clothColor: "tournament", rail: 0x141414,
             note: "Lỗ góc 4,25″ (108 mm), lỗ giữa 4,92″ (125 mm) theo trang của Predator – chặt hơn chuẩn WPA. Góc cắt/kệ lỗ chưa công bố: dùng WPA.",
             sources: ["https://predatorcues.com/pages/predator-apex-9ft-professional-table"]),
        make("diamond-proam9", "Diamond", "Pro-Am 9 ft", size: size9, corner: inch(4.5), side: inch(5),
             cushion: ("Cao su Diamond (ước lượng)", 0.87), cloth: ClothModel.simonis860, clothColor: "tournament", rail: 0x202024,
             note: "Mặt chơi 100×50″. Hãng không ghi số lỗ; 4,5″/5″ là cỡ phổ biến (người dùng đo).",
             sources: ["https://diamondbilliards.com/products/diamond-pro-am-pool-table",
                       "https://forums.azbilliards.com/threads/anybody-out-there-with-a-diamond-table-that-has-tighter-pockets-than-pro-cut.473033/"]),
        make("diamond-proam9-tight", "Diamond", "Pro-Am 9 ft – túi chặt 4¼″", size: size9, corner: inch(4.25), side: inch(4.75),
             cushion: ("Cao su Diamond (ước lượng)", 0.87), cloth: ClothModel.simonis760, clothColor: "tournament", rail: 0x202024,
             note: "Cấu hình túi chặt hay gặp ở giải/CLB: góc 4¼″, giữa 4¾″ (số đo người dùng, không phải số hãng).",
             sources: ["https://forums.azbilliards.com/threads/anybody-out-there-with-a-diamond-table-that-has-tighter-pockets-than-pro-cut.473033/"]),
        make("diamond-proam8", "Diamond", "Pro-Am 8 ft", size: size8, corner: inch(4.5), side: inch(5),
             cushion: ("Cao su Diamond (ước lượng)", 0.87), cloth: ClothModel.simonis860, clothColor: "tournament", rail: 0x202024,
             note: "Mặt chơi 90×45″.", sources: ["https://diamondbilliards.com/products/diamond-pro-am-pool-table"]),
        make("diamond-proam7", "Diamond", "Pro-Am 7 ft (bar box)", size: size7, corner: inch(4.5), side: inch(5),
             cushion: ("Cao su Diamond (ước lượng)", 0.87), cloth: ClothModel.simonis860, clothColor: "tournament", rail: 0x202024,
             note: "Mặt chơi 80×40″ – cỡ bàn giải bar box.", sources: ["https://diamondbilliards.com/products/diamond-pro-am-pool-table"]),
        make("rasson-victory3-9", "Rasson", "Victory III 9 ft", size: size9, corner: inch(4.5), side: inch(5),
             cushion: ("Klematch P59", 0.87), cloth: ClothModel.simonis860, clothColor: "tournament", rail: 0x1c1c1e,
             note: "Mặt chơi 100×50″, lỗ góc 4,5″, lỗ giữa 5″, băng Klematch P59, nỉ Simonis 860.",
             sources: ["https://gameroomgorilla.com/shop/rasson-victory-ii-plus-pool-table"]),
        make("rasson-victory3-8", "Rasson", "Victory III 8 ft", size: size8, corner: inch(4.5), side: inch(5),
             cushion: ("Klematch P59", 0.87), cloth: ClothModel.simonis860, clothColor: "tournament", rail: 0x1c1c1e,
             note: "Mặt chơi 90×45″.", sources: ["https://gameroomgorilla.com/shop/rasson-victory-ii-plus-pool-table"]),
        make("rasson-ox9", "Rasson", "OX 9 ft (lỗ 4″)", size: size9, corner: inch(4), side: inch(5),
             cushion: ("MAX K55", 0.88), cloth: ClothModel.simonis860, clothColor: "tournament", rail: 0x2a2a2d,
             note: "Rasson cho biết OX chuyển mặc định sang lỗ góc 4″ / giữa 5″ (trước đây 4,5″/5″ theo WPA). Băng MAX K55.",
             sources: ["https://forums.azbilliards.com/threads/rasson-ox-table.541822/", "https://billiardfactory.com/rasson-ox-ii-pool-table"]),
        make("mrsung-acurra9", "Mr Sung", "Acurra 9 ft (Rasson Mr-Sung series)", size: size9, corner: inch(4.5), side: inch(5),
             cushion: ("Cao su thi đấu (chưa công bố)", 0.87), cloth: ClothModel.simonis860, clothColor: "tournament", rail: 0x161618,
             note: "Dòng Mr-Sung của Rasson, dùng ở nhiều giải. Hãng chỉ đăng thông số dạng ảnh – lỗ/băng ở đây lấy theo WPA 4,5″/5″, hãy chỉnh theo bàn bạn tập.",
             sources: ["https://rasson.cn/acurra-mr-sung", "https://forums.azbilliards.com/threads/rasson-table-for-world-championships.564146/"]),
        make("mrsung-hero9", "Mr Sung", "Hero 9 ft (by Rasson)", size: size9, corner: inch(4.5), side: inch(5),
             cushion: ("Cao su thi đấu (chưa công bố)", 0.87), cloth: ClothModel.simonis860, clothColor: "tournament", rail: 0x161618,
             note: "Thông số lỗ chưa công bố dạng chữ – dùng WPA 4,5″/5″.",
             sources: ["https://www.thailandpooltables.com/en/rasson-hero-black-pool-table-9ft-drop-pockets.html"]),
        make("brunswick-gc6", "Brunswick", "Gold Crown VI Tournament 9 ft", size: size9, corner: inch(4.5625), side: inch(5.0625),
             cushion: ("SuperSpeed", 0.88), cloth: ClothModel.simonis860, clothColor: "green", rail: 0x18181a,
             note: "Lỗ góc 4,5–4,625″, lỗ giữa 5–5,125″ (lấy giữa khoảng), băng SuperSpeed, theo chuẩn WPA.",
             sources: ["https://pooltables.com/products/brunswick-gold-crown-vi-9-tournament-matte-black"]),
        make("club-slow9", "CLB", "Bàn CLB 9 ft – nỉ chậm, lỗ rộng", size: size9, corner: inch(4.75), side: inch(5.25),
             cushion: ("K66 cũ (nảy kém)", 0.80), cloth: ClothModel.woolen, clothColor: "green", rail: 0x5a3a20, wood: true,
             note: "Mô phỏng bàn quán: nỉ len thường chậm, băng cũ, lỗ rộng. Dùng để so sánh cảm giác lực.", sources: []),
    ]

    static func preset(_ id: String) -> TableSpec? { presets.first { $0.id == id } }
}
