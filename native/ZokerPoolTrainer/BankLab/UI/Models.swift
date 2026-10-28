import UIKit

struct BallState: Codable {
    let id: Int
    var x: Double
    var y: Double
    var height: Double? = nil
    var vertical: Double? = nil
    var sunk: Bool = false
    var wx: Double = 0
    var wy: Double = 0
    var spin: Double = 0
    var rails: Int = 0
    var vx: Double? = nil
    var vy: Double? = nil
    var qx:Double? = nil
    var qy:Double? = nil
    var qz:Double? = nil
    var qw:Double? = nil
    init(id: Int, x: Double, y: Double) { self.id=id; self.x=x; self.y=y }
    init(_ d: [String:NSNumber]) {
        id=d["id"]!.intValue; x=d["x"]!.doubleValue; y=d["y"]!.doubleValue
        height=d["height"]?.doubleValue;vertical=d["vertical"]?.doubleValue
        vx=d["vx"]?.doubleValue; vy=d["vy"]?.doubleValue
        qx=d["qx"]?.doubleValue;qy=d["qy"]?.doubleValue;qz=d["qz"]?.doubleValue;qw=d["qw"]?.doubleValue
        sunk=d["sunk"]?.boolValue ?? false
        wx=d["wx"]?.doubleValue ?? 0; wy=d["wy"]?.doubleValue ?? 0
        spin=d["spin"]?.doubleValue ?? 0; rails=d["rails"]?.intValue ?? 0
    }
    // A layout is at rest, but retains each ball's visible orientation for retry.
    var dictionary: [String:NSNumber] { ["id":NSNumber(value:id),"x":NSNumber(value:x),"y":NSNumber(value:y),"sunk":NSNumber(value:sunk),"qx":NSNumber(value:qx ?? 0),"qy":NSNumber(value:qy ?? 0),"qz":NSNumber(value:qz ?? 0),"qw":NSNumber(value:qw ?? 1)] }
}
struct Layout: Codable { var name: String; var balls:[BallState]; var angle:Double }
/// Cú đã lưu (thư viện cú đẹp): đủ đầu vào để mô phỏng lại đúng cú (solver tất định).
struct SavedShot: Codable {
    var name: String
    var date: Date
    var balls: [BallState]
    var aimAngle: Double
    var speed: Double
    var side: Double
    var top: Double
    var elevation: Double
    var cueType: Int
    /// Hướng đánh thật gửi cho solver (sau hiệu chỉnh hình học cơ); nil với bản lưu cũ.
    var strikeAngle: Double? = nil
    static let key="savedShots015"
    static func all()->[SavedShot]{
        guard let data=UserDefaults.standard.data(forKey:key) else{return []}
        return (try? JSONDecoder().decode([SavedShot].self,from:data)) ?? []
    }
    static func store(_ shots:[SavedShot]){
        if let data=try? JSONEncoder().encode(Array(shots.suffix(60))){UserDefaults.standard.set(data,forKey:key)}
    }
}
final class DrillsController:UITableViewController {
    var load:((Int)->Void)?
    private lazy var headings=["KICK · 1 BĂNG","KICK · 2 BĂNG","KICK · 3 BĂNG","BANK · 1 BĂNG","BANK · 2 BĂNG","BANK · 3 BĂNG","KIỂM SOÁT & VÀO LỖ","ĐO BÀN / TỰ DO"]
    private lazy var groups:[[Int]]={
        let drills=Drill.all
        return (1...3).map{r in drills.indices.filter{drills[$0].kick && drills[$0].rails==r}} +
            (1...3).map{r in drills.indices.filter{!drills[$0].kick && drills[$0].rails==r}} +
            [drills.indices.filter{drills[$0].goal != nil || (drills[$0].rails==0 && $0>=8 && $0<=13)},
             drills.indices.filter{drills[$0].rails==0 && drills[$0].goal==nil && !($0>=8 && $0<=13)} + drills.indices.filter{drills[$0].rails>3}]
    }()
    override func viewDidLoad(){
        super.viewDidLoad();title="\(Drill.all.count) bài luyện · Chọn kỹ năng"
        tableView.backgroundColor=UIColor(red:0.09,green:0.05,blue:0.025,alpha:1)
        navigationController?.navigationBar.barStyle = .black
        tableView.rowHeight=UITableView.automaticDimension;tableView.estimatedRowHeight=100
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Xong",style:.done,target:self,action:#selector(close))
    }
    @objc private func close(){dismiss(animated:true)}
    override func numberOfSections(in tableView:UITableView)->Int{groups.count}
    override func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int{groups[section].count}
    override func tableView(_ tableView:UITableView,titleForHeaderInSection section:Int)->String?{headings[section]}
    override func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell{
        let drill=Drill.all[groups[indexPath.section][indexPath.row]]
        let cell=UITableViewCell(style:.subtitle,reuseIdentifier:nil)
        cell.backgroundColor=UIColor(red:0.19,green:0.11,blue:0.065,alpha:1)
        cell.textLabel?.textColor=MenuSkin.gold;cell.detailTextLabel?.textColor=UIColor(white:0.85,alpha:1)
        cell.imageView?.image=UIImage(systemName:indexPath.section==3 ? "scope":"circle.dotted")
        cell.imageView?.tintColor=MenuSkin.gold
        cell.textLabel?.text=drill.title;cell.textLabel?.font = .systemFont(ofSize:16,weight:.semibold)
        cell.detailTextLabel?.text=drill.note;cell.detailTextLabel?.numberOfLines=3
        cell.detailTextLabel?.font = .systemFont(ofSize:12)
        cell.accessoryType = .disclosureIndicator;return cell
    }
    override func tableView(_ tableView:UITableView,didSelectRowAt indexPath:IndexPath){
        tableView.deselectRow(at:indexPath,animated:true)
        let index=groups[indexPath.section][indexPath.row],drill=Drill.all[groups[indexPath.section][indexPath.row]]
        let lesson=DrillLessonController(drill:drill)
        lesson.start={[weak self] in guard let self=self else{return};self.dismiss(animated:true){self.load?(index)}}
        navigationController?.pushViewController(lesson,animated:true)
    }
}
struct PracticeGoal {
    let x:Double,y:Double,radius:Double
    let potRequired:Bool
    var potOnly=false
}
struct PracticeRecord:Codable {
    let date:Date
    let drill:String
    let passed:Bool
    let speed:Double
    let side:Double
    let top:Double
}
struct Drill {
    let title:String
    let note:String
    let rails:Int
    let kick:Bool
    let balls:[BallState]
    let angle:Double
    var goal:PracticeGoal? = nil
    var level:Int = 1
    var levelName:String { ["Cơ bản","Trung cấp","Nâng cao"][max(0,min(2,level-1))] }
    var familyName:String { kick ? "Kick · bi cái qua băng" : (rails>0 ? "Bank · bi mục tiêu qua băng" : "Kiểm soát đường bi") }
    var formula:String {
        let mirror="Bàn chuẩn 2,54 × 1,27 m; R = 28,575 mm. Dùng đường biên tâm bi cách mũi băng một khoảng bán kính tiếp xúc ngang. Qua biên x = a: x′ = 2a − x; qua y = b: y′ = 2b − y. Với 2–3 băng, phản chiếu theo thứ tự ngược từ đích về điểm xuất phát, rồi gập đường thẳng trở lại bàn. Không phản xạ xuyên miệng lỗ. θ = atan2(Δy, Δx). Góc tới/bật bằng nhau chỉ là mốc gương lý tưởng."
        if rails>0 && kick { return "Kick \(rails) băng: phản chiếu tâm bi 1 để lấy một hướng khởi đầu. Khi kiểm tra chạm bi, dùng khoảng cách hai tâm 2R, không coi bi đích là một điểm.\n\n"+mirror+"\n\nSau đó chỉnh bằng dự báo native với lực, xoáy và ma sát hiện tại; không cộng/trừ một góc effect cố định." }
        if rails>0 { return "Bank \(rails) băng: phản chiếu đích lỗ để tìm hướng bi 1. Với đơn vị hướng d của bi 1, tâm bi ma G = O − 2R·d; hướng ban đầu bi cái là C → G.\n\n"+mirror+"\n\nSau va bi còn có throw và spin truyền sang bi 1; trạng thái đó phải được giữ tới băng tiếp theo. Thử cả hai phía effect, ghi góc và tốc độ ra mỗi băng." }
        return "Giữ hướng và điểm chạm làm mốc; chỉ thay một biến mỗi lượt (lực, ép phê hoặc góc). Đường gương là ước lượng hình học ban đầu, không tính đầy đủ độ nảy, ma sát, throw và xoáy của cú đánh."
    }
    var coaching:String { "Đánh 10 lượt cùng thế bi. Mục tiêu luyện: đạt ít nhất 7/10, không scratch. Nếu lệch, chỉ đổi một thông số mỗi lần và ghi lại lực, ép phê, số băng và kết quả. Góc gương là mốc ngắm để bắt đầu; bộ mô phỏng và bàn thật có thể lệch do ma sát, tốc độ và độ nảy." }
    private static let foundation:[Drill] = [
        Drill(title:"Tự do",note:"Đặt bi ở góc nhìn trên. Bank: bi mục tiêu chạm băng; kick: bi cái chạm băng trước khi gặp bi mục tiêu.",rails:0,kick:false,balls:[BallState(id:0,x:0,y:-0.72),BallState(id:1,x:0.13,y:0.30)],angle:1.43),
        Drill(title:"Kick · 1 băng",note:"Đưa bi cái chạm 1 băng rồi mới chạm bi số 1. Điểm đạt tính theo lần va chạm đầu tiên.",rails:1,kick:true,balls:[BallState(id:0,x:-0.25,y:-0.72),BallState(id:1,x:-0.23,y:0.56)],angle:0.91),
        Drill(title:"Kick · 2 băng",note:"Chạm đúng 2 băng trước khi gặp bi số 1. Hãy thử thay lực và ép phê, rồi xem lại đường bi.",rails:2,kick:true,balls:[BallState(id:0,x:-0.28,y:-0.68),BallState(id:1,x:0.20,y:0.40)],angle:0.49),
        Drill(title:"Kick · 3 băng",note:"Bi cái chạm đúng 3 băng trước lần va bi đầu tiên. Nút kim cương là tọa độ tham khảo, không phải công thức bảo đảm trúng.",rails:3,kick:true,balls:[BallState(id:0,x:-0.30,y:-0.70),BallState(id:1,x:0.17,y:0.50)],angle:0.36),
        Drill(title:"Kick · 4 băng",note:"Thử chuỗi 4 băng. Độ dài đường đi nhạy với lực, độ trượt vải và ma sát băng.",rails:4,kick:true,balls:[BallState(id:0,x:-0.25,y:-0.60),BallState(id:1,x:0.15,y:0.38)],angle:0.29),
        Drill(title:"Bank · 2 băng",note:"Đánh bi số 1 vào lỗ sau đúng 2 lần chạm băng. Bi cái vào lỗ sẽ tính lỗi.",rails:2,kick:false,balls:[BallState(id:0,x:-0.30,y:-0.70),BallState(id:1,x:-0.08,y:-0.13)],angle:1.18),
        Drill(title:"Bank · 3 băng",note:"Bi mục tiêu vào lỗ sau đúng 3 băng. Dự báo trắng/vàng dùng tốc độ đã chọn, hiển thị bi cái và bi 1 trong tối đa 12 giây.",rails:3,kick:false,balls:[BallState(id:0,x:0.22,y:-0.72),BallState(id:1,x:0.06,y:-0.15)],angle:1.84),
        Drill(title:"Bank · 4 băng",note:"Bi mục tiêu vào lỗ sau đúng 4 băng. Đây là bài tự tìm đường, không có sẵn lời giải đã hiệu chuẩn.",rails:4,kick:false,balls:[BallState(id:0,x:-0.20,y:-0.76),BallState(id:1,x:-0.06,y:-0.20)],angle:1.32),
        Drill(title:"Đo độ lăn",note:"Cú thẳng không xoáy. So quãng dừng ở cùng tốc độ ban đầu để hiệu chỉnh cản lăn; kết hợp video chậm để đo tốc độ đầu trên bàn thật.",rails:0,kick:false,balls:[BallState(id:0,x:0,y:-0.90)],angle:Double.pi/2),
        Drill(title:"Đo độ nảy",note:"Đánh vuông góc băng dài. So tốc độ và quãng đường sau nảy để chỉnh hệ số đàn hồi. Tắt ép phê trước khi đo.",rails:0,kick:false,balls:[BallState(id:0,x:0,y:0.34)],angle:0),
        Drill(title:"Kiểm soát lực · Vùng dừng",note:"Đưa tâm bi cái dừng trong vòng tròn, không vào lỗ. Luyện 10 cú, mục tiêu tự đặt 7/10. Thế bi BankLab tự thiết kế; tham khảo cách tổ chức và ghi điểm của PoolShot.",rails:0,kick:false,balls:[BallState(id:0,x:0,y:-0.85)],angle:Double.pi/2,goal:PracticeGoal(x:0,y:0.55,radius:0.15,potRequired:false)),
        Drill(title:"Stop shot · Giữ bi cái",note:"Đánh bi 1 vào lỗ và giữ tâm bi cái trong vòng tròn gần điểm tiếp xúc. Giữ thế bi, thử lực và điểm chạm; 10 cú/lượt. Đây là thế bi tự thiết kế của BankLab.",rails:0,kick:false,balls:[BallState(id:0,x:0.02,y:0.01),BallState(id:1,x:0.33,y:0.63)],angle:atan2(0.62,0.31),goal:PracticeGoal(x:0.3044,y:0.5789,radius:0.10,potRequired:true)),
        Drill(title:"Cu-lê · Theo vào vùng",note:"Bi 1 vào lỗ; tâm bi cái dừng trong vòng tròn phía trước. Thay điểm chạm trên tâm và lực, tránh scratch. Thế bi BankLab tự thiết kế, mục tiêu thử 7/10.",rails:0,kick:false,balls:[BallState(id:0,x:0.02,y:0.01),BallState(id:1,x:0.33,y:0.63)],angle:atan2(0.62,0.31),goal:PracticeGoal(x:0.50,y:0.97,radius:0.12,potRequired:true)),
        Drill(title:"Trô · Lùi vào vùng",note:"Bi 1 vào lỗ; tâm bi cái lùi và dừng trong vòng tròn phía sau. Theo dõi ảnh hưởng của khoảng cách và lực. Thế bi BankLab tự thiết kế; không phải bài sao chép từ thư viện PoolShot.",rails:0,kick:false,balls:[BallState(id:0,x:0.02,y:0.01),BallState(id:1,x:0.33,y:0.63)],angle:atan2(0.62,0.31),goal:PracticeGoal(x:0.17,y:0.31,radius:0.12,potRequired:true)),
        Drill(title:"Bank · 1 băng",note:"Bi 1 vào một lỗ bất kỳ sau đúng một băng; bi cái không scratch. Giữ thế bi để so góc, lực và ép phê. Thế bi BankLab tự thiết kế.",rails:1,kick:false,balls:[BallState(id:0,x:-0.28,y:-0.65),BallState(id:1,x:0.06,y:0.20)],angle:1.19)
    ]
    static let all:[Drill] = {
        var result=foundation
        for (i,y) in [-0.2,0.1,0.4,0.7,1.0].enumerated(){
            result.append(Drill(title:"Lực \(i+1)/5 · Dừng đúng vùng",note:"Một bi, năm cự ly. Giữ hướng thẳng, tập cùng điểm chạm; mục tiêu 7/10. Tâm bi phải dừng trong vòng 9 cm, không scratch. Thế bi Zoker tự thiết kế.",rails:0,kick:false,
                balls:[BallState(id:0,x:0,y:-0.9)],angle:Double.pi/2,goal:PracticeGoal(x:0,y:y,radius:0.09,potRequired:false)))
        }
        for degrees in [15,30,45,60]{for mirror in [-1.0,1.0]{
            let length=hypot(0.42,0.755),dx=0.42/length,dy=0.755/length
            let radians=Double(degrees)*Double.pi/180
            let ix=dx*cos(radians)-dy*sin(radians),iy=dx*sin(radians)+dy*cos(radians)
            let gx=0.25-dx*0.05715,gy=0.55-dy*0.05715
            let cue=BallState(id:0,x:(gx-ix*0.65)*mirror,y:gy-iy*0.65)
            let object=BallState(id:1,x:0.25*mirror,y:0.55)
            let aim=atan2(iy,ix*mirror)
            result.append(Drill(title:"Cắt \(mirror<0 ? "trái":"phải") · \(degrees)°",note:"Đưa bi 1 vào lỗ, bi cái không scratch. Góc nạp sẵn là hình học ban đầu; lực, throw và ép phê có thể cần chỉnh. Đánh 10 cú cùng thế bi, so hai bên. Bài do Zoker tự thiết kế, không chép sơ đồ PoolShot.",rails:0,kick:false,
                balls:[cue,object],angle:aim,goal:PracticeGoal(x:0,y:0,radius:0,potRequired:true,potOnly:true)))
        }}
        // Progressive, hand-authored layouts: one-, two- and three-rail routes at
        // three levels. Aiming angles are starting references, not validated solutions.
        for isKick in [true,false] { for rails in 1...3 { for level in 1...3 {
            let spread=Double(level-1)*0.055
            let x=isKick ? (-0.28+spread) : (-0.24+spread)
            let y=isKick ? (-0.78+Double(rails-1)*0.035) : (-0.30+Double(rails-1)*0.07)
            let tx=isKick ? (0.24-spread*0.5) : (0.08+spread*0.35)
            let ty=isKick ? (0.46-Double(rails-1)*0.04) : (0.34-Double(rails-1)*0.06)
            let blockers:[BallState] = level==1 ? [] : [BallState(id:2,x:0.02,y:0.03+Double(level-2)*0.14)]
            let family=isKick ? "Kick":"Bank"
            result.append(Drill(title:"\(family) · \(rails) băng · Cấp \(level)",
                note:"\(isKick ? "Bi cái chạm băng trước khi gặp bi 1":"Bi 1 chạm đúng số băng rồi vào lỗ") · \(["Cơ bản","Trung cấp","Nâng cao"][level-1]). \(level==1 ? "Đường thoáng.":(level==2 ? "Có bi cản đường trực tiếp.":"Có bi cản và thế bi lệch tâm."))",
                rails:rails,kick:isKick,balls:[BallState(id:0,x:x,y:y),BallState(id:1,x:tx,y:ty)]+blockers,
                angle:isKick ? atan2(ty-y,tx-x) : atan2(ty-y,tx-x),level:level))
        }}}
        return result
    }()
}

private final class DrillLessonController:UIViewController {
    let drill:Drill
    var start:(()->Void)?
    init(drill:Drill){self.drill=drill;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    override func viewDidLoad(){
        super.viewDidLoad();title=drill.levelName;view.backgroundColor=UIColor(red:0.09,green:0.05,blue:0.025,alpha:1)
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(scroll)
        let stack=UIStackView();stack.axis = .vertical;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(stack)
        func label(_ text:String,_ size:CGFloat,_ color:UIColor,_ weight:UIFont.Weight = .regular)->UILabel{let v=UILabel();v.text=text;v.textColor=color;v.font = .systemFont(ofSize:size,weight:weight);v.numberOfLines=0;return v}
        stack.addArrangedSubview(label(drill.title,22,MenuSkin.gold,.bold))
        stack.addArrangedSubview(label(drill.familyName+"  ·  Mục tiêu: đúng \(drill.rails) băng",15,.white,.semibold))
        let diagram=DrillPreviewView(drill:drill);diagram.heightAnchor.constraint(equalToConstant:236).isActive=true;diagram.contentMode = .redraw;stack.addArrangedSubview(diagram)
        stack.addArrangedSubview(label("Cách tính tham khảo",16,MenuSkin.gold,.bold));stack.addArrangedSubview(label(drill.formula,14,.white))
        stack.addArrangedSubview(label("Hướng dẫn luyện",16,MenuSkin.gold,.bold));stack.addArrangedSubview(label(drill.coaching,14,.white))
        let button=UIButton(type:.system);var config=UIButton.Configuration.filled();config.title="Bắt đầu luyện";config.baseBackgroundColor=MenuSkin.gold;config.baseForegroundColor = .black;button.configuration=config;button.addAction(UIAction{[weak self]_ in self?.start?()},for:.touchUpInside);stack.addArrangedSubview(button)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:20),scroll.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-20),scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:12),scroll.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-12),stack.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor),stack.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor),stack.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor),stack.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor),stack.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor)])
    }
}
private final class DrillPreviewView:UIView {
    let drill:Drill
    init(drill:Drill){self.drill=drill;super.init(frame:.zero);backgroundColor=UIColor(red:0.07,green:0.045,blue:0.03,alpha:1);layer.cornerRadius=12;clipsToBounds=true}
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    override func draw(_ rect:CGRect){
        guard let c=UIGraphicsGetCurrentContext() else{return}
        // 0.16: màn ngang → vẽ bàn nằm ngang (trục dài theo chiều rộng khung) để sơ đồ lấp đầy khung, không còn là ô nhỏ giữa nền xanh.
        let bounds=self.bounds.insetBy(dx:18,dy:22)
        let landscape=bounds.width>=bounds.height
        let long=2.54,short=1.27
        let scale=landscape ? min(bounds.width/long,bounds.height/short):min(bounds.width/short,bounds.height/long)
        let w=CGFloat(landscape ? long:short)*scale,h=CGFloat(landscape ? short:long)*scale
        let table=CGRect(x:bounds.midX-w/2,y:bounds.midY-h/2,width:w,height:h)
        // Toạ độ bàn: x theo cạnh ngắn, y theo cạnh dài (đầu bàn y dương).
        func point(_ x:Double,_ y:Double)->CGPoint{
            landscape ? CGPoint(x:table.midX+CGFloat(y)*scale,y:table.midY+CGFloat(x)*scale)
                      : CGPoint(x:table.midX+CGFloat(x)*scale,y:table.midY-CGFloat(y)*scale)
        }
        c.setFillColor(UIColor(red:0.06,green:0.38,blue:0.34,alpha:1).cgColor);c.fill(table)
        c.setStrokeColor(UIColor(white:0.88,alpha:0.8).cgColor);c.setLineWidth(1.5);c.stroke(table)
        // Nút kim cương: 8 khoảng trên cạnh dài, 4 trên cạnh ngắn.
        c.setFillColor(UIColor(white:0.92,alpha:0.55).cgColor)
        for i in 1..<8 where i != 4 {let y=-long/2+Double(i)*long/8;for x in [-short/2,short/2]{let q=point(x,y);c.fillEllipse(in:CGRect(x:q.x-1.5,y:q.y-1.5,width:3,height:3))}}
        for i in 1..<4 {let x=-short/2+Double(i)*short/4;for y in [-long/2,long/2]{let q=point(x,y);c.fillEllipse(in:CGRect(x:q.x-1.5,y:q.y-1.5,width:3,height:3))}}
        let pocket=max(6,min(11,CGFloat(0.06)*scale))
        c.setFillColor(UIColor(white:0.02,alpha:1).cgColor)
        for x in [-short/2,short/2]{for y in [-long/2,0.0,long/2]{let q=point(x,y);c.fillEllipse(in:CGRect(x:q.x-pocket,y:q.y-pocket,width:2*pocket,height:2*pocket))}}
        let r=max(6,min(10,CGFloat(0.0286)*scale*1.6))
        // Mũi tên hướng ngắm bắt đầu từ bi cái (trước đây chỉ có chữ, không có hình).
        if let cue=drill.balls.first(where:{$0.id==0}) {
            let from=point(cue.x,cue.y),to=point(cue.x+cos(drill.angle)*0.45,cue.y+sin(drill.angle)*0.45)
            let dx=to.x-from.x,dy=to.y-from.y,len=max(1,hypot(dx,dy)),ux=dx/len,uy=dy/len
            c.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor);c.setLineWidth(1.5);c.setLineDash(phase:0,lengths:[5,4])
            c.move(to:CGPoint(x:from.x+ux*r,y:from.y+uy*r));c.addLine(to:to);c.strokePath();c.setLineDash(phase:0,lengths:[])
            c.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            c.move(to:to);c.addLine(to:CGPoint(x:to.x-ux*9-uy*5,y:to.y-uy*9+ux*5));c.addLine(to:CGPoint(x:to.x-ux*9+uy*5,y:to.y-uy*9-ux*5));c.closePath();c.fillPath()
        }
        for b in drill.balls {
            let q=point(b.x,b.y),box=CGRect(x:q.x-r,y:q.y-r,width:2*r,height:2*r)
            let color:UIColor = b.id==0 ? .white:(b.id==1 ? UIColor(red:1,green:0.63,blue:0.1,alpha:1):UIColor(white:0.35,alpha:1))
            c.setFillColor(color.cgColor);c.fillEllipse(in:box)
            c.setStrokeColor(UIColor.black.withAlphaComponent(0.55).cgColor);c.setLineWidth(1);c.strokeEllipse(in:box)
        }
        let note="Trắng: bi cái · Cam: bi 1 · Xám: bi cản · Nét đứt: hướng ngắm gợi ý ban đầu" as NSString
        note.draw(at:CGPoint(x:bounds.minX,y:self.bounds.maxY-18),withAttributes:[.font:UIFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:UIColor.white.withAlphaComponent(0.85)])
    }
}

// Original practice sequences; linked instruction remains with its authors.
struct Lesson {
    let title: String
    let drill: Int
    let steps: String
    let source: String
    let video: String?
    static let all: [Lesson] = [
        Lesson(title:"Video · Trung điểm một băng",drill:1,
          steps:"Video anh gửi: Make the 8 with a One-Rail Kick - Midpoint Aiming Method. Hình minh họa tìm trung điểm rồi dịch đường cơ để ngắm. Đây là mốc hình học khởi đầu. Vào Tìm góc kick, chọn bi đích và 1 băng để đối chiếu theo lực Đánh thử và ép phê đang chọn. Thay từng thông số một; không coi góc tới bằng góc ra khi có xoáy hoặc mất năng lượng.",
          source:"https://drdavepoolinfo.com/faq/bank-kick/two-to-one/",video:nil),
        Lesson(title:"Video · Hai băng và điểm ép phê",drill:2,
          steps:"Video anh gửi: How to use this two rail bank system! Trên hình có thang nút và hình bi đánh dấu điểm chạm. Chưa xác định được lực và độ lệch chính xác từ hình. Giữ mặt bi cạnh B góc trái để mở vòng 25/50% bán kính; X dương bên phải, Y dương phía trên, nhìn từ đuôi cơ. Vòng cam chỉ là giới hạn nhập mô phỏng. Tìm góc kick 2 băng giữ nguyên lực và điểm chạm hiện tại.",
          source:"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",video:nil),
        Lesson(title:"Video · Parallel Shift ba băng",drill:3,
          steps:"Video Free Pool Lessons hiển thị 1.5 + 5.5 = 7: 1.5 ở hướng đầu cơ, 5.5 là kéo dài về phía đuôi cơ, 7 là mốc đích trong ví dụ. Sau đó dịch đường cơ song song qua bi cái. Giữ nguyên quy ước đánh số của video; không đổi thành Corner-5. App chưa vẽ thang số riêng của hệ này lên bàn. Tìm góc kick 3 băng là lời giải số của mô hình, không phải xác nhận công thức video đúng ở mọi lực và xoáy.",
          source:"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",video:nil),
        Lesson(title:"Video · Plus System",drill:3,
          steps:"Video The Plus Kicking System minh họa 60 + 20 = 80, 50 + 20 = 70, 30 + 30 = 60 và 30 + 50 = 80 trên thang số riêng. Không thay trực tiếp những số đó bằng khoảng cách mét hoặc số nút của hệ khác. Chưa có đủ dữ liệu lực, xoáy và tọa độ để hiệu chuẩn hệ này trong app. Dùng bài ba băng để khảo sát; ghi sai lệch trước khi áp dụng trên bàn thật.",
          source:"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",video:nil),
        Lesson(title:"01 · Nút số và đường gương",drill:1,
          steps:"Mở bài Kick 1 băng. Chuyển Trên cao, chọn đường ngắm rồi tắt đường chấm. Thử ở 1 và 2 m/s, mỗi lực 5 cú, dùng Lùi cú để giữ thế bi. Ghi góc cần sửa. Hệ 2:1 là mốc khởi đầu có điều kiện; bàn không in số; nút kim cương chỉ là mốc hình học. Thế bi này do BankLab thiết kế, không phải sơ đồ nguyên bản trong video.",
          source:"https://drdavepoolinfo.com/faq/bank-kick/two-to-one/",video:"https://www.youtube.com/watch?v=rcWccgPnoso"),
        Lesson(title:"02 · Tách ảnh hưởng của lực và xoáy",drill:1,
          steps:"Giữ nguyên thế bi và góc. Về tâm, thử 1 / 2 / 3 m/s. Sau đó giữ 2 m/s, lần lượt thử ép phê trái, tâm, phải với cùng độ lệch. Mỗi lần chỉ thay một yếu tố. So đường chạy và xuất CSV trước khi Lùi cú. Dự báo mới có tính xoáy nhưng vẫn phải đối chiếu với bàn thật.",
          source:"https://drdavepoolinfo.com/faq/bank-kick/effects/",video:"https://www.youtube.com/watch?v=11iSqkJjWgM"),
        Lesson(title:"03 · Kick hai băng",drill:2,
          steps:"Xem bài hướng dẫn gốc trước. Với thế bi luyện riêng của app, tìm chuỗi hai băng ở 2 m/s, sau đó tắt dự báo và thực hiện 10 cú. App tính đạt khi bi cái gặp bi 1 sau đúng hai lần chạm băng, không scratch. Đây là bài tìm đường; góc nạp sẵn chưa phải lời giải được hiệu chuẩn.",
          source:"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",video:"https://www.youtube.com/watch?v=UhIH0BmuSdE"),
        Lesson(title:"04 · Corner-5 và kick ba băng",drill:3,
          steps:"Đọc cách đánh số Corner-5 trong nguồn gốc. App chưa có lớp đánh số hoặc lời giải theo công thức Corner-5: không lấy các nút kim cương trên bàn thay trực tiếp vào công thức. Dùng bài ba băng để thử đường và ghi sai lệch theo lực; chỉ chuyển kinh nghiệm sang bàn thật sau khi đối chiếu.",
          source:"https://drdavepoolinfo.com/faq/bank-kick/corner-5/",video:nil),
        Lesson(title:"05 · Bank và ảnh hưởng góc cắt",drill:0,
          steps:"Dùng Đặt bi để tạo một đường bank một băng. Giữ bi mục tiêu cố định, dịch bi cái để đổi góc cắt. Mỗi vị trí thử 5 cú cùng lực và ghi điểm về băng. Bài tự do chưa tự chấm bank một băng. Tham khảo bài VEPP của Dr. Dave và Bob Jewett ở nguồn; app không sao chép sơ đồ của tác giả.",
          source:"https://drdavepoolinfo.com/bd_articles/2013/feb13.pdf",video:nil),
        Lesson(title:"06 · Kiểm tra bàn trước khi luyện",drill:8,
          steps:"Đầu tiên đo độ lăn, sau đó chọn bài Đo độ nảy. Dùng tốc độ cố định thấp để tránh chạm nhiều băng khi đo độ lăn. Trên bàn thật cần video có thước chuẩn và thời gian để ước lượng vận tốc. Chỉnh từng thông số, lưu số đo rồi kiểm tra lại ở lực khác. Không thể suy ra tất cả thông số chỉ từ một cú đánh.",
          source:"https://drdavepoolinfo.com/faq/bank-kick/testing/",video:nil),
        Lesson(title:"07 · Tăng lên bank/kick bốn băng",drill:4,
          steps:"Hoàn thành bài hai và ba băng trước. Bắt đầu với Kick 4 băng; chọn Bank 2–4 băng trong Bài tập khi muốn luyện bi mục tiêu. Mỗi lượt 10 cú cùng thế bi, ghi lực và kết quả. Đây là bài tự luyện của BankLab, chưa phải giáo án hoặc lời giải được huấn luyện viên chứng nhận.",
          source:"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",video:nil),
        Lesson(title:"08 · PoolShot: cách tổ chức buổi tập",drill:10,
          steps:"PoolShot có công cụ tạo bài và lưu điểm theo mục tiêu. BankLab áp dụng cách luyện có tiêu chí: chọn một thế bi, đánh 10 cú, ghi kết quả rồi đổi bài. Bài vùng dừng này do BankLab tự thiết kế; tâm bi cái phải nằm trong vòng tròn. Xem điểm đã lưu ở Thế bi → Nhật ký luyện tập.",
          source:"https://poolshot.org/pages/logiciel-poolshot",video:"https://www.youtube.com/user/PoolShotSoftware"),
        Lesson(title:"09 · Stop / cu-lê / trô có vùng đích",drill:11,
          steps:"Bắt đầu Stop shot, sau đó chọn Cu-lê và Trô trong Bài tập. Chấm đạt chỉ khi bi 1 vào lỗ, bi cái không scratch và tâm bi cái dừng trong vùng. Ba thế bi do BankLab thiết kế độc lập. Liên kết PoolShot để anh xem chương trình US Pool gốc, không phải thư viện đã nhập vào app.",
          source:"https://poolshot.org/pages/billard-americain",video:nil),
        Lesson(title:"10 · Tự tạo bài và theo dõi tiến bộ",drill:14,
          steps:"Dùng Đặt bi rồi Thế bi → Lưu để tạo biến thể. Bank 1 băng được chấm bằng va chạm/lỗ; những thế bi lưu riêng mở ở chế độ tự do, chưa lưu vùng đích hoặc tiêu chí riêng. Nhật ký lưu tối đa 200 cú có chấm điểm trên máy. BankLab chưa nhập file DRL của PoolShot.",
          source:"https://poolshot.org/products/fichier-drl-103-training-drills-pour-poolshot-software-niveau-1",video:nil)
    ]
}
final class LessonsController: UITableViewController {
    var load: ((Int)->Void)?
    override func viewDidLoad() {
        super.viewDidLoad(); title="Giáo trình · Nguồn gốc"
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Xong",style:.done,target:self,action:#selector(close))
        tableView.rowHeight=UITableView.automaticDimension
        tableView.estimatedRowHeight=70
    }
    @objc private func close(){dismiss(animated:true)}
    override func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int{Lesson.all.count}
    override func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let cell=UITableViewCell(style:.subtitle,reuseIdentifier:nil)
        cell.textLabel?.text=Lesson.all[indexPath.row].title;cell.textLabel?.numberOfLines=0
        cell.detailTextLabel?.text="Hướng dẫn · Nạp thế bi · Mở tài liệu/video gốc"
        cell.detailTextLabel?.numberOfLines=0;cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView:UITableView,didSelectRowAt indexPath:IndexPath) {
        tableView.deselectRow(at:indexPath,animated:true)
        let lesson=Lesson.all[indexPath.row]
        let sheet=UIAlertController(title:lesson.title,message:lesson.steps,preferredStyle:.alert)
        sheet.addAction(UIAlertAction(title:"Nạp thế bi luyện",style:.default){[weak self]_ in
            guard let self=self else{return};self.dismiss(animated:true){self.load?(lesson.drill)}
        })
        sheet.addAction(UIAlertAction(title:"Đọc nguồn gốc",style:.default){_ in
            if let url=URL(string:lesson.source){UIApplication.shared.open(url)}
        })
        if let video=lesson.video {
            sheet.addAction(UIAlertAction(title:"Xem YouTube của tác giả",style:.default){_ in
                if let url=URL(string:video){UIApplication.shared.open(url)}
            })
        }
        sheet.addAction(UIAlertAction(title:"Đóng",style:.cancel));present(sheet,animated:true)
    }
}
