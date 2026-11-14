import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        L10n.install()   // 0.42: seven languages, English by default (UI/L10n042.swift)
        let window = UIWindow(frame: UIScreen.main.bounds)
        let tokens=NSDataAsset(name:"PC_Tokens").flatMap{try? JSONSerialization.jsonObject(with:$0.data) as? [String:Any]}
        let gold=(tokens?["gold"] as? String).flatMap{UInt32($0.replacingOccurrences(of:"#",with:""),radix:16)} ?? 0xEAC583
        window.tintColor = UIColor.rgb(gold)
        window.rootViewController = TrainingController()
        window.makeKeyAndVisible()
        self.window = window
        IntroOverlay.present(in: window)   // 0.43: "The Golden Break" (full once, then a 1 s sting; tap to skip)
        return true
    }
}
