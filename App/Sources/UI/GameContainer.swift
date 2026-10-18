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
        arView.environment.background = .color(UIColor(white: 0.04, alpha: 1))
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
            scene.updateCue(aim: model.aimAngle, tip: model.tip,
                            visible: st == .aiming || st == .locked,
                            pullBack: st == .locked ? 0.02 : 0.06)
            let size = arView.bounds.size
            scene.updateCamera(mode: model.cameraMode, aim: model.aimAngle, eyeHeight: model.settings.eyeHeight,
                               aspect: Float(size.width / max(size.height, 1)))
        }
    }
}
