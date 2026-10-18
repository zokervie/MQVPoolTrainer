import SwiftUI

@main
struct PoolTrainerApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .persistentSystemOverlays(.hidden)
                .statusBarHidden()
        }
    }
}
