import UIKit
import UniformTypeIdentifiers

final class SettingsController:UIViewController,UIDocumentPickerDelegate {
    var apply:(([String:NSNumber],Double)->Void)?
    private var values:[String:NSNumber]
    private var sensitivity:Double
    private let body=UIStackView()
    init(settings:[String:NSNumber],sensitivity:Double){values=settings;self.sensitivity=sensitivity;super.init(nibName:nil,bundle:nil)}
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
        body.addArrangedSubview(UIButton.lab("Xuất mẫu dữ liệu hiệu chuẩn"){[weak self]in self?.exportTemplate()})
        let contactSwitch=UISwitch();contactSwitch.isOn=values["coupledCushions"]?.boolValue ?? true
        contactSwitch.addAction(UIAction{[weak self,weak contactSwitch]_ in self?.values["coupledCushions"]=NSNumber(value:contactSwitch?.isOn ?? false)},for:.valueChanged)
        let contactLabel=UILabel();contactLabel.text="A1 · tiếp xúc 3D băng + mặt đá";contactLabel.textColor = .white
        body.addArrangedSubview(UIStackView(arrangedSubviews:[contactLabel,contactSwitch]))
        slider("Cản lăn — thấp: bi chạy xa","rolling",0.003,0.04,0.012)
        slider("Ma sát trượt — thời gian chuyển sang lăn","sliding",0.08,0.35,0.20)
        slider("Đàn hồi băng — cao: giữ lực nhiều","railRestitution",0.4,0.98,0.82)
        slider("ZUPE: giảm độ nảy theo lực — 0 là bản gốc","railSpeedSensitivity",0,0.08,0)
        slider("Ma sát băng — ảnh hưởng ép phê","railFriction",0,0.35,0.16)
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
        slider("Giảm ép phê ngang (rad/s²)","spinDecay",1,20,7)
        slider("Độ nhạy vuốt cơ","sensitivity",0.5,1.8,1)
        body.addArrangedSubview(UIButton.lab("Khôi phục mặc định"){[weak self]in
            guard let self=self else{return};self.values=BLWorld().settings;self.sensitivity=1
            self.apply?(self.values,self.sensitivity);self.dismiss(animated:true)
        })
        let limits=UILabel();limits.numberOfLines=0;limits.textColor=UIColor(white:0.65,alpha:1);limits.font = .systemFont(ofSize:12)
        limits.text="Hiệu chuẩn: va chạm băng dạng xung lực gần đúng, lòng lỗ dùng vùng bắt 2D. A1 dùng xung lực 3D, ma sát Coulomb hai chiều và ràng buộc mặt đá khi bi tiếp xúc. Đây chưa phải mô hình băng biến dạng Mathavan/Stronge. Thông số fit của mô hình cũ cần đo lại. Bản 0.14: throw theo ma sát phụ thuộc tốc độ (TP A.14), squirt (TP A.31, khối lượng đầu cơ giả định) và tốc độ bi theo điểm chạm (TP A.30). Chưa hiệu chuẩn băng biến dạng, độ ẩm, swerve hoặc Jump/Massé. Hãy đối chiếu bằng bài đo trước khi dùng để suy ra đường thi đấu."
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
                    for i in 0..<4{self.values["railBounce\(i)"]=self.values["railRestitution"] ?? 0.82;self.values["railGrip\(i)"]=self.values["railFriction"] ?? 0.16}
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
