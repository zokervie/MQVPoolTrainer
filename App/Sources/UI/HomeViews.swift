import SwiftUI
import PoolPhysics
import PoolDrills

/// Màn chính: chọn chế độ. Có chữ ở đây; màn chơi thì không.
struct HomeView: View {
    let model: GameModel
    var onPlay: () -> Void
    @State private var drills = DrillCatalog.load()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { model.startFree(); onPlay() } label: {
                        Label("Chơi tự do (bi cái + 1 bi)", systemImage: "circle.grid.2x1")
                    }
                    Button { model.startRack(); onPlay() } label: {
                        Label("Xếp bi phá", systemImage: "triangle")
                    }
                } header: { Text("Luyện tập tự do") }

                Section {
                    ForEach(drills) { d in
                        NavigationLink { DrillDetailView(drill: d, model: model, onPlay: onPlay) } label: {
                            DrillRow(drill: d, stats: DrillStats(model.history.logs.filter { $0.drillId == d.id && !$0.shotLab }))
                        }
                    }
                } header: { Text("Bài tập (\(drills.count))") }

                Section {
                    NavigationLink { HistoryView(history: model.history, drills: drills) } label: {
                        Label("Lịch sử và phân tích", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink { SettingsView(settings: model.settings, tables: model.tables) } label: {
                        Label("Cài đặt", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Zoker Pool Trainer")
        }
    }
}

private struct DrillRow: View {
    let drill: Drill
    let stats: DrillStats
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(drill.ten)
            Text(stats.attempts == 0 ? "Chưa tập" :
                 String(format: "%d lần · đạt %.0f%%", stats.attempts, stats.successRate * 100))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Thẻ hướng dẫn xem trước cú đánh (có chữ ở đây; ẩn khi vào màn chơi).
struct DrillDetailView: View {
    let drill: Drill
    let model: GameModel
    var onPlay: () -> Void

    var body: some View {
        List {
            Section("Hướng dẫn") {
                LabeledContent("Lực", value: "Mức \(drill.huongDan.luc) (\(String(format: "%.1f", SpeedScale.cueSpeed(level: drill.huongDan.luc))) m/s)")
                LabeledContent("Điểm chạm", value: String(format: "dọc %+.2f · ngang %+.2f", drill.huongDan.diemCham.doc, drill.huongDan.diemCham.ngang))
                if let f = drill.huongDan.congThuc { LabeledContent("Công thức", value: f) }
                if let note = drill.huongDan.ghiChu { Text(note) }
            }
            Section("Điều kiện đạt") {
                ForEach(Array(drill.parsedConditions.enumerated()), id: \.offset) { _, c in
                    Text(GameModel.describe(c))
                }
                LabeledContent("Số lần", value: "\(drill.soLan)")
            }
            Section {
                Button { model.startDrill(drill); onPlay() } label: {
                    Label("Bắt đầu", systemImage: "play.fill")
                }
            }
        }
        .navigationTitle(drill.ten)
    }
}

struct HistoryView: View {
    let history: HistoryStore
    let drills: [Drill]
    @State private var confirmClear = false

    var body: some View {
        List {
            let insights = ErrorAnalysis.insights(history.logs)
            Section("Nhận xét") {
                if insights.isEmpty {
                    Text("Chưa đủ dữ liệu (cần ít nhất 8 cú cho mỗi nhận xét).").foregroundStyle(.secondary)
                }
                ForEach(insights, id: \.code) { i in
                    VStack(alignment: .leading) {
                        Text(i.message)
                        if let id = i.suggestedDrillId, let d = drills.first(where: { $0.id == id }) {
                            Text("Gợi ý bài: \(d.ten)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Theo bài tập") {
                ForEach(drills) { d in
                    let s = DrillStats(history.logs.filter { $0.drillId == d.id && !$0.shotLab })
                    if s.attempts > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.ten)
                            Text(statsLine(s)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Gần đây") {
                ForEach(Array(history.logs.suffix(30).reversed().enumerated()), id: \.offset) { _, log in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drills.first { $0.id == log.drillId }?.ten ?? "Tự do")
                        Text(logLine(log)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button("Xóa lịch sử", role: .destructive) { confirmClear = true }
            }
        }
        .navigationTitle("Lịch sử")
        .confirmationDialog("Xóa toàn bộ lịch sử?", isPresented: $confirmClear) {
            Button("Xóa", role: .destructive) { history.clear() }
        }
    }

    private func statsLine(_ s: DrillStats) -> String {
        var parts = [String(format: "%d lần · đạt %.0f%%", s.attempts, s.successRate * 100)]
        if let cv = s.speedCV { parts.append(String(format: "lực dao động %.0f%%", cv * 100)) }
        if let a = s.meanAbsAimError { parts.append(String(format: "lệch ngắm TB %.2f°", a)) }
        return parts.joined(separator: " · ")
    }

    private func logLine(_ l: ShotLog) -> String {
        var parts = [l.date.formatted(date: .abbreviated, time: .shortened), "mức \(l.speedLevel)"]
        if let s = l.success { parts.append(s ? "đạt" : "chưa đạt") }
        if let a = l.aimErrorDegrees { parts.append(String(format: "ngắm %+.2f°", a)) }
        if l.shotLab { parts.append("Shot Lab") }
        return parts.joined(separator: " · ")
    }
}
