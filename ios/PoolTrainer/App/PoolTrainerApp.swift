import SwiftUI

@main
struct PoolTrainerApp: App {
    @StateObject private var g = Game()
    var body: some Scene {
        WindowGroup {
            RootView(g: g)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct RootView: View {
    @ObservedObject var g: Game
    var body: some View {
        ZStack {
            TableView(g: g).ignoresSafeArea()
            if g.phase == .menu { MenuView(g: g).transition(.opacity) }
            else { HUDView(g: g) }
        }
        .background(Color.black)
        .animation(.easeInOut(duration: 0.25), value: g.phase == .menu)
        .fullScreenCover(item: $g.card) { c in
            switch c {
            case .drill(let d, let inGame): DrillCardView(g: g, drill: d, inGame: inGame)
            case .finished(let t, let l, let s, let a): FinishedCard(g: g, title: t, lead: l, stats: s, again: a)
            case .settings: SettingsView(g: g)
            case .help: HelpView(g: g)
            case .sources: SourcesView(g: g)
            }
        }
    }
}
