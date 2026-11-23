import UIKit
import ObjectiveC

/// 0.53 stability probe (Debug only, `--layout-trace-qa`): records the call stack that dirties the layout of a few watched views while a shot runs,
/// so a stray mid-shot layout pass can be traced to its caller. Exposed through the scene probe as `layoutCause`. Release builds carry only the empty shell.
enum LayoutTrace {
    static var watched: [UIView] = []
    static var cause = ""
    static var armed = false
    static func install() {
        #if DEBUG
        guard !armed, let a = class_getInstanceMethod(UIView.self, #selector(UIView.setNeedsLayout)), let b = class_getInstanceMethod(UIView.self, #selector(UIView.zk_setNeedsLayout)) else { return }
        method_exchangeImplementations(a, b); armed = true
        #endif
    }
}
#if DEBUG
extension UIView {
    @objc func zk_setNeedsLayout() {
        if LayoutTrace.armed, LayoutTrace.cause.count < 1500, LayoutTrace.watched.contains(where: { $0 === self }) {
            let frames = Thread.callStackSymbols.dropFirst(2).prefix(14).map { s -> String in
                let parts = s.split(separator: " ", omittingEmptySubsequences: true); return parts.count > 3 ? String(parts[3]) : s }
            LayoutTrace.cause += "{" + String(describing: type(of: self)) + ":" + frames.joined(separator: "<") + "}"
        }
        zk_setNeedsLayout()   // the swizzled original
    }
}
#endif
