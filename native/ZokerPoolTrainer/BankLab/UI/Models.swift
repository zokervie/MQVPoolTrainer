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
    var shotKind: Int? = nil
    /// Recorded snapshots live on disk; legacy input-only entries remain readable.
    var recordingID: String? = nil
    var coachVisible: Bool? = nil
    var physicsSettings: [String:Double]? = nil
    static let key="savedShots015"
    static func all()->[SavedShot]{
        guard let data=UserDefaults.standard.data(forKey:key) else{return []}
        return (try? JSONDecoder().decode([SavedShot].self,from:data)) ?? []
    }
    static func store(_ shots:[SavedShot]){
        if let data=try? JSONEncoder().encode(Array(shots.suffix(60))){UserDefaults.standard.set(data,forKey:key)}
    }
}
/// 0.35: hệ bài tập mới theo cấp (thay toàn bộ hệ cũ). Danh sách hiện 5 cấp; mỗi bài một lượt 5 cú, qua bài khi đạt ≥ 3/5,
/// sao = số cú đạt (5 sao cần điểm trung bình ≥ 85). Điểm từng cú do app tự chấm trên máy (không gửi dữ liệu đi đâu).
final class DrillsController:UITableViewController {
    var load:((Int)->Void)?
    var guidedLoad:((Int)->Void)?
    private lazy var groups:[[Int]]={(1...5).map{l in Drill.all.indices.filter{Drill.all[$0].level==l}}}()
    override func viewDidLoad(){
        super.viewDidLoad()
        let stars=Drill.bestStars(),cleared=Drill.all.filter{$0.level>0 && (stars[$0.title] ?? 0)>=3}.count
        title="Bài tập · \(cleared)/\(Drill.lessonCount) bài đã qua"
        tableView.backgroundColor=UIColor(red:0.07,green:0.07,blue:0.08,alpha:1)
        navigationController?.navigationBar.barStyle = .black
        tableView.rowHeight=UITableView.automaticDimension;tableView.estimatedRowHeight=90
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Xong",style:.done,target:self,action:#selector(close))
    }
    override func viewWillAppear(_ animated:Bool){super.viewWillAppear(animated);tableView.reloadData()}
    @objc private func close(){dismiss(animated:true)}
    override func numberOfSections(in tableView:UITableView)->Int{groups.count}
    override func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int{groups[section].count}
    override func tableView(_ tableView:UITableView,titleForHeaderInSection section:Int)->String?{Drill.levelNames[section+1].uppercased()}
    override func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell{
        let drill=Drill.all[groups[indexPath.section][indexPath.row]]
        let best=Drill.bestStars()[drill.title] ?? 0
        let cell=UITableViewCell(style:.subtitle,reuseIdentifier:nil)
        cell.backgroundColor=UIColor(white:0.14,alpha:1)
        cell.textLabel?.textColor = .white;cell.detailTextLabel?.textColor=UIColor(white:0.78,alpha:1)
        cell.imageView?.image=UIImage(systemName:best>=3 ? "checkmark.seal.fill":Drill.levelIcons[drill.level])
        cell.imageView?.tintColor=best>=3 ? .systemGreen:MenuSkin.gold
        cell.textLabel?.text=drill.title+"   "+Drill.starText(best);cell.textLabel?.font = .systemFont(ofSize:16,weight:.semibold)
        cell.detailTextLabel?.text=drill.note;cell.detailTextLabel?.numberOfLines=2
        cell.detailTextLabel?.font = .systemFont(ofSize:12)
        cell.accessoryType = .disclosureIndicator;return cell
    }
    override func tableView(_ tableView:UITableView,didSelectRowAt indexPath:IndexPath){
        tableView.deselectRow(at:indexPath,animated:true)
        let index=groups[indexPath.section][indexPath.row]
        let lesson=DrillLessonController(drill:Drill.all[index])
        lesson.start={[weak self] in guard let self=self else{return};self.dismiss(animated:true){self.load?(index)}}
        lesson.guidedStart={[weak self] in guard let self=self else{return};self.dismiss(animated:true){self.guidedLoad?(index)}}
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
    /// 0 = công cụ (không hiện trong danh sách bài tập); 1…5 = cấp giáo trình.
    var level:Int = 1
    /// Hệ nút số / mẹo của bài (nguồn đã công bố ghi trong chuỗi).
    var system:String = ""
    /// 0.35: public video / article of the author (opened, never embedded).
    var video:String? = nil
    static let levelNames=["Công cụ","Cấp 1 · Nền tảng: lực và vị trí bi cái","Cấp 2 · Nút số: kick 1 băng (hệ gương)","Cấp 3 · Nút số: kick 2–3 băng (Corner-5)","Cấp 4 · Bank và hệ Plus","Cấp 5 · Trick shot"]
    static let levelIcons=["wrench","target","1.circle","3.circle","arrow.triangle.branch","sparkles"]
    var levelName:String { Drill.levelNames[max(0,min(5,level))] }
    var familyName:String { kick ? "Kick · bi cái qua băng rồi chạm bi 1" : (rails>0 ? "Bank · bi 1 qua băng rồi vào lỗ" : (goal?.potOnly==true ? "Đưa bi 1 vào lỗ" : "Kiểm soát bi cái")) }
    var goalText:String {
        if kick {return "Bi cái chạm đúng \(rails) băng rồi mới chạm bi 1"}
        if rails>0 {return "Bi 1 chạm đúng \(rails) băng rồi vào lỗ"}
        if let g=goal {return g.potOnly ? "Bi 1 vào lỗ, bi cái không vào lỗ" : (g.potRequired ? "Bi 1 vào lỗ và bi cái dừng trong vòng tròn" : "Bi cái dừng trong vòng tròn")}
        return "Tự do"
    }
    var formula:String {
        if !system.isEmpty {return system}
        if kick || rails>0 {return "Đường gương: phản chiếu bi đích qua băng, ngắm vào ảnh. Đây là mốc hình học; lực, effect và ma sát băng làm đường thật lệch đi."}
        return "Giữ hướng và điểm chạm làm mốc; mỗi cú chỉ thay một biến (lực, điểm chạm hoặc góc)."
    }
    var coaching:String { "Một lượt = 5 cú cùng thế bi; sau mỗi cú app tự xếp lại bi. Qua bài khi đạt từ 3/5 cú. Sao = số cú đạt; 5 sao cần thêm điểm trung bình từ 85.\n\nĐiểm mỗi cú (0–100) app tự chấm: cú đạt được 100 (bài vùng dừng trừ theo khoảng cách tới tâm vòng); cú trượt được điểm theo độ gần: bi cái trượt bi 1 bao nhiêu cm, bi 1 dừng cách lỗ bao xa, sai số băng. Bi cái vào lỗ = 0. Bật Coach để xem điểm va băng và lời khuyên một thay đổi cho cú sau." }
    // Công cụ và bài khởi động: chỉ số cố định, mã QA và màn mở đầu dùng chúng.
    static let free=0, rollTest=1, startup=3
    static var lessonCount:Int { all.filter{$0.level>0}.count }
    static func bestStars()->[String:Int]{UserDefaults.standard.dictionary(forKey:"lessonStars035") as? [String:Int] ?? [:]}
    static func recordStars(_ stars:Int,for title:String){
        var all=bestStars();if stars>(all[title] ?? 0){all[title]=stars;UserDefaults.standard.set(all,forKey:"lessonStars035")}
    }
    static func starText(_ n:Int)->String{String(repeating:"★",count:max(0,min(5,n)))+String(repeating:"☆",count:5-max(0,min(5,n)))}

    private static let mirror="Hệ gương (kick 1 băng): đếm nút trên băng định đánh, lấy ảnh đối xứng của bi 1 qua băng; điểm ngắm là chỗ đường bi cái → ảnh cắt băng. Khi hai bi cách băng bằng nhau, điểm ngắm nằm giữa hai số nút của chúng (trung điểm). Bật Coach: app tính sẵn số nút gương cho thế bi này. Effect thuận mở góc ra, effect nghịch thu góc lại (Dr. Dave Alciatore, kick/bank FAQ)."
    private static let corner5="Corner-5 (3 băng, Walter Harris / Robert Byrne): số bi cái (đếm theo đường cơ trên băng dài) − số đích ở băng thứ 3 = số ngắm ở băng thứ nhất. Ví dụ bi cái ở 5, muốn tới 2 thì ngắm 3. Đánh effect thuận vừa, lực vừa; bàn nhanh/chậm cần bù ½ nút. Kick 2 băng: dùng nút gương hai lần (phản chiếu qua băng thứ 2 rồi băng thứ 1)."
    private static let plus="Hệ Plus (kick 2 băng qua băng ngắn rồi băng dài): số vị trí bi cái + số điểm đến = số ngắm trên băng dài đối diện. Bank 1 băng: phản chiếu lỗ qua băng (hệ gương); bi 1 nhận throw từ cắt mỏng nên ngắm sâu hơn một chút khi cắt mạnh."

    private static func kickLayout(rails:Int,variant:Int)->(cue:BallState,object:BallState,blockers:[BallState],angle:Double){
        let spread=Double(variant)*0.055
        let x = -0.28+spread,y = -0.78+Double(rails-1)*0.035
        let tx=0.24-spread*0.5,ty=0.46-Double(rails-1)*0.04
        let blockers:[BallState] = variant==0 ? [] : [BallState(id:2,x:0.02,y:0.03+Double(variant-1)*0.14)]
        return (BallState(id:0,x:x,y:y),BallState(id:1,x:tx,y:ty),blockers,atan2(ty-y,tx-x))
    }
    private static func kickDrill(_ title:String,note:String,rails:Int,variant:Int,level:Int,system:String)->Drill{
        let k=kickLayout(rails:rails,variant:variant)
        return Drill(title:title,note:note,rails:rails,kick:true,balls:[k.cue,k.object]+k.blockers,angle:k.angle,level:level,system:system)
    }
    private static func cut(_ degrees:Double,mirror m:Double,level:Int)->Drill{
        let length=hypot(0.42,0.755),dx=0.42/length,dy=0.755/length
        let r=degrees*Double.pi/180
        let ix=dx*cos(r)-dy*sin(r),iy=dx*sin(r)+dy*cos(r)
        let gx=0.25-dx*0.05715,gy=0.55-dy*0.05715
        return Drill(title:"Cắt \(m<0 ? "trái":"phải") \(Int(degrees))° vào lỗ góc",note:"Bi 1 vào lỗ góc, bi cái không vào lỗ. Điểm ngắm là tâm bi ma (cách tâm bi 1 đúng 2R theo hướng lỗ).",rails:0,kick:false,
            balls:[BallState(id:0,x:(gx-ix*0.65)*m,y:gy-iy*0.65),BallState(id:1,x:0.25*m,y:0.55)],angle:atan2(iy,ix*m),
            goal:PracticeGoal(x:0,y:0,radius:0,potRequired:true,potOnly:true),level:level,
            system:"Bi ma: điểm ngắm = tâm bi 1 lùi 2R (57 mm) theo hướng ngược đường bi 1 → lỗ. Cắt \(Int(degrees))°: bi 1 đi lệch \(Int(degrees))° so với đường cơ; cắt càng mỏng throw càng làm bi 1 lệch theo hướng bi cái đi (bù ngắm dày hơn ~1–2°).")
    }
    static let all:[Drill] = {
        let stopBalls=[BallState(id:0,x:0.02,y:0.01),BallState(id:1,x:0.33,y:0.63)],stopAngle=atan2(0.62,0.31)
        var r:[Drill]=[
            // 0–2: công cụ (ẩn khỏi danh sách)
            Drill(title:"Tự do",note:"Bàn tự do.",rails:0,kick:false,balls:[BallState(id:0,x:0,y:-0.72),BallState(id:1,x:0.13,y:0.30)],angle:1.43,level:0),
            Drill(title:"Đo độ lăn",note:"Cú thẳng không xoáy để so quãng dừng.",rails:0,kick:false,balls:[BallState(id:0,x:0,y:-0.90)],angle:Double.pi/2,level:0),
            Drill(title:"Đo độ nảy",note:"Đánh vuông góc băng dài để so độ nảy.",rails:0,kick:false,balls:[BallState(id:0,x:0,y:0.34)],angle:0,level:0),
            // 3: bài mở đầu (cũng là thế bi khi mở app)
            Drill(title:"Kick 1 băng · Gương A",note:"Bi cái chạm 1 băng rồi mới chạm bi 1. Mốc: số nút gương (bật Coach để xem).",rails:1,kick:true,
                  balls:[BallState(id:0,x:-0.25,y:-0.72),BallState(id:1,x:-0.23,y:0.56)],angle:0.91,level:2,system:mirror),
            // Cấp 1 · nền tảng
            Drill(title:"Stop · Giữ bi cái",note:"Bi 1 vào lỗ, bi cái dừng trong vòng tròn sát điểm chạm.",rails:0,kick:false,balls:stopBalls,angle:stopAngle,
                  goal:PracticeGoal(x:0.3044,y:0.5789,radius:0.10,potRequired:true),level:1,system:"Đánh dưới tâm vừa đủ để bi cái hết xoáy đúng lúc chạm bi 1: càng xa càng phải thấp hơn hoặc mạnh hơn."),
            Drill(title:"Cu-lê · Theo vào vùng",note:"Bi 1 vào lỗ, bi cái theo tới vòng tròn phía trước.",rails:0,kick:false,balls:stopBalls,angle:stopAngle,
                  goal:PracticeGoal(x:0.50,y:0.97,radius:0.12,potRequired:true),level:1,system:"Đánh trên tâm: sau va chạm bi cái lăn theo hướng bi 1. Quãng theo tăng theo lực và độ cao điểm chạm."),
            Drill(title:"Trô · Lùi vào vùng",note:"Bi 1 vào lỗ, bi cái lùi về vòng tròn phía sau.",rails:0,kick:false,balls:stopBalls,angle:stopAngle,
                  goal:PracticeGoal(x:0.17,y:0.31,radius:0.12,potRequired:true),level:1,system:"Đánh dưới tâm, ra cơ dứt khoát. Quãng lùi phụ thuộc lực và khoảng cách: bi cái đi xa thì xoáy dưới mất dần trên nỉ."),
            cut(30,mirror:1,level:1),cut(45,mirror:-1,level:1)
        ]
        for (i,y) in [0.1,0.55,0.95].enumerated(){
            r.append(Drill(title:"Lực \(i+1)/3 · Dừng đúng vùng",note:"Một bi, ba cự ly tăng dần. Tâm bi cái phải dừng trong vòng tròn.",rails:0,kick:false,
                balls:[BallState(id:0,x:0,y:-0.9)],angle:Double.pi/2,goal:PracticeGoal(x:0,y:y,radius:0.09,potRequired:false),level:1,
                system:"Quãng dừng tỉ lệ với bình phương tốc độ đầu: muốn đi gấp đôi quãng thì lực chỉ cần tăng khoảng 1,4 lần."))
        }
        // Cấp 2 · nút số: kick 1 băng
        r.append(kickDrill("Kick 1 băng · Gương B",note:"Không bi cản. Đếm nút, tìm điểm gương rồi đánh tâm.",rails:1,variant:0,level:2,system:mirror))
        r.append(kickDrill("Kick 1 băng · Thoát bi cản",note:"Có bi cản trên đường thẳng: bắt buộc qua băng.",rails:1,variant:1,level:2,system:mirror))
        r.append(kickDrill("Kick 1 băng · Bi cản xa",note:"Bi cản lệch xa hơn; giữ lực vừa để góc băng đúng gương.",rails:1,variant:2,level:2,system:mirror))
        // Cấp 3 · kick 2–3 băng
        r.append(Drill(title:"Kick 2 băng · Gương kép",note:"Bi cái chạm đúng 2 băng rồi mới gặp bi 1.",rails:2,kick:true,
            balls:[BallState(id:0,x:-0.28,y:-0.68),BallState(id:1,x:0.20,y:0.40)],angle:0.49,level:3,system:corner5))
        r.append(kickDrill("Kick 2 băng · Thoát bi cản",note:"Có bi cản; tìm đường 2 băng.",rails:2,variant:1,level:3,system:corner5))
        r.append(Drill(title:"Kick 3 băng · Corner-5",note:"Bi cái chạm đúng 3 băng trước lần va bi đầu tiên. Áp dụng: số bi cái − số đích = số ngắm.",rails:3,kick:true,
            balls:[BallState(id:0,x:-0.30,y:-0.70),BallState(id:1,x:0.17,y:0.50)],angle:0.36,level:3,system:corner5))
        r.append(kickDrill("Kick 3 băng · Bi cản giữa bàn",note:"Có bi cản giữa bàn; 3 băng rồi chạm bi 1.",rails:3,variant:1,level:3,system:corner5))
        r.append(kickDrill("Kick 3 băng · Bi cản cao",note:"Bi cản đặt cao hơn, đường 3 băng hẹp hơn.",rails:3,variant:2,level:3,system:corner5))
        // Cấp 4 · bank và Plus
        r.append(Drill(title:"Bank 1 băng",note:"Bi 1 chạm đúng 1 băng rồi vào lỗ; bi cái không vào lỗ.",rails:1,kick:false,
            balls:[BallState(id:0,x:-0.28,y:-0.65),BallState(id:1,x:0.06,y:0.20)],angle:1.19,level:4,system:plus))
        r.append(Drill(title:"Bank 2 băng",note:"Bi 1 vào lỗ sau đúng 2 băng.",rails:2,kick:false,
            balls:[BallState(id:0,x:-0.30,y:-0.70),BallState(id:1,x:-0.08,y:-0.13)],angle:1.18,level:4,system:plus))
        r.append(Drill(title:"Kick 2 băng · Hệ Plus",note:"Qua băng ngắn rồi băng dài trước khi chạm bi 1.",rails:2,kick:true,
            balls:[BallState(id:0,x:-0.22,y:-0.95),BallState(id:1,x:0.30,y:0.62),BallState(id:2,x:0.05,y:-0.20)],angle:atan2(0.62+0.95,0.30+0.22),level:4,system:plus))
        r.append(Drill(title:"Bank 3 băng",note:"Bi 1 vào lỗ sau đúng 3 băng.",rails:3,kick:false,
            balls:[BallState(id:0,x:0.22,y:-0.72),BallState(id:1,x:0.06,y:-0.15)],angle:1.84,level:4,system:plus))
        r.append(Drill(title:"Kick 4 băng",note:"Chuỗi 4 băng trước khi chạm bi 1; rất nhạy với lực.",rails:4,kick:true,
            balls:[BallState(id:0,x:-0.25,y:-0.60),BallState(id:1,x:0.15,y:0.38)],angle:0.29,level:4,system:corner5))
        // Cấp 5 · trick shot (bi 1 phải vào lỗ, bi cái không vào lỗ)
        let pot=PracticeGoal(x:0,y:0,radius:0,potRequired:true,potOnly:true)
        r.append(Drill(title:"Trick · Combo dính",note:"Bi 2 dính sát bi 1 chĩa vào lỗ góc. Đánh bi 2, bi 1 vào lỗ.",rails:0,kick:false,
            balls:[BallState(id:0,x:0.10,y:0.40),BallState(id:2,x:0.50,y:1.10),BallState(id:1,x:0.5356,y:1.1447)],angle:atan2(0.70,0.40),goal:pot,level:5,
            system:"Hai bi dính sát: bi trước đi theo đường nối hai tâm, cộng throw ~2–4° về phía bi cái đi. Đánh dày vừa, effect giữa."))
        r.append(Drill(title:"Trick · Jump qua bi cản",note:"Bi cản sát đường. Chọn gậy Jump (cơ ~45°), nhảy qua bi cản cắt bi 1 vào lỗ góc.",rails:0,kick:false,
            balls:[BallState(id:0,x:0.15,y:-0.20),BallState(id:2,x:0.201,y:-0.027),BallState(id:1,x:0.55,y:1.15)],angle:atan2(1.35,0.40),goal:pot,level:5,
            system:"Jump: cơ dốc 40–50°, đánh trên tâm một chút, ra cơ nhanh và ngắn. Bi bật lên khỏi mặt nỉ rồi rơi về; khoảng cách tới bi cản cần ≥ 1 gang tay (TP 7.x, Dr. Dave)."))
        r.append(Drill(title:"Trick · Massé vòng bi cản",note:"Bi cản che thẳng. Chọn Massé (cơ ≥ 60°), đánh lệch tâm để bi cái cong vòng qua.",rails:0,kick:false,
            balls:[BallState(id:0,x:-0.20,y:0.10),BallState(id:2,x:-0.12,y:0.32),BallState(id:1,x:0.05,y:0.85)],angle:atan2(0.75,0.25),goal:pot,level:5,
            system:"Massé: hướng cuối của bi cái ≈ 5/7 hướng ra cơ + 2/7 do xoáy (Coriolis), cong về phía effect đặt. Cơ càng dốc, đường cong càng ngắn."))
        r.append(Drill(title:"Trick · Kick 3 băng thoát cụm",note:"Bi 1 nằm sau cụm bi cản; kick 3 băng rồi đưa bi 1 vào lỗ.",rails:0,kick:false,
            balls:[BallState(id:0,x:-0.30,y:-0.70),BallState(id:2,x:0.05,y:0.10),BallState(id:3,x:0.25,y:0.25),BallState(id:1,x:0.52,y:1.10)],angle:0.36,goal:pot,level:5,system:corner5))
        // Thế bi theo clip "Reverse bank zigzag" (đo trong Tests/ReverseZigzagTests.cpp: bi đích ở nút dài 4,36 / ngắn 1,83,
        // đi tới băng tại nút 3,44, rồi zigzag đổi chiều sau băng 2).
        r.append(Drill(title:"Trick · Reverse bank zigzag",note:"Như clip: bi 1 đập băng rồi zigzag ĐỔI CHIỀU về lỗ. Đánh effect ngược với hướng bi 1 văng ra (bánh răng), lực mạnh.",rails:0,kick:false,
            balls:[BallState(id:0,x:-0.511,y:0.316),BallState(id:1,x:-0.054,y:0.114)],angle:atan2(-0.404,0.914),goal:pot,level:5,
            system:"Hiệu ứng bánh răng: effect bi cái ngược chiều văng của bi 1 truyền xoáy ngược sang bi 1 (≈ R·ω/v 0,13–0,14 ở effect tối đa). Chạm băng, xoáy ngược kéo bi 1 giật về, đường đi đổi chiều sau băng thứ 2. Effect thuận thì không giật mà mở góc."))
        let videos:[String:String]=[
            "Kick 1 băng · Gương A":"https://www.youtube.com/watch?v=rcWccgPnoso",
            "Kick 1 băng · Gương B":"https://drdavepoolinfo.com/faq/bank-kick/two-to-one/",
            "Kick 1 băng · Thoát bi cản":"https://www.youtube.com/watch?v=11iSqkJjWgM",
            "Kick 1 băng · Bi cản xa":"https://www.youtube.com/watch?v=11iSqkJjWgM",
            "Kick 2 băng · Gương kép":"https://www.youtube.com/watch?v=UhIH0BmuSdE",
            "Kick 2 băng · Thoát bi cản":"https://www.youtube.com/watch?v=UhIH0BmuSdE",
            "Kick 3 băng · Corner-5":"https://drdavepoolinfo.com/faq/bank-kick/corner-5/",
            "Kick 3 băng · Bi cản giữa bàn":"https://drdavepoolinfo.com/faq/bank-kick/corner-5/",
            "Kick 3 băng · Bi cản cao":"https://drdavepoolinfo.com/faq/bank-kick/corner-5/",
            "Bank 1 băng":"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",
            "Bank 2 băng":"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",
            "Bank 3 băng":"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",
            "Kick 2 băng · Hệ Plus":"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",
            "Kick 4 băng":"https://drdavepoolinfo.com/tutorial/kicks-and-banks/",
            "Trick · Jump qua bi cản":"https://drdavepoolinfo.com/FAQ/jump/technique/",
            "Trick · Massé vòng bi cản":"https://www.youtube.com/shorts/D_lf-6KgFTo",
            "Trick · Reverse bank zigzag":"https://youtube.com/shorts/c-ZBSi9KBfc",
            "Trick · Kick 3 băng thoát cụm":"https://drdavepoolinfo.com/faq/bank-kick/corner-5/"]
        return r.map{var d=$0;d.video=videos[d.title];return d}
    }()
}

private final class DrillLessonController:UIViewController {
    let drill:Drill
    var start:(()->Void)?
    var guidedStart:(()->Void)?
    init(drill:Drill){self.drill=drill;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    override func viewDidLoad(){
        super.viewDidLoad();title="Bài tập";view.backgroundColor=UIColor(red:0.07,green:0.07,blue:0.08,alpha:1)
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(scroll)
        let stack=UIStackView();stack.axis = .vertical;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(stack)
        func label(_ text:String,_ size:CGFloat,_ color:UIColor,_ weight:UIFont.Weight = .regular)->UILabel{let v=UILabel();v.text=text;v.textColor=color;v.font = .systemFont(ofSize:size,weight:weight);v.numberOfLines=0;return v}
        stack.addArrangedSubview(label(drill.title,22,MenuSkin.gold,.bold))
        stack.addArrangedSubview(label(drill.levelName+"\nMục tiêu: "+drill.goalText,15,.white,.semibold))
        let diagram=DrillPreviewView(drill:drill);diagram.heightAnchor.constraint(equalToConstant:236).isActive=true;diagram.contentMode = .redraw;stack.addArrangedSubview(diagram)
        stack.addArrangedSubview(label("Hệ nút số / công thức",16,MenuSkin.gold,.bold));stack.addArrangedSubview(label(drill.formula,14,.white))
        stack.addArrangedSubview(label("Cách chấm điểm",16,MenuSkin.gold,.bold));stack.addArrangedSubview(label(drill.coaching,14,.white))
        let button=UIButton(type:.system);var config=UIButton.Configuration.filled();config.title="Bắt đầu · 5 cú";config.baseBackgroundColor=MenuSkin.gold;config.baseForegroundColor = .black;button.configuration=config;button.addAction(UIAction{[weak self]_ in self?.start?()},for:.touchUpInside);stack.addArrangedSubview(button)
        let guided=UIButton(type:.system);guided.setTitle("Bắt đầu có Coach (xem điểm va băng, lời khuyên)",for:.normal);guided.heightAnchor.constraint(greaterThanOrEqualToConstant:44).isActive=true;guided.addAction(UIAction{[weak self]_ in self?.guidedStart?()},for:.touchUpInside);stack.addArrangedSubview(guided)
        if let link=drill.video,let url=URL(string:link) {
            let video=UIButton(type:.system);video.setTitle(link.contains("youtu") ? "▶︎ Xem video hướng dẫn của tác giả":"📄 Đọc hướng dẫn của tác giả",for:.normal)
            video.heightAnchor.constraint(greaterThanOrEqualToConstant:44).isActive=true
            video.addAction(UIAction{_ in UIApplication.shared.open(url)},for:.touchUpInside);stack.addArrangedSubview(video)
        }
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
        for i in 1..<8 where i != 4 {let y = -long/2+Double(i)*long/8;for x in [-short/2,short/2]{let q=point(x,y);c.fillEllipse(in:CGRect(x:q.x-1.5,y:q.y-1.5,width:3,height:3))}}
        for i in 1..<4 {let x = -short/2+Double(i)*short/4;for y in [-long/2,long/2]{let q=point(x,y);c.fillEllipse(in:CGRect(x:q.x-1.5,y:q.y-1.5,width:3,height:3))}}
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
