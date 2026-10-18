import Foundation

// Bài tập dạng JSON theo đặc tả "pool-trainer" (docs/04-drills.md): toạ độ theo ĐƠN VỊ KIM CƯƠNG
// (x 0…8 theo chiều dài, y 0…4 theo chiều rộng, y = 0 là băng dài dưới), khoá tiếng Việt không dấu.

struct JDrill: Codable, Equatable {
    var id: String
    var ten: String
    var ban: String? = "9ft"
    var bi: [JBall]
    var danh_dau: [JMarker]? = []
    var huong_dan: JGuide
    var dieu_kien_dat: [String]
    var so_lan: Int? = 10
    var lech_ngau_nhien: Double? = 0
}
struct JBall: Codable, Equatable { var so: Int; var x: Double; var y: Double }
struct JMarker: Codable, Equatable {
    var loai: String                  // vi_tri_bi | vung_dich | diem_bang
    var so: Int? = nil
    var x: Double? = nil
    var y: Double? = nil
    var ban_kinh: Double? = nil       // kim cương
    var canh: String? = nil           // dai_tren | dai_duoi | ngan_trai | ngan_phai
    var kim_cuong: Double? = nil
}
struct JGuide: Codable, Equatable {
    var luc: Int
    var diem_cham: JTip
    var cong_thuc: String? = nil
    var ghi_chu: String? = nil
}
struct JTip: Codable, Equatable { var doc: Double; var ngang: Double }

/// Đánh dấu dán trên nỉ (decal) – không phải tia ngắm.
enum StageMarker: Equatable {
    case ballSpot(P2)     // vòng vị trí bi
    case railPoint(P2)    // điểm trên đường nút
}

enum JSONDrillError: LocalizedError {
    case noCueBall, badCondition(String)
    var errorDescription: String? {
        switch self {
        case .noCueBall: return "Bài tập thiếu bi cái (so = 0)."
        case .badCondition(let c): return "Điều kiện chưa hỗ trợ: \(c)"
        }
    }
}

extension JDrill {
    static func decode(_ data: Data) throws -> JDrill { try JSONDecoder().decode(JDrill.self, from: data) }
    func encoded() throws -> Data {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try e.encode(self)
    }

    static func railSpot(canh: String, kc: Double) -> P2 {
        switch canh {
        case "dai_tren": return railPoint(kc, 4)
        case "ngan_trai": return railPoint(0, kc)
        case "ngan_phai": return railPoint(8, kc)
        default: return railPoint(kc, 0)
        }
    }

    /// Đổi sang bài tập của ứng dụng (dùng bộ máy chấm điểm chung).
    func toDrill() throws -> Drill {
        guard let cueJ = bi.first(where: { $0.so == 0 }) else { throw JSONDrillError.noCueBall }
        var goal = Goal()
        var pots: [Int] = []
        let zones = (danh_dau ?? []).filter { $0.loai == "vung_dich" }
        for c in dieu_kien_dat {
            let parts = c.split(separator: "_").map(String.init)
            if c == "bi_cai_trong_vung_dich" {
                if let z = zones.first, let x = z.x, let y = z.y {
                    goal.cueZone = Zone(c: fromDiamond(x, y), r: (z.ban_kinh ?? 0.3) * DIAMOND)
                }
            } else if parts.count == 4, parts[0] == "bi", parts[2] == "vao", parts[3] == "lo", let n = Int(parts[1]) {
                pots.append(n)
            } else if parts.count == 5, c.hasPrefix("bi_cai_cham_bang_"), let n = Int(parts[4]) {
                goal.minRails = n
            } else if c == "bi_bat_ky_vao_lo" {
                goal.potAny = true
            } else { throw JSONDrillError.badCondition(c) }
        }
        if !pots.isEmpty { goal.pot = pots }
        let cue = fromDiamond(cueJ.x, cueJ.y)
        let balls = bi.filter { $0.so != 0 }.map { BallSpec(id: $0.so, p: fromDiamond($0.x, $0.y)) }
        let hint: Hint
        if let t = pots.first { hint = .ghost(ball: t, pocket: nil) }
        else if let z = goal.cueZone { hint = .dir(atan2(z.c.z - cue.z, z.c.x - cue.x)) }
        else { hint = .dir(0) }
        var markers: [StageMarker] = []
        for m in danh_dau ?? [] {
            if m.loai == "vi_tri_bi", let x = m.x, let y = m.y { markers.append(.ballSpot(fromDiamond(x, y))) }
            if m.loai == "diem_bang", let c = m.canh, let k = m.kim_cuong { markers.append(.railPoint(JDrill.railSpot(canh: c, kc: k))) }
        }
        let demo = Demo(a: max(-0.6, min(0.6, huong_dan.diem_cham.ngang)), b: max(-0.6, min(0.6, huong_dan.diem_cham.doc)),
                        speed: SpeedScale.speed(level: huong_dan.luc))
        var st = Stage(cue: cue, balls: balls, goal: goal, hint: hint, demo: demo)
        st.markers = markers
        var formula: [FormulaBlock] = []
        if let f = huong_dan.cong_thuc, !f.isEmpty { formula.append(.formula(f)) }
        formula.append(.text("Lực **\(huong_dan.luc)/7** (≈ \(vn(SpeedScale.speed(level: huong_dan.luc))) m/s) · điểm chạm dọc \(vn(huong_dan.diem_cham.doc, 2))R, ngang \(vn(huong_dan.diem_cham.ngang, 2))R."))
        var d = Drill(id: "json-" + id, cat: .custom, level: 2, title: ten, summary: huong_dan.ghi_chu ?? "Bài tập tự soạn (JSON).",
                      formula: formula, steps: ["Đánh \(so_lan ?? 10) lần, xem tỉ lệ thành công."] + ((lech_ngau_nhien ?? 0) > 0 ? ["Mỗi lần bi lệch ngẫu nhiên tới ±\(vn(lech_ngau_nhien ?? 0, 2)) nút."] : []),
                      tips: huong_dan.ghi_chu.map { [$0] } ?? [], video: ten + " pool drill", stages: [st])
        d.repeats = max(1, so_lan ?? 10)
        d.jitter = lech_ngau_nhien ?? 0
        d.source = self
        return d
    }

    /// Xuất một bài tập có sẵn sang JSON (để chỉnh tay / chia sẻ).
    static func from(_ d: Drill) -> JDrill? {
        if let s = d.source { return s }
        guard let st = d.stages.first, let cue = st.cue else { return nil }
        func dm(_ p: P2) -> (Double, Double) { let t = toDiamond(p); return ((t.dx * 100).rounded() / 100, (t.dz * 100).rounded() / 100) }
        var bi = [JBall(so: 0, x: dm(cue).0, y: dm(cue).1)]
        bi += st.balls.map { JBall(so: $0.id, x: dm($0.p).0, y: dm($0.p).1) }
        var marks: [JMarker] = st.balls.map { JMarker(loai: "vi_tri_bi", so: $0.id, x: dm($0.p).0, y: dm($0.p).1) }
        var cond: [String] = []
        if let z = st.goal.cueZone {
            marks.append(JMarker(loai: "vung_dich", x: dm(z.c).0, y: dm(z.c).1, ban_kinh: (z.r / DIAMOND * 100).rounded() / 100))
            cond.append("bi_cai_trong_vung_dich")
        }
        for n in st.goal.pot ?? [] { cond.append("bi_\(n)_vao_lo") }
        if let mr = st.goal.minRails { cond.append("bi_cai_cham_bang_\(mr)") }
        if st.goal.potAny { cond.append("bi_bat_ky_vao_lo") }
        let demo = st.demo ?? Demo(a: 0, b: 0, speed: 2)
        let luc = (1...7).min { abs(SpeedScale.speed(level: $0) - demo.speed) < abs(SpeedScale.speed(level: $1) - demo.speed) } ?? 3
        var formula: String? = nil
        if case .formula(let f)? = d.formula.first { formula = f }
        return JDrill(id: d.id, ten: d.title, ban: "9ft", bi: bi, danh_dau: marks,
                      huong_dan: JGuide(luc: luc, diem_cham: JTip(doc: demo.b, ngang: demo.a), cong_thuc: formula, ghi_chu: d.summary),
                      dieu_kien_dat: cond, so_lan: 10, lech_ngau_nhien: 0)
    }
}


/// Thư viện bài JSON: bài mẫu đóng gói trong app + bài người dùng nhập (Documents/drills).
enum DrillLibrary {
    static var custom: [Drill] = []
    static var errors: [String] = []

    static var userDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("drills", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func reload(bundleDir: URL?) {
        var out: [Drill] = [], errs: [String] = []
        var urls: [URL] = []
        if let b = bundleDir, let fs = try? FileManager.default.contentsOfDirectory(at: b, includingPropertiesForKeys: nil) { urls += fs }
        if let fs = try? FileManager.default.contentsOfDirectory(at: userDir, includingPropertiesForKeys: nil) { urls += fs }
        for u in urls.filter({ $0.pathExtension.lowercased() == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let d = try JDrill.decode(Data(contentsOf: u)).toDrill()
                if !out.contains(where: { $0.id == d.id }) { out.append(d) }
            } catch { errs.append("\(u.lastPathComponent): \(error.localizedDescription)") }
        }
        custom = out; errors = errs
    }

    /// Nhập một file JSON (kiểm tra hợp lệ rồi chép vào thư mục người dùng).
    @discardableResult
    static func importFile(_ url: URL) throws -> Drill {
        let data = try Data(contentsOf: url)
        let j = try JDrill.decode(data)
        let d = try j.toDrill()
        try data.write(to: userDir.appendingPathComponent("\(j.id).json"), options: .atomic)
        return d
    }
}
