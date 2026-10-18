import SwiftUI

struct MenuView: View {
    @ObservedObject var g: Game
    @State private var cat: Category = .aim

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    MiniBall(id: 9, size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MQV Pool Trainer").font(.system(size: 28, weight: .heavy))
                        Text("Bàn 9 ft, vật lý trượt – lăn – xoáy thật. Mỗi bài có công thức và sơ đồ trước khi tập.")
                            .font(.subheadline).foregroundColor(.white.opacity(0.75))
                    }
                }
                HStack(spacing: 12) {
                    bigButton("Tập tự do 8 bi", "Xếp 15 bi, phá và dọn bàn") { g.startFree("8") }
                    bigButton("Tập tự do 9 bi", "Luật chạm bi nhỏ nhất trước") { g.startFree("9") }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Category.allCases) { c in
                            Button { cat = c } label: {
                                Label(c.title, systemImage: c.icon).font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Capsule().fill(cat == c ? accent : Color.white.opacity(0.08)))
                                    .foregroundColor(cat == c ? .black : .white)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Text(cat.desc).font(.footnote).foregroundColor(.white.opacity(0.6))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                    ForEach(DRILLS.filter { $0.cat == cat }) { d in drillTile(d) }
                }
                HStack(spacing: 20) {
                    Button("Cài đặt") { g.card = .settings }
                    Button("Cách điều khiển") { g.card = .help }
                    Button("Nguồn tham khảo") { g.card = .sources }
                }.font(.system(size: 15, weight: .semibold)).foregroundColor(accent).padding(.top, 4)
            }
            .padding(.horizontal, 28).padding(.vertical, 20)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .foregroundColor(.white)
        .background(LinearGradient(colors: [Color(hex: 0x0b1116, alpha: 0.92), Color(hex: 0x0b1116, alpha: 0.75)], startPoint: .top, endPoint: .bottom))
    }

    private func bigButton(_ t: String, _ s: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t).font(.system(size: 18, weight: .heavy))
                Text(s).font(.system(size: 13)).opacity(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [Color(hex: 0x1d6e45), Color(hex: 0x14532d)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        }.buttonStyle(.plain)
    }

    private func drillTile(_ d: Drill) -> some View {
        let st = buildStage(d, 0, seed: 7)
        let s = g.stats[d.id]
        return Button { g.card = .drill(d, inGame: false) } label: {
            HStack(alignment: .top, spacing: 12) {
                DiagramView(stage: st, labels: d.labels ?? .std).frame(width: 130)
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.title).font(.system(size: 15, weight: .bold)).multilineTextAlignment(.leading)
                    Text(d.summary).font(.system(size: 12)).opacity(0.75).multilineTextAlignment(.leading).lineLimit(3)
                    HStack {
                        Text(String(repeating: "◆", count: d.level) + String(repeating: "◇", count: 3 - d.level)).foregroundColor(Color(hex: 0xffd166))
                        Spacer()
                        Text(s.map { "\($0.ok)/\($0.att) thành công" } ?? "\(d.stageCount) chặng").opacity(0.7)
                    }.font(.system(size: 12))
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
        }.buttonStyle(.plain)
    }
}

// MARK: - Phiếu bài tập
struct DrillCardView: View {
    @ObservedObject var g: Game
    let drill: Drill
    let inGame: Bool
    @State private var demo: DemoResult? = nil
    @State private var loading = true

    private var stage: Stage { inGame ? (g.stage ?? buildStage(drill, g.stageIdx, seed: 7)) : buildStage(drill, 0, seed: 7) }
    private var idx: Int { inGame ? g.stageIdx : 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(drill.title).font(.system(size: 24, weight: .heavy))
                Text(drill.summary).font(.subheadline).opacity(0.8)
                ZStack {
                    DiagramView(stage: stage, labels: drill.labels ?? .std, demo: demo)
                    if loading { ProgressView().tint(.white) }
                }
                HStack(spacing: 14) {
                    legend(.white, "bi cái"); legend(Color(hex: 0xffd166), "bi mục tiêu")
                    if drill.cat == .sys { legend(Color(hex: 0xff9f1c), "đường hệ thống") }
                    Text("Đường đi lấy từ mô phỏng cú mẫu").opacity(0.6)
                }.font(.caption)
                section("Công thức")
                FormulaView(blocks: drill.formula)
                section("Cách tập")
                ForEach(Array(drill.steps.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top) { Text("\(i + 1).").bold(); Text(md(s)) }
                }
                section("Mẹo")
                ForEach(Array(drill.tips.enumerated()), id: \.offset) { _, s in HStack(alignment: .top) { Text("•"); Text(md(s)) } }
                if let dm = (drill.generate == nil ? drill.stages[idx].demo : nil), demo != nil {
                    Text("Cú mẫu: \(vn(dm.speed)) m/s · điểm đánh ngang \(vn(dm.a, 2))R, dọc \(vn(dm.b, 2))R").font(.footnote).opacity(0.75)
                }
                if let url = URL(string: "https://www.youtube.com/results?search_query=" + (drill.video.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) {
                    Link(destination: url) { Label("Tìm video hướng dẫn miễn phí trên YouTube", systemImage: "play.rectangle.fill") }.foregroundColor(accent)
                }
                if let s = g.stats[drill.id] { Text("Kết quả của bạn: \(s.ok)/\(s.att) thành công · chuỗi tốt nhất \(s.best)").font(.footnote).opacity(0.75) }
                HStack {
                    if inGame {
                        Button("Tiếp tục tập") { g.card = nil }.buttonStyle(PrimaryButton())
                        Button("Tập lại chặng") { g.card = nil; g.loadStage() }.buttonStyle(GhostButton())
                    } else {
                        Button("Bắt đầu tập") { g.card = nil; g.startDrill(drill) }.buttonStyle(PrimaryButton())
                        Button("Đóng") { g.card = nil }.buttonStyle(GhostButton())
                    }
                }.padding(.top, 6)
            }
            .padding(24)
        }
        .foregroundColor(.white)
        .background(Color(hex: 0x111a20).ignoresSafeArea())
        .onAppear {
            let st = stage
            DispatchQueue.global(qos: .userInitiated).async {
                let d = demoShot(st)
                DispatchQueue.main.async { demo = d; loading = false }
            }
        }
    }

    private func legend(_ c: Color, _ t: String) -> some View { HStack(spacing: 4) { Capsule().fill(c).frame(width: 16, height: 4); Text(t) } }
    private func section(_ t: String) -> some View { Text(t).font(.system(size: 17, weight: .bold)).foregroundColor(accent).padding(.top, 4) }
}

func md(_ s: String) -> AttributedString { (try? AttributedString(markdown: s)) ?? AttributedString(s) }

struct FormulaView: View {
    let blocks: [FormulaBlock]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                switch b {
                case .formula(let f):
                    Text(f).font(.system(size: 20, weight: .semibold, design: .serif)).italic()
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.07)))
                case .text(let t): Text(md(t)).font(.system(size: 14)).opacity(0.9)
                case .table(let rows):
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { ri, row in
                            HStack(spacing: 0) {
                                ForEach(Array(row.enumerated()), id: \.offset) { ci, cell in
                                    Text(cell).font(.system(size: 13, weight: ci == 0 ? .bold : .regular))
                                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                                        .background(ci == 0 ? Color.white.opacity(0.08) : Color.clear)
                                }
                            }
                            if ri < rows.count - 1 { Divider().background(Color.white.opacity(0.2)) }
                        }
                    }.overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15)))
                }
            }
        }
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .bold)).padding(.horizontal, 20).padding(.vertical, 11)
            .background(Capsule().fill(accent)).foregroundColor(.black).opacity(configuration.isPressed ? 0.7 : 1)
    }
}
struct GhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .semibold)).padding(.horizontal, 20).padding(.vertical, 11)
            .background(Capsule().stroke(Color.white.opacity(0.3))).foregroundColor(.white).opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Phiếu kết thúc
struct FinishedCard: View {
    @ObservedObject var g: Game
    let title: String, lead: String, stats: String?, again: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundColor(Color(hex: 0x52b788))
            Text(title).font(.system(size: 26, weight: .heavy))
            Text(lead).opacity(0.85)
            if let stats { Text(stats).font(.footnote).opacity(0.7) }
            HStack {
                Button(again) { g.card = nil; g.again() }.buttonStyle(PrimaryButton())
                Button("Về menu") { g.card = nil; g.openMenu() }.buttonStyle(GhostButton())
            }
        }
        .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(.white).background(Color(hex: 0x111a20).ignoresSafeArea())
    }
}

// MARK: - Cài đặt
struct SettingsView: View {
    @ObservedObject var g: Game
    var body: some View {
        NavigationStack {
            Form {
                Section("Bàn") {
                    Picker("Màu nỉ", selection: $g.settings.cloth) { ForEach(Settings.clothColors, id: \.id) { Text($0.name).tag($0.id) } }
                    Toggle("Hiện số nút trên băng", isOn: $g.settings.labels)
                    Toggle("Góc nhìn 3D", isOn: $g.settings.view3D)
                }
                Section(footer: Text("Tay còn lại giữ nút khoá cơ và chỉnh điểm đánh.")) {
                    Picker("Tay đẩy lực", selection: $g.settings.leftHand) { Text("Tay phải").tag(false); Text("Tay trái").tag(true) }
                    Picker("Cách chỉnh lực", selection: $g.settings.swipePower) { Text("Vuốt đẩy (theo tốc độ tay)").tag(true); Text("Thanh lực + nút Đánh").tag(false) }
                    Picker("Độ nhạy", selection: $g.settings.sens) { Text("Thấp").tag(0.6); Text("Vừa").tag(1.0); Text("Cao").tag(1.4) }
                }
                Section("Vật lý & hỗ trợ") {
                    Toggle("Lệch hướng khi đánh english (squirt)", isOn: $g.settings.squirt)
                    Picker("Hỗ trợ ngắm", selection: $g.settings.guide) { Text("Tắt").tag(0); Text("Cơ bản").tag(1); Text("Đầy đủ (dự đoán vật lý)").tag(2) }
                    Toggle("Tự mở khoá sau mỗi cú", isOn: $g.settings.autoUnlock)
                    Toggle("Bảng thông số bi cái", isOn: $g.settings.telemetry)
                }
                Section("Âm thanh") {
                    Toggle("Âm thanh", isOn: $g.settings.sound)
                    Toggle("Rung phản hồi", isOn: $g.settings.haptics)
                }
                Section {
                    Button("Xoá kết quả tập", role: .destructive) { g.stats = [:]; Store.save("mqv-stats", g.stats) }
                }
            }
            .navigationTitle("Cài đặt")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { g.card = nil } } }
        }
        .preferredColorScheme(.dark)
    }
}

struct HelpView: View {
    @ObservedObject var g: Game
    private let items: [(String, String)] = [
        ("Ngắm", "Kéo một ngón trên bàn. Ở góc nhìn 2D, cơ chỉ thẳng tới chỗ ngón tay; ở 3D, kéo ngang để xoay, kéo dọc để đổi độ cao camera. Hai ngón để phóng to/thu nhỏ."),
        ("Vi chỉnh", "Kéo thanh vạch ở giữa (mỗi điểm ảnh ≈ 0,02°) hoặc giữ nút ‹ ›."),
        ("Khoá cơ", "Chạm nút **Khoá cơ** để giữ nguyên hướng. Khi khoá, kéo trên bàn chỉ xoay camera để quan sát. Chạm lần nữa để mở."),
        ("Lực đánh", "Đặt ngón tay còn lại lên ô lực, **kéo xuống** (lùi cơ) rồi **đẩy lên**. Tốc độ đẩy quyết định lực: đẩy chậm = đánh nhẹ, đẩy nhanh và dứt khoát = đánh mạnh. Thả tay mà không đẩy thì huỷ cú."),
        ("Điểm đánh", "Kéo chấm xanh trên quả bi trắng: trên = theo, dưới = kéo, trái/phải = english. Chạm đúp để về tâm. Thanh độ nâng cơ để đánh massé."),
        ("Hỗ trợ ngắm", "Biểu tượng con mắt: Tắt / Cơ bản (tới điểm chạm, hướng bi mục tiêu) / Đầy đủ (dự đoán vật lý cả xoáy, băng). Dự đoán dùng lực của cú trước."),
        ("Bi trong tay", "Khi phạm lỗi hoặc bài cho phép, kéo bi cái tới chỗ mới (hoặc bấm biểu tượng bàn tay)."),
        ("Chậm & thông số", "Nút rùa phát chậm 5 lần để quan sát xoáy; bảng thông số (bật trong Cài đặt) hiện tốc độ, tỉ số ωR/v, xoáy ngang và trạng thái trượt/lăn."),
    ]
    var body: some View {
        NavigationStack {
            List(items, id: \.0) { it in
                VStack(alignment: .leading, spacing: 4) { Text(it.0).font(.headline); Text(md(it.1)).font(.subheadline).opacity(0.85) }.padding(.vertical, 4)
            }
            .navigationTitle("Cách điều khiển")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Đã hiểu") { g.card = nil } } }
        }.preferredColorScheme(.dark)
    }
}

struct SourcesView: View {
    @ObservedObject var g: Game
    private let links: [(String, String)] = [
        ("Dr. Dave Alciatore – các hệ thống nút số", "https://drdavepoolinfo.com/FAQ/bank-kick/diamond-systems/"),
        ("Billiards Digest (11/2010) – Corner-5", "https://billiards.colostate.edu/bd_articles/2010/nov10.pdf"),
        ("Thông số vật lý thiết bị bi-a", "https://drdavepoolinfo.com/?p=2349"),
        ("Video bài tập miễn phí trên YouTube", "https://www.youtube.com/results?search_query=dr+dave+pool+drills"),
        ("PoolShot – phần mềm tạo bài tập (tham khảo phong cách sơ đồ)", "https://www.poolshot.org"),
    ]
    var body: some View {
        NavigationStack {
            List {
                Text("Bài tập được biên soạn lại từ các kiến thức và bài giảng miễn phí phổ biến; sơ đồ được vẽ lại từ mô phỏng trong ứng dụng.").font(.subheadline)
                ForEach(links, id: \.1) { l in if let u = URL(string: l.1) { Link(l.0, destination: u) } }
            }
            .navigationTitle("Nguồn tham khảo")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Đóng") { g.card = nil } } }
        }.preferredColorScheme(.dark)
    }
}
