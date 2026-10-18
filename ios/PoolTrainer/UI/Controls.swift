import SwiftUI

let accent = Color(hex: 0x4cc9f0)
let panelBG = Color(hex: 0x0d1418, alpha: 0.72)

struct Panel: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(panelBG))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08)))
    }
}
extension View { func panel() -> some View { modifier(Panel()) } }

/// Nút tròn trên thanh công cụ.
struct IconButton: View {
    let system: String?
    var text: String? = nil
    var on = false
    var badge: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let system { Image(systemName: system).font(.system(size: 16, weight: .semibold)) }
                    else { Text(text ?? "").font(.system(size: 14, weight: .heavy)) }
                }
                .frame(width: 38, height: 38)
                .background(Circle().fill(on ? accent.opacity(0.35) : panelBG))
                .overlay(Circle().stroke(on ? accent : Color.white.opacity(0.1)))
                if let badge {
                    Text(badge).font(.system(size: 9, weight: .bold)).padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(accent)).foregroundColor(.black).offset(x: 4, y: -2)
                }
            }
        }
        .buttonStyle(.plain).foregroundColor(.white)
    }
}

/// Chọn điểm đánh trên bi cái (±0,6R). Chạm đúp để về tâm.
struct SpinPad: View {
    @ObservedObject var g: Game
    let size: CGFloat = 96
    var body: some View {
        let lim = 0.6
        ZStack {
            Circle().fill(RadialGradient(colors: [.white, Color(white: 0.78)], center: UnitPoint(x: 0.38, y: 0.32), startRadius: 2, endRadius: size * 0.7))
            Circle().stroke(Color.red.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: size * 0.8, height: size * 0.8)
            Rectangle().fill(Color.black.opacity(0.18)).frame(width: 1, height: size)
            Rectangle().fill(Color.black.opacity(0.18)).frame(width: size, height: 1)
            Circle().fill(accent).overlay(Circle().stroke(Color.white, lineWidth: 2)).frame(width: 16, height: 16)
                .offset(x: CGFloat(g.spinA / lim) * size * 0.4, y: -CGFloat(g.spinB / lim) * size * 0.4)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            var a = (v.location.x / size - 0.5) * 2, b = -(v.location.y / size - 0.5) * 2
            let m = hypot(a, b); if m > 1 { a /= m; b /= m }
            g.spinA = (Double(a) * lim * 100).rounded() / 100
            g.spinB = (Double(b) * lim * 100).rounded() / 100
        })
        .simultaneousGesture(TapGesture(count: 2).onEnded { g.spinA = 0; g.spinB = 0 })
        .accessibilityLabel("Điểm đánh trên bi cái")
    }
}

/// Nút giữ để lặp (vi chỉnh ‹ ›).
struct HoldButton: View {
    let label: String
    let action: (Int) -> Void
    @State private var timer: Timer? = nil
    @State private var n = 0
    var body: some View {
        Text(label).font(.system(size: 22, weight: .bold)).frame(width: 36, height: 36)
            .background(Circle().fill(Color.white.opacity(0.1))).foregroundColor(.white)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard timer == nil else { return }
                    n = 0; action(0)
                    timer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { _ in n += 1; action(n) }
                }
                .onEnded { _ in timer?.invalidate(); timer = nil })
    }
}

/// Thanh vạch vi chỉnh: ~0,023° mỗi điểm ảnh.
struct FineStrip: View {
    @ObservedObject var g: Game
    @State private var last: CGFloat? = nil
    @State private var off: CGFloat = 0
    var body: some View {
        HStack(spacing: 6) {
            HoldButton(label: "‹") { n in g.nudge(-0.0009 * (n > 12 ? 4 : 1)) }
            ZStack {
                Canvas { ctx, size in
                    let step: CGFloat = 10
                    var x = off.truncatingRemainder(dividingBy: step * 4) - step * 4
                    var i = 0
                    while x < size.width + step * 4 {
                        let big = i % 4 == 0
                        let h: CGFloat = big ? size.height * 0.6 : size.height * 0.32
                        ctx.fill(Path(CGRect(x: x, y: (size.height - h) / 2, width: 1.5, height: h)), with: .color(.white.opacity(big ? 0.7 : 0.35)))
                        x += step; i += 1
                    }
                    ctx.fill(Path(CGRect(x: size.width / 2 - 1, y: 0, width: 2, height: size.height)), with: .color(accent))
                }
            }
            .frame(width: 150, height: 34)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let x = v.location.x
                    if let l = last, !g.locked { g.nudge(Double(x - l) * 0.0004); off += x - l }
                    last = x
                }
                .onEnded { _ in last = nil })
            HoldButton(label: "›") { n in g.nudge(0.0009 * (n > 12 ? 4 : 1)) }
        }
        .opacity(g.locked ? 0.45 : 1)
        .accessibilityLabel("Vi chỉnh hướng cơ")
    }
}

/// Ô lực: kéo xuống (lùi cơ) rồi đẩy lên – tốc độ đẩy quyết định lực.
struct PowerPad: View {
    @ObservedObject var g: Game
    @State private var y0: CGFloat? = nil
    @State private var maxPull: CGFloat = 0
    @State private var pullNow: CGFloat = 0
    @State private var samples: [(y: CGFloat, t: TimeInterval)] = []
    @State private var fired = false
    let height: CGFloat = 170

    private func speedToPower(_ v: CGFloat) -> Double {
        let vmax = max(1400, height * 5.5) * CGFloat(g.settings.sens)
        return Double(min(1, max(0, v / vmax)))
    }
    private func velocity() -> CGFloat {
        guard let a = samples.first, let b = samples.last, b.t > a.t else { return 0 }
        return (a.y - b.y) / CGFloat(b.t - a.t)
    }

    var body: some View {
        let canShoot = g.phase == .aim || g.phase == .placing
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06))
            // độ lùi cơ
            RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xff6b6b).opacity(0.55))
                .frame(height: max(0, pullNow * height * 0.7))
            if let p = g.shownPower {
                RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [Color(hex: 0x52b788), Color(hex: 0xffd166), Color(hex: 0xef476f)], startPoint: .bottom, endPoint: .top))
                    .frame(height: CGFloat(p) * height).opacity(0.8)
            }
            VStack(spacing: 2) {
                Image(systemName: "arrow.up.and.down").font(.system(size: 18, weight: .bold))
                Text("Kéo xuống").font(.system(size: 12, weight: .bold))
                Text("rồi đẩy lên").font(.system(size: 10)).opacity(0.8)
            }.foregroundColor(.white.opacity(0.85)).frame(maxHeight: .infinity)
        }
        .frame(width: 84, height: height)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(y0 != nil ? accent : Color.white.opacity(0.12), lineWidth: y0 != nil ? 2 : 1))
        .opacity(canShoot ? 1 : 0.4)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                guard g.phase == .aim || g.phase == .placing else { return }
                let now = v.time.timeIntervalSinceReferenceDate
                if y0 == nil { y0 = v.startLocation.y; maxPull = 0; samples = []; fired = false }
                guard !fired, let y0 else { return }
                samples.append((v.location.y, now))
                while samples.count > 2 && now - samples[0].t > 0.09 { samples.removeFirst() }
                let pull = min(1, max(0, (v.location.y - y0) / (height * 0.65)))
                maxPull = max(maxPull, pull); pullNow = pull
                g.pull = Double(pull) * 0.22
                let vel = velocity(), p = speedToPower(vel)
                if vel > 0 { g.shownPower = p }
                if maxPull > 0.04 && v.location.y <= y0 && vel > 40 { fired = true; finish(p) }
            }
            .onEnded { _ in
                if y0 != nil && !fired {
                    let vel = velocity()
                    if maxPull > 0.04 && vel > 120 { finish(speedToPower(vel)) }
                    else { g.pull = 0; g.shownPower = nil; if maxPull > 0.04 { g.showToast("Kéo xuống rồi đẩy lên dứt khoát để đánh") } }
                }
                y0 = nil; pullNow = 0; samples = []
            })
        .accessibilityLabel("Lực đánh: kéo xuống rồi đẩy lên")
    }

    private func finish(_ p: Double) { g.pull = 0; pullNow = 0; g.shoot(p) }
}

/// Chế độ thanh lực + nút Đánh.
struct SliderPower: View {
    @ObservedObject var g: Game
    var body: some View {
        VStack(spacing: 8) {
            Slider(value: $g.lastPower, in: 0.02...1).frame(width: 150)
            Button { g.shoot(g.lastPower) } label: {
                Text("ĐÁNH").font(.system(size: 16, weight: .heavy)).frame(width: 110, height: 52)
                    .background(Capsule().fill(Color(hex: 0xf77f00))).foregroundColor(.white)
            }.disabled(!(g.phase == .aim || g.phase == .placing))
        }
    }
}

/// Bi nhỏ cho dải bi / sơ đồ.
struct MiniBall: View {
    let id: Int
    var gone = false
    var size: CGFloat = 20
    var body: some View {
        let col = Color(hex: BallColors.hex(id))
        ZStack {
            if id > 8 {
                Circle().fill(Color(hex: BallColors.ivory))
                Rectangle().fill(col).frame(height: size * 0.5).clipShape(Circle().scale(1))
                    .mask(Circle())
            } else { Circle().fill(col) }
            Circle().fill(Color(hex: BallColors.ivory)).frame(width: size * 0.56, height: size * 0.56)
            Text("\(id)").font(.system(size: size * 0.36, weight: .heavy)).foregroundColor(.black)
        }
        .frame(width: size, height: size)
        .opacity(gone ? 0.22 : 1)
    }
}
