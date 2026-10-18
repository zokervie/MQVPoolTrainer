import SwiftUI
import PoolDrills

/// Số liệu sau cú đánh (chỉ hiện khi bi đã dừng). Sai số ngắm chỉ khi bài tập có mục tiêu cụ thể.
struct FeedbackPanel: View {
    let model: GameModel
    let feedback: ShotFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ok = feedback.drillSuccess {
                Label(ok ? "Đạt" : "Chưa đạt", systemImage: ok ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.headline)
                    .foregroundStyle(ok ? .green : .orange)
            }
            ForEach(feedback.conditionLines, id: \.self) { Text($0).font(.caption) }

            if feedback.miscue {
                Text("Trượt cơ: điểm chạm quá xa tâm bi.").font(.callout).foregroundStyle(.orange)
            }
            row("Lực", String(format: "mức %d · %.1f m/s · bi tự lăn ≈ %.1f chiều dài bàn",
                              feedback.speedLevel, feedback.cueSpeed, feedback.tableLengths))
            if let lat = feedback.lateralRatio {
                row("Cú vuốt", abs(lat) < 0.04 ? "thẳng" :
                    String(format: "lệch %@ %.0f%%", lat > 0 ? "phải" : "trái", abs(lat) * 100))
            }
            if let f = feedback.followThroughRatio, f < 0.85 {
                row("Ra cơ", String(format: "giảm tốc trước khi chạm (%.0f%% tốc độ đỉnh)", f * 100))
            }
            if let d = feedback.cueBallDistance {
                row("Bi cái", String(format: "cách tâm vùng đích %.0f cm", d * 100))
            }
            aimRow
            if feedback.shotLab { Text("Cú từ Shot Lab").font(.caption2).foregroundStyle(.secondary) }

            HStack {
                button("Phát lại", "play.fill") { model.replay(rate: 1) }
                button("Chậm ×4", "tortoise.fill") { model.replay(rate: 0.25) }
                Spacer()
                if model.drill != nil {
                    button("Đặt lại", "arrow.counterclockwise") { model.resetLayout() }
                    button("Lần tiếp", "forward.fill") { model.nextAttempt() }
                } else {
                    button("Tiếp tục", "forward.fill") { model.dismissReview() }
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.primary)
    }

    @ViewBuilder private var aimRow: some View {
        if feedback.aimPending {
            HStack { ProgressView(); Text("Đang tính khoảng ngắm…").font(.caption) }
        } else if let err = feedback.aimErrorDegrees {
            if err == 0 {
                row("Ngắm", String(format: "nằm trong khoảng đạt (rộng %.1f°)", feedback.aimWindowDegrees ?? 0))
            } else {
                // err > 0: lẽ ra phải ngắm sang trái hơn → người chơi ngắm lệch phải.
                let mm = feedback.aimErrorMillimetersAtPocket.map { String(format: " ≈ %.0f mm tại miệng lỗ", $0) } ?? ""
                row("Ngắm", String(format: "lệch %@ %.2f°%@ · khoảng đạt rộng %.1f°",
                                   err > 0 ? "phải" : "trái", abs(err), mm, feedback.aimWindowDegrees ?? 0))
            }
        } else if model.drill?.primaryPocketTarget != nil {
            row("Ngắm", "không tìm thấy hướng đạt với lực và điểm chạm này")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.caption.weight(.semibold)).frame(width: 64, alignment: .leading)
            Text(value).font(.callout)
        }
    }

    private func button(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.callout).lineLimit(1).fixedSize() }
            .buttonStyle(.bordered)
    }
}
