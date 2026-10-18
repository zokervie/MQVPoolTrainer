import SwiftUI
import SceneKit
import UIKit

/// SCNView + cử chỉ trên bàn: kéo để ngắm (2D: cơ chỉ tới ngón tay; 3D: kéo ngang xoay, kéo dọc đổi độ cao camera),
/// hai ngón để phóng to, kéo bi cái khi có bi trong tay. Khi khoá cơ, kéo chỉ xoay camera để quan sát.
struct TableView: UIViewRepresentable {
    let g: Game

    func makeCoordinator() -> Coordinator { Coordinator(g) }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(frame: .zero)
        v.scene = g.scene.scene
        v.antialiasingMode = .multisampling4X
        v.preferredFramesPerSecond = 60
        v.rendersContinuously = true
        v.backgroundColor = .black
        v.isJitteringEnabled = false
        g.scene.view = v
        g.scene.setMode3D(g.settings.view3D)
        let c = context.coordinator
        c.view = v
        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.pinch(_:)))
        pan.delegate = c; pinch.delegate = c
        v.addGestureRecognizer(pan)
        v.addGestureRecognizer(pinch)
        let tap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.tap(_:)))
        v.addGestureRecognizer(tap)
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        DispatchQueue.main.async { g.scene.updateOrtho() }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let g: Game
        weak var view: SCNView?
        private enum Mode { case drag, place }
        private var mode: Mode = .drag
        private var dir0 = 0.0, pitch0 = 0.0, yaw0 = 0.0
        private var dist0 = 1.0, zoom0 = 1.0

        init(_ g: Game) { self.g = g }

        func gestureRecognizer(_ a: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith b: UIGestureRecognizer) -> Bool { false }

        private var canAim: Bool { !g.locked && (g.phase == .aim || g.phase == .placing) }

        @objc func pan(_ r: UIPanGestureRecognizer) {
            guard g.phase != .menu, let v = view else { return }
            let sc = g.scene
            let loc = r.location(in: v)
            switch r.state {
            case .began:
                let start = CGPoint(x: loc.x - r.translation(in: v).x, y: loc.y - r.translation(in: v).y)
                if g.ballInHand, (g.phase == .aim || g.phase == .placing), let cb = g.cueBall, let p = sc.pick(start), p.dist(cb.pos) < 0.09 {
                    mode = .place; g.phase = .placing; return
                }
                mode = .drag
                dir0 = g.dir; pitch0 = sc.cam.pitch; yaw0 = g.camYawOffset
                if !sc.is3D, canAim { aimAt(loc) }
            case .changed:
                if mode == .place { if let p = sc.pick(loc) { g.placeCue(p) }; return }
                let t = r.translation(in: v)
                if !sc.is3D {
                    if canAim { aimAt(loc) }
                } else {
                    let sens = 0.0042 * g.settings.sens * (0.6 + 0.4 * sc.cam.dist)
                    if canAim { g.dir = dir0 + Double(t.x) * sens }
                    else if g.phase != .rolling { g.camLookAround = true; g.camYawOffset = yaw0 + Double(t.x) * 0.006; sc.cam.yaw = g.dir + g.camYawOffset }
                    sc.cam.pitch = min(1.45, max(0.06, pitch0 + Double(t.y) * 0.004))
                }
            default:
                if mode == .place { g.phase = .placing; g.markPreviewDirty() }
                mode = .drag
            }
        }

        private func aimAt(_ pt: CGPoint) {
            guard let cb = g.cueBall, let p = g.scene.pick(pt) else { return }
            if p.dist(cb.pos) > 0.01 { g.dir = atan2(p.z - cb.z, p.x - cb.x) }
        }

        @objc func pinch(_ r: UIPinchGestureRecognizer) {
            guard g.phase != .menu else { return }
            let sc = g.scene
            if r.state == .began { dist0 = sc.cam.dist; zoom0 = sc.cam.orthoZoom }
            let k = Double(r.scale)
            if sc.is3D { sc.cam.dist = min(3.4, max(0.3, dist0 / k)) }
            else { sc.cam.orthoZoom = min(4, max(1, zoom0 * k)); sc.updateOrtho() }
        }

        @objc func tap(_ r: UITapGestureRecognizer) {
            guard let v = view, !g.scene.is3D, canAim else { return }
            aimAt(r.location(in: v))
        }
    }
}
