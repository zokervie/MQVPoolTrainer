import UIKit
import UniformTypeIdentifiers

final class SettingsController:UIViewController,UIDocumentPickerDelegate {
    var apply:(([String:NSNumber],Double)->Void)?
    private var values:[String:NSNumber]
    private var originalValues:[String:NSNumber]
    private var originalSensitivity:Double
    private var sensitivity:Double
    private let body=UIStackView()
    init(settings:[String:NSNumber],sensitivity:Double){values=settings;originalValues=settings;originalSensitivity=sensitivity;self.sensitivity=sensitivity;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError()}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override func viewDidLoad(){
        super.viewDidLoad();title="Hiệu chỉnh bàn";view.backgroundColor = .ink
        navigationController?.navigationBar.barStyle = .black
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Lưu",style:.done,target:self,action:#selector(save))
        navigationItem.leftBarButtonItem=UIBarButtonItem(title:"Hủy",style:.plain,target:self,action:#selector(cancel))
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(scroll)
        MenuSkin.frame(view,content:scroll,tone:MenuSkin.tones[3])   // 0.41: wood frame
        body.axis = .vertical;body.spacing=18;body.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(body)
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),scroll.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-8),scroll.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:10),scroll.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-10),body.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:20),body.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-24),body.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:20),body.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-20),body.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-40)])
        let note=UILabel();note.text="Cấu hình thử nghiệm · Bàn 9 ft (1.27 × 2.54 m) · Bi 57.15 mm, 170 g\n\nBắt đầu với cú giữa bi, đo cùng tốc độ đầu. Chỉnh cản lăn trước, rồi độ nảy và ma sát băng. Thông số này chưa đại diện cho một mẫu bàn hoặc loại vải cụ thể."
        note.numberOfLines=0;note.textColor = .white;note.font = .systemFont(ofSize:13);body.addArrangedSubview(note)
        body.addArrangedSubview(UIButton.lab("Nhập cú đo băng · JSON"){[weak self]in
            let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.json],asCopy:true);picker.delegate=self;self?.present(picker,animated:true)
        })
        body.addArrangedSubview(UIButton.lab("Xuất MD · cấu hình và thay đổi"){[weak self]in self?.exportMarkdown()})
        body.addArrangedSubview(UIButton.lab("Xuất mẫu dữ liệu hiệu chuẩn"){[weak self]in self?.exportTemplate()})
        let contactSwitch=UISwitch();contactSwitch.isOn=values["coupledCushions"]?.boolValue ?? true
        contactSwitch.addAction(UIAction{[weak self,weak contactSwitch]_ in self?.values["coupledCushions"]=NSNumber(value:contactSwitch?.isOn ?? false)},for:.valueChanged)
        let contactLabel=UILabel();contactLabel.text="A1 · tiếp xúc 3D băng + mặt đá";contactLabel.textColor = .white
        body.addArrangedSubview(UIStackView(arrangedSubviews:[contactLabel,contactSwitch]))
        // 0.37: table presets (owner chose). Values sit inside the published ranges [design assumption, not measured].
        let presetTitle=UILabel();presetTitle.text="Mẫu loại bàn";presetTitle.textColor = .white;presetTitle.font = .systemFont(ofSize:15,weight:.semibold)
        body.addArrangedSubview(presetTitle)
        let presets:[(String,[String:Double])]=[
            ("Nỉ mới · nhanh",["rolling":0.007,"sliding":0.17,"railRestitution":0.86,"spinDecay":12]),
            ("Tiêu chuẩn",["rolling":0.012,"sliding":0.20,"railRestitution":0.82,"spinDecay":15]),
            ("Nỉ cũ, ẩm · chậm",["rolling":0.015,"sliding":0.28,"railRestitution":0.76,"spinDecay":15])]
        let row=UIStackView();row.axis = .horizontal;row.spacing=10;row.distribution = .fillEqually
        for (name,set) in presets {
            let b=UIButton.lab(name){[weak self]in
                guard let self=self else{return};for (k,v) in set{self.values[k]=NSNumber(value:v)}
                self.apply?(self.values,self.sensitivity);self.dismiss(animated:true)
            };b.accessibilityIdentifier="TablePreset-"+name;row.addArrangedSubview(b)
        }
        body.addArrangedSubview(row)
        let realNote=UILabel();realNote.numberOfLines=0;realNote.textColor=UIColor(white:0.7,alpha:1);realNote.font = .systemFont(ofSize:12)
        realNote.text="Vạch xanh dưới thanh trượt = vùng thực tế (giá trị đã công bố). Kéo ra ngoài vẫn được, nhưng bàn sẽ khác bàn thật.";body.addArrangedSubview(realNote)
        slider("Cản lăn — thấp: bi chạy xa","rolling",0.003,0.04,0.012,real:(0.005,0.015))
        slider("Ma sát trượt — thời gian chuyển sang lăn","sliding",0.08,0.35,0.20,real:(0.15,0.35))
        slider("Đàn hồi băng — cao: giữ lực nhiều","railRestitution",0.4,0.98,0.82,real:(0.6,0.9))
        slider("ZUPE: giảm độ nảy theo lực — 0 là bản gốc","railSpeedSensitivity",0,0.08,0)
        slider("Ma sát băng — ảnh hưởng ép phê (0.31: 0,20 theo Mathavan 2010; 0,45 = cảm nhận bàn anh)","railFriction",0,0.6,0.20,real:(0.14,0.2))
        let railSwitch=UISwitch();railSwitch.isOn=values["individualRails"]?.boolValue ?? false
        railSwitch.addAction(UIAction{[weak self,weak railSwitch]_ in self?.values["individualRails"]=NSNumber(value:railSwitch?.isOn ?? false)},for:.valueChanged)
        let railLabel=UILabel();railLabel.text="Dùng thông số riêng từng băng";railLabel.textColor = .white
        body.addArrangedSubview(UIStackView(arrangedSubviews:[railLabel,railSwitch]))
        for (i,name) in ["Trái","Phải","Đầu −Y","Đầu +Y"].enumerated(){
            slider("Băng \(name) · độ nảy","railBounce\(i)",0.4,0.98,0.82)
            slider("Băng \(name) · ma sát","railGrip\(i)",0,0.35,0.16)
        }
        slider("Đàn hồi bi–bi","ballRestitution",0.80,1,0.94,real:(0.92,0.98))
        slider("Ma sát bi–bi khi trượt chậm μ₀ (giảm theo tốc độ, TP A.14)","ballFriction",0,0.12,0.118)
        slider("Truyền xoáy bi–bi (bánh răng) — ma sát khi trượt nhanh, 0.30: 0,05","ballFrictionMin",0,0.1,0.05)
        slider("Giảm ép phê ngang (rad/s²) — 0.31: 15 (công bố 5–15)","spinDecay",1,40,15,real:(5,15))
        slider("Băng nảy ngược tiếp tuyến β (grip-slip) — 0.21: 0,30, fit clip zigzag","railTangentialRestitution",0,0.9,0.30)
        slider("Squirt đủ ở độ nâng cơ (°) — 0: luôn có squirt","squirtRampDegrees",0,60,15)
        slider("Gậy phá · hệ số lực","breakSpeedGain",1,1.8,1.4)
        slider("Massé · hệ số lực (0.30: 1,2 = +20%)","masseSpeedGain",1,1.6,1.2)
        slider("Massé · đàn hồi cơ–bi (thấp: dính lâu, xoáy nhiều)","masseCueRestitution",0.1,0.9,0.35)
        slider("Độ nhạy vuốt cơ","sensitivity",0.5,1.8,1)
        body.addArrangedSubview(UIButton.lab("Khôi phục mặc định"){[weak self]in
            guard let self=self else{return};self.values=BLWorld().settings;self.sensitivity=1
            self.apply?(self.values,self.sensitivity);self.dismiss(animated:true)
        })
        let limits=UILabel();limits.numberOfLines=0;limits.textColor=UIColor(white:0.65,alpha:1);limits.font = .systemFont(ofSize:12)
        limits.text="0.21: β băng và giảm xoáy fit theo clip zigzag; squirt chỉ khi nâng cơ; gậy phá ×1,4; đầu tẩy mềm/cứng (giả định). Hiệu chuẩn: va chạm băng dạng xung lực gần đúng, lòng lỗ dùng vùng bắt 2D. A1 dùng xung lực 3D, ma sát Coulomb hai chiều và ràng buộc mặt đá khi bi tiếp xúc. Đây chưa phải mô hình băng biến dạng Mathavan/Stronge. Thông số fit của mô hình cũ cần đo lại. Bản 0.14: throw theo ma sát phụ thuộc tốc độ (TP A.14), squirt (TP A.31, khối lượng đầu cơ giả định) và tốc độ bi theo điểm chạm (TP A.30). Chưa hiệu chuẩn băng biến dạng, độ ẩm, swerve hoặc Jump/Massé. Hãy đối chiếu bằng bài đo trước khi dùng để suy ra đường thi đấu."
        body.addArrangedSubview(limits)
    }
    private func slider(_ title:String,_ key:String,_ lo:Double,_ hi:Double,_ fallback:Double,real:(Double,Double)?=nil){
        let label=UILabel();label.textColor = .white;label.font = .systemFont(ofSize:12,weight:.medium);label.numberOfLines=0
        let current=key=="sensitivity" ? sensitivity:(values[key]?.doubleValue ?? fallback)
        func caption(_ v:Double)->String{
            guard let r=real else{return String(format:"%@  ·  %.3f",title,v)}
            return String(format:"%@  ·  %.3f  %@",title,v,(v>=r.0-1e-9 && v<=r.1+1e-9) ? "✓ thực tế":"⚠︎ ngoài vùng thực tế")
        }
        label.text=caption(current)
        let s=UISlider();s.minimumValue=Float(lo);s.maximumValue=Float(hi);s.value=Float(current);s.tintColor = .mint
        s.accessibilityLabel=title
        s.addAction(UIAction{[weak self,weak s,weak label]_ in
            guard let self=self,let s=s else{return};let v=Double(s.value)
            if key=="sensitivity" {self.sensitivity=v}else{self.values[key]=NSNumber(value:v)}
            label?.text=caption(v)
        },for:.valueChanged)
        var parts:[UIView]=[label,s]
        if let r=real {
            // realistic band drawn to scale under the track
            let track=UIView();track.backgroundColor=UIColor(white:1,alpha:0.10);track.layer.cornerRadius=2
            track.heightAnchor.constraint(equalToConstant:4).isActive=true
            let band=UIView();band.backgroundColor = .mint;band.layer.cornerRadius=2;band.translatesAutoresizingMaskIntoConstraints=false;track.addSubview(band)
            let a=CGFloat((r.0-lo)/(hi-lo)),b=CGFloat((min(r.1,hi)-lo)/(hi-lo))
            NSLayoutConstraint.activate([band.topAnchor.constraint(equalTo:track.topAnchor),band.bottomAnchor.constraint(equalTo:track.bottomAnchor),
                NSLayoutConstraint(item:band,attribute:.leading,relatedBy:.equal,toItem:track,attribute:.trailing,multiplier:max(0.001,a),constant:0),
                NSLayoutConstraint(item:band,attribute:.trailing,relatedBy:.equal,toItem:track,attribute:.trailing,multiplier:max(0.002,b),constant:0)])
            parts.append(track)
        }
        let group=UIStackView(arrangedSubviews:parts);group.axis = .vertical;group.spacing=5;body.addArrangedSubview(group)
    }
    private func exportMarkdown(){
        var lines=["# Z-Trainer — hiệu chỉnh bàn", "", "Ngày: "+ISO8601DateFormatter().string(from:Date()), "", "Thông số do người dùng chỉnh tay; chưa xác nhận bằng đo đạc độc lập.", "", "| Thông số | Khi mở | Hiện tại |", "| --- | ---: | ---: |"]
        for key in Set(originalValues.keys).union(values.keys).sorted(){
            lines.append("| \(key) | \(originalValues[key]?.stringValue ?? "—") | \(values[key]?.stringValue ?? "—") |")
        }
        lines.append("| swipeSensitivity | \(originalSensitivity) | \(sensitivity) |")
        lines += ["", "## Nguồn hệ số (0.30)", "", "- railTangentialRestitution 0,30: fit clip *Reverse bank zigzag* (c-ZBSi9KBfc), 4 băng, sai lệch ≤ 0,3 nút.", "- railFriction 0,20: Mathavan 2010 / pooltool (ma sát bi–băng công bố 0,14–0,2). 0,45 = cảm nhận bàn anh (tuỳ chọn).", "- Đầu cơ tối đa 0,55R: giới hạn trượt cơ ~0,5R điểm chạm (Alciatore).", "- ballFrictionMin 0,05: fit — effect ngược truyền xoáy ngược sang bi đích (bánh răng), R·ω/v ≈ 0,13 như clip.", "- spinDecay 15: đầu trên khoảng công bố 5–15 rad/s² (Alciatore, Physical properties).", "- railRestitution 0,82: giữ nguyên.", "- squirtRampDegrees 15, breakSpeedGain 1,4, masseCueRestitution 0,35: giả định / thiết kế.", "- Đầu tẩy: trung tính = vật lý mặc định; mềm (Massé) chạm xa tâm hơn 0,08R; cứng (Jump/Phá) +6% năng lượng — giả định."]
        lines += ["", "## Ghi chú đo bàn thật", "", "- Loại bàn / nỉ / bi:", "- Cự ly và tốc độ đầu đo được:", "- Quãng đường dừng / góc bật đo được:", "- Sai lệch so với ứng dụng:", "", "Xuất file không tự áp dụng cấu hình; bấm Lưu để áp dụng."]
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("ZTrainer-calibration-"+UUID().uuidString+".md")
        do{
            try lines.joined(separator:"\n").write(to:url,atomically:true,encoding:.utf8)
            let sheet=UIActivityViewController(activityItems:[url],applicationActivities:nil)
            sheet.popoverPresentationController?.sourceView=view
            sheet.popoverPresentationController?.sourceRect=CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1)
            present(sheet,animated:true)
        }catch{message("Không xuất được file MD: "+error.localizedDescription)}
    }
    private func exportTemplate(){
        let template:[String:Any]=["schemaVersion":1,"rail":0,"source":"measured","units":"metres, seconds, radians; XY table plane; Z up","instructions":"8–500 independent flat straight-rail impacts. State immediately before/after impact. No pocket jaws. vx,vy,wx,wy,spin,outVx,outVy,outWx,outWy,outSpin required. Every fourth row is validation; do not order rows by speed or spin.","samples":[]]
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("Zoker-cushion-measurements.json")
        do{try JSONSerialization.data(withJSONObject:template,options:[.prettyPrinted,.sortedKeys]).write(to:url)
            let sheet=UIActivityViewController(activityItems:[url],applicationActivities:nil);sheet.popoverPresentationController?.sourceView=view;sheet.popoverPresentationController?.sourceRect=CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1);present(sheet,animated:true)
        }catch{message("Không xuất được mẫu dữ liệu.")}
    }
    func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]){
        guard let url=urls.first else{return}
        do{
            let data=try Data(contentsOf:url);guard data.count<2_000_000,let payload=try JSONSerialization.jsonObject(with:data) as? [String:Any],payload["schemaVersion"] as? Int==1,payload["source"] as? String=="measured",let rail=payload["rail"] as? Int,(0...3).contains(rail),let rows=payload["samples"] as? [[String:Any]] else{message("JSON sai cấu trúc hoặc chưa xác nhận nguồn đo thực tế.");return}
            let snapshot=values
            let busy=UIActivityIndicatorView(style:.large);busy.center=view.center;view.addSubview(busy);busy.startAnimating()
            view.isUserInteractionEnabled=false;navigationItem.leftBarButtonItem?.isEnabled=false;navigationItem.rightBarButtonItem?.isEnabled=false
            DispatchQueue.global(qos:.userInitiated).async{[weak self] in
                let engine=BLWorld();engine.settings=snapshot
                let result=engine.fitCushion(samples:rows,rail:rail) as NSDictionary
                DispatchQueue.main.async{[weak self] in
                    busy.removeFromSuperview()
                    guard let self=self else{return}
                    self.view.isUserInteractionEnabled=true;self.navigationItem.leftBarButtonItem?.isEnabled=true;self.navigationItem.rightBarButtonItem?.isEnabled=true
                    self.showFit(result,rail:rail)
                }
            }
        }catch{message("Không đọc được JSON cú đo.")}
    }
    private func showFit(_ result:NSDictionary,rail:Int){
            if let error=result["error"] as? String{message(error);return}
            guard let bounce=result["bounce"] as? Double,let grip=result["grip"] as? Double,let train=result["trainRMSE"] as? Double,let validation=result["validationRMSE"] as? Double,let baseline=result["baselineRMSE"] as? Double else{message("Không tính được kết quả.");return}
            let text=String(format:"Băng %d · e=%.4f · μ=%.4f\nSai số fit: %.4f m/s\nKiểm định: %.4f → %.4f m/s\nSai số gộp vận tốc và R×xoáy. Chưa kiểm định chuỗi nhiều băng hoặc cú Jump/Massé.",rail,bounce,grip,train,baseline,validation)
            let alert=UIAlertController(title:"Kết quả hiệu chuẩn ứng viên",message:text,preferredStyle:.alert)
            alert.addAction(UIAlertAction(title:"Đóng",style:.cancel))
            if validation<baseline {alert.addAction(UIAlertAction(title:"Chọn kết quả · sau đó bấm Lưu",style:.default){[weak self]_ in
                if let self=self,!(self.values["individualRails"]?.boolValue ?? false){
                    for i in 0..<4{self.values["railBounce\(i)"]=self.values["railRestitution"] ?? 0.82;self.values["railGrip\(i)"]=self.values["railFriction"] ?? 0.20}
                }
                self?.values["individualRails"]=1;self?.values["railBounce\(rail)"]=NSNumber(value:bounce);self?.values["railGrip\(rail)"]=NSNumber(value:grip)
                self?.message("Đã chọn thông số ứng viên. Bấm Lưu để áp dụng; cần nghiệm thu bằng cú nhiều băng độc lập.")
            })}
            present(alert,animated:true)
    }
    private func message(_ text:String){let a=UIAlertController(title:"Hiệu chuẩn",message:text,preferredStyle:.alert);a.addAction(UIAlertAction(title:"OK",style:.default));present(a,animated:true)}
    @objc private func save(){apply?(values,sensitivity);dismiss(animated:true)}
    @objc private func cancel(){dismiss(animated:true)}
}

// MARK: - 0.36 Tuỳ chỉnh (owner IQ200 #4): lighting, diamond prominence, max power + physics, HUD arrangement, smoothness.
enum Tuning {
    static func value(_ key:String,_ fallback:Double)->Double{UserDefaults.standard.object(forKey:key) as? Double ?? fallback}
    /// Bool preference that also accepts launch-argument strings ("-key YES" in UI tests).
    static func flag(_ key:String,_ fallback:Bool)->Bool{UserDefaults.standard.object(forKey:key)==nil ? fallback:UserDefaults.standard.bool(forKey:key)}
    /// Active render cadence. 120 needs ProMotion (CADisableMinimumFrameDurationOnPhone is set); more heat.
    static var frameRate:Int{
        #if targetEnvironment(simulator)
        return 30   // CI Simulator: keep the runner responsive
        #else
        return UserDefaults.standard.integer(forKey:"tuneFPS036")==120 ? 120:60
        #endif
    }
    /// Fraction of the native pixel scale the 3D view renders at (1, 0.85, 0.7).
    static var renderScale:Double{value("tuneScale036",1)}
    /// Multiplier on the stroke speed (BLStrokeSpeed tops out at 8 m/s): 0.6 → 4.8 m/s, 1.3 → 10.4 m/s.
    static var maxPower:Double{value("tuneMaxPower036",1)}
    /// 0.37: HUD fades while the player aims; effect ball lock (off = only B locks); predict-first eye training.
    static var hudFade:Bool{flag("tuneHUDFade037",true)}
    static var effectLock:Bool{flag("tuneEffectLock037",false)}
    static var predictFirst:Bool{flag("tunePredictFirst037",false)}
    // 0.38 (owner approved all proposals)
    static var hudScale:Double{value("tuneHUDScale038",1)}
    static var hudAlpha:Double{value("tuneHUDAlpha038",1)}
    static var autoNumbers:Bool{flag("tuneAutoNumbers038",true)}
    static var guideBySkill:Bool{flag("tuneGuideSkill038",true)}
    static var aimPitch:Double{value("tuneAimPitch038",0.57)}
    static var aimZoom:Double{value("tuneAimZoom038",1)}
}

final class CustomizeController:UIViewController {
    var changed:(()->Void)?
    var openPhysics:(()->Void)?
    var openDiagnostics:(()->Void)?
    var arrangeHUD:(()->Void)?
    var resetHUD:(()->Void)?
    var saveLayout:((Int)->Void)?
    var loadLayout:((Int)->Void)?
    private let body=UIStackView()
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override func viewDidLoad(){
        super.viewDidLoad();title="Tuỳ chỉnh";view.backgroundColor = .ink
        navigationController?.navigationBar.barStyle = .black
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Xong",style:.done,target:self,action:#selector(done))
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(scroll)
        MenuSkin.frame(view,content:scroll,tone:MenuSkin.tones[0])   // 0.41: wood frame, tone per tab
        body.axis = .vertical;body.spacing=14;body.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(body)
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),scroll.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-8),scroll.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:10),scroll.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-10),body.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:16),body.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-24),body.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:20),body.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-20),body.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-40)])
        // 0.39 (owner: "4 thẻ hơi rối, sắp xếp lại logic hơn"). Grouped by what the player is thinking about, not by
        // implementation: what I SEE (ball / table / lamp) · how I AIM · the KEYS on screen · how the table PLAYS ·
        // the DEVICE (smoothness, heat, sound). Every item lives in exactly one place.
        let tabs=UISegmentedControl(items:["Hình ảnh","Ngắm","Phím","Vật lý","Máy · Âm thanh"]);tabs.selectedSegmentIndex=0
        tabs.selectedSegmentTintColor=UIColor.rgb(0xEAC583);tabs.setTitleTextAttributes([.foregroundColor:UIColor.black,.font:UIFont.systemFont(ofSize:14,weight:.semibold)],for:.selected)
        tabs.setTitleTextAttributes([.foregroundColor:UIColor.white,.font:UIFont.systemFont(ofSize:14,weight:.medium)],for:.normal)
        tabs.accessibilityIdentifier="CustomizeTabs";body.addArrangedSubview(tabs)
        var pages:[UIStackView]=[]
        for _ in 0..<5 {let page=UIStackView();page.axis = .vertical;page.spacing=14;pages.append(page);body.addArrangedSubview(page)}
        func show(_ i:Int){for (k,p) in pages.enumerated(){p.isHidden = k != i};UIView.animate(withDuration:0.25){scroll.backgroundColor=MenuSkin.tones[min(i,MenuSkin.tones.count-1)]}}
        tabs.addAction(UIAction{[weak tabs]_ in show(tabs?.selectedSegmentIndex ?? 0)},for:.valueChanged)
        // 1 · Hình ảnh: preset first, then Bi → Bàn → Đèn
        target=pages[0]
        header("Mẫu nhanh")
        let looks:[(String,[String:Double])]=[
            ("Câu lạc bộ",[TableScene.tuneLight:1.0,TableScene.tuneBall:1.0,TableScene.tuneShadow:1.0,TableScene.tuneCloth:1.0]),
            ("TV · sáng rõ",[TableScene.tuneLight:1.35,TableScene.tuneBall:0.92,TableScene.tuneShadow:0.8,TableScene.tuneCloth:1.15]),
            ("Dịu mắt",[TableScene.tuneLight:0.8,TableScene.tuneBall:0.85,TableScene.tuneShadow:1.1,TableScene.tuneCloth:0.9])]
        let row=UIStackView();row.axis = .horizontal;row.spacing=10;row.distribution = .fillEqually
        for (name,set) in looks {let b=UIButton.lab(name){[weak self] in
            for (k,v) in set{UserDefaults.standard.set(v,forKey:k)};self?.changed?();self?.dismiss(animated:true)}
            b.accessibilityIdentifier="LightLook-"+name;row.addArrangedSubview(b)}
        target.addArrangedSubview(row)
        header("Bi")
        slider("Độ chói bi",TableScene.tuneBall,0.6,1.3)
        slider("Độ đậm bóng bi",TableScene.tuneShadow,0.4,1.3)
        toggle("Bóng bi thật, tròn mềm (tắt nếu máy nóng/yếu)","tuneRealShadow039",true)
        header("Bàn")
        // 0.40b (owner: cloth colours as icons like the sample card, inside Tuỳ chỉnh).
        swatches("Màu nỉ · Z-Weave 300 (60% len · 40% nylon)",TableScene.clothColors.map{name,color in (name,Self.clothSwatch(color))},
                 UserDefaults.standard.object(forKey:"clothTintIndex") as? Int ?? -1){UserDefaults.standard.set($0,forKey:"clothTintIndex")}
        segmented("Tình trạng nỉ",["Mới · rõ sợi","Cũ · xơ"],UserDefaults.standard.bool(forKey:"clothWear021") ? 1:0){UserDefaults.standard.set($0==1,forKey:"clothWear021")}
        slider("Độ sáng mặt bàn (nỉ)",TableScene.tuneCloth,0.6,1.4)
        slider("Độ rõ vân nỉ",TableScene.tuneWeave,0,1.5)
        // 0.40c (owner, 3rd round on the weave): thread size seen when zooming close — 0.6 mm is real cloth, larger reads clearer.
        slider("Độ thô sợi nỉ khi zoom gần",TableScene.tuneWeavePitch,0.6,1.6,fallback:1.0,format:{String(format:"%.1f mm/sợi",$0)})
        slider("Độ nổi kim cương / nút số",TableScene.tuneDiamond,0.8,2.0)
        header("Đèn")
        slider("Đèn bàn",TableScene.tuneLight,0.5,1.6)
        header("Bảng điểm (trận đấu)")
        swatches("Kiểu bảng tên · 10 mẫu",TrainingController.scoreboardStyles.map{($0.name,Self.scoreboardSwatch($0))},
                 TrainingController.scoreboardStyleIndex){UserDefaults.standard.set($0,forKey:"scoreboardStyle040")}
        // 2 · Ngắm
        target=pages[1]
        header("Góc ngắm mặc định (camera quay về sau mỗi cú)")
        slider("Độ cao camera",  "tuneAimPitch038",0.35,0.95,fallback:0.57,format:{String(format:"%.0f°",$0*57.3)})
        slider("Độ gần (zoom)","tuneAimZoom038",0.8,1.4)
        slider("Góc nhìn (FOV)","tuneAimFOV038",30,52,fallback:38,format:{String(format:"%.0f°",$0)})
        header("Đường ngắm")
        let colours=TableScene.guideColors.map{$0.0}
        segmented("Màu đường ngắm",colours,UserDefaults.standard.integer(forKey:TableScene.tuneGuideColor)){UserDefaults.standard.set($0,forKey:TableScene.tuneGuideColor)}
        slider("Độ dày đường ngắm",TableScene.tuneGuideWidth,0.6,2.2)
        toggle("Gậy mờ đi khi che hướng ngắm / bi mục tiêu","tuneCueFade039",true)
        slider("Độ rõ của gậy khi mờ","tuneCueGhost040",0.2,0.8,fallback:0.42,format:{String(format:"%.0f%%",$0*100)})
        // 0.41 (owner): 7-colour power scale (tím = nhẹ … đỏ = mạnh), misty swipe trail, speed shown where the swipe ends.
        toggle("Thang lực 7 màu · vệt vuốt · số lực cuối cú","tunePowerFX041",true)
        header("Khoá hướng cơ")
        toggle("Chạm bi effect cũng khoá hướng (mặc định chỉ phím B)","tuneEffectLock037",false)
        header("Luyện mắt")
        toggle("Dự đoán trước: đánh xong mới hiện đường đúng và báo lệch bao nhiêu độ","tunePredictFirst037",false)
        toggle("Nút số tự hiện khi đường ngắm chạm băng","tuneAutoNumbers038",true)
        toggle("Đường chỉ dẫn mờ dần khi anh đánh đúng nhiều","tuneGuideSkill038",true)
        // 3 · Phím
        target=pages[2]
        header("Sắp xếp")
        target.addArrangedSubview(UIButton.lab("Sắp xếp phím · kéo từng phím tới vị trí muốn"){[weak self] in
            guard let self=self else{return};self.dismiss(animated:true){self.arrangeHUD?()}})
        target.addArrangedSubview(UIButton.lab("Đưa phím về vị trí mặc định"){[weak self] in self?.resetHUD?()})
        header("Lưu nhiều bố cục")
        let slots=UIStackView();slots.axis = .horizontal;slots.spacing=8;slots.distribution = .fillEqually
        for n in 1...3 {
            slots.addArrangedSubview(UIButton.lab("Lưu \(n)"){[weak self] in self?.saveLayout?(n)})
            slots.addArrangedSubview(UIButton.lab("Dùng \(n)"){[weak self] in self?.loadLayout?(n);self?.dismiss(animated:true)})
        }
        target.addArrangedSubview(slots)
        header("Hiển thị")
        slider("Kích thước phím","tuneHUDScale038",0.8,1.3)
        slider("Độ đậm của phím (thấp = trong hơn)","tuneHUDAlpha038",0.4,1)
        toggle("Phím tự mờ khi đang ngắm","tuneHUDFade037",true)
        // 4 · Vật lý
        target=pages[3]
        header("Thi đấu · đồng hồ cú")
        segmented("Đồng hồ cú (áp dụng ván kế tiếp)",TrainingController.shotClockPresets.map{$0.name.components(separatedBy:" · ").first ?? $0.name},
                  UserDefaults.standard.integer(forKey:"shotClock040")){UserDefaults.standard.set($0,forKey:"shotClock040")}
        let clockNote=UILabel();clockNote.numberOfLines=0;clockNote.font = .systemFont(ofSize:11);clockNote.textColor=UIColor(white:1,alpha:0.7)
        clockNote.text="Quốc tế: 30 s mỗi cú, mỗi người 1 lần GIA HẠN +30 s mỗi ván. Luyện thi đấu: 45 s, 2 lần. Nhanh: 20 s, 1 lần +15 s. Hết giờ = phạm lỗi, đối thủ có bi trong tay. Cú phá không tính giờ; đồng hồ dừng khi bi đang chạy."
        target.addArrangedSubview(clockNote)
        header("Lực đánh")
        slider("Lực đánh tối đa",  "tuneMaxPower036",0.6,1.3,format:{String(format:"%.1f m/s",8*$0)})
        header("Bàn và vật lý")
        target.addArrangedSubview(UIButton.lab("Mẫu loại bàn (nhanh / chuẩn / chậm) và thông số chi tiết"){[weak self] in
            guard let self=self else{return};self.dismiss(animated:true){self.openPhysics?()}})
        // 5 · Máy · Âm thanh
        target=pages[4]
        header("Độ mượt")
        segmented("Tần số khung hình khi bi chạy",["60 Hz","120 Hz (ProMotion, nóng hơn)"],Tuning.frameRate==120 ? 1:0){
            UserDefaults.standard.set($0==1 ? 120:60,forKey:"tuneFPS036")}
        let scales=[1.0,0.85,0.7]
        segmented("Độ phân giải 3D",["100 %","85 %","70 % (mát máy)"],scales.firstIndex{abs($0-Tuning.renderScale)<0.01} ?? 0){
            UserDefaults.standard.set(scales[$0],forKey:"tuneScale036")}
        toggle("Đồng bộ khung hình (bi trôi mượt, không giật)","tuneFramePacing039",true)
        target.addArrangedSubview(UIButton.lab("Chẩn đoán độ mượt · số đo cú vừa đánh"){[weak self] in
            guard let self=self else{return};self.dismiss(animated:true){self.openDiagnostics?()}})
        header("Âm thanh")
        slider("Âm lượng tiếng bi","tuneVolume037",0,1)
        // 0.41: owner's pack (sliced, 3 lực × biến thể + phá bi) vs the 0.17 set — A/B on the device.
        segmented("Bộ âm thanh",["Mới 0.41 · 18 mẫu","Cũ 0.17"],(UserDefaults.standard.object(forKey:PoolAudio.packKey) as? Int ?? 1)==1 ? 0:1){UserDefaults.standard.set($0==0 ? 1:0,forKey:PoolAudio.packKey)}
        target=body
        body.addArrangedSubview(UIButton.lab("Khôi phục mặc định tất cả tuỳ chỉnh"){[weak self] in
            for k in [TableScene.tuneBall,TableScene.tuneCloth,TableScene.tuneLight,TableScene.tuneDiamond,TableScene.tuneShadow,"tuneMaxPower036","tuneFPS036","tuneScale036","tuneHUDFade037","tuneEffectLock037","tunePredictFirst037","tuneVolume037",TableScene.tuneWeave,TableScene.tuneGuideColor,TableScene.tuneGuideWidth,"tuneHUDScale038","tuneHUDAlpha038","tuneAutoNumbers038","tuneGuideSkill038","tuneAimPitch038","tuneAimZoom038","tuneAimFOV038","tuneRealShadow039","tuneCueFade039","tuneFramePacing039",TableScene.tuneWeavePitch,"tuneCueGhost040"]{UserDefaults.standard.removeObject(forKey:k)}
            self?.resetHUD?();self?.changed?();self?.dismiss(animated:true)})
        show(0)
    }
    private lazy var target:UIStackView=body
    private func toggle(_ title:String,_ key:String,_ fallback:Bool){
        let l=UILabel();l.text=title;l.textColor = .white;l.font = .systemFont(ofSize:13,weight:.medium);l.numberOfLines=0
        let sw=UISwitch();sw.isOn=UserDefaults.standard.object(forKey:key) as? Bool ?? fallback;sw.onTintColor = .mint;sw.accessibilityIdentifier=key
        sw.addAction(UIAction{[weak self,weak sw]_ in UserDefaults.standard.set(sw?.isOn ?? fallback,forKey:key);self?.changed?()},for:.valueChanged)
        let r=UIStackView(arrangedSubviews:[l,sw]);r.spacing=12;r.alignment = .center;target.addArrangedSubview(r)
    }
    private func header(_ text:String){
        let l=UILabel();l.text=text.uppercased();l.textColor=UIColor.rgb(0xEAC583);l.font = .systemFont(ofSize:13,weight:.bold);target.addArrangedSubview(l)
    }
    private func slider(_ title:String,_ key:String,_ lo:Double,_ hi:Double,fallback:Double=1,format:((Double)->String)? = nil){
        let fmt=format ?? {String(format:"%d %%",Int(($0*100).rounded()))}
        let label=UILabel();label.textColor = .white;label.font = .systemFont(ofSize:13,weight:.medium)
        let current=Tuning.value(key,fallback);label.text="\(title)  ·  \(fmt(current))"
        let s=UISlider();s.minimumValue=Float(lo);s.maximumValue=Float(hi);s.value=Float(current);s.tintColor = .mint;s.accessibilityLabel=title
        s.addAction(UIAction{[weak s,weak label]_ in guard let s=s else{return};label?.text="\(title)  ·  \(fmt(Double(s.value)))"},for:.valueChanged)
        // Apply on release: cloth/diamond changes rebuild the table geometry.
        for event:UIControl.Event in [.touchUpInside,.touchUpOutside]{
            s.addAction(UIAction{[weak self,weak s]_ in guard let s=s else{return};UserDefaults.standard.set(Double(s.value),forKey:key);self?.changed?()},for:event)
        }
        let g=UIStackView(arrangedSubviews:[label,s]);g.axis = .vertical;g.spacing=4;target.addArrangedSubview(g)
    }
    /// Horizontal strip of picture swatches (cloth colours, scoreboard styles); the chosen one gets a gold ring.
    private func swatches(_ title:String,_ items:[(String,UIImage)],_ selected:Int,_ set:@escaping(Int)->Void){
        let label=UILabel();label.text=title;label.textColor = .white;label.font = .systemFont(ofSize:13,weight:.medium);label.numberOfLines=0
        let strip=UIStackView();strip.axis = .horizontal;strip.spacing=10;strip.alignment = .top
        let scroll=UIScrollView();scroll.showsHorizontalScrollIndicator=false;scroll.translatesAutoresizingMaskIntoConstraints=false
        strip.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(strip)
        NSLayoutConstraint.activate([strip.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor),strip.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor),
                                     strip.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor),strip.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor),
                                     strip.heightAnchor.constraint(equalTo:scroll.frameLayoutGuide.heightAnchor)])
        var buttons:[UIButton]=[]
        func mark(_ chosen:Int){for (i,b) in buttons.enumerated(){b.layer.borderWidth = i==chosen ? 2.5:0}}
        for (index,item) in items.enumerated(){
            let b=UIButton(type:.custom);b.setImage(item.1,for:.normal);b.imageView?.contentMode = .scaleAspectFit
            b.layer.cornerRadius=10;b.layer.borderColor=UIColor.rgb(0xEAC583).cgColor;b.clipsToBounds=true
            b.accessibilityLabel=item.0;b.accessibilityIdentifier="Swatch-"+item.0
            let caption=UILabel();caption.text=item.0;caption.font = .systemFont(ofSize:10,weight:.semibold);caption.textColor = UIColor(white:1,alpha:0.85)
            caption.textAlignment = .center;caption.numberOfLines=2
            let cell=UIStackView(arrangedSubviews:[b,caption]);cell.axis = .vertical;cell.spacing=4;cell.alignment = .center
            b.widthAnchor.constraint(equalToConstant:item.1.size.width).isActive=true;b.heightAnchor.constraint(equalToConstant:item.1.size.height).isActive=true
            caption.widthAnchor.constraint(equalToConstant:max(56,item.1.size.width)).isActive=true
            b.addAction(UIAction{[weak self]_ in set(index);mark(index);self?.changed?()},for:.touchUpInside)
            buttons.append(b);strip.addArrangedSubview(cell)
        }
        mark(selected)
        scroll.heightAnchor.constraint(equalToConstant:(items.first?.1.size.height ?? 48)+34).isActive=true
        let g=UIStackView(arrangedSubviews:[label,scroll]);g.axis = .vertical;g.spacing=6;target.addArrangedSubview(g)
    }
    /// A cloth sample: the colour with a woven grain, like the swatches on a cloth card.
    static func clothSwatch(_ color:UIColor)->UIImage{
        UIGraphicsImageRenderer(size:CGSize(width:56,height:44)).image{ctx in
            color.setFill();ctx.fill(CGRect(x:0,y:0,width:56,height:44))
            for y in stride(from:0,to:44,by:2){for x in stride(from:(y/2)%2,to:56,by:2){
                UIColor(white:(x*7+y*13)%5==0 ? 0:1,alpha:0.10).setFill();ctx.fill(CGRect(x:CGFloat(x),y:CGFloat(y),width:1.4,height:1.4))}}
        }
    }
    /// A miniature of a scoreboard style (two plates, scores, centre, one lit lamp).
    static func scoreboardSwatch(_ s:TrainingController.ScoreboardStyle)->UIImage{
        UIGraphicsImageRenderer(size:CGSize(width:116,height:30)).image{ctx in
            UIColor(white:0.12,alpha:1).setFill();ctx.fill(CGRect(x:0,y:0,width:116,height:30))
            let bar=UIBezierPath(roundedRect:CGRect(x:4,y:8,width:108,height:15),cornerRadius:min(6,s.radius*0.6));bar.addClip()
            s.plates.0.setFill();ctx.fill(CGRect(x:4,y:8,width:38,height:15));s.score.setFill();ctx.fill(CGRect(x:42,y:8,width:10,height:15))
            s.centre.setFill();ctx.fill(CGRect(x:52,y:8,width:12,height:15));s.score.setFill();ctx.fill(CGRect(x:64,y:8,width:10,height:15))
            s.plates.1.setFill();ctx.fill(CGRect(x:74,y:8,width:38,height:15))
            s.lamp.setFill();ctx.cgContext.fillEllipse(in:CGRect(x:8,y:13,width:5,height:5))
            s.text.withAlphaComponent(0.8).setFill();ctx.fill(CGRect(x:16,y:14.5,width:20,height:2));ctx.fill(CGRect(x:80,y:14.5,width:20,height:2))
            if s.frame != .clear {s.frame.setStroke();bar.lineWidth=1.5;bar.stroke()}
        }
    }
    private func segmented(_ title:String,_ items:[String],_ selected:Int,_ set:@escaping(Int)->Void){
        let label=UILabel();label.text=title;label.textColor = .white;label.font = .systemFont(ofSize:13,weight:.medium)
        let c=UISegmentedControl(items:items);c.selectedSegmentIndex=selected
        c.addAction(UIAction{[weak self,weak c]_ in guard let c=c else{return};set(c.selectedSegmentIndex);self?.changed?()},for:.valueChanged)
        let g=UIStackView(arrangedSubviews:[label,c]);g.axis = .vertical;g.spacing=4;target.addArrangedSubview(g)
    }
    @objc private func done(){dismiss(animated:true)}
}

// MARK: - 0.37 Sảnh chính (owner: "dễ tìm, dễ nhìn, dễ nắm bắt")
/// Three colour-coded cards; every feature is at most two taps away. Colour = mode, gold = primary action only.
final class LobbyController:UIViewController {
    struct Action {let title:String;let icon:String;let id:String;let run:()->Void}
    struct Card {let title:String;let subtitle:String;let icon:String;let color:UIColor;let actions:[Action]}
    var cards:[Card]=[]
    var footer:[Action]=[]
    static let practice=UIColor.rgb(0x2FA36E),match=UIColor.rgb(0xE8833A),profile=UIColor.rgb(0x3D86DA),gold=UIColor.rgb(0xEAC583)
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override var prefersStatusBarHidden:Bool{true}
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor=UIColor.rgb(0x0E1114);view.accessibilityIdentifier="Lobby"
        let glow=CAGradientLayer();glow.type = .radial;glow.colors=[UIColor.rgb(0x16473A).withAlphaComponent(0.55).cgColor,UIColor.clear.cgColor]
        glow.startPoint=CGPoint(x:0.5,y:0.0);glow.endPoint=CGPoint(x:1.1,y:1.0);glow.frame=UIScreen.main.bounds;view.layer.insertSublayer(glow,at:0)
        let title=UILabel();title.attributedText={
            let t=NSMutableAttributedString(string:"ZOKER POOL",attributes:[.font:UIFont.systemFont(ofSize:30,weight:.heavy),.foregroundColor:UIColor.white,.kern:2])
            t.append(NSAttributedString(string:"  TRAINER",attributes:[.font:UIFont.systemFont(ofSize:16,weight:.bold),.foregroundColor:Self.gold,.kern:5]))
            return t}()
        let row=UIStackView();row.axis = .horizontal;row.spacing=14;row.distribution = .fillEqually;row.alignment = .fill
        for card in cards{row.addArrangedSubview(makeCard(card))}
        let foot=UIStackView();foot.axis = .horizontal;foot.spacing=10;foot.distribution = .fillEqually
        for a in footer{foot.addArrangedSubview(chip(a))}
        let main=UIStackView(arrangedSubviews:[title,row,foot]);main.axis = .vertical;main.spacing=14;main.translatesAutoresizingMaskIntoConstraints=false
        view.addSubview(main)
        let g=view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([main.leadingAnchor.constraint(equalTo:g.leadingAnchor,constant:20),main.trailingAnchor.constraint(equalTo:g.trailingAnchor,constant:-20),
            main.topAnchor.constraint(equalTo:g.topAnchor,constant:12),main.bottomAnchor.constraint(lessThanOrEqualTo:g.bottomAnchor,constant:-10),
            foot.heightAnchor.constraint(equalToConstant:40)])
    }
    private func makeCard(_ c:Card)->UIView{
        let v=UIView();v.backgroundColor=UIColor.rgb(0x171B20);v.layer.cornerRadius=18;v.layer.borderWidth=1;v.layer.borderColor=c.color.withAlphaComponent(0.55).cgColor
        v.accessibilityIdentifier="LobbyCard-"+c.title
        let bar=UIView();bar.backgroundColor=c.color;bar.layer.cornerRadius=2
        let icon=UIImageView(image:UIImage(systemName:c.icon,withConfiguration:UIImage.SymbolConfiguration(pointSize:22,weight:.bold)));icon.tintColor=c.color
        let t=UILabel();t.text=c.title;t.font = .systemFont(ofSize:20,weight:.bold);t.textColor = .white
        let s=UILabel();s.text=c.subtitle;s.font = .systemFont(ofSize:12,weight:.medium);s.textColor=UIColor(white:0.72,alpha:1);s.numberOfLines=2
        let head=UIStackView(arrangedSubviews:[icon,t]);head.spacing=8;head.alignment = .center
        let list=UIStackView(arrangedSubviews:c.actions.map{action(button:$0,color:c.color)});list.axis = .vertical;list.spacing=8
        let stack=UIStackView(arrangedSubviews:[bar,head,s,list]);stack.axis = .vertical;stack.spacing=8;stack.translatesAutoresizingMaskIntoConstraints=false
        v.addSubview(stack)
        NSLayoutConstraint.activate([bar.heightAnchor.constraint(equalToConstant:4),stack.leadingAnchor.constraint(equalTo:v.leadingAnchor,constant:14),stack.trailingAnchor.constraint(equalTo:v.trailingAnchor,constant:-14),
            stack.topAnchor.constraint(equalTo:v.topAnchor,constant:12),stack.bottomAnchor.constraint(lessThanOrEqualTo:v.bottomAnchor,constant:-12)])
        return v
    }
    private func action(button a:Action,color:UIColor)->UIButton{
        var cfg=UIButton.Configuration.filled();cfg.title=a.title;cfg.image=UIImage(systemName:a.icon);cfg.imagePadding=8;cfg.imagePlacement = .leading
        cfg.baseBackgroundColor=color.withAlphaComponent(0.16);cfg.baseForegroundColor = .white;cfg.cornerStyle = .large
        cfg.contentInsets=NSDirectionalEdgeInsets(top:9,leading:10,bottom:9,trailing:10)
        cfg.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{x in var x=x;x.font=UIFont.systemFont(ofSize:14,weight:.semibold);return x}
        let b=UIButton(configuration:cfg);b.contentHorizontalAlignment = .leading;b.accessibilityIdentifier=a.id
        b.addAction(UIAction{[weak self]_ in self?.dismiss(animated:true){a.run()}},for:.touchUpInside)
        return b
    }
    private func chip(_ a:Action)->UIButton{
        var cfg=UIButton.Configuration.gray();cfg.title=a.title;cfg.image=UIImage(systemName:a.icon);cfg.imagePadding=6;cfg.baseForegroundColor=UIColor(white:0.9,alpha:1);cfg.cornerStyle = .capsule
        cfg.background.backgroundColor=UIColor(white:1,alpha:0.08)
        let b=UIButton(configuration:cfg);b.accessibilityIdentifier=a.id
        b.addAction(UIAction{[weak self]_ in self?.dismiss(animated:true){a.run()}},for:.touchUpInside)
        return b
    }
}
