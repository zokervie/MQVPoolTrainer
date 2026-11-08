import UIKit
import SceneKit

struct TableLook {
    let id:String,brand:String,name:String,base:Int
    let cabinet:UInt32,cloth:UInt32,trim:UInt32
    let wood:Bool
    let source:String
    var title:String {brand+" · "+name}
    // 0.34: brands renamed Z-… (owner rule: no real trademarks until licensed); "Z-Max Pro" = the owner's reference
    // club table (black cabinet, silver-grey cloth, brushed aluminium caps, white side logo) and the new default.
    static let all:[TableLook] = [
        .init(id:"zmax",brand:"Z-Max",name:"Pro 9 ft",base:0,cabinet:0x0e0f11,cloth:0x6e767d,trim:0xc4c9cd,wood:false,source:"owner reference photo 08/11/2026"),
        .init(id:"apex",brand:"Z-Pr",name:"APEX Pro",base:0,cabinet:0x20252b,cloth:0x237f92,trim:0xb8bec3,wood:false,source:"https://predatorcues.com/pages/billiard-tables"),
        .init(id:"arc",brand:"Z-Pr",name:"ARC",base:4,cabinet:0xe2ddd2,cloth:0x377a8e,trim:0x41494d,wood:false,source:"https://predatorcues.com/pages/predator-arc-pool-table"),
        .init(id:"gc7",brand:"Z-Br",name:"Crown VII",base:1,cabinet:0x67513e,cloth:0x267e84,trim:0xc3c4c1,wood:true,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"gc6",brand:"Z-Br",name:"Crown VI",base:1,cabinet:0x71462c,cloth:0x287d67,trim:0xb4b8ba,wood:true,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"blackwolf",brand:"Z-Br",name:"Black Wolf",base:0,cabinet:0x28282a,cloth:0x2e728d,trim:0x55595c,wood:false,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"blackwolfpro",brand:"Z-Br",name:"Black Wolf Pro",base:0,cabinet:0x181e24,cloth:0x277f91,trim:0x9dabb0,wood:false,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"allenton",brand:"Z-Br",name:"Allenton",base:2,cabinet:0x482615,cloth:0x12695D,trim:0xEAC583,wood:true,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"glenwood",brand:"Z-Br",name:"Glenwood",base:5,cabinet:0x7b5032,cloth:0x80504b,trim:0xa88d60,wood:true,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"oakland",brand:"Z-Br",name:"Oakland II",base:2,cabinet:0x503728,cloth:0x366c5a,trim:0x998b70,wood:true,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"sanibel",brand:"Z-Br",name:"Sanibel",base:3,cabinet:0x9b8a71,cloth:0x67858b,trim:0x494744,wood:true,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"canton",brand:"Z-Br",name:"Canton",base:3,cabinet:0x6e4933,cloth:0x3e6b75,trim:0x343231,wood:true,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"botanic",brand:"Z-Br",name:"Botanic",base:5,cabinet:0x776951,cloth:0x526d57,trim:0x494940,wood:true,source:"https://www.brunswickbilliards.com/collections/billiard-tables"),
        .init(id:"proam",brand:"Z-Di",name:"Pro-Am",base:0,cabinet:0x493127,cloth:0x267ca1,trim:0x8a6f49,wood:true,source:"https://diamondbilliards.com/pages/pro-am"),
        .init(id:"professional",brand:"Z-Di",name:"Professional",base:2,cabinet:0x604332,cloth:0x29864c,trim:0xa08c6c,wood:true,source:"https://diamondbilliards.com/"),
        .init(id:"smart",brand:"Z-Di",name:"Smart",base:0,cabinet:0x24282d,cloth:0x297e9c,trim:0x72777a,wood:false,source:"https://diamondbilliards.com/pages/smart"),
        .init(id:"ox",brand:"Z-Ra",name:"OX",base:3,cabinet:0x25282e,cloth:0x287b94,trim:0x8b949a,wood:false,source:"https://www.rasson.cn/pool-tables"),
        .init(id:"victory",brand:"Z-Ra",name:"Victory II Plus",base:4,cabinet:0xd4d7d5,cloth:0x33828e,trim:0x60686d,wood:false,source:"https://www.rasson.cn/pool-tables"),
        .init(id:"acurra",brand:"Z-Ra",name:"Acurra",base:3,cabinet:0x33383d,cloth:0x377f99,trim:0xbdc2c6,wood:false,source:"https://www.rasson.cn/acurra-mr-sung"),
        .init(id:"tournament",brand:"Z-Ol",name:"Tournament Pro",base:4,cabinet:0x38332f,cloth:0x2d7d96,trim:0x94918a,wood:false,source:"https://www.olhausenbilliards.com/departments/pool-tables/tournament"),
        .init(id:"champion",brand:"Z-Ol",name:"Grand Champion III",base:1,cabinet:0x775136,cloth:0x31795b,trim:0xaaa49c,wood:true,source:"https://www.olhausenbilliards.com/departments/pool-tables/tournament"),
        // 0.35: bar-box bodies (solid cabinet to the floor, coin door) — Zoker designs; the bed stays the 9 ft physics bed.
        .init(id:"zbar",brand:"Z-Va",name:"Bar Box Classic",base:6,cabinet:0x1b1d20,cloth:0x7a2529,trim:0xb9bdc1,wood:false,source:"Zoker design (bar-box style)"),
        .init(id:"zbaroak",brand:"Z-Va",name:"Bar Box Oak",base:6,cabinet:0x6a4a30,cloth:0x2f6e4a,trim:0xc8b27a,wood:true,source:"Zoker design (bar-box style)"),
        .init(id:"zbarpro",brand:"Z-Di",name:"Bar Box Pro",base:6,cabinet:0x26292e,cloth:0x2a6fa8,trim:0x9aa3aa,wood:false,source:"Zoker design (bar-box style)"),
    ]
    static var selected:TableLook {
        // 0.34: make the owner's reference table the default once, then respect later choices
        if !UserDefaults.standard.bool(forKey:"tableDefault034"){UserDefaults.standard.set(true,forKey:"tableDefault034");UserDefaults.standard.set("zmax",forKey:"tableLook015")}
        return all.first{$0.id==UserDefaults.standard.string(forKey:"tableLook015")} ?? all[0]
    }
}
struct CueLook {
    let id:String,brand:String,name:String,role:Int
    let color:UInt32,accent:UInt32
    let carbon:Bool
    var title:String {brand+" · "+name}
    static let roles=["Đánh","Jump","Phá"]
    static let all:[CueLook] = [
        .init(id:"p3",brand:"Z-Pr",name:"P3 Black",role:0,color:0x25272b,accent:0xc6bca0,carbon:true),
        .init(id:"air",brand:"Z-Pr",name:"Air Rush",role:1,color:0x155c65,accent:0xc5c8c9,carbon:true),
        .init(id:"bk",brand:"Z-Pr",name:"BK Rush",role:2,color:0x23262a,accent:0xc7ad43,carbon:true),
        .init(id:"svb",brand:"Z-Cu",name:"Cynergy SVB",role:0,color:0x66605c,accent:0xe0d7bb,carbon:true),
        .init(id:"propel",brand:"Z-Cu",name:"Propel",role:1,color:0x6c2529,accent:0xb7bbbd,carbon:true),
        .init(id:"breach",brand:"Z-Cu",name:"Breach",role:2,color:0x543826,accent:0xa7976b,carbon:true),
        .init(id:"ec9",brand:"Z-Me",name:"EC9",role:0,color:0x563b28,accent:0xd5d1bf,carbon:false),
        .init(id:"ad3",brand:"Z-Me",name:"Airdrive 3",role:1,color:0x242b2c,accent:0xbcc8c3,carbon:true),
        .init(id:"pbg",brand:"Z-Me",name:"Power Break G",role:2,color:0x252c29,accent:0x9ca68c,carbon:true),
        .init(id:"zplay",brand:"Zoker",name:"Maple",role:0,color:0x5d3224,accent:0xd7b676,carbon:false),
        .init(id:"zjump",brand:"Zoker",name:"Jump",role:1,color:0x18515a,accent:0xb5b9bc,carbon:false),
        .init(id:"zbreak",brand:"Zoker",name:"Break",role:2,color:0x322b26,accent:0xb29b70,carbon:false)
    ]
}
enum CueBag {
    static let names=["Thi đấu","Luyện tập","Dự phòng"]
    static var active:Int {
        get {min(2,max(0,UserDefaults.standard.integer(forKey:"activeBag015")))}
        set {UserDefaults.standard.set(min(2,max(0,newValue)),forKey:"activeBag015")}
    }
    static func cue(_ role:Int)->CueLook {
        let r=min(2,max(0,role)),fallback=CueLook.all[active*3+r]
        let id=UserDefaults.standard.string(forKey:"cueBag015.\(active).\(r)")
        return CueLook.all.first{$0.id==id && $0.role==r} ?? fallback
    }
    static func put(_ cue:CueLook){UserDefaults.standard.set(cue.id,forKey:"cueBag015.\(active).\(cue.role)")}
}
extension UIColor {
    static func rgb(_ hex:UInt32)->UIColor {UIColor(red:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1)}
}
final class EquipmentLibraryController:UIViewController,UITableViewDataSource,UITableViewDelegate {
    var changed:((Int?)->Void)?
    var initialTab=0
    private let table:TableScene
    private let list=UITableView(frame:.zero,style:.insetGrouped),preview=SCNView(),note=UILabel()
    private let tabs=UISegmentedControl(items:["\(TableLook.all.count) bàn","12 cơ","3 bao cơ"])
    private var chosenCue=CueBag.cue(0)
    init(table:TableScene){self.table=table;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError()}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override func viewDidLoad(){
        super.viewDidLoad();overrideUserInterfaceStyle = .dark;title="Thư viện bàn & bao cơ";view.backgroundColor = .ink
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Xong",style:.done,target:self,action:#selector(close))
        tabs.selectedSegmentTintColor = .mint
        tabs.setTitleTextAttributes([.foregroundColor:UIColor.white],for:.normal)
        tabs.setTitleTextAttributes([.foregroundColor:UIColor.ink],for:.selected)
        let bar=UINavigationBarAppearance();bar.configureWithOpaqueBackground();bar.backgroundColor = .ink;bar.titleTextAttributes=[.foregroundColor:UIColor.white]
        navigationController?.navigationBar.standardAppearance=bar;navigationController?.navigationBar.scrollEdgeAppearance=bar;navigationController?.navigationBar.compactAppearance=bar
        tabs.selectedSegmentIndex=initialTab;tabs.addAction(UIAction{[weak self]_ in self?.refresh()},for:.valueChanged)
        for v in [tabs,list,preview,note]{v.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(v)}
        list.dataSource=self;list.delegate=self;list.backgroundColor = .clear
        preview.backgroundColor = .clear;preview.allowsCameraControl=true;preview.autoenablesDefaultLighting=false
        preview.antialiasingMode = .multisampling4X;preview.isPlaying=true
        note.numberOfLines=0;note.font = .systemFont(ofSize:11);note.textColor = .mint
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),tabs.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:12),tabs.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-12),
            list.topAnchor.constraint(equalTo:tabs.bottomAnchor,constant:8),list.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor),list.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor),list.widthAnchor.constraint(equalTo:view.widthAnchor,multiplier:0.47),
            preview.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor),preview.topAnchor.constraint(equalTo:tabs.bottomAnchor,constant:8),preview.trailingAnchor.constraint(equalTo:list.leadingAnchor),preview.bottomAnchor.constraint(equalTo:note.topAnchor,constant:-4),
            note.leadingAnchor.constraint(equalTo:preview.leadingAnchor,constant:12),note.trailingAnchor.constraint(equalTo:preview.trailingAnchor,constant:-10),note.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-8),note.heightAnchor.constraint(equalToConstant:62)])
        refresh()
    }
    private func refresh(){
        list.reloadData()
        if tabs.selectedSegmentIndex==0 {
            preview.scene=table.tablePreviewScene()
            note.text=TableLook.selected.title+"\nDựng tham khảo · xoay để xem. Tất cả dùng sân tập 9 ft; hình học và thông số hãng chưa được tái tạo chính xác."
        }else{
            preview.scene=table.cuePreviewScene()
            note.text="Bao \(CueBag.names[CueBag.active]) · chọn cơ để đưa vào đúng ngăn Đánh / Jump / Phá.\nMẫu dựng tham khảo; vật lý dùng ba cấu hình chung của Zoker."
        }
    }
    func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int {[TableLook.all.count,CueLook.all.count,CueBag.names.count][tabs.selectedSegmentIndex]}
    func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let cell=UITableViewCell(style:.subtitle,reuseIdentifier:nil);cell.backgroundColor=UIColor(white:0.12,alpha:1)
        cell.textLabel?.textColor = .white;cell.detailTextLabel?.textColor = .mint;cell.textLabel?.font = .systemFont(ofSize:13,weight:.medium)
        cell.detailTextLabel?.font = .systemFont(ofSize:11);cell.detailTextLabel?.numberOfLines=2
        let i=indexPath.row
        if tabs.selectedSegmentIndex==0 {
            let item=TableLook.all[i];cell.textLabel?.text=item.title
            cell.detailTextLabel?.text="Bản dựng tham khảo · xem 3D";cell.imageView?.image=tableIcon(item)
            cell.accessoryType=item.id==TableLook.selected.id ? .checkmark:.none
        }else if tabs.selectedSegmentIndex==1 {
            let item=CueLook.all[i];cell.textLabel?.text=item.title;cell.detailTextLabel?.text=CueLook.roles[item.role]+" · thêm vào bao "+CueBag.names[CueBag.active]
            cell.accessoryType=CueBag.cue(item.role).id==item.id ? .checkmark:.none
            cell.imageView?.image=UIImage(systemName:item.role==1 ? "arrow.up.right":"line.diagonal");cell.imageView?.tintColor = .rgb(item.accent)
        }else{
            cell.textLabel?.text=CueBag.names[i];cell.detailTextLabel?.text="Ba ngăn: Đánh · Jump · Phá"
            cell.imageView?.image=UIImage(systemName:"bag");cell.imageView?.tintColor = .mint;cell.accessoryType=i==CueBag.active ? .checkmark:.none
        };return cell
    }
    func tableView(_ tableView:UITableView,didSelectRowAt indexPath:IndexPath){
        let i=indexPath.row
        if tabs.selectedSegmentIndex==0 {let look=TableLook.all[i];UserDefaults.standard.set(look.id,forKey:"tableLook015");table.selectTable(look);changed?(nil)}
        else if tabs.selectedSegmentIndex==1 {chosenCue=CueLook.all[i];CueBag.put(chosenCue);table.selectCue(chosenCue.role);changed?(chosenCue.role)}
        else {CueBag.active=i;table.selectCue(0);changed?(0)}
        refresh()
    }
    private func tableIcon(_ item:TableLook)->UIImage {
        UIGraphicsImageRenderer(size:CGSize(width:62,height:40)).image{c in
            UIColor.rgb(item.cabinet).setFill();UIBezierPath(roundedRect:CGRect(x:1,y:1,width:60,height:38),cornerRadius:5).fill()
            UIColor.rgb(item.cloth).setFill();UIBezierPath(roundedRect:CGRect(x:7,y:6,width:48,height:28),cornerRadius:3).fill()
            UIColor.black.setFill();for x in [8,31,54]{for y in [6,34]{c.cgContext.fillEllipse(in:CGRect(x:x-2,y:y-2,width:4,height:4))}}
        }
    }
    @objc private func close(){preview.isPlaying=false;dismiss(animated:true)}
}
