import SwiftUI

/// Lớp điều khiển khi đang chơi: thanh công cụ, dải bi, cụm điểm đánh, khoá cơ + vi chỉnh, ô lực.
struct HUDView: View {
    @ObservedObject var g: Game
    @State private var equipmentOpen = false

    var body: some View {
        VStack(spacing: 6) {
            if !g.locked { topBar }
            if !g.locked { HStack(spacing: 4) { ForEach(g.ballStrip) { MiniBall(id: $0.id, gone: $0.gone, size: 18) } } }
            if !g.locked, let info = g.sysInfo {
                Text(info).font(.system(size: 14, weight: .heavy)).padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: 0xff9f1c, alpha: 0.9))).foregroundColor(.black)
            }
            if !g.locked { HStack(alignment: .top) {
                if g.settings.telemetry && !g.settings.realistic { TelemetryView(t: g.telemetry) }
                Spacer()
                if let fb = g.feedback { FeedbackPanel(g: g, fb: fb).transition(.move(edge: .trailing).combined(with: .opacity)) }
            }
            }
            Spacer()
            if !g.locked, let t = g.toast {
                Text(t.msg).font(.system(size: 14, weight: .semibold)).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(t.kind == .ok ? Color(hex: 0x1b5e3b, alpha: 0.95) : t.kind == .bad ? Color(hex: 0x7a1f2b, alpha: 0.95) : panelBG))
                    .foregroundColor(.white).transition(.opacity).id(t.id)
            }
            bottom
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .animation(.easeOut(duration: 0.2), value: g.toast)
        .animation(.easeOut(duration: 0.25), value: g.feedback)
        .sheet(isPresented: $equipmentOpen) { EquipmentPanel(g: g) }
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
                if g.hasDemo && !g.settings.realistic { IconButton(system: "play.fill") { g.playDemo() } }
            }
            if g.ballInHand { IconButton(system: "hand.raised", on: g.phase == .placing) { g.toggleHand() } }
            if g.lastShot != nil { IconButton(system: "gobackward") { g.replay() }.disabled(!g.canReplay) }
            IconButton(system: "scope", on: g.settings.realistic) { g.toggleRealistic() }
            if !g.settings.realistic {
                IconButton(system: "eye", badge: ["Tắt", "1", "Đủ"][g.settings.guide]) { g.cycleGuide() }
            }
            IconButton(system: "tortoise", on: g.slow) { g.slow.toggle(); g.showToast(g.slow ? "Phát chậm ×5" : "Tốc độ thường") }
            IconButton(system: nil, text: g.settings.view3D ? "3D" : "2D") { g.toggleView() }
            IconButton(system: "arrow.counterclockwise") { g.reset() }
        }
    }

    private var spinCluster: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "angle").font(.system(size: 12))
                Slider(value: $g.elev, in: 0...30, step: 1).frame(width: 80)
                Text("\(Int(g.elev))°").font(.system(size: 12, weight: .bold).monospacedDigit()).frame(width: 28)
            }.foregroundColor(.white)
            SpinPad(g: g)
            Text(g.spinText == "tâm bi" ? "Tâm bi" : g.spinText).font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.85))
        }.panel()
    }

    // gọn, sát đáy màn hình để không che bi cái
    private var centerCluster: some View {
        VStack(spacing: 4) {
            if !g.settings.realistic {
                Text(g.aimText).font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundColor(.white.opacity(0.8))
            }
            HStack(spacing: 8) {
                Button { g.toggleLock() } label: {
                    Text("B").font(.system(size: 19, weight: .bold, design: .rounded))
                        .font(.system(size: 14, weight: .bold)).padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Circle().fill(g.locked ? Color.white.opacity(0.24) : Color.white.opacity(0.10)))
                        .foregroundColor(.white)
                }.buttonStyle(.plain)
                FineStrip(g: g).opacity(0.47).scaleEffect(y: 0.68)
            }
        }.padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(panelBG))
    }

    private var powerCluster: some View {
        VStack(spacing: 6) {
            if g.settings.swipePower { PowerPad(g: g) } else { SliderPower(g: g) }
            Text(powerText).font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundColor(.white.opacity(0.85))
        }.panel()
    }

    private var powerText: String {
        guard let p = g.shownPower ?? (g.settings.swipePower ? nil : g.lastPower) else { return "Lực —" }
        let v = Game.powerToSpeed(p)
        if g.settings.realistic && g.phase != .rolling && g.feedback == nil { return "Lực —" }
        return "\(vn(v)) m/s · mức \(vn(SpeedScale.level(speed: v)))/7"
    }

    // 0.9 bridge layout: always retain B at lower-left while locked;
    // all other controls disappear during the hold.
    private var bridgeButton: some View {
        Text("B").font(.system(size: 19, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .frame(width: 62, height: 62)
            .background(Circle().fill(Color.white.opacity(g.locked ? 0.23 : 0.10)))
            .overlay(Circle().stroke(Color.white.opacity(0.30), lineWidth: 1))
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !g.locked && g.phase == .aim { g.setLock(true) }
                }
                .onEnded { _ in if g.locked { g.setLock(false) } })
            .accessibilityLabel("Giữ B để khóa cầu tay, vuốt trên bàn bằng ngón còn lại")
    }

    private var bottom: some View {
        HStack(alignment: .bottom) {
            bridgeButton
            if !g.locked {
                spinCluster
                Button { equipmentOpen = true } label: { Image(systemName: "pencil.tip.crop.circle").font(.system(size: 20)).frame(width: 38, height: 38).background(Circle().fill(Color.white.opacity(0.12))) }.buttonStyle(.plain).foregroundColor(.white)
                Spacer(minLength: 8)
                FineStrip(g: g).opacity(0.42).scaleEffect(y: 0.65)
                Spacer(minLength: 8)
                if !g.settings.swipePower { powerCluster }
            } else {
                Spacer()
            }
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
