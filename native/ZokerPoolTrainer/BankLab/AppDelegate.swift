import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // QA: simulate a fresh install's language (no saved choice) for the first-launch language UI test.
        if ProcessInfo.processInfo.arguments.contains("--fresh-language") { UserDefaults.standard.removeObject(forKey: L10n.key) }
        L10n.install()   // 0.42: seven languages; 0.44.1: device language, else Vietnamese (UI/L10n042.swift)
        let window = UIWindow(frame: UIScreen.main.bounds)
        let tokens=NSDataAsset(name:"PC_Tokens").flatMap{try? JSONSerialization.jsonObject(with:$0.data) as? [String:Any]}
        let gold=(tokens?["gold"] as? String).flatMap{UInt32($0.replacingOccurrences(of:"#",with:""),radix:16)} ?? 0xEAC583
        window.tintColor = UIColor.rgb(gold)
        window.rootViewController = TrainingController()
        window.makeKeyAndVisible()
        self.window = window
        // 0.44.1 M5 investigation only: --old-intro-qa replays the 0.43/0.44 window overlay to find why it was black.
        if ProcessInfo.processInfo.arguments.contains("--old-intro-qa") { IntroOverlay.present(in: window) }
        // 0.44.1 M5: the intro now runs inside TrainingController on the play table (Intro0441.swift), before the Lobby.
        return true
    }
}
