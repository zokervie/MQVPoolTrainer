import UIKit
import SwiftUI
import Charts

/// 0.47 M3 — màn "Tiến bộ" (Swift Charts): made-rate per local day over 7 / 30 days, the weekly test without help
/// (the "real progress" line, M5), streak, rounds. Data: PlayerStore (read only). QA photo: --progress-demo-qa.
struct ProgressDay: Identifiable { let id: Int64; let date: Date; let attempts: Int; let made: Int; let rounds: Int
    var rate: Double { attempts > 0 ? Double(made) / Double(attempts) * 100 : 0 } }
struct ProgressTest: Identifiable { let id: Int; let date: Date; let percent: Double }

struct ProgressView047: View {
    let store: PlayerStore
    var startWeekly: (() -> Void)?
    var close: () -> Void
    @State var span = 7

    private func date(_ day: Int64) -> Date {
        let tz = store.timeZone
        let utcMidnight = Date(timeIntervalSince1970: Double(day) * 86400)
        return utcMidnight.addingTimeInterval(-Double(tz.secondsFromGMT(for: utcMidnight)) + 43200)   // local noon of that day
    }
    private var days: [ProgressDay] { store.daily(days: span).map { ProgressDay(id: $0.day, date: date($0.day), attempts: $0.attempts, made: $0.made, rounds: $0.rounds) } }
    private var tests: [ProgressTest] {
        let first = store.day(Date()) - Int64(span) + 1
        return store.data.tests.enumerated().filter { $0.element.kind == "weekly" && $0.element.day >= first && $0.element.shots > 0 }
            .map { ProgressTest(id: $0.offset, date: date($0.element.day), percent: Double($0.element.made) / Double($0.element.shots) * 100) }
    }
    var body: some View {
        let d = days, played = d.filter { $0.attempts > 0 }
        let attempts = d.reduce(0) { $0 + $1.attempts }, made = d.reduce(0) { $0 + $1.made }, rounds = d.reduce(0) { $0 + $1.rounds }
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("", selection: $span) { Text(L10n.tr("7 ngày")).tag(7); Text(L10n.tr("30 ngày")).tag(30) }
                        .pickerStyle(.segmented).accessibilityIdentifier("ProgressSpan")
                    HStack(spacing: 10) {
                        stat("\(store.streakShown())", "ngày liên tiếp", "flame.fill", .orange)
                        stat("\(store.data.streak.best)", "chuỗi dài nhất", "trophy.fill", Color(ZDesign.Color.gold))
                        stat(attempts > 0 ? "\(made * 100 / attempts)%" : "–", "tỉ lệ vào", "scope", .green)
                        stat("\(rounds)", "lượt bài", "checklist", .blue)
                        stat("\(store.data.level)", "cấp độ", "chart.bar.fill", .purple)
                    }
                    Text(L10n.tr("Tỉ lệ vào theo ngày")).font(.headline).foregroundColor(.white)
                    Chart {
                        ForEach(played) { day in
                            BarMark(x: .value("Ngày", day.date, unit: .day), y: .value("Tỉ lệ vào", day.rate))
                                .foregroundStyle(Color.green.opacity(0.75))
                        }
                        ForEach(tests) { t in
                            PointMark(x: .value("Ngày", t.date, unit: .day), y: .value("Bài kiểm", t.percent))
                                .foregroundStyle(Color(ZDesign.Color.gold)).symbolSize(110)
                        }
                        if tests.count > 1 {
                            ForEach(tests) { t in LineMark(x: .value("Ngày", t.date, unit: .day), y: .value("Bài kiểm", t.percent)).foregroundStyle(Color(ZDesign.Color.gold)) }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 220)
                    .accessibilityIdentifier("ProgressChart")
                    HStack(spacing: 16) {
                        Label(L10n.tr("Tỉ lệ vào khi tập"), systemImage: "square.fill").foregroundColor(.green)
                        Label(L10n.tr("Bài kiểm tuần (tiến bộ thật)"), systemImage: "circle.fill").foregroundColor(Color(ZDesign.Color.gold))
                    }.font(.caption)
                    if let startWeekly = startWeekly {
                        let done = store.weeklyTestDone()
                        Button(action: startWeekly) {
                            Label(L10n.tr(done ? "Bài kiểm tuần: đã làm tuần này" : "Bài kiểm tuần · 10 cú không trợ giúp"), systemImage: "flag.checkered")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(Color(ZDesign.Color.gold)).foregroundColor(.black)
                        .disabled(done).accessibilityIdentifier("WeeklyTest")
                    }
                    let distinct = Set(store.data.rounds.filter { $0.day > store.day(Date()) - Int64(span) }.map { $0.drill }).count
                    Text(L10n.tr("Số bài khác nhau đã tập") + ": \(distinct) · " + L10n.tr("đóng băng chuỗi đã dùng") + ": \(store.data.streak.freezesUsed)")
                        .font(.footnote).foregroundColor(.gray)
                }
                .padding(16)
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea())
            .navigationTitle(L10n.tr("Tiến bộ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.tr("Xong"), action: close).accessibilityIdentifier("ProgressDone") } }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("Progress")
    }
    private func stat(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).foregroundColor(color)
            Text(verbatim: value).font(.title3.bold()).foregroundColor(.white).minimumScaleFactor(0.7).lineLimit(1)
            Text(L10n.tr(label)).font(.caption2).foregroundColor(.gray).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
        .accessibilityElement(children: .combine)
    }
}

extension TrainingController {
    func openProgress() {
        guard FeatureFlags.progress else { return }
        var host: UIHostingController<ProgressView047>?
        let weekly: (() -> Void)? = FeatureFlags.fadingFeedback ? { [weak self] in host?.dismiss(animated: true) { self?.startWeeklyTest() } } : nil
        let view = ProgressView047(store: .shared, startWeekly: weekly, close: { host?.dismiss(animated: true) }, span: QA.has("--progress-demo-qa") ? 30 : 7)
        host = UIHostingController(rootView: view)
        host?.modalPresentationStyle = .fullScreen
        if let h = host { topPresenter.present(h, animated: true) }
    }
    /// M5: the weekly test — 10 shots over today's drills (or the open ladder), no feedback until the end.
    func startWeeklyTest() {
        var pool = DailyDrills.today()
        if pool.isEmpty { pool = Chapters.all.flatMap { $0.drills }.filter { Chapters.playable($0) }.compactMap { Chapters.index(of: $0) } }
        guard !pool.isEmpty else { return }
        let drills = (0..<Int(BL_EXAM_SHOTS)).map { pool[$0 % pool.count] }
        startTestRun(TestRun(kind: "weekly", title: "Bài kiểm tuần", drills: drills, coachBefore: coaching))
    }
    /// M3 "Kỷ lục mới": ≤ 1,5 s, tap to skip; still (no zoom) with Reduce Motion.
    func showNewRecord(_ text: String) {
        let v = UIControl(frame: view.bounds); v.autoresizingMask = [.flexibleWidth, .flexibleHeight]; v.accessibilityIdentifier = "NewRecord"
        v.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        let l = UILabel(); l.numberOfLines = 0; l.textAlignment = .center
        l.attributedText = {
            let t = NSMutableAttributedString(string: L10n.tr("Kỷ lục mới!") + "\n", attributes: [.font: UIFont.systemFont(ofSize: 40, weight: .black), .foregroundColor: ZDesign.Color.gold])
            t.append(NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor.white]))
            return t }()
        l.layer.shadowColor = UIColor.black.cgColor; l.layer.shadowOpacity = 0.8; l.layer.shadowRadius = 8; l.layer.shadowOffset = .zero
        l.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(l)
        NSLayoutConstraint.activate([l.centerXAnchor.constraint(equalTo: v.centerXAnchor), l.centerYAnchor.constraint(equalTo: v.centerYAnchor),
                                     l.widthAnchor.constraint(lessThanOrEqualTo: v.widthAnchor, constant: -40)])
        view.addSubview(v)
        let gone = { [weak v] in UIView.animate(withDuration: 0.15, animations: { v?.alpha = 0 }) { _ in v?.removeFromSuperview() } }
        v.addAction(UIAction { _ in gone() }, for: .touchUpInside)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if !UIAccessibility.isReduceMotionEnabled {
            l.transform = CGAffineTransform(scaleX: 0.6, y: 0.6); l.alpha = 0
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: { l.transform = .identity; l.alpha = 1 })
        }
        UIAccessibility.post(notification: .announcement, argument: L10n.tr("Kỷ lục mới!") + " " + text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) { gone() }
    }
}
