import SwiftUI
import PoolPhysics

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let tables: TableStore

    var body: some View {
        Form {
            Section("Âm thanh") {
                Toggle("Tắt âm thanh", isOn: $settings.muted)
                VStack(alignment: .leading) {
                    Text("Âm lượng hiệu ứng: \(Int(settings.effectsVolume * 100))%")
                    Slider(value: $settings.effectsVolume, in: 0...1)
                }
                Toggle("Âm thanh không gian", isOn: $settings.spatialAudio)
                Toggle("Chế độ tai nghe", isOn: $settings.headphoneMode)
                Text("Âm thanh hiện là bộ mẫu tổng hợp tạm, chưa thu từ bàn thật.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Điều khiển") {
                Toggle("Thuận tay trái (đảo bố cục)", isOn: $settings.leftHanded)
                VStack(alignment: .leading) {
                    Text(String(format: "Độ cao mắt: %.0f cm trên mặt bàn", settings.eyeHeight * 100))
                    Slider(value: $settings.eyeHeight, in: 0.15...0.30)
                }
                NavigationLink("Hiệu chỉnh kích thước màn hình") { ScreenCalibrationView(settings: settings) }
                Button("Hiện lại hướng dẫn vùng khóa") { settings.seenLockHint = false }
            }
            Section("Bàn") {
                NavigationLink("Hồ sơ bàn (chỉnh tay)") { TableProfileView(tables: tables) }
            }
        }
        .navigationTitle("Cài đặt")
        .onDisappear { settings.save() }
    }
}

/// Đặt một thẻ ngân hàng (85,6 × 53,98 mm) lên màn hình, kéo thanh trượt đến khi khung khớp thẻ.
struct ScreenCalibrationView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            Text("Đặt một thẻ ngân hàng lên khung, kéo thanh trượt cho đến khi khung vừa khít cạnh thẻ.")
                .multilineTextAlignment(.center)
            RoundedRectangle(cornerRadius: 3.2 / settings.mmPerPoint)
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: 85.6 / settings.mmPerPoint, height: 53.98 / settings.mmPerPoint)
            Slider(value: $settings.mmPerPoint, in: 0.10...0.22)
                .frame(maxWidth: 360)
            Text(String(format: "%.4f mm/điểm", settings.mmPerPoint)).font(.caption.monospacedDigit())
        }
        .padding()
        .navigationTitle("Hiệu chỉnh màn hình")
        .onDisappear { settings.save() }
    }
}

/// R5: chỉnh tay tham số bàn theo cảm nhận trên bàn thật. Ghi rõ nguồn gốc là "giả định, chỉnh tay".
struct TableProfileView: View {
    let tables: TableStore
    @State private var rolling: Double = 0
    @State private var sliding: Double = 0
    @State private var cushionE: Double = 0
    @State private var cushionMu: Double = 0
    @State private var conditions = ""

    var body: some View {
        Form {
            Section {
                slider("Cản lăn (nỉ nhanh ↔ chậm)", $rolling, ParameterKey.rollingResistance, "%.4f")
                slider("Ma sát trượt", $sliding, .slidingFriction, "%.3f")
                slider("Độ nảy băng", $cushionE, .cushionRestitution, "%.2f")
                slider("Ma sát băng", $cushionMu, .cushionFriction, "%.2f")
                TextField("Điều kiện bàn (loại nỉ, độ mới, bi…)", text: $conditions)
            } footer: {
                Text("Giá trị chỉnh tay được lưu với nguồn gốc \"giả định\". Đo bằng video ở R4 mới cho số liệu đã kiểm chứng.")
            }
            Section("Nguồn gốc hiện tại") {
                ForEach(ParameterKey.allCases, id: \.self) { k in
                    VStack(alignment: .leading) {
                        Text(k.rawValue).font(.caption.monospaced())
                        Text(describe(tables.provenance[k])).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button("Lưu hồ sơ") { save() }
                Button("Về mặc định", role: .destructive) { tables.save(nil); load() }
            }
        }
        .navigationTitle("Hồ sơ bàn")
        .onAppear { load() }
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ key: ParameterKey, _ fmt: String) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(String(format: fmt, value.wrappedValue))")
            Slider(value: value, in: key.plausibleRange)
        }
    }

    private func load() {
        let p = tables.parameters
        rolling = p.rollingResistance; sliding = p.slidingFriction
        cushionE = p.cushionRestitution; cushionMu = p.cushionFriction
        conditions = tables.calibration?.conditions ?? ""
    }

    private func save() {
        let note = Provenance.assumed(note: "Chỉnh tay theo cảm nhận trên bàn thật, chưa đo")
        let profile = CalibrationProfile(
            tableId: tables.definition.id, measuredAt: Date(), conditions: conditions,
            overrides: [.rollingResistance: Measured(rolling, note), .slidingFriction: Measured(sliding, note),
                        .cushionRestitution: Measured(cushionE, note), .cushionFriction: Measured(cushionMu, note)])
        tables.save(profile)
    }

    private func describe(_ p: Provenance?) -> String {
        switch p {
        case .published(let s): "Đã công bố: \(s)"
        case .measured(let m, let n, let r): "Đã đo: \(m), \(n) mẫu, sai số dư \(r)"
        case .assumed(let note): "Giả định: \(note)"
        case nil: "Thiếu nguồn"
        }
    }
}
