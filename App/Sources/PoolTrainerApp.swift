import SwiftUI

@main
struct PoolTrainerApp: App {
    @State private var settings: AppSettings
    @State private var model: GameModel
    @State private var playing = false

    init() {
        let s = AppSettings()
        _settings = State(initialValue: s)
        _model = State(initialValue: GameModel(settings: s, history: HistoryStore(), tables: TableStore()))
    }

    var body: some Scene {
        WindowGroup {
            HomeView(model: model) { playing = true }
                .fullScreenCover(isPresented: $playing) {
                    GameScreen(model: model) { playing = false }
                }
                .task {
                    // Chỉ chạy khi có tham số -autotest (CI chụp màn hình).
                    await AutoTest.run(model: model) { playing = $0 }
                }
        }
    }
}
