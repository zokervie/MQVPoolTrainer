import UIKit
import WebKit

/// Offline research workspace. It never changes BLWorld or the saved training profile.
final class ZupeLabController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private var web: WKWebView!
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ZUPE 2.0 · Thử nghiệm"
        view.backgroundColor = .black
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Xong", style: .done, target: self, action: #selector(close))
        let content = WKUserContentController()
        content.add(self, name: "zupeExport")
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.isOpaque = false
        web.backgroundColor = .black
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "ZupeLab") else {
            let label = UILabel(frame: view.bounds)
            label.text = "Thiếu tài nguyên ZUPE Lab. Kiểm tra Resources trong Xcode."
            label.textColor = .white; label.numberOfLines = 0; label.textAlignment = .center
            view.addSubview(label)
            return
        }
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    @objc private func close() {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "zupeExport")
        web.stopLoading()
        dismiss(animated: true)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        decisionHandler(url.isFileURL || url.absoluteString == "about:blank" ? .allow : .cancel)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "zupeExport", let body = message.body as? [String: String],
              let text = body["text"], text.utf8.count <= 8_000_000,
              let name = body["name"], ["ZUPE-trajectory.json", "ZUPE-calibration.json"].contains(name),
              let bytes = text.data(using: .utf8), (try? JSONSerialization.jsonObject(with: bytes)) != nil else { return }
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let url = directory.appendingPathComponent(name)
            try bytes.write(to: url, options: .atomic)
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            share.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
            present(share, animated: true)
        } catch {
            let alert = UIAlertController(title: "Không thể xuất tệp", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .default))
            present(alert, animated: true)
        }
    }
}
