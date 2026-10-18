import SwiftUI
import UniformTypeIdentifiers

// MARK: - Bảng số liệu sau cú đánh (docs/05-feedback.md của bộ đặc tả)
struct FeedbackPanel: View {
    @ObservedObject var g: Game
    let fb: ShotFeedback

    private func row(_ k: String, _ v: String, _ tone: Color = .white) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(k).opacity(0.7)
            Spacer(minLength: 10)
            Text(v).foregroundColor(tone).fontWeight(.semibold)
        }
    }
    private func lr(_ d: Double, unit: String = "°", digits: Int = 2) -> String {
        abs(d) < 0.005 ? "0\(unit)" : "\(vn(abs(d), digits))\(unit) \(d > 0 ? "phải" : "trái")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Sau cú đánh").font(.system(size: 14, weight: .heavy))
                Spacer()
                Button { g.feedback = nil; g.markPreviewDirty() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
                    .buttonStyle(.plain).opacity(g.feedbackPending ? 0 : 1)
            }
            Group {
                row("Tốc độ bi cái", "\(vn(fb.params.speed, 2)) m/s · mức \(vn(fb.level))/7")
                if fb.params.speed <= 3 { row("Nếu lăn thuần", "≈ \(vn(fb.rollLengths)) chiều dài bàn") }
                if fb.params.a != 0 || fb.params.b != 0 {
                    row("Điểm đánh", "\(fb.params.b >= 0 ? "theo" : "kéo") \(vn(abs(fb.params.b), 2))R · \(fb.params.a >= 0 ? "phải" : "trái") \(vn(abs(fb.params.a), 2))R")
                }
                if let s = fb.stroke {
                    let straight = abs(s.lateralRatio)
                    row("Độ thẳng cú vuốt", straight < 0.04 ? "thẳng" : "lệch \(vn(straight * 100, 0))% \(s.lateralRatio > 0 ? "phải" : "trái")",
                        straight < 0.04 ? Color(hex: 0x52b788) : (straight < 0.12 ? Color(hex: 0xffd166) : Color(hex: 0xef476f)))
                    row("Theo cơ", s.followThrough > 0.85 ? "đều tay" : "ngắt cơ (còn \(vn(s.followThrough * 100, 0))% tốc độ)",
                        s.followThrough > 0.85 ? Color(hex: 0x52b788) : Color(hex: 0xffd166))
                }
            }.font(.system(size: 12).monospacedDigit())
            Group {
                if let e = fb.aimErrorDeg { row("Lệch hướng ngắm", lr(e), abs(e) < 0.3 ? Color(hex: 0x52b788) : Color(hex: 0xffd166)) }
                if let c = fb.cutDeg { row("Góc cắt thực tế", "\(vn(c))°") }
                if let t = fb.throwDeg { row("Throw bi mục tiêu", lr(t)) }
                if let m = fb.obMissMM { row("Bi mục tiêu tới lỗ", abs(m) < 3 ? "giữa lỗ" : lr(m, unit: " mm", digits: 0), abs(m) < 15 ? Color(hex: 0x52b788) : Color(hex: 0xef476f)) }
                if let fr = fb.firstRail {
                    row("Chạm băng đầu", "nút \(vn(fr.diamond))" + (fb.predictedRailDiamond.map { " (dự tính \(vn($0)))" } ?? ""))
                }
                if let z = fb.zoneMissCM { row("Bi cái tới vùng đích", z < 0.5 ? "trong vùng" : "cách \(vn(z, 0)) cm", z < 0.5 ? Color(hex: 0x52b788) : Color(hex: 0xffd166)) }
                row("Bi cái đi", "\(vn(fb.cueTravel)) m · \(fb.cueRails) băng")
            }.font(.system(size: 12).monospacedDigit())
            HStack(spacing: 8) {
                Button { g.replay() } label: { Label("Phát lại", systemImage: "gobackward").font(.system(size: 13, weight: .bold)) }
                    .buttonStyle(GhostButton()).disabled(!g.canReplay)
                if g.feedbackPending {
                    Button("Tiếp") { g.continueAfterFeedback() }.buttonStyle(PrimaryButton())
                }
            }.padding(.top, 4)
            if g.settings.ghostTrail { Text("Đường mờ: cú trước · đường sáng: cú này").font(.system(size: 10)).opacity(0.55) }
        }
        .foregroundColor(.white)
        .frame(width: 270)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0x0d1418, alpha: 0.88)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1)))
    }
}

// MARK: - Chọn bàn theo hãng
struct TablesView: View {
    @ObservedObject var g: Game
    private var brands: [String] { var seen: [String] = []; for t in TableSpec.presets where !seen.contains(t.brand) { seen.append(t.brand) }; return seen }

    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text("Kích thước và miệng lỗ lấy theo thông số hãng/WPA đã công bố (xem nguồn ở từng bàn). Hệ số nỉ và băng là ước lượng theo loại nỉ/cao su – chỉnh trong “Bàn tùy chỉnh” cho khớp bàn bạn hay tập.")) {
                    Button { g.card = .tableEditor } label: {
                        Label("Bàn tùy chỉnh (đo bàn của bạn)…", systemImage: "slider.horizontal.3")
                    }
                    if let c = g.settings.customTable { tableRow(c) }
                }
                ForEach(brands, id: \.self) { b in
                    Section(b) { ForEach(TableSpec.presets.filter { $0.brand == b }) { tableRow($0) } }
                }
            }
            .navigationTitle("Bàn tập")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { g.card = nil } } }
        }.preferredColorScheme(.dark)
    }

    private func tableRow(_ t: TableSpec) -> some View {
        let on = g.settings.table.id == t.id && (t.id != "custom" || g.settings.tableId == "custom")
        return Button { g.selectTable(t) } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: t.railHex)).frame(width: 40, height: 24)
                    .overlay(RoundedRectangle(cornerRadius: 2).fill(Color(hex: Settings.clothColors.first { $0.id == t.clothColor }?.hex ?? 0x1f5d9e)).padding(4))
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.model).font(.system(size: 15, weight: .bold))
                    Text("\(t.sizeName) · lỗ góc \(inchStr(t.cornerMouth))″ (\(mmStr(t.cornerMouth)) mm) · lỗ giữa \(inchStr(t.sideMouth))″ (\(mmStr(t.sideMouth)) mm)")
                        .font(.system(size: 12)).opacity(0.85)
                    Text("Băng \(t.cushionName) · nỉ \(t.clothName) · góc cắt \(Int(t.cornerAngle))°/\(Int(t.sideAngle))°")
                        .font(.system(size: 11)).opacity(0.65)
                    if !t.note.isEmpty { Text(t.note).font(.system(size: 11)).opacity(0.55) }
                    ForEach(t.sources, id: \.self) { src in if let u = URL(string: src) { Link(u.host ?? src, destination: u).font(.system(size: 11)) } }
                }
                Spacer()
                if on { Image(systemName: "checkmark.circle.fill").foregroundColor(accent) }
            }.padding(.vertical, 3)
        }.foregroundColor(.white)
    }
}

func inchStr(_ m: Double) -> String { vn(m / 0.0254, 2).replacingOccurrences(of: ",00", with: "") }
func mmStr(_ m: Double) -> String { String(Int((m * 1000).rounded())) }

// MARK: - Bàn tùy chỉnh
struct TableEditorView: View {
    @ObservedObject var g: Game
    @State private var t: TableSpec

    init(g: Game) {
        self.g = g
        var base = g.settings.customTable ?? g.settings.table
        base.id = "custom"; base.brand = "Tùy chỉnh"
        if base.model.isEmpty || g.settings.customTable == nil { base.model = "Bàn của tôi (từ \(g.settings.table.model))" }
        base.sources = []
        _t = State(initialValue: base)
    }

    private func slider(_ title: String, _ v: Binding<Double>, _ range: ClosedRange<Double>, step: Double, fmt: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(title); Spacer(); Text(fmt(v.wrappedValue)).monospacedDigit().foregroundColor(accent) }.font(.system(size: 14))
            Slider(value: v, in: range, step: step)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tên") { TextField("Tên bàn", text: $t.model) }
                Section("Kích thước mặt chơi") {
                    Picker("Cỡ bàn", selection: Binding(get: { t.sizeName }, set: { v in
                        let s: (Double, Double) = v == "9 ft" ? (2.54, 1.27) : (v == "8 ft" ? (2.286, 1.143) : (2.032, 1.016))
                        t.length = s.0; t.width = s.1 })) {
                        Text("9 ft (100×50″)").tag("9 ft"); Text("8 ft (90×45″)").tag("8 ft"); Text("7 ft (80×40″)").tag("7 ft")
                    }
                }
                Section(footer: Text("WPA: lỗ góc 4,5–4,625″, lỗ giữa 5–5,125″, góc cắt 142°/104° (±1°), kệ lỗ góc 1–2¼″, lỗ giữa 0–⅜″.")) {
                    slider("Miệng lỗ góc", $t.cornerMouth, inchR(3.75)...inchR(5), step: inchR(0.0625)) { "\(inchStr($0))″ · \(mmStr($0)) mm" }
                    slider("Miệng lỗ giữa", $t.sideMouth, inchR(4.25)...inchR(5.5), step: inchR(0.0625)) { "\(inchStr($0))″ · \(mmStr($0)) mm" }
                    slider("Góc cắt lỗ góc", $t.cornerAngle, 136...148, step: 0.5) { "\(vn($0))°" }
                    slider("Góc cắt lỗ giữa", $t.sideAngle, 98...110, step: 0.5) { "\(vn($0))°" }
                    slider("Kệ lỗ góc (độ sâu)", $t.cornerShelf, 0...inchR(2.5), step: inchR(0.125)) { "\(inchStr($0))″" }
                    slider("Kệ lỗ giữa", $t.sideShelf, 0...inchR(0.75), step: inchR(0.0625)) { "\(inchStr($0))″" }
                }
                Section(footer: Text("Hồi phục băng cao = băng nảy hơn. Mũi băng WPA: 62,5–64,5% đường kính bi.")) {
                    TextField("Loại cao su băng", text: $t.cushionName)
                    slider("Hồi phục băng", $t.eCushion, 0.7...0.95, step: 0.01) { vn($0, 2) }
                    slider("Ma sát bi–băng", $t.muCushion, 0.1...0.3, step: 0.01) { vn($0, 2) }
                    slider("Chiều cao mũi băng", Binding(get: { t.cushionRatio * 100 }, set: { t.cushionHeight = $0 / 100 * 2 * R }), 60...67, step: 0.25) { "\(vn($0))% đường kính bi" }
                }
                Section(footer: Text("Cản lăn nhỏ = nỉ nhanh. Ví dụ: bi đẩy 1 m/s lăn được \(vn(1 / (2 * t.muRoll * G), 2)) m.")) {
                    TextField("Loại nỉ", text: $t.clothName)
                    slider("Cản lăn (μ lăn)", $t.muRoll, 0.006...0.016, step: 0.0005) { vn($0, 4) }
                    slider("Ma sát trượt (μ trượt)", $t.muSlide, 0.15...0.3, step: 0.005) { vn($0, 3) }
                    slider("Giảm xoáy ngang", $t.spinDecel, 6...14, step: 0.5) { "\(vn($0)) rad/s²" }
                    Picker("Màu nỉ", selection: $t.clothColor) { ForEach(Settings.clothColors, id: \.id) { Text($0.name).tag($0.id) } }
                    Toggle("Khung gỗ (tắt = sơn đen mờ)", isOn: $t.railWood)
                }
            }
            .navigationTitle("Bàn tùy chỉnh")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { g.card = .tables } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dùng bàn này") { t.railHex = t.railWood ? 0x4a2b17 : 0x18181a; g.selectTable(t); g.card = nil }
                }
            }
        }.preferredColorScheme(.dark)
    }
}

private func inchR(_ v: Double) -> Double { v * 0.0254 }

// MARK: - Nhập / chia sẻ bài JSON
/// Ghi JSON ra file tạm để chia sẻ (AirDrop, Tin nhắn, Tệp).
func jsonShareURL(_ d: Drill) -> URL? {
    guard let j = JDrill.from(d), let data = try? j.encoded() else { return nil }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(j.id).json")
    try? data.write(to: url, options: .atomic)
    return url
}
