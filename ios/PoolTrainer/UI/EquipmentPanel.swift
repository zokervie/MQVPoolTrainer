import SwiftUI

enum CuePreset: String, CaseIterable, Identifiable {
    case playing, jump, breakCue
    var id: String { rawValue }
    var label: String {
        switch self {
        case .playing: return "Zoker Playing"
        case .jump: return "Zoker Jump"
        case .breakCue: return "Zoker Break"
        }
    }
}
struct EquipmentPanel: View {
    @ObservedObject var g: Game
    @AppStorage("zoker-cue-choice") private var cue = "playing"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Thư viện cơ 3D") {
                    ForEach(CuePreset.allCases) { preset in
                        Button {
                            cue = preset.rawValue
                            g.scene.selectCue(cue)
                        } label: {
                            HStack {
                                Text(preset.label)
                                Spacer()
                                if cue == preset.rawValue { Image(systemName: "checkmark.circle.fill") }
                            }
                        }
                    }
                    Text("Các mẫu cơ Zoker là mô phỏng; chưa đại diện thông số cơ hãng thực tế.")
                        .font(.footnote)
                }
                Section("Góc nâng cơ") {
                    Slider(value: $g.elev, in: 0...65, step: 1)
                    Text("\(Int(g.elev))°")
                    Text("Jump và massé vẫn cần hiệu chuẩn vật lý trên thiết bị thật.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Cơ và độ dốc")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
        }.onAppear { g.scene.selectCue(cue) }
    }
}
