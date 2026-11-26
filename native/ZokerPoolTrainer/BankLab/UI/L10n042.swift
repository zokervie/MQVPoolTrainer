import UIKit
import ObjectiveC

/// 0.42 (owner acceptance 0.41 item 12): seven languages; 0.44.1: device language by default, else Vietnamese — en, vi, fil, es, zh-Hans, ja, hi.
/// The source text of the app is Vietnamese. Rather than touching ~900 call sites, UIKit's text entry points
/// (UILabel, UIButton, UIAlertController/Action, UISegmentedControl, UINavigationItem) are swizzled once and pass
/// through `L10n.tr`: exact phrase first, then known phrases inside dynamic text ("Bi 5 · lỗ 3"), longest first.
/// Untranslated text falls back to English if present, otherwise stays Vietnamese.
/// Catalog: `L10n.table` below (core screens) + optional `I18N_<code>` data assets (Tools/i18n, full catalog).
/// Translations other than vi/en are machine-quality drafts: a native speaker must review before release.
enum L10n {
    static let languages: [(code: String, name: String)] = [("en", "English"), ("vi", "Tiếng Việt"), ("fil", "Filipino"),
                                                             ("es", "Español"), ("zh", "中文"), ("ja", "日本語"), ("hi", "हिन्दी")]
    static let key = "appLanguage042"
    /// QA launches (UI tests, probes) always run in the source language so their text assertions stay valid.
    /// `--l10n-real` lets a QA launch use the real device language (first-launch language UI test).
    static let qa = ProcessInfo.processInfo.arguments.contains { $0.hasSuffix("-qa") } && !ProcessInfo.processInfo.arguments.contains("--l10n-real")   // 0.47: mọi cờ *-qa (không chỉ --visual-qa) giữ tiếng nguồn
    /// 0.44.1 (owner): no saved choice → the device language if supported, else Vietnamese (was: English).
    static var code: String {
        qa ? "vi" : (UserDefaults.standard.string(forKey: key) ?? deviceDefault)
    }
    private static var cache: [String: String] = [:]
    /// Computed once per launch (review: it ran on every translated string). A language change restarts the app anyway.
    static let deviceDefault = L10nDefault.code(preferred: Locale.preferredLanguages, supported: languages.map { $0.code })
    private static var loaded: [String: [String: String]] = [:]
    /// Order of each row: en, fil, es, zh, ja, hi.
    static let table: [String: [String]] = [
        "Luyện tập": ["Practice", "Pagsasanay", "Práctica", "练习", "練習", "अभ्यास"],
        "Thi đấu": ["Match", "Laban", "Partida", "比赛", "対戦", "मैच"],
        "Hồ sơ": ["Profile", "Profile", "Perfil", "个人资料", "プロフィール", "प्रोफ़ाइल"],
        "Tập tự do": ["Free practice", "Malayang pagsasanay", "Práctica libre", "自由练习", "フリー練習", "मुक्त अभ्यास"],
        "Bài tập · 5 cấp": ["Drills · 5 levels", "Drills · 5 antas", "Ejercicios · 5 niveles", "训练 · 5 级", "ドリル · 5段階", "ड्रिल · 5 स्तर"],
        "Thử thách kick 1–3 băng": ["Kick challenge 1–3 rails", "Kick challenge 1–3 rail", "Reto de kick 1–3 bandas", "1–3 库踢球挑战", "1〜3クッション キック", "किक चुनौती 1–3 रेल"],
        "Đấu với máy · 6 cấp": ["Vs computer · 6 levels", "Laban sa computer · 6 antas", "Contra la máquina · 6 niveles", "人机对战 · 6 级", "CPU対戦 · 6段階", "कंप्यूटर से · 6 स्तर"],
        "Hai người · một máy": ["Two players · one device", "Dalawang manlalaro · isang device", "Dos jugadores · un dispositivo", "双人 · 一台设备", "2人 · 1台", "दो खिलाड़ी · एक डिवाइस"],
        "Wi‑Fi gần nhau": ["Nearby Wi‑Fi", "Wi‑Fi sa malapit", "Wi‑Fi cercano", "附近 Wi‑Fi", "近くのWi‑Fi", "पास का Wi‑Fi"],
        "Online · Game Center": ["Online · Game Center", "Online · Game Center", "En línea · Game Center", "在线 · Game Center", "オンライン · Game Center", "ऑनलाइन · Game Center"],
        "Thế bi · nhật ký": ["Layouts · journal", "Layouts · journal", "Posiciones · diario", "球型 · 日志", "配置 · 記録", "लेआउट · जर्नल"],
        "Cú đã lưu · video highlight": ["Saved shots · highlights", "Mga naka-save na tira · highlights", "Tiros guardados · resúmenes", "已保存击球 · 集锦", "保存したショット · ハイライト", "सहेजे गए शॉट · हाइलाइट"],
        "Tài khoản · Game Center": ["Account · Game Center", "Account · Game Center", "Cuenta · Game Center", "账户 · Game Center", "アカウント · Game Center", "खाता · Game Center"],
        "Tập tự do, bài tập chấm sao, tìm góc kick": ["Free play, star-rated drills, kick angles", "Malayang laro, drills na may bituin, anggulo ng kick", "Juego libre, ejercicios con estrellas, ángulos de kick", "自由练习、星级训练、踢球角度", "フリー練習・星評価ドリル・キック角度", "मुक्त खेल, स्टार ड्रिल, किक कोण"],
        "8 · 9 · 10 Ball luật WPA, 15 Ball Rotation": ["8 · 9 · 10-ball WPA rules, 15-ball rotation", "8 · 9 · 10-ball WPA rules, 15-ball rotation", "Reglas WPA 8 · 9 · 10 bolas, rotación 15 bolas", "WPA 规则 8·9·10 球，15 球轮换", "WPAルール 8・9・10ボール、15ボールローテーション", "WPA नियम 8 · 9 · 10 बॉल, 15 बॉल रोटेशन"],
        "Nhật ký tập, cú đánh đã lưu, tài khoản": ["Practice log, saved shots, account", "Talaan ng pagsasanay, mga tira, account", "Registro, tiros guardados, cuenta", "练习记录、已保存击球、账户", "練習記録・保存ショット・アカウント", "अभ्यास लॉग, सहेजे शॉट, खाता"],
        "Đánh": ["Shot", "Tira", "Tiro", "击球", "ショット", "शॉट"],
        "Massé": ["Massé", "Massé", "Massé", "扎杆", "マッセ", "मासे"],
        "Menu": ["Menu", "Menu", "Menú", "菜单", "メニュー", "मेनू"],
        "Xem lại": ["Replay", "Replay", "Repetición", "回放", "リプレイ", "रीप्ले"],
        "Xem lại cú": ["Replay shot", "Replay ng tira", "Repetir tiro", "回放这一杆", "ショットを再生", "शॉट रीप्ले"],
        "Đặt bi": ["Place ball", "Ilagay ang bola", "Colocar bola", "放球", "ボール配置", "गेंद रखें"],
        "Thêm bi": ["Add ball", "Magdagdag ng bola", "Añadir bola", "加球", "ボール追加", "गेंद जोड़ें"],
        "Bao cơ": ["Cue case", "Lalagyan ng tako", "Estuche", "球杆包", "キューケース", "क्यू केस"],
        "Camera · ngắm": ["Camera · aim", "Camera · tutok", "Cámara · apuntar", "镜头 · 瞄准", "カメラ · 照準", "कैमरा · निशाना"],
        "Toàn cảnh": ["Overview", "Kabuuan", "General", "全景", "全体", "पूरा दृश्य"],
        "Bảng": ["Card", "Card", "Tarjeta", "卡片", "カード", "कार्ड"],
        // 0.44.1 M4 tutorial and M1 additions (fil/es/zh/ja/hi: machine-quality drafts, review before release)
        "Kéo để ngắm vào chấm vàng": ["Drag to aim at the gold dot", "I-drag para tumutok sa gintong tuldok", "Arrastra para apuntar al punto dorado", "拖动瞄准金色圆点", "ドラッグして金の点を狙う", "सुनहरे बिंदु पर निशाना लगाने के लिए खींचें"],
        "Giữ B, vuốt lùi rồi đẩy tới": ["Hold B, pull back, push through", "Hawakan ang B, hilahin, itulak", "Mantén B, tira atrás y empuja", "按住 B，后拉再推出", "Bを押したまま引いて突く", "B दबाएँ, पीछे खींचें, आगे धकेलें"],
        "Đã chuyển 60 Hz cho mượt": ["Switched to 60 Hz for smoothness", "Lumipat sa 60 Hz para sa kinis", "Cambiado a 60 Hz para más fluidez", "已切换到 60 Hz 以更流畅", "なめらかさのため60 Hzに切り替えました", "स्मूदनेस के लिए 60 Hz पर बदला"],
        "Vào rồi!": ["It's in!", "Pasok!", "¡Dentro!", "进了！", "入った！", "गया!"],
        "Thử lại nhé": ["Try again", "Subukan ulit", "Inténtalo de nuevo", "再试一次", "もう一度", "फिर कोशिश करें"],
        "Xem lại cú này": ["Replay this shot", "Panoorin muli ang tira", "Mira el tiro otra vez", "回看这一杆", "このショットを見返す", "यह शॉट फिर देखें"],
        "Đánh lại từ đây": ["Replay from here", "Ulitin mula rito", "Repetir desde aquí", "从这里重打", "ここから打ち直す", "यहाँ से फिर खेलें"],
        "Kéo để chọn điểm chạm": ["Drag to pick the tip spot", "I-drag para pumili ng tama", "Arrastra para elegir el efecto", "拖动选择击球点", "ドラッグで撞点を選ぶ", "टिप बिंदु चुनने के लिए खींचें"],
        "Kéo để nâng đuôi cơ": ["Drag to raise the cue butt", "I-drag para itaas ang tako", "Arrastra para elevar el taco", "拖动抬高球杆尾部", "ドラッグでキューを立てる", "क्यू का पिछला भाग उठाने के लिए खींचें"],
        "Hướng dẫn chơi": ["How to play", "Paano maglaro", "Cómo jugar", "玩法指南", "遊び方", "कैसे खेलें"],
        "Cú đầu tiên · ngắm và ra cơ": ["First shot · aim and stroke", "Unang tira · tumutok at tumira", "Primer tiro · apuntar y tirar", "第一杆 · 瞄准与出杆", "最初のショット · 狙って突く", "पहला शॉट · निशाना और स्ट्रोक"],
        "Cú đầu tiên": ["First shot", "Unang tira", "Primer tiro", "第一杆", "最初のショット", "पहला शॉट"],
        "Sao chép số đo cú vừa đánh": ["Copy last shot's measurements", "Kopyahin ang sukat ng huling tira", "Copiar medidas del último tiro", "复制上一杆的测量数据", "直前のショットの計測をコピー", "पिछले शॉट का माप कॉपी करें"],
        "Gợi ý theo ngữ cảnh (mỗi gợi ý một lần, tự tắt sau 6 giây)": ["Contextual tips (each once, hides after 6 s)", "Mga tip ayon sa konteksto (isang beses, 6 s)", "Consejos según contexto (una vez, 6 s)", "情境提示（每条一次，6 秒后隐藏）", "状況に応じたヒント（各1回、6秒で消える）", "संदर्भ सुझाव (हर एक बार, 6 सेकंड बाद छिपे)"],
        "Hướng dẫn cú đầu tiên khi mở app lần đầu (xem lại: Menu → Hướng dẫn chơi)": ["First-shot guide on first launch (again: Menu → How to play)", "Gabay sa unang tira sa unang bukas", "Guía del primer tiro al abrir por primera vez", "首次打开时的第一杆指引", "初回起動時の最初のショットガイド", "पहली बार खोलने पर पहले शॉट की गाइड"],
        "Chấm cú": ["Shot grade", "Marka ng tira", "Nota del tiro", "击球评分", "ショット評価", "शॉट ग्रेड"],
        "Camera · toàn cảnh": ["Camera · overview", "Camera · kabuuan", "Cámara · general", "镜头 · 全景", "カメラ · 全体", "कैमरा · पूरा दृश्य"],
        "Hình ảnh": ["Graphics", "Graphics", "Gráficos", "画面", "グラフィック", "ग्राफ़िक्स"],
        "Ngắm": ["Aiming", "Pagtutok", "Apuntar", "瞄准", "照準", "निशाना"],
        "Phím": ["Controls", "Mga kontrol", "Controles", "按键", "操作", "नियंत्रण"],
        "Vật lý": ["Physics", "Pisika", "Física", "物理", "物理", "भौतिकी"],
        "Máy · Âm thanh": ["Device · Sound", "Device · Tunog", "Dispositivo · Sonido", "设备 · 声音", "端末 · サウンド", "डिवाइस · ध्वनि"],
        "Ngôn ngữ": ["Language", "Wika", "Idioma", "语言", "言語", "भाषा"],
        "Chơi tiếp": ["Play again", "Maglaro muli", "Jugar otra vez", "再来一局", "もう一度", "फिर खेलें"],
        "Về sảnh": ["Back to lobby", "Bumalik sa lobby", "Volver al lobby", "返回大厅", "ロビーへ", "लॉबी पर लौटें"],
        "Lượt của bạn": ["Your turn", "Iyong tira", "Tu turno", "轮到你", "あなたの番", "आपकी बारी"],
        "Đang xem đối thủ": ["Watching opponent", "Pinapanood ang kalaban", "Viendo al rival", "观看对手", "相手を観戦中", "प्रतिद्वंद्वी देख रहे हैं"],
        "Chuyền máy": ["Pass & play", "Pasa at laro", "Pasar y jugar", "轮流同机", "交代プレイ", "पास करके खेलें"],
        "Người 1": ["Player 1", "Manlalaro 1", "Jugador 1", "玩家 1", "プレイヤー1", "खिलाड़ी 1"],
        "Người 2": ["Player 2", "Manlalaro 2", "Jugador 2", "玩家 2", "プレイヤー2", "खिलाड़ी 2"],
        "thắng ván": ["wins the rack", "panalo sa rack", "gana la partida", "赢下本局", "がラックを獲得", "रैक जीता"],
        "thắng trận": ["wins the match", "panalo sa laban", "gana el partido", "赢得比赛", "が試合に勝利", "मैच जीता"],
        "Kết thúc ván": ["End of rack", "Tapos ang rack", "Fin de la partida", "本局结束", "ラック終了", "रैक समाप्त"],
        "Kết thúc trận": ["Match over", "Tapos ang laban", "Fin del partido", "比赛结束", "試合終了", "मैच समाप्त"],
        "bắt đầu": ["starts", "magsisimula", "empieza", "开始", "開始", "शुरू"],
        "ván": ["rack", "rack", "partida", "局", "ラック", "रैक"],
        "Cú của": ["Shot by", "Tira ni", "Tiro de", "击球：", "ショット：", "शॉट:"],
        "Điểm chạm": ["Tip contact", "Tama ng tip", "Contacto", "击点", "撞点", "टिप संपर्क"],
        "Gọi bi và lỗ": ["Call ball and pocket", "Tawagin ang bola at butas", "Cantar bola y tronera", "指定球和袋", "ボールとポケットをコール", "गेंद और पॉकेट बताएं"],
        "Gọi đánh an toàn": ["Call safety", "Tawagin ang safety", "Cantar seguridad", "宣布安全球", "セーフティをコール", "सेफ्टी बताएं"],
        "Nhận thua ván": ["Concede rack", "Sumuko sa rack", "Conceder partida", "认输本局", "ラックを投了", "रैक छोड़ें"],
        "Đóng": ["Close", "Isara", "Cerrar", "关闭", "閉じる", "बंद करें"],
        "Hủy": ["Cancel", "Kanselahin", "Cancelar", "取消", "キャンセル", "रद्द करें"],
        "Huỷ": ["Cancel", "Kanselahin", "Cancelar", "取消", "キャンセル", "रद्द करें"],
        "Lưu": ["Save", "I-save", "Guardar", "保存", "保存", "सहेजें"],
        "Bật": ["On", "Bukas", "Sí", "开", "オン", "चालू"],
        "Tắt": ["Off", "Sarado", "No", "关", "オフ", "बंद"],
        "Hiện": ["Show", "Ipakita", "Mostrar", "显示", "表示", "दिखाएं"],
        "Ẩn": ["Hide", "Itago", "Ocultar", "隐藏", "非表示", "छिपाएं"],
        "Nhận bàn / tiếp tục": ["Take the table / continue", "Kunin ang mesa / ituloy", "Tomar la mesa / seguir", "接手球台 / 继续", "続行する", "टेबल लें / जारी रखें"],
        "Trả lượt cho người vừa đánh": ["Give it back to the shooter", "Ibalik sa tumira", "Devolver al tirador", "让对方继续", "相手に戻す", "शूटर को लौटाएं"],
        "Nhận bi cái trong tay": ["Take ball in hand", "Kunin ang ball in hand", "Bola en mano", "自由球", "フリーボール", "बॉल इन हैंड लें"],
        "Bi cái trong tay · chạm Đặt bi": ["Ball in hand · tap Place ball", "Ball in hand · pindutin ang Ilagay", "Bola en mano · toca Colocar", "自由球 · 点击放球", "フリーボール · 配置をタップ", "बॉल इन हैंड · गेंद रखें दबाएं"],
        "Club (mặc định)": ["Club (default)", "Club (default)", "Club (predet.)", "俱乐部（默认）", "クラブ（標準）", "क्लब (डिफ़ॉल्ट)"],
        "Trong nhà": ["Home", "Bahay", "Casa", "家中", "自宅", "घर"],
        "Sân vườn": ["Garden", "Hardin", "Jardín", "花园", "庭", "बगीचा"],
        "Cung điện": ["Palace", "Palasyo", "Palacio", "宫殿", "宮殿", "महल"],
        "Hoàng gia": ["Royal", "Royal", "Real", "皇家", "ロイヤル", "राजसी"],
        "Thi đấu quốc tế": ["International arena", "Internasyonal na arena", "Arena internacional", "国际赛场", "国際アリーナ", "अंतरराष्ट्रीय एरीना"],
        "Club cổ điển": ["Classic club", "Klasikong club", "Club clásico", "经典俱乐部", "クラシッククラブ", "क्लासिक क्लब"],
        "Phòng VIP Zoker": ["Zoker VIP lounge", "Zoker VIP lounge", "Sala VIP Zoker", "Zoker 贵宾室", "Zoker VIPラウンジ", "Zoker VIP लाउंज"],
        "Sân thượng đêm": ["Rooftop at night", "Rooftop sa gabi", "Azotea nocturna", "夜间天台", "夜の屋上", "रात की छत"],
        "Hầm đá": ["Stone cellar", "Batong silong", "Bodega de piedra", "石窖", "石の地下室", "पत्थर का तहखाना"],
        "Nhạc của tôi": ["My music", "Aking musika", "Mi música", "我的音乐", "マイミュージック", "मेरा संगीत"],
        "Thêm bài": ["Add tracks", "Magdagdag ng kanta", "Añadir canciones", "添加歌曲", "曲を追加", "गाने जोड़ें"],
        "Camera lượt đối thủ": ["Opponent-turn camera", "Camera sa tira ng kalaban", "Cámara del turno rival", "对手回合镜头", "相手ターンのカメラ", "प्रतिद्वंद्वी बारी कैमरा"],
        "Truyền hình": ["Broadcast", "Broadcast", "Televisión", "转播", "中継", "प्रसारण"],
        "Trên cao": ["Top", "Itaas", "Cenital", "俯视", "真上", "ऊपर से"],
        "Theo cơ": ["Follow cue", "Sundan ang tako", "Seguir taco", "跟随球杆", "キュー追従", "क्यू के साथ"],
    ]
    private static func asset(_ code: String) -> [String: String] {
        if let t = loaded[code] { return t }
        var t: [String: String] = [:]
        if let data = NSDataAsset(name: "I18N_\(code)")?.data, let d = try? JSONSerialization.jsonObject(with: data) as? [String: String] { t = d }
        let column = ["en": 0, "fil": 1, "es": 2, "zh": 3, "ja": 4, "hi": 5][code]
        if let c = column { for (k, row) in table where row.indices.contains(c) && t[k] == nil { t[k] = row[c] } }
        loaded[code] = t; return t
    }
    private static var phraseKeys: [String: [String]] = [:]
    static func tr(_ s: String) -> String {
        let lang = code
        guard lang != "vi", !s.isEmpty else { return s }
        if let hit = cache[lang + "\u{1}" + s] { return hit }
        let t = asset(lang), en = lang == "en" ? t : asset("en")
        var out = t[s] ?? en[s]
        if out == nil {
            // dynamic text: replace known phrases inside it, longest first (only phrases of 4+ characters)
            if phraseKeys[lang] == nil { phraseKeys[lang] = Array(Set(t.keys).union(en.keys)).filter { $0.count >= 4 }.sorted { $0.count > $1.count } }
            var r = s
            for k in phraseKeys[lang] ?? [] where r.contains(k) { r = r.replacingOccurrences(of: k, with: t[k] ?? en[k] ?? k) }
            out = r
        }
        if cache.count > 4000 { cache.removeAll() }
        cache[lang + "\u{1}" + s] = out
        return out ?? s
    }
    static func set(_ code: String) { UserDefaults.standard.set(code, forKey: key); cache.removeAll(); phraseKeys.removeAll() }

    // MARK: swizzling (installed once at launch)
    private static var installed = false
    static func install() {
        guard !installed else { return }; installed = true
        swap(UILabel.self, #selector(setter: UILabel.text), #selector(UILabel.l10n_setText(_:)))
        swap(UIButton.self, #selector(UIButton.setTitle(_:for:)), #selector(UIButton.l10n_setTitle(_:for:)))
        // 0.59 (bản 200, owner screenshots): buttons built with UIButton.Configuration set `configuration.title`, which never
        // passed through setTitle(_:for:) — the right column (Đặt bi · Camera · ngắm · Bàn · Xong · Toàn cảnh) stayed Vietnamese.
        swap(UIButton.self, NSSelectorFromString("setConfiguration:"), #selector(UIButton.l10n_setConfiguration(_:)))
        swap(UIViewController.self, #selector(setter: UIViewController.title), #selector(UIViewController.l10n_setTitle(_:)))
        swap(UIAlertController.self, #selector(setter: UIAlertController.message), #selector(UIAlertController.l10n_setMessage(_:)))
        swap(UIAlertController.self, #selector(setter: UIAlertController.title), #selector(UIAlertController.l10n_alertSetTitle(_:)))
        swap(UISegmentedControl.self, #selector(UISegmentedControl.insertSegment(withTitle:at:animated:)), #selector(UISegmentedControl.l10n_insertSegment(withTitle:at:animated:)))
        swap(UISegmentedControl.self, #selector(UISegmentedControl.setTitle(_:forSegmentAt:)), #selector(UISegmentedControl.l10n_setTitle(_:forSegmentAt:)))
        if let original = class_getClassMethod(UIAlertAction.self, NSSelectorFromString("actionWithTitle:style:handler:")),
           let replacement = class_getClassMethod(UIAlertAction.self, #selector(UIAlertAction.l10n_action(withTitle:style:handler:))) {
            method_exchangeImplementations(original, replacement)
        }
    }
    private static func swap(_ cls: AnyClass, _ a: Selector, _ b: Selector) {
        // Safe pattern: when the class only inherits `a`, add it on this class first so the superclass is untouched.
        guard let m1 = class_getInstanceMethod(cls, a), let m2 = class_getInstanceMethod(cls, b) else { return }
        if class_addMethod(cls, a, method_getImplementation(m2), method_getTypeEncoding(m2)) {
            class_replaceMethod(cls, b, method_getImplementation(m1), method_getTypeEncoding(m1))
        } else { method_exchangeImplementations(m1, m2) }
    }
}
extension UILabel { @objc func l10n_setText(_ t: String?) { l10n_setText(t.map(L10n.tr)) } }
extension UIButton {
    @objc func l10n_setTitle(_ t: String?, for state: UIControl.State) { l10n_setTitle(t.map(L10n.tr), for: state) }
    /// `configuration` setter: the title (and subtitle) go through L10n.tr; Vietnamese (and every QA launch) returns them unchanged.
    @objc func l10n_setConfiguration(_ c: AnyObject?) {
        guard L10n.code != "vi", var config = c as? UIButton.Configuration else { l10n_setConfiguration(c); return }
        if let t = config.title { let tt = L10n.tr(t); if tt != t { config.title = tt } }
        if let t = config.subtitle { let tt = L10n.tr(t); if tt != t { config.subtitle = tt } }
        l10n_setConfiguration(config as AnyObject)
    }
}
extension UIViewController { @objc func l10n_setTitle(_ t: String?) { l10n_setTitle(t.map(L10n.tr)) } }
extension UIAlertController {
    @objc func l10n_setMessage(_ t: String?) { l10n_setMessage(t.map(L10n.tr)) }
    @objc func l10n_alertSetTitle(_ t: String?) { l10n_alertSetTitle(t.map(L10n.tr)) }
}
extension UISegmentedControl {
    @objc func l10n_insertSegment(withTitle t: String?, at i: Int, animated: Bool) { l10n_insertSegment(withTitle: t.map(L10n.tr), at: i, animated: animated) }
    @objc func l10n_setTitle(_ t: String?, forSegmentAt i: Int) { l10n_setTitle(t.map(L10n.tr), forSegmentAt: i) }
}
extension UIAlertAction {
    @objc class func l10n_action(withTitle t: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)?) -> UIAlertAction {
        l10n_action(withTitle: t.map(L10n.tr), style: style, handler: handler)
    }
}
