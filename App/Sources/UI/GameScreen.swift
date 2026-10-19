import SwiftUI
import PoolPhysics
import PoolInput

/// Màn chơi: cảnh 3D toàn màn hình, không chữ khi đánh. Chỉ có biểu tượng nhỏ và bi effect mờ.
struct GameScreen: View {
    @Bindable var model: GameModel
    var onExit: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let insets = UIEdgeInsets(top: proxy.safeAreaInsets.top, left: proxy.safeAreaInsets.leading,
                                      bottom: proxy.safeAreaInsets.bottom, right: proxy.safeAreaInsets.trailing)
            let full = CGSize(width: proxy.size.width + insets.left + insets.right,
                              height: proxy.size.height + insets.top + insets.bottom)
            ZStack(alignment: .topLeading) {
                GameContainer(model: model)

                if model.state == .aiming {
                    EffectBall(tip: model.tip, expanded: model.effectExpanded)
                        .position(EffectBallLayout.center(size: full, insets: insets, mirrored: model.settings.leftHanded))
                        .allowsHitTesting(false)
                }

                // Một nút menu mờ duy nhất; ẩn khi đã khóa / đang chạy cú để không che bàn.
                if model.state == .aiming || model.state == .reviewing {
                    GameMenu(model: model, onExit: onExit)
                        .padding(.leading, model.settings.leftHanded ? 0 : insets.left + 10)
                        .padding(.top, insets.top + 8)
                        .frame(maxWidth: .infinity, alignment: model.settings.leftHanded ? .topTrailing : .topLeading)
                        .padding(.trailing, model.settings.leftHanded ? insets.right + 10 : 0)
                }

                // Hướng dẫn vùng khóa: vòng sáng nhấp nháy, không chữ; chỉ hiện tới lần khóa đầu tiên.
                if !model.settings.seenLockHint && model.state == .aiming {
                    LockPulse()
                        .position(x: full.width * (model.settings.leftHanded ? 0.845 : 0.155), y: full.height * 0.72)
                        .allowsHitTesting(false)
                }

                if model.state == .reviewing, let fb = model.feedback {
                    FeedbackPanel(model: model, feedback: fb)
                        .frame(maxWidth: 420)
                        .position(x: full.width / 2, y: full.height / 2)
                }

                if model.shotLabOpen && (model.state == .aiming || model.state == .locked) {
                    ShotLabPanel(model: model)
                        .frame(width: 300)
                        .position(x: model.settings.leftHanded ? full.width - insets.right - 170 : insets.left + 170,
                                  y: full.height / 2 + 20)
                }
            }
            .frame(width: full.width, height: full.height)
            .ignoresSafeArea()
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
    }
}

/// Bi chỉnh effect — vẽ như bi cái tập thật nhìn từ phía sau cơ:
/// bi ngà có khối, vạch chữ thập, vòng 1 và 2 đầu tẩy, vòng giới hạn trượt cơ (0,5R),
/// và dấu đầu tẩy màu phấn đúng tỉ lệ thật (đầu tẩy Ø13 mm trên bi Ø57,15 mm).
/// Thu nhỏ và mờ khi không chạm; phóng to khi chạm. Không có chữ hay số.
struct EffectBall: View {
    var tip: SIMD2<Double>
    var expanded: Bool

    /// Bán kính đầu tẩy / bán kính bi. Giả định đầu tẩy 13 mm (khoảng thường gặp 12,5–13,5 mm), bi 57,15 mm.
    static let tipRatio: CGFloat = 13.0 / 57.15
    /// "1 đầu tẩy" = lệch tâm một bán kính đầu tẩy; 2 đầu tẩy ≈ 0,45R, sát giới hạn trượt cơ 0,5R.

    var body: some View {
        let r = expanded ? EffectBallLayout.expandedRadius : EffectBallLayout.compactRadius
        let k = Self.tipRatio
        let limit = CGFloat(CueSpec().miscueLimit)
        let ink = Color(red: 0.25, green: 0.22, blue: 0.18)
        ZStack {
            // Bi ngà: sáng phía trên trái (đèn trần), tối dần ra mép.
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.99, blue: 0.95),
                                              Color(red: 0.93, green: 0.91, blue: 0.85),
                                              Color(red: 0.62, green: 0.60, blue: 0.55)],
                                     center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: r * 1.25))
                .shadow(color: .black.opacity(expanded ? 0.55 : 0.3), radius: expanded ? 10 : 3, y: expanded ? 5 : 1)

            if expanded {
                // Vạch chữ thập và vạch chia theo từng bán kính đầu tẩy.
                Path { p in
                    p.move(to: CGPoint(x: r, y: r * 0.06)); p.addLine(to: CGPoint(x: r, y: r * 1.94))
                    p.move(to: CGPoint(x: r * 0.06, y: r)); p.addLine(to: CGPoint(x: r * 1.94, y: r))
                    for i in [-2.0, -1.0, 1.0, 2.0] {
                        let d = CGFloat(i) * k * r
                        p.move(to: CGPoint(x: r + d, y: r - 4)); p.addLine(to: CGPoint(x: r + d, y: r + 4))
                        p.move(to: CGPoint(x: r - 4, y: r + d)); p.addLine(to: CGPoint(x: r + 4, y: r + d))
                    }
                }
                .stroke(ink.opacity(0.35), lineWidth: 1)
                .frame(width: r * 2, height: r * 2)
                // Vòng 1 và 2 đầu tẩy.
                ForEach([1.0, 2.0], id: \.self) { n in
                    Circle()
                        .stroke(ink.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .frame(width: 2 * CGFloat(n) * k * r, height: 2 * CGFloat(n) * k * r)
                }
                // Giới hạn trượt cơ.
                Circle()
                    .stroke(Color(red: 0.75, green: 0.15, blue: 0.12).opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    .frame(width: 2 * limit * r, height: 2 * limit * r)
            }

            // Dấu đầu tẩy đúng tỉ lệ, màu phấn xanh; chấm tâm = điểm chạm.
            ZStack {
                Circle().fill(Color(red: 0.18, green: 0.42, blue: 0.78).opacity(expanded ? 0.45 : 0.6))
                Circle().stroke(Color(red: 0.12, green: 0.30, blue: 0.62).opacity(0.9), lineWidth: expanded ? 1.5 : 1)
                Circle().fill(Color(red: 0.08, green: 0.2, blue: 0.45)).frame(width: expanded ? 4 : 2, height: expanded ? 4 : 2)
            }
            .frame(width: 2 * k * r, height: 2 * k * r)
            .offset(x: CGFloat(tip.x) * r, y: -CGFloat(tip.y) * r)
        }
        .frame(width: r * 2, height: r * 2)
        .opacity(expanded ? 1 : 0.6)
        .animation(.easeOut(duration: 0.15), value: expanded)
    }
}

/// Vòng sáng nhấp nháy đánh dấu vùng khóa ẩn (không chữ — docs/02-controls.md).
private struct LockPulse: View {
    @State private var on = false
    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.55), lineWidth: 2)
            .frame(width: 56, height: 56)
            .scaleEffect(on ? 1.25 : 0.8)
            .opacity(on ? 0.15 : 0.7)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// Một nút menu nhỏ, mờ: thoát, đổi góc nhìn, Shot Lab, đặt lại thế bi.
private struct GameMenu: View {
    @Bindable var model: GameModel
    var onExit: () -> Void

    var body: some View {
        Menu {
            Button { model.cameraMode = model.cameraMode == .firstPerson ? .overview : .firstPerson } label: {
                Label(model.cameraMode == .firstPerson ? "Nhìn từ trên" : "Góc cúi đánh",
                      systemImage: model.cameraMode == .firstPerson ? "square.grid.3x3" : "eye")
            }
            Button { model.shotLabOpen.toggle() } label: {
                Label(model.shotLabOpen ? "Đóng Shot Lab" : "Shot Lab", systemImage: "slider.horizontal.3")
            }
            Button { model.resetLayout() } label: { Label("Đặt lại thế bi", systemImage: "arrow.counterclockwise") }
            Divider()
            Button(role: .destructive) { onExit() } label: { Label("Thoát", systemImage: "chevron.backward") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.25), in: Circle())
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
