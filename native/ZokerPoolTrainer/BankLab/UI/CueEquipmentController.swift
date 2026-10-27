import UIKit
import SceneKit

/// Native equipment changes both the visible mesh and the C++ experimental shot profile.
final class CueEquipmentController:UIViewController {
    var apply:(([String:NSNumber])->Void)?
    private var values:[String:NSNumber]
    private let table:TableScene
    private let preview=SCNView()
    private let enabled=UISwitch(),elevation=UISlider(),label=UILabel()
    private let types=UISegmentedControl(items:["Playing","Jump","Break"])
    init(settings:[String:NSNumber],table:TableScene){values=settings;self.table=table;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError()}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override func viewDidLoad(){
        super.viewDidLoad();title="Cơ 3D · Jump / Massé";view.backgroundColor = .ink
        navigationItem.rightBarButtonItem=UIBarButtonItem(barButtonSystemItem:.done,target:self,action:#selector(close))
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(scroll)
        let body=UIStackView();body.axis = .vertical;body.spacing=14;body.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(body)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor),scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),scroll.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor),body.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:20),body.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-20),body.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:12),body.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-20),body.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-40)])
        preview.heightAnchor.constraint(equalToConstant:180).isActive=true;preview.allowsCameraControl=true;preview.isPlaying=true;preview.autoenablesDefaultLighting=false
        preview.antialiasingMode = .multisampling4X;body.addArrangedSubview(preview)
        types.selectedSegmentIndex=values["cueType"]?.intValue ?? 0;body.addArrangedSubview(types)
        let toggle=UIStackView();let heading=UILabel();heading.text="Bật bộ giải 3D thử nghiệm trên bàn";heading.textColor = .white
        toggle.addArrangedSubview(heading);toggle.addArrangedSubview(enabled);body.addArrangedSubview(toggle)
        enabled.isOn=values["experimental3D"]?.boolValue ?? false
        elevation.minimumValue=0;elevation.maximumValue=90;elevation.value=values["cueElevationDegrees"]?.floatValue ?? 0
        elevation.accessibilityLabel="Góc nâng cơ";body.addArrangedSubview(elevation);label.textColor = .mint;label.numberOfLines=0;body.addArrangedSubview(label)
        let note=UILabel();note.numberOfLines=0;note.textColor=UIColor(white:0.76,alpha:1);note.font = .systemFont(ofSize:13)
        note.text="Thử Jump: chọn Jump, bật 3D, nâng 35–60°, đánh gần tâm. Thử massé: chọn Playing, nâng 55–75°, đặt ép phê ngang rồi dùng lực nhẹ. Cú đánh có thể chỉ hop hoặc không cong tùy thông số.\n\nChọn mẫu cơ và lưu vào bao trong Thư viện. Ba loại cơ dùng cấu hình vật lý minh hoạ của Zoker. Quỹ đạo, độ cao, va bi và xoáy lấy từ mô phỏng; tiếp xúc mặt đá/băng còn gần đúng, chưa hiệu chuẩn bằng cú thật. Tắt 3D để trở lại bộ giải 0.9."
        body.addArrangedSubview(note)
        for control in [types as UIControl,enabled as UIControl,elevation as UIControl]{control.addAction(UIAction{[weak self]_ in self?.changed()},for:.valueChanged)}
        changed()
    }
    private func changed(){
        values["cueType"]=NSNumber(value:types.selectedSegmentIndex)
        values["experimental3D"]=NSNumber(value:enabled.isOn)
        values["cueElevationDegrees"]=NSNumber(value:Double(elevation.value))
        table.selectCue(types.selectedSegmentIndex)
        preview.scene=table.cuePreviewScene()
        elevation.isEnabled=enabled.isOn
        let names=["Playing · 540 g · 12.5 mm","Jump · 310 g · 13.8 mm","Break · 560 g · 13.0 mm"]
        label.text="\(CueBag.cue(types.selectedSegmentIndex).title) · \(names[types.selectedSegmentIndex]) · \(Int(elevation.value))°\n"+(enabled.isOn ? "3D nghiên cứu đang bật":"Bộ giải 0.9 đang bật")
        apply?(values)
    }
    @objc private func close(){preview.isPlaying=false;dismiss(animated:true)}
}
