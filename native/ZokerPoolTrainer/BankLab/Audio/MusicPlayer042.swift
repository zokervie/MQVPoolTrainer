import AVFoundation
import UIKit
import UniformTypeIdentifiers

/// 0.42 (owner acceptance 0.41 item 11 + 13/11 17:54):
///  - The room owner imports songs from the Files app (copied into the app's Documents/Music) and plays them.
///  - Spectral ducking: when a ball sound plays, the music is cut only in the band that sound occupies (ball/cue
///    clicks ~2–6 kHz, pocket thump ~120–500 Hz) for ~0.3 s, so the impact is heard without the whole track dipping.
///  - Listening together ONLY on the same Wi-Fi (nearby room): the host streams PCM to the guest over the match link.
///    Never over the internet (owner: online sharing only later via paid streaming services where both have accounts).
final class MusicPlayer042 {
    static let shared = MusicPlayer042()
    private let engine = AVAudioEngine(), player = AVAudioPlayerNode(), eq = AVAudioUnitEQ(numberOfBands: 3)
    private var ready = false, file: AVAudioFile?
    private(set) var tracks: [URL] = []
    private(set) var index = 0
    private(set) var playing = false
    var volume: Float = UserDefaults.standard.object(forKey: "musicVolume042") as? Float ?? 0.6 {
        didSet { player.volume = volume; UserDefaults.standard.set(volume, forKey: "musicVolume042") }
    }
    /// Set by the match: sends one encoded chunk to the guest (nearby Wi-Fi only). nil = not sharing.
    var shareSink: ((Data) -> Void)?
    var onChange: (() -> Void)?
    private var shareTimer: Timer?, sharePosition: AVAudioFramePosition = 0, shareSeq: UInt32 = 0

    static var folder: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    init() { reload() }
    func reload() {
        let exts = Set(["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac"])
        tracks = ((try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { exts.contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        index = min(index, max(0, tracks.count - 1)); onChange?()
    }
    /// Copies picked files into the library (security-scoped URLs from the document picker). Returns how many.
    @discardableResult func importFiles(_ urls: [URL]) -> Int {
        var n = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let target = Self.folder.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: target)
            if (try? FileManager.default.copyItem(at: url, to: target)) != nil, (try? AVAudioFile(forReading: target)) != nil { n += 1 }
            else { try? FileManager.default.removeItem(at: target) }
        }
        reload(); return n
    }
    func delete(at i: Int) { guard tracks.indices.contains(i) else { return }; if i == index { stop() }; try? FileManager.default.removeItem(at: tracks[i]); reload() }
    var title: String { tracks.indices.contains(index) ? tracks[index].deletingPathExtension().lastPathComponent : "Chưa có bài" }

    private func setup() {
        guard !ready else { return }
        engine.attach(player); engine.attach(eq)
        let bands: [(Float, Float)] = [(3200, 1.1), (5600, 1.2), (260, 0.9)]
        for (k, b) in eq.bands.enumerated() { b.filterType = .parametric; b.frequency = bands[k].0; b.bandwidth = bands[k].1; b.gain = 0; b.bypass = false }
        engine.connect(player, to: eq, format: nil); engine.connect(eq, to: engine.mainMixerNode, format: nil)
        player.volume = volume; ready = true
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, self.playing else { return }
            if !self.engine.isRunning { try? self.engine.start(); self.player.play() }   // same lifecycle fix as PoolAudio
        }
    }
    func play(_ i: Int? = nil) {
        if let i = i { index = i }
        guard tracks.indices.contains(index), let f = try? AVAudioFile(forReading: tracks[index]) else { return }
        setup(); player.stop(); file = f
        if engine.isRunning == false {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            engine.prepare(); try? engine.start()
        }
        player.scheduleFile(f, at: nil) { [weak self] in DispatchQueue.main.async { if self?.playing == true && self?.file === f { self?.next() } } }
        player.play(); playing = true; sharePosition = 0; startSharingTimer(); onChange?()
    }
    func toggle() { if playing { pause() } else if file != nil, engine.isRunning { player.play(); playing = true; onChange?() } else { play() } }
    func pause() { player.pause(); playing = false; onChange?() }
    func stop() { player.stop(); playing = false; file = nil; shareTimer?.invalidate(); onChange?() }
    func next() { guard !tracks.isEmpty else { return }; play((index + 1) % tracks.count) }

    /// Spectral duck for one impact. kind: 0 rail, 1 ball, 2 pocket, 3 cue (PoolAudio kinds); impact 0…~8 m/s.
    func duck(kind: Int, impact: Double) {
        guard ready, playing else { return }
        let depth = Float(-6 - min(8, impact * 2.5))
        let band = kind == 2 ? 2 : (kind == 3 ? 0 : 1)
        let b = eq.bands[band]; b.gain = depth
        if band != 2 { eq.bands[band == 0 ? 1 : 0].gain = depth * 0.5 }
        let release = 0.32
        DispatchQueue.main.asyncAfter(deadline: .now() + release) { [weak self] in
            guard let self = self else { return }
            for step in 1...6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.03) { for b in self.eq.bands { b.gain *= 0.55 } ; if step == 6 { for b in self.eq.bands { b.gain = 0 } } }
            }
        }
    }

    // MARK: same-Wi-Fi listening (host → guest). Chunk = "ZMU1" | seq u32 | frames u32 | PCM s16 mono 22 050 Hz.
    static let magic = Data("ZMU1".utf8)
    private func startSharingTimer() {
        shareTimer?.invalidate()
        guard shareSink != nil else { return }
        shareTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.pushChunk() }
    }
    func setSharing(_ sink: ((Data) -> Void)?) { shareSink = sink; if playing { startSharingTimer() } else { shareTimer?.invalidate() } }
    private func pushChunk() {
        guard let sink = shareSink, playing, let url = tracks.indices.contains(index) ? tracks[index] : nil,
              let source = try? AVAudioFile(forReading: url) else { return }
        // read the matching 0.25 s from the file position the local player has reached (+0.3 s ahead for jitter)
        guard let nodeTime = player.lastRenderTime, let t = player.playerTime(forNodeTime: nodeTime) else { return }
        let rate = source.processingFormat.sampleRate
        let start = AVAudioFramePosition(Double(t.sampleTime) / t.sampleRate * rate + 0.3 * rate)
        if start < sharePosition { return }
        let frames = AVAudioFrameCount(0.25 * rate)
        guard start < source.length, let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: frames) else { return }
        source.framePosition = start
        guard (try? source.read(into: buffer, frameCount: frames)) != nil, let data = buffer.floatChannelData else { return }
        sharePosition = start + AVAudioFramePosition(buffer.frameLength)
        let channels = Int(source.processingFormat.channelCount), step = rate / 22_050
        let outFrames = Int(Double(buffer.frameLength) / step)
        var out = Self.magic; shareSeq &+= 1
        withUnsafeBytes(of: shareSeq.bigEndian) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(outFrames).bigEndian) { out.append(contentsOf: $0) }
        out.reserveCapacity(out.count + outFrames * 2)
        for i in 0..<outFrames {
            let src = min(Int(buffer.frameLength) - 1, Int(Double(i) * step))
            var v: Float = 0; for c in 0..<channels { v += data[c][src] }; v /= Float(channels)
            let s = Int16(max(-1, min(1, v)) * 32_000)
            withUnsafeBytes(of: s.bigEndian) { out.append(contentsOf: $0) }
        }
        sink(out)
    }
    // guest side
    private let remote = AVAudioPlayerNode(); private var remoteReady = false
    func receiveShared(_ data: Data) {
        guard data.count > 12, data.prefix(4) == Self.magic else { return }
        let frames = Int(data[8..<12].reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        guard frames > 0, data.count >= 12 + frames * 2,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 22_050, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { return }
        buffer.frameLength = AVAudioFrameCount(frames)
        let out = buffer.floatChannelData![0]
        data.withUnsafeBytes { raw in
            for i in 0..<frames { let hi = raw[12 + 2 * i], lo = raw[13 + 2 * i]; out[i] = Float(Int16(bitPattern: UInt16(hi) << 8 | UInt16(lo))) / 32_000 }
        }
        setup()
        if !remoteReady { engine.attach(remote); engine.connect(remote, to: eq, format: format); remoteReady = true }
        if !engine.isRunning { engine.prepare(); try? engine.start() }
        remote.volume = volume; remote.scheduleBuffer(buffer, completionHandler: nil)
        if !remote.isPlaying { remote.play() }
        playing = true
    }
}

/// Tuỳ chỉnh → Nhạc: list, import from Files, play/pause/next, volume, share on Wi-Fi.
final class MusicController: UITableViewController, UIDocumentPickerDelegate {
    private let music = MusicPlayer042.shared
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Nhạc của tôi"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Thêm bài", style: .plain, target: self, action: #selector(add))
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        music.onChange = { [weak self] in self?.tableView.reloadData() }
    }
    @objc private func close() { dismiss(animated: true) }
    @objc private func add() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio, UTType.mp3, UTType.mpeg4Audio, UTType.wav], asCopy: true)
        picker.allowsMultipleSelection = true; picker.delegate = self; present(picker, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let n = music.importFiles(urls)
        let a = UIAlertController(title: "Đã thêm \(n) bài", message: n < urls.count ? "Một số tệp không đọc được (định dạng không hỗ trợ hoặc có DRM)." : nil, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default)); present(a, animated: true)
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 3 : max(1, music.tracks.count) }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Đang phát: \(music.title)" : "Thư viện · nghe cùng đối thủ chỉ khi chơi cùng Wi-Fi"
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath); cell.accessoryView = nil; cell.accessoryType = .none
        var c = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0: c.text = music.playing ? "⏸ Tạm dừng" : "▶︎ Phát"
            case 1: c.text = "⏭ Bài tiếp"
            default:
                c.text = "Âm lượng nhạc"
                let s = UISlider(frame: CGRect(x: 0, y: 0, width: 160, height: 30)); s.value = music.volume
                s.addAction(UIAction { [weak self] a in self?.music.volume = (a.sender as? UISlider)?.value ?? 0.6 }, for: .valueChanged)
                cell.accessoryView = s
            }
        } else if music.tracks.isEmpty {
            c.text = "Chạm \"Thêm bài\" để chọn nhạc trong app Tệp"; c.textProperties.color = .secondaryLabel
        } else {
            c.text = music.tracks[indexPath.row].deletingPathExtension().lastPathComponent
            if indexPath.row == music.index && music.playing { cell.accessoryType = .checkmark }
        }
        cell.contentConfiguration = c; return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 { if indexPath.row == 0 { music.toggle() } else if indexPath.row == 1 { music.next() } }
        else if !music.tracks.isEmpty { music.play(indexPath.row) }
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if indexPath.section == 1, editingStyle == .delete { music.delete(at: indexPath.row) }
    }
}
