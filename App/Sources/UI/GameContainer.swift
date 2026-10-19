import SwiftUI
import RealityKit
import Combine
import QuartzCore
import PoolPhysics

/// ARView (non-AR) + lớp cảm ứng. Mỗi khung hình đọc trạng thái bi từ GameModel.
struct GameContainer: UIViewRepresentable {
    let model: GameModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(UIColor(red: 0.09, green: 0.085, blue: 0.08, alpha: 1))
        arView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(arView)

        let touch = TouchSurface(frame: .zero)
        touch.model = model
        touch.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(touch)

        for v in [arView, touch] {
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                v.topAnchor.constraint(equalTo: container.topAnchor),
                v.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
        // Ánh sáng môi trường dựng sẵn: bi và gỗ phản chiếu phòng/đèn thay vì khoảng đen.
        if let image = TableDecor.environmentImage() {
            Task { @MainActor [weak arView] in
                guard let env = try? await EnvironmentResource(equirectangular: image, withName: nil) else { return }
                arView?.environment.lighting.resource = env
                arView?.environment.lighting.intensityExponent = 0.3
            }
        }
        context.coordinator.attach(arView)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        let model: GameModel
        private var scene: TableScene?
        private weak var arView: ARView?
        private var subscription: (any Cancellable)?
        private var drillId: String?? = .none

        init(model: GameModel) { self.model = model }

        func attach(_ view: ARView) {
            arView = view
            let s = TableScene(table: model.table)
            view.scene.addAnchor(s.root)
            scene = s
            subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                let dt = Float(event.deltaTime)
                MainActor.assumeIsolated { self?.tick(dt: dt) }
            }
        }

        func detach() {
            subscription?.cancel()
            subscription = nil
            model.audio.stop()
        }

        private func tick(dt: Float) {
            guard let scene, let arView else { return }
            if drillId != .some(model.drill?.id) {
                drillId = .some(model.drill?.id)
                scene.showMarkers(for: model.drill)
            }
            let balls = model.displayBalls(now: CACurrentMediaTime())
            scene.updateBalls(balls, dt: dt)
            let st = model.state
            // Cơ: ngắm → cách mặt bi 3,5 cm; đã khóa → theo ngón (kéo lùi/đẩy tới); vừa ra cơ → đi tiếp qua vị trí
            // bi trong 0,25 s rồi ẩn (cú đánh thật có follow-through, không dừng ở mặt bi).
            let since = model.playbackTime(now: CACurrentMediaTime())
            let follow = st == .shotRunning && since < 0.25
            let pull: Double = switch st {
            case .aiming: 0.035
            case .locked: 0.012 + model.cueDraw
            default: -0.08 * min(1, since / 0.12)
            }
            scene.updateCue(aim: model.aimAngle, tip: model.tip, elevation: model.elevation,
                            visible: st == .aiming || st == .locked || follow,
                            pullBack: Float(pull), follow: st == .aiming || st == .locked)
            let size = arView.bounds.size
            scene.setOverview(model.cameraMode == .overview)
            scene.updateCamera(mode: model.cameraMode, aim: model.aimAngle, eyeHeight: model.settings.eyeHeight,
                               aspect: Float(size.width / max(size.height, 1)),
                               follow: st != .shotRunning && st != .reviewing)
            AutoTest.recordFrame(dt: dt, balls: balls.filter { $0.state != .pocketed }.count,
                                 camera: scene.camera.position(relativeTo: nil))
        }
    }
}
