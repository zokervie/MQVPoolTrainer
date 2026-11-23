import UIKit

/// 0.58 L3 — the UIKit side of PushedChrome: a labelled "Đóng" (pops one screen) next to the chevron, readable on the dark bar, and the edge swipe kept.
extension UIViewController {
    func addPushedClose() {
        let c = PushedChrome.buttonText
        let color = UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
        let item = UIBarButtonItem(title: L10n.tr(PushedChrome.closeTitleKey), style: .plain, target: self, action: #selector(popPushedScreen058))
        item.tintColor = color; item.accessibilityIdentifier = "PushedClose"
        item.setTitleTextAttributes([.foregroundColor: color, .font: UIFont.systemFont(ofSize: 17, weight: .semibold)], for: .normal)
        navigationItem.leftBarButtonItem = item
        navigationItem.leftItemsSupplementBackButton = true
        navigationController?.navigationBar.tintColor = color
    }
    @objc func popPushedScreen058() {
        if let nav = navigationController, nav.viewControllers.count > 1 { nav.popViewController(animated: true) } else { dismiss(animated: true) }
    }
}
