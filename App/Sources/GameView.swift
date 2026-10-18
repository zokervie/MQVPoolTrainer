import SwiftUI
import RealityKit
import PoolPhysics

/// Khung màn hình chơi (Giai đoạn 0). Chỉ dựng mặt bàn đúng kích thước để kiểm tra
/// màn hình ngang và RealityKit. Camera, bi, điều khiển làm ở Giai đoạn 3.
struct GameView: View {
    private let table = TableSpec.nineFoot

    var body: some View {
        RealityView { content in
            let cloth = ModelEntity(
                mesh: .generatePlane(width: Float(table.length), depth: Float(table.width)),
                materials: [SimpleMaterial(color: .init(red: 0.05, green: 0.35, blue: 0.2, alpha: 1),
                                           isMetallic: false)]
            )
            content.add(cloth)

            let light = DirectionalLight()
            light.look(at: .zero, from: [0, 2, 0.5], relativeTo: nil)
            content.add(light)

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 42
            camera.look(at: .zero, from: [0, 1.6, 1.8], relativeTo: nil)
            content.add(camera)
        }
        .background(Color.black)
    }
}
