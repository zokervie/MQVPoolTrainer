import UIKit

/// 0.51 N1 — "Thế bí của ngày": everyone gets the same puzzle on the same local date (BLDailyPuzzle), at most 6 tries, no hints, locked
/// after a solve or the 6th try until tomorrow. Each try is graded ⚪ far · 🟡 near · 🟢 solved (BLDailyGrade) and shown as a row of dots;
/// the share text (BLDailyShareText) and the 1080×1350 card never show the layout. Core: PuzzleDaily.h.
enum DailyPuzzle {
    /// QA: `--daily-day-qa=<n>` moves "today" n days ahead (tests set the date; the epoch of puzzle #1 is a release-day constant).
    static var dayOffset: Int {
        for a in QA.arguments where a.hasPrefix("--daily-day-qa=") { return Int(a.dropFirst("--daily-day-qa=".count)) ?? 0 }
        return 0
    }
    static func now() -> Date { Date().addingTimeInterval(Double(dayOffset) * 86400) }
    static func today(_ s: PlayerStore = .shared) -> Int64 { s.day(now()) }
    static func puzzle(day: Int64) -> (index: Int, mirrored: Bool)? {
        var mirrored: Int32 = 0
        let i = BLDailyPuzzle(day, &mirrored)
        return i >= 0 ? (Int(i), mirrored != 0) : nil
    }
    static func dots(_ grades: [Int]) -> String { grades.map { ["⚪", "🟡", "🟢"][max(0, min(2, $0))] }.joined() }
    /// "Zoker #128 · 3/6\n⚪🟡🟢\n🔥 12" (BLDailyShareText: no spoiler).
    static func shareText(day: Int64, state: DailyPuzzleState, streak: Int) -> String {
        guard !state.grades.isEmpty else { return "" }
        var buf = [CChar](repeating: 0, count: 256)
        let grades = state.grades.map { Int32($0) }
        let n = BLDailyShareText(&buf, 256, BLDailyNumber(day), grades, Int32(grades.count), Int32(streak))
        return n > 0 ? String(cString: buf) : ""
    }
    /// "In tờ thế bí": an A5 PDF for a pool hall wall — logo word, "Thế bí của ngày", the number, a QR code that opens the app on today's puzzle
    /// (`zokerpool://daily`). The layout is not drawn.
    static func flyerPDF(day: Int64) -> Data {
        let page = CGRect(x: 0, y: 0, width: 419.5, height: 595.3)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            ctx.beginPage()
            UIColor(red: 0.06, green: 0.04, blue: 0.03, alpha: 1).setFill(); ctx.fill(page)
            func draw(_ text: String, _ font: UIFont, _ color: UIColor, y: CGFloat) {
                let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]; let w = (text as NSString).size(withAttributes: a).width
                (text as NSString).draw(at: CGPoint(x: (page.width - w) / 2, y: y), withAttributes: a)
            }
            draw("ZOKER POOL", Wood.titleFont(46), ZDesign.Color.gold, y: 40)
            draw(L10n.tr("Thế bí của ngày"), .systemFont(ofSize: 26, weight: .bold), .white, y: 130)
            draw("#\(BLDailyNumber(day))", .systemFont(ofSize: 44, weight: .heavy), ZDesign.Color.gold, y: 175)
            let filter = CIFilter(name: "CIQRCodeGenerator"); filter?.setValue(Data("zokerpool://daily".utf8), forKey: "inputMessage"); filter?.setValue("M", forKey: "inputCorrectionLevel")
            if let out = filter?.outputImage {
                let scaled = out.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
                let ci = CIContext(); if let cg = ci.createCGImage(scaled, from: scaled.extent) {
                    let size: CGFloat = 220, rect = CGRect(x: (page.width - size) / 2, y: 260, width: size, height: size)
                    UIColor.white.setFill(); ctx.fill(rect.insetBy(dx: -12, dy: -12))
                    UIImage(cgImage: cg).draw(in: rect)
                }
            }
            draw(L10n.tr("Quét mã để chơi thế bí hôm nay"), .systemFont(ofSize: 15, weight: .medium), UIColor(white: 0.85, alpha: 1), y: 520)
        }
    }
    /// The share picture, 1080 × 1350: logo word, number, the dots as coloured circles, the streak. The layout is NOT drawn.
    static func cardImage(day: Int64, state: DailyPuzzleState, streak: Int) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [UIColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 1).cgColor, UIColor(red: 0.10, green: 0.07, blue: 0.04, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) { c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: []) }
            func draw(_ text: String, _ font: UIFont, _ color: UIColor, y: CGFloat) {
                let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]; let w = (text as NSString).size(withAttributes: a).width
                (text as NSString).draw(at: CGPoint(x: (size.width - w) / 2, y: y), withAttributes: a)
            }
            draw("ZOKER POOL", Wood.titleFont(120), ZDesign.Color.gold, y: 150)
            let solved = state.solved
            draw("Zoker #\(BLDailyNumber(day))", .systemFont(ofSize: 84, weight: .heavy), .white, y: 420)
            draw(solved ? "\(state.grades.count)/\(DailyPuzzleState.maxTries)" : "X/\(DailyPuzzleState.maxTries)", .systemFont(ofSize: 150, weight: .heavy), solved ? .systemGreen : .systemOrange, y: 540)
            let r: CGFloat = 52, gap: CGFloat = 24, total = CGFloat(state.grades.count) * (2 * r) + CGFloat(max(0, state.grades.count - 1)) * gap
            var x = (size.width - total) / 2 + r
            for g in state.grades {
                let col = [UIColor(white: 0.85, alpha: 1), UIColor.systemYellow, UIColor.systemGreen][max(0, min(2, g))]
                col.setFill(); c.fillEllipse(in: CGRect(x: x - r, y: 800 - r, width: 2 * r, height: 2 * r)); x += 2 * r + gap
            }
            if streak >= 2 { draw("🔥 \(streak)", .systemFont(ofSize: 90, weight: .bold), .white, y: 940) }
            draw("zokerpool", .systemFont(ofSize: 44, weight: .medium), UIColor(white: 0.6, alpha: 1), y: 1230)
        }
    }
}

extension TrainingController {
    /// Sảnh › Bài tập › "Thế bí của ngày".
    func openDailyPuzzle() {
        guard !shotActive, replayIndex == nil else { return }
        let day = DailyPuzzle.today(), state = PlayerStore.shared.dailyState(day)
        guard let p = DailyPuzzle.puzzle(day: day) else { return }
        if state.locked { showDailyResult(day: day); return }
        beginPuzzle(p.index, mirrored: p.mirrored, daily: day)
    }
    /// After each try of the daily puzzle: grade it (⚪ 🟡 🟢), keep it, lock + show the result when it ends.
    func dailyShotFinished(_ session: PuzzleSession, day: Int64, d: Drill, passed: Bool, events: [[String: NSNumber]]) {
        guard var spec = d.spec else { return }
        let kinds = events.map { Int32($0["kind"]?.intValue ?? 0) }, a = events.map { Int32($0["a"]?.intValue ?? 0) }, b = events.map { Int32($0["b"]?.intValue ?? 0) }
        let contact = BLDrillFirstContact(Int32(events.count), kinds, a, b)
        let state = balls
        let ids = state.map { Int32($0.id) }, xs = state.map { $0.x }, ys = state.map { $0.y }, sunk = state.map { Int32($0.sunk ? 1 : 0) }
        var miss = BLPuzzleMissMetres(&spec, Int32(state.count), ids, xs, ys, sunk)
        if miss < 0, spec.kind == Int32(BL_DRILL_REACH), let ball1 = d.balls.first(where: { $0.id == 1 }), let path = paths[0], !path.isEmpty {
            // REACH: the cue ball's closest approach to ball 1, minus two radii (from the shot's samples)
            let closest = path.reduce(Double.infinity) { min($0, hypot(Double($1.x) - ball1.x, Double($1.z) - ball1.y)) }
            miss = max(0, closest - 2 * BL_DRILL_RADIUS)
        }
        let grade = Int(BLDailyGrade(passed ? 1 : 0, contact, miss))
        let after = PlayerStore.shared.recordDailyTry(day: day, grade: grade)
        statusLabel.text = "\(L10n.tr("Thế bí của ngày")) · \(after.grades.count)/\(DailyPuzzleState.maxTries) · " + DailyPuzzle.dots(after.grades)
        notifyStatus(statusLabel.text ?? "")
        syncPuzzleBar()
        if after.locked {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.showDailyResult(day: day) }
        } else if QA.has("--daily-autoretry-qa") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.retryPuzzle() }
        }
    }
    func showDailyResult(day: Int64) {
        let state = PlayerStore.shared.dailyState(day)
        let streak = Int(PlayerStore.shared.streakShown(at: DailyPuzzle.now()))
        let text = DailyPuzzle.shareText(day: day, state: state, streak: streak)
        dailyShareShown = text
        let title = L10n.tr("Thế bí của ngày") + " #\(BLDailyNumber(day))"
        let message = (state.solved ? L10n.tr("Giải được") + " " : L10n.tr("Hết cơ hôm nay") + " ") + "\n" + DailyPuzzle.dots(state.grades) + "\n" + L10n.tr("Mai có thế mới.")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.view.accessibilityIdentifier = "DailyResult"
        alert.addAction(UIAlertAction(title: L10n.tr("Khoe"), style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.dailyShareTaps += 1; PlayerStore.shared.noteDailyShare()
            let image = DailyPuzzle.cardImage(day: day, state: state, streak: streak)
            let share = UIActivityViewController(activityItems: [text, image], applicationActivities: nil)
            share.popoverPresentationController?.sourceView = self.view
            share.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
            self.topPresenter.present(share, animated: true)
        })
        if let p = DailyPuzzle.puzzle(day: day) {
            alert.addAction(UIAlertAction(title: L10n.tr("Luyện thế này"), style: .default) { [weak self] _ in self?.beginPuzzle(p.index, mirrored: p.mirrored) })
        }
        alert.addAction(UIAlertAction(title: L10n.tr("In tờ thế bí"), style: .default) { [weak self] _ in
            guard let self = self else { return }
            let data = DailyPuzzle.flyerPDF(day: day)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("zoker-the-bi-\(BLDailyNumber(day)).pdf")
            try? data.write(to: url); self.flyerBytes = data.count
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            share.popoverPresentationController?.sourceView = self.view
            share.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
            self.topPresenter.present(share, animated: true)
        })
        alert.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel))
        topPresenter.present(alert, animated: true)
    }
}
