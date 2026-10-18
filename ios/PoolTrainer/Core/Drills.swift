import Foundation

// Thư viện bài tập + hệ thống nút số (khớp src/drills.js). Mỗi bài có công thức/giải thích hiển thị TRƯỚC khi tập.

struct Zone: Equatable { var c: P2; var r: Double }

struct Goal {
    var pot: [Int]? = nil
    var cueZone: Zone? = nil
    var minRails: Int? = nil
    var firstHit: Int? = nil
    var clear: [Int]? = nil
    var ordered = false
    var maxMisses: Int? = nil
    var maxShots: Int? = nil
    var minRailsBall: Int? = nil
    var potAny = false
}

enum Hint {
    case dir(Double)
    case ghost(ball: Int, pocket: String?)
    case mirror(rail: Rail, ball: Int)
    case cornerReflect(corner: String, ball: Int)
    case bank(ball: Int, rail: Rail, pocket: String)
    case corner5(T: Double)

    var ball: Int? {
        switch self {
        case .ghost(let b, _), .mirror(_, let b), .cornerReflect(_, let b), .bank(let b, _, _): return b
        default: return nil
        }
    }
}

struct Demo { var a: Double; var b: Double; var speed: Double }

struct BallSpec { var id: Int; var p: P2 }

struct Stage {
    var cue: P2?
    var balls: [BallSpec]
    var goal: Goal
    var hint: Hint
    var demo: Demo?
    var ballInHand = false
    var rack: String? = nil
    var place: (cut: Double, dist: Double, side: Double)? = nil
}

enum FormulaBlock {
    case formula(String)       // dòng công thức nổi bật
    case text(String)          // đoạn giải thích (Markdown: **đậm**)
    case table([[String]])     // bảng nhỏ, hàng đầu là tiêu đề
}

enum Category: String, CaseIterable, Identifiable {
    case aim, cue, sys, game
    var id: String { rawValue }
    var title: String { ["aim": "Ngắm bi & góc cắt", "cue": "Điều bi cái", "sys": "Hệ thống nút số", "game": "Vào trận"][rawValue]! }
    var desc: String {
        ["aim": "Bi ma, độ chồng bi, góc cắt, bi sát băng", "cue": "Dừng, kéo, theo, quy tắc 90°/30°, lực, chạy vị trí",
         "sys": "Gương, chia đôi, bank, phản chiếu góc, Corner-5", "game": "Phá bi, dọn bàn theo mẫu"][rawValue]!
    }
    var icon: String { ["aim": "scope", "cue": "circle.circle", "sys": "diamond", "game": "trophy"][rawValue]! }
}

struct Drill: Identifiable {
    let id: String
    let cat: Category
    let level: Int
    let title: String
    let summary: String
    let formula: [FormulaBlock]
    let steps: [String]
    let tips: [String]
    let video: String
    var labels: LabelKind? = nil
    var stages: [Stage] = []
    var generate: ((UInt32) -> Stage)? = nil

    var stageCount: Int { generate != nil ? 1 : stages.count }
}

let POCKET_IDS = (TR: "c1-1", TL: "c-1-1", BR: "c11", BL: "c-11", ST: "s-1", SB: "s1")

// MARK: - tiện ích dựng tình huống
private func d(_ dx: Double, _ dz: Double) -> P2 { fromDiamond(dx, dz) }
private func B(_ id: Int, _ dx: Double, _ dz: Double) -> BallSpec { BallSpec(id: id, p: fromDiamond(dx, dz)) }
private func rad(_ deg: Double) -> Double { deg * .pi / 180 }

private func cutStage(ob: P2, pocket: String, angle: Double, dist: Double, side: Double = 1,
                      spin: (Double, Double) = (0, 0.2), speed: Double = 2.2,
                      zone: ((P2, P2, P2) -> Zone)? = nil) -> Stage {
    let p = pocketById(pocket)!
    let tgt = pocketAimPoint(p)
    let cue = placeForCut(ob, tgt, angle, dist, side)
    var g = Goal(pot: [1])
    if let z = zone { g.cueZone = z(cue, ob, tgt) }
    return Stage(cue: cue, balls: [BallSpec(id: 1, p: ob)], goal: g, hint: .ghost(ball: 1, pocket: pocket),
                 demo: Demo(a: spin.0, b: spin.1, speed: speed))
}

/// Vùng dừng theo đường tiếp tuyến (quy tắc 90°) hoặc lệch 30° (bi lăn).
private func deflectZone(_ tangent: Bool, _ dist: Double, _ r: Double = 0.13) -> (P2, P2, P2) -> Zone {
    return { cue, ob, tgt in
        let g = ghostBall(ob, tgt)
        let ix = g.x - cue.x, iz = g.z - cue.z, im = (ix * ix + iz * iz).squareRoot()
        let ux = ix / im, uz = iz / im
        let nx = (ob.x - g.x) / (2 * R), nz = (ob.z - g.z) / (2 * R)
        let dn = ux * nx + uz * nz
        var tx = ux - dn * nx, tz = uz - dn * nz
        let tm = (tx * tx + tz * tz).squareRoot(); tx /= tm; tz /= tm
        var ox: Double, oz: Double
        if tangent { ox = tx; oz = tz } else {
            let cr = ux * tz - uz * tx
            let s: Double = cr > 0 ? 1 : (cr < 0 ? -1 : 0)
            let a = rad(30) * s
            ox = ux * cos(a) - uz * sin(a); oz = ux * sin(a) + uz * cos(a)
        }
        return Zone(c: P2(g.x + ox * dist, g.z + oz * dist), r: r)
    }
}

private func lineAt(_ a: P2, _ b: P2, _ t: Double) -> P2 { P2(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t) }

/// Bộ sinh số ngẫu nhiên giống hệt bản web (LCG 32 bit).
struct LCG {
    var s: UInt32
    init(_ seed: UInt32) { s = seed }
    mutating func next() -> Double { s = s &* 1664525 &+ 1013904223; return Double(s) / 4294967296 }
}

// MARK: - Công thức
private enum F {
    static let ghost: [FormulaBlock] = [.formula("G = O − 2R · û"),
        .text("O: tâm bi mục tiêu · û: hướng từ bi mục tiêu tới lỗ · R: bán kính bi (28,6 mm). Nhắm tâm bi cái vào bi ma G.")]
    static let fraction: [FormulaBlock] = [.formula("sin θ = 1 − f"),
        .table([["Độ chồng f", "Đầy", "¾", "½", "¼", "⅛"], ["Góc cắt θ", "0°", "14,5°", "30°", "48,6°", "61°"]])]
    static let slide: [FormulaBlock] = [.formula("d(trượt) = 12·v₀² / (49·μ·g)"),
        .text("Đánh tâm, bi cái trượt hết quãng d(trượt) rồi mới lăn (μ ≈ 0,2 ⇒ v₀ = 2 m/s trượt ~0,5 m). Đánh dưới tâm để kéo dài giai đoạn trượt; bi cái chỉ **dừng** khi lúc chạm còn trượt thuần (không xoáy tới/lui).")]
    static let rule90: [FormulaBlock] = [.formula("Bi cái trượt (stun) ⇒ góc tách = 90°"),
        .text("Bi cái đi theo **đường tiếp tuyến**, vuông góc với hướng bi mục tiêu. Xoáy theo đẩy bi cái ra phía trước tiếp tuyến, xoáy kéo đưa về phía sau.")]
    static let rule30: [FormulaBlock] = [.formula("Bi lăn đều + va ½ bi ⇒ bi cái lệch ≈ 30°"),
        .text("Đúng cho dải độ chồng ¼ → ¾ (27°–34°). Mẹo tay chữ V: ngón trỏ chỉ hướng bi ma, ngón giữa mở ~30° là hướng bi cái.")]
    static let speed: [FormulaBlock] = [.formula("v = √(2 · μ(lăn) · g · d)"),
        .text("μ(lăn) ≈ 0,011 ⇒ muốn bi lăn d = 4 m cần v ≈ 0,93 m/s (≈ 3,3 km/h). Mỗi lần chạm băng mất ~20–30% tốc độ. Quãng đường tỉ lệ với **bình phương** tốc độ: gấp đôi lực ⇒ đi xa gấp bốn.")]
    static let mirror: [FormulaBlock] = [.formula("x(c) = (x₁·d₂ + x₂·d₁) / (d₁ + d₂)"),
        .text("Phản chiếu bi mục tiêu qua băng (đường tâm bi cách mũi băng 1R) rồi nhắm thẳng ảnh đó. x₁, x₂: vị trí theo nút của bi cái và bi mục tiêu; d₁, d₂: khoảng cách của chúng tới băng.")]
    static let equal: [FormulaBlock] = [.formula("d₁ = d₂ ⇒ x(c) = (x₁ + x₂) / 2"),
        .text("Hai bi cách băng bằng nhau thì điểm chạm băng nằm chính giữa (theo số nút). Bi lăn mạnh, có xoáy theo sẽ nảy \"dài\" hơn một chút.")]
    static let bank: [FormulaBlock] = [.formula("P' = ảnh gương của lỗ qua băng · G = O − 2R·û(P' − O)"),
        .text("Bi mục tiêu đi tới ảnh P' của lỗ. Thực tế cú bank bi cắt / đánh mạnh thường bị \"ngắn\" (góc nảy hẹp) – nhắm dài hơn một chút hoặc đánh chậm hơn.")]
    static let corner: [FormulaBlock] = [.formula("T' = 2C − T"),
        .text("Đánh 2 băng kề nhau (qua một góc bàn): đường ra **song song** đường vào. C là góc của hình chữ nhật tâm bi (cách mũi băng 1R). Nhắm vào ảnh đối xứng tâm T' của bi mục tiêu qua C.")]
    static let corner5: [FormulaBlock] = [.formula("T = D − F"),
        .text("**D** (số xuất phát, vàng): góc dưới-trái = 5; +1 mỗi nút đi lên băng ngắn trái; −½ mỗi nút đi sang phải trên băng dưới. **F** (băng 1, xanh) và **T** (băng 3, hồng): số 1 ở nút đầu tiên tính từ băng ngắn bên phải. Đường chuẩn **5 − 3 = 2**. Chỉ đúng cho bi cái lăn, lực vừa, có **english xuôi** (running english). Xoay cơ quanh bi cái tới khi D − F bằng số T cần.")]
}

// MARK: - Danh sách bài
let DRILLS: [Drill] = [
    // ===== NGẮM =====
    Drill(id: "a-straight", cat: .aim, level: 1, title: "Bi thẳng – đánh dừng",
          summary: "Ăn bi thẳng vào lỗ góc và giữ bi cái dừng tại chỗ.", formula: F.ghost + F.slide,
          steps: ["Xếp bi cái, bi mục tiêu và lỗ thẳng hàng.", "Đặt điểm đánh hơi dưới tâm (≈ −0,2R).", "Lực vừa, ra cơ thẳng, giữ yên người sau cú đánh."],
          tips: ["Nếu bi cái lăn theo: hạ điểm đánh hoặc tăng lực.", "Nếu bi cái lùi: nâng điểm đánh hoặc giảm lực."],
          video: "stop shot drill pool lesson",
          stages: [Stage(cue: d(4, 2), balls: [B(1, 6, 3)], goal: Goal(pot: [1], cueZone: Zone(c: d(5.92, 2.96), r: 0.09)),
                         hint: .ghost(ball: 1, pocket: POCKET_IDS.TR), demo: Demo(a: 0, b: -0.25, speed: 1.2))]),
    Drill(id: "a-long", cat: .aim, level: 2, title: "Bi dài dọc bàn",
          summary: "Cú thẳng dài gần hết chiều dài bàn – kiểm tra độ thẳng của cú ra cơ.",
          formula: F.ghost + [.text("Sai số góc ε (rad) ở bi cái lệch điểm chạm một đoạn ≈ D·ε. Với D = 2 m, lệch 0,5° ⇒ ~1,7 cm – đủ trượt lỗ.")],
          steps: ["Nhìn bi mục tiêu ở cuối cú ra cơ.", "Đánh tâm hoặc hơi trên tâm, lực vừa."],
          tips: ["Dùng nút Khoá cơ khi đã ngắm xong để tay còn lại chỉ tập trung vào lực."],
          video: "long straight in shot drill pool",
          stages: [Stage(cue: d(1, 0.5), balls: [B(1, 7, 3.5)], goal: Goal(pot: [1]),
                         hint: .ghost(ball: 1, pocket: POCKET_IDS.TR), demo: Demo(a: 0, b: 0.2, speed: 2.6))]),
    Drill(id: "a-half", cat: .aim, level: 1, title: "Cắt ½ bi (30°)",
          summary: "Góc cắt chuẩn 30°: mép bi cái nhắm vào tâm bi mục tiêu.", formula: F.fraction + F.ghost,
          steps: ["Ngắm mép bi cái vào tâm bi mục tiêu (độ chồng ½).", "Lực vừa, đánh hơi trên tâm."],
          tips: ["Bi cái chậm và trượt sẽ \"kéo\" (throw) bi mục tiêu về phía đường đi bi cái ~1–2°: cắt dày hơn chút."],
          video: "half ball hit aiming pool fractional aiming",
          stages: [cutStage(ob: d(6, 3), pocket: POCKET_IDS.TR, angle: 30, dist: 0.6, side: 1)]),
    Drill(id: "a-ladder", cat: .aim, level: 2, title: "Thang độ chồng ¾ – ½ – ¼ – ⅛",
          summary: "4 cú cắt liên tiếp với 4 độ chồng chuẩn.", formula: F.fraction + F.ghost,
          steps: ["Mỗi chặng ước lượng độ chồng trước, rồi mới bật hỗ trợ ngắm để kiểm tra.", "Hoàn thành cả 4 chặng."],
          tips: ["Cắt mỏng (⅛) cần lực mạnh hơn vì bi mục tiêu nhận ít năng lượng: v(OB) = v·cosθ."],
          video: "fractional ball aiming system pool",
          stages: [14.5, 30, 48.6, 61].enumerated().map { i, a in
              cutStage(ob: d(5.6, 3.1), pocket: POCKET_IDS.TR, angle: a, dist: 0.55, side: i % 2 == 1 ? -1 : 1, speed: 2 + Double(i) * 0.3)
          }),
    Drill(id: "a-random", cat: .aim, level: 2, title: "Bi ma ngẫu nhiên",
          summary: "Mỗi lần một thế bi mới. Ước lượng góc cắt bằng mắt.", formula: F.ghost + F.fraction,
          steps: ["Tắt hỗ trợ ngắm để tự ước lượng, bật lại để kiểm tra.", "Ăn 10 bi, xem tỉ lệ thành công."],
          tips: ["Đứng sau đường bi mục tiêu → lỗ để \"thấy\" bi ma, rồi mới vào tư thế."],
          video: "ghost ball aiming method pool",
          generate: { seed in
              var r = LCG(seed)
              let ids = [POCKET_IDS.TR, POCKET_IDS.TL, POCKET_IDS.BR, POCKET_IDS.BL, POCKET_IDS.ST, POCKET_IDS.SB]
              for _ in 0..<200 {
                  let ob = d(1.5 + r.next() * 5, 0.8 + r.next() * 2.4)
                  let pocket = ids[Int(floor(r.next() * Double(ids.count)))]
                  let angle = r.next() * 55, dist = 0.35 + r.next() * 0.8, side: Double = r.next() < 0.5 ? -1 : 1
                  let st = cutStage(ob: ob, pocket: pocket, angle: angle, dist: dist, side: side, speed: 2.2)
                  let c = st.cue!
                  let p = pocketById(pocket)!
                  let dirIn = atan2(p.mouth.z - ob.z, p.mouth.x - ob.x)
                  let toP = p.mouth.dist(ob)
                  if !p.corner && abs(sin(dirIn)) < 0.6 { continue }
                  if toP < 0.25 { continue }
                  if abs(c.x) < TL / 2 - 0.08 && abs(c.z) < TW / 2 - 0.08 { return st }
              }
              return cutStage(ob: d(6, 3), pocket: POCKET_IDS.TR, angle: 20, dist: 0.6)
          }),
    Drill(id: "a-rail", cat: .aim, level: 2, title: "Bi sát băng",
          summary: "Bi mục tiêu dính băng trên, ăn vào lỗ góc dọc theo băng.",
          formula: F.ghost + [.text("Bi dính băng: điểm tiếp xúc nằm trên đường song song băng. Có thể nhắm cho bi cái chạm băng và bi mục tiêu **cùng lúc**. Thêm một chút english phía băng (english xuôi) để giảm throw.")],
          steps: ["Ngắm bi ma nằm sát băng.", "Lực vừa – mạnh quá bi dễ nảy ra ở hàm lỗ."],
          tips: ["Bi chạm hàm lỗ khi tới quá lệch: lỗ góc \"hiệu dụng\" hẹp lại theo góc tới."],
          video: "frozen rail cut shot technique pool",
          stages: [Stage(cue: d(4, 2.2), balls: [BallSpec(id: 1, p: P2(d(6.5, 4).x, -TW / 2 + R + 0.001))], goal: Goal(pot: [1]),
                         hint: .ghost(ball: 1, pocket: POCKET_IDS.TR), demo: Demo(a: 0, b: 0.1, speed: 1.8))]),
    Drill(id: "a-side", cat: .aim, level: 2, title: "Cắt vào lỗ giữa",
          summary: "Lỗ giữa nhận bi tốt khi góc tới gần vuông góc, khó dần khi bi đi chéo.",
          formula: F.ghost + [.text("Góc tới lỗ giữa (so với pháp tuyến băng) nên ≤ ~40°. Lớn hơn, cửa lỗ hiệu dụng ≈ miệng·cos(α) thu hẹp nhanh.")],
          steps: ["Ngắm bi ma theo đường bi mục tiêu → giữa miệng lỗ.", "Lực nhẹ – vừa."],
          tips: ["Đánh nhẹ thì lỗ \"rộng\" hơn: bi chậm ít bị hàm lỗ đẩy ra."],
          video: "side pocket cut shot pool",
          stages: [cutStage(ob: d(3.4, 3.2), pocket: POCKET_IDS.ST, angle: 25, dist: 0.55, side: -1, speed: 1.6)]),

    // ===== ĐIỀU BI CÁI =====
    Drill(id: "c-stop", cat: .cue, level: 1, title: "Thang bi dừng (1 → 4 nút)",
          summary: "Bi dừng ở 4 khoảng cách tăng dần – hạ điểm đánh khi xa hơn.", formula: F.slide,
          steps: ["Mỗi chặng xa thêm 1 nút.", "Bi cái phải dừng trong vòng tròn vàng."],
          tips: ["Khoảng cách càng xa, xoáy kéo càng bị vải \"ăn\" bớt: cần điểm đánh thấp hơn và lực mạnh hơn."],
          video: "stop shot ladder drill pool",
          stages: [1, 2, 3, 4].map { k in
              Stage(cue: d(6 - Double(k), 3 - Double(k) / 2), balls: [B(1, 6, 3)],
                    goal: Goal(pot: [1], cueZone: Zone(c: d(5.9, 2.95), r: 0.12)),
                    hint: .ghost(ball: 1, pocket: POCKET_IDS.TR),
                    demo: Demo(a: 0, b: [-0.12, -0.25, -0.36, -0.45][k - 1], speed: [1.7, 2.1, 2.5, 2.9][k - 1]))
          }),
    Drill(id: "c-draw", cat: .cue, level: 2, title: "Kéo bi về vùng",
          summary: "Ăn bi thẳng và kéo bi cái lùi về vòng tròn.",
          formula: [.formula("ω·R / v > 1 lúc chạm ⇒ bi cái lùi"),
                    .text("Điểm đánh b (theo R) tạo xoáy ω = 5·v·b / (2R). Đánh −0,5R ⇒ ωR/v = 1,25 ban đầu; vải làm xoáy giảm dần trên đường đi, nên bi càng xa càng phải kéo thấp/mạnh.")],
          steps: ["Điểm đánh −0,4R đến −0,6R.", "Ra cơ dài, đều, không \"giật\"."],
          tips: ["Kéo quá 0,6R dễ trượt cơ (miscue)."],
          video: "draw shot technique pool lesson",
          stages: [Stage(cue: d(4.5, 2.25), balls: [B(1, 6, 3)], goal: Goal(pot: [1], cueZone: Zone(c: d(3.4, 1.7), r: 0.15)),
                         hint: .ghost(ball: 1, pocket: POCKET_IDS.TR), demo: Demo(a: 0, b: -0.5, speed: 2.3))]),
    Drill(id: "c-follow", cat: .cue, level: 1, title: "Theo bi vừa đủ",
          summary: "Ăn bi thẳng, bi cái theo tới vòng tròn nhưng không rơi lỗ.",
          formula: [.formula("b = 0,4R ⇒ lăn đều ngay (ω·R = v)"),
                    .text("Bi lăn đều khi chạm thẳng sẽ truyền gần hết vận tốc rồi bị xoáy tới kéo đi theo ≈ 2/7 vận tốc ban đầu.")],
          steps: ["Điểm đánh +0,3R đến +0,4R.", "Lực nhẹ – vừa, đủ cho bi cái theo ~½ nút."],
          tips: ["Theo bi luôn xảy ra khi bi cái lăn: chỉ cần chỉnh lực để kiểm soát quãng đường."],
          video: "follow shot drill pool",
          stages: [Stage(cue: d(3.6, 1.8), balls: [B(1, 6, 3)], goal: Goal(pot: [1], cueZone: Zone(c: d(6.55, 3.27), r: 0.11)),
                         hint: .ghost(ball: 1, pocket: POCKET_IDS.TR), demo: Demo(a: 0, b: 0.2, speed: 1.0))]),
    Drill(id: "c-90", cat: .cue, level: 2, title: "Quy tắc 90° (bi trượt)",
          summary: "Cắt ½ bi với bi cái trượt, bi cái đi theo đường tiếp tuyến vào vòng tròn.", formula: F.rule90 + F.fraction,
          steps: ["Đánh tâm/hơi dưới tâm để bi cái còn trượt khi chạm.", "Lực vừa."],
          tips: ["Muốn bi cái chạy đúng tiếp tuyến ở cú xa: hạ điểm đánh nhiều hơn."],
          video: "90 degree rule pool stun shot",
          stages: [cutStage(ob: d(6, 3), pocket: POCKET_IDS.TR, angle: 30, dist: 0.5, side: 1, spin: (0, -0.5), speed: 1.6, zone: deflectZone(true, 0.42))]),
    Drill(id: "c-30", cat: .cue, level: 2, title: "Quy tắc 30° (bi lăn)",
          summary: "Cắt ½ bi với bi cái lăn đều, bi cái lệch ~30° vào vòng tròn.", formula: F.rule30,
          steps: ["Đánh tâm hoặc hơi trên tâm, lực nhẹ để bi cái lăn đều trước khi chạm.", "Chạm ½ bi."],
          tips: ["Cú cắt mỏng/dày hơn ½ bi thì góc lệch vẫn gần 30° nhưng quãng đi thay đổi."],
          video: "30 degree rule pool peace sign",
          stages: [cutStage(ob: d(6, 3), pocket: POCKET_IDS.TR, angle: 30, dist: 0.7, side: -1, spin: (0, 0.05), speed: 1.0, zone: deflectZone(false, 0.3, 0.15))]),
    Drill(id: "c-lag", cat: .cue, level: 1, title: "Kiểm soát lực – Lag",
          summary: "Đánh bi cái lên băng cuối bàn và về dừng gần băng đầu bàn.", formula: F.speed,
          steps: ["Đánh tâm/hơi trên tâm, hướng thẳng.", "Bi cái phải chạm băng xa rồi dừng trong vòng tròn."],
          tips: ["Quãng đường ≈ 2 chiều dài bàn ~4,5 m ⇒ v ≈ 1,0 m/s, cộng phần mất ở băng ⇒ ~1,4 m/s."],
          video: "lag shot speed control drill pool",
          stages: [Stage(cue: d(1, 2), balls: [], goal: Goal(cueZone: Zone(c: d(0.6, 2), r: 0.16), minRails: 1),
                         hint: .dir(0), demo: Demo(a: 0, b: 0.3, speed: 1.4))]),
    Drill(id: "c-two", cat: .cue, level: 2, title: "Chạy vị trí 2 bi",
          summary: "Ăn bi 1 rồi bi 2 trong 2 cú, phải để vị trí sau cú đầu.", formula: F.rule30 + F.rule90,
          steps: ["Trước khi đánh bi 1, chọn vùng đặt bi cái cho bi 2.", "Dùng quy tắc 90°/30° để dự đoán đường bi cái."],
          tips: ["Chọn góc cắt \"đúng phía\" cho bi sau – đừng để bi thẳng tuyệt đối."],
          video: "pool position play drill two balls",
          stages: [Stage(cue: d(4.2, 1.8), balls: [B(1, 6, 3), B(2, 2.4, 3.2)], goal: Goal(clear: [1, 2], maxShots: 2),
                         hint: .ghost(ball: 1, pocket: POCKET_IDS.TR), demo: Demo(a: 0, b: -0.3, speed: 2.4))]),
    Drill(id: "c-line", cat: .cue, level: 3, title: "Line-up 6 bi",
          summary: "6 bi trên đường giữa bàn. Bi trong tay ở cú đầu, dọn sạch không trượt.", formula: F.rule90 + F.rule30,
          steps: ["Dọn theo thứ tự tuỳ ý.", "Không được trượt bi nào."],
          tips: ["Ưu tiên giữ góc cắt nhỏ, di chuyển bi cái ngắn."],
          video: "line up drill pool practice",
          stages: [Stage(cue: d(1.3, 1.4), balls: [2.4, 3.1, 3.8, 4.5, 5.2, 5.9].enumerated().map { B($0.offset + 1, $0.element, 2) },
                         goal: Goal(clear: [1, 2, 3, 4, 5, 6], maxMisses: 0), hint: .ghost(ball: 1, pocket: POCKET_IDS.TL), demo: nil, ballInHand: true)]),
    Drill(id: "c-x", cat: .cue, level: 3, title: "Mighty X",
          summary: "8 bi trên hai đường chéo. Dọn sạch, tối đa 2 cú trượt.", formula: F.rule90 + F.rule30,
          steps: ["Bi trong tay ở cú đầu.", "Dọn sạch, trượt quá 2 lần là hỏng."],
          tips: ["Bi gần lỗ trước để mở đường cho bi ở giữa."],
          video: "mighty x drill pool",
          stages: [Stage(cue: d(4, 2.8),
                         balls: [(2.4, 1.2), (3.2, 1.6), (4.8, 2.4), (5.6, 2.8), (2.4, 2.8), (3.2, 2.4), (4.8, 1.6), (5.6, 1.2)].enumerated().map { B($0.offset + 1, $0.element.0, $0.element.1) },
                         goal: Goal(clear: [1, 2, 3, 4, 5, 6, 7, 8], maxMisses: 2), hint: .ghost(ball: 1, pocket: POCKET_IDS.BL), demo: nil, ballInHand: true)]),

    // ===== HỆ THỐNG NÚT SỐ =====
    Drill(id: "s-mirror", cat: .sys, level: 2, title: "Hệ thống Gương – kick 1 băng",
          summary: "Bi chắn đường thẳng. Kick bi cái 1 băng (băng trên) chạm bi mục tiêu.", formula: F.mirror,
          steps: ["Ước lượng ảnh gương của bi 1 bên ngoài băng trên.", "Đánh lực vừa, không english, bi cái hơi trượt (stun) để góc nảy đúng gương."],
          tips: ["Bi lăn mạnh có xoáy theo nảy \"dài\"; english xuôi cũng làm dài góc. Bật gợi ý để thấy ảnh gương."],
          video: "mirror system kick shot pool", labels: .std,
          stages: [
            Stage(cue: d(2.5, 3.0), balls: [B(1, 5.5, 3.3), B(2, 4.0, 3.18)], goal: Goal(minRails: 1, firstHit: 1),
                  hint: .mirror(rail: .top, ball: 1), demo: Demo(a: 0, b: 0, speed: 1.8)),
            Stage(cue: d(1.6, 2.4), balls: [B(1, 6.2, 3.2), B(2, 4.0, 2.85), B(3, 4.4, 3.0)], goal: Goal(minRails: 1, firstHit: 1),
                  hint: .mirror(rail: .top, ball: 1), demo: Demo(a: 0, b: 0, speed: 2.0)),
          ]),
    Drill(id: "s-equal", cat: .sys, level: 1, title: "Chia đôi khoảng cách",
          summary: "Hai bi cách băng bằng nhau: nhắm đúng nút chính giữa.", formula: F.equal + F.mirror,
          steps: ["Đọc số nút của bi cái (x₁) và bi mục tiêu (x₂).", "Nhắm điểm (x₁ + x₂)/2 trên băng dưới."],
          tips: ["Chặng 2 hai bi cách băng khác nhau: dùng công thức tổng quát."],
          video: "one rail kick system diamonds pool", labels: .std,
          stages: [
            Stage(cue: d(2, 1), balls: [B(1, 6, 1), B(2, 4, 1)], goal: Goal(minRails: 1, firstHit: 1),
                  hint: .mirror(rail: .bottom, ball: 1), demo: Demo(a: 0, b: 0, speed: 2.0)),
            Stage(cue: d(1.5, 0.8), balls: [B(1, 6.5, 1.6), B(2, 4, 1.2)], goal: Goal(minRails: 1, firstHit: 1),
                  hint: .mirror(rail: .bottom, ball: 1), demo: Demo(a: 0, b: 0, speed: 2.2)),
          ]),
    Drill(id: "s-bank", cat: .sys, level: 3, title: "Bank 1 băng vào lỗ giữa",
          summary: "Đánh bi mục tiêu chạm băng trên rồi về lỗ giữa dưới (cross-side).", formula: F.bank,
          steps: ["Lấy ảnh gương của lỗ giữa dưới qua băng trên.", "Cắt bi mục tiêu về phía ảnh đó."],
          tips: ["Đánh vừa lực. Mạnh quá bi bank bị \"ngắn\" (góc nảy hẹp lại)."],
          video: "cross side bank shot system pool", labels: .std,
          stages: [Stage(cue: nil, balls: [B(1, 3.55, 2.6)], goal: Goal(pot: [1], minRailsBall: 1),
                         hint: .bank(ball: 1, rail: .top, pocket: POCKET_IDS.SB), demo: Demo(a: 0, b: 0.3, speed: 1.5),
                         place: (cut: 12, dist: 0.5, side: -1))]),
    Drill(id: "s-corner", cat: .sys, level: 2, title: "Phản chiếu qua góc – 2 băng",
          summary: "Kick 2 băng (băng phải → băng trên) chạm bi mục tiêu bị che.", formula: F.corner,
          steps: ["Lấy ảnh đối xứng tâm của bi mục tiêu qua góc trên-phải.", "Nhắm thẳng ảnh đó, lực vừa, không english."],
          tips: ["Lực mạnh làm bi nảy \"ngắn\" hơn ở băng đầu; english xuôi làm dài góc."],
          video: "two rail kick system pool corner", labels: .std,
          stages: [Stage(cue: d(6.3, 1.2), balls: [B(1, 5.6, 3.2), B(2, 5.95, 2.2)], goal: Goal(minRails: 2, firstHit: 1),
                         hint: .cornerReflect(corner: "tr", ball: 1), demo: Demo(a: 0, b: 0, speed: 2.2))]),
    Drill(id: "s-c5ref", cat: .sys, level: 2, title: "Corner-5: đường chuẩn 5-3-2",
          summary: "Ghi nhớ đường chuẩn 5 − 3 = 2 của hệ thống 3 băng Corner-5.", formula: F.corner5,
          steps: ["Bi cái nằm trên đường từ góc (D = 5) tới nút F = 3 của băng trên.", "Bi lăn, lực vừa, english xuôi (phải) ~0,3R.", "Bi cái chạm 3 băng rồi trúng bi 1 ở nút T = 2."],
          tips: ["Trên đa số bàn, đường 5-3-2 về hơi ngắn so với lý thuyết: hiệu chỉnh theo bàn bạn tập."],
          video: "corner 5 diamond system three rail kick", labels: .corner5,
          stages: [Stage(cue: lineAt(railPoint(0, 0), railPoint(5, 4), 0.2), balls: [B(1, 6.05, 0.22)], goal: Goal(minRails: 3, firstHit: 1),
                         hint: .corner5(T: 2), demo: Demo(a: 0.3, b: 0.3, speed: 2.5))]),
    Drill(id: "s-c5", cat: .sys, level: 3, title: "Corner-5: tính số nhắm",
          summary: "Kick 3 băng trúng bi bị che hoàn toàn. Tự tính F = D − T.", formula: F.corner5,
          steps: ["Đọc số T nơi cần tới ở băng 3 (băng dưới).", "Xoay cơ quanh bi cái tới khi D − F = T.", "Bi lăn, english xuôi, lực vừa."],
          tips: ["Bi xa băng: dịch đường 5-3-2 song song qua bi để ước lượng T cần."],
          video: "corner 5 system kick explained", labels: .corner5,
          stages: [
            Stage(cue: d(0.9, 0.9), balls: [B(1, 5.1, 0.25), B(2, 3.0, 0.6), B(3, 3.4, 0.35)], goal: Goal(minRails: 3, firstHit: 1),
                  hint: .corner5(T: 3), demo: Demo(a: 0.3, b: 0.3, speed: 2.5)),
            Stage(cue: d(1.4, 1.6), balls: [B(1, 6.6, 0.25), B(2, 4.0, 0.9)], goal: Goal(minRails: 3, firstHit: 1),
                  hint: .corner5(T: 1.5), demo: Demo(a: 0.3, b: 0.3, speed: 2.5)),
          ]),

    // ===== VÀO TRẬN =====
    Drill(id: "g-break9", cat: .game, level: 2, title: "Phá bi 9 bi",
          summary: "Phá bi 9 bi: phải có bi vào lỗ và bi cái không rơi.",
          formula: [.formula("E = ½·m·v²"), .text("Phá bi cần tốc độ cao (7–9 m/s) nhưng bi cái phải chạm **đầy** bi số 1. Đánh hơi dưới tâm để bi cái dừng giữa bàn sau va chạm.")],
          steps: ["Đặt bi cái gần băng đầu, hơi lệch tâm.", "Kéo lùi tay đẩy thật dài rồi đẩy nhanh (lực mạnh nhất)."],
          tips: ["Chính xác quan trọng hơn sức mạnh: chạm lệch làm mất năng lượng."],
          video: "9 ball break technique",
          stages: [Stage(cue: d(1.5, 2.6), balls: [], goal: Goal(potAny: true), hint: .ghost(ball: 1, pocket: nil), demo: nil, ballInHand: true, rack: "9")]),
    Drill(id: "g-run9", cat: .game, level: 3, title: "Dọn bàn 9 bi theo mẫu",
          summary: "Thế bi cố định, dọn theo thứ tự 1 → 9, không trượt.", formula: F.rule90 + F.rule30,
          steps: ["Luôn chạm bi số nhỏ nhất trước.", "Lên kế hoạch 3 bi trước."],
          tips: ["Chọn góc cắt để bi cái đi theo hướng bi kế tiếp."],
          video: "9 ball run out pattern play",
          stages: [Stage(cue: d(2, 1),
                         balls: [(3, 3.1), (5.5, 1.1), (6.8, 3.3), (4.6, 2.8), (1.6, 3.4), (2.6, 0.8), (5.2, 3.5), (7.1, 1.0), (4.0, 1.4)].enumerated().map { B($0.offset + 1, $0.element.0, $0.element.1) },
                         goal: Goal(clear: [1, 2, 3, 4, 5, 6, 7, 8, 9], ordered: true, maxMisses: 0),
                         hint: .ghost(ball: 1, pocket: nil), demo: nil, ballInHand: true)]),
]

func drillById(_ id: String) -> Drill? { DRILLS.first { $0.id == id } }

/// Dựng chặng: đủ toạ độ (xếp bi, đặt bi cái cho bài bank, sinh ngẫu nhiên).
func buildStage(_ drill: Drill, _ idx: Int, seed: UInt32 = UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970 * 1000))) -> Stage {
    var st = drill.generate?(seed) ?? drill.stages[idx]
    if let rk = st.rack { st.balls = rackBalls(rk) }
    if st.cue == nil, let pl = st.place, case .bank(let bid, let rail, let pocket) = st.hint,
       let ob = st.balls.first(where: { $0.id == bid }) {
        let img = mirrorPoint(pocketAimPoint(pocketById(pocket)!), rail)
        st.cue = placeForCut(ob.p, img, pl.cut, pl.dist, pl.side)
    }
    return st
}

// MARK: - Xếp bi
func rackBalls(_ kind: String) -> [BallSpec] {
    let f = fromDiamond(6, 2)
    let dx = R * 3.0.squareRoot() * 1.002, dz = 2 * R * 1.002
    var pos: [P2] = []
    if kind == "9" {
        let rows = [1, 2, 3, 2, 1]
        for (r, n) in rows.enumerated() { for c in 0..<n { pos.append(P2(f.x + Double(r) * dx, f.z + (Double(c) - Double(n - 1) / 2) * dz)) } }
        let order = [1, 2, 3, 4, 9, 5, 6, 7, 8]
        return pos.enumerated().map { BallSpec(id: order[$0.offset], p: $0.element) }
    }
    for r in 0..<5 { for c in 0...r { pos.append(P2(f.x + Double(r) * dx, f.z + (Double(c) - Double(r) / 2) * dz)) } }
    let ids = [1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15]
    return pos.enumerated().map { BallSpec(id: ids[$0.offset], p: $0.element) }
}

// MARK: - Lời giải ngắm (đường gợi ý, sơ đồ, kiểm tra tự động)
enum LineKind { case cue, ob, sys }
enum MarkKind { case ghost, image, contact }
struct HintSolution {
    var dir: Double
    var lines: [(P2, P2, LineKind)] = []
    var marks: [(p: P2, kind: MarkKind, label: String?)] = []
    var info: String? = nil
}

private func fmt1(_ n: Double) -> String { String(format: "%.1f", n).replacingOccurrences(of: ".", with: ",") }

func solveHint(_ hint: Hint, cue: P2?, ballPos: (Int) -> P2?) -> HintSolution? {
    guard let cue else { return nil }
    switch hint {
    case .dir(let d): return HintSolution(dir: d)
    case .ghost(let id, let pid):
        guard let ob = ballPos(id) else { return nil }
        guard let pocket = pid.flatMap(pocketById) ?? bestPocket(cue, ob) else { return nil }
        let tgt = pocketAimPoint(pocket), g = ghostBall(ob, tgt)
        return HintSolution(dir: atan2(g.z - cue.z, g.x - cue.x), lines: [(cue, g, .cue), (ob, tgt, .ob)], marks: [(g, .ghost, nil)])
    case .mirror(let rail, let id):
        guard let ob = ballPos(id) else { return nil }
        let img = mirrorPoint(ob, rail), c = mirrorContact(cue, ob, rail)
        return HintSolution(dir: atan2(img.z - cue.z, img.x - cue.x), lines: [(cue, c, .cue), (c, ob, .cue), (c, img, .sys)],
                            marks: [(img, .image, nil), (c, .contact, nil)])
    case .cornerReflect(let corner, let id):
        guard let ob = ballPos(id) else { return nil }
        let (img, C) = cornerReflect(ob, corner)
        let pts = polyReflect(cue, img, C)
        return HintSolution(dir: atan2(img.z - cue.z, img.x - cue.x),
                            lines: [(cue, pts.0, .cue), (pts.0, pts.1, .cue), (pts.1, ob, .cue), (C, img, .sys), (pts.0, img, .sys)],
                            marks: [(img, .image, nil), (C, .contact, nil)])
    case .bank(let id, let rail, let pid):
        guard let ob = ballPos(id), let p = pocketById(pid) else { return nil }
        let tgt = pocketAimPoint(p), img = mirrorPoint(tgt, rail), g = ghostBall(ob, img), c = mirrorContact(ob, tgt, rail)
        return HintSolution(dir: atan2(g.z - cue.z, g.x - cue.x), lines: [(cue, g, .cue), (ob, c, .ob), (c, tgt, .ob), (c, img, .sys)],
                            marks: [(g, .ghost, nil), (img, .image, nil)])
    case .corner5(let T):
        guard let s = corner5Solve(cue, T) else { return nil }
        return HintSolution(dir: atan2(s.aim.z - cue.z, s.aim.x - cue.x), lines: [(s.origin, s.aim, .sys)],
                            marks: [(s.aim, .contact, "F \(fmt1(s.F))"), (s.origin, .contact, "D \(fmt1(s.D))"), (s.arrival, .contact, "T \(fmt1(s.T))")],
                            info: "D \(fmt1(s.D)) − F \(fmt1(s.F)) = T \(fmt1(s.T))")
    }
}

private func polyReflect(_ a: P2, _ img: P2, _ C: P2) -> (P2, P2) {
    let dx = img.x - a.x, dz = img.z - a.z
    let tx = (C.x - a.x) / dx, tz = (C.z - a.z) / dz
    let first = tx < tz ? P2(C.x, a.z + dz * tx) : P2(a.x + dx * tz, C.z)
    let second = tx < tz ? P2(2 * C.x - (a.x + dx * tz), C.z) : P2(C.x, 2 * C.z - (a.z + dz * tx))
    return (first, second)
}

/// Chọn lỗ dễ nhất cho bi mục tiêu (góc cắt nhỏ, đường ngắn).
func bestPocket(_ cue: P2, _ ob: P2) -> Pocket? {
    var best: Pocket? = nil, bs = Double.infinity
    for p in POCKETS {
        let t = pocketAimPoint(p), g = ghostBall(ob, t)
        let a1 = atan2(g.z - cue.z, g.x - cue.x), a2 = atan2(t.z - ob.z, t.x - ob.x)
        var cut = abs(a1 - a2); if cut > .pi { cut = 2 * .pi - cut }
        if cut > rad(80) { continue }
        if !p.corner {
            let ang = abs(atan2(t.x - ob.x, abs(t.z - ob.z)))
            if ang > rad(55) { continue }
        }
        let score = cut * 2 + t.dist(ob) * 0.6
        if score < bs { bs = score; best = p }
    }
    return best
}

// MARK: - Đánh giá cú đánh
struct StageState { var shots = 0; var misses = 0; var potted = Set<Int>() }
struct ShotResult { var done: Bool; var ok: Bool; var msg: String }

func evaluate(_ stage: Stage, _ events: [SimEvent], _ balls: [Ball], _ state: inout StageState) -> ShotResult {
    let g = stage.goal
    let cue = balls.first { $0.id == 0 }
    let pottedNow = events.pottedIds
    let scratch = pottedNow.contains(0)
    let fh = events.firstCueHit
    let firstHit = fh?.other
    let railsBefore = events.cushions(of: 0).filter { fh == nil || $0.t < fh!.t }.count
    state.shots += 1
    for id in pottedNow where id != 0 { state.potted.insert(id) }

    if scratch { return ShotResult(done: true, ok: false, msg: "Bi cái rơi lỗ (scratch)!") }

    if let clear = g.clear {
        let left = clear.filter { !state.potted.contains($0) }
        if g.ordered {
            let lowest = clear.filter { !state.potted.contains($0) || pottedNow.contains($0) }.min()
            if firstHit != lowest { return ShotResult(done: true, ok: false, msg: "Lỗi: phải chạm bi \(lowest ?? 0) trước.") }
        }
        let potThis = pottedNow.contains { $0 != 0 }
        if !potThis {
            state.misses += 1
            if let mm = g.maxMisses, state.misses > mm { return ShotResult(done: true, ok: false, msg: "Trượt quá số lần cho phép.") }
        }
        if left.isEmpty { return ShotResult(done: true, ok: true, msg: "Dọn sạch trong \(state.shots) cú!") }
        if let ms = g.maxShots, state.shots >= ms { return ShotResult(done: true, ok: false, msg: "Hết lượt.") }
        return ShotResult(done: false, ok: potThis, msg: potThis ? "Vào! Còn \(left.count) bi." : "Trượt. Còn \(left.count) bi.")
    }

    if let want = g.firstHit {
        if firstHit != want { return ShotResult(done: true, ok: false, msg: firstHit == nil ? "Không chạm bi nào." : "Chạm nhầm bi \(firstHit!).") }
        if let mr = g.minRails, railsBefore < mr { return ShotResult(done: true, ok: false, msg: "Cần chạm \(mr) băng trước (mới \(railsBefore)).") }
    }
    if let pot = g.pot {
        if pot.contains(where: { !pottedNow.contains($0) }) { return ShotResult(done: true, ok: false, msg: "Bi không vào lỗ.") }
        if let mrb = g.minRailsBall {
            let hitT = fh?.t ?? 0
            let rails = events.cushions(of: pot[0]).filter { $0.t > hitT && $0.rail != .jaw }.count
            if rails < mrb { return ShotResult(done: true, ok: false, msg: "Bi phải chạm băng trước khi vào lỗ.") }
        }
    }
    if g.potAny && !pottedNow.contains(where: { $0 != 0 }) { return ShotResult(done: true, ok: false, msg: "Không có bi nào vào lỗ.") }
    if let mr = g.minRails, g.firstHit == nil {
        if events.cushions(of: 0).count < mr { return ShotResult(done: true, ok: false, msg: "Bi cái phải chạm băng.") }
    }
    if let z = g.cueZone, let cue {
        let dz = cue.pos.dist(z.c)
        if dz > z.r { return ShotResult(done: true, ok: false, msg: "Bi cái cách vùng \(Int((dz * 100).rounded())) cm.") }
    }
    return ShotResult(done: true, ok: true, msg: "Thành công!")
}

// MARK: - Cú mẫu (mô phỏng, tinh chỉnh nhỏ quanh hướng gợi ý)
struct DemoResult { var dir: Double; var traces: [Int: [P2]]; var ok: Bool; var hint: HintSolution }

func demoShot(_ st: Stage) -> DemoResult? {
    guard let demo = st.demo, let cue = st.cue else { return nil }
    let pos: (Int) -> P2? = { id in st.balls.first { $0.id == id }?.p }
    guard let h = solveHint(st.hint, cue: cue, ballPos: pos) else { return nil }
    var focus: Set<Int> = [0]
    if let b = st.hint.ball { focus.insert(b) }
    func run(_ dir: Double, trace: Bool) -> (Simulation, ShotResult) {
        let sim = Simulation([Ball(0, cue)] + st.balls.map { Ball($0.id, $0.p) })
        sim.trackRotation = false
        if trace {
            sim.traceIds = focus
            for id in focus { sim.tracePts[id] = [pos(id) ?? cue] }
        }
        sim.strike(0, dir: dir, speed: demo.speed, a: demo.a, b: demo.b, elev: 0, squirt: 0.02)
        sim.runUntilRest(20, dt: 1.0 / 1500)
        if trace { for id in focus { if let b = sim.ball(id) { sim.tracePts[id, default: []].append(b.pocketed ? (b.dropFrom ?? b.pos) : b.pos) } } }
        var s = StageState()
        return (sim, evaluate(st, sim.events, sim.balls, &s))
    }
    var best = h.dir
    if !run(h.dir, trace: false).1.ok {
        outer: for k in 1...20 { for s in [1.0, -1.0] {
            let dd = h.dir + s * Double(k) * 0.1 * .pi / 180
            if run(dd, trace: false).1.ok { best = dd; break outer }
        } }
    }
    let (sim, res) = run(best, trace: true)
    return DemoResult(dir: best, traces: sim.tracePts, ok: res.ok, hint: h)
}
