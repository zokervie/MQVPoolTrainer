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

                HUD(model: model, onExit: onExit)
                    .padding(.leading, insets.left + 12)
                    .padding(.top, insets.top + 10)

                if !model.settings.seenLockHint && model.state == .aiming {
                    LockHint()
                        .position(x: model.settings.leftHanded ? full.width - insets.right - 120 : insets.left + 120,
                                  y: full.height - insets.bottom - 70)
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

/// Bi chỉnh effect: mờ và nhỏ khi không chạm; phóng to, nổi khối khi chạm. Chấm đỏ là điểm chạm.
struct EffectBall: View {
    var tip: SIMD2<Double>
    var expanded: Bool

    var body: some View {
        let r = expanded ? EffectBallLayout.expandedRadius : EffectBallLayout.compactRadius
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white, Color(white: 0.78)], center: UnitPoint(x: 0.35, y: 0.3),
                                     startRadius: 1, endRadius: r * 1.4))
                .shadow(color: .black.opacity(expanded ? 0.5 : 0), radius: 8, y: 4)
            Circle()
                .stroke(Color.red.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: r * 2 * CueSpec().miscueLimit, height: r * 2 * CueSpec().miscueLimit)
                .opacity(expanded ? 1 : 0)
            Circle()
                .fill(Color.red)
                .frame(width: expanded ? 12 : 6, height: expanded ? 12 : 6)
                .offset(x: CGFloat(tip.x) * r, y: -CGFloat(tip.y) * r)
        }
        .frame(width: r * 2, height: r * 2)
        .opacity(expanded ? 1 : 0.35)
        .animation(.easeOut(duration: 0.15), value: expanded)
    }
}

private struct LockHint: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "hand.tap")
            Text("Chạm nhanh vào góc này để khóa hướng ngắm")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(width: 200)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(.white)
    }
}

/// Biểu tượng nhỏ góc trên: thoát, đổi camera, Shot Lab, đặt lại.
private struct HUD: View {
    @Bindable var model: GameModel
    var onExit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            icon("chevron.backward") { onExit() }
            icon(model.cameraMode == .firstPerson ? "eye" : "square.grid.3x3") {
                model.cameraMode = model.cameraMode == .firstPerson ? .overview : .firstPerson
            }
            icon("slider.horizontal.3", active: model.shotLabOpen) { model.shotLabOpen.toggle() }
            icon("arrow.counterclockwise") { model.resetLayout() }
            if model.state == .locked {
                Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.7)).font(.caption)
            }
        }
    }

    private func icon(_ name: String, active: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(.black.opacity(active ? 0.7 : 0.35), in: Circle())
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
