import SwiftUI
import PoolPhysics
import PoolDrills

/// Shot Lab: nhập trực tiếp hướng, điểm chạm, lực để tái hiện cú và làm bài quyết định.
/// Không có trợ giúp: không tự căn bi, không bù squirt/throw, không hiện quỹ đạo trước cú.
struct ShotLabPanel: View {
    @Bindable var model: GameModel
    @State private var offsetDegrees = 0.0
    @State private var vertical = 0.0
    @State private var horizontal = 0.0
    @State private var level = 3
    @State private var elevationDeg = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shot Lab").font(.headline)
            Text(String(format: "Hướng: %+.1f° so với hướng hiện tại", offsetDegrees)).font(.caption)
            Slider(value: $offsetDegrees, in: -10...10, step: 0.1)
            Text(String(format: "Điểm chạm dọc %+.2f · ngang %+.2f (bán kính bi)", vertical, horizontal)).font(.caption)
            Slider(value: $vertical, in: -0.5...0.5, step: 0.05)
            Slider(value: $horizontal, in: -0.5...0.5, step: 0.05)
            Text(String(format: "Độ dốc cơ %.0f° (nhảy bi / massé)", elevationDeg)).font(.caption)
            Slider(value: $elevationDeg, in: 0...80, step: 1)
            Stepper("Lực mức \(level) (\(String(format: "%.1f", SpeedScale.cueSpeed(level: level))) m/s)",
                    value: $level, in: 1...7)
                .font(.caption)
            HStack {
                if let s = model.lastStrike {
                    Button("Lấy cú vừa đánh") {
                        offsetDegrees = 0
                        model.aimAngle = s.aimAngle
                        vertical = s.tipVertical; horizontal = s.tipHorizontal
                        level = SpeedScale.level(forCueSpeed: s.cueSpeed)
                        elevationDeg = s.elevation * 180 / .pi
                    }
                    .font(.caption)
                }
                Spacer()
                Button {
                    let s = CueStrike(aimAngle: model.aimAngle + offsetDegrees * .pi / 180,
                                      cueSpeed: SpeedScale.cueSpeed(level: level),
                                      tipVertical: vertical, tipHorizontal: horizontal,
                                      elevation: elevationDeg * .pi / 180, cueId: model.cue.id)
                    model.shootShotLab(s)
                } label: { Label("Đánh", systemImage: "scope") }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
