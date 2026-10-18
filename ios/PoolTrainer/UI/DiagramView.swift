import SwiftUI

/// Sơ đồ bài tập: bàn, nút đánh số, bi, vùng đích, đường hệ thống và đường đi THỰC TẾ từ mô phỏng cú mẫu.
struct DiagramView: View {
    let stage: Stage
    var labels: LabelKind = .std
    var demo: DemoResult? = nil

    private let CB = 0.05, RW = 0.115
    private var BR: Double { R * 1.45 }   // vẽ bi to hơn thực tế để dễ đọc

    var body: some View {
        Canvas { ctx, size in
            let OX = TL / 2 + CB + RW, OZ = TW / 2 + CB + RW
            let s = min(Double(size.width) / (2 * OX + 0.04), Double(size.height) / (2 * OZ + 0.04))
            let cx = Double(size.width) / 2, cz = Double(size.height) / 2
            func P(_ p: P2) -> CGPoint { CGPoint(x: cx + p.x * s, y: cz + p.z * s) }
            func rect(_ x0: Double, _ z0: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: cx + x0 * s, y: cz + z0 * s, width: w * s, height: h * s) }
            func circle(_ p: P2, _ r: Double) -> Path { Path(ellipseIn: CGRect(x: cx + (p.x - r) * s, y: cz + (p.z - r) * s, width: 2 * r * s, height: 2 * r * s)) }

            ctx.fill(Path(roundedRect: rect(-OX, -OZ, 2 * OX, 2 * OZ), cornerRadius: 0.04 * s), with: .color(Color(hex: 0x5c3a22)))
            ctx.fill(Path(rect(-TL / 2 - CB, -TW / 2 - CB, TL + 2 * CB, TW + 2 * CB)), with: .color(Color(hex: 0x174a80)))
            ctx.fill(Path(rect(-TL / 2, -TW / 2, TL, TW)), with: .radialGradient(Gradient(colors: [Color(hex: 0x2a6db3), Color(hex: 0x1a4f86)]),
                                                                              center: CGPoint(x: cx, y: cz * 0.9), startRadius: 0, endRadius: TL * s * 0.6))
            for p in POCKETS { ctx.fill(circle(p.p, p.r), with: .color(Color(hex: 0x0c0c0d))) }
            // nút
            func dm(_ p: P2) {
                var path = Path(); let c = P(p), w = 0.007 * s, h = 0.011 * s
                path.move(to: CGPoint(x: c.x, y: c.y - h)); path.addLine(to: CGPoint(x: c.x + w, y: c.y))
                path.addLine(to: CGPoint(x: c.x, y: c.y + h)); path.addLine(to: CGPoint(x: c.x - w, y: c.y)); path.closeSubpath()
                ctx.fill(path, with: .color(Color(hex: 0xe9dcc0)))
            }
            for i in 1..<8 where i != 4 { dm(railPoint(Double(i), 0)); dm(railPoint(Double(i), 4)) }
            for j in 1..<4 { dm(railPoint(0, Double(j))); dm(railPoint(8, Double(j))) }
            // số nút
            for lb in systemLabels(labels) {
                var p = lb.p; let o = 0.05
                switch lb.side { case .top: p.z -= o; case .bottom: p.z += o; case .left: p.x -= o; case .right: p.x += o; case .bottom2: p.z -= 0.13 }
                let fs = (lb.side == .bottom2 ? 0.040 : 0.048) * s
                ctx.draw(Text(lb.text).font(.system(size: fs, weight: .bold)).foregroundColor(Color(hex: lb.color)), at: P(p))
            }
            // vùng đích
            if let z = stage.goal.cueZone {
                let c = circle(z.c, z.r)
                ctx.fill(c, with: .color(Color(hex: 0xffd166, alpha: 0.18)))
                ctx.stroke(c, with: .color(Color(hex: 0xffd166)), style: StrokeStyle(lineWidth: 0.005 * s, dash: [0.018 * s, 0.012 * s]))
            }
            // đường hệ thống
            if let h = demo?.hint {
                for (a, b, kind) in h.lines where kind == .sys {
                    var path = Path(); path.move(to: P(a)); path.addLine(to: P(b))
                    ctx.stroke(path, with: .color(Color(hex: 0xff9f1c)), style: StrokeStyle(lineWidth: 0.005 * s, dash: [0.02 * s, 0.014 * s]))
                }
                for m in h.marks {
                    if m.kind == .image { ctx.stroke(circle(m.p, BR), with: .color(Color(hex: 0xff9f1c)), style: StrokeStyle(lineWidth: 0.005 * s, dash: [0.01 * s, 0.008 * s])) }
                    if let label = m.label {
                        let lp = P2(max(-TL / 2 + 0.12, min(TL / 2 - 0.12, m.p.x)), max(-TW / 2 + 0.07, min(TW / 2 - 0.07, m.p.z)))
                        ctx.draw(Text(label).font(.system(size: 0.044 * s, weight: .heavy)).foregroundColor(Color(hex: 0xffbf69)), at: P(lp))
                    }
                }
            }
            // đường đi mô phỏng
            if let tr = demo?.traces {
                for (id, pts) in tr.sorted(by: { $0.key < $1.key }) where pts.count >= 2 {
                    var path = Path(); path.move(to: P(pts[0])); for q in pts.dropFirst() { path.addLine(to: P(q)) }
                    let col = id == 0 ? Color.white : Color(hex: 0xffd166)
                    ctx.stroke(path, with: .color(col.opacity(0.92)), style: StrokeStyle(lineWidth: 0.006 * s, lineJoin: .round, dash: id == 0 ? [0.016 * s, 0.01 * s] : []))
                    // mũi tên
                    let a = pts[pts.count - 2], b = pts[pts.count - 1]
                    let ang = atan2(b.z - a.z, b.x - a.x), L = 0.035
                    var head = Path(); head.move(to: P(b))
                    head.addLine(to: P(P2(b.x - L * cos(ang - 0.45), b.z - L * sin(ang - 0.45))))
                    head.addLine(to: P(P2(b.x - L * cos(ang + 0.45), b.z - L * sin(ang + 0.45)))); head.closeSubpath()
                    if a.dist(b) > 1e-4 { ctx.fill(head, with: .color(col)) }
                }
            }
            // bi
            func ball(_ id: Int, _ p: P2) {
                let c = circle(p, BR), col = Color(hex: BallColors.hex(id))
                ctx.fill(c, with: .color(id > 8 ? Color(hex: BallColors.ivory) : col))
                if id > 8 {
                    var cc = ctx; cc.clip(to: c)
                    cc.fill(Path(rect(p.x - BR, p.z - BR * 0.5, 2 * BR, BR)), with: .color(col))
                }
                ctx.stroke(c, with: .color(Color(hex: 0x0b1520)), lineWidth: 0.004 * s)
                if id != 0 {
                    ctx.fill(circle(p, BR * 0.55), with: .color(Color(hex: BallColors.ivory)))
                    ctx.draw(Text("\(id)").font(.system(size: (id > 9 ? 0.032 : 0.04) * s, weight: .heavy)).foregroundColor(.black), at: P(p))
                }
            }
            for b in stage.balls { ball(b.id, b.p) }
            if let c = stage.cue { ball(0, c) }
        }
        .aspectRatio(CGFloat((TL + 2 * (CB + RW) + 0.04) / (TW + 2 * (CB + RW) + 0.04)), contentMode: .fit)
    }
}
