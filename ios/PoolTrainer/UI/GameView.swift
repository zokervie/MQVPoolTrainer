import SwiftUI

/// Lớp điều khiển khi đang chơi: thanh công cụ, dải bi, cụm điểm đánh, khoá cơ + vi chỉnh, ô lực.
struct HUDView: View {
    @ObservedObject var g: Game

    var body: some View {
        VStack(spacing: 6) {
            topBar
            HStack(spacing: 4) { ForEach(g.ballStrip) { MiniBall(id: $0.id, gone: $0.gone, size: 18) } }
            if let info = g.sysInfo {
                Text(info).font(.system(size: 14, weight: .heavy)).padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: 0xff9f1c, alpha: 0.9))).foregroundColor(.black)
            }
            HStack(alignment: .top) {
                if g.settings.telemetry { TelemetryView(t: g.telemetry) }
                Spacer()
            }
            Spacer()
            if let t = g.toast {
                Text(t.msg).font(.system(size: 14, weight: .semibold)).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(t.kind == .ok ? Color(hex: 0x1b5e3b, alpha: 0.95) : t.kind == .bad ? Color(hex: 0x7a1f2b, alpha: 0.95) : panelBG))
                    .foregroundColor(.white).transition(.opacity).id(t.id)
            }
            bottom
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .animation(.easeOut(duration: 0.2), value: g.toast)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            IconButton(system: "line.3.horizontal") { g.openMenu() }
            VStack(alignment: .leading, spacing: 1) {
                Text(g.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                Text(g.subtitle).font(.system(size: 11)).opacity(0.75).lineLimit(1)
            }.foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(panelBG))
            Spacer(minLength: 4)
            if g.mode == .drill, let d = g.drill {
                IconButton(system: "function") { g.card = .drill(d, inGame: true) }
                IconButton(system: "lightbulb", on: g.hintOn) { g.toggleHint() }
                if g.hasDemo { IconButton(system: "play.fill") { g.playDemo() } }
            }
            if g.ballInHand { IconButton(system: "hand.raised", on: g.phase == .placing) { g.toggleHand() } }
            IconButton(system: "eye", badge: ["Tắt", "1", "Đủ"][g.settings.guide]) { g.cycleGuide() }
            IconButton(system: "tortoise", on: g.slow) { g.slow.toggle(); g.showToast(g.slow ? "Phát chậm ×5" : "Tốc độ thường") }
            IconButton(system: nil, text: g.settings.view3D ? "3D" : "2D") { g.toggleView() }
            IconButton(system: "arrow.counterclockwise") { g.reset() }
        }
    }

    private var spinCluster: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "angle").font(.system(size: 12))
                Slider(value: $g.elev, in: 0...30, step: 1).frame(width: 90)
                Text("\(Int(g.elev))°").font(.system(size: 12, weight: .bold).monospacedDigit()).frame(width: 28)
            }.foregroundColor(.white)
            SpinPad(g: g)
            Text(g.spinText == "tâm bi" ? "Tâm bi" : g.spinText).font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.85))
        }.panel()
    }

    private var centerCluster: some View {
        VStack(spacing: 6) {
            Button { g.toggleLock() } label: {
                Label(g.locked ? "Đã khoá" : "Khoá cơ", systemImage: g.locked ? "lock.fill" : "lock.open")
                    .font(.system(size: 15, weight: .bold)).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(g.locked ? Color(hex: 0xf77f00) : Color.white.opacity(0.1)))
                    .foregroundColor(.white)
            }.buttonStyle(.plain)
            FineStrip(g: g)
            Text(g.aimText).font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundColor(.white.opacity(0.8))
        }.panel()
    }

    private var powerCluster: some View {
        VStack(spacing: 6) {
            if g.settings.swipePower { PowerPad(g: g) } else { SliderPower(g: g) }
            Text(powerText).font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundColor(.white.opacity(0.85))
        }.panel()
    }

    private var powerText: String {
        guard let p = g.shownPower ?? (g.settings.swipePower ? nil : g.lastPower) else { return "Lực —" }
        return "Lực \(Int((p * 100).rounded()))% · \(vn(Game.powerToSpeed(p))) m/s"
    }

    private var bottom: some View {
        HStack(alignment: .bottom) {
            if g.settings.leftHand { powerCluster } else { spinCluster }
            Spacer()
            centerCluster
            Spacer()
            if g.settings.leftHand { spinCluster } else { powerCluster }
        }
    }
}

struct TelemetryView: View {
    let t: Telemetry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Tốc độ  \(vn(t.speed, 2)) m/s  (\(vn(t.speed * 3.6)) km/h)")
            Text("ωR/v  \(vn(t.top, 2))   ·   ngang \(vn(t.side, 1)) v/s")
            Text("Trạng thái: \(t.speed < 0.005 ? "đứng yên" : t.sliding ? "TRƯỢT" : "LĂN")")
            Text("Va băng \(t.rails)   ·   Vmax \(vn(t.vmax, 2)) m/s")
        }
        .font(.system(size: 11, design: .monospaced)).foregroundColor(.white).padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.55)))
    }
}
