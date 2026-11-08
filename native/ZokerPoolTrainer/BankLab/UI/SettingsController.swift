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
        body.axis = .vertical;body.spacing=18;body.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(body)
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),scroll.bottomAnchor.constraint(equalTo:view.bottomAnchor),scroll.leadingAnchor.constraint(equalTo:view.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:view.trailingAnchor),body.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:20),body.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-24),body.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:20),body.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-20),body.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-40)])
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
        slider("Cản lăn — thấp: bi chạy xa","rolling",0.003,0.04,0.012)
        slider("Ma sát trượt — thời gian chuyển sang lăn","sliding",0.08,0.35,0.20)
        slider("Đàn hồi băng — cao: giữ lực nhiều","railRestitution",0.4,0.98,0.82)
        slider("ZUPE: giảm độ nảy theo lực — 0 là bản gốc","railSpeedSensitivity",0,0.08,0)
        slider("Ma sát băng — ảnh hưởng ép phê (0.31: 0,20 theo Mathavan 2010; 0,45 = cảm nhận bàn anh)","railFriction",0,0.6,0.20)
        let railSwitch=UISwitch();railSwitch.isOn=values["individualRails"]?.boolValue ?? false
        railSwitch.addAction(UIAction{[weak self,weak railSwitch]_ in self?.values["individualRails"]=NSNumber(value:railSwitch?.isOn ?? false)},for:.valueChanged)
        let railLabel=UILabel();railLabel.text="Dùng thông số riêng từng băng";railLabel.textColor = .white
        body.addArrangedSubview(UIStackView(arrangedSubviews:[railLabel,railSwitch]))
        for (i,name) in ["Trái","Phải","Đầu −Y","Đầu +Y"].enumerated(){
            slider("Băng \(name) · độ nảy","railBounce\(i)",0.4,0.98,0.82)
            slider("Băng \(name) · ma sát","railGrip\(i)",0,0.35,0.16)
        }
        slider("Đàn hồi bi–bi","ballRestitution",0.80,1,0.94)
        slider("Ma sát bi–bi khi trượt chậm μ₀ (giảm theo tốc độ, TP A.14)","ballFriction",0,0.12,0.118)
        slider("Truyền xoáy bi–bi (bánh răng) — ma sát khi trượt nhanh, 0.30: 0,05","ballFrictionMin",0,0.1,0.05)
        slider("Giảm ép phê ngang (rad/s²) — 0.31: 15 (công bố 5–15)","spinDecay",1,40,15)
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
    private func slider(_ title:String,_ key:String,_ lo:Double,_ hi:Double,_ fallback:Double){
        let label=UILabel();label.textColor = .white;label.font = .systemFont(ofSize:12,weight:.medium)
        let current=key=="sensitivity" ? sensitivity:(values[key]?.doubleValue ?? fallback)
        label.text=String(format:"%@  ·  %.3f",title,current)
        let s=UISlider();s.minimumValue=Float(lo);s.maximumValue=Float(hi);s.value=Float(current);s.tintColor = .mint
        s.accessibilityLabel=title
        s.addAction(UIAction{[weak self,weak s,weak label]_ in
            guard let self=self,let s=s else{return};let v=Double(s.value)
            if key=="sensitivity" {self.sensitivity=v}else{self.values[key]=NSNumber(value:v)}
            label?.text=String(format:"%@  ·  %.3f",title,v)
        },for:.valueChanged)
        let group=UIStackView(arrangedSubviews:[label,s]);group.axis = .vertical;group.spacing=5;body.addArrangedSubview(group)
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
    /// Active render cadence. 120 needs ProMotion (CADisableMinimumFrameDurationOnPhone is set); more heat.
    static var frameRate:Int{UserDefaults.standard.integer(forKey:"tuneFPS036")==120 ? 120:60}
    /// Fraction of the native pixel scale the 3D view renders at (1, 0.85, 0.7).
    static var renderScale:Double{value("tuneScale036",1)}
    /// Multiplier on the stroke speed (BLStrokeSpeed tops out at 8 m/s): 0.6 → 4.8 m/s, 1.3 → 10.4 m/s.
    static var maxPower:Double{value("tuneMaxPower036",1)}
}

final class CustomizeController:UIViewController {
    var changed:(()->Void)?
    var openPhysics:(()->Void)?
    var arrangeHUD:(()->Void)?
    var resetHUD:(()->Void)?
    private let body=UIStackView()
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override func viewDidLoad(){
        super.viewDidLoad();title="Tuỳ chỉnh";view.backgroundColor = .ink
        navigationController?.navigationBar.barStyle = .black
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Xong",style:.done,target:self,action:#selector(done))
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(scroll)
        body.axis = .vertical;body.spacing=14;body.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(body)
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),scroll.bottomAnchor.constraint(equalTo:view.bottomAnchor),scroll.leadingAnchor.constraint(equalTo:view.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:view.trailingAnchor),body.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:16),body.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-24),body.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:20),body.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-20),body.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-40)])
        header("Ánh sáng")
        slider("Độ sáng bi",TableScene.tuneBall,0.6,1.3)
        slider("Độ sáng mặt bàn (nỉ)",TableScene.tuneCloth,0.6,1.4)
        slider("Đèn bàn",TableScene.tuneLight,0.5,1.6)
        slider("Độ nổi kim cương / nút số",TableScene.tuneDiamond,0.8,2.0)
        header("Lực đánh và vật lý")
        slider("Lực đánh tối đa",  "tuneMaxPower036",0.6,1.3,format:{String(format:"%.1f m/s",8*$0)})
        body.addArrangedSubview(UIButton.lab("Hiệu chỉnh vật lý chi tiết (ma sát, băng, xoáy…)"){[weak self] in
            guard let self=self else{return};self.dismiss(animated:true){self.openPhysics?()}})
        header("Bố cục phím trên màn hình")
        body.addArrangedSubview(UIButton.lab("Sắp xếp phím · kéo từng phím tới vị trí muốn"){[weak self] in
            guard let self=self else{return};self.dismiss(animated:true){self.arrangeHUD?()}})
        body.addArrangedSubview(UIButton.lab("Đưa phím về vị trí mặc định"){[weak self] in self?.resetHUD?()})
        header("Độ mượt")
        segmented("Tần số khung hình khi bi chạy",["60 Hz","120 Hz (ProMotion, nóng hơn)"],Tuning.frameRate==120 ? 1:0){
            UserDefaults.standard.set($0==1 ? 120:60,forKey:"tuneFPS036")}
        let scales=[1.0,0.85,0.7]
        segmented("Độ phân giải 3D",["100 %","85 %","70 % (mát máy)"],scales.firstIndex{abs($0-Tuning.renderScale)<0.01} ?? 0){
            UserDefaults.standard.set(scales[$0],forKey:"tuneScale036")}
        body.addArrangedSubview(UIButton.lab("Khôi phục mặc định tất cả tuỳ chỉnh"){[weak self] in
            for k in [TableScene.tuneBall,TableScene.tuneCloth,TableScene.tuneLight,TableScene.tuneDiamond,"tuneMaxPower036","tuneFPS036","tuneScale036"]{UserDefaults.standard.removeObject(forKey:k)}
            self?.resetHUD?();self?.changed?();self?.dismiss(animated:true)})
    }
    private func header(_ text:String){
        let l=UILabel();l.text=text.uppercased();l.textColor=UIColor.rgb(0xEAC583);l.font = .systemFont(ofSize:13,weight:.bold);body.addArrangedSubview(l)
    }
    private func slider(_ title:String,_ key:String,_ lo:Double,_ hi:Double,format:((Double)->String)? = nil){
        let fmt=format ?? {String(format:"%d %%",Int(($0*100).rounded()))}
        let label=UILabel();label.textColor = .white;label.font = .systemFont(ofSize:13,weight:.medium)
        let current=Tuning.value(key,1);label.text="\(title)  ·  \(fmt(current))"
        let s=UISlider();s.minimumValue=Float(lo);s.maximumValue=Float(hi);s.value=Float(current);s.tintColor = .mint;s.accessibilityLabel=title
        s.addAction(UIAction{[weak s,weak label]_ in guard let s=s else{return};label?.text="\(title)  ·  \(fmt(Double(s.value)))"},for:.valueChanged)
        // Apply on release: cloth/diamond changes rebuild the table geometry.
        for event:UIControl.Event in [.touchUpInside,.touchUpOutside]{
            s.addAction(UIAction{[weak self,weak s]_ in guard let s=s else{return};UserDefaults.standard.set(Double(s.value),forKey:key);self?.changed?()},for:event)
        }
        let g=UIStackView(arrangedSubviews:[label,s]);g.axis = .vertical;g.spacing=4;body.addArrangedSubview(g)
    }
    private func segmented(_ title:String,_ items:[String],_ selected:Int,_ set:@escaping(Int)->Void){
        let label=UILabel();label.text=title;label.textColor = .white;label.font = .systemFont(ofSize:13,weight:.medium)
        let c=UISegmentedControl(items:items);c.selectedSegmentIndex=selected
        c.addAction(UIAction{[weak self,weak c]_ in guard let c=c else{return};set(c.selectedSegmentIndex);self?.changed?()},for:.valueChanged)
        let g=UIStackView(arrangedSubviews:[label,c]);g.axis = .vertical;g.spacing=4;body.addArrangedSubview(g)
    }
    @objc private func done(){dismiss(animated:true)}
}
